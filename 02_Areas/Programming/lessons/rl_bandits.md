---
subject: programming
lesson_id: programming.rl_bandits
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Автоматы: пробовать новое или брать лучшее / Slot machines: explore or exploit

## Русский

### Цель

Понять главный спор обучения с подкреплением: пользоваться тем, что уже знаешь, или пробовать новое. Посчитать оценку и сожаление руками, увидеть в настоящем опыте, как жадность запирает агента на плохом выборе, и сравнить три правила. Нужно около 40 минут.

### Идея и механизм

**Шаг 1. Что здесь нового.** До сих пор у модели был учитель: для каждого примера известен верный ответ. Теперь учителя нет. **Агент**, то есть программа, которая действует, выбирает **действие**, получает **награду**, то есть просто число, и сам решает, что делать дальше. Это и есть обучение с подкреплением.

Самая простая такая задача: пять игровых автоматов. Каждый выигрывает со своей вероятностью `0,2`, `0,35`, `0,5`, `0,65` и `0,8`, но агент этих чисел не знает. Он знает только то, что выпало. Задача называется «многорукий бандит»: так в шутку зовут автомат с рычагом.

**Шаг 2. Оценка руками.** Оценка автомата это среднее его наград. Пусть выпало `1`, `0`, `1`. Среднее равно 2/3. Хранить все награды не нужно, хватит одного числа и правила «сдвинься к новому на долю»:

`Q ← Q + (награда − Q) / n`, где `n` это номер попытки.

- `n = 1`: `0 + (1 − 0) / 1 = 1`
- `n = 2`: `1 + (0 − 1) / 2 = 0,5`
- `n = 3`: `0,5 + (1 − 0,5) / 3 = 0,667`

Запомни эту форму: новая оценка равна старой плюс шаг к новому. Она будет в каждом следующем уроке об обучении с подкреплением.

**Шаг 3. Сожаление.** Сами награды шумят, поэтому качество меряют **сожалением**: сколько агент потерял в среднем по сравнению с лучшим автоматом. За один ход на автомате `0,35` сожаление равно `0,8 − 0,35 = 0,45`. Игрок, который тянет наугад, теряет в среднем `(0,6 + 0,45 + 0,3 + 0,15 + 0) / 5 = 0,3` за ход, то есть 900 за 3000 ходов. Это точка отсчёта.

**Шаг 4. Жадность ломается.** Жадное правило всегда тянет автомат с самой высокой оценкой. При равных оценках выбирает случайно. Создай файл `nano ~/ai-path/bandit.py`, вставь программу и запусти. В строке номер автомата (от 0), награда, новая оценка и накопленное сожаление.

```python
import math

PROBS = [0.2, 0.35, 0.5, 0.65, 0.8]
BEST = max(PROBS)


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


def epsilon_rule(epsilon):
    def choose(values, counts, step, rand):
        if rand.next() < epsilon:
            return int(rand.next() * len(values))
        top = max(values)
        ties = [arm for arm, value in enumerate(values) if value == top]
        return ties[int(rand.next() * len(ties))]
    return choose


def ucb_rule(values, counts, step, rand):
    for arm, count in enumerate(counts):
        if count == 0:
            return arm
    scores = [value + math.sqrt(2 * math.log(step) / count) for value, count in zip(values, counts)]
    return scores.index(max(scores))


def play(choose, steps, seed):
    rand = Rand(seed)
    values, counts = [0.0] * len(PROBS), [0] * len(PROBS)
    regret = 0.0
    history = []
    for step in range(1, steps + 1):
        arm = choose(values, counts, step, rand)
        reward = 1 if rand.next() < PROBS[arm] else 0
        counts[arm] += 1
        values[arm] += (reward - values[arm]) / counts[arm]
        regret += BEST - PROBS[arm]
        history.append((arm, reward, round(values[arm], 3), round(regret, 2)))
    return history, counts


history, counts = play(epsilon_rule(0.0), 8, seed=7)
for row in history:
    print(row)
print("counts", counts)
```

```output
(4, 0, 0.0, 0.0)
(1, 1, 1.0, 0.45)
(1, 0, 0.5, 0.9)
(1, 0, 0.333, 1.35)
(1, 1, 0.5, 1.8)
(1, 1, 0.6, 2.25)
(1, 0, 0.5, 2.7)
(1, 1, 0.571, 3.15)
counts [0, 7, 0, 0, 1]
```

Посмотри на первые две строки. Первым выпал лучший автомат с номером 4, но он дал 0, и его оценка стала 0. Затем автомат 1 дал 1, его оценка стала 1,0. Теперь его оценка всегда больше нуля, и жадное правило **никогда не вернётся к лучшему автомату**. Одна неудача закрыла его навсегда, и исправить это нечем: чтобы исправить оценку, нужно попробовать снова.

**Шаг 5. Два лекарства.**

*ε-жадное правило*: с малой вероятностью ε тянем случайный автомат, в остальное время лучший по оценке. Цена известна заранее: при ε = 0,1 случайный выбор теряет `0,1 · 0,3 = 0,03` за ход всегда, даже когда всё уже понятно.

*UCB1*: к оценке добавляем надбавку за незнание, `√(2 · ln t / n)`, где `t` это номер хода, а `n` сколько раз тянули этот автомат. Посчитаем при `t = 100`: для `n = 4` надбавка `√(2 · 4,605 / 4) = 1,52`, а для `n = 50` она `√(9,21 / 50) = 0,43`. Автомат, который пробовали редко, получает большой бонус. Его попробуют, и бонус упадёт сам. Случайности в выборе нет совсем. Идея называется «оптимизм перед неизвестным».

Допиши в файл и запусти. Нужно около трёх секунд.

```python
RULES = [("greedy", epsilon_rule(0.0)), ("eps 0.01", epsilon_rule(0.01)), ("eps 0.1", epsilon_rule(0.1)),
         ("eps 0.5", epsilon_rule(0.5)), ("UCB1", ucb_rule)]
RUNS, CHECKS = 100, (100, 1000, 3000)

print("rule      regret@100 regret@1000 regret@3000 best-arm share")
for name, rule in RULES:
    totals = [0.0] * len(CHECKS)
    best = 0
    for seed in range(RUNS):
        history, counts = play(rule, CHECKS[-1], seed=1000 + seed)
        for i, check in enumerate(CHECKS):
            totals[i] += history[check - 1][3]
        best += counts[4] / CHECKS[-1]
    means = [round(total / RUNS, 1) for total in totals]
    print(name, *means, round(best / RUNS, 2))
```

```output
rule      regret@100 regret@1000 regret@3000 best-arm share
greedy 21.2 210.2 630.2 0.32
eps 0.01 20.2 109.5 184.3 0.7
eps 0.1 13.4 52.4 112.2 0.88
eps 0.5 18.6 156.0 455.5 0.59
UCB1 18.7 80.6 126.1 0.83
```

Сверим с расчётом. Жадное правило теряет 630: это почти как наугад, лучший автомат оно находит только в 32 % хода. При ε = 0,5 половина ходов случайна, расчёт даёт `0,15 · 3000 = 450`, опыт 455,5. При ε = 0,1 прибавка от 1000 до 3000 ходов равна `112,2 − 52,4 = 59,8`, а расчёт `0,03 · 2000 = 60`. Формула работает.

UCB1 за те же ходы прибавил только `126,1 − 80,6 = 45,5`. Здесь ε = 0,1 пока впереди по сумме, но у UCB1 сожаление растёт медленнее: Ауэр и соавторы доказали, что оно растёт как логарифм числа ходов, а у постоянного ε рост прямой. Поэтому при длинной игре UCB1 обгонит. Какое правило лучше, зависит от длины игры, и единственного победителя нет.

**Учись у тех, кто это создаёт.** Глава 2 книги [Sutton и Barto](http://incompleteideas.net/book/the-book-2nd.html), она бесплатна. Лекция 9 курса [David Silver](https://www.davidsilver.uk/teaching/) разбирает исследование подробно. Курс [Stanford CS234](https://web.stanford.edu/class/cs234/) идёт дальше, в строгую теорию.

### Исследуй и потренируйся

В тренажёре сначала сыграй сам: пять автоматов, вероятности спрятаны и перемешаны. Заметь, как тянет остаться на том, что уже дало выигрыш. Потом двигай ε и смотри на настоящие кривые сожаления за 3000 ходов.

В программе поменяй вероятности на `0,78`, `0,79`, `0,8`, `0,81`, `0,82`. Сожаление станет меньше, а доля лучшего автомата? Подумай, почему.

### Вопрос

Почему жадное правило может навсегда застрять на плохом автомате?

### Варианты

- Оно не пробует другие автоматы, и ошибочно низкая оценка лучшего не исправляется.
- Оно считает среднее неверно, и оценка плохого автомата со временем только растёт.
- Оно тратит половину ходов на случайные автоматы, и сведений о лучшем не хватает.

### Ответ

1

### Разбор

Среднее считается верно, а случайных ходов у жадного правила нет. Беда в том, что оценка меняется только у того автомата, который тянут. Если лучший автомат один раз не выиграл и его оценка упала, правило больше его не тронет, и ошибка останется навсегда.

### Границы модели

Вероятности здесь постоянны, а в жизни они меняются, и тогда простое среднее устаревает. Награда только 0 или 1. У автомата нет состояния: прошлый ход не меняет следующий, и как раз это изменится в следующем уроке. Средние взяты по 100 запускам и немного плавают. Значения ε я выбрал для наглядности, это не настройка, найденная поиском.

## English

### Goal

Understand the central tension of reinforcement learning: use what you already know, or try something new. Compute an estimate and regret by hand, see in a real experiment how greed locks the agent into a bad choice, and compare three rules. It takes about 40 minutes.

### Idea and mechanism

**Step 1. What is new here.** Until now a model had a teacher: the right answer was known for each example. Now there is no teacher. An **agent**, a program that acts, picks an **action**, receives a **reward**, which is simply a number, and decides for itself what to do next. That is reinforcement learning.

The simplest such task: five slot machines. Each wins with its own probability, `0.2`, `0.35`, `0.5`, `0.65` and `0.8`, but the agent does not know these numbers. It knows only what came up. The task is called a "multi-armed bandit": a joking name for a slot machine with a lever.

**Step 2. An estimate by hand.** A machine's estimate is the mean of its rewards. Suppose `1`, `0`, `1` came up. The mean is 2/3. You need not store all rewards: one number and the rule "move towards the new value by a share" are enough:

`Q ← Q + (reward − Q) / n`, where `n` is the attempt number.

- `n = 1`: `0 + (1 − 0) / 1 = 1`
- `n = 2`: `1 + (0 − 1) / 2 = 0.5`
- `n = 3`: `0.5 + (1 − 0.5) / 3 = 0.667`

Remember this form: the new estimate equals the old one plus a step towards the new value. It appears in every later lesson on reinforcement learning.

**Step 3. Regret.** Rewards themselves are noisy, so quality is measured by **regret**: how much the agent lost on average compared with the best machine. One turn on the `0.35` machine has regret `0.8 − 0.35 = 0.45`. A player pulling at random loses on average `(0.6 + 0.45 + 0.3 + 0.15 + 0) / 5 = 0.3` per turn, which is 900 over 3000 turns. That is our reference point.

**Step 4. Greed breaks.** The greedy rule always pulls the machine with the highest estimate, choosing at random among ties. Create the file `nano ~/ai-path/bandit.py`, paste the program and run it. Each row shows the machine number (from 0), the reward, the new estimate and the accumulated regret.

```python
import math

PROBS = [0.2, 0.35, 0.5, 0.65, 0.8]
BEST = max(PROBS)


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


def epsilon_rule(epsilon):
    def choose(values, counts, step, rand):
        if rand.next() < epsilon:
            return int(rand.next() * len(values))
        top = max(values)
        ties = [arm for arm, value in enumerate(values) if value == top]
        return ties[int(rand.next() * len(ties))]
    return choose


def ucb_rule(values, counts, step, rand):
    for arm, count in enumerate(counts):
        if count == 0:
            return arm
    scores = [value + math.sqrt(2 * math.log(step) / count) for value, count in zip(values, counts)]
    return scores.index(max(scores))


def play(choose, steps, seed):
    rand = Rand(seed)
    values, counts = [0.0] * len(PROBS), [0] * len(PROBS)
    regret = 0.0
    history = []
    for step in range(1, steps + 1):
        arm = choose(values, counts, step, rand)
        reward = 1 if rand.next() < PROBS[arm] else 0
        counts[arm] += 1
        values[arm] += (reward - values[arm]) / counts[arm]
        regret += BEST - PROBS[arm]
        history.append((arm, reward, round(values[arm], 3), round(regret, 2)))
    return history, counts


history, counts = play(epsilon_rule(0.0), 8, seed=7)
for row in history:
    print(row)
print("counts", counts)
```

```output
(4, 0, 0.0, 0.0)
(1, 1, 1.0, 0.45)
(1, 0, 0.5, 0.9)
(1, 0, 0.333, 1.35)
(1, 1, 0.5, 1.8)
(1, 1, 0.6, 2.25)
(1, 0, 0.5, 2.7)
(1, 1, 0.571, 3.15)
counts [0, 7, 0, 0, 1]
```

Look at the first two rows. The best machine, number 4, came up first but gave 0, so its estimate became 0. Then machine 1 gave 1, and its estimate became 1.0. Its estimate now stays above zero, and the greedy rule **will never return to the best machine**. One failure closed it for good, and nothing can repair that: to repair an estimate you must try again.

**Step 5. Two remedies.**

*The ε-greedy rule*: with a small probability ε pull a random machine, otherwise the best by estimate. The price is known in advance: at ε = 0.1 random choice always loses `0.1 · 0.3 = 0.03` per turn, even when everything is already clear.

*UCB1*: add a bonus for not knowing to the estimate, `√(2 · ln t / n)`, where `t` is the turn number and `n` is how many times this machine was pulled. Compute it at `t = 100`: for `n = 4` the bonus is `√(2 · 4.605 / 4) = 1.52`, and for `n = 50` it is `√(9.21 / 50) = 0.43`. A rarely tried machine gets a large bonus. It gets tried, and the bonus falls by itself. The choice has no randomness at all. The idea is called "optimism in the face of uncertainty".

Add this to the file and run it. It takes about three seconds.

```python
RULES = [("greedy", epsilon_rule(0.0)), ("eps 0.01", epsilon_rule(0.01)), ("eps 0.1", epsilon_rule(0.1)),
         ("eps 0.5", epsilon_rule(0.5)), ("UCB1", ucb_rule)]
RUNS, CHECKS = 100, (100, 1000, 3000)

print("rule      regret@100 regret@1000 regret@3000 best-arm share")
for name, rule in RULES:
    totals = [0.0] * len(CHECKS)
    best = 0
    for seed in range(RUNS):
        history, counts = play(rule, CHECKS[-1], seed=1000 + seed)
        for i, check in enumerate(CHECKS):
            totals[i] += history[check - 1][3]
        best += counts[4] / CHECKS[-1]
    means = [round(total / RUNS, 1) for total in totals]
    print(name, *means, round(best / RUNS, 2))
```

```output
rule      regret@100 regret@1000 regret@3000 best-arm share
greedy 21.2 210.2 630.2 0.32
eps 0.01 20.2 109.5 184.3 0.7
eps 0.1 13.4 52.4 112.2 0.88
eps 0.5 18.6 156.0 455.5 0.59
UCB1 18.7 80.6 126.1 0.83
```

Compare with the calculation. The greedy rule loses 630: nearly as bad as guessing, and it plays the best machine only 32 % of the time. At ε = 0.5 half of the turns are random, the calculation gives `0.15 · 3000 = 450`, the experiment 455.5. At ε = 0.1 the increase from 1000 to 3000 turns is `112.2 − 52.4 = 59.8`, and the calculation gives `0.03 · 2000 = 60`. The formula works.

Over the same turns UCB1 added only `126.1 − 80.6 = 45.5`. Here ε = 0.1 is still ahead in total, but UCB1's regret grows more slowly: Auer and co-authors proved that it grows as the logarithm of the number of turns, while a constant ε grows in a straight line. So in a long game UCB1 overtakes. Which rule is better depends on the length of the game, and there is no single winner.

**Learn from the people who build this.** Chapter 2 of [Sutton and Barto](http://incompleteideas.net/book/the-book-2nd.html), which is free. Lecture 9 of [David Silver's course](https://www.davidsilver.uk/teaching/) covers exploration in depth. [Stanford CS234](https://web.stanford.edu/class/cs234/) goes further, into rigorous theory.

### Explore and practise

In the lab, play first yourself: five machines, with hidden and shuffled probabilities. Notice the urge to stay with what has already paid. Then move ε and watch the real regret curves over 3000 turns.

In the program, change the probabilities to `0.78`, `0.79`, `0.8`, `0.81`, `0.82`. Regret will fall, but what about the share of the best machine? Think about why.

### Question

Why can the greedy rule get stuck on a bad machine for good?

### Options

- It never tries the other machines, so a wrongly low estimate of the best stays uncorrected.
- It computes the mean incorrectly, so the estimate of a bad machine only grows over time.
- It spends half of its turns on random machines, so it lacks information about the best.

### Answer

1

### Explanation

The mean is computed correctly, and the greedy rule has no random turns. The trouble is that an estimate changes only for the machine being pulled. If the best machine failed once and its estimate fell, the rule never touches it again, and the error stays for good.

### Limits

The probabilities here are constant, while in real life they change, and then a plain mean goes stale. The reward is only 0 or 1. A machine has no state: the previous turn does not change the next one, and that is exactly what changes in the next lesson. Means are over 100 runs and drift a little. I chose the ε values for clarity, not by a search for the best setting.

## Sources

- Richard S. Sutton, Andrew G. Barto, "Reinforcement Learning: An Introduction", 2nd ed., MIT Press (2018), chapter 2, recalled from the book; the site answered with an error on the check of 2026-11-03, and the rules and numbers here are recomputed by the program: [book page](http://incompleteideas.net/book/the-book-2nd.html)
- Peter Auer, Nicolò Cesa-Bianchi, Paul Fischer, "Finite-time Analysis of the Multiarmed Bandit Problem", Machine Learning 47 (2002), title read 2026-11-03; the UCB1 formula and the logarithmic bound are recalled from the paper: [Springer](https://link.springer.com/article/10.1023/A:1013689704352)
- David Silver, "Lectures on Reinforcement Learning", lecture 9 (the site refused the automated check on 2026-11-03): [course page](https://www.davidsilver.uk/teaching/)
- Stanford CS234, "Reinforcement Learning": [course page](https://web.stanford.edu/class/cs234/)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
