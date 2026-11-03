---
subject: programming
lesson_id: programming.agi_world_models
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Модели мира: учиться в воображении / World models: learning in imagination

## Русский

### Цель

Понять, зачем агенту внутренняя модель мира. Написать агента, который запоминает, как устроен мир, и учится на воображаемых шагах, измерить выгоду и разобрать настоящий спор: нужны ли для AGI модели мира вместо языковых моделей. Нужно около 45 минут.

### Идея и механизм

**Шаг 1. Что такое модель мира.** Q-агент из прошлых уроков платит настоящим шагом за каждый кусочек опыта. **Модель мира** это то, что агент сам запоминает: из этой клетки это действие ведёт туда и даёт такую награду. Тогда можно учиться и **в воображении**: взять уже виденный переход и обновить оценку снова, не делая шага в мире. На этой идее построена схема Dyna из книги Саттона и Барто.

Руками: в настоящем мире `A → B` даёт `0`, а у лучшего действия из `B` оценка `0,8`. Шаг `α = 0,5`, скидка `0,95`. Настоящий шаг: `Q(A) = 0 + 0,5 · (0 + 0,95 · 0,8 − 0) = 0,38`. Воображаемый повтор того же перехода, без шага в мире: `0,38 + 0,5 · (0,76 − 0,38) = 0,57`. Ещё один: `0,665`. Оценка догоняет цель за счёт памяти, а не опыта.

**Шаг 2. Опыт.** Поле 5 на 6 со стеной, цель в правом верхнем углу. Создай файл `nano ~/ai-path/world.py`, вставь и запусти. Строка это число воображаемых шагов на один настоящий и среднее число настоящих шагов за игру по 20 запускам.

```python
class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53

    def below(self, limit):
        return int(self.next() * limit)


ROWS, COLS, START, GOAL = 5, 6, 24, 5
WALLS = {8, 14, 20}
MOVES = [(-1, 0), (0, 1), (1, 0), (0, -1)]


def step(cell, action, walls):
    r, c = cell // COLS + MOVES[action][0], cell % COLS + MOVES[action][1]
    if not (0 <= r < ROWS and 0 <= c < COLS) or r * COLS + c in walls:
        return cell, 0.0
    next_cell = r * COLS + c
    return next_cell, 1.0 if next_cell == GOAL else 0.0


def choose(row, epsilon, rand):
    if rand.next() < epsilon:
        return rand.below(4)
    top = max(row)
    ties = [a for a in range(4) if row[a] == top]
    return ties[rand.below(len(ties))]


def run(plans, episodes, seed, walls=WALLS, change=None, alpha=0.5, epsilon=0.1, gamma=0.95):
    rand = Rand(seed)
    Q = [[0.0] * 4 for _ in range(ROWS * COLS)]
    model = {}
    seen = []
    log = []
    for episode in range(episodes):
        if change and episode == change[0]:
            walls = change[1]
        cell, steps = START, 0
        while cell != GOAL and steps < 300:
            action = choose(Q[cell], epsilon, rand)
            next_cell, reward = step(cell, action, walls)
            future = 0.0 if next_cell == GOAL else gamma * max(Q[next_cell])
            Q[cell][action] += alpha * (reward + future - Q[cell][action])
            if (cell, action) not in model:
                seen.append((cell, action))
            model[cell, action] = (next_cell, reward)
            for _ in range(plans):
                s, a = seen[rand.below(len(seen))]
                n, r = model[s, a]
                future = 0.0 if n == GOAL else gamma * max(Q[n])
                Q[s][a] += alpha * (r + future - Q[s][a])
            cell = next_cell
            steps += 1
        log.append(steps)
    return log, len(model)


print("imagined steps per real step, mean real steps per game in games 1, 2, 3-5, 6-20, 21-50")
for plans in (0, 5, 50):
    totals = [0.0] * 50
    for seed in range(20):
        log, known = run(plans, 50, 500 + seed)
        totals = [a + b for a, b in zip(totals, log)]
    means = [t / 20 for t in totals]
    print(plans, round(means[0]), round(means[1]), round(sum(means[2:5]) / 3), round(sum(means[5:20]) / 15), round(sum(means[20:50]) / 30))
```

```output
imagined steps per real step, mean real steps per game in games 1, 2, 3-5, 6-20, 21-50
0 165 142 90 26 10
5 158 70 26 10 10
50 126 30 11 11 10
```

Без воображения вторая игра занимает 142 настоящих шага, при 5 воображаемых 70, а при 50 всего 30. К третьей-пятой игре агент с воображением уже почти на лучшем пути, а без него ему нужно ещё около 90 шагов. **Настоящего опыта нужно намного меньше.** Цена в расчётах: при 50 воображаемых шагах считать надо в 51 раз больше. Когда настоящий шаг стоит дорого, как у робота, такой обмен выгоден.

**Шаг 3. Мир изменился.** Модель устаревает. На игре 30 перенесём стену. Допиши и запусти.

```python
print("the wall moves at game 30; plans, steps in games 29, 31, 32-40, 41-60")
for plans in (0, 50):
    totals = [0.0] * 60
    for seed in range(20):
        log, known = run(plans, 60, 700 + seed, walls={8, 14, 20}, change=(30, {2, 8, 14}))
        totals = [a + b for a, b in zip(totals, log)]
    means = [t / 20 for t in totals]
    print(plans, round(means[28]), round(means[30]), round(sum(means[31:40]) / 9), round(sum(means[40:60]) / 20))
```

```output
the wall moves at game 30; plans, steps in games 29, 31, 32-40, 41-60
0 10 188 153 67
50 10 115 65 20
```

Агент с моделью снова быстрее, 65 шагов против 153 в следующих играх. Но заметь и обратную сторону: первая игра после перемены стоит ему 115 шагов, а воображение всё ещё обновляет оценки по старой карте, пока он не наткнётся на новую стену.

**Шаг 4. Настоящие системы.** Та же идея, только модель это нейросеть.

- **World Models** (Ha и Schmidhuber, 2018) и **DreamerV3** учат модель прямо из картинок и обучают политику внутри воображаемых траекторий. DreamerV3 освоила больше 150 задач с одними настройками.
- **MuZero** не предсказывает картинку, а учит только то, что нужно для планирования. Об этом будет отдельный урок.
- **JEPA** Янна Лекуна предсказывает не сами пиксели, а скрытое представление следующего кадра: так не нужно тратить силы на неважные подробности. V-JEPA 2 это такая модель для видео.

**Шаг 5. Спор.** Здесь нужно отделить слова от опытов.

*Мнение Лекуна:* языковые модели тупиковый путь к настоящему интеллекту, потому что они не понимают физический мир, не умеют планировать и у них нет постоянной памяти. Нужны модели мира.

*Возражение:* в языковых моделях находят внутренние представления мира. Например, на игре в отелло сеть без единого объяснения правил хранила положение доски (Li и др., 2022). Сторонники масштабирования считают, что такие представления появятся сами и шире.

*Что показано:* и DreamerV3, и отелло это настоящие опыты. Но ни один из них не решает спор о том, что приведёт к AGI. Это прогнозы, и честный ответ: пока неизвестно.

**Учись у тех, кто это создаёт.** Глава 8 книги [Sutton и Barto](http://incompleteideas.net/book/the-book-2nd.html). Статья [World Models](https://arxiv.org/abs/1803.10122) и [DreamerV3](https://arxiv.org/abs/2301.04104). План Лекуна: [A Path Towards Autonomous Machine Intelligence](https://openreview.net/forum?id=BZ5a1r-kVsf).

### Исследуй и потренируйся

В тренажёре настоящий агент учится по той же формуле. Двигай число воображаемых шагов и смотри, как падает кривая. Включи перенос стены и сравни, как агент приходит в себя.

В программе поставь `plans=500`. Становится ли лучше, и какой ценой?

### Вопрос

Что воображаемый шаг даёт агенту, если нового опыта он не приносит?

### Варианты

- Он снова использует уже виденный переход, и сведения быстрее расходятся по оценкам.
- Он открывает новые клетки поля, потому что агент заранее угадывает скрытую карту.
- Он заменяет случайный выбор действий, потому что исследовать больше не требуется.

### Ответ

1

### Разбор

Воображение работает только с тем, что агент уже видел, поэтому новых клеток не открывает. Исследовать всё равно нужно, особенно когда мир меняется. Выгода в другом: одно наблюдение используется много раз, поэтому ценность цели расходится быстрее, как волна в уроке об уравнении Беллмана.

### Границы модели

Мир здесь без шума и крошечный, поэтому модель это просто таблица и она всегда верна, пока мир не изменится. В настоящих системах модель ошибается, и эти ошибки накапливаются при длинном воображении. Числа зависят от карты и от настроек, которые выбрал я. Двадцать запусков дают заметный разброс в первых играх.

## English

### Goal

Understand why an agent needs an internal model of the world. Write an agent that remembers how the world works and learns on imagined steps, measure the gain, and examine a real dispute: does AGI need world models rather than language models? It takes about 45 minutes.

### Idea and mechanism

**Step 1. What a world model is.** The Q-agent of earlier lessons pays one real step for each piece of experience. A **world model** is what the agent itself remembers: from this cell this action leads there and gives such a reward. Then it can also learn **in imagination**: take a transition it has seen and update the estimate again, without a step in the world. Sutton and Barto's Dyna scheme is built on this idea.

By hand: in the real world `A → B` gives `0`, and the best action from `B` has estimate `0.8`. Step `α = 0.5`, discount `0.95`. A real step: `Q(A) = 0 + 0.5 · (0 + 0.95 · 0.8 − 0) = 0.38`. An imagined repeat of the same transition, with no step in the world: `0.38 + 0.5 · (0.76 − 0.38) = 0.57`. One more: `0.665`. The estimate catches up through memory, not experience.

**Step 2. The experiment.** A 5 by 6 field with a wall, the goal at the top right. Create the file `nano ~/ai-path/world.py`, paste and run it. A row shows the number of imagined steps per real one, and the mean number of real steps per game over 20 runs.

```python
class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53

    def below(self, limit):
        return int(self.next() * limit)


ROWS, COLS, START, GOAL = 5, 6, 24, 5
WALLS = {8, 14, 20}
MOVES = [(-1, 0), (0, 1), (1, 0), (0, -1)]


def step(cell, action, walls):
    r, c = cell // COLS + MOVES[action][0], cell % COLS + MOVES[action][1]
    if not (0 <= r < ROWS and 0 <= c < COLS) or r * COLS + c in walls:
        return cell, 0.0
    next_cell = r * COLS + c
    return next_cell, 1.0 if next_cell == GOAL else 0.0


def choose(row, epsilon, rand):
    if rand.next() < epsilon:
        return rand.below(4)
    top = max(row)
    ties = [a for a in range(4) if row[a] == top]
    return ties[rand.below(len(ties))]


def run(plans, episodes, seed, walls=WALLS, change=None, alpha=0.5, epsilon=0.1, gamma=0.95):
    rand = Rand(seed)
    Q = [[0.0] * 4 for _ in range(ROWS * COLS)]
    model = {}
    seen = []
    log = []
    for episode in range(episodes):
        if change and episode == change[0]:
            walls = change[1]
        cell, steps = START, 0
        while cell != GOAL and steps < 300:
            action = choose(Q[cell], epsilon, rand)
            next_cell, reward = step(cell, action, walls)
            future = 0.0 if next_cell == GOAL else gamma * max(Q[next_cell])
            Q[cell][action] += alpha * (reward + future - Q[cell][action])
            if (cell, action) not in model:
                seen.append((cell, action))
            model[cell, action] = (next_cell, reward)
            for _ in range(plans):
                s, a = seen[rand.below(len(seen))]
                n, r = model[s, a]
                future = 0.0 if n == GOAL else gamma * max(Q[n])
                Q[s][a] += alpha * (r + future - Q[s][a])
            cell = next_cell
            steps += 1
        log.append(steps)
    return log, len(model)


print("imagined steps per real step, mean real steps per game in games 1, 2, 3-5, 6-20, 21-50")
for plans in (0, 5, 50):
    totals = [0.0] * 50
    for seed in range(20):
        log, known = run(plans, 50, 500 + seed)
        totals = [a + b for a, b in zip(totals, log)]
    means = [t / 20 for t in totals]
    print(plans, round(means[0]), round(means[1]), round(sum(means[2:5]) / 3), round(sum(means[5:20]) / 15), round(sum(means[20:50]) / 30))
```

```output
imagined steps per real step, mean real steps per game in games 1, 2, 3-5, 6-20, 21-50
0 165 142 90 26 10
5 158 70 26 10 10
50 126 30 11 11 10
```

Without imagination the second game takes 142 real steps, with 5 imagined 70, and with 50 only 30. By games three to five the imagining agent is nearly on the best path, while the other still needs about 90 steps. **Far less real experience is needed.** The price is in computing: with 50 imagined steps you compute 51 times more. When a real step is expensive, as for a robot, this trade pays.

**Step 3. The world changed.** A model goes stale. At game 30 we move the wall. Add this and run it.

```python
print("the wall moves at game 30; plans, steps in games 29, 31, 32-40, 41-60")
for plans in (0, 50):
    totals = [0.0] * 60
    for seed in range(20):
        log, known = run(plans, 60, 700 + seed, walls={8, 14, 20}, change=(30, {2, 8, 14}))
        totals = [a + b for a, b in zip(totals, log)]
    means = [t / 20 for t in totals]
    print(plans, round(means[28]), round(means[30]), round(sum(means[31:40]) / 9), round(sum(means[40:60]) / 20))
```

```output
the wall moves at game 30; plans, steps in games 29, 31, 32-40, 41-60
0 10 188 153 67
50 10 115 65 20
```

The agent with a model is faster again, 65 steps against 153 in the following games. Note the other side too: the first game after the change costs it 115 steps, and imagination still updates estimates by the old map until it runs into the new wall.

**Step 4. Real systems.** The same idea, with a neural network as the model.

- **World Models** (Ha and Schmidhuber, 2018) and **DreamerV3** learn a model straight from pictures and train a policy inside imagined trajectories. DreamerV3 mastered over 150 tasks with one set of settings.
- **MuZero** does not predict the picture but learns only what planning needs. A separate lesson covers it.
- **JEPA** by Yann LeCun predicts not the pixels but a hidden representation of the next frame: so no effort goes to unimportant details. V-JEPA 2 is such a model for video.

**Step 5. The dispute.** Here words must be separated from experiments.

*LeCun's opinion:* language models are a dead end on the way to real intelligence, because they do not understand the physical world, cannot plan and have no lasting memory. World models are needed.

*The objection:* inner representations of the world are found in language models. For example, in the game of Othello a network, told no rules, kept track of the board's state (Li et al., 2022). Scaling supporters believe such representations will arise by themselves, more widely.

*What is shown:* DreamerV3 and Othello are both real experiments. But neither settles what will lead to AGI. Those are forecasts, and the honest answer is: unknown so far.

**Learn from the people who build this.** Chapter 8 of [Sutton and Barto](http://incompleteideas.net/book/the-book-2nd.html). The papers [World Models](https://arxiv.org/abs/1803.10122) and [DreamerV3](https://arxiv.org/abs/2301.04104). LeCun's plan: [A Path Towards Autonomous Machine Intelligence](https://openreview.net/forum?id=BZ5a1r-kVsf).

### Explore and practise

In the lab a real agent learns by the same formula. Move the number of imagined steps and watch the curve fall. Switch on the wall move and compare how the agent recovers.

In the program, set `plans=500`. Does it get better, and at what price?

### Question

What does an imagined step give the agent, if it brings no new experience?

### Options

- It reuses a transition already seen, so information spreads through estimates faster.
- It opens new cells of the field, because the agent guesses the hidden map in advance.
- It replaces random choice of actions, because exploring is no longer required at all.

### Answer

1

### Explanation

Imagination works only with what the agent has seen, so it opens no new cells. Exploring is still needed, especially when the world changes. The gain is elsewhere: one observation is used many times, so the goal's value spreads faster, like the wave in the Bellman equation lesson.

### Limits

The world here is noiseless and tiny, so the model is just a table and is always right until the world changes. In real systems the model errs, and errors accumulate over long imagination. The numbers depend on the map and the settings I chose. Twenty runs leave noticeable spread in the first games.

## Sources

- Richard S. Sutton, Andrew G. Barto, "Reinforcement Learning: An Introduction", 2nd ed., MIT Press (2018), chapter 8, recalled; the site answered with an error on the check of 2026-11-03: [book page](http://incompleteideas.net/book/the-book-2nd.html)
- David Ha, Jürgen Schmidhuber, "World Models", arXiv:1803.10122 (2018), title read 2026-11-03: [arXiv:1803.10122](https://arxiv.org/abs/1803.10122)
- Danijar Hafner et al., "Mastering Diverse Domains through World Models", arXiv:2301.04104 (2023), title read 2026-11-03: [arXiv:2301.04104](https://arxiv.org/abs/2301.04104)
- Yann LeCun, "A Path Towards Autonomous Machine Intelligence" (2022), recalled: [OpenReview](https://openreview.net/forum?id=BZ5a1r-kVsf)
- Mido Assran et al., "V-JEPA 2", arXiv:2506.09985 (2025), title read 2026-11-03: [arXiv:2506.09985](https://arxiv.org/abs/2506.09985)
- Kenneth Li et al., "Emergent World Representations", arXiv:2210.13382 (2022), recalled: [arXiv:2210.13382](https://arxiv.org/abs/2210.13382)
- Julian Schrittwieser et al., "Mastering Atari, Go, Chess and Shogi by Planning with a Learned Model", arXiv:1911.08265 (2019), recalled: [arXiv:1911.08265](https://arxiv.org/abs/1911.08265)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
