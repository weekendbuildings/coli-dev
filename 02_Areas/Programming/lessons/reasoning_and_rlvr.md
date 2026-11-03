---
subject: programming
lesson_id: programming.reasoning_and_rlvr
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Рассуждение и награда по проверке / Reasoning and verifiable rewards

## Русский

### Цель

Измерить на своём компьютере, что даёт и сколько стоит рассуждение модели. Понять, как обучают рассуждать через награду за проверяемый ответ, и честно увидеть пределы: рассуждение не всегда показывает настоящую причину ответа. Нужно около 40 минут, но опыт с моделью идёт больше получаса, и его можно не повторять: запись лежит в уроке.

### Идея и механизм

**Шаг 1. Опыт.** Модель `qwen3.5` умеет два режима. С `"think": false` она отвечает сразу. С `"think": true` сначала пишет длинный скрытый текст с рассуждением, а затем ответ. Возьмём 12 задач, где верный ответ проверяется числом: арифметика, ловушки на внимание, подсчёт букв. Лимит 3000 токенов на ответ. Создай файл `nano ~/ai-path/reasoning.py` и запусти.

```python
import json
import re
import urllib.request

MODEL = "qwen3.5"
TASKS = [("Сколько будет 37 · 43 − 19 · 21?", 1192),
         ("У Анны было 3 коробки по 17 карандашей. Она отдала 14, а затем купила вдвое больше, чем отдала. Сколько карандашей у неё теперь?", 65),
         ("Ручка и тетрадь вместе стоят 110 рублей. Ручка дороже тетради на 100 рублей. Сколько рублей стоит тетрадь?", 5),
         ("Сколько раз встречается буква «р» в слове «перераспределение»?", 3),
         ("Чему равна сумма цифр числа 2 в степени 15?", 26),
         ("Какой остаток даёт 234567 при делении на 7?", 4),
         ("Какая последняя цифра числа 7 в степени 2026?", 9),
         ("5 станков делают 5 деталей за 5 минут. За сколько минут 100 станков сделают 100 деталей?", 5),
         ("Кувшинки на озере удваиваются каждый день и закрывают всё озеро за 48 дней. За сколько дней они закрывают половину озера?", 47),
         ("У Маши 4 брата, и у каждого брата 2 сестры. Сколько сестёр у Маши?", 1),
         ("Сколько будет 13 · 17 + 11 · 19?", 430),
         ("Поезд прошёл 120 км за 1,5 часа, потом 180 км за 2,5 часа. Какова его средняя скорость в км/ч?", 75)]


def ask(question, think):
    rule = "Подумай и в конце напиши одно число." if think else "Ответь сразу, только одним числом, без объяснений."
    body = {"model": MODEL, "stream": False, "think": think, "options": {"seed": 1, "temperature": 0.2, "num_predict": 3000},
            "messages": [{"role": "user", "content": question + " " + rule}]}
    request = urllib.request.Request("http://localhost:11434/api/chat", json.dumps(body).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=900) as response:
        return json.load(response)


def number_in(reply):
    found = re.findall(r"-?\d+", reply["message"]["content"].replace(" ", ""))
    return int(found[-1]) if found else None


results = []
print("task right | direct tokens seconds | reasoning tokens seconds")
for i, (question, right) in enumerate(TASKS, 1):
    fast, slow = ask(question, False), ask(question, True)
    row = (number_in(fast), fast["eval_count"], fast["total_duration"] / 1e9, number_in(slow), slow["eval_count"], slow["total_duration"] / 1e9)
    results.append((row[0] == right, row[1], row[3] == right, row[4]))
    print(i, right, "|", row[0], row[1], round(row[2], 1), "|", row[3], row[4], round(row[5], 1))
print("right without reasoning", sum(r[0] for r in results), "with", sum(r[2] for r in results), "of", len(TASKS))
print("mean tokens", round(sum(r[1] for r in results) / len(TASKS)), round(sum(r[3] for r in results) / len(TASKS)))
```

```output
task right | direct tokens seconds | reasoning tokens seconds
1 1192 | 1580 4 5.8 | 1192 2060 142.1
2 65 | 50 2 1.4 | 65 1412 109.3
3 5 | 10 2 1.0 | 5 1214 89.7
4 3 | 4 1 1.0 | None 3000 383.6
5 26 | 26 2 2.2 | None 3000 339.5
6 4 | 4 1 0.9 | 4 1498 129.3
7 9 | 9 1 1.0 | 9 2793 262.1
8 5 | 5 1 1.3 | 5 2457 279.7
9 47 | 47 2 1.3 | 47 1008 105.3
10 1 | 3 1 1.0 | 1 1115 111.9
11 430 | 250 3 1.4 | 430 1442 134.5
12 75 | 120 3 1.1 | 75 1447 127.9
right without reasoning 5 with 10 of 12
mean tokens 2 1870
```

Читай таблицу. Без рассуждения верно 5 из 12, и уходит около секунды. С рассуждением верно 10 из 12, но нужно 100–380 секунд и в среднем 1870 токенов против 2. Посмотри на задачу 3: «ручка и тетрадь». Сразу модель сказала `10`, это классическая ловушка, а рассуждая, нашла `5`.

Заметь и другую сторону. На задачах 4 и 5, с буквами в слове и с цифрами степени, рассуждение **съело все 3000 токенов и не успело ответить**. На задаче 5 прямой ответ был верен, а рассуждение нет. Подробности опыта: одна модель, одно зерно, поэтому числа только мои.

**Шаг 2. Что там внутри.** Допиши и запусти.

```python
sample = ask(TASKS[2][0], True)
print(sample["message"].get("thinking", "")[:500].replace("`", "'"))
print("ANSWER:", sample["message"]["content"][:200].replace("`", "'"))
```

```output
Thinking Process:

1.  **Analyze the Request:**
    *   Problem: A pen and a notebook together cost 110 rubles. The pen is more expensive than the notebook by 100 rubles.
    *   Question: How much does the notebook cost?
    *   Constraint: Think first, then write only one number at the end.

2.  **Formulate Equations:**
    *   Let $P$ be the price of the pen.
    *   Let $N$ be the price of the notebook.
    *   Equation 1 (Total cost): $P + N = 110$
    *   Equation 2 (Price difference): $P 
ANSWER: Пусть цена тетради равна $x$ рублей. Тогда цена ручки равна $x + 100$ рублей.
Составим уравнение по условию задачи:
$x + (x + 100) = 110$
$2x + 100 = 110$
$2x = 10$
$x = 5$

Тетрадь стоит 5 рублей.

5
```

Модель получила задачу по-русски, а рассуждает по-английски. Перед нами обычный текст: она сама себя подталкивает к следующему шагу. Никакого нового механизма в ней нет, те же вероятности следующего токена, только токенов намного больше. Рассуждение помогает потому, что длинная цепочка мелких шагов надёжнее одного большого прыжка.

**Шаг 3. Как этому учат.** Откуда у модели такая привычка? Есть работа DeepSeek-R1: модель обучали через RL, а наградой была **проверка ответа**: верный результат задачи или прошедшие тесты кода. Это называют RLVR (RL with verifiable rewards). Вспомни уроки REINFORCE и RLHF, формула та же: `награда · ∇ ln p(токенов)`. Но есть важное отличие от RLHF: здесь нет модели награды, которую можно обмануть, а есть программа, которая проверяет ответ. Лазеек меньше, хотя они есть: например, можно научиться обходить тест.

Посчитаем цену. Пусть 1000 токенов стоят `c`, а верный ответ приносит 1. Рассуждение в среднем даёт `10/12 − 1,87 · c`, а прямой ответ `5/12`. Они равны при `c = (5/12) / 1,87 = 0,22`. Значит, при цене выше 0,22 рассуждать невыгодно.

**Шаг 4. Обучи выбор сам.** Настоящую модель мы тут не дообучим. Но механизм можно увидеть: политика выбирает один из двух режимов, а награда считается по **настоящим результатам из таблицы выше**. Это REINFORCE из урока о градиенте политики. Допиши и запусти.

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


def choose_mode(price, steps=4000, rate=0.02, seed=3):
    rand, theta, base = Rand(seed), 0.0, 0.0
    for _ in range(steps):
        p = 1 / (1 + math.exp(-theta))
        think = rand.next() < p
        task = results[rand.below(len(results))]
        right, tokens = (task[2], task[3]) if think else (task[0], task[1])
        reward = float(right) - price * tokens / 1000
        base += 0.05 * (reward - base)
        theta += rate * (reward - base) * ((1 - p) if think else -p)
    return 1 / (1 + math.exp(-theta))


print("price of 1000 tokens, share of choosing reasoning after training")
for price in (0.0, 0.1, 0.2, 0.25, 0.3, 0.5):
    print(price, round(choose_mode(price), 3))
```

```output
price of 1000 tokens, share of choosing reasoning after training
0.0 0.963
0.1 0.937
0.2 0.761
0.25 0.323
0.3 0.15
0.5 0.033
```

При `0,2` политика выбирает рассуждение в 76 % случаев, а при `0,25` только в 32 %. Перелом точно там, где сказал расчёт. Это игрушка: тут выбирается только режим, а не сам текст. Настоящий RLVR сдвигает веса так, что вероятнее становятся те токены, которые вели к верному ответу.

**Шаг 5. Что здесь спорно.** Можно ли верить рассуждению? Turpin и соавторы подсовывали моделям подсказку в условии. Ответы менялись, но в рассуждении подсказка не упоминалась: объяснение не отражало настоящую причину. Chen и соавторы получили похожее для моделей с рассуждением: они часто не признаются, что использовали подсказку. Поэтому текст рассуждения полезен, но это не окно в настоящий механизм. Спорно и то, «думает» ли модель в таком режиме: тут лучше описывать, что она делает, и не спорить о слове.

**Учись у тех, кто это создаёт.** Статья [DeepSeek-R1](https://arxiv.org/abs/2501.12948) написана очень понятно. Лекция 16 курса [Stanford CS336](https://stanford-cs336.github.io/spring2025/) и лекции о рассуждениях в [Stanford CS224N](https://web.stanford.edu/class/cs224n/). Как модели не говорят всего: [Turpin и др.](https://arxiv.org/abs/2305.04388).

### Исследуй и потренируйся

В тренажёре настоящие результаты этого опыта. Тащи лимит токенов по полоскам и смотри, сколько задач модель успеет решить. Двигай цену токенов и смотри, как обучается выбор.

Добавь в программу свои задачи. Придумай такую, где прямой ответ верен, а рассуждение ошибается. Это труднее, чем кажется.

### Вопрос

Чем награда в RLVR отличается от награды в RLHF?

### Варианты

- В RLVR её считает программа проверки ответа, а в RLHF обученная модель предпочтений людей.
- В RLVR её ставят люди после чтения рассуждения, а в RLHF считает программа проверки ответа.
- В RLVR награды нет вовсе, поскольку модель сразу учится на готовых верных примерах решения.

### Ответ

1

### Разбор

В RLHF награду считает модель, обученная на сравнениях людей, поэтому её можно обмануть, как в том уроке. В RLVR награду даёт проверка: совпал ли ответ, прошли ли тесты. Награда в RLVR есть, а формула обновления та же самая.

### Границы модели

Всего 12 задач, одна модель, одно зерно. Лимит в 3000 токенов выбран мной, а при большем лимите задачи 4 и 5 могли бы решиться. Время зависит от моего компьютера. Часть задач это известные ловушки, и модель могла видеть их при обучении, поэтому оценка ей льстит. Выбор режима в шаге 4 это учебная игрушка, настоящее обучение с рассуждением устроено гораздо сложнее.

## English

### Goal

Measure on your own computer what a model's reasoning gives and what it costs. Understand how models are taught to reason through a reward for a checkable answer, and honestly see the limits: reasoning does not always show the true cause of an answer. It takes about 40 minutes, though the model experiment runs over half an hour and need not be repeated: the recording is in the lesson.

### Idea and mechanism

**Step 1. The experiment.** The model `qwen3.5` has two modes. With `"think": false` it answers at once. With `"think": true` it first writes a long hidden text of reasoning and then answers. We take 12 tasks whose right answer can be checked as a number: arithmetic, attention traps, counting letters. The limit is 3000 tokens per answer. Create the file `nano ~/ai-path/reasoning.py` and run it.

```python
import json
import re
import urllib.request

MODEL = "qwen3.5"
TASKS = [("Сколько будет 37 · 43 − 19 · 21?", 1192),
         ("У Анны было 3 коробки по 17 карандашей. Она отдала 14, а затем купила вдвое больше, чем отдала. Сколько карандашей у неё теперь?", 65),
         ("Ручка и тетрадь вместе стоят 110 рублей. Ручка дороже тетради на 100 рублей. Сколько рублей стоит тетрадь?", 5),
         ("Сколько раз встречается буква «р» в слове «перераспределение»?", 3),
         ("Чему равна сумма цифр числа 2 в степени 15?", 26),
         ("Какой остаток даёт 234567 при делении на 7?", 4),
         ("Какая последняя цифра числа 7 в степени 2026?", 9),
         ("5 станков делают 5 деталей за 5 минут. За сколько минут 100 станков сделают 100 деталей?", 5),
         ("Кувшинки на озере удваиваются каждый день и закрывают всё озеро за 48 дней. За сколько дней они закрывают половину озера?", 47),
         ("У Маши 4 брата, и у каждого брата 2 сестры. Сколько сестёр у Маши?", 1),
         ("Сколько будет 13 · 17 + 11 · 19?", 430),
         ("Поезд прошёл 120 км за 1,5 часа, потом 180 км за 2,5 часа. Какова его средняя скорость в км/ч?", 75)]


def ask(question, think):
    rule = "Подумай и в конце напиши одно число." if think else "Ответь сразу, только одним числом, без объяснений."
    body = {"model": MODEL, "stream": False, "think": think, "options": {"seed": 1, "temperature": 0.2, "num_predict": 3000},
            "messages": [{"role": "user", "content": question + " " + rule}]}
    request = urllib.request.Request("http://localhost:11434/api/chat", json.dumps(body).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=900) as response:
        return json.load(response)


def number_in(reply):
    found = re.findall(r"-?\d+", reply["message"]["content"].replace(" ", ""))
    return int(found[-1]) if found else None


results = []
print("task right | direct tokens seconds | reasoning tokens seconds")
for i, (question, right) in enumerate(TASKS, 1):
    fast, slow = ask(question, False), ask(question, True)
    row = (number_in(fast), fast["eval_count"], fast["total_duration"] / 1e9, number_in(slow), slow["eval_count"], slow["total_duration"] / 1e9)
    results.append((row[0] == right, row[1], row[3] == right, row[4]))
    print(i, right, "|", row[0], row[1], round(row[2], 1), "|", row[3], row[4], round(row[5], 1))
print("right without reasoning", sum(r[0] for r in results), "with", sum(r[2] for r in results), "of", len(TASKS))
print("mean tokens", round(sum(r[1] for r in results) / len(TASKS)), round(sum(r[3] for r in results) / len(TASKS)))
```

```output
task right | direct tokens seconds | reasoning tokens seconds
1 1192 | 1580 4 5.8 | 1192 2060 142.1
2 65 | 50 2 1.4 | 65 1412 109.3
3 5 | 10 2 1.0 | 5 1214 89.7
4 3 | 4 1 1.0 | None 3000 383.6
5 26 | 26 2 2.2 | None 3000 339.5
6 4 | 4 1 0.9 | 4 1498 129.3
7 9 | 9 1 1.0 | 9 2793 262.1
8 5 | 5 1 1.3 | 5 2457 279.7
9 47 | 47 2 1.3 | 47 1008 105.3
10 1 | 3 1 1.0 | 1 1115 111.9
11 430 | 250 3 1.4 | 430 1442 134.5
12 75 | 120 3 1.1 | 75 1447 127.9
right without reasoning 5 with 10 of 12
mean tokens 2 1870
```

Read the table. Without reasoning 5 of 12 are right, in about a second. With reasoning 10 of 12 are right, but it takes 100–380 seconds and on average 1870 tokens against 2. Look at task 3, the pen and the notebook. At once the model said `10`, the classic trap, and while reasoning it found `5`.

Note the other side too. On tasks 4 and 5, with letters in a word and the digits of a power, reasoning **used up all 3000 tokens and never answered**. On task 5 the direct answer was right and reasoning was not. The experiment's details: one model, one seed, so the numbers are only mine.

**Step 2. What is inside.** Add this and run it.

```python
sample = ask(TASKS[2][0], True)
print(sample["message"].get("thinking", "")[:500].replace("`", "'"))
print("ANSWER:", sample["message"]["content"][:200].replace("`", "'"))
```

```output
Thinking Process:

1.  **Analyze the Request:**
    *   Problem: A pen and a notebook together cost 110 rubles. The pen is more expensive than the notebook by 100 rubles.
    *   Question: How much does the notebook cost?
    *   Constraint: Think first, then write only one number at the end.

2.  **Formulate Equations:**
    *   Let $P$ be the price of the pen.
    *   Let $N$ be the price of the notebook.
    *   Equation 1 (Total cost): $P + N = 110$
    *   Equation 2 (Price difference): $P 
ANSWER: Пусть цена тетради равна $x$ рублей. Тогда цена ручки равна $x + 100$ рублей.
Составим уравнение по условию задачи:
$x + (x + 100) = 110$
$2x + 100 = 110$
$2x = 10$
$x = 5$

Тетрадь стоит 5 рублей.

5
```

The model received the task in Russian and reasons in English. This is ordinary text: it nudges itself to the next step. There is no new mechanism, the same probabilities of the next token, only far more tokens. Reasoning helps because a long chain of small steps is more reliable than one big leap.

**Step 3. How this is taught.** Where does a model get this habit? In the DeepSeek-R1 work a model was trained by RL, and the reward was **checking the answer**: the task's right result or passing code tests. This is called RLVR (RL with verifiable rewards). Recall the REINFORCE and RLHF lessons; the formula is the same: `reward · ∇ ln p(tokens)`. But there is an important difference from RLHF: here is no reward model to fool, only a program that checks the answer. There are fewer loopholes, though they exist: for example, a model can learn to get around a test.

Let us compute the price. Suppose 1000 tokens cost `c`, and a right answer brings 1. Reasoning gives on average `10/12 − 1.87 · c`, and the direct answer `5/12`. They are equal at `c = (5/12) / 1.87 = 0.22`. So at a price above 0.22 reasoning does not pay.

**Step 4. Train the choice yourself.** We will not fine-tune the real model here. But the mechanism can be seen: a policy picks one of two modes, and the reward uses the **real results from the table above**. This is REINFORCE from the policy gradient lesson. Add this and run it.

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


def choose_mode(price, steps=4000, rate=0.02, seed=3):
    rand, theta, base = Rand(seed), 0.0, 0.0
    for _ in range(steps):
        p = 1 / (1 + math.exp(-theta))
        think = rand.next() < p
        task = results[rand.below(len(results))]
        right, tokens = (task[2], task[3]) if think else (task[0], task[1])
        reward = float(right) - price * tokens / 1000
        base += 0.05 * (reward - base)
        theta += rate * (reward - base) * ((1 - p) if think else -p)
    return 1 / (1 + math.exp(-theta))


print("price of 1000 tokens, share of choosing reasoning after training")
for price in (0.0, 0.1, 0.2, 0.25, 0.3, 0.5):
    print(price, round(choose_mode(price), 3))
```

```output
price of 1000 tokens, share of choosing reasoning after training
0.0 0.963
0.1 0.937
0.2 0.761
0.25 0.323
0.3 0.15
0.5 0.033
```

At `0.2` the policy picks reasoning 76 % of the time, and at `0.25` only 32 %. The turning point is exactly where the calculation said. This is a toy: it picks only the mode, not the text itself. Real RLVR shifts weights so that the tokens that led to a right answer become more probable.

**Step 5. What is disputed here.** Can reasoning be trusted? Turpin and co-authors slipped a hint into a task's wording. The answers changed, but the reasoning did not mention the hint: the explanation did not reflect the true cause. Chen and co-authors found similar results for reasoning models: they often do not admit using a hint. So the reasoning text is useful, but it is no window into the true mechanism. Whether a model "thinks" in this mode is disputed too: better to describe what it does than to argue over the word.

**Learn from the people who build this.** The [DeepSeek-R1 paper](https://arxiv.org/abs/2501.12948) is written very clearly. Lecture 16 of [Stanford CS336](https://stanford-cs336.github.io/spring2025/) and the reasoning lectures of [Stanford CS224N](https://web.stanford.edu/class/cs224n/). How models do not say everything: [Turpin et al.](https://arxiv.org/abs/2305.04388).

### Explore and practise

The lab holds this experiment's real results. Drag the token limit across the bars and see how many tasks the model can solve. Move the token price and see how the choice trains.

Add your own tasks to the program. Invent one where the direct answer is right and reasoning errs. It is harder than it seems.

### Question

How does the reward in RLVR differ from the reward in RLHF?

### Options

- In RLVR a program checking the answer computes it, in RLHF a trained model of preferences.
- In RLVR people give it after reading the reasoning, in RLHF a program checking the answer.
- RLVR has no reward at all, since the model learns at once from ready correct solutions.

### Answer

1

### Explanation

In RLHF a model trained on people's comparisons computes the reward, so it can be fooled, as in that lesson. In RLVR a check gives the reward: did the answer match, did the tests pass. RLVR does have a reward, and the update formula is the same.

### Limits

Just 12 tasks, one model, one seed. I chose the 3000-token limit, and with a larger limit tasks 4 and 5 might be solved. Time depends on my computer. Some tasks are well-known traps the model may have seen in training, so the estimate flatters it. The mode choice of step 4 is a teaching toy; real training with reasoning is far more complex.

## Sources

- DeepSeek-AI, "DeepSeek-R1: Incentivizing Reasoning Capability in LLMs via Reinforcement Learning", arXiv:2501.12948 (2025), recalled from the paper: [arXiv:2501.12948](https://arxiv.org/abs/2501.12948)
- Miles Turpin et al., "Language Models Don't Always Say What They Think", arXiv:2305.04388 (2023), recalled: [arXiv:2305.04388](https://arxiv.org/abs/2305.04388)
- Yanda Chen et al., "Reasoning Models Don't Always Say What They Think", arXiv:2505.05410 (2025), recalled: [arXiv:2505.05410](https://arxiv.org/abs/2505.05410)
- Jason Wei et al., "Chain-of-Thought Prompting Elicits Reasoning in Large Language Models", arXiv:2201.11903 (2022): [arXiv:2201.11903](https://arxiv.org/abs/2201.11903)
- Stanford CS336 and CS224N, titles read 2026-11-03: [CS336](https://stanford-cs336.github.io/spring2025/), [CS224N](https://web.stanford.edu/class/cs224n/)
- The programs were written for this lesson, and the numbers come from a run on the owner's Mac with qwen3.5. The lesson paraphrases these sources and does not copy their text.
