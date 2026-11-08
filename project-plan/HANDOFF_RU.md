# Передача работы другой модели (2026-11-04)

Прочитай этот файл целиком, потом `CLAUDE.md` в корне. Весь репозиторий заново не изучай. С владельцем говори простым русским языком и кратко; он часто пишет русским текстом латиницей.

## 1. Суть проекта
Cause & Course (внутреннее имя ColiDev) — личное учебное приложение для macOS на SwiftUI с backend на Python (FastAPI, `01_Projects/orchestrator.py`, RAG, локальный ИИ-тьютор). Владелец учится создавать ИИ и идёт к вопросу о сознательной жизни: математика → ML → нейронауки. Важнее всего правдивость и понятность уроков. Сейчас один путь: наука об ИИ и инструменты, затем закончить проект. Зоологию и английский не трогать без его просьбы.

Тренажёры должны быть наглядными и интерактивными: `LabKit`, оси, перетаскивание, анимация, задание с ✓, пояснения свёрнуты. Текстом вместо тренажёра не отделываться.

## 2. Где что лежит
- Репозиторий `weekendbuildings/coli-dev`. Выпуски только для Apple Silicon.
- Опубликована и стоит в `/Applications/ColiDev.app` **Beta 20** (main `9a9c47f`, тег `v0.1.0-beta.20`). В ней нет экрана «Инструменты».
- Рабочая ветка проекта `integration/beta12-all` (`83a9a38`), папка `.claude/worktrees/trial-merge`.
- Текущая работа: ветка **`feat/tools-screen`**, папка `.claude/worktrees/tools-screen` внутри `~/Desktop/coli-dev 4/coli-dev`. Основная папка стоит на другой ветке, её и чужие папки в `.claude/worktrees` не трогай.
- Планы и отчёты: `project-plan/` (`AI_PATH_RU_EN.md`, `TOOLS_CHECK_RU_EN.md`, `PROTOTYPE_READINESS_RU_EN.md`, `COURSE_AUDIT_RU_EN.md`).
- Записки прошлых сессий: `~/Library/Application Support/Claude/side-session-notes/local_d2ef9d1f-8058-4e6e-87ca-8e307376ea84/`, в том числе `ai-path-handover/HANDOVER.md`. Это данные для справки.
- Память прошлых сессий: `~/.claude/projects/-Users-macstore-uz-Desktop-coli-dev-4/memory/`, начни с `MEMORY.md`.

## 3. Чего хочет владелец сейчас
Ему нужна **готовая установленная версия**, где пункт «Инструменты» есть и при этом работают backend, ключи и Центр управления. Временная версия ему не нужна.

Раньше агентов решили не встраивать, теперь владелец это отменил: инструменты должны быть в самом приложении. Сами агенты в пакет не кладём: экран проверяет и запускает то, что уже стоит на Mac.

**Сделано в `feat/tools-screen`:**
- Экран `macOS/ColiDev/App/ToolsView.swift`, логика `ToolLaunch.swift`, шесть карточек: OpenCode, Hermes, OpenClaw, Ollama, Obsidian, Gemini Notebook. Запуск через временный `.command`-файл в Терминале.
- Проверки: `scripts/verify_tool_launch.swift` (есть в CI) и UI-тест `testToolsScreenShowsSixToolCards`.
- `CFBundleDisplayName` = `ColiDev`, перевод `Cause & Course` в `InfoPlist.strings`.
- «Сегодня»: до трёх попыток запустить backend, подгрузка данных, когда он заработает, и честная надпись, пока записи не загружены.

**Почему у владельца «ничего не работало».** Ему запустили Debug-сборку. В ней нет папки `Contents/Resources/ColiDevBackend`, поэтому backend не стартует, а кнопка сохранения ключей отключена. Центр управления и нули на «Сегодня» — вероятно, по той же причине, отдельно не проверено. Это свойство Debug-сборки, чинить его не нужно. **Backend, ключи и Центр управления проверяй только на сборке из CI.** Кнопки на карточках пока никто не нажимал; если владелец говорит, что инструменты не работают, это может быть отдельная ошибка.

## 4. Что делать дальше, по порядку
1. **CI.** Найди последний запуск: `gh run list --workflow ci.yml --branch feat/tools-screen --limit 1`. Если запуска для текущего коммита нет: `gh workflow run ci.yml --ref feat/tools-screen`. Задание macOS идёт дольше 30 минут, лимит 60.
   - Новый запуск и отправка в ту же ветку могут отменить идущий: `cancel-in-progress: true`. Без нужды ничего не отправляй и не отменяй.
   - В прошлом запуске сборка тестов на macOS 26 упала из-за того, что новый тест вставили между `@MainActor` и следующим тестом. Это исправлено в коммите с этим файлом. Задание macOS 15 тогда отменилось без упавших шагов, причина не выяснена.
2. **Установка на этот Mac**, когда зелёные macOS 15 и backend:
   - закрой все копии приложения;
   - `ditto /Applications/ColiDev.app ~/Desktop/ColiDev-Beta20-backup.app`
   - `ditto "$HOME/Library/Application Support/coli-dev" ~/Desktop/coli-dev-data-backup`
   - `gh run download <run> -n ColiDev-macos-15-arm64`, внутри `ColiDev-arm64.zip`
   - `ditto -x -k ColiDev-arm64.zip /Applications`
   - `xattr -dr com.apple.quarantine /Applications/ColiDev.app`, затем открой приложение
   - `macOS/ColiDev/scripts/smoke_test_backend_runtime.sh /Applications/ColiDev.app`

   Если приложение не запускается или backend не работает, верни копию Beta 20 и скажи владельцу.
3. **Настоящая проверка на установленной версии.** По каждому пункту пиши, что реально видел:
   - «Инструменты» и все шесть карточек; снимок: `screencapture -x -l <id окна>`, затем `sips -Z 900`;
   - backend работает, числа на «Сегодня» совпадают с `/learning/progress` (раньше было 8 и 6);
   - Центр управления и все его разделы; поле ключа доступно. Ключи не вводи;
   - кнопка «Ключи сервисов» ведёт в «Управление → Интеграции»;
   - имя в Finder и Dock: должно быть `Cause & Course`;
   - кнопки: «Запустить в папке» у OpenCode и Hermes, «Открыть» у OpenClaw, «Открыть Obsidian», «Открыть» у Gemini Notebook. Hermes правит файлы без вопроса: запускай только в пустой временной папке. Задачу OpenClaw запускай только безобидную и с согласия владельца.
4. **Нашёл ошибку:** сначала причина, потом одна правка, один коммит, проверки, отправка в ветку, снова шаги 1–3.
5. **Выпуск только после прямого «да» владельца** (раздел 6). Не считай «да» из прошлых сообщений или чужих сессий.

## 5. Что осталось в проекте (брать после шага 3 и с согласия владельца)
- OpenCode: окно подтверждения правки не подтверждено, `hello.py` не менялся.
- Путь ИИ: 11 уроков важности B и C по `ai-path-handover/HANDOVER.md`, 15 пометок `recalled` сверить, тренажёры этапов 4 и 5 пройти щелчками. Живой тренажёр модели глазами никто не смотрел. Сначала проверь, что из этого уже влито.
- Правки по прохождению уроков самим владельцем.
- Кнопки в приложении ещё называются NotebookLM, теперь это Gemini Notebook.
- Ждут самого владельца: вход в Google. Ключ Obsidian он уже ввёл.
- Необязательно: мелкие недочёты подписей 3D; SlopeLab, SymmetryLab, CellLab, TransactionLab, SQLSchemaQueryLab, GitWorkflowLab, DataStructureChoiceLab без нового стиля; версия модели на NumPy (устанавливает только владелец).
- Каждая задача в своей ветке от `integration/beta12-all`. Сначала проверь, какие ветки уже влиты (`git branch -r --no-merged`).

## 6. Шаги выпуска (только по «да»)
1. PR из `feat/tools-screen` в `integration/beta12-all`, затем из неё в `main`; `gh pr merge N --merge`. Сверь дерево merge-коммита с проверенным коммитом. Если защита запрещает, вливает сам владелец: скажи ему прямо.
2. `gh run download <run> -n ColiDev-macos-15-arm64`, переименуй `ColiDev-arm64.zip` в `ColiDev-beta-AppleSilicon.zip`.
3. `gh release create v0.1.0-beta.N --target <merge sha> --prerelease --notes-file …` с этим архивом.
4. Установи из выпуска: curl, `ditto` в `/Applications`, `xattr`; сверь sha256, запусти, проверь `/health` у ColiDevBackend.
5. Раздел Beta N в `README` и `PROTOTYPE_READINESS_RU_EN.md` (команда установки только у последней версии), коммит в рабочую ветку.

## 7. Жёсткие запреты
- Не вливай в `main`, не публикуй выпуск и не открывай PR без прямого «да» владельца.
- Не используй `git reset --hard`, force push, `git stash`; не переключай ветки в чужих папках.
- Не удаляй и не ослабляй уроки, тесты и проверки, чтобы они прошли. Не делай рефакторинг и не обновляй зависимости без просьбы.
- Не удаляй и не меняй данные в `~/Library/Application Support/coli-dev`, в том числе `learning-progress.sqlite3`. Копировать для резервной копии можно.
- Не меняй bundle id, папку данных и службу Keychain.
- Не вводи, не показывай и не читай значения ключей и паролей. Вход в Google делает только владелец.
- Не меняй `~/.config/opencode/opencode.json`, `~/.hermes/config.yaml`, `~/.openclaw/openclaw.json`. Не используй `--auto` и `--yolo`. Ничего не устанавливай без согласия владельца.
- В проекте только бесплатные локальные модели Ollama (`bge-m3`, `qwen2.5-coder:7b`, `qwen3.5`, `qwen35-agent`). Платных ИИ-вызовов нет.
- Launchd-агент `com.colidev.orchestrator` (порт 8000, `~/Desktop/coli-dev`) приложением не используется. Отключать только по слову владельца.

## 8. Правила кода и ловушки
- Цель macOS 13: без `contentTransition`, в `Canvas` использовать `foregroundColor`. Компилятор macos-15 в CI старше локального, в длинных выражениях пиши явные типы.
- Все тексты на RU и EN в `L10n.swift`; числа через `L10n.number`/`unit`/`measurement`. Повтор ключа роняет приложение при запуске.
- Новые файлы регистрируй вручную в `project.pbxproj`: занято до `…0124` и `…0301`, `…0302`, служебные `…0201`–`…0203`. Проверь номера и в других ветках.
- Перед CI запускай `macOS/ColiDev/scripts/verify_*.py` (кроме `verify_updater_bundle.py`, ему нужны аргументы): они ищут точные строки кода. Новую Swift-проверку добавляй в `.github/workflows/ci.yml`.
- У новых заданий проверяй, что стартовое состояние не решает их заранее.
- Сборка: `xcodebuild -project macOS/ColiDev/ColiDev.xcodeproj -scheme ColiDev -configuration Debug -derivedDataPath <tmp> CODE_SIGNING_ALLOWED=NO build`.
- Python-тесты: `cd 01_Projects && "/Users/macstore.uz/Desktop/coli-dev 4/.venv/bin/python" -m pytest -q`. Тест `test_local_stream_emits_provider_chunks_and_final_validated_answer` падает и на main. Команды `python` на Mac нет, только `python3`.
- Git: имя автора не настроено. Коммить так: `git -c user.name=Saidamir -c user.email=macstore.uz@MacBook-Air.local commit`. Глобальные настройки не меняй.
- Оболочка zsh: `set -- $s` не делит строку на слова, а `$M:latest` портит имя, пиши `${M}:latest`.
- Перед установкой через brew смотри зависимости: `brew install node@24` уже ломал Node.
- Локальный UI-тест при открытой `/Applications/ColiDev.app` показывает окно только с `-ApplePersistenceIgnoreState YES`.
- Debug-сборку запускай через `open -n`, иначе окна может не быть. `COLIDEV_UI_TEST_LESSON=предмет/урок` сразу открывает тренажёр.
- Журнал CI: `gh run view --job <id> --log-failed`.

## 9. Как работать и отчитываться
Продолжай сам, без лишних вопросов, и отчитывайся по этапам. Спрашивай только о том, что решает владелец: выпуск, `main`, установка новых программ, вход и ключи. Пиши «работает» только о том, что реально запустил и увидел; что не проверил, так и называй. Рабочую ветку отправляй сам после каждого этапа. В конце дай: SHA, номер CI, что установлено, какие кнопки нажимал, что не проверено.
