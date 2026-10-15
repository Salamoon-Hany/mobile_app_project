import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import vm from 'node:vm';
import {LaunchState} from '../web/sanad-launch-state.mjs';
const ui = readFileSync(new URL('../web/sanad-intro.js', import.meta.url), 'utf8')
  .replace("import {LaunchState} from './sanad-launch-state.mjs';", '');
function launch({seen = false, storageDenied = false, reducedMotion = false} = {}) {
  const nodes = new Map(); const timers = []; const stored = new Map();
  if (seen) stored.set('sanad.onboarding.v1', 'done');
  stored.set('flutter.sanad.language.v1', JSON.stringify('ar'));
  const make = id => ({id, hidden:['sanad-intro','sanad-wait','sanad-retry','sanad-back'].includes(id),
    inert: id === 'sanad-app-host', style:{}, dataset:{}, attrs:{}, events:{},
    addEventListener(event, fn) { this.events[event] = fn; },
    setAttribute(k,v) { this.attrs[k] = v; }, removeAttribute(k) { delete this.attrs[k]; },
    focus() { this.focused = true; }, click() { this.events.click?.(); }});
  const dots = Array.from({length:3}, (_,i) => Object.assign(make(`dot-${i}`),{dataset:{step:String(i)}}));
  const doc = {getElementById(id) { if (!nodes.has(id)) nodes.set(id,make(id)); return nodes.get(id); },
    querySelectorAll(selector) { return selector === '[data-step]' ? dots : []; }, createElement() { return make('script'); }, body:{appendChild() {}}};
  let reloaded = false;
  const context = {LaunchState, document:doc, window:{matchMedia:() => ({matches:reducedMotion})},
    localStorage:{getItem(k) { if(storageDenied) throw Error('disabled'); return stored.get(k); },
      setItem(k,v) { if(storageDenied) throw Error('disabled'); stored.set(k,v); }},
    setTimeout(fn,ms) { const t={fn,ms,active:true}; timers.push(t); return t; },
    clearTimeout(t) { t.active=false; }, location:{reload() { reloaded=true; }}};
  vm.runInNewContext(ui,context);
  const run = ms => { for(const t of timers.filter(t => t.active && t.ms===ms)) {t.active=false;t.fn();} };
  return {node:doc.getElementById.bind(doc), window:context.window, run, stored, dots, reloaded:() => reloaded};
}
test('first visit keeps app inert until intro completion AND engine readiness', () => {
  const app=launch(); app.run(2699);assert.equal(app.node('sanad-intro').hidden,true);app.run(2700);
  assert.equal(app.node('sanad-intro').hidden,false);
  assert.equal(app.node('sanad-app-host').inert,true);
  app.node('sanad-next').click(); app.node('sanad-next').click();
  assert.equal(app.node('sanad-next-label').textContent,'يلا نبدأ');
  app.node('sanad-next').click();
  assert.equal(app.node('sanad-wait').hidden,false);
  assert.equal(app.node('sanad-app-host').inert,true);
  app.window.sanadEngineReady(); app.run(280);
  assert.equal(app.node('sanad-app-host').inert,false);
  assert.equal(app.node('sanad-launch').hidden,true);
  assert.equal(app.stored.get('sanad.onboarding.v1'),'done');
});
test('ready engine does not skip first-time onboarding', () => {
  const app=launch(); app.window.sanadEngineReady(); app.run(2700);
  assert.equal(app.node('sanad-app-host').inert,true);
  app.node('sanad-skip').click(); app.run(280);
  assert.equal(app.node('sanad-launch').hidden,true);
});
test('returning visitor sees brief splash without repeated slides', () => {
  const app=launch({seen:true}); app.window.sanadEngineReady();
  assert.equal(app.node('sanad-app-host').inert,true);
  app.run(2700); app.run(280);
  assert.equal(app.node('sanad-intro').hidden,true);
  assert.equal(app.node('sanad-launch').hidden,true);
});
test('storage disabled still permits normal skip and handoff', () => {
  const app=launch({storageDenied:true}); app.run(2700);
  app.node('sanad-skip').click(); app.window.sanadEngineReady(); app.run(280);
  assert.equal(app.node('sanad-app-host').inert,false);
});
test('failed initialization exposes retry and never reveals broken app', () => {
  const app=launch({seen:true}); app.run(2700); app.window.sanadEngineError();
  assert.equal(app.node('sanad-retry').hidden,false);
  assert.equal(app.node('sanad-app-host').inert,true);
  app.node('sanad-retry').click(); assert.equal(app.reloaded(),true);
});
test('slow initialization can recover after timeout', () => {
  const app=launch({seen:true}); app.run(2700); app.run(30000);
  assert.equal(app.node('sanad-retry').hidden,false);
  app.window.sanadEngineReady(); app.run(280);
  assert.equal(app.node('sanad-launch').hidden,true);
});
test('reduced motion uses immediate handoff after short static splash', () => {
  const app=launch({seen:true,reducedMotion:true}); app.window.sanadEngineReady();
  app.run(150); app.run(0); assert.equal(app.node('sanad-launch').hidden,true);
});
test('back navigation and dot selection keep controls in sync', () => {
  const app=launch(); app.run(2700); app.node('sanad-next').click();
  assert.equal(app.node('sanad-back').hidden,false);
  app.node('sanad-back').click(); assert.equal(app.node('sanad-back').hidden,true);
  app.dots[2].click(); assert.equal(app.node('sanad-next-label').textContent,'يلا نبدأ');
  assert.equal(app.node('sanad-count').textContent,'٣ / ٣');
});
