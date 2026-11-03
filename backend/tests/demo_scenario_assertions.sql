begin;
do $$
declare customer uuid; provider uuid; service bigint; b bigint; real_b bigint; row public.bookings; n integer;
begin
 select p.id into customer from public.app_profiles p join auth.users u on u.id=p.id where p.role='Customer' and u.email like '%.test' order by p.id limit 1;
 if customer is null then raise exception 'Test customer required'; end if;
 perform public.seed_sulh_demo_catalog();
 select public.seed_sulh_demo_catalog() into n;
 assert n=0, 'repeat seed must add zero rows';
 assert (select count(*)=24 from public.services where data->>'demoSeed'='sulh-demo-v2'), '24 distinct services required';
 select id,owner_id into service,provider from public.services where data->>'demoSeed'='sulh-demo-v2' order by id limit 1;
 insert into public.bookings(service_id,customer_id,provider_id,amount_minor,payment_status,data)
 values(service,customer,provider,10000,'External','{"demoScenario":true}') returning id into b;
 begin
  perform public.advance_sulh_demo_booking(provider,b,'Requested',false);
  raise exception 'wrong customer was allowed';
 exception when no_data_found then null; end;
 begin
  perform public.advance_sulh_demo_booking(customer,b,'Requested',true);
  raise exception 'early payment skip was allowed';
 exception when invalid_parameter_value then null; end;
 select * into row from public.advance_sulh_demo_booking(customer,b,'Requested',false);
 assert row.booking_status='Accepted';
 assert not exists(select 1 from public.booking_email_outbox where booking_id=b),'demo must not queue email';
 begin
  perform public.advance_sulh_demo_booking(customer,b,'Requested',false);
  raise exception 'stale retry advanced twice';
 exception when serialization_failure then null; end;
 perform public.advance_sulh_demo_booking(customer,b,'Accepted',false);
 select * into row from public.advance_sulh_demo_booking(customer,b,'OnTheWay',false);
 assert row.booking_status='Completed';
 perform public.advance_sulh_demo_booking(customer,b,'Completed',true);
 select * into row from public.advance_sulh_demo_booking(customer,b,'Completed',true);
 assert row.data->>'demoPaymentSkipped'='true';
 assert row.payment_status='External' and row.stripe_payment_intent_id is null, 'skip must not create payment';
 insert into public.bookings(service_id,customer_id,provider_id,amount_minor,payment_status,data)
 values(service,customer,provider,10000,'External','{}') returning id into real_b;
 begin
  perform public.advance_sulh_demo_booking(customer,real_b,'Requested',false);
  raise exception 'unflagged booking was allowed';
 exception when insufficient_privilege then null; end;
 update public.bookings set booking_status='Cancelled' where id=real_b;
 update public.bookings set data='{"demoScenario":true}' where id=real_b;
 begin
  perform public.advance_sulh_demo_booking(customer,real_b,'Cancelled',false);
  raise exception 'cancelled booking advanced';
 exception when invalid_parameter_value then null; end;
 assert not has_function_privilege('anon','public.seed_sulh_demo_catalog()','EXECUTE');
 assert not has_function_privilege('authenticated','public.advance_sulh_demo_booking(uuid,bigint,text,boolean)','EXECUTE');
 assert (select count(*)>0 from public.search_sulh_services(p_search=>'الكَهرباء',p_include_demo=>true)), 'Arabic normalized search required';
 assert (select count(*)>=8 from public.search_sulh_services(p_search=>'جدة',p_include_demo=>true)), 'city text search required';
 assert not exists(select 1 from public.search_sulh_services(p_include_demo=>false) where is_demo),'real results exclude demos';
 raise notice 'PASS: seed idempotency, ownership, sequence, retry, skip, financial isolation, email suppression, cancelled booking, permissions and Arabic search';
end $$;
rollback;
