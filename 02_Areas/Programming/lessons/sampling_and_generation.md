---
subject: programming
lesson_id: programming.sampling_and_generation
level: intermediate
languages: ru, en
source_checked: 2026-11-07
source_review_interval_days: 180
---

# Как модель выбирает слова: top-k, top-p и лучевой поиск / How a model picks words: top-k, top-p and beam search

## Русский

### Простыми словами

Модель не пишет слово сразу. Она выдаёт вероятность каждому возможному следующему токену, а выбирает уже отдельное правило. Похоже на выбор блюда в кафе. Всегда брать самое популярное скучно, и ты быстро ходишь по кругу. Брать наугад из всего меню опасно: попадётся что-то странное. Можно выбрать из пяти самых популярных блюд, это top-k, или из тех, что вместе заказывают 90 % гостей, это top-p. А лучевой поиск обдумывает несколько обедов целиком и берёт самый вероятный.

**Что нужно знать до.** Урок «Счётчик пар: первая языковая модель» (шаг 10): вероятности следующей буквы. Урок «Живая модель на твоём Mac» (шаг 1): температура и вероятности токенов настоящей модели. Урок «Своя языковая модель» (шаг 12).

**Если непонятно.** Если неясно, откуда берутся вероятности, вернись к уроку «Счётчик пар». Если неясен логарифм вероятности, перечитай урок «Информация, энтропия и кросс-энтропия» (шаг 6). Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Сравнить четыре способа выбирать следующий токен: жадный, top-k, top-p и лучевой поиск. Увидеть, почему самый вероятный текст часто плохой, и посчитать на настоящих вероятностях `qwen2.5-coder:7b`, сколько токенов оставляет top-p. Нужно около 30 минут.

### Идея и механизм

**Шаг 1. Жадный выбор.** Самое простое правило: всегда брать самый вероятный токен. Его называют *жадным*. Возьмём счётчик пар из урока «Счётчик пар» (шаг 10) и текст о маме, коте и псе. Создай файл `nano ~/ai-path/sampling.py`, вставь и запусти.

```python
import math

TRAIN = (
    "мама мыла раму. папа читал книгу. мама читала книгу сыну. "
    "кот спал на окне. пёс спал у двери. кот видел пса, а пёс видел кота. "
    "сын читал книгу коту. мама мыла окно. папа мыл пол. кот мыл лапу. "
    "утром мама пила чай, а папа пил кофе. вечером сын пил молоко. "
    "пёс любил гулять, а кот любил спать. мама любила книги. "
)
counts = {}
for a, b in zip(TRAIN, TRAIN[1:]):
    counts.setdefault(a, {})
    counts[a][b] = counts[a].get(b, 0) + 1


def probs(a):
    row = counts[a]
    total = sum(row.values())
    return sorted(((b, c / total) for b, c in row.items()), key=lambda kv: (-kv[1], kv[0]))


def top_k(dist, k):
    kept = dist[:k]
    total = sum(p for _, p in kept)
    return [(b, p / total) for b, p in kept]


def top_p(dist, p):
    kept, mass = [], 0.0
    for b, q in dist:
        kept.append((b, q))
        mass += q
        if mass >= p:
            break
    return [(b, q / mass) for b, q in kept]


def show(dist):
    return " ".join(f"{b!r}:{q:.2f}" for b, q in dist)


print("after 'о':", show(probs("о")))
print("top-k, k = 2:", show(top_k(probs("о"), 2)))
print("top-p, p = 0.5:", show(top_p(probs("о"), 0.5)))
print("top-p, p = 0.9:", show(top_p(probs("о"), 0.9)))

text = "м"
for _ in range(30):
    text += probs(text[-1])[0][0]
print("greedy:", text)
```

```output
after 'о': 'т':0.38 'к':0.19 '.':0.12 'л':0.12 'м':0.12 'ф':0.06
top-k, k = 2: 'т':0.67 'к':0.33
top-p, p = 0.5: 'т':0.67 'к':0.33
top-p, p = 0.9: 'т':0.40 'к':0.20 '.':0.13 'л':0.13 'м':0.13
greedy: ма кот кот кот кот кот кот кот
```

Сначала посмотри на последнюю строку. Жадный текст попал в петлю «кот кот кот» и уже не выйдет из неё: после «т» лучше всего пробел, после пробела «к», и так по кругу. Большие модели при жадном выборе тоже часто повторяются, только петли у них длиннее. Holtzman и соавторы в 2019 году назвали это *вырождением текста*.

**Шаг 2. Отрезать хвост руками.** После «о» модель даёт «т» 0,38, «к» 0,19, а остальным меньше. *Top-k* оставляет `k` лучших и делит их вероятности на их сумму, чтобы снова вышло 1. При `k = 2`: сумма `0,38 + 0,19 = 0,57`, и новые вероятности `0,38 / 0,57 = 0,67` и `0,19 / 0,57 = 0,33`. *Top-p*, или *выбор из ядра*, оставляет самые вероятные токены, пока их сумма не дойдёт до `p`. При `p = 0,5`: «т» даёт 0,38, этого мало, добавляем «к», выходит 0,57, хватит. Программа выше напечатала ровно эти числа. Разница в том, что top-k всегда оставляет одно и то же число токенов, а top-p оставляет меньше, когда модель уверена, и больше, когда сомневается.

**Шаг 3. Лучевой поиск.** Жадный выбор смотрит на один шаг. *Лучевой поиск* держит сразу несколько лучших продолжений, *лучей*, и на каждом шаге продлевает все. Вероятность продолжения это произведение вероятностей его токенов, поэтому складывают логарифмы. Допиши и запусти.

```python
def beam(start, steps, width):
    beams = [(0.0, start)]
    for _ in range(steps):
        grown = []
        for score, text in beams:
            for b, q in probs(text[-1]):
                grown.append((score + math.log(q), text + b))
        beams = sorted(grown, key=lambda kv: (-kv[0], kv[1]))[:width]
    return beams[0]


for width in (1, 2, 5):
    score, text = beam("п", 4, width)
    print(f"beam width {width}: {text!r}, probability {math.exp(score):.4f}")
```

```output
beam width 1: 'па ко', probability 0.0252
beam width 2: 'па ко', probability 0.0252
beam width 5: 'пёсыл', probability 0.0286
```

Ширина 1 это и есть жадный выбор: «па ко». С шириной 5 поиск нашёл продолжение вероятнее, `0,0286` против `0,0252`, но это «пёсыл», бессмыслица из обрывков «пёс» и «сыл». Вот главный урок: самый вероятный текст не значит самый хороший. Holtzman и соавторы показали это на больших моделях: тексты людей вовсе не самые вероятные с точки зрения модели. Поэтому лучевой поиск хорош там, где ответ короткий и почти однозначный, например в переводе, а для свободного текста обычно берут случайный выбор с top-p.

**Шаг 4. Настоящая модель.** Здесь нужны вероятности настоящей модели. В уроке «Живая модель на твоём Mac» `qwen2.5-coder:7b` уже ответила на «The capital of France is», и 20 лучших токенов записаны. Фильтры при этой записи были выключены, поэтому видно настоящее распределение. Допиши и запусти, Ollama не нужна.

```python
# qwen2.5-coder:7b after "The capital of France is", recorded 2026-11-02 (Ollama 0.40.13)
TOP20 = [
    (' Paris', -0.4599),
    (' __', -3.0503),
    (':\n', -3.1145),
    (' ______', -3.1598),
    (' a', -3.5436),
    (':\n\n', -3.5548),
    (' located', -3.5708),
    (' ____', -4.4905),
    (' the', -4.8847),
    (' not', -4.9136),
    (' ___', -5.0097),
    ('\n', -5.0983),
    (' in', -5.1732),
    ('____', -5.4525),
    (' an', -5.5102),
    (' known', -5.6419),
    (' also', -5.6668),
    (' situated', -5.6904),
    (' where', -5.7956),
    (' .\n', -5.8063)
]
real = [(token, math.exp(logprob)) for token, logprob in TOP20]
print("P(' Paris') =", round(real[0][1], 3), "| mass of the 20 best:", round(sum(q for _, q in real), 3))
for p in (0.5, 0.8, 0.9, 0.95):
    mass, size = 0.0, 0
    for _, q in real:
        mass += q
        size += 1
        if mass >= p:
            break
    print(f"top-p = {p}:", f"keeps {size}" if mass >= p else "keeps more than 20, the recording is too short")
print("top-k = 3 keeps", [token for token, _ in real[:3]])
```

```output
P(' Paris') = 0.631 | mass of the 20 best: 0.92
top-p = 0.5: keeps 1
top-p = 0.8: keeps 6
top-p = 0.9: keeps 14
top-p = 0.95: keeps more than 20, the recording is too short
top-k = 3 keeps [' Paris', ' __', ':\n']
```

Что ты увидел. « Paris» получает 0,631, а 20 лучших вместе только 0,92: остальные 8 % размазаны по тысячам токенов. При `p = 0,9` в ядре 14 токенов, при `p = 0,5` один. При `p = 0,95` записи не хватает: ядро больше 20, и честно сказать его размер по этой записи нельзя. Заметь и вторую вещь: top-k = 3 оставил « __» и перевод строки. Модель приняла фразу за упражнение «заполни пропуск». Top-k и top-p оставляют верх списка, каким бы он ни был: убрать вероятный мусор они не могут.

В Ollama эти правила задаются параметрами `top_k`, `top_p` и `temperature`. По документации Ollama по умолчанию `top_k = 40`, `top_p = 0,9` и `temperature = 0,8`, если модель не задаёт своих значений. Порядок важен: сначала отрезается хвост, потом выбирается случайный токен из оставшихся.

**Учись у тех, кто это создаёт.** Статья [The Curious Case of Neural Text Degeneration](https://arxiv.org/abs/1904.09751), где предложен top-p. Карпатый показывает выбор следующего токена в [Let's build GPT](https://karpathy.ai/zero-to-hero.html).

### Исследуй и потренируйся

В тренажёре ниже столбики это настоящие вероятности 20 лучших токенов. Двигай `k` и `p`: серые столбики отрезаны. Температуры здесь нет: хвост за пределами 20 токенов не записан, и пересчитать его честно нельзя. Нажми «Выбрать 50 раз» и посмотри, какие токены реально выпадают. Найди настройку, при которой остаётся только « Paris», и настройку, при которой ядро больше 10 токенов.

### Вопрос

Лучевой поиск шириной 5 нашёл продолжение вероятнее жадного, но это бессмыслица «пёсыл». Что это показывает?

### Варианты

- Самое вероятное продолжение не обязательно хороший текст: поиск максимизирует вероятность, а не смысл
- Лучевой поиск работает с ошибкой: при правильной программе он всегда находит осмысленные слова
- Ширина 5 слишком мала, а при ширине 50 поиск наверняка нашёл бы уже нормальное слово

### Ответ

1

### Разбор

Поиск делает ровно то, что ему сказали: ищет произведение вероятностей побольше. Наша модель помнит одну букву, и для неё «пёсыл» правдоподобнее, чем «па ко». Программа здесь ни при чём, а большая ширина только лучше найдёт ещё более вероятное, а не более осмысленное. У больших моделей смысла больше, но и у них самый вероятный текст часто скучный и повторяющийся.

### Границы модели

Счётчик пар знает одну букву, поэтому его тексты бессмысленны при любом правиле выбора. Вероятности настоящей модели здесь только для одного места текста и только 20 лучших, поэтому размер ядра при больших `p` по ним не узнать. Есть и другие правила, например `min_p` в Ollama и штраф за повторы; здесь они не разобраны.

## English

### In plain words

A model does not write a word straight away. It gives a probability to every possible next token, and a separate rule does the choosing. It is like choosing a dish in a café. Always taking the most popular one is boring, and you soon go round in circles. Picking at random from the whole menu is risky: you may get something strange. You can choose from the five most popular dishes, that is top-k, or from those that together make up 90 % of orders, that is top-p. Beam search thinks through several whole meals and takes the most likely one.

**What to know first.** «A pair counter: the first language model» (step 10): next-letter probabilities. «A live model on your Mac» (step 1): temperature and a real model's token probabilities. «Your Own Language Model» (step 12).

**If something is unclear.** If it is unclear where the probabilities come from, go back to «A pair counter». If the logarithm of a probability is unclear, reread «Information, Entropy, and Cross-Entropy» (step 6). Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Compare four ways to pick the next token: greedy, top-k, top-p and beam search. See why the most likely text is often bad, and count on real `qwen2.5-coder:7b` probabilities how many tokens top-p keeps. It takes about 30 minutes.

### Idea and mechanism

**Step 1. Greedy choice.** The simplest rule: always take the most likely token. It is called *greedy*. Take the pair counter from «A pair counter» (step 10) and the text about mum, the cat and the dog. Create the file `nano ~/ai-path/sampling.py`, paste and run it.

```python
import math

TRAIN = (
    "мама мыла раму. папа читал книгу. мама читала книгу сыну. "
    "кот спал на окне. пёс спал у двери. кот видел пса, а пёс видел кота. "
    "сын читал книгу коту. мама мыла окно. папа мыл пол. кот мыл лапу. "
    "утром мама пила чай, а папа пил кофе. вечером сын пил молоко. "
    "пёс любил гулять, а кот любил спать. мама любила книги. "
)
counts = {}
for a, b in zip(TRAIN, TRAIN[1:]):
    counts.setdefault(a, {})
    counts[a][b] = counts[a].get(b, 0) + 1


def probs(a):
    row = counts[a]
    total = sum(row.values())
    return sorted(((b, c / total) for b, c in row.items()), key=lambda kv: (-kv[1], kv[0]))


def top_k(dist, k):
    kept = dist[:k]
    total = sum(p for _, p in kept)
    return [(b, p / total) for b, p in kept]


def top_p(dist, p):
    kept, mass = [], 0.0
    for b, q in dist:
        kept.append((b, q))
        mass += q
        if mass >= p:
            break
    return [(b, q / mass) for b, q in kept]


def show(dist):
    return " ".join(f"{b!r}:{q:.2f}" for b, q in dist)


print("after 'о':", show(probs("о")))
print("top-k, k = 2:", show(top_k(probs("о"), 2)))
print("top-p, p = 0.5:", show(top_p(probs("о"), 0.5)))
print("top-p, p = 0.9:", show(top_p(probs("о"), 0.9)))

text = "м"
for _ in range(30):
    text += probs(text[-1])[0][0]
print("greedy:", text)
```

```output
after 'о': 'т':0.38 'к':0.19 '.':0.12 'л':0.12 'м':0.12 'ф':0.06
top-k, k = 2: 'т':0.67 'к':0.33
top-p, p = 0.5: 'т':0.67 'к':0.33
top-p, p = 0.9: 'т':0.40 'к':0.20 '.':0.13 'л':0.13 'м':0.13
greedy: ма кот кот кот кот кот кот кот
```

Look at the last line first. The greedy text fell into the loop «кот кот кот» ("cat cat cat") and will never leave it: after «т» a space is best, after a space «к», and so round and round. Large models also often repeat themselves under greedy choice, only their loops are longer. Holtzman and co-authors called this *text degeneration* in 2019.

**Step 2. Cutting the tail by hand.** After «о» the model gives «т» 0.38, «к» 0.19 and the rest less. *Top-k* keeps the `k` best and divides their probabilities by their sum so they add up to 1 again. At `k = 2`: the sum is `0.38 + 0.19 = 0.57`, and the new probabilities are `0.38 / 0.57 = 0.67` and `0.19 / 0.57 = 0.33`. *Top-p*, or *nucleus sampling*, keeps the most likely tokens until their sum reaches `p`. At `p = 0.5`: «т» gives 0.38, not enough, add «к», that makes 0.57, enough. The program above printed exactly these numbers. The difference: top-k always keeps the same number of tokens, while top-p keeps fewer when the model is sure and more when it hesitates.

**Step 3. Beam search.** Greedy choice looks one step ahead. *Beam search* keeps several best continuations, *beams*, at once and extends all of them at each step. A continuation's probability is the product of its tokens' probabilities, so logarithms are added. Add this and run it.

```python
def beam(start, steps, width):
    beams = [(0.0, start)]
    for _ in range(steps):
        grown = []
        for score, text in beams:
            for b, q in probs(text[-1]):
                grown.append((score + math.log(q), text + b))
        beams = sorted(grown, key=lambda kv: (-kv[0], kv[1]))[:width]
    return beams[0]


for width in (1, 2, 5):
    score, text = beam("п", 4, width)
    print(f"beam width {width}: {text!r}, probability {math.exp(score):.4f}")
```

```output
beam width 1: 'па ко', probability 0.0252
beam width 2: 'па ко', probability 0.0252
beam width 5: 'пёсыл', probability 0.0286
```

Width 1 is just greedy choice: «па ко». With width 5 the search found a more likely continuation, `0.0286` against `0.0252`, but it is «пёсыл», nonsense made of the scraps «пёс» ("dog") and «сыл». Here is the main lesson: the most likely text is not the best text. Holtzman and co-authors showed this on large models: human texts are not at all the most likely ones from the model's point of view. So beam search is good where the answer is short and nearly unambiguous, for example in translation, while free text is usually sampled at random with top-p.

**Step 4. A real model.** This needs a real model's probabilities. In «A live model on your Mac», `qwen2.5-coder:7b` already answered "The capital of France is", and its 20 best tokens were recorded. The filters were off for that recording, so the true distribution is visible. Add this and run it; Ollama is not needed.

```python
# qwen2.5-coder:7b after "The capital of France is", recorded 2026-11-02 (Ollama 0.40.13)
TOP20 = [
    (' Paris', -0.4599),
    (' __', -3.0503),
    (':\n', -3.1145),
    (' ______', -3.1598),
    (' a', -3.5436),
    (':\n\n', -3.5548),
    (' located', -3.5708),
    (' ____', -4.4905),
    (' the', -4.8847),
    (' not', -4.9136),
    (' ___', -5.0097),
    ('\n', -5.0983),
    (' in', -5.1732),
    ('____', -5.4525),
    (' an', -5.5102),
    (' known', -5.6419),
    (' also', -5.6668),
    (' situated', -5.6904),
    (' where', -5.7956),
    (' .\n', -5.8063)
]
real = [(token, math.exp(logprob)) for token, logprob in TOP20]
print("P(' Paris') =", round(real[0][1], 3), "| mass of the 20 best:", round(sum(q for _, q in real), 3))
for p in (0.5, 0.8, 0.9, 0.95):
    mass, size = 0.0, 0
    for _, q in real:
        mass += q
        size += 1
        if mass >= p:
            break
    print(f"top-p = {p}:", f"keeps {size}" if mass >= p else "keeps more than 20, the recording is too short")
print("top-k = 3 keeps", [token for token, _ in real[:3]])
```

```output
P(' Paris') = 0.631 | mass of the 20 best: 0.92
top-p = 0.5: keeps 1
top-p = 0.8: keeps 6
top-p = 0.9: keeps 14
top-p = 0.95: keeps more than 20, the recording is too short
top-k = 3 keeps [' Paris', ' __', ':\n']
```

What you saw. " Paris" gets 0.631, while the 20 best together get only 0.92: the remaining 8 % is spread over thousands of tokens. At `p = 0.9` the nucleus holds 14 tokens, at `p = 0.5` one. At `p = 0.95` the recording is not enough: the nucleus is larger than 20, and its size honestly cannot be told from this recording. Note a second thing: top-k = 3 kept " __" and a line break. The model took the phrase for a "fill in the blank" exercise. Top-k and top-p keep the top of the list, whatever it is: they cannot remove likely junk.

In Ollama these rules are set by the `top_k`, `top_p` and `temperature` parameters. According to the Ollama documentation the defaults are `top_k = 40`, `top_p = 0.9` and `temperature = 0.8` unless a model sets its own. The order matters: first the tail is cut, then a random token is chosen from the rest.

**Learn from the people who build this.** The paper [The Curious Case of Neural Text Degeneration](https://arxiv.org/abs/1904.09751), which proposed top-p. Karpathy shows next-token sampling in [Let's build GPT](https://karpathy.ai/zero-to-hero.html).

### Explore and practise

In the lab below the bars are the real probabilities of the 20 best tokens. Move `k` and `p`: grey bars are cut off. There is no temperature here: the tail beyond the 20 tokens was not recorded, so it cannot be recomputed honestly. Press "Pick 50 times" and see which tokens actually come up. Find a setting that leaves only " Paris", and one with a nucleus of more than 10 tokens.

### Question

Beam search of width 5 found a continuation more likely than the greedy one, but it is the nonsense «пёсыл». What does this show?

### Options

- The most likely continuation is not necessarily good text: search maximizes probability, not meaning
- Beam search has a bug: with a correct program it would always find words that make sense
- Width 5 is too small, and at width 50 the search would surely have found a proper word

### Answer

1

### Explanation

The search does exactly what it was told: it looks for a larger product of probabilities. Our model remembers one letter, and for it «пёсыл» is more plausible than «па ко». The program is not at fault, and a larger width would only find something even more likely, not more meaningful. Large models carry more meaning, but even for them the most likely text is often dull and repetitive.

### Limits

The pair counter knows one letter, so its texts are meaningless under any choice rule. The real model's probabilities here cover only one place in one text and only the 20 best tokens, so the nucleus size at large `p` cannot be told from them. There are other rules too, such as `min_p` in Ollama and a repetition penalty; they are not covered here.

## Sources

- Ari Holtzman, Jan Buys, Li Du, Maxwell Forbes, Yejin Choi, "The Curious Case of Neural Text Degeneration", arXiv:1904.09751 (2019), the definition of the top-p vocabulary (equation 2) read 2026-11-07: [arXiv:1904.09751](https://arxiv.org/abs/1904.09751)
- Ollama, Modelfile reference, the `top_k`, `top_p`, `min_p` and `temperature` parameters and their defaults read 2026-11-07: [docs](https://docs.ollama.com/modelfile)
- The 20 best tokens of `qwen2.5-coder:7b` were recorded with Ollama 0.40.13 on 2026-11-02 for the lesson «A live model on your Mac»: `02_Areas/Programming/resources/live_model_recording.json`. The pair counter, beam search and all other numbers were computed for this lesson on 2026-11-07.
