---
subject: programming
lesson_id: programming.agi_scaling_debate
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Спор о масштабировании / The scaling debate

## Русский

### Простыми словами

Несколько лет ошибка языковых моделей падала очень ровно, когда росли размер модели, данные и вычисления. На графике в логарифмах это почти прямая линия, её называют степенным законом. Главный спор: продолжится ли эта линия до AGI. Представь кривую роста ребёнка: за первые годы она гладкая, но если продолжить её до тридцати лет, выйдет великан. Хорошее совпадение на измеренных точках ещё не говорит, что будет дальше. В уроке ты сам подгонишь такой закон и увидишь, как он обманывает на продолжении.

**Что нужно знать до.** Урок «Своя языковая модель» (шаг 12): ошибка на тексте, которого модель не видела. Логарифм встречается в уроке «Информация, энтропия и кросс-энтропия» (шаг 6).

**Если непонятно.** Если неясно, почему степень на графике в логарифмах становится прямой, перечитай пример руками в шаге 1: там всё посчитано на двух точках. Если неясен логарифм, вернись к уроку «Информация, энтропия и кросс-энтропия». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Разобрать главный спор пути к AGI: хватит ли просто больше данных и вычислений. Подогнать степенной закон своими руками, увидеть, как он обманывает на продолжении, и научиться отделять измерения от прогнозов и мнений. Нужно около 40 минут.

### Идея и механизм

**Шаг 1. Откуда спор.** В 2020 году Kaplan и соавторы измерили, что ошибка языковых моделей падает очень ровно как **степень** от числа параметров, данных и вычислений. Прямая линия на графике в логарифмах! Отсюда простая и сильная мысль: больше вычислений значит лучше, причём предсказуемо. Но степенной закон это наблюдение на измеренном участке, а не закон природы.

Руками: пусть при `n = 100` ошибка `2`, а при `n = 10000` ошибка `1`. Показатель это наклон в логарифмах: `ln(1/2) / ln(100) = −0,15`. Значит, ошибка равна `c · n^(−0,15)`, и каждые 100 раз данных делят её пополам.

**Шаг 2. Опыт.** Модель это счётчик: по 3 символам предсказывает следующий. Текст случайно сложен из 17 слов. Обучим на разном объёме. Создай файл `nano ~/ai-path/scale.py`, вставь и запусти. Справа ошибка на новом тексте.

```python
class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53

    def below(self, limit):
        return int(self.next() * limit)


import math

WORDS = ["кот", "пёс", "мама", "папа", "дед", "гусь", "ест", "видит", "любит", "ищет", "несёт", "рыбу", "воду", "кашу", "мяч", "дом", "траву"]


def text_of(length, seed):
    rand = Rand(seed)
    parts = []
    size = 0
    while size < length:
        word = WORDS[rand.below(len(WORDS))]
        parts.append(word)
        size += len(word) + 1
    return " ".join(parts)[:length]


CHECK = text_of(20000, 999)
ALPHABET = sorted(set(text_of(200000, 1)))


def error(train_size, order=3):
    train = text_of(train_size, 1)
    counts, totals = {}, {}
    for i in range(order, len(train)):
        key = train[i - order:i]
        counts[key, train[i]] = counts.get((key, train[i]), 0) + 1
        totals[key] = totals.get(key, 0) + 1
    total = 0.0
    for i in range(order, len(CHECK)):
        key = CHECK[i - order:i]
        total -= math.log((counts.get((key, CHECK[i]), 0) + 0.1) / (totals.get(key, 0) + 0.1 * len(ALPHABET)))
    return total / (len(CHECK) - order)


SIZES = [100, 300, 1000, 3000, 10000, 30000, 100000]
ERRORS = [error(n) for n in SIZES]
for n, e in zip(SIZES, ERRORS):
    print(n, round(e, 3))
```

```output
100 2.144
300 1.593
1000 1.088
3000 0.764
10000 0.631
30000 0.599
100000 0.587
```

**Шаг 3. Закон и обман.** Подгоним степенной закон только по первым 4 точкам и проверим его на остальных. Допиши и запусти.

```python
def fit(xs, ys):
    lx, ly = [math.log(x) for x in xs], [math.log(y) for y in ys]
    mx, my = sum(lx) / len(lx), sum(ly) / len(ly)
    slope = sum((a - mx) * (b - my) for a, b in zip(lx, ly)) / sum((a - mx) ** 2 for a in lx)
    return slope, math.exp(my - slope * mx)


slope, scale = fit(SIZES[:4], ERRORS[:4])
print("law from the first 4 sizes: error =", round(scale, 2), "* n ^", round(slope, 3))
for n, e in zip(SIZES, ERRORS):
    print(n, "real", round(e, 3), "law", round(scale * n ** slope, 3))
print("law at a billion characters", round(scale * (10 ** 9) ** slope, 3))
slope2, scale2 = fit(SIZES[-3:], ERRORS[-3:])
print("law from the last 3 sizes: exponent", round(slope2, 3))
```

```output
law from the first 4 sizes: error = 8.88 * n ^ -0.305
100 real 2.144 law 2.18
300 real 1.593 law 1.559
1000 real 1.088 law 1.08
3000 real 0.764 law 0.773
10000 real 0.631 law 0.535
30000 real 0.599 law 0.383
100000 real 0.587 law 0.265
law at a billion characters 0.016
law from the last 3 sizes: exponent -0.031
```

На первых точках закон сходится очень точно: `1,088` и `1,08`. Отличный результат, можно хвалиться. А дальше: при 100 000 символов настоящая ошибка `0,587`, а закон обещает `0,265`. На миллиарде символов он обещает `0,016`, а на деле ошибка уже почти не падает: показатель по последним точкам всего `−0,031`.

Почему? В этом тексте есть **нижний предел**. Следующее слово выбрано случайно из 17, поэтому `ln 17 = 2,83` единицы неопределённости на слово, а средняя длина слова с пробелом `4,88` символа. Получаем предел `2,83 / 4,88 = 0,58`. Ниже никакая модель не опустится. **Прямая идёт, пока не упрётся, и заранее по ней этого не увидишь.** Есть ли такой предел у настоящих задач и где он, неизвестно: это и есть спор. Здесь предел задан моим текстом, а в настоящих данных он может лежать намного ниже.

**Шаг 4. Ещё продолжение.** METR, независимая исследовательская группа, которая оценивает возможности ИИ, измерила в 2025 году, что длина задач, которые агенты решают в половине случаев, удваивается примерно за 7 месяцев. Это измерение прошлого. Посчитаем продолжение, начиная для примера с одного часа. Допиши и запусти.

```python
print("METR: months from now, hours of work an agent can do at 50 % if the trend of doubling every 7 months holds, starting from 1 hour")
for months in (0, 7, 14, 28, 56, 84):
    print(months, 2 ** (months / 7))
```

```output
METR: months from now, hours of work an agent can do at 50 % if the trend of doubling every 7 months holds, starting from 1 hour
0 1.0
7 2.0
14 4.0
28 16.0
56 256.0
84 4096.0
```

За 7 лет выходит 4096 часов, это около двух лет работы человека по 40 часов в неделю. Сам расчёт простой, а вопрос в том, продолжится ли кривая. Сравни с шагом 3.

**Шаг 5. Что измерено, что предсказано, кто спорит.**

| Утверждение | Что это | Откуда |
|---|---|---|
| Ошибка падает как степень от вычислений на изученном участке | Измерение | Kaplan и др., 2020 |
| Данных на параметр нужно больше, чем думали, около 20 токенов на параметр | Измерение | Hoffmann и др., 2022 |
| Длина задач агентов удваивается примерно за 7 месяцев | Измерение прошлого | METR, 2025 |
| В одном опыте опытные разработчики с ИИ работали на 19 % медленнее, хотя считали, что быстрее | Измерение на узком случае | METR, 2025 |
| В долгую побеждают общие методы плюс рост вычислений | Довод из истории, мнение | Sutton, 2019 |
| Эпоха простого масштабирования кончается, снова нужны исследования | Мнение | Sutskever, 2025 |
| Масштабирование одно дойдёт до AGI | Прогноз | Часть компаний, спорно |
| Без новых идей масштабирование упрётся | Прогноз | Лекун, Шолле и другие, спорно |

Заметь: опыт METR с 19 % и кривая METR не спорят: одно меряет задачу в особых условиях, другое меряет другое. Часто «противоречие» бывает просто разными вопросами. И рост и торможение можно подтвердить примерами. Моё мнение как автора урока не имеет большого веса, поэтому здесь его нет: прочитай обе стороны и сравни их с числами.

**Учись у тех, кто это создаёт.** [The Bitter Lesson](http://www.incompleteideas.net/IncIdeas/BitterLesson.html) всего на две страницы. Статьи [Kaplan и др.](https://arxiv.org/abs/2001.08361) и [Hoffmann и др.](https://arxiv.org/abs/2203.15556). Два опыта METR: [задачи](https://arxiv.org/abs/2503.14499) и [разработчики](https://arxiv.org/abs/2507.09089). Лекции 2, 9 и 11 курса [Stanford CS336](https://stanford-cs336.github.io/spring2025/).

### Исследуй и потренируйся

В тренажёре настоящие точки этого опыта. Подгоняй закон по разному числу первых точек и смотри, что он обещает дальше. Затем разложи утверждения по трём видам.

В программе поменяй 17 слов на 170. Что станет с нижним пределом? Сначала посчитай его руками.

### Вопрос

Закон отлично сходится на измеренных точках. Что это говорит о продолжении?

### Варианты

- Почти ничего наверняка: кривая может упереться в предел, которого на участке не видно.
- Продолжение будет точным, потому что хорошая подгонка на участке доказывает весь закон.
- Продолжение всегда неверно, потому что степенной закон никогда не описывает настоящее.

### Ответ

1

### Разбор

Хорошая подгонка на участке верна только для участка. В опыте закон был точен на первых 4 точках и сильно ошибся дальше, но нельзя сказать, что он неверен всегда: у Kaplan он описал большой настоящий участок. Поэтому спорить надо о том, где и почему кривая может измениться.

### Границы модели

Счётчик символов это не языковая модель, и предел в моём тексте задан мной. У настоящих задач такого простого предела может не быть. Таблица это моё сжатое пересказывание чужих работ, поэтому сверяй с первоисточниками. Мнение людей со временем меняется, и даты здесь важны.

## English

### In plain words

For several years the error of language models fell very smoothly as model size, data and compute grew. On a log graph this is almost a straight line, called a power law. The main dispute: will this line continue all the way to AGI. Picture a child's growth curve: it is smooth for the first years, but if you extend it to age thirty you get a giant. A good fit on measured points does not yet say what comes next. In the lesson you fit such a law yourself and see how it misleads when extended.

**What to know first.** The lesson «Your Own Language Model» (step 12): error on text the model has not seen. The logarithm appears in «Information, Entropy, and Cross-Entropy» (step 6).

**If something is unclear.** If it is unclear why a power becomes a straight line on a log graph, reread the worked example in step 1: everything is computed from two points. If the logarithm is unclear, go back to «Information, Entropy, and Cross-Entropy». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Examine the main dispute on the road to AGI: will just more data and computing be enough? Fit a power law by hand, see how it deceives when extended, and learn to separate measurements from forecasts and opinions. It takes about 40 minutes.

### Idea and mechanism

**Step 1. Where the dispute comes from.** In 2020 Kaplan and co-authors measured that the error of language models falls very evenly as a **power** of the number of parameters, data and computing. A straight line on a log-log chart! Hence a simple and strong idea: more computing means better, predictably so. But a power law is an observation on the measured range, not a law of nature.

By hand: suppose at `n = 100` the error is `2`, and at `n = 10000` it is `1`. The exponent is the slope in logarithms: `ln(1/2) / ln(100) = −0.15`. So the error equals `c · n^(−0.15)`, and each 100 times more data halves it.

**Step 2. The experiment.** The model is a counter: from 3 characters it predicts the next. The text is randomly composed of 17 words. We train on various amounts. Create the file `nano ~/ai-path/scale.py`, paste and run it. On the right is the error on new text.

```python
class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53

    def below(self, limit):
        return int(self.next() * limit)


import math

WORDS = ["кот", "пёс", "мама", "папа", "дед", "гусь", "ест", "видит", "любит", "ищет", "несёт", "рыбу", "воду", "кашу", "мяч", "дом", "траву"]


def text_of(length, seed):
    rand = Rand(seed)
    parts = []
    size = 0
    while size < length:
        word = WORDS[rand.below(len(WORDS))]
        parts.append(word)
        size += len(word) + 1
    return " ".join(parts)[:length]


CHECK = text_of(20000, 999)
ALPHABET = sorted(set(text_of(200000, 1)))


def error(train_size, order=3):
    train = text_of(train_size, 1)
    counts, totals = {}, {}
    for i in range(order, len(train)):
        key = train[i - order:i]
        counts[key, train[i]] = counts.get((key, train[i]), 0) + 1
        totals[key] = totals.get(key, 0) + 1
    total = 0.0
    for i in range(order, len(CHECK)):
        key = CHECK[i - order:i]
        total -= math.log((counts.get((key, CHECK[i]), 0) + 0.1) / (totals.get(key, 0) + 0.1 * len(ALPHABET)))
    return total / (len(CHECK) - order)


SIZES = [100, 300, 1000, 3000, 10000, 30000, 100000]
ERRORS = [error(n) for n in SIZES]
for n, e in zip(SIZES, ERRORS):
    print(n, round(e, 3))
```

```output
100 2.144
300 1.593
1000 1.088
3000 0.764
10000 0.631
30000 0.599
100000 0.587
```

**Step 3. The law and the deception.** We fit a power law to only the first 4 points and check it on the rest. Add this and run it.

```python
def fit(xs, ys):
    lx, ly = [math.log(x) for x in xs], [math.log(y) for y in ys]
    mx, my = sum(lx) / len(lx), sum(ly) / len(ly)
    slope = sum((a - mx) * (b - my) for a, b in zip(lx, ly)) / sum((a - mx) ** 2 for a in lx)
    return slope, math.exp(my - slope * mx)


slope, scale = fit(SIZES[:4], ERRORS[:4])
print("law from the first 4 sizes: error =", round(scale, 2), "* n ^", round(slope, 3))
for n, e in zip(SIZES, ERRORS):
    print(n, "real", round(e, 3), "law", round(scale * n ** slope, 3))
print("law at a billion characters", round(scale * (10 ** 9) ** slope, 3))
slope2, scale2 = fit(SIZES[-3:], ERRORS[-3:])
print("law from the last 3 sizes: exponent", round(slope2, 3))
```

```output
law from the first 4 sizes: error = 8.88 * n ^ -0.305
100 real 2.144 law 2.18
300 real 1.593 law 1.559
1000 real 1.088 law 1.08
3000 real 0.764 law 0.773
10000 real 0.631 law 0.535
30000 real 0.599 law 0.383
100000 real 0.587 law 0.265
law at a billion characters 0.016
law from the last 3 sizes: exponent -0.031
```

On the first points the law agrees very closely: `1.088` and `1.08`. An excellent result to boast of. And then: at 100,000 characters the real error is `0.587`, and the law promises `0.265`. At a billion characters it promises `0.016`, while in truth the error hardly falls any more: the exponent over the last points is only `−0.031`.

Why? This text has a **lower limit**. The next word is picked at random from 17, so there are `ln 17 = 2.83` units of uncertainty per word, and the mean length of a word with its space is `4.88` characters. That gives a limit of `2.83 / 4.88 = 0.58`. No model goes lower. **The line runs until it hits something, and you cannot see that in advance from it.** Whether real tasks have such a limit, and where, is unknown: that is the dispute. Here my text sets the limit, while in real data it may lie far lower.

**Step 4. Another extension.** METR, an independent research group that evaluates AI capabilities, measured in 2025 that the length of tasks agents solve half the time doubles about every 7 months. That measures the past. We compute the extension, starting for the sake of example from one hour. Add this and run it.

```python
print("METR: months from now, hours of work an agent can do at 50 % if the trend of doubling every 7 months holds, starting from 1 hour")
for months in (0, 7, 14, 28, 56, 84):
    print(months, 2 ** (months / 7))
```

```output
METR: months from now, hours of work an agent can do at 50 % if the trend of doubling every 7 months holds, starting from 1 hour
0 1.0
7 2.0
14 4.0
28 16.0
56 256.0
84 4096.0
```

Over 7 years that gives 4096 hours, about two years of a person's work at 40 hours a week. The calculation is simple, and the question is whether the curve continues. Compare with step 3.

**Step 5. What is measured, what is forecast, who disputes.**

| Claim | What it is | From |
|---|---|---|
| Error falls as a power of computing over the studied range | Measurement | Kaplan et al., 2020 |
| More data per parameter is needed than was thought, about 20 tokens per parameter | Measurement | Hoffmann et al., 2022 |
| The length of agents' tasks doubles about every 7 months | Measurement of the past | METR, 2025 |
| In one study experienced developers with AI worked 19 % more slowly, though believing they were faster | Measurement of a narrow case | METR, 2025 |
| In the long run general methods plus growing computing win | An argument from history, an opinion | Sutton, 2019 |
| The age of plain scaling is ending, and research is needed again | Opinion | Sutskever, 2025 |
| Scaling alone will reach AGI | Forecast | Some companies, disputed |
| Without new ideas scaling will hit a wall | Forecast | LeCun, Chollet and others, disputed |

Note: the 19 % study and the METR curve do not conflict: one measures a task under special conditions, the other measures something else. A "contradiction" often means just different questions. Both growth and slowing can be backed with examples. My opinion as the lesson's author carries little weight, so it is not here: read both sides and compare them with the numbers.

**Learn from the people who build this.** [The Bitter Lesson](http://www.incompleteideas.net/IncIdeas/BitterLesson.html) is only two pages. The papers by [Kaplan et al.](https://arxiv.org/abs/2001.08361) and [Hoffmann et al.](https://arxiv.org/abs/2203.15556). METR's two studies: [tasks](https://arxiv.org/abs/2503.14499) and [developers](https://arxiv.org/abs/2507.09089). Lectures 2, 9 and 11 of [Stanford CS336](https://stanford-cs336.github.io/spring2025/).

### Explore and practise

The lab has this experiment's real points. Fit the law to a varying number of first points and see what it promises further. Then sort the claims into three kinds.

In the program, change 17 words to 170. What happens to the lower limit? Compute it by hand first.

### Question

A law fits the measured points excellently. What does that say about the extension?

### Options

- Almost nothing for certain: the curve may hit a limit that the range does not show.
- The extension will be accurate, because a good fit on the range proves the whole law.
- The extension is always wrong, because a power law never describes anything real.

### Answer

1

### Explanation

A good fit on a range holds only for that range. In the experiment the law was accurate on the first 4 points and erred greatly further on, but you cannot say it is always wrong: Kaplan's described a large real range. So the argument must be about where and why the curve may change.

### Limits

A character counter is not a language model, and I set the limit in my text. Real tasks may have no such simple limit. The table is my condensed retelling of others' work, so check it against the primary sources. People's opinions change over time, and the dates matter here.

## Sources

- Jared Kaplan et al., "Scaling Laws for Neural Language Models", arXiv:2001.08361 (2020), title read 2026-11-03: [arXiv:2001.08361](https://arxiv.org/abs/2001.08361)
- Jordan Hoffmann et al., "Training Compute-Optimal Large Language Models", arXiv:2203.15556 (2022), read 2026-11-03: 1.4 trillion tokens for 70 billion parameters, which gives the ratio of 20 tokens per parameter: [arXiv:2203.15556](https://arxiv.org/abs/2203.15556)
- Thomas Kwa et al. (METR), "Measuring AI Ability to Complete Long Software Tasks", arXiv:2503.14499 (2025), title read 2026-11-03: [arXiv:2503.14499](https://arxiv.org/abs/2503.14499)
- Joel Becker et al. (METR), "Measuring the Impact of Early-2025 AI on Experienced Open-Source Developer Productivity", arXiv:2507.09089 (2025), abstract read 2026-11-03: [arXiv:2507.09089](https://arxiv.org/abs/2507.09089)
- Richard Sutton, "The Bitter Lesson" (2019), read 2026-11-03: [essay](http://www.incompleteideas.net/IncIdeas/BitterLesson.html)
- Ilya Sutskever, interview on the Dwarkesh Podcast (2025), the title "We're moving from the age of scaling to the age of research" read 2026-11-03, the transcript not re-read: [episode](https://www.dwarkesh.com/p/ilya-sutskever-2)
- Stanford CS336, title read 2026-11-03: [course](https://stanford-cs336.github.io/spring2025/)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
