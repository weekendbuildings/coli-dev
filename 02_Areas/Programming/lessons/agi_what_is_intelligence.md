---
subject: programming
lesson_id: programming.agi_what_is_intelligence
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Что такое интеллект: три определения / What is intelligence: three definitions

## Русский

### Простыми словами

AGI, общий искусственный интеллект, это слово, у которого нет одного принятого определения. Поэтому спор «есть ли уже AGI» часто идёт ни о чём. В уроке три серьёзных определения: сколько целей система достигает в самых разных средах; как быстро она осваивает новое; на каком она уровне по качеству и широте умений. Похоже на вопрос «кто лучший спортсмен»: ответ зависит от того, считаешь ли ты медали в одном виде спорта, во многих или то, как быстро человек осваивает новый вид. В опыте ты увидишь, что победитель меняется вместе с определением.

**Что нужно знать до.** Что такое агент, среда и награда: урок «Автоматы: пробовать новое или брать лучшее» (шаг 13). Своя языковая модель из урока «Своя языковая модель» (шаг 12): её мы тоже оцениваем.

**Если непонятно.** Если неясна запись `2^(−K)` и длина описания в битах, вернись к уроку «Информация, энтропия и кросс-энтропия» (шаг 6). Если неясно, что такое награда, загляни в шаг 1 урока «Автоматы». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Разобрать три настоящих определения интеллекта, применить их к своим системам и увидеть в опыте, что победитель меняется вместе с определением. Здесь много спорного, поэтому показано отдельно, что измерено, а что чьё мнение. Нужно около 40 минут.

### Идея и механизм

**Шаг 1. Зачем определение.** Слово AGI (общий искусственный интеллект) часто говорят без определения, и спор тогда ни о чём. Возьмём три серьёзных подхода.

- **Legg и Hutter, 2007.** Интеллект это способность достигать целей в широком кругу сред. Считается как сумма наград по всем средам, причём простые среды весят больше: вес `2^(−K)`, где `K` это длина описания среды в битах.
- **Chollet, 2019.** Важен не навык, а **скорость его получения**. Шахматная программа умеет много, но ничему новому не учится. Мерить надо, как быстро система осваивает новое при данном запасе опыта и заготовок.
- **Morris и др., 2023.** Вместо одной черты уровни по двум осям: качество и широта задач. Спрашивают, что система умеет, а не как она устроена и «понимает» ли.

**Шаг 2. Посчитай вес руками.** Две среды: длина описания 2 бита и 8 бит. Веса `2^(−2) = 0,25` и `2^(−8) = 0,0039`. Простая среда важнее в 64 раза. Настоящую длину описания `K` вычислить вообще нельзя, это доказано, поэтому в опыте я задаю биты сам, и это моё упрощение.

**Шаг 3. Опыт.** Восемь игрушечных сред с автоматами. Три системы: *случайная*, *специалист*, который знает ответ в первой среде и больше ничего, это наш аналог шахматной программы, и *ученик*, ε-жадное правило из урока об автоматах. Создай файл `nano ~/ai-path/intelligence.py`, вставь и запусти.

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


def run_bandit(probs, policy, steps, rand):
    total = 0.0
    state = policy["new"](len(probs))
    for _ in range(steps):
        arm = policy["pick"](state, rand)
        reward = 1 if rand.next() < probs[arm] else 0
        policy["see"](state, arm, reward)
        total += reward
    return total / steps


def learner():
    def new(n):
        return {"values": [0.0] * n, "counts": [0] * n}

    def pick(state, rand):
        if rand.next() < 0.1:
            return rand.below(len(state["values"]))
        return state["values"].index(max(state["values"]))

    def see(state, arm, reward):
        state["counts"][arm] += 1
        state["values"][arm] += (reward - state["values"][arm]) / state["counts"][arm]
    return {"new": new, "pick": pick, "see": see}


def fixed(arm_of_task, task):
    def new(n):
        return {"n": n}

    def pick(state, rand):
        return arm_of_task if task == 0 else rand.below(state["n"])

    def see(state, arm, reward):
        pass
    return {"new": new, "pick": pick, "see": see}


def blind():
    def new(n):
        return {"n": n}

    def pick(state, rand):
        return rand.below(state["n"])

    def see(state, arm, reward):
        pass
    return {"new": new, "pick": pick, "see": see}


# Eight small worlds: the machines' win chances and the description length in bits.
WORLDS = [([0.9, 0.1], 2), ([0.1, 0.9], 2), ([0.8, 0.2, 0.2], 3), ([0.2, 0.8, 0.2], 3),
          ([0.2, 0.2, 0.2, 0.8], 4), ([0.3, 0.7, 0.3, 0.3, 0.3], 5), ([0.4, 0.4, 0.4, 0.4, 0.4, 0.6], 6), ([0.45, 0.55] * 4, 8)]


def score_table(steps, runs=30):
    rows = {"blind": [], "specialist": [], "learner": []}
    for w, (probs, bits) in enumerate(WORLDS):
        for name in rows:
            total = 0.0
            for run in range(runs):
                rand = Rand(100 * w + run + 1)
                policy = {"blind": blind(), "specialist": fixed(0, w), "learner": learner()}[name]
                total += run_bandit(probs, policy, steps, rand)
            rows[name].append(total / runs)
    return rows


rows = score_table(100)
print("mean reward over 100 steps by world")
for name, row in rows.items():
    print(name, [round(v, 2) for v in row])
```

```output
mean reward over 100 steps by world
blind [0.5, 0.5, 0.39, 0.43, 0.34, 0.37, 0.45, 0.5]
specialist [0.9, 0.5, 0.39, 0.43, 0.34, 0.37, 0.45, 0.5]
learner [0.85, 0.74, 0.76, 0.58, 0.55, 0.39, 0.44, 0.47]
```

В первой среде специалист набирает `0,9`, а ученику приходится ещё пробовать. Но дальше специалист не лучше случайного, а ученик заметно лучше.

**Шаг 4. Кто умнее?** Допиши и запусти.

```python
def legg_hutter(row):
    return sum(v * 2 ** -bits for v, (_, bits) in zip(row, WORLDS))


print("Legg and Hutter score: reward weighted by 2 to the minus description length")
for name, row in rows.items():
    print(name, round(legg_hutter(row), 3))
print("Only the first world")
for name, row in rows.items():
    print(name, round(row[0], 3))
```

```output
Legg and Hutter score: reward weighted by 2 to the minus description length
blind 0.394
specialist 0.493
learner 0.621
Only the first world
blind 0.504
specialist 0.901
learner 0.855
```

По Legg и Hutter побеждает ученик: `0,621` против `0,493`. Смотрим только первую среду, и побеждает специалист: `0,901` против `0,855`. **Числа те же, а победитель другой**, потому что другой вопрос. Заметь и то, что вес `2^(−K)` зависит от языка описания: другое описание дало бы другие веса. Это одно из главных возражений к этому определению.

**Шаг 5. Опыт решает.** Теперь в духе Chollet: как меняется результат с опытом? Допиши и запусти.

```python
print("steps of experience, learner's and specialist's plain mean over all worlds")
for steps in (5, 20, 100, 400):
    table = score_table(steps, runs=30)
    print(steps, round(sum(table["learner"]) / 8, 3), round(sum(table["specialist"]) / 8, 3))
```

```output
steps of experience, learner's and specialist's plain mean over all worlds
5 0.448 0.501
20 0.491 0.486
100 0.598 0.483
400 0.68 0.483
```

Специалисту опыт не нужен: `0,483`, сколько ни играй. Ученик при 5 шагах хуже него, а уже при 20 догоняет и при 400 уходит далеко: `0,68`. Именно этот рост и есть то, что Chollet называет интеллектом. Простой подсчёт: если учесть только качество в конце обучения, эту разницу не увидишь.

**Шаг 6. Три системы по трём определениям.** Заполни сам, а потом сравни с моим мнением. Оно не единственно верное.

| Система | Legg и Hutter | Chollet | Morris и др. |
|---|---|---|---|
| Шахматная программа | Узкий круг сред, поэтому низко | Сама не осваивает новое, поэтому низко | Очень высокое качество, очень узкая широта |
| Твоя маленькая модель | Низко | Учится, но только продолжать похожий текст | Низкое качество, узкая широта |
| `qwen3.5` | Заметно выше: много задач, в том числе незнакомых | Спорно: большая часть умений получена заранее | Широта заметная, качество сильно зависит от задачи |

**Что здесь спорно.** Есть ли вообще одна черта «интеллект»? Некоторые исследователи считают, что общего интеллекта нет, а есть набор умений. Близки ли мы к AGI, сильно зависит от определения, поэтому заявления «AGI уже достигнут» и «до него далеко» могут быть обе верны при разных определениях. Сначала спрашивай: что именно имеется в виду?

**Учись у тех, кто это создаёт.** Статья [On the Measure of Intelligence](https://arxiv.org/abs/1911.01547) написана понятно, начни с её первой части. Прочитай и [Universal Intelligence](https://arxiv.org/abs/0712.3329), и [Levels of AGI](https://arxiv.org/abs/2311.02462).

### Исследуй и потренируйся

В тренажёре настоящие прогоны этих трёх систем. Двигай опыт и вес простых сред, переключай подсчёт только по первой среде и смотри, кто выигрывает.

В программе придумай четвёртую систему. Какая система выиграла бы у всех при малом опыте?

### Вопрос

Почему в опыте победитель меняется, хотя результаты в средах те же?

### Варианты

- Определения задают разные веса средам и опыту, поэтому и лучшая система выходит разной.
- Случайность каждый раз даёт другие числа, поэтому и лучшая система всякий раз другая.
- Специалист обучается медленнее, поэтому на первой среде он всегда проигрывает ученику.

### Ответ

1

### Разбор

Зёрна случайности в опыте постоянны, а таблица результатов одна. Специалист вообще не обучается и на первой среде как раз выигрывает. Меняется только то, как мы сводим таблицу к одному числу, а значит, спорить надо о своде, а не об арифметике.

### Границы модели

Среды это простые автоматы, и никакой мерой интеллекта этот опыт не является. Биты описания я задал вручную. Настоящие длины описания невычислимы, а оценка Legg и Hutter теоретическая. Таблицу с оценками систем я заполнил по своему суждению, это мнение. Определений интеллекта намного больше трёх.

## English

### In plain words

AGI, artificial general intelligence, is a word with no single accepted definition. So the argument "is AGI already here" is often about nothing. The lesson gives three serious definitions: how many goals a system reaches across very different environments; how fast it learns something new; what level it reaches in quality and breadth of skills. It is like asking "who is the best athlete": the answer depends on whether you count medals in one sport, in many, or how fast a person learns a new sport. In the experiment you will see the winner change along with the definition.

**What to know first.** What an agent, an environment and a reward are: the lesson «Slot machines: explore or exploit» (step 13). Your own language model from «Your Own Language Model» (step 12): we rate it too.

**If something is unclear.** If the notation `2^(−K)` and description length in bits are unclear, go back to «Information, Entropy, and Cross-Entropy» (step 6). If reward is unclear, see step 1 of «Slot machines». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Examine three real definitions of intelligence, apply them to your own systems, and see in an experiment that the winner changes with the definition. Much here is disputed, so what was measured and whose opinion it is are shown separately. It takes about 40 minutes.

### Idea and mechanism

**Step 1. Why a definition.** The word AGI (artificial general intelligence) is often used without a definition, and the argument is then about nothing. We take three serious approaches.

- **Legg and Hutter, 2007.** Intelligence is the ability to achieve goals in a wide range of environments. It is computed as a sum of rewards over all environments, with simple ones weighing more: weight `2^(−K)`, where `K` is the environment's description length in bits.
- **Chollet, 2019.** What matters is not skill but the **speed of acquiring it**. A chess program can do much but learns nothing new. We should measure how fast a system masters new things given its stock of experience and built-in priors.
- **Morris et al., 2023.** Instead of one trait, levels along two axes: quality and breadth of tasks. They ask what a system can do, not how it is built or whether it "understands".

**Step 2. Compute a weight by hand.** Two environments: description length 2 bits and 8 bits. Weights `2^(−2) = 0.25` and `2^(−8) = 0.0039`. The simple one matters 64 times more. The true description length `K` cannot be computed at all, as has been proved, so in the experiment I set the bits myself, and that is my simplification.

**Step 3. The experiment.** Eight toy environments with slot machines. Three systems: *random*, a *specialist* that knows the answer in the first environment and nothing else, our analogue of a chess program, and a *learner*, the ε-greedy rule from the slot machine lesson. Create the file `nano ~/ai-path/intelligence.py`, paste and run it.

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


def run_bandit(probs, policy, steps, rand):
    total = 0.0
    state = policy["new"](len(probs))
    for _ in range(steps):
        arm = policy["pick"](state, rand)
        reward = 1 if rand.next() < probs[arm] else 0
        policy["see"](state, arm, reward)
        total += reward
    return total / steps


def learner():
    def new(n):
        return {"values": [0.0] * n, "counts": [0] * n}

    def pick(state, rand):
        if rand.next() < 0.1:
            return rand.below(len(state["values"]))
        return state["values"].index(max(state["values"]))

    def see(state, arm, reward):
        state["counts"][arm] += 1
        state["values"][arm] += (reward - state["values"][arm]) / state["counts"][arm]
    return {"new": new, "pick": pick, "see": see}


def fixed(arm_of_task, task):
    def new(n):
        return {"n": n}

    def pick(state, rand):
        return arm_of_task if task == 0 else rand.below(state["n"])

    def see(state, arm, reward):
        pass
    return {"new": new, "pick": pick, "see": see}


def blind():
    def new(n):
        return {"n": n}

    def pick(state, rand):
        return rand.below(state["n"])

    def see(state, arm, reward):
        pass
    return {"new": new, "pick": pick, "see": see}


# Eight small worlds: the machines' win chances and the description length in bits.
WORLDS = [([0.9, 0.1], 2), ([0.1, 0.9], 2), ([0.8, 0.2, 0.2], 3), ([0.2, 0.8, 0.2], 3),
          ([0.2, 0.2, 0.2, 0.8], 4), ([0.3, 0.7, 0.3, 0.3, 0.3], 5), ([0.4, 0.4, 0.4, 0.4, 0.4, 0.6], 6), ([0.45, 0.55] * 4, 8)]


def score_table(steps, runs=30):
    rows = {"blind": [], "specialist": [], "learner": []}
    for w, (probs, bits) in enumerate(WORLDS):
        for name in rows:
            total = 0.0
            for run in range(runs):
                rand = Rand(100 * w + run + 1)
                policy = {"blind": blind(), "specialist": fixed(0, w), "learner": learner()}[name]
                total += run_bandit(probs, policy, steps, rand)
            rows[name].append(total / runs)
    return rows


rows = score_table(100)
print("mean reward over 100 steps by world")
for name, row in rows.items():
    print(name, [round(v, 2) for v in row])
```

```output
mean reward over 100 steps by world
blind [0.5, 0.5, 0.39, 0.43, 0.34, 0.37, 0.45, 0.5]
specialist [0.9, 0.5, 0.39, 0.43, 0.34, 0.37, 0.45, 0.5]
learner [0.85, 0.74, 0.76, 0.58, 0.55, 0.39, 0.44, 0.47]
```

In the first environment the specialist earns `0.9`, while the learner must still try things. But further on the specialist is no better than random, and the learner is noticeably better.

**Step 4. Who is smarter?** Add this and run it.

```python
def legg_hutter(row):
    return sum(v * 2 ** -bits for v, (_, bits) in zip(row, WORLDS))


print("Legg and Hutter score: reward weighted by 2 to the minus description length")
for name, row in rows.items():
    print(name, round(legg_hutter(row), 3))
print("Only the first world")
for name, row in rows.items():
    print(name, round(row[0], 3))
```

```output
Legg and Hutter score: reward weighted by 2 to the minus description length
blind 0.394
specialist 0.493
learner 0.621
Only the first world
blind 0.504
specialist 0.901
learner 0.855
```

By Legg and Hutter the learner wins: `0.621` against `0.493`. Looking only at the first environment, the specialist wins: `0.901` against `0.855`. **The same numbers, a different winner**, because the question is different. Note also that the weight `2^(−K)` depends on the description language: another description would give other weights. That is one of the main objections to this definition.

**Step 5. Experience decides.** Now in Chollet's spirit: how does the result change with experience? Add this and run it.

```python
print("steps of experience, learner's and specialist's plain mean over all worlds")
for steps in (5, 20, 100, 400):
    table = score_table(steps, runs=30)
    print(steps, round(sum(table["learner"]) / 8, 3), round(sum(table["specialist"]) / 8, 3))
```

```output
steps of experience, learner's and specialist's plain mean over all worlds
5 0.448 0.501
20 0.491 0.486
100 0.598 0.483
400 0.68 0.483
```

The specialist needs no experience: `0.483`, however long it plays. With 5 steps the learner is worse, by 20 it catches up, and by 400 it is far ahead: `0.68`. This growth is what Chollet calls intelligence. A plain count of quality at the end of training would not show this difference.

**Step 6. Three systems by three definitions.** Fill it in yourself, then compare with my opinion. It is not the only right one.

| System | Legg and Hutter | Chollet | Morris et al. |
|---|---|---|---|
| A chess program | A narrow range of environments, so low | Masters nothing new by itself, so low | Very high quality, very narrow breadth |
| Your small model | Low | Learns, but only to continue similar text | Low quality, narrow breadth |
| `qwen3.5` | Noticeably higher: many tasks, including unfamiliar ones | Disputed: most skills were acquired in advance | Noticeable breadth, with quality strongly dependent on the task |

**What is disputed here.** Is there one trait called "intelligence" at all? Some researchers hold that no general intelligence exists, only a set of skills. How close we are to AGI depends heavily on the definition, so the claims "AGI is already here" and "it is far away" may both hold under different definitions. Ask first: what exactly is meant?

**Learn from the people who build this.** [On the Measure of Intelligence](https://arxiv.org/abs/1911.01547) is written clearly; start with its first part. Read too [Universal Intelligence](https://arxiv.org/abs/0712.3329) and [Levels of AGI](https://arxiv.org/abs/2311.02462).

### Explore and practise

The lab has real runs of these three systems. Move the experience and the weight of simple environments, switch to counting only the first environment, and see who wins.

In the program, invent a fourth system. Which system would beat all others at low experience?

### Question

Why does the winner change in the experiment, though the results per environment are the same?

### Options

- The definitions weigh environments and experience differently, so the best system differs.
- Randomness gives different numbers each time, so the best system differs every time too.
- The specialist learns more slowly, so in the first environment it always loses to the learner.

### Answer

1

### Explanation

The random seeds in the experiment are constant, and there is one table of results. The specialist does not learn at all, and in the first environment it actually wins. Only the way we reduce the table to one number changes, so the argument should be about that reduction, not about arithmetic.

### Limits

The environments are simple slot machines, and this experiment is no measure of intelligence. I set the description bits by hand. True description lengths are uncomputable, and the Legg and Hutter score is theoretical. I filled in the table of system ratings by my own judgement, which is an opinion. There are far more than three definitions of intelligence.

## Sources

- Shane Legg, Marcus Hutter, "Universal Intelligence: A Definition of Machine Intelligence", arXiv:0712.3329 (2007), the formula read 2026-11-03: [arXiv:0712.3329](https://arxiv.org/abs/0712.3329)
- François Chollet, "On the Measure of Intelligence", arXiv:1911.01547 (2019), title read 2026-11-03: [arXiv:1911.01547](https://arxiv.org/abs/1911.01547)
- Meredith Ringel Morris et al., "Levels of AGI for Operationalizing Progress on the Path to AGI", arXiv:2311.02462 (2023), title read 2026-11-03: [arXiv:2311.02462](https://arxiv.org/abs/2311.02462)
- The environments, program and numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
