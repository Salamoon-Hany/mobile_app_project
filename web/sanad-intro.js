import {LaunchState} from './sanad-launch-state.mjs';
const seenKey = 'sanad.onboarding.v1';
let seen = false;
try { seen = localStorage.getItem(seenKey) === 'done'; } catch (_) { /* Storage can be disabled. */ }
let language = 'en';
try { if (JSON.parse(localStorage.getItem('flutter.sanad.language.v1')) === 'ar') language = 'ar'; } catch (_) {}
const arabic = language === 'ar';
const state = new LaunchState(seen);
const byId = id => document.getElementById(`sanad-${id}`);
byId('launch').setAttribute('dir', arabic ? 'rtl' : 'ltr');
document.documentElement?.setAttribute('lang', language);
const copy = arabic ? null : {
  skip:'Skip intro', back:'Back', next:'Next', start:'Let’s get started',
  ready:'Getting Sanad ready for you…', retry:'Try again',
  error:'The app is taking longer to load. Check your internet connection and try again.',
  tagline:'Here for you, every step.',
};
if (copy) {
  byId('skip').textContent=copy.skip; byId('back').textContent=copy.back;
  byId('retry').textContent=copy.retry;
  document.querySelectorAll('[data-step]').forEach((el,i) => el.setAttribute('aria-label', ['Choose a service','Set your location','Book and follow your request'][i]));
  document.querySelectorAll('.sanad-tagline, .sanad-footer > span:first-child').forEach(el => el.textContent=copy.tagline);
}
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
const frame = content => `<svg viewBox="0 0 360 360" xmlns="http://www.w3.org/2000/svg" fill="none">${content}</svg>`;
const house = '<path d="m97 161 83-71 83 71" stroke="#171917" stroke-width="14" stroke-linecap="round" stroke-linejoin="round"/><path d="M113 153v103h134V153" fill="#D7FF00" stroke="#171917" stroke-width="8" stroke-linejoin="round"/><rect x="160" y="192" width="40" height="64" rx="7" fill="#171917"/><path d="M75 270h211" stroke="#B5C49C" stroke-width="7" stroke-linecap="round"/>';
const steps = [
  {eyebrow:'خدمات كتير. تطبيق واحد.', title:'كل خدمات بيتك،\nفي مكان واحد', body:'كهربائي، سبّاك، نجّار وخدمات تانية. اختار الخدمة اللي محتاجها وابدأ طلبك بسهولة.', art:frame(house + '<g class="float-card"><rect x="34" y="91" width="77" height="66" rx="20" fill="#fff"/><path d="m80 105-17 22h13l-10 17 20-24H72Z" fill="#171917"/></g><g class="float-card"><rect x="258" y="179" width="71" height="68" rx="20" fill="#fff"/><path d="M282 199v18h24v-18m-12 18v13" stroke="#171917" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/></g><circle cx="265" cy="98" r="12" fill="#D7FF00"/>')},
  {eyebrow:'خطوة بسيطة، وتبقى أقرب.', title:'حدّد مكانك،\nوسيب الباقي علينا', body:'اضغط Locate me أو ابحث عن منطقتك. ضيف عنوانك وتفاصيل الشغل، عشان طلبك يبقى واضح من البداية.', art:frame('<rect x="56" y="63" width="248" height="238" rx="35" fill="#fff"/><path d="m76 136 212 50M116 78l-29 204M237 82l-29 202M73 247l211-30" stroke="#E5EAD9" stroke-width="19"/><path d="M109 250v-57h73v-43" stroke="#96AE36" stroke-width="6" stroke-linecap="round" stroke-dasharray="8 12"/><circle cx="109" cy="251" r="13" fill="#171917"/><circle cx="109" cy="251" r="5" fill="#D7FF00"/><g class="float-card"><path d="M180 87c-31 0-52 22-52 50 0 32 39 68 52 81 13-13 52-49 52-81 0-28-21-50-52-50Z" fill="#D7FF00"/><circle cx="180" cy="135" r="17" fill="#171917"/></g>')},
  {eyebrow:'من أول طلب، لحد آخر خطوة.', title:'احجز خدمتك،\nوتابع طلبك', body:'سجّل حسابك وأكّد إيميلك، وبعدها كمّل طلبك. تفاصيل الخدمة والطلبات والإشعارات تبقى قدّامك في مكان واحد.', art:frame('<rect x="81" y="64" width="198" height="252" rx="30" fill="#fff"/><rect x="126" y="46" width="108" height="37" rx="15" fill="#171917"/><path d="M112 161h64m-64 38h103m-103 38h79" stroke="#CBD4B9" stroke-width="9" stroke-linecap="round"/><circle cx="242" cy="220" r="53" fill="#D7FF00" class="float-card"/><path d="m217 220 17 17 33-35" stroke="#171917" stroke-width="10" stroke-linecap="round" stroke-linejoin="round"/><circle cx="116" cy="119" r="8" fill="#D7FF00"/><path d="M139 119h61" stroke="#171917" stroke-width="8" stroke-linecap="round"/>')},
];
if (!arabic) {
  const english = [
    ['Many services. One app.', 'All your home services.\nOne place.', 'Electricians, plumbers, carpenters and more. Choose the service you need and start your request.'],
    ['A simple step brings you closer.', 'Set your location.\nWe will take it from there.', 'Use Locate me or search for your area. Add your address and work details so your request is clear from the start.'],
    ['From your first request to the last step.', 'Book your service.\nFollow your request.', 'Create your account, verify your email and complete your request. Keep services, orders and notifications together in one place.'],
  ];
  steps.forEach((step,i) => { [step.eyebrow,step.title,step.body]=english[i]; });
}
let opened = false;
const timeout = setTimeout(() => {
  if (!state.ready) {
    state.engineError();
    update();
  }
}, 30000);
function render(focus = false) {
  const step = steps[state.step];
  byId('eyebrow').textContent = step.eyebrow;
  byId('heading').textContent = step.title;
  byId('description').textContent = step.body;
  byId('art').innerHTML = step.art;
  byId('next-label').textContent = state.step === 2 ? (copy?.start ?? 'يلا نبدأ') : (copy?.next ?? 'التالي');
  byId('back').hidden = state.step === 0;
  byId('count').textContent = arabic ? `${['١','٢','٣'][state.step]} / ٣` : `${state.step+1} / 3`;
  document.querySelectorAll('[data-step]').forEach(dot => {
    if (Number(dot.dataset.step) === state.step) dot.setAttribute('aria-current', 'step');
    else dot.removeAttribute('aria-current');
  });
  if (focus) byId('heading').focus({preventScroll: true});
}
function openApp() {
  if (opened || !state.canOpen) return;
  opened = true;
  clearTimeout(timeout);
  const host = byId('app-host');
  host.style.visibility = 'visible';
  host.inert = false;
  host.removeAttribute('aria-hidden');
  byId('launch').style.opacity = '0';
  setTimeout(() => {
    byId('launch').hidden = true;
    host.setAttribute('tabindex', '-1');
    host.focus({preventScroll: true});
  }, reducedMotion ? 0 : 280);
}
function update() {
  if (state.canOpen) { openApp(); return; }
  if (!state.minElapsed) return;
  byId('splash').hidden = true;
  if (state.complete) {
    byId('intro').hidden = true;
    byId('wait').hidden = false;
    byId('status').textContent = state.failed
      ? (copy?.error ?? 'التطبيق أخد وقت أطول في التحميل. اتأكد من اتصالك بالإنترنت وحاول تاني.')
      : (copy?.ready ?? 'بنجهّز سند ليك…');
    byId('retry').hidden = !state.failed;
    if (state.failed) byId('retry').focus({preventScroll: true});
  } else {
    const firstShow = byId('intro').hidden;
    byId('intro').hidden = false;
    if (firstShow) render(true);
  }
}
function finish() {
  state.finish();
  // Save only after an explicit skip or completing all three steps.
  try { localStorage.setItem(seenKey, 'done'); } catch (_) { /* Nonessential. */ }
  update();
}
byId('skip').addEventListener('click', finish);
byId('next').addEventListener('click', () => {
  if (state.step === 2) finish();
  else { state.next(); render(true); }
});
byId('back').addEventListener('click', () => { state.back(); render(true); });
document.querySelectorAll('[data-step]').forEach(dot => dot.addEventListener('click', () => {
  state.step = Number(dot.dataset.step); render(true);
}));
byId('retry').addEventListener('click', () => location.reload());
window.sanadEngineReady = () => { state.engineReady(); clearTimeout(timeout); update(); };
window.sanadEngineError = () => { state.engineError(); clearTimeout(timeout); update(); };
setTimeout(() => { state.minElapsed = true; update(); }, reducedMotion ? 150 : 2700);
const bootstrap = document.createElement('script');
bootstrap.src = 'flutter_bootstrap.js';
bootstrap.async = true;
bootstrap.addEventListener('error', window.sanadEngineError);
document.body.appendChild(bootstrap);
// First launch slides remain usable while the app engine loads in the background.
