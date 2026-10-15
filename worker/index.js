import {createMarketplaceHandler, MarketplaceRepository} from './marketplace.mjs';
import {createPhoneHandler, PhoneRepository} from './phone-auth.mjs';
import {perimeter} from './security.mjs';

const handlers=new WeakMap();
async function route(request, env) {
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
    return env.ASSETS.fetch(request);
}
export default {fetch:(request,env)=>perimeter(request,env,route)};
