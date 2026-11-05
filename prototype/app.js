const icons = {
  wave: '<path d="M3 16c3-7 5-9 8-9s3 7 6 7c1.5 0 2.5-2 4-5M3 20c3-7 5-9 8-9s3 7 6 7c1.5 0 2.5-2 4-5"/>',
  activity: '<path d="M4 19V9m5 10V5m5 14v-7m5 7V3"/>',
  settings: '<path d="m9 3-.6 2.1-2 .9-2-.6-2 3.4 1.5 1.6v2.2L2.4 14l2 3.4 2-.6 2 .9L9 20h4l.6-2.3 2-.9 2 .6 2-3.4-1.5-1.4v-2.2l1.5-1.6-2-3.4-2 .6-2-.9L13 3z"/><circle cx="11" cy="11.5" r="3"/>',
  browser: '<rect x="3" y="4" width="18" height="16" rx="3"/><path d="M3 9h18M7 6.5h.01m3 0h.01"/>',
  moon: '<path d="M20 14A8.5 8.5 0 0 1 10 4a8.5 8.5 0 1 0 10 10Z"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.5 1.5m11 11L19 19M5 19l1.5-1.5m11-11L19 5"/>',
  pause: '<path d="M9 5v14M15 5v14"/>',
  play: '<path d="m8 5 11 7-11 7z"/>',
  wifi: '<path d="M3 8a15 15 0 0 1 18 0M6 12a10 10 0 0 1 12 0m-9 4a5 5 0 0 1 6 0m-3 4h.01"/>',
  battery: '<rect x="2" y="6" width="17" height="12" rx="2"/><path d="M22 10v4"/><path d="M5 9h11v6H5z" fill="currentColor" stroke="none"/>',
  down: '<path d="M12 4v16m-6-6 6 6 6-6"/>',
  up: '<path d="M12 20V4m-6 6 6-6 6 6"/>',
  'arrow-up': '<path d="M12 20V4m-6 6 6-6 6 6"/>',
  back: '<path d="m14 6-6 6 6 6"/>',
  right: '<path d="m9 6 6 6-6 6"/>',
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6m0-10h.01"/>',
  shield: '<path d="m12 3 8 3v6c0 4-5 8-8 9-3-1-8-5-8-9V6z"/><path d="m8 12 3 3 5-6"/>',
  check: '<path d="m5 12 4 4L19 6"/>',
  close: '<path d="m6 6 12 12M6 18 18 6"/>',
  trash: '<path d="M4 7h16M9 7V4h6v3M6 7l1 14h10l1-14M10 11v6m4-6v6"/>',
  youtube: '<rect x="2" y="5" width="20" height="14" rx="5" fill="currentColor" stroke="none"/><path d="m10 9 6 3-6 3z" fill="white" stroke="none"/>',
  instagram: '<rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><path d="M17.5 6.5h.01"/>',
  reddit: '<path d="m12 7 2-4 5 1"/><circle cx="20" cy="4" r="2"/><ellipse cx="12" cy="14" rx="9" ry="6"/><path d="M4 10C0 5 0 14 3 14m17-4c4-5 4 4 1 4m-13 3c2 2 6 2 8 0"/><circle cx="8" cy="13" r="1" fill="currentColor"/><circle cx="16" cy="13" r="1" fill="currentColor"/>',
  x: '<path d="m4 3 16 18h-5L3 3h5l13 18M20 3 4 21"/>',
  github: '<path d="M8 20c-5 1-5-3-7-3m13 5v-4c0-1 .1-1.6-.5-2 4-.5 6-2 6-5 0-1.5-.5-2.5-1.5-3.5.3-1 .3-2.5 0-3.5-2 0-3 1-4 1.5a14 14 0 0 0-7 0C6 5 5 4 3 4c-.3 1-.3 2.5 0 3.5C2 8.5 1.5 9.5 1.5 11c0 3 2 4.5 6 5-.6.4-.5 1-.5 2v4" transform="translate(2 -1) scale(.9)"/>',
  safari: '<circle cx="12" cy="12" r="9" stroke="#5e9fe5"/><path d="m16 7-3 7-5 3 3-7z" fill="#5e9fe5" stroke="none"/><path d="m16 7-5 3 2 4z" fill="#ef7a73" stroke="none"/>',
  chrome: '<circle cx="12" cy="12" r="9" stroke="#e0a64b" stroke-width="3"/><path d="M12 3a9 9 0 0 1 8 5H12" stroke="#dc6b60" stroke-width="3"/><path d="M4 8a9 9 0 0 0 8 13l4-8" stroke="#6ca27a" stroke-width="3"/><circle cx="12" cy="12" r="4" fill="#619beb" stroke="white"/>',
};
function icon(name, extra = '') { return `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.65" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" ${extra}>${icons[name] || icons.browser}</svg>`; }
function hydrateIcons(root = document) { root.querySelectorAll('[data-icon]').forEach(el => { el.innerHTML = icon(el.dataset.icon); }); }
const platforms = [
  {id:'youtube',name:'YouTube',domain:'youtube.com',today:74,yesterday:102,color:'#e76868',bg:'#fff0ee',ink:'#e95858'},
  {id:'instagram',name:'Instagram',domain:'instagram.com',today:42,yesterday:28,color:'#bf86bd',bg:'#faeef6',ink:'#bb6298'},
  {id:'reddit',name:'Reddit',domain:'reddit.com',today:31,yesterday:46,color:'#e9a16f',bg:'#fff1e7',ink:'#e78a4f'},
  {id:'x',name:'X / Twitter',domain:'x.com',today:23,yesterday:41,color:'#929ba7',bg:'#edf0f3',ink:'#3d4757'},
  {id:'github',name:'GitHub',domain:'github.com',today:20,yesterday:25,color:'#9c95cf',bg:'#f0eefa',ink:'#77719f'},
];
const initial = () => ({screen:'activity',period:'daily',day:'today',paused:false,dark:false,login:false,retention:'30',excluded:[],connected:{safari:true,chrome:false},deleted:false,detail:null});
let state = initial();
try {
  const saved = JSON.parse(localStorage.getItem('surfmeter-preview-v1'));
  if (saved) {
    for (const key of ['paused','dark','login','deleted']) if (typeof saved[key] === 'boolean') state[key] = saved[key];
    if (['7','30','90'].includes(saved.retention)) state.retention = saved.retention;
    if (Array.isArray(saved.excluded)) state.excluded = saved.excluded.filter(x => typeof x === 'string' && /^[a-z0-9.-]+$/.test(x));
    for (const b of ['safari','chrome']) if (typeof saved.connected?.[b] === 'boolean') state.connected[b] = saved.connected[b];
  }
} catch { /* Preview remains usable when local storage is unavailable. */ }
function persist() { try { localStorage.setItem('surfmeter-preview-v1', JSON.stringify(state)); } catch {} }
function escapeHtml(value) { return String(value).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c])); }
const duration = m => m >= 60 ? `${Math.floor(m/60)}h${m%60 ? ` ${m%60}m` : ''}` : `${m}m`;
const total = day => state.deleted ? 0 : platforms.reduce((sum,p) => sum+p[day],0);
const content = document.querySelector('#app-content');
let toastTimer;
function toast(message) { const el = document.querySelector('#toast'); el.textContent = message; el.classList.add('visible'); clearTimeout(toastTimer); toastTimer = setTimeout(() => el.classList.remove('visible'), 3000); }
function go(screen) { state.screen = screen; state.detail = null; document.querySelector('#app-popover').hidden = false; document.querySelector('#closed-hint').hidden = true; document.querySelector('#menubar-trigger').setAttribute('aria-expanded','true'); render(); }
function platformIcon(p) { return `<span class="platform-icon" style="--icon-bg:${p.bg};--icon-color:${p.ink}">${icon(p.id)}</span>`; }
function chart(day, platform = null) {
  const weights = day === 'today' ? [0,0,0,0,0,0,0,0,8,18,32,16,24,12,27,18,20,15,0,0,0,0,0,0] : [0,0,0,0,0,0,0,5,12,26,35,20,18,8,29,20,19,18,13,10,7,2,0,0];
  const value = state.deleted ? 0 : platform ? platform[day] : total(day);
  const sum = weights.reduce((a,b)=>a+b,0);
  const times = weights.map(w => Math.round(w / sum * value));
  const max = Math.max(1,...times);
  return `<div class="chart" role="img" aria-label="Illustrative hourly distribution of ${duration(value)} of ${day === 'today' ? "today's" : "yesterday's"} browsing">${times.map((t,i) => `<span class="hour-bar ${i === 17 && day === 'today' ? 'current' : ''}" title="${String(i).padStart(2,'0')}:00 · approximately ${t}m"><span style="--height:${t/max*94}%"></span></span>`).join('')}</div><div class="chart-labels"><span>00:00</span><span>06:00</span><span>12:00</span><span>18:00</span><span>24:00</span></div>`;
}
// The seven sample days end on the demo date, Thursday 5 November.
const weekDays = [
  {label:'Fri',date:'30 Oct'}, {label:'Sat',date:'31 Oct'},
  {label:'Sun',date:'1 Nov'}, {label:'Mon',date:'2 Nov'},
  {label:'Tue',date:'3 Nov'}, {label:'Wed',date:'4 Nov'},
  {label:'Thu',date:'5 Nov'},
];
const weekHistory = {
  youtube:[95,110,86,65,92,102,74],
  instagram:[35,52,48,30,38,28,42],
  reddit:[44,38,55,27,39,46,31],
  x:[30,46,32,22,35,41,23],
  github:[40,15,0,52,36,25,20],
};
function weekValues(platform = null) {
  return weekDays.map((_, i) => state.deleted ? 0 : platform
    ? weekHistory[platform.id][i]
    : platforms.reduce((sum, p) => sum + weekHistory[p.id][i], 0));
}
function weekTotal(platform = null) { return weekValues(platform).reduce((sum, value) => sum + value, 0); }
function weeklyChart(platform = null) {
  const values = weekValues(platform), max = Math.max(1, ...values);
  return `<div class="weekly-chart" role="img" aria-label="Daily browsing, 30 October to 5 November: ${weekDays.map((d,i)=>`${d.label} ${d.date}, ${duration(values[i])}`).join('; ')}">${weekDays.map((d,i)=>`
    <div class="week-column ${i===6?'current':''}">
      <span class="week-value">${duration(values[i])}</span>
      <span class="week-bar-track"><span style="--height:${values[i]/max*100}%"></span></span>
      <span class="week-day">${d.label}</span><span class="week-date">${i===6?'Today':d.date}</span>
    </div>`).join('')}</div>`;
}
function platformRows(weekly) {
  const value = p => weekly ? weekTotal(p) : p[state.day];
  const max = Math.max(1, ...platforms.map(value));
  return [...platforms].sort((a,b)=>value(b)-value(a)).map(p => {
    const delta = p.today-p.yesterday, compare = !weekly && state.day==='today';
    return `<button class="platform-row" data-platform="${p.id}" aria-label="${p.name}, ${duration(value(p))}${weekly?', last 7 days':compare?`, yesterday ${duration(p.yesterday)}, ${duration(Math.abs(delta))} ${delta>0?'more':'less'}`:''}">
      ${platformIcon(p)}<span class="platform-info"><span class="platform-name">${p.name}</span><span class="usage-track"><span style="--width:${value(p)/max*100}%;--bar-color:${p.color}"></span></span></span>
      <span class="platform-times"><span class="today-time">${duration(value(p))}</span>${compare?`<span class="yesterday-time">${duration(p.yesterday)} yesterday</span>`:weekly?`<span class="yesterday-time">${duration(Math.round(value(p)/7))} / day</span>`:''}</span>
      ${compare?`<span class="delta ${delta>0?'up':'down'}">${icon(delta>0?'up':'down')}${Math.abs(delta)}m</span>`:''}</button>`;
  }).join('');
}
function activityView() {
  const weekly = state.period==='weekly', today = state.day==='today';
  const minutes = weekly ? weekTotal() : total(state.day);
  const difference = total('today')-total('yesterday');
  return `${state.paused ? `<div class="paused-banner">${icon('pause')}Tracking is paused. Your totals are saved.</div>` : ''}
    <div class="tabs" role="tablist" aria-label="Activity period">${['daily','weekly'].map(period=>`<button id="tab-${period}" role="tab" aria-selected="${state.period===period}" aria-controls="activity-panel" tabindex="${state.period===period?0:-1}" class="${state.period===period?'selected':''}" data-period="${period}">${period==='daily'?'Daily':'Weekly'}</button>`).join('')}</div>
    <div id="activity-panel" role="tabpanel" aria-labelledby="tab-${state.period}">
    <section class="summary"><div class="summary-top period-heading"><span>${weekly?'Last 7 days':today?'Today · Thu, 5 Nov':'Yesterday · Wed, 4 Nov'}</span>${weekly?'<span class="date">30 OCT – 5 NOV</span>':`<button class="yesterday-button ${!today?'selected':''}" data-day="${today?'yesterday':'today'}" aria-pressed="${!today}" title="${today?'Show yesterday':'Return to today'}">${icon('back')}Yesterday</button>`}</div>
    <h2 class="big-total" aria-label="${duration(minutes)}">${Math.floor(minutes/60)}<small>h</small>${minutes%60}<small>m</small></h2>
    <div class="total-comparison">${state.deleted ? '<span>No activity recorded yet</span>' : weekly ? `<span class="weekly-average"><strong>${duration(Math.round(minutes/7))}</strong> daily average · includes today so far</span>` : today ? `${icon(difference>0?'up':'down')}<strong class="${difference>0?'up':''}">${duration(Math.abs(difference))} ${difference>0?'more':'less'}</strong><span>than yesterday</span>` : '<span>Full day · across 5 websites</span>'}</div>
    ${weekly?weeklyChart():chart(state.day)}</section>
    <section class="platform-section"><div class="section-labels"><span>Your platforms</span><span>${weekly?'7-day total':today?'vs. yesterday':'Daily total'} ${icon('info')}</span></div>
    ${state.deleted ? `<div class="empty-state">${icon('wave')}<h3>A fresh start.</h3><p>Your activity will appear here as you browse. For now, explore with sample data.</p><button data-action="restore">Restore sample activity</button></div>` : platformRows(weekly)}
    <p class="coverage-note">${icon('shield')}${weekly?'Last 7 calendar days, including today so far.':today?'Compared with yesterday’s full day.':'Click Yesterday again to return to today.'}</p></section></div>`;
}
function header(title) { return `<div class="view-header"><button class="back-button" data-action="back" aria-label="Back to activity">${icon('back')}</button><h2>${title}</h2></div>`; }
function settingsView() { return `${header('Preferences')}<div class="settings-content">
  <p class="group-title">Make it yours</p><div class="setting-row"><div class="setting-copy"><span>Launch at login</span><small>Ready when your day begins.</small></div><button class="switch" role="switch" aria-checked="${state.login}" aria-label="Launch at login" data-toggle="login"></button></div>
  <div class="setting-row"><div class="setting-copy"><span>Dark appearance</span><small>A softer glow after hours.</small></div><button class="switch" role="switch" aria-checked="${state.dark}" aria-label="Dark appearance" data-toggle="dark"></button></div>
  <button class="connection-button" data-action="setup"><span>${icon('browser')}Connected browsers</span><span><small>${Object.values(state.connected).filter(Boolean).length} connected</small>${icon('right')}</span></button>
  <p class="group-title group-gap">Your data</p><div class="setting-row"><div class="setting-copy"><span>Keep daily totals</span><small>Older activity is cleared automatically.</small></div><select id="retention" aria-label="Keep daily totals">${['7','30','90'].map(d=>`<option value="${d}" ${state.retention===d?'selected':''}>${d} days</option>`).join('')}</select></div>
  <div class="setting-row"><div class="setting-copy"><span>Excluded websites</span><small>Leave these websites out of your totals.</small></div></div>
  <form id="exclusion-form" class="exclusion-form"><input id="excluded-domain" type="text" autocomplete="off" spellcheck="false" placeholder="e.g. work.example.com" aria-label="Website domain to exclude" required><button type="submit">Add</button></form>
  <div class="excluded-list">${state.excluded.map(d=>`<span class="excluded-tag">${escapeHtml(d)}<button data-remove="${escapeHtml(d)}" aria-label="Remove exclusion for ${escapeHtml(d)}">${icon('close')}</button></span>`).join('')}</div>
  <button class="delete-button" data-action="delete">Delete all activity…</button><div class="privacy-note">${icon('shield')}<span>Your activity stays on this Mac.<br>No accounts. No browsing data sent anywhere.</span></div></div>`; }
function setupView() { return `<div class="setup-content"><div class="setup-art"><span class="setup-browser">${icon('browser')}</span><span class="connection-line"></span><span class="brand-icon">${icon('wave')}</span><span class="connection-line"></span><span class="setup-browser">${icon('shield')}</span></div><h2>A window into your habits.</h2><p class="setup-description">Connect a browser to see where your time goes. Just the website and the time. Nothing more.</p>
  ${['safari','chrome'].map(b=>`<div class="browser-card">${icon(b)}<div><strong>${b==='safari'?'Safari':'Google Chrome'}</strong><small>${state.connected[b]?'Ready to track active browsing':'Connect to start tracking'}</small></div><button data-browser="${b}" class="${state.connected[b]?'connected':''}" aria-label="${state.connected[b]?'Disconnect':'Connect'} ${b==='safari'?'Safari':'Google Chrome'}">${state.connected[b]?'✓ Connected':'Connect'}</button></div>`).join('')}
  <div class="setup-private">${icon('shield')}<div><strong>A little awareness. A lot of privacy.</strong><p>Only your active tab counts. Private windows stay private. Everything stays on your Mac.</p></div></div>
  <button class="primary-button" data-action="back">${Object.values(state.connected).some(Boolean)?'Back to my activity':'Explore sample activity'}</button><p class="detail-footnote" style="text-align:center">Preview only. Browser connections are simulated.</p></div>`; }
function detailView() {
  const p = platforms.find(p=>p.id===state.detail), delta = p.today-p.yesterday;
  const weekly = state.period==='weekly', today = state.day==='today';
  return `${header('Website activity')}<div class="detail-content"><div class="detail-identity">${platformIcon(p)}<div><h2>${p.name}</h2><p>${p.domain}</p></div></div>
    <div class="detail-numbers">${weekly?`<div><span>Last 7 days</span><strong>${duration(weekTotal(p))}</strong></div><div><span>Daily average</span><strong>${duration(Math.round(weekTotal(p)/7))}</strong></div>`:`<div><span>${today?'Today':'Yesterday'}</span><strong>${duration(p[state.day])}</strong></div><div><span>${today?'Yesterday':'Today'}</span><strong>${duration(today?p.yesterday:p.today)}</strong></div>`}</div>
    ${weekly?'<p class="detail-footnote">30 Oct – 5 Nov · includes today so far</p>':today?`<div class="detail-comparison ${delta>0?'up':''}">${icon(delta>0?'up':'down')}${duration(Math.abs(delta))} ${delta>0?'more':'less'} than yesterday’s full day</div>`:'<p class="detail-footnote">Yesterday’s complete calendar day</p>'}
    <p class="detail-chart-label">${weekly?'Your week, day by day':today?'Today, hour by hour':'Yesterday, hour by hour'}</p>${weekly?weeklyChart(p):chart(state.day,p)}
    <button class="detail-exclude" data-exclude="${p.domain}">${state.excluded.includes(p.domain)?'Include this website again':'Exclude this website'}</button><p class="detail-footnote">Excluding a website stops future tracking. Your existing totals stay in place.</p></div>`;
}
function render() {
  document.body.classList.toggle('dark',state.dark);
  content.innerHTML = state.detail ? detailView() : state.screen === 'settings' ? settingsView() : state.screen === 'setup' ? setupView() : activityView();
  document.querySelectorAll('.screen-button').forEach(b=>{ b.classList.toggle('active',b.dataset.screen===state.screen); if(b.dataset.screen===state.screen)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current'); });
  const pill = document.querySelector('#status-pill'); pill.classList.toggle('paused',state.paused); pill.innerHTML = `<span></span>${state.paused?'Paused':'Tracking'}`; pill.title = state.paused?'Resume tracking':'Pause tracking';
  document.querySelector('#pause-toggle').innerHTML = `${icon(state.paused?'play':'pause')}<span>${state.paused?'Resume tracking':'Pause tracking'}</span>`;
  document.querySelector('#menubar-total').textContent = state.paused?'Paused':duration(total('today'));
  document.querySelector('#theme-toggle').innerHTML = `${icon(state.dark?'sun':'moon')}<span>${state.dark?'Light appearance':'Dark appearance'}</span>`;
  document.querySelector('#theme-toggle').setAttribute('aria-label', state.dark ? 'Light appearance' : 'Dark appearance');
  persist();
}
function togglePause() { state.paused = !state.paused; render(); toast(state.paused?'Tracking paused':'Tracking resumed · sample data'); }
function alignPopover() {
  const popover = document.querySelector('#app-popover');
  if (popover.hidden) return;
  const trigger = document.querySelector('#menubar-trigger').getBoundingClientRect();
  const panel = popover.getBoundingClientRect();
  const offset = Math.min(panel.width - 20, Math.max(20, trigger.left + trigger.width / 2 - panel.left));
  document.querySelector('.popover-notch').style.left = `${offset - 6.5}px`;
  document.querySelector('.popover-notch').style.right = 'auto';
}
window.addEventListener('resize', alignPopover);
new ResizeObserver(alignPopover).observe(document.querySelector('#app-popover'));
document.querySelectorAll('[data-screen]').forEach(b=>b.addEventListener('click',()=>go(b.dataset.screen)));
document.querySelector('#pause-toggle').addEventListener('click',togglePause);
document.querySelector('#status-pill').addEventListener('click',togglePause);
document.querySelector('#preferences-button').addEventListener('click',()=>go(state.screen==='settings'?'activity':'settings'));
document.querySelector('#theme-toggle').addEventListener('click',()=>{state.dark=!state.dark;render();});
document.querySelector('#menubar-trigger').addEventListener('click',()=>{ const p=document.querySelector('#app-popover');p.hidden=!p.hidden;document.querySelector('#closed-hint').hidden=!p.hidden;document.querySelector('#menubar-trigger').setAttribute('aria-expanded',String(!p.hidden)); });
document.querySelector('#reset-demo').addEventListener('click',()=>{state=initial();go('activity');toast('Demo reset to its original state');});
content.addEventListener('click',e=>{
  const target=e.target.closest('button'); if(!target)return;
  if(target.dataset.period){state.period=target.dataset.period;if(state.period==='daily')state.day='today';render();content.querySelector(`[data-period="${state.period}"]`).focus();}
  if(target.dataset.day){state.day=target.dataset.day;render();content.querySelector('.yesterday-button').focus();}
  if(target.dataset.platform){state.detail=target.dataset.platform;render();content.querySelector('.back-button').focus();}
  if(target.dataset.toggle){const key=target.dataset.toggle;state[key]=!state[key];render();content.querySelector(`[data-toggle="${key}"]`).focus();if(key==='login')toast(`Launch at login ${state.login?'enabled':'disabled'} in this preview`);}
  if(target.dataset.browser){const b=target.dataset.browser;state.connected[b]=!state.connected[b];render();content.querySelector(`[data-browser="${b}"]`).focus();toast(`${b==='safari'?'Safari':'Chrome'} ${state.connected[b]?'connected':'disconnected'} · simulated`);}
  if(target.dataset.remove){state.excluded=state.excluded.filter(d=>d!==target.dataset.remove);render();toast('Website included again');}
  if(target.dataset.exclude){const d=target.dataset.exclude,excluded=state.excluded.includes(d);state.excluded=excluded?state.excluded.filter(x=>x!==d):[...state.excluded,d];render();toast(excluded?'Website included again':'Website excluded from future tracking');}
  if(target.dataset.action==='back'){go('activity');document.querySelector('#preferences-button').focus();}
  if(target.dataset.action==='setup')go('setup');
  if(target.dataset.action==='delete')document.querySelector('#delete-dialog').showModal();
  if(target.dataset.action==='restore'){state.deleted=false;render();toast('Sample activity restored');}
});
content.addEventListener('change',e=>{if(e.target.id==='retention'){state.retention=e.target.value;persist();toast(`Preview retention set to ${state.retention} days`);}});
content.addEventListener('submit',e=>{
  if(e.target.id!=='exclusion-form')return;e.preventDefault();const input=document.querySelector('#excluded-domain');let domain;
  try{const raw=input.value.trim();const url=new URL(raw.includes('://')?raw:`https://${raw}`);domain=url.hostname.toLowerCase().replace(/^www\./,'');if(!/^(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z]{2,}$/.test(domain))throw new Error();}catch{input.setCustomValidity('Enter a website domain, such as example.com.');input.reportValidity();return;}
  if(state.excluded.includes(domain)){toast('This website is already excluded');return;}state.excluded.push(domain);render();content.querySelector('#excluded-domain').focus();toast(`${domain} excluded from future tracking`);
});
content.addEventListener('input',e=>{if(e.target.id==='excluded-domain')e.target.setCustomValidity('');});
content.addEventListener('keydown',e=>{
  if(e.target.matches('[role="tab"]')&&['ArrowLeft','ArrowRight','Home','End'].includes(e.key)) {
    e.preventDefault();
    state.period=e.key==='Home'?'daily':e.key==='End'?'weekly':state.period==='daily'?'weekly':'daily';
    if(state.period==='daily')state.day='today';
    render();content.querySelector(`[data-period="${state.period}"]`).focus();
  }
});
document.querySelector('#cancel-delete').addEventListener('click',()=>document.querySelector('#delete-dialog').close());
document.querySelector('#confirm-delete').addEventListener('click',()=>{state.deleted=true;document.querySelector('#delete-dialog').close();go('activity');toast('Sample activity deleted');});
hydrateIcons();render();
