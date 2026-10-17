import {DatabaseSync} from 'node:sqlite';
import fs from 'node:fs';
import {MarketplaceRepository,createMarketplaceHandler} from '../marketplace.mjs';
export function setup(file=':memory:'){
 const sql=new DatabaseSync(file);sql.exec('PRAGMA foreign_keys=ON');
 if(!sql.prepare("SELECT name FROM sqlite_master WHERE name='phone_login_aliases'").get())sql.exec(fs.readFileSync(new URL('../../drizzle/0000_phone_login.sql',import.meta.url),'utf8'));
 if(!sql.prepare("SELECT name FROM sqlite_master WHERE name='marketplace_accounts'").get())sql.exec(fs.readFileSync(new URL('../../drizzle/0001_marketplace.sql',import.meta.url),'utf8'));
 if(!sql.prepare("SELECT name FROM sqlite_master WHERE name='worker_applications'").get())sql.exec(fs.readFileSync(new URL('../../drizzle/0002_customer_settings.sql',import.meta.url),'utf8'));
 if(!sql.prepare("SELECT name FROM sqlite_master WHERE name='marketplace_withdrawals'").get())sql.exec(fs.readFileSync(new URL('../../drizzle/0003_account_wallet.sql',import.meta.url),'utf8'));
 if(!sql.prepare("PRAGMA table_info(marketplace_accounts)").all().some(c=>c.name==='available'))sql.exec(fs.readFileSync(new URL('../../drizzle/0004_worker_availability.sql',import.meta.url),'utf8'));
 if(!sql.prepare("SELECT name FROM sqlite_master WHERE name='order_messages'").get())sql.exec(fs.readFileSync(new URL('../../drizzle/0005_service_experience.sql',import.meta.url),'utf8'));
 if(!sql.prepare("SELECT name FROM sqlite_master WHERE name='security_rate_limits'").get())sql.exec(fs.readFileSync(new URL('../../drizzle/0006_security.sql',import.meta.url),'utf8'));
 if(!sql.prepare("SELECT name FROM sqlite_master WHERE name='platform_fee_ledger'").get())sql.exec(fs.readFileSync(new URL('../../drizzle/0007_admin_finance.sql',import.meta.url),'utf8'));
 if(!sql.prepare("SELECT sql FROM sqlite_master WHERE name='wallet_withdrawals'").get().sql.includes('800'))sql.exec(fs.readFileSync(new URL('../../drizzle/0008_fee_policy.sql',import.meta.url),'utf8'));
 const db={prepare(statement){return {bind(...args){return {async first(){return sql.prepare(statement).get(...args);},async all(){return {results:sql.prepare(statement).all(...args)};},async run(){const r=sql.prepare(statement).run(...args);return {meta:{changes:r.changes}};}};}};}};
 let tail=Promise.resolve();db.batch=(statements)=>{const next=tail.then(async()=>{sql.exec('BEGIN');try{const results=[];for(const statement of statements)results.push(await statement.run());sql.exec('COMMIT');return results;}catch(e){sql.exec('ROLLBACK');throw e;}});tail=next.catch(()=>{});return next;};
 return {sql,repo:new MarketplaceRepository(db)};
}
export async function fixture(){const r=setup();for(const [uid,role] of [['c','customer'],['w','worker'],['other','worker']])await r.repo.register({localId:uid,createdAt:'1792000000000',emailVerified:true,displayName:uid+' name',phoneNumber:'+201012345678'},{role,name:uid+' name',legacyBalance:role==='customer'?20000:0});await r.repo.update('w',{skills:['builder','plumber']});return r;}
export const order=(id='request_001')=>({requestId:id,workerUid:'w',services:['builder'],details:'repair',location:{latitude:30.04,longitude:31.2,label:'Dokki',fromGps:true}});
