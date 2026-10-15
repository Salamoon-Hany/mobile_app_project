import fs from 'node:fs';
import path from 'node:path';
const root=process.cwd();
const web=path.join(root,'build/web');
if(!fs.existsSync(path.join(web,'main.dart.js')))throw Error('Build Flutter Web before packaging');
// Output is derived; remove stale files before exposing a new asset bundle.
fs.rmSync('dist',{recursive:true,force:true});
fs.mkdirSync('dist/server',{recursive:true});
fs.mkdirSync('dist/.openai',{recursive:true});
fs.cpSync(web,'dist/client',{recursive:true});
fs.copyFileSync('worker/marketplace.mjs','dist/server/marketplace.mjs');
fs.copyFileSync('worker/service-experience.mjs','dist/server/service-experience.mjs');
fs.copyFileSync('worker/index.js','dist/server/index.js');
fs.copyFileSync('worker/phone-auth.mjs','dist/server/phone-auth.mjs');
for(const name of ['security.mjs','photo-validation.mjs'])fs.copyFileSync('worker/'+name,'dist/server/'+name);
fs.copyFileSync('.openai/hosting.json','dist/.openai/hosting.json');
fs.writeFileSync('dist/server/wrangler.json',JSON.stringify({name:'sanad',main:'index.js',compatibility_date:'2026-05-15',assets:{directory:'../client',binding:'ASSETS',not_found_handling:'single-page-application',run_worker_first:true},d1_databases:[{binding:'DB',database_name:'site-creator-d1',database_id:'00000000-0000-4000-8000-000000000000'}]},null,2));
console.log('Packaged Flutter client and phone-login Worker');
