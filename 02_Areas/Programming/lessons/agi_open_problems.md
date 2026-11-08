---
subject: programming
lesson_id: programming.agi_open_problems
level: advanced
languages: ru, en
source_checked: 2026-11-07
source_review_interval_days: 180
---

# Открытые задачи на пути к AGI / Open problems on the road to AGI

## Русский

### Простыми словами

Современные модели умеют очень много, но есть задачи, которые никто пока не решил надёжно. Этот урок собирает их в один список и для каждой честно говорит, что уже измерено, а что остаётся спором. Похоже на карту с белыми пятнами: важно не только то, что нарисовано, но и то, где карта кончается. Одно белое пятно ты исследуешь сам: научишь сеть складывать числа и увидишь, как она ошибается за пределами виденного. Это самая старая и самая упрямая из открытых задач.

**Что нужно знать до.** Уроки этапа 4: «Что такое интеллект» (шаг 19), «Модели мира» (шаг 20), «Непрерывное обучение» (шаг 21) и «Спор о масштабировании» (шаг 22). Урок «Скрытый слой: нейросеть учит XOR» (шаг 8) для программы.

**Если непонятно.** Если неясна программа, вернись к уроку «Скрытый слой»: здесь такая же сеть, только с функцией tanh. Если неясно, что значит «за пределами виденного», перечитай урок «Машинное обучение: baseline и отложенная проверка» (шаг 9). Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Составить список главных открытых задач на пути к AGI, отделить в каждой измеренное от мнений и самому поставить опыт на одной из них: обобщение за пределы виденного. Нужно около 35 минут.

### Идея и механизм

**Шаг 1. Опыт: сложение за пределами виденного.** Научим маленькую сеть складывать два числа, но покажем ей только числа от 0 до 1. Потом спросим о числах от 1 до 2. Человек, понявший сложение, не заметит разницы. Сеть с функцией `tanh` внутри это не обязательно сумеет: `tanh` насыщается, её значение не выходит за пределы от −1 до 1. Создай файл `nano ~/ai-path/openproblems.py`, вставь и запусти.

```python
import math


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


def make(rand, low, high, count):
    return [(low + (high - low) * rand.next(), low + (high - low) * rand.next()) for _ in range(count)]


rand = Rand(2)
TRAIN = make(rand, 0, 1, 200)
NEAR = make(rand, 0, 1, 100)
FAR = make(rand, 1, 2, 100)

H = 8
w1 = [[rand.next() - 0.5, rand.next() - 0.5] for _ in range(H)]
b1 = [0.0] * H
w2 = [rand.next() - 0.5 for _ in range(H)]
b2 = 0.0


def predict(x):
    h = [math.tanh(w[0] * x[0] + w[1] * x[1] + b) for w, b in zip(w1, b1)]
    return sum(v * h_ for v, h_ in zip(w2, h)) + b2, h


for epoch in range(300):
    for x in TRAIN:
        y, h = predict(x)
        d = y - (x[0] + x[1])
        for j in range(H):
            g = d * w2[j] * (1 - h[j] ** 2)
            w2[j] -= 0.02 * d * h[j]
            w1[j][0] -= 0.02 * g * x[0]
            w1[j][1] -= 0.02 * g * x[1]
            b1[j] -= 0.02 * g
        b2 -= 0.02 * d


def error(points):
    return sum((predict(x)[0] - (x[0] + x[1])) ** 2 for x in points) / len(points)


print(f"mean squared error on new points inside [0, 1]: {error(NEAR):.5f}")
print(f"mean squared error on points in [1, 2]:        {error(FAR):.4f}")
for x in ((0.5, 0.5), (1, 1), (1.5, 1.5), (2, 2)):
    print(f"x = {x}: true {x[0] + x[1]}, network {predict(x)[0]:.2f}")
```

```output
mean squared error on new points inside [0, 1]: 0.00004
mean squared error on points in [1, 2]:        0.1156
x = (0.5, 0.5): true 1.0, network 1.01
x = (1, 1): true 2, network 1.96
x = (1.5, 1.5): true 3.0, network 2.71
x = (2, 2): true 4, network 3.23
```

Внутри участка обучения сеть почти не ошибается: средний квадрат ошибки 0,00004. За его пределами ошибка в тысячи раз больше, а в точке (2, 2) сеть отвечает 3,23 вместо 4. Она выучила не «сложение», а то, как выглядит сумма там, где её видела. Простая формула `x₁ + x₂` ошиблась бы на нуль везде: важна не только сеть, но и то, что в неё заложено заранее. Это и называют *обобщением за пределы распределения*. Geirhos и соавторы в 2020 году собрали много таких случаев под именем *короткого пути*: сеть находит правило, которое верно на данных обучения, но не то, которое имел в виду человек.

**Шаг 2. Список.** Ниже главные открытые задачи. У каждой отмечено, что *измерено* и что *открыто*. Каждая разобрана подробнее в одном из уроков пути.

- **Обобщение.** Измерено: сети ломаются за пределами виденного, как в опыте выше. Открыто: как учить так, чтобы правило переносилось на новое.
- **Обучение на малом.** Измерено: на ARC люди решают задачи по нескольким примерам заметно лучше моделей, и авторы ARC выпустили ARC-AGI-2, где разрыв снова велик. Открыто: как учиться так же экономно. Урок «Как мерить общий интеллект: ARC» (шаг 19).
- **Обучение всю жизнь.** Измерено: сеть забывает старое, когда учит новое. Открыто: как учиться постоянно без забывания и без хранения всего прошлого. Урок «Непрерывное обучение» (шаг 21).
- **Модели мира и планирование.** Измерено: поиск с моделью сильнее в играх и задачах с проверкой. Открыто: как строить точные модели открытого мира. Уроки «Модели мира» и «Планирование: поиск по дереву» (шаг 20).
- **Надёжное рассуждение.** Измерено: рассуждение повышает точность на задачах с проверкой, но написанная цепочка не всегда настоящая причина ответа. Открыто: как сделать рассуждение проверяемым. Урок «Рассуждение и награда по проверке» (шаг 14).
- **Долгие задачи.** Измерено: по замерам METR длина задач, которые агенты решают в половине случаев, удваивалась примерно за 7 месяцев. Открыто: продолжится ли это. Урок «Спор о масштабировании» (шаг 22).
- **Понимание устройства.** Измерено: в моделях находят понятные признаки и цепи. Открыто: можно ли объяснить большую модель целиком. Уроки шага 17.
- **Цели и безопасность.** Измерено: обман награды, поддакивание и подмена инструкций воспроизводятся. Открыто: как надёжно задать цель системе умнее проверяющего. Урок «Безопасность: что идёт не так» (шаг 18).

**Шаг 3. Как читать такой список.** Список не говорит, сколько лет до AGI и нужна ли для него каждая задача. Это мнения, и серьёзные исследователи расходятся. Одни считают, что многое решит масштаб и новые данные. Другие, например LeCun и Саттон, считают, что нужны другие устройства: модели мира и обучение на опыте. Честная позиция такая: измерения выше реальны, а вывод из них о сроках никто не доказал.

**Учись у тех, кто это создаёт.** Курс [Stanford CS224N](https://web.stanford.edu/class/cs224n/), лекция об открытых вопросах. Статья [Shortcut Learning in Deep Neural Networks](https://arxiv.org/abs/2004.07780). Отчёт [ARC-AGI-2](https://arxiv.org/abs/2505.11831).

### Исследуй и потренируйся

В тренажёре ниже серая полоса это участок, на котором сеть училась, линия это верный ответ, а кривая это ответ сети вдоль диагонали `x₁ = x₂`. В начале сеть учится на участке от 0 до 1, и в точке (2, 2) она сильно ошибается. Попробуй расширить участок обучения и найди, при каком ошибка в (2, 2) станет меньше 0,1.

### Вопрос

Сеть почти без ошибки складывает числа от 0 до 1, но для (2, 2) отвечает 3,23. Что это показывает?

### Варианты

- Сеть выучила вид суммы на виденном участке, а не само правило, и за пределами ошибается
- Сеть обучалась слишком мало шагов, и при более долгом обучении она бы правильно сложила
- Функция tanh не умеет складывать числа, поэтому сеть с ней ошибается и внутри участка

### Ответ

1

### Разбор

Внутри участка ошибка 0,00004, значит, обучения хватило. Ошибка появляется только там, где сеть не видела примеров. Функция tanh насыщается, и сеть, собранная из таких функций, плохо продолжает прямую линию далеко за участок. Расширение участка обучения помогает, но только до новой границы: это лечение данными, а не переносимое правило.

### Границы модели

Опыт крошечный: одна сеть, одна задача, один посев. Сети с другими функциями, например ReLU, продолжают прямые иначе, и итог будет другим. Список задач выбран мной по урокам этого пути и по названным источникам; другие авторы составили бы его иначе.

## English

### In plain words

Today's models can do a great deal, but some tasks nobody has yet solved reliably. This lesson gathers them into one list and for each says honestly what has been measured and what remains a dispute. It is like a map with blank areas: what matters is not only what is drawn but also where the map ends. You will explore one blank area yourself: teach a network to add numbers and see how it errs beyond what it has seen. This is the oldest and most stubborn of the open problems.

**What to know first.** The stage 4 lessons: «What is intelligence» (step 19), «World models» (step 20), «Continual learning» (step 21) and «The scaling debate» (step 22). «The Hidden Layer: A Network Learns XOR» (step 8) for the program.

**If something is unclear.** If the program is unclear, go back to «The Hidden Layer»: this is the same kind of network, only with the tanh function. If "beyond what it has seen" is unclear, reread «Machine Learning: Baselines and Held-out Evaluation» (step 9). Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Draw up a list of the main open problems on the road to AGI, separate in each what has been measured from opinion, and run an experiment on one of them yourself: generalising beyond what was seen. It takes about 35 minutes.

### Idea and mechanism

**Step 1. The experiment: addition beyond what was seen.** Teach a small network to add two numbers, but show it only numbers from 0 to 1. Then ask about numbers from 1 to 2. A person who has understood addition will not notice the difference. A network with the `tanh` function inside may not manage: `tanh` saturates, its value never leaves the range from −1 to 1. Create the file `nano ~/ai-path/openproblems.py`, paste and run it.

```python
import math


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


def make(rand, low, high, count):
    return [(low + (high - low) * rand.next(), low + (high - low) * rand.next()) for _ in range(count)]


rand = Rand(2)
TRAIN = make(rand, 0, 1, 200)
NEAR = make(rand, 0, 1, 100)
FAR = make(rand, 1, 2, 100)

H = 8
w1 = [[rand.next() - 0.5, rand.next() - 0.5] for _ in range(H)]
b1 = [0.0] * H
w2 = [rand.next() - 0.5 for _ in range(H)]
b2 = 0.0


def predict(x):
    h = [math.tanh(w[0] * x[0] + w[1] * x[1] + b) for w, b in zip(w1, b1)]
    return sum(v * h_ for v, h_ in zip(w2, h)) + b2, h


for epoch in range(300):
    for x in TRAIN:
        y, h = predict(x)
        d = y - (x[0] + x[1])
        for j in range(H):
            g = d * w2[j] * (1 - h[j] ** 2)
            w2[j] -= 0.02 * d * h[j]
            w1[j][0] -= 0.02 * g * x[0]
            w1[j][1] -= 0.02 * g * x[1]
            b1[j] -= 0.02 * g
        b2 -= 0.02 * d


def error(points):
    return sum((predict(x)[0] - (x[0] + x[1])) ** 2 for x in points) / len(points)


print(f"mean squared error on new points inside [0, 1]: {error(NEAR):.5f}")
print(f"mean squared error on points in [1, 2]:        {error(FAR):.4f}")
for x in ((0.5, 0.5), (1, 1), (1.5, 1.5), (2, 2)):
    print(f"x = {x}: true {x[0] + x[1]}, network {predict(x)[0]:.2f}")
```

```output
mean squared error on new points inside [0, 1]: 0.00004
mean squared error on points in [1, 2]:        0.1156
x = (0.5, 0.5): true 1.0, network 1.01
x = (1, 1): true 2, network 1.96
x = (1.5, 1.5): true 3.0, network 2.71
x = (2, 2): true 4, network 3.23
```

Inside the training range the network barely errs: the mean squared error is 0.00004. Outside it the error is thousands of times larger, and at (2, 2) the network answers 3.23 instead of 4. It learned not "addition" but what the sum looks like where it saw it. The plain formula `x₁ + x₂` would be off by zero everywhere: what matters is not only the network but what is built into it beforehand. This is called *out-of-distribution generalisation*. Geirhos and co-authors gathered many such cases in 2020 under the name *shortcut learning*: a network finds a rule that is right on the training data but not the one a person meant.

**Step 2. The list.** Below are the main open problems. Each notes what is *measured* and what is *open*. Each is covered in more detail in one of the path's lessons.

- **Generalisation.** Measured: networks break beyond what they have seen, as in the experiment above. Open: how to train so that a rule carries over to the new.
- **Learning from little.** Measured: on ARC people solve tasks from a few examples clearly better than models, and the ARC authors released ARC-AGI-2, where the gap is large again. Open: how to learn as economically. «Measuring general intelligence: ARC» (step 19).
- **Lifelong learning.** Measured: a network forgets the old when it learns the new. Open: how to learn continually without forgetting and without storing all the past. «Continual learning» (step 21).
- **World models and planning.** Measured: search with a model is stronger in games and tasks with a check. Open: how to build accurate models of the open world. «World models» and «Planning: tree search» (step 20).
- **Reliable reasoning.** Measured: reasoning raises accuracy on tasks with a check, but the written chain is not always the real cause of the answer. Open: how to make reasoning checkable. «Reasoning and verifiable rewards» (step 14).
- **Long tasks.** Measured: by METR's measurements, the length of tasks agents solve half the time doubled about every 7 months. Open: whether this continues. «The scaling debate» (step 22).
- **Understanding the inside.** Measured: understandable features and circuits are found in models. Open: whether a large model can be explained as a whole. The lessons of step 17.
- **Goals and safety.** Measured: reward hacking, sycophancy and prompt injection can be reproduced. Open: how to reliably give a goal to a system smarter than its checker. «Safety: what goes wrong» (step 18).

**Step 3. How to read such a list.** The list does not say how many years remain until AGI, nor whether each problem is needed for it. These are opinions, and serious researchers disagree. Some think scale and new data will solve much. Others, for example LeCun and Sutton, think other designs are needed: world models and learning from experience. The honest position: the measurements above are real, but nobody has proven a conclusion about timelines from them.

**Learn from the people who build this.** The [Stanford CS224N](https://web.stanford.edu/class/cs224n/) course, the lecture on open questions. The paper [Shortcut Learning in Deep Neural Networks](https://arxiv.org/abs/2004.07780). The [ARC-AGI-2](https://arxiv.org/abs/2505.11831) report.

### Explore and practise

In the lab below the grey band is the range the network trained on, the line is the right answer, and the curve is the network's answer along the diagonal `x₁ = x₂`. At the start the network trains on the range from 0 to 1, and at (2, 2) it errs badly. Try widening the training range and find at which width the error at (2, 2) drops below 0.1.

### Question

The network adds numbers from 0 to 1 almost without error, but for (2, 2) it answers 3.23. What does this show?

### Options

- The network learned what the sum looks like on the range it saw, not the rule, and errs beyond it
- The network trained for too few steps, and with longer training it would have added correctly
- The tanh function cannot add numbers, so the network with it errs inside the range as well

### Answer

1

### Explanation

Inside the range the error is 0.00004, so training was enough. The error appears only where the network saw no examples. The tanh function saturates, and a network built of such functions continues a straight line badly far beyond the range. Widening the training range helps, but only up to the new border: this is a cure by data, not a rule that carries over.

### Limits

The experiment is tiny: one network, one task, one seed. Networks with other functions, such as ReLU, continue straight lines differently, and the result would differ. The list of problems was chosen by me from the lessons of this path and the named sources; other authors would draw it up differently.

## Sources

- Robert Geirhos et al., "Shortcut Learning in Deep Neural Networks", arXiv:2004.07780 (2020), title read 2026-11-07: [arXiv:2004.07780](https://arxiv.org/abs/2004.07780)
- Francois Chollet et al., "ARC-AGI-2: A New Challenge for Frontier AI Reasoning Systems", arXiv:2505.11831 (2025), title read 2026-11-07: [arXiv:2505.11831](https://arxiv.org/abs/2505.11831)
- Thomas Kwa et al. (METR), "Measuring AI Ability to Complete Long Software Tasks", arXiv:2503.14499 (2025), as cited in «The scaling debate»: [arXiv:2503.14499](https://arxiv.org/abs/2503.14499)
- Stanford CS224N, course page opened 2026-11-02: [web.stanford.edu](https://web.stanford.edu/class/cs224n/)
- The program and all numbers were written for this lesson on 2026-11-07; the other claims summarise the lessons of this path, where their sources are listed.
