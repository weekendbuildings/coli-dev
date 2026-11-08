---
subject: programming
lesson_id: programming.transformer_block
level: advanced
languages: ru, en
source_checked: 2026-11-01
source_review_interval_days: 365
---

# Блок трансформера / The Transformer Block

## Русский

### Простыми словами

Блок трансформера это повторяющаяся деталь, из которой собраны все большие языковые модели. В нём несколько голов внимания смотрят на текст по-разному, а маленькая сеть обрабатывает каждый токен отдельно. Обходной путь `x + F(x)` прибавляет новое к старому, а не заменяет его. Как правки в документе поверх исходного текста: исходник остаётся, и ошибка легко доходит до нижних слоёв. Нормализация держит числа в разумном масштабе.

**Что нужно знать до.** Уроки «Механизм внимания» (шаг 11), «Инициализация и нормализация» и «Оптимизаторы» (шаг 9).

**Если непонятно.** Если неясно, зачем обходной путь, вернись к уроку «Инициализация и нормализация»: там сигнал гаснет без него. Если неясно внимание, перечитай урок «Механизм внимания». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Собрать блок трансформера из многоголового внимания, сети прямого прохода, обходных путей и нормализации, проверить его программой и понять, почему без обходных путей глубокая сеть почти не учится.

### Идея и механизм

В прошлом уроке одна голова внимания находила, куда смотреть. Но взвешенное среднее линейно по значениям и умеет смотреть только одним способом. Блок трансформера добавляет к вниманию ещё три детали, и каждая решает свою задачу. Такие блоки ставят друг на друга, и этого хватает для большой языковой модели.

**Несколько голов.** Одна голова считает один набор весов. Несколько голов смотрят на текст по-разному: например, одна может искать близкие символы, а другая дальние. Обычно вектор длиной `d` делят между `h` головами: у каждой своя часть длиной `d/h`, поэтому объём вычислений почти не растёт. Каждая голова считает внимание отдельно, ответы склеивают и пропускают через ещё одну матрицу, чтобы головы могли обменяться найденным.

**Сеть прямого прохода.** Внимание только смешивает значения разных мест. Чтобы обдумать собранное, к каждому месту применяют маленькую сеть: `умножить на матрицу → ReLU → умножить на матрицу`. Сеть одна и та же для всех мест и не смешивает их между собой. Функция `ReLU(a) = max(0, a)` даёт нелинейность, без которой, как мы знаем из урока о скрытом слое, новые слои ничего бы не добавили.

**Обходные пути.** Вместо `x = F(x)` пишут `x = x + F(x)`. Слой учит не весь ответ, а поправку к входу. Посмотрим на производную по правилу цепочки. Для стопки `x → F₁(x) → F₂(F₁(x)) → …` производная по входу — это произведение производных всех слоёв. Если у каждого слоя она равна 0,5, то через 12 слоёв останется `0,5¹² ≈ 0,00024`. Ошибка почти не доходит до нижних слоёв, и они почти не учатся. А для `x + F(x)` производная равна `1 + F′(x)`: даже если `F′` близка к нулю, единица остаётся. Этот приём предложили Каймин Хэ с коллегами в 2015 году для сетей с сотней слоёв и больше.

**Нормализация слоя.** Во время обучения числа внутри сети могут уплывать, и слоям приходится постоянно к этому приспосабливаться. Поэтому после сложения каждый вектор приводят к среднему 0 и разбросу 1. Это делают отдельно для каждого места и по одному примеру, поэтому размер пакета не важен.

Собранный блок для языковой модели работает так:

`x ← norm(x + внимание(x))`

`x ← norm(x + сеть(x))`

Здесь внимание с маской, чтобы модель не видела будущего. В оригинальной статье 2017 года у трансформера есть ещё кодировщик и внимание к нему, потому что задача там перевод. Языковой модели, которая только продолжает текст, они не нужны, поэтому мы оставляем две эти строки. Сверху стопки блоков стоит знакомая матрица и softmax, которые выдают вероятности следующего символа.

Вот весь блок на чистом Python, со случайными весами. Его ещё не обучали: сейчас важно проверить, что он устроен правильно. Заодно измерим, сколько сигнала ошибки доходит до нижнего слоя в стопке:

```python
import math

size, heads, length = 8, 2, 6  # длина вектора, число голов, длина текста
part = size // heads  # у каждой головы своя часть вектора
state = 2024


def next_value():
    global state
    state = state * 16807 % 2147483647
    return state / 2147483647 - 0.5


def matrix(rows, cols):
    return [[next_value() for _ in range(cols)] for _ in range(rows)]


def apply(m, v):
    return [sum(a * b for a, b in zip(row, v)) for row in m]


def softmax(scores):
    top = max(scores)
    powers = [math.exp(s - top) for s in scores]
    total = sum(powers)
    return [p / total for p in powers]


def normalize(v):  # нормализация слоя: среднее 0, разброс 1
    mean = sum(v) / len(v)
    spread = math.sqrt(sum((a - mean) ** 2 for a in v) / len(v)) + 1e-5
    return [(a - mean) / spread for a in v]


query = [matrix(part, size) for _ in range(heads)]
key = [matrix(part, size) for _ in range(heads)]
value = [matrix(part, size) for _ in range(heads)]
mix = matrix(size, size)  # соединяет ответы голов
wide, narrow = matrix(16, size), matrix(size, 16)  # сеть прямого прохода


def head(x, h):
    q = [apply(query[h], row) for row in x]
    k = [apply(key[h], row) for row in x]
    v = [apply(value[h], row) for row in x]
    result = []
    for t in range(len(x)):
        scores = [sum(a * b for a, b in zip(q[t], k[j])) / math.sqrt(part) for j in range(t + 1)]  # маска
        weights = softmax(scores)
        result.append([sum(weights[j] * v[j][i] for j in range(t + 1)) for i in range(part)])
    return result


def block(x):
    joined = [sum((head(x, h)[t] for h in range(heads)), []) for t in range(len(x))]
    attended = [apply(mix, row) for row in joined]
    x = [normalize([a + b for a, b in zip(r, s)]) for r, s in zip(x, attended)]  # обход и нормализация
    fed = [apply(narrow, [max(0.0, a) for a in apply(wide, row)]) for row in x]  # ReLU в середине
    return [normalize([a + b for a, b in zip(r, s)]) for r, s in zip(x, fed)]


text = matrix(length, size)
output = block(text)
print("weights", heads * 3 * part * size + size * size + 16 * size + size * 16)
print("mean", round(sum(output[3]) / size, 6), "spread", round(math.sqrt(sum(a * a for a in output[3]) / size), 3))

changed = [row[:] for row in text]
changed[5] = [a + 1 for a in changed[5]]  # меняем только последнее место
after = block(changed)
print("last changed, earlier moved by", round(max(abs(a - b) for t in range(5) for a, b in zip(output[t], after[t])), 6))
print("last changed, last moved by", round(max(abs(a - b) for a, b in zip(output[5], after[5])), 3))
changed = [row[:] for row in text]
changed[0] = [a + 1 for a in changed[0]]  # меняем только первое место
after = block(changed)
print("first changed, last moved by", round(max(abs(a - b) for a, b in zip(output[5], after[5])), 3))


def make_stack(depth, gain=0.25):  # слои со случайными весами и вход
    global state
    state = 99
    layers = [[[gain * 2 * next_value() for _ in range(size)] for _ in range(size)] for _ in range(depth)]
    return layers, [next_value() for _ in range(size)]


def forward(layers, x, bypass):
    states = []
    for layer in layers:
        states.append(x)
        y = [math.tanh(a) for a in apply(layer, x)]
        x = [a + b for a, b in zip(x, y)] if bypass else y
    return x, states


def gradient(layers, x, bypass):  # обратный проход: начинаем от первого числа на верхнем слое
    states = forward(layers, x, bypass)[1]
    g = [1.0] + [0.0] * (size - 1)
    for layer, before in zip(reversed(layers), reversed(states)):
        slopes = [1 - math.tanh(a) ** 2 for a in apply(layer, before)]
        back = [sum(layer[r][c] * slopes[r] * g[r] for r in range(size)) for c in range(size)]
        g = [a + b for a, b in zip(g, back)] if bypass else back
    return g


layers, start = make_stack(12)
for bypass in (False, True):
    g = gradient(layers, start, bypass)
    print("bypass" if bypass else "no bypass", f"{math.sqrt(sum(a * a for a in g)):.2e}")
```

Программа печатает:

```text
weights 512
mean 0.0 spread 1.0
last changed, earlier moved by 0.0
last changed, last moved by 0.448
first changed, last moved by 0.458
no bypass 4.59e-06
bypass 1.28e+00
```

Проверим каждую строку. В блоке 512 весов: у двух голов по три матрицы `4 × 8`, это 192, ещё 64 в матрице соединения и 256 в сети прямого прохода. Нормализация работает: на любом месте среднее равно 0, а разброс 1. Маска работает: мы изменили только последнее место, и все более ранние места не сдвинулись совсем, ровно на 0. Само последнее место сдвинулось на 0,448. А если изменить первое место, то последнее тоже сдвинется, на 0,458: сигнал идёт только вперёд. Так программа доказывает, что блок не подглядывает в будущее.

Последние две строки — главный результат. В стопке из 12 слоёв без обходных путей от ошибки до нижнего слоя доходит около 4,6 миллионных. С обходными путями доходит примерно 1,28, то есть сигнал не теряется. В такой глубокой стопке без обходов нижние слои почти не учатся.

**Что дальше.** Чтобы обучить целый блок, нужен обратный проход через всё это. Писать его вручную для каждой детали, как в прошлом уроке, долго и легко ошибиться. В финальном проекте мы напишем общий механизм, который сам считает градиенты по правилу цепочки для любой собранной модели.

### Исследуй и потренируйся

В тренажёре стоит настоящая стопка слоёв, и сверху вниз идёт настоящий сигнал ошибки. Яркость и длина шкалы у каждого слоя показывают, сколько ошибки туда дошло. Покрути башню мышью и выбери глубину. Без обходных путей шарик ошибки тает, а нижние слои темнеют. Включи обходные пути и сравни. На какой глубине без них сигнал падает ниже одной тысячной?

Затем проверь программу сама собой: посчитай численно, как первое число на верхнем слое зависит от `start[0]`, и сравни со значением `gradient(layers, start, False)[0]`.

### Вопрос

Обучается глубокая сеть из многих слоёв, и нижние слои почти не меняются. Почему запись `x + F(x)` вместо `F(x)` помогает?

### Варианты

- Производная слоя становится `1 + F′`, и сигнал не гаснет на пути вниз.
- Весов становится меньше, и поэтому ошибка быстрее доходит до них.
- Сумма делает числа больше, и шаг обучения от этого становится длиннее.

### Ответ

1

### Разбор

Сигнал ошибки идёт вниз как произведение производных слоёв, и множители меньше единицы быстро его гасят. У `x + F(x)` производная `1 + F′(x)`, поэтому даже при маленькой `F′` множитель остаётся около единицы. Весов обход не убирает, а размер чисел здесь ни при чём: их как раз удерживает нормализация.

### Границы модели

Блок в программе не обучен, поэтому проверяет устройство, а не умение. Цифры про затухание относятся к этой стопке с `tanh`, этим размером весов и этим началом: при других весах сигнал может и взрываться, поэтому их начальный размер подбирают тщательно. Нормализацию в настоящих моделях часто ставят перед вниманием, а не после: это другой порядок той же идеи. Для простоты мы взяли ReLU, а большие модели часто используют похожие функции. Настоящие модели используют десятки блоков и тысячи чисел в векторах, и им нужна защита от переобучения, например отключение случайных связей.

## English

### In plain words

The transformer block is the repeating part from which all large language models are built. In it, several attention heads look at the text in different ways, and a small network processes each token separately. The shortcut `x + F(x)` adds the new to the old instead of replacing it. Like tracked changes over the original text: the original stays, and the error easily reaches the lower layers. Normalization keeps the numbers at a sensible scale.

**What to know first.** «The Attention Mechanism» (step 11), «Initialization and normalization» and «Optimizers» (step 9).

**If something is unclear.** If the shortcut is unclear, go back to «Initialization and normalization»: there the signal fades without it. If attention is unclear, reread «The Attention Mechanism». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Assemble a transformer block from multi-head attention, a feed-forward network, bypass paths, and normalization, check it with a program, and understand why a deep network hardly learns without bypass paths.

### Idea and mechanism

In the last lesson one attention head found where to look. But a weighted mean is linear in the values and can look in only one way. A transformer block adds three more parts to attention, each solving its own problem. Such blocks are stacked on each other, and this is enough for a large language model.

**Several heads.** One head computes one set of weights. Several heads look at the text in different ways: for example, one may seek nearby characters and another distant ones. Usually a vector of length `d` is divided among `h` heads: each gets its own part of length `d/h`, so the amount of computation barely grows. Each head computes attention separately, then the answers are joined and passed through one more matrix, so that the heads can exchange what they found.

**The feed-forward network.** Attention only mixes values from different places. To work over what was gathered, a small network is applied to each place: `multiply by a matrix → ReLU → multiply by a matrix`. The network is the same for all places and does not mix them with each other. The function `ReLU(a) = max(0, a)` gives the nonlinearity without which, as we know from the hidden layer lesson, new layers would add nothing.

**Bypass paths.** Instead of `x = F(x)` we write `x = x + F(x)`. A layer learns not the whole answer but a correction to its input. Look at the derivative by the chain rule. For a stack `x → F₁(x) → F₂(F₁(x)) → …`, the derivative over the input is the product of the derivatives of all layers. If each one is 0.5, then after 12 layers `0.5¹² ≈ 0.00024` remains. The error hardly reaches the lower layers, and they hardly learn. But for `x + F(x)` the derivative is `1 + F′(x)`: even if `F′` is close to zero, the one remains. Kaiming He and colleagues proposed this technique in 2015 for networks of a hundred layers and more.

**Layer normalization.** During training the numbers inside a network can drift, and layers must keep adapting to this. So after the addition each vector is brought to mean 0 and spread 1. This is done separately for each place and for one example at a time, so the batch size does not matter.

The assembled block for a language model works like this:

`x ← norm(x + attention(x))`

`x ← norm(x + network(x))`

Here attention has a mask, so the model cannot see the future. In the original 2017 paper the transformer also has an encoder and attention to it, because the task there is translation. A language model that only continues a text does not need them, so we keep these two lines. On top of the stack of blocks stands the familiar matrix and softmax, which give the probabilities of the next character.

Here is the whole block in plain Python, with random weights. It is not trained yet: right now what matters is to check that it is built correctly. Along the way we will measure how much of the error signal reaches the lowest layer of a stack:

```python
import math

size, heads, length = 8, 2, 6  # vector length, number of heads, text length
part = size // heads  # each head has its own part of the vector
state = 2024


def next_value():
    global state
    state = state * 16807 % 2147483647
    return state / 2147483647 - 0.5


def matrix(rows, cols):
    return [[next_value() for _ in range(cols)] for _ in range(rows)]


def apply(m, v):
    return [sum(a * b for a, b in zip(row, v)) for row in m]


def softmax(scores):
    top = max(scores)
    powers = [math.exp(s - top) for s in scores]
    total = sum(powers)
    return [p / total for p in powers]


def normalize(v):  # layer normalization: mean 0, spread 1
    mean = sum(v) / len(v)
    spread = math.sqrt(sum((a - mean) ** 2 for a in v) / len(v)) + 1e-5
    return [(a - mean) / spread for a in v]


query = [matrix(part, size) for _ in range(heads)]
key = [matrix(part, size) for _ in range(heads)]
value = [matrix(part, size) for _ in range(heads)]
mix = matrix(size, size)  # joins the answers of the heads
wide, narrow = matrix(16, size), matrix(size, 16)  # the feed-forward network


def head(x, h):
    q = [apply(query[h], row) for row in x]
    k = [apply(key[h], row) for row in x]
    v = [apply(value[h], row) for row in x]
    result = []
    for t in range(len(x)):
        scores = [sum(a * b for a, b in zip(q[t], k[j])) / math.sqrt(part) for j in range(t + 1)]  # the mask
        weights = softmax(scores)
        result.append([sum(weights[j] * v[j][i] for j in range(t + 1)) for i in range(part)])
    return result


def block(x):
    joined = [sum((head(x, h)[t] for h in range(heads)), []) for t in range(len(x))]
    attended = [apply(mix, row) for row in joined]
    x = [normalize([a + b for a, b in zip(r, s)]) for r, s in zip(x, attended)]  # bypass and normalization
    fed = [apply(narrow, [max(0.0, a) for a in apply(wide, row)]) for row in x]  # ReLU in the middle
    return [normalize([a + b for a, b in zip(r, s)]) for r, s in zip(x, fed)]


text = matrix(length, size)
output = block(text)
print("weights", heads * 3 * part * size + size * size + 16 * size + size * 16)
print("mean", round(sum(output[3]) / size, 6), "spread", round(math.sqrt(sum(a * a for a in output[3]) / size), 3))

changed = [row[:] for row in text]
changed[5] = [a + 1 for a in changed[5]]  # change only the last place
after = block(changed)
print("last changed, earlier moved by", round(max(abs(a - b) for t in range(5) for a, b in zip(output[t], after[t])), 6))
print("last changed, last moved by", round(max(abs(a - b) for a, b in zip(output[5], after[5])), 3))
changed = [row[:] for row in text]
changed[0] = [a + 1 for a in changed[0]]  # change only the first place
after = block(changed)
print("first changed, last moved by", round(max(abs(a - b) for a, b in zip(output[5], after[5])), 3))


def make_stack(depth, gain=0.25):  # layers with random weights, and an input
    global state
    state = 99
    layers = [[[gain * 2 * next_value() for _ in range(size)] for _ in range(size)] for _ in range(depth)]
    return layers, [next_value() for _ in range(size)]


def forward(layers, x, bypass):
    states = []
    for layer in layers:
        states.append(x)
        y = [math.tanh(a) for a in apply(layer, x)]
        x = [a + b for a, b in zip(x, y)] if bypass else y
    return x, states


def gradient(layers, x, bypass):  # the backward pass: start from the first number of the top layer
    states = forward(layers, x, bypass)[1]
    g = [1.0] + [0.0] * (size - 1)
    for layer, before in zip(reversed(layers), reversed(states)):
        slopes = [1 - math.tanh(a) ** 2 for a in apply(layer, before)]
        back = [sum(layer[r][c] * slopes[r] * g[r] for r in range(size)) for c in range(size)]
        g = [a + b for a, b in zip(g, back)] if bypass else back
    return g


layers, start = make_stack(12)
for bypass in (False, True):
    g = gradient(layers, start, bypass)
    print("bypass" if bypass else "no bypass", f"{math.sqrt(sum(a * a for a in g)):.2e}")
```

The program prints:

```text
weights 512
mean 0.0 spread 1.0
last changed, earlier moved by 0.0
last changed, last moved by 0.448
first changed, last moved by 0.458
no bypass 4.59e-06
bypass 1.28e+00
```

Check each line. The block has 512 weights: two heads with three `4 × 8` matrices each make 192, then 64 in the joining matrix and 256 in the feed-forward network. Normalization works: at any place the mean is 0 and the spread is 1. The mask works: we changed only the last place, and all earlier places did not move at all, exactly 0. The last place itself moved by 0.448. And if the first place changes, the last one moves too, by 0.458: the signal goes only forward. So the program proves that the block does not peek into the future.

The last two lines are the main result. In a stack of 12 layers without bypass paths, about 4.6 millionths of the error reaches the lowest layer. With bypass paths about 1.28 reaches it, so the signal is not lost. In such a deep stack without bypasses, the lower layers hardly learn.

**What comes next.** To train a whole block, we need a backward pass through all of this. Writing it by hand for each part, as in the last lesson, is slow and error-prone. In the final project we will write a general mechanism that computes gradients by the chain rule for any assembled model.

### Explore and practise

The lab holds a real stack of layers, with a real error signal going from top to bottom. The brightness and scale length of each layer show how much error reached it. Turn the tower with the mouse and choose a depth. Without bypass paths the error ball melts and the lower layers go dark. Switch on the bypass paths and compare. At what depth does the signal without them fall below one thousandth?

Then check the program against itself: compute numerically how the first number of the top layer depends on `start[0]`, and compare it with `gradient(layers, start, False)[0]`.

### Question

A deep network of many layers is training, and its lower layers barely change. Why does writing `x + F(x)` instead of `F(x)` help?

### Options

- A layer's derivative becomes `1 + F′`, so the signal does not fade going down.
- There are fewer weights, so the error reaches them more quickly.
- The sum makes numbers larger, and that makes the training step longer.

### Answer

1

### Explanation

The error signal goes down as a product of the layers' derivatives, and factors below one quickly fade it. For `x + F(x)` the derivative is `1 + F′(x)`, so even with a small `F′` the factor stays near one. A bypass removes no weights, and the size of the numbers has nothing to do with it: normalization is what holds them in check.

### Limits

The block in the program is not trained, so it tests the structure, not any skill. The figures on fading apply to this stack with `tanh`, this size of weights, and this start: at other weights the signal can also explode, so their initial size is chosen with care. Real models often place normalization before attention instead of after: another order of the same idea. We took ReLU for simplicity, and large models often use similar functions. Real models use dozens of blocks and thousands of numbers per vector, and they need protection from overfitting, such as randomly dropping connections.

## Sources

- Ashish Vaswani and colleagues, “Attention Is All You Need”, arXiv:1706.03762 (2017), abstract read 2026-11-01: the transformer, built from attention with no recurrent or convolutional layers: [arXiv:1706.03762](https://arxiv.org/abs/1706.03762)
- Aston Zhang, Zachary C. Lipton, Mu Li, Alexander J. Smola, *Dive into Deep Learning* (version 1.0.3), “The Transformer Architecture” (consulted 2026-11-01): position-wise networks, residual connections, layer normalization, masked self-attention, and stacks of identical layers: [D2L, transformer](https://d2l.ai/chapter_attention-mechanisms-and-transformers/transformer.html)
- *Dive into Deep Learning*, “Multi-Head Attention” (consulted 2026-11-01): several attention passes in parallel, joined and mixed, with each head sized as the total divided by the number of heads: [D2L, multi-head attention](https://d2l.ai/chapter_attention-mechanisms-and-transformers/multihead-attention.html)
- Kaiming He, Xiangyu Zhang, Shaoqing Ren, Jian Sun, “Deep Residual Learning for Image Recognition”, arXiv:1512.03385 (2015), abstract read 2026-11-01: layers learn a correction to their input, which makes networks up to 152 layers easier to optimize: [arXiv:1512.03385](https://arxiv.org/abs/1512.03385)
- Jimmy Lei Ba, Jamie Ryan Kiros, Geoffrey E. Hinton, “Layer Normalization”, arXiv:1607.06450 (2016), abstract read 2026-11-01: normalizing with statistics computed from one example within a layer: [arXiv:1607.06450](https://arxiv.org/abs/1607.06450)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
