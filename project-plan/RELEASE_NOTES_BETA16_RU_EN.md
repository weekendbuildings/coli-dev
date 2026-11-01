# ColiDev 0.1.0 Beta 16 — заметки к выпуску / Release notes

**Статус: готовится, ещё не опубликовано. / Status: in preparation, not yet published.**

## Русский

**Главное.** Тренажёры стали наглядными и интерактивными. Все 22 новых тренажёра построены на общем наборе LabKit: цветные графики с осями и подписями, управление мышкой, анимации, крупные показатели, цветной статус, задание, которое отмечается ✓, а формулы свёрнуты под «Как это работает». Девять тренажёров добавлены, тринадцать из Beta 15 переделаны.

**Новые тренажёры:**
- Физика: замедление времени (часы корабля и Земли, кривая γ), спектр водорода (уровни энергии и радужная полоса), электромагнитные волны (c = fλ), цепь из двух резисторов (бегущий ток), закон Снеллиуса (луч поворачивается мышкой), качели (детей можно перетаскивать).
- Зоология: логистический рост (горб прироста и S-кривая), мечение и повторный отлов, поверхность и объём тела.

**Переделаны:** градиентный спуск (тепловая карта, «Пуск», кривая потерь), слой нейросети (живая схема связей), подгонка прямой (ручки и квадраты ошибок), пластичность синапса, кинетика фермента, метод Эйлера, автокатализ, точность копирования ДНК, расстояние Хэмминга (буквы меняются кликом), радиоактивное датирование (сетка атомов), обратная связь в гомеостазе, сопряжение с АТФ (энергетическая лестница), равновесие Q против K.

**Как проверялось:** модель каждого тренажёра проверяется отдельной программой в CI; 43 UI-теста открывают уроки и проверяют числа из вопросов; Python-тесты (817); CI на macOS 15 и 26 Apple Silicon; внешний вид проверен по снимкам отдельной сборки.

**Установка одной командой (Apple Silicon):**

```bash
curl -fL -o /tmp/ColiDev.zip "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.16/ColiDev-beta-AppleSilicon.zip" && rm -rf /Applications/ColiDev.app && ditto -x -k /tmp/ColiDev.zip /Applications && xattr -dr com.apple.quarantine /Applications/ColiDev.app 2>/dev/null; open /Applications/ColiDev.app
```

Сборка не подписана Developer ID: если macOS не открывает приложение, щёлкни по нему в Finder с Control → «Открыть».

## English

**Highlights.** The labs are now visual and interactive. All 22 new labs are built on the shared LabKit set: colour charts with axes and labels, mouse control, animations, large readouts, a coloured status, a goal that turns ✓, and formulas folded under "How it works". Nine labs are new and thirteen from Beta 15 were redesigned.

**New labs:**
- Physics: time dilation (ship and Earth clocks, the γ curve), the hydrogen spectrum (energy levels and a rainbow strip), electromagnetic waves (c = fλ), a two-resistor circuit (flowing current), Snell's law (drag the ray), and a seesaw (drag the children).
- Zoology: logistic growth (the growth hump and S-curve), mark and recapture, and body surface and volume.

**Redesigned:** gradient descent (heat map, Play, loss curve), the neural network layer (a live connection diagram), line fitting (drag handles and error squares), synaptic plasticity, enzyme kinetics, Euler's method, autocatalysis, DNA copying accuracy, the Hamming distance (click letters to substitute), radioactive dating (a grid of atoms), feedback in homeostasis, ATP coupling (an energy staircase), and equilibrium Q versus K.

**How it was checked:** each lab's model is checked by its own program in CI; 43 UI tests open the lessons and check the numbers from their questions; Python tests (817); CI on macOS 15 and 26 Apple Silicon; the look was checked with screenshots of a separate build.

**One-command install (Apple Silicon):**

```bash
curl -fL -o /tmp/ColiDev.zip "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.16/ColiDev-beta-AppleSilicon.zip" && rm -rf /Applications/ColiDev.app && ditto -x -k /tmp/ColiDev.zip /Applications && xattr -dr com.apple.quarantine /Applications/ColiDev.app 2>/dev/null; open /Applications/ColiDev.app
```

The build is not signed with a Developer ID: if macOS will not open the app, Control-click it in Finder and choose Open.
