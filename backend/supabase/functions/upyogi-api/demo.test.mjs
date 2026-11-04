import test from 'node:test';
import assert from 'node:assert/strict';
import * as demo from './demo.mjs';

test('simulation requires server-owned flag and an exact catalog seed', () => {
  assert.equal(demo.isDemoScenario({data:{demoScenario:true}}, {is_demo:true,data:{demoSeed:'sulh-demo-v2'}}),true);
  for(const seed of [undefined,'upyogi-demo-v1','fake']) assert.equal(demo.isDemoScenario({data:{demoScenario:true}},{is_demo:true,data:{demoSeed:seed}}),false);
  assert.equal(demo.isDemoScenario({data:{}},{is_demo:true,data:{demoSeed:'sulh-demo-v2'}}),false);
});
test('only sequential stages and completed unpaid checkout are available', () => {
  assert.equal(demo.nextDemoStatus('Requested',false),'Accepted');
  assert.equal(demo.nextDemoStatus('Accepted',false),'OnTheWay');
  assert.equal(demo.nextDemoStatus('OnTheWay',false),'Completed');
  assert.equal(demo.nextDemoStatus('Completed',true),'Completed');
  for(const status of ['Requested','Accepted','OnTheWay','Cancelled','Rejected']) assert.throws(()=>demo.nextDemoStatus(status,true));
  for(const status of ['Completed','Cancelled','Rejected','Paid','']) assert.throws(()=>demo.nextDemoStatus(status,false));
});
