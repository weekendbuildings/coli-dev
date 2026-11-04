---
subject: programming
lesson_id: programming.initialization_and_normalization
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Инициализация и нормализация / Initialization and normalization

## Русский

### Цель

Увидеть, почему глубокая сеть может сломаться ещё до первого шага обучения: сигнал гаснет или застревает, а градиент исчезает или раздувается. Подобрать начальный масштаб весов и проверить, что меняет нормализация. Нужно около 40 минут.

### Идея и механизм

**Шаг 1. Пример с умножением.** Слой умножает числа на веса. Упростим: пусть каждый слой уменьшает разброс сигнала ровно в 4 раза, то есть умножает его на 0,25. После 8 слоёв останется `0,25⁸ ≈ 0,000015`. Сигнал почти исчез, и последний слой получает почти одинаковые числа на любой вход. *Разброс* здесь это стандартное отклонение: насколько числа отличаются от своего среднего.

Если же каждый слой увеличивает сигнал, он быстро упирается в край функции `tanh`: её значения лежат между −1 и 1. Вдали от нуля `tanh` почти плоская, поэтому её производная близка к нулю. Это называют *насыщением*. Нейрон выдаёт ±1 и почти перестаёт учиться.

**Почему вес делят на корень из ширины.** В нейроне складываются 32 произведения «вес на вход». Дисперсии независимых слагаемых складываются. Если у входов дисперсия 1, а у весов `масштаб² / 32`, то у суммы дисперсия `32 · масштаб² / 32 = масштаб²`. Поэтому вес берут с разбросом `масштаб / √ширина`: так сигнал не зависит от ширины слоя, а зависит только от масштаба. Значит, идея в том, чтобы держать масштаб около 1. Для `tanh` это близко к правилу Глоро и Бенджио 2010 года.

**Шаг 2. Настоящая сеть.** Это 8 слоёв по 32 нейрона до всякого обучения. Строка `act` показывает разброс выхода в каждом слое, от первого к последнему. Строка `grad` показывает размер градиента по весам каждого слоя. Создай файл `nano ~/ai-path/layers.py`, вставь программу и запусти. Считается несколько секунд:

```python
import math

LAYERS, WIDTH, BATCH = 8, 32, 16
state = 4242


def uniform():
    global state
    state = state * 16807 % 2147483647
    return state / 2147483647


def gauss():
    return math.sqrt(-2 * math.log(uniform())) * math.cos(2 * math.pi * uniform())


def spread(rows):
    values = [v for row in rows for v in row]
    mean = sum(values) / len(values)
    return math.sqrt(sum((v - mean) ** 2 for v in values) / len(values))


def normalize(z):
    mean = sum(z) / len(z)
    s = math.sqrt(sum((v - mean) ** 2 for v in z) / len(z)) + 1e-9
    return [(v - mean) / s for v in z], s


def run(scale, norm=False):
    global state
    state = 4242
    deviation = scale / math.sqrt(WIDTH)
    weights = [[[gauss() * deviation for _ in range(WIDTH)] for _ in range(WIDTH)] for _ in range(LAYERS)]
    inputs = [[gauss() for _ in range(WIDTH)] for _ in range(BATCH)]
    outs, tapes, current = [], [], inputs
    for layer in weights:
        rows, tape = [], []
        for x in current:
            z = [sum(w * v for w, v in zip(row, x)) for row in layer]
            s = 1.0
            if norm:
                z, s = normalize(z)
            rows.append([math.tanh(v) for v in z])
            tape.append((z, s))
        outs.append(rows)
        tapes.append(tape)
        current = rows
    # back: the error is the sum of the last layer, so its gradient is 1
    grads = []
    back = [[1.0] * WIDTH for _ in range(BATCH)]
    for depth in range(LAYERS - 1, -1, -1):
        size = 0.0
        new = []
        for k in range(BATCH):
            z, s = tapes[depth][k]
            g = [b * (1 - math.tanh(v) ** 2) for b, v in zip(back[k], z)]
            if norm:
                mg = sum(g) / WIDTH
                mz = sum(a * b for a, b in zip(g, z)) / WIDTH
                g = [(a - mg - mz * b) / s for a, b in zip(g, z)]
            row = [sum(weights[depth][i][j] * g[i] for i in range(WIDTH)) for j in range(WIDTH)]
            for i in range(WIDTH):
                size += sum((g[i] * v) ** 2 for v in (outs[depth - 1][k] if depth else inputs[k]))
            new.append(row)
        grads.append(math.sqrt(size / (BATCH * WIDTH * WIDTH)))
        back = new
    grads.reverse()
    return [spread(rows) for rows in outs], grads


def show(label, values):
    print(label, " ".join(f"{v:.3g}" for v in values))


for scale in (0.25, 1.0, 4.0):
    activations, gradients = run(scale)
    print("scale", scale)
    show("  act ", activations)
    show("  grad", gradients)
```

```output
scale 0.25
  act  0.232 0.0563 0.0159 0.00404 0.00097 0.000237 6.35e-05 1.65e-05
  grad 7.27e-05 5.88e-05 7.04e-05 6.48e-05 5.76e-05 6.8e-05 6.84e-05 6.35e-05
scale 1.0
  act  0.618 0.472 0.429 0.363 0.325 0.291 0.287 0.259
  grad 0.384 0.277 0.313 0.276 0.226 0.276 0.278 0.265
scale 4.0
  act  0.89 0.872 0.888 0.882 0.899 0.888 0.897 0.881
  grad 7.06 4.49 3.05 2.17 1.38 0.831 0.583 0.35
```

Читаем три случая.

- **Масштаб 0,25.** Разброс падает с 0,232 до 0,0000165, как в примере с умножением. Градиенты около 0,00007: при таком наклоне обучение почти не двигается.
- **Масштаб 1.** Сигнал живёт во всех слоях, от 0,618 до 0,259, а градиенты близки между собой. Такая сеть готова учиться.
- **Масштаб 4.** Разброс около 0,88: нейроны в насыщении. Градиент у первого слоя 7,06, а у последнего 0,35, то есть раздувается в 20 раз к началу сети. Шаг, подходящий для одного слоя, будет плох для другого.

**Шаг 3. Нормализация.** Подбирать масштаб трудно, поэтому придумали приём: перед функцией `tanh` в каждом слое вычитать среднее и делить на разброс. Сигнал получает одинаковую величину в любом слое. Это *нормализация слоя*. Допиши:

```python
for scale in (0.25, 1.0, 4.0):
    activations, gradients = run(scale, norm=True)
    print("norm, scale", scale)
    show("  act ", activations)
    show("  grad", gradients)
```

```output
norm, scale 0.25
  act  0.629 0.635 0.628 0.625 0.633 0.641 0.64 0.632
  grad 2.86 2.28 1.97 1.85 1.56 1.54 1.38 1.36
norm, scale 1.0
  act  0.629 0.635 0.628 0.625 0.633 0.641 0.64 0.632
  grad 0.714 0.569 0.492 0.462 0.389 0.385 0.345 0.339
norm, scale 4.0
  act  0.629 0.635 0.628 0.625 0.633 0.641 0.64 0.632
  grad 0.179 0.142 0.123 0.115 0.0974 0.0964 0.0862 0.0849
```

Строки `act` одинаковы при любом масштабе, потому что нормализация убирает масштаб совсем. Разброс везде около 0,63. Заметь, что градиенты всё же разные: при большем масштабе они меньше, так что начальный масштаб всё ещё влияет на скорость обучения, хотя сеть уже не ломает.

Есть две главные версии. *Нормализация пакета* (batch norm) считает среднее по примерам в пакете, и её часто берут для картинок. *Нормализация слоя* (layer norm) считает по нейронам одного примера, как у нас, и именно она стоит в блоке трансформера, который ты разбирал.

**Учись у тех, кто это создаёт.** Андрей Карпатый смотрит на такие графики активаций и градиентов в лекции makemore 3 курса Zero to Hero, и это лучший следующий шаг. Первоисточники: Глоро и Бенджио 2010, Иоффе и Сегеди 2015, Ба и соавторы 2016. Ссылки в разделе источников.

### Исследуй и потренируйся

В тренажёре каждый столбец это слой, а цвет показывает, сколько нейронов дали такое значение от −1 до 1. Сверху подписан разброс. Здоровый слой это широкое пятно в середине. При малом масштабе столбцы сжимаются в тонкую полоску у нуля, а при большом всё уходит к краям +1 и −1. Ниже показан размер градиента по слоям.

Подвигай масштаб, затем включи нормализацию и снова подвигай. В программе поменяй `tanh` на `max(v, 0)`, функцию ReLU, с её производной. Какой масштаб теперь лучше?

### Вопрос

При масштабе 0,25 разброс в последнем слое почти нулевой. Почему?

### Варианты

- Каждый слой умножает разброс примерно на 0,25, и за 8 слоёв он почти исчезает.
- Функция `tanh` при малых числах обрезает сигнал до нуля и убирает его совсем.
- Случайные веса при малом масштабе стали равны и полностью гасят друг друга.

### Ответ

1

### Разбор

При малых числах `tanh` почти не меняет число: `tanh(0,01) ≈ 0,01`. Обрезает она большие числа, а не малые. И веса остаются разными, просто все маленькие. Сигнал гаснет из-за умножения в каждом слое.

### Границы модели

Мы смотрели только на начальное состояние, до обучения. Хорошая картина здесь не гарантирует успеха, она лишь убирает одну причину провала. У функции ReLU другая поправка, правило Хе и соавторов. Сеть у нас маленькая и прямая; обходные пути, о которых шла речь в уроке о блоке трансформера, тоже спасают сигнал ошибки. Причину, почему нормализация помогает, исследователи до конца не объяснили, и первоначальное объяснение из работы 2015 года оспаривается.

## English

### Goal

See why a deep network can break before its first training step: the signal fades or sticks, and the gradient vanishes or swells. Choose a starting weight scale and test what normalization changes. It takes about 40 minutes.

### Idea and mechanism

**Step 1. An example with multiplication.** A layer multiplies numbers by weights. Let us simplify: say each layer cuts the signal's spread by exactly 4 times, that is, multiplies it by 0.25. After 8 layers there remains `0.25⁸ ≈ 0.000015`. The signal has nearly vanished, and the last layer gets almost the same numbers for any input. *Spread* here is the standard deviation: how far numbers lie from their mean.

If instead each layer enlarges the signal, it soon hits the edge of the `tanh` function: its values lie between −1 and 1. Far from zero `tanh` is nearly flat, so its derivative is close to zero. This is called *saturation*. A neuron gives ±1 and almost stops learning.

**Why a weight is divided by the root of the width.** A neuron adds 32 products of a weight and an input. The variances of independent terms add up. If the inputs have variance 1 and the weights `scale² / 32`, the sum has variance `32 · scale² / 32 = scale²`. So a weight gets the spread `scale / √width`: the signal then depends not on the width of the layer but only on the scale. So the idea is to keep the scale near 1. For `tanh` this is close to the rule of Glorot and Bengio from 2010.

**Step 2. A real network.** Here are 8 layers of 32 neurons before any training. The line `act` shows the spread of the output in each layer, from first to last. The line `grad` shows the size of the gradient by the weights of each layer. Create a file with `nano ~/ai-path/layers.py`, paste the program, and run it. It computes for a few seconds:

```python
import math

LAYERS, WIDTH, BATCH = 8, 32, 16
state = 4242


def uniform():
    global state
    state = state * 16807 % 2147483647
    return state / 2147483647


def gauss():
    return math.sqrt(-2 * math.log(uniform())) * math.cos(2 * math.pi * uniform())


def spread(rows):
    values = [v for row in rows for v in row]
    mean = sum(values) / len(values)
    return math.sqrt(sum((v - mean) ** 2 for v in values) / len(values))


def normalize(z):
    mean = sum(z) / len(z)
    s = math.sqrt(sum((v - mean) ** 2 for v in z) / len(z)) + 1e-9
    return [(v - mean) / s for v in z], s


def run(scale, norm=False):
    global state
    state = 4242
    deviation = scale / math.sqrt(WIDTH)
    weights = [[[gauss() * deviation for _ in range(WIDTH)] for _ in range(WIDTH)] for _ in range(LAYERS)]
    inputs = [[gauss() for _ in range(WIDTH)] for _ in range(BATCH)]
    outs, tapes, current = [], [], inputs
    for layer in weights:
        rows, tape = [], []
        for x in current:
            z = [sum(w * v for w, v in zip(row, x)) for row in layer]
            s = 1.0
            if norm:
                z, s = normalize(z)
            rows.append([math.tanh(v) for v in z])
            tape.append((z, s))
        outs.append(rows)
        tapes.append(tape)
        current = rows
    # back: the error is the sum of the last layer, so its gradient is 1
    grads = []
    back = [[1.0] * WIDTH for _ in range(BATCH)]
    for depth in range(LAYERS - 1, -1, -1):
        size = 0.0
        new = []
        for k in range(BATCH):
            z, s = tapes[depth][k]
            g = [b * (1 - math.tanh(v) ** 2) for b, v in zip(back[k], z)]
            if norm:
                mg = sum(g) / WIDTH
                mz = sum(a * b for a, b in zip(g, z)) / WIDTH
                g = [(a - mg - mz * b) / s for a, b in zip(g, z)]
            row = [sum(weights[depth][i][j] * g[i] for i in range(WIDTH)) for j in range(WIDTH)]
            for i in range(WIDTH):
                size += sum((g[i] * v) ** 2 for v in (outs[depth - 1][k] if depth else inputs[k]))
            new.append(row)
        grads.append(math.sqrt(size / (BATCH * WIDTH * WIDTH)))
        back = new
    grads.reverse()
    return [spread(rows) for rows in outs], grads


def show(label, values):
    print(label, " ".join(f"{v:.3g}" for v in values))


for scale in (0.25, 1.0, 4.0):
    activations, gradients = run(scale)
    print("scale", scale)
    show("  act ", activations)
    show("  grad", gradients)
```

```output
scale 0.25
  act  0.232 0.0563 0.0159 0.00404 0.00097 0.000237 6.35e-05 1.65e-05
  grad 7.27e-05 5.88e-05 7.04e-05 6.48e-05 5.76e-05 6.8e-05 6.84e-05 6.35e-05
scale 1.0
  act  0.618 0.472 0.429 0.363 0.325 0.291 0.287 0.259
  grad 0.384 0.277 0.313 0.276 0.226 0.276 0.278 0.265
scale 4.0
  act  0.89 0.872 0.888 0.882 0.899 0.888 0.897 0.881
  grad 7.06 4.49 3.05 2.17 1.38 0.831 0.583 0.35
```

Let us read the three cases.

- **Scale 0.25.** The spread falls from 0.232 to 0.0000165, as in the multiplication example. The gradients are around 0.00007: at such a slope training hardly moves.
- **Scale 1.** The signal lives in all layers, from 0.618 to 0.259, and the gradients are close to each other. Such a network is ready to learn.
- **Scale 4.** The spread is around 0.88: the neurons are saturated. The gradient is 7.06 at the first layer and 0.35 at the last, swelling 20 times toward the start of the network. A step good for one layer will be bad for another.

**Step 3. Normalization.** Choosing a scale is hard, so a trick was invented: before the `tanh` function in each layer, subtract the mean and divide by the spread. The signal gets the same size in any layer. This is *layer normalization*. Add this:

```python
for scale in (0.25, 1.0, 4.0):
    activations, gradients = run(scale, norm=True)
    print("norm, scale", scale)
    show("  act ", activations)
    show("  grad", gradients)
```

```output
norm, scale 0.25
  act  0.629 0.635 0.628 0.625 0.633 0.641 0.64 0.632
  grad 2.86 2.28 1.97 1.85 1.56 1.54 1.38 1.36
norm, scale 1.0
  act  0.629 0.635 0.628 0.625 0.633 0.641 0.64 0.632
  grad 0.714 0.569 0.492 0.462 0.389 0.385 0.345 0.339
norm, scale 4.0
  act  0.629 0.635 0.628 0.625 0.633 0.641 0.64 0.632
  grad 0.179 0.142 0.123 0.115 0.0974 0.0964 0.0862 0.0849
```

The `act` lines are the same at any scale, because normalization removes the scale entirely. The spread is about 0.63 everywhere. Notice that the gradients still differ: at a larger scale they are smaller, so the starting scale still affects the speed of training, though it no longer breaks the network.

There are two main versions. *Batch normalization* computes the mean over the examples in a batch, and it is often used for images. *Layer normalization* computes over the neurons of one example, as we do, and it stands in the transformer block you studied.

**Learn from those who build this.** Andrej Karpathy looks at such plots of activations and gradients in the makemore 3 lecture of Zero to Hero, and it is the best next step. The primary sources are Glorot and Bengio 2010, Ioffe and Szegedy 2015, and Ba and colleagues 2016. The links are in the sources.

### Explore and practise

In the lab each column is a layer, and colour shows how many neurons gave a value from −1 to 1. The spread is written on top. A healthy layer is a wide patch in the middle. At a small scale the columns shrink to a thin strip near zero, and at a large one everything goes to the edges +1 and −1. Below is the size of the gradient by layer.

Move the scale, then switch normalization on and move it again. In the program, replace `tanh` with `max(v, 0)`, the ReLU function, together with its derivative. Which scale is better now?

### Question

At scale 0.25 the spread in the last layer is almost zero. Why?

### Options

- Each layer multiplies the spread by about 0.25, and over 8 layers it nearly vanishes.
- The `tanh` function cuts the signal to zero at small numbers and removes it entirely.
- Random weights at a small scale became equal and fully cancel out one another.

### Answer

1

### Explanation

At small numbers `tanh` hardly changes a number: `tanh(0.01) ≈ 0.01`. It cuts large numbers, not small ones. And the weights stay different, only all small. The signal fades because of the multiplication in each layer.

### Limits

We looked only at the starting state, before training. A good picture here does not promise success; it only removes one cause of failure. The ReLU function has another correction, the rule of He and colleagues. Our network is small and straight; the bypass paths from the transformer block lesson also rescue the error signal. Researchers have not fully explained why normalization helps, and the original explanation from the 2015 work is disputed.

## Sources

- Andrej Karpathy, "Building makemore Part 3: Activations & Gradients, BatchNorm", in Neural Networks: Zero to Hero (consulted 2026-11-02): [Zero to Hero](https://karpathy.ai/zero-to-hero.html)
- Xavier Glorot, Yoshua Bengio, "Understanding the difficulty of training deep feedforward neural networks", AISTATS 2010 (page opened 2026-11-02): [PMLR](https://proceedings.mlr.press/v9/glorot10a.html)
- Sergey Ioffe, Christian Szegedy, "Batch Normalization", arXiv:1502.03167 (2015), title read 2026-11-02: [arXiv:1502.03167](https://arxiv.org/abs/1502.03167)
- Jimmy Lei Ba, Jamie Ryan Kiros, Geoffrey Hinton, "Layer Normalization", arXiv:1607.06450 (2016), title read 2026-11-02: [arXiv:1607.06450](https://arxiv.org/abs/1607.06450)
- Kaiming He and colleagues, "Delving Deep into Rectifiers", arXiv:1502.01852 (2015), title read 2026-11-02: [arXiv:1502.01852](https://arxiv.org/abs/1502.01852)
- Shibani Santurkar and colleagues, "How Does Batch Normalization Help Optimization?", arXiv:1805.11604 (2018), abstract read 2026-11-03: it disputes the original explanation: [arXiv:1805.11604](https://arxiv.org/abs/1805.11604)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
