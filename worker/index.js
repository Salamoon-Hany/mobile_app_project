import {createMarketplaceHandler, MarketplaceRepository} from './marketplace.mjs';
import {createPhoneHandler, PhoneRepository} from './phone-auth.mjs';

let marketplace;
export default {
  async fetch(request, env) {
    if (new URL(request.url).pathname.startsWith('/api/marketplace/')) {
      if (!env.DB) return Response.json({error:'TEMPORARILY_UNAVAILABLE'},{status:503});
      marketplace ??= createMarketplaceHandler({repository:new MarketplaceRepository(env.DB),apiKey:'AIzaSyDErM-SGwWQ76_YTj_AIiZbD8ODBdh9d0g'});
      return marketplace(request);
    }
    if (new URL(request.url).pathname.startsWith('/api/auth/phone/')) {
      if (!env.DB) return Response.json({error:'TEMPORARILY_UNAVAILABLE'},{status:503});
      return createPhoneHandler({repository:new PhoneRepository(env.DB),apiKey:'AIzaSyDErM-SGwWQ76_YTj_AIiZbD8ODBdh9d0g'})(request);
    }
    return env.ASSETS.fetch(request);
  },
};
