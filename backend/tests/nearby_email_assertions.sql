-- Disposable fixtures: every insert/update is rolled back; no external email is sent.
begin;
set local role service_role;
do $$
declare provider uuid; customer uuid; near_id bigint; far_id bigint; demo_id bigint; missing_id bigint; edge_id bigint; booking bigint; ids bigint[]; n integer;
begin
 select owner_id into provider from public.services limit 1;
 select customer_id into customer from public.bookings limit 1;
 if provider is null or customer is null then raise exception 'Existing test participants required'; end if;
 insert into public.services(owner_id,data) values(provider,'{"title":"Geo assertion A","category":"Cleaner","startingPrice":75,"latitude":0,"longitude":0}') returning id into near_id;
 insert into public.services(owner_id,data) values(provider,'{"title":"Geo assertion B","category":"Cleaning","startingPrice":125,"latitude":0.03,"longitude":0}') returning id into far_id;
 insert into public.services(owner_id,data) values(provider,'{"title":"Geo assertion C","category":"Cleaning","startingPrice":60,"latitude":0.001,"longitude":0,"isDemo":true}') returning id into demo_id;
 insert into public.services(owner_id,data) values(provider,'{"title":"Geo assertion D","category":"Cleaning","startingPrice":10}') returning id into missing_id;
 insert into public.services(owner_id,data) values(provider,'{"title":"Geo assertion E","category":"Cleaning","startingPrice":80,"latitude":0,"longitude":-179.99}') returning id into edge_id;
 select array_agg(id order by distance_m) into ids from public.search_sulh_services(0,0,5,'Geo assertion','تنظيف','',null,null,'nearest',false);
 -- This statement below is intentionally separate from API numeric parsing: typed SQL arguments only.
 if ids is distinct from array[near_id,far_id] then raise exception 'Nearest/category/demo/unknown-location check failed: %',ids; end if;
 select array_agg(id) into ids from public.search_sulh_services(0,0,1,'Geo assertion','','',null,null,'nearest',false);
 if ids is distinct from array[near_id] then raise exception 'Radius filter failed'; end if;
 select array_agg(id) into ids from public.search_sulh_services(0,0,5,'Geo assertion','','',100,150,'nearest',false);
 if ids is distinct from array[far_id] then raise exception 'Price filter failed'; end if;
 select count(*) into n from public.search_sulh_services(0,0,5,'Geo assertion','','',null,null,'nearest',true);
 if n<>3 then raise exception 'Explicit demo mode failed'; end if;
 select count(*) into n from public.search_sulh_services(0,179.99,5,'Geo assertion','','',null,null,'nearest',false) where id=edge_id;
 if n<>1 then raise exception 'Antimeridian distance failed'; end if;
 if has_function_privilege('anon','public.search_sulh_services(double precision,double precision,double precision,text,text,text,double precision,double precision,text,boolean)','EXECUTE') then raise exception 'Anonymous RPC access'; end if;
 insert into public.bookings(service_id,customer_id,provider_id,data,amount_minor,currency,booking_status,payment_status) values(near_id,customer,provider,'{"serviceTitle":"Geo assertion A","providerName":"QA"}',7500,'sar','Requested','Pending') returning id into booking;
 update public.bookings set booking_status='Accepted' where id=booking;
 update public.bookings set booking_status='Accepted' where id=booking;
 select count(*) into n from public.booking_email_outbox where booking_id=booking and recipient_id=customer;
 if n<>1 then raise exception 'Confirmation must queue exactly once for customer'; end if;
 select count(*) into n from public.claim_sulh_booking_email(booking);
 if n<>1 then raise exception 'First mail lease missing'; end if;
 select count(*) into n from public.claim_sulh_booking_email(booking);
 if n<>0 then raise exception 'Duplicate simultaneous mail lease'; end if;
 perform public.record_sulh_email_delivery('sulh-rollback-assertion','delivered');
 update public.booking_email_outbox set provider_message_id='sulh-rollback-assertion',status='submitted' where booking_id=booking;
 perform public.record_sulh_email_delivery('sulh-rollback-assertion','delayed');
 if not exists(select 1 from public.booking_email_outbox where booking_id=booking and status='delivered') then raise exception 'Receipt race/terminal delivery regressed'; end if;
end $$;
rollback;
select 'nearest, radius, category, price, demo, antimeridian, RPC ACL, outbox uniqueness, lease, webhook receipt: passed' as checks;
