---
subject: programming
lesson_id: programming.consciousness_global_workspace
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Глобальное рабочее пространство / The global workspace

## Русский

### Цель

Понять одну из главных научных теорий сознания: построить на Python маленькое рабочее пространство, увидеть вспышку «всё или ничего» и борьбу стимулов, а потом честно сказать, чего такая программа не доказывает. Нужно около 40 минут.

### Идея и механизм

**Шаг 1. Теория.** Бернард Баарс предложил образ театра. В мозге много специальных модулей работают параллельно и без отчёта. Но есть узкое общее место, **рабочее пространство**. То, что туда попало, рассылается всем модулям сразу: речи, памяти, планированию. Сознательно, по этой теории, то, что разослано. Дехане и коллеги описали нейронный механизм: при достаточном сигнале длинные связи лобной и теменной коры входят в самоподдерживающуюся активность. Это резкая **вспышка** (ignition).

**Шаг 2. Механизм руками.** Сигнал толкает пространство, а оно через обратную связь поддерживает само себя:

`W ← S(толчок + 1,68 · W)`, где `S` это сигмоида с порогом `0,8`, а `1,68` это произведение усиления и затухания: `2,4 · 0,7`.

Посчитаем для толчка `0,9` без шума. Вход `0,9`, сигмоида `S(0,9) = 1 / (1 + e^(−6 · 0,1)) = 0,65`. На втором шаге `0,9 + 1,68 · 0,65 = 1,99`, сигмоида почти `1`. Толчок кончился, а обратная связь уже даёт `1,68`, этого хватает, чтобы держаться. **Активность осталась после исчезновения стимула.** Слабый толчок `0,3`: `S(0,3) = 0,05`, обратная связь мала, и всё гаснет.

**Шаг 3. Опыт.** Создай файл `nano ~/ai-path/workspace.py`, вставь и запусти. Толчок идёт 2 шага из 12, есть шум.

```python
import math


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53

    def noise(self):
        return sum(self.next() for _ in range(12)) - 6


MODULES = ["зрение", "слух", "память", "речь", "движение"]
FEEDBACK, DECAY, GAIN, THRESHOLD = 2.4, 0.7, 6.0, 0.8


def squash(x):
    return 1 / (1 + math.exp(-GAIN * (x - THRESHOLD)))


def trial(strength, rand, steps=12, noise=0.08):
    workspace = 0.0
    trace = []
    for step in range(steps):
        pushed = strength if step < 2 else 0.0
        drive = pushed + FEEDBACK * workspace * DECAY + noise * rand.noise()
        workspace = squash(drive)
        trace.append(workspace)
    return trace


rand = Rand(3)
for strength in (0.3, 0.6, 0.9):
    print(strength, [round(v, 2) for v in trial(strength, rand)])
```

```output
0.3 [0.06, 0.14, 0.02, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01]
0.6 [0.5, 0.97, 0.99, 0.99, 1.0, 1.0, 1.0, 0.99, 0.99, 0.99, 1.0, 0.99]
0.9 [0.57, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.99, 0.99, 1.0, 1.0, 1.0]
```

При `0,3` всё гаснет. При `0,6` и `0,9` значение подскакивает и держится около `1,0` до конца. Промежуточного устойчивого состояния почти нет.

**Шаг 4. Всё или ничего.** Допиши и запусти: 200 проб на каждую силу.

```python
print("strength, share of trials with ignition out of 200, mean final workspace")
rand = Rand(4)
for strength in (0.2, 0.4, 0.5, 0.6, 0.7, 0.8, 1.0):
    finals = [trial(strength, rand)[-1] for _ in range(200)]
    print(strength, round(sum(f > 0.5 for f in finals) / 200, 2), round(sum(finals) / 200, 2))
```

```output
strength, share of trials with ignition out of 200, mean final workspace
0.2 0.0 0.01
0.4 0.04 0.04
0.5 0.45 0.45
0.6 0.93 0.92
0.7 1.0 0.99
0.8 1.0 0.99
1.0 1.0 0.99
```

Сила меняется плавно, а доля вспышек почти скачком: `0,04` при `0,4`, `0,45` при `0,5` и `0,93` при `0,6`. На пороге **один и тот же стимул** иногда вызывает вспышку, а иногда нет, и решает шум. Это похоже на опыты, где одинаковый стимул у порога человек то замечает, то нет. Дехане показывает в них поздний широкий всплеск активности при замеченном. Но заметь: мне хватило одной петли обратной связи, поэтому такая форма кривой ничего особенного сама по себе не доказывает.

**Шаг 5. Узкое место.** Два стимула сразу, и они подавляют друг друга. Допиши и запусти.

```python
def compete(first, second, rand, steps=12, noise=0.08, inhibition=2.0):
    a, b = 0.0, 0.0
    for step in range(steps):
        push_a = first if step < 2 else 0.0
        push_b = second if step < 2 else 0.0
        drive_a = push_a + FEEDBACK * a * DECAY - inhibition * b + noise * rand.noise()
        drive_b = push_b + FEEDBACK * b * DECAY - inhibition * a + noise * rand.noise()
        a, b = squash(drive_a), squash(drive_b)
    return a, b


rand = Rand(5)
print("two stimuli at once, who holds the workspace after 12 steps, out of 200")
for first, second in ((0.9, 0.9), (1.0, 0.8), (0.7, 0.7)):
    wins = [compete(first, second, rand) for _ in range(200)]
    print(first, second, "first", sum(a > 0.5 and b <= 0.5 for a, b in wins), "second", sum(b > 0.5 and a <= 0.5 for a, b in wins),
          "both", sum(a > 0.5 and b > 0.5 for a, b in wins), "none", sum(a <= 0.5 and b <= 0.5 for a, b in wins))
```

```output
two stimuli at once, who holds the workspace after 12 steps, out of 200
0.9 0.9 first 42 second 43 both 0 none 115
1.0 0.8 first 184 second 2 both 0 none 14
0.7 0.7 first 45 second 41 both 0 none 114
```

Оба одновременно не побеждают ни разу. При равной силе победитель случаен, часто оба гаснут, а более сильный обычно выигрывает. Это и есть узкое место: одно содержание за раз.

**Шаг 6. Чего это не доказывает.** Программа делает вспышку, рассылку и борьбу. Значит ли это, что ей что-то видно? Нет оснований так считать. Это функциональная схема из десятка строк. Защитники теории и сами не считают, что любая петля сознательна. Нужна настоящая архитектура с модулями, памятью и отчётом. Вопрос прямо из прошлого урока: даже полная архитектура объясняет доступ, но объясняет ли она переживание?

**Шаг 7. Что сейчас спорят.** Опыт Cogitate (Nature, 2025) проверял эту теорию вместе с теорией интегрированной информации, и ни одна не прошла полностью: у рабочего пространства, в частности, вспышка при исчезновении стимула была слабее предсказанной. Об этом будет урок об опытах.

И новое: в работе Gurnee и соавторов 2026 года в языковой модели нашли пространство представлений, которое поддерживает словесный отчёт и похоже по ролям на рабочее пространство. По их описанию, без него модель говорит и понимает, но хуже справляется со сложными внутренними рассуждениями. Это интересная **функциональная** находка. Заявлением о сознании она сама по себе не является, и об этом читай первоисточник.

**Учись у тех, кто это создаёт.** Обзор [Mashour и др.](https://www.cell.com/neuron/fulltext/S0896-6273(20)30052-3). Книга Дехане «Сознание и мозг». Опыт на языковой модели: [Verbalizable Representations Form a Global Workspace](https://transformer-circuits.pub/2026/workspace/index.html).

### Исследуй и потренируйся

В тренажёре настоящая модель из программы. Двигай силу стимула, смотри на кривую вспышки и запускай пробы. Найди порог, у которого один и тот же стимул то зажигает все модули, то нет.

В программе поменяй обратную связь: `FEEDBACK = 1.0`. Что станет с кривой? Подумай, что выходит без петли.

### Вопрос

Что показывает резкая вспышка в нашей программе?

### Варианты

- Что обратная связь даёт поведение «всё или ничего», а о переживании это ничего не говорит.
- Что программа стала сознательной, так как у неё есть рассылка всем и резкая вспышка.
- Что теория рабочего пространства доказана, так как модель повторяет её предсказание.

### Ответ

1

### Разбор

Мне хватило одной петли, поэтому форма кривой не доказывает теорию: её дают многие системы с обратной связью. И сознательной программу такое поведение не делает: она не умеет ни отчёта, ни рассуждения. Про механизм кривая говорит ясно, а про переживание молчит.

### Границы модели

Это не модель мозга: одно число вместо миллиардов нейронов, а модули в тренажёре только показывают значение. Числа подобраны мной, чтобы был виден порог. Сама теория широко обсуждается, и у неё есть сильные соперники. Работа 2026 года здесь пересказана только по её описанию, поэтому читай сам.

## English

### Goal

Understand one of the main scientific theories of consciousness: build a small workspace in Python, see an all-or-none flash and competition among stimuli, and then say honestly what such a program does not prove. It takes about 40 minutes.

### Idea and mechanism

**Step 1. The theory.** Bernard Baars proposed the image of a theatre. In the brain many specialized modules work in parallel without report. But there is a narrow common place, the **workspace**. What enters it is broadcast to all modules at once: speech, memory, planning. Conscious, by this theory, is what is broadcast. Dehaene and colleagues described a neural mechanism: with enough signal, long connections of the frontal and parietal cortex enter self-sustaining activity. This is a sharp **ignition**.

**Step 2. The mechanism by hand.** A signal pushes the workspace, and it sustains itself through feedback:

`W ← S(push + 1.68 · W)`, where `S` is a sigmoid with threshold `0.8`, and `1.68` is the product of gain and decay: `2.4 · 0.7`.

Compute for a push of `0.9` with no noise. Input `0.9`, sigmoid `S(0.9) = 1 / (1 + e^(−6 · 0.1)) = 0.65`. On the second step `0.9 + 1.68 · 0.65 = 1.99`, a sigmoid near `1`. The push ends, but feedback already gives `1.68`, enough to hold on. **Activity remains after the stimulus is gone.** A weak push of `0.3`: `S(0.3) = 0.05`, feedback is small, and all fades.

**Step 3. The experiment.** Create the file `nano ~/ai-path/workspace.py`, paste and run it. The push lasts 2 steps of 12, with noise.

```python
import math


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53

    def noise(self):
        return sum(self.next() for _ in range(12)) - 6


MODULES = ["зрение", "слух", "память", "речь", "движение"]
FEEDBACK, DECAY, GAIN, THRESHOLD = 2.4, 0.7, 6.0, 0.8


def squash(x):
    return 1 / (1 + math.exp(-GAIN * (x - THRESHOLD)))


def trial(strength, rand, steps=12, noise=0.08):
    workspace = 0.0
    trace = []
    for step in range(steps):
        pushed = strength if step < 2 else 0.0
        drive = pushed + FEEDBACK * workspace * DECAY + noise * rand.noise()
        workspace = squash(drive)
        trace.append(workspace)
    return trace


rand = Rand(3)
for strength in (0.3, 0.6, 0.9):
    print(strength, [round(v, 2) for v in trial(strength, rand)])
```

```output
0.3 [0.06, 0.14, 0.02, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01, 0.01]
0.6 [0.5, 0.97, 0.99, 0.99, 1.0, 1.0, 1.0, 0.99, 0.99, 0.99, 1.0, 0.99]
0.9 [0.57, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 0.99, 0.99, 1.0, 1.0, 1.0]
```

At `0.3` all fades. At `0.6` and `0.9` the value jumps and stays near `1.0` to the end. There is almost no stable state in between.

**Step 4. All or none.** Add this and run it: 200 trials at each strength.

```python
print("strength, share of trials with ignition out of 200, mean final workspace")
rand = Rand(4)
for strength in (0.2, 0.4, 0.5, 0.6, 0.7, 0.8, 1.0):
    finals = [trial(strength, rand)[-1] for _ in range(200)]
    print(strength, round(sum(f > 0.5 for f in finals) / 200, 2), round(sum(finals) / 200, 2))
```

```output
strength, share of trials with ignition out of 200, mean final workspace
0.2 0.0 0.01
0.4 0.04 0.04
0.5 0.45 0.45
0.6 0.93 0.92
0.7 1.0 0.99
0.8 1.0 0.99
1.0 1.0 0.99
```

Strength changes smoothly, but the share of flashes almost jumps: `0.04` at `0.4`, `0.45` at `0.5` and `0.93` at `0.6`. At the threshold **the same stimulus** sometimes ignites and sometimes does not, and noise decides. This resembles experiments where a person now notices and now misses an identical stimulus near threshold. Dehaene shows in them a late, wide burst of activity when it is noticed. But note: one feedback loop was enough for me, so this curve's shape alone proves nothing special.

**Step 5. The bottleneck.** Two stimuli at once, suppressing each other. Add this and run it.

```python
def compete(first, second, rand, steps=12, noise=0.08, inhibition=2.0):
    a, b = 0.0, 0.0
    for step in range(steps):
        push_a = first if step < 2 else 0.0
        push_b = second if step < 2 else 0.0
        drive_a = push_a + FEEDBACK * a * DECAY - inhibition * b + noise * rand.noise()
        drive_b = push_b + FEEDBACK * b * DECAY - inhibition * a + noise * rand.noise()
        a, b = squash(drive_a), squash(drive_b)
    return a, b


rand = Rand(5)
print("two stimuli at once, who holds the workspace after 12 steps, out of 200")
for first, second in ((0.9, 0.9), (1.0, 0.8), (0.7, 0.7)):
    wins = [compete(first, second, rand) for _ in range(200)]
    print(first, second, "first", sum(a > 0.5 and b <= 0.5 for a, b in wins), "second", sum(b > 0.5 and a <= 0.5 for a, b in wins),
          "both", sum(a > 0.5 and b > 0.5 for a, b in wins), "none", sum(a <= 0.5 and b <= 0.5 for a, b in wins))
```

```output
two stimuli at once, who holds the workspace after 12 steps, out of 200
0.9 0.9 first 42 second 43 both 0 none 115
1.0 0.8 first 184 second 2 both 0 none 14
0.7 0.7 first 45 second 41 both 0 none 114
```

Both never win together. At equal strength the winner is random, both often fade, and the stronger one usually wins. This is the bottleneck: one content at a time.

**Step 6. What this does not prove.** The program makes a flash, a broadcast and competition. Does that mean anything is seen by it? There is no ground to think so. It is a functional scheme of ten lines. The theory's defenders themselves do not hold that any loop is conscious. It takes a real architecture with modules, memory and report. The question comes right from the last lesson: even a full architecture explains access, but does it explain experience?

**Step 7. What is argued now.** The Cogitate experiment (Nature, 2025) tested this theory along with integrated information theory, and neither fully passed: for the workspace, in particular, the ignition at the stimulus's disappearance was weaker than predicted. A lesson on experiments covers this.

And something new: Gurnee and co-authors in 2026 found in a language model a space of representations that supports verbal report and resembles a workspace in its roles. By their account, without it the model speaks and understands but handles complex inner reasoning worse. This is an interesting **functional** finding. It is not itself a claim of consciousness; read the primary source on this.

**Learn from the people who build this.** The survey by [Mashour et al.](https://www.cell.com/neuron/fulltext/S0896-6273(20)30052-3). Dehaene's book "Consciousness and the Brain". The experiment on a language model: [Verbalizable Representations Form a Global Workspace](https://transformer-circuits.pub/2026/workspace/index.html).

### Explore and practise

The lab has the program's real model. Move the stimulus strength, look at the ignition curve and run trials. Find the threshold at which the same stimulus now lights all modules and now does not.

In the program, change the feedback: `FEEDBACK = 1.0`. What happens to the curve? Think about what you get without the loop.

### Question

What does the sharp flash in our program show?

### Options

- That feedback gives all-or-none behaviour, and that says nothing about experience.
- That the program has become conscious, as it has a broadcast and a sharp flash.
- That workspace theory is proved, as the model repeats the theory's prediction.

### Answer

1

### Explanation

One loop was enough for me, so the curve's shape does not prove the theory: many systems with feedback give it. Nor does such behaviour make the program conscious: it can neither report nor reason. About the mechanism the curve says plenty; about experience it is silent.

### Limits

This is no model of the brain: one number instead of billions of neurons, and the modules in the lab only show the value. I chose the numbers to make a threshold visible. The theory itself is widely debated and has strong rivals. The 2026 work is retold here only by its own description, so read it yourself.

## Sources

- Bernard J. Baars, "A Cognitive Theory of Consciousness", Cambridge University Press (1988), details checked 2026-11-03 in the Stanford Encyclopedia bibliography; the book itself not re-read.
- Stanislas Dehaene, Jean-Pierre Changeux, "Experimental and Theoretical Approaches to Conscious Processing", Neuron 70 (2011), abstract read 2026-11-03.
- George A. Mashour et al., "Conscious Processing and the Global Neuronal Workspace Hypothesis", Neuron 105 (2020), title and journal checked 2026-11-03; the paper itself not re-read: [article](https://www.cell.com/neuron/fulltext/S0896-6273(20)30052-3)
- Cogitate Consortium, "Adversarial testing of global neuronal workspace and integrated information theories of consciousness", Nature (2025), title read 2026-11-03: [article](https://www.nature.com/articles/s41586-025-08888-1)
- Wes Gurnee et al., "Verbalizable Representations Form a Global Workspace in Language Models", Transformer Circuits (2026), title and parts read 2026-11-03: [paper](https://transformer-circuits.pub/2026/workspace/index.html)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
