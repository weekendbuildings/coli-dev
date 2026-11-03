---
subject: programming
lesson_id: programming.rl_policy_gradient
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Градиент политики: REINFORCE / The policy gradient: REINFORCE

## Русский

### Цель

Научиться менять саму политику, а не таблицу ценностей. Посчитать шаг REINFORCE руками, написать его на чистом Python, увидеть, зачем нужна базовая линия и как большой шаг ломает обучение. Этот метод лежит под RLHF, следующими уроками. Нужно около 50 минут.

### Идея и механизм

**Шаг 1. Зачем другой метод.** Q-обучение учит ценности, а действие выбирает по `max`. У этого два слабых места. Действий может быть очень много: у языковой модели следующий токен выбирается из десятков тысяч. И лучшая политика бывает случайной, а `max` выбирает одно и то же. Поэтому учим прямо политику: числа `θ`, которые через softmax дают вероятности действий. Языковая модель как раз такая и есть: её выход это вероятности следующего токена.

Идея в одной фразе: **что принесло много, делай чаще; что принесло мало, делай реже.**

**Шаг 2. Шаг руками.** Два действия, «вправо» и «влево», `θ = (0; 0)`. Softmax даёт вероятности `0,5` и `0,5`. Агент пошёл вправо и получил **отдачу** `G = +2`, то есть сумму наград до конца игры. Шаг `α = 0,1`.

Правило REINFORCE: `θ ← θ + α · G · ∇ ln π(a)`. Для softmax производная логарифма вероятности проста: для выбранного действия `1 − p`, а для другого `−(1 − p)`, где `p` это вероятность выбранного.

- `∇ ln π = (0,5; −0,5)`
- `θ = (0 + 0,1 · 2 · 0,5; 0 − 0,1 · 2 · 0,5) = (0,1; −0,1)`
- новая вероятность «вправо»: `e^0,1 / (e^0,1 + e^−0,1) = 0,55`

Выросла. Если бы `G = −2`, вероятность упала бы до `0,45`. Это весь метод. Логарифм нужен потому, что `∇ ln π = ∇π / π`: деление на вероятность убирает нечестное преимущество действий, которые просто чаще выбираются. Теорема о градиенте политики говорит, что в среднем такой шаг идёт вверх по ожидаемой отдаче. Каждый шаг шумный, а среднее верное.

**Шаг 3. Мир, где таблица не поможет.** Возьмём коридор из книги Саттона и Барто, пример 13.1. Три клетки и выход. Каждый шаг стоит `−1`. В клетках 1 и 3 кнопка «вправо» ведёт вправо, а в клетке 2 кнопки **перепутаны**. И агент не видит, в какой он клетке: у него одно число, вероятность нажать «вправо» `p`.

Если всегда жать «вправо» (`p = 1`), агент ходит между клетками 1 и 2 вечно. Если всегда «влево» (`p = 0`), он застрянет в клетке 1. Значит, **лучшая политика случайна**, и `max` её не найдёт. Уравнения Беллмана для трёх клеток решаются на бумаге: `V₁ = −2(2 − p) / (p(1 − p))`. Лучшее `p = 2 − √2 ≈ 0,586`. Создай файл `nano ~/ai-path/corridor.py` и запусти.

```python
import math


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


def step(state, right):
    if state == 1:
        return (2 if right else 1), -1.0, False
    if state == 2:
        return (1 if right else 3), -1.0, False
    if right:
        return 4, -1.0, True
    return 2, -1.0, False


def exact_value(p):
    return -2 * (2 - p) / (p * (1 - p))


for p in (0.1, 0.3, 0.5, 0.55, 0.59, 0.6, 0.7, 0.9):
    print(p, round(exact_value(p), 2))
print("best p", round(2 - math.sqrt(2), 4), round(exact_value(2 - math.sqrt(2)), 3))
```

```output
0.1 -42.22
0.3 -16.19
0.5 -12.0
0.55 -11.72
0.59 -11.66
0.6 -11.67
0.7 -12.38
0.9 -24.44
best p 0.5858 -11.657
```

Лучшее значение `−11,66`: в среднем почти 12 шагов. Проверим формулу игрой: 5000 партий на настоящем коридоре. Допиши и запусти.

```python
def play(p, rand, limit=500):
    state, done, tape = 1, False, []
    while not done and len(tape) < limit:
        right = rand.next() < p
        state, reward, done = step(state, right)
        tape.append((right, reward))
    return tape


rand = Rand(5)
for p in (0.1, 0.59, 0.9):
    runs = [play(p, rand) for _ in range(5000)]
    print(p, round(sum(sum(r for _, r in tape) for tape in runs) / 5000, 2))
```

```output
0.1 -42.87
0.59 -11.83
0.9 -24.55
```

Сходится с формулой с точностью до шума партий, чуть меньше единицы.

**Шаг 4. REINFORCE.** Начинаем с плохой политики, `p = 0,1`. Играем партию до конца, идём по ней с конца, складываем отдачу и сдвигаем `θ` на каждом шаге. Базовая линия `w` это средняя отдача, которую мы тоже учим: вместо `G` берём `G − w`. Важен не сам результат, а насколько он лучше обычного. Допиши и запусти. Строки: средняя отдача по сотням партий, итоговое `p`, наименьшее и наибольшее по 20 запускам.

```python
def right_probability(theta):
    return 1 / (1 + math.exp(max(-30.0, min(30.0, theta[1] - theta[0]))))


def reinforce(episodes, rate, baseline_rate, seed):
    rand = Rand(seed)
    theta = [0.0, math.log(9.0)]
    w = 0.0
    curve = []
    for _ in range(episodes):
        p = right_probability(theta)
        tape = play(p, rand)
        curve.append((sum(r for _, r in tape), p))
        future = 0.0
        for right, reward in reversed(tape):
            future += reward
            p = right_probability(theta)
            advantage = future - w if baseline_rate else future
            if baseline_rate:
                w += baseline_rate * advantage
            grad = (1 - p, -(1 - p)) if right else (-p, p)
            theta[0] += rate * advantage * grad[0]
            theta[1] += rate * advantage * grad[1]
    return curve


RUNS = 20
for name, rate, baseline in (("plain 2^-13", 2**-13, 0.0), ("plain 2^-12", 2**-12, 0.0), ("baseline 2^-10", 2**-10, 2**-6)):
    finals, returns = [], [0.0] * 6
    for seed in range(RUNS):
        curve = reinforce(600, rate, baseline, 3000 + seed)
        finals.append(curve[-1][1])
        for i in range(6):
            part = curve[i * 100:i * 100 + 100]
            returns[i] += sum(g for g, _ in part) / 100
    print(name, [round(v / RUNS, 1) for v in returns], "p", round(sum(finals) / RUNS, 3), "min", round(min(finals), 3), "max", round(max(finals), 3))
print("plain 2^-9, one run:", [round(reinforce(k, 2**-9, 0.0, 3000)[-1][1], 3) for k in (1, 5, 20, 80)])
```

```output
plain 2^-13 [-32.7, -21.7, -18.7, -16.3, -14.9, -13.4] p 0.411 min 0.375 max 0.455
plain 2^-12 [-26.0, -16.3, -13.8, -13.1, -12.1, -12.0] p 0.522 min 0.431 max 0.61
baseline 2^-10 [-17.8, -12.0, -11.7, -11.5, -11.8, -11.5] p 0.59 min 0.514 max 0.715
plain 2^-9, one run: [0.1, 1.0, 1.0, 1.0]
```

Смотри. Без базовой линии при шаге `2⁻¹³` за 600 партий `p` поднимается лишь до 0,4, а отдача до −13. При шаге `2⁻¹²` быстрее, но всё равно медленно. С базовой линией при шаге `2⁻¹⁰` уже после 200 партий отдача около −12, а `p` у верхнего значения 0,59. **Почему?** Здесь все отдачи отрицательные, около −40. Без базовой линии каждое действие наказывается, причём сильно, а полезная разница тонет в большом общем сдвиге. После вычитания среднего шум намного меньше, и можно брать шаг в 8 раз больше.

Последняя строка показывает другое: шаг `2⁻⁹` без базовой линии за 5 партий загоняет `p` в 1,0. Там производная `1 − p` почти ноль, и обучение **замирает навсегда**, причём именно там, где агент ходит по кругу. Большой шаг опасен не только скачками: он может выбить политику туда, откуда нет дороги назад. Поэтому метод PPO ограничивает, насколько можно менять политику за раз.

**Шаг 5. Причём здесь языковая модель.** Замени слова. Действие это следующий токен, политика это её softmax, а `G` это оценка ответа человеком или моделью награды. Формула та же: `оценка · ∇ ln p(токена)`. Работа InstructGPT (Ouyang и др., 2022) использовала PPO, потомка этого метода. Это будет в уроке о RLHF. Базовая линия там тоже есть, только обучаемая: это критик, и пара «политика и критик» называется actor–critic.

**Учись у тех, кто это создаёт.** Глава 13 книги [Sutton и Barto](http://incompleteideas.net/book/the-book-2nd.html). Статья [Karpathy о Pong](http://karpathy.github.io/2016/05/31/rl/) строит то же с нуля простыми словами. Вывод формулы по шагам: [Spinning Up, часть 3](https://spinningup.openai.com/en/latest/spinningup/rl_intro3.html). Как это ведёт к языковым моделям: книга [Nathan Lambert о RLHF](https://rlhfbook.com/).

### Исследуй и потренируйся

В тренажёре сначала сам найди лучшую политику: тащи точку по настоящей кривой ценности. Затем запусти REINFORCE и смотри, как белая точка ползёт к вершине. Затем поставь шаг побольше без базовой линии и посмотри, как обучение ломается.

В программе начни с `p = 0,9`, то есть `theta = [math.log(9.0), 0.0]`. Сходится ли туда же?

### Вопрос

Зачем из отдачи вычитают базовую линию?

### Варианты

- Она убирает общий сдвиг отдачи, и шум обновлений становится намного меньше.
- Она меняет лучшую политику, и агент находит решение лучше, чем без неё было можно.
- Она делает все отдачи равными нулю, и шаг обучения больше не нужно подбирать.

### Ответ

1

### Разбор

Базовая линия не меняет среднее направление шага, если она не зависит от действия: лучшая политика остаётся той же. Меняется разброс. Отдачи не становятся нулями, становится видно только, насколько партия лучше обычной. Подбирать шаг всё равно нужно: это видно в последней строке опыта.

### Границы модели

Здесь всего одно число политики и одна отдача, и настоящие модели устроены намного сложнее. На шаге я подбирал вручную небольшую сетку. Партия обрывается на 500 шагах, иначе застрявший агент ходил бы вечно. 20 запусков дают заметный разброс: итоговое `p` у одной настройки лежит от 0,51 до 0,72. У настоящих языковых моделей добавляются другие проблемы, например обман награды, и о них отдельный урок.

## English

### Goal

Learn to change the policy itself, not a table of values. Compute a REINFORCE step by hand, write it in plain Python, and see why a baseline is needed and how a large step breaks training. This method underlies RLHF in the next lessons. It takes about 50 minutes.

### Idea and mechanism

**Step 1. Why another method.** Q-learning learns values and picks an action by `max`. That has two weak points. There may be very many actions: a language model picks the next token from tens of thousands. And the best policy may be random, while `max` always picks the same thing. So we learn the policy directly: numbers `θ` that give action probabilities through softmax. A language model is exactly that: its output is the probabilities of the next token.

The idea in one phrase: **what earned a lot, do more often; what earned little, do less often.**

**Step 2. One step by hand.** Two actions, "right" and "left", `θ = (0; 0)`. Softmax gives probabilities `0.5` and `0.5`. The agent went right and received the **return** `G = +2`, the sum of rewards to the game's end. The step is `α = 0.1`.

The REINFORCE rule: `θ ← θ + α · G · ∇ ln π(a)`. For softmax the derivative of the log probability is simple: for the chosen action `1 − p`, and for the other `−(1 − p)`, where `p` is the chosen action's probability.

- `∇ ln π = (0.5; −0.5)`
- `θ = (0 + 0.1 · 2 · 0.5; 0 − 0.1 · 2 · 0.5) = (0.1; −0.1)`
- the new probability of "right": `e^0.1 / (e^0.1 + e^−0.1) = 0.55`

It grew. If `G = −2`, the probability would fall to `0.45`. That is the whole method. The logarithm is needed because `∇ ln π = ∇π / π`: dividing by the probability removes the unfair advantage of actions that are simply picked more often. The policy gradient theorem says that on average such a step goes uphill on the expected return. Each step is noisy, and the mean is right.

**Step 3. A world where a table will not help.** Take the corridor from Sutton and Barto's book, Example 13.1. Three cells and an exit. Each step costs `−1`. In cells 1 and 3 the "right" button leads right, and in cell 2 the buttons are **swapped**. And the agent does not see which cell it is in: it has one number, the probability `p` of pressing "right".

If it always presses "right" (`p = 1`), the agent walks between cells 1 and 2 forever. If always "left" (`p = 0`), it stays stuck in cell 1. So **the best policy is random**, and `max` will not find it. The Bellman equations for three cells can be solved on paper: `V₁ = −2(2 − p) / (p(1 − p))`. The best `p = 2 − √2 ≈ 0.586`. Create the file `nano ~/ai-path/corridor.py` and run it.

```python
import math


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


def step(state, right):
    if state == 1:
        return (2 if right else 1), -1.0, False
    if state == 2:
        return (1 if right else 3), -1.0, False
    if right:
        return 4, -1.0, True
    return 2, -1.0, False


def exact_value(p):
    return -2 * (2 - p) / (p * (1 - p))


for p in (0.1, 0.3, 0.5, 0.55, 0.59, 0.6, 0.7, 0.9):
    print(p, round(exact_value(p), 2))
print("best p", round(2 - math.sqrt(2), 4), round(exact_value(2 - math.sqrt(2)), 3))
```

```output
0.1 -42.22
0.3 -16.19
0.5 -12.0
0.55 -11.72
0.59 -11.66
0.6 -11.67
0.7 -12.38
0.9 -24.44
best p 0.5858 -11.657
```

The best value is `−11.66`: almost 12 steps on average. Check the formula by playing: 5000 games on the real corridor. Add this and run it.

```python
def play(p, rand, limit=500):
    state, done, tape = 1, False, []
    while not done and len(tape) < limit:
        right = rand.next() < p
        state, reward, done = step(state, right)
        tape.append((right, reward))
    return tape


rand = Rand(5)
for p in (0.1, 0.59, 0.9):
    runs = [play(p, rand) for _ in range(5000)]
    print(p, round(sum(sum(r for _, r in tape) for tape in runs) / 5000, 2))
```

```output
0.1 -42.87
0.59 -11.83
0.9 -24.55
```

It agrees with the formula within the noise of the games, a little under one.

**Step 4. REINFORCE.** We start from a poor policy, `p = 0.1`. Play a game to the end, walk through it from the end, add up the return, and shift `θ` at each step. The baseline `w` is the mean return, which we also learn: instead of `G` we use `G − w`. What matters is not the result itself but how much better it is than usual. Add this and run it. The rows show the mean return by hundreds of games, the final `p`, and the lowest and highest over 20 runs.

```python
def right_probability(theta):
    return 1 / (1 + math.exp(max(-30.0, min(30.0, theta[1] - theta[0]))))


def reinforce(episodes, rate, baseline_rate, seed):
    rand = Rand(seed)
    theta = [0.0, math.log(9.0)]
    w = 0.0
    curve = []
    for _ in range(episodes):
        p = right_probability(theta)
        tape = play(p, rand)
        curve.append((sum(r for _, r in tape), p))
        future = 0.0
        for right, reward in reversed(tape):
            future += reward
            p = right_probability(theta)
            advantage = future - w if baseline_rate else future
            if baseline_rate:
                w += baseline_rate * advantage
            grad = (1 - p, -(1 - p)) if right else (-p, p)
            theta[0] += rate * advantage * grad[0]
            theta[1] += rate * advantage * grad[1]
    return curve


RUNS = 20
for name, rate, baseline in (("plain 2^-13", 2**-13, 0.0), ("plain 2^-12", 2**-12, 0.0), ("baseline 2^-10", 2**-10, 2**-6)):
    finals, returns = [], [0.0] * 6
    for seed in range(RUNS):
        curve = reinforce(600, rate, baseline, 3000 + seed)
        finals.append(curve[-1][1])
        for i in range(6):
            part = curve[i * 100:i * 100 + 100]
            returns[i] += sum(g for g, _ in part) / 100
    print(name, [round(v / RUNS, 1) for v in returns], "p", round(sum(finals) / RUNS, 3), "min", round(min(finals), 3), "max", round(max(finals), 3))
print("plain 2^-9, one run:", [round(reinforce(k, 2**-9, 0.0, 3000)[-1][1], 3) for k in (1, 5, 20, 80)])
```

```output
plain 2^-13 [-32.7, -21.7, -18.7, -16.3, -14.9, -13.4] p 0.411 min 0.375 max 0.455
plain 2^-12 [-26.0, -16.3, -13.8, -13.1, -12.1, -12.0] p 0.522 min 0.431 max 0.61
baseline 2^-10 [-17.8, -12.0, -11.7, -11.5, -11.8, -11.5] p 0.59 min 0.514 max 0.715
plain 2^-9, one run: [0.1, 1.0, 1.0, 1.0]
```

Look. Without a baseline, at step `2⁻¹³`, over 600 games `p` rises only to 0.4 and the return to −13. At step `2⁻¹²` it is quicker, yet still slow. With a baseline at step `2⁻¹⁰`, after only 200 games the return is about −12 and `p` is near the top value of 0.59. **Why?** All returns here are negative, around −40. Without a baseline each action is punished, and heavily, while the useful difference drowns in a large common shift. After subtracting the mean the noise is much smaller, and the step can be 8 times larger.

The last row shows something else: step `2⁻⁹` without a baseline drives `p` to 1.0 within 5 games. There the derivative `1 − p` is nearly zero, and training **freezes for good**, exactly where the agent walks in circles. A large step is dangerous not only for its jumps: it can knock the policy to a place with no way back. That is why the PPO method limits how much the policy may change at once.

**Step 5. What this has to do with a language model.** Replace the words. The action is the next token, the policy is its softmax, and `G` is the score a person or a reward model gives the answer. The same formula: `score · ∇ ln p(token)`. The InstructGPT work (Ouyang et al., 2022) used PPO, a descendant of this method. That is coming in the RLHF lesson. The baseline is there too, only learned: it is the critic, and the pair of policy and critic is called actor–critic.

**Learn from the people who build this.** Chapter 13 of [Sutton and Barto](http://incompleteideas.net/book/the-book-2nd.html). [Karpathy's article on Pong](http://karpathy.github.io/2016/05/31/rl/) builds the same thing from scratch in simple words. The derivation step by step: [Spinning Up, part 3](https://spinningup.openai.com/en/latest/spinningup/rl_intro3.html). How this leads to language models: [Nathan Lambert's book on RLHF](https://rlhfbook.com/).

### Explore and practise

In the lab, first find the best policy yourself: drag the point along the real value curve. Then run REINFORCE and watch the white point crawl to the top. Then set a larger step without a baseline and see training break.

In the program, start from `p = 0.9`, that is `theta = [math.log(9.0), 0.0]`. Does it converge to the same place?

### Question

Why is a baseline subtracted from the return?

### Options

- It removes the common shift of the return, so the noise of the updates gets much smaller.
- It changes the best policy, so the agent finds a better solution than was possible before.
- It makes all returns equal to zero, so the learning step no longer needs to be tuned.

### Answer

1

### Explanation

A baseline that does not depend on the action does not change the mean direction of the step: the best policy stays the same. What changes is the spread. Returns do not become zero; you just see how much better a game is than usual. The step still needs tuning: the last row of the experiment shows that.

### Limits

There is only one number in this policy and one return, and real models are far more complex. I tuned the step by hand on a small grid. A game stops at 500 steps; otherwise a stuck agent would walk forever. 20 runs leave noticeable spread: the final `p` for one setting lies between 0.51 and 0.72. Real language models bring other problems, such as reward hacking, and a separate lesson covers those.

## Sources

- Richard S. Sutton, Andrew G. Barto, "Reinforcement Learning: An Introduction", 2nd ed., MIT Press (2018), chapter 13 and Example 13.1, recalled from the book; the site answered with an error on the check of 2026-11-03; the value formula and its maximum are derived and checked by simulation in the program: [book page](http://incompleteideas.net/book/the-book-2nd.html)
- Ronald J. Williams, "Simple statistical gradient-following algorithms for connectionist reinforcement learning", Machine Learning 8 (1992), title read 2026-11-03: [Springer](https://link.springer.com/article/10.1007/BF00992696)
- John Schulman et al., "Proximal Policy Optimization Algorithms", arXiv:1707.06347 (2017): [arXiv:1707.06347](https://arxiv.org/abs/1707.06347)
- Long Ouyang et al., "Training language models to follow instructions with human feedback", arXiv:2203.02155 (2022): [arXiv:2203.02155](https://arxiv.org/abs/2203.02155)
- Andrej Karpathy, "Deep Reinforcement Learning: Pong from Pixels" (2016), title read 2026-11-03: [article](http://karpathy.github.io/2016/05/31/rl/)
- OpenAI, "Spinning Up, Part 3: Intro to Policy Optimization", title read 2026-11-03: [page](https://spinningup.openai.com/en/latest/spinningup/rl_intro3.html)
- Nathan Lambert, "Reinforcement Learning from Human Feedback", title read 2026-11-03: [book](https://rlhfbook.com/)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
