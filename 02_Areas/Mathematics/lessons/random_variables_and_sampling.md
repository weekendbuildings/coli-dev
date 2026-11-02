---
subject: mathematics
lesson_id: mathematics.random_variables_and_sampling
level: advanced
languages: ru, en
source_checked: 2026-11-02
source_review_interval_days: 365
---

# Случайные величины и выборка / Random Variables and Sampling

## Русский

### Цель

Считать математическое ожидание и дисперсию, объяснять, почему большие выборки точнее и откуда берётся колокол, и получать случайный символ из вероятностей, управляя температурой. Так языковая модель пишет текст.

### Идея и механизм

**Случайная величина** — это число, которое зависит от случая: результат броска кубика, номер следующей буквы, ошибка на случайном пакете данных. Заранее её значение неизвестно, но известно распределение: какие значения она принимает и с какими вероятностями.

**Математическое ожидание** — это среднее значение, взвешенное по вероятностям:

`E[X] = Σ x · p(x)`

Для честного кубика `E[X] = (1 + 2 + 3 + 4 + 5 + 6) / 6 = 3,5`. Значения 3,5 у кубика не бывает: это долгосрочное среднее, а не вероятный результат.

**Дисперсия** показывает разброс, то есть среднее квадрата отклонения от ожидания:

`Var[X] = E[(X − E[X])²]`

Для кубика это `(2,5² + 1,5² + 0,5² + 0,5² + 1,5² + 2,5²) / 6 = 35/12 ≈ 2,917`. Корень из дисперсии называют стандартным отклонением: у кубика оно около 1,71.

**Закон больших чисел и цена точности.** Среднее по выборке приближается к ожиданию, когда примеров становится больше. Для независимых величин дисперсии складываются, поэтому у среднего из `n` значений дисперсия равна `Var[X] / n`, а стандартное отклонение равно `σ / √n`. Это та самая причина из урока о мини-батчах: чтобы уменьшить шум в 10 раз, примеров нужно в 100 раз больше.

**Доска Гальтона и колокол.** Шарик падает через `n` рядов штырей и на каждом уходит вправо с вероятностью `p`. Номер корзины — это число уходов вправо. У такой величины биномиальное распределение: её ожидание `np`, а дисперсия `np(1 − p)`. Каждый ряд это независимый шаг, поэтому ожидание и дисперсия одного шага просто умножаются на `n`. Чем больше рядов, тем сильнее форма горки похожа на колокол. Это проявление центральной предельной теоремы: сумма многих независимых случайных шагов почти всегда распределена близко к нормальному закону. Доску придумал Фрэнсис Гальтон в XIX веке.

**Как получить случайный символ.** Пусть модель выдала вероятности `(0,6; 0,3; 0,1)`. Разложим их на отрезке от 0 до 1 по порядку: `[0; 0,6)`, `[0,6; 0,9)`, `[0,9; 1)`. Возьмём равномерное случайное число `u`. В какой отрезок оно попало, тот символ и выпал. При `u = 0,75` это второй символ. Каждый символ выпадает с нужной вероятностью, потому что длина его отрезка и есть эта вероятность.

**Температура.** Перед softmax оценки делят на число `T`:

`qₖ = softmax(zₖ / T)`

При `T = 1` это обычные вероятности. При малых `T` разности оценок растут, и почти всегда выпадает самый вероятный символ: текст становится осторожным и начинает повторяться. При больших `T` распределение становится ближе к равномерному, а текст более случайным. При оценках `(2; 1; 0)` получаем `(0,867; 0,117; 0,016)` при `T = 0,5`, `(0,665; 0,245; 0,090)` при `T = 1` и `(0,506; 0,307; 0,186)` при `T = 2`.

Всё это на чистом Python, вместе со счётчиком пар букв, который уже пишет текст:

```python
import math
from collections import Counter

state = 1234


def random_number():
    global state
    state = state * 16807 % 2147483647
    return state / 2147483647


for count in (100, 10000):
    rolls = [1 + int(random_number() * 6) for _ in range(count)]
    mean = sum(rolls) / count
    variance = sum((r - mean) ** 2 for r in rolls) / count
    print("rolls", count, round(mean, 3), round(variance, 3))

rows, right = 12, 0.75
bins = [0] * (rows + 1)
for _ in range(2000):
    bins[sum(random_number() < right for _ in range(rows))] += 1
mean = sum(k * n for k, n in enumerate(bins)) / 2000
variance = sum(n * (k - mean) ** 2 for k, n in enumerate(bins)) / 2000
print("board", round(mean, 2), rows * right, round(variance, 2), rows * right * (1 - right))


def softmax(scores, temperature=1.0):
    top = max(scores)
    powers = [math.exp((s - top) / temperature) for s in scores]
    total = sum(powers)
    return [p / total for p in powers]


def sample(probabilities):  # отрезки подряд и случайная точка на них
    u, total = random_number(), 0.0
    for index, p in enumerate(probabilities):
        total += p
        if u < total:
            return index
    return len(probabilities) - 1


for temperature in (0.5, 1, 2):
    print("temperature", temperature, [round(p, 3) for p in softmax([2, 1, 0], temperature)])

text = "the cat sat on the mat and the dog sat on the log"
alphabet = sorted(set(text))
pairs = Counter(zip(text, text[1:]))


def write(temperature, length=44):
    result = "t"
    for _ in range(length):
        scores = [math.log(pairs[result[-1], c] + 0.1) for c in alphabet]
        result += alphabet[sample(softmax(scores, temperature))]
    return result


print(write(1))
print(write(0.3))
print(write(3))
```

Программа печатает:

```text
rolls 100 3.56 2.446
rolls 10000 3.531 2.898
board 9.01 9.0 2.21 2.25
temperature 0.5 [0.867, 0.117, 0.016]
temperature 1 [0.665, 0.245, 0.09]
temperature 2 [0.506, 0.307, 0.186]
t d scloncdoge g dn cadthe t t m at t one sat
t t the og sat dog sathe on t the t sat t the
t adh lcnhsao th o ead osaeddn d dsohmmche th
```

Первые две строки показывают закон больших чисел: при 100 бросках дисперсия 2,446 далека от настоящей 2,917, а при 10 000 бросков получается 2,898. На доске Гальтона с 12 рядами и `p = 0,75` среднее 9,01 при теории 9,0, а дисперсия 2,21 при теории 2,25.

Последние три строки — первая в этом курсе программа, которая пишет. Это всего лишь счётчик пар букв с температурой. При `T = 1` появляются обрывки слов. При `T = 0,3` модель почти всегда берёт самую частую пару и повторяет `the` и `sat`. При `T = 3` выходит почти случайный набор букв. Финальный проект пишет так же, только вероятности даёт обученная сеть.

### Исследуй и потренируйся

В тренажёре стоит настоящая доска Гальтона. Шарики падают через штыри, а настоящие случайные числа решают, куда им идти. Столбики растут в корзинах, а золотые кольца показывают, сколько должно быть по формуле. Покрути доску мышью. Брось 10 шариков и посмотри на разницу с кольцами, а потом брось ещё сотни. Подвигай `p` и число рядов. Как связаны положение горки и формула `np`?

Затем измени программу: поставь `write(0.1)` и `write(10)`. Что случилось с текстом и почему?

### Вопрос

Средняя ошибка на пакете из 100 примеров слишком шумная. Какой пакет снизит её стандартное отклонение примерно вдвое?

### Варианты

- Пакет из 200 примеров, потому что шум падает как `1/n`.
- Пакет из 400 примеров, потому что шум падает как `1/√n`.
- Пакет из 10 000 примеров, потому что шум падает как `1/n²`.

### Ответ

2

### Разбор

У среднего из `n` независимых значений дисперсия равна `Var[X] / n`, а стандартное отклонение равно `σ / √n`. Чтобы уменьшить его вдвое, `√n` должен вырасти вдвое, то есть `n` вчетверо: с 100 до 400. Поэтому точность так дорого стоит.

### Границы модели

Формула `σ / √n` требует независимых примеров, а куски одного текста часто связаны между собой, поэтому настоящий шум бывает больше. Генератор в программе простой и учебный: он хорош для урока и не годится там, где важна настоящая случайность, например в криптографии. Нормальное приближение на доске хуже всего работает при `p` рядом с 0 или 1 и при малом числе рядов. Текст счётчика пар кажется похожим на английский лишь потому, что выборка из короткой фразы: он повторяет её куски и ничего не понимает.

## English

### Goal

Compute the expected value and variance, explain why large samples are more precise and where the bell comes from, and draw a random character from probabilities while controlling the temperature. This is how a language model writes text.

### Idea and mechanism

A **random variable** is a number that depends on chance: the roll of a die, the number of the next letter, the error on a random batch of data. Its value is unknown in advance, but its distribution is known: which values it takes, and with what probabilities.

The **expected value** is the mean weighted by the probabilities:

`E[X] = Σ x · p(x)`

For a fair die, `E[X] = (1 + 2 + 3 + 4 + 5 + 6) / 6 = 3.5`. A die never shows 3.5: this is a long-run average, not a likely result.

The **variance** shows spread, the mean of the squared deviation from the expected value:

`Var[X] = E[(X − E[X])²]`

For a die this is `(2.5² + 1.5² + 0.5² + 0.5² + 1.5² + 2.5²) / 6 = 35/12 ≈ 2.917`. The square root of the variance is called the standard deviation: for a die it is about 1.71.

**The law of large numbers and the price of precision.** A sample mean approaches the expected value as examples accumulate. For independent variables the variances add, so the mean of `n` values has variance `Var[X] / n` and standard deviation `σ / √n`. This is the very reason from the mini-batch lesson: to reduce noise 10 times, you need 100 times more examples.

**The Galton board and the bell.** A ball falls through `n` rows of pegs and at each one goes right with probability `p`. The bin number is the count of rightward moves. Such a variable has a binomial distribution: its expected value is `np` and its variance `np(1 − p)`. Each row is an independent step, so the expected value and variance of one step are simply multiplied by `n`. The more rows, the more the pile resembles a bell. This shows the central limit theorem at work: a sum of many independent random steps is almost always distributed close to the normal law. Francis Galton devised the board in the 19th century.

**How to draw a random character.** Let a model give the probabilities `(0.6, 0.3, 0.1)`. Lay them out in order on the segment from 0 to 1: `[0, 0.6)`, `[0.6, 0.9)`, `[0.9, 1)`. Take a uniform random number `u`. Whichever segment it lands in, that character comes up. At `u = 0.75` it is the second character. Each character comes up with the right probability, because the length of its segment is that probability.

**Temperature.** Before softmax the scores are divided by a number `T`:

`qₖ = softmax(zₖ / T)`

At `T = 1` these are the ordinary probabilities. At small `T` the score differences grow, and the most likely character almost always comes up: the text turns cautious and starts repeating. At large `T` the distribution comes closer to uniform, and the text is more random. For scores `(2, 1, 0)` we get `(0.867, 0.117, 0.016)` at `T = 0.5`, `(0.665, 0.245, 0.090)` at `T = 1`, and `(0.506, 0.307, 0.186)` at `T = 2`.

All of this in plain Python, together with a letter-pair counter that already writes text:

```python
import math
from collections import Counter

state = 1234


def random_number():
    global state
    state = state * 16807 % 2147483647
    return state / 2147483647


for count in (100, 10000):
    rolls = [1 + int(random_number() * 6) for _ in range(count)]
    mean = sum(rolls) / count
    variance = sum((r - mean) ** 2 for r in rolls) / count
    print("rolls", count, round(mean, 3), round(variance, 3))

rows, right = 12, 0.75
bins = [0] * (rows + 1)
for _ in range(2000):
    bins[sum(random_number() < right for _ in range(rows))] += 1
mean = sum(k * n for k, n in enumerate(bins)) / 2000
variance = sum(n * (k - mean) ** 2 for k, n in enumerate(bins)) / 2000
print("board", round(mean, 2), rows * right, round(variance, 2), rows * right * (1 - right))


def softmax(scores, temperature=1.0):
    top = max(scores)
    powers = [math.exp((s - top) / temperature) for s in scores]
    total = sum(powers)
    return [p / total for p in powers]


def sample(probabilities):  # segments in a row and a random point on them
    u, total = random_number(), 0.0
    for index, p in enumerate(probabilities):
        total += p
        if u < total:
            return index
    return len(probabilities) - 1


for temperature in (0.5, 1, 2):
    print("temperature", temperature, [round(p, 3) for p in softmax([2, 1, 0], temperature)])

text = "the cat sat on the mat and the dog sat on the log"
alphabet = sorted(set(text))
pairs = Counter(zip(text, text[1:]))


def write(temperature, length=44):
    result = "t"
    for _ in range(length):
        scores = [math.log(pairs[result[-1], c] + 0.1) for c in alphabet]
        result += alphabet[sample(softmax(scores, temperature))]
    return result


print(write(1))
print(write(0.3))
print(write(3))
```

The program prints:

```text
rolls 100 3.56 2.446
rolls 10000 3.531 2.898
board 9.01 9.0 2.21 2.25
temperature 0.5 [0.867, 0.117, 0.016]
temperature 1 [0.665, 0.245, 0.09]
temperature 2 [0.506, 0.307, 0.186]
t d scloncdoge g dn cadthe t t m at t one sat
t t the og sat dog sathe on t the t sat t the
t adh lcnhsao th o ead osaeddn d dsohmmche th
```

The first two lines show the law of large numbers: at 100 rolls the variance of 2.446 is far from the true 2.917, while at 10,000 rolls it reaches 2.898. On a Galton board with 12 rows and `p = 0.75`, the mean is 9.01 against a theoretical 9.0, and the variance 2.21 against 2.25.

The last three lines are the first program in this course that writes. It is just a letter-pair counter with a temperature. At `T = 1` scraps of words appear. At `T = 0.3` the model almost always takes the most frequent pair and repeats `the` and `sat`. At `T = 3` an almost random set of letters comes out. The final project writes the same way, only a trained network provides the probabilities.

### Explore and practise

The lab holds a true Galton board. Balls fall through the pegs, and true random numbers decide where they go. Columns grow in the bins, and gold rings show how much there should be by the formula. Turn the board with the mouse. Drop 10 balls and look at the difference from the rings, then drop hundreds more. Move `p` and the number of rows. How are the position of the pile and the formula `np` related?

Then change the program: use `write(0.1)` and `write(10)`. What happened to the text, and why?

### Question

The mean error on a batch of 100 examples is too noisy. Which batch cuts its standard deviation about in half?

### Options

- A batch of 200 examples, because noise falls as `1/n`.
- A batch of 400 examples, because noise falls as `1/√n`.
- A batch of 10,000 examples, because noise falls as `1/n²`.

### Answer

2

### Explanation

The mean of `n` independent values has variance `Var[X] / n` and standard deviation `σ / √n`. To cut it in half, `√n` must double, so `n` must quadruple: from 100 to 400. That is why precision costs so much.

### Limits

The formula `σ / √n` requires independent examples, while pieces of one text are often related, so the true noise can be larger. The generator in the program is simple and for teaching: it is fine for a lesson and unsuitable where true randomness matters, as in cryptography. The normal approximation on the board works worst at `p` near 0 or 1 and with few rows. The pair counter's text looks like English only because it samples from a short phrase: it repeats pieces of it and understands nothing.

## Sources

- Barbara Illowsky, Susan Dean, *Introductory Statistics 2e*, OpenStax (December 13, 2023), §4.2 “Mean or Expected Value and Standard Deviation” (consulted 2026-11-02): expected value as a long-run average, the standard deviation of a discrete variable, and the law of large numbers: [OpenStax, §4.2](https://openstax.org/books/introductory-statistics-2e/pages/4-2-mean-or-expected-value-and-standard-deviation)
- *Introductory Statistics 2e*, §4.3 “Binomial Distribution” (consulted 2026-11-02): the mean np and the variance npq: [OpenStax, §4.3](https://openstax.org/books/introductory-statistics-2e/pages/4-3-binomial-distribution)
- Aston Zhang, Zachary C. Lipton, Mu Li, Alexander J. Smola, *Dive into Deep Learning* (version 1.0.3), “Probability and Statistics” (consulted 2026-11-02): expectation, variance, and estimates improving at about one over the square root of the sample size: [D2L, probability](https://d2l.ai/chapter_preliminaries/probability.html)
- Wikipedia, “Galton board” (consulted 2026-11-02): Galton's device, the binomial counts in its bins, and the bell shape: [Galton board](https://en.wikipedia.org/wiki/Galton_board)
- Wikipedia, “Softmax function” (consulted 2026-11-02): the temperature parameter, which flattens the distribution when high and sharpens it when low: [Softmax function](https://en.wikipedia.org/wiki/Softmax_function)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
