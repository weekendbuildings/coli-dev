# ColiDev 0.1.0 Beta 14 — заметки к выпуску / Release notes

**Статус: готовится, ещё не опубликовано. / Status: in preparation, not yet published.**

## Русский

**Главное.** Курс вырос с 109 до 117 уроков. Теперь у каждой строки дорожных карт по биологии, химии, математике, физике, программированию и зоологии есть свой урок; пустыми остаются только две строки английского, который пока на паузе. Код приложения не менялся — это выпуск с содержанием.

**Новые уроки:**
- Физика: g по данным маятника методом наименьших квадратов — от формулы к плану измерения и подгонке прямой.
- Математика: простые числа, наибольший общий делитель и арифметика остатков.
- Зоология: систематика и научные названия видов; план строения насекомых и метаморфоз.
- Программирование: конкурентность с async и await; повторы запросов и идемпотентность; логи и измерение времени; разбор выражения в абстрактное синтаксическое дерево и безопасный ast.literal_eval.

**Исправление в заметках.** В заметках и README к Beta 13 было написано «106 уроков»; на самом деле в Beta 13 было 109 уроков, привязанных к дорожным картам.

**Как проверялось:** каждый факт сверен с текстом учебников OpenStax или документации Python и IETF; код из уроков запускается в тестах, а печать программ и ответы на вопросы сверяются с текстом урока; Python-тесты (805) и CI на macOS 15 и 26 Apple Silicon и macOS 15 Intel.

**Установка одной командой:**

```bash
A=$([ "$(uname -m)" = arm64 ] && echo AppleSilicon || echo Intel); curl -fL -o /tmp/ColiDev.zip "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.14/ColiDev-beta-$A.zip" && rm -rf /Applications/ColiDev.app && ditto -x -k /tmp/ColiDev.zip /Applications && xattr -dr com.apple.quarantine /Applications/ColiDev.app 2>/dev/null; open /Applications/ColiDev.app
```

Сборка не подписана Developer ID: если macOS не открывает приложение, щёлкни по нему в Finder с Control → «Открыть».

## English

**Highlights.** The course grew from 109 to 117 lessons. Every roadmap row in Biology, Chemistry, Mathematics, Physics, Programming, and Zoology now has its own lesson; only two English rows remain empty, as English is paused for now. The app code is unchanged: this is a content release.

**New lessons:**
- Physics: finding g from pendulum data by least squares, from a formula to a measurement plan and a fitted line.
- Mathematics: prime numbers, the greatest common divisor, and remainder arithmetic.
- Zoology: systematics and scientific species names; the insect body plan and metamorphosis.
- Programming: concurrency with async and await; request retries and idempotency; logging and timing; parsing an expression into an abstract syntax tree and the safe ast.literal_eval.

**Correction.** The Beta 13 notes and README said "106 lessons"; Beta 13 actually had 109 lessons linked into the roadmaps.

**How it was checked:** every fact was compared with the text of OpenStax textbooks or the Python and IETF documentation; the code in the lessons runs in tests, and the programs' output and quiz answers are checked against the lesson text; Python tests (805) and CI on macOS 15 and 26 Apple Silicon and macOS 15 Intel.

**One-command install:**

```bash
A=$([ "$(uname -m)" = arm64 ] && echo AppleSilicon || echo Intel); curl -fL -o /tmp/ColiDev.zip "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.14/ColiDev-beta-$A.zip" && rm -rf /Applications/ColiDev.app && ditto -x -k /tmp/ColiDev.zip /Applications && xattr -dr com.apple.quarantine /Applications/ColiDev.app 2>/dev/null; open /Applications/ColiDev.app
```

The build is not signed with a Developer ID: if macOS will not open the app, Control-click it in Finder and choose Open.
