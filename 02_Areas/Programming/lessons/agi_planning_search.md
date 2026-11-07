---
subject: programming
lesson_id: programming.agi_planning_search
level: advanced
languages: ru, en
source_checked: 2026-11-07
source_review_interval_days: 180
---

# Планирование: поиск по дереву / Planning: tree search

## Русский

### Простыми словами

Планировать значит перебирать ходы в уме до того, как сделать настоящий. Все варианты обычно не перебрать, поэтому умный поиск тратит время на самые многообещающие ходы и почти не тратит на явно плохие. Похоже на шахматиста, который не считает каждый ход до конца партии, а углубляется только в те, что выглядят интересно. Поиск по дереву методом Монте-Карло, MCTS, так и делает: доигрывает партии наугад и запоминает, какие ходы чаще ведут к победе. Этот же поиск стоит внутри AlphaZero и MuZero.

**Что нужно знать до.** Урок «Автоматы: пробовать новое или брать лучшее» (шаг 13): формула UCB и спор между исследованием и использованием. Урок «Модели мира: учиться в воображении» (шаг 20): зачем агенту модель мира. Урок «Клетчатый мир и уравнение Беллмана» (шаг 13).

**Если непонятно.** Если неясна формула выбора хода, вернись к UCB1 в уроке «Автоматы»: здесь та же надбавка за незнание. Если неясно, зачем вообще воображать ходы, перечитай шаг 1 урока «Модели мира». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Найти точную стратегию простой игры перебором, написать поиск MCTS и измерить, сколько симуляций ему нужно, чтобы найти верный ход. Понять, что добавили AlphaZero и MuZero. Нужно около 40 минут.

### Идея и механизм

**Шаг 1. Игра и точный ответ.** В куче 21 палочка. Игроки по очереди берут 1, 2 или 3, кто взял последнюю, выиграл. Куча *проигрышная* для того, чей ход, если любой его ход оставляет сопернику выигрышную. Руками: при 4 палочках возьмёшь 1, 2 или 3, и сопернику останется 3, 2 или 1, он заберёт всё. Значит, 4 проигрышная. А 5, 6 и 7 выигрышные: оставь сопернику 4. Создай файл `nano ~/ai-path/planning.py`, вставь и запусти.

```python
import math


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


# The game: a pile of sticks, each player takes 1, 2 or 3, whoever takes the last stick wins.
WIN = {0: False}
for n in range(1, 22):
    WIN[n] = any(not WIN[n - take] for take in (1, 2, 3) if take <= n)
print("losing piles for the player to move:", [n for n in range(1, 22) if not WIN[n]])


def perfect_moves(n):
    return [take for take in (1, 2, 3) if take <= n and not WIN[n - take]]


print("from 21 the winning move is to take", perfect_moves(21))
```

```output
losing piles for the player to move: [4, 8, 12, 16, 20]
from 21 the winning move is to take [1]
```

Проигрышные кучи делятся на 4. Из 21 нужно взять 1 и оставить 20. Это точный ответ, найденный полным перебором. В шахматах и го так нельзя: позиций больше, чем можно перебрать за жизнь Вселенной.

**Шаг 2. Поиск по дереву Монте-Карло.** MCTS не перебирает всё. Он повторяет *симуляцию* из четырёх частей. Выбор: от текущей кучи спускается по уже знакомым кучам, каждый раз беря ход с лучшей оценкой «доля побед плюс надбавка за незнание», как в UCB1. Расширение: добавляет первую незнакомую кучу. Доигрывание: доигрывает от неё случайными ходами до конца. Обратный ход: записывает результат во все кучи пути, причём для каждого игрока со своей стороны. Руками надбавку: при 100 посещениях родителя и 4 посещениях хода она `1,4 · √(ln 100 / 4) = 1,4 · √(4,605 / 4) ≈ 1,50`, а при 50 посещениях только `1,4 · √(4,605 / 50) ≈ 0,42`. Редкий ход получает шанс. Допиши и запусти.

```python
def rollout(n, rand):
    # random play to the end; returns True if the player to move at n wins
    mover = True
    while True:
        take = 1 + int(rand.next() * min(3, n))
        n -= take
        if n == 0:
            return mover
        mover = not mover


def mcts(n, simulations, rand, c=1.4):
    visits, wins = {}, {}
    for _ in range(simulations):
        path, node, mover_won = [], n, None
        while node > 0 and node in visits:
            total = visits[node]
            children = [node - take for take in (1, 2, 3) if take <= node]
            def score(child):
                if child == 0:
                    return math.inf
                if child not in visits:
                    return math.inf
                return (1 - wins[child] / visits[child]) + c * math.sqrt(math.log(total) / visits[child])
            best = max(children, key=lambda child: (score(child), -child))
            path.append(node)
            node = best
        if node == 0:
            mover_won = False
        else:
            visits[node], wins[node] = 0, 0.0
            mover_won = rollout(node, rand)
        path.append(node)
        for state in reversed(path):
            if state == 0:
                mover_won = not mover_won
                continue
            visits[state] = visits.get(state, 0) + 1
            wins[state] = wins.get(state, 0.0) + (1.0 if mover_won else 0.0)
            mover_won = not mover_won
    children = [(take, n - take) for take in (1, 2, 3) if take <= n]
    return max(children, key=lambda tc: (tc[1] == 0, visits.get(tc[1], 0)))[0], {take: visits.get(child, 0) for take, child in children}


for simulations in (10, 50, 200, 1000):
    right = 0
    for n in range(5, 22):
        if WIN[n]:
            move, _ = mcts(n, simulations, Rand(n))
            right += move in perfect_moves(n)
    print(f"{simulations} simulations: right move in {right} of 13 winning piles")
move, counts = mcts(21, 1000, Rand(21))
print("from 21 with 1000 simulations: take", move, "| visits per move", counts)
```

```output
10 simulations: right move in 8 of 13 winning piles
50 simulations: right move in 12 of 13 winning piles
200 simulations: right move in 13 of 13 winning piles
1000 simulations: right move in 13 of 13 winning piles
from 21 with 1000 simulations: take 1 | visits per move {1: 977, 2: 330, 3: 339}
```

Что ты увидел. При 10 симуляциях поиск верно играет только в 8 из 13 выигрышных куч, при 50 в 12, при 200 во всех. Из 21 после 1000 симуляций ход «взять 1» посещён намного чаще остальных: поиск сам сосредоточился на лучшем ходе. Одна оговорка: мы храним счёт по числу палочек, а не по пути, поэтому одна и та же куча, встреченная разными путями, считается вместе, и посещения ходов не складываются ровно в 1000.

**Шаг 3. Что добавили AlphaZero и MuZero.** Случайное доигрывание в сложной игре почти ничего не говорит. В 2017 году Silver и соавторы в AlphaZero заменили его нейросетью: она оценивает позицию и подсказывает, какие ходы смотреть первыми, а сама учится на партиях с собой. Так программа без человеческих партий научилась шахматам, сёги и го. В 2019 году Schrittwieser и соавторы в MuZero пошли дальше: сеть учит ещё и модель мира, поэтому правила игры поиску заранее не нужны, он планирует внутри выученной модели. Это прямое продолжение урока «Модели мира».

**Что здесь спорно.** Поиск блестяще работает там, где мир понятный и можно быстро проверить много вариантов: игры, задачи с проверкой. Насколько та же идея переносится на открытый мир, где модель мира неточна, а цель размыта, это открытый вопрос. Многие исследователи считают планирование необходимой частью пути к AGI, но как именно его делать, не решено.

**Учись у тех, кто это создаёт.** Книга Саттона и Барто, глава 8 о планировании и раздел о поиске по дереву Монте-Карло: [сайт книги](http://incompleteideas.net/book/the-book-2nd.html). Статьи [AlphaZero](https://arxiv.org/abs/1712.01815) и [MuZero](https://arxiv.org/abs/1911.08265).

### Исследуй и потренируйся

В тренажёре ниже полоса из 17 куч, от 5 до 21: зелёная значит, что поиск нашёл верный ход, красная значит, что ошибся. Столбики показывают, сколько раз поиск посетил каждый ход для выбранной кучи. Двигай число симуляций. В начале их 10, и часть куч красная. Найди наименьшее число симуляций, при котором все выигрышные кучи зелёные.

### Вопрос

При 10 симуляциях поиск ошибся в 5 из 13 выигрышных куч, а при 200 ни в одной. Почему?

### Варианты

- Оценки ходов строятся из случайных доигрываний, и при малом числе симуляций они ещё очень шумные
- При 10 симуляциях поиск не знает правил игры и поэтому выбирает ходы совершенно наугад
- Игра меняется от числа симуляций: при 200 симуляциях проигрышные кучи становятся другими

### Ответ

1

### Разбор

Каждое доигрывание это один бросок монетки с неравными шансами. По 10 броскам доли побед почти случайны, и надбавка за незнание ещё велика, поэтому выбор часто неверный. С ростом числа симуляций доли становятся точнее, и поиск сосредотачивается на лучшем ходе. Правила поиск знает всегда, а проигрышные кучи не зависят от поиска: они делятся на 4.

### Границы модели

Игра крошечная, и точный ответ известен, поэтому мы можем проверить поиск. В настоящих играх точного ответа нет. Наша версия хранит счёт по кучам, а не по пути, и использует случайное доигрывание без нейросети. Число симуляций, нужное для верной игры, зависит от посева и от постоянной `c = 1,4`.

## English

### In plain words

To plan means to try moves in your head before making a real one. All options usually cannot be tried, so a smart search spends its time on the most promising moves and almost none on clearly bad ones. It is like a chess player who does not calculate every move to the end of the game but goes deeper only into those that look interesting. Monte Carlo tree search, MCTS, does just that: it plays games out at random and remembers which moves lead to a win more often. The same search sits inside AlphaZero and MuZero.

**What to know first.** «Slot machines: explore or exploit» (step 13): the UCB formula and the explore-exploit dilemma. «World models: learning in imagination» (step 20): why an agent needs a world model. «A grid world and the Bellman equation» (step 13).

**If something is unclear.** If the move-selection formula is unclear, go back to UCB1 in «Slot machines»: the same bonus for not knowing is used here. If it is unclear why one should imagine moves at all, reread step 1 of «World models». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Find the exact strategy of a simple game by full search, write an MCTS search and measure how many simulations it needs to find the right move. Understand what AlphaZero and MuZero added. It takes about 40 minutes.

### Idea and mechanism

**Step 1. The game and the exact answer.** A pile holds 21 sticks. Players take turns taking 1, 2 or 3; whoever takes the last one wins. A pile is *losing* for the player to move if every move leaves the opponent a winning pile. By hand: with 4 sticks you take 1, 2 or 3, leaving the opponent 3, 2 or 1, and they take everything. So 4 is losing. And 5, 6 and 7 are winning: leave the opponent 4. Create the file `nano ~/ai-path/planning.py`, paste and run it.

```python
import math


class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


# The game: a pile of sticks, each player takes 1, 2 or 3, whoever takes the last stick wins.
WIN = {0: False}
for n in range(1, 22):
    WIN[n] = any(not WIN[n - take] for take in (1, 2, 3) if take <= n)
print("losing piles for the player to move:", [n for n in range(1, 22) if not WIN[n]])


def perfect_moves(n):
    return [take for take in (1, 2, 3) if take <= n and not WIN[n - take]]


print("from 21 the winning move is to take", perfect_moves(21))
```

```output
losing piles for the player to move: [4, 8, 12, 16, 20]
from 21 the winning move is to take [1]
```

The losing piles are multiples of 4. From 21 you must take 1 and leave 20. This is the exact answer, found by full search. In chess and Go this is impossible: there are more positions than could be searched in the lifetime of the universe.

**Step 2. Monte Carlo tree search.** MCTS does not search everything. It repeats a *simulation* in four parts. Selection: from the current pile it goes down through piles it already knows, each time taking the move with the best score "share of wins plus a bonus for not knowing", as in UCB1. Expansion: it adds the first unknown pile. Rollout: it plays on from there with random moves to the end. Backup: it writes the result into every pile on the path, from each player's own side. The bonus by hand: with 100 visits of the parent and 4 visits of the move it is `1.4 · √(ln 100 / 4) = 1.4 · √(4.605 / 4) ≈ 1.50`, while with 50 visits it is only `1.4 · √(4.605 / 50) ≈ 0.42`. A rare move gets a chance. Add this and run it.

```python
def rollout(n, rand):
    # random play to the end; returns True if the player to move at n wins
    mover = True
    while True:
        take = 1 + int(rand.next() * min(3, n))
        n -= take
        if n == 0:
            return mover
        mover = not mover


def mcts(n, simulations, rand, c=1.4):
    visits, wins = {}, {}
    for _ in range(simulations):
        path, node, mover_won = [], n, None
        while node > 0 and node in visits:
            total = visits[node]
            children = [node - take for take in (1, 2, 3) if take <= node]
            def score(child):
                if child == 0:
                    return math.inf
                if child not in visits:
                    return math.inf
                return (1 - wins[child] / visits[child]) + c * math.sqrt(math.log(total) / visits[child])
            best = max(children, key=lambda child: (score(child), -child))
            path.append(node)
            node = best
        if node == 0:
            mover_won = False
        else:
            visits[node], wins[node] = 0, 0.0
            mover_won = rollout(node, rand)
        path.append(node)
        for state in reversed(path):
            if state == 0:
                mover_won = not mover_won
                continue
            visits[state] = visits.get(state, 0) + 1
            wins[state] = wins.get(state, 0.0) + (1.0 if mover_won else 0.0)
            mover_won = not mover_won
    children = [(take, n - take) for take in (1, 2, 3) if take <= n]
    return max(children, key=lambda tc: (tc[1] == 0, visits.get(tc[1], 0)))[0], {take: visits.get(child, 0) for take, child in children}


for simulations in (10, 50, 200, 1000):
    right = 0
    for n in range(5, 22):
        if WIN[n]:
            move, _ = mcts(n, simulations, Rand(n))
            right += move in perfect_moves(n)
    print(f"{simulations} simulations: right move in {right} of 13 winning piles")
move, counts = mcts(21, 1000, Rand(21))
print("from 21 with 1000 simulations: take", move, "| visits per move", counts)
```

```output
10 simulations: right move in 8 of 13 winning piles
50 simulations: right move in 12 of 13 winning piles
200 simulations: right move in 13 of 13 winning piles
1000 simulations: right move in 13 of 13 winning piles
from 21 with 1000 simulations: take 1 | visits per move {1: 977, 2: 330, 3: 339}
```

What you saw. With 10 simulations the search plays right in only 8 of the 13 winning piles, with 50 in 12, with 200 in all. From 21, after 1000 simulations, the move "take 1" was visited far more often than the others: the search focused on the best move by itself. One caveat: we keep counts by the number of sticks rather than by the path, so the same pile met along different paths is counted together, and the move visits do not add up to exactly 1000.

**Step 3. What AlphaZero and MuZero added.** A random rollout says almost nothing in a complex game. In 2017 Silver and co-authors in AlphaZero replaced it with a neural network: it rates a position and suggests which moves to look at first, and it learns from games against itself. This way a program learned chess, shogi and Go without human games. In 2019 Schrittwieser and co-authors in MuZero went further: the network also learns a world model, so the search does not need the rules of the game in advance; it plans inside the learned model. This directly continues «World models».

**What is disputed.** Search works brilliantly where the world is clear and many options can be checked quickly: games, tasks with a check. How far the same idea carries over to the open world, where the world model is inexact and the goal vague, is an open question. Many researchers consider planning a necessary part of the road to AGI, but how exactly to do it is not settled.

**Learn from the people who build this.** Sutton and Barto's book, chapter 8 on planning and the section on Monte Carlo tree search: [book page](http://incompleteideas.net/book/the-book-2nd.html). The papers [AlphaZero](https://arxiv.org/abs/1712.01815) and [MuZero](https://arxiv.org/abs/1911.08265).

### Explore and practise

In the lab below there is a strip of 17 piles, from 5 to 21: green means the search found the right move, red means it erred. The bars show how many times the search visited each move for the chosen pile. Move the number of simulations. At the start there are 10, and some piles are red. Find the smallest number of simulations at which all winning piles are green.

### Question

With 10 simulations the search erred in 5 of the 13 winning piles, and with 200 in none. Why?

### Options

- Move scores are built from random rollouts, and with few simulations they are still very noisy
- With 10 simulations the search does not know the rules, so it picks its moves completely at random
- The game changes with the number of simulations: at 200 the losing piles become different ones

### Answer

1

### Explanation

Each rollout is one toss of an unfair coin. Over 10 tosses the win shares are nearly random and the bonus for not knowing is still large, so the choice is often wrong. As simulations grow the shares become more accurate, and the search focuses on the best move. The search always knows the rules, and the losing piles do not depend on the search: they are multiples of 4.

### Limits

The game is tiny and the exact answer is known, so we can check the search. Real games have no exact answer. Our version keeps counts by pile rather than by path and uses random rollouts without a neural network. The number of simulations needed for right play depends on the seed and on the constant `c = 1.4`.

## Sources

- Richard S. Sutton, Andrew G. Barto, "Reinforcement Learning: An Introduction", 2nd ed., MIT Press (2018), chapter 8 and section 8.11 "Monte Carlo Tree Search", which credits the central ideas of MCTS to Coulom (2006) and to Kocsis and Szepesvári (2006), read in the authors' free PDF on 2026-11-07: [book page](http://incompleteideas.net/book/the-book-2nd.html), [PDF](http://incompleteideas.net/book/RLbook2020.pdf)
- Peter Auer, Nicolò Cesa-Bianchi, Paul Fischer, "Finite-time Analysis of the Multiarmed Bandit Problem", Machine Learning 47 (2002), the UCB1 index read in Figure 1 on 2026-11-07: [Springer](https://link.springer.com/article/10.1023/A:1013689704352)
- David Silver et al., "Mastering Chess and Shogi by Self-Play with a General Reinforcement Learning Algorithm", arXiv:1712.01815 (2017), title read 2026-11-07: [arXiv:1712.01815](https://arxiv.org/abs/1712.01815)
- Julian Schrittwieser et al., "Mastering Atari, Go, Chess and Shogi by Planning with a Learned Model", arXiv:1911.08265 (2019), title read 2026-11-07: [arXiv:1911.08265](https://arxiv.org/abs/1911.08265)
- The game, the program and all numbers were written for this lesson on 2026-11-07.
