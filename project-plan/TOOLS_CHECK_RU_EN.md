# Проверка инструментов на настоящем Mac / Tools check on a real Mac

Дата: 2026-11-02, пробы агентов повторены 2026-11-03. Версия при проверке: Beta 18, сборка 20261102855, установлена из выпуска на MacBook Air M1. Beta 19 (сборка 20261103863) установлена так же: SHA-256 совпал, проверка backend прошла, записи прогресса на месте. Платных ИИ-вызовов не было.

*Date: 2026-11-02, agent trials repeated on 2026-11-03. Version checked: Beta 18, build 20261102855, installed from the release on a MacBook Air M1. Beta 19 (build 20261103863) was installed the same way: the SHA-256 matched, the backend check passed, and the progress records are in place. No paid AI calls were made.*

## Итог / Result

| Инструмент / Tool | Результат / Result | Как проверено / How it was checked | Что не проверено / Not checked |
|---|---|---|---|
| Установка / Install | работает / works | SHA-256 архива совпал, приложение запустилось, проверка встроенного backend прошла / archive SHA-256 matched, the app launched, the bundled backend check passed | macOS 13 и 14 / macOS 13 and 14 |
| Прогресс / Progress | работает / works | Записи о пройденных уроках на месте после замены Beta 17 на Beta 18; сохранение после перезапуска проверяет CI / completed lessons survived replacing Beta 17 with Beta 18; CI checks persistence after relaunch | — |
| Тьютор, локальный маршрут / Tutor, local route | работает, с ошибкой в детали / works, with a wrong detail | Настоящий вопрос через `qwen3.5`, ответ за 65 с, поиск нашёл новый урок о кросс-энтропии / a real question through `qwen3.5`, answered in 65 s, retrieval found the new cross-entropy lesson | Модель назвала `CrossEntropyLoss` функцией активации, а это функция потерь: ответы локальной модели надо сверять с уроком / the model called `CrossEntropyLoss` an activation function, but it is a loss function: check local answers against the lesson |
| Видео / Video | работает / works | Тот же адрес и Referer, что в приложении: без звука проиграно 17,7 с за 18 с, есть субтитры ru и en, выбраны ru / the app's URL and Referer: 17.7 s played in 18 s, muted, with ru and en captions and ru selected | Показ текста субтитров на экране и запуск настоящим щелчком / captions text on screen and starting with a real click |
| Obsidian | соединение есть, запись ждёт ключа / connected, writing needs the key | Плагин Local REST API 4.1.7 отвечает на порту 27123, который приложение пробует первым; без ключа запрос к хранилищу получает 401 / the plugin answers on port 27123, the app's first choice; a vault request without the key gets 401 | Сохранение урока и хранение ключа в Keychain: ключ вводит владелец / saving a lesson and keeping the key in Keychain: the owner enters the key |
| NotebookLM | копирование работает / copying works | UI-тест в CI проверяет, что Markdown урока попадает в буфер обмена. Адрес из приложения теперь ведёт на Gemini Notebook (`notebook.google.com`) / a CI UI test checks that the lesson Markdown reaches the clipboard. The app's link now leads to Gemini Notebook (`notebook.google.com`) | Импорт: нужен вход в аккаунт Google владельца / the import needs the owner's Google sign-in |
| OpenCode, Hermes, OpenClaw | настроены на постоянную работу / set up for regular use | На `qwen3.5:4b`, см. раздел ниже; правку через настоящие настройки проверили Hermes и OpenClaw, у OpenCode проверено чтение / on `qwen3.5:4b`, see the section below; Hermes and OpenClaw edited through the real settings, OpenCode was checked for reading | Подтверждение правки в OpenCode, большие задачи, режим автоодобрения; в приложение они не встраиваются / the edit approval in OpenCode, large tasks, the auto-approve mode; they are not built into the app |

## Пробы агентов / Agent trials

Задача одна для всех: исправить две ошибки в маленьком `stats.py`, не меняя тестов. Каждый инструмент работал во временной папке, только на локальной Ollama, без ключей, с запретом сети. Команды запрещены, кроме `python3 -m unittest` у OpenCode. Версии: OpenCode 2.2.5, Hermes 0.22.5, OpenClaw 2026.10.9.

*One task for all: fix two bugs in a small `stats.py` without changing the tests. Each tool ran in a temporary folder, on local Ollama only, with no keys and no network. Commands were denied, except `python3 -m unittest` for OpenCode. Versions: OpenCode 2.2.5, Hermes 0.22.5, OpenClaw 2026.10.9.*

### Вторая проба, 2026-11-03: `qwen3.5:4b`, контекст 64K / Second trial, 2026-11-03: `qwen3.5:4b`, 64K context

| Инструмент / Tool | Время / Time | Что вышло / Outcome |
|---|---|---|
| OpenCode | 7 мин 36 с | Обе ошибки исправлены, сам запустил тесты, все прошли, тесты не изменены / both bugs fixed, ran the tests itself, all passed, tests unchanged |
| Hermes | 5 мин 22 с | Обе ошибки исправлены, тесты прошли при моей проверке и не изменены. Но он пытался править `test_stats.py` вопреки условию: правка сорвалась только из-за неверного пути / both bugs fixed, the tests passed when I checked and are unchanged. But it tried to edit `test_stats.py` against the instructions: the edit failed only because of a wrong path |
| OpenClaw | 3 мин 49 с | Обе ошибки исправлены, тесты прошли при моей проверке и не изменены; сам он их запустить не мог: команды запрещены / both bugs fixed, the tests passed when I checked and are unchanged; it could not run them itself because commands were denied |

**Вывод.** Дело было в модели: `qwen3.5:4b` делает настоящие вызовы инструментов, и все три агента справились. Это по одному запуску на задаче из двух ошибок, поэтому сравнивать инструменты по качеству рано, и о больших задачах проба ничего не говорит. Случай с Hermes показывает, что правки агента надо смотреть и что условие «не меняй это» не защищает файл. Запуск с автоодобрением всех действий (`--auto`) запретила автоматическая проверка прав, такой режим не проверялся. Модель занимает 4,0 ГБ.

*Conclusion. The model was the limit: `qwen3.5:4b` makes real tool calls, and all three agents managed. This is one run each on a task with two bugs, so it is too early to compare the tools' quality, and the trial says nothing about large tasks. The Hermes case shows that an agent's edits need review and that the instruction "do not change this" does not protect a file. The automatic permission check refused a run that auto-approves every action (`--auto`), so that mode was not tried. The model takes 4.0 GB.*

### Постоянная настройка, 2026-11-03 / Regular setup, 2026-11-03

Все три работают через `qwen35-agent`: это `qwen3.5:4b` с контекстом 64K в Ollama, без ключей и платных сервисов. Один небольшой запрос занимает минуты, поэтому начинать лучше с маленьких задач и в папке под git, чтобы видеть и откатывать правки.

*All three use `qwen35-agent`: `qwen3.5:4b` with a 64K context in Ollama, with no keys or paid services. One small request takes minutes, so start with small tasks in a git folder, where edits can be seen and undone.*

| Инструмент / Tool | Как запустить / How to start | Что ему можно / What it may do | Проверка с настоящими настройками / Check with the real settings |
|---|---|---|---|
| OpenCode | `opencode` в папке проекта / in the project folder | Читает сам; правки и команды по подтверждению; другие папки запрещены / reads on its own; edits and commands need approval; other folders are denied | Прочитал файл и ответил за 3 мин 30 с. Без человека за 7 минут правок не сделал. Само окно подтверждения не проверено / read a file and answered in 3 min 30 s. With nobody to approve, it made no edit in 7 minutes. The approval prompt itself is unchecked |
| Hermes | `hermes chat -t file` | С `-t file` только файловые инструменты; правит файлы без вопроса / with `-t file`, file tools only; edits files without asking | Исправил обе ошибки за 2 мин 40 с, тесты прошли / fixed both bugs in 2 min 40 s, the tests passed |
| OpenClaw | `openclaw agent --local --session-id work --message "задача"` | Работает в `~/agent-work`, правит файлы без вопроса; команды, браузер и сеть запрещены. Не выходит ли он за эту папку, не проверено / works in `~/agent-work`, edits files without asking; commands, browser, and web are denied. Whether it can leave this folder is unchecked | Исправил обе ошибки за 1 мин 46 с, тесты прошли / fixed both bugs in 1 min 46 s, the tests passed |

Настройки: `~/.config/opencode/opencode.json`, `~/.hermes/config.yaml` (прежняя копия рядом: `config.yaml.bak-2026-11-03`), `~/.openclaw/openclaw.json`. Сбор статистики в Hermes выключен и отправка тоже: так было по умолчанию.

*Settings: `~/.config/opencode/opencode.json`, `~/.hermes/config.yaml` (the earlier copy is next to it: `config.yaml.bak-2026-11-03`), `~/.openclaw/openclaw.json`. Metrics collection and sending in Hermes are off, as they were by default.*

### Первая проба, 2026-11-02: задачу не решил никто / First trial, 2026-11-02: nobody solved the task

| Инструмент / Tool | Модель / Model | Что вышло / Outcome |
|---|---|---|
| OpenCode | `qwen3.5`, контекст 32K | Один шаг занял 8 мин 50 с; за 9 минут ни одной правки / one step took 8 min 50 s; no edit in 9 minutes |
| OpenCode | `qwen2.5-coder:7b`, контекст 32K | Ответ за 30 с, но вызов инструмента написан текстом, правок нет / answered in 30 s, but wrote the tool call as text, no edits |
| Hermes | `qwen2.5-coder:7b`, контекст 64K | Ответ за 44 с, вызовы текстом, правок нет. Контекст ниже 64K Hermes не принимает / answered in 44 s, calls as text, no edits. Hermes refuses a context below 64K |
| OpenClaw | `qwen2.5-coder:7b`, контекст 64K | Ответ за 106 с, вызовы текстом, правок нет / answered in 106 s, calls as text, no edits |

## Смотреть глазами / Check by eye

По снимкам из CI: нейроны стали объёмными блоками, сцена поворачивается, тренажёр обученной модели пишет текст. Мелкие недочёты: на повёрнутой сцене сети подписи наезжают друг на друга, в тренажёре модели выходные кубики у правого края обрезаны. В установленной версии вращение мышью сам не проверял.

*From the CI screenshots: neurons are solid blocks, the scene rotates, and the trained model's lab writes text. Small flaws: labels overlap on the turned network scene, and the output cubes are clipped at the right edge of the model lab. Mouse rotation was not tried by hand in the installed version.*

В Beta 19 экран «Путь ИИ» с пятью этапами и урок об ARC открываются в установленном приложении. Тренажёры настоящими щелчками там не проверены, запуск видео щелчком и текст субтитров тоже. В приложении кнопки всё ещё называются NotebookLM, хотя адрес ведёт на Gemini Notebook.

*In Beta 19 the five-stage AI Path screen and the ARC lesson open in the installed app. The labs were not tried there with real clicks, and neither were starting a video by clicking and the caption text. The app's buttons still say NotebookLM, although the link leads to Gemini Notebook.*
