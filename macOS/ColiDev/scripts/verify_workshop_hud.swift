import Foundation

// Checks the workshop HUD: the core state, page messages, answer text, HTML, safe file paths, and the page itself
// (no network, the local Three.js is complete, the demo is off in the app, every string exists in L10n).
// Проверка HUD Мастерской: состояние ядра, сообщения страницы, текст ответа, HTML, безопасные пути и сама страница
// (без сети, локальный Three.js полный, демо в приложении выключено, все строки есть в L10n).

var failures = 0
func check(_ condition: Bool, _ message: String) {
    if !condition {
        failures += 1
        print("✗ " + message)
    }
}

@main
struct VerifyWorkshopHUD {
    static func main() {
        coreState()
        messages()
        text()
        html()
        paths()
        summon()
        elevenLabs()
        memory()
        page()
        if failures > 0 {
            print("\(failures) check(s) failed / проверок не прошло: \(failures)")
            exit(1)
        }
        print("✓ Workshop HUD / HUD Мастерской")
    }

    static func coreState() {
        check(HUDActivity().mode == .listen, "idle core listens / в покое ядро слушает")
        check(HUDActivity(isAnswering: true).mode == .think, "no text yet → think / нет текста → думает")
        check(HUDActivity(isAnswering: true, answerHasText: true).mode == .speak, "streaming → speak / текст идёт → отвечает")
        check(HUDActivity(isListening: true, isAnswering: true, answerHasText: true).mode == .listen, "listening wins / слушание важнее")
        check(HUDActivity(agentsWorking: true).mode == .agents, "agents at work / агенты работают")
        check(HUDActivity(isAnswering: true, agentsWorking: true).mode == .think, "the answer wins over agents / ответ важнее агентов")
        check(HUDActivity(showsFinishedAnswer: true, agentsWorking: true).mode == .speak, "a fresh answer is shown / свежий ответ показывается")
        check(HUDActivity.readingSeconds("один") == 3, "reading time at least 3 s / не меньше 3 с")
        check(HUDActivity.readingSeconds(String(repeating: "слово ", count: 400)) == 12, "reading time at most 12 s / не больше 12 с")
    }

    static func messages() {
        check(HUDInbound.parse(["type": "ready"]) == .ready, "ready")
        check(HUDInbound.parse(["type": "ask", "text": "  Что такое якобиан?  "]) == .ask("Что такое якобиан?"), "ask is trimmed / вопрос обрезан по краям")
        check(HUDInbound.parse(["type": "ask", "text": "   "]) == nil, "empty question dropped / пустой вопрос отброшен")
        check(HUDInbound.parse(["type": "ask", "text": 5]) == nil, "wrong field type dropped / неверный тип отброшен")
        if case .ask(let long)? = HUDInbound.parse(["type": "ask", "text": String(repeating: "я", count: 9000)]) {
            check(long.count == HUDInbound.maxText, "long text is cut / длинный текст обрезан")
        } else {
            check(false, "long question still parses / длинный вопрос разбирается")
        }
        check(HUDInbound.parse(["type": "rail", "act": "path"]) == .rail("path"), "rail path")
        check(HUDInbound.parse(["type": "rail", "act": "rm -rf"]) == nil, "unknown rail dropped / неизвестная кнопка отброшена")
        check(HUDInbound.parse(["type": "tool", "tool": "oll"]) == .tool("oll"), "tool oll")
        check(HUDInbound.parse(["type": "tool", "tool": "safari"]) == nil, "unknown tool dropped / неизвестный инструмент отброшен")
        check(HUDInbound.parse(["type": "confirm", "id": "A", "yes": true]) == .confirm(id: "A", yes: true), "confirm yes")
        check(HUDInbound.parse(["type": "confirm", "id": "A", "yes": "true"]) == nil, "confirm needs a real bool / нужен настоящий bool")
        check(HUDInbound.parse(["type": "task"]) == .task(""), "empty task asks for text / пустая задача просит текст")
        check(HUDInbound.parse(["type": "eval", "code": "1"]) == nil, "unknown type dropped / неизвестный тип отброшен")
        check(HUDInbound.parse("ask") == nil, "not a dictionary / не словарь")
        check(HUDInbound.councilQuestion("Совет: что лучше, LoRA или полное обучение?") == "что лучше, LoRA или полное обучение?", "council prefix ru")
        check(HUDInbound.councilQuestion("council: which optimizer?") == "which optimizer?", "council prefix en")
        check(HUDInbound.councilQuestion("совет:") == nil, "empty council question / пустой вопрос совету")
        check(HUDInbound.councilQuestion("Дай совет: как учиться") == nil, "only a leading prefix / только приставка в начале")
        check(HUDTool.agentID("open") == "opencode" && HUDTool.agentID("obs") == nil, "dock tiles map to agents / плитки и агенты")
        check(HUDTool.tile(ofAgent: "openclaw") == "claw", "agents map back to tiles / агенты и плитки")
    }

    static func text() {
        check(HUDText.line("Коротко.") == "Коротко.", "short answer unchanged / короткий ответ без изменений")
        let markdown = "## Якобиан\n\n**Якобиан** — таблица производных. См. [урок](https://example.com).\n\n```python\nprint(1)\n```"
        let plain = HUDText.plain(markdown)
        check(plain == "Якобиан Якобиан — таблица производных. См. урок.", "markdown made plain / Markdown без разметки: \(plain)")
        let long = String(repeating: "Первое предложение про градиент. ", count: 12)
        let line = HUDText.line(long)
        check(line.count <= 220 && line.hasSuffix("."), "long answer ends on a sentence / длинный ответ кончается предложением")
        let words = String(repeating: "слово ", count: 80)
        check(HUDText.line(words).hasSuffix("…") && HUDText.line(words).count <= 221, "no sentence end → word cut with … / обрезка по слову")
        check(HUDText.needsWindow(markdown), "code needs the window / код открывает окно")
        check(!HUDText.needsWindow("Да."), "a short answer stays in the line / короткий ответ остаётся в строке")
        check(HUDText.short("абв\nгде", limit: 4) == "абв…", "short text is one line / одна строка")
        check(HUDText.withoutActions("Готово.\n```action\n{\"tool\": \"open\"}\n```\nДальше.") == "Готово.\n\nДальше."
              && HUDText.withoutActions("Сейчас.\n```action\n{\"tool\":") == "Сейчас.", "action blocks hidden while streaming / действия скрыты")
        check(HUDText.outputLine("1 2 3\n2 4 6\n\n3 6 9\n") == "1 2 3 · 2 4 6 · 3 6 9", "output in the design's style / вывод в стиле макета")
        let tasks = HUDTask.adding("Повторить циклы", to: [], at: Date())
        check(tasks.count == 1 && HUDTask.adding("  ", to: tasks, at: Date()).count == 1, "empty task ignored / пустая задача не пишется")
        let many = (0..<40).reduce([HUDTask]()) { HUDTask.adding("t\($1)", to: $0, at: Date()) }
        check(many.count == HUDTask.limit && many.first?.text == "t39", "tasks kept newest first, limited / новые сверху, с пределом")
    }

    static func html() {
        check(HUDHTML.escape("<script>\"x\" & 'y'") == "&lt;script&gt;&quot;x&quot; &amp; &#39;y&#39;", "escape")
        let answer = HUDHTML.answer("Привет <b>\n\n- пункт **важно**\n\n```\nif a < b:\n    pass\n```")
        check(answer.contains("<p>Привет &lt;b&gt;</p>"), "paragraph escaped / абзац экранирован: \(answer)")
        check(answer.contains("<p>• пункт <b>важно</b></p>"), "list item with bold / пункт списка")
        check(answer.contains("<pre class=\"code\"><span class=\"l\">if a &lt; b:</span><span class=\"l\">    pass</span></pre>"), "code block / блок кода")
        check(!HUDHTML.answer("<img src=x onerror=alert(1)>").contains("<img"), "no raw HTML from the model / без сырого HTML модели")
        let source = "for i in range(3):\n    print(\"<\", i)  # x\n"
        let tokens: [(kind: String, range: NSRange)] = [
            ("keyword", NSRange(location: 0, length: 3)), ("keyword", NSRange(location: 6, length: 2)),
            ("builtin", NSRange(location: 9, length: 5)), ("number", NSRange(location: 15, length: 1)),
            ("builtin", NSRange(location: 23, length: 5)), ("string", NSRange(location: 29, length: 3)),
            ("comment", NSRange(location: 38, length: 3)),
        ]
        let code = HUDHTML.python(source, tokens: tokens)
        check(code.components(separatedBy: "<span class=\"l\">").count - 1 == 2, "one span.l per line / по span.l на строку: \(code)")
        check(code.hasPrefix("<span class=\"l\"><span class=\"k\">for</span> i <span class=\"k\">in</span> <span class=\"f\">range</span>(<span class=\"nm\">3</span>):</span>"),
              "design colour classes / классы цвета макета: \(code)")
        check(code.contains("<span class=\"s\">&quot;&lt;&quot;</span>") && code.contains("<span class=\"c\"># x</span>"), "strings and comments escaped / строки и комментарии")
        check(HUDHTML.python("a\nb\nc\nd", tokens: [], maxLines: 2).components(separatedBy: "span class=\"l\"").count - 1 == 2, "line limit / предел строк")
        check(HUDHTML.python("", tokens: []).isEmpty, "empty file / пустой файл")
        guard let script = HUDScript.receive(HUDStateMessage(mode: .speak, line: "а\u{2028}б </script>")) else {
            check(false, "state encodes / состояние кодируется")
            return
        }
        check(script.hasPrefix("window.creatorApp && window.creatorApp.receive({"), "script calls the page / скрипт зовёт страницу")
        check(script.contains("\"mode\":\"speak\"") && script.contains("\\u2028") && !script.contains("\u{2028}"), "JSON safe for JavaScript / безопасный JSON")
        check(HUDScript.receive(HUDConfirmMessage(id: nil, text: "")).map { !$0.contains("\"id\"") } ?? false, "no id hides the bar / без id полоса скрыта")
    }

    static func summon() {
        check(HUDWakeWord.count(in: "Creator, объясни LoRA") == 1, "Creator heard / слово услышано")
        check(HUDWakeWord.count(in: "креатор… КРЕАТОР!") == 2, "any case, twice / любой регистр, дважды")
        check(HUDWakeWord.count(in: "Привет, Творец") == 1 && HUDWakeWord.count(in: "Путь Творца") == 0, "«Творец» yes, «Творца» no / форма слова")
        check(HUDWakeWord.count(in: "recreation creators") == 0, "only whole words / только целые слова")
        let t0 = Date(timeIntervalSince1970: 0)
        check(HUDVoiceTurn.ending(transcript: "", started: t0, lastChange: t0, now: t0.addingTimeInterval(2)) == nil, "wait for words / ждём слов")
        check(HUDVoiceTurn.ending(transcript: "", started: t0, lastChange: t0, now: t0.addingTimeInterval(8)) == .cancel, "silence ends quietly / тишина — отмена")
        check(HUDVoiceTurn.ending(transcript: "что такое", started: t0, lastChange: t0.addingTimeInterval(3), now: t0.addingTimeInterval(4)) == nil, "still talking / ещё говорит")
        check(HUDVoiceTurn.ending(transcript: "что такое LoRA", started: t0, lastChange: t0.addingTimeInterval(3), now: t0.addingTimeInterval(5)) == .ask, "a pause sends / пауза отправляет")
        check(HUDVoiceTurn.ending(transcript: "долго", started: t0, lastChange: t0.addingTimeInterval(39.9), now: t0.addingTimeInterval(40)) == .ask, "a long turn is cut / долгий вопрос обрезается")
        let combos = HUDShortcut.all.map { "\($0.keyCode)-\($0.modifiers)" }
        check(Set(HUDShortcut.all.map(\.id)).count == HUDShortcut.all.count && Set(combos).count == combos.count, "presets unique / клавиши разные")
        check(!combos.contains("\(HUDShortcut.voice.keyCode)-\(HUDShortcut.voice.modifiers)"), "voice key kept apart / ⌃⌥V отдельно")
        check(HUDShortcut.find(nil).title == "⌃⌥T" && HUDShortcut.find("f13").keyCode == 0x69 && HUDShortcut.find("bad").id == "ctrl-opt-t", "default ⌃⌥T / по умолчанию ⌃⌥T")
    }

    static func elevenLabs() {
        check(ElevenLabsVoice.request(text: "Привет", voiceID: "", key: "") == nil, "no key → no request / без ключа запроса нет")
        guard let request = ElevenLabsVoice.request(text: "Привет", voiceID: "../evil?x=1", key: "k") else {
            check(false, "request with a key / запрос с ключом")
            return
        }
        check(request.url?.absoluteString == "https://api.elevenlabs.io/v1/text-to-speech/\(ElevenLabsVoice.defaultVoiceID)?output_format=mp3_44100_128",
              "bad voice ID falls back to the default / плохой ID голоса заменён: \(request.url?.absoluteString ?? "")")
        check(request.value(forHTTPHeaderField: "xi-api-key") == "k" && request.httpMethod == "POST", "key in the header only / ключ только в заголовке")
        check(!(request.url?.absoluteString.contains("k?") ?? true) && request.url?.query == "output_format=mp3_44100_128", "key never in the URL / ключа нет в адресе")
        let body = (try? JSONSerialization.jsonObject(with: request.httpBody ?? Data())) as? [String: String]
        check(body?["model_id"] == ElevenLabsVoice.model && body?["text"] == "Привет", "body / тело запроса")
        let long = String(repeating: "Предложение про градиент. ", count: 100)
        check(ElevenLabsVoice.spoken(long).count <= ElevenLabsVoice.maxCharacters && ElevenLabsVoice.spoken(long).hasSuffix("."), "quota guard / предел символов")
        check(ElevenLabsVoice.failure(status: 200, body: Data([1])) == nil, "audio plays / звук играет")
        check(ElevenLabsVoice.failure(status: 200, body: Data()) == .audio, "empty audio → Mac voice / пустой звук")
        check(ElevenLabsVoice.failure(status: 401, body: Data("{\"detail\":{\"status\":\"quota_exceeded\"}}".utf8)) == .quota, "401 quota_exceeded is the quota / лимит")
        check(ElevenLabsVoice.failure(status: 401, body: Data("{\"detail\":{\"status\":\"invalid_api_key\"}}".utf8)) == .key, "bad key / неверный ключ")
        check(ElevenLabsVoice.failure(status: 429, body: Data()) == .quota && ElevenLabsVoice.failure(status: 503, body: Data()) == .server, "429 and 5xx")
        check(ElevenLabsVoice.voiceID("pNInz6obpgDQGcFmaJgB") == "pNInz6obpgDQGcFmaJgB", "a real voice ID is kept / настоящий ID сохраняется")
        check(ElevenLabsVoice.voices.first?.name == "Daniel" && ElevenLabsVoice.defaultVoiceID == ElevenLabsVoice.voices[0].id
              && Set(ElevenLabsVoice.voices.map(\.id)).count == ElevenLabsVoice.voices.count, "Daniel by default, voices unique / Daniel по умолчанию")
        let pieces = ElevenLabsVoice.sentences("Да. Это градиент! Он показывает, куда расти функции быстрее всего, и поэтому обучение идёт против него. Вопросы?")
        check(pieces.count == 3 && pieces[0] == "Да. Это градиент!" && pieces[2] == "Вопросы?", "short sentences joined, long kept / предложения: \(pieces)")
        check(ElevenLabsVoice.sentences("без точки в конце") == ["без точки в конце"], "an unfinished sentence is kept / хвост без точки")
        check(ElevenLabsVoice.sentences(String(repeating: "Фраза номер один. ", count: 200)).joined(separator: " ").count <= ElevenLabsVoice.maxCharacters,
              "quota guard over all pieces / предел на весь ответ")
        let name = ElevenLabsVoice.cacheName(text: "Слушаю.", voiceID: "")
        check(name.count == 68 && name.hasSuffix(".mp3") && name == ElevenLabsVoice.cacheName(text: "Слушаю.", voiceID: ElevenLabsVoice.defaultVoiceID)
              && name != ElevenLabsVoice.cacheName(text: "Слушаю!", voiceID: ""), "cache name by voice, model and text / имя кэша")
        check(ElevenLabsVoice.language(of: "Это градиент.") == "ru" && ElevenLabsVoice.language(of: "We focus on module one.") == "en"
              && ElevenLabsVoice.language(of: "123 …") == nil && ElevenLabsVoice.language(of: "Модель GPT учится.") == "ru", "voice language per sentence / язык голоса")
        check(HUDWakeWord.count(in: "Tvorets, open") == 1, "en recognizer spelling of «Творец» / английское написание")
        check(ElevenLabsVoice.isCacheable("Слушаю.") && !ElevenLabsVoice.isCacheable(String(repeating: "a", count: 81)), "only short phrases cached / кэш только коротких")
    }

    static func memory() {
        check(MemoryVault.body("---\ntags: [a]\n---\n# Заголовок\nтекст") == "# Заголовок\nтекст", "front matter removed / шапка убрана")
        check(MemoryVault.body("# Без шапки") == "# Без шапки", "no front matter kept / без шапки как есть")
        check(MemoryVault.readable("См. [[Градиент]] и [[attention|внимание]], ![[img.png]]") == "См. **Градиент** и **внимание**, **img.png**", "wiki links readable / вики-ссылки")
        let url = MemoryVault.obsidianURL(path: "/Users/u/Творец/Заметка 1.md")?.absoluteString ?? ""
        check(url.hasPrefix("obsidian://open?path=") && !url.contains(" ") && url.contains("%D0%A2"), "Obsidian link encoded / ссылка закодирована: \(url)")
        check(MemoryVault.matches(query: "градиент спуск", name: "ml/Градиент.md", text: "Градиентный спуск — ...") && !MemoryVault.matches(query: "LoRA", name: "a.md", text: "b"), "search words / поиск")
        check(MemoryVault.isNote(relativePath: "ml/Заметка.md") && !MemoryVault.isNote(relativePath: ".obsidian/workspace.md") && !MemoryVault.isNote(relativePath: "a.png"), "notes only / только заметки")
    }

    static func paths() {
        let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("hud-check-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: root.appendingPathComponent("vendor"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        func file(_ text: String) -> URL? { HUDResource.file(for: URL(string: text)!, root: root) }
        check(file("creator://hud/index.html")?.lastPathComponent == "index.html", "page file / файл страницы")
        check(file("creator://hud/vendor/three/build/three.module.js") != nil, "nested file / вложенный файл")
        check(file("creator://hud/../secret.txt") == nil && file("creator://hud/vendor/../../x") == nil, "no way up / выхода вверх нет")
        check(file("creator://hud/%2E%2E/x") == nil, "no encoded way up / нет и в кодировке")
        check(file("creator://hud/.git/config") == nil, "no hidden files / скрытых файлов нет")
        check(file("creator://other/index.html") == nil && file("file:///etc/passwd") == nil, "only our scheme and host / только своя схема")
        check(file("creator://hud/") == nil, "no folder listing / без списка папки")
        check(HUDResource.mimeType(URL(fileURLWithPath: "/a/b.js")) == "text/javascript", "JavaScript MIME for modules / MIME модулей")
        check(HUDResource.mimeType(URL(fileURLWithPath: "/a/f.woff2")) == "font/woff2", "font MIME")
    }

    static func page() {
        let app = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("App")
        let folder = app.appendingPathComponent(HUDResource.folderName)
        guard let page = try? String(contentsOf: folder.appendingPathComponent("index.html"), encoding: .utf8) else {
            check(false, "WorkshopHUD/index.html exists / страница есть")
            return
        }
        // No network: only the SVG namespace may look like a URL. / Без сети: похожа на адрес только SVG-схема.
        let urls = (try? NSRegularExpression(pattern: "https?://[^\"' )]+"))?.matches(in: page, range: NSRange(page.startIndex..., in: page))
            .compactMap { Range($0.range, in: page).map { String(page[$0]) } } ?? []
        check(urls.allSatisfy { $0.hasPrefix("http://www.w3.org/2000/svg") }, "no network addresses in the page / адресов сети нет: \(urls.filter { !$0.contains("w3.org") })")
        check(page.contains("\"three\":\"./vendor/three/build/three.module.js\"") && page.contains("\"three/addons/\":\"./vendor/three/examples/jsm/\""),
              "importmap points to local files / importmap ведёт на локальные файлы")
        check(page.contains("href=\"fonts/fonts.css\""), "local fonts / локальные шрифты")
        if let demo = page.range(of: "const demo = ["), let guardStart = page.range(of: "if (!APP) {") {
            check(guardStart.lowerBound < demo.lowerBound && page.distance(from: guardStart.upperBound, to: demo.lowerBound) < 12,
                  "the demo runs only outside the app / демо только вне приложения")
        } else {
            check(page.contains("if (!APP) {"), "demo guard / защита демо")
        }
        check(!page.contains("classList.add('open'), 14000"), "no auto-shown confirmation / без автопоказа подтверждения")
        for needle in ["window.creatorApp = {", "post('ready')", "post('ask', { text: q })", "post('practiceRun')", "post('practiceCheck')",
                       "post('confirm'", "post('tool'", "post('task'", "messageHandlers.workshop"] {
            check(page.contains(needle), "bridge: \(needle) / мост")
        }

        // Every module import resolves to a file in the bundle. / Каждый импорт модуля ведёт к файлу.
        let three = folder.appendingPathComponent("vendor/three")
        var queue = ["examples/jsm/postprocessing/EffectComposer.js", "examples/jsm/postprocessing/RenderPass.js",
                     "examples/jsm/postprocessing/UnrealBloomPass.js", "examples/jsm/postprocessing/ShaderPass.js",
                     "examples/jsm/postprocessing/OutputPass.js"]
        check(FileManager.default.fileExists(atPath: three.appendingPathComponent("build/three.module.js").path), "three.module.js 0.160 is bundled / в ресурсах")
        var seen = Set<String>()
        let importPattern = try? NSRegularExpression(pattern: "from\\s+'(\\.{1,2}/[^']+)'")
        while let relative = queue.popLast() {
            guard seen.insert(relative).inserted else { continue }
            let url = three.appendingPathComponent(relative)
            guard let source = try? String(contentsOf: url, encoding: .utf8) else {
                check(false, "missing \(relative) / нет файла")
                continue
            }
            for match in importPattern?.matches(in: source, range: NSRange(source.startIndex..., in: source)) ?? [] {
                guard let range = Range(match.range(at: 1), in: source) else { continue }
                let target = url.deletingLastPathComponent().appendingPathComponent(String(source[range])).standardizedFileURL.path
                queue.append(String(target.dropFirst(three.standardizedFileURL.path.count + 1)))
            }
        }
        if let fonts = try? String(contentsOf: folder.appendingPathComponent("fonts/fonts.css"), encoding: .utf8) {
            let files = (try? NSRegularExpression(pattern: "url\\('?([^')]+)'?\\)"))?.matches(in: fonts, range: NSRange(fonts.startIndex..., in: fonts))
                .compactMap { Range($0.range(at: 1), in: fonts).map { String(fonts[$0]) } } ?? []
            check(!files.isEmpty, "fonts.css lists fonts / шрифты перечислены")
            for name in files {
                check(FileManager.default.fileExists(atPath: folder.appendingPathComponent("fonts").appendingPathComponent(name).path), "font \(name) / шрифт")
            }
            check(fonts.contains("Onest") && fonts.contains("JetBrains Mono"), "both design fonts / оба шрифта макета")
        } else {
            check(false, "fonts/fonts.css exists / есть")
        }

        // Strings: every key exists once in L10n. / Строки: каждый ключ есть в L10n ровно один раз.
        guard let l10n = try? String(contentsOf: app.appendingPathComponent("L10n.swift"), encoding: .utf8) else {
            check(false, "L10n.swift readable / читается")
            return
        }
        var keys = HUDStrings.pageKeys
        for source in [page, (try? String(contentsOf: app.appendingPathComponent("WorkshopHUDView.swift"), encoding: .utf8)) ?? ""] {
            let found = (try? NSRegularExpression(pattern: "[\"'](hud\\.[A-Za-z.]+[A-Za-z])[\"']"))?.matches(in: source, range: NSRange(source.startIndex..., in: source))
                .compactMap { Range($0.range(at: 1), in: source).map { String(source[$0]) } } ?? []
            keys += found
        }
        keys += ["claude", "opencode", "hermes", "openclaw", "freebuff"].map { "hud.agent.\($0)" }
        for key in Set(keys) {
            let count = l10n.components(separatedBy: "\"\(key)\": (").count - 1
            check(count == 1, "L10n key \(key) appears \(count) time(s) / ключ встречается \(count) раз")
        }
    }
}
