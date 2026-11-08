---
subject: programming
lesson_id: programming.finetuning_and_lora
level: advanced
languages: ru, en
source_checked: 2026-11-07
source_review_interval_days: 365
---

# Дообучение и LoRA / Fine-tuning and LoRA

## Русский

### Простыми словами

Обучить большую модель с нуля очень дорого. Дешевле взять готовую и дообучить на своих примерах: модель уже знает язык, ей нужно лишь освоить новый стиль. LoRA идёт ещё дальше: основные веса не трогают, а рядом ставят маленькую добавку и учат только её. Как съёмная насадка на инструмент: снял её, и инструмент в точности прежний. Учить приходится гораздо меньше чисел, а у больших моделей в тысячи раз меньше.

**Что нужно знать до.** Урок «Своя языковая модель» (шаг 12). Урок «Векторы и матрицы» (шаг 3): размер матрицы. Урок «Мини-батчи и переобучение» (шаг 9).

**Если непонятно.** Если неясно, почему LoRA экономит, сравни число весов, которое ты посчитал в шаге 2, с числом весов адаптера в шаге 3. Если неясно умножение матриц, вернись к уроку «Векторы и матрицы». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Понять, почему готовую модель выгодно дообучать, а не учить заново. Обучить маленькую сеть, дообучить её на новом стиле четырьмя способами, сравнить с обучением с нуля и посчитать, что экономит LoRA. Нужно около 45 минут.

### Идея и механизм

**Шаг 1. Что такое дообучение.** Модель уже обучена на одних текстах. **Дообучение** значит продолжить обучение на других текстах, с меньшим шагом и намного меньшим объёмом данных. Первые слои уже умеют общие вещи, например слова, а новый стиль меняет немногое. Поэтому мы не начинаем с нуля.

Настоящую модель из урока «Собери свою языковую модель» чистый Python учит очень долго. Здесь её младшая сестра: на входе 3 символа, на выходе следующий символ, один скрытый слой на 24 нейрона. Механизм тот же.

**Шаг 2. Посчитай веса руками.** Символов 29, у каждого вектор из 6 чисел: `29 · 6 = 174`. Внутренний слой: `(3 · 6 + 1) · 24 = 456`. Выходной слой: `(24 + 1) · 29 = 725`. Всего `174 + 456 + 725 = 1355`.

Старый стиль: «кот ест рыбу.» Новый стиль: «ну кот ест рыбу, да!» Слова те же, обёртка новая. Создай файл `nano ~/ai-path/fine.py`, вставь программу и запусти. Нужно около 3 секунд.

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


ALPHABET = sorted(set(text_of("old", 400, 1) + text_of("new", 400, 1)))
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
        self.a, self.b = None, None

    def copy(self):
        twin = Net.__new__(Net)
        twin.embed = [row[:] for row in self.embed]
        twin.inner = [row[:] for row in self.inner]
        twin.inner_bias = self.inner_bias[:]
        twin.outer = [row[:] for row in self.outer]
        twin.outer_bias = self.outer_bias[:]
        twin.a, twin.b = None, None
        return twin

    def add_adapter(self, rank, seed):
        rand = Rand(seed)
        self.a = [[(rand.next() - 0.5) * 0.5 for _ in range(H)] for _ in range(rank)]
        self.b = [[0.0] * rank for _ in range(V)]

    def forward(self, context):
        x = [value for c in context for value in self.embed[c]]
        h = [math.tanh(sum(w * v for w, v in zip(row, x)) + bias) for row, bias in zip(self.inner, self.inner_bias)]
        out = [sum(w * v for w, v in zip(row, h)) + bias for row, bias in zip(self.outer, self.outer_bias)]
        low = None
        if self.a:
            low = [sum(w * v for w, v in zip(row, h)) for row in self.a]
            out = [o + sum(w * v for w, v in zip(row, low)) for o, row in zip(out, self.b)]
        top = max(out)
        weights = [math.exp(o - top) for o in out]
        total = sum(weights)
        return x, h, low, [w / total for w in weights]

    def step(self, context, target, rate, part):
        x, h, low, p = self.forward(context)
        error = p[:]
        error[target] -= 1.0
        if part == "adapter":
            back = [sum(e * row[k] for e, row in zip(error, self.b)) for k in range(len(self.a))]
            for row, e in zip(self.b, error):
                for k, value in enumerate(low):
                    row[k] -= rate * e * value
            for row, g in zip(self.a, back):
                for j, value in enumerate(h):
                    row[j] -= rate * g * value
            return
        back = [sum(e * row[j] for e, row in zip(error, self.outer)) for j in range(H)]
        for row, e in zip(self.outer, error):
            for j, value in enumerate(h):
                row[j] -= rate * e * value
        for v, e in enumerate(error):
            self.outer_bias[v] -= rate * e
        if part == "head":
            return
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

    def loss(self, numbers):
        total = 0.0
        for i in range(CONTEXT, len(numbers)):
            total -= math.log(self.forward(numbers[i - CONTEXT:i])[3][numbers[i]] + 1e-12)
        return total / (len(numbers) - CONTEXT)

    def sample(self, start, length, seed):
        rand = Rand(seed)
        numbers = [CODE[c] for c in start]
        for _ in range(length):
            p = [q ** 2 for q in self.forward(numbers[-CONTEXT:])[3]]
            pick, total = rand.next() * sum(p), 0.0
            for v, q in enumerate(p):
                total += q
                if pick <= total:
                    numbers.append(v)
                    break
        return "".join(ALPHABET[n] for n in numbers)


def train(net, numbers, steps, rate, part, seed):
    rand = Rand(seed)
    for _ in range(steps):
        i = CONTEXT + rand.below(len(numbers) - CONTEXT)
        net.step(numbers[i - CONTEXT:i], numbers[i], rate, part)


def encode(text):
    return [CODE[c] for c in text]


OLD, NEW_CHECK = encode(text_of("old", 600, 1)), encode(text_of("new", 30, 99))
base = Net(3)
train(base, OLD, 6000, 0.03, "all", 4)
print("alphabet", V, "weights", V * E + (CONTEXT * E + 1) * H + (H + 1) * V)
print("old style loss", round(base.loss(encode(text_of("old", 30, 99))), 3))
print("new style loss before fine-tuning", round(base.loss(NEW_CHECK), 3))
print(base.sample("кот", 40, 5))
```

```output
alphabet 29 weights 1355
old style loss 0.451
new style loss before fine-tuning 3.451
кот году. папа ест воду. гусь ищет траву. г
```

На старом стиле ошибка `0,451`. На новом `3,451`. Для сравнения, случайное угадывание даёт `ln 29 = 3,37`. Модель на новом стиле **хуже случайной**: она уверенно ждёт точку там, где теперь запятая.

**Шаг 3. Идея LoRA.** Сколько весов менять? Все 1355 дорого, если весов миллиарды. Заметим, что изменение часто устроено просто. Матрицу можно записать как произведение двух узких. Пример: столбец `(1; 2)` умножить на строку `(3; 4; 5)` даёт матрицу `2 × 3`:

`3 4 5`
`6 8 10`

Шесть чисел записаны пятью. Для нашего выхода `24 × 29` выходит `696` чисел в полной матрице против `24 + 29 = 53` при ранге 1. **LoRA** (low-rank adaptation) замораживает исходные веса и учит только добавку: `W + A · B`, где `A` и `B` узкие. `B` начинается с нулей, поэтому сначала модель в точности прежняя. **Ранг** `r` это ширина добавки: весов `r · (24 + 29)`.

**Шаг 4. Сравнение.** Допиши и запусти. Сравниваем обучение с нуля, дообучение всех весов, только последнего слоя и LoRA трёх рангов, на 5 и на 80 предложениях. В последних трёх колонках ошибка на новых предложениях, которых модель не видела.

```python
PARTS = {"from scratch": V * E + (CONTEXT * E + 1) * H + (H + 1) * V, "all weights": V * E + (CONTEXT * E + 1) * H + (H + 1) * V,
         "last layer": (H + 1) * V}
runs = {}


def run(name, sentences, rank=0):
    data = encode(text_of("new", sentences, 7))
    net = Net(3) if name == "from scratch" else base.copy()
    part = "all"
    if name == "last layer":
        part = "head"
    if rank:
        net.add_adapter(rank, 8)
        part = "adapter"
    curve = []
    for _ in range(3):
        train(net, data, 300, 0.02, part, 9 + len(curve))
        curve.append(round(net.loss(NEW_CHECK), 3))
    return net, curve


print("sentences method weights loss after 300, 600, 900 steps")
for sentences in (5, 80):
    for name in ("from scratch", "all weights", "last layer"):
        net, curve = run(name, sentences)
        runs[sentences, name] = (net, curve)
        print(sentences, name, PARTS[name], curve)
    for rank in (1, 2, 4):
        net, curve = run(f"LoRA {rank}", sentences, rank)
        runs[sentences, f"LoRA {rank}"] = (net, curve)
        print(sentences, f"LoRA {rank}", rank * (H + V), curve)
```

```output
sentences method weights loss after 300, 600, 900 steps
5 from scratch 1355 [2.936, 2.504, 2.189]
5 all weights 1355 [1.164, 0.795, 0.726]
5 last layer 725 [1.634, 1.145, 0.992]
5 LoRA 1 53 [3.29, 2.097, 1.988]
5 LoRA 2 106 [3.21, 1.931, 1.665]
5 LoRA 4 212 [2.535, 1.676, 1.322]
80 from scratch 1355 [2.899, 2.472, 2.134]
80 all weights 1355 [1.131, 0.676, 0.587]
80 last layer 725 [1.687, 1.06, 0.859]
80 LoRA 1 53 [3.187, 1.907, 1.837]
80 LoRA 2 106 [3.15, 1.659, 1.549]
80 LoRA 4 212 [2.292, 1.449, 1.314]
```

Читай по строкам для 80 предложений. С нуля за 900 шагов `2,134`: модель ещё только учит слова. Все веса `0,587`: почти как на старом стиле. Только последний слой, 725 весов, `0,859`. LoRA ранга 4, всего 212 весов, `1,314`, а ранга 1, 53 веса, `1,837`. **Даже 53 обучаемых веса обгоняют обучение с нуля по всем 1355.** Но бесплатного тут нет: меньше весов дают хуже качество, и на этой маленькой модели разрыв заметен.

И данных нужно мало: всего 5 предложений дают `0,726` при всех весах, а с нуля `2,189`. Правда, новый стиль здесь очень правильный, поэтому оценка щедрая.

**Шаг 5. Текст и выключатель.** Допиши и запусти.

```python
for name in ("from scratch", "all weights", "LoRA 2"):
    print(name, "|", runs[80, name][0].sample("ну ", 44, 5))
adapter = runs[80, "LoRA 2"][0]
plain = base.loss(NEW_CHECK)
keep = adapter.a
adapter.a = None
print("adapter off", round(adapter.loss(NEW_CHECK), 3), "same as base", round(plain, 3))
adapter.a = keep
print("adapter on", round(adapter.loss(NEW_CHECK), 3))
```

```output
from scratch | ну на да! ни ! на у т да! кё! ну дюн  да! !б в 
all weights | ну ну мама видит ры ну ну мама да! но! ну ду ищ
LoRA 2 | ну несёт до! ву, мюбм, мюбит до! дюбит до! на!д
adapter off 3.451 same as base 3.451
adapter on 1.549
```

С нуля выходит почти каша, при всех весах уже есть «мама видит», а LoRA ранга 2 узнаёт обёртку, но слова ломает. Последние строки показывают главное удобство: при выключенном адаптере ошибка снова ровно `3,451`. **Исходные веса не менялись.** Поэтому один большой файл модели и десяток маленьких адаптеров можно хранить рядом и переключать. Так работают и с большими моделями: адаптеры хранят отдельно и подключают, когда нужно. Но в Ollama на этом Mac так уже нельзя. Раньше она подключала адаптер строкой `ADAPTER` в файле `Modelfile`, а с версии 0.34.1 (сентябрь 2026) отвечает на неё ошибкой «LoRA adapters are no longer supported». Для Ollama адаптер пришлось бы заранее влить в веса: `W + A · B` это обычная матрица того же размера.

**Учись у тех, кто это создаёт.** Статья [LoRA](https://arxiv.org/abs/2106.09685) читается легко, начни с первых двух разделов. Лаборатория 3 курса [MIT 6.S191](http://introtodeeplearning.com/) дообучает настоящую модель. Курс [Stanford CS336](https://stanford-cs336.github.io/spring2025/) объясняет, чем дообучение отличается от предобучения.

### Исследуй и потренируйся

В тренажёре настоящие кривые этой программы. Двигай бюджет весов, включай способы и сравнивай, смотри на текст, а затем выключи адаптер.

В программе поставь адаптер ещё и на внутренний слой. Настоящая LoRA ставит добавки на много слоёв, а не на один.

### Вопрос

Почему адаптер LoRA можно выключить, и модель станет в точности прежней?

### Варианты

- Исходные веса заморожены, а адаптер это отдельная добавка, которую можно не прибавлять.
- Адаптер хранит копию всех исходных весов, и при выключении она записывается обратно.
- Обучение идёт на очень малом шаге, и поэтому отличие от исходной модели незаметно.

### Ответ

1

### Разбор

Обучается только добавка `A · B`, а веса `W` не меняются ни разу, поэтому копия не нужна. Шаг тут ни при чём: ошибка на новом стиле упала с `3,451` до `1,549`, это заметное отличие. При выключении просто не прибавляем добавку.

### Границы модели

Это игрушка на 1355 весов с искусственным стилем, и выводы о размерах нельзя переносить на большие модели. Адаптер здесь стоит только на последнем слое, поэтому ему трудно менять само чтение слов. Шаг обучения и число шагов я подобрал вручную. Обучение с нуля проигрывает ещё и потому, что я дал всем поровну 900 шагов, а с большим числом шагов оно бы догоняло.

## English

### In plain words

Training a large model from scratch is very expensive. It is cheaper to take a ready one and fine-tune it on your examples: the model already knows the language and only needs to learn a new style. LoRA goes further: the main weights stay untouched, and a small add-on is placed beside them and only it is trained. Like a detachable attachment on a tool: take it off and the tool is exactly as before. Far fewer numbers have to be trained, and for large models thousands of times fewer.

**What to know first.** «Your Own Language Model» (step 12). «Vectors and Matrices» (step 3): matrix size. «Mini-Batches and Overfitting» (step 9).

**If something is unclear.** If it is unclear why LoRA saves so much, compare the weight count you made in step 2 with the adapter's weight count in step 3. If matrix multiplication is unclear, go back to «Vectors and Matrices». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Understand why fine-tuning a ready model beats training anew. Train a small network, fine-tune it on a new style in four ways, compare with training from scratch, and compute what LoRA saves. It takes about 45 minutes.

### Idea and mechanism

**Step 1. What fine-tuning is.** A model is already trained on some texts. **Fine-tuning** means continuing to train on other texts, with a smaller step and far less data. The first layers already know general things, such as words, and a new style changes little. So we do not start from zero.

Plain Python takes very long to train the real model from the "Build your language model" lesson. Here is its younger sister: 3 characters in, the next character out, one hidden layer of 24 neurons. The mechanism is the same.

**Step 2. Count the weights by hand.** There are 29 characters, each with a vector of 6 numbers: `29 · 6 = 174`. The inner layer: `(3 · 6 + 1) · 24 = 456`. The output layer: `(24 + 1) · 29 = 725`. In total `174 + 456 + 725 = 1355`.

The old style is "кот ест рыбу." ("the cat eats fish."). The new style is "ну кот ест рыбу, да!" ("so the cat eats fish, yes!"). The same words in a new wrapping. Create the file `nano ~/ai-path/fine.py`, paste the program and run it. It takes about 3 seconds.

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


ALPHABET = sorted(set(text_of("old", 400, 1) + text_of("new", 400, 1)))
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
        self.a, self.b = None, None

    def copy(self):
        twin = Net.__new__(Net)
        twin.embed = [row[:] for row in self.embed]
        twin.inner = [row[:] for row in self.inner]
        twin.inner_bias = self.inner_bias[:]
        twin.outer = [row[:] for row in self.outer]
        twin.outer_bias = self.outer_bias[:]
        twin.a, twin.b = None, None
        return twin

    def add_adapter(self, rank, seed):
        rand = Rand(seed)
        self.a = [[(rand.next() - 0.5) * 0.5 for _ in range(H)] for _ in range(rank)]
        self.b = [[0.0] * rank for _ in range(V)]

    def forward(self, context):
        x = [value for c in context for value in self.embed[c]]
        h = [math.tanh(sum(w * v for w, v in zip(row, x)) + bias) for row, bias in zip(self.inner, self.inner_bias)]
        out = [sum(w * v for w, v in zip(row, h)) + bias for row, bias in zip(self.outer, self.outer_bias)]
        low = None
        if self.a:
            low = [sum(w * v for w, v in zip(row, h)) for row in self.a]
            out = [o + sum(w * v for w, v in zip(row, low)) for o, row in zip(out, self.b)]
        top = max(out)
        weights = [math.exp(o - top) for o in out]
        total = sum(weights)
        return x, h, low, [w / total for w in weights]

    def step(self, context, target, rate, part):
        x, h, low, p = self.forward(context)
        error = p[:]
        error[target] -= 1.0
        if part == "adapter":
            back = [sum(e * row[k] for e, row in zip(error, self.b)) for k in range(len(self.a))]
            for row, e in zip(self.b, error):
                for k, value in enumerate(low):
                    row[k] -= rate * e * value
            for row, g in zip(self.a, back):
                for j, value in enumerate(h):
                    row[j] -= rate * g * value
            return
        back = [sum(e * row[j] for e, row in zip(error, self.outer)) for j in range(H)]
        for row, e in zip(self.outer, error):
            for j, value in enumerate(h):
                row[j] -= rate * e * value
        for v, e in enumerate(error):
            self.outer_bias[v] -= rate * e
        if part == "head":
            return
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

    def loss(self, numbers):
        total = 0.0
        for i in range(CONTEXT, len(numbers)):
            total -= math.log(self.forward(numbers[i - CONTEXT:i])[3][numbers[i]] + 1e-12)
        return total / (len(numbers) - CONTEXT)

    def sample(self, start, length, seed):
        rand = Rand(seed)
        numbers = [CODE[c] for c in start]
        for _ in range(length):
            p = [q ** 2 for q in self.forward(numbers[-CONTEXT:])[3]]
            pick, total = rand.next() * sum(p), 0.0
            for v, q in enumerate(p):
                total += q
                if pick <= total:
                    numbers.append(v)
                    break
        return "".join(ALPHABET[n] for n in numbers)


def train(net, numbers, steps, rate, part, seed):
    rand = Rand(seed)
    for _ in range(steps):
        i = CONTEXT + rand.below(len(numbers) - CONTEXT)
        net.step(numbers[i - CONTEXT:i], numbers[i], rate, part)


def encode(text):
    return [CODE[c] for c in text]


OLD, NEW_CHECK = encode(text_of("old", 600, 1)), encode(text_of("new", 30, 99))
base = Net(3)
train(base, OLD, 6000, 0.03, "all", 4)
print("alphabet", V, "weights", V * E + (CONTEXT * E + 1) * H + (H + 1) * V)
print("old style loss", round(base.loss(encode(text_of("old", 30, 99))), 3))
print("new style loss before fine-tuning", round(base.loss(NEW_CHECK), 3))
print(base.sample("кот", 40, 5))
```

```output
alphabet 29 weights 1355
old style loss 0.451
new style loss before fine-tuning 3.451
кот году. папа ест воду. гусь ищет траву. г
```

On the old style the error is `0.451`. On the new one it is `3.451`. For comparison, random guessing gives `ln 29 = 3.37`. On the new style the model is **worse than random**: it confidently expects a full stop where a comma now stands.

**Step 3. The idea of LoRA.** How many weights should change? All 1355 is expensive when weights number in billions. Note that the change is often simple. A matrix can be written as a product of two narrow ones. For example, the column `(1; 2)` times the row `(3; 4; 5)` gives a `2 × 3` matrix:

`3 4 5`
`6 8 10`

Six numbers are written with five. For our `24 × 29` output that means `696` numbers in the full matrix against `24 + 29 = 53` at rank 1. **LoRA** (low-rank adaptation) freezes the original weights and trains only an addition: `W + A · B`, where `A` and `B` are narrow. `B` starts at zero, so at first the model is exactly as before. The **rank** `r` is the addition's width: `r · (24 + 29)` weights.

**Step 4. The comparison.** Add this and run it. We compare training from scratch, fine-tuning all weights, only the last layer, and LoRA at three ranks, on 5 and on 80 sentences. The last three columns are the error on new sentences the model has not seen.

```python
PARTS = {"from scratch": V * E + (CONTEXT * E + 1) * H + (H + 1) * V, "all weights": V * E + (CONTEXT * E + 1) * H + (H + 1) * V,
         "last layer": (H + 1) * V}
runs = {}


def run(name, sentences, rank=0):
    data = encode(text_of("new", sentences, 7))
    net = Net(3) if name == "from scratch" else base.copy()
    part = "all"
    if name == "last layer":
        part = "head"
    if rank:
        net.add_adapter(rank, 8)
        part = "adapter"
    curve = []
    for _ in range(3):
        train(net, data, 300, 0.02, part, 9 + len(curve))
        curve.append(round(net.loss(NEW_CHECK), 3))
    return net, curve


print("sentences method weights loss after 300, 600, 900 steps")
for sentences in (5, 80):
    for name in ("from scratch", "all weights", "last layer"):
        net, curve = run(name, sentences)
        runs[sentences, name] = (net, curve)
        print(sentences, name, PARTS[name], curve)
    for rank in (1, 2, 4):
        net, curve = run(f"LoRA {rank}", sentences, rank)
        runs[sentences, f"LoRA {rank}"] = (net, curve)
        print(sentences, f"LoRA {rank}", rank * (H + V), curve)
```

```output
sentences method weights loss after 300, 600, 900 steps
5 from scratch 1355 [2.936, 2.504, 2.189]
5 all weights 1355 [1.164, 0.795, 0.726]
5 last layer 725 [1.634, 1.145, 0.992]
5 LoRA 1 53 [3.29, 2.097, 1.988]
5 LoRA 2 106 [3.21, 1.931, 1.665]
5 LoRA 4 212 [2.535, 1.676, 1.322]
80 from scratch 1355 [2.899, 2.472, 2.134]
80 all weights 1355 [1.131, 0.676, 0.587]
80 last layer 725 [1.687, 1.06, 0.859]
80 LoRA 1 53 [3.187, 1.907, 1.837]
80 LoRA 2 106 [3.15, 1.659, 1.549]
80 LoRA 4 212 [2.292, 1.449, 1.314]
```

Read the rows for 80 sentences. From scratch, after 900 steps, `2.134`: the model is still learning words. All weights `0.587`: nearly as good as on the old style. Only the last layer, 725 weights, `0.859`. LoRA at rank 4, just 212 weights, `1.314`, and at rank 1, 53 weights, `1.837`. **Even 53 trainable weights beat training all 1355 from scratch.** But nothing is free here: fewer weights give worse quality, and on this small model the gap is visible.

Little data is needed too: just 5 sentences give `0.726` with all weights, and from scratch `2.189`. Admittedly the new style here is very regular, so this estimate is generous.

**Step 5. Text and the switch.** Add this and run it.

```python
for name in ("from scratch", "all weights", "LoRA 2"):
    print(name, "|", runs[80, name][0].sample("ну ", 44, 5))
adapter = runs[80, "LoRA 2"][0]
plain = base.loss(NEW_CHECK)
keep = adapter.a
adapter.a = None
print("adapter off", round(adapter.loss(NEW_CHECK), 3), "same as base", round(plain, 3))
adapter.a = keep
print("adapter on", round(adapter.loss(NEW_CHECK), 3))
```

```output
from scratch | ну на да! ни ! на у т да! кё! ну дюн  да! !б в 
all weights | ну ну мама видит ры ну ну мама да! но! ну ду ищ
LoRA 2 | ну несёт до! ву, мюбм, мюбит до! дюбит до! на!д
adapter off 3.451 same as base 3.451
adapter on 1.549
```

From scratch it is nearly mush, with all weights "мама видит" ("mum sees") already appears, and LoRA at rank 2 knows the wrapping but breaks the words. The last rows show the chief convenience: with the adapter off, the error is again exactly `3.451`. **The original weights never changed.** So one big model file and a dozen small adapters can sit side by side and be switched. Large models are handled the same way: adapters are stored separately and attached when needed. But Ollama on this Mac can no longer do it. It used to attach an adapter with the `ADAPTER` line in a `Modelfile`, and since version 0.34.1 (September 2026) it answers that line with the error "LoRA adapters are no longer supported". For Ollama the adapter would have to be merged into the weights first: `W + A · B` is an ordinary matrix of the same size.

**Learn from the people who build this.** The [LoRA paper](https://arxiv.org/abs/2106.09685) reads easily; start with the first two sections. Lab 3 of [MIT 6.S191](http://introtodeeplearning.com/) fine-tunes a real model. [Stanford CS336](https://stanford-cs336.github.io/spring2025/) explains how fine-tuning differs from pretraining.

### Explore and practise

The lab has the real curves of this program. Move the weight budget, switch methods on and compare, read the text, and then switch the adapter off.

In the program, put an adapter on the inner layer too. Real LoRA places additions on many layers, not one.

### Question

Why can a LoRA adapter be switched off, leaving the model exactly as before?

### Options

- The original weights are frozen, and the adapter is a separate addition you can leave out.
- The adapter keeps a copy of all original weights, and switching off writes them back.
- Training uses a very small step, so the difference from the original model is unnoticeable.

### Answer

1

### Explanation

Only the addition `A · B` is trained and the weights `W` never change, so no copy is needed. The step has nothing to do with it: the error on the new style fell from `3.451` to `1.549`, a visible difference. Switching off simply means not adding the addition.

### Limits

This is a toy with 1355 weights and an artificial style, and conclusions on sizes do not carry over to large models. The adapter here sits only on the last layer, so it struggles to change how words are read. I tuned the learning step and the number of steps by hand. Training from scratch also loses because I gave everyone the same 900 steps; with more steps it would catch up.

## Sources

- Edward J. Hu et al., "LoRA: Low-Rank Adaptation of Large Language Models", arXiv:2106.09685 (2021), abstract with frozen weights and the low-rank addition read 2026-11-03: [arXiv:2106.09685](https://arxiv.org/abs/2106.09685)
- MIT 6.S191, "Introduction to Deep Learning", title read 2026-11-03: [course](http://introtodeeplearning.com/)
- Stanford CS336, "Language Modeling from Scratch" (2025), title read 2026-11-03: [course](https://stanford-cs336.github.io/spring2025/)
- Ollama source code, `server/create.go`, read on GitHub on 2026-11-07: tag v0.34.0 has no adapter error, tags v0.34.1 and v0.40.13 (the version on this Mac) return "LoRA adapters are no longer supported" for a model with adapters; the Modelfile reference read the same day no longer lists `ADAPTER`: [create.go](https://github.com/ollama/ollama/blob/main/server/create.go), [Modelfile reference](https://docs.ollama.com/modelfile)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
