---
subject: programming
lesson_id: programming.matrix_calculus_jacobians
level: advanced
languages: ru, en
source_checked: 2026-11-07
source_review_interval_days: 180
---

# Матричные производные и якобианы / Matrix derivatives and Jacobians

## Русский

### Простыми словами

Обычная производная говорит, как меняется одно число от другого. Когда на входе несколько чисел и на выходе несколько, нужна целая таблица таких производных: как каждый выход зависит от каждого входа. Эта таблица называется *якобианом*. Похоже на пульт с несколькими ручками и несколькими лампочками: якобиан записывает, насколько ярче станет каждая лампочка, если чуть повернуть каждую ручку. В статьях об ИИ почти все формулы обратного распространения записаны через якобианы, и после этого урока ты сможешь их читать.

**Что нужно знать до.** Урок «Частные производные и градиент» (шаг 4). Урок «Векторы и матрицы» (шаг 3). Урок «Нейросеть учится сама» (шаг 8): правило цепочки для одного числа.

**Если непонятно.** Если неясна частная производная, вернись к уроку «Частные производные и градиент». Если неясно умножение матриц, вернись к уроку «Векторы и матрицы». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Посчитать якобиан маленького слоя сети по формуле и проверить его малыми шагами, увидеть правило цепочки для векторов как произведение якобианов и понять, почему обратное распространение умножает ошибку на транспонированный якобиан. Нужно около 40 минут.

### Идея и механизм

**Шаг 1. Якобиан руками.** Пусть `f(x₁, x₂) = (x₁ · x₂; x₁ + 3x₂)`. Два входа, два выхода. Строка якобиана это производные одного выхода по всем входам. Первый выход `x₁ · x₂`: по `x₁` будет `x₂`, по `x₂` будет `x₁`. Второй выход: `1` и `3`. Значит, `J = [[x₂, x₁], [1, 3]]`, а в точке `(2; 5)` это `[[5, 2], [1, 3]]`. Смысл: если сдвинуть вход на маленький вектор `d`, выход сдвинется примерно на `J · d`.

Теперь настоящий слой сети: `y = tanh(W · x)`, где `W` это матрица `3 × 2`. Производная `tanh(z)` равна `1 − tanh(z)²`, поэтому `J = diag(1 − y²) · W`: каждую строку `W` умножаем на свою производную. Создай файл `nano ~/ai-path/jacobian.py`, вставь и запусти.

```python
import math


def f(x):
    # a small layer: y = tanh(W x)
    W = [[0.5, -1.0], [2.0, 0.3], [-0.7, 0.8]]
    return [math.tanh(sum(w * v for w, v in zip(row, x))) for row in W], W


x = [0.4, -0.2]
y, W = f(x)
z = [sum(w * v for w, v in zip(row, x)) for row in W]
J = [[(1 - math.tanh(z[i]) ** 2) * W[i][j] for j in range(2)] for i in range(3)]
print("input 2 numbers, output 3 numbers, so the Jacobian is 3 x 2")
for row in J:
    print("  ", [round(v, 4) for v in row])
```

```output
input 2 numbers, output 3 numbers, so the Jacobian is 3 x 2
   [0.4278, -0.8556]
   [1.2084, 0.1813]
   [-0.5802, 0.6631]
```

**Шаг 2. Проверка малыми шагами.** Сдвинем каждый вход на `h = 0,000001` и посмотрим, как изменились выходы. Это та же проверка, что в уроке «Свой механизм градиентов» (шаг 8). Допиши и запусти.

```python
h = 1e-6
numeric = [[0.0, 0.0] for _ in range(3)]
for j in range(2):
    xp = x[:]
    xp[j] += h
    yp, _ = f(xp)
    for i in range(3):
        numeric[i][j] = (yp[i] - y[i]) / h
print("largest gap to the numerical derivative:", f"{max(abs(J[i][j] - numeric[i][j]) for i in range(3) for j in range(2)):.1e}")
```

```output
largest gap to the numerical derivative: 1.5e-06
```

Разница порядка `10⁻⁶`: это погрешность самого шага, формула верна.

**Шаг 3. Цепочка и обратный ход.** Если `y = f(x)`, а потом `z = g(y)`, то якобиан всей цепочки это произведение `J_g · J_f`. Это правило цепочки, только для таблиц вместо чисел. При обучении нам нужен *градиент* ошибки `L` по входу, а ошибка это одно число. Тогда цепочка начинается с вектора `∂L / ∂y`, и градиент по `x` равен `Jᵀ · ∂L / ∂y`, где `Jᵀ` это якобиан, повёрнутый на бок. Обратное распространение именно это и делает слой за слоем, не собирая большие якобианы целиком. Допиши и запусти.

```python
target = [0.0, 1.0, 0.0]
error = [y[i] - target[i] for i in range(3)]  # gradient of L = 1/2 |y - t|^2 with respect to y
grad = [sum(error[i] * J[i][j] for i in range(3)) for j in range(2)]  # J transposed times the error
loss = lambda x_: 0.5 * sum((a - b) ** 2 for a, b in zip(f(x_)[0], target))
check = [(loss([x[0] + h, x[1]]) - loss(x)) / h, (loss([x[0], x[1] + h]) - loss(x)) / h]
print("gradient by J^T times the error:", [round(g, 4) for g in grad])
print("gradient by small steps:        ", [round(g, 4) for g in check])
```

```output
gradient by J^T times the error: [-0.0456, -0.6666]
gradient by small steps:         [-0.0456, -0.6666]
```

Два способа дали одно и то же. Заметь размеры: ошибка из 3 чисел, якобиан `3 × 2`, а градиент из 2 чисел, по одному на вход. В статьях эту операцию называют *произведением вектора на якобиан*, VJP.

**Как это читать в статьях.** Запись `∂y / ∂x` с векторами обычно и есть якобиан. Есть два соглашения о том, что считать строкой, а что столбцом, и разные авторы выбирают разное; поэтому всегда проверяй размеры. Parr и Howard в 2018 году написали понятное введение именно для глубокого обучения.

**Учись у тех, кто это создаёт.** Статья [The Matrix Calculus You Need For Deep Learning](https://arxiv.org/abs/1802.01528). Карпатый строит обратный ход по слоям в [Zero to Hero](https://karpathy.ai/zero-to-hero.html).

### Исследуй и потренируйся

В тренажёре ниже отображение `f(x₁, x₂) = (x₁² − x₂; x₁ · x₂)` переводит маленький квадрат вокруг точки в искривлённую фигуру. Синий параллелограмм это то, что предсказывает якобиан. Перетаскивай точку. *Определитель* якобиана показывает, во сколько раз меняется площадь. В начале точка в `(1; 1)`, и площадь растёт втрое. Найди точку, где определитель почти ноль: там отображение сплющивает квадрат в линию.

### Вопрос

У слоя 2 входа и 3 выхода, а ошибка это одно число. Какой размер у градиента ошибки по входу?

### Варианты

- Два числа: по одному на каждый вход, это Jᵀ, умноженный на вектор из трёх чисел ошибки
- Три числа: по одному на каждый выход, потому что ошибку считают по выходам сети
- Таблица 3 × 2: градиент по входу всегда совпадает с самим якобианом этого слоя

### Ответ

1

### Разбор

Градиент по входу говорит, как ошибка меняется от каждого входа, поэтому в нём столько чисел, сколько входов. Вектор из трёх чисел это `∂L / ∂y`, градиент по выходам. Якобиан это таблица всех производных выходов по входам; градиент получается, когда его умножают на вектор ошибки.

### Границы модели

Слой здесь крошечный, и якобиан можно выписать целиком. В настоящих сетях он огромен, и его никогда не строят полностью: считают только произведения с векторами. Проверка малыми шагами точна лишь примерно и зависит от `h`.

## English

### In plain words

An ordinary derivative says how one number changes with another. When there are several numbers at the input and several at the output, you need a whole table of such derivatives: how each output depends on each input. This table is called the *Jacobian*. It is like a panel with several knobs and several lamps: the Jacobian records how much brighter each lamp gets if you turn each knob slightly. In AI papers almost all backpropagation formulas are written with Jacobians, and after this lesson you will be able to read them.

**What to know first.** «Partial Derivatives and the Gradient» (step 4). «Vectors and Matrices» (step 3). «A Neural Network Learns» (step 8): the chain rule for one number.

**If something is unclear.** If a partial derivative is unclear, go back to «Partial Derivatives and the Gradient». If matrix multiplication is unclear, go back to «Vectors and Matrices». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Compute the Jacobian of a small network layer by formula and check it with small steps, see the chain rule for vectors as a product of Jacobians, and understand why backpropagation multiplies the error by the transposed Jacobian. It takes about 40 minutes.

### Idea and mechanism

**Step 1. A Jacobian by hand.** Let `f(x₁, x₂) = (x₁ · x₂; x₁ + 3x₂)`. Two inputs, two outputs. A row of the Jacobian holds the derivatives of one output with respect to all inputs. The first output `x₁ · x₂`: with respect to `x₁` it is `x₂`, with respect to `x₂` it is `x₁`. The second output: `1` and `3`. So `J = [[x₂, x₁], [1, 3]]`, and at the point `(2; 5)` it is `[[5, 2], [1, 3]]`. Meaning: if the input moves by a small vector `d`, the output moves by about `J · d`.

Now a real network layer: `y = tanh(W · x)`, where `W` is a `3 × 2` matrix. The derivative of `tanh(z)` is `1 − tanh(z)²`, so `J = diag(1 − y²) · W`: each row of `W` is multiplied by its own derivative. Create the file `nano ~/ai-path/jacobian.py`, paste and run it.

```python
import math


def f(x):
    # a small layer: y = tanh(W x)
    W = [[0.5, -1.0], [2.0, 0.3], [-0.7, 0.8]]
    return [math.tanh(sum(w * v for w, v in zip(row, x))) for row in W], W


x = [0.4, -0.2]
y, W = f(x)
z = [sum(w * v for w, v in zip(row, x)) for row in W]
J = [[(1 - math.tanh(z[i]) ** 2) * W[i][j] for j in range(2)] for i in range(3)]
print("input 2 numbers, output 3 numbers, so the Jacobian is 3 x 2")
for row in J:
    print("  ", [round(v, 4) for v in row])
```

```output
input 2 numbers, output 3 numbers, so the Jacobian is 3 x 2
   [0.4278, -0.8556]
   [1.2084, 0.1813]
   [-0.5802, 0.6631]
```

**Step 2. Checking with small steps.** Move each input by `h = 0.000001` and see how the outputs changed. This is the same check as in «Your own gradient engine» (step 8). Add this and run it.

```python
h = 1e-6
numeric = [[0.0, 0.0] for _ in range(3)]
for j in range(2):
    xp = x[:]
    xp[j] += h
    yp, _ = f(xp)
    for i in range(3):
        numeric[i][j] = (yp[i] - y[i]) / h
print("largest gap to the numerical derivative:", f"{max(abs(J[i][j] - numeric[i][j]) for i in range(3) for j in range(2)):.1e}")
```

```output
largest gap to the numerical derivative: 1.5e-06
```

A difference of about `10⁻⁶`: that is the error of the step itself, and the formula is right.

**Step 3. The chain and the backward pass.** If `y = f(x)` and then `z = g(y)`, the Jacobian of the whole chain is the product `J_g · J_f`. This is the chain rule, only for tables instead of numbers. In training we need the *gradient* of the error `L` with respect to the input, and the error is one number. Then the chain starts with the vector `∂L / ∂y`, and the gradient with respect to `x` equals `Jᵀ · ∂L / ∂y`, where `Jᵀ` is the Jacobian turned on its side. Backpropagation does exactly this, layer by layer, without ever assembling large Jacobians. Add this and run it.

```python
target = [0.0, 1.0, 0.0]
error = [y[i] - target[i] for i in range(3)]  # gradient of L = 1/2 |y - t|^2 with respect to y
grad = [sum(error[i] * J[i][j] for i in range(3)) for j in range(2)]  # J transposed times the error
loss = lambda x_: 0.5 * sum((a - b) ** 2 for a, b in zip(f(x_)[0], target))
check = [(loss([x[0] + h, x[1]]) - loss(x)) / h, (loss([x[0], x[1] + h]) - loss(x)) / h]
print("gradient by J^T times the error:", [round(g, 4) for g in grad])
print("gradient by small steps:        ", [round(g, 4) for g in check])
```

```output
gradient by J^T times the error: [-0.0456, -0.6666]
gradient by small steps:         [-0.0456, -0.6666]
```

The two ways gave the same. Note the sizes: the error is 3 numbers, the Jacobian `3 × 2`, and the gradient 2 numbers, one per input. In papers this operation is called a *vector-Jacobian product*, VJP.

**How to read this in papers.** The notation `∂y / ∂x` with vectors is usually the Jacobian. There are two conventions for what counts as a row and what as a column, and different authors choose differently; so always check the sizes. Parr and Howard wrote a clear introduction for deep learning in 2018.

**Learn from the people who build this.** The paper [The Matrix Calculus You Need For Deep Learning](https://arxiv.org/abs/1802.01528). Karpathy builds the backward pass layer by layer in [Zero to Hero](https://karpathy.ai/zero-to-hero.html).

### Explore and practise

In the lab below the map `f(x₁, x₂) = (x₁² − x₂; x₁ · x₂)` turns a small square around a point into a curved shape. The blue parallelogram is what the Jacobian predicts. Drag the point. The *determinant* of the Jacobian shows how many times the area changes. At the start the point is at `(1; 1)`, and the area triples. Find a point where the determinant is almost zero: there the map flattens the square into a line.

### Question

A layer has 2 inputs and 3 outputs, and the error is one number. What size is the gradient of the error with respect to the input?

### Options

- Two numbers: one for each input, it is Jᵀ multiplied by the three-number error vector
- Three numbers: one for each output, because the error is computed at the network's outputs
- A 3 × 2 table: the gradient by the input always equals the Jacobian of this layer itself

### Answer

1

### Explanation

The gradient with respect to the input says how the error changes with each input, so it has as many numbers as there are inputs. The three-number vector is `∂L / ∂y`, the gradient with respect to the outputs. The Jacobian is the table of all derivatives of outputs by inputs; the gradient appears when it is multiplied by the error vector.

### Limits

The layer here is tiny, so its Jacobian can be written out in full. In real networks it is enormous and is never built completely: only products with vectors are computed. The small-step check is only approximate and depends on `h`.

## Sources

- Terence Parr, Jeremy Howard, "The Matrix Calculus You Need For Deep Learning", arXiv:1802.01528 (2018), title read 2026-11-07: [arXiv:1802.01528](https://arxiv.org/abs/1802.01528)
- Andrej Karpathy, "Neural Networks: Zero to Hero", course page opened 2026-11-02: [karpathy.ai](https://karpathy.ai/zero-to-hero.html)
- The layer, the program and all numbers were written for this lesson on 2026-11-07.
