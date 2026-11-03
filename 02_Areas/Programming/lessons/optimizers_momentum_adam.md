---
subject: programming
lesson_id: programming.optimizers_momentum_adam
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Оптимизаторы: импульс и Adam / Optimizers: momentum and Adam

## Русский

### Цель

Понять, почему обычный градиентный спуск ползёт по длинной долине, а импульс и Adam идут быстрее. Посчитать один шаг каждого правила руками, сравнить их в настоящем опыте и увидеть пути на объёмной модели. Нужно около 40 минут.

### Идея и механизм

**Шаг 1. Почему шаг нельзя просто увеличить.** Возьмём рельеф ошибки `0,005x² + y²`. Вдоль `x` он пологий, поперёк `y` крутой: это длинная узкая долина. В настоящих сетях такие долины обычны. Минимум лежит в точке `(0; 0)`, а старт в `(−8; 2)`.

Обычный спуск делает `y ← y − шаг · 2y = y · (1 − 2 · шаг)`. Подставим числа:

- шаг 0,9: `y` умножается на −0,8. Он меняет знак, то есть прыгает через дно, но уменьшается.
- шаг 1,01: `y` умножается на −1,02. Он растёт с каждым шагом, и спуск расходится.

Значит, шаг ограничен самым крутым направлением: не больше 1. А вдоль `x` при шаге 0,99 координата умножается всего на `1 − 0,01 · 0,99 ≈ 0,99`. Это очень медленно. **Крутая стена запрещает большой шаг, а без большого шага пологое дно не пройти.**

**Шаг 2. Два исправления.**

*Импульс* копит скорость, как шар на склоне: `v ← 0,9 · v + g`, затем `x ← x − шаг · v`. Там, где градиент всё время смотрит в одну сторону, скорость растёт. Там, где он меняет знак, части скорости гасят друг друга. Как раз это и нужно долине.

*Adam* делит шаг по каждой оси на типичный размер градиента по этой оси. Посчитаем первый шаг при шаге обучения 0,5. Он хранит среднее градиента `m` и среднее квадрата `s`, а в начале исправляет их на малое число накопленных шагов. После первого шага исправленное `m` равно `g`, а исправленное `s` равно `g²`. Сдвиг равен `0,5 · g / √(g²) = 0,5`, какой бы ни был градиент. Поэтому первый шаг идёт на 0,5 и по пологой, и по крутой оси.

**Шаг 3. Опыт.** Создай файл `nano ~/ai-path/valley.py`, вставь программу и запусти. В таблице правило, шаг обучения и сколько шагов нужно, чтобы ошибка стала меньше 0,01. `None` значит, что за 1500 шагов цель не достигнута.

```python
import math


def loss(x, y):
    return 0.005 * x * x + y * y


def slope(x, y):
    return 0.01 * x, 2 * y


START = (-8.0, 2.0)


def plain(rate, steps=1500):
    x, y = START
    path = [(x, y)]
    for _ in range(steps):
        gx, gy = slope(x, y)
        x, y = x - rate * gx, y - rate * gy
        path.append((x, y))
    return path


def momentum(rate, beta=0.9, steps=1500):
    x, y = START
    vx, vy = 0.0, 0.0
    path = [(x, y)]
    for _ in range(steps):
        gx, gy = slope(x, y)
        vx, vy = beta * vx + gx, beta * vy + gy
        x, y = x - rate * vx, y - rate * vy
        path.append((x, y))
    return path


def adam(rate, beta1=0.9, beta2=0.999, steps=1500):
    x, y = START
    m1x, m1y, m2x, m2y = 0.0, 0.0, 0.0, 0.0
    path = [(x, y)]
    for t in range(1, steps + 1):
        gx, gy = slope(x, y)
        m1x, m1y = beta1 * m1x + (1 - beta1) * gx, beta1 * m1y + (1 - beta1) * gy
        m2x, m2y = beta2 * m2x + (1 - beta2) * gx * gx, beta2 * m2y + (1 - beta2) * gy * gy
        fix1, fix2 = 1 - beta1 ** t, 1 - beta2 ** t
        x -= rate * (m1x / fix1) / (math.sqrt(m2x / fix2) + 1e-8)
        y -= rate * (m1y / fix1) / (math.sqrt(m2y / fix2) + 1e-8)
        path.append((x, y))
    return path


def steps_to(path, goal=0.01):
    for step, (x, y) in enumerate(path):
        if loss(x, y) < goal:
            return step
    return None


for name, rule, rates in (
    ("plain", plain, (0.1, 0.5, 0.9, 0.99, 1.01)),
    ("momentum", momentum, (0.1, 0.3, 0.5, 1.0)),
    ("adam", adam, (0.1, 0.5, 1.0)),
):
    for rate in rates:
        print(name, rate, steps_to(rule(rate)))
```

```output
plain 0.1 None
plain 0.5 346
plain 0.9 192
plain 0.99 187
plain 1.01 None
momentum 0.1 166
momentum 0.3 55
momentum 0.5 36
momentum 1.0 41
adam 0.1 87
adam 0.5 15
adam 1.0 9
```

Обычный спуск при лучшем шаге 0,99 тратит 187 шагов, а при 1,01 расходится. Импульс при 0,5 тратит 36, а Adam при 1,0 тратит 9. Посмотрим на первые шаги. Допиши:

```python
print([(round(x, 2), round(y, 2)) for x, y in plain(0.9)[:4]])
print([(round(x, 2), round(y, 2)) for x, y in momentum(0.3)[:4]])
print([(round(x, 2), round(y, 2)) for x, y in adam(0.5)[:4]])
```

```output
[(-8.0, 2.0), (-7.93, -1.6), (-7.86, 1.28), (-7.79, -1.02)]
[(-8.0, 2.0), (-7.98, 0.8), (-7.93, -0.76), (-7.87, -1.71)]
[(-8.0, 2.0), (-7.5, 1.5), (-7.0, 1.01), (-6.5, 0.54)]
```

В первой строке обычный спуск при шаге 0,9: `y` прыгает со знаком, а `x` еле движется. Во второй импульс: `x` уже набирает ход. В третьей Adam: по обеим осям ровно по 0,5 в первый шаг.

**Что это значит на практике.** Не вывод «Adam всегда лучше». Здесь игрушка в двух измерениях, а в настоящих сетях миллионы весов и шум от случайных пакетов. Там Adam часто берут как хорошее начало: авторы предложили шаг 0,001 по умолчанию. Иногда лучше обобщает обычный спуск с импульсом, и это предмет споров. Шаг обучения по-прежнему важен для всех правил, как видно в таблице: Adam при 0,1 тратит уже 87 шагов.

**Учись у тех, кто это создаёт.** Обзор Себастьяна Рудера хорошо сравнивает правила, а исходная работа об Adam написана Кингмой и Ба. Карпатый строит обучение на Adam в лекции «Let's build GPT». Ссылки в разделе источников.

### Исследуй и потренируйся

В тренажёре настоящая долина: высота это настоящая ошибка, её можно крутить мышью. Три шарика катятся по одним и тем же формулам, что и в программе. Нажми «Пуск», и за ними потянутся следы. Двигай шаг каждого правила. Щелчок по поверхности задаёт новый старт.

В программе поменяй долину на `0,05x² + y²`, в 10 раз более круглую, и не забудь градиент. Насколько теперь отстаёт обычный спуск?

### Вопрос

Почему обычному спуску на этой долине нельзя поставить шаг больше 1?

### Варианты

- По крутой оси каждый шаг умножает `y` на `1 − 2 · шаг`, и при шаге больше 1 он растёт.
- По пологой оси ошибка почти плоская, и при большом шаге градиент там совсем пропадает.
- Формула спуска определена только для шага до единицы, и больший шаг в ней не имеет смысла.

### Ответ

1

### Разбор

Формула работает при любом шаге, но при шаге больше 1 множитель по `y` становится по модулю больше единицы, и `y` растёт. Пологая ось тут ни при чём: на ней шаг можно было бы взять намного больше, но крутая ось не даёт.

### Границы модели

Это двумерная игрушка с плавным рельефом и без шума, поэтому числа шагов нельзя переносить на настоящие сети. Я подбирал шаги вручную по небольшой сетке. Цель в 0,01 тоже выбрана мной: при другой цели разрыв изменится. В настоящем обучении важны ещё расписание шага и ослабление весов, и обычно берут вариант AdamW.

## English

### Goal

Understand why plain gradient descent crawls along a long valley while momentum and Adam go faster. Compute one step of each rule by hand, compare them in a real experiment, and see the paths on a 3D model. It takes about 40 minutes.

### Idea and mechanism

**Step 1. Why the step cannot simply grow.** Take the error relief `0.005x² + y²`. Along `x` it is gentle, across `y` it is steep: a long narrow valley. Such valleys are common in real networks. The minimum lies at `(0, 0)`, and the start is at `(−8, 2)`.

Plain descent does `y ← y − step · 2y = y · (1 − 2 · step)`. Put in numbers:

- step 0.9: `y` is multiplied by −0.8. It changes sign, jumping over the bottom, but it shrinks.
- step 1.01: `y` is multiplied by −1.02. It grows with each step, and descent diverges.

So the step is limited by the steepest direction: at most 1. And along `x` at step 0.99 the coordinate is multiplied by only `1 − 0.01 · 0.99 ≈ 0.99`. That is very slow. **The steep wall forbids a large step, and without a large step the gentle floor cannot be crossed.**

**Step 2. Two fixes.**

*Momentum* builds up speed, like a ball on a slope: `v ← 0.9 · v + g`, then `x ← x − step · v`. Where the gradient keeps pointing one way, speed grows. Where it changes sign, parts of the speed cancel. That is just what a valley needs.

*Adam* divides the step on each axis by the typical size of the gradient on that axis. Let us compute the first step at a learning rate of 0.5. It keeps a mean of the gradient `m` and a mean of its square `s`, and early on it corrects them for the small number of steps so far. After the first step the corrected `m` equals `g`, and the corrected `s` equals `g²`. The shift is `0.5 · g / √(g²) = 0.5`, whatever the gradient. So the first step goes 0.5 along both the gentle and the steep axis.

**Step 3. The experiment.** Create a file with `nano ~/ai-path/valley.py`, paste the program, and run it. The table gives the rule, the learning rate, and how many steps are needed for the error to fall below 0.01. `None` means the goal was not reached in 1500 steps.

```python
import math


def loss(x, y):
    return 0.005 * x * x + y * y


def slope(x, y):
    return 0.01 * x, 2 * y


START = (-8.0, 2.0)


def plain(rate, steps=1500):
    x, y = START
    path = [(x, y)]
    for _ in range(steps):
        gx, gy = slope(x, y)
        x, y = x - rate * gx, y - rate * gy
        path.append((x, y))
    return path


def momentum(rate, beta=0.9, steps=1500):
    x, y = START
    vx, vy = 0.0, 0.0
    path = [(x, y)]
    for _ in range(steps):
        gx, gy = slope(x, y)
        vx, vy = beta * vx + gx, beta * vy + gy
        x, y = x - rate * vx, y - rate * vy
        path.append((x, y))
    return path


def adam(rate, beta1=0.9, beta2=0.999, steps=1500):
    x, y = START
    m1x, m1y, m2x, m2y = 0.0, 0.0, 0.0, 0.0
    path = [(x, y)]
    for t in range(1, steps + 1):
        gx, gy = slope(x, y)
        m1x, m1y = beta1 * m1x + (1 - beta1) * gx, beta1 * m1y + (1 - beta1) * gy
        m2x, m2y = beta2 * m2x + (1 - beta2) * gx * gx, beta2 * m2y + (1 - beta2) * gy * gy
        fix1, fix2 = 1 - beta1 ** t, 1 - beta2 ** t
        x -= rate * (m1x / fix1) / (math.sqrt(m2x / fix2) + 1e-8)
        y -= rate * (m1y / fix1) / (math.sqrt(m2y / fix2) + 1e-8)
        path.append((x, y))
    return path


def steps_to(path, goal=0.01):
    for step, (x, y) in enumerate(path):
        if loss(x, y) < goal:
            return step
    return None


for name, rule, rates in (
    ("plain", plain, (0.1, 0.5, 0.9, 0.99, 1.01)),
    ("momentum", momentum, (0.1, 0.3, 0.5, 1.0)),
    ("adam", adam, (0.1, 0.5, 1.0)),
):
    for rate in rates:
        print(name, rate, steps_to(rule(rate)))
```

```output
plain 0.1 None
plain 0.5 346
plain 0.9 192
plain 0.99 187
plain 1.01 None
momentum 0.1 166
momentum 0.3 55
momentum 0.5 36
momentum 1.0 41
adam 0.1 87
adam 0.5 15
adam 1.0 9
```

Plain descent at its best step of 0.99 takes 187 steps, and at 1.01 it diverges. Momentum at 0.5 takes 36, and Adam at 1.0 takes 9. Let us look at the first steps. Add this:

```python
print([(round(x, 2), round(y, 2)) for x, y in plain(0.9)[:4]])
print([(round(x, 2), round(y, 2)) for x, y in momentum(0.3)[:4]])
print([(round(x, 2), round(y, 2)) for x, y in adam(0.5)[:4]])
```

```output
[(-8.0, 2.0), (-7.93, -1.6), (-7.86, 1.28), (-7.79, -1.02)]
[(-8.0, 2.0), (-7.98, 0.8), (-7.93, -0.76), (-7.87, -1.71)]
[(-8.0, 2.0), (-7.5, 1.5), (-7.0, 1.01), (-6.5, 0.54)]
```

The first line is plain descent at step 0.9: `y` jumps in sign and `x` barely moves. The second is momentum: `x` is already gaining speed. The third is Adam: exactly 0.5 on both axes in the first step.

**What this means in practice.** Not the conclusion "Adam is always better". This is a toy in two dimensions, and real networks have millions of weights and noise from random batches. There Adam is often taken as a good start: its authors proposed a default rate of 0.001. Sometimes plain descent with momentum generalizes better, and this is disputed. The learning rate still matters for all rules, as the table shows: Adam at 0.1 already takes 87 steps.

**Learn from those who build this.** Sebastian Ruder's overview compares the rules well, and the original Adam work is by Kingma and Ba. Karpathy trains with Adam in the lecture "Let's build GPT". The links are in the sources.

### Explore and practise

The lab holds a real valley: its height is the real error, and you can turn it with the mouse. Three balls roll by the same formulas as in the program. Press Play, and trails stretch behind them. Move the step of each rule. A click on the surface sets a new start.

In the program, change the valley to `0.05x² + y²`, ten times rounder, and do not forget the gradient. How far does plain descent lag now?

### Question

Why can plain descent not take a step above 1 on this valley?

### Options

- On the steep axis each step multiplies `y` by `1 − 2 · step`, and above 1 it grows.
- On the gentle axis the error is nearly flat, and at a large step the gradient vanishes.
- The descent formula is defined only for steps up to one, and a larger one means nothing.

### Answer

1

### Explanation

The formula works at any step, but above 1 the multiplier on `y` exceeds one in size, and `y` grows. The gentle axis plays no part: there the step could be far larger, but the steep axis does not allow it.

### Limits

This is a two-dimensional toy with a smooth relief and no noise, so step counts cannot be carried over to real networks. I chose the steps by hand on a small grid. The goal of 0.01 is my choice too: with another goal the gap changes. Real training also needs a step schedule and weight decay, and usually uses the AdamW variant.

## Sources

- Diederik P. Kingma, Jimmy Ba, "Adam: A Method for Stochastic Optimization", arXiv:1412.6980 (2014), title read 2026-11-02; the rule and its default values are recalled from the paper's algorithm: [arXiv:1412.6980](https://arxiv.org/abs/1412.6980)
- Sebastian Ruder, "An overview of gradient descent optimization algorithms", arXiv:1609.04747 (2016), title read 2026-11-02: [arXiv:1609.04747](https://arxiv.org/abs/1609.04747)
- Andrej Karpathy, "Let's build GPT", in Neural Networks: Zero to Hero (consulted 2026-11-02): [Zero to Hero](https://karpathy.ai/zero-to-hero.html)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
