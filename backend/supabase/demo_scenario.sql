begin;
-- Catalog keys prevent concurrent/repeated generation from creating duplicates.
create unique index if not exists services_sulh_demo_code on public.services ((data->>'demoCode')) where data->>'demoSeed'='sulh-demo-v2';
create or replace function public.seed_sulh_demo_catalog() returns integer
language plpgsql security invoker set search_path='' as $$
declare provider uuid; item record; city record; inserted integer; total integer:=0;
begin
 select s.owner_id into provider from public.services s join auth.users u on u.id=s.owner_id
 join public.app_profiles p on p.id=u.id
 where s.data->>'demoSeed'='upyogi-demo-v1' and u.email='provider@upyogi.test' and p.role='Provider' order by s.id limit 1;
 if provider is null then raise exception 'demo_provider_missing'; end if;
 for city in select * from (values ('riyadh','الرياض',24.7136,46.6753),('jeddah','جدة',21.5433,39.1728),('dammam','الدمام',26.4207,50.0888)) as c(code,name,lat,lng) loop
  for item in select * from (values
   ('cleaning','Cleaning','تنظيف المنزل','Home cleaning',120,'تنظيف وتعقيم الغرف والمطبخ'),
   ('plumbing','Plumber','إصلاح السباكة','Plumbing repair',95,'إصلاح تسرب المياه والحنفيات'),
   ('electrical','Electrician','صيانة الكهرباء','Electrical repair',110,'إصلاح الإنارة والمفاتيح الكهربائية'),
   ('ac','AC Repair','صيانة المكيفات','AC maintenance',150,'تنظيف وصيانة مكيفات الهواء'),
   ('carpentry','Carpenter','نجارة وتركيب أثاث','Furniture assembly',130,'تركيب وصيانة الأبواب والأثاث'),
   ('painting','Painter','دهان الغرف','Room painting',200,'دهان الجدران وتجديد الغرف'),
   ('appliances','Appliance Repair','صيانة الأجهزة المنزلية','Appliance repair',175,'صيانة الغسالات والثلاجات والأفران'),
   ('pest','Pest Control','مكافحة الحشرات','Pest control',160,'خدمة مكافحة الحشرات المنزلية')
  ) as i(code,category,title,en,price,description) loop
   insert into public.services(owner_id,data) values(provider,jsonb_build_object(
    'demoSeed','sulh-demo-v2','demoCode',city.code||'-'||item.code,'isDemo',true,
    'title',item.title||' — '||city.name||' / '||item.en||' (تجريبي)',
    'category',item.category,'subcategory',item.en,'shortDescription',item.description||' — بيانات افتراضية',
    'detailedDescription','خدمة وفني وموقع افتراضيون لتجربة صلح فقط. يمكن محاكاة الطلب حتى شاشة الدفع وتخطيها. لا تتم زيارة أو دفعة حقيقية.',
    'startingPrice',item.price,'priceType','Fixed','city',city.name,'state',city.name,
    'fullAddress','عنوان افتراضي — '||city.name,'pincode','00000',
    'latitude',city.lat,'longitude',city.lng,'providerName','فني صلح الافتراضي — '||item.title,
    'phoneNumber','0500000000','email','provider@upyogi.test','experienceYears',0,
    'skills',item.description,'serviceDuration','60 minutes','workingDays','Saturday,Sunday,Monday,Tuesday,Wednesday,Thursday',
    'startTime','09:00','endTime','18:00','emergencyService',false,'homeVisitAvailable',true,'materialsIncluded',false,
    'rating',0,'totalReviews',0,'imageUrl',''
   )) on conflict do nothing;
   get diagnostics inserted=row_count; total:=total+inserted;
  end loop;
 end loop;
 return total;
end $$;
revoke all on function public.seed_sulh_demo_catalog() from public,anon,authenticated;
grant execute on function public.seed_sulh_demo_catalog() to service_role;

create or replace function public.advance_sulh_demo_booking(p_user_id uuid,p_booking_id bigint,p_expected_status text,p_skip_payment boolean default false)
returns setof public.bookings language plpgsql security invoker set search_path='' as $$
declare b public.bookings; next_status text;
begin
 select * into b from public.bookings where id=p_booking_id and customer_id=p_user_id for update;
 if not found then raise exception 'demo_not_found' using errcode='P0002'; end if;
 if coalesce(b.data->>'demoScenario','')<>'true' or not exists(select 1 from public.services s where s.id=b.service_id and s.is_demo and s.data->>'demoSeed'='sulh-demo-v2')
 then raise exception 'not_demo' using errcode='42501'; end if;
 if b.payment_status<>'External' or b.stripe_payment_intent_id is not null then raise exception 'demo_has_payment' using errcode='22023'; end if;
 if p_expected_status is null or b.booking_status<>p_expected_status then raise exception 'demo_stale' using errcode='40001'; end if;
 if p_skip_payment then
  if b.booking_status<>'Completed' then raise exception 'demo_not_completed' using errcode='22023'; end if;
  update public.bookings set data=data||jsonb_build_object('demoPaymentSkipped',true) where id=b.id;
 else
  next_status:=case b.booking_status when 'Requested' then 'Accepted' when 'Accepted' then 'OnTheWay' when 'OnTheWay' then 'Completed' end;
  if next_status is null then raise exception 'demo_invalid_transition' using errcode='22023'; end if;
  update public.bookings set booking_status=next_status where id=b.id;
  insert into public.notifications(owner_id,title,message,type,related_id)
   values(p_user_id,'صلح — محاكاة حجز','تحديث تجريبي فقط: '||next_status,'Booking',b.id);
 end if;
 return query select * from public.bookings where id=b.id;
end $$;
revoke all on function public.advance_sulh_demo_booking(uuid,bigint,text,boolean) from public,anon,authenticated;
grant execute on function public.advance_sulh_demo_booking(uuid,bigint,text,boolean) to service_role;

-- A simulated acceptance must not queue or send real confirmation email.
create or replace function private.queue_sulh_booking_email() returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.data->>'demoScenario'='true' then return new; end if;
 if new.booking_status='Accepted' and old.booking_status is distinct from 'Accepted' then
  insert into public.booking_email_outbox(booking_id,recipient_id,payload) values(new.id,new.customer_id,
   jsonb_build_object('serviceTitle',new.data->>'serviceTitle','providerName',new.data->>'providerName','appointmentDate',new.data->>'appointmentDate','appointmentTime',new.data->>'appointmentTime')) on conflict(booking_id) do nothing;
  insert into public.notifications(owner_id,title,message,type,related_id) values(new.customer_id,'تم تأكيد الحجز','وافق الفني على طلبك. يمكنك متابعة الحجز من التطبيق.','Booking',new.id);
 end if;
 return new;
end $$;
create or replace function private.sulh_search_text(value text) returns text language sql immutable security invoker set search_path='' as $$
 select lower(translate(regexp_replace(coalesce(value,''),'[ًٌٍَُِّْـٰ]','','g'),'أإآى','اااي'));
$$;
revoke all on function private.sulh_search_text(text) from public,anon,authenticated;
grant execute on function private.sulh_search_text(text) to service_role;
create or replace function public.search_sulh_services(p_lat double precision default null,p_lng double precision default null,p_radius_km double precision default 25,p_search text default '',p_category text default '',p_city text default '',p_min_price double precision default null,p_max_price double precision default null,p_sort text default 'newest',p_include_demo boolean default false)
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
   and (p_search='' or position(private.sulh_search_text(p_search) in private.sulh_search_text(concat_ws(' ',s.data->>'title',s.data->>'shortDescription',s.data->>'subcategory',s.data->>'category',s.data->>'providerName',s.data->>'city')))>0 or private.sulh_category(s.data->>'category')=private.sulh_category(p_search))
   and (p_min_price is null or (s.data->>'startingPrice')::double precision>=p_min_price)
   and (p_max_price is null or (s.data->>'startingPrice')::double precision<=p_max_price)
   and (p_lat is null or (s.location is not null and extensions.st_dwithin(s.location,extensions.st_setsrid(extensions.st_makepoint(p_lng,p_lat),4326)::extensions.geography,p_radius_km*1000)))
 ) select m.id,m.owner_id,m.data,m.is_active,m.created_at,m.is_demo,m.lat,m.lng,m.dist from matches m
 order by case when p_sort='nearest' then m.dist end asc nulls last,
 case when p_sort='price_asc' then m.price end asc nulls last,
 case when p_sort='price_desc' then m.price end desc nulls last,
 case when p_sort='rating' then m.rating end desc nulls last,m.created_at desc,m.id desc limit 100;
end $$;
commit;
