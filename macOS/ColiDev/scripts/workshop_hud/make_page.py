#!/usr/bin/env python3
"""Builds App/WorkshopHUD/index.html from the approved workshop design (one HTML page on Three.js 0.160).
Собирает App/WorkshopHUD/index.html из одобренного макета Мастерской (одна страница на Three.js 0.160).

The design stays as it is; the script only (1) points fonts and the importmap at files inside the app, so the page
works without a network, (2) adds the bridge to Swift (app_layer.js) and (3) keeps the demo for the browser only.
Each replacement must match exactly once, so a changed design fails loudly instead of half-working.
Макет не меняется; скрипт только (1) ведёт шрифты и importmap на файлы внутри приложения, чтобы страница работала
без сети, (2) добавляет мост со Swift (app_layer.js) и (3) оставляет демо только для браузера.
Каждая замена должна совпасть ровно один раз: изменённый макет даёт ошибку, а не полуработающую страницу.

Usage / запуск:
    python3 -I macOS/ColiDev/scripts/workshop_hud/make_page.py [design.html]
Default design: ~/.creator-preview/workshop.html. Then run scripts/verify_workshop_hud.swift.
"""
import os
import sys

here = os.path.dirname(os.path.abspath(__file__))
src = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser('~/.creator-preview/workshop.html')
dst = os.path.join(here, '..', '..', 'App', 'WorkshopHUD', 'index.html')
layer = os.path.join(here, 'app_layer.js')
s = open(src, encoding='utf-8').read()

def rep(old, new, count=1):
    global s
    n = s.count(old)
    assert n == count, (n, old[:80])
    s = s.replace(old, new)

s = '<!doctype html>\n' + s
rep('<link rel="preconnect" href="https://fonts.googleapis.com">\n<link href="https://fonts.googleapis.com/css2?family=Onest:wght@300;400;500;600;700&amp;family=JetBrains+Mono:wght@400;500&amp;display=swap" rel="stylesheet">',
    '<!-- Шрифты лежат рядом, без сети. / Fonts ship next to the page, no network. -->\n<link rel="stylesheet" href="fonts/fonts.css">')
rep('\n</style>\n\n<canvas id="scene"', '''
/* В приложении длинный ответ и код прокручиваются внутри окон; цвет комментария в коде.
   In the app long answers and code scroll inside their windows; comment colour in code. */
html.app .exb { max-height: max(120px, min(46vh, 420px, calc(100vh - 480px))); overflow-y: auto; overscroll-behavior: contain; }
html.app #edWin pre.code { max-height: min(38vh, 340px); overflow: auto; }
html.app .exb code { font: 400 12.5px var(--mono); color: #ffcf8a; }
html.app #edWin .file, html.app .voice, html.app .plist [data-path] { cursor: pointer; }
pre.code .c { color: #6d6762; }
/* Одно название: «Мастерская Творца» / "Creator Workshop", без подзаголовка. / One title, no subtitle. */
html.app .wm-sub { display: none; }
html.app .wm { text-transform: uppercase; }
/* Строка под ядром — не больше трёх строк и не просвечивает сквозь открытые окна. / The line stays short and never shows through windows. */
html.app #line { display: -webkit-box; -webkit-box-orient: vertical; -webkit-line-clamp: 3; overflow: hidden; max-width: min(560px, 46vw); }
html.app .hud:has(#exWin.open) #line, html.app .hud:has(#edWin.open) #line { opacity: 0; }
html.app #line { transition: opacity .3s ease; }
/* Вкладки карточки — вертикально на её краю; свёрнутая карточка — только эта полоса. / Vertical tabs on the card's edge. */
html.app .card { display: flex; flex-direction: row-reverse; align-items: flex-start; width: auto; }
html.app .card .row1 { flex: none; }
html.app .card .seg { flex-direction: column; width: auto; gap: 3px; }
/* Кнопки вкладок стоят столбиком: значок и обычная горизонтальная подпись. / A column of buttons with plain labels. */
html.app .card .seg button { flex: none; display: flex; align-items: center; gap: 8px; height: 34px; padding: 0 12px 0 10px; text-align: left; white-space: nowrap; }
html.app .card .seg button::before { content: ""; width: 15px; height: 15px; flex: none; background: currentColor; }
html.app .card .seg button[data-v="agents"]::before { -webkit-mask: url("data:image/svg+xml,%3Csvg%20xmlns%3D%27http%3A//www.w3.org/2000/svg%27%20viewBox%3D%270%200%2024%2024%27%20fill%3D%27none%27%20stroke%3D%27black%27%20stroke-width%3D%272%27%20stroke-linecap%3D%27round%27%3E%3Ccircle%20cx%3D%279%27%20cy%3D%279%27%20r%3D%273%27/%3E%3Cpath%20d%3D%27M3.5%2019a5.5%205.5%200%200%201%2011%200%27/%3E%3Ccircle%20cx%3D%2717%27%20cy%3D%2710%27%20r%3D%272.4%27/%3E%3Cpath%20d%3D%27M15.5%2014.6A4.5%204.5%200%200%201%2021%2019%27/%3E%3C/svg%3E") center / contain no-repeat; }
html.app .card .seg button[data-v="council"]::before { -webkit-mask: url("data:image/svg+xml,%3Csvg%20xmlns%3D%27http%3A//www.w3.org/2000/svg%27%20viewBox%3D%270%200%2024%2024%27%20fill%3D%27none%27%20stroke%3D%27black%27%20stroke-width%3D%272%27%20stroke-linecap%3D%27round%27%3E%3Cpath%20d%3D%27M4%2020V10M10%2020V4M16%2020v-7M22%2020H2%27/%3E%3C/svg%3E") center / contain no-repeat; }
html.app .card .seg button[data-v="rem"]::before { -webkit-mask: url("data:image/svg+xml,%3Csvg%20xmlns%3D%27http%3A//www.w3.org/2000/svg%27%20viewBox%3D%270%200%2024%2024%27%20fill%3D%27none%27%20stroke%3D%27black%27%20stroke-width%3D%272%27%20stroke-linecap%3D%27round%27%3E%3Cpath%20d%3D%27M6%2016v-5a6%206%200%200%201%2012%200v5l1.5%202h-15z%27/%3E%3Cpath%20d%3D%27M10%2020.5a2%202%200%200%200%204%200%27/%3E%3C/svg%3E") center / contain no-repeat; }

html.app .card .body { grid-template-rows: 1fr; width: 0; max-height: 0; transition: width .55s cubic-bezier(.2,.8,.2,1), max-height .55s cubic-bezier(.2,.8,.2,1), opacity .3s ease; }
html.app .card.open .body { width: 300px; max-height: calc(100vh - 300px); transition: width .55s cubic-bezier(.2,.8,.2,1), max-height .55s cubic-bezier(.2,.8,.2,1), opacity .45s ease .1s; }
/* Память и NotebookLM — большие стеклянные панели внутри HUD (только в приложении).
   Memory and NotebookLM — large glass panels inside the HUD (app only). */
.appwin { display: none; }
html.app .appwin { display: flex; flex-direction: column; top: 96px; bottom: calc(176px + env(safe-area-inset-bottom, 0px)); left: calc(var(--side) + 88px); right: calc(var(--side-r) + 88px); width: auto; }
.hud:has(.appwin.open) #say { opacity: 0; transition: opacity .3s ease; }
.memgrid { display: grid; grid-template-columns: minmax(200px, 280px) 1fr; gap: 14px; flex: 1; min-height: 0; }
.memside { display: flex; flex-direction: column; gap: 8px; min-height: 0; }
.memside input { height: 36px; border-radius: 12px; border: 1px solid rgba(255,255,255,.14); background: rgba(0,0,0,.25); color: var(--fg); padding: 0 12px; font: inherit; }
#memList { overflow-y: auto; display: grid; gap: 2px; align-content: start; }
.memi { text-align: left; border: 0; background: none; color: var(--fg); padding: 7px 10px; border-radius: 10px; cursor: pointer; }
.memi b { display: block; font-weight: 500; font-size: 13.5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.memi span { display: block; font-size: 12px; color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.memi:hover, .memi.on { background: rgba(255,255,255,.08); }
html.app #memBody { max-height: none; overflow-y: auto; min-height: 0; padding-right: 6px; }
#nbBody { flex: 1; min-height: 0; border-radius: 16px; background: rgba(0,0,0,.28); }
</style>

<canvas id="scene"''')
rep('<script type="importmap">{"imports":{"three":"https://cdn.jsdelivr.net/npm/three@0.160.0/build/three.module.js","three/addons/":"https://cdn.jsdelivr.net/npm/three@0.160.0/examples/jsm/"}}</script>',
    '<script type="importmap">{"imports":{"three":"./vendor/three/build/three.module.js","three/addons/":"./vendor/three/examples/jsm/"}}</script>')
rep("const isNarrow = () => innerWidth < 900;\n", """const isNarrow = () => innerWidth < 900;
/* Мост с приложением: в WKWebView ответы, данные и состояния приходят из Swift, демо выключено.
   Bridge to the app: in the WKWebView answers, data and states come from Swift, the demo is off. */
const bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.workshop;
const APP = !!bridge;
const post = (type, body) => { if (bridge) bridge.postMessage(Object.assign({ type }, body || {})); };
let T = {};
const t = (k, d) => T[k] || d || '';
if (APP) document.documentElement.classList.add('app');
""")
rep('  <div class="bc" id="bc">', '  <!-- Память и NotebookLM: панели приложения. / App-only panels. -->\n  <section class="win gl appwin" id="memWin" data-bezel="16" data-blur="20" data-fade aria-label="Память">\n    <div class="wh"><b id="memTitle">Память</b><span class="file" id="memVault"></span><button class="round" type="button" data-close="memWin" aria-label="Закрыть"><svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg></button></div>\n    <div class="memgrid"><div class="memside"><input id="memQ" placeholder="Поиск" aria-label="Поиск"><div id="memList"></div></div><div class="exb" id="memBody"></div></div>\n    <div class="wa"><button class="pill light" type="button" id="memObs">Открыть в Obsidian</button><button class="pill" type="button" id="memChoose">Папка хранилища…</button></div>\n  </section>\n  <section class="win gl appwin" id="nbWin" data-bezel="16" data-blur="20" data-fade aria-label="NotebookLM">\n    <div class="wh"><b>NotebookLM</b><button class="round" type="button" data-close="nbWin" aria-label="Закрыть"><svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6L6 18"/></svg></button></div>\n    <div id="nbBody"></div>\n  </section>\n\n' + '  <div class="bc" id="bc">')
rep("const fmtTime = new Intl", "let fmtTime = new Intl")
rep("const fmtDay = new Intl", "let fmtDay = new Intl")
rep("if (v === 'rem') $('remBreak')", "if (v === 'rem' && $('remBreak')) $('remBreak')")
rep("""Object.keys(exViews).forEach((name, i) => {
  const b = document.createElement('button');
  b.type = 'button'; b.setAttribute('role', 'tab'); b.textContent = name; b.setAttribute('aria-selected', String(i === 0));
  b.addEventListener('click', () => { [...$('tabs').children].forEach((x) => x.setAttribute('aria-selected', String(x === b))); $('exBody').innerHTML = exViews[name]; });
  $('tabs').appendChild(b);
});
$('exBody').innerHTML = exViews['Слайды'];""", """let exSel = null;
function buildTabs() {
  const names = Object.keys(exViews);
  if (!names.includes(exSel)) exSel = names[0];
  $('tabs').replaceChildren();
  names.forEach((name) => {
    const b = document.createElement('button');
    b.type = 'button'; b.setAttribute('role', 'tab'); b.textContent = name; b.setAttribute('aria-selected', String(name === exSel));
    b.addEventListener('click', () => { exSel = name; [...$('tabs').children].forEach((x) => x.setAttribute('aria-selected', String(x === b))); $('exBody').innerHTML = exViews[name]; });
    $('tabs').appendChild(b);
  });
  $('exBody').innerHTML = exViews[exSel];
}
buildTabs();""")
rep("""function ask(q) {
  lastAct = performance.now();
""", """function ask(q) {
  lastAct = performance.now();
  if (APP) { post('ask', { text: q }); return; }
""")
rep("""$('run').addEventListener('click', () => {
""", """$('run').addEventListener('click', () => {
  if (APP) { post('practiceRun'); return; }
""")
rep("""$('check').addEventListener('click', () => {
""", """$('check').addEventListener('click', () => {
  if (APP) { post('practiceCheck'); return; }
""")
rep("""  lastAct = performance.now(); const act = b.dataset.act;
""", """  lastAct = performance.now(); const act = b.dataset.act;
  if (APP) {
    post('rail', { act });
    if (act === 'new') { $('ask').value = t('hud.newProject'); $('ask').focus(); clearInterval(typing); lineEl.textContent = t('hud.newProject.say', railSay.new); return; }
    if (act === 'notes') return; // «Память» opens in the app. / «Память» открывается в приложении.
  }
""")
rep("""document.querySelectorAll('.dock .tile').forEach((b) => b.addEventListener('click', () => { lastAct = performance.now(); """,
    """document.querySelectorAll('.dock .tile').forEach((b) => b.addEventListener('click', () => { lastAct = performance.now(); if (APP) { if (typeof setTools === 'function') setTools(false); post('tool', { tool: b.dataset.tool }); return; } """)
rep("""  $('toast').classList.remove('open'); lastAct = performance.now();
""", """  $('toast').classList.remove('open'); lastAct = performance.now();
  if (APP) { post('confirm', { id: appState.confirmId, yes: b.dataset.ans === 'yes' }); return; }
""")
rep("""  const v = $('note').value.trim(); $('note').value = '';
""", """  const v = $('note').value.trim(); $('note').value = '';
  if (APP) { post('task', { text: v }); return; }
""")
demo_start = s.index('const demo = [')
demo_end = s.index('/* ---------- Кольцо голоса')
demo = s[demo_start:demo_end]
app_layer = open(layer, encoding='utf-8').read()
s = s[:demo_start] + "// Демо и автопоказ подтверждения — только вне приложения. / Demo and the auto-shown confirmation run only outside the app.\nif (!APP) {\n" + ''.join('  ' + l if l.strip() else l for l in demo.splitlines(True)) + "}\n\n" + app_layer + "\n" + s[demo_end:]
rep("requestAnimationFrame(frame);\n</script>", "requestAnimationFrame(frame);\nif (APP) post('ready');\n</script>")
open(dst, 'w', encoding='utf-8').write(s)
print('ok', os.path.normpath(dst), len(s))
