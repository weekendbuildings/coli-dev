# Проверка инструментов на настоящем Mac / Tools check on a real Mac

Дата: 2026-11-02. Версия: Beta 18, сборка 20261102855, установлена из выпуска на MacBook Air M1. Платных ИИ-вызовов не было.

*Date: 2026-11-02. Version: Beta 18, build 20261102855, installed from the release on a MacBook Air M1. No paid AI calls were made.*

## Итог / Result

| Инструмент / Tool | Результат / Result | Как проверено / How it was checked | Что не проверено / Not checked |
|---|---|---|---|
| Установка / Install | работает / works | SHA-256 архива совпал, приложение запустилось, проверка встроенного backend прошла / archive SHA-256 matched, the app launched, the bundled backend check passed | macOS 13 и 14 / macOS 13 and 14 |
| Прогресс / Progress | работает / works | Записи о пройденных уроках на месте после замены Beta 17 на Beta 18; сохранение после перезапуска проверяет CI / completed lessons survived replacing Beta 17 with Beta 18; CI checks persistence after relaunch | — |
| Тьютор, локальный маршрут / Tutor, local route | работает, с ошибкой в детали / works, with a wrong detail | Настоящий вопрос через `qwen3.5`, ответ за 65 с, поиск нашёл новый урок о кросс-энтропии / a real question through `qwen3.5`, answered in 65 s, retrieval found the new cross-entropy lesson | Модель назвала `CrossEntropyLoss` функцией активации, а это функция потерь: ответы локальной модели надо сверять с уроком / the model called `CrossEntropyLoss` an activation function, but it is a loss function: check local answers against the lesson |
| Видео / Video | работает / works | Тот же адрес и Referer, что в приложении: без звука проиграно 17,7 с за 18 с, есть субтитры ru и en, выбраны ru / the app's URL and Referer: 17.7 s played in 18 s, muted, with ru and en captions and ru selected | Показ текста субтитров на экране и запуск настоящим щелчком / captions text on screen and starting with a real click |
| Obsidian | соединение есть, запись ждёт ключа / connected, writing needs the key | Плагин Local REST API 4.1.7 отвечает на порту 27123, который приложение пробует первым; без ключа запрос к хранилищу получает 401 / the plugin answers on port 27123, the app's first choice; a vault request without the key gets 401 | Сохранение урока и хранение ключа в Keychain: ключ вводит владелец / saving a lesson and keeping the key in Keychain: the owner enters the key |
| NotebookLM | копирование работает / copying works | UI-тест в CI проверяет, что Markdown урока попадает в буфер обмена. Адрес из приложения теперь ведёт на Gemini Notebook (`notebook.google.com`) / a CI UI test checks that the lesson Markdown reaches the clipboard. The app's link now leads to Gemini Notebook (`notebook.google.com`) | Импорт: нужен вход в аккаунт Google владельца / the import needs the owner's Google sign-in |
| OpenCode, Hermes, OpenClaw | установлены, задачу не решили / installed, did not solve the task | См. раздел ниже / see the section below | Работа с другой моделью; в приложение они не встраиваются / work with another model; they are not built into the app |

## Пробы агентов / Agent trials

Задача одна для всех: исправить две ошибки в маленьком `stats.py`, не меняя тестов. Каждый инструмент работал во временной папке, только на локальной Ollama, без ключей, с запретом команд и сети. Версии: OpenCode 2.2.5, Hermes 0.22.5, OpenClaw 2026.10.9.

*One task for all: fix two bugs in a small `stats.py` without changing the tests. Each tool ran in a temporary folder, on local Ollama only, with no keys and with commands and network denied. Versions: OpenCode 2.2.5, Hermes 0.22.5, OpenClaw 2026.10.9.*

| Инструмент / Tool | Модель / Model | Что вышло / Outcome |
|---|---|---|
| OpenCode | `qwen3.5`, контекст 32K | Один шаг занял 8 мин 50 с; за 9 минут ни одной правки / one step took 8 min 50 s; no edit in 9 minutes |
| OpenCode | `qwen2.5-coder:7b`, контекст 32K | Ответ за 30 с, но вызов инструмента написан текстом, правок нет / answered in 30 s, but wrote the tool call as text, no edits |
| Hermes | `qwen2.5-coder:7b`, контекст 64K | Ответ за 44 с, вызовы текстом, правок нет. Контекст ниже 64K Hermes не принимает / answered in 44 s, calls as text, no edits. Hermes refuses a context below 64K |
| OpenClaw | `qwen2.5-coder:7b`, контекст 64K | Ответ за 106 с, вызовы текстом, правок нет / answered in 106 s, calls as text, no edits |

**Вывод.** Все три запускаются и связываются с Ollama, задачу не решил ни один: `qwen2.5-coder:7b` не делает настоящих вызовов инструментов, а `qwen3.5` на этом Mac слишком медленна для агента. Дело в моделях, поэтому сравнить сами инструменты по качеству эта проба не позволяет. Запуск с автоодобрением всех действий (`--auto`) запретила автоматическая проверка прав, такой режим не проверялся.

*Conclusion. All three start and reach Ollama, and none solved the task: `qwen2.5-coder:7b` makes no real tool calls, and `qwen3.5` is too slow for an agent on this Mac. The models are the limit, so this trial cannot compare the tools' quality. The automatic permission check refused a run that auto-approves every action (`--auto`), so that mode was not tried.*

## Смотреть глазами / Check by eye

По снимкам из CI: нейроны стали объёмными блоками, сцена поворачивается, тренажёр обученной модели пишет текст. Мелкие недочёты: на повёрнутой сцене сети подписи наезжают друг на друга, в тренажёре модели выходные кубики у правого края обрезаны. В установленной версии вращение мышью сам не проверял.

*From the CI screenshots: neurons are solid blocks, the scene rotates, and the trained model's lab writes text. Small flaws: labels overlap on the turned network scene, and the output cubes are clipped at the right edge of the model lab. Mouse rotation was not tried by hand in the installed version.*
