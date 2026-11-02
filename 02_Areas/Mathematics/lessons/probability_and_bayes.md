---
subject: mathematics
lesson_id: mathematics.probability_and_bayes
level: advanced
languages: ru, en
source_checked: 2026-11-02
source_review_interval_days: 365
---

# Вероятность и формула Байеса / Probability and Bayes' Rule

## Русский

### Цель

Считать условную вероятность, проверять независимость событий и пользоваться формулой Байеса, чтобы переворачивать вероятности и не попадаться на ошибку базовой частоты.

### Идея и механизм

Языковая модель отвечает на один вопрос: какова вероятность следующей буквы, если известно, что уже написано? Это условная вероятность. Понять её проще всего на подсчётах.

**Условная вероятность.** Вероятность события `A` при условии, что случилось `B`, равна

`P(A | B) = P(A и B) / P(B)`

Смысл простой: узнав про `B`, мы выбрасываем все исходы, где `B` не случилось, и считаем долю `A` среди оставшихся. Возьмём фразу `the cat sat on the mat and the dog sat on the log`. В ней 49 символов, и буква `h` встречается 4 раза, поэтому `P(h) = 4/49 ≈ 0,082`. Буква `t` встречается 8 раз, и 4 раза за ней идёт `h`, поэтому `P(h | перед ней t) = 4/8 = 0,5`. Знание предыдущей буквы подняло вероятность в шесть раз. Именно на этом работает счётчик пар букв из урока о кросс-энтропии.

**Независимость.** События независимы, если знание одного не меняет вероятность другого: `P(A | B) = P(A)`. Тогда `P(A и B) = P(A) · P(B)`. Буквы в тексте зависимы, и этим мы только что воспользовались. Два броска честной монеты независимы: первый ничего не говорит о втором.

**Формула Байеса.** Из определения следует, что `P(A и B) = P(A | B) · P(B) = P(B | A) · P(A)`. Поделив на `P(B)`, получаем способ перевернуть условие:

`P(A | B) = P(B | A) · P(A) / P(B)`

Здесь `P(A)` называют априорной вероятностью, то есть тем, что мы думали до наблюдения. `P(A | B)` называют апостериорной вероятностью: это обновлённое мнение после наблюдения. Знаменатель раскладывается на все способы получить `B`: `P(B) = P(B | A) · P(A) + P(B | не A) · P(не A)`.

**Разберём пример.** Редкая болезнь есть у 1 % людей. Тест находит 99 % больных, но у 5 % здоровых тоже даёт ложную тревогу. У человека положительный тест. Какова вероятность, что он болен? Интуиция подсказывает ответ близкий к 99 %. Посчитаем на 1000 людях. Больных 10, тест найдёт примерно 9,9 из них. Здоровых 990, и ложно сработает примерно у 49,5. Всего положительных 59,4, и больных среди них 9,9:

`P(болен | +) = 9,9 / 59,4 ≈ 0,167`

Всего 17 %. Вероятность `P(+ | болен) = 0,99` перевернулась в `P(болен | +) ≈ 0,167`, и это совсем разные числа. Ошибка, когда игнорируют редкость самой болезни, называется ошибкой базовой частоты. Причина в том, что здоровых гораздо больше, поэтому даже малая доля их ложных тревог превышает всех настоящих больных.

**Обновление.** Сделаем второй независимый тест. Теперь наше априорное мнение это 0,167, а не 0,01. Формула даёт `0,167 · 0,99 / (0,167 · 0,99 + 0,833 · 0,05) ≈ 0,798`. Каждое наблюдение обновляет мнение, и следующее начинает уже с нового значения. Обучение модели тоже можно понимать как обновление мнения о мире на основе данных.

Всё это на чистом Python:

```python
from collections import Counter

text = "the cat sat on the mat and the dog sat on the log"
letters = Counter(text)
pairs = Counter(zip(text, text[1:]))
starts = Counter(text[:-1])


def chance(letter):
    return letters[letter] / len(text)


def chance_after(previous, letter):  # P(буква | предыдущая)
    return pairs[previous, letter] / starts[previous]


def bayes(prior, hit, false_alarm):
    return prior * hit / (prior * hit + (1 - prior) * false_alarm)


print("P(h)", round(chance("h"), 3))
print("P(h|t)", round(chance_after("t", "h"), 3))
first = bayes(0.01, 0.99, 0.05)
print("after one test", round(first, 3))
print("after two tests", round(bayes(first, 0.99, 0.05), 3))
print("fewer false alarms", round(bayes(0.01, 0.99, 0.01), 3))
```

Программа печатает:

```text
P(h) 0.082
P(h|t) 0.5
after one test 0.167
after two tests 0.798
fewer false alarms 0.5
```

Последняя строка объясняет, что важнее всего в таком тесте: если снизить ложные тревоги с 5 % до 1 %, то вероятность болезни при положительном тесте вырастет с 17 % до 50 %.

### Исследуй и потренируйся

В тренажёре стоит настоящий город из 1000 жителей. Каждый житель это кубик. Больные красные, здоровые синие. У кого тест положительный, тот поднимается над городом. Посмотри на поднятые кубики: какая доля из них красная? Это и есть `P(болен | +)`. Покрути город мышью и подвигай ползунки. Как меняется ответ, когда болезнь становится редкой? Что будет, если сделать второй тест только для поднятых?

Затем допиши программу: посчитай `chance_after("a", "t")`. Чем это число отличается от `chance("t")`?

### Вопрос

Тест находит 99 % больных. У тебя положительный результат, а болезнь очень редкая. Что можно сказать точно?

### Варианты

- Вероятность болезни равна 99 %, потому что столько находит тест.
- Вероятность болезни зависит ещё от редкости и ложных тревог.
- Вероятность болезни равна 1 %, потому что столько людей болеют.

### Ответ

2

### Разбор

Число 99 % это `P(+ | болен)`, а вопрос про `P(болен | +)`. Чтобы перевернуть условие, нужны априорная вероятность болезни и доля ложных тревог. При редкой болезни ложных тревог может быть больше, чем настоящих случаев, поэтому ответ может быть намного ниже 99 %. Но и 1 % неверно: положительный тест всё же поднимает вероятность.

### Границы модели

В примере все числа заданы точно, а в жизни и заболеваемость, и точность теста сами оцениваются с ошибкой, а люди идут на тест не случайно. Второй тест считается независимым только при условии, что ошибки двух тестов не связаны между собой, а у одинаковых тестов это часто не так. Это учебный пример и не медицинский совет. Счётчик букв в уроке считает частоты в одной фразе, поэтому его вероятности верны только для неё. В тренажёре дробные люди округляются до целых кубиков.

## English

### Goal

Compute conditional probability, test events for independence, and use Bayes' rule to reverse probabilities and avoid the base rate fallacy.

### Idea and mechanism

A language model answers one question: what is the probability of the next letter, given what has been written? This is a conditional probability. It is easiest to understand through counts.

**Conditional probability.** The probability of an event `A` given that `B` happened is

`P(A | B) = P(A and B) / P(B)`

The meaning is simple: having learned of `B`, we throw out all outcomes where `B` did not happen, and count the share of `A` among those left. Take the phrase `the cat sat on the mat and the dog sat on the log`. It has 49 characters, and the letter `h` occurs 4 times, so `P(h) = 4/49 ≈ 0.082`. The letter `t` occurs 8 times, and 4 times `h` follows it, so `P(h | t before it) = 4/8 = 0.5`. Knowing the previous letter raised the probability sixfold. This is how the letter-pair counter from the cross-entropy lesson works.

**Independence.** Events are independent if knowing one does not change the probability of the other: `P(A | B) = P(A)`. Then `P(A and B) = P(A) · P(B)`. Letters in a text are dependent, and we just used that. Two flips of a fair coin are independent: the first says nothing about the second.

**Bayes' rule.** From the definition, `P(A and B) = P(A | B) · P(B) = P(B | A) · P(A)`. Dividing by `P(B)` gives a way to reverse the condition:

`P(A | B) = P(B | A) · P(A) / P(B)`

Here `P(A)` is called the prior probability, what we thought before the observation. `P(A | B)` is called the posterior probability: the updated belief after the observation. The denominator splits into all the ways of getting `B`: `P(B) = P(B | A) · P(A) + P(B | not A) · P(not A)`.

**A worked example.** A rare disease affects 1% of people. A test finds 99% of the sick, but also gives a false alarm for 5% of the healthy. A person tests positive. What is the probability they are sick? Intuition suggests something near 99%. Compute it with 1000 people. There are 10 sick, and the test finds about 9.9 of them. There are 990 healthy, and about 49.5 get a false alarm. There are 59.4 positives in all, of whom 9.9 are sick:

`P(sick | +) = 9.9 / 59.4 ≈ 0.167`

Just 17%. The probability `P(+ | sick) = 0.99` reversed into `P(sick | +) ≈ 0.167`, and these are quite different numbers. Ignoring how rare the disease itself is is called the base rate fallacy. The reason is that the healthy are far more numerous, so even a small share of false alarms among them outnumbers all the truly sick.

**Updating.** Take a second, independent test. Now our prior belief is 0.167, not 0.01. The rule gives `0.167 · 0.99 / (0.167 · 0.99 + 0.833 · 0.05) ≈ 0.798`. Each observation updates the belief, and the next one starts from the new value. Training a model can also be understood as updating a belief about the world from data.

All of this in plain Python:

```python
from collections import Counter

text = "the cat sat on the mat and the dog sat on the log"
letters = Counter(text)
pairs = Counter(zip(text, text[1:]))
starts = Counter(text[:-1])


def chance(letter):
    return letters[letter] / len(text)


def chance_after(previous, letter):  # P(letter | previous)
    return pairs[previous, letter] / starts[previous]


def bayes(prior, hit, false_alarm):
    return prior * hit / (prior * hit + (1 - prior) * false_alarm)


print("P(h)", round(chance("h"), 3))
print("P(h|t)", round(chance_after("t", "h"), 3))
first = bayes(0.01, 0.99, 0.05)
print("after one test", round(first, 3))
print("after two tests", round(bayes(first, 0.99, 0.05), 3))
print("fewer false alarms", round(bayes(0.01, 0.99, 0.01), 3))
```

The program prints:

```text
P(h) 0.082
P(h|t) 0.5
after one test 0.167
after two tests 0.798
fewer false alarms 0.5
```

The last line explains what matters most in such a test: lowering false alarms from 5% to 1% raises the probability of disease after a positive test from 17% to 50%.

### Explore and practise

The lab holds a true town of 1000 people. Each person is a cube. The sick are red and the healthy are blue. Those who test positive rise above the town. Look at the raised cubes: what share of them is red? That is `P(sick | +)`. Turn the town with the mouse and move the sliders. How does the answer change as the disease gets rarer? What happens if only the raised cubes take a second test?

Then extend the program: compute `chance_after("a", "t")`. How does this number differ from `chance("t")`?

### Question

A test finds 99% of the sick. Your result is positive, and the disease is very rare. What can be said for certain?

### Options

- The probability of disease is 99%, because the test finds that many.
- The probability of disease also depends on rarity and false alarms.
- The probability of disease is 1%, because that many people are sick.

### Answer

2

### Explanation

The number 99% is `P(+ | sick)`, while the question is about `P(sick | +)`. To reverse the condition, you need the prior probability of disease and the share of false alarms. With a rare disease there can be more false alarms than true cases, so the answer may be far below 99%. But 1% is wrong too: a positive test does raise the probability.

### Limits

In the example all numbers are given exactly, while in life both the disease rate and the test's accuracy are themselves estimated with error, and people do not take tests at random. A second test counts as independent only if the errors of the two tests are unrelated, which is often untrue for identical tests. This is a teaching example and not medical advice. The letter counter in the lesson counts frequencies in one phrase, so its probabilities hold only for that phrase. In the lab, fractional people are rounded to whole cubes.

## Sources

- Barbara Illowsky, Susan Dean, *Introductory Statistics 2e*, OpenStax (December 13, 2023), §3.1 “Terminology” (consulted 2026-11-02): conditional probability as a reduced sample space and P(A AND B) / P(B): [OpenStax, §3.1](https://openstax.org/books/introductory-statistics-2e/pages/3-1-terminology)
- Aston Zhang, Zachary C. Lipton, Mu Li, Alexander J. Smola, *Dive into Deep Learning* (version 1.0.3), “Probability and Statistics” (consulted 2026-11-02): conditional probability, Bayes' theorem, and independence: [D2L, probability](https://d2l.ai/chapter_preliminaries/probability.html)
- Wikipedia, “Base rate fallacy” (consulted 2026-11-02): ignoring how common a condition is, and the false positive paradox of an accurate test for a rare condition: [Base rate fallacy](https://en.wikipedia.org/wiki/Base_rate_fallacy)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
