---
subject: programming
lesson_id: programming.neural_network_backpropagation
level: advanced
languages: ru, en
source_checked: 2026-10-31
source_review_interval_days: 365
---

# Нейросеть учится сама: обратное распространение ошибки / A Neural Network Learns: Backpropagation

## Русский

### Цель

Написать на Python искусственный нейрон, который учится сам: посчитать ошибку, найти по правилу цепочки, как она зависит от каждого веса, и сдвинуть веса против градиента.

### Идея и механизм

Нейрон из урока о матрицах считает y = w · x + b. Чтобы он научился, нужна мера ошибки. Для желаемого ответа t возьмём квадрат отклонения: L = (y − t)². Обучение — сделать L как можно меньше, меняя w и b.

Для этого нужно знать, как L меняется при изменении каждого веса, — частные производные. Ошибка зависит от w не напрямую, а через y, поэтому работает правило цепочки: ∂L/∂w = ∂L/∂y · ∂y/∂w = 2(y − t) · x, а ∂L/∂b = 2(y − t) · 1. Обратное распространение ошибки (backpropagation) — способ применять правило цепочки слой за слоем от выхода к входу, чтобы получить градиент по всем весам большой сети. Дальше — шаг градиентного спуска: w ← w − η · ∂L/∂w, где η — скорость обучения.

```python
w, b = 0.5, 0.0
x, target = 2.0, 2.0
rate = 0.05

for step in range(3):
    y = w * x + b
    loss = (y - target) ** 2
    grad_w = 2 * (y - target) * x
    grad_b = 2 * (y - target)
    w -= rate * grad_w
    b -= rate * grad_b
    print(step, round(loss, 4), round(w, 3), round(b, 3))
```

Программа печатает ошибку 1, затем 0,25, затем 0,0625: с каждым шагом нейрон отвечает всё ближе к цели 2. Большая нейросеть делает то же самое для миллионов весов сразу — в этом и состоит её обучение.

### Исследуй и потренируйся

Запусти программу и проверь числа. Затем поставь rate = 0,3 и посмотри, что происходит с ошибкой — почему слишком большая скорость обучения мешает? Добавь второй пример (x = 1, target = 1) и считай градиент как сумму по двум примерам. Проверь то же в тренажёре «Нейрон учится»: найди скорость, при которой обучение перестаёт сходиться.

### Вопрос

В программе w = 0,5, b = 0, x = 2, target = 2, rate = 0,05. Чему станет равен w после первого шага?

### Варианты

- 0,7: y = 1, grad_w = 2 · (1 − 2) · 2 = −4, и w = 0,5 − 0,05 · (−4) = 0,7.
- 0,3: шаг делают в сторону градиента, 0,5 + 0,05 · (−4).
- 0,55: к весу просто прибавляют скорость обучения.

### Ответ

1

### Разбор

Сначала прямой проход: y = 0,5 · 2 + 0 = 1, ошибка (1 − 2)² = 1. По правилу цепочки grad_w = 2 · (y − t) · x = 2 · (−1) · 2 = −4. Шаг против градиента: w = 0,5 − 0,05 · (−4) = 0,7. Градиент отрицательный, значит, увеличение w уменьшает ошибку — так и выходит: на следующем шаге y = 1,5 и ошибка 0,25.

### Границы модели

Один нейрон без нелинейности умеет только прямые зависимости; настоящие сети добавляют нелинейную функцию после каждого слоя, а градиент через все слои считает автоматическое дифференцирование. Обратное распространение через настоящий скрытый слой разобрано в следующем уроке — «Скрытый слой: нейросеть учит XOR». Обучение на одном примере — учебный случай: настоящие сети учатся на больших наборах данных и проверяются на отложенной выборке, как в уроке о базовой модели.

## English

### Goal

Write an artificial neuron in Python that learns by itself: compute the error, use the chain rule to find how it depends on each weight, and move the weights against the gradient.

### Idea and mechanism

The neuron from the matrices lesson computes y = w · x + b. To make it learn, we need a measure of error. For a desired answer t, take the squared deviation: L = (y − t)². Learning means making L as small as possible by changing w and b.

For that we need to know how L changes as each weight changes: the partial derivatives. The error depends on w not directly but through y, so the chain rule applies: ∂L/∂w = ∂L/∂y · ∂y/∂w = 2(y − t) · x, and ∂L/∂b = 2(y − t) · 1. Backpropagation is a way of applying the chain rule layer by layer from the output back to the input, to obtain the gradient for all the weights of a large network. Then comes a gradient descent step: w ← w − η · ∂L/∂w, where η is the learning rate.

```python
w, b = 0.5, 0.0
x, target = 2.0, 2.0
rate = 0.05

for step in range(3):
    y = w * x + b
    loss = (y - target) ** 2
    grad_w = 2 * (y - target) * x
    grad_b = 2 * (y - target)
    w -= rate * grad_w
    b -= rate * grad_b
    print(step, round(loss, 4), round(w, 3), round(b, 3))
```

The program prints an error of 1, then 0.25, then 0.0625: with each step the neuron answers closer to the target 2. A large network does the same for millions of weights at once, and that is what its training is.

### Explore and practise

Run the program and check the numbers. Then set rate = 0.3 and see what happens to the error: why does too high a learning rate get in the way? Add a second example (x = 1, target = 1) and compute the gradient as a sum over both examples. Check the same thing in the “A neuron learns” lab: find the rate at which training stops converging.

### Question

In the program w = 0.5, b = 0, x = 2, target = 2, rate = 0.05. What does w become after the first step?

### Options

- 0.7: y = 1, grad_w = 2 · (1 − 2) · 2 = −4, and w = 0.5 − 0.05 · (−4) = 0.7.
- 0.3: the step goes along the gradient, 0.5 + 0.05 · (−4).
- 0.55: the learning rate is simply added to the weight.

### Answer

1

### Explanation

First the forward pass: y = 0.5 · 2 + 0 = 1, error (1 − 2)² = 1. By the chain rule grad_w = 2 · (y − t) · x = 2 · (−1) · 2 = −4. The step goes against the gradient: w = 0.5 − 0.05 · (−4) = 0.7. The gradient is negative, so increasing w reduces the error, and it does: on the next step y = 1.5 and the error is 0.25.

### Limits

One neuron without a nonlinearity can capture only straight-line relationships; real networks add a nonlinear function after each layer, and automatic differentiation computes the gradient through all the layers. Backpropagation through a real hidden layer is worked out in the next lesson, "The Hidden Layer: A Network Learns XOR". Training on one example is a teaching case: real networks learn from large datasets and are checked on a held-out set, as in the baseline model lesson.

## Sources

- Ian Goodfellow, Yoshua Bengio, Aaron Courville, *Deep Learning*, MIT Press, 2016, chapter 6 “Deep Feedforward Networks”, section 6.5 “Back-Propagation and Other Differentiation Algorithms” (consulted 2026-10-31): gradient-based learning with a cost function, the chain rule of calculus, and the back-propagation algorithm for computing gradients efficiently: [Deep Learning, chapter 6](https://www.deeplearningbook.org/contents/mlp.html)
- Ian Goodfellow, Yoshua Bengio, Aaron Courville, *Deep Learning*, MIT Press, 2016, chapter 4 “Numerical Computation” (consulted 2026-10-27): gradient descent x′ = x − ε∇f(x) with learning rate ε: [Deep Learning, chapter 4](https://www.deeplearningbook.org/contents/numerical.html)
- The lesson paraphrases the book and does not copy its text.
