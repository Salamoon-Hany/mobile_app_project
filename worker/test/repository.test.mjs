import {test} from 'node:test';
import assert from 'node:assert/strict';
import {DatabaseSync} from 'node:sqlite';
import fs from 'node:fs';
import {PhoneRepository} from '../phone-auth.mjs';

function repository() {
  const sqlite=new DatabaseSync(':memory:');
  sqlite.exec(fs.readFileSync(new URL('../../drizzle/0000_phone_login.sql',import.meta.url),'utf8'));
  sqlite.exec(fs.readFileSync(new URL('../../drizzle/0001_marketplace.sql',import.meta.url),'utf8'));sqlite.exec(fs.readFileSync(new URL('../../drizzle/0002_customer_settings.sql',import.meta.url),'utf8'));sqlite.exec(fs.readFileSync(new URL('../../drizzle/0003_account_wallet.sql',import.meta.url),'utf8'));
  const db={prepare(sql){return {bind(...args){return {async first(){return sqlite.prepare(sql).get(...args);},async run(){return sqlite.prepare(sql).run(...args);}};}};},async batch(statements){sqlite.exec('BEGIN');try{for(const statement of statements)await statement.run();sqlite.exec('COMMIT');}catch(error){sqlite.exec('ROLLBACK');throw error;}}};
  return {repo:new PhoneRepository(db),sqlite};
}
test('migration and rate-limit SQL apply and reset the next minute',async()=>{
  const {repo,sqlite}=repository();
  assert.equal(await repo.limit('ip:test',2,60000),true);
  assert.equal(await repo.limit('ip:test',2,60001),true);
  assert.equal(await repo.limit('ip:test',2,60002),false);
  assert.equal(await repo.limit('ip:test',2,120000),true);
  sqlite.close();
});
test('phone changes replace the alias while keeping the same UID',async()=>{
  const {repo,sqlite}=repository();
  await repo.save({localId:'uid-a',phoneNumber:'+201012345678',email:'a@example.com'});
  await repo.save({localId:'uid-a',phoneNumber:'+201099999999',email:'a@example.com'});
  assert.equal(await repo.find('+201012345678'),undefined);
  assert.equal((await repo.find('+201099999999')).uid,'uid-a');
  sqlite.close();
});
