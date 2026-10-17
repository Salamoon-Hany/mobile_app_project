import {HttpProblem} from './security.mjs';
const sections=['Orders','Withdrawals','Applications','Complaints'];
const events=`WITH events AS (
 SELECT 'admin:order:'||id||':'||status||':'||updated_at AS id,'Orders' AS section,'Order update' AS title,status AS body,updated_at AS at FROM marketplace_orders
 UNION ALL SELECT 'admin:withdrawal:'||uid||':'||request_id||':'||status||':'||updated_at,'Withdrawals','Withdrawal request',status,updated_at FROM wallet_withdrawal_history
 UNION ALL SELECT 'admin:application:'||uid||':'||status||':'||updated_at,'Applications','Worker application',status,updated_at FROM worker_applications
 UNION ALL SELECT 'admin:complaint:'||id||':'||status||':'||updated_at,'Complaints','Support update',status,updated_at FROM order_complaints
)`;
export class AdminAlerts{
 constructor(db){this.db=db;}
 async list(uid){
  const filter=' FROM events e LEFT JOIN notification_reads r ON r.uid=? AND r.id=e.id';
  const items=(await this.db.prepare(events+' SELECT e.*,r.id IS NOT NULL AS read'+filter+' ORDER BY e.at DESC,e.id LIMIT 100').bind(uid).all()).results.map(n=>({...n,read:!!n.read}));
  const rows=(await this.db.prepare(events+' SELECT e.section,COUNT(*) AS count'+filter+' WHERE r.id IS NULL GROUP BY e.section').bind(uid).all()).results;
  const counts=Object.fromEntries(sections.map(s=>[s,0]));for(const row of rows)counts[row.section]=row.count;
  return {items,counts,unreadCount:Object.values(counts).reduce((a,b)=>a+b,0)};
 }
 async read(uid,body){
  if(body.section!==undefined&&!sections.includes(body.section))throw new HttpProblem('INVALID_REQUEST');
  if(body.id!==undefined&&(typeof body.id!=='string'||body.id.length>500))throw new HttpProblem('INVALID_REQUEST');
  if(!body.section&&!body.id)throw new HttpProblem('INVALID_REQUEST');
  const where=body.id?'e.id=?':'e.section=?',value=body.id??body.section;
  await this.db.prepare(events+' INSERT OR IGNORE INTO notification_reads(uid,id) SELECT ?,e.id FROM events e WHERE '+where).bind(uid,value).run();
 }
}
