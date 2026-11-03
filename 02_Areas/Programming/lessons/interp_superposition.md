---
subject: programming
lesson_id: programming.interp_superposition
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Суперпозиция: больше понятий, чем нейронов / Superposition: more features than neurons

## Русский

### Цель

Понять, почему нейрон редко значит что-то одно. Обучить игрушечную модель сжимать 5 признаков в 2 числа и увидеть, как при редких данных из весов сама собирается правильная фигура. Посчитать цену такого сжатия. Нужно около 45 минут.

### Идея и механизм

**Шаг 1. Загадка.** Смотрят на нейрон языковой модели, а он включается и на цитатах, и на коде, и на корейском. Почему не одно понятие на нейрон? Гипотеза суперпозиции говорит: понятий намного больше, чем нейронов, и сеть хранит их **наклонными направлениями**, которые почти не мешают друг другу. Если так, то читать нужно не нейроны, а направления. Это гипотеза, хотя у неё много опытных подтверждений.

**Шаг 2. Игрушка.** Модель Elhage и соавторов: на входе 5 **признаков**, сжимаем их в 2 числа и восстанавливаем обратно:

`скрытое = W · x`, `выход = ReLU(Wᵀ · W · x + b)`

Столбец матрицы `W` это вектор признака на плоскости. Если признак встречается редко, его значение чаще всего 0. **Редкость** `S` это доля нулей.

**Шаг 3. Цена руками.** Сколько мешают друг другу соседние векторы правильного пятиугольника единичной длины? Косинус 72° равен `0,309`, а косинус 144° равен `−0,809`. Пусть включён один признак со значением 1. При чтении соседний признак получает помеху `0,309`, а следующий `−0,809`. Отрицательную убирает ReLU. Положительную убирает отрицательный сдвиг `b`. **Нужная часть проходит, помеху срезает порог, но за это платим:** если включатся два соседних признака сразу, они помешают друг другу. Поэтому такое хранение выгодно, только когда признаки редко включаются вместе.

**Шаг 4. Опыт.** Создай файл `nano ~/ai-path/superposition.py`, вставь и запусти. Нужно около 3 секунд. Для каждой редкости печатаем длины пяти векторов, сколько длиннее 0,5, и углы между соседними живыми векторами.

```python
import math


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53

    def below(self, limit):
        return int(self.next() * limit)


def train(features, dims, sparsity, steps, seed, batch=16, rate=0.01):
    rand = Rand(seed)
    w = [[(rand.next() - 0.5) * 0.6 for _ in range(features)] for _ in range(dims)]
    b = [0.0] * features
    params = [row for row in w] + [b]
    m1 = [[0.0] * len(row) for row in params]
    m2 = [[0.0] * len(row) for row in params]
    for step in range(1, steps + 1):
        gw = [[0.0] * features for _ in range(dims)]
        gb = [0.0] * features
        for _ in range(batch):
            x = [rand.next() if rand.next() > sparsity else 0.0 for _ in range(features)]
            hidden = [sum(a * c for a, c in zip(row, x)) for row in w]
            out = [sum(w[d][i] * hidden[d] for d in range(dims)) + b[i] for i in range(features)]
            err = [(max(o, 0.0) - t) * (o > 0) for o, t in zip(out, x)]
            back = [sum(w[d][i] * err[i] for i in range(features)) for d in range(dims)]
            for i in range(features):
                gb[i] += 2 * err[i] / batch
                for d in range(dims):
                    gw[d][i] += 2 * (err[i] * hidden[d] + back[d] * x[i]) / batch
        grads = gw + [gb]
        for row, g, a, c in zip(params, grads, m1, m2):
            for i in range(len(row)):
                a[i] = 0.9 * a[i] + 0.1 * g[i]
                c[i] = 0.999 * c[i] + 0.001 * g[i] * g[i]
                row[i] -= rate * (a[i] / (1 - 0.9 ** step)) / (math.sqrt(c[i] / (1 - 0.999 ** step)) + 1e-8)
    return [[w[d][i] for d in range(dims)] for i in range(features)]


def describe(vectors):
    norms = [math.sqrt(sum(v * v for v in vector)) for vector in vectors]
    alive = [v for v, n in zip(vectors, norms) if n > 0.5]
    angles = sorted(round(math.degrees(math.atan2(v[1], v[0])) % 360) for v in alive) if len(vectors[0]) == 2 else []
    gaps = [(b - a) for a, b in zip(angles, angles[1:] + [angles[0] + 360])] if angles else []
    return [round(n, 2) for n in norms], len(alive), gaps


for sparsity in (0.0, 0.5, 0.8, 0.9, 0.95):
    vectors = train(5, 2, sparsity, 5000, 31)
    print("sparsity", sparsity, *describe(vectors))
```

```output
sparsity 0.0 [0.44, 0.9, 0.53, 0.28, 0.81] 3 [75, 206, 79]
sparsity 0.5 [0.38, 0.9, 0.95, 0.4, 0.95] 3 [87, 177, 96]
sparsity 0.8 [0.99, 0.02, 1.04, 1.03, 0.97] 4 [91, 89, 91, 89]
sparsity 0.9 [1.09, 1.17, 1.09, 1.07, 1.13] 5 [71, 73, 70, 76, 70]
sparsity 0.95 [1.13, 1.15, 1.08, 1.12, 1.04] 5 [73, 70, 71, 76, 70]
```

Смотри сверху вниз. Плотные данные, `S = 0`: живых 3, длины разные. Два числа не могут вместить пять плотных признаков. При `S = 0,8` четыре вектора и углы около 90°: квадрат, а один признак сеть просто бросила, его длина `0,02`. При `S = 0,9` все пять живых и углы около 72°: **пятиугольник**. Его никто не задавал, веса сошлись сами из случайного начала. Это и есть результат статьи Elhage и соавторов, повторённый на чистом Python.

**Шаг 5. Объём.** Те же правила, но 6 признаков в 3 измерениях. Допиши и запусти. Нижняя таблица это попарные скалярные произведения векторов.

```python
vectors = train(6, 3, 0.95, 4000, 32)
norms, alive, _ = describe(vectors)
print("6 features in 3 dimensions", norms, alive)
for vector in vectors:
    print([round(v, 2) for v in vector])
for i, first in enumerate(vectors):
    print([round(sum(a * b for a, b in zip(first, second))) for second in vectors])
```

```output
6 features in 3 dimensions [1.02, 1.03, 1.01, 0.98, 1.02, 1.03] 6
[-0.83, -0.25, 0.54]
[-0.3, -0.63, -0.75]
[0.81, 0.26, -0.54]
[0.26, 0.61, 0.73]
[0.52, -0.75, 0.44]
[-0.52, 0.77, -0.45]
[1, 0, -1, 0, 0, 0]
[0, 1, 0, -1, 0, 0]
[-1, 0, 1, 0, 0, 0]
[0, -1, 0, 1, 0, 0]
[0, 0, 0, 0, 1, -1]
[0, 0, 0, 0, -1, 1]
```

Все 6 живы. В таблице видно по одной `−1` в каждой строке, остальное нули. Значит, векторы разбились на пары строго напротив друг друга, а пары взаимно перпендикулярны. Такая фигура это **октаэдр**, в тренажёре ты покрутишь его мышью. Вектор напротив мешает меньше всего: ReLU срезает отрицательную помеху целиком.

**Шаг 6. Зачем это знать.** Если сети хранят понятия наклонно, то отдельный нейрон запутан, и искать смысл нужно в направлениях. Отсюда следующий инструмент: разреженные автокодировщики, которые ищут эти направления в настоящих моделях. Спорно, насколько эта картина верна для больших моделей: есть и нелинейные признаки, и работы, которые показывают пределы таких методов. Это активная область.

**Учись у тех, кто это создаёт.** Статья [Toy Models of Superposition](https://transformer-circuits.pub/2022/toy_model/index.html) это одна из самых красивых работ в области, читай с рисунками. Следующий шаг: [Towards Monosemanticity](https://transformer-circuits.pub/2023/monosemantic-features/index.html).

### Исследуй и потренируйся

В тренажёре сеть учится прямо у тебя на глазах по тем же формулам. Двигай редкость и смотри, как на плоскости складывается фигура из пяти векторов. Затем переключись на 6 признаков в 3 измерениях и крути объёмную фигуру.

В программе сделай признаки неравными: ошибку признака `i` умножь на `0,9 ** i`. Какие признаки сеть бросит первыми?

### Вопрос

Почему при редких признаках сеть может хранить больше понятий, чем у неё измерений?

### Варианты

- Редкие признаки почти не включаются вместе, поэтому помеха срезается порогом и почти не вредит.
- Редкие признаки занимают меньше места в памяти, поэтому в те же числа их можно вместить больше.
- Редкие признаки становятся строго перпендикулярными, поэтому друг другу они совсем не мешают.

### Ответ

1

### Разбор

В двух измерениях строго перпендикулярны только два вектора, а у пятиугольника косинус соседних `0,309`, так что помеха есть. Числа в памяти те же. Выгода в том, что помеха срабатывает лишь тогда, когда признаки включаются вместе, а при редких данных это случается редко.

### Границы модели

Это игрушка, а не языковая модель: данные искусственные, признаки независимы и равны по важности. При плотных данных статья получает другую картину, потому что там признаки неравны; у меня живых 3 с неровными длинами. Результат зависит от случайного начала и числа шагов: иногда один вектор отстаёт. Переносить фигуры на большие модели прямо нельзя.

## English

### Goal

Understand why a neuron rarely means one thing. Train a toy model to squeeze 5 features into 2 numbers and watch the right figure assemble itself from the weights when data is sparse. Compute the price of this squeezing. It takes about 45 minutes.

### Idea and mechanism

**Step 1. The puzzle.** People look at a neuron in a language model, and it fires on quotations, on code, and on Korean. Why not one concept per neuron? The superposition hypothesis says: there are far more concepts than neurons, and a network stores them as **slanted directions** that barely disturb one another. If so, you should read directions, not neurons. It is a hypothesis, though with much experimental support.

**Step 2. The toy.** The model of Elhage and co-authors: 5 **features** come in, we squeeze them into 2 numbers and restore them:

`hidden = W · x`, `output = ReLU(Wᵀ · W · x + b)`

A column of the matrix `W` is a feature's vector on the plane. If a feature is rare, its value is mostly 0. **Sparsity** `S` is the share of zeros.

**Step 3. The price by hand.** How much do neighbouring vectors of a regular pentagon of unit length disturb each other? The cosine of 72° is `0.309`, and of 144° it is `−0.809`. Suppose one feature is on with value 1. On reading, the neighbouring feature gets interference `0.309`, and the next one `−0.809`. ReLU removes the negative one. The negative shift `b` removes the positive one. **The needed part passes, the threshold cuts the interference, but we pay for it:** if two neighbouring features fire together, they disturb each other. So this storage pays only when features rarely fire together.

**Step 4. The experiment.** Create the file `nano ~/ai-path/superposition.py`, paste and run it. It takes about 3 seconds. For each sparsity we print the lengths of the five vectors, how many exceed 0.5, and the angles between neighbouring live vectors.

```python
import math


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53

    def below(self, limit):
        return int(self.next() * limit)


def train(features, dims, sparsity, steps, seed, batch=16, rate=0.01):
    rand = Rand(seed)
    w = [[(rand.next() - 0.5) * 0.6 for _ in range(features)] for _ in range(dims)]
    b = [0.0] * features
    params = [row for row in w] + [b]
    m1 = [[0.0] * len(row) for row in params]
    m2 = [[0.0] * len(row) for row in params]
    for step in range(1, steps + 1):
        gw = [[0.0] * features for _ in range(dims)]
        gb = [0.0] * features
        for _ in range(batch):
            x = [rand.next() if rand.next() > sparsity else 0.0 for _ in range(features)]
            hidden = [sum(a * c for a, c in zip(row, x)) for row in w]
            out = [sum(w[d][i] * hidden[d] for d in range(dims)) + b[i] for i in range(features)]
            err = [(max(o, 0.0) - t) * (o > 0) for o, t in zip(out, x)]
            back = [sum(w[d][i] * err[i] for i in range(features)) for d in range(dims)]
            for i in range(features):
                gb[i] += 2 * err[i] / batch
                for d in range(dims):
                    gw[d][i] += 2 * (err[i] * hidden[d] + back[d] * x[i]) / batch
        grads = gw + [gb]
        for row, g, a, c in zip(params, grads, m1, m2):
            for i in range(len(row)):
                a[i] = 0.9 * a[i] + 0.1 * g[i]
                c[i] = 0.999 * c[i] + 0.001 * g[i] * g[i]
                row[i] -= rate * (a[i] / (1 - 0.9 ** step)) / (math.sqrt(c[i] / (1 - 0.999 ** step)) + 1e-8)
    return [[w[d][i] for d in range(dims)] for i in range(features)]


def describe(vectors):
    norms = [math.sqrt(sum(v * v for v in vector)) for vector in vectors]
    alive = [v for v, n in zip(vectors, norms) if n > 0.5]
    angles = sorted(round(math.degrees(math.atan2(v[1], v[0])) % 360) for v in alive) if len(vectors[0]) == 2 else []
    gaps = [(b - a) for a, b in zip(angles, angles[1:] + [angles[0] + 360])] if angles else []
    return [round(n, 2) for n in norms], len(alive), gaps


for sparsity in (0.0, 0.5, 0.8, 0.9, 0.95):
    vectors = train(5, 2, sparsity, 5000, 31)
    print("sparsity", sparsity, *describe(vectors))
```

```output
sparsity 0.0 [0.44, 0.9, 0.53, 0.28, 0.81] 3 [75, 206, 79]
sparsity 0.5 [0.38, 0.9, 0.95, 0.4, 0.95] 3 [87, 177, 96]
sparsity 0.8 [0.99, 0.02, 1.04, 1.03, 0.97] 4 [91, 89, 91, 89]
sparsity 0.9 [1.09, 1.17, 1.09, 1.07, 1.13] 5 [71, 73, 70, 76, 70]
sparsity 0.95 [1.13, 1.15, 1.08, 1.12, 1.04] 5 [73, 70, 71, 76, 70]
```

Read from top to bottom. Dense data, `S = 0`: 3 live, with different lengths. Two numbers cannot hold five dense features. At `S = 0.8` four vectors and angles near 90°: a square, and the network simply dropped one feature, of length `0.02`. At `S = 0.9` all five live and angles near 72°: a **pentagon**. Nobody specified it; the weights converged to it from a random start. This is the result of the paper by Elhage and co-authors, repeated in plain Python.

**Step 5. In 3D.** The same rules, but 6 features in 3 dimensions. Add this and run it. The lower table holds the pairwise dot products of the vectors.

```python
vectors = train(6, 3, 0.95, 4000, 32)
norms, alive, _ = describe(vectors)
print("6 features in 3 dimensions", norms, alive)
for vector in vectors:
    print([round(v, 2) for v in vector])
for i, first in enumerate(vectors):
    print([round(sum(a * b for a, b in zip(first, second))) for second in vectors])
```

```output
6 features in 3 dimensions [1.02, 1.03, 1.01, 0.98, 1.02, 1.03] 6
[-0.83, -0.25, 0.54]
[-0.3, -0.63, -0.75]
[0.81, 0.26, -0.54]
[0.26, 0.61, 0.73]
[0.52, -0.75, 0.44]
[-0.52, 0.77, -0.45]
[1, 0, -1, 0, 0, 0]
[0, 1, 0, -1, 0, 0]
[-1, 0, 1, 0, 0, 0]
[0, -1, 0, 1, 0, 0]
[0, 0, 0, 0, 1, -1]
[0, 0, 0, 0, -1, 1]
```

All 6 are alive. The table has one `−1` in each row and zeros elsewhere. So the vectors split into pairs pointing exactly opposite, and the pairs are mutually perpendicular. That figure is an **octahedron**, and in the lab you can turn it with the mouse. An opposite vector disturbs least: ReLU cuts its negative interference entirely.

**Step 6. Why know this.** If networks store concepts at a slant, a single neuron is tangled, and meaning must be sought in directions. Hence the next tool: sparse autoencoders, which look for these directions in real models. How true this picture is for large models is disputed: there are nonlinear features too, and work showing the limits of such methods. It is an active field.

**Learn from the people who build this.** [Toy Models of Superposition](https://transformer-circuits.pub/2022/toy_model/index.html) is one of the most beautiful works in the field; read it with the pictures. The next step: [Towards Monosemanticity](https://transformer-circuits.pub/2023/monosemantic-features/index.html).

### Explore and practise

In the lab a network trains right before your eyes by the same formulas. Move the sparsity and watch a figure of five vectors form on the plane. Then switch to 6 features in 3 dimensions and turn the solid figure.

In the program, make features unequal: multiply feature `i`'s error by `0.9 ** i`. Which features does the network drop first?

### Question

Why can a network with sparse features store more concepts than it has dimensions?

### Options

- Sparse features rarely fire together, so a threshold cuts the interference and it hardly harms.
- Sparse features take up less room in memory, so more of them fit into the same numbers.
- Sparse features become strictly perpendicular, so they do not disturb each other at all.

### Answer

1

### Explanation

In two dimensions only two vectors can be strictly perpendicular, and a pentagon's neighbours have cosine `0.309`, so interference exists. The numbers in memory are the same. The gain is that interference acts only when features fire together, and with sparse data that happens rarely.

### Limits

This is a toy, not a language model: the data is artificial, with independent features of equal importance. For dense data the paper gets a different picture because its features are unequal; mine has 3 live with uneven lengths. The result depends on the random start and the number of steps: sometimes one vector lags. The figures do not carry over directly to large models.

## Sources

- Nelson Elhage et al., "Toy Models of Superposition", Transformer Circuits Thread (2022), arXiv:2209.10652, title read 2026-11-03; the model and the figures are recalled from the paper and reproduced by the program: [paper](https://transformer-circuits.pub/2022/toy_model/index.html), [arXiv:2209.10652](https://arxiv.org/abs/2209.10652)
- Trenton Bricken et al., "Towards Monosemanticity", Transformer Circuits Thread (2023), recalled: [paper](https://transformer-circuits.pub/2023/monosemantic-features/index.html)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
