const errorResponse = (error, status) => Response.json({error}, {status, headers: {'Cache-Control':'no-store'}});
const normalizePhone = input => {
  let phone = String(input ?? '').trim().replace(/[\s()\-]/g, '');
  phone = phone.replace(/[٠-٩۰-۹]/g, d => String('٠١٢٣٤٥٦٧٨٩'.includes(d) ? '٠١٢٣٤٥٦٧٨٩'.indexOf(d) : '۰۱۲۳۴۵۶۷۸۹'.indexOf(d)));
  if (phone.startsWith('00')) phone = '+' + phone.slice(2);
  if (/^01[0125]\d{8}$/.test(phone)) phone = '+20' + phone.slice(1);
  if (!/^\+[1-9]\d{7,14}$/.test(phone)) throw new Error('INVALID_REQUEST');
  return phone;
};
const hash = async value => Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))), x => x.toString(16).padStart(2,'0')).join('');

export class PhoneRepository {
  constructor(db) { this.db = db; }
  async limit(key, maximum, now) {
    const window = Math.floor(now / 60000);
    const result = await this.db.prepare('INSERT INTO phone_login_limits (key, window, count) VALUES (?, ?, 1) ON CONFLICT(key) DO UPDATE SET count = CASE WHEN window = excluded.window THEN count + 1 ELSE 1 END, window = excluded.window RETURNING count').bind(key, window).first();
    return result.count <= maximum;
  }
  async find(phone) { return this.db.prepare('SELECT uid, email FROM phone_login_aliases WHERE phone = ?').bind(phone).first(); }
  async isDeleted(uid){return !!(await this.db.prepare('SELECT deleted_at FROM marketplace_accounts WHERE uid=? AND deleted_at<>0').bind(uid).first());}
  async save(user) {
    await this.db.batch([
      this.db.prepare('INSERT INTO marketplace_assertions(passed) SELECT CASE WHEN NOT EXISTS(SELECT 1 FROM marketplace_accounts WHERE uid=? AND deleted_at<>0) THEN 1 ELSE 0 END').bind(user.localId),
      this.db.prepare('DELETE FROM phone_login_aliases WHERE uid = ? AND phone <> ?').bind(user.localId, user.phoneNumber),
      this.db.prepare('INSERT INTO phone_login_aliases (phone, uid, email) VALUES (?, ?, ?) ON CONFLICT(phone) DO UPDATE SET uid=excluded.uid, email=excluded.email').bind(user.phoneNumber, user.localId, user.email),
      this.db.prepare('DELETE FROM marketplace_assertions').bind(),
    ]);
  }
}

export function createPhoneHandler({repository, apiKey, fetchImpl = fetch, now = Date.now}) {
  async function firebase(action, body) {
    const response = await fetchImpl(`https://identitytoolkit.googleapis.com/v1/accounts:${action}?key=${encodeURIComponent(apiKey)}`, {
      method:'POST', headers:{'Content-Type':'application/json'}, body:JSON.stringify(body), signal:AbortSignal.timeout(15000),
    });
    if (!response.ok) throw new Error(response.status === 429 ? 'RATE_LIMIT' : 'INVALID_CREDENTIALS');
    return response.json();
  }
  async function lookup(idToken) {
    const result = await firebase('lookup', {idToken});
    const user = result.users?.[0];
    if (!user?.localId || !user.email || user.emailVerified !== true || !user.phoneNumber || user.disabled) throw new Error('INVALID_CREDENTIALS');
    if(repository.isDeleted&&await repository.isDeleted(user.localId))throw new Error('INVALID_CREDENTIALS');
    user.phoneNumber = normalizePhone(user.phoneNumber);
    return user;
  }
  return async request => {
    try {
      const url = new URL(request.url);
      if (request.method !== 'POST') return errorResponse('METHOD_NOT_ALLOWED',405);
      if (request.headers.get('Origin') && request.headers.get('Origin') !== url.origin) return errorResponse('FORBIDDEN',403);
      if (!request.headers.get('Content-Type')?.startsWith('application/json')) return errorResponse('INVALID_REQUEST',400);
      if (Number(request.headers.get('Content-Length')) > 8192) return errorResponse('INVALID_REQUEST',400);
      const bodyText = await request.text();
      if (bodyText.length > 8192) return errorResponse('INVALID_REQUEST',400);
      let body; try { body=JSON.parse(bodyText); } catch { return errorResponse('INVALID_REQUEST',400); }
      const ip = request.headers.get('CF-Connecting-IP') ?? 'unknown';
      if (!await repository.limit('ip:'+await hash(ip),20,now())) return errorResponse('RATE_LIMIT',429);
      if (url.pathname === '/api/auth/phone/register') {
        const token = request.headers.get('Authorization')?.match(/^Bearer (\S+)$/)?.[1];
        if (!token) return errorResponse('INVALID_CREDENTIALS',401);
        const user = await lookup(token);
        await repository.save(user);
        return Response.json({registered:true}, {headers:{'Cache-Control':'no-store'}});
      }
      if (url.pathname !== '/api/auth/phone/login') return errorResponse('NOT_FOUND',404);
      const phone = normalizePhone(body?.phone);
      if (typeof body?.password !== 'string' || !body.password || body.password.length > 4096) return errorResponse('INVALID_REQUEST',400);
      if (!await repository.limit('phone:'+await hash(phone),6,now())) return errorResponse('RATE_LIMIT',429);
      const account = await repository.find(phone);
      if (!account) return errorResponse('INVALID_CREDENTIALS',401);
      const signed = await firebase('signInWithPassword', {email:account.email,password:body.password,returnSecureToken:true});
      const current = await lookup(signed.idToken);
      if (current.localId !== account.uid || current.phoneNumber !== phone || current.email.toLowerCase() !== account.email.toLowerCase()) return errorResponse('INVALID_CREDENTIALS',401);
      // Reveal the account email only after Firebase verifies the password and
      // confirms that the phone is still linked. Never return session tokens.
      return Response.json({email:current.email,uid:current.localId}, {headers:{'Cache-Control':'no-store'}});
    } catch(error) {
      if (error.message === 'RATE_LIMIT') return errorResponse('RATE_LIMIT',429);
      if (error.message === 'INVALID_REQUEST') return errorResponse('INVALID_REQUEST',400);
      if (error.message === 'INVALID_CREDENTIALS') return errorResponse('INVALID_CREDENTIALS',401);
      return errorResponse('TEMPORARILY_UNAVAILABLE',503);
    }
  };
}
