---
subject: programming
lesson_id: programming.minibatches_and_overfitting
level: advanced
languages: ru, en
source_checked: 2026-11-01
source_review_interval_days: 365
---

# Мини-батчи и переобучение / Mini-Batches and Overfitting

## Русский

### Цель

Понять, почему модели учат на маленьких пакетах данных, измерить выигрыш в числе прочитанных примеров, увидеть переобучение на двух кривых и остановить его двумя способами: ранней остановкой и ослаблением весов.

### Идея и механизм

До сих пор в каждом шаге мы считали градиент по всем примерам. На четырёх примерах XOR это легко. Но в финальном проекте текст содержит больше миллиона символов, и один шаг по всем данным занял бы слишком много времени. Кроме того, в данных много повторов: чтобы узнать направление спуска, не нужно читать весь текст.

**Мини-батч.** Возьмём `b` случайных примеров и посчитаем градиент только по ним. Его среднее значение совпадает с настоящим градиентом, поэтому в среднем шаг идёт куда нужно. Но он шумит: дисперсия такого градиента падает как `1/b`, а его типичное отклонение как `1/√b`. Значит, пакет в 100 раз больше убирает шум лишь в 10 раз. Отсюда главный расчёт: четыре примера дают в 4 раза больше данных, но шаг точнее только в 2 раза. Поэтому при том же числе прочитанных примеров несколько шумных шагов обычно полезнее одного точного.

Один проход по всем данным называется эпохой. Обычно перед каждой эпохой данные перемешивают и берут пакеты по порядку: так каждый пример читается один раз за эпоху.

**Переобучение.** Модель может запомнить свои данные вместе с их шумом, а не найти правило. Признак переобучения легко заметить, если отложить часть данных и не учиться на них: ошибка на обучающих данных продолжает падать, а ошибка на отложенных сначала падает, а потом растёт. В этом месте модель начинает учить случайности.

Лечат это несколькими способами. **Ранняя остановка:** помним веса с лучшей отложенной ошибкой и возвращаемся к ним. **Ослабление весов:** к ошибке прибавляем `λ Σ w²`, поэтому большие веса обходятся дорого, а шаг обучения слегка уменьшает все веса. Большие веса позволяют функции резко изгибаться, чтобы пройти через шумные точки, а малые держат её более гладкой. Третий способ — просто взять больше данных.

Проверим оба явления на чистом Python. Сначала прямая по 24 точкам: сколько примеров нужно прочитать, чтобы подойти к лучшей ошибке на 5 %. Затем модель из 21 волны на 12 точках с шумом и 40 отложенных точках:

```python
import math

state = 31337


def random_number():
    global state
    state = state * 16807 % 2147483647
    return state / 2147483647


def noise(scale):
    return (random_number() + random_number() + random_number() - 1.5) * scale


points = [(-1.5 + 3 * i / 23, 0.0) for i in range(24)]
points = [(x, 1.2 * x + 0.5 + noise(0.7)) for x, _ in points]


def loss(w, b):
    return sum((w * x + b - y) ** 2 for x, y in points) / len(points)


def best_loss():  # точное решение метода наименьших квадратов
    n, sx, sy = len(points), sum(p[0] for p in points), sum(p[1] for p in points)
    sxx, sxy = sum(p[0] ** 2 for p in points), sum(p[0] * p[1] for p in points)
    w = (n * sxy - sx * sy) / (n * sxx - sx * sx)
    return loss(w, (sy - w * sx) / n)


def reads_to_target(batch, rate):
    global state
    state = 555  # каждый опыт перемешивает данные одинаково
    w, b, reads, cursor = -2.5, 2.5, 0, len(points)
    order = list(range(len(points)))
    target = best_loss() * 1.05  # на 5 % выше лучшего
    while loss(w, b) > target and reads < 2000:
        if cursor + batch > len(order):  # новая эпоха: перемешиваем
            for i in range(len(order) - 1, 0, -1):
                j = int(random_number() * (i + 1))
                order[i], order[j] = order[j], order[i]
            cursor = 0
        chosen = [points[k] for k in order[cursor:cursor + batch]]
        cursor += batch
        w, b = (w - rate * sum(2 * (w * x + b - y) * x for x, y in chosen) / batch,
                b - rate * sum(2 * (w * x + b - y) for x, y in chosen) / batch)
        reads += batch
    return reads


for batch in (1, 4, 24):
    print("batch", batch, "reads", reads_to_target(batch, 0.1), reads_to_target(batch, 0.2))

state = 2718
train = [(-1.5 + 3 * i / 11, 0.0) for i in range(12)]
train = [(x, 1.2 * math.sin(1.5 * x) + noise(0.9)) for x, _ in train]
held = [(-1.5 + 3 * (i + 0.5) / 40, 0.0) for i in range(40)]
held = [(x, 1.2 * math.sin(1.5 * x) + noise(0.9)) for x, _ in held]


def features(x):
    wave = [1.0]
    for k in range(1, 11):
        wave += [math.cos(1.05 * k * x) / k, math.sin(1.05 * k * x) / k]
    return wave


def error(w, data):
    return sum((sum(a * f for a, f in zip(w, features(x))) - y) ** 2 for x, y in data) / len(data)


def train_model(decay, steps=600, rate=0.05):
    w = [0.0] * 21
    best = (error(w, held), 0)
    for step in range(1, steps + 1):
        slope = [2 * decay * a for a in w]
        for x, y in train:
            f = features(x)
            miss = 2 * (sum(a * b for a, b in zip(w, f)) - y) / len(train)
            slope = [s + miss * v for s, v in zip(slope, f)]
        w = [a - rate * s for a, s in zip(w, slope)]
        best = min(best, (error(w, held), step))
    return round(error(w, train), 3), round(error(w, held), 3), round(best[0], 3), best[1]


print("decay 0", train_model(0.0))
print("decay 0.1", train_model(0.1))
```

Программа печатает:

```text
batch 1 reads 19 27
batch 4 reads 88 44
batch 24 reads 528 240
decay 0 (0.005, 0.427, 0.316, 31)
decay 0.1 (0.074, 0.338, 0.323, 41)
```

В первых трёх строках указаны размер пакета и число прочитанных примеров при скорости 0,1 и 0,2. При скорости 0,2 полный проход по всем 24 точкам требует 240 чтений, пакет из 4 точек требует 44, а по одной точке хватает 27. Шумный путь приходит к цели за намного меньшую цену. Но цель здесь широкая: при малом пакете шаг не останавливается у самого минимума, а блуждает вокруг него. Поэтому к концу обучения скорость обычно снижают.

В последних двух строках указаны четыре числа: ошибка на обучающих данных в конце, ошибка на отложенных в конце, лучшая отложенная ошибка и шаг, на котором она была. Без ослабления весов обучающая ошибка падает почти до нуля, 0,005: модель почти запомнила шум. А отложенная ошибка к концу выросла до 0,427, хотя на шаге 31 она была всего 0,316. Ранняя остановка вернула бы нас именно туда. С ослаблением `λ = 0,1` обучающая ошибка выше, 0,074, зато отложенная в конце намного лучше, 0,338, и почти не растёт после своего минимума.

**Для языковой модели.** В финальном проекте мы будем брать случайные куски текста, следить за ошибкой на отложенной части текста и сохранять лучшие веса. Отложенная ошибка и будет честной мерой того, чему модель научилась.

### Исследуй и потренируйся

В первом тренажёре стоит настоящая чаша ошибки прямой. Оранжевая стрелка показывает шаг, который подсказал текущий пакет, а белая настоящее направление спуска. Запусти обучение при большом пакете и при малом: как изменились путь, разница стрелок и число прочитанных примеров? Выполни задание: дойди до цели меньше чем за один проход по данным.

Во втором тренажёре смотри на две кривые ошибки и саму функцию на графике. Запусти обучение без ослабления весов и посмотри, как функция начинает проходить через шумные точки. Затем подбери `λ`, чтобы отложенная ошибка к концу стала низкой.

Затем добавь в программу пакеты размером 8 и проверь, укладываются ли они между числами в таблице.

### Вопрос

Обучающая ошибка продолжает падать, а отложенная начала расти. Что это значит и что делать?

### Варианты

- Шаг слишком мал: поэтому нужно увеличить скорость обучения.
- Модель учит шум: нужно остановиться или ослабить веса.
- Ошибка считается неверно: кривые всегда должны падать.

### Ответ

2

### Разбор

Когда кривые расходятся, модель всё лучше запоминает свои примеры и всё хуже работает на новых. Значит, она начала учить случайности данных. Скорость тут не поможет: быстрее падать будет именно обучающая ошибка. Расхождение кривых не ошибка программы, а обычное поведение гибкой модели на малых данных. Лечат его ранней остановкой, ослаблением весов или большим объёмом данных.

### Границы модели

В опытах урока данные маленькие и выбраны так, чтобы всё было видно. Числа зависят от случайной выборки, поэтому при других перемешиваниях будут другими. Чаша прямой выпуклая, поэтому шум там лишь мешает, а на сложных рельефах настоящих сетей шум иногда помогает выйти с плато. Отложенные данные можно использовать для выбора `λ` и момента остановки, но тогда они перестают быть полностью честными: для итоговой оценки хранят ещё одну часть данных, которую не трогают до самого конца.

## English

### Goal

Understand why models are trained on small batches of data, measure the gain in examples read, see overfitting on two curves, and stop it in two ways: early stopping and weight decay.

### Idea and mechanism

So far each step computed the gradient over all examples. With four XOR examples this is easy. But in the final project the text holds over a million characters, and one step over all the data would take too long. Besides, data has many repeats: to learn the direction of descent, you need not read the whole text.

**The mini-batch.** Take `b` random examples and compute the gradient over them alone. Its mean matches the true gradient, so on average a step goes where it should. But it is noisy: the variance of such a gradient falls as `1/b`, and its typical deviation as `1/√b`. So a batch 100 times larger removes only 10 times the noise. This gives the main calculation: four examples hold 4 times more data but make a step only 2 times more precise. So for the same number of examples read, several noisy steps are usually more useful than one precise step.

One pass over all the data is called an epoch. Usually the data is shuffled before each epoch and batches are taken in order, so each example is read once per epoch.

**Overfitting.** A model can memorize its data along with its noise instead of finding the rule. A sign of overfitting is easy to spot if part of the data is set aside and not trained on: the error on the training data keeps falling, while the error on the held-out data falls at first and then rises. At that point the model starts learning chance.

There are several cures. **Early stopping:** remember the weights with the best held-out error and go back to them. **Weight decay:** add `λ Σ w²` to the error, so that large weights cost more, and a training step slightly shrinks all weights. Large weights let a function bend sharply to pass through noisy points, while small ones keep it smoother. A third cure is simply to get more data.

Check both effects in plain Python. First a line over 24 points: how many examples must be read to come within 5% of the best error. Then a model of 21 waves on 12 noisy points and 40 held-out points:

```python
import math

state = 31337


def random_number():
    global state
    state = state * 16807 % 2147483647
    return state / 2147483647


def noise(scale):
    return (random_number() + random_number() + random_number() - 1.5) * scale


points = [(-1.5 + 3 * i / 23, 0.0) for i in range(24)]
points = [(x, 1.2 * x + 0.5 + noise(0.7)) for x, _ in points]


def loss(w, b):
    return sum((w * x + b - y) ** 2 for x, y in points) / len(points)


def best_loss():  # the exact least-squares solution
    n, sx, sy = len(points), sum(p[0] for p in points), sum(p[1] for p in points)
    sxx, sxy = sum(p[0] ** 2 for p in points), sum(p[0] * p[1] for p in points)
    w = (n * sxy - sx * sy) / (n * sxx - sx * sx)
    return loss(w, (sy - w * sx) / n)


def reads_to_target(batch, rate):
    global state
    state = 555  # each experiment shuffles the data the same way
    w, b, reads, cursor = -2.5, 2.5, 0, len(points)
    order = list(range(len(points)))
    target = best_loss() * 1.05  # 5% above the best
    while loss(w, b) > target and reads < 2000:
        if cursor + batch > len(order):  # a new epoch: shuffle
            for i in range(len(order) - 1, 0, -1):
                j = int(random_number() * (i + 1))
                order[i], order[j] = order[j], order[i]
            cursor = 0
        chosen = [points[k] for k in order[cursor:cursor + batch]]
        cursor += batch
        w, b = (w - rate * sum(2 * (w * x + b - y) * x for x, y in chosen) / batch,
                b - rate * sum(2 * (w * x + b - y) for x, y in chosen) / batch)
        reads += batch
    return reads


for batch in (1, 4, 24):
    print("batch", batch, "reads", reads_to_target(batch, 0.1), reads_to_target(batch, 0.2))

state = 2718
train = [(-1.5 + 3 * i / 11, 0.0) for i in range(12)]
train = [(x, 1.2 * math.sin(1.5 * x) + noise(0.9)) for x, _ in train]
held = [(-1.5 + 3 * (i + 0.5) / 40, 0.0) for i in range(40)]
held = [(x, 1.2 * math.sin(1.5 * x) + noise(0.9)) for x, _ in held]


def features(x):
    wave = [1.0]
    for k in range(1, 11):
        wave += [math.cos(1.05 * k * x) / k, math.sin(1.05 * k * x) / k]
    return wave


def error(w, data):
    return sum((sum(a * f for a, f in zip(w, features(x))) - y) ** 2 for x, y in data) / len(data)


def train_model(decay, steps=600, rate=0.05):
    w = [0.0] * 21
    best = (error(w, held), 0)
    for step in range(1, steps + 1):
        slope = [2 * decay * a for a in w]
        for x, y in train:
            f = features(x)
            miss = 2 * (sum(a * b for a, b in zip(w, f)) - y) / len(train)
            slope = [s + miss * v for s, v in zip(slope, f)]
        w = [a - rate * s for a, s in zip(w, slope)]
        best = min(best, (error(w, held), step))
    return round(error(w, train), 3), round(error(w, held), 3), round(best[0], 3), best[1]


print("decay 0", train_model(0.0))
print("decay 0.1", train_model(0.1))
```

The program prints:

```text
batch 1 reads 19 27
batch 4 reads 88 44
batch 24 reads 528 240
decay 0 (0.005, 0.427, 0.316, 31)
decay 0.1 (0.074, 0.338, 0.323, 41)
```

The first three lines give the batch size and the examples read at rates 0.1 and 0.2. At rate 0.2, full passes over all 24 points need 240 reads, a batch of 4 points needs 44, and one point at a time needs just 27. The noisy path arrives at a far lower cost. But the target here is broad: with a small batch a step does not stop at the very minimum but wanders around it. So the rate is usually lowered toward the end of training.

The last two lines give four numbers: the final training error, the final held-out error, the best held-out error, and the step at which it occurred. Without weight decay the training error falls almost to zero, 0.005: the model has nearly memorized the noise. Yet the held-out error grew to 0.427 by the end, though at step 31 it was only 0.316. Early stopping would take us back exactly there. With decay `λ = 0.1` the training error is higher, 0.074, but the final held-out error is far better, 0.338, and it barely rises after its minimum.

**For a language model.** In the final project we will take random pieces of text, watch the error on a held-out part of the text, and keep the best weights. The held-out error will be the honest measure of what the model has learned.

### Explore and practise

The first lab holds the true error bowl of a line. The orange arrow shows the step suggested by the current batch, and the white one the true direction of descent. Start training with a large batch and a small one: how did the path, the difference between the arrows, and the examples read change? Do the task: reach the target in less than one pass over the data.

In the second lab, watch the two error curves and the function itself on the chart. Start training without weight decay and see the function begin to pass through noisy points. Then find a `λ` that makes the held-out error low by the end.

Then add batches of size 8 to the program and check whether they fall between the numbers in the table.

### Question

The training error keeps falling, while the held-out error has begun to rise. What does this mean, and what should be done?

### Options

- The step is too small: so the learning rate must be raised.
- The model is learning noise: stop or apply weight decay.
- The error is computed wrongly: both curves should always fall.

### Answer

2

### Explanation

When the curves diverge, the model memorizes its examples better and better while working worse and worse on new ones. So it has started learning the chance features of the data. The rate will not help: only the training error will fall faster. Diverging curves are not a program error but the usual behaviour of a flexible model on small data. The cures are early stopping, weight decay, or more data.

### Limits

The lesson's experiments use small data chosen so that everything can be seen. The numbers depend on the random sample, so other shuffles give other numbers. A line's bowl is convex, so noise there only gets in the way, while on the complex terrains of real networks noise sometimes helps escape a plateau. Held-out data can be used to choose `λ` and the stopping moment, but then it stops being fully honest: for the final estimate, yet another part of the data is kept untouched until the very end.

## Sources

- Aston Zhang, Zachary C. Lipton, Mu Li, Alexander J. Smola, *Dive into Deep Learning* (version 1.0.3), “Minibatch Stochastic Gradient Descent” (consulted 2026-11-01): the balance between full batches and single examples, the expected value of the batch gradient, its variance falling by a factor of b, and diminishing returns from larger batches: [D2L, minibatch SGD](https://d2l.ai/chapter_optimization/minibatch-sgd.html)
- *Dive into Deep Learning*, “Weight Decay” (consulted 2026-11-01): the penalty on the squared norm of the weights, the shrinking of the weights at each step, and its link to overfitting: [D2L, weight decay](https://d2l.ai/chapter_linear-regression/weight-decay.html)
- Google for Developers, *Machine Learning Crash Course*, “Overfitting” (consulted 2026-11-01): memorizing a training set, and the divergence of training and validation curves: [MLCC, overfitting](https://developers.google.com/machine-learning/crash-course/overfitting/overfitting)
- The programs and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
