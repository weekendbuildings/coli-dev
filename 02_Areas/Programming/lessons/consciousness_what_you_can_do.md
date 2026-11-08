---
subject: programming
lesson_id: programming.consciousness_what_you_can_do
level: advanced
languages: ru, en
source_checked: 2026-11-07
source_review_interval_days: 180
---

# Что можешь сделать ты / What you can do

## Русский

### Простыми словами

Готового пути к сознательному ИИ нет, и этот урок не делает вид, что он есть. Зато есть работа, которую посильно делать одному человеку уже сейчас: честно проверять утверждения, ставить маленькие опыты и знать, где идут большие исследования. Главный инструмент здесь не сложная техника, а привычка заранее записывать, что ты ждёшь и что будешь считать провалом. Похоже на ставку, сделанную до матча: после матча любой «знал заранее». В уроке ты сам проверишь гипотезу о модели на настоящих данных и увидишь, что даже заметная разница может оказаться недоказанной.

**Что нужно знать до.** Урок «Как модель ошибается и как это проверить» (шаг 1): откуда данные. Урок «Оценка, которая что-то значит» (шаг 15): доверительный интервал. Урок «Мысль о мысли и предсказание» (шаг 24): метапознание. Урок «Индикаторы» (шаг 25).

**Если непонятно.** Если неясен доверительный интервал, вернись к шагу 2 урока «Оценка, которая что-то значит». Если неясно, зачем вообще проверять уверенность модели, перечитай урок «Мысль о мысли и предсказание». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Записать гипотезу до опыта, проверить её на настоящих ответах локальной модели методом повторных выборок, честно назвать результат и составить список того, что посильно одному человеку и где идёт настоящая работа. Нужно около 35 минут.

### Идея и механизм

**Шаг 1. Записать до.** *Предрегистрация* значит: до того как смотреть на данные, записать гипотезу и правило, по которому она будет считаться подтверждённой. Иначе легко подогнать вывод под результат. Наша гипотеза касается *метапознания*, одного из индикаторов: знает ли модель, когда она права. Если знает, то её уверенные ответы должны быть верны чаще неуверенных. Данные это 20 настоящих ответов `qwen2.5-coder:7b` из урока «Как модель ошибается»: уверенность и верен ли ответ. Создай файл `nano ~/ai-path/youcan.py`, вставь и запусти.

```python
class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


# Written BEFORE looking at the data:
HYPOTHESIS = "answers with confidence 0.9 or more are right more often than the rest"
CRITERION = "the difference in accuracy is at least 0.2, and the 95 % interval of the difference is above zero"

# confidence and correctness of the 20 answers of qwen2.5-coder:7b from «How a model errs»
DATA = [(0.869, 1), (0.945, 1), (0.936, 1), (0.795, 0), (0.898, 1), (0.988, 1), (0.998, 1), (0.991, 1),
        (0.344, 0), (0.631, 0), (0.36, 0), (0.559, 0), (0.602, 0), (0.737, 1), (0.771, 0), (0.877, 0),
        (0.89, 0), (0.896, 1), (0.994, 0), (0.964, 0)]


def gap(rows):
    high = [right for conf, right in rows if conf >= 0.9]
    low = [right for conf, right in rows if conf < 0.9]
    if not high or not low:
        return None
    return sum(high) / len(high) - sum(low) / len(low)


high = [right for conf, right in DATA if conf >= 0.9]
low = [right for conf, right in DATA if conf < 0.9]
print(f"confidence >= 0.9: {sum(high)} right of {len(high)}; below 0.9: {sum(low)} right of {len(low)}")
print(f"difference in accuracy: {gap(DATA):.2f}")
```

```output
confidence >= 0.9: 5 right of 7; below 0.9: 4 right of 13
difference in accuracy: 0.41
```

Руками: уверенных ответов 7, верных среди них 5, доля `5 / 7 = 0,71`. Остальных 13, верных 4, доля `4 / 13 = 0,31`. Разница `0,71 − 0,31 = 0,41`, при округлении из точных долей. Это больше 0,2. Подтверждена ли гипотеза? Ещё нет: правило требует и второго условия.

**Шаг 2. Повторные выборки.** 20 ответов это мало, и разница могла выйти случайно. *Повторные выборки*, или *бутстреп*, отвечают, насколько она шаткая: 2000 раз берём 20 ответов из наших же 20 с возвращением, то есть один и тот же ответ может попасть несколько раз, и каждый раз считаем разницу. Середина этих разниц, без крайних 2,5 % с каждой стороны, и есть 95-процентный интервал. Допиши и запусти.

```python
rand = Rand(9)
gaps = []
for _ in range(2000):
    sample = [DATA[int(rand.next() * len(DATA))] for _ in DATA]
    value = gap(sample)
    if value is not None:
        gaps.append(value)
gaps.sort()
low_end, high_end = gaps[int(0.025 * len(gaps))], gaps[int(0.975 * len(gaps))]
print(f"95 % interval of the difference: from {low_end:.2f} to {high_end:.2f}")
passed = gap(DATA) >= 0.2 and low_end > 0
print("criterion met:", passed)
```

```output
95 % interval of the difference: from -0.06 to 0.80
criterion met: False
```

Интервал от −0,06 до 0,80 захватывает ноль. Значит, по нашему же записанному правилу гипотеза **не подтверждена**: на 20 ответах разница может быть случайной. Это не значит, что метапознания нет. Это значит, что данных мало. Честный вывод звучит так: «не смогли показать», а не «показали» и не «опровергли». И это главное умение исследователя: не выдавать надежду за результат.

**Шаг 3. Что посильно одному человеку.** Вот работа, которую ты можешь делать с тем, что уже есть на этом Mac.

- **Проверять утверждения.** Когда пишут «модель сознательна» или «модель точно не сознательна», спрашивай: какой индикатор, каким опытом, с каким интервалом? Уроки этапа 5 дают для этого всё.
- **Ставить маленькие опыты на моделях.** Калибровка уверенности, как в этом уроке, но на сотнях вопросов. Проверка, меняется ли «самоотчёт» от подсказки, как в уроке «Что говорят о себе языковые модели» (шаг 25). Зонды и автокодировщики на маленьких моделях, как в шаге 17.
- **Ставить опыты на себе.** Маскировка и `d′` из урока «Опыты о сознании» (шаг 25) это настоящие методы психофизики.
- **Записывать заранее.** Любой свой опыт начинай с записи гипотезы и правила, как здесь.

**Шаг 4. Где идёт настоящая работа.** Крупные исследования ведут научные группы. Ассоциация научного изучения сознания, ASSC, каждый год собирает учёных на конференцию. В Сассекском центре науки о сознании работает Анил Сет, чей взгляд разобран в уроке «Биология или функция». Группа Eleos AI занимается вопросом, могут ли у ИИ быть благополучие и моральный статус, а в Нью-Йоркском университете работает центр «Разум, этика и политика». Опыт Cogitate из урока «Опыты о сознании» показал ещё один формат: сторонники соперничающих теорий заранее договариваются, какой результат что опровергнет.

**Что здесь честно сказать.** Путь к пониманию сознания не проложен, и никто не знает, приведёт ли он к сознательному ИИ. Но вклад одного внимательного человека реален: правильно поставленный маленький опыт и честный отказ от громких выводов нужны этой области больше, чем ещё одно мнение.

**Учись у тех, кто это создаёт.** Сайты [ASSC](https://theassc.org), [Sussex Centre for Consciousness Science](https://www.sussex.ac.uk/research/centres/sussex-centre-for-consciousness-science/), [Eleos AI](https://eleosai.org) и [NYU Center for Mind, Ethics, and Policy](https://sites.google.com/nyu.edu/mindethicspolicy). Отчёт [Butlin и соавторов](https://arxiv.org/abs/2308.08708) с открытыми вопросами.

### Исследуй и потренируйся

В тренажёре ниже сначала запиши гипотезу: выбери порог уверенности и наименьшую разницу, которую будешь считать подтверждением, и нажми «Записать». Только после этого увидишь результат и интервал. Потом посмотри, сколько ответов понадобилось бы, чтобы интервал перестал захватывать ноль.

### Вопрос

Разница в точности 0,41, а 95-процентный интервал от −0,06 до 0,80. Какой вывод честный?

### Варианты

- Гипотеза не подтверждена: на 20 ответах разница может быть случайной, нужно больше данных
- Гипотеза подтверждена: разница 0,41 намного больше заранее записанного порога 0,2
- Гипотеза опровергнута: раз интервал захватывает ноль, метапознания у модели нет

### Ответ

1

### Разбор

Правило было записано заранее и требует двух условий: разницы не меньше 0,2 и интервала выше нуля. Второе не выполнено, значит, подтверждения нет. Но и опровержения нет: интервал захватывает и большие положительные разницы. Данных просто мало, чтобы решить.

### Границы модели

Уверенность здесь взята из вероятностей токенов модели, а это лишь один из способов её мерить. 20 вопросов выбраны для другого урока. Бутстреп на маленькой выборке сам неточен. Список групп не полный: я назвал те, чьи страницы открыл и проверил.

## English

### In plain words

There is no ready path to conscious AI, and this lesson does not pretend there is. But there is work one person can do already: check claims honestly, run small experiments and know where the big research happens. The main tool here is not complex technology but the habit of writing down in advance what you expect and what you will count as failure. It is like a bet placed before the match: after the match everyone "knew all along". In the lesson you will test a hypothesis about a model on real data yourself and see that even a noticeable difference can remain unproven.

**What to know first.** «How a model errs and how to check it» (step 1): where the data come from. «Evaluation that means something» (step 15): the confidence interval. «Thoughts about thoughts and prediction» (step 24): metacognition. «Indicators» (step 25).

**If something is unclear.** If the confidence interval is unclear, go back to step 2 of «Evaluation that means something». If it is unclear why one should test a model's confidence at all, reread «Thoughts about thoughts and prediction». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Write a hypothesis down before the experiment, test it on real answers of a local model by resampling, honestly name the result, and draw up a list of what one person can do and where the real work happens. It takes about 35 minutes.

### Idea and mechanism

**Step 1. Write it down first.** *Preregistration* means: before looking at the data, write down the hypothesis and the rule by which it will count as confirmed. Otherwise it is easy to fit the conclusion to the result. Our hypothesis concerns *metacognition*, one of the indicators: does the model know when it is right? If it does, its confident answers should be right more often than its unsure ones. The data are 20 real answers of `qwen2.5-coder:7b` from «How a model errs»: the confidence and whether the answer is right. Create the file `nano ~/ai-path/youcan.py`, paste and run it.

```python
class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


# Written BEFORE looking at the data:
HYPOTHESIS = "answers with confidence 0.9 or more are right more often than the rest"
CRITERION = "the difference in accuracy is at least 0.2, and the 95 % interval of the difference is above zero"

# confidence and correctness of the 20 answers of qwen2.5-coder:7b from «How a model errs»
DATA = [(0.869, 1), (0.945, 1), (0.936, 1), (0.795, 0), (0.898, 1), (0.988, 1), (0.998, 1), (0.991, 1),
        (0.344, 0), (0.631, 0), (0.36, 0), (0.559, 0), (0.602, 0), (0.737, 1), (0.771, 0), (0.877, 0),
        (0.89, 0), (0.896, 1), (0.994, 0), (0.964, 0)]


def gap(rows):
    high = [right for conf, right in rows if conf >= 0.9]
    low = [right for conf, right in rows if conf < 0.9]
    if not high or not low:
        return None
    return sum(high) / len(high) - sum(low) / len(low)


high = [right for conf, right in DATA if conf >= 0.9]
low = [right for conf, right in DATA if conf < 0.9]
print(f"confidence >= 0.9: {sum(high)} right of {len(high)}; below 0.9: {sum(low)} right of {len(low)}")
print(f"difference in accuracy: {gap(DATA):.2f}")
```

```output
confidence >= 0.9: 5 right of 7; below 0.9: 4 right of 13
difference in accuracy: 0.41
```

By hand: there are 7 confident answers, 5 of them right, a share of `5 / 7 = 0.71`. The other 13 have 4 right, a share of `4 / 13 = 0.31`. The difference is `0.71 − 0.31 = 0.41` when computed from the exact shares. That is more than 0.2. Is the hypothesis confirmed? Not yet: the rule requires a second condition too.

**Step 2. Resampling.** 20 answers are few, and the difference could have come out by chance. *Resampling*, or the *bootstrap*, tells how shaky it is: 2000 times we draw 20 answers from our own 20 with replacement, so the same answer may come in several times, and each time compute the difference. The middle of these differences, without the extreme 2.5 % on each side, is the 95 % interval. Add this and run it.

```python
rand = Rand(9)
gaps = []
for _ in range(2000):
    sample = [DATA[int(rand.next() * len(DATA))] for _ in DATA]
    value = gap(sample)
    if value is not None:
        gaps.append(value)
gaps.sort()
low_end, high_end = gaps[int(0.025 * len(gaps))], gaps[int(0.975 * len(gaps))]
print(f"95 % interval of the difference: from {low_end:.2f} to {high_end:.2f}")
passed = gap(DATA) >= 0.2 and low_end > 0
print("criterion met:", passed)
```

```output
95 % interval of the difference: from -0.06 to 0.80
criterion met: False
```

The interval from −0.06 to 0.80 includes zero. So by our own written rule the hypothesis is **not confirmed**: on 20 answers the difference may be chance. This does not mean there is no metacognition. It means there are too few data. The honest conclusion reads: "could not show", not "showed" and not "refuted". And this is the researcher's main skill: not passing hope off as a result.

**Step 3. What one person can do.** Here is work you can do with what is already on this Mac.

- **Check claims.** When people write "the model is conscious" or "the model is certainly not conscious", ask: which indicator, by what experiment, with what interval? The stage 5 lessons give you everything for this.
- **Run small experiments on models.** Calibration of confidence, as in this lesson, but on hundreds of questions. Checking whether a "self-report" changes with the prompt, as in «What language models say about themselves» (step 25). Probes and autoencoders on small models, as in step 17.
- **Run experiments on yourself.** Masking and `d′` from «Experiments on consciousness» (step 25) are real methods of psychophysics.
- **Write it down first.** Start any experiment of yours by writing down the hypothesis and the rule, as here.

**Step 4. Where the real work happens.** Large studies are run by research groups. The Association for the Scientific Study of Consciousness, ASSC, gathers researchers at a conference every year. The Sussex Centre for Consciousness Science is home to Anil Seth, whose view is covered in «Biology or function». The group Eleos AI works on whether AI could have wellbeing and moral status, and New York University has a Center for Mind, Ethics, and Policy. The Cogitate experiment from «Experiments on consciousness» showed one more format: supporters of rival theories agree in advance which result would refute what.

**What is honest to say here.** The path to understanding consciousness is not laid out, and nobody knows whether it leads to conscious AI. But one careful person's contribution is real: a well-designed small experiment and an honest refusal of loud conclusions are needed in this field more than one more opinion.

**Learn from the people who build this.** The sites of [ASSC](https://theassc.org), the [Sussex Centre for Consciousness Science](https://www.sussex.ac.uk/research/centres/sussex-centre-for-consciousness-science/), [Eleos AI](https://eleosai.org) and the [NYU Center for Mind, Ethics, and Policy](https://sites.google.com/nyu.edu/mindethicspolicy). The [report by Butlin and co-authors](https://arxiv.org/abs/2308.08708) with its open questions.

### Explore and practise

In the lab below first write down your hypothesis: choose a confidence threshold and the smallest difference you will count as confirmation, and press "Write it down". Only then will you see the result and the interval. Then see how many answers would be needed for the interval to stop including zero.

### Question

The difference in accuracy is 0.41, and the 95 % interval runs from −0.06 to 0.80. Which conclusion is honest?

### Options

- The hypothesis is not confirmed: on 20 answers the difference may be chance; more data are needed
- The hypothesis is confirmed: a difference of 0.41 is far above the threshold of 0.2 written down earlier
- The hypothesis is refuted: since the interval includes zero, the model has no metacognition

### Answer

1

### Explanation

The rule was written down in advance and requires two conditions: a difference of at least 0.2 and an interval above zero. The second is not met, so there is no confirmation. But there is no refutation either: the interval also includes large positive differences. There are simply too few data to decide.

### Limits

Confidence here comes from the model's token probabilities, which is only one way to measure it. The 20 questions were chosen for another lesson. A bootstrap on a small sample is itself imprecise. The list of groups is not complete: I named those whose pages I opened and checked.

## Sources

- The 20 answers of `qwen2.5-coder:7b` with their confidence come from the lesson «How a model errs and how to check it»: `02_Areas/Programming/resources/model_mistakes_recording.json`.
- Patrick Butlin et al., "Consciousness in Artificial Intelligence: Insights from the Science of Consciousness", arXiv:2308.08708 (2023): [arXiv:2308.08708](https://arxiv.org/abs/2308.08708)
- Pages opened 2026-11-07: [theassc.org](https://theassc.org), [Sussex Centre for Consciousness Science](https://www.sussex.ac.uk/research/centres/sussex-centre-for-consciousness-science/), [Eleos AI Research](https://eleosai.org), [NYU Center for Mind, Ethics, and Policy](https://sites.google.com/nyu.edu/mindethicspolicy)
- The hypothesis, the program and the numbers were written for this lesson on 2026-11-07.
