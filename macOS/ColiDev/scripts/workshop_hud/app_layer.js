/* ---------- Приложение: данные и состояния из Swift / The app: data and states from Swift ----------
   Swift вызывает window.creatorApp.receive({type, …}): state, data, practice, answer, confirm.
   Swift calls window.creatorApp.receive({type, …}): state, data, practice, answer, confirm. */
const esc = (v) => String(v == null ? '' : v).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const appState = { answerId: null, confirmId: null, lessonsSet: false, terminal: null, terminalId: '0', memoryId: 0, notebookId: 0 };
const GRAD = ['#ffb27a,#ffe3c8', '#a9ccff,#e0ecff', '#cbbcff,#ece6ff'];
function setTip(el, text) { if (!el || !text) return; el.dataset.tip = text; el.setAttribute('aria-label', text); }
function applyStrings(s, locale) {
  T = s || {};
  if (locale) {
    fmtTime = new Intl.DateTimeFormat(locale, { hour: '2-digit', minute: '2-digit' });
    fmtDay = new Intl.DateTimeFormat(locale, { weekday: 'short', day: 'numeric', month: 'long' });
    document.documentElement.lang = locale.slice(0, 2); tick();
  }
  const set = (sel, key, prop) => { const el = document.querySelector(sel); if (el && T[key]) el[prop || 'textContent'] = T[key]; };
  set('.wm', 'hud.sub'); set('.wm-sub', 'hud.sub'); set('#ask', 'hud.ask', 'placeholder'); set('label[for="ask"]', 'hud.askLabel');
  const send = document.querySelector('.send'); if (send && T['hud.send']) send.setAttribute('aria-label', T['hud.send']);
  const tips = ['hud.tip.claude', 'hud.tip.gemini', 'hud.tip.qwen', 'hud.tip.access'];
  document.querySelectorAll('.status svg[data-tip]').forEach((el, i) => setTip(el, T[tips[i]]));
  ['new', 'ex', 'ed', 'proj', 'notes', 'rem', 'agents', 'set'].forEach((a) => setTip(document.querySelector(`.item[data-act="${a}"]`), T['hud.rail.' + a]));
  const segKeys = { agents: 'hud.rail.agents', council: 'hud.seg.council', rem: 'hud.rail.rem' };
  document.querySelectorAll('#seg button').forEach((b) => { if (T[segKeys[b.dataset.v]]) b.textContent = T[segKeys[b.dataset.v]]; });
  set('#note', 'hud.note', 'placeholder'); set('.foot .sr', 'hud.noteLabel');
  const add = $('addTask'); if (add && T['hud.addTask'] && add.lastChild) add.lastChild.textContent = T['hud.addTask'];
  set('#run', 'hud.run'); set('#check', 'hud.check'); set('#edWin .wh b', 'hud.rail.ed');
  set('#toast [data-ans="yes"]', 'hud.yes'); set('#toast [data-ans="no"]', 'hud.no'); set('#fallback', 'hud.fallback');
  if (T['hud.confirmLabel']) $('toast').setAttribute('aria-label', T['hud.confirmLabel']);
  const voiceEl = document.querySelector('.voice'); if (voiceEl && T['hud.voice']) voiceEl.setAttribute('aria-label', T['hud.voice']);
  const fileEl = document.querySelector('#edWin .file'); if (fileEl && T['hud.edit']) fileEl.title = T['hud.edit'];
  ['listen', 'think', 'agents', 'speak'].forEach((m) => { if (T['hud.state.' + m]) STATES[m].name = T['hud.state.' + m]; });
  $('state').textContent = STATES[mode].name;
}
function appData(d) {
  applyStrings(d.strings, d.locale);
  const on = document.querySelector('.status .on .t'); if (on) on.textContent = t(d.online ? 'hud.online' : 'hud.starting');
  const p = d.path, rb = document.querySelector('.ringb');
  setTip(rb, `${t('hud.rail.path')} · ${p.percent}%`);
  rb.querySelector('text').textContent = `${p.percent}%`;
  rb.querySelectorAll('circle')[1].setAttribute('stroke-dasharray', `${(p.percent / 100 * 113.1).toFixed(1)} 113.1`);
  pops.path = `<h3>${esc(t('hud.rail.path'))}</h3><div class="big">${p.percent}%</div><div class="psub">${esc(p.sub)}</div>
    <div class="stages">${p.stages.map((x) => `<div class="stg"><span>${esc(x.name)}</span><output>${x.percent}%</output><div class="tr"><i style="width:${x.percent}%"></i></div></div>`).join('')}</div>
    <div class="trio">${p.trio.map((x) => `<div><b>${esc(x.value)}</b><span>${esc(x.label)}</span></div>`).join('')}</div>`;
  const list = (l) => `<h3>${esc(l.title)}</h3>${l.sub ? `<div class="psub">${esc(l.sub)}</div>` : ''}<div class="plist">${l.items.length
    ? l.items.map((i) => `<div${i.path ? ` data-path="${esc(i.path)}" role="button" tabindex="0"` : ''}><b>${esc(i.name)}</b><span>${esc(i.detail)}</span></div>`).join('')
    : `<div><span>${esc(l.empty)}</span></div>`}</div>`;
  pops.proj = list(d.projects); pops.notes = list(d.notes); pops.set = list(d.settings);
  views.agents = () => d.agents.map((a) => `<div class="row">${ico(AG[a.icon] ? a.icon : 'open')}<div><b>${esc(a.name)}</b><span>${esc(a.detail)}</span></div><span class="st${a.live ? ' live' : ''}">${esc(a.status)}</span></div>`).join('');
  views.council = () => d.council.members.map((m, i) => `<div class="vote"><span>${esc(m.name)}</span><div class="tr"><i style="width:${m.percent}%;background:linear-gradient(90deg,${GRAD[i % 3]})"></i></div><output>${esc(m.mark)}</output></div>`).join('')
    + `<p class="hint">${esc(d.council.hint)}</p>`;
  views.rem = () => (d.reminders.length ? d.reminders.map((r) => `<div class="rem"><time>${esc(r.time)}</time><span>${esc(r.text)}</span></div>`).join('') : `<p class="hint">${esc(d.remindersEmpty)}</p>`);
  if (d.lessons.length) {
    lessons.splice(0, lessons.length, ...d.lessons.map((l) => [l.title, l.sub]));
    if (!appState.lessonsSet || li >= lessons.length) { li = d.lessonIndex; appState.lessonsSet = true; }
    showLesson();
  }
  document.querySelectorAll('#hints button').forEach((b, i) => { if (d.hints[i]) b.textContent = d.hints[i]; });
  document.querySelectorAll('.dock .tile').forEach((b) => { const x = d.tiles[b.dataset.tool]; if (x) { setTip(b, x.tip); b.classList.toggle('run', !!x.live); } });
  showSeg(seg);
  if (popOpen) $('pop').innerHTML = pops[popOpen];
}
function appStateMsg(m) {
  if (STATES[m.mode] && m.mode !== mode) setMode(m.mode);
  if (typeof m.line === 'string' && lineEl.textContent !== m.line) { clearInterval(typing); lineEl.textContent = m.line; if (m.mode === 'speak') pulse = 1; }
}
function appPractice(p) {
  document.querySelector('#edWin .file').textContent = p.file;
  document.querySelector('#edWin pre.code').innerHTML = p.code;
  $('outText').textContent = p.out; $('outOk').textContent = p.ok; $('outOk').classList.toggle('ok', !!p.good);
}
function appAnswer(a) {
  $('exTitle').textContent = a.title;
  Object.keys(exViews).forEach((k) => delete exViews[k]);
  exViews[t('hud.ex.answer', 'Ответ')] = a.html;
  exViews[t('hud.ex.sources', 'Источники')] = a.sources.split('\n').map((l) => `<p>${esc(l)}</p>`).join('');
  if (appState.terminal) exViews[t('hud.ex.terminal', 'Терминал')] = appState.terminal;
  const body = $('exBody'), top = body.scrollTop;
  buildTabs(); body.scrollTop = top;
  if (a.open && a.id !== appState.answerId) { appState.answerId = a.id; setWin('exWin', true); }
}
/* «Терминал»: команды «$ …» и живой вывод агента. / Raw commands and the live agent output. */
function appTerminal(m) {
  appState.terminal = m.html;
  const name = t('hud.ex.terminal', 'Терминал');
  exViews[name] = m.html;
  const body = $('exBody'), atEnd = body.scrollTop + body.clientHeight >= body.scrollHeight - 24, top = body.scrollTop;
  if (m.open && m.id !== appState.terminalId) {
    appState.terminalId = m.id; exSel = name; setWin('exWin', true);
  }
  if (exSel === name) $('exTitle').textContent = m.title;
  buildTabs();
  body.scrollTop = exSel === name && atEnd ? body.scrollHeight : top;
}
/* «Память»: список, поиск и заметка в стеклянной панели. / Memory in a glass panel. */
function appMemory(m) {
  $('memVault').textContent = m.vault;
  $('memList').innerHTML = m.items.length
    ? m.items.map((i) => `<button type="button" class="memi${i.id === m.selected ? ' on' : ''}" data-id="${esc(i.id)}"><b>${esc(i.title)}</b><span>${esc(i.folder || '/')}</span></button>`).join('')
    : `<p class="hint">${esc(m.empty)}</p>`;
  $('memBody').innerHTML = m.html;
  if (m.openID && m.openID !== appState.memoryId) { appState.memoryId = m.openID; $('nbWin').classList.remove('open'); $('memWin').classList.add('open'); }
}
/* NotebookLM: настоящий веб-вид macOS лежит поверх #nbBody; страница сообщает его место.
   NotebookLM: a native web view sits over #nbBody; the page reports where it is. */
function nbReport() {
  const open = $('nbWin').classList.contains('open'), r = $('nbBody').getBoundingClientRect();
  post('nbRect', { x: r.left, y: r.top, w: r.width, h: r.height, open });
}
function nbFollow() { const end = performance.now() + 700; const step = () => { nbReport(); if (performance.now() < end) requestAnimationFrame(step); }; requestAnimationFrame(step); }
function appNotebook(m) {
  if (m.openID && m.openID !== appState.notebookId) { appState.notebookId = m.openID; $('memWin').classList.remove('open'); $('nbWin').classList.add('open'); }
}
function appConfirm(c) {
  appState.confirmId = c.id || null;
  if (!c.id) { $('toast').classList.remove('open'); return; }
  $('toast').querySelector('span').textContent = c.text; $('toast').classList.add('open');
}
window.creatorApp = {
  receive(m) {
    try {
      if (m.type === 'state') appStateMsg(m);
      else if (m.type === 'data') appData(m);
      else if (m.type === 'practice') appPractice(m);
      else if (m.type === 'answer') appAnswer(m);
      else if (m.type === 'confirm') appConfirm(m);
      else if (m.type === 'terminal') appTerminal(m);
      else if (m.type === 'memory') appMemory(m);
      else if (m.type === 'notebook') appNotebook(m);
    } catch (e) { console.error('creatorApp', e); }
  },
};
if (APP) {
  lineEl.textContent = '';
  document.querySelector('.voice').addEventListener('click', () => post('voice'));
  $('memList').addEventListener('click', (e) => { const b = e.target.closest('[data-id]'); if (b) post('memoryNote', { id: b.dataset.id }); });
  let memTimer;
  $('memQ').addEventListener('input', () => { clearTimeout(memTimer); memTimer = setTimeout(() => post('memorySearch', { text: $('memQ').value }), 250); });
  $('memObs').addEventListener('click', () => post('memoryObsidian'));
  $('memChoose').addEventListener('click', () => post('memoryChoose'));
  new MutationObserver(nbFollow).observe($('nbWin'), { attributes: true, attributeFilter: ['class'] });
  addEventListener('resize', nbReport);
  document.querySelector('#edWin .file').addEventListener('click', () => post('practiceEdit'));
  document.querySelector('#edWin pre.code').addEventListener('dblclick', () => post('practiceEdit'));
  $('pop').addEventListener('click', (e) => { const r = e.target.closest('[data-path]'); if (r) post('reveal', { path: r.dataset.path }); });
  // Esc on an empty HUD hides the overlay (seen before the page closes its windows). / Esc на пустом HUD прячет оверлей.
  addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && ($('memWin').classList.contains('open') || $('nbWin').classList.contains('open'))) {
      $('memWin').classList.remove('open'); $('nbWin').classList.remove('open'); e.stopImmediatePropagation(); return;
    }
    if (e.key === 'Escape' && !$('edWin').classList.contains('open') && !$('exWin').classList.contains('open') && !popOpen
        && !$('bc').classList.contains('tools') && document.activeElement !== $('ask')) post('dismiss');
  }, true);
  addEventListener('keydown', (e) => {
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'r' && $('edWin').classList.contains('open')) { e.preventDefault(); post('practiceRun'); }
  });
}

