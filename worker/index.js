import {ASSET_PREFIX} from './asset-paths.mjs';
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
    const marketplace=url.pathname.startsWith('/api/marketplace/');
    const phone=url.pathname.startsWith('/api/auth/phone/')||url.pathname==='/api/auth/login';
    if(marketplace||phone){
      const apiKey=typeof env.FIREBASE_SERVER_API_KEY==='string'?env.FIREBASE_SERVER_API_KEY.trim():'';
      if(!env.DB||!apiKey)return Response.json({error:'TEMPORARILY_UNAVAILABLE'},{status:503});
      let saved=handlers.get(env.DB);
      const signature=(env.ADMIN_EMAILS??'')+'|'+(env.DEMO_FUNDS_ENABLED??'');
      if(!saved||saved.signature!==signature||saved.apiKey!==apiKey){
        saved={signature,apiKey,marketplace:createMarketplaceHandler({repository:new MarketplaceRepository(env.DB),apiKey,adminEmails:(env.ADMIN_EMAILS??'').split(',').map(x=>x.trim()).filter(Boolean),allowDemoFunds:env.DEMO_FUNDS_ENABLED==='true',limiterEnabled:true}),phone:createPhoneHandler({repository:new PhoneRepository(env.DB),apiKey})};handlers.set(env.DB,saved);
      }
      return marketplace?saved.marketplace(request):saved.phone(request);
    }
    if(url.pathname.startsWith('/api/'))return Response.json({error:'NOT_FOUND'},{status:404});
    const assetUrl=new URL(request.url);assetUrl.pathname=ASSET_PREFIX+assetUrl.pathname;
    const asset=await env.ASSETS.fetch(new Request(assetUrl,request));
    if(asset.status===404&&(request.headers.get('Accept')?.includes('text/html')||request.headers.get('Sec-Fetch-Mode')==='navigate'))return new Response(request.method==='HEAD'?null:appShell,{headers:{'Content-Type':'text/html; charset=utf-8','Cache-Control':'private, no-cache'}});
    return asset;
}
export default {fetch:(request,env)=>perimeter(request,env,route)};
