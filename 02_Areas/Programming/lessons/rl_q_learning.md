---
subject: programming
lesson_id: programming.rl_q_learning
level: advanced
languages: ru, en
source_checked: 2026-11-07
source_review_interval_days: 365
---

# Q-обучение: агент учится сам / Q-learning: an agent learns on its own

## Русский

### Простыми словами

В прошлом уроке агент знал устройство мира заранее. Теперь не знает: он ходит, получает награды и сам запоминает, что выгодно. Для каждой пары «клетка и действие» он хранит оценку `Q` и после каждого шага чуть сдвигает её к тому, что увидел. Похоже на изучение нового района пешком: сначала плутаешь, но каждая прогулка уточняет карту в голове. SARSA, осторожный родственник, учитывает собственные случайные шаги и поэтому держится подальше от обрыва.

**Что нужно знать до.** Урок «Клетчатый мир и уравнение Беллмана» (шаг 13): состояние, ценность, скидка. Урок «Автоматы» (шаг 13): исследование.

**Если непонятно.** Если неясна формула обновления, посчитай шаг 2 урока руками с теми же числами. Если неясна скидка, вернись к уроку «Клетчатый мир». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Снять главное условие прошлого урока: теперь агент не знает мир заранее. Посчитать шаг Q-обучения руками, обучить агента проходить мир только на опыте и сравнить его с осторожным SARSA. Нужно около 45 минут.

### Идея и механизм

**Шаг 1. Что мешало.** Итерация ценности заглядывала в модель мира: куда ведёт действие и какая там награда. В жизни такой модели обычно нет. Есть только опыт: сделал, получил, оказался. Поэтому учим не ценность клетки, а **ценность действия** `Q(s, a)`: сколько ждать, если сейчас в клетке `s` сделать `a`, а дальше действовать лучшим образом. Тогда модель мира не нужна: лучшее действие это то, у которого `Q` больше.

**Шаг 2. Шаг руками.** Агент стоит в клетке, идёт вправо, платит `−0,04` и видит, что у лучшего действия в новой клетке `Q = 0,8`. Сколько теперь стоит его действие? Опыт подсказывает новую оценку, **цель**:

`цель = −0,04 + 0,95 · 0,8 = 0,72`

Сдвигаем старое значение к цели на долю `α = 0,5`:

- первый раз: `0 + 0,5 · (0,72 − 0) = 0,36`
- второй раз: `0,36 + 0,5 · (0,72 − 0,36) = 0,54`

Узнаёшь форму из урока об автоматах? Новая оценка равна старой плюс шаг к новому. Разница `цель − Q` называется **ошибкой временной разности**: насколько будущее оказалось лучше ожиданий.

Вся формула:

`Q(s, a) ← Q(s, a) + α · (r + γ · max Q(s′, ·) − Q(s, a))`

Важно: агент учится по одному шагу и не ждёт конца игры. Сведения о цели идут назад, как волна в прошлом уроке, но теперь только там, где агент реально ходил. Действия выбираем ε-жадно, как у автоматов, иначе агент запрётся на первом удачном пути.

**Шаг 3. Опыт.** Мир прежний: 5 строк, 6 столбцов, яма посередине нижней строки, без проскальзывания. Создай файл `nano ~/ai-path/q.py`, вставь и запусти. Печатаем среднюю награду за игру, среднее число шагов и выученные стрелки.

```python
MAP = ["......",
       "......",
       "......",
       "......",
       "SPPPPG"]
ROWS, COLS = len(MAP), len(MAP[0])
MOVES = [(-1, 0), (0, 1), (1, 0), (0, -1)]
ARROWS = "^>v<"


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


def step(cell, action):
    r, c = cell[0] + MOVES[action][0], cell[1] + MOVES[action][1]
    if not (0 <= r < ROWS and 0 <= c < COLS):
        r, c = cell
    kind = MAP[r][c]
    if kind == "G":
        return (r, c), 1.0, True
    if kind == "P":
        return (r, c), -1.0, True
    return (r, c), -0.04, False


def best(row, rand):
    top = max(row)
    ties = [a for a in range(4) if row[a] == top]
    return ties[int(rand.next() * len(ties))]


def choose(row, epsilon, rand):
    if rand.next() < epsilon:
        return int(rand.next() * 4)
    return best(row, rand)


def train(episodes, alpha, epsilon, gamma, seed, sarsa=False):
    rand = Rand(seed)
    Q = {(r, c): [0.0] * 4 for r in range(ROWS) for c in range(COLS)}
    log = []
    for _ in range(episodes):
        cell, total, steps, done = (4, 0), 0.0, 0, False
        action = choose(Q[cell], epsilon, rand)
        while not done and steps < 200:
            next_cell, reward, done = step(cell, action)
            next_action = choose(Q[next_cell], epsilon, rand)
            target = next_action if sarsa else Q[next_cell].index(max(Q[next_cell]))
            future = 0.0 if done else gamma * Q[next_cell][target]
            Q[cell][action] += alpha * (reward + future - Q[cell][action])
            cell, action = next_cell, next_action
            total += reward
            steps += 1
        log.append((total, steps, reward == -1.0))
    return Q, log


def route(Q):
    cell, cells, done = (4, 0), [(4, 0)], False
    while not done and len(cells) < 40:
        cell, _, done = step(cell, Q[cell].index(max(Q[cell])))
        cells.append(cell)
    return cells


def show(Q):
    for r in range(ROWS):
        print(" ".join(MAP[r][c] if MAP[r][c] in "PG" else ARROWS[Q[(r, c)].index(max(Q[(r, c)]))] for c in range(COLS)))


Q, log = train(300, alpha=0.5, epsilon=0.1, gamma=0.95, seed=11)
print("episodes  mean return  mean steps")
for first in range(0, 300, 50):
    part = log[first:first + 50]
    print(f"{first + 1}-{first + 50}", round(sum(e[0] for e in part) / 50, 3), round(sum(e[1] for e in part) / 50, 1))
show(Q)
print("route steps", len(route(Q)) - 1, "Q at start", round(max(Q[(4, 0)]), 3))
```

```output
episodes  mean return  mean steps
1-50 -0.009 13.2
51-100 0.518 8.0
101-150 0.47 7.2
151-200 0.574 7.6
201-250 0.617 7.6
251-300 0.462 7.4
< < v v > >
> < v < v ^
> > v < v v
> > > > > v
^ P P P P G
route steps 7 Q at start 0.523
```

Агент не знал ничего. За первые 50 игр он часто падает, средняя награда около нуля. Уже к сотой игре он почти всё время доходит, примерно за 7–8 шагов. Шум в награде не исчезает: при `ε = 0,1` он по-прежнему иногда шагает случайно и падает в яму.

Теперь сравни с прошлым уроком. Выученное значение на старте `0,523`, а итерация ценности, которая знала мир, дала те же `0,523`. **Без модели мира, только на опыте, агент получил тот же ответ.** На настоящем пути стрелки верны. А вот наверху поля они странные, например `<` и `v` рядом. Это честно: агент там почти не бывает, значения там остались почти нетронутыми, и знать их ему незачем.

**Шаг 4. Q-обучение и SARSA.** В формуле стоит `max`: агент учится так, будто дальше будет действовать идеально. А ведь он ходит ε-жадно и иногда шагает случайно. **SARSA** отличается одним словом: вместо `max` она берёт то действие, которое агент действительно выберет следующим. Значит, свои случайные ошибки она учитывает в оценке.

Допиши и запусти. Здесь `ε = 0,2`, поэтому случайных шагов больше, и 30 запусков. Смотрим последние 300 игр из 400.

```python
print("rule   training return  falls of 300  route steps  highest row")
for name, sarsa in (("Q-learning", False), ("SARSA", True)):
    total, falls, lengths, tops = 0.0, 0, 0, 0
    for seed in range(30):
        Q, log = train(400, alpha=0.1, epsilon=0.2, gamma=0.95, seed=2000 + seed, sarsa=sarsa)
        total += sum(e[0] for e in log[100:]) / 300
        falls += sum(1 for e in log[100:] if e[2])
        cells = route(Q)
        lengths += len(cells) - 1
        tops += min(r for r, c in cells)
    print(name, round(total / 30, 3), round(falls / 30, 1), round(lengths / 30, 1), round(tops / 30, 2))
```

```output
rule   training return  falls of 300  route steps  highest row
Q-learning 0.208 78.9 7.0 3.0
SARSA 0.269 63.0 9.9 2.63
```

Q-обучение выучило самый короткий путь по краю, 7 шагов, но на нём падает чаще: 78,9 раза за 300 игр. SARSA выбирает более длинный и безопасный путь, почти 10 шагов, падает 63 раза и за время обучения получает больше: `0,269` против `0,208`. Этот приём взят из книги Саттона и Барто, пример «обрыв». Это не значит, что SARSA лучше. Если после обучения выключить случайность, по-настоящему лучшим будет путь Q-обучения. Какое правило выбрать, зависит от того, платишь ли ты за ошибки во время обучения.

**Шаг 5. Куда дальше.** Таблица годится для 30 клеток. В игре Atari состояние это картинка, и таблицы не хватит. DQN (Mnih и др., 2013) заменила таблицу нейросетью: на вход картинка, на выходе `Q` для каждой кнопки. Та же формула, только вместо записи в таблицу шаг градиента.

**Учись у тех, кто это создаёт.** Глава 6 книги [Sutton и Barto](http://incompleteideas.net/book/the-book-2nd.html). Лекции 4 и 5 курса [David Silver](https://www.davidsilver.uk/teaching/). Практика с настоящими средами: [Hugging Face Deep RL Course](https://huggingface.co/learn/deep-rl-course/unit1/introduction).

### Исследуй и потренируйся

В тренажёре настоящий агент: цветной треугольник в клетке показывает `Q` этого действия. Нажми «Пуск» и смотри на первые шаги: вокруг цели появляется зелёный след. Кнопка «+100 игр» проматывает обучение. Щелчком ставь и убирай стены: агент должен найти новый путь.

В программе поставь `alpha=1.0`, затем `alpha=0.01`. Что случится с кривой?

### Вопрос

Чем Q-обучение отличается от SARSA?

### Варианты

- Q-обучение берёт в оценке лучшее следующее действие, а SARSA действие, выбранное на деле.
- Q-обучение знает заранее модель мира и награды, а SARSA обходится только своим опытом.
- Q-обучение обновляет оценку в конце игры, а SARSA обновляет её после каждого сделанного шага.

### Ответ

1

### Разбор

Модели мира нет ни у той, ни у другой: обе учатся на опыте. Обе обновляют оценку после каждого шага. Разница только в будущем внутри формулы: `max` у Q-обучения и выбранное действие у SARSA. Из-за неё SARSA учитывает свои случайные шаги и держится дальше от обрыва.

### Границы модели

Мир маленький и без шума, поэтому Q-обучение тут сходится быстро. Теорема о сходимости (Watkins и Dayan, 1992) требует, чтобы каждое действие пробовалось бесконечно часто, а шаги уменьшались так, чтобы их сумма была бесконечной, а сумма их квадратов конечной; у меня шаг постоянный, поэтому сходимость тут опытный факт, а не доказанный. С нейросетями вместо таблицы гарантий мало, и обучение бывает неустойчивым. Числа сравнения зависят от `ε`, `α` и размера ямы, а 30 запусков дают заметный разброс.

## English

### In plain words

In «A grid world» the agent knew how the world worked in advance. Now it does not: it walks, gets rewards and remembers by itself what pays. For each "cell and action" pair it keeps an estimate `Q` and after each step nudges it toward what it saw. It is like exploring a new neighbourhood on foot: at first you get lost, but each walk refines the map in your head. SARSA, a cautious relative, takes its own random steps into account and so keeps away from the cliff.

**What to know first.** «A grid world and the Bellman equation» (step 13): state, value, discount. «Slot machines» (step 13): exploration.

**If something is unclear.** If the update formula is unclear, work step 2 of the lesson by hand with the same numbers. If the discount is unclear, go back to «A grid world». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Remove the main condition of the last lesson: now the agent does not know the world in advance. Compute a Q-learning step by hand, train an agent to cross the world from experience alone, and compare it with cautious SARSA. It takes about 45 minutes.

### Idea and mechanism

**Step 1. What was in the way.** Value iteration looked into a model of the world: where an action leads and what reward is there. In real life there is usually no such model. There is only experience: did it, got this, ended up there. So we learn not a cell's value but an **action value** `Q(s, a)`: what to expect if in cell `s` you do `a` now and then act as well as possible. No world model is then needed: the best action is the one with the larger `Q`.

**Step 2. One step by hand.** The agent stands in a cell, goes right, pays `−0.04` and sees that the best action in the new cell has `Q = 0.8`. What is its action worth now? Experience suggests a new estimate, the **target**:

`target = −0.04 + 0.95 · 0.8 = 0.72`

We move the old value towards the target by the share `α = 0.5`:

- first time: `0 + 0.5 · (0.72 − 0) = 0.36`
- second time: `0.36 + 0.5 · (0.72 − 0.36) = 0.54`

Recognize the form from the slot machines? The new estimate equals the old one plus a step towards the new value. The difference `target − Q` is called the **temporal difference error**: how much better the future turned out than expected.

The whole formula:

`Q(s, a) ← Q(s, a) + α · (r + γ · max Q(s′, ·) − Q(s, a))`

Importantly, the agent learns one step at a time and does not wait for the game's end. Knowledge of the goal travels backwards, like the wave of the last lesson, but now only where the agent really walked. We choose actions ε-greedily, as with the machines; otherwise the agent locks onto the first path that worked.

**Step 3. The experiment.** The same world: 5 rows, 6 columns, the pit in the middle of the bottom row, no slipping. Create the file `nano ~/ai-path/q.py`, paste and run it. We print the mean reward per game, the mean steps, and the learned arrows.

```python
MAP = ["......",
       "......",
       "......",
       "......",
       "SPPPPG"]
ROWS, COLS = len(MAP), len(MAP[0])
MOVES = [(-1, 0), (0, 1), (1, 0), (0, -1)]
ARROWS = "^>v<"


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


def step(cell, action):
    r, c = cell[0] + MOVES[action][0], cell[1] + MOVES[action][1]
    if not (0 <= r < ROWS and 0 <= c < COLS):
        r, c = cell
    kind = MAP[r][c]
    if kind == "G":
        return (r, c), 1.0, True
    if kind == "P":
        return (r, c), -1.0, True
    return (r, c), -0.04, False


def best(row, rand):
    top = max(row)
    ties = [a for a in range(4) if row[a] == top]
    return ties[int(rand.next() * len(ties))]


def choose(row, epsilon, rand):
    if rand.next() < epsilon:
        return int(rand.next() * 4)
    return best(row, rand)


def train(episodes, alpha, epsilon, gamma, seed, sarsa=False):
    rand = Rand(seed)
    Q = {(r, c): [0.0] * 4 for r in range(ROWS) for c in range(COLS)}
    log = []
    for _ in range(episodes):
        cell, total, steps, done = (4, 0), 0.0, 0, False
        action = choose(Q[cell], epsilon, rand)
        while not done and steps < 200:
            next_cell, reward, done = step(cell, action)
            next_action = choose(Q[next_cell], epsilon, rand)
            target = next_action if sarsa else Q[next_cell].index(max(Q[next_cell]))
            future = 0.0 if done else gamma * Q[next_cell][target]
            Q[cell][action] += alpha * (reward + future - Q[cell][action])
            cell, action = next_cell, next_action
            total += reward
            steps += 1
        log.append((total, steps, reward == -1.0))
    return Q, log


def route(Q):
    cell, cells, done = (4, 0), [(4, 0)], False
    while not done and len(cells) < 40:
        cell, _, done = step(cell, Q[cell].index(max(Q[cell])))
        cells.append(cell)
    return cells


def show(Q):
    for r in range(ROWS):
        print(" ".join(MAP[r][c] if MAP[r][c] in "PG" else ARROWS[Q[(r, c)].index(max(Q[(r, c)]))] for c in range(COLS)))


Q, log = train(300, alpha=0.5, epsilon=0.1, gamma=0.95, seed=11)
print("episodes  mean return  mean steps")
for first in range(0, 300, 50):
    part = log[first:first + 50]
    print(f"{first + 1}-{first + 50}", round(sum(e[0] for e in part) / 50, 3), round(sum(e[1] for e in part) / 50, 1))
show(Q)
print("route steps", len(route(Q)) - 1, "Q at start", round(max(Q[(4, 0)]), 3))
```

```output
episodes  mean return  mean steps
1-50 -0.009 13.2
51-100 0.518 8.0
101-150 0.47 7.2
151-200 0.574 7.6
201-250 0.617 7.6
251-300 0.462 7.4
< < v v > >
> < v < v ^
> > v < v v
> > > > > v
^ P P P P G
route steps 7 Q at start 0.523
```

The agent knew nothing. In the first 50 games it often falls, and the mean reward is near zero. By the hundredth game it nearly always gets through, in about 7–8 steps. The noise in the reward does not vanish: at `ε = 0.1` it still sometimes steps at random and falls into the pit.

Now compare with the last lesson. The learned value at the start is `0.523`, and value iteration, which knew the world, gave the same `0.523`. **Without a model of the world, from experience alone, the agent got the same answer.** On the real path the arrows are right. At the top of the field they look odd, such as `<` next to `v`. That is honest: the agent hardly ever goes there, the values remain nearly untouched, and it has no need to know them.

**Step 4. Q-learning and SARSA.** The formula contains `max`: the agent learns as if it will act perfectly from now on. Yet it walks ε-greedily and sometimes steps at random. **SARSA** differs by one word: instead of `max` it takes the action the agent really picks next. So it counts its own random mistakes in the estimate.

Add this and run it. Here `ε = 0.2`, so there are more random steps, and 30 runs. We look at the last 300 games of 400.

```python
print("rule   training return  falls of 300  route steps  highest row")
for name, sarsa in (("Q-learning", False), ("SARSA", True)):
    total, falls, lengths, tops = 0.0, 0, 0, 0
    for seed in range(30):
        Q, log = train(400, alpha=0.1, epsilon=0.2, gamma=0.95, seed=2000 + seed, sarsa=sarsa)
        total += sum(e[0] for e in log[100:]) / 300
        falls += sum(1 for e in log[100:] if e[2])
        cells = route(Q)
        lengths += len(cells) - 1
        tops += min(r for r, c in cells)
    print(name, round(total / 30, 3), round(falls / 30, 1), round(lengths / 30, 1), round(tops / 30, 2))
```

```output
rule   training return  falls of 300  route steps  highest row
Q-learning 0.208 78.9 7.0 3.0
SARSA 0.269 63.0 9.9 2.63
```

Q-learning learned the shortest path along the edge, 7 steps, but falls more often on it: 78.9 times in 300 games. SARSA picks a longer, safer path of nearly 10 steps, falls 63 times and earns more during training: `0.269` against `0.208`. The setup comes from Sutton and Barto's book, the "cliff" example. It does not mean SARSA is better. If randomness is switched off after training, Q-learning's path is truly the best. Which rule to choose depends on whether you pay for mistakes during training.

**Step 5. Where next.** A table works for 30 cells. In an Atari game the state is a picture, and a table is not enough. DQN (Mnih et al., 2013) replaced the table with a neural network: a picture goes in, and `Q` for each button comes out. The same formula, with a gradient step in place of a table write.

**Learn from the people who build this.** Chapter 6 of [Sutton and Barto](http://incompleteideas.net/book/the-book-2nd.html). Lectures 4 and 5 of [David Silver's course](https://www.davidsilver.uk/teaching/). Practice on real environments: the [Hugging Face Deep RL Course](https://huggingface.co/learn/deep-rl-course/unit1/introduction).

### Explore and practise

The lab has a real agent: a coloured triangle in a cell shows the `Q` of that action. Press Play and watch the first steps: a green trail appears around the goal. The "+100 games" button fast-forwards training. Click to place and remove walls: the agent must find a new path.

In the program, set `alpha=1.0`, then `alpha=0.01`. What happens to the curve?

### Question

How does Q-learning differ from SARSA?

### Options

- Q-learning uses the best next action in its estimate, and SARSA the action actually chosen.
- Q-learning knows the world's model and rewards in advance, and SARSA has only its experience.
- Q-learning updates its estimate at the game's end, and SARSA updates it after each step taken.

### Answer

1

### Explanation

Neither has a world model: both learn from experience. Both update the estimate after each step. The only difference is the future inside the formula: `max` for Q-learning and the chosen action for SARSA. Because of it SARSA counts its own random steps and stays further from the cliff.

### Limits

The world is small and noiseless, so Q-learning converges quickly here. The convergence theorem (Watkins and Dayan, 1992) requires every action to be tried infinitely often and the steps to shrink so that their sum is infinite while the sum of their squares is finite; my step is constant, so convergence here is an observed fact, not a proven one. With neural networks in place of a table there are few guarantees, and training can be unstable. The comparison numbers depend on `ε`, `α` and the pit's size, and 30 runs leave noticeable spread.

## Sources

- Richard S. Sutton, Andrew G. Barto, "Reinforcement Learning: An Introduction", 2nd ed., MIT Press (2018), chapter 6, Example 6.6 "Cliff Walking" read in the authors' free PDF on 2026-11-07 (Q-learning learns the path along the edge and sometimes falls off under ε-greedy with ε = 0.1, Sarsa learns the longer safer path); the numbers here are recomputed by the program: [book page](http://incompleteideas.net/book/the-book-2nd.html), [PDF](http://incompleteideas.net/book/RLbook2020.pdf)
- Christopher J. C. H. Watkins, Peter Dayan, "Q-learning", Machine Learning 8 (1992), abstract with the repeated sampling condition read 2026-11-03; the theorem and the conditions on the sums and sums of squares of the learning rates read in the scanned paper on 2026-11-07: [Springer](https://link.springer.com/article/10.1007/BF00992698), [PDF](https://www.gatsby.ucl.ac.uk/~dayan/papers/cjch.pdf)
- Volodymyr Mnih et al., "Playing Atari with Deep Reinforcement Learning", arXiv:1312.5602 (2013): [arXiv:1312.5602](https://arxiv.org/abs/1312.5602)
- David Silver, "Lectures on Reinforcement Learning", lectures 4 and 5 (the site refused the automated check on 2026-11-03): [course page](https://www.davidsilver.uk/teaching/)
- Hugging Face, Deep RL Course (page read 2026-11-03): [course](https://huggingface.co/learn/deep-rl-course/unit1/introduction)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
