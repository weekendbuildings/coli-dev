# Cause & Course 0.1.0 Beta 20 — заметки к выпуску / Release notes

**Опубликовано 2026-11-04: [v0.1.0-beta.20](https://github.com/weekendbuildings/coli-dev/releases/tag/v0.1.0-beta.20), выпуск из `9a9c47f` (Merge PR #18), дерево которого совпадает с проверенным `aab6cf5`; CI [41718257756](https://github.com/weekendbuildings/coli-dev/actions/runs/41718257756) зелёный на macOS 15 и 26 Apple Silicon. Только для Apple Silicon. / Published 2026-11-04 from `9a9c47f` (Merge PR #18), whose tree matches the tested `aab6cf5`; Apple Silicon only.**

## Русский

**Главное.** Приложение теперь называется Cause & Course, раньше это был ColiDev. Файл остаётся `ColiDev.app`, а прогресс и ключи хранятся там же.

**Что нового:**
- Новая палитра цветов для светлой и тёмной темы. Фон больше не меняется, когда окно теряет фокус. Выбор в боковой панели стал мягким.
- Новый объёмный значок.
- Новое имя в окне приложения. В Finder и Dock пока остаётся ColiDev: это ошибка настройки, её исправление требует новой сборки.
- Gemini Notebook: кнопки переименованы, прямо в уроке есть шаги и три готовых вопроса к уроку.
- Obsidian: повторное нажатие больше не создаёт копию незаметно, виден путь сохранённой копии.
- Задача 10 в тренажёре ARC теперь решается: раньше в палитре не было нужного цвета.
- Тренажёр забывания не сбрасывает результат после прокрутки.
- Столбики в тренажёре модели не обрезаются, подписи сети разведены.
- Источники этапов 3–5 сверены: прочитанное отмечено датой, ссылка о слепозрении исправлена.

**Что не проверено:**
- Человек новые уроки ещё не проходил.
- Тренажёры этапов 4 и 5 проверены по коду и расчётам модели, щелчками в окне приложения их никто не нажимал.
- Кнопки внутри Gemini Notebook после входа: названия взяты из справки Google, вход делает сам владелец.
- Подписи на повёрнутой сцене сети глазами не смотрели, только сборка и тесты.
- Настройки и Центр управления в новых цветах на снимках не просмотрены.
- Сохранение в Obsidian новой кнопкой на настоящем хранилище.
- 15 ссылок на источники остаются с пометкой `recalled`, каждая со своей причиной.

**Как проверялось:** Python-тесты, UI-тесты на macOS 15 и 26 Apple Silicon и скрипты `verify_*` в CI.

**Установка одной командой (Apple Silicon):**

```bash
curl -fL -o /tmp/ColiDev.zip "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.20/ColiDev-beta-AppleSilicon.zip" && rm -rf /Applications/ColiDev.app && ditto -x -k /tmp/ColiDev.zip /Applications && xattr -dr com.apple.quarantine /Applications/ColiDev.app 2>/dev/null; open /Applications/ColiDev.app
```

Сборка не подписана Developer ID: если macOS не открывает приложение, щёлкни по нему в Finder с Control → «Открыть».

## English

**Highlights.** The app is now called Cause & Course; it was ColiDev. The file stays `ColiDev.app`, and progress and keys stay where they were.

**What is new:**
- A new color palette for light and dark themes. The background no longer changes when the window loses focus. Sidebar selection is soft.
- A new icon with depth.
- The new name in the app window. Finder and the Dock still show ColiDev: this is a settings bug, and fixing it needs a new build.
- Gemini Notebook: renamed buttons, steps in the lesson, and three ready questions about it.
- Obsidian: a second click no longer adds a copy silently, and the path of the saved copy is shown.
- ARC task 10 can now be solved: the palette lacked the color it needs.
- The forgetting lab keeps its result after scrolling.
- The output pillars in the model lab are no longer cut off, and the network labels are spaced apart.
- Sources of stages 3–5 were checked: what was read carries the date, and the blindsight citation is corrected.

**Not checked:**
- No person has gone through the new lessons yet.
- The stage 4 and 5 labs were checked by code and model calculations; nobody has clicked them in the app window.
- The buttons inside Gemini Notebook after sign-in: the names come from Google's help, and the owner signs in.
- The labels on a turned network scene were not looked at by eye, only built and tested.
- Settings and the Control Center in the new colors were not looked at in screenshots.
- Saving to a real Obsidian vault with the new button.
- 15 source entries keep the `recalled` mark, each with its reason.

**How it was checked:** Python tests, UI tests on macOS 15 and 26 Apple Silicon, and the `verify_*` scripts in CI.

**One-command install (Apple Silicon):**

```bash
curl -fL -o /tmp/ColiDev.zip "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.20/ColiDev-beta-AppleSilicon.zip" && rm -rf /Applications/ColiDev.app && ditto -x -k /tmp/ColiDev.zip /Applications && xattr -dr com.apple.quarantine /Applications/ColiDev.app 2>/dev/null; open /Applications/ColiDev.app
```

The build is not signed with a Developer ID: if macOS will not open the app, Control-click it in Finder and choose Open.
