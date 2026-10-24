begin;
create extension if not exists postgis with schema extensions;
grant usage on schema private to service_role;
alter table public.services add column location extensions.geography(Point,4326);
alter table public.services add column is_demo boolean not null default false;
create function private.sync_sulh_service_location() returns trigger language plpgsql security invoker set search_path='' as $$
declare lat double precision; lng double precision;
begin
 new.is_demo := coalesce((new.data->>'isDemo')='true',false) or new.data ? 'demoSeed' or new.data ? 'demoProject' or coalesce(new.data->>'title','') ~* '(demo|تجريب|تجربة)';
 if jsonb_typeof(new.data->'latitude')='number' and jsonb_typeof(new.data->'longitude')='number' then
   lat := (new.data->>'latitude')::double precision; lng := (new.data->>'longitude')::double precision;
   if lat between -90 and 90 and lng between -180 and 180 then new.location:=extensions.st_setsrid(extensions.st_makepoint(lng,lat),4326)::extensions.geography; else new.location:=null; end if;
 else new.location:=null;
 end if;
 return new;
end $$;
revoke all on function private.sync_sulh_service_location() from public,anon,authenticated;
create trigger sync_sulh_service_location before insert or update of data on public.services for each row execute function private.sync_sulh_service_location();
-- Derive new search columns without changing any advertised service fields.
update public.services set data=data;
create index services_location_gist on public.services using gist(location) where is_active;
create function private.sulh_category(value text) returns text language sql immutable security invoker set search_path='' as $$
 select case lower(trim(coalesce(value,''))) when 'cleaner' then 'cleaning' when 'تنظيف' then 'cleaning' when 'سباكة' then 'plumber' when 'سباك' then 'plumber' when 'كهرباء' then 'electrician' when 'كهربائي' then 'electrician' when 'تكييف' then 'ac repair' when 'مكيفات' then 'ac repair' when 'نجارة' then 'carpenter' when 'نجار' then 'carpenter' when 'دهان' then 'painter' when 'أجهزة' then 'appliance repair' else lower(trim(coalesce(value,''))) end;
$$;
revoke all on function private.sulh_category(text) from public,anon,authenticated;
grant execute on function private.sulh_category(text) to service_role;
create function public.search_sulh_services(p_lat double precision default null,p_lng double precision default null,p_radius_km double precision default 25,p_search text default '',p_category text default '',p_city text default '',p_min_price double precision default null,p_max_price double precision default null,p_sort text default 'newest',p_include_demo boolean default false)
returns table(id bigint,owner_id uuid,data jsonb,is_active boolean,created_at timestamptz,is_demo boolean,latitude double precision,longitude double precision,distance_m double precision)
language plpgsql stable security invoker set search_path='' as $$
begin
 if (p_lat is null)<>(p_lng is null) or p_lat not between -90 and 90 or p_lng not between -180 and 180 or p_radius_km not between 1 and 200 or p_radius_km is null then raise exception 'invalid_location' using errcode='22023'; end if;
 if p_sort not in ('nearest','newest','price_asc','price_desc','rating') or (p_sort='nearest' and p_lat is null) then raise exception 'invalid_sort' using errcode='22023'; end if;
 if p_min_price<0 or p_max_price<0 or p_min_price>p_max_price then raise exception 'invalid_price' using errcode='22023'; end if;
 return query
 with matches as (
  select s.id,s.owner_id,s.data,s.is_active,s.created_at,s.is_demo,
   extensions.st_y(s.location::extensions.geometry) lat,extensions.st_x(s.location::extensions.geometry) lng,
   case when p_lat is not null then extensions.st_distance(s.location,extensions.st_setsrid(extensions.st_makepoint(p_lng,p_lat),4326)::extensions.geography) end dist,
   (s.data->>'startingPrice')::double precision price,coalesce((s.data->>'rating')::double precision,0) rating
  from public.services s
  where s.is_active and (p_include_demo or not s.is_demo)
   and (p_category='' or private.sulh_category(s.data->>'category')=private.sulh_category(p_category))
   and (p_city='' or s.data->>'city'=p_city)
   and (p_search='' or position(lower(p_search) in lower(concat_ws(' ',s.data->>'title',s.data->>'shortDescription',s.data->>'subcategory',s.data->>'category',s.data->>'providerName')))>0 or private.sulh_category(s.data->>'category')=private.sulh_category(p_search))
   and (p_min_price is null or (s.data->>'startingPrice')::double precision>=p_min_price)
   and (p_max_price is null or (s.data->>'startingPrice')::double precision<=p_max_price)
   and (p_lat is null or (s.location is not null and extensions.st_dwithin(s.location,extensions.st_setsrid(extensions.st_makepoint(p_lng,p_lat),4326)::extensions.geography,p_radius_km*1000)))
 ) select m.id,m.owner_id,m.data,m.is_active,m.created_at,m.is_demo,m.lat,m.lng,m.dist from matches m
 order by case when p_sort='nearest' then m.dist end asc nulls last,
 case when p_sort='price_asc' then m.price end asc nulls last,
 case when p_sort='price_desc' then m.price end desc nulls last,
 case when p_sort='rating' then m.rating end desc nulls last,m.created_at desc,m.id desc limit 100;
end $$;
revoke all on function public.search_sulh_services(double precision,double precision,double precision,text,text,text,double precision,double precision,text,boolean) from public,anon,authenticated;
grant execute on function public.search_sulh_services(double precision,double precision,double precision,text,text,text,double precision,double precision,text,boolean) to service_role;

create table public.booking_email_outbox (
 id uuid primary key default gen_random_uuid(),
 booking_id bigint not null unique references public.bookings(id) on delete cascade,
 recipient_id uuid not null references auth.users(id),
 payload jsonb not null,
 status text not null default 'queued' check(status in ('queued','processing','submitted','delivered','delayed','bounced','failed','blocked')),
 attempt_count integer not null default 0 check(attempt_count>=0),
 lock_token uuid, first_attempt_at timestamptz,last_attempt_at timestamptz,
 next_attempt_at timestamptz not null default now(),
 provider_message_id text unique,error_code text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
alter table public.booking_email_outbox enable row level security;
revoke all on public.booking_email_outbox from public,anon,authenticated;
grant all on public.booking_email_outbox to service_role;
create index booking_email_recipient_idx on public.booking_email_outbox(recipient_id);
create function private.queue_sulh_booking_email() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.booking_status='Accepted' and old.booking_status is distinct from 'Accepted' then
  insert into public.booking_email_outbox(booking_id,recipient_id,payload) values(new.id,new.customer_id,
   jsonb_build_object('serviceTitle',new.data->>'serviceTitle','providerName',new.data->>'providerName','appointmentDate',new.data->>'appointmentDate','appointmentTime',new.data->>'appointmentTime')) on conflict(booking_id) do nothing;
  insert into public.notifications(owner_id,title,message,type,related_id) values(new.customer_id,'تم تأكيد الحجز','وافق الفني على طلبك. يمكنك متابعة الحجز من التطبيق.','Booking',new.id);
 end if;
 return new;
end $$;
revoke all on function private.queue_sulh_booking_email() from public,anon,authenticated;
create trigger queue_sulh_booking_email after update of booking_status on public.bookings for each row execute function private.queue_sulh_booking_email();
create function public.claim_sulh_booking_email(p_booking_id bigint) returns setof public.booking_email_outbox language sql security invoker set search_path='' as $$
 update public.booking_email_outbox e set status='processing',attempt_count=e.attempt_count+1,lock_token=gen_random_uuid(),first_attempt_at=coalesce(e.first_attempt_at,now()),last_attempt_at=now(),next_attempt_at=now()+interval '2 minutes',updated_at=now()
 where e.booking_id=p_booking_id and e.attempt_count<5
 and (e.first_attempt_at is null or e.first_attempt_at>now()-interval '23 hours')
 and (e.status in ('queued','failed','blocked') or (e.status='processing' and e.last_attempt_at<now()-interval '2 minutes'))
 and e.next_attempt_at<=now()
 and exists(select 1 from public.bookings b where b.id=e.booking_id and b.booking_status in ('Accepted','OnTheWay','Completed'))
 returning e.*;
$$;
revoke all on function public.claim_sulh_booking_email(bigint) from public,anon,authenticated;
grant execute on function public.claim_sulh_booking_email(bigint) to service_role;
commit;
