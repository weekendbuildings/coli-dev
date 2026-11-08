---
subject: programming
lesson_id: programming.interp_probes
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Зонды: что знает сеть внутри / Probes: what a network knows inside

## Русский

### Простыми словами

Внутри сети на каждом слое лежат числа, активации. Зонд это маленькая простая модель, которая по этим числам пытается угадать какое-то свойство входа. Если угадывает, значит, сведения там есть. Похоже на детектор металла: он пищит, значит, металл в земле есть, но это ещё не значит, что его кто-то использует. Поэтому найденное направление ещё и убирают и смотрят, станет ли сеть работать хуже.

**Что нужно знать до.** Уроки «Классификация и softmax» (шаг 7) и «Скрытый слой» (шаг 8). Урок «Машинное обучение: baseline» (шаг 9): отложенная проверка.

**Если непонятно.** Если неясно, что такое направление, вспомни векторы из урока «Векторы и матрицы»: это стрелка в пространстве активаций. Если неясен контрольный опыт, перечитай шаг 2 урока. Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Заглянуть внутрь своей сети. Обучить линейный зонд на её активациях, проверить его контрольными опытами и убрать найденное направление, чтобы понять, пользуется ли им сеть. Главный вывод: высокая точность зонда ещё не значит, что сеть это использует. Нужно около 45 минут.

### Идея и механизм

**Шаг 1. Что такое зонд.** Сеть считает числа, и понять их прямо трудно. **Зонд** это маленький простой классификатор, чаще всего логистическая регрессия. На вход он получает **активации** скрытого слоя, а учится отвечать на наш вопрос: например, стоит ли сейчас конец слова. Если зонд отвечает точно, значит, ответ можно прочитать из активаций простой линейной формулой.

Руками: пусть две активации `(1; −2)` и веса зонда `(0,5; −1)`, сдвиг `−1`. Сумма `0,5 · 1 + (−1) · (−2) − 1 = 1,5`, она больше нуля, значит, зонд отвечает «да».

**Шаг 2. Опыт и контроль.** Берём сеть из урока о дообучении: 3 символа на входе, 24 нейрона внутри, тексты вида «кот ест рыбу.». Спрашиваем зонд о трёх вещах: последняя буква гласная, следующий символ это конец слова, сейчас идёт третье слово. Но одной точности мало, поэтому нужны две проверки: как часто верен самый частый ответ, и что покажет тот же зонд на **необученной** сети той же формы. Создай файл `nano ~/ai-path/probes.py`, вставь и запусти. Нужно около 3 секунд.

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


WHO = ["кот", "пёс", "мама", "папа", "дед", "гусь"]
DOES = ["ест", "видит", "любит", "ищет", "несёт"]
WHAT = ["рыбу", "воду", "кашу", "мяч", "дом", "траву"]


def text_of(style, count, seed):
    rand = Rand(seed)
    parts = []
    for _ in range(count):
        phrase = f"{WHO[rand.below(6)]} {DOES[rand.below(5)]} {WHAT[rand.below(6)]}"
        parts.append(phrase + ". " if style == "old" else "ну " + phrase + ", да! ")
    return "".join(parts)


ALPHABET = sorted(set(text_of("old", 400, 1)))
V, CONTEXT, E, H = len(ALPHABET), 3, 6, 24
CODE = {c: i for i, c in enumerate(ALPHABET)}


class Net:
    def __init__(self, seed):
        rand = Rand(seed)
        noise = lambda scale: (rand.next() - 0.5) * scale
        self.embed = [[noise(1.0) for _ in range(E)] for _ in range(V)]
        self.inner = [[noise(0.6) for _ in range(CONTEXT * E)] for _ in range(H)]
        self.inner_bias = [0.0] * H
        self.outer = [[noise(0.3) for _ in range(H)] for _ in range(V)]
        self.outer_bias = [0.0] * V

    def forward(self, context):
        x = [value for c in context for value in self.embed[c]]
        h = [math.tanh(sum(w * v for w, v in zip(row, x)) + bias) for row, bias in zip(self.inner, self.inner_bias)]
        out = [sum(w * v for w, v in zip(row, h)) + bias for row, bias in zip(self.outer, self.outer_bias)]
        top = max(out)
        weights = [math.exp(o - top) for o in out]
        total = sum(weights)
        return x, h, [w / total for w in weights]

    def step(self, context, target, rate):
        x, h, p = self.forward(context)
        error = p[:]
        error[target] -= 1.0
        back = [sum(e * row[j] for e, row in zip(error, self.outer)) for j in range(H)]
        for row, e in zip(self.outer, error):
            for j, value in enumerate(h):
                row[j] -= rate * e * value
        for v, e in enumerate(error):
            self.outer_bias[v] -= rate * e
        into = [0.0] * len(x)
        for j, row in enumerate(self.inner):
            g = back[j] * (1 - h[j] * h[j])
            self.inner_bias[j] -= rate * g
            for i, value in enumerate(x):
                row[i] -= rate * g * value
                into[i] += g * row[i]
        for k, c in enumerate(context):
            for d in range(E):
                self.embed[c][d] -= rate * into[k * E + d]

def train(net, numbers, steps, rate, seed):
    rand = Rand(seed)
    for _ in range(steps):
        i = CONTEXT + rand.below(len(numbers) - CONTEXT)
        net.step(numbers[i - CONTEXT:i], numbers[i], rate)


def encode(text):
    return [CODE[c] for c in text]


OLD = encode(text_of("old", 600, 1))
trained, untouched = Net(3), Net(3)
train(trained, OLD, 6000, 0.03, 4)
VOWELS = set("аеёиоуыэюя")
sample_text = text_of("old", 220, 50)
codes = encode(sample_text)


def rows(net):
    result = []
    for i in range(CONTEXT, len(codes) - 1):
        word_start = sample_text.rfind(". ", 0, i)
        spaces = sample_text.count(" ", word_start + 2, i)
        result.append({"h": net.forward(codes[i - CONTEXT:i])[1],
                       "last_vowel": sample_text[i - 1] in VOWELS,
                       "next_space": sample_text[i] in " .",
                       "third_word": spaces == 2})
    return result


def fit(features, labels, epochs=25, rate=0.05):
    split = len(features) * 3 // 4
    weights, bias = [0.0] * len(features[0]), 0.0
    for _ in range(epochs):
        for x, y in zip(features[:split], labels[:split]):
            s = sum(w * v for w, v in zip(weights, x)) + bias
            p = 1 / (1 + math.exp(-max(min(s, 30), -30)))
            for j, v in enumerate(x):
                weights[j] += rate * (y - p) * v
            bias += rate * (y - p)

    def accuracy(part_x, part_y):
        return round(sum((sum(w * v for w, v in zip(weights, x)) + bias > 0) == y for x, y in zip(part_x, part_y)) / len(part_y), 3)
    return accuracy(features[:split], labels[:split]), accuracy(features[split:], labels[split:]), weights, bias


own, blank = rows(trained), rows(untouched)
rand = Rand(9)
noise = [rand.next() < 0.5 for _ in own]
always = lambda labels: round(max(sum(labels), len(labels) - sum(labels)) / len(labels), 3)
print("samples", len(own))
print("question, always the same answer, trained net train/test, untrained net train/test")
for name in ("last_vowel", "next_space", "third_word"):
    labels = [r[name] for r in own]
    a = fit([r["h"] for r in own], labels)
    b = fit([r["h"] for r in blank], labels)
    print(name, always(labels), a[0], a[1], b[0], b[1])
c = fit([r["h"] for r in own], noise)
print("random labels", always(noise), c[0], c[1])
```

```output
samples 3466
question, always the same answer, trained net train/test, untrained net train/test
last_vowel 0.697 0.986 0.993 0.892 0.877
next_space 0.746 1.0 1.0 0.977 0.979
third_word 0.632 0.989 0.985 0.825 0.84
random labels 0.504 0.503 0.51
```

Читай строку `next_space`. Зонд на обученной сети даёт `1,0`. Звучит как открытие. Но всегда отвечать «нет» уже даёт `0,746`, а **сеть, которая ничему не училась, даёт `0,979`**. Вход проходит через случайные веса и всё равно остаётся в активациях. Значит, большая часть успеха это заслуга входа, а не обучения. Настоящий вклад обучения это разница `1,0` и `0,979`. У строки `third_word` разница больше: `0,985` против `0,84`.

Последняя строка это ещё один контроль, случайные ответы. Зонд даёт около `0,5`, как и должно быть: простой зонд не может заучить бессмыслицу. Hewitt и Liang советуют такую проверку всегда, потому что слишком мощный зонд способен выучить задачу сам.

**Шаг 3. Два направления.** 24 числа не нарисуешь. Найдём два направления, вдоль которых активации меняются сильнее всего: это метод главных компонент, здесь его считает степенной метод. Допиши и запусти.

```python
def top_direction(vectors, seed, skip=None):
    rand = Rand(seed)
    d = [rand.next() - 0.5 for _ in vectors[0]]
    for _ in range(30):
        next_d = [0.0] * len(d)
        for v in vectors:
            s = sum(a * b for a, b in zip(v, d))
            for j, value in enumerate(v):
                next_d[j] += s * value
        if skip:
            s = sum(a * b for a, b in zip(next_d, skip))
            next_d = [a - s * b for a, b in zip(next_d, skip)]
        size = math.sqrt(sum(a * a for a in next_d))
        d = [a / size for a in next_d]
    return d


vectors = [r["h"] for r in own]
middle = [sum(v[j] for v in vectors) / len(vectors) for j in range(H)]
centred = [[a - b for a, b in zip(v, middle)] for v in vectors]
first = top_direction(centred, 1)
second = top_direction(centred, 2, first)
points = [(round(sum(a * b for a, b in zip(v, first)), 2), round(sum(a * b for a, b in zip(v, second)), 2), r["next_space"]) for v, r in zip(centred, own)]
flat = fit([list(p[:2]) for p in points], [p[2] for p in points], epochs=60)
print("two directions keep the question? train/test", flat[0], flat[1])
print(points[:4])
```

```output
two directions keep the question? train/test 1.0 1.0
[(-1.44, -2.05, True), (-1.11, 3.17, False), (1.73, -1.71, False), (0.98, -1.07, False)]
```

Даже в двух измерениях ответ о конце слова отделяется полностью. Именно такие точки ты увидишь в тренажёре.

**Шаг 4. Знает или использует?** Зонд показывает, что сведения **есть**, но не что сеть ими пользуется. Проверить можно опытом: убрать из активаций направление зонда и посмотреть, стала ли сеть хуже. Это идея «амнезии» Elazar и соавторов. Руками: если `h = (1; 2)`, а направление `(1; 0)`, то убираем проекцию и получаем `(0; 2)`. Допиши и запусти.

```python
def loss_without(net, direction=None):
    total, count = 0.0, 0
    for i in range(CONTEXT, len(codes) - 1):
        h = list(net.forward(codes[i - CONTEXT:i])[1])
        if direction:
            s = sum(a * b for a, b in zip(h, direction))
            h = [a - s * b for a, b in zip(h, direction)]
        out = [sum(w * v for w, v in zip(row, h)) + bias for row, bias in zip(net.outer, net.outer_bias)]
        top = max(out)
        weights = [math.exp(o - top) for o in out]
        total -= math.log(weights[codes[i]] / sum(weights))
        count += 1
    return round(total / count, 3)


def unit(vector):
    size = math.sqrt(sum(v * v for v in vector))
    return [v / size for v in vector]


rand = Rand(12)
print("normal loss", loss_without(trained))
print("a random direction removed", loss_without(trained, unit([rand.next() - 0.5 for _ in range(H)])))
for name in ("last_vowel", "next_space", "third_word"):
    weights = fit([r["h"] for r in own], [r[name] for r in own])[2]
    print(name, "direction removed", loss_without(trained, unit(weights)))
```

```output
normal loss 0.44
a random direction removed 0.467
last_vowel direction removed 0.446
next_space direction removed 0.629
third_word direction removed 0.449
```

Обычная ошибка `0,44`. Случайное направление даёт `0,467`, это наша мера шума. Удаление направления `next_space` даёт `0,629`, намного хуже: сеть этим направлением пользуется. А удаление `third_word` даёт `0,449`, почти не меняет ничего, хотя зонд на этот вопрос отвечал с точностью `0,985`. **Сведения в активациях есть, а для предсказания нужны мало.**

**Шаг 5. Что здесь спорно.** Убрать одно направление это грубый опыт: сведения могут лежать в нескольких направлениях, поэтому слабый эффект не доказывает, что они не нужны. Есть и обратная беда: удаление может повредить что-то ещё. Методы зондов широко используют, но вопрос, что они доказывают, до сих пор обсуждается, и обзор Belinkov об этом честно пишет.

**Учись у тех, кто это создаёт.** Обзор [Belinkov о зондах](https://arxiv.org/abs/2102.12452) это хороший вход. Лекция Been Kim в курсе [Stanford CS224N](https://web.stanford.edu/class/cs224n/) объясняет, чего ждать от объяснений. Работа [Hewitt и Liang](https://arxiv.org/abs/1909.03368) показывает контрольные задачи.

### Исследуй и потренируйся

В тренажёре настоящие активации твоей сети в двух главных направлениях. Тащи концы прямой и разделяй точки сам. Меняй вопрос. Затем переключись на необученную сеть и сравни, что выйдет.

В программе увеличь `third_word` до вопроса «сейчас идёт второе слово». Сможет ли зонд ответить? Посмотри, сколько букв видит сеть на входе.

### Вопрос

Зонд отвечает с точностью 98 %. Что это доказывает?

### Варианты

- Сведения можно прочитать из активаций, но неизвестно, пользуется ли ими сама сеть.
- Сеть опирается именно на эти сведения, поэтому без них она сразу перестанет работать.
- Сеть обучилась этому понятию, потому что необученная сеть так ответить не смогла бы.

### Ответ

1

### Разбор

Необученная сеть в опыте тоже дала высокую точность, так что обучение тут доказывать рано. А удаление направления `third_word` почти не изменило ошибку, хотя точность зонда была `0,985`. Значит, точность говорит только о том, что сведения там лежат.

### Границы модели

Сеть здесь крошечная, и её вход всего 3 символа, поэтому почти всё можно понять и без зонда. На настоящих моделях сведения разбросаны сложнее. Метка «третье слово» опирается на разбор текста мной. Удаление одного направления это простейшая проверка: есть и более строгие, но и они спорны.

## English

### In plain words

Inside a network, each layer holds numbers, activations. A probe is a small simple model that tries to guess some property of the input from those numbers. If it guesses well, the information is there. It is like a metal detector: it beeps, so there is metal in the ground, but that does not mean anyone is using it. So the found direction is also removed, to see whether the network starts working worse.

**What to know first.** «Classification and Softmax» (step 7) and «The Hidden Layer» (step 8). «Machine Learning: Baselines» (step 9): held-out evaluation.

**If something is unclear.** If a direction is unclear, recall vectors from «Vectors and Matrices»: it is an arrow in the space of activations. If the control experiment is unclear, reread step 2 of the lesson. Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Look inside your network. Train a linear probe on its activations, test it with control experiments, and remove the direction found, to see whether the network uses it. The main finding: high probe accuracy does not yet mean the network uses that information. It takes about 45 minutes.

### Idea and mechanism

**Step 1. What a probe is.** A network computes numbers, and reading them directly is hard. A **probe** is a small simple classifier, most often logistic regression. It takes a hidden layer's **activations** as input and learns to answer our question, for example whether a word is ending now. If a probe answers accurately, the answer can be read from the activations by a simple linear formula.

By hand: suppose two activations are `(1; −2)`, the probe's weights `(0.5; −1)`, and the shift `−1`. The sum `0.5 · 1 + (−1) · (−2) − 1 = 1.5` is above zero, so the probe answers "yes".

**Step 2. The experiment and the controls.** Take the network from the fine-tuning lesson: 3 characters in, 24 neurons inside, texts such as "кот ест рыбу." We ask the probe three things: is the last letter a vowel, does a word end next, is this the third word. One accuracy is not enough, so two checks are needed: how often the most frequent answer is right, and what the same probe shows on an **untrained** network of the same shape. Create the file `nano ~/ai-path/probes.py`, paste and run it. It takes about 3 seconds.

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


WHO = ["кот", "пёс", "мама", "папа", "дед", "гусь"]
DOES = ["ест", "видит", "любит", "ищет", "несёт"]
WHAT = ["рыбу", "воду", "кашу", "мяч", "дом", "траву"]


def text_of(style, count, seed):
    rand = Rand(seed)
    parts = []
    for _ in range(count):
        phrase = f"{WHO[rand.below(6)]} {DOES[rand.below(5)]} {WHAT[rand.below(6)]}"
        parts.append(phrase + ". " if style == "old" else "ну " + phrase + ", да! ")
    return "".join(parts)


ALPHABET = sorted(set(text_of("old", 400, 1)))
V, CONTEXT, E, H = len(ALPHABET), 3, 6, 24
CODE = {c: i for i, c in enumerate(ALPHABET)}


class Net:
    def __init__(self, seed):
        rand = Rand(seed)
        noise = lambda scale: (rand.next() - 0.5) * scale
        self.embed = [[noise(1.0) for _ in range(E)] for _ in range(V)]
        self.inner = [[noise(0.6) for _ in range(CONTEXT * E)] for _ in range(H)]
        self.inner_bias = [0.0] * H
        self.outer = [[noise(0.3) for _ in range(H)] for _ in range(V)]
        self.outer_bias = [0.0] * V

    def forward(self, context):
        x = [value for c in context for value in self.embed[c]]
        h = [math.tanh(sum(w * v for w, v in zip(row, x)) + bias) for row, bias in zip(self.inner, self.inner_bias)]
        out = [sum(w * v for w, v in zip(row, h)) + bias for row, bias in zip(self.outer, self.outer_bias)]
        top = max(out)
        weights = [math.exp(o - top) for o in out]
        total = sum(weights)
        return x, h, [w / total for w in weights]

    def step(self, context, target, rate):
        x, h, p = self.forward(context)
        error = p[:]
        error[target] -= 1.0
        back = [sum(e * row[j] for e, row in zip(error, self.outer)) for j in range(H)]
        for row, e in zip(self.outer, error):
            for j, value in enumerate(h):
                row[j] -= rate * e * value
        for v, e in enumerate(error):
            self.outer_bias[v] -= rate * e
        into = [0.0] * len(x)
        for j, row in enumerate(self.inner):
            g = back[j] * (1 - h[j] * h[j])
            self.inner_bias[j] -= rate * g
            for i, value in enumerate(x):
                row[i] -= rate * g * value
                into[i] += g * row[i]
        for k, c in enumerate(context):
            for d in range(E):
                self.embed[c][d] -= rate * into[k * E + d]

def train(net, numbers, steps, rate, seed):
    rand = Rand(seed)
    for _ in range(steps):
        i = CONTEXT + rand.below(len(numbers) - CONTEXT)
        net.step(numbers[i - CONTEXT:i], numbers[i], rate)


def encode(text):
    return [CODE[c] for c in text]


OLD = encode(text_of("old", 600, 1))
trained, untouched = Net(3), Net(3)
train(trained, OLD, 6000, 0.03, 4)
VOWELS = set("аеёиоуыэюя")
sample_text = text_of("old", 220, 50)
codes = encode(sample_text)


def rows(net):
    result = []
    for i in range(CONTEXT, len(codes) - 1):
        word_start = sample_text.rfind(". ", 0, i)
        spaces = sample_text.count(" ", word_start + 2, i)
        result.append({"h": net.forward(codes[i - CONTEXT:i])[1],
                       "last_vowel": sample_text[i - 1] in VOWELS,
                       "next_space": sample_text[i] in " .",
                       "third_word": spaces == 2})
    return result


def fit(features, labels, epochs=25, rate=0.05):
    split = len(features) * 3 // 4
    weights, bias = [0.0] * len(features[0]), 0.0
    for _ in range(epochs):
        for x, y in zip(features[:split], labels[:split]):
            s = sum(w * v for w, v in zip(weights, x)) + bias
            p = 1 / (1 + math.exp(-max(min(s, 30), -30)))
            for j, v in enumerate(x):
                weights[j] += rate * (y - p) * v
            bias += rate * (y - p)

    def accuracy(part_x, part_y):
        return round(sum((sum(w * v for w, v in zip(weights, x)) + bias > 0) == y for x, y in zip(part_x, part_y)) / len(part_y), 3)
    return accuracy(features[:split], labels[:split]), accuracy(features[split:], labels[split:]), weights, bias


own, blank = rows(trained), rows(untouched)
rand = Rand(9)
noise = [rand.next() < 0.5 for _ in own]
always = lambda labels: round(max(sum(labels), len(labels) - sum(labels)) / len(labels), 3)
print("samples", len(own))
print("question, always the same answer, trained net train/test, untrained net train/test")
for name in ("last_vowel", "next_space", "third_word"):
    labels = [r[name] for r in own]
    a = fit([r["h"] for r in own], labels)
    b = fit([r["h"] for r in blank], labels)
    print(name, always(labels), a[0], a[1], b[0], b[1])
c = fit([r["h"] for r in own], noise)
print("random labels", always(noise), c[0], c[1])
```

```output
samples 3466
question, always the same answer, trained net train/test, untrained net train/test
last_vowel 0.697 0.986 0.993 0.892 0.877
next_space 0.746 1.0 1.0 0.977 0.979
third_word 0.632 0.989 0.985 0.825 0.84
random labels 0.504 0.503 0.51
```

Read the row `next_space`. The probe on the trained network gives `1.0`. That sounds like a discovery. But always answering "no" already gives `0.746`, and **a network that learned nothing gives `0.979`**. The input passes through random weights and still stays in the activations. So most of the success is the input's, not training's. Training's real contribution is the difference between `1.0` and `0.979`. The row `third_word` has a larger difference: `0.985` against `0.84`.

The last row is another control, random answers. The probe gives about `0.5`, as it should: a simple probe cannot memorize nonsense. Hewitt and Liang advise such a check always, because a very powerful probe can learn the task by itself.

**Step 3. Two directions.** You cannot draw 24 numbers. We find two directions along which activations vary most: that is principal component analysis, computed here by the power method. Add this and run it.

```python
def top_direction(vectors, seed, skip=None):
    rand = Rand(seed)
    d = [rand.next() - 0.5 for _ in vectors[0]]
    for _ in range(30):
        next_d = [0.0] * len(d)
        for v in vectors:
            s = sum(a * b for a, b in zip(v, d))
            for j, value in enumerate(v):
                next_d[j] += s * value
        if skip:
            s = sum(a * b for a, b in zip(next_d, skip))
            next_d = [a - s * b for a, b in zip(next_d, skip)]
        size = math.sqrt(sum(a * a for a in next_d))
        d = [a / size for a in next_d]
    return d


vectors = [r["h"] for r in own]
middle = [sum(v[j] for v in vectors) / len(vectors) for j in range(H)]
centred = [[a - b for a, b in zip(v, middle)] for v in vectors]
first = top_direction(centred, 1)
second = top_direction(centred, 2, first)
points = [(round(sum(a * b for a, b in zip(v, first)), 2), round(sum(a * b for a, b in zip(v, second)), 2), r["next_space"]) for v, r in zip(centred, own)]
flat = fit([list(p[:2]) for p in points], [p[2] for p in points], epochs=60)
print("two directions keep the question? train/test", flat[0], flat[1])
print(points[:4])
```

```output
two directions keep the question? train/test 1.0 1.0
[(-1.44, -2.05, True), (-1.11, 3.17, False), (1.73, -1.71, False), (0.98, -1.07, False)]
```

Even in two dimensions the answer about a word's end separates fully. These are the points you will see in the lab.

**Step 4. Knows or uses?** A probe shows that the information **is there**, not that the network uses it. An experiment can check this: remove the probe's direction from the activations and see whether the network gets worse. This is the "amnesic" idea of Elazar and co-authors. By hand: if `h = (1; 2)` and the direction is `(1; 0)`, remove the projection to get `(0; 2)`. Add this and run it.

```python
def loss_without(net, direction=None):
    total, count = 0.0, 0
    for i in range(CONTEXT, len(codes) - 1):
        h = list(net.forward(codes[i - CONTEXT:i])[1])
        if direction:
            s = sum(a * b for a, b in zip(h, direction))
            h = [a - s * b for a, b in zip(h, direction)]
        out = [sum(w * v for w, v in zip(row, h)) + bias for row, bias in zip(net.outer, net.outer_bias)]
        top = max(out)
        weights = [math.exp(o - top) for o in out]
        total -= math.log(weights[codes[i]] / sum(weights))
        count += 1
    return round(total / count, 3)


def unit(vector):
    size = math.sqrt(sum(v * v for v in vector))
    return [v / size for v in vector]


rand = Rand(12)
print("normal loss", loss_without(trained))
print("a random direction removed", loss_without(trained, unit([rand.next() - 0.5 for _ in range(H)])))
for name in ("last_vowel", "next_space", "third_word"):
    weights = fit([r["h"] for r in own], [r[name] for r in own])[2]
    print(name, "direction removed", loss_without(trained, unit(weights)))
```

```output
normal loss 0.44
a random direction removed 0.467
last_vowel direction removed 0.446
next_space direction removed 0.629
third_word direction removed 0.449
```

The normal error is `0.44`. A random direction gives `0.467`, our measure of noise. Removing the `next_space` direction gives `0.629`, far worse: the network uses that direction. But removing `third_word` gives `0.449`, changing almost nothing, though the probe answered that question with accuracy `0.985`. **The information is in the activations, yet prediction hardly needs it.**

**Step 5. What is disputed here.** Removing one direction is a crude experiment: information may lie in several directions, so a weak effect does not prove it is unneeded. The opposite trouble exists too: removal may damage something else. Probes are widely used, but what they prove is still debated, and Belinkov's survey says so honestly.

**Learn from the people who build this.** [Belinkov's survey of probes](https://arxiv.org/abs/2102.12452) is a good entry. Been Kim's lecture in [Stanford CS224N](https://web.stanford.edu/class/cs224n/) explains what to expect from explanations. The work by [Hewitt and Liang](https://arxiv.org/abs/1909.03368) shows control tasks.

### Explore and practise

The lab has the real activations of your network along two main directions. Drag the ends of the line and separate the points yourself. Change the question. Then switch to the untrained network and compare what comes out.

In the program, change `third_word` to the question "is this the second word". Can the probe answer? See how many letters the network sees at its input.

### Question

A probe answers with 98 % accuracy. What does this prove?

### Options

- The information can be read from activations, but whether the network uses it is unknown.
- The network relies on exactly this information, so without it the network stops working.
- The network has learned this concept, since an untrained network could not answer so.

### Answer

1

### Explanation

The untrained network in the experiment also gave high accuracy, so it is too early to credit training. And removing the `third_word` direction barely changed the error, though the probe's accuracy was `0.985`. So accuracy says only that the information lies there.

### Limits

The network here is tiny, and its input is only 3 characters, so nearly everything can be grasped without a probe. On real models information is spread in more complex ways. The "third word" label relies on my own parsing of the text. Removing one direction is the simplest check: stricter ones exist, and they too are disputed.

## Sources

- Guillaume Alain, Yoshua Bengio, "Understanding intermediate layers using linear classifier probes", arXiv:1610.01644 (2016), title read 2026-11-03: [arXiv:1610.01644](https://arxiv.org/abs/1610.01644)
- John Hewitt, Percy Liang, "Designing and Interpreting Probes with Control Tasks", arXiv:1909.03368 (2019), title read 2026-11-03: [arXiv:1909.03368](https://arxiv.org/abs/1909.03368)
- Yanai Elazar et al., "Amnesic Probing: Behavioral Explanation with Amnesic Counterfactuals", arXiv:2006.00995 (2020), title read 2026-11-03: [arXiv:2006.00995](https://arxiv.org/abs/2006.00995)
- Yonatan Belinkov, "Probing Classifiers: Promises, Shortcomings, and Advances", arXiv:2102.12452 (2021), title read 2026-11-03: [arXiv:2102.12452](https://arxiv.org/abs/2102.12452)
- Stanford CS224N, title read 2026-11-03: [course](https://web.stanford.edu/class/cs224n/)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
