---
subject: programming
lesson_id: programming.consciousness_higher_order_and_prediction
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Мысль о мысли и предсказание / Thoughts about thoughts and prediction

## Русский

### Цель

Разобрать две теории: сознание как состояние о своём состоянии и сознание как предсказание. Измерить метапознание на маленькой модели: понимает ли она, когда ошибается, и как это чинится. Затем честно сказать, чем это не является. Нужно около 40 минут.

### Идея и механизм

**Шаг 1. Теории высшего порядка.** Дэвид Розенталь и другие говорят так: восприятие становится сознательным, когда система как-то **представляет сама себе**, что она это воспринимает. Хакван Лау и коллеги развивают близкий взгляд через **метапознание**: особая система следит, надёжен ли сигнал или это шум. Отсюда проверяемый вопрос: можно ли разъединить результат и уверенность? В опытах бывает, что точность та же, а уверенность разная.

**Шаг 2. Уверенность модели.** Построим простой случай. Классификатор на шумных точках и всего 40 обучающих примерах, с лишними признаками, поэтому он заучивает шум. Его уверенность это большая из вероятностей softmax. **Откалибрована** ли она? Если модель говорит «90 %», верна ли она в 90 % случаев? Создай файл `nano ~/ai-path/meta.py`, вставь и запусти. Строка это корзина уверенности: сколько точек, настоящая доля верных и средняя уверенность.

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


def sample(count, seed, spread=1.3):
    rand = Rand(seed)
    out = []
    for _ in range(count):
        label = rand.below(2)
        centre = 1.0 if label else -1.0
        x = centre + spread * (sum(rand.next() for _ in range(12)) - 6)
        y = rand.next() * 2 - 1
        out.append((x, y, label))
    return out


TRAIN, CHECK = sample(40, 1), sample(1000, 2)


def extras(x, y):
    return [x, y, math.sin(9 * x), math.sin(9 * y), math.cos(13 * x), math.sin(5 * x + 7 * y)]


def train(data, epochs=400, rate=0.3):
    weights, bias = [0.0] * 6, 0.0
    for _ in range(epochs):
        for x, y, label in data:
            f = extras(x, y)
            s = sum(a * b for a, b in zip(weights, f)) + bias
            p = 1 / (1 + math.exp(-max(min(s, 30), -30)))
            for j in range(6):
                weights[j] += rate * (label - p) * f[j]
            bias += rate * (label - p)
    return weights, bias


weights, bias = train(TRAIN)


def score(x, y):
    return sum(a * b for a, b in zip(weights, extras(x, y))) + bias


def confidence(s, temperature=1.0):
    p = 1 / (1 + math.exp(-max(min(s / temperature, 30), -30)))
    return max(p, 1 - p)


def reliability(temperature, bins=5):
    rows = [[0, 0, 0.0] for _ in range(bins)]
    for x, y, label in CHECK:
        s = score(x, y)
        c = confidence(s, temperature)
        b = min(int((c - 0.5) * 2 * bins), bins - 1)
        rows[b][0] += 1
        rows[b][1] += (s > 0) == bool(label)
        rows[b][2] += c
    gap = sum(abs(r[1] - r[2]) for r in rows if r[0]) / len(CHECK)
    return [(r[0], round(r[1] / r[0], 2), round(r[2] / r[0], 2)) if r[0] else (0, None, None) for r in rows], round(gap, 3)


accuracy = sum((score(x, y) > 0) == bool(label) for x, y, label in CHECK) / len(CHECK)
print("accuracy on new points", round(accuracy, 3))
print("bin: count, accuracy, mean confidence")
for row in reliability(1.0)[0]:
    print(row)
print("gap", reliability(1.0)[1])
```

```output
accuracy on new points 0.717
bin: count, accuracy, mean confidence
(125, 0.46, 0.55)
(122, 0.57, 0.65)
(160, 0.68, 0.75)
(202, 0.7, 0.85)
(391, 0.87, 0.96)
gap 0.099
```

Точность `0,717`, а в верхней корзине модель уверена в среднем на `0,96`, хотя верна только в `0,87`. Она **самоуверенна**. Средний разрыв `0,099`. Посчитай руками для корзины 4: `|0,70 − 0,85| = 0,15`, вес `202/1000`, вклад `0,03`.

**Шаг 3. Лечение.** Разделим логиты на **температуру** `T`: ответы при этом не меняются, ведь знак тот же, а уверенность падает. При `T = 2` логит `2` становится `1`, уверенность падает с `0,88` до `0,73`. Допиши и запусти.

```python
for temperature in (1.0, 2.0, 4.0, 8.0, 16.0):
    print("temperature", temperature, "gap", reliability(temperature)[1])
```

```output
temperature 1.0 gap 0.099
temperature 2.0 gap 0.031
temperature 4.0 gap 0.097
temperature 8.0 gap 0.154
temperature 16.0 gap 0.185
```

При `T = 2` разрыв `0,031`, а дальше снова растёт: `T = 16` даёт `0,185`, модель уже слишком робка. Заметь: **мы улучшили её знание о себе, а ответы не изменились ни разу.** Именно такое разъединение результата и уверенности важно теориям высшего порядка, но не считай его доказательством.

**Шаг 4. Знает ли, когда ошибается?** Калибровка смотрит на средние. Другой вопрос: верные ответы увереннее неверных? Если взять один верный и один неверный, насколько часто верный увереннее? Для случая `0,5`, для идеала `1,0`. Допиши и запусти.

```python
pairs = [(confidence(score(x, y), 1.0), (score(x, y) > 0) == bool(label)) for x, y, label in CHECK]
right = [c for c, ok in pairs if ok]
wrong = [c for c, ok in pairs if not ok]
wins = 0.0
for a in right[::4]:
    for b in wrong[::2]:
        wins += 1.0 if a > b else 0.5 if a == b else 0.0
print("type 2 score: how often a right answer is more confident than a wrong one", round(wins / (len(right[::4]) * len(wrong[::2])), 3))
```

```output
type 2 score: how often a right answer is more confident than a wrong one 0.726
```

`0,726`. Лучше случая, но далеко от идеала. Похожее измеряют у языковых моделей: Kadavath и соавторы показали, что большие модели неплохо оценивают, знают ли они ответ, но неидеально.

**Шаг 5. Предсказательная обработка.** Другая большая идея (Энди Кларк, Анил Сет и др.): мозг всё время предсказывает вход и исправляет ошибку. Формула знакома с урока об автоматах: `оценка ← оценка + шаг · (вход − оценка)`. Пусть оценка `10`, вход `14`, шаг `0,25`: новая оценка `11`, ошибка `4`. Сет идёт дальше: то, что мы переживаем, это скорее лучшая догадка мозга о причинах сигналов, а не сами сигналы. «Контролируемая галлюцинация», как он это называет. Особое место занимает догадка о собственном теле.

**Шаг 6. Спор и граница.**

*Спорно:* нужно ли метапознание для сознания. Критики указывают: младенцы и животные могут переживать, плохо следя за собой. Сторонники отвечают, что нужен не отчёт, а простейшая внутренняя пометка. Для предсказательной обработки неясно, как она вообще объясняет именно переживание, а не просто работу восприятия.

*Граница:* температура это одно число, деление. Никто не считает, что модель от этого что-то переживает. Запомни: уметь оценивать свою уверенность и чувствовать уверенность не обязательно одно и то же.

**Учись у тех, кто это создаёт.** Обзор [Brown, Lau и LeDoux](https://www.cell.com/trends/cognitive-sciences/fulltext/S1364-6613(19)30161-4). Выступление [Анила Сета на TED](https://www.ted.com/talks/anil_seth_your_brain_hallucinates_your_conscious_reality). Калибровка: [Guo и др.](https://arxiv.org/abs/1706.04599). Языковые модели: [Kadavath и др.](https://arxiv.org/abs/2207.05221).

### Исследуй и потренируйся

В тренажёре настоящая диаграмма надёжности этой модели. Столбцы это настоящая доля верных, а диагональ это идеал. Двигай температуру и добейся, чтобы столбцы легли на диагональ, глядя, что точность при этом не меняется.

В программе возьми больше обучающих точек, например 400. Станет ли модель сама лучше знать свои ошибки?

### Вопрос

Что меняет температура в нашей модели?

### Варианты

- Только уверенность: ответы те же, поэтому точность остаётся прежней при любом T.
- Только ответы: уверенность та же, поэтому надёжность модели остаётся прежней.
- И ответы, и уверенность: чем больше T, тем выше точность на новых данных.

### Ответ

1

### Разбор

Деление на положительное число не меняет знак, поэтому выбранный класс тот же, и точность остаётся `0,717`. Меняется только то, насколько близка вероятность к единице. Как раз это и разъединяет результат с уверенностью, и потому такой пример интересен.

### Границы модели

Модель это логистическая регрессия на игрушечных данных. Я подобрал данные так, чтобы самоуверенность была заметна. Калибровка не имеет прямого отношения к сознанию, и связь здесь лишь в том, что теории высшего порядка говорят о метапознании. Отображение спора короткое, и обе теории намного богаче.

## English

### Goal

Examine two theories: consciousness as a state about one's own state, and consciousness as prediction. Measure metacognition on a small model: does it know when it errs, and how can that be repaired. Then say honestly what this is not. It takes about 40 minutes.

### Idea and mechanism

**Step 1. Higher-order theories.** David Rosenthal and others say this: a perception becomes conscious when a system somehow **represents to itself** that it perceives it. Hakwan Lau and colleagues develop a close view through **metacognition**: a special system monitors whether a signal is reliable or noise. Hence a testable question: can result and confidence be separated? In experiments accuracy may stay the same while confidence differs.

**Step 2. A model's confidence.** We build a simple case. A classifier on noisy points and only 40 training examples, with extra features, so it memorizes noise. Its confidence is the larger softmax probability. Is it **calibrated**? When the model says "90 %", is it right 90 % of the time? Create the file `nano ~/ai-path/meta.py`, paste and run it. A row is a confidence bin: how many points, the real share right, and the mean confidence.

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


def sample(count, seed, spread=1.3):
    rand = Rand(seed)
    out = []
    for _ in range(count):
        label = rand.below(2)
        centre = 1.0 if label else -1.0
        x = centre + spread * (sum(rand.next() for _ in range(12)) - 6)
        y = rand.next() * 2 - 1
        out.append((x, y, label))
    return out


TRAIN, CHECK = sample(40, 1), sample(1000, 2)


def extras(x, y):
    return [x, y, math.sin(9 * x), math.sin(9 * y), math.cos(13 * x), math.sin(5 * x + 7 * y)]


def train(data, epochs=400, rate=0.3):
    weights, bias = [0.0] * 6, 0.0
    for _ in range(epochs):
        for x, y, label in data:
            f = extras(x, y)
            s = sum(a * b for a, b in zip(weights, f)) + bias
            p = 1 / (1 + math.exp(-max(min(s, 30), -30)))
            for j in range(6):
                weights[j] += rate * (label - p) * f[j]
            bias += rate * (label - p)
    return weights, bias


weights, bias = train(TRAIN)


def score(x, y):
    return sum(a * b for a, b in zip(weights, extras(x, y))) + bias


def confidence(s, temperature=1.0):
    p = 1 / (1 + math.exp(-max(min(s / temperature, 30), -30)))
    return max(p, 1 - p)


def reliability(temperature, bins=5):
    rows = [[0, 0, 0.0] for _ in range(bins)]
    for x, y, label in CHECK:
        s = score(x, y)
        c = confidence(s, temperature)
        b = min(int((c - 0.5) * 2 * bins), bins - 1)
        rows[b][0] += 1
        rows[b][1] += (s > 0) == bool(label)
        rows[b][2] += c
    gap = sum(abs(r[1] - r[2]) for r in rows if r[0]) / len(CHECK)
    return [(r[0], round(r[1] / r[0], 2), round(r[2] / r[0], 2)) if r[0] else (0, None, None) for r in rows], round(gap, 3)


accuracy = sum((score(x, y) > 0) == bool(label) for x, y, label in CHECK) / len(CHECK)
print("accuracy on new points", round(accuracy, 3))
print("bin: count, accuracy, mean confidence")
for row in reliability(1.0)[0]:
    print(row)
print("gap", reliability(1.0)[1])
```

```output
accuracy on new points 0.717
bin: count, accuracy, mean confidence
(125, 0.46, 0.55)
(122, 0.57, 0.65)
(160, 0.68, 0.75)
(202, 0.7, 0.85)
(391, 0.87, 0.96)
gap 0.099
```

Accuracy is `0.717`, yet in the top bin the model is on average `0.96` sure while right only `0.87` of the time. It is **overconfident**. The mean gap is `0.099`. Compute by hand for bin 4: `|0.70 − 0.85| = 0.15`, weight `202/1000`, contribution `0.03`.

**Step 3. The cure.** Divide logits by a **temperature** `T`: answers do not change, as the sign stays, while confidence falls. At `T = 2` a logit of `2` becomes `1`, and confidence falls from `0.88` to `0.73`. Add this and run it.

```python
for temperature in (1.0, 2.0, 4.0, 8.0, 16.0):
    print("temperature", temperature, "gap", reliability(temperature)[1])
```

```output
temperature 1.0 gap 0.099
temperature 2.0 gap 0.031
temperature 4.0 gap 0.097
temperature 8.0 gap 0.154
temperature 16.0 gap 0.185
```

At `T = 2` the gap is `0.031`, and then it grows again: `T = 16` gives `0.185`, the model is now too timid. Note: **we improved its knowledge of itself, and not one answer changed.** Such a separation of result and confidence matters to higher-order theories, but do not take it as proof.

**Step 4. Does it know when it errs?** Calibration looks at means. Another question: are right answers more confident than wrong ones? Taking one right and one wrong, how often is the right one more confident? By chance `0.5`, ideally `1.0`. Add this and run it.

```python
pairs = [(confidence(score(x, y), 1.0), (score(x, y) > 0) == bool(label)) for x, y, label in CHECK]
right = [c for c, ok in pairs if ok]
wrong = [c for c, ok in pairs if not ok]
wins = 0.0
for a in right[::4]:
    for b in wrong[::2]:
        wins += 1.0 if a > b else 0.5 if a == b else 0.0
print("type 2 score: how often a right answer is more confident than a wrong one", round(wins / (len(right[::4]) * len(wrong[::2])), 3))
```

```output
type 2 score: how often a right answer is more confident than a wrong one 0.726
```

`0.726`. Better than chance, far from ideal. Something similar is measured in language models: Kadavath and co-authors showed that large models estimate rather well whether they know an answer, but not perfectly.

**Step 5. Predictive processing.** Another big idea (Andy Clark, Anil Seth and others): the brain constantly predicts its input and corrects the error. The formula is familiar from the slot machine lesson: `estimate ← estimate + step · (input − estimate)`. Suppose the estimate is `10`, the input `14`, the step `0.25`: the new estimate is `11`, the error `4`. Seth goes further: what we experience is rather the brain's best guess at the causes of signals, not the signals themselves. A "controlled hallucination", as he calls it. A guess about one's own body holds a special place.

**Step 6. The dispute and the boundary.**

*Disputed:* whether metacognition is needed for consciousness. Critics point out that infants and animals may have experience while monitoring themselves poorly. Supporters reply that what is needed is not a report but a simple inner tag. For predictive processing it is unclear how it explains experience as such, rather than just the work of perception.

*The boundary:* temperature is one number, a division. Nobody holds that it makes a model experience anything. Remember: estimating your confidence and feeling confidence need not be the same.

**Learn from the people who build this.** The survey by [Brown, Lau and LeDoux](https://www.cell.com/trends/cognitive-sciences/fulltext/S1364-6613(19)30161-4). [Anil Seth's TED talk](https://www.ted.com/talks/anil_seth_your_brain_hallucinates_your_conscious_reality). Calibration: [Guo et al.](https://arxiv.org/abs/1706.04599). Language models: [Kadavath et al.](https://arxiv.org/abs/2207.05221).

### Explore and practise

The lab has this model's real reliability diagram. Bars are the real share right, and the diagonal is the ideal. Move the temperature and get the bars onto the diagonal, while seeing that accuracy does not change.

In the program, take more training points, such as 400. Does the model itself come to know its errors better?

### Question

What does temperature change in our model?

### Options

- Only confidence: answers stay the same, so accuracy is unchanged at any T.
- Only answers: confidence stays the same, so the model's reliability is unchanged.
- Both answers and confidence: the larger T is, the higher the accuracy on new data.

### Answer

1

### Explanation

Dividing by a positive number does not change the sign, so the chosen class stays, and accuracy remains `0.717`. Only how close the probability is to one changes. That is exactly what separates result from confidence, which is why the example is interesting.

### Limits

The model is logistic regression on toy data. I chose the data to make overconfidence visible. Calibration has no direct link to consciousness; the only link here is that higher-order theories speak of metacognition. The account of the dispute is short, and both theories are far richer.

## Sources

- Richard Brown, Hakwan Lau, Joseph E. LeDoux, "Understanding the Higher-Order Approach to Consciousness", Trends in Cognitive Sciences 23 (2019), title and journal checked 2026-11-03; the paper itself not re-read: [article](https://www.cell.com/trends/cognitive-sciences/fulltext/S1364-6613(19)30161-4)
- David M. Rosenthal, "Consciousness and Mind", Oxford University Press (2005), details checked 2026-11-03; the book itself not re-read.
- Andy Clark, "Whatever next? Predictive brains, situated agents, and the future of cognitive science", Behavioral and Brain Sciences 36 (2013), title and journal checked 2026-11-03; the paper itself not re-read.
- Anil Seth, "Being You" (Dutton, 2021), details checked 2026-11-03 through a published review, the book itself not re-read; TED talk, page opened the same day: [Your brain hallucinates your conscious reality](https://www.ted.com/talks/anil_seth_your_brain_hallucinates_your_conscious_reality)
- Chuan Guo et al., "On Calibration of Modern Neural Networks", arXiv:1706.04599 (2017): [arXiv:1706.04599](https://arxiv.org/abs/1706.04599)
- Saurav Kadavath et al., "Language Models (Mostly) Know What They Know", arXiv:2207.05221 (2022): [arXiv:2207.05221](https://arxiv.org/abs/2207.05221)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
