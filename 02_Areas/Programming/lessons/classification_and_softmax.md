---
subject: programming
lesson_id: programming.classification_and_softmax
level: advanced
languages: ru, en
source_checked: 2026-11-01
source_review_interval_days: 365
---

# Классификация и softmax / Classification and Softmax

## Русский

### Простыми словами

Классификация значит выбрать один ответ из нескольких: кошка, собака или птица. Модель сначала даёт каждому варианту оценку, любое число. Softmax превращает оценки в вероятности: все положительные и в сумме дают 1. Похоже на деление пирога: у кого оценка выше, тому кусок больше, но кусок есть у каждого. Ошибку считают как удивление верным ответом, и спуск двигает оценки так, чтобы верный кусок рос.

**Что нужно знать до.** Урок «Информация, энтропия и кросс-энтропия» (шаг 6) и урок «Градиентный спуск и шаг обучения» (шаг 4).

**Если непонятно.** Если неясна экспонента `e^z`, посчитай softmax для оценок `(2, 1, 0)` руками и проверь, что сумма равна 1. Если неясна ошибка `−ln q`, вернись к уроку «Информация, энтропия и кросс-энтропия». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Превращать оценки модели в вероятности через softmax, выводить градиент кросс-энтропии и написать на чистом Python классификатор, который сам учится выбирать один класс из нескольких.

### Идея и механизм

Классификация — это выбор одного ответа из нескольких: цифра на картинке, тема письма. Языковая модель делает то же самое на каждом шаге: следующий символ — это класс, и символов в алфавите столько же, сколько классов. Поэтому механизм этого урока и есть выход будущей языковой модели.

**Из оценок в вероятности.** Для каждого класса `k` модель считает одно число, оценку `zₖ`. В простейшей модели это взвешенная сумма входов: `zₖ = wₖ₁x₁ + wₖ₂x₂ + bₖ`. Оценки могут быть любыми, даже отрицательными. Чтобы получить вероятности, применяют softmax:

`qₖ = exp(zₖ) / Σ exp(zⱼ)`

Экспонента делает всё положительным, а деление на сумму делает сумму равной 1. Посчитаем для оценок `z = (2; 1; 0)`. Степени равны `7,389`, `2,718` и `1`, их сумма `11,107`, поэтому `q = (0,665; 0,245; 0,090)`. Порядок сохранился: самая большая оценка дала самую большую вероятность. Важны только разности оценок: при `z = (3; 2; 1)` вероятности те же самые. А если разности растут, модель становится увереннее: при `z = (4; 2; 0)` получаем `q = (0,867; 0,117; 0,016)`. Ни одна вероятность не становится нулём, поэтому ошибка никогда не будет бесконечной.

**Функция ошибки.** Из прошлого урока мы знаем ответ: для примера с верным классом `r` ошибка равна `L = −ln q_r`. Если при `z = (2; 1; 0)` верен первый класс, ошибка `−ln 0,665 ≈ 0,408`. Если верен третий, `−ln 0,090 ≈ 2,408`. Модель получает большую ошибку именно тогда, когда уверенно ошибается. Пока веса нулевые, все вероятности равны `1/3`, и ошибка равна `ln 3 ≈ 1,099`. Это и есть проверка из прошлого урока: начальная ошибка должна быть близка к `ln V`.

**Градиент.** Запишем ошибку прямо через оценки: `L = −z_r + ln Σ exp(zⱼ)`. Берём производную по `zₖ`. Первое слагаемое даёт `−1`, если `k = r`, иначе 0. Второе по правилу цепочки даёт `exp(zₖ) / Σ exp(zⱼ)`, а это и есть `qₖ`. Значит,

`∂L/∂zₖ = qₖ − pₖ`

где `pₖ` равно 1 для верного класса и 0 для остальных. Градиент оказывается просто разностью между тем, что сказала модель, и тем, что было на самом деле. Ещё один шаг по правилу цепочки доходит до весов: `∂L/∂wₖ₁ = (qₖ − pₖ) · x₁`, `∂L/∂bₖ = qₖ − pₖ`.

**Почему не квадратичная ошибка.** В уроке о скрытом слое мы брали `(y − t)²`. Сравним на одном нейроне с сигмоидой, когда он уверенно ошибается: `y = 0,01`, цель `t = 1`. Квадратичная ошибка даёт градиент по оценке `2(y − t) · y(1 − y) ≈ −0,0196`: множитель `y(1 − y)` почти нулевой, и нейрон еле учится именно тогда, когда ошибается сильнее всего. Кросс-энтропия для того же нейрона даёт `y − t = −0,99`, то есть примерно в 50 раз больше. Логарифм в ошибке снимает насыщение сигмоиды.

Вся программа на чистом Python. Двенадцать точек лежат в трёх облаках, а модель с нулевыми весами учится их различать:

```python
import math

data = [(-1.0, -0.6, 0), (-0.7, -1.0, 0), (-1.1, -1.0, 0), (-0.6, -0.5, 0),
        (1.0, -0.7, 1), (0.7, -1.0, 1), (1.1, -0.3, 1), (0.6, -0.5, 1),
        (0.0, 1.0, 2), (-0.4, 0.7, 2), (0.4, 0.8, 2), (0.1, 0.5, 2)]
rate = 0.3


def softmax(scores):
    powers = [math.exp(z) for z in scores]
    total = sum(powers)
    return [p / total for p in powers]


def answer(w, x1, x2):
    return softmax([w[k][0] * x1 + w[k][1] * x2 + w[k][2] for k in range(3)])


def loss(w):
    return sum(-math.log(answer(w, x1, x2)[label]) for x1, x2, label in data) / len(data)


def gradient(w):
    total = [[0.0] * 3 for _ in range(3)]
    for x1, x2, label in data:
        q = answer(w, x1, x2)
        for k in range(3):
            difference = q[k] - (1 if k == label else 0)  # q − p
            for i, value in enumerate((x1, x2, 1)):
                total[k][i] += difference * value / len(data)
    return total


w = [[0.0] * 3 for _ in range(3)]
for step in range(301):
    if step in (0, 20, 60, 300):
        print(step, round(loss(w), 3))
    if step < 300:
        g = gradient(w)
        w = [[w[k][i] - rate * g[k][i] for i in range(3)] for k in range(3)]

print([round(p, 3) for p in answer(w, 0.9, -0.8)])
print([round(p, 3) for p in answer(w, 0.0, -0.3)])
print(sum(max(range(3), key=lambda k: answer(w, x1, x2)[k]) == label for x1, x2, label in data), "of", len(data))
```

Программа печатает:

```text
0 1.099
20 0.32
60 0.122
300 0.027
[0.006, 0.992, 0.002]
[0.396, 0.397, 0.207]
12 of 12
```

Ошибка начинается с `ln 3` и падает до 0,027. Посмотри на две новые точки, которых не было в данных. Точка `(0,9; −0,8)` лежит внутри второго облака, и модель уверена: 0,992. Точка `(0; −0,3)` лежит между первым и вторым облаками, и модель честно колеблется: 0,396 против 0,397. Это и есть польза вероятностей: модель сообщает не только ответ, но и свою уверенность.

**Граница всегда прямая.** Классы `a` и `b` равновероятны там, где `z_a = z_b`. Это линейное уравнение от входов, то есть прямая на плоскости. Softmax не сгибает границы, потому что сохраняет порядок оценок, а сами оценки линейны. Поэтому классификатор без скрытых слоёв не решит задачу XOR: её классы нельзя разделить прямыми, и средняя ошибка застынет около `ln 2 ≈ 0,69`, то есть модель будет только угадывать между двумя классами. Скрытые слои строят новое представление, в котором прямых уже хватает, и об этом следующий шаг пути.

### Исследуй и потренируйся

В тренажёре настоящий классификатор построен как объёмный рельеф. Основание — все возможные входы, цвет — выбранный класс, высота — уверенность модели. Нажми «Пуск» и смотри, как из плоскости вырастают три плато, а между ними остаются низины: там модель колеблется. Подбери скорость обучения для задания. Затем выбери класс и щёлкни по чужому плато, чтобы добавить туда точку: как изменились границы и ошибка? Наконец, включи набор XOR и посмотри, где застынет ошибка.

Затем измени программу: поставь `rate = 3.0` и сравни, сколько шагов нужно, чтобы опуститься ниже 0,1.

### Вопрос

Модель выдала вероятности `(0,8; 0,1; 0,1)`, а верен второй класс. Какими будут знаки градиента по оценкам `(z₁; z₂; z₃)`?

### Варианты

- `(+; +; +)`: все оценки завышены и должны снизиться.
- `(−; −; −)`: все оценки занижены и должны вырасти.
- `(+; −; +)`: оценка верного класса вырастет, другие снизятся.

### Ответ

3

### Разбор

Градиент равен `q − p`, а это `(0,8; 0,1 − 1; 0,1) = (0,8; −0,9; 0,1)`. Шаг идёт против градиента, поэтому оценка верного второго класса вырастет, а первая и третья снизятся. Сильнее всего снизится первая: именно на неё пришлась ошибочная уверенность. Сумма компонент всегда равна нулю, поэтому все знаки сразу одинаковыми быть не могут.

### Границы модели

Двенадцать чистых точек на плоскости — учебный пример: настоящие классы редко образуют такие ровные облака. Модель в этом уроке линейна и видит только два входа, поэтому границы у неё прямые. Вероятности модели — это её собственная оценка, а не обязательно правда: у обученной сети они могут быть завышены, поэтому уверенность проверяют на отложенных данных. Рост весов на разделимых данных не останавливается сам: ошибка стремится к нулю только при бесконечно больших весах.

## English

### In plain words

Classification means picking one answer out of several: cat, dog or bird. The model first gives each option a score, any number. Softmax turns the scores into probabilities: all positive and adding up to 1. It is like slicing a pie: a higher score gets a bigger slice, but everyone gets some. The error is the surprise at the right answer, and descent moves the scores so the right slice grows.

**What to know first.** The lesson «Information, Entropy, and Cross-Entropy» (step 6) and «Gradient Descent and the Learning Rate» (step 4).

**If something is unclear.** If the exponent `e^z` is unclear, compute softmax for the scores `(2, 1, 0)` by hand and check that the sum is 1. If the error `−ln q` is unclear, go back to «Information, Entropy, and Cross-Entropy». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Turn a model's scores into probabilities with softmax, derive the gradient of cross-entropy, and write in plain Python a classifier that learns by itself to choose one class among several.

### Idea and mechanism

Classification means choosing one answer among several: the digit in an image, the topic of a letter. A language model does the same at every step: the next character is a class, and there are as many classes as characters in the alphabet. So the mechanism of this lesson is the output of your future language model.

**From scores to probabilities.** For each class `k` the model computes one number, the score `zₖ`. In the simplest model this is a weighted sum of inputs: `zₖ = wₖ₁x₁ + wₖ₂x₂ + bₖ`. Scores can be anything, even negative. To get probabilities, apply softmax:

`qₖ = exp(zₖ) / Σ exp(zⱼ)`

The exponential makes everything positive, and dividing by the sum makes the total 1. Compute it for the scores `z = (2, 1, 0)`. The powers are `7.389`, `2.718`, and `1`, their sum is `11.107`, so `q = (0.665, 0.245, 0.090)`. The order is preserved: the largest score gave the largest probability. Only differences between scores matter: `z = (3, 2, 1)` gives the very same probabilities. If the differences grow, the model becomes more confident: `z = (4, 2, 0)` gives `q = (0.867, 0.117, 0.016)`. No probability ever becomes zero, so the error is never infinite.

**The error function.** The last lesson gave the answer: for an example whose right class is `r`, the error is `L = −ln q_r`. If at `z = (2, 1, 0)` the first class is right, the error is `−ln 0.665 ≈ 0.408`. If the third is right, it is `−ln 0.090 ≈ 2.408`. The model gets a large error exactly when it is confidently wrong. While the weights are zero, all probabilities equal `1/3` and the error equals `ln 3 ≈ 1.099`. This is the check from the last lesson: the starting error should be near `ln V`.

**The gradient.** Write the error directly in terms of the scores: `L = −z_r + ln Σ exp(zⱼ)`. Take the derivative with respect to `zₖ`. The first term gives `−1` if `k = r` and 0 otherwise. The second, by the chain rule, gives `exp(zₖ) / Σ exp(zⱼ)`, which is `qₖ`. So

`∂L/∂zₖ = qₖ − pₖ`

where `pₖ` is 1 for the right class and 0 for the others. The gradient turns out to be simply the difference between what the model said and what actually happened. One more chain-rule step reaches the weights: `∂L/∂wₖ₁ = (qₖ − pₖ) · x₁`, `∂L/∂bₖ = qₖ − pₖ`.

**Why not squared error.** In the hidden layer lesson we used `(y − t)²`. Compare on one sigmoid neuron that is confidently wrong: `y = 0.01`, target `t = 1`. Squared error gives a gradient over the score of `2(y − t) · y(1 − y) ≈ −0.0196`: the factor `y(1 − y)` is almost zero, and the neuron barely learns exactly when it is most wrong. Cross-entropy for the same neuron gives `y − t = −0.99`, about 50 times more. The logarithm in the error removes the saturation of the sigmoid.

The whole program in plain Python. Twelve points lie in three clouds, and a model with zero weights learns to tell them apart:

```python
import math

data = [(-1.0, -0.6, 0), (-0.7, -1.0, 0), (-1.1, -1.0, 0), (-0.6, -0.5, 0),
        (1.0, -0.7, 1), (0.7, -1.0, 1), (1.1, -0.3, 1), (0.6, -0.5, 1),
        (0.0, 1.0, 2), (-0.4, 0.7, 2), (0.4, 0.8, 2), (0.1, 0.5, 2)]
rate = 0.3


def softmax(scores):
    powers = [math.exp(z) for z in scores]
    total = sum(powers)
    return [p / total for p in powers]


def answer(w, x1, x2):
    return softmax([w[k][0] * x1 + w[k][1] * x2 + w[k][2] for k in range(3)])


def loss(w):
    return sum(-math.log(answer(w, x1, x2)[label]) for x1, x2, label in data) / len(data)


def gradient(w):
    total = [[0.0] * 3 for _ in range(3)]
    for x1, x2, label in data:
        q = answer(w, x1, x2)
        for k in range(3):
            difference = q[k] - (1 if k == label else 0)  # q − p
            for i, value in enumerate((x1, x2, 1)):
                total[k][i] += difference * value / len(data)
    return total


w = [[0.0] * 3 for _ in range(3)]
for step in range(301):
    if step in (0, 20, 60, 300):
        print(step, round(loss(w), 3))
    if step < 300:
        g = gradient(w)
        w = [[w[k][i] - rate * g[k][i] for i in range(3)] for k in range(3)]

print([round(p, 3) for p in answer(w, 0.9, -0.8)])
print([round(p, 3) for p in answer(w, 0.0, -0.3)])
print(sum(max(range(3), key=lambda k: answer(w, x1, x2)[k]) == label for x1, x2, label in data), "of", len(data))
```

The program prints:

```text
0 1.099
20 0.32
60 0.122
300 0.027
[0.006, 0.992, 0.002]
[0.396, 0.397, 0.207]
12 of 12
```

The error starts at `ln 3` and falls to 0.027. Look at the two new points that were not in the data. The point `(0.9, −0.8)` lies inside the second cloud, and the model is sure: 0.992. The point `(0, −0.3)` lies between the first and second clouds, and the model honestly hesitates: 0.396 against 0.397. This is the use of probabilities: a model reports not only an answer but also its confidence.

**The boundary is always straight.** Classes `a` and `b` are equally likely where `z_a = z_b`. This is a linear equation in the inputs, so it is a straight line on the plane. Softmax does not bend the boundaries, because it preserves the order of the scores, and the scores themselves are linear. So a classifier with no hidden layers cannot solve XOR: its classes cannot be separated by lines, and the mean error freezes near `ln 2 ≈ 0.69`, meaning the model can only guess between two classes. Hidden layers build a new representation in which lines are enough, and that is the next step of the path.

### Explore and practise

In the lab, a real classifier is built as a solid relief. The base is all possible inputs, the colour is the chosen class, and the height is the model's confidence. Press Play and watch three plateaus rise from the plane, with low ground between them where the model hesitates. Find a learning rate for the task. Then pick a class and click on another class's plateau to add a point there: how did the boundaries and the error change? Finally, switch to the XOR set and see where the error freezes.

Then change the program: set `rate = 3.0` and compare how many steps it takes to go below 0.1.

### Question

A model gave the probabilities `(0.8, 0.1, 0.1)`, and the second class is right. What are the signs of the gradient over the scores `(z₁, z₂, z₃)`?

### Options

- `(+, +, +)`: all scores are too high and must go down.
- `(−, −, −)`: all scores are too low and must go up.
- `(+, −, +)`: the right class's score rises, the others go down.

### Answer

3

### Explanation

The gradient is `q − p`, which is `(0.8, 0.1 − 1, 0.1) = (0.8, −0.9, 0.1)`. A step goes against the gradient, so the score of the right second class rises while the first and third go down. The first falls most: the mistaken confidence sat on it. The components always sum to zero, so all the signs cannot match.

### Limits

Twelve clean points on a plane are a teaching example: real classes rarely form such tidy clouds. The model in this lesson is linear and sees only two inputs, so its boundaries are straight. A model's probabilities are its own estimate and not necessarily the truth: those of a trained network can be overconfident, so confidence is checked on held-out data. On separable data the weights keep growing by themselves: the error approaches zero only as the weights go to infinity.

## Sources

- Aston Zhang, Zachary C. Lipton, Mu Li, Alexander J. Smola, *Dive into Deep Learning* (version 1.0.3), “Softmax Regression” (consulted 2026-11-01): the softmax definition, its preservation of order, cross-entropy as negative log probability of the right class, its equivalence to maximum likelihood, and the gradient as prediction minus label: [D2L, softmax regression](https://d2l.ai/chapter_linear-classification/softmax-regression.html)
- Stanford CS231n notes, “Linear classification” (consulted 2026-11-01): the softmax classifier, its cross-entropy loss, and the straight boundaries of a linear classifier: [CS231n, linear classification](https://cs231n.github.io/linear-classify/)
- The derivation, the program, and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
