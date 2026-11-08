---
subject: programming
lesson_id: programming.agi_continual_learning
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Непрерывное обучение: как сеть забывает / Continual learning: how a network forgets

## Русский

### Простыми словами

Обычная сеть, выучив вторую задачу, часто забывает первую. Причина простая: обучение подгоняет веса только под те примеры, что видит сейчас, и стирает то, что было нужно раньше. Похоже на школьную доску: пишешь новую задачу мелом поверх старой, и старая пропадает. Простое лечение это повторять старые примеры вперемешку с новыми, но за это платят памятью и временем. Как учиться всю жизнь и не забывать, остаётся открытым вопросом.

**Что нужно знать до.** Уроки «Градиентный спуск и шаг обучения» (шаг 4) и «Скрытый слой: нейросеть учит XOR» (шаг 8): как обучение меняет веса. Урок «Мини-батчи и переобучение» (шаг 9): ошибка на проверочных данных.

**Если непонятно.** Если неясно, почему шаг спуска «не помнит» прошлое, вернись к уроку «Градиентный спуск и шаг обучения». Если неясны веса скрытого слоя, перечитай пример в уроке «Скрытый слой». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Своими руками заставить сеть забыть первую задачу после второй, полечить это повторением примеров и посчитать цену. Попробовать и упругие веса, увидеть, что простая версия у меня не сработала, и понять почему. Нужно около 40 минут.

### Идея и механизм

**Шаг 1. Беда.** Человек, научившись ездить на велосипеде, не разучивается ходить. Обычная сеть разучивается. Причина простая: спуск меняет веса так, чтобы снизить ошибку **на текущих данных**, и ему всё равно, что было раньше. Это называют **катастрофическим забыванием**. Большие языковые модели обходят беду просто: их обучают на всех данных сразу и потом замораживают. Но система, которая учится всю жизнь, так не может, и поэтому Alberta Plan Саттона и соавторов ставит такое обучение в центр пути к AGI. Это их взгляд, а не общепринятый вывод.

**Шаг 2. Опыт.** Сеть на 8 скрытых нейронов. Точки на плоскости. Задача A: левая половина, ответ «да» при `y > 0`. Задача B: правая половина, ответ «да» при `y < 0`. Одна сеть может решить обе: зоны разные. Создай файл `nano ~/ai-path/forget.py`, вставь и запусти.

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


HIDDEN = 8


def new_net(seed):
    rand = Rand(seed)
    noise = lambda: (rand.next() - 0.5) * 2
    return {"w1": [[noise() for _ in range(3)] for _ in range(HIDDEN)], "w2": [noise() for _ in range(HIDDEN + 1)]}


def forward(net, x, y):
    h = [math.tanh(w[0] * x + w[1] * y + w[2]) for w in net["w1"]]
    s = sum(a * b for a, b in zip(net["w2"], h)) + net["w2"][-1]
    return h, 1 / (1 + math.exp(-max(min(s, 30), -30)))


def train_step(net, x, y, label, rate, anchors=None, strength=0.0):
    h, p = forward(net, x, y)
    error = p - label
    for j in range(HIDDEN):
        g = net["w2"][j] * (1 - h[j] * h[j]) * error
        net["w1"][j][0] -= rate * g * x
        net["w1"][j][1] -= rate * g * y
        net["w1"][j][2] -= rate * g
        net["w2"][j] -= rate * h[j] * error
    net["w2"][-1] -= rate * error
    if anchors:
        for j in range(HIDDEN):
            for k in range(3):
                net["w1"][j][k] -= rate * strength * anchors["f1"][j][k] * (net["w1"][j][k] - anchors["w1"][j][k])
        for j in range(HIDDEN + 1):
            net["w2"][j] -= rate * strength * anchors["f2"][j] * (net["w2"][j] - anchors["w2"][j])


def points(side, count, seed):
    rand = Rand(seed)
    out = []
    for _ in range(count):
        x, y = side * (0.1 + 0.9 * rand.next()), rand.next() * 2 - 1
        out.append((x, y, (y > 0) if side < 0 else (y < 0)))
    return out


TRAIN_A, TRAIN_B, CHECK_A, CHECK_B = points(-1, 200, 1), points(1, 200, 2), points(-1, 300, 3), points(1, 300, 4)


def accuracy(net, data):
    return round(sum((forward(net, x, y)[1] > 0.5) == label for x, y, label in data) / len(data), 3)


def train_on(net, data, epochs, seed, rate=0.08, replay=None, share=0.0, anchors=None, strength=0.0):
    rand = Rand(seed)
    for _ in range(epochs * len(data)):
        if replay and rand.next() < share:
            x, y, label = replay[rand.below(len(replay))]
        else:
            x, y, label = data[rand.below(len(data))]
        train_step(net, x, y, label, rate, anchors, strength)


net = new_net(11)
train_on(net, TRAIN_A, 60, 12)
print("after task A: A", accuracy(net, CHECK_A), "B", accuracy(net, CHECK_B))
trained_a = {"w1": [row[:] for row in net["w1"]], "w2": net["w2"][:]}
train_on(net, TRAIN_B, 40, 13)
print("after task B: A", accuracy(net, CHECK_A), "B", accuracy(net, CHECK_B))
```

```output
after task A: A 1.0 B 0.017
after task B: A 0.003 B 0.99
```

После задачи A точность на ней `1,0`. После задачи B на ней `0,003`. Сеть не просто забыла: она теперь отвечает почти всегда наоборот. Новое правило распространилось и на старую зону, потому что про старую зону обучение ничего не знало.

**Шаг 3. Лекарство: повторение.** Сохраним несколько примеров A и будем иногда подмешивать их при обучении на B. Допиши и запусти. Строка это сколько примеров сохранено, какая доля шагов идёт на них и итоговая точность на A и B.

```python
def copy(net):
    return {"w1": [row[:] for row in net["w1"]], "w2": net["w2"][:]}


print("replay: stored examples of A, share of steps, A, B")
for stored, share in ((0, 0.0), (5, 0.2), (20, 0.2), (20, 0.5), (200, 0.5)):
    net = copy(trained_a)
    train_on(net, TRAIN_B, 40, 13, replay=TRAIN_A[:stored] or None, share=share)
    print(stored, share, accuracy(net, CHECK_A), accuracy(net, CHECK_B))
```

```output
replay: stored examples of A, share of steps, A, B
0 0.0 0.003 0.99
5 0.2 0.517 0.983
20 0.2 0.8 0.983
20 0.5 0.853 0.99
200 0.5 0.973 0.993
```

Пять примеров при доле `0,2` дают `0,517`, уже не катастрофа. Двадцать примеров дают `0,8`, а при доле `0,5` дают `0,853`. Все 200 примеров дают `0,973`. **Цена ясна:** нужно хранить старые данные и тратить на них шаги. Для одного повторения шагов становится больше, а на всю жизнь данных накопится очень много. Иногда старые данные и вовсе хранить нельзя, например личные.

**Шаг 4. Упругие веса.** Kirkpatrick и соавторы предложили метод EWC (elastic weight consolidation, «упругое закрепление весов»). Важные для старой задачи веса привязываем пружиной к старым значениям. Штраф: `λ / 2 · Σ F · (w − w_старое)²`, где `F` показывает важность веса: это средний квадрат градиента на старых данных. Посчитай руками: при `F = 0,5`, `λ = 10`, `w − w_старое = 0,2` штраф `10 / 2 · 0,5 · 0,04 = 0,1`. Допиши и запусти.

```python
def importance(net, data):
    f1 = [[0.0] * 3 for _ in range(HIDDEN)]
    f2 = [0.0] * (HIDDEN + 1)
    for x, y, label in data:
        h, p = forward(net, x, y)
        error = p - label
        for j in range(HIDDEN):
            g = net["w2"][j] * (1 - h[j] * h[j]) * error
            f1[j][0] += (g * x) ** 2 / len(data)
            f1[j][1] += (g * y) ** 2 / len(data)
            f1[j][2] += g ** 2 / len(data)
            f2[j] += (h[j] * error) ** 2 / len(data)
        f2[-1] += error ** 2 / len(data)
    return f1, f2


f1, f2 = importance(trained_a, TRAIN_A)
anchors = {"w1": trained_a["w1"], "w2": trained_a["w2"], "f1": f1, "f2": f2}
print("elastic weights: strength, A, B")
for strength in (0, 10, 100, 1000, 5000):
    net = copy(trained_a)
    train_on(net, TRAIN_B, 40, 13, anchors=anchors, strength=strength)
    print(strength, accuracy(net, CHECK_A), accuracy(net, CHECK_B))
```

```output
elastic weights: strength, A, B
0 0.003 0.99
10 0.003 0.987
100 0.003 0.987
1000 0.48 0.483
5000 0.48 0.483
```

И вот честный итог: **в моём опыте это не помогло**. При силе 10 и 100 забывание то же, `0,003`. При 1000 сеть застревает на угадывании: `0,48` на обеих задачах. Почему? После полного обучения на A ошибка почти нулевая, поэтому и градиенты почти нулевые, и важность `F` оказывается очень мала: пружины слабые. При большой силе шаг становится неустойчивым. Это не значит, что метод плох: в статье он работал на больших сетях и других задачах. Значит, простая версия на моей маленькой сети не годится, и заявления о методах стоит проверять своими руками.

**Шаг 5. Что здесь открыто.** Хорошего общего решения нет. Есть работы, показывающие и обратную беду: сеть, которая долго учится, теряет способность учиться новому (Dohare и др., 2024). Многие считают это серьёзным препятствием на пути к AGI. Другие отвечают, что на практике хватает повторения и периодического обучения заново. Спор открыт.

**Учись у тех, кто это создаёт.** Статья [EWC](https://arxiv.org/abs/1612.00796) и [The Alberta Plan](https://arxiv.org/abs/2208.11173). Лекции Ричарда Саттона легко найти по его [странице](http://incompleteideas.net/).

### Исследуй и потренируйся

В тренажёре сеть учится прямо сейчас. Цвет фона это её ответ в каждой точке. Смотри, как при обучении на B левая половина перекрашивается. Двигай, сколько хранить и как часто повторять, и найди наименьшую память, при которой сеть помнит обе задачи.

В программе поставь задаче B ту же зону, что у A, со своим правилом. Может ли помочь повторение? Подумай, что вообще может знать сеть без номера задачи на входе.

### Вопрос

Почему сеть забывает задачу A, когда учится на задаче B?

### Варианты

- Спуск снижает ошибку только на текущих данных и потому меняет веса, важные для старой задачи.
- Старые веса стираются из памяти компьютера, потому что новых весов становится больше.
- Новая задача всегда труднее старой, поэтому сеть тратит на неё все нейроны без остатка.

### Ответ

1

### Разбор

Ничего не стирается, и веса те же, их только сдвигают. Задача B тут не труднее задачи A. Спуск просто не знает о старых данных: на них нет никакой ошибки в формуле. Поэтому веса уходят туда, где хорошо только новой задаче.

### Границы модели

Сеть и задачи игрушечные и подобраны так, чтобы забывание было полным. Настоящие задачи обычно частично совпадают, и забывание слабее. Версия EWC здесь самая простая, без подбора важности, поэтому её неудача говорит только об этом опыте. Числа зависят от зерна случайности и шага.

## English

### In plain words

An ordinary network that learns a second task often forgets the first. The reason is simple: training fits the weights only to the examples it sees now and wipes what was needed before. It is like a school blackboard: you chalk a new problem over the old one, and the old one is gone. The simple cure is to replay old examples mixed with new ones, but you pay for it in memory and time. How to learn for a lifetime without forgetting is still an open question.

**What to know first.** The lessons «Gradient Descent and the Learning Rate» (step 4) and «The Hidden Layer: A Network Learns XOR» (step 8): how training changes weights. The lesson «Mini-Batches and Overfitting» (step 9): error on held-out data.

**If something is unclear.** If it is unclear why a descent step "does not remember" the past, go back to «Gradient Descent and the Learning Rate». If the hidden-layer weights are unclear, reread the example in «The Hidden Layer». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Make a network forget the first task after the second with your own hands, treat this with replay of examples, and count the price. Try elastic weights too, see that a simple version failed for me, and understand why. It takes about 40 minutes.

### Idea and mechanism

**Step 1. The trouble.** A person who learns to ride a bike does not forget how to walk. An ordinary network does. The reason is simple: descent changes weights to lower the error **on current data**, and what came before does not matter to it. This is called **catastrophic forgetting**. Large language models avoid the trouble simply: they train on all data at once and then freeze. But a system that learns for life cannot do that, so Sutton and co-authors' Alberta Plan puts such learning at the centre of the road to AGI. That is their view, not a settled conclusion.

**Step 2. The experiment.** A network of 8 hidden neurons. Points on a plane. Task A: the left half, the answer is yes when `y > 0`. Task B: the right half, the answer is yes when `y < 0`. One network can solve both: the zones differ. Create the file `nano ~/ai-path/forget.py`, paste and run it.

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


HIDDEN = 8


def new_net(seed):
    rand = Rand(seed)
    noise = lambda: (rand.next() - 0.5) * 2
    return {"w1": [[noise() for _ in range(3)] for _ in range(HIDDEN)], "w2": [noise() for _ in range(HIDDEN + 1)]}


def forward(net, x, y):
    h = [math.tanh(w[0] * x + w[1] * y + w[2]) for w in net["w1"]]
    s = sum(a * b for a, b in zip(net["w2"], h)) + net["w2"][-1]
    return h, 1 / (1 + math.exp(-max(min(s, 30), -30)))


def train_step(net, x, y, label, rate, anchors=None, strength=0.0):
    h, p = forward(net, x, y)
    error = p - label
    for j in range(HIDDEN):
        g = net["w2"][j] * (1 - h[j] * h[j]) * error
        net["w1"][j][0] -= rate * g * x
        net["w1"][j][1] -= rate * g * y
        net["w1"][j][2] -= rate * g
        net["w2"][j] -= rate * h[j] * error
    net["w2"][-1] -= rate * error
    if anchors:
        for j in range(HIDDEN):
            for k in range(3):
                net["w1"][j][k] -= rate * strength * anchors["f1"][j][k] * (net["w1"][j][k] - anchors["w1"][j][k])
        for j in range(HIDDEN + 1):
            net["w2"][j] -= rate * strength * anchors["f2"][j] * (net["w2"][j] - anchors["w2"][j])


def points(side, count, seed):
    rand = Rand(seed)
    out = []
    for _ in range(count):
        x, y = side * (0.1 + 0.9 * rand.next()), rand.next() * 2 - 1
        out.append((x, y, (y > 0) if side < 0 else (y < 0)))
    return out


TRAIN_A, TRAIN_B, CHECK_A, CHECK_B = points(-1, 200, 1), points(1, 200, 2), points(-1, 300, 3), points(1, 300, 4)


def accuracy(net, data):
    return round(sum((forward(net, x, y)[1] > 0.5) == label for x, y, label in data) / len(data), 3)


def train_on(net, data, epochs, seed, rate=0.08, replay=None, share=0.0, anchors=None, strength=0.0):
    rand = Rand(seed)
    for _ in range(epochs * len(data)):
        if replay and rand.next() < share:
            x, y, label = replay[rand.below(len(replay))]
        else:
            x, y, label = data[rand.below(len(data))]
        train_step(net, x, y, label, rate, anchors, strength)


net = new_net(11)
train_on(net, TRAIN_A, 60, 12)
print("after task A: A", accuracy(net, CHECK_A), "B", accuracy(net, CHECK_B))
trained_a = {"w1": [row[:] for row in net["w1"]], "w2": net["w2"][:]}
train_on(net, TRAIN_B, 40, 13)
print("after task B: A", accuracy(net, CHECK_A), "B", accuracy(net, CHECK_B))
```

```output
after task A: A 1.0 B 0.017
after task B: A 0.003 B 0.99
```

After task A its accuracy there is `1.0`. After task B it is `0.003`. The network did not just forget: it now answers nearly always the opposite way. The new rule spread to the old zone too, because training knew nothing about the old zone.

**Step 3. A remedy: replay.** We keep a few examples of A and sometimes mix them in while training on B. Add this and run it. A row shows how many examples are stored, what share of steps goes to them, and the final accuracy on A and B.

```python
def copy(net):
    return {"w1": [row[:] for row in net["w1"]], "w2": net["w2"][:]}


print("replay: stored examples of A, share of steps, A, B")
for stored, share in ((0, 0.0), (5, 0.2), (20, 0.2), (20, 0.5), (200, 0.5)):
    net = copy(trained_a)
    train_on(net, TRAIN_B, 40, 13, replay=TRAIN_A[:stored] or None, share=share)
    print(stored, share, accuracy(net, CHECK_A), accuracy(net, CHECK_B))
```

```output
replay: stored examples of A, share of steps, A, B
0 0.0 0.003 0.99
5 0.2 0.517 0.983
20 0.2 0.8 0.983
20 0.5 0.853 0.99
200 0.5 0.973 0.993
```

Five examples at share `0.2` give `0.517`, no longer a catastrophe. Twenty examples give `0.8`, and at share `0.5` give `0.853`. All 200 examples give `0.973`. **The price is clear:** you must store old data and spend steps on it. For one replay there are more steps, and over a lifetime a great deal of data piles up. Sometimes old data cannot be kept at all, such as personal data.

**Step 4. Elastic weights.** Kirkpatrick and co-authors proposed the EWC method (elastic weight consolidation). Weights important to the old task are tied by a spring to their old values. The fine: `λ / 2 · Σ F · (w − w_old)²`, where `F` shows a weight's importance: the mean squared gradient on old data. Compute by hand: at `F = 0.5`, `λ = 10`, `w − w_old = 0.2` the fine is `10 / 2 · 0.5 · 0.04 = 0.1`. Add this and run it.

```python
def importance(net, data):
    f1 = [[0.0] * 3 for _ in range(HIDDEN)]
    f2 = [0.0] * (HIDDEN + 1)
    for x, y, label in data:
        h, p = forward(net, x, y)
        error = p - label
        for j in range(HIDDEN):
            g = net["w2"][j] * (1 - h[j] * h[j]) * error
            f1[j][0] += (g * x) ** 2 / len(data)
            f1[j][1] += (g * y) ** 2 / len(data)
            f1[j][2] += g ** 2 / len(data)
            f2[j] += (h[j] * error) ** 2 / len(data)
        f2[-1] += error ** 2 / len(data)
    return f1, f2


f1, f2 = importance(trained_a, TRAIN_A)
anchors = {"w1": trained_a["w1"], "w2": trained_a["w2"], "f1": f1, "f2": f2}
print("elastic weights: strength, A, B")
for strength in (0, 10, 100, 1000, 5000):
    net = copy(trained_a)
    train_on(net, TRAIN_B, 40, 13, anchors=anchors, strength=strength)
    print(strength, accuracy(net, CHECK_A), accuracy(net, CHECK_B))
```

```output
elastic weights: strength, A, B
0 0.003 0.99
10 0.003 0.987
100 0.003 0.987
1000 0.48 0.483
5000 0.48 0.483
```

And here is the honest result: **in my experiment this did not help**. At strengths 10 and 100 the forgetting is the same, `0.003`. At 1000 the network gets stuck guessing: `0.48` on both tasks. Why? After full training on A the error is nearly zero, so gradients are nearly zero, and the importance `F` turns out very small: the springs are weak. At great strength the step becomes unstable. This does not mean the method is bad: in the paper it worked on large networks and other tasks. It means a simple version on my small network does not fit, and claims about methods are worth checking by hand.

**Step 5. What is open here.** There is no good general solution. Work also shows an opposite trouble: a network that trains for long loses the ability to learn new things (Dohare et al., 2024). Many consider this a serious obstacle on the road to AGI. Others reply that in practice replay and periodic retraining are enough. The dispute is open.

**Learn from the people who build this.** The [EWC paper](https://arxiv.org/abs/1612.00796) and [The Alberta Plan](https://arxiv.org/abs/2208.11173). Richard Sutton's lectures are easy to find through his [page](http://incompleteideas.net/).

### Explore and practise

In the lab the network trains right now. The background colour is its answer at each point. Watch the left half change colour during training on B. Move how much to store and how often to replay, and find the smallest memory at which the network remembers both tasks.

In the program, give task B the same zone as A, with its own rule. Can replay help? Think about what a network can know at all without a task number at its input.

### Question

Why does a network forget task A while learning task B?

### Options

- Descent lowers error only on current data, so it changes weights important to the old task.
- Old weights are wiped from the computer's memory, because new weights become more numerous.
- A new task is always harder than the old, so the network spends every neuron on it alone.

### Answer

1

### Explanation

Nothing is wiped, and the weights are the same ones, only shifted. Task B is no harder than task A here. Descent simply does not know of the old data: there is no error from them in the formula. So weights move where things are good only for the new task.

### Limits

The network and tasks are toys chosen to make forgetting total. Real tasks usually overlap partly, and forgetting is weaker. The EWC version here is the simplest, with no tuning of importance, so its failure speaks only of this experiment. The numbers depend on the random seed and the step.

## Sources

- James Kirkpatrick et al., "Overcoming catastrophic forgetting in neural networks", arXiv:1612.00796 (2016), equation 3, the fine, read 2026-11-03: [arXiv:1612.00796](https://arxiv.org/abs/1612.00796)
- Richard S. Sutton, Michael Bowling, Patrick M. Pilarski, "The Alberta Plan for AI Research", arXiv:2208.11173 (2022), title read 2026-11-03: [arXiv:2208.11173](https://arxiv.org/abs/2208.11173)
- Shibhansh Dohare et al., "Loss of plasticity in deep continual learning", Nature 632 (2024), abstract read 2026-11-03: [Nature](https://www.nature.com/articles/s41586-024-07711-7)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
