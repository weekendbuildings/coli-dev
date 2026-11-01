# ColiDev 0.1.0 Beta 13 — заметки к выпуску / Release notes


**Опубликовано 2026-10-31: [v0.1.0-beta.13](https://github.com/weekendbuildings/coli-dev/releases/tag/v0.1.0-beta.13), собрано из `f55b211` (Merge PR #9), CI [41247367541](https://github.com/weekendbuildings/coli-dev/actions/runs/41247367541) зелёный на трёх Mac. / Published 2026-10-31, built from `f55b211`, CI green on three Macs.**

## Русский

**Главное.** Курс вырос с 64 до 109 уроков и получил новый предмет «Химия». Добавлены уроки на пути к пониманию и созданию жизни и ИИ — от атомов и энтропии до пластичности синапсов и обучения нейросетей — и восемь новых тренажёров.

**Исправления после ручной проверки Beta 12 на MacBook Air M1:**
- счётчик «проверки записаны» больше не обнуляется после перезапуска;
- абзацы и пункты в уроках не склеиваются, в вопросах нет лишних кавычек разметки;
- после выхода из приложения backend больше не остаётся работать в фоне, даже если окно закрыли раньше или приложение упало;
- единицы и числа в тренажёрах — по-русски (запятая, «м», «Н»), подписи для VoiceOver;
- Beta 9–11 помечены как не запускающиеся;
- обновления ищутся в новом адресе репозитория `weekendbuildings/coli-dev`: Beta 12 после переноса репозитория не видит новых выпусков в настройках, поэтому Beta 13 нужно поставить вручную, а дальше обновления снова будут видны.

**Новое в курсе:**
- Химия: атомы и связи, вода и pH, углерод и органика, энергия реакций и катализ, равновесие, пребиотическая химия и автокатализ, АТФ и сопряжение, кинетика ферментов.
- Биология: что такое жизнь и порог ошибок Эйгена, Харди — Вайнберг, микробы, гомеостаз, точность копирования ДНК, пластичность синапсов, древо жизни, биоинформатика, биотехнология и этика.
- Физика: энтропия, цепи, вращение, магнетизм, оптика, квантовый атом, радиоактивная датировка, уравнения Максвелла, теория относительности.
- Математика: векторы и матрицы, градиент, метод Эйлера, логика.
- Программирование: классы Python, HTTP и API, виртуальные окружения, безопасность приложений, обучение нейрона.
- Тренажёры: 3D-поверхность метода Лагранжа, порог ошибок, шкала pH, сборка молекул, энергетическая диаграмма, монеты и энтропия, Харди — Вайнберг, «Нейрон учится».
- Поиск по смыслу для тьютора (bge-m3) и локальный тьютор qwen3.5 по умолчанию.

**Как проверялось:** каждый факт в новых уроках сверен с текстом учебников OpenStax, документацией и научными статьями (через Crossref); Python-тесты и Swift-проверки моделей; CI на macOS 15 и 26 Apple Silicon и macOS 15 Intel.

**Установка одной командой:**

```bash
A=$([ "$(uname -m)" = arm64 ] && echo AppleSilicon || echo Intel); curl -fL -o /tmp/ColiDev.zip "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.13/ColiDev-beta-$A.zip" && rm -rf /Applications/ColiDev.app && ditto -x -k /tmp/ColiDev.zip /Applications && xattr -dr com.apple.quarantine /Applications/ColiDev.app 2>/dev/null; open /Applications/ColiDev.app
```

Сборка не подписана Developer ID: если macOS не открывает приложение, щёлкни по нему в Finder с Control → «Открыть».

## English

**Highlights.** The course grew from 64 to 109 lessons and gained a new subject, Chemistry. New lessons follow the path toward understanding and creating life and AI, from atoms and entropy to synaptic plasticity and neural-network training, with eight new labs.

**Fixes after the manual Beta 12 check on a MacBook Air M1:**
- the "checks recorded" counter no longer resets after a restart;
- lesson paragraphs and list items no longer run together, and questions show no stray Markdown quotes;
- the backend no longer keeps running after you quit, even if the window was closed first or the app crashed;
- lab units and numbers follow the interface language, with VoiceOver labels;
- Betas 9–11 are marked as failing to launch;
- updates are looked up at the repository's new address, `weekendbuildings/coli-dev`: after the move Beta 12 cannot see new releases in Settings, so install Beta 13 manually, and updates will be visible again afterwards.

**New in the course:** Chemistry from atoms to enzyme kinetics and prebiotic chemistry; Biology from the error threshold and Hardy–Weinberg to DNA repair, synaptic plasticity, phylogenetics, bioinformatics, and bioethics; Physics from entropy to quantum levels, radiometric dating, Maxwell's equations, and relativity; Mathematics with vectors, the gradient, Euler's method, and logic; Programming with Python classes, HTTP, environments, application security, and a learning neuron; eight new labs; semantic search for the tutor (bge-m3) and qwen3.5 as the default local tutor.

**How it was checked:** every fact in the new lessons was checked against the text of OpenStax textbooks, documentation, and research papers (via Crossref); Python tests and Swift model checks; CI on macOS 15 and 26 Apple Silicon and macOS 15 Intel.

**One-command install:** see the command above. The build is not Developer ID signed: if macOS will not open it, Control-click the app in Finder and choose Open.
