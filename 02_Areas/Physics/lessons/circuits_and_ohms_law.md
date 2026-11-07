---
subject: physics
lesson_id: physics.circuits_and_ohms_law
level: intermediate
languages: ru, en
source_checked: 2026-10-26
source_review_interval_days: 365
---

# Электрические цепи и закон Ома / Electric Circuits and Ohm's Law

## Русский

### Цель

Связывать напряжение, ток и сопротивление законом Ома, рассчитывать общее сопротивление при последовательном и параллельном соединении и объяснять, почему параллельное соединение уменьшает сопротивление.

### Идея и механизм

Источник — батарея или генератор — создаёт напряжение V, и оно гонит заряды по цепи; поток зарядов — это ток I. Движущиеся заряды сталкиваются с атомами вещества и теряют энергию, поэтому вещество мешает току. Эту величину называют сопротивлением R и измеряют в омах. Для многих материалов ток прямо пропорционален напряжению и обратно пропорционален сопротивлению: I = V / R. Это закон Ома; такие материалы называют омическими.

При последовательном соединении ток проходит через все резисторы по очереди, и сопротивления складываются: R = R₁ + R₂ + … При параллельном соединении ток делится между ветвями, а складываются обратные величины: 1/R = 1/R₁ + 1/R₂ + … Каждая новая параллельная ветвь — ещё один путь для тока, поэтому общее сопротивление становится меньше самого маленького из сопротивлений ветвей.

### Исследуй и потренируйся

Резисторы 4 Ом и 12 Ом подключены к батарее 6 В. Посчитай общий ток, если они соединены последовательно, и если параллельно. Во сколько раз отличаются токи? Затем проверь, что при параллельном соединении общее сопротивление меньше 4 Ом.

### Вопрос

Резисторы 2 Ом и 6 Ом соединены параллельно и подключены к источнику 12 В. Какой общий ток течёт от источника?

### Варианты

- 8 А: 1/R = 1/2 + 1/6 = 2/3, R = 1,5 Ом, I = 12 / 1,5 = 8 А.
- 1,5 А: сопротивления надо сложить, 12 / (2 + 6) = 1,5 А.
- 2 А: ток определяет большее сопротивление, 12 / 6 = 2 А.

### Ответ

1

### Разбор

При параллельном соединении складываются обратные сопротивления: 1/2 + 1/6 = 3/6 + 1/6 = 4/6 = 2/3, поэтому R = 1,5 Ом. По закону Ома I = 12 В / 1,5 Ом = 8 А. Проверка по ветвям: через 2 Ом идёт 12 / 2 = 6 А, через 6 Ом — 12 / 6 = 2 А, вместе 8 А. Ответ 1,5 А — это последовательное соединение, а 2 А — ток только через одну ветвь.

### Границы модели

Закон Ома выполняется не для всех материалов и устройств: у диодов, ламп накаливания при сильном нагреве и полупроводников ток зависит от напряжения нелинейно. Расчёт считает провода и источник идеальными, без собственного сопротивления. Опыты делай только с батарейками низкого напряжения: бытовая сеть опасна для жизни.

## English

### Goal

Relate voltage, current, and resistance with Ohm's law, calculate total resistance for series and parallel connections, and explain why connecting in parallel lowers resistance.

### Idea and mechanism

A source, such as a battery or generator, creates a voltage V that drives charges around a circuit; the flow of charge is the current I. Moving charges collide with the atoms of a material and lose energy, so the material impedes the current. This quantity is called resistance R and is measured in ohms. For many materials the current is directly proportional to voltage and inversely proportional to resistance: I = V / R. This is Ohm's law, and such materials are called ohmic.

In a series connection the current passes through every resistor in turn, and the resistances add up: R = R₁ + R₂ + … In a parallel connection the current splits among the branches, and the reciprocals add up: 1/R = 1/R₁ + 1/R₂ + … Each new parallel branch is one more path for the current, so the total resistance becomes smaller than the smallest branch resistance.

### Explore and practise

Resistors of 4 Ω and 12 Ω are connected to a 6 V battery. Calculate the total current if they are connected in series and if they are connected in parallel. How many times do the currents differ? Then check that in parallel the total resistance is less than 4 Ω.

### Question

Resistors of 2 Ω and 6 Ω are connected in parallel to a 12 V source. What total current flows from the source?

### Options

- 8 A: 1/R = 1/2 + 1/6 = 2/3, so R = 1.5 Ω and I = 12 / 1.5 = 8 A.
- 1.5 A: the resistances should be added, 12 / (2 + 6) = 1.5 A.
- 2 A: the larger resistance sets the current, 12 / 6 = 2 A.

### Answer

1

### Explanation

In a parallel connection the reciprocal resistances add: 1/2 + 1/6 = 3/6 + 1/6 = 4/6 = 2/3, so R = 1.5 Ω. By Ohm's law I = 12 V / 1.5 Ω = 8 A. Check branch by branch: 12 / 2 = 6 A flows through 2 Ω and 12 / 6 = 2 A through 6 Ω, 8 A together. The answer 1.5 A is the series connection, and 2 A is the current through only one branch.

### Limits

Ohm's law does not hold for every material and device: in diodes, strongly heated light bulbs, and semiconductors the current depends on voltage nonlinearly. The calculation treats the wires and the source as ideal, with no resistance of their own. Experiment only with low-voltage batteries: household mains electricity can kill.

## Sources

- Paul Peter Urone, Roger Hinrichs, *College Physics 2e*, OpenStax, 2022, section 20.2 “Ohm’s Law: Resistance and Simple Circuits” (consulted 2026-10-26): voltage driving current, resistance from collisions of moving charges, I = V/R, and ohmic materials: [OpenStax College Physics 2e, 20.2](https://openstax.org/books/college-physics-2e/pages/20-2-ohms-law-resistance-and-simple-circuits)
- *College Physics 2e*, section 21.1 “Resistors in Series and Parallel” (consulted 2026-10-26): Rs = R₁ + R₂ + … for series and 1/Rp = 1/R₁ + 1/R₂ + … for parallel resistors: [OpenStax College Physics 2e, 21.1](https://openstax.org/books/college-physics-2e/pages/21-1-resistors-in-series-and-parallel)
- The OpenStax pages state their own license terms; the lesson paraphrases the sections and does not copy their text: [OpenStax terms of use](https://openstax.org/terms-of-use)
