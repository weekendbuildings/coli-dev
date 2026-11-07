---
subject: programming
lesson_id: programming.autograd_engine
level: advanced
languages: ru, en
source_checked: 2026-11-02
source_review_interval_days: 365
---

# Свой механизм градиентов / Your own gradient engine

## Русский

### Простыми словами

Считать производные руками для каждой новой сети долго и легко ошибиться. Механизм градиентов делает это сам. Каждое число запоминает, из каких чисел и какой операцией оно получено. Потом от ответа назад каждая операция применяет своё маленькое правило, и все производные складываются. Похоже на чек, где у каждой строки написано, из чего она сложилась: пройдя чек снизу вверх, видишь вклад каждой покупки. Так же работает PyTorch, только на больших массивах.

**Что нужно знать до.** Урок «Нейросеть учится сама» (шаг 8): правило цепочки. Урок «Классы в Python» (шаг 2): объекты и методы.

**Если непонятно.** Если неясно, зачем `+=`, найди в уроке шаг 4: там число используется дважды, и его вклады складываются. Если неясны классы, вернись к уроку «Классы в Python». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Написать примерно за 70 строк на чистом Python механизм, который сам считает градиенты для любой формулы, проверить его численно и обучить им настоящую маленькую сеть. Внутри PyTorch работает та же идея, только на больших массивах чисел. Нужно около часа.

### Идея и механизм

В уроке об обратном распространении ты выводил производные руками для маленькой сети. Для большой модели это невозможно: там миллионы весов. Нужна программа, которая сама запоминает, как считалась формула, и сама идёт обратно. Такой механизм называют *автоматическим дифференцированием*.

**Шаг 1. Пример руками.** Пусть `a = 2`, `b = −3`, `c = 10`, а формула такая: `d = a · b`, потом `L = d + c`. Получаем `d = −6` и `L = 4`. Вопрос: если чуть увеличить `a`, как изменится `L`? Идём с конца.

- `L = d + c`. Если `d` вырастет на 1, то и `L` вырастет на 1. Значит, градиент `L` по `d` равен 1. По `c` тоже 1.
- `d = a · b`. Если `a` вырастет на 1, то `d` изменится на `b`, то есть на −3. Если вырастет `b`, то `d` изменится на `a`, то есть на 2.
- По правилу цепочки перемножаем: градиент `L` по `a` равен `1 · (−3) = −3`, а по `b` равен `1 · 2 = 2`.

Весь алгоритм здесь. Идём от конца к началу, и в каждом узле работает маленькое правило: **сложение передаёт градиент как есть, а умножение передаёт его, умножив на другой множитель.** Проверь на числах: увеличим `a` на 0,1, тогда `L = 2,1 · (−3) + 10 = 3,7`. Значение упало на 0,3, а градиент −3 предсказывал как раз `−3 · 0,1 = −0,3`.

**Шаг 2. Программа.** Создай файл:

```bash
cd ~/ai-path && nano value.py
```

Класс `Value` хранит число, его градиент `grad`, родителей, то есть значения, из которых оно получено, и функцию `push`, которая передаёт градиент родителям. Специальные имена `__add__` и `__mul__` позволяют писать для наших объектов обычные `a + b` и `a * b`. Функция `backward` выстраивает узлы так, чтобы каждый обрабатывался после всех, кто от него зависит, и идёт с конца. Вставь программу, сохрани и запусти командой `python3 value.py`:

```python
import math


class Value:
    def __init__(self, data, parents=()):
        self.data = data
        self.grad = 0.0
        self.parents = parents
        self.push = lambda: None  # как передать градиент родителям

    def __add__(self, other):
        other = other if isinstance(other, Value) else Value(other)
        result = Value(self.data + other.data, (self, other))

        def push():
            self.grad += result.grad
            other.grad += result.grad

        result.push = push
        return result

    def __mul__(self, other):
        other = other if isinstance(other, Value) else Value(other)
        result = Value(self.data * other.data, (self, other))

        def push():
            self.grad += other.data * result.grad
            other.grad += self.data * result.grad

        result.push = push
        return result

    def tanh(self):
        result = Value(math.tanh(self.data), (self,))

        def push():
            self.grad += (1 - result.data ** 2) * result.grad

        result.push = push
        return result

    def backward(self):
        order, seen = [], set()

        def visit(node):
            if node not in seen:
                seen.add(node)
                for parent in node.parents:
                    visit(parent)
                order.append(node)

        visit(self)
        self.grad = 1.0
        for node in reversed(order):
            node.push()


a, b, c = Value(2.0), Value(-3.0), Value(10.0)
d = a * b
L = d + c
L.backward()
print("L =", L.data)
print("a, b, c, d:", a.grad, b.grad, c.grad, d.grad)
```

```output
L = 4.0
a, b, c, d: -3.0 2.0 1.0 1.0
```

Программа сама получила те же числа, что мы считали руками.

**Шаг 3. Проверка числом.** Новый механизм мог ошибиться, поэтому градиенты всегда сверяют с *численным наклоном*: чуть сдвигаем вход вверх и вниз и делим разницу значений на разницу входов. Допиши:

```python
def formula(a, b, c):
    return a * b + c


h = 0.001
print("a:", round((formula(2 + h, -3, 10) - formula(2 - h, -3, 10)) / (2 * h), 6))
print("b:", round((formula(2, -3 + h, 10) - formula(2, -3 - h, 10)) / (2 * h), 6))
print("c:", round((formula(2, -3, 10 + h) - formula(2, -3, 10 - h)) / (2 * h), 6))
```

```output
a: -3.0
b: 2.0
c: 1.0
```

Числа совпали. Так проверяют любой новый код градиентов, и в больших проектах тоже.

**Шаг 4. Почему в `push` стоит `+=`.** Одно значение может использоваться несколько раз. Производная `x · x` равна `2x`, и при `x = 3` это 6. Допиши:

```python
x = Value(3.0)
y = x * x
y.backward()
print("x * x, x = 3:", x.grad)
```

```output
x * x, x = 3: 6.0
```

В `push` оба множителя здесь один и тот же объект, и он получает градиент дважды: 3 и ещё 3. Если бы мы написали `=` вместо `+=`, вышло бы 3. Такую ошибку легко не заметить: программа работает, но учится хуже.

**Шаг 5. Настоящая сеть.** Обучим механизмом задачу XOR из урока о скрытом слое: два входа, два скрытых нейрона, один выход, всего 9 весов. Правильные ответы тут −1 и 1. Допиши и запусти:

```python
state = 7


def weight():
    global state
    state = state * 16807 % 2147483647
    return Value(state / 2147483647 * 2 - 1)


hidden = [[weight(), weight(), weight()] for _ in range(2)]
out = [weight(), weight(), weight()]
weights = [w for neuron in hidden for w in neuron] + out
data = [(0, 0, -1), (0, 1, 1), (1, 0, 1), (1, 1, -1)]


def predict(p, q):
    h1 = (hidden[0][0] * p + hidden[0][1] * q + hidden[0][2]).tanh()
    h2 = (hidden[1][0] * p + hidden[1][1] * q + hidden[1][2]).tanh()
    return (out[0] * h1 + out[1] * h2 + out[2]).tanh()


for step in range(401):
    loss = Value(0.0)
    for p, q, answer in data:
        miss = predict(p, q) + (-answer)
        loss = loss + miss * miss
    for w in weights:
        w.grad = 0.0
    loss.backward()
    for w in weights:
        w.data -= 0.2 * w.grad
    if step % 100 == 0:
        print(step, round(loss.data, 4))
print([round(predict(p, q).data, 2) for p, q, _ in data])
```

```output
0 5.4584
100 0.0182
200 0.0075
300 0.0047
400 0.0034
[-0.97, 0.97, 0.97, -0.98]
```

Ошибка упала почти до нуля, и ответы близки к `−1, 1, 1, −1`. Ни одной производной для сети мы не выводили руками: механизм сделал это сам. Обрати внимание на строку `w.grad = 0.0`: градиенты каждый раз обнуляют, иначе они накапливаются от шага к шагу. Почему это плохо, увидишь в следующем уроке.

**Учись у тех, кто это создаёт.** Андрей Карпатый строит такой механизм за одну лекцию в начале курса Zero to Hero, его библиотека называется micrograd. Название `Value` я взял оттуда, а код в этом уроке написан заново. У него же есть microgpt: целый GPT на чистом Python. Ссылки в разделе источников.

### Исследуй и потренируйся

В тренажёре формула `L = (a · b + c) · f`. Нажимай «Шаг назад» и смотри, как градиент идёт от конца к началу. Кнопками плюс и минус толкай входы на 0,5 и сравни предсказание градиента с настоящим изменением.

В программе: добавь в класс вычитание `__sub__` и деление на число. Проверь их численно, как на шаге 3. Затем поменяй в сети шаг 0,2 на 2 и посмотри на ошибку.

**Собери и проверь сам.** Код выше дан готовым. Теперь напиши ключевой шаг своими руками: передачу градиента в умножении и в tanh и обратный проход в верном порядке. Заготовка и строгая проверка лежат в папке проекта `01_Projects/creator_labs`. Скопируй её к себе (уже написанные тобой файлы не перезапишутся) и запусти проверку:

```bash
mkdir -p ~/ai-path && cp -Rn ~/Desktop/"coli-dev 4"/coli-dev/01_Projects/creator_labs ~/ai-path/
cd ~/ai-path/creator_labs && python3 check_autograd_engine.py
```

Сначала все строки будут с ✗. Открой `autograd_blank.py`, допиши функции, где стоит `NotImplementedError`, и запускай проверку, пока все строки не станут ✓. Проверка сверяет твой код с численной производной, граничными случаями и свойствами, которые обязаны выполняться всегда. В самом файле проверки есть ответ: открывай его только после своей попытки.

### Вопрос

В `__mul__` градиент для `self` умножается на `other.data`. Почему?

### Варианты

- Если `self` вырастет на 1, результат вырастет на `other`: это и есть производная.
- Так результат умножения становится меньше, и обучение идёт заметно стабильнее.
- Это нужно лишь для проверки числом, а на сам градиент значение не влияет.

### Ответ

1

### Разбор

Производная произведения `x · y` по `x` равна `y`. Умножение на `result.grad` это правило цепочки, а не приём для устойчивости. И численная проверка не отдельный режим: она только подтверждает, что правило верное.

### Границы модели

Наш механизм работает с отдельными числами, поэтому он очень медленный: на каждое умножение создаётся объект Python. Настоящие библиотеки считают целыми массивами и на видеокарте, поэтому им хватает времени на миллиарды весов. Операций у нас мало, и обход в `backward` рекурсивный, поэтому на очень длинных формулах упрётся в предел глубины Python. Сеть на XOR при других начальных весах может застрять: это обычное свойство обучения, а не ошибка механизма.

## English

### In plain words

Computing derivatives by hand for every new network is slow and error-prone. A gradient engine does it itself. Each number remembers which numbers it came from and by which operation. Then, going back from the answer, each operation applies its own small rule, and all the derivatives add up. It is like a receipt where each line says what it was made of: reading it from bottom to top, you see each purchase's share. PyTorch works the same way, only on large arrays.

**What to know first.** «A Neural Network Learns» (step 8): the chain rule. «Python Classes» (step 2): objects and methods.

**If something is unclear.** If it is unclear why `+=` is used, find step 4 in the lesson: a number is used twice there, and its contributions add up. If classes are unclear, go back to «Python Classes». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Write, in about 70 lines of plain Python, an engine that computes gradients for any formula by itself, check it numerically, and use it to train a real small network. PyTorch works by the same idea, only on large arrays of numbers. It takes about an hour.

### Idea and mechanism

In the backpropagation lesson you derived derivatives by hand for a small network. For a large model this is impossible: it has millions of weights. We need a program that remembers how a formula was computed and goes back by itself. Such a mechanism is called *automatic differentiation*.

**Step 1. An example by hand.** Let `a = 2`, `b = −3`, `c = 10`, and the formula be: `d = a · b`, then `L = d + c`. We get `d = −6` and `L = 4`. The question: if `a` grows a little, how does `L` change? We go from the end.

- `L = d + c`. If `d` grows by 1, `L` grows by 1 too. So the gradient of `L` by `d` is 1. By `c` it is 1 as well.
- `d = a · b`. If `a` grows by 1, `d` changes by `b`, that is, by −3. If `b` grows, `d` changes by `a`, that is, by 2.
- By the chain rule we multiply: the gradient of `L` by `a` is `1 · (−3) = −3`, and by `b` it is `1 · 2 = 2`.

That is the whole algorithm. We go from the end to the start, and each node has a small rule: **addition passes the gradient as it is, and multiplication passes it times the other factor.** Check it with numbers: raise `a` by 0.1, and then `L = 2.1 · (−3) + 10 = 3.7`. The value fell by 0.3, and the gradient −3 predicted exactly `−3 · 0.1 = −0.3`.

**Step 2. The program.** Create a file:

```bash
cd ~/ai-path && nano value.py
```

The class `Value` holds a number, its gradient `grad`, its parents (the values it came from), and a function `push` that passes the gradient to the parents. The special names `__add__` and `__mul__` let us write ordinary `a + b` and `a * b` for our objects. The function `backward` lines the nodes up so that each is handled after all that depend on it, and goes from the end. Paste the program, save it, and run it with `python3 value.py`:

```python
import math


class Value:
    def __init__(self, data, parents=()):
        self.data = data
        self.grad = 0.0
        self.parents = parents
        self.push = lambda: None  # how to pass the gradient to the parents

    def __add__(self, other):
        other = other if isinstance(other, Value) else Value(other)
        result = Value(self.data + other.data, (self, other))

        def push():
            self.grad += result.grad
            other.grad += result.grad

        result.push = push
        return result

    def __mul__(self, other):
        other = other if isinstance(other, Value) else Value(other)
        result = Value(self.data * other.data, (self, other))

        def push():
            self.grad += other.data * result.grad
            other.grad += self.data * result.grad

        result.push = push
        return result

    def tanh(self):
        result = Value(math.tanh(self.data), (self,))

        def push():
            self.grad += (1 - result.data ** 2) * result.grad

        result.push = push
        return result

    def backward(self):
        order, seen = [], set()

        def visit(node):
            if node not in seen:
                seen.add(node)
                for parent in node.parents:
                    visit(parent)
                order.append(node)

        visit(self)
        self.grad = 1.0
        for node in reversed(order):
            node.push()


a, b, c = Value(2.0), Value(-3.0), Value(10.0)
d = a * b
L = d + c
L.backward()
print("L =", L.data)
print("a, b, c, d:", a.grad, b.grad, c.grad, d.grad)
```

```output
L = 4.0
a, b, c, d: -3.0 2.0 1.0 1.0
```

The program got by itself the same numbers we computed by hand.

**Step 3. A numeric check.** A new engine may err, so gradients are always compared with a *numeric slope*: shift an input a little up and down and divide the difference of values by the difference of inputs. Add this:

```python
def formula(a, b, c):
    return a * b + c


h = 0.001
print("a:", round((formula(2 + h, -3, 10) - formula(2 - h, -3, 10)) / (2 * h), 6))
print("b:", round((formula(2, -3 + h, 10) - formula(2, -3 - h, 10)) / (2 * h), 6))
print("c:", round((formula(2, -3, 10 + h) - formula(2, -3, 10 - h)) / (2 * h), 6))
```

```output
a: -3.0
b: 2.0
c: 1.0
```

The numbers match. Any new gradient code is checked this way, in large projects too.

**Step 4. Why `push` uses `+=`.** One value may be used several times. The derivative of `x · x` is `2x`, which is 6 at `x = 3`. Add this:

```python
x = Value(3.0)
y = x * x
y.backward()
print("x * x, x = 3:", x.grad)
```

```output
x * x, x = 3: 6.0
```

In `push` both factors are here the same object, and it receives the gradient twice: 3 and 3 more. With `=` instead of `+=` we would get 3. Such a bug is easy to miss: the program runs but learns worse.

**Step 5. A real network.** Let us train the XOR task from the hidden layer lesson with our engine: two inputs, two hidden neurons, one output, 9 weights in all. The right answers here are −1 and 1. Add this and run it:

```python
state = 7


def weight():
    global state
    state = state * 16807 % 2147483647
    return Value(state / 2147483647 * 2 - 1)


hidden = [[weight(), weight(), weight()] for _ in range(2)]
out = [weight(), weight(), weight()]
weights = [w for neuron in hidden for w in neuron] + out
data = [(0, 0, -1), (0, 1, 1), (1, 0, 1), (1, 1, -1)]


def predict(p, q):
    h1 = (hidden[0][0] * p + hidden[0][1] * q + hidden[0][2]).tanh()
    h2 = (hidden[1][0] * p + hidden[1][1] * q + hidden[1][2]).tanh()
    return (out[0] * h1 + out[1] * h2 + out[2]).tanh()


for step in range(401):
    loss = Value(0.0)
    for p, q, answer in data:
        miss = predict(p, q) + (-answer)
        loss = loss + miss * miss
    for w in weights:
        w.grad = 0.0
    loss.backward()
    for w in weights:
        w.data -= 0.2 * w.grad
    if step % 100 == 0:
        print(step, round(loss.data, 4))
print([round(predict(p, q).data, 2) for p, q, _ in data])
```

```output
0 5.4584
100 0.0182
200 0.0075
300 0.0047
400 0.0034
[-0.97, 0.97, 0.97, -0.98]
```

The error fell almost to zero, and the answers are close to `−1, 1, 1, −1`. We derived no derivative for the network by hand: the engine did it itself. Notice the line `w.grad = 0.0`: gradients are zeroed each time, or they pile up from step to step. You will see why this is bad in the next lesson.

**Learn from those who build this.** Andrej Karpathy builds such an engine in one lecture at the start of his Zero to Hero course; his library is called micrograd. I took the name `Value` from there, and the code in this lesson was written anew. He also has microgpt: a whole GPT in plain Python. The links are in the sources.

### Explore and practise

In the lab the formula is `L = (a · b + c) · f`. Press "Step back" and watch the gradient go from the end to the start. Use the plus and minus buttons to push inputs by 0.5, and compare the gradient's prediction with the real change.

In the program: add subtraction `__sub__` and division by a number to the class. Check them numerically, as in step 3. Then change the network's step from 0.2 to 2 and look at the error.

**Build and check it yourself.** The code above was given ready-made. Now write the key step with your own hands: the gradient push for multiplication and tanh and the backward pass in the right order. The blank and a strict check are in the project folder `01_Projects/creator_labs`. Copy it (files you have already written are not overwritten) and run the check:

```bash
mkdir -p ~/ai-path && cp -Rn ~/Desktop/"coli-dev 4"/coli-dev/01_Projects/creator_labs ~/ai-path/
cd ~/ai-path/creator_labs && python3 check_autograd_engine.py
```

At first every line shows ✗. Open `autograd_blank.py`, fill in the functions that raise `NotImplementedError`, and rerun until every line shows ✓. The check compares your code with numerical derivatives, edge cases and invariants that must always hold. The check file itself contains the answer: open it only after your own attempt.

### Question

In `__mul__` the gradient for `self` is multiplied by `other.data`. Why?

### Options

- If `self` grows by 1, the result grows by `other`: that is the derivative itself.
- It makes the product smaller, so that training goes noticeably more stably.
- It is needed only for the numeric check, and the value does not affect the gradient.

### Answer

1

### Explanation

The derivative of the product `x · y` by `x` is `y`. Multiplying by `result.grad` is the chain rule, not a trick for stability. And the numeric check is no separate mode: it only confirms that the rule is right.

### Limits

Our engine works with single numbers, so it is very slow: each multiplication creates a Python object. Real libraries compute with whole arrays on a graphics card, so they have time for billions of weights. We have few operations, and the walk in `backward` is recursive, so on very long formulas it hits Python's depth limit. The XOR network may get stuck with other starting weights: this is a normal property of training, not an error of the engine.

## Sources

- Andrej Karpathy, "The spelled-out intro to neural networks and backpropagation: building micrograd", in Neural Networks: Zero to Hero (consulted 2026-11-02): [Zero to Hero](https://karpathy.ai/zero-to-hero.html), [micrograd](https://github.com/karpathy/micrograd)
- Andrej Karpathy, "microgpt" (2026-02-12, consulted 2026-11-02): a GPT in about 200 lines of plain Python: [microgpt](https://karpathy.github.io/2026/02/12/microgpt/)
- Simon J.D. Prince, *Understanding Deep Learning*, MIT Press, 2023, the chapter on gradients and initialization (the site could not be read automatically on 2026-11-02, so I recommend it from memory, unverified): [udlbook](https://udlbook.github.io/udlbook/)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
