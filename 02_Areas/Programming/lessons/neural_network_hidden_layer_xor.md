---
subject: programming
lesson_id: programming.neural_network_hidden_layer_xor
level: advanced
languages: ru, en
source_checked: 2026-11-01
source_review_interval_days: 365
---

# Скрытый слой: нейросеть учит XOR / The Hidden Layer: A Network Learns XOR

## Русский

### Цель

Доказать, что один нейрон не может выучить XOR, построить сеть со скрытым слоем и провести обратное распространение через два слоя: от ошибки на выходе к весам скрытых нейронов.

### Идея и механизм

В уроке «Нейросеть учится сама» один нейрон подбирал веса по правилу цепочки. Теперь дадим ему простую с виду задачу — XOR, «исключающее или»: ответ 1, когда входы различаются, и 0, когда совпадают. Четыре примера: (0, 0) → 0, (0, 1) → 1, (1, 0) → 1, (1, 1) → 0.

Один нейрон с этим не справится, и это можно доказать. Нейрон с порогом отвечает 1, когда `w₁x₁ + w₂x₂ + b > 0`, то есть проводит на плоскости одну прямую. Для XOR нужны сразу четыре условия: `b < 0`, `w₂ + b > 0`, `w₁ + b > 0` и `w₁ + w₂ + b < 0`. Сложим второе и третье: `w₁ + w₂ + 2b > 0`. Сложим первое и четвёртое: `w₁ + w₂ + 2b < 0`. Одно и то же число не может быть и больше, и меньше нуля, значит, таких весов нет. Минский и Пейперт разбирали такие ограничения простых перцептронов ещё в 1969 году.

Решение — поставить между входами и выходом скрытый слой. Скрытый нейрон устроен так же, как обычный: взвешенная сумма входов, затем нелинейная функция. Возьмём два скрытых нейрона и один выходной:

`h₁ = σ(w₁₁x₁ + w₁₂x₂ + b₁)`

`h₂ = σ(w₂₁x₁ + w₂₂x₂ + b₂)`

`y = σ(v₁h₁ + v₂h₂ + c)`

Здесь `σ(z) = 1 / (1 + e⁻ᶻ)` — сигмоида: она сжимает любое число в промежуток от 0 до 1 и плавно заменяет порог. Нелинейность обязательна: линейная функция от линейной функции снова линейная, и без σ скрытый слой ничего бы не добавил.

Обучение идёт как раньше: прямой проход, ошибка `L = (y − t)²`, градиент, шаг против градиента. Новое только одно: ошибка должна дойти до весов скрытого слоя. Здесь снова работает правило цепочки, а производная сигмоиды равна `σ′ = σ(1 − σ)`. Сначала считаем общий множитель на выходе, а затем идём назад:

`out = 2(y − t) · y(1 − y)`

`∂L/∂v₁ = out · h₁`

`∂L/∂w₁₁ = out · v₁ · h₁(1 − h₁) · x₁`

**Разберём один пример.** Веса: `w₁₁ = 0,7`, `w₁₂ = 0,7`, `b₁ = 0,6`, `w₂₁ = 0,1`, `w₂₂ = −0,9`, `b₂ = 0,5`, `v₁ = 0,7`, `v₂ = 0,7`, `c = −0,9`. Вход (1, 0), цель `t = 1`.

Прямой проход: `h₁ = σ(0,7 · 1 + 0,7 · 0 + 0,6) = σ(1,3) ≈ 0,786`, `h₂ = σ(0,1 · 1 − 0,9 · 0 + 0,5) = σ(0,6) ≈ 0,646`, `y = σ(0,7 · 0,786 + 0,7 · 0,646 − 0,9) = σ(0,102) ≈ 0,525`. Ошибка на этом примере `(0,525 − 1)² ≈ 0,225`.

Обратный проход: `out = 2 · (0,525 − 1) · 0,525 · 0,475 ≈ −0,237`. Для веса на выходе `∂L/∂v₁ = −0,237 · 0,786 ≈ −0,186`. Для веса в скрытом слое сигнал идёт дальше: `∂L/∂w₁₁ = −0,237 · 0,7 · 0,786 · 0,214 · 1 ≈ −0,028`. Оба градиента отрицательные, поэтому шаг против градиента увеличит эти веса, и y приблизится к 1. Заметь: по дороге назад сигнал ослаб примерно в восемь раз.

Вся сеть на чистом Python, четыре примера и средний градиент:

```python
import math

data = [((0, 0), 0), ((0, 1), 1), ((1, 0), 1), ((1, 1), 0)]
rate = 1.0


def sigma(z):
    return 1 / (1 + math.exp(-z))


def forward(w, x):
    h1 = sigma(w[0] * x[0] + w[1] * x[1] + w[2])
    h2 = sigma(w[3] * x[0] + w[4] * x[1] + w[5])
    return h1, h2, sigma(w[6] * h1 + w[7] * h2 + w[8])


def loss(w):
    return sum((forward(w, x)[2] - t) ** 2 for x, t in data) / len(data)


def gradient(w):
    total = [0.0] * 9
    for x, t in data:
        h1, h2, y = forward(w, x)
        out = 2 * (y - t) * y * (1 - y)  # общий множитель на выходе
        back1 = out * w[6] * h1 * (1 - h1)  # сигнал для первого скрытого нейрона
        back2 = out * w[7] * h2 * (1 - h2)  # сигнал для второго скрытого нейрона
        parts = [back1 * x[0], back1 * x[1], back1,
                 back2 * x[0], back2 * x[1], back2,
                 out * h1, out * h2, out]
        total = [a + b / len(data) for a, b in zip(total, parts)]
    return total


w = [0.7, 0.7, 0.6, 0.1, -0.9, 0.5, 0.7, 0.7, -0.9]
for step in range(3000):
    if step in (0, 500, 1000):
        print(step, round(loss(w), 4))
    w = [a - rate * g for a, g in zip(w, gradient(w))]
print(3000, round(loss(w), 4))

for x, t in data:
    h1, h2, y = forward(w, x)
    print(x, t, round(h1, 2), round(h2, 2), round(y, 2))
```

Средняя ошибка падает так: 0,2483 в начале, 0,1734 через 500 итераций, 0,0272 через 1000 и 0,0026 через 3000. Затем программа печатает вход, цель, `h₁`, `h₂` и `y`:

```text
(0, 0) 0 0.05 1.0 0.05
(0, 1) 1 0.97 0.91 0.95
(1, 0) 1 0.97 0.91 0.95
(1, 1) 0 1.0 0.09 0.06
```

Посмотри на `h₁` и `h₂`. Первый скрытый нейрон стал похож на ИЛИ: он почти 0 только при (0, 0). Второй стал похож на И-НЕ: он почти 0 только при (1, 1). Выходной нейрон смотрит уже не на входы, а на `h₁` и `h₂`, и ему хватает одной прямой: ответ 1, когда включены оба. В этом главная мысль урока: скрытый слой сам строит новое представление данных, в котором трудная задача становится простой. Про ИЛИ и И-НЕ сети никто не говорил. Именно это показали Румельхарт, Хинтон и Уильямс в 1986 году: при обратном распространении скрытые нейроны начинают представлять важные признаки задачи.

**Начальные веса важны.** Если у двух скрытых нейронов одинаковые веса, то у них одинаковые градиенты, и они навсегда останутся копиями: сеть ведёт себя так, будто скрытый нейрон один. Поэтому веса сначала задают случайно и разными. Но и при разных весах обучение может застыть на плато: при старте `w = [0,2; −0,7; −0,5; 0,8; 0,9; −0,9; −0,6; −0,1; −0,5]` и той же скорости ошибка за 50 000 итераций остаётся около 0,167. В такой маленькой сети помогает запуск с других начальных весов.

**Зачем это дальше.** Большие сети учатся по той же схеме: прямой проход, обратный проход по правилу цепочки, шаг против градиента. Различаются число слоёв и весов, функция ошибки и данные.

### Исследуй и потренируйся

В тренажёре сначала выбери «Один нейрон», предскажи, до какой ошибки он дойдёт, и запусти обучение. Затем выбери скрытый слой и старт 1: посмотри на маленькие карты `h₁` и `h₂` и назови, на какие логические операции они стали похожи. Поставь старт 2 и объясни, чем его плато отличается от предела одного нейрона. Поставь «Одинаковые» и сравни карты `h₁` и `h₂`.

Затем проверь обратное распространение численно. Прибавь к `w[0]` число `0.000001`, посчитай `(loss(новые веса) − loss(w)) / 0.000001` и сравни с `gradient(w)[0]`. Числа должны почти совпасть: так ищут ошибки в вычислении градиента.

### Вопрос

Один нейрон на данных XOR застыл: на все четыре входа он отвечает 0,5. Что ему поможет?

### Варианты

- Больше итераций: ошибка рано или поздно дойдёт до нуля.
- Скрытый слой с нелинейностью: одной прямой XOR не разделить.
- Другая скорость обучения: при подходящей скорости веса найдутся.

### Ответ

2

### Разбор

Условия для XOR противоречат друг другу: сумма `w₁ + w₂ + 2b` должна быть сразу и больше, и меньше нуля. Таких весов нет, поэтому ни новые итерации, ни другая скорость не помогут: дело в устройстве модели, а не в обучении. Скрытый слой переводит входы в новое представление, например в ИЛИ и И-НЕ, и там одной прямой уже достаточно.

### Границы модели

Четыре примера без шума — учебная задача: она проверяет, может ли сеть их выучить, а работу на новых данных не измеряет. Сигмоида и квадратичная ошибка взяты ради простых формул; современные сети чаще используют ReLU и другие функции ошибки. При многих слоях сигнал ошибки по дороге назад может затухать, как в разобранном примере, или, наоборот, взрываться. Плато не значит, что лучших весов нет: они есть, но градиент там почти нулевой. Это модель машинного обучения, а не мозга: как меняются настоящие синапсы, показывает урок о пластичности.

## English

### Goal

Prove that one neuron cannot learn XOR, build a network with a hidden layer, and carry backpropagation through two layers: from the error at the output to the weights of the hidden neurons.

### Idea and mechanism

In the lesson "A Neural Network Learns", one neuron tuned its weights with the chain rule. Now give it a task that looks simple: XOR, "exclusive or". The answer is 1 when the inputs differ and 0 when they match. Four examples: (0, 0) → 0, (0, 1) → 1, (1, 0) → 1, (1, 1) → 0.

One neuron cannot do this, and we can prove it. A neuron with a threshold answers 1 when `w₁x₁ + w₂x₂ + b > 0`, which draws one straight line on the plane. XOR needs four conditions at once: `b < 0`, `w₂ + b > 0`, `w₁ + b > 0`, and `w₁ + w₂ + b < 0`. Add the second and third: `w₁ + w₂ + 2b > 0`. Add the first and fourth: `w₁ + w₂ + 2b < 0`. The same number cannot be both above and below zero, so no such weights exist. Minsky and Papert studied such limits of simple perceptrons back in 1969.

The solution is to put a hidden layer between the inputs and the output. A hidden neuron works like any other: a weighted sum of inputs, then a nonlinear function. Take two hidden neurons and one output neuron:

`h₁ = σ(w₁₁x₁ + w₁₂x₂ + b₁)`

`h₂ = σ(w₂₁x₁ + w₂₂x₂ + b₂)`

`y = σ(v₁h₁ + v₂h₂ + c)`

Here `σ(z) = 1 / (1 + e⁻ᶻ)` is the sigmoid: it squeezes any number into the range from 0 to 1 and is a smooth stand-in for the threshold. The nonlinearity is essential: a linear function of a linear function is again linear, so without σ the hidden layer would add nothing.

Training goes as before: forward pass, error `L = (y − t)²`, gradient, step against the gradient. Only one thing is new: the error has to reach the weights of the hidden layer. The chain rule does this again, and the sigmoid's derivative is `σ′ = σ(1 − σ)`. First compute a shared factor at the output, then go backward:

`out = 2(y − t) · y(1 − y)`

`∂L/∂v₁ = out · h₁`

`∂L/∂w₁₁ = out · v₁ · h₁(1 − h₁) · x₁`

**A worked example.** Weights: `w₁₁ = 0.7`, `w₁₂ = 0.7`, `b₁ = 0.6`, `w₂₁ = 0.1`, `w₂₂ = −0.9`, `b₂ = 0.5`, `v₁ = 0.7`, `v₂ = 0.7`, `c = −0.9`. Input (1, 0), target `t = 1`.

Forward pass: `h₁ = σ(0.7 · 1 + 0.7 · 0 + 0.6) = σ(1.3) ≈ 0.786`, `h₂ = σ(0.1 · 1 − 0.9 · 0 + 0.5) = σ(0.6) ≈ 0.646`, `y = σ(0.7 · 0.786 + 0.7 · 0.646 − 0.9) = σ(0.102) ≈ 0.525`. The error on this example is `(0.525 − 1)² ≈ 0.225`.

Backward pass: `out = 2 · (0.525 − 1) · 0.525 · 0.475 ≈ −0.237`. For the weight at the output, `∂L/∂v₁ = −0.237 · 0.786 ≈ −0.186`. For a weight in the hidden layer the signal travels further: `∂L/∂w₁₁ = −0.237 · 0.7 · 0.786 · 0.214 · 1 ≈ −0.028`. Both gradients are negative, so a step against the gradient raises these weights and brings y closer to 1. Notice that the signal weakened about eightfold on its way back.

The whole network in plain Python, with four examples and the mean gradient:

```python
import math

data = [((0, 0), 0), ((0, 1), 1), ((1, 0), 1), ((1, 1), 0)]
rate = 1.0


def sigma(z):
    return 1 / (1 + math.exp(-z))


def forward(w, x):
    h1 = sigma(w[0] * x[0] + w[1] * x[1] + w[2])
    h2 = sigma(w[3] * x[0] + w[4] * x[1] + w[5])
    return h1, h2, sigma(w[6] * h1 + w[7] * h2 + w[8])


def loss(w):
    return sum((forward(w, x)[2] - t) ** 2 for x, t in data) / len(data)


def gradient(w):
    total = [0.0] * 9
    for x, t in data:
        h1, h2, y = forward(w, x)
        out = 2 * (y - t) * y * (1 - y)  # shared factor at the output
        back1 = out * w[6] * h1 * (1 - h1)  # signal for the first hidden neuron
        back2 = out * w[7] * h2 * (1 - h2)  # signal for the second hidden neuron
        parts = [back1 * x[0], back1 * x[1], back1,
                 back2 * x[0], back2 * x[1], back2,
                 out * h1, out * h2, out]
        total = [a + b / len(data) for a, b in zip(total, parts)]
    return total


w = [0.7, 0.7, 0.6, 0.1, -0.9, 0.5, 0.7, 0.7, -0.9]
for step in range(3000):
    if step in (0, 500, 1000):
        print(step, round(loss(w), 4))
    w = [a - rate * g for a, g in zip(w, gradient(w))]
print(3000, round(loss(w), 4))

for x, t in data:
    h1, h2, y = forward(w, x)
    print(x, t, round(h1, 2), round(h2, 2), round(y, 2))
```

The mean error falls like this: 0.2483 at the start, 0.1734 after 500 iterations, 0.0272 after 1000, and 0.0026 after 3000. The program then prints the input, target, `h₁`, `h₂`, and `y`:

```text
(0, 0) 0 0.05 1.0 0.05
(0, 1) 1 0.97 0.91 0.95
(1, 0) 1 0.97 0.91 0.95
(1, 1) 0 1.0 0.09 0.06
```

Look at `h₁` and `h₂`. The first hidden neuron came to resemble OR: it is near 0 only at (0, 0). The second came to resemble NAND: it is near 0 only at (1, 1). The output neuron no longer looks at the inputs but at `h₁` and `h₂`, and one line is enough for it: the answer is 1 when both are on. This is the main idea of the lesson: the hidden layer builds a new representation of the data by itself, one in which a hard task becomes simple. Nobody told the network about OR and NAND. This is what Rumelhart, Hinton, and Williams showed in 1986: with backpropagation, hidden units come to represent important features of the task.

**Starting weights matter.** If two hidden neurons have identical weights, they have identical gradients and stay copies forever, so the network behaves as if it had one hidden neuron. That is why weights start out random and different. Even with different weights, training can stall on a plateau: starting from `w = [0.2, −0.7, −0.5, 0.8, 0.9, −0.9, −0.6, −0.1, −0.5]` at the same rate, the error stays near 0.167 for 50,000 iterations. In a network this small, starting again from other weights helps.

**Why this matters next.** Large networks learn by the same scheme: forward pass, backward pass by the chain rule, step against the gradient. What differs is the number of layers and weights, the error function, and the data.

### Explore and practise

In the lab, first choose "One neuron", predict what error it will reach, and start training. Then choose the hidden layer and start 1: look at the small maps of `h₁` and `h₂` and name the logic operations they came to resemble. Set start 2 and explain how its plateau differs from the limit of one neuron. Set "Identical" and compare the maps of `h₁` and `h₂`.

Then check backpropagation numerically. Add `0.000001` to `w[0]`, compute `(loss(new weights) − loss(w)) / 0.000001`, and compare it with `gradient(w)[0]`. The numbers should nearly match: this is how errors in gradient code are found.

### Question

One neuron on the XOR data has stalled: it answers 0.5 for all four inputs. What will help it?

### Options

- More iterations: sooner or later the error will reach zero.
- A hidden layer with a nonlinearity: one line cannot separate XOR.
- A different learning rate: at the right rate the weights will be found.

### Answer

2

### Explanation

The conditions for XOR contradict each other: the sum `w₁ + w₂ + 2b` would have to be both above and below zero. No such weights exist, so neither more iterations nor another rate will help: the problem is the structure of the model, not the training. A hidden layer maps the inputs into a new representation, such as OR and NAND, where one line is enough.

### Limits

Four examples without noise are a teaching task: it tests whether the network can learn them and does not measure how it works on new data. The sigmoid and squared error were chosen for their simple formulas; modern networks more often use ReLU and other error functions. With many layers the error signal can fade on its way back, as in the worked example, or instead explode. A plateau does not mean better weights are missing: they exist, but the gradient there is nearly zero. This is a machine learning model, not a model of the brain: the lesson on plasticity shows how real synapses change.

## Sources

- Aston Zhang, Zachary C. Lipton, Mu Li, Alexander J. Smola, *Dive into Deep Learning*, “Multilayer Perceptrons” (consulted 2026-11-01): hidden layers, and why stacked linear layers add nothing without a nonlinearity: [D2L, MLP](https://d2l.ai/chapter_multilayer-perceptrons/mlp.html)
- *Dive into Deep Learning*, “Numerical Stability and Initialization” (consulted 2026-11-01): identical hidden units stay identical under gradient updates, random initialization breaks the symmetry, and sigmoid gradients can vanish: [D2L, initialization](https://d2l.ai/chapter_multilayer-perceptrons/numerical-stability-and-init.html)
- Stanford CS231n notes, “Backpropagation, Intuitions” (consulted 2026-11-01): backpropagation as recursive application of the chain rule, the forward and backward pass, and the sigmoid derivative (1 − σ)σ: [CS231n](https://cs231n.github.io/optimization-2/)
- Google for Developers, *Machine Learning Crash Course*, “Neural networks: Training using backpropagation” (consulted 2026-11-01; page updated 2025-12-15): backpropagation makes gradient descent feasible for multi-layer networks; vanishing and exploding gradients. Text under CC BY 4.0: [MLCC, backpropagation](https://developers.google.com/machine-learning/crash-course/neural-networks/backpropagation)
- David E. Rumelhart, Geoffrey E. Hinton, Ronald J. Williams, “Learning representations by back-propagating errors”, *Nature* 323, 533–536 (1986), first page read 2026-11-01: the procedure repeatedly adjusts the weights to reduce the difference between the actual and desired output, and hidden units come to represent important features of the task: [doi:10.1038/323533a0](https://doi.org/10.1038/323533a0)
- Wikipedia, “Perceptrons (book)” (consulted 2026-11-01): Minsky and Papert's 1969 results on restricted perceptrons, and XOR as a hard predicate for a single neuron: [Perceptrons (book)](https://en.wikipedia.org/wiki/Perceptrons_(book))
- The XOR proof, the program, and all its numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
