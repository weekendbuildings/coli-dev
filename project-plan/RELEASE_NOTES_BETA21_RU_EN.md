# Cause & Course 0.1.0 Beta 21 — заметки к выпуску / Release notes

**Опубликовано 2026-11-08: [v0.1.0-beta.21](https://github.com/weekendbuildings/coli-dev/releases/tag/v0.1.0-beta.21), выпуск из `faf4082` (Merge PR #19), дерево которого совпадает с проверенным `6cb53d6`; CI [42460400910](https://github.com/weekendbuildings/coli-dev/actions/runs/42460400910) зелёный на macOS 15 и 26 Apple Silicon и backend. Только для Apple Silicon. / Published 2026-11-08 from `faf4082` (Merge PR #19), whose tree matches the tested `6cb53d6`; Apple Silicon only.**

## Русский

**Главное.** Это итоговая бета. Путь ИИ закрыт целиком, а в ключевых уроках код теперь пишешь сам. Файл по-прежнему `ColiDev.app`, прогресс и ключи хранятся там же.

**Что нового в уроках:**
- Все 11 уроков важности B и C: законы масштабирования, данные, разреженные признаки, цепи, поиск по дереву, открытые задачи, биология или функция, что можешь сделать ты, счётчик пар, выбор слов, правила и DPO. У каждого урока свой тренажёр.
- Уроки для чтения статей: SVD и малоранговые матрицы, матричные производные и якобианы, методы измерения мозга и модель Ходжкина — Хаксли.
- «От циклов к матрицам»: та же твоя модель на NumPy. Она совпадает с версией на чистом Python до 10⁻¹⁶ и учится за 22 секунды вместо 47 минут.
- «Собери и проверь сам» в семи уроках: внимание, градиенты, токенизатор, REINFORCE, LoRA, зонд, мера интеграции. Ключевой шаг пишешь сам, строгая проверка сверяет его с численной производной и граничными случаями (`01_Projects/creator_labs`).
- В каждом уроке пути есть «Простыми словами», «Что нужно знать до» и «Если непонятно». Добавлен словарь пути ИИ на 112 слов. Все 15 ссылок с пометкой `recalled` сверены с первоисточниками.
- В 36 вопросах правильный ответ больше не угадывается по длине или по расчёту.
- Исправлена ошибка в градиенте нормализации слоя твоей модели: на части весов он был неточен до 0,1 %.

**Что нового в приложении:**
- Экран «Инструменты»: OpenCode, Hermes, OpenClaw, Ollama, Obsidian и Gemini Notebook. Приложение проверяет, что установлено, и запускает агентов в Терминале в выбранной папке, без флагов автоодобрения.
- Finder и Dock показывают имя Cause & Course.
- «Сегодня» больше не показывает нули после обновления: приложение ждёт backend, пока тот пересобирает индекс курса.
- Центр управления: вкладки без обрезанного заголовка, кнопки называются Gemini Notebook.

**Проверено:**
- CI: Python-тесты, UI-тесты и скрипты `verify_*` на macOS 15 и 26 Apple Silicon. Локально прошли 1797 Python-тестов.
- Щелчками в прошлой сессии: тренажёры этапов 3–5, видео с субтитрами, все шесть кнопок «Инструментов».
- На этом Mac: backend работает, «Сегодня» показывает 8 тем и 6 повторений, Finder показывает имя Cause & Course.

**Что не проверено:**
- Тренажёры новых уроков глазами не смотрели: они проверены сборкой, тестами моделей и Swift-проверками.
- Ответы агентов в «Инструментах»: в день проверки завис runner Ollama, его нужно перезапустить.
- Вход в Gemini Notebook делает сам владелец.
- На странице тьютора в браузере осталась надпись NotebookLM.
- При первом запуске новой сборки macOS может спросить доступ к Связке ключей: нажми «Всегда разрешать».

**Установка одной командой (Apple Silicon):**

```bash
curl -fL -o /tmp/ColiDev.zip "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.21/ColiDev-beta-AppleSilicon.zip" && rm -rf /Applications/ColiDev.app && ditto -x -k /tmp/ColiDev.zip /Applications && xattr -dr com.apple.quarantine /Applications/ColiDev.app 2>/dev/null; open /Applications/ColiDev.app
```

Сборка не подписана Developer ID: если macOS не открывает приложение, щёлкни по нему в Finder с Control → «Открыть».

## English

**Highlights.** This is the final beta. The AI path is complete, and in the key lessons you now write the code yourself. The file is still `ColiDev.app`; progress and keys stay where they were.

**New in the lessons:**
- All 11 importance B and C lessons: scaling laws, data, sparse features, circuits, tree search, open problems, biology or function, what you can do, the pair counter, choosing words, rules and DPO. Each has its own lab.
- Lessons for reading papers: SVD and low-rank matrices, matrix derivatives and Jacobians, brain measurement methods and the Hodgkin–Huxley model.
- "From loops to matrices": your own model in NumPy. It matches the plain Python version to 10⁻¹⁶ and trains in 22 seconds instead of 47 minutes.
- "Build and check it yourself" in seven lessons: attention, gradients, the tokenizer, REINFORCE, LoRA, a probe, the integration measure. You write the key step; a strict check compares it with numerical derivatives and edge cases (`01_Projects/creator_labs`).
- Every path lesson has "In plain words", "What to know first" and "If something is unclear". A 112-word AI path glossary. All 15 sources marked `recalled` were checked against primary sources.
- In 36 questions the right option no longer gives itself away by length or by a calculation.
- A bug in your model's layer-normalization gradient is fixed: for some weights it was off by up to 0.1%.

**New in the app:**
- A Tools screen: OpenCode, Hermes, OpenClaw, Ollama, Obsidian and Gemini Notebook. The app checks what is installed and starts agents in Terminal in a chosen folder, with no auto-approve flags.
- Finder and the Dock show the name Cause & Course.
- Today no longer shows zeros after an update: the app waits for the backend while it rebuilds the course index.
- Control Center: tabs without a cut title, buttons named Gemini Notebook.

**Checked:**
- CI: Python tests, UI tests and the `verify_*` scripts on macOS 15 and 26 Apple Silicon. Locally, 1797 Python tests passed.
- By clicking in the previous session: the stage 3–5 labs, the video with captions, all six Tools buttons.
- On this Mac: the backend runs, Today shows 8 topics and 6 reviews, Finder shows the name Cause & Course.

**Not checked:**
- The new lessons' labs were not looked at by eye: they were checked by the build, model tests and Swift checks.
- Agent answers in Tools: on the day of the check the Ollama runner hung and needs a restart.
- Signing in to Gemini Notebook is done by the owner.
- The tutor's browser page still says NotebookLM.
- On the first launch of a new build macOS may ask for Keychain access: choose "Always Allow".

**One-command install (Apple Silicon):**

```bash
curl -fL -o /tmp/ColiDev.zip "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.21/ColiDev-beta-AppleSilicon.zip" && rm -rf /Applications/ColiDev.app && ditto -x -k /tmp/ColiDev.zip /Applications && xattr -dr com.apple.quarantine /Applications/ColiDev.app 2>/dev/null; open /Applications/ColiDev.app
```

The build is not signed with a Developer ID: if macOS will not open the app, Control-click it in Finder and choose Open.
