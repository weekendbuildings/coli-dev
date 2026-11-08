# ColiDev — заметки для Claude Code

Личное учебное приложение для macOS. В нём курсы по математике, физике, биологии, программированию и ML с интерактивными тренажёрами и локальным ИИ-тьютором с RAG. Цель владельца — глубоко понять основы (математика → ML → нейронауки) и стать создателем ИИ. Поэтому главное — достоверность и понятность уроков.

## Правила
- В `main` ничего не сливать и никуда не отправлять (push, PR, публикации) без явного «да» владельца.
- Платные ИИ-вызовы не делать, ключи не показывать. Для проверок использовать только локальные модели Ollama: `bge-m3`, `qwen2.5-coder:7b`, `qwen3.5`.
- Работать в отдельной ветке и сразу писать тесты. Комментарии и тексты — на двух языках, RU и EN.
- Экономить токены. Не изучать весь репозиторий заново: сначала этот файл, потом нужные файлы точечно. Скриншоты делать только для проверки интерфейса.

## Устройство
- `macOS/ColiDev/App/*.swift` — приложение на SwiftUI.
  - `LearningViews.swift` — уроки и тренажёры (большой файл, читать по кускам).
  - `L10n.swift` — все тексты RU/EN, числа выводить через `L10n.number`/`unit`/`measurement`. Ключи словаря не должны повторяться: повтор роняет приложение при запуске.
  - `AppModels.swift` — `LearningStore`, `LocalBackendSupervisor` (запускает встроенный backend).
  - `LessonMarkdown.swift` — показ Markdown в уроках, без `AttributedString(markdown:)` целиком.
- `macOS/ColiDev/ColiDev.xcodeproj/project.pbxproj` — новые файлы регистрировать вручную, ID вида `A1…00NN` (BuildFile) и `A2…00NN` (FileRef). Перед выбором номера посмотреть, какой ID последний во всех открытых ветках.
- `macOS/ColiDev/scripts/verify_*.swift` — проверки, которые CI собирает через `swiftc`. Каждую новую проверку добавлять в `.github/workflows/ci.yml`.
- `01_Projects/` — backend на Python: FastAPI `orchestrator.py`, уроки, RAG `knowledge_index.py`, тесты `test_*.py`. Упаковывается через PyInstaller в `scripts/package_backend_runtime.sh`.
- `project-plan/` — планы и отчёты. Готовность и ручная проверка — в `PROTOTYPE_READINESS_RU_EN.md`.

## Команды
- Сборка: `xcodebuild -project macOS/ColiDev/ColiDev.xcodeproj -scheme ColiDev -configuration Debug -derivedDataPath <tmp> CODE_SIGNING_ALLOWED=NO build`
- Python-тесты: `cd 01_Projects && <venv>/bin/python -m pytest -q`. В системном python3 нет pytest. Тест `test_orchestrator.py::TestStreamingChat::test_local_stream_emits_provider_chunks_and_final_validated_answer` падает и на main — это из-за окружения, а не из-за нашего кода.
- Swift-проверки: шаги `swiftc …` из `ci.yml`. Команды `python` на Mac нет, только `python3`.
- Полная сборка с backend на этом Mac, без CI: `macOS/ColiDev/scripts/build_local_full_app.sh` (параметры в начале файла). Собирает, встраивает backend из кэша, если `01_Projects` без тестов не менялся, проверяет и ставит в `/Applications` с копией в `~/ColiDev-backups`. Если кэша нет: `--seed-backend-from /Applications/ColiDev.app` берёт backend из сборки CI с теми же файлами. Новый backend собирает только PyInstaller, его ставит владелец.
