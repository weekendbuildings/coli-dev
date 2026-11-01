# ColiDev 0.1.0 Beta 17 — заметки к выпуску / Release notes

**Статус: готовится, ещё не опубликовано. / Status: in preparation, not yet published.**

## Русский

**Главное.** Новый наглядный стиль дошёл до старых тренажёров. 16 из них переделаны полностью: графики с осями, управление мышкой, анимации, крупные показатели, задание с ✓ и свёрнутые пояснения. Ещё у 34 появились заголовок в новом стиле и свёрнутые пояснения о границах модели.

**Переделаны полностью:**
- Путь к ИИ: градиентный спуск (данные и парабола ошибки, по которой прыгает w), «Нейрон учится» (схема нейрона и кривая ошибки), отложенная проверка модели, производная («Сжать h» превращает секущую в касательную), линейный и бинарный поиск (гонка сравнений).
- Мозг: суммация в синапсе (аксон вспыхивает на пороге), потенциал действия (график мембраны по кнопке «Стимул»).
- Жизнь: порог ошибок Эйгена, монеты и энтропия (кнопка «Бросить»), Харди — Вайнберг (100 особей по генотипам), решётка Пеннета (100 случайных потомков), фотосинтез (карта ограничивающего фактора), поток энергии в экосистеме (пирамида).
- Физика: маятник с настоящим периодом, теплообмен (стаканы по температуре), кинетическая энергия (теорема о работе и энергии).

**Доступность:** маятник и ток в цепи учитывают системную настройку «Уменьшить движение».

**Как проверялось:** Python-тесты (817); 43 UI-теста на macOS 15 и 26 Apple Silicon; модели проверяются в CI.

**Установка одной командой (Apple Silicon):**

```bash
curl -fL -o /tmp/ColiDev.zip "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.17/ColiDev-beta-AppleSilicon.zip" && rm -rf /Applications/ColiDev.app && ditto -x -k /tmp/ColiDev.zip /Applications && xattr -dr com.apple.quarantine /Applications/ColiDev.app 2>/dev/null; open /Applications/ColiDev.app
```

Сборка не подписана Developer ID: если macOS не открывает приложение, щёлкни по нему в Finder с Control → «Открыть».

## English

**Highlights.** The new visual style now reaches the older labs. 16 were fully redesigned: charts with axes, mouse control, animations, large readouts, a goal with ✓, and folded explanations. Another 34 gained the new-style header and folded explanations of the model's limits.

**Fully redesigned:**
- Path to AI: gradient descent (the data and the error parabola w hops along), A neuron learns (a neuron diagram and loss curve), the held-out check, the derivative (Shrink h turns the secant into the tangent), and linear versus binary search (a race of comparisons).
- Brain: synaptic summation (the axon flashes at threshold) and the action potential (a membrane trace on Stimulate).
- Life: Eigen's error threshold, coins and entropy (Toss), Hardy–Weinberg (a hundred individuals by genotype), the Punnett square (a hundred random offspring), photosynthesis (a limiting-factor map), and ecosystem energy flow (a pyramid).
- Physics: the pendulum with its true period, heat mixing (beakers by temperature), and kinetic energy (the work–energy theorem).

**Accessibility:** the pendulum and the circuit current respect the system's Reduce Motion setting.

**How it was checked:** Python tests (817); 43 UI tests on macOS 15 and 26 Apple Silicon; models are verified in CI.

**One-command install (Apple Silicon):**

```bash
curl -fL -o /tmp/ColiDev.zip "https://github.com/weekendbuildings/coli-dev/releases/download/v0.1.0-beta.17/ColiDev-beta-AppleSilicon.zip" && rm -rf /Applications/ColiDev.app && ditto -x -k /tmp/ColiDev.zip /Applications && xattr -dr com.apple.quarantine /Applications/ColiDev.app 2>/dev/null; open /Applications/ColiDev.app
```

The build is not signed with a Developer ID: if macOS will not open the app, Control-click it in Finder and choose Open.
