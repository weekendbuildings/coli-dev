# ColiDev 0.1.0 Beta 15 — заметки к выпуску / Release notes

**Статус: готовится, ещё не опубликовано. / Status: in preparation, not yet published.**

## Русский

**Главное.** 13 новых интерактивных тренажёров к урокам на пути к жизни и ИИ: теперь их можно не только прочитать, но и «потрогать» — двигать параметры и сразу видеть, как меняется результат. Каждый тренажёр начинается с чисел из вопроса своего урока.

**Новые тренажёры:**
- Путь к ИИ: «Слой нейросети: Wx + b» (веса, смещения, ReLU), «Градиентный спуск на плоскости» (почему слишком большой шаг перепрыгивает минимум), «Подгонка прямой» методом наименьших квадратов по данным маятника.
- Мозг: «Пластичность синапса» — синапс усиливается, только когда совпадают выброс глутамата и сильная деполяризация (правило Хебба).
- Жизнь и химия: «Кинетика фермента» (кривая Михаэлиса — Ментен), «Автокатализ» (удвоение против прибавления, логарифмическая шкала), «Сопряжение реакций с АТФ», «Равновесие: Q против K» с принципом Ле Шателье.
- Биология: «Точность копирования и длина генома» (порог Эйгена до 10⁻¹⁰), «Расстояние Хэмминга» для последовательностей ДНК, «Обратная связь в гомеостазе».
- Моделирование и физика: «Метод Эйлера» (шаг и точность), «Радиоактивное датирование».

**Исправления:** в тренажёре кинетики фермента знак процента в строке «… % от Vmax» мог показываться неверно — исправлено, и новый тест проверяет все строки интерфейса.

**Как проверялось:** модель каждого тренажёра проверяется отдельной программой в CI (числа из уроков, граничные случаи); UI-тесты открывают уроки и нажимают кнопки тренажёров; Python-тесты (814) и CI на macOS 15 и 26 Apple Silicon.

**Установка одной командой (Apple Silicon):**

```bash
curl -fL -o /tmp/ColiDev.zip "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.15/ColiDev-beta-AppleSilicon.zip" && rm -rf /Applications/ColiDev.app && ditto -x -k /tmp/ColiDev.zip /Applications && xattr -dr com.apple.quarantine /Applications/ColiDev.app 2>/dev/null; open /Applications/ColiDev.app
```

Сборка не подписана Developer ID: если macOS не открывает приложение, щёлкни по нему в Finder с Control → «Открыть».

## English

**Highlights.** 13 new interactive labs for lessons on the path to life and AI: they can now be not only read but "touched", changing parameters and seeing the result change at once. Each lab starts at the numbers from its lesson's question.

**New labs:**
- Path to AI: "A neural network layer: Wx + b" (weights, biases, ReLU), "Gradient descent in two dimensions" (why too large a step jumps over the minimum), "Fitting a line" by least squares to pendulum data.
- Brain: "Synaptic plasticity": a synapse strengthens only when glutamate release and strong depolarisation coincide (the Hebbian principle).
- Life and chemistry: "Enzyme kinetics" (the Michaelis–Menten curve), "Autocatalysis" (doubling versus adding, a logarithmic scale), "Coupling reactions to ATP", "Equilibrium: Q versus K" with Le Châtelier's principle.
- Biology: "Copying accuracy and genome length" (Eigen's threshold down to 10⁻¹⁰), "The Hamming distance" for DNA sequences, "Feedback in homeostasis".
- Modelling and physics: "Euler's method" (step size and accuracy), "Radioactive dating".

**Fixes:** in the enzyme kinetics lab the percent sign in "… % of Vmax" could be shown incorrectly; this is fixed, and a new test checks every interface string.

**How it was checked:** each lab's model is checked by its own program in CI (lesson numbers and edge cases); UI tests open the lessons and press the labs' buttons; Python tests (814) and CI on macOS 15 and 26 Apple Silicon.

**One-command install (Apple Silicon):**

```bash
curl -fL -o /tmp/ColiDev.zip "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.15/ColiDev-beta-AppleSilicon.zip" && rm -rf /Applications/ColiDev.app && ditto -x -k /tmp/ColiDev.zip /Applications && xattr -dr com.apple.quarantine /Applications/ColiDev.app 2>/dev/null; open /Applications/ColiDev.app
```

The build is not signed with a Developer ID: if macOS will not open the app, Control-click it in Finder and choose Open.
