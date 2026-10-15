import {appShell} from './app-shell.mjs';
import {createMarketplaceHandler, MarketplaceRepository} from './marketplace.mjs';
import {createPhoneHandler, PhoneRepository} from './phone-auth.mjs';
import {perimeter} from './security.mjs';

const handlers=new WeakMap();
async function route(request, env) {
    const url=new URL(request.url);
    // Sites serves matching assets ahead of the Worker. Keep HTML out of the
    // asset namespace so the document always receives the security boundary.
    if(url.pathname==='/'||url.pathname==='/index.html')return new Response(request.method==='HEAD'?null:appShell,{headers:{'Content-Type':'text/html; charset=utf-8','Cache-Control':'private, no-cache'}});
    if (new URL(request.url).pathname.startsWith('/api/')&&!env.DB) return Response.json({error:'TEMPORARILY_UNAVAILABLE'},{status:503});
    let saved=env.DB?handlers.get(env.DB):null;
    const signature=(env.ADMIN_EMAILS??'')+'|'+(env.DEMO_FUNDS_ENABLED??'');
    if(env.DB&&(!saved||saved.signature!==signature)){
      saved={signature,marketplace:createMarketplaceHandler({repository:new MarketplaceRepository(env.DB),apiKey:'AIzaSyDErM-SGwWQ76_YTj_AIiZbD8ODBdh9d0g',adminEmails:(env.ADMIN_EMAILS??'').split(',').map(x=>x.trim()).filter(Boolean),allowDemoFunds:env.DEMO_FUNDS_ENABLED==='true',limiterEnabled:true}),phone:createPhoneHandler({repository:new PhoneRepository(env.DB),apiKey:'AIzaSyDErM-SGwWQ76_YTj_AIiZbD8ODBdh9d0g'})};handlers.set(env.DB,saved);
    }
    if (new URL(request.url).pathname.startsWith('/api/marketplace/')) {
      if (!env.DB) return Response.json({error:'TEMPORARILY_UNAVAILABLE'},{status:503});
      return saved.marketplace(request);
    }
    if (new URL(request.url).pathname.startsWith('/api/auth/phone/')||new URL(request.url).pathname==='/api/auth/login') {
      if (!env.DB) return Response.json({error:'TEMPORARILY_UNAVAILABLE'},{status:503});
      return saved.phone(request);
    }
    if(new URL(request.url).pathname.startsWith('/api/'))return Response.json({error:'NOT_FOUND'},{status:404});
    const asset=await env.ASSETS.fetch(request);
    if(asset.status===404&&(request.headers.get('Accept')?.includes('text/html')||request.headers.get('Sec-Fetch-Mode')==='navigate'))return new Response(request.method==='HEAD'?null:appShell,{headers:{'Content-Type':'text/html; charset=utf-8','Cache-Control':'private, no-cache'}});
    return asset;
}
export default {fetch:(request,env)=>perimeter(request,env,route)};
