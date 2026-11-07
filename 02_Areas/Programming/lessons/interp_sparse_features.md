---
subject: programming
lesson_id: programming.interp_sparse_features
level: advanced
languages: ru, en
source_checked: 2026-11-07
source_review_interval_days: 180
---

# Разреженные признаки: автокодировщик / Sparse features: an autoencoder

## Русский

### Простыми словами

В уроке «Суперпозиция» сеть сжимала 5 понятий в 2 числа, и отдельное число ничего не значило само по себе. Разреженный автокодировщик пытается сделать обратное: разложить смешанные числа снова на понятия. Он учится описывать каждую точку несколькими признаками из большого словаря, причём так, чтобы одновременно включались немногие. Похоже на краски: зелёный цвет можно записать как «синий плюс жёлтый», и если разрешено брать мало красок, разложение получается понятным. В уроке ты увидишь, что без требования «бери мало» разложение бессмысленно, а со слишком строгим признаки умирают.

**Что нужно знать до.** Урок «Суперпозиция: больше понятий, чем нейронов» (шаг 17): откуда берутся смешанные направления. Урок «Зонды: что знает сеть внутри» (шаг 17). Урок «Векторы и матрицы» (шаг 3): скалярное произведение и длина вектора.

**Если непонятно.** Если неясно, почему 5 понятий помещаются в 2 числа, вернись к уроку «Суперпозиция». Если неясно, что делает ReLU, это функция, которая оставляет положительное число и заменяет отрицательное нулём. Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Построить на чистом Python разреженный автокодировщик, обучить его на активациях с пятью скрытыми понятиями и найти штраф `λ`, при котором он находит все пять понятий. Понять, чем платят за разреженность. Нужно около 40 минут.

### Идея и механизм

**Шаг 1. Данные.** Возьмём ту же игрушку, что в уроке «Суперпозиция». Есть 5 понятий, их направления это 5 стрелок на плоскости, как лучи звезды. Каждое понятие включено редко, с вероятностью 0,1, и тогда добавляет к точке свою стрелку с силой от 0 до 1. Сеть видит только итоговую точку, 2 числа. Создай файл `nano ~/ai-path/sae.py`, вставь и запусти.

```python
import math


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


FEATURES = [(math.cos(2 * math.pi * k / 5), math.sin(2 * math.pi * k / 5)) for k in range(5)]


def sample(rand):
    x = [0.0, 0.0]
    for direction in FEATURES:
        if rand.next() < 0.1:
            value = rand.next()
            x[0] += value * direction[0]
            x[1] += value * direction[1]
    return x


rand = Rand(3)
DATA = [sample(rand) for _ in range(2000)]
print("points:", len(DATA), "| empty (all features off):", sum(1 for x in DATA if x == [0.0, 0.0]))
print("feature 1 points at", [round(v, 3) for v in FEATURES[1]])
rand = Rand(3)
on = 0
for _ in range(2000):
    for direction in FEATURES:
        if rand.next() < 0.1:
            on += 1
            rand.next()
print("features really on per point:", round(on / 2000, 2))
```

```output
points: 2000 | empty (all features off): 1176
feature 1 points at [0.309, 0.951]
features really on per point: 0.5
```

В среднем в точке включено 0,5 понятия, а в 1176 точках из 2000 не включено ни одно. Это и есть *разреженность*: почти всегда почти всё выключено.

**Шаг 2. Автокодировщик.** *Автокодировщик* это сеть, которая учится выдавать на выходе свой же вход. У нас в середине 5 признаков. *Кодер* считает силу каждого признака: `f = ReLU(e · x + b)`. *Декодер* собирает точку обратно: `x̂ = f₁ · d₁ + … + f₅ · d₅`, где `d` это направления признаков длины 1. Ошибка это квадрат промаха плюс штраф за включённые признаки: `|x − x̂|² + λ · (f₁ + … + f₅)`.

Руками: точка `x = (0,8; 0)` от понятия 0 силой 0,8. Пусть у признака строка кодера `e = (1; 0)`, сдвиг `b = −0,1` и направление `d = (1; 0)`. Тогда `f = ReLU(0,8 − 0,1) = 0,7`, `x̂ = (0,7; 0)`, квадрат промаха `0,1² = 0,01`, а штраф при `λ = 0,3` равен `0,3 · 0,7 = 0,21`. Штраф тянет признак к нулю, а промах тянет к 0,8: обучение ищет равновесие. Допиши и запусти.

```python
def train(lam, units=5, epochs=20, rate=0.05, seed=11):
    r = Rand(seed)
    enc = [[r.next() - 0.5, r.next() - 0.5] for _ in range(units)]
    bias = [0.0] * units
    dec = [[row[0], row[1]] for row in enc]
    for _ in range(epochs):
        for x in DATA:
            f = [max(0.0, e[0] * x[0] + e[1] * x[1] + b) for e, b in zip(enc, bias)]
            out = [sum(f[j] * dec[j][i] for j in range(units)) for i in range(2)]
            err = [out[i] - x[i] for i in range(2)]
            for j in range(units):
                g = sum(2 * err[i] * dec[j][i] for i in range(2)) + lam
                for i in range(2):
                    dec[j][i] -= rate * 2 * err[i] * f[j]
                if f[j] > 0:
                    for i in range(2):
                        enc[j][i] -= rate * g * x[i]
                    bias[j] -= rate * g
            for j in range(units):
                norm = math.hypot(dec[j][0], dec[j][1]) or 1.0
                dec[j] = [dec[j][0] / norm, dec[j][1] / norm]
    return enc, bias, dec


def report(lam):
    enc, bias, dec = train(lam)
    counts = [0] * 5
    active, error = 0, 0.0
    for x in DATA:
        f = [max(0.0, e[0] * x[0] + e[1] * x[1] + b) for e, b in zip(enc, bias)]
        out = [sum(f[j] * dec[j][i] for j in range(5)) for i in range(2)]
        error += (out[0] - x[0]) ** 2 + (out[1] - x[1]) ** 2
        active += sum(v > 0 for v in f)
        for j in range(5):
            counts[j] += f[j] > 0
    alive = [d for d, c in zip(dec, counts) if c > 0]
    best = [max([abs(d[0] * t[0] + d[1] * t[1]) for d in alive] or [0.0]) for t in FEATURES]
    found = sum(c > 0.95 for c in best)
    dead = sum(c == 0 for c in counts)
    print(f"lambda {lam}: error {error / len(DATA):.4f}, active per point {active / len(DATA):.2f}, "
          f"found {found} of 5, dead units {dead}")
    return dec


for lam in (0.0, 0.03, 0.3, 1.0, 3.0):
    report(lam)
```

```output
lambda 0.0: error 0.0000, active per point 4.00, found 4 of 5, dead units 0
lambda 0.03: error 0.0002, active per point 0.92, found 3 of 5, dead units 0
lambda 0.3: error 0.0164, active per point 0.48, found 5 of 5, dead units 0
lambda 1.0: error 0.0768, active per point 0.25, found 5 of 5, dead units 0
lambda 3.0: error 0.1570, active per point 0.00, found 0 of 5, dead units 5
```

**Шаг 3. Что ты увидел.** «Нашёл» значит, что для понятия есть живой признак с направлением ближе 0,95 по косинусу. Мёртвый признак ни разу не включился.

- `λ = 0`: промах почти ноль, но в каждой точке включены 4 признака, хотя понятий в среднем 0,5. Такое разложение верно, но бесполезно: оно не говорит, какие понятия здесь есть.
- `λ = 0,03`: признаков уже меньше, но нашлись только 3 понятия из 5.
- `λ = 0,3`: найдены все 5, и признаков в точке 0,48, почти как настоящих понятий. Это лучший случай.
- `λ = 1`: все 5 найдены, но признаков в точке только 0,25: слабые понятия штраф обнуляет. Промах вырос почти в 5 раз.
- `λ = 3`: все признаки мертвы. Штраф больше пользы от любого включения.

Отсюда главная мысль: штраф `λ` выбирает человек, и от него зависит, что мы «найдём» внутри сети. На настоящих моделях так же: размер словаря и штраф меняют набор признаков.

**Шаг 4. Настоящие модели.** В 2023 году Bricken и соавторы из Anthropic в работе «Towards Monosemanticity» обучили такие автокодировщики на одном слое маленького трансформера, со словарём от 512 до 131 072 признаков. Многие признаки оказались понятными людям, хотя отдельные нейроны того же слоя смешивали много смыслов. В 2024 году в «Scaling Monosemanticity» тот же подход применили к Claude 3 Sonnet со словарями до 34 миллионов признаков; среди них, например, признак, который отвечает на упоминания моста Золотые Ворота. Cunningham и соавторы независимо показали похожее на открытых моделях.

**Что здесь спорно.** Признаки автокодировщика это способ описания, а не доказанные «настоящие» единицы мысли модели: другой словарь даст другие признаки, а часть признаков людям непонятна. Хорошо ли они помогают управлять моделью и находить опасное поведение, исследуют до сих пор.

**Учись у тех, кто это создаёт.** [Towards Monosemanticity](https://transformer-circuits.pub/2023/monosemantic-features/index.html) и [Scaling Monosemanticity](https://transformer-circuits.pub/2024/scaling-monosemanticity/index.html), а также статья [Sparse Autoencoders Find Highly Interpretable Features in Language Models](https://arxiv.org/abs/2309.08600).

### Исследуй и потренируйся

В тренажёре ниже серые пунктиры это пять настоящих понятий, точки это данные, цветные стрелки это направления признаков автокодировщика. Выбирай `λ` и смотри, совпадают ли стрелки с пунктирами. В начале стоит `λ = 0`: стрелки есть, но признаков в точке слишком много. Найди `λ`, при котором найдены все пять понятий, а признаков в точке столько же, сколько настоящих понятий.

### Вопрос

При `λ = 0` автокодировщик восстанавливает точки почти без ошибки. Почему его признаки всё же плохие?

### Варианты

- В каждой точке включено около 4 признаков при 0,5 понятия, и разложение ничего не объясняет
- При нулевом штрафе все признаки умирают и ни разу не включаются ни на одной точке данных
- Без штрафа автокодировщик не может обучиться, и его направления остаются случайными

### Ответ

1

### Разбор

Точно восстановить две координаты пятью признаками можно многими способами, и без штрафа сети всё равно какой выбрать. Поэтому она включает почти все признаки сразу, и по ним не понять, какие понятия были в точке. Признаки умирают при очень большом штрафе, а не при нулевом. И обучение без штрафа идёт: ошибка почти ноль, просто решение не то, что нам нужно.

### Границы модели

Данные здесь игрушечные: мы знаем настоящие понятия и можем проверить ответ, а в настоящей модели их никто не знает. Признаков столько же, сколько понятий; в настоящих работах словарь в десятки и тысячи раз больше. Обучение короткое и с одним начальным случаем, другой посев даст немного другие числа.

## English

### In plain words

In «Superposition» a network squeezed 5 concepts into 2 numbers, and a single number meant nothing on its own. A sparse autoencoder tries the reverse: to split the mixed numbers back into concepts. It learns to describe each point with a few features from a large dictionary, so that only a few are on at once. It is like paints: green can be written as "blue plus yellow", and if you may use only a few paints, the breakdown makes sense. In the lesson you will see that without the "use few" requirement the breakdown is meaningless, and with too strict a one the features die.

**What to know first.** «Superposition: more features than neurons» (step 17): where mixed directions come from. «Probes: what a network knows inside» (step 17). «Vectors and Matrices» (step 3): the dot product and a vector's length.

**If something is unclear.** If it is unclear how 5 concepts fit into 2 numbers, go back to «Superposition». If ReLU is unclear, it is a function that keeps a positive number and replaces a negative one with zero. Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Build a sparse autoencoder in pure Python, train it on activations with five hidden concepts and find the penalty `λ` at which it finds all five. Understand what sparsity costs. It takes about 40 minutes.

### Idea and mechanism

**Step 1. The data.** Take the same toy as in «Superposition». There are 5 concepts, and their directions are 5 arrows on a plane, like the rays of a star. Each concept is on rarely, with probability 0.1, and then adds its arrow to the point with a strength from 0 to 1. The network sees only the resulting point, 2 numbers. Create the file `nano ~/ai-path/sae.py`, paste and run it.

```python
import math


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


FEATURES = [(math.cos(2 * math.pi * k / 5), math.sin(2 * math.pi * k / 5)) for k in range(5)]


def sample(rand):
    x = [0.0, 0.0]
    for direction in FEATURES:
        if rand.next() < 0.1:
            value = rand.next()
            x[0] += value * direction[0]
            x[1] += value * direction[1]
    return x


rand = Rand(3)
DATA = [sample(rand) for _ in range(2000)]
print("points:", len(DATA), "| empty (all features off):", sum(1 for x in DATA if x == [0.0, 0.0]))
print("feature 1 points at", [round(v, 3) for v in FEATURES[1]])
rand = Rand(3)
on = 0
for _ in range(2000):
    for direction in FEATURES:
        if rand.next() < 0.1:
            on += 1
            rand.next()
print("features really on per point:", round(on / 2000, 2))
```

```output
points: 2000 | empty (all features off): 1176
feature 1 points at [0.309, 0.951]
features really on per point: 0.5
```

On average 0.5 concepts are on in a point, and in 1176 points out of 2000 none is. That is *sparsity*: nearly everything is off nearly always.

**Step 2. The autoencoder.** An *autoencoder* is a network that learns to output its own input. Ours has 5 features in the middle. The *encoder* computes each feature's strength: `f = ReLU(e · x + b)`. The *decoder* rebuilds the point: `x̂ = f₁ · d₁ + … + f₅ · d₅`, where `d` are the features' directions of length 1. The error is the squared miss plus a penalty for features that are on: `|x − x̂|² + λ · (f₁ + … + f₅)`.

By hand: a point `x = (0.8; 0)` from concept 0 at strength 0.8. Let a feature have encoder row `e = (1; 0)`, bias `b = −0.1` and direction `d = (1; 0)`. Then `f = ReLU(0.8 − 0.1) = 0.7`, `x̂ = (0.7; 0)`, the squared miss is `0.1² = 0.01`, and the penalty at `λ = 0.3` is `0.3 · 0.7 = 0.21`. The penalty pulls the feature towards zero, the miss pulls it towards 0.8: training looks for a balance. Add this and run it.

```python
def train(lam, units=5, epochs=20, rate=0.05, seed=11):
    r = Rand(seed)
    enc = [[r.next() - 0.5, r.next() - 0.5] for _ in range(units)]
    bias = [0.0] * units
    dec = [[row[0], row[1]] for row in enc]
    for _ in range(epochs):
        for x in DATA:
            f = [max(0.0, e[0] * x[0] + e[1] * x[1] + b) for e, b in zip(enc, bias)]
            out = [sum(f[j] * dec[j][i] for j in range(units)) for i in range(2)]
            err = [out[i] - x[i] for i in range(2)]
            for j in range(units):
                g = sum(2 * err[i] * dec[j][i] for i in range(2)) + lam
                for i in range(2):
                    dec[j][i] -= rate * 2 * err[i] * f[j]
                if f[j] > 0:
                    for i in range(2):
                        enc[j][i] -= rate * g * x[i]
                    bias[j] -= rate * g
            for j in range(units):
                norm = math.hypot(dec[j][0], dec[j][1]) or 1.0
                dec[j] = [dec[j][0] / norm, dec[j][1] / norm]
    return enc, bias, dec


def report(lam):
    enc, bias, dec = train(lam)
    counts = [0] * 5
    active, error = 0, 0.0
    for x in DATA:
        f = [max(0.0, e[0] * x[0] + e[1] * x[1] + b) for e, b in zip(enc, bias)]
        out = [sum(f[j] * dec[j][i] for j in range(5)) for i in range(2)]
        error += (out[0] - x[0]) ** 2 + (out[1] - x[1]) ** 2
        active += sum(v > 0 for v in f)
        for j in range(5):
            counts[j] += f[j] > 0
    alive = [d for d, c in zip(dec, counts) if c > 0]
    best = [max([abs(d[0] * t[0] + d[1] * t[1]) for d in alive] or [0.0]) for t in FEATURES]
    found = sum(c > 0.95 for c in best)
    dead = sum(c == 0 for c in counts)
    print(f"lambda {lam}: error {error / len(DATA):.4f}, active per point {active / len(DATA):.2f}, "
          f"found {found} of 5, dead units {dead}")
    return dec


for lam in (0.0, 0.03, 0.3, 1.0, 3.0):
    report(lam)
```

```output
lambda 0.0: error 0.0000, active per point 4.00, found 4 of 5, dead units 0
lambda 0.03: error 0.0002, active per point 0.92, found 3 of 5, dead units 0
lambda 0.3: error 0.0164, active per point 0.48, found 5 of 5, dead units 0
lambda 1.0: error 0.0768, active per point 0.25, found 5 of 5, dead units 0
lambda 3.0: error 0.1570, active per point 0.00, found 0 of 5, dead units 5
```

**Step 3. What you saw.** "Found" means that a concept has a living feature whose direction is closer than 0.95 in cosine. A dead feature never switched on.

- `λ = 0`: the miss is almost zero, but 4 features are on in each point, although there are 0.5 concepts on average. Such a breakdown is correct but useless: it does not say which concepts are present.
- `λ = 0.03`: fewer features now, but only 3 of the 5 concepts were found.
- `λ = 0.3`: all 5 found, with 0.48 features per point, almost as many as real concepts. This is the best case.
- `λ = 1`: all 5 found, but only 0.25 features per point: the penalty zeroes weak concepts. The miss grew almost 5 times.
- `λ = 3`: all features are dead. The penalty outweighs the benefit of any switching on.

Hence the main idea: a person chooses the penalty `λ`, and what we "find" inside a network depends on it. On real models it is the same: the dictionary size and the penalty change the set of features.

**Step 4. Real models.** In 2023 Bricken and co-authors at Anthropic, in "Towards Monosemanticity", trained such autoencoders on one layer of a small transformer, with dictionaries from 512 to 131,072 features. Many features turned out to be understandable to people, although the individual neurons of the same layer mixed many meanings. In 2024, "Scaling Monosemanticity" applied the same approach to Claude 3 Sonnet with dictionaries of up to 34 million features; among them is, for example, a feature that responds to mentions of the Golden Gate Bridge. Cunningham and co-authors independently showed something similar on open models.

**What is disputed.** Autoencoder features are a way of describing, not proven "real" units of the model's thought: another dictionary gives other features, and some features are not understandable to people. How well they help to steer a model and to find dangerous behaviour is still being studied.

**Learn from the people who build this.** [Towards Monosemanticity](https://transformer-circuits.pub/2023/monosemantic-features/index.html) and [Scaling Monosemanticity](https://transformer-circuits.pub/2024/scaling-monosemanticity/index.html), and the paper [Sparse Autoencoders Find Highly Interpretable Features in Language Models](https://arxiv.org/abs/2309.08600).

### Explore and practise

In the lab below the grey dashed lines are the five real concepts, the dots are the data, and the coloured arrows are the directions of the autoencoder's features. Choose `λ` and see whether the arrows match the dashed lines. At the start `λ = 0`: there are arrows, but too many features per point. Find the `λ` at which all five concepts are found and there are as many features per point as real concepts.

### Question

At `λ = 0` the autoencoder rebuilds the points almost without error. Why are its features still bad?

### Options

- About 4 features are on per point against 0.5 concepts, so the breakdown explains nothing
- With zero penalty all features die and never switch on at all on any single point of the data
- Without a penalty the autoencoder cannot train, so its directions simply stay at random

### Answer

1

### Explanation

Two coordinates can be rebuilt exactly with five features in many ways, and without a penalty the network does not care which one to pick. So it switches on almost all features at once, and they do not tell which concepts were in the point. Features die at a very large penalty, not at zero. And training does work without a penalty: the error is almost zero; the solution is just not the one we need.

### Limits

The data here are a toy: we know the real concepts and can check the answer, while in a real model nobody knows them. There are as many features as concepts; in real work the dictionary is tens to thousands of times larger. Training is short and from one starting point; another seed gives slightly different numbers.

## Sources

- Trenton Bricken et al., "Towards Monosemanticity: Decomposing Language Models With Dictionary Learning", Transformer Circuits (2023): a sparse autoencoder on a one-layer transformer, dictionaries from 512 to 131,072 features, read 2026-11-07: [transformer-circuits.pub](https://transformer-circuits.pub/2023/monosemantic-features/index.html)
- Adly Templeton et al., "Scaling Monosemanticity: Extracting Interpretable Features from Claude 3 Sonnet", Transformer Circuits (2024): dictionaries up to 34M features and the Golden Gate Bridge feature, read 2026-11-07: [transformer-circuits.pub](https://transformer-circuits.pub/2024/scaling-monosemanticity/index.html)
- Hoagy Cunningham et al., "Sparse Autoencoders Find Highly Interpretable Features in Language Models", arXiv:2309.08600 (2023), title read 2026-11-07: [arXiv:2309.08600](https://arxiv.org/abs/2309.08600)
- The toy data, the program and all numbers were written for this lesson on 2026-11-07, following the toy model of «Superposition».
