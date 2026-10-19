-- Idempotent display-only examples. Never creates successful payment events or money.
-- Existing account names, services, passwords and business records are preserved.
begin;
do $$
declare
 c uuid; p uuid; s_id bigint; b_id bigint; item jsonb; i integer := 0;
 status text; label text; booking_code text; service_data jsonb;
 statuses text[] := array['Requested','Requested','Requested','Accepted','Accepted','OnTheWay','Completed','Completed','Completed','Cancelled','Rejected'];
begin
 perform pg_advisory_xact_lock(hashtext('upyogi-demo-v1'));
 select id into c from auth.users where email='customer@upyogi.test';
 select id into p from auth.users where email='provider@upyogi.test';
 if c is null or p is null then raise exception 'Create the two confirmed demo accounts first'; end if;
 if not exists(select 1 from public.app_profiles where id=c and role='Customer') or not exists(select 1 from public.app_profiles where id=p and role='Provider') then raise exception 'Unexpected account roles'; end if;
 insert into public.wallet_accounts(owner_id,currency) values(c,'sar'),(p,'sar') on conflict(owner_id,currency) do nothing;
 insert into public.provider_profiles(owner_id,data)
 values(p,jsonb_build_object('bio','ملف عرض تجريبي فقط / Demo provider','serviceCategory','Cleaner','experienceYears',3,'priceFrom',50,'priceTo',250,'serviceRadiusKm',15,'address','عنوان تجريبي — الرياض','workingDays','Saturday,Sunday,Monday,Tuesday,Wednesday,Thursday','workingHoursStart','09:00','workingHoursEnd','18:00')) on conflict(owner_id) do nothing;
 for item in select value from jsonb_array_elements('[
 {"code":"electrical","title":"كهرباء منزلية — تجريبي / Demo Electrical","category":"Electrician","subcategory":"Home Wiring","price":95},
 {"code":"plumbing","title":"سباكة منزلية — تجريبي / Demo Plumbing","category":"Plumber","subcategory":"Leak Repair","price":110},
 {"code":"ac","title":"صيانة مكيفات — تجريبي / Demo AC Repair","category":"AC Repair","subcategory":"AC Maintenance","price":150},
 {"code":"carpentry","title":"نجارة وتركيب — تجريبي / Demo Carpentry","category":"Carpenter","subcategory":"Furniture Assembly","price":130},
 {"code":"painting","title":"دهان غرف — تجريبي / Demo Painting","category":"Painter","subcategory":"Interior Painting","price":200},
 {"code":"appliance","title":"صيانة أجهزة — تجريبي / Demo Appliances","category":"Appliance Repair","subcategory":"Appliance Maintenance","price":125}
 ]'::jsonb) loop
   if not exists(select 1 from public.services where owner_id=p and data->>'demoSeed'='upyogi-demo-v1' and data->>'demoCode'=item->>'code') then
     insert into public.services(owner_id,data,is_active) values(p,jsonb_build_object(
       'demoSeed','upyogi-demo-v1','demoCode',item->>'code','title',item->>'title','category',item->>'category','subcategory',item->>'subcategory',
       'shortDescription','خدمة افتراضية لعرض التطبيق فقط / Demonstration only',
       'detailedDescription','مثال افتراضي لا يمثل حجزًا أو مقدم خدمة حقيقيًا. الدفع مع الفني مباشرة بعد الإنجاز. / Demo only. Pay the technician after completion.',
       'startingPrice',(item->>'price')::numeric,'priceType','Fixed','state','الرياض — تجريبي','city','الرياض — تجريبي',
       'fullAddress','عنوان افتراضي للعرض فقط — لا يوجد موقع عميل حقيقي','latitude',24.7136,'longitude',46.6753,
       'workingDays','Saturday,Sunday,Monday,Tuesday,Wednesday,Thursday','startTime','09:00','endTime','18:00',
       'providerName','فني تجريبي / Demo Technician','phoneNumber','0500000000','email','provider@upyogi.test',
       'experienceYears',3,'certifications','بيانات عرض فقط، غير موثقة / Demo only, unverified','skills','خدمة منزلية تجريبية',
       'serviceDuration','60 minutes','emergencyService',false,'homeVisitAvailable',true,'materialsIncluded',false,
       'imageUrl','','rating',0,'totalReviews',0),true);
   end if;
 end loop;
 foreach status in array statuses loop
   i := i+1; booking_code := 'booking-'||i;
   select id,data into s_id,service_data from public.services where owner_id=p and data->>'demoSeed'='upyogi-demo-v1' order by id offset ((i-1)%6) limit 1;
   select id into b_id from public.bookings where customer_id=c and provider_id=p and data->>'demoSeed'='upyogi-demo-v1' and data->>'demoCode'=booking_code;
   if b_id is null then
     insert into public.bookings(service_id,customer_id,provider_id,amount_minor,currency,booking_status,payment_status,data)
     values(s_id,c,p,round((service_data->>'startingPrice')::numeric*100),'sar',status,'External',jsonb_build_object(
       'demoSeed','upyogi-demo-v1','demoCode',booking_code,'serviceTitle',service_data->>'title',
       'customerName','عميل افتراضي / Demo Customer','providerName','فني تجريبي / Demo Technician','customerPhone','0500000000',
       'appointmentDate',to_char((case when status in ('Completed','Cancelled','Rejected') then now()-make_interval(days=>i) else now()+make_interval(days=>i) end) at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
       'appointmentTime','10:00','serviceAddress','عنوان افتراضي للعرض فقط — الرياض / Fictional demo address',
       'notes','بيانات عرض افتراضية فقط، ليست طلب خدمة حقيقيًا. / Demonstration only.',
       'latitude',24.7136,'longitude',46.6753)) returning id into b_id;
   end if;
   -- A deliberately old fictional point prevents displaying it as a fresh GPS fix.
   if status='OnTheWay' then
     insert into public.booking_locations(booking_id,latitude,longitude,updated_at)
     values(b_id,24.7136,46.6753,now()-interval '10 minutes') on conflict(booking_id) do nothing;
   end if;
   if status='Completed' then
     insert into public.reviews(booking_id,service_id,customer_id,customer_name,rating,comment)
     values(b_id,s_id,c,'عميل افتراضي / Demo Customer',case when i=8 then 4 else 5 end,
       'تقييم افتراضي للعرض فقط، وليس تجربة عميل حقيقية. / Demonstration review only.') on conflict(booking_id) do nothing;
   end if;
   label := '[DEMO upyogi-demo-v1] '||booking_code;
   if not exists(select 1 from public.notifications where owner_id=p and title=label) then
     insert into public.notifications(owner_id,title,message,type,related_id,is_read)
     values(p,label,'طلب عرض افتراضي — '||(service_data->>'title')||' / Demo request.','Booking',b_id,status<>'Requested');
   end if;
   if not exists(select 1 from public.notifications where owner_id=c and title=label) then
     insert into public.notifications(owner_id,title,message,type,related_id,is_read)
     values(c,label,'حجز تجريبي بحالة '||status||'. الدفع خارج التطبيق بعد الإنجاز. / Demo booking.','Booking',b_id,status in ('Completed','Cancelled','Rejected'));
   end if;
 end loop;
 -- Aggregate display ratings from the explicitly marked demonstration reviews only.
 update public.services s set data=s.data||jsonb_build_object('rating',coalesce((select round(avg(r.rating),1) from public.reviews r where r.service_id=s.id),0),'totalReviews',(select count(*) from public.reviews r where r.service_id=s.id)) where owner_id=p and data->>'demoSeed'='upyogi-demo-v1';
end $$;
commit;
