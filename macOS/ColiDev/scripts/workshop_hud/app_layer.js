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
  if (p.openID && p.openID !== appState.practiceId) { appState.practiceId = p.openID; setWin('exWin', false); setWin('edWin', true); }
  document.querySelector('#edWin .file').textContent = p.file;
  document.querySelector('#edWin pre.code').innerHTML = p.code;
  $('outText').textContent = p.out; $('outOk').textContent = p.ok; $('outOk').classList.toggle('ok', !!p.good);
}
function appAnswer(a) {
  $('exTitle').textContent = a.title;
  Object.keys(exViews).forEach((k) => delete exViews[k]);
  exViews[t('hud.ex.answer', 'Ответ')] = a.html;
  // Слайды, 3D, Видео, Практика — из ответа и темы, без отдельной генерации. / Views from the answer and the topic.
  const slides = slidesFrom(a.html);
  if (slides.length > 1) exViews[t('hud.ex.slides', 'Слайды')] = slidesHTML(slides);
  const ex = a.explain || {};
  if (ex.template || ex.lesson) {
    exViews['3D'] = (ex.template ? `<div class="three3d" data-t="${esc(ex.template)}"></div><p class="hint">${esc(t('hud.ex.three.' + ex.template))}</p>` : '')
      + (ex.lesson ? `<button class="pill light" type="button" data-act2="openLesson">${esc(t('hud.ex.openLesson'))} «${esc(ex.lesson)}»</button>` : '');
  }
  if ((ex.videos || []).length) {
    exViews[t('hud.ex.video', 'Видео')] = ex.videos.map((v) => `<button type="button" class="memi" data-video="${esc(v.id)}"><b>${esc(v.title)}</b><span>${esc(v.channel)}</span></button>`).join('');
  }
  exViews[t('hud.ex.practice', 'Практика')] = `<p>${esc(t('hud.ex.practiceText'))}${ex.lesson ? ' «' + esc(ex.lesson) + '»' : ''}.</p><button class="pill light" type="button" data-act2="practiceTopic">${esc(t('hud.ex.practiceOpen'))}</button>`;
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
  document.querySelector('#nbWin .wh b').textContent = m.title || 'NotebookLM';
  if (m.openID && m.openID !== appState.notebookId) { appState.notebookId = m.openID; $('memWin').classList.remove('open'); $('nbWin').classList.add('open'); }
}
/* Слайды: каждый абзац или блок ответа — шаг; ‹ › и стрелки. / Each block of the answer is a step. */
function slidesFrom(html) {
  const box = document.createElement('div'); box.innerHTML = html;
  const out = []; let pending = '';
  [...box.children].forEach((el) => {
    const isHead = el.tagName === 'P' && el.children.length === 1 && el.firstElementChild.tagName === 'B' && el.textContent.length < 80;
    if (isHead) { pending += el.outerHTML; return; }
    out.push(pending + el.outerHTML); pending = '';
  });
  if (pending) out.push(pending);
  return out;
}
function slidesHTML(slides) {
  return `<div class="slides" data-i="0">${slides.map((s, i) => `<div class="slide"${i ? ' hidden' : ''}>${s}</div>`).join('')}`
    + `<div class="snav"><button class="round" type="button" data-s="-1" aria-label="‹">‹</button><span>1 / ${slides.length}</span><button class="round" type="button" data-s="1" aria-label="›">›</button></div></div>`;
}
function slideStep(d) {
  const box = $('exBody').querySelector('.slides'); if (!box) return false;
  const all = box.querySelectorAll('.slide'); const i = Math.max(0, Math.min(all.length - 1, (+box.dataset.i) + d));
  box.dataset.i = i; all.forEach((s, k) => { s.hidden = k !== i; }); box.querySelector('.snav span').textContent = `${i + 1} / ${all.length}`;
  return true;
}
/* 3D: небольшие сцены three.js по теме. / Small three.js scenes by topic. */
function mount3D(host) {
  if (host.dataset.mounted) return; host.dataset.mounted = '1';
  const w = host.clientWidth || 440, h = 260;
  const r = new THREE.WebGLRenderer({ antialias: true, alpha: true }); r.setPixelRatio(Math.min(2, devicePixelRatio)); r.setSize(w, h); host.appendChild(r.domElement);
  const scene = new THREE.Scene(), cam = new THREE.PerspectiveCamera(45, w / h, 0.1, 100); cam.position.set(6, 5, 7); cam.lookAt(0, 0, 0);
  scene.add(new THREE.AmbientLight(0xffffff, 0.8)); const sun = new THREE.DirectionalLight(0xffffff, 0.9); sun.position.set(4, 8, 5); scene.add(sun);
  const kind = host.dataset.t; let ball = null, path = null;
  if (kind === 'surface') {
    const g = new THREE.PlaneGeometry(8, 8, 40, 40); g.rotateX(-Math.PI / 2);
    const p = g.attributes.position; for (let i = 0; i < p.count; i++) { const x = p.getX(i), z = p.getZ(i); p.setY(i, 0.12 * (x * x + 1.6 * z * z) - 1.5); }
    g.computeVertexNormals();
    scene.add(new THREE.Mesh(g, new THREE.MeshStandardMaterial({ color: 0x8a8fa8, roughness: 0.6, transparent: true, opacity: 0.75, side: THREE.DoubleSide })));
    scene.add(new THREE.LineSegments(new THREE.WireframeGeometry(g), new THREE.LineBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.12 })));
    ball = new THREE.Mesh(new THREE.SphereGeometry(0.16, 20, 20), new THREE.MeshStandardMaterial({ color: 0xffcf8a, emissive: 0x553300 })); scene.add(ball);
    path = { x: 3.4, z: -2.8 };
  } else if (kind === 'vectors') {
    const a = new THREE.Vector3(2.5, 1, 0.5), b = new THREE.Vector3(-0.5, 1.5, 2), o = new THREE.Vector3();
    [[a, 0xffcf8a], [b, 0x9ec4ff], [a.clone().add(b), 0x7cf5c8]].forEach(([v, c]) => scene.add(new THREE.ArrowHelper(v.clone().normalize(), o, v.length(), c, 0.3, 0.18)));
    scene.add(new THREE.GridHelper(8, 8, 0x444444, 0x2a2a2a));
  } else {
    const pts = []; for (let x = -4; x <= 4; x += 0.05) pts.push(new THREE.Vector3(x, 3 / (1 + Math.exp(-2 * x)) - 1.5, 0));
    scene.add(new THREE.Line(new THREE.BufferGeometry().setFromPoints(pts), new THREE.LineBasicMaterial({ color: 0xffcf8a })));
    scene.add(new THREE.GridHelper(8, 8, 0x444444, 0x2a2a2a)); cam.position.set(0, 1, 8);
  }
  let t0 = performance.now();
  const loop = () => {
    if (!host.isConnected) { r.dispose(); return; }
    const t = (performance.now() - t0) / 1000;
    if (kind !== 'function') scene.rotation.y = t * 0.25;
    if (ball && path) {
      path.x -= 0.24 * path.x * 0.04; path.z -= 0.38 * path.z * 0.04;
      if (Math.abs(path.x) + Math.abs(path.z) < 0.05) { path.x = 3.4; path.z = -2.8; }
      ball.position.set(path.x, 0.12 * (path.x * path.x + 1.6 * path.z * path.z) - 1.5 + 0.16, path.z);
    }
    r.render(scene, cam); requestAnimationFrame(loop);
  };
  loop();
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
  $('exBody').addEventListener('click', (e) => {
    const s = e.target.closest('[data-s]'); if (s) { slideStep(+s.dataset.s); return; }
    const v = e.target.closest('[data-video]'); if (v) { setWin('exWin', false); post('video', { id: v.dataset.video }); return; }
    const a = e.target.closest('[data-act2]'); if (a) post(a.dataset.act2);
  });
  new MutationObserver(() => { const host = $('exBody').querySelector('.three3d'); if (host) mount3D(host); }).observe($('exBody'), { childList: true });
  addEventListener('keydown', (e) => {
    if (!$('exWin').classList.contains('open') || document.activeElement === $('ask')) return;
    if (e.key === 'ArrowRight' && slideStep(1)) e.preventDefault();
    if (e.key === 'ArrowLeft' && slideStep(-1)) e.preventDefault();
  });
  // Как поповер macOS: щелчок мимо закрывает открытое окно, панель, карточку и док. / Click outside closes, like a popover.
  addEventListener('pointerdown', (e) => {
    const inside = (sel) => e.target.closest(sel);
    if (inside('#rail') || inside('#tip')) return;
    ['edWin', 'exWin', 'memWin', 'nbWin'].forEach((id) => { if ($(id).classList.contains('open') && !inside('#' + id)) setWin(id, false); });
    if (popOpen && !inside('#pop')) setPop(popOpen);
    if ($('card').classList.contains('open') && !inside('#card')) $('card').classList.remove('open');
    if ($('bc').classList.contains('tools') && !inside('#bc')) setTools(false);
  }, true);
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

