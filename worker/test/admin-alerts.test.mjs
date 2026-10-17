import {test} from 'node:test';
import assert from 'node:assert/strict';
import {fixture} from './fixture.mjs';
import {AdminAlerts} from '../admin-alerts.mjs';

test('standalone admin alerts persist reads by administrator and update after an order changes',async()=>{
 const {repo,sql}=await fixture();try{
  const alerts=new AdminAlerts(repo.db);
  const id=await repo.createOrder('c',{requestId:'alert_order_001',workerUid:'w',services:['builder'],details:'Repair work',location:{latitude:30.04,longitude:31.2,label:'Dokki',fromGps:true}});
  await repo.withdraw('c',{requestId:'alert_withdrawal_001',amount:1000,method:'instapay',destination:'customer@instapay'});
  let state=await alerts.list('standalone_admin');
  assert.equal(state.unreadCount,2);assert.equal(state.counts.Orders,1);assert.equal(state.counts.Withdrawals,1);
  await alerts.read('standalone_admin',{section:'Orders'});
  assert.equal((await alerts.list('standalone_admin')).unreadCount,1);
  assert.equal((await alerts.list('another_admin')).unreadCount,2);
  await repo.decide('w',id,'accept');
  state=await alerts.list('standalone_admin');assert.equal(state.counts.Orders,1);
  await alerts.read('standalone_admin',{id:state.items.find(n=>n.section==='Withdrawals').id});
  assert.equal((await alerts.list('standalone_admin')).counts.Withdrawals,0);
  await assert.rejects(alerts.read('standalone_admin',{section:'arbitrary SQL'}),/INVALID_REQUEST/);
  assert.equal(await repo.account('standalone_admin'),undefined);
 }finally{sql.close();}
});

test('fee policy migration preserves old quotes while new withdrawals use two and eight percent',async()=>{
 const {repo,sql}=await fixture();try{
  await repo.withdraw('c',{requestId:'policy_customer_001',amount:1000,method:'instapay',destination:'customer@instapay'});
  sql.prepare("UPDATE marketplace_accounts SET balance=10000 WHERE uid='w'").run();
  await repo.withdraw('w',{requestId:'policy_worker_001',amount:1000,method:'instapay',destination:'worker@instapay'});
  const customer=(await repo.snapshot('c')).withdrawals[0],worker=(await repo.snapshot('w')).withdrawals[0];
  assert.equal(customer.fee_bps,200);assert.equal(customer.fee,20);assert.equal(worker.fee_bps,800);assert.equal(worker.fee,80);
  sql.prepare("UPDATE wallet_withdrawals SET fee_bps=500,fee=50,net=950 WHERE uid='w'").run();
  await repo.withdraw('w',{requestId:'policy_worker_001',amount:1000,method:'instapay',destination:'worker@instapay'});
  assert.equal((await repo.snapshot('w')).withdrawals[0].fee,50);
  await repo.deposit('c',{requestId:'policy_deposit_001',amount:10000,method:'visa'});
  const platform=(await repo.finance.dashboard()).platform;assert.equal(platform.totalBalance,200);assert.equal(platform.totalMonthlyEarnings,200);
 }finally{sql.close();}
});
