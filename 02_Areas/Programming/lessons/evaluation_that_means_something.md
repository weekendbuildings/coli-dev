---
subject: programming
lesson_id: programming.evaluation_that_means_something
level: advanced
languages: ru, en
source_checked: 2026-11-07
source_review_interval_days: 365
---

# Оценка, которая что-то значит / Evaluation that means something

## Русский

### Простыми словами

Одно число из теста часто обманывает. Если сравнить сто одинаковых моделей, лучшая из них случайно покажет результат выше среднего: это проклятие победителя. Доверительный интервал показывает, насколько число может гулять от случая. А закон Гудхарта говорит: если число становится целью, его начинают подгонять, и оно перестаёт мерить то, что нужно. Как школа, которая учит сдавать тест, а не понимать предмет.

**Что нужно знать до.** Уроки «Как модель ошибается» (шаг 1), «Случайные величины и выборка» (шаг 5) и «Машинное обучение: baseline» (шаг 9).

**Если непонятно.** Если неясен интервал, посчитай шаг 2 урока руками: 80 % верных из 100 вопросов. Если неясно, почему маленькая выборка шумит, вернись к закону больших чисел в уроке «Случайные величины и выборка». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Понять, почему одно число из бенчмарка часто врёт. Измерить в опыте проклятие победителя, посчитать доверительный интервал руками, обмануть метрику и составить правила своей проверки. Нужно около 35 минут.

### Идея и механизм

**Шаг 1. Проклятие победителя.** Пусть все модели **одинаково** хороши: каждая верна в 70 % случаев. Проверь их на 20 вопросах. Из-за случайности одна наберёт 60 %, другая 85 %. Если выбрать лучшую из многих и объявить её результат, он будет завышен, хотя лучше она не стала. Создай файл `nano ~/ai-path/evaluate.py`, вставь и запусти.

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


def pick_best(models, test_size, rand):
    best = 0.0
    for _ in range(models):
        hits = sum(rand.next() < 0.7 for _ in range(test_size))
        best = max(best, hits / test_size)
    return best


rand = Rand(21)
print("all models are truly 70 % right")
print("test size, models tried, mean score of the winner")
for test_size in (20, 100, 500):
    for models in (1, 10, 100):
        scores = [pick_best(models, test_size, rand) for _ in range(40)]
        print(test_size, models, round(sum(scores) / 40, 3))
```

```output
all models are truly 70 % right
test size, models tried, mean score of the winner
20 1 0.715
20 10 0.853
20 100 0.927
100 1 0.711
100 10 0.766
100 100 0.81
500 1 0.697
500 10 0.726
500 100 0.751
```

Все модели верны на 70 %. Но из 100 моделей на тесте из 20 вопросов победитель показывает `92,7 %`. Рост на 23 пункта это чистый шум. Даже на 500 вопросах лучшая из 100 показывает `75,1 %`. Поэтому большое число попыток на одном и том же тесте завышает результат: чем больше ты пробуешь, тем больше обманываешься. Отсюда первое правило: **отложенный тест смотрят один раз**, а для подбора берут другой.

**Шаг 2. Интервал руками.** Сколько значит «80 % верных»? Для теста из 100 вопросов разброс оценки примерно `√(0,8 · 0,2 / 100) = 0,04`, а 95 % интервал это плюс-минус две такие величины, примерно от 72 % до 88 %. Точнее считает интервал Вильсона. Допиши и запусти.

```python
def wilson(hits, n, z=1.96):
    p = hits / n
    middle = (p + z * z / (2 * n)) / (1 + z * z / n)
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / (1 + z * z / n)
    return round(middle - half, 3), round(middle + half, 3)


for hits, n in ((8, 10), (80, 100), (800, 1000)):
    print(hits, n, wilson(hits, n))
print("models 77/100 and 72/100:", wilson(77, 100), wilson(72, 100))
```

```output
8 10 (0.49, 0.943)
80 100 (0.711, 0.867)
800 1000 (0.774, 0.824)
models 77/100 and 72/100: (0.678, 0.842) (0.625, 0.799)
```

При 8 верных из 10 настоящая доля может быть от 49 % до 94 %, то есть число почти ничего не значит. При 800 из 1000 от 77 % до 82 %. А вот типичное «наша модель лучше»: 77 % против 72 % на 100 вопросах. Интервалы сильно пересекаются, и различие может быть шумом. Чтобы вдвое сузить интервал, нужно **вчетверо** больше вопросов.

**Шаг 3. Закон Гудхарта.** Метрика это приближение к тому, что нужно. Если гнаться за ней, она ломается. Возьмём простую проверку: ответ верен, если в нём есть нужное слово. Честная модель отвечает правильно или говорит, что не знает. Вторая просто высыпает все возможные ответы. Допиши и запусти.

```python
ANSWERS = [("Столица Франции?", "Париж", "Столица Франции это Париж."),
           ("Сколько будет 12 · 12?", "144", "12 · 12 = 144."),
           ("Какая формула воды?", "H2O", "Вода это H2O."),
           ("Кто автор «Войны и мира»?", "Толстой", "Роман написал Лев Толстой."),
           ("Сколько планет в Солнечной системе?", "8", "Сейчас их считают 8."),
           ("Какой газ мы выдыхаем больше прежнего?", "углекислый", "Больше прежнего выдыхаем углекислый газ.")]


def honest(question, key, good, rand):
    return good if rand.next() < 0.7 else "Не знаю точно."


def stuffing(question, key, good, rand):
    return "Возможно: " + " ".join(k for _, k, _ in ANSWERS) + "."


def keyword_metric(reply, key):
    return key.lower() in reply.lower()


def person_metric(reply, good):
    return reply == good


rand = Rand(4)
for name, model in (("honest", honest), ("stuffs keywords", stuffing)):
    runs = [(model(q, k, g, rand), k, g) for q, k, g in ANSWERS * 20]
    print(name, "keyword metric", round(sum(keyword_metric(r, k) for r, k, g in runs) / len(runs), 2),
          "useful answers", round(sum(person_metric(r, g) for r, k, g in runs) / len(runs), 2))
```

```output
honest keyword metric 0.66 useful answers 0.66
stuffs keywords keyword metric 1.0 useful answers 0.0
```

Метрика дала наполнителю `1,0`, а честной модели `0,66`. Полезных ответов у наполнителя `0`. Это не только игрушка: Manheim и Garrabrant разобрали четыре вида такого сбоя, и проклятие победителя из шага 1 это один из них.

**Шаг 4. Настоящие бенчмарки.** Два настоящих примера, и оба с оговорками.

- Recht и соавторы собрали новый тест для ImageNet тем же способом. Точность моделей упала на 11–14 пунктов. Но порядок моделей почти сохранился, и сами авторы считают, что дело в небольшом сдвиге данных, а не в переобучении на тесте.
- Статья The Leaderboard Illusion о рейтинге Chatbot Arena утверждает, что крупные компании проверяли много закрытых вариантов и показывали лучший. Это как раз шаг 1. Создатели рейтинга часть выводов оспорили, так что спор не закрыт.

**Шаг 5. Правила своей проверки.**

1. Сначала напиши, что значит «хорошо» для твоей задачи, и только потом смотри результат.
2. Держи отложенный набор отдельно и смотри на него редко.
3. Считай интервал. Без него разница в 2 пункта на 100 вопросах ничего не значит.
4. Сравнивай с простейшей линейкой, например с угадыванием самого частого ответа.
5. Смотри на ошибки своими глазами, а не только на среднее. Несколько примеров часто показывают то, чего не показывает число.
6. Спрашивай: как эту метрику можно обмануть? Если легко, добавь проверку на такой случай.

**Учись у тех, кто это создаёт.** Лекции об оценке в [Stanford CS224N](https://web.stanford.edu/class/cs224n/) и [Stanford CS336](https://stanford-cs336.github.io/spring2025/). Статья [Manheim и Garrabrant](https://arxiv.org/abs/1803.04585) короткая и ясная.

### Исследуй и потренируйся

В тренажёре настоящий опыт: точки это модели, каждая верна на 70 %. Двигай число моделей и размер теста и смотри, насколько завышен победитель. Нажми «Новый опыт» и посмотри, что покажет тот же победитель на свежем тесте.

В программе пусть одна из моделей будет верна на 75 %. Как часто побеждает она при тесте на 20 вопросов и на 500?

### Вопрос

Все модели одинаковы, но лучшая из ста показала результат намного выше среднего. Почему?

### Варианты

- Из многих случайных результатов лучший завышен шумом, хотя сама модель не лучше других.
- Лучшая модель случайно обучилась сильнее других, поэтому её качество правда выше.
- Тест из малого числа вопросов всегда занижает точность, и победитель это исправляет.

### Ответ

1

### Разбор

В опыте все модели верны ровно на 70 %, и никакого настоящего различия нет. Тест не занижает точность: в среднем он даёт верное значение. Завышение появляется при выборе максимума из шумных чисел. На свежем тесте тот же победитель снова показывает около 70 %.

### Границы модели

Модели здесь это монетки с независимыми ответами. У настоящих моделей ошибки связаны, вопросы разной сложности, и интервал поэтому только примерный. Ответы в шаге 3 написаны мной так, чтобы эффект был виден. Сравнение моделей на одном и том же наборе точнее считать по парам вопросов, здесь я этого не делаю.

## English

### In plain words

One number from a test often misleads. If you compare a hundred identical models, the best of them will by chance score above average: that is the winner's curse. A confidence interval shows how far the number can drift by chance. And Goodhart's law says: when a number becomes a target, people start tuning to it, and it stops measuring what it should. Like a school that teaches to pass the test rather than to understand the subject.

**What to know first.** «How a model errs» (step 1), «Random Variables and Sampling» (step 5) and «Machine Learning: Baselines» (step 9).

**If something is unclear.** If the interval is unclear, work step 2 of the lesson by hand: 80 % correct out of 100 questions. If it is unclear why a small sample is noisy, go back to the law of large numbers in «Random Variables and Sampling». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Understand why a single benchmark number often lies. Measure the winner's curse in an experiment, compute a confidence interval by hand, fool a metric, and set rules for your own testing. It takes about 35 minutes.

### Idea and mechanism

**Step 1. The winner's curse.** Suppose all models are **equally** good: each is right 70 % of the time. Test them on 20 questions. By chance one gets 60 %, another 85 %. If you pick the best of many and announce its result, it will be inflated, though it is no better. Create the file `nano ~/ai-path/evaluate.py`, paste and run it.

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


def pick_best(models, test_size, rand):
    best = 0.0
    for _ in range(models):
        hits = sum(rand.next() < 0.7 for _ in range(test_size))
        best = max(best, hits / test_size)
    return best


rand = Rand(21)
print("all models are truly 70 % right")
print("test size, models tried, mean score of the winner")
for test_size in (20, 100, 500):
    for models in (1, 10, 100):
        scores = [pick_best(models, test_size, rand) for _ in range(40)]
        print(test_size, models, round(sum(scores) / 40, 3))
```

```output
all models are truly 70 % right
test size, models tried, mean score of the winner
20 1 0.715
20 10 0.853
20 100 0.927
100 1 0.711
100 10 0.766
100 100 0.81
500 1 0.697
500 10 0.726
500 100 0.751
```

All models are 70 % right. But of 100 models on a 20-question test the winner shows `92.7 %`. The 23-point gain is pure noise. Even on 500 questions the best of 100 shows `75.1 %`. So many attempts on the same test inflate the result: the more you try, the more you fool yourself. Hence the first rule: **look at a held-out test once**, and use another for tuning.

**Step 2. An interval by hand.** How much does "80 % right" mean? For a 100-question test the estimate's spread is about `√(0.8 · 0.2 / 100) = 0.04`, and a 95 % interval is plus or minus two of these, about 72 % to 88 %. The Wilson interval computes this more precisely. Add this and run it.

```python
def wilson(hits, n, z=1.96):
    p = hits / n
    middle = (p + z * z / (2 * n)) / (1 + z * z / n)
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / (1 + z * z / n)
    return round(middle - half, 3), round(middle + half, 3)


for hits, n in ((8, 10), (80, 100), (800, 1000)):
    print(hits, n, wilson(hits, n))
print("models 77/100 and 72/100:", wilson(77, 100), wilson(72, 100))
```

```output
8 10 (0.49, 0.943)
80 100 (0.711, 0.867)
800 1000 (0.774, 0.824)
models 77/100 and 72/100: (0.678, 0.842) (0.625, 0.799)
```

With 8 right of 10 the true share may be from 49 % to 94 %, so the number says almost nothing. With 800 of 1000, from 77 % to 82 %. And here is a typical "our model is better": 77 % against 72 % on 100 questions. The intervals overlap heavily, and the difference may be noise. To halve an interval you need **four times** more questions.

**Step 3. Goodhart's law.** A metric approximates what you need. Chase it and it breaks. Take a simple check: an answer counts as right if it contains the needed word. An honest model answers rightly or says it does not know. A second one simply pours out all possible answers. Add this and run it.

```python
ANSWERS = [("Столица Франции?", "Париж", "Столица Франции это Париж."),
           ("Сколько будет 12 · 12?", "144", "12 · 12 = 144."),
           ("Какая формула воды?", "H2O", "Вода это H2O."),
           ("Кто автор «Войны и мира»?", "Толстой", "Роман написал Лев Толстой."),
           ("Сколько планет в Солнечной системе?", "8", "Сейчас их считают 8."),
           ("Какой газ мы выдыхаем больше прежнего?", "углекислый", "Больше прежнего выдыхаем углекислый газ.")]


def honest(question, key, good, rand):
    return good if rand.next() < 0.7 else "Не знаю точно."


def stuffing(question, key, good, rand):
    return "Возможно: " + " ".join(k for _, k, _ in ANSWERS) + "."


def keyword_metric(reply, key):
    return key.lower() in reply.lower()


def person_metric(reply, good):
    return reply == good


rand = Rand(4)
for name, model in (("honest", honest), ("stuffs keywords", stuffing)):
    runs = [(model(q, k, g, rand), k, g) for q, k, g in ANSWERS * 20]
    print(name, "keyword metric", round(sum(keyword_metric(r, k) for r, k, g in runs) / len(runs), 2),
          "useful answers", round(sum(person_metric(r, g) for r, k, g in runs) / len(runs), 2))
```

```output
honest keyword metric 0.66 useful answers 0.66
stuffs keywords keyword metric 1.0 useful answers 0.0
```

The metric gave the stuffing model `1.0` and the honest one `0.66`. The stuffing model's useful answers are `0`. This is not only a toy: Manheim and Garrabrant sorted such failures into four kinds, and the winner's curse of step 1 is one of them.

**Step 4. Real benchmarks.** Two real examples, both with caveats.

- Recht and co-authors built a new ImageNet test in the same way. Model accuracy fell by 11–14 points. But the models' order mostly held, and the authors themselves attribute this to a small data shift, not to overfitting the test.
- The Leaderboard Illusion, on the Chatbot Arena ranking, claims that large companies tested many private variants and showed the best one. That is exactly step 1. The ranking's creators disputed part of the findings, so the argument is not closed.

**Step 5. Rules for your own testing.**

1. First write down what "good" means for your task, and only then look at results.
2. Keep a held-out set apart and look at it rarely.
3. Compute an interval. Without one, a 2-point difference on 100 questions means nothing.
4. Compare with the simplest baseline, such as guessing the most frequent answer.
5. Read the errors with your own eyes, not just the mean. A few examples often show what a number does not.
6. Ask: how could this metric be fooled? If easily, add a check for that case.

**Learn from the people who build this.** The evaluation lectures of [Stanford CS224N](https://web.stanford.edu/class/cs224n/) and [Stanford CS336](https://stanford-cs336.github.io/spring2025/). The paper by [Manheim and Garrabrant](https://arxiv.org/abs/1803.04585) is short and clear.

### Explore and practise

The lab has a real experiment: dots are models, each 70 % right. Move the number of models and the test size and see how inflated the winner is. Press New experiment and see what the same winner shows on a fresh test.

In the program, let one of the models be 75 % right. How often does it win on a test of 20 questions and of 500?

### Question

All models are the same, yet the best of a hundred showed a result far above average. Why?

### Options

- The best of many random results is inflated by noise, though that model is no better.
- The best model happened to train harder than others, so its quality truly is higher.
- A test with few questions always understates accuracy, and the winner corrects that.

### Answer

1

### Explanation

In the experiment all models are exactly 70 % right, and no real difference exists. A test does not understate accuracy: on average it gives the true value. The inflation appears when picking the maximum of noisy numbers. On a fresh test the same winner again shows about 70 %.

### Limits

Models here are coins with independent answers. Real models have linked errors and questions of differing difficulty, so the interval is only approximate. I wrote the answers in step 3 to make the effect visible. Comparing models on the same set is more accurate question by question; I do not do that here.

## Sources

- David Manheim, Scott Garrabrant, "Categorizing Variants of Goodhart's Law", arXiv:1803.04585 (2018), title read 2026-11-03: [arXiv:1803.04585](https://arxiv.org/abs/1803.04585)
- Benjamin Recht et al., "Do ImageNet Classifiers Generalize to ImageNet?", arXiv:1902.10811 (2019), abstract with the figures read 2026-11-03: [arXiv:1902.10811](https://arxiv.org/abs/1902.10811)
- Shivalika Singh et al., "The Leaderboard Illusion", arXiv:2504.20879 (2025), title read 2026-11-03: [arXiv:2504.20879](https://arxiv.org/abs/2504.20879)
- Edwin B. Wilson, "Probable Inference, the Law of Succession, and Statistical Inference", Journal of the American Statistical Association 22 (158), 209–212 (1927), title and journal checked 2026-11-03, the paper itself not read. The interval in the program was checked on 2026-11-07 in two ways: derived from Wilson's condition (p̂ − p)² = z² · p(1 − p) / n, which gives the centre (p̂ + z²/2n) / (1 + z²/n) and the half-width z · √(p̂(1 − p̂)/n + z²/4n²) / (1 + z²/n) used in the code, and matched against the statement of the Wilson score interval in [Wikipedia: Binomial proportion confidence interval](https://en.wikipedia.org/wiki/Binomial_proportion_confidence_interval).
- Stanford CS224N and CS336, titles read 2026-11-03: [CS224N](https://web.stanford.edu/class/cs224n/), [CS336](https://stanford-cs336.github.io/spring2025/)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
