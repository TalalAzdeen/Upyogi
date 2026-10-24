import test from 'node:test';
import assert from 'node:assert/strict';
import {webcrypto} from 'node:crypto';
import {validPoint,validEmail,searchParams,confirmationMessage,verifyEmailWebhook} from './domain.mjs';
if(!globalThis.crypto)globalThis.crypto=webcrypto;
test('zero coordinates are valid and a half location never becomes zero',()=>{
 assert.equal(validPoint(0,0),true);assert.equal(validPoint(null,0),false);assert.equal(validPoint(91,0),false);
 assert.deepEqual(searchParams(new URLSearchParams('latitude=0&longitude=0')).p_lat,0);
 for(const q of ['latitude=0','latitude=&longitude=0','latitude=NaN&longitude=0','latitude=91&longitude=0','latitude=0&longitude=181']) assert.throws(()=>searchParams(new URLSearchParams(q)));
});
test('nearest uses real listings by default and validates radius, price and sort',()=>{
 const q=searchParams(new URLSearchParams('latitude=24.7&longitude=46.6&category=Plumber&radiusKm=10&minPrice=20&maxPrice=100'));
 assert.equal(q.p_include_demo,false);assert.equal(q.p_sort,'nearest');assert.equal(q.p_category,'Plumber');assert.equal(q.p_radius_km,10);
 assert.equal(searchParams(new URLSearchParams('latitude=0&longitude=0&includeDemo=true')).p_include_demo,true);
 for(const q of ['radiusKm=0','radiusKm=201','minPrice=100&maxPrice=10','minPrice=-1','sortBy=nearest','sortBy=anything','includeDemo=yes'])assert.throws(()=>searchParams(new URLSearchParams(q)));
});
test('confirmation recipients come only from the confirmed auth user',()=>{
 const message=confirmationMessage({email:'client@real-domain.com',email_confirmed_at:'2026-10-24'}, {email:'attacker@evil.com',serviceTitle:'Repair',latitude:24,serviceAddress:'private street'},42);
 assert.deepEqual(message.to,['client@real-domain.com']);assert.equal(message.text.includes('private street'),false);assert.equal(message.text.includes('attacker'),false);
 assert.throws(()=>confirmationMessage({email:'provider@upyogi.test',email_confirmed_at:'yes'},{},42),/recipient_invalid/);
 assert.throws(()=>confirmationMessage({email:'client@real-domain.com'},{},42),/recipient_unverified/);
 for(const address of ['a@x.invalid','a@localhost','a@example.com','a@x.test','a\r\nb@domain.com'])assert.equal(validEmail(address),false);
});
test('only a valid, fresh signed callback can claim delivery',async()=>{
 const secret='whsec_'+btoa('a-test-only-32-byte-signing-secret');const now=Date.now(),ts=String(Math.floor(now/1000)),id='msg_test';
 const raw=JSON.stringify({type:'email.delivered',data:{email_id:'email_test'}});
 const key=await crypto.subtle.importKey('raw',new TextEncoder().encode('a-test-only-32-byte-signing-secret'),{name:'HMAC',hash:'SHA-256'},false,['sign']);
 const sig=await crypto.subtle.sign('HMAC',key,new TextEncoder().encode(`${id}.${ts}.${raw}`));
 const signature=btoa(String.fromCharCode(...new Uint8Array(sig)));const headers=new Headers({'svix-id':id,'svix-timestamp':ts,'svix-signature':'v1,'+signature});
 assert.equal((await verifyEmailWebhook(raw,headers,secret,now)).type,'email.delivered');
 await assert.rejects(()=>verifyEmailWebhook(raw+' ',headers,secret,now));await assert.rejects(()=>verifyEmailWebhook(raw,headers,secret,now+301000));
});
