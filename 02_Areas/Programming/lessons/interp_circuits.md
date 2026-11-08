---
subject: programming
lesson_id: programming.interp_circuits
level: advanced
languages: ru, en
source_checked: 2026-11-07
source_review_interval_days: 180
---

# Цепи: какие части сети делают работу / Circuits: which parts of a network do the work

## Русский

### Простыми словами

Зонд показывает, что сведения в сети есть, но не говорит, какие её части делают работу. Чтобы это узнать, части сети отключают и смотрят, что сломалось. Небольшой набор частей, который сам решает задачу, называют *цепью*. Похоже на поиск неисправности в электрощитке: выключаешь автоматы по одному и смотришь, где погас свет. Но есть подвох, и ты его увидишь: если у части есть дублёр, её отключение ничего не ломает, и по одному отключению её не найти.

**Что нужно знать до.** Урок «Скрытый слой: нейросеть учит XOR» (шаг 8): зачем нужен скрытый слой и что такое XOR. Урок «Зонды: что знает сеть внутри» (шаг 17): знать и использовать это разное. Урок «Нейросеть учится сама» (шаг 8): обратное распространение.

**Если непонятно.** Если неясно, почему XOR требует нескольких нейронов, вернись к уроку «Скрытый слой». Если неясна сигмоида, это функция, которая сжимает число в промежуток от 0 до 1. Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Обучить маленькую сеть правилу «(a XOR b) И c», отключить её нейроны по одному, найти наименьшую цепь, которая решает задачу, и сделать подмену активаций, главный приём настоящих работ о цепях. Понять, почему отключение по одному обманывает. Нужно около 40 минут.

### Идея и механизм

**Шаг 1. Сеть и отключение.** Сеть видит три бита `a`, `b`, `c` и должна ответить 1, если `a` и `b` разные и при этом `c = 1`. В скрытом слое 6 нейронов. После обучения веса округлены до двух знаков, чтобы их было удобно читать. *Отключить* нейрон значит заменить его выход средним по всем входам: тогда он перестаёт нести сведения о конкретном входе, но сеть не получает непривычный ноль. Создай файл `nano ~/ai-path/circuits.py`, вставь и запусти. Обучение идёт меньше секунды.

```python
import itertools
import math


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


INPUTS = [(a, b, c) for a in (0, 1) for b in (0, 1) for c in (0, 1)]
TARGET = {x: int((x[0] != x[1]) and x[2]) for x in INPUTS}


def sig(z):
    return 1 / (1 + math.exp(-z))


rand = Rand(5)
W1 = [[rand.next() * 2 - 1 for _ in range(3)] for _ in range(6)]
B1 = [0.0] * 6
W2 = [rand.next() * 2 - 1 for _ in range(6)]
B2 = 0.0
for step in range(4000):
    for x in INPUTS:
        h = [sig(sum(w * v for w, v in zip(row, x)) + b) for row, b in zip(W1, B1)]
        y = sig(sum(w * v for w, v in zip(W2, h)) + B2)
        d = y - TARGET[x]
        for j in range(6):
            g = d * W2[j] * h[j] * (1 - h[j])
            W2[j] -= 0.5 * d * h[j]
            for i in range(3):
                W1[j][i] -= 0.5 * g * x[i]
            B1[j] -= 0.5 * g
        B2 -= 0.5 * d
W1 = [[round(w, 2) for w in row] for row in W1]
B1 = [round(b, 2) for b in B1]
W2 = [round(w, 2) for w in W2]
B2 = round(B2, 2)


def hidden(x):
    return [sig(sum(w * v for w, v in zip(row, x)) + b) for row, b in zip(W1, B1)]


def output(h):
    return sig(sum(w * v for w, v in zip(W2, h)) + B2)


MEAN = [sum(hidden(x)[j] for x in INPUTS) / 8 for j in range(6)]


def accuracy(keep):
    right = 0
    for x in INPUTS:
        h = [v if j in keep else MEAN[j] for j, v in enumerate(hidden(x))]
        right += (output(h) > 0.5) == TARGET[x]
    return right


print("all 6 neurons:", accuracy(set(range(6))), "of 8")
for j in range(6):
    print(f"neuron {j} switched off: {accuracy(set(range(6)) - {j})} of 8, output weight {W2[j]:+.2f}")
```

```output
all 6 neurons: 8 of 8
neuron 0 switched off: 8 of 8, output weight -1.49
neuron 1 switched off: 8 of 8, output weight -4.86
neuron 2 switched off: 7 of 8, output weight -13.85
neuron 3 switched off: 8 of 8, output weight -9.60
neuron 4 switched off: 8 of 8, output weight -6.43
neuron 5 switched off: 8 of 8, output weight +5.87
```

Только отключение нейрона 2 что-то ломает, и то один ответ из восьми. Остальные пять по одному ничего не меняют. Неужели вся работа в нейроне 2? Нет, и следующий шаг это покажет.

**Шаг 2. Наименьшая цепь.** Переберём все наборы нейронов: оставим набор включённым, а остальные отключим. Наборов всего `2⁶ = 64`, это быстро. Допиши и запусти.

```python
for size in range(7):
    circuits = [set(s) for s in itertools.combinations(range(6), size) if accuracy(set(s)) == 8]
    if circuits:
        print(f"smallest circuit: {size} neurons, for example {sorted(circuits[0])}; such circuits: {len(circuits)}")
        break
```

```output
smallest circuit: 2 neurons, for example [2, 3]; such circuits: 2
```

Цепь из двух нейронов, 2 и 3, решает задачу целиком. Но нейрон 3 по одному отключению был невидим. Причина: его работу частично повторяют другие нейроны, и пока они включены, без него можно обойтись. Это называют *избыточностью*, и в настоящих моделях она встречается постоянно. Вывод: «отключил, и ничего не сломалось» не значит «эта часть не нужна».

**Шаг 3. Подмена активаций.** Второй приём отвечает на другой вопрос: где хранится разница между двумя входами? Берут *чистый* вход `(1, 0, 1)` с ответом 1 и *испорченный* `(1, 1, 1)` с ответом 0: они отличаются только битом `b`. Запускают сеть на испорченном входе, но выход одного нейрона *подменяют* значением из чистого запуска. Если ответ вернулся к 1, этот нейрон и несёт нужную разницу. Допиши и запусти.

```python
clean, corrupt = (1, 0, 1), (1, 1, 1)
print("clean (1, 0, 1) gives", round(output(hidden(clean)), 3), "| corrupted (1, 1, 1) gives", round(output(hidden(corrupt)), 3))
for j in range(6):
    h = hidden(corrupt)
    h[j] = hidden(clean)[j]
    print(f"patch neuron {j} from the clean run: {output(h):.3f}")
```

```output
clean (1, 0, 1) gives 1.0 | corrupted (1, 1, 1) gives 0.001
patch neuron 0 from the clean run: 0.000
patch neuron 1 from the clean run: 0.001
patch neuron 2 from the clean run: 0.993
patch neuron 3 from the clean run: 0.000
patch neuron 4 from the clean run: 0.000
patch neuron 5 from the clean run: 0.080
```

Подмена одного нейрона 2 возвращает ответ почти целиком, 0,993. Значит, именно в нём лежит разница «b изменился, XOR стал 0». Нейрон 3 здесь не помогает: он нужен для другой части задачи, а не для этой пары входов. Два приёма вместе дают картину лучше, чем каждый отдельно.

**Шаг 4. Настоящие цепи.** В 2022 году Wang и соавторы нашли в GPT-2 small цепь для задачи «кому передали предмет» из 26 голов внимания, сгруппированных в 7 классов. Они использовали те же идеи: отключение и подмену. В 2025 году Anthropic описала *трассировку цепей*: модель на время заменяют более понятной, строят граф, по которому сведения идут от входа к ответу, и проверяют его вмешательством. В работе «On the Biology of a Large Language Model» этим методом разобраны, например, шаги рассуждения и планирование рифмы в стихах.

**Что здесь спорно.** Найденная цепь объясняет поведение на выбранных примерах, но не обязательно на всех. Граф строится для упрощённой замены модели, и авторы прямо пишут, что он описывает лишь часть вычисления. Отключение средним, нулём или другим входом даёт разные ответы, и выбор способа влияет на вывод.

**Учись у тех, кто это создаёт.** Статья [Interpretability in the Wild](https://arxiv.org/abs/2211.00593), работы [Circuit Tracing](https://transformer-circuits.pub/2025/attribution-graphs/methods.html) и [On the Biology of a Large Language Model](https://transformer-circuits.pub/2025/attribution-graphs/biology.html).

### Исследуй и потренируйся

В тренажёре ниже нажимай на нейроны, чтобы отключать и включать их, и смотри на восемь ответов сети справа. В начале включены все шесть. Найди наименьший набор, который ещё отвечает верно на все восемь входов. Потом включи подмену и посмотри, какой нейрон возвращает ответ.

### Вопрос

Отключение нейрона 3 по одному ничего не сломало, но он входит в наименьшую цепь. Как это возможно?

### Варианты

- Его работу частично дублируют другие нейроны, и пока они включены, без него можно обойтись
- Нейрон 3 на самом деле не нужен, а программа перебора наборов нейронов ошиблась
- Отключение средним значением никогда не меняет ответы сети, поэтому его итог ничего не значит

### Ответ

1

### Разбор

В цепи из двух нейронов остальные четыре отключены, и дублёров у нейрона 3 больше нет: без него цепь не справится. Пока дублёры включены, они закрывают его отсутствие, поэтому одиночное отключение его не видит. Перебор здесь полный, все 64 набора. А отключение средним меняет ответы: без нейрона 2 сеть ошиблась на одном входе.

### Границы модели

Сеть крошечная, и все 64 набора можно перебрать; в настоящей модели частей миллионы, и ищут умнее. Веса округлены до двух знаков. Наименьших цепей здесь две, и программа печатает первую из них; какую из равных называть «той самой», решает человек.

## English

### In plain words

A probe shows that information is in a network, but not which of its parts do the work. To find out, parts of the network are switched off to see what breaks. A small set of parts that solves the task by itself is called a *circuit*. It is like finding a fault in a fuse box: you switch the breakers off one by one and see where the light goes out. But there is a catch, and you will see it: if a part has a backup, switching it off breaks nothing, and one-at-a-time switching cannot find it.

**What to know first.** «The Hidden Layer: A Network Learns XOR» (step 8): why a hidden layer is needed and what XOR is. «Probes: what a network knows inside» (step 17): knowing and using are different. «A Neural Network Learns» (step 8): backpropagation.

**If something is unclear.** If it is unclear why XOR needs several neurons, go back to «The Hidden Layer». If the sigmoid is unclear, it is a function that squeezes a number into the range from 0 to 1. Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Train a small network on the rule "(a XOR b) AND c", switch its neurons off one by one, find the smallest circuit that solves the task, and do activation patching, the main technique of real circuit work. Understand why one-at-a-time switching misleads. It takes about 40 minutes.

### Idea and mechanism

**Step 1. The network and switching off.** The network sees three bits `a`, `b`, `c` and must answer 1 if `a` and `b` differ and `c = 1`. The hidden layer has 6 neurons. After training the weights are rounded to two decimals so they are easy to read. To *switch off* a neuron means to replace its output with its average over all inputs: it then carries no information about a particular input, but the network does not get an unfamiliar zero. Create the file `nano ~/ai-path/circuits.py`, paste and run it. Training takes under a second.

```python
import itertools
import math


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


INPUTS = [(a, b, c) for a in (0, 1) for b in (0, 1) for c in (0, 1)]
TARGET = {x: int((x[0] != x[1]) and x[2]) for x in INPUTS}


def sig(z):
    return 1 / (1 + math.exp(-z))


rand = Rand(5)
W1 = [[rand.next() * 2 - 1 for _ in range(3)] for _ in range(6)]
B1 = [0.0] * 6
W2 = [rand.next() * 2 - 1 for _ in range(6)]
B2 = 0.0
for step in range(4000):
    for x in INPUTS:
        h = [sig(sum(w * v for w, v in zip(row, x)) + b) for row, b in zip(W1, B1)]
        y = sig(sum(w * v for w, v in zip(W2, h)) + B2)
        d = y - TARGET[x]
        for j in range(6):
            g = d * W2[j] * h[j] * (1 - h[j])
            W2[j] -= 0.5 * d * h[j]
            for i in range(3):
                W1[j][i] -= 0.5 * g * x[i]
            B1[j] -= 0.5 * g
        B2 -= 0.5 * d
W1 = [[round(w, 2) for w in row] for row in W1]
B1 = [round(b, 2) for b in B1]
W2 = [round(w, 2) for w in W2]
B2 = round(B2, 2)


def hidden(x):
    return [sig(sum(w * v for w, v in zip(row, x)) + b) for row, b in zip(W1, B1)]


def output(h):
    return sig(sum(w * v for w, v in zip(W2, h)) + B2)


MEAN = [sum(hidden(x)[j] for x in INPUTS) / 8 for j in range(6)]


def accuracy(keep):
    right = 0
    for x in INPUTS:
        h = [v if j in keep else MEAN[j] for j, v in enumerate(hidden(x))]
        right += (output(h) > 0.5) == TARGET[x]
    return right


print("all 6 neurons:", accuracy(set(range(6))), "of 8")
for j in range(6):
    print(f"neuron {j} switched off: {accuracy(set(range(6)) - {j})} of 8, output weight {W2[j]:+.2f}")
```

```output
all 6 neurons: 8 of 8
neuron 0 switched off: 8 of 8, output weight -1.49
neuron 1 switched off: 8 of 8, output weight -4.86
neuron 2 switched off: 7 of 8, output weight -13.85
neuron 3 switched off: 8 of 8, output weight -9.60
neuron 4 switched off: 8 of 8, output weight -6.43
neuron 5 switched off: 8 of 8, output weight +5.87
```

Only switching off neuron 2 breaks anything, and then just one answer of eight. The other five, one at a time, change nothing. Is all the work in neuron 2? No, and the next step shows it.

**Step 2. The smallest circuit.** Try all sets of neurons: keep the set on and switch the rest off. There are only `2⁶ = 64` sets, so this is fast. Add this and run it.

```python
for size in range(7):
    circuits = [set(s) for s in itertools.combinations(range(6), size) if accuracy(set(s)) == 8]
    if circuits:
        print(f"smallest circuit: {size} neurons, for example {sorted(circuits[0])}; such circuits: {len(circuits)}")
        break
```

```output
smallest circuit: 2 neurons, for example [2, 3]; such circuits: 2
```

A circuit of two neurons, 2 and 3, solves the whole task. But neuron 3 was invisible to one-at-a-time switching. The reason: its work is partly repeated by other neurons, and while they are on, it can be done without. This is called *redundancy*, and real models have it all the time. Conclusion: "switched it off and nothing broke" does not mean "this part is not needed".

**Step 3. Activation patching.** The second technique answers another question: where is the difference between two inputs kept? Take a *clean* input `(1, 0, 1)` with answer 1 and a *corrupted* one `(1, 1, 1)` with answer 0: they differ only in bit `b`. Run the network on the corrupted input, but *patch* one neuron's output with its value from the clean run. If the answer goes back to 1, this neuron carries the difference. Add this and run it.

```python
clean, corrupt = (1, 0, 1), (1, 1, 1)
print("clean (1, 0, 1) gives", round(output(hidden(clean)), 3), "| corrupted (1, 1, 1) gives", round(output(hidden(corrupt)), 3))
for j in range(6):
    h = hidden(corrupt)
    h[j] = hidden(clean)[j]
    print(f"patch neuron {j} from the clean run: {output(h):.3f}")
```

```output
clean (1, 0, 1) gives 1.0 | corrupted (1, 1, 1) gives 0.001
patch neuron 0 from the clean run: 0.000
patch neuron 1 from the clean run: 0.001
patch neuron 2 from the clean run: 0.993
patch neuron 3 from the clean run: 0.000
patch neuron 4 from the clean run: 0.000
patch neuron 5 from the clean run: 0.080
```

Patching neuron 2 alone brings the answer almost all the way back, 0.993. So the difference "b changed, XOR became 0" lies in it. Neuron 3 does not help here: it is needed for another part of the task, not for this pair of inputs. The two techniques together give a better picture than either alone.

**Step 4. Real circuits.** In 2022 Wang and co-authors found in GPT-2 small a circuit for "who was the object given to" made of 26 attention heads grouped into 7 classes. They used the same ideas: switching off and patching. In 2025 Anthropic described *circuit tracing*: the model is temporarily replaced by a more understandable one, a graph of how information flows from the input to the answer is built, and it is checked by intervention. The work "On the Biology of a Large Language Model" uses this method to examine, for example, steps of reasoning and the planning of rhymes in poems.

**What is disputed.** A circuit found explains behaviour on the chosen examples, but not necessarily on all. The graph is built for a simplified replacement of the model, and the authors say directly that it describes only part of the computation. Switching off by the mean, by zero or by another input gives different answers, and the choice of method affects the conclusion.

**Learn from the people who build this.** The paper [Interpretability in the Wild](https://arxiv.org/abs/2211.00593), and the works [Circuit Tracing](https://transformer-circuits.pub/2025/attribution-graphs/methods.html) and [On the Biology of a Large Language Model](https://transformer-circuits.pub/2025/attribution-graphs/biology.html).

### Explore and practise

In the lab below click the neurons to switch them off and on, and watch the network's eight answers on the right. At the start all six are on. Find the smallest set that still answers all eight inputs correctly. Then switch on patching and see which neuron brings the answer back.

### Question

Switching neuron 3 off on its own broke nothing, yet it belongs to the smallest circuit. How is that possible?

### Options

- Its work is partly duplicated by other neurons, and while they are on, it can be done without
- Neuron 3 is not really needed, and the program that tried every set of neurons made a mistake
- Switching off by the mean never changes the network's answers, so its result means nothing

### Answer

1

### Explanation

In the two-neuron circuit the other four are off, and neuron 3 has no backups left: without it the circuit fails. While the backups are on they cover its absence, so single switching does not see it. The search here is complete, all 64 sets. And switching off by the mean does change answers: without neuron 2 the network erred on one input.

### Limits

The network is tiny, so all 64 sets can be tried; a real model has millions of parts, and the search is smarter. The weights are rounded to two decimals. There are two smallest circuits here, and the program prints the first; which of equal ones to call "the" circuit is a human choice.

## Sources

- Kevin Wang et al., "Interpretability in the Wild: a Circuit for Indirect Object Identification in GPT-2 small", arXiv:2211.00593 (2022): 26 attention heads grouped into 7 main classes, read in the abstract on 2026-11-07: [arXiv:2211.00593](https://arxiv.org/abs/2211.00593)
- Emmanuel Ameisen et al., "Circuit Tracing: Revealing Computational Graphs in Language Models", Transformer Circuits (2025), title and page opened 2026-11-07: [transformer-circuits.pub](https://transformer-circuits.pub/2025/attribution-graphs/methods.html)
- Jack Lindsey et al., "On the Biology of a Large Language Model", Transformer Circuits (2025), title and page opened 2026-11-07: [transformer-circuits.pub](https://transformer-circuits.pub/2025/attribution-graphs/biology.html)
- The network, the program and all numbers were written for this lesson on 2026-11-07.
