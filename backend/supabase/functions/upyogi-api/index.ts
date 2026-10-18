import { createClient } from 'npm:@supabase/supabase-js@2.95.0';

const url = Deno.env.get('SUPABASE_URL')!;
const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false, autoRefreshToken: false },
});
const authClient = () => createClient(url, anon, { auth: { persistSession: false, autoRefreshToken: false } });
const cors = { 'Access-Control-Allow-Origin': '*', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info', 'Access-Control-Allow-Methods': 'GET,POST,PUT,DELETE,OPTIONS' };
class ApiError extends Error { constructor(public status: number, message: string) { super(message); } }
const fail = (status: number, message: string): never => { throw new ApiError(status, message); };
const reply = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...cors, 'Content-Type': 'application/json' } });
function checked<T>(r: { data: T; error: unknown }): T { if (r.error) { console.error('Database operation failed'); fail(500, 'تعذر إتمام العملية.'); } return r.data; }
const one = async (table: string, key: string, value: unknown) => checked(await admin.from(table).select('*').eq(key, value).maybeSingle());
const text = (v: unknown, max = 2000) => typeof v === 'string' ? v.trim().slice(0, max) : '';
async function input(req: Request): Promise<Record<string, any>> {
  if (Number(req.headers.get('content-length') || 0) > 6 * 1024 * 1024) fail(413, 'الملف كبير جدًا.');
  if (req.headers.get('content-type')?.includes('multipart/form-data')) {
    const result: Record<string, any> = {};
    for (const [key, value] of await req.formData()) result[key[0].toLowerCase() + key.slice(1)] = value;
    return result;
  }
  try { const data = await req.json(); if (data && typeof data === 'object' && !Array.isArray(data)) return data; } catch { /* invalid body */ }
  return fail(400, 'بيانات الطلب غير صحيحة.');
}
async function image(file: unknown, owner: string, privateFile = false) {
  if (!(file instanceof File) || !file.size) return undefined;
  const allowed = privateFile ? ['image/jpeg','image/png','application/pdf'] : ['image/jpeg','image/png','image/webp'];
  if (file.size > 5 * 1024 * 1024 || !allowed.includes(file.type)) fail(400, 'نوع الملف أو حجمه غير مسموح.');
  const bucket = privateFile ? 'private-documents' : 'service-images';
  const path = `${owner}/${crypto.randomUUID()}`;
  checked(await admin.storage.from(bucket).upload(path, file, { contentType: file.type }));
  return privateFile ? path : admin.storage.from(bucket).getPublicUrl(path).data.publicUrl;
}
async function stripe(path: string, values?: Record<string,string>, key?: string) {
  const secret = Deno.env.get('STRIPE_SECRET_KEY');
  if (!secret) fail(503, 'الشحن غير مفعّل بعد. يجب إعداد بوابة الدفع أولًا.');
  const r = await fetch(`https://api.stripe.com/v1/${path}`, { method: values ? 'POST' : 'GET', headers: { Authorization: `Bearer ${secret}`, ...(values ? { 'Content-Type':'application/x-www-form-urlencoded' } : {}), ...(key ? { 'Idempotency-Key':key } : {}) }, body: values ? new URLSearchParams(values) : undefined });
  const data = await r.json();
  if (!r.ok) fail(502, 'تعذر الاتصال ببوابة الدفع.');
  return data;
}
async function webhook(req: Request) {
  const secret = Deno.env.get('STRIPE_WEBHOOK_SECRET');
  if (!secret) return fail(503, 'Webhook not configured');
  const raw = await req.text();
  const parts = (req.headers.get('stripe-signature') || '').split(',').map(p => p.split('='));
  const timestamp = parts.find(p => p[0] === 't')?.[1];
  if (!timestamp || Math.abs(Date.now()/1000 - Number(timestamp)) > 300) fail(400, 'Invalid signature');
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey('raw', encoder.encode(secret), {name:'HMAC',hash:'SHA-256'}, false, ['sign']);
  const signature = new Uint8Array(await crypto.subtle.sign('HMAC', key, encoder.encode(`${timestamp}.${raw}`)));
  const valid = parts.filter(p => p[0] === 'v1').some(p => {
    if (!/^[0-9a-f]{64}$/.test(p[1] || '')) return false;
    let diff = 0; for (let i=0;i<32;i++) diff |= signature[i] ^ parseInt(p[1].slice(i*2,i*2+2),16); return diff === 0;
  });
  if (!valid) fail(400, 'Invalid signature');
  const event = JSON.parse(raw);
  if (event.type === 'payment_intent.succeeded') {
    const intent = event.data.object;
    if (intent.metadata?.purpose === 'wallet_topup') checked(await admin.rpc('credit_verified_topup', {
      p_stripe_event_id:event.id, p_payment_intent_id:intent.id, p_amount_minor:intent.amount_received, p_currency:intent.currency,
    }));
    else if (intent.metadata?.purpose === 'booking') {
      const booking = await one('bookings','stripe_payment_intent_id',intent.id);
      if (booking && booking.amount_minor === intent.amount_received && booking.currency === intent.currency)
        checked(await admin.from('bookings').update({payment_status:'Paid'}).eq('id',booking.id));
    }
  }
  return reply({received:true});
}
const serviceView = (s: any) => ({ ...s.data, id:s.id, isActive:s.is_active });
const bookingView = (b: any) => ({ ...b.data, id:b.id, serviceId:b.service_id, amount:b.amount_minor/100, bookingStatus:b.booking_status, paymentStatus:b.payment_status });
const reviewView = (r: any) => ({id:r.id,customerName:r.customer_name,rating:r.rating,comment:r.comment,createdAt:r.created_at});

Deno.serve(async req => {
  if (req.method === 'OPTIONS') return new Response('ok',{headers:cors});
  try {
    const parsed = new URL(req.url);
    const path = parsed.pathname.replace(/^.*\/upyogi-api\/?/, '/').replace(/\/$/, '') || '/';
    const method = req.method;
    if (path === '/health') return reply({status:'ok',currency:'sar',publishableKey:Deno.env.get('STRIPE_PUBLISHABLE_KEY') || null,paymentsConfigured:!!Deno.env.get('STRIPE_SECRET_KEY') && !!Deno.env.get('STRIPE_WEBHOOK_SECRET') && !!Deno.env.get('STRIPE_PUBLISHABLE_KEY')});
    if (path === '/stripe-webhook' && method === 'POST') return await webhook(req);
    if (path === '/api/Auth/register' && method === 'POST') {
      const b = await input(req);
      if (!text(b.fullName,100) || !text(b.email,254).includes('@') || typeof b.password !== 'string' || b.password.length < 8 || !['Customer','Provider'].includes(b.role)) fail(400, 'أدخل اسمًا وبريدًا صحيحين وكلمة مرور من 8 أحرف على الأقل.');
      const {data,error} = await authClient().auth.signUp({email:text(b.email,254),password:b.password,options:{data:{fullName:text(b.fullName,100),role:b.role}}});
      if (error) fail(400, 'تعذر إنشاء الحساب. تحقق من البيانات أو حاول لاحقًا.');
      return reply({success:true,requiresEmailConfirmation:!data.session,message:'تم استلام طلب التسجيل. تحقق من بريدك لتأكيد الحساب.'});
    }
    if ((path === '/api/Auth/login' || path === '/api/Auth/refresh') && method === 'POST') {
      const b = await input(req); const client = authClient();
      const {data,error} = path.endsWith('/refresh') ? await client.auth.refreshSession({refresh_token:b.refreshToken}) : await client.auth.signInWithPassword({email:text(b.email,254),password:b.password || ''});
      if (error || !data.session || !data.user) fail(401, 'بيانات الدخول غير صحيحة أو البريد لم يُؤكّد بعد.');
      const p = await one('app_profiles','id',data.user.id);
      return reply({token:data.session.access_token,refreshToken:data.session.refresh_token,expiresAt:data.session.expires_at,user:{id:data.user.id,role:p.role,fullName:p.full_name,profileImageUrl:p.profile_image_url,email:data.user.email}});
    }
    if (path === '/api/Service' && method === 'GET') {
      let rows = checked(await admin.from('services').select('*').eq('is_active',true).order('created_at',{ascending:false}).limit(200));
      const q = parsed.searchParams;
      rows = rows.filter((s:any) => (!q.get('search') || `${s.data.title} ${s.data.shortDescription}`.toLowerCase().includes(q.get('search')!.toLowerCase())) && (!q.get('city') || s.data.city === q.get('city')) && (!q.get('category') || s.data.category === q.get('category')) && (!q.get('minPrice') || s.data.startingPrice >= Number(q.get('minPrice'))) && (!q.get('maxPrice') || s.data.startingPrice <= Number(q.get('maxPrice'))));
      return reply(rows.map(serviceView));
    }
    if (/^\/api\/Service\/\d+$/.test(path) && method === 'GET') {
      const s = await one('services','id',Number(path.split('/')[3]));
      if (!s || !s.is_active) fail(404, 'الخدمة غير متاحة.');
      return reply(serviceView(s));
    }
    if (/^\/api\/Review\/service\/\d+$/.test(path) && method === 'GET')
      return reply(checked(await admin.from('reviews').select('*').eq('service_id',Number(path.split('/')[4])).limit(100)).map(reviewView));
    const token = (req.headers.get('authorization') || '').replace(/^Bearer /i,'');
    const {data:{user},error} = await authClient().auth.getUser(token);
    if (error || !user) fail(401, 'يرجى تسجيل الدخول.');
    const profile = await one('app_profiles','id',user.id);
    const isProvider = profile?.role === 'Provider';
    const requireProvider = () => { if (!isProvider) fail(403, 'هذا الإجراء لمقدم الخدمة.'); };
    if (path === '/api/Auth/logout' && method === 'POST') {
      const r = await fetch(`${url}/auth/v1/logout?scope=global`, {method:'POST',headers:{apikey:anon,Authorization:`Bearer ${token}`}});
      if (!r.ok) fail(502,'تعذر إنهاء الجلسة على الخادم.'); return reply({success:true});
    }
    if (path === '/api/Auth/password' && method === 'PUT') {
      const b=await input(req); if (typeof b.password!=='string' || b.password.length<8) fail(400,'استخدم كلمة مرور من 8 أحرف على الأقل.');
      const r=await fetch(`${url}/auth/v1/user`,{method:'PUT',headers:{apikey:anon,Authorization:`Bearer ${token}`,'Content-Type':'application/json'},body:JSON.stringify({password:b.password})});
      if (!r.ok) fail(400,'تعذر تغيير كلمة المرور. أعد تسجيل الدخول وحاول مجددًا.'); return reply({success:true});
    }
    if (/^\/api\/Location\/\d+$/.test(path) && ['GET','PUT'].includes(method)) {
      const id=Number(path.split('/')[3]); const b=await one('bookings','id',id);
      if (!b || ![b.customer_id,b.provider_id].includes(user.id)) fail(404,'الحجز غير موجود.');
      if (b.booking_status!=='Accepted') fail(409,'التتبع متاح أثناء الحجز المقبول فقط.');
      if (method==='GET') {
        const loc=await one('booking_locations','booking_id',id); return reply(loc ? {latitude:loc.latitude,longitude:loc.longitude,updatedAt:loc.updated_at}:null);
      }
      if (b.provider_id!==user.id) fail(403,'مقدم الخدمة فقط يستطيع إرسال الموقع.');
      const loc=await input(req);
      if (!Number.isFinite(loc.latitude) || !Number.isFinite(loc.longitude) || Math.abs(loc.latitude)>90 || Math.abs(loc.longitude)>180) fail(400,'موقع غير صحيح.');
      checked(await admin.from('booking_locations').upsert({booking_id:id,latitude:loc.latitude,longitude:loc.longitude,updated_at:new Date().toISOString()})); return reply({success:true});
    }
    if (path === '/api/Auth/me') return reply({id:user.id,email:user.email,role:profile.role,fullName:profile.full_name,profileImageUrl:profile.profile_image_url});
    if (path === '/api/Auth/edit-profile' && method === 'PUT') {
      const b = await input(req); const updates:Record<string,unknown> = {};
      if (text(b.fullName,100)) updates.full_name = text(b.fullName,100);
      const uploaded = await image(b.profileImage,user.id); if (uploaded) updates.profile_image_url = uploaded;
      const updated=checked(await admin.from('app_profiles').update(updates).eq('id',user.id).select().single()); return reply({fullName:updated.full_name,profileImageUrl:updated.profile_image_url});
    }
    if (path === '/api/Provider/profile/me' && method === 'GET') {
      const p = await one('provider_profiles','owner_id',user.id); if (!p) fail(404,'أكمل ملف مقدم الخدمة.'); return reply(p.data);
    }
    if (path === '/api/Provider/profile' && method === 'POST') {
      requireProvider(); const b = await input(req);
      const data:Record<string,any> = {};
      for (const field of ['bio','serviceCategory','workingDays','workingHoursStart','workingHoursEnd','address']) data[field]=text(b[field]);
      for (const field of ['experienceYears','priceFrom','priceTo','serviceRadiusKm','latitude','longitude']) { const n=Number(b[field]); if (Number.isFinite(n)) data[field]=n; }
      const uploaded = await image(b.profileImage,user.id); if (uploaded) data.profileImageUrl=uploaded;
      const kyc = await image(b.kycDocument,user.id,true); if (kyc) data.kycDocumentPath=kyc;
      const old = await one('provider_profiles','owner_id',user.id);
      checked(await admin.from('provider_profiles').upsert({owner_id:user.id,data:{...old?.data,...data},updated_at:new Date().toISOString()})); return reply(data);
    }
    if (path === '/api/Service/my-services' && method === 'GET') return reply(checked(await admin.from('services').select('*').eq('owner_id',user.id)).map(serviceView));
    if (path === '/api/Service' && method === 'POST' || /^\/api\/Service\/\d+$/.test(path) && ['PUT','DELETE'].includes(method) || /^\/api\/Service\/\d+\/toggle-status$/.test(path) && method === 'PUT') {
      requireProvider(); const id=Number(path.split('/')[3]); const old=id ? await one('services','id',id) : null;
      if (id && (!old || old.owner_id !== user.id)) fail(404,'الخدمة غير موجودة.');
      if (method === 'DELETE') { checked(await admin.from('services').update({is_active:false}).eq('id',id)); return reply({success:true}); }
      if (path.endsWith('toggle-status')) { checked(await admin.from('services').update({is_active:!old.is_active}).eq('id',id)); return reply({success:true}); }
      const b=await input(req); const d={...old?.data};
      for (const field of ['title','category','subcategory','shortDescription','detailedDescription','priceType','state','city','fullAddress','pincode','workingDays','startTime','endTime','providerName','phoneNumber','email','certifications','skills','serviceDuration']) if (b[field] !== undefined) d[field]=text(b[field]);
      for (const field of ['startingPrice','experienceYears','latitude','longitude']) if (b[field] !== undefined) { const n=Number(b[field]); if (!Number.isFinite(n)) fail(400,'قيمة رقمية غير صحيحة.'); d[field]=n; }
      for (const field of ['emergencyService','homeVisitAvailable','materialsIncluded']) if (b[field] !== undefined) d[field]=String(b[field])==='true';
      if (!d.title || !(d.startingPrice>0) || d.startingPrice>100000) fail(400,'حدد عنوانًا وسعرًا صحيحين.');
      const uploaded=await image(b.serviceImage,user.id); if (uploaded) d.imageUrl=uploaded;
      const s=id ? checked(await admin.from('services').update({data:d}).eq('id',id).select().single()) : checked(await admin.from('services').insert({owner_id:user.id,data:d}).select().single()); return reply(serviceView(s));
    }
    if (path === '/api/Booking' && method === 'POST') {
      const b=await input(req); const s=await one('services','id',Number(b.serviceId));
      if (!s?.is_active || s.owner_id===user.id) fail(400,'الخدمة غير متاحة للحجز.');
      if (!b.appointmentDate || !Number.isFinite(Date.parse(b.appointmentDate)) || Date.parse(b.appointmentDate)<Date.now() || !text(b.appointmentTime) || !text(b.serviceAddress)) fail(400,'حدد موعدًا قادمًا وعنوان الخدمة.');
      const data={appointmentDate:b.appointmentDate,appointmentTime:text(b.appointmentTime,30),serviceAddress:text(b.serviceAddress,500),notes:text(b.notes),customerPhone:text(b.customerPhone,30),customerName:profile.full_name,providerName:s.data.providerName,serviceTitle:s.data.title,latitude:b.latitude,longitude:b.longitude};
      const booking=checked(await admin.from('bookings').insert({service_id:s.id,customer_id:user.id,provider_id:s.owner_id,amount_minor:Math.round(s.data.startingPrice*100),data}).select().single());
      checked(await admin.from('notifications').insert({owner_id:s.owner_id,title:'حجز جديد',message:`طلب خدمة ${s.data.title}`,related_id:booking.id})); return reply(bookingView(booking));
    }
    if (['/api/Booking/customer','/api/Booking/provider'].includes(path) && method==='GET') return reply(checked(await admin.from('bookings').select('*').eq(path.endsWith('provider')?'provider_id':'customer_id',user.id).order('created_at',{ascending:false})).map(bookingView));
    if (/^\/api\/Booking\/\d+\/(accept|reject|complete|cancel)$/.test(path) && method==='PUT') {
      const id=Number(path.split('/')[3]); const action=path.split('/')[4]; const b=await one('bookings','id',id);
      if (!b || (action==='cancel' ? b.customer_id!==user.id : b.provider_id!==user.id)) fail(404,'الحجز غير موجود.');
      const expected=action==='complete'?'Accepted':'Requested';
      if (action==='cancel' && (b.payment_status==='Paid' || b.stripe_payment_intent_id)) fail(409,'تواصل مع الدعم لاسترداد حجز مدفوع.');
      if (b.booking_status!==expected) fail(409,'تغيرت حالة الحجز. أعد تحميل الصفحة.');
      if (action==='complete' && b.payment_status!=='Paid') fail(409,'لم يُؤكّد الدفع.');
      const next=({accept:'Accepted',reject:'Rejected',complete:'Completed',cancel:'Cancelled'} as Record<string,string>)[action];
      const updated=checked(await admin.from('bookings').update({booking_status:next}).eq('id',id).eq('booking_status',expected).select()); if (!updated.length) fail(409,'تغيرت حالة الحجز.'); return reply({success:true});
    }
    if (path==='/api/Wallet' && method==='GET') {
      const wallet=checked(await admin.from('wallet_accounts').upsert({owner_id:user.id,currency:'sar'},{onConflict:'owner_id,currency',ignoreDuplicates:true}));
      const account=checked(await admin.from('wallet_accounts').select('*').eq('owner_id',user.id).eq('currency','sar').single());
      const entries=checked(await admin.from('wallet_topups').select('id,amount_minor,currency,status,created_at,stripe_payment_intent_id').eq('owner_id',user.id).order('created_at',{ascending:false}).limit(50));
      return reply({balanceMinor:account.balance_minor,currency:'sar',topups:entries,publishableKey:Deno.env.get('STRIPE_PUBLISHABLE_KEY') || null,paymentsConfigured:!!Deno.env.get('STRIPE_SECRET_KEY') && !!Deno.env.get('STRIPE_WEBHOOK_SECRET') && !!Deno.env.get('STRIPE_PUBLISHABLE_KEY')});
    }
    if (path==='/api/Wallet/topup' && method==='POST') {
      const b=await input(req);
      if (!Number.isSafeInteger(b.amountMinor) || b.amountMinor<1000 || b.amountMinor>1000000 || !/^[0-9a-f-]{36}$/.test(b.requestId||'')) fail(400,'أدخل مبلغًا بين 10 و10,000 ريال.');
      if (!Deno.env.get('STRIPE_WEBHOOK_SECRET')) fail(503,'بوابة الدفع لم تكتمل بعد.');
      checked(await admin.from('wallet_accounts').upsert({owner_id:user.id,currency:'sar'},{onConflict:'owner_id,currency',ignoreDuplicates:true}));
      const w=checked(await admin.from('wallet_accounts').select('*').eq('owner_id',user.id).eq('currency','sar').single());
      const intent=await stripe('payment_intents',{amount:String(b.amountMinor),currency:'sar','automatic_payment_methods[enabled]':'true','metadata[purpose]':'wallet_topup','metadata[owner_id]':user.id},`topup-${user.id}-${b.requestId}`);
      checked(await admin.from('wallet_topups').upsert({wallet_id:w.id,owner_id:user.id,currency:'sar',amount_minor:b.amountMinor,stripe_payment_intent_id:intent.id},{onConflict:'stripe_payment_intent_id',ignoreDuplicates:true}));
      return reply({clientSecret:intent.client_secret,publishableKey:Deno.env.get('STRIPE_PUBLISHABLE_KEY'),paymentIntentId:intent.id});
    }
    if (/^\/api\/Payment\/(create-payment-intent|confirm)\/\d+$/.test(path) && method==='POST') {
      const id=Number(path.split('/')[4]); const b=await one('bookings','id',id);
      if (!b || b.customer_id!==user.id) fail(404,'الحجز غير موجود.');
      if (path.includes('/confirm/')) {
        if (!b.stripe_payment_intent_id) fail(409,'لم يبدأ الدفع.');
        const intent=await stripe(`payment_intents/${b.stripe_payment_intent_id}`);
        if (intent.status!=='succeeded' || intent.amount_received!==b.amount_minor || intent.currency!==b.currency) fail(409,'لم يُؤكّد الدفع بعد.');
        checked(await admin.from('bookings').update({payment_status:'Paid'}).eq('id',id)); return reply({success:true});
      }
      if (!['Requested','Accepted'].includes(b.booking_status) || b.payment_status==='Paid') fail(409,'الحجز غير قابل للدفع.');
      const intent=b.stripe_payment_intent_id ? await stripe(`payment_intents/${b.stripe_payment_intent_id}`) : await stripe('payment_intents',{amount:String(b.amount_minor),currency:b.currency,'automatic_payment_methods[enabled]':'true','metadata[purpose]':'booking'},`booking-${id}`);
      checked(await admin.from('bookings').update({stripe_payment_intent_id:intent.id}).eq('id',id)); return reply({clientSecret:intent.client_secret});
    }
    if (path==='/api/Review' && method==='POST') {
      const b=await input(req); const booking=await one('bookings','id',Number(b.bookingId));
      if (!booking || booking.customer_id!==user.id || booking.booking_status!=='Completed' || !Number.isInteger(b.rating) || b.rating<1 || b.rating>5) fail(400,'التقييم متاح للحجوزات المكتملة فقط.');
      const result=await admin.from('reviews').insert({booking_id:booking.id,service_id:booking.service_id,customer_id:user.id,customer_name:profile.full_name,rating:b.rating,comment:text(b.comment)});
      if (result.error?.code==='23505') fail(409,'تم تقييم هذا الحجز.'); checked(result); return reply({success:true});
    }
    if (/^\/api\/Review\/booking\/\d+$/.test(path) && method==='GET') { const r=await one('reviews','booking_id',Number(path.split('/')[4])); if (!r || r.customer_id!==user.id) fail(404,'لم يُقيّم الحجز.'); return reply(reviewView(r)); }
    if (path.startsWith('/api/Notification')) {
      if (path==='/api/Notification/unread-count') { const r=await admin.from('notifications').select('id',{count:'exact',head:true}).eq('owner_id',user.id).eq('is_read',false); checked(r); return reply({count:r.count}); }
      if (method==='PUT' && (path.endsWith('/mark-all-read') || /^\/api\/Notification\/\d+\/mark-read$/.test(path))) { let q=admin.from('notifications').update({is_read:true}).eq('owner_id',user.id); if (!path.endsWith('mark-all-read')) q=q.eq('id',Number(path.split('/')[3])); checked(await q); return reply({success:true}); }
      if (path==='/api/Notification' && method==='GET') return reply(checked(await admin.from('notifications').select('*').eq('owner_id',user.id).order('created_at',{ascending:false}).limit(100)).map((n:any)=>({id:n.id,title:n.title,message:n.message,type:n.type,relatedId:n.related_id,isRead:n.is_read,createdAt:n.created_at})));
    }
    return fail(404,'المسار غير موجود.');
  } catch (e) {
    if (e instanceof ApiError) return reply({message:e.message},e.status);
    console.error('Unhandled API error', e instanceof Error ? e.name : 'unknown');
    return reply({message:'تعذر إتمام الطلب. حاول مجددًا.'},500);
  }
});
