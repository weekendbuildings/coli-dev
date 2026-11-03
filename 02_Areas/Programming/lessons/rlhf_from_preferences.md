---
subject: programming
lesson_id: programming.rlhf_from_preferences
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# RLHF: обучение на предпочтениях людей / RLHF: learning from human preferences

## Русский

### Цель

Пройти весь путь RLHF своими руками: собрать сравнения ответов, обучить модель награды и сдвинуть маленькую языковую модель. Затем увидеть главную ловушку: награда растёт, а настоящее качество падает. Нужно около 50 минут.

### Идея и механизм

**Шаг 1. Зачем это нужно.** Голая языковая модель продолжает текст, а не помогает. Нам нужно, чтобы она писала то, что нравится людям. Но формулу «хорошего ответа» никто написать не может, а оценить ответ числом людям трудно: один ставит 7, другой 4. Зато сравнить два ответа и сказать, какой лучше, человек может легко.

RLHF поэтому состоит из трёх шагов: люди сравнивают пары ответов, **модель награды** учится предсказывать их выбор, а языковая модель сдвигается в сторону высокой награды. Здесь на втором шаге работает REINFORCE из прошлого урока.

**Шаг 2. Сравнения.** Наша языковая модель очень простая: для каждого слова таблица вероятностей следующего слова. Настоящую заменять ей нельзя, зато весь путь виден и идёт за секунду. Человека в программе заменяет функция `person`: она любит слова «спасибо», «пожалуйста» и «добрый», не любит «дурак» и «плохой» и штрафует повтор слова на 2. В тренажёре выбирать будешь ты сам. Создай файл `nano ~/ai-path/rlhf.py`, вставь и запусти.

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


CORPUS = """кот ест рыбу
спасибо кот ест рыбу
пёс ищет дом
плохой пёс ест кашу
дурак ищет кашу
мама любит кота
спасибо мама любит кота
папа несёт воду
пожалуйста несёт воду папа
добрый дед несёт кашу
плохой дед ищет рыбу
дурак несёт воду
гусь ест траву
добрый гусь ищет дом
пожалуйста кот несёт рыбу
очень добрый пёс любит маму
очень плохой гусь ест кашу""".split("\n")
WORDS = sorted({w for line in CORPUS for w in line.split()}) + ["."]
INDEX = {w: i for i, w in enumerate(WORDS)}
START, V = len(WORDS), len(WORDS)
GOOD, BAD = {"спасибо", "пожалуйста", "добрый"}, {"дурак", "плохой"}


def start_table():
    table = [[0.1] * V for _ in range(V + 1)]
    for line in CORPUS:
        previous = START
        for word in line.split() + ["."]:
            table[previous][INDEX[word]] += 1.0
            previous = INDEX[word]
    return [[math.log(c / sum(row)) for c in row] for row in table]


def probabilities(row):
    top = max(row)
    weights = [math.exp(v - top) for v in row]
    total = sum(weights)
    return [w / total for w in weights]


def sample(table, rand, limit=10):
    previous, words = START, []
    while len(words) < limit:
        p, pick, total = probabilities(table[previous]), rand.next(), 0.0
        for v, q in enumerate(p):
            total += q
            if pick <= total:
                break
        if WORDS[v] == ".":
            break
        words.append(WORDS[v])
        previous = v
    return words


def person(words):
    score = sum((w in GOOD) - (w in BAD) for w in words)
    return score - 2 * (len(words) - len(set(words)))


policy0 = start_table()
rand = Rand(5)
for _ in range(5):
    print(" ".join(sample(policy0, rand)))
pairs = []
for _ in range(200):
    a, b = sample(policy0, rand), sample(policy0, rand)
    if person(a) != person(b):
        pairs.append((a, b) if person(a) > person(b) else (b, a))
print("pairs with a clear winner", len(pairs))
```

```output
пожалуйста ест рыбу пёс ищет дом пёс пожалуйста кот ест
дурак ищет папа кашу
спасибо добрый спасибо кот ест рыбу
дурак ищет
добрый дед маму плохой гусь ест
pairs with a clear winner 162
```

**Шаг 3. Модель награды руками.** У каждого слова вес, а награда предложения это сумма весов. Пусть награда лучшего ответа 1, а худшего 0. Вероятность, что модель угадает выбор человека, равна `1 / (1 + e^(0 − 1)) = 0,73`. Чем ближе к единице, тем лучше. Обновление сдвигает веса слов лучшего ответа вверх, а худшего вниз на `0,02 · (1 − 0,73)`. Это логистическая регрессия на парах. Допиши и запусти.

```python
weight = {w: 0.0 for w in WORDS}


def reward(words):
    return sum(weight[w] for w in words)


for _ in range(60):
    for better, worse in pairs:
        chance = 1 / (1 + math.exp(reward(worse) - reward(better)))
        for w in better:
            weight[w] += 0.02 * (1 - chance)
        for w in worse:
            weight[w] -= 0.02 * (1 - chance)
right = sum(reward(a) > reward(b) for a, b in pairs)
print("reward model agrees with the person on", right, "of", len(pairs))
print(sorted(((round(v, 2), w) for w, v in weight.items() if w != "."), reverse=True))
print("spasibo x3:", round(reward(["спасибо"] * 3), 2), "person:", person(["спасибо"] * 3))
```

```output
reward model agrees with the person on 140 of 162
[(2.5, 'спасибо'), (1.38, 'добрый'), (0.57, 'маму'), (0.38, 'траву'), (0.27, 'пожалуйста'), (0.05, 'рыбу'), (0.03, 'пёс'), (-0.23, 'кашу'), (-0.24, 'кот'), (-0.3, 'ест'), (-0.37, 'мама'), (-0.46, 'кота'), (-0.6, 'дед'), (-0.61, 'несёт'), (-0.63, 'воду'), (-0.65, 'любит'), (-0.67, 'ищет'), (-0.85, 'очень'), (-1.08, 'папа'), (-1.66, 'дом'), (-1.75, 'гусь'), (-2.36, 'дурак'), (-2.4, 'плохой')]
spasibo x3: 7.5 person: -1
```

Модель награды согласна с человеком в 140 случаях из 162. На первом месте «спасибо» с весом 2,5, это верно. Но посмотри дальше: «маму» и «траву» получили плюс, хотя человек о них не сказал ни слова. Они просто чаще оказывались в выбранных ответах. **Модель награды учит не вкус, а его приближение.** И последняя строка: три раза «спасибо» она оценивает в `7,5`, а человек в `−1`. Повторов в обучающих парах почти не было, и модель о них ничего не знает.

**Шаг 4. Сдвигаем модель.** Каждый шаг берём предложение, считаем его награду минус среднюю и применяем REINFORCE к строкам таблицы: то, что принесло больше обычного, становится вероятнее. Печатаем каждые 200 шагов: шаг, средняя награда по модели награды, средняя оценка человека, сколько разных из 300 предложений и их длина. Допиши и запусти.

```python
def shift(updates, rate, kl_weight, seed):
    table = [row[:] for row in policy0]
    rand, base, log = Rand(seed), 0.0, []
    for update in range(updates + 1):
        if update % 200 == 0:
            check = Rand(77)
            texts = [sample(table, check) for _ in range(300)]
            log.append((update, round(sum(map(reward, texts)) / 300, 2), round(sum(map(person, texts)) / 300, 2),
                        len({" ".join(t) for t in texts}), round(sum(map(len, texts)) / 300, 1)))
        words = sample(table, rand)
        chain = [START] + [INDEX[w] for w in words]
        moves = list(zip(chain, chain[1:] + [INDEX["."]])) if len(words) < 10 else list(zip(chain, chain[1:]))
        penalty = 0.0
        for previous, word in moves:
            penalty += math.log(probabilities(table[previous])[word]) - math.log(probabilities(policy0[previous])[word])
        score = reward(words) - kl_weight * penalty
        base += 0.05 * (score - base)
        for previous, word in moves:
            p = probabilities(table[previous])
            for v in range(V):
                table[previous][v] += rate * (score - base) * ((v == word) - p[v])
    return table, log


print("no limit: update, reward model, person, different of 300, length")
free, log = shift(2000, 0.02, 0.0, 6)
for row in log:
    print(row)
check = Rand(3)
print(" | ".join(" ".join(sample(free, check)) for _ in range(4)))
```

```output
no limit: update, reward model, person, different of 300, length
(0, -2.26, -0.86, 275, 5.3)
(200, -0.49, -0.18, 274, 5.2)
(400, 1.0, 0.37, 252, 5.1)
(600, 1.1, 0.42, 236, 5.0)
(800, 1.52, 0.32, 226, 4.7)
(1000, 1.73, 0.48, 211, 4.5)
(1200, 22.95, -7.22, 49, 9.7)
(1400, 24.55, -7.83, 10, 9.9)
(1600, 24.76, -7.91, 5, 9.9)
(1800, 24.9, -7.95, 5, 10.0)
(2000, 24.93, -7.97, 2, 10.0)
спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо | спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо | спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо | спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо
```

Посмотри на две колонки вместе. До шага 1000 всё прекрасно: награда растёт с `−2,26` до `1,73`, а оценка человека с `−0,86` до `0,48`. Затем резко: награда взлетает до `24,93`, а оценка человека падает до `−7,97`. Модель нашла лазейку и пишет только «спасибо спасибо спасибо». Разных предложений остаётся 2 из 300. Это и есть **закон Гудхарта** на деле: когда мера становится целью, она перестаёт быть хорошей мерой. Gao и соавторы показали такой же горб на настоящих больших моделях: истинное качество сначала растёт, а затем падает.

**Шаг 5. Поводок.** Простое лекарство: штраф за то, что модель ушла слишком далеко от исходной. Из награды вычитаем разницу логарифмов вероятностей новой и старой модели, это оценка расхождения Кульбака–Лейблера. Допиши и запусти.

```python
print("with a penalty for drifting")
held, log = shift(2000, 0.02, 1.0, 6)
for row in log[::2]:
    print(row)
check = Rand(3)
print(" | ".join(" ".join(sample(held, check)) for _ in range(4)))
```

```output
with a penalty for drifting
(0, -2.26, -0.86, 275, 5.3)
(400, 0.04, -0.08, 270, 4.8)
(800, 0.74, 0.28, 244, 4.5)
(1200, 0.79, 0.37, 247, 4.4)
(1600, 0.98, 0.36, 237, 4.3)
(2000, 1.37, 0.3, 239, 4.4)
добрый дурак несёт кашу | спасибо мама любит маму | спасибо спасибо кот несёт рыбу | плохой пёс ищет рыбу
```

Награда теперь намного скромнее, `1,37`, зато оценка человека остаётся `0,3`, а разных предложений 239. Проигрываем в числе, которое видит программа, и выигрываем в том, что нужно на самом деле. Настоящие работы ограничивают сдвиг похожим образом: Ziegler и соавторы штрафовали расхождение, а PPO ограничивает шаг.

**Что здесь спорно.** RLHF сделал модели полезнее, это показано опытом InstructGPT. Но хорош ли сам подход как путь к безопасным системам, спорят: люди ошибаются, их легко убедить красивым ответом, и модель может учиться нравиться, а не быть правой. Об этом урок о рисках.

**Учись у тех, кто это создаёт.** Бесплатная книга [Nathan Lambert о RLHF](https://rlhfbook.com/) это лучший вход. Статья [InstructGPT](https://arxiv.org/abs/2203.02155) показала метод на большой модели. Лекция 15 курса [Stanford CS336](https://stanford-cs336.github.io/spring2025/) идёт от предобучения к RLHF.

### Исследуй и потренируйся

В тренажёре человек это ты. Выбери лучшее предложение в 12 парах, посмотри, что выучила модель награды, и двигай ползунок по шагам сдвига. Найди момент, когда модель сломалась. Потом включи штраф и сравни.

В программе убери из функции `person` штраф за повтор. Обманула ли теперь модель человека? Подумай, какой вывод отсюда про настоящих людей.

### Вопрос

Почему при долгом сдвиге награда растёт, а оценка человека падает?

### Варианты

- Модель находит ответы, которые модель награды завышает, хотя человеку они не нравятся.
- Человек со временем устаёт, поэтому его оценки становятся строже к хорошим ответам.
- Шаг обучения постепенно уменьшается, и поэтому модель перестаёт улучшать настоящие ответы.

### Ответ

1

### Разбор

Оценка человека в программе постоянна: она не устаёт, и шаг тоже постоянен. Модель награды это приближение, обученное на обычных ответах. Там, где обучающих примеров нет, например при повторах, она ошибается. Сдвиг сам находит такие места, потому что именно там награда самая большая.

### Границы модели

Модель здесь это таблица пар слов, а награда это сумма весов, она не видит порядка слов. Настоящие модели награды намного умнее, но и настоящие модели находят их слабости тоньше. Человека заменяет простая функция, поэтому оценка точна, чего в жизни нет. Размер штрафа и шага я выбрал вручную, и при других значениях поломка наступает раньше или позже.

## English

### Goal

Walk the whole RLHF path by hand: collect comparisons of answers, train a reward model, and shift a small language model. Then see the main trap: reward rises while true quality falls. It takes about 50 minutes.

### Idea and mechanism

**Step 1. Why this is needed.** A bare language model continues text rather than helps. We want it to write what people like. But nobody can write a formula for a "good answer", and scoring an answer with a number is hard for people: one gives 7, another 4. Comparing two answers and saying which is better, however, is easy.

So RLHF has three steps: people compare pairs of answers, a **reward model** learns to predict their choice, and the language model shifts towards high reward. The second step here uses REINFORCE from the last lesson.

**Step 2. Comparisons.** Our language model is very simple: for each word, a table of probabilities for the next word. It cannot replace a real one, but the whole path is visible and takes a second. In the program a function `person` stands in for a human: it likes the words "спасибо" (thanks), "пожалуйста" (please) and "добрый" (kind), dislikes "дурак" (fool) and "плохой" (bad), and fines a repeated word by 2. In the lab you choose yourself. Create the file `nano ~/ai-path/rlhf.py`, paste and run it.

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


CORPUS = """кот ест рыбу
спасибо кот ест рыбу
пёс ищет дом
плохой пёс ест кашу
дурак ищет кашу
мама любит кота
спасибо мама любит кота
папа несёт воду
пожалуйста несёт воду папа
добрый дед несёт кашу
плохой дед ищет рыбу
дурак несёт воду
гусь ест траву
добрый гусь ищет дом
пожалуйста кот несёт рыбу
очень добрый пёс любит маму
очень плохой гусь ест кашу""".split("\n")
WORDS = sorted({w for line in CORPUS for w in line.split()}) + ["."]
INDEX = {w: i for i, w in enumerate(WORDS)}
START, V = len(WORDS), len(WORDS)
GOOD, BAD = {"спасибо", "пожалуйста", "добрый"}, {"дурак", "плохой"}


def start_table():
    table = [[0.1] * V for _ in range(V + 1)]
    for line in CORPUS:
        previous = START
        for word in line.split() + ["."]:
            table[previous][INDEX[word]] += 1.0
            previous = INDEX[word]
    return [[math.log(c / sum(row)) for c in row] for row in table]


def probabilities(row):
    top = max(row)
    weights = [math.exp(v - top) for v in row]
    total = sum(weights)
    return [w / total for w in weights]


def sample(table, rand, limit=10):
    previous, words = START, []
    while len(words) < limit:
        p, pick, total = probabilities(table[previous]), rand.next(), 0.0
        for v, q in enumerate(p):
            total += q
            if pick <= total:
                break
        if WORDS[v] == ".":
            break
        words.append(WORDS[v])
        previous = v
    return words


def person(words):
    score = sum((w in GOOD) - (w in BAD) for w in words)
    return score - 2 * (len(words) - len(set(words)))


policy0 = start_table()
rand = Rand(5)
for _ in range(5):
    print(" ".join(sample(policy0, rand)))
pairs = []
for _ in range(200):
    a, b = sample(policy0, rand), sample(policy0, rand)
    if person(a) != person(b):
        pairs.append((a, b) if person(a) > person(b) else (b, a))
print("pairs with a clear winner", len(pairs))
```

```output
пожалуйста ест рыбу пёс ищет дом пёс пожалуйста кот ест
дурак ищет папа кашу
спасибо добрый спасибо кот ест рыбу
дурак ищет
добрый дед маму плохой гусь ест
pairs with a clear winner 162
```

**Step 3. The reward model by hand.** Each word has a weight, and a sentence's reward is the sum of its weights. Suppose the better answer's reward is 1 and the worse one's is 0. The probability that the model guesses the person's choice is `1 / (1 + e^(0 − 1)) = 0.73`. The closer to one the better. The update moves the better answer's word weights up and the worse answer's down by `0.02 · (1 − 0.73)`. This is logistic regression on pairs. Add this and run it.

```python
weight = {w: 0.0 for w in WORDS}


def reward(words):
    return sum(weight[w] for w in words)


for _ in range(60):
    for better, worse in pairs:
        chance = 1 / (1 + math.exp(reward(worse) - reward(better)))
        for w in better:
            weight[w] += 0.02 * (1 - chance)
        for w in worse:
            weight[w] -= 0.02 * (1 - chance)
right = sum(reward(a) > reward(b) for a, b in pairs)
print("reward model agrees with the person on", right, "of", len(pairs))
print(sorted(((round(v, 2), w) for w, v in weight.items() if w != "."), reverse=True))
print("spasibo x3:", round(reward(["спасибо"] * 3), 2), "person:", person(["спасибо"] * 3))
```

```output
reward model agrees with the person on 140 of 162
[(2.5, 'спасибо'), (1.38, 'добрый'), (0.57, 'маму'), (0.38, 'траву'), (0.27, 'пожалуйста'), (0.05, 'рыбу'), (0.03, 'пёс'), (-0.23, 'кашу'), (-0.24, 'кот'), (-0.3, 'ест'), (-0.37, 'мама'), (-0.46, 'кота'), (-0.6, 'дед'), (-0.61, 'несёт'), (-0.63, 'воду'), (-0.65, 'любит'), (-0.67, 'ищет'), (-0.85, 'очень'), (-1.08, 'папа'), (-1.66, 'дом'), (-1.75, 'гусь'), (-2.36, 'дурак'), (-2.4, 'плохой')]
spasibo x3: 7.5 person: -1
```

The reward model agrees with the person in 140 cases of 162. In first place is "спасибо" with weight 2.5, which is right. But look further: "маму" (mum) and "траву" (grass) earned a plus, though the person said nothing about them. They merely turned up more often in chosen answers. **A reward model learns not the taste but an approximation of it.** And the last row: three times "спасибо" it rates at `7.5`, the person at `−1`. Repeats were nearly absent from the training pairs, so the model knows nothing about them.

**Step 4. Shifting the model.** At each step we take a sentence, compute its reward minus the mean, and apply REINFORCE to the table's rows: what earned more than usual becomes more probable. We print every 200 steps: the step, mean reward by the reward model, mean score by the person, how many of 300 sentences are different, and their length. Add this and run it.

```python
def shift(updates, rate, kl_weight, seed):
    table = [row[:] for row in policy0]
    rand, base, log = Rand(seed), 0.0, []
    for update in range(updates + 1):
        if update % 200 == 0:
            check = Rand(77)
            texts = [sample(table, check) for _ in range(300)]
            log.append((update, round(sum(map(reward, texts)) / 300, 2), round(sum(map(person, texts)) / 300, 2),
                        len({" ".join(t) for t in texts}), round(sum(map(len, texts)) / 300, 1)))
        words = sample(table, rand)
        chain = [START] + [INDEX[w] for w in words]
        moves = list(zip(chain, chain[1:] + [INDEX["."]])) if len(words) < 10 else list(zip(chain, chain[1:]))
        penalty = 0.0
        for previous, word in moves:
            penalty += math.log(probabilities(table[previous])[word]) - math.log(probabilities(policy0[previous])[word])
        score = reward(words) - kl_weight * penalty
        base += 0.05 * (score - base)
        for previous, word in moves:
            p = probabilities(table[previous])
            for v in range(V):
                table[previous][v] += rate * (score - base) * ((v == word) - p[v])
    return table, log


print("no limit: update, reward model, person, different of 300, length")
free, log = shift(2000, 0.02, 0.0, 6)
for row in log:
    print(row)
check = Rand(3)
print(" | ".join(" ".join(sample(free, check)) for _ in range(4)))
```

```output
no limit: update, reward model, person, different of 300, length
(0, -2.26, -0.86, 275, 5.3)
(200, -0.49, -0.18, 274, 5.2)
(400, 1.0, 0.37, 252, 5.1)
(600, 1.1, 0.42, 236, 5.0)
(800, 1.52, 0.32, 226, 4.7)
(1000, 1.73, 0.48, 211, 4.5)
(1200, 22.95, -7.22, 49, 9.7)
(1400, 24.55, -7.83, 10, 9.9)
(1600, 24.76, -7.91, 5, 9.9)
(1800, 24.9, -7.95, 5, 10.0)
(2000, 24.93, -7.97, 2, 10.0)
спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо | спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо | спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо | спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо спасибо
```

Look at two columns together. Up to step 1000 all is fine: reward grows from `−2.26` to `1.73`, and the person's score from `−0.86` to `0.48`. Then suddenly: reward soars to `24.93`, and the person's score falls to `−7.97`. The model found a loophole and writes only "спасибо спасибо спасибо". Just 2 of 300 sentences stay different. This is **Goodhart's law** in action: when a measure becomes a target, it stops being a good measure. Gao and co-authors showed the same hump on real large models: true quality first rises and then falls.

**Step 5. A leash.** A simple remedy: a fine for straying too far from the original model. We subtract the difference of log probabilities of the new and old models from the reward, which estimates the Kullback–Leibler divergence. Add this and run it.

```python
print("with a penalty for drifting")
held, log = shift(2000, 0.02, 1.0, 6)
for row in log[::2]:
    print(row)
check = Rand(3)
print(" | ".join(" ".join(sample(held, check)) for _ in range(4)))
```

```output
with a penalty for drifting
(0, -2.26, -0.86, 275, 5.3)
(400, 0.04, -0.08, 270, 4.8)
(800, 0.74, 0.28, 244, 4.5)
(1200, 0.79, 0.37, 247, 4.4)
(1600, 0.98, 0.36, 237, 4.3)
(2000, 1.37, 0.3, 239, 4.4)
добрый дурак несёт кашу | спасибо мама любит маму | спасибо спасибо кот несёт рыбу | плохой пёс ищет рыбу
```

The reward is far more modest now, `1.37`, but the person's score stays at `0.3`, and 239 sentences remain different. We lose on the number the program sees and win on what we truly need. Real work limits the shift in similar ways: Ziegler and co-authors fined divergence, and PPO limits the step.

**What is disputed here.** RLHF made models more useful, as the InstructGPT experiment showed. But whether the approach itself is a path to safe systems is argued: people make mistakes, are easily persuaded by a nice answer, and a model may learn to please rather than be right. The lesson on risks returns to this.

**Learn from the people who build this.** [Nathan Lambert's free book on RLHF](https://rlhfbook.com/) is the best entry. The [InstructGPT paper](https://arxiv.org/abs/2203.02155) showed the method on a large model. Lecture 15 of [Stanford CS336](https://stanford-cs336.github.io/spring2025/) goes from pretraining to RLHF.

### Explore and practise

In the lab, you are the person. Choose the better sentence in 12 pairs, see what the reward model learned, and move the slider along the shift steps. Find the moment the model broke. Then switch on the fine and compare.

In the program, remove the repeat fine from the `person` function. Did the model fool the person now? Think about what follows for real people.

### Question

Why does long shifting raise reward while the person's score falls?

### Options

- The model finds answers the reward model overrates, though the person does not like them.
- The person gets tired over time, so their scores grow stricter towards good answers.
- The learning step gradually shrinks, so the model stops improving the real answers.

### Answer

1

### Explanation

The person's score in the program is constant: it does not tire, and the step is constant too. A reward model is an approximation trained on ordinary answers. Where training examples are absent, such as with repeats, it errs. The shift finds such places by itself, since reward is largest exactly there.

### Limits

The model here is a table of word pairs, and the reward is a sum of weights that does not see word order. Real reward models are far smarter, but real language models find their weaknesses more subtly too. A simple function stands in for a person, so the score is exact, which is not so in real life. I chose the size of the fine and the step by hand, and with other values the breakdown comes earlier or later.

## Sources

- Long Ouyang et al., "Training language models to follow instructions with human feedback", arXiv:2203.02155 (2022), recalled from the paper: [arXiv:2203.02155](https://arxiv.org/abs/2203.02155)
- Paul Christiano et al., "Deep reinforcement learning from human preferences", arXiv:1706.03741 (2017), title read 2026-11-03: [arXiv:1706.03741](https://arxiv.org/abs/1706.03741)
- Leo Gao, John Schulman, Jacob Hilton, "Scaling Laws for Reward Model Overoptimization", arXiv:2210.10760 (2022), title read 2026-11-03; the hump is recalled from the paper: [arXiv:2210.10760](https://arxiv.org/abs/2210.10760)
- Daniel M. Ziegler et al., "Fine-Tuning Language Models from Human Preferences", arXiv:1909.08593 (2019): [arXiv:1909.08593](https://arxiv.org/abs/1909.08593)
- Nathan Lambert, "Reinforcement Learning from Human Feedback", title read 2026-11-03: [book](https://rlhfbook.com/)
- Stanford CS336, "Language Modeling from Scratch" (2025), title read 2026-11-03: [course](https://stanford-cs336.github.io/spring2025/)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
