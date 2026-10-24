export function validPoint(lat, lng) {
  return typeof lat==='number' && typeof lng==='number' && Number.isFinite(lat) && Number.isFinite(lng) && Math.abs(lat)<=90 && Math.abs(lng)<=180;
}
export function validEmail(value) {
  if (typeof value!=='string' || value.length>254 || !/^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/.test(value)) return false;
  const domain=value.split('@')[1].toLowerCase();
  return !/(^|\.)(test|invalid|localhost|example)$/.test(domain) && !['example.com','example.org','example.net'].includes(domain);
}
export function searchParams(q) {
  const num=(key,fallback=null)=>{ if(!q.has(key))return fallback;const raw=q.get(key);if(!raw?.trim() || !Number.isFinite(Number(raw)))throw Error('invalid_filters');return Number(raw); };
  const lat=num('latitude'),lng=num('longitude'),radius=num('radiusKm',25);
  if ((lat!==null || lng!==null) && !validPoint(lat,lng)) throw Error('invalid_location');
  if (radius<1 || radius>200) throw Error('invalid_radius');
  const sort=q.get('sortBy') || (lat!==null?'nearest':'newest');
  if(!['nearest','newest','price_asc','price_desc','rating'].includes(sort) || (sort==='nearest' && lat===null)) throw Error('invalid_sort');
  const min=num('minPrice'),max=num('maxPrice');
  if ((min!==null && min<0)||(max!==null && max<0)||(min!==null && max!==null && min>max)) throw Error('invalid_price');
  const demo=q.get('includeDemo');if(demo!==null && !['true','false'].includes(demo))throw Error('invalid_filters');
  return {p_lat:lat,p_lng:lng,p_radius_km:radius,p_search:(q.get('search')||'').trim().slice(0,100),p_category:(q.get('category')||'').trim().slice(0,80),p_city:(q.get('city')||'').trim().slice(0,100),p_min_price:min,p_max_price:max,p_sort:sort,p_include_demo:demo===null?lat===null:demo==='true'};
}
export function confirmationMessage(user,payload,id) {
  if(!validEmail(user?.email))throw Error('recipient_invalid');
  if(!user.email_confirmed_at)throw Error('recipient_unverified');
  const line=v=>String(v||'').replace(/[\r\n]/g,' ').slice(0,200);
  return {to:[user.email],subject:`صلح | تأكيد الحجز #${id}`,text:[`تم تأكيد حجزك رقم ${id} — Sulh booking confirmed`, `الخدمة / Service: ${line(payload.serviceTitle)}`,`الفني / Technician: ${line(payload.providerName)}`,`الموعد / Appointment: ${line(payload.appointmentDate)} ${line(payload.appointmentTime)}`,'الدفع مباشرة مع الفني بعد انتهاء العمل، خارج التطبيق.','Pay the technician directly after completion. No payment is collected in the app.'].join('\n'),tags:[{name:'kind',value:'booking_confirmation'},{name:'booking_id',value:String(id)}]};
}
export async function verifyEmailWebhook(raw,headers,secret,now=Date.now()) {
  const id=headers.get('svix-id'),ts=headers.get('svix-timestamp'),signature=headers.get('svix-signature');
  if(!secret?.startsWith('whsec_')||!id||!/^\d+$/.test(ts||'')||!signature||Math.abs(now/1000-Number(ts))>300)throw Error('invalid_signature');
  const bytes=v=>Uint8Array.from(atob(v),c=>c.charCodeAt(0));
  const key=await crypto.subtle.importKey('raw',bytes(secret.slice(6)),{name:'HMAC',hash:'SHA-256'},false,['verify']);
  const data=new TextEncoder().encode(`${id}.${ts}.${raw}`);
  for(const candidate of signature.split(' ')) {
    const [version,value]=candidate.split(',');
    if(version==='v1' && value) {try{if(await crypto.subtle.verify('HMAC',key,bytes(value),data))return JSON.parse(raw);}catch{ /* Try any other signature. */ }}
  }
  throw Error('invalid_signature');
}
