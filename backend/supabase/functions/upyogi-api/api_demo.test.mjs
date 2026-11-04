// Exercise the real request handler without network or privileged credentials.
// PostgreSQL transition behavior is covered by demo_scenario_assertions.sql.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';

let handler;
let records;
let calls;
let rpcResult;
class Query {
  constructor(table) { this.table=table; this.filters={}; }
  select() { return this; }
  eq(key,value) { this.filters[key]=value; return this; }
  insert(value) { this.value=value; return this; }
  async maybeSingle() { return {data:records[this.table]?.find(r=>Object.entries(this.filters).every(([k,v])=>r[k]===v))??null,error:null}; }
  async single() { return {data:{id:43,...this.value},error:null}; }
  then(resolve,reject) { return Promise.resolve({data:this.value,error:null}).then(resolve,reject); }
}
const client={
  auth:{getUser:async token=>({data:{user:token==='test-token'?{id:'customer'}:null},error:token==='test-token'?null:{message:'unauthorized'}})},
  from:table=>new Query(table),
  rpc:async(name,args)=>{calls.push({name,args});return rpcResult;},
};
globalThis.__sulhApiTestClient=client;
globalThis.Deno={env:{get:()=>''},serve:fn=>{handler=fn;}};
let source=readFileSync(new URL('./index.ts',import.meta.url),'utf8');
source=source.replace("import { createClient } from 'npm:@supabase/supabase-js@2.95.0';",'const createClient=()=>globalThis.__sulhApiTestClient;');
for(const file of ['domain.mjs','demo.mjs']) source=source.replace(`'./${file}'`,JSON.stringify(new URL(file,import.meta.url).href));
await import(`data:text/javascript;base64,${Buffer.from(stripTypeScriptTypes(source,{mode:'transform'})).toString('base64')}`);

function reset() {
  records={app_profiles:[{id:'customer',role:'Customer',full_name:'Test customer'}],
    services:[{id:7,owner_id:'provider',is_active:true,is_demo:true,data:{demoSeed:'sulh-demo-v2',startingPrice:120,title:'Demo',providerName:'Demo technician'}}],
    bookings:[{id:42,customer_id:'customer',service_id:7,amount_minor:12000,payment_status:'External',booking_status:'Completed',data:{demoScenario:true}}]};
  calls=[]; rpcResult={data:[records.bookings[0]],error:null};
}
async function request(path,{method='GET',body,token='test-token'}={}) {
  return handler(new Request(`https://server.test/upyogi-api/api/${path}`,{method,
    headers:{authorization:`Bearer ${token}`,'Content-Type':'application/json'},
    body:body===undefined?undefined:JSON.stringify(body)}));
}

test('demo routes reject unauthenticated users and another customer booking',async()=>{
  reset();
  assert.equal((await request('Demo/catalog',{method:'POST',body:{},token:'invalid'})).status,401);
  records.bookings[0].customer_id='somebody-else';
  assert.equal((await request('Demo/bookings/42')).status,404);
  assert.equal(calls.length,0);
});
test('catalog uses bounded seed and demo checkout forwards the authenticated identity',async()=>{
  reset(); rpcResult={data:0,error:null};
  const seed=await request('Demo/catalog',{method:'POST',body:{}});
  assert.equal(seed.status,200); assert.deepEqual(await seed.json(),{created:0,total:24});
  rpcResult={data:[records.bookings[0]],error:null};
  const skip=await request('Demo/bookings/42/advance',{method:'POST',body:{expectedStatus:'Completed',skipPayment:true,p_user_id:'somebody-else'}});
  assert.equal(skip.status,200);
  assert.equal(calls[1].args.p_user_id,'customer');
  assert.equal(calls[1].args.p_skip_payment,true);
  assert.equal((await skip.json()).paymentStatus,'External');
});
test('client flags cannot enable simulation for an unflagged booking or other catalog',async()=>{
  reset(); records.bookings[0].data.demoScenario=false;
  assert.equal((await request('Demo/bookings/42/advance',{method:'POST',body:{demoScenario:true,expectedStatus:'Completed',skipPayment:true}})).status,403);
  records.bookings[0].data.demoScenario=true;records.services[0].data.demoSeed='other';
  assert.equal((await request('Demo/bookings/42')).status,403);
  assert.equal(calls.length,0);
});
test('stale transitions surface a conflict and no real payment endpoint is enabled',async()=>{
  reset(); rpcResult={data:null,error:{code:'40001'}};
  assert.equal((await request('Demo/bookings/42/advance',{method:'POST',body:{expectedStatus:'Accepted',skipPayment:false}})).status,409);
  assert.equal((await request('Payment/confirm/42',{method:'POST'})).status,410);
});
test('new booking demo flag comes from the service, ignoring submitted flags',async()=>{
  reset();
  const body={serviceId:7,appointmentDate:'2099-01-01T10:00:00Z',appointmentTime:'10:00',serviceAddress:'Demo',customerPhone:'0500000000',demoScenario:false};
  const demo=await request('Booking',{method:'POST',body});
  assert.equal(demo.status,200); assert.equal((await demo.json()).demoScenario,true);
  records.services[0].data.demoSeed='other';body.demoScenario=true;
  const ordinary=await request('Booking',{method:'POST',body});
  assert.equal(ordinary.status,200); assert.equal((await ordinary.json()).demoScenario,false);
});
test('demo confirmation email is suppressed without querying or calling an email provider',async()=>{
  reset();
  const response=await request('Booking/42/confirmation-email',{method:'POST',body:{}});
  assert.equal(response.status,200); assert.deepEqual(await response.json(),{status:'demo'});
  assert.equal(calls.length,0);
});
