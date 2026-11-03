---
subject: programming
lesson_id: programming.rl_mdp_bellman
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Клетчатый мир и уравнение Беллмана / A grid world and the Bellman equation

## Русский

### Цель

Понять, что такое состояние, политика и ценность. Посчитать ценность клетки руками по уравнению Беллмана, запустить итерацию ценности и увидеть, как ценность идёт волной от цели, а в объёме становится настоящей поверхностью. Нужно около 50 минут.

### Идея и механизм

**Шаг 1. Новые слова.** У автоматов из прошлого урока не было памяти. Теперь ход меняет положение агента, и прошлые решения важны.

- **Состояние**: где агент сейчас. Здесь это клетка.
- **Действие**: идти вверх, вправо, вниз или влево.
- **Награда**: число за вход в клетку.
- **Политика**: правило, что делать в каждой клетке.
- **Ценность** `V`: какую сумму будущих наград ждать из этой клетки, если дальше действовать по лучшей политике.

Такая запись мира называется **марковским процессом принятия решений**: следующее состояние зависит только от текущего и от действия, а не от всей истории.

Мир такой: 5 строк, 6 столбцов. Старт `S` внизу слева, цель `G` внизу справа, между ними яма `P`. Вход в цель даёт `+1`, в яму `−1`, каждый обычный шаг стоит `−0,04`, чтобы агент не гулял. На цели и в яме игра кончается, поэтому ценность там 0: дальше ничего не будет.

Будущее ценится меньше настоящего. Каждый следующий шаг умножается на **скидку** `γ = 0,95`.

**Шаг 2. Ценность руками.** Иди от цели назад.

- Клетка над целью: шаг вниз даёт `+1`, дальше ничего. `V = 1`.
- Клетка левее неё: шаг стоит `−0,04`, затем ценность соседа со скидкой. `V = −0,04 + 0,95 · 1 = 0,91`.
- Ещё левее: `−0,04 + 0,95 · 0,91 = 0,82`.
- Ещё левее: `−0,04 + 0,95 · 0,82 = 0,74`.

Это и есть **уравнение Беллмана**: ценность клетки равна награде за лучший шаг плюс ценность соседа со скидкой. Его сила в том, что длинная сумма будущих наград превращается в связь между соседними клетками.

**Шаг 3. Проскальзывание руками.** Добавим мир, где действие не всегда выходит. При проскальзывании `0,2` агент идёт куда хотел с вероятностью `0,8`, а вбок по `0,1` в каждую сторону. Тогда нужно среднее по исходам. Возьми клетку прямо над ямой с соседями `0,82` справа и `0,67` сверху. Идём вправо:

`0,8 · (−0,04 + 0,95 · 0,82) + 0,1 · (−0,04 + 0,95 · 0,67) + 0,1 · (−1) = 0,591 + 0,060 − 0,1 = 0,55`

Без проскальзывания было `0,74`. Близость ямы стоит примерно `0,19`. Полная формула:

`V(s) = max по действиям a [ Σ p(s′ | s, a) · (r(s′) + γ · V(s′)) ]`

**Шаг 4. Итерация ценности.** Формула связывает `V` с самой собой. Решить её можно просто: начни с нулей и много раз обнови все клетки по формуле. Создай файл `nano ~/ai-path/grid.py`, вставь и запусти. Печатаем три первых прохода.

```python
MAP = ["......",
       "......",
       "......",
       "......",
       "SPPPPG"]
ROWS, COLS = len(MAP), len(MAP[0])
MOVES = {"^": (-1, 0), ">": (0, 1), "v": (1, 0), "<": (0, -1)}
SIDES = {"^": "<>", "v": "<>", "<": "^v", ">": "^v"}
STEP_COST = -0.04


def is_terminal(cell):
    return MAP[cell[0]][cell[1]] in "PG"


def reward(cell):
    return {"G": 1.0, "P": -1.0}.get(MAP[cell[0]][cell[1]], STEP_COST)


def move(cell, action):
    r, c = cell[0] + MOVES[action][0], cell[1] + MOVES[action][1]
    return (r, c) if 0 <= r < ROWS and 0 <= c < COLS else cell


def outcomes(cell, action, slip):
    result = [(1 - slip, move(cell, action))]
    if slip > 0:
        result += [(slip / 2, move(cell, side)) for side in SIDES[action]]
    return result


def action_value(cell, action, V, gamma, slip):
    return sum(p * (reward(n) + gamma * V[n]) for p, n in outcomes(cell, action, slip))


CELLS = [(r, c) for r in range(ROWS) for c in range(COLS)]


def show(V):
    for r in range(ROWS):
        print(" ".join(f"{V[(r, c)]:6.2f}" for c in range(COLS)))


V = {cell: 0.0 for cell in CELLS}
for sweep in range(1, 4):
    V = {cell: 0.0 if is_terminal(cell) else max(action_value(cell, a, V, 0.95, 0.0) for a in MOVES) for cell in CELLS}
    print("sweep", sweep)
    show(V)
```

```output
sweep 1
 -0.04  -0.04  -0.04  -0.04  -0.04  -0.04
 -0.04  -0.04  -0.04  -0.04  -0.04  -0.04
 -0.04  -0.04  -0.04  -0.04  -0.04  -0.04
 -0.04  -0.04  -0.04  -0.04  -0.04   1.00
 -0.04   0.00   0.00   0.00   0.00   0.00
sweep 2
 -0.08  -0.08  -0.08  -0.08  -0.08  -0.08
 -0.08  -0.08  -0.08  -0.08  -0.08  -0.08
 -0.08  -0.08  -0.08  -0.08  -0.08   0.91
 -0.08  -0.08  -0.08  -0.08   0.91   1.00
 -0.08   0.00   0.00   0.00   0.00   0.00
sweep 3
 -0.11  -0.11  -0.11  -0.11  -0.11  -0.11
 -0.11  -0.11  -0.11  -0.11  -0.11   0.82
 -0.11  -0.11  -0.11  -0.11   0.82   0.91
 -0.11  -0.11  -0.11   0.82   0.91   1.00
 -0.11   0.00   0.00   0.00   0.00   0.00
```

Смотри на цифры. После первого прохода о цели знает только клетка над ней. После второго ещё две, после третьего ещё три. **Сведения о цели расходятся на одну клетку за проход**, потому что формула заглядывает только на шаг вперёд. Яма и цель показывают `0,00`, как и договаривались: там игра окончена.

**Шаг 5. До конца.** Допиши и запусти. Останавливаемся, когда за проход ничего не меняется сильнее чем на `0,0001`.

```python
def value_iteration(gamma, slip, tolerance=1e-4):
    V = {cell: 0.0 for cell in CELLS}
    sweeps = 0
    while True:
        sweeps += 1
        new = {cell: 0.0 if is_terminal(cell) else max(action_value(cell, a, V, gamma, slip) for a in MOVES) for cell in CELLS}
        change = max(abs(new[cell] - V[cell]) for cell in CELLS)
        V = new
        if change < tolerance:
            return V, sweeps


def greedy(cell, V, gamma, slip):
    return max(MOVES, key=lambda a: round(action_value(cell, a, V, gamma, slip), 9))


def show_policy(V, gamma, slip):
    for r in range(ROWS):
        print(" ".join(MAP[r][c] if is_terminal((r, c)) else greedy((r, c), V, gamma, slip) for c in range(COLS)))


V, sweeps = value_iteration(0.95, 0.0)
print("sweeps", sweeps)
show(V)
show_policy(V, 0.95, 0.0)
```

```output
sweeps 10
  0.39   0.46   0.52   0.59   0.67   0.74
  0.46   0.52   0.59   0.67   0.74   0.82
  0.52   0.59   0.67   0.74   0.82   0.91
  0.59   0.67   0.74   0.82   0.91   1.00
  0.52   0.00   0.00   0.00   0.00   0.00
> > > > > v
> > > > > v
> > > > > v
> > > > > v
^ P P P P G
```

Всего 10 проходов. Ценность старта `0,52`, это число сошлось с расчётом руками: `−0,04 + 0,95 · 0,59 = 0,52`. Ниже напечатана **политика**: в каждой клетке стрелка на лучшего соседа. Её не задавали, она получилась сама из ценности. Маршрут идёт прямо по краю ямы, потому что мир надёжен.

**Шаг 6. Скользкий мир.** Допиши и запусти.

```python
def route(V, gamma, slip):
    cell, cells = (4, 0), [(4, 0)]
    while not is_terminal(cell):
        cell = move(cell, greedy(cell, V, gamma, slip))
        if cell in cells:
            return None
        cells.append(cell)
    return cells


print("slip  V(S)  sweeps  steps  highest row of the route")
for slip in (0.0, 0.1, 0.2, 0.3, 0.4):
    V, sweeps = value_iteration(0.95, slip)
    cells = route(V, 0.95, slip)
    print(slip, round(V[(4, 0)], 3), sweeps, *((len(cells) - 1, min(r for r, c in cells)) if cells else ("waits at the wall", "-")))
for slip in (0.2, 0.3):
    V, _ = value_iteration(0.95, slip)
    print("slip", slip)
    show_policy(V, 0.95, slip)
```

```output
slip  V(S)  sweeps  steps  highest row of the route
0.0 0.523 10 7 3
0.1 0.239 20 9 2
0.2 0.065 26 9 2
0.3 -0.112 42 waits at the wall -
0.4 -0.178 51 waits at the wall -
slip 0.2
> > > > > v
> > > > > v
> > > > > v
^ ^ ^ ^ > v
^ P P P P G
slip 0.3
> > > > > v
> > > > > v
> > > > > v
^ ^ ^ ^ ^ v
< P P P P G
```

При проскальзывании `0,1` и `0,2` маршрут уходит на строку выше, отдаляясь от ямы: 9 шагов вместо 7. Никто этого не программировал, такое поведение следует из формулы. При `0,3` происходит странное: на старте стрелка смотрит **влево, в стену**. Агент стоит и платит `−0,04`, ожидая, что его снесёт вверх, ведь идти вверх рискованно: может снести вправо, в яму. Это не ошибка программы, а лучшая политика именно в этой модели. Так оптимизация находит лазейки, и об этом будет урок о безопасности.

**Шаг 7. Плохая политика и скидка.** Без `max` та же формула оценивает любую заданную политику. Допиши и запусти.

```python
def evaluate_random(gamma, slip, tolerance=1e-4):
    V = {cell: 0.0 for cell in CELLS}
    while True:
        new = {cell: 0.0 if is_terminal(cell) else sum(action_value(cell, a, V, gamma, slip) for a in MOVES) / 4 for cell in CELLS}
        if max(abs(new[cell] - V[cell]) for cell in CELLS) < tolerance:
            return new
        V = new


print("random policy V(S)", round(evaluate_random(0.95, 0.0)[(4, 0)], 3))
print("best policy V(S)", round(value_iteration(0.95, 0.0)[0][(4, 0)], 3))
for gamma in (0.5, 0.8, 0.95, 0.99):
    print("gamma", gamma, "sweeps", value_iteration(gamma, 0.2)[1], "V(S)", round(value_iteration(gamma, 0.2)[0][(4, 0)], 3))
```

```output
random policy V(S) -0.936
best policy V(S) 0.523
gamma 0.5 sweeps 12 V(S) -0.08
gamma 0.8 sweeps 24 V(S) -0.159
gamma 0.95 sweeps 26 V(S) 0.065
gamma 0.99 sweeps 32 V(S) 0.282
```

Случайная политика стоит `−0,936`, а лучшая `0,523`. Скидка меняет дальновидность. При `γ = 0,5` награда за 7 шагов отсюда умножается на `0,5⁶`, почти на ноль, поэтому агент цель почти не видит. Чем ближе `γ` к 1, тем больше проходов нужно: сведениям надо пройти дальше.

**Учись у тех, кто это создаёт.** Главы 3 и 4 книги [Sutton и Barto](http://incompleteideas.net/book/the-book-2nd.html). Лекции 2 и 3 курса [David Silver](https://www.davidsilver.uk/teaching/) медленно разбирают ровно это уравнение. Глава о марковских процессах в [Stanford CS234](https://web.stanford.edu/class/cs234/).

### Исследуй и потренируйся

В тренажёре настоящая поверхность ценности: высота башни это настоящее `V`, стрелки это политика, белая линия это маршрут. Для ямы и цели высота показывает их награду, чтобы их было видно. Жми «Один проход» и смотри, как волна идёт от цели. Двигай проскальзывание и скидку, крути сцену мышью.

В программе перенеси яму: поставь `S` в центр поля. Что станет с поверхностью?

### Вопрос

Почему после первого прохода о цели знает только соседняя клетка?

### Варианты

- Формула смотрит на шаг вперёд, поэтому сведения идут от цели по клетке за проход.
- Формула обновляет одну клетку за проход, а до остальных очередь ещё не дошла.
- Скидка обнуляет далёкие награды, поэтому дальше одной клетки цели не видно вовсе.

### Ответ

1

### Разбор

За проход обновляются все клетки, а не одна. Скидка лишь уменьшает далёкие награды, но не обнуляет их: после 10 проходов старт ценность получает. Причина в том, что формула смотрит только на соседей, а у соседей до этого прохода были нули.

### Границы модели

Здесь агент заранее знает всю модель мира: куда ведёт каждое действие и какие там награды. Обычно это не так, и следующий урок снимает это условие. В мире всего 30 клеток, поэтому хватает таблицы. В настоящих задачах состояний больше, чем можно перебрать, и ценность приближают нейросетью. Награды и проскальзывание выбрал я, и лазейка у стены зависит от этих чисел.

## English

### Goal

Understand state, policy and value. Compute a cell's value by hand from the Bellman equation, run value iteration, and watch value spread as a wave from the goal and become a real surface in 3D. It takes about 50 minutes.

### Idea and mechanism

**Step 1. New words.** The machines of the last lesson had no memory. Now a move changes where the agent is, and past decisions matter.

- **State**: where the agent is now. Here it is a cell.
- **Action**: go up, right, down or left.
- **Reward**: a number for entering a cell.
- **Policy**: a rule for what to do in each cell.
- **Value** `V`: what sum of future rewards to expect from this cell if the agent then acts by the best policy.

This description of a world is called a **Markov decision process**: the next state depends only on the current one and the action, not on the whole history.

The world: 5 rows, 6 columns. Start `S` at bottom left, goal `G` at bottom right, a pit `P` between them. Entering the goal gives `+1`, the pit `−1`, and each ordinary step costs `−0.04`, so that the agent does not wander. The game ends at the goal and in the pit, so their value is 0: nothing follows.

The future counts for less than the present. Each next step is multiplied by the **discount** `γ = 0.95`.

**Step 2. Value by hand.** Go back from the goal.

- The cell above the goal: stepping down gives `+1`, then nothing. `V = 1`.
- The cell to its left: a step costs `−0.04`, then the neighbour's value, discounted. `V = −0.04 + 0.95 · 1 = 0.91`.
- Further left: `−0.04 + 0.95 · 0.91 = 0.82`.
- Further left: `−0.04 + 0.95 · 0.82 = 0.74`.

This is the **Bellman equation**: a cell's value equals the reward for the best step plus the neighbour's discounted value. Its power is that a long sum of future rewards turns into a link between neighbouring cells.

**Step 3. Slipping by hand.** Now a world where an action does not always work. With slip `0.2` the agent goes where it wanted with probability `0.8`, and sideways with `0.1` each way. Then we need the mean over outcomes. Take the cell right above the pit, with neighbours `0.82` to the right and `0.67` above. Going right:

`0.8 · (−0.04 + 0.95 · 0.82) + 0.1 · (−0.04 + 0.95 · 0.67) + 0.1 · (−1) = 0.591 + 0.060 − 0.1 = 0.55`

Without slipping it was `0.74`. Being near the pit costs about `0.19`. The full formula:

`V(s) = max over actions a [ Σ p(s′ | s, a) · (r(s′) + γ · V(s′)) ]`

**Step 4. Value iteration.** The formula links `V` to itself. Solving it is simple: start from zeros and update all cells by the formula many times. Create the file `nano ~/ai-path/grid.py`, paste and run it. We print the first three sweeps.

```python
MAP = ["......",
       "......",
       "......",
       "......",
       "SPPPPG"]
ROWS, COLS = len(MAP), len(MAP[0])
MOVES = {"^": (-1, 0), ">": (0, 1), "v": (1, 0), "<": (0, -1)}
SIDES = {"^": "<>", "v": "<>", "<": "^v", ">": "^v"}
STEP_COST = -0.04


def is_terminal(cell):
    return MAP[cell[0]][cell[1]] in "PG"


def reward(cell):
    return {"G": 1.0, "P": -1.0}.get(MAP[cell[0]][cell[1]], STEP_COST)


def move(cell, action):
    r, c = cell[0] + MOVES[action][0], cell[1] + MOVES[action][1]
    return (r, c) if 0 <= r < ROWS and 0 <= c < COLS else cell


def outcomes(cell, action, slip):
    result = [(1 - slip, move(cell, action))]
    if slip > 0:
        result += [(slip / 2, move(cell, side)) for side in SIDES[action]]
    return result


def action_value(cell, action, V, gamma, slip):
    return sum(p * (reward(n) + gamma * V[n]) for p, n in outcomes(cell, action, slip))


CELLS = [(r, c) for r in range(ROWS) for c in range(COLS)]


def show(V):
    for r in range(ROWS):
        print(" ".join(f"{V[(r, c)]:6.2f}" for c in range(COLS)))


V = {cell: 0.0 for cell in CELLS}
for sweep in range(1, 4):
    V = {cell: 0.0 if is_terminal(cell) else max(action_value(cell, a, V, 0.95, 0.0) for a in MOVES) for cell in CELLS}
    print("sweep", sweep)
    show(V)
```

```output
sweep 1
 -0.04  -0.04  -0.04  -0.04  -0.04  -0.04
 -0.04  -0.04  -0.04  -0.04  -0.04  -0.04
 -0.04  -0.04  -0.04  -0.04  -0.04  -0.04
 -0.04  -0.04  -0.04  -0.04  -0.04   1.00
 -0.04   0.00   0.00   0.00   0.00   0.00
sweep 2
 -0.08  -0.08  -0.08  -0.08  -0.08  -0.08
 -0.08  -0.08  -0.08  -0.08  -0.08  -0.08
 -0.08  -0.08  -0.08  -0.08  -0.08   0.91
 -0.08  -0.08  -0.08  -0.08   0.91   1.00
 -0.08   0.00   0.00   0.00   0.00   0.00
sweep 3
 -0.11  -0.11  -0.11  -0.11  -0.11  -0.11
 -0.11  -0.11  -0.11  -0.11  -0.11   0.82
 -0.11  -0.11  -0.11  -0.11   0.82   0.91
 -0.11  -0.11  -0.11   0.82   0.91   1.00
 -0.11   0.00   0.00   0.00   0.00   0.00
```

Look at the digits. After the first sweep only the cell above the goal knows about it. After the second, two more, after the third, three more. **Knowledge of the goal spreads one cell per sweep**, because the formula looks only one step ahead. The pit and the goal show `0.00`, as agreed: the game is over there.

**Step 5. To the end.** Add this and run it. We stop when a sweep changes nothing by more than `0.0001`.

```python
def value_iteration(gamma, slip, tolerance=1e-4):
    V = {cell: 0.0 for cell in CELLS}
    sweeps = 0
    while True:
        sweeps += 1
        new = {cell: 0.0 if is_terminal(cell) else max(action_value(cell, a, V, gamma, slip) for a in MOVES) for cell in CELLS}
        change = max(abs(new[cell] - V[cell]) for cell in CELLS)
        V = new
        if change < tolerance:
            return V, sweeps


def greedy(cell, V, gamma, slip):
    return max(MOVES, key=lambda a: round(action_value(cell, a, V, gamma, slip), 9))


def show_policy(V, gamma, slip):
    for r in range(ROWS):
        print(" ".join(MAP[r][c] if is_terminal((r, c)) else greedy((r, c), V, gamma, slip) for c in range(COLS)))


V, sweeps = value_iteration(0.95, 0.0)
print("sweeps", sweeps)
show(V)
show_policy(V, 0.95, 0.0)
```

```output
sweeps 10
  0.39   0.46   0.52   0.59   0.67   0.74
  0.46   0.52   0.59   0.67   0.74   0.82
  0.52   0.59   0.67   0.74   0.82   0.91
  0.59   0.67   0.74   0.82   0.91   1.00
  0.52   0.00   0.00   0.00   0.00   0.00
> > > > > v
> > > > > v
> > > > > v
> > > > > v
^ P P P P G
```

Only 10 sweeps. The start's value is `0.52`, and it agrees with the hand calculation: `−0.04 + 0.95 · 0.59 = 0.52`. Below is the printed **policy**: in each cell an arrow to the best neighbour. Nobody specified it; it came out of the value by itself. The route runs right along the edge of the pit, because the world is reliable.

**Step 6. A slippery world.** Add this and run it.

```python
def route(V, gamma, slip):
    cell, cells = (4, 0), [(4, 0)]
    while not is_terminal(cell):
        cell = move(cell, greedy(cell, V, gamma, slip))
        if cell in cells:
            return None
        cells.append(cell)
    return cells


print("slip  V(S)  sweeps  steps  highest row of the route")
for slip in (0.0, 0.1, 0.2, 0.3, 0.4):
    V, sweeps = value_iteration(0.95, slip)
    cells = route(V, 0.95, slip)
    print(slip, round(V[(4, 0)], 3), sweeps, *((len(cells) - 1, min(r for r, c in cells)) if cells else ("waits at the wall", "-")))
for slip in (0.2, 0.3):
    V, _ = value_iteration(0.95, slip)
    print("slip", slip)
    show_policy(V, 0.95, slip)
```

```output
slip  V(S)  sweeps  steps  highest row of the route
0.0 0.523 10 7 3
0.1 0.239 20 9 2
0.2 0.065 26 9 2
0.3 -0.112 42 waits at the wall -
0.4 -0.178 51 waits at the wall -
slip 0.2
> > > > > v
> > > > > v
> > > > > v
^ ^ ^ ^ > v
^ P P P P G
slip 0.3
> > > > > v
> > > > > v
> > > > > v
^ ^ ^ ^ ^ v
< P P P P G
```

With slip `0.1` and `0.2` the route moves one row up, away from the pit: 9 steps rather than 7. Nobody programmed this; the behaviour follows from the formula. At `0.3` something odd happens: at the start the arrow points **left, into the wall**. The agent stands and pays `−0.04`, waiting to be carried upwards, because going up is risky: it could slip right, into the pit. This is not a bug but the best policy in this particular model. That is how optimization finds loopholes, and the safety lesson returns to it.

**Step 7. A poor policy and the discount.** Without `max` the same formula evaluates any given policy. Add this and run it.

```python
def evaluate_random(gamma, slip, tolerance=1e-4):
    V = {cell: 0.0 for cell in CELLS}
    while True:
        new = {cell: 0.0 if is_terminal(cell) else sum(action_value(cell, a, V, gamma, slip) for a in MOVES) / 4 for cell in CELLS}
        if max(abs(new[cell] - V[cell]) for cell in CELLS) < tolerance:
            return new
        V = new


print("random policy V(S)", round(evaluate_random(0.95, 0.0)[(4, 0)], 3))
print("best policy V(S)", round(value_iteration(0.95, 0.0)[0][(4, 0)], 3))
for gamma in (0.5, 0.8, 0.95, 0.99):
    print("gamma", gamma, "sweeps", value_iteration(gamma, 0.2)[1], "V(S)", round(value_iteration(gamma, 0.2)[0][(4, 0)], 3))
```

```output
random policy V(S) -0.936
best policy V(S) 0.523
gamma 0.5 sweeps 12 V(S) -0.08
gamma 0.8 sweeps 24 V(S) -0.159
gamma 0.95 sweeps 26 V(S) 0.065
gamma 0.99 sweeps 32 V(S) 0.282
```

The random policy is worth `−0.936`, the best one `0.523`. The discount changes how far the agent sees. At `γ = 0.5` a reward 7 steps away is multiplied by `0.5⁶`, nearly zero, so the agent barely sees the goal. The closer `γ` is to 1, the more sweeps are needed: knowledge must travel further.

**Learn from the people who build this.** Chapters 3 and 4 of [Sutton and Barto](http://incompleteideas.net/book/the-book-2nd.html). Lectures 2 and 3 of [David Silver's course](https://www.davidsilver.uk/teaching/) go slowly through exactly this equation. The Markov process material of [Stanford CS234](https://web.stanford.edu/class/cs234/).

### Explore and practise

The lab shows a real value surface: a tower's height is the real `V`, arrows are the policy, the white line is the route. For the pit and the goal the height shows their reward, so that they are visible. Press "One sweep" and watch the wave leave the goal. Move the slip and the discount, and turn the scene with the mouse.

In the program, move the pit: put `S` in the middle of the field. What happens to the surface?

### Question

Why does only the neighbouring cell know about the goal after the first sweep?

### Options

- The formula looks one step ahead, so knowledge leaves the goal one cell per sweep.
- The formula updates one cell per sweep, and the other cells have not had a turn yet.
- The discount zeroes distant rewards, so the goal is invisible beyond a single cell.

### Answer

1

### Explanation

A sweep updates all cells, not one. The discount only shrinks distant rewards and does not zero them: after 10 sweeps the start does get value. The reason is that the formula looks only at neighbours, and before this sweep those neighbours held zeros.

### Limits

Here the agent knows the whole model of the world in advance: where each action leads and what rewards are there. Usually that is not so, and the next lesson removes this condition. The world has only 30 cells, so a table is enough. Real tasks have more states than can be enumerated, and value is approximated by a neural network. I chose the rewards and the slip, and the wall loophole depends on these numbers.

## Sources

- Richard S. Sutton, Andrew G. Barto, "Reinforcement Learning: An Introduction", 2nd ed., MIT Press (2018), chapters 3 and 4, recalled from the book; the site answered with an error on the check of 2026-11-03, and the numbers here are recomputed by the program: [book page](http://incompleteideas.net/book/the-book-2nd.html)
- David Silver, "Lectures on Reinforcement Learning", lectures 2 and 3 (the site refused the automated check on 2026-11-03): [course page](https://www.davidsilver.uk/teaching/)
- Stanford CS234, "Reinforcement Learning": [course page](https://web.stanford.edu/class/cs234/)
- The world, the program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
