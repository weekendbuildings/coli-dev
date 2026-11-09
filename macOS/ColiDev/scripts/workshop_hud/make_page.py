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
