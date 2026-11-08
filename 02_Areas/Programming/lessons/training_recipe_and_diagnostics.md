---
subject: programming
lesson_id: programming.training_recipe_and_diagnostics
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Как читать обучение и находить ошибки / Reading training and finding bugs

## Русский

### Простыми словами

Обучение редко ломается громко. Чаще программа работает, а модель учится плохо, и причину надо найти по кривым ошибки. Это как врач, который ставит диагноз по температуре и пульсу. Две простые проверки ловят большинство ошибок сразу: начальная ошибка должна быть такой, как у случайного угадывания, а маленький пакет модель должна уметь заучить до нуля. В уроке ты поставишь диагноз шести настоящим запускам.

**Что нужно знать до.** Уроки «Мини-батчи и переобучение» (шаг 9) и «Классификация и softmax» (шаг 7): откуда берётся начальная ошибка `ln V`.

**Если непонятно.** Если неясно, почему начальная ошибка равна `ln V`, вернись к уроку «Классификация и softmax»: при равных вероятностях каждая из `V` равна `1/V`. Если неясны две кривые, перечитай урок «Мини-батчи и переобучение». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Научиться по двум кривым понимать, что сломалось в обучении. Выполнить две простые проверки, которые ловят большинство ошибок сразу. Поставить диагноз шести настоящим запускам. Нужно около 40 минут.

### Идея и механизм

Обычная программа при ошибке падает. Сеть при ошибке чаще всего молча учится хуже. Андрей Карпатый пишет об этом в заметке «A Recipe for Training Neural Networks»: сломанная сеть обычно не выдаёт никаких сообщений. Поэтому нужны свои проверки.

**Две кривые.** Во время обучения считают ошибку на двух наборах: на обучающих данных и на *проверочных*, которых модель не видит. Обе кривые рисуют на одном графике.

**Проверка 1: начальная ошибка.** Ещё до обучения ты знаешь, какой она должна быть. У задачи с двумя классами случайное угадывание даёт вероятность 0,5, и кросс-энтропия равна `−ln 0,5 = ln 2 ≈ 0,693`. Если в начале ошибка равна 5, что-то не так с данными или с формулой, и учить дальше бессмысленно.

**Проверка 2: заучи маленький пакет.** Дай сети 8 примеров. Сеть на 33 весах должна заучить их почти до нуля. Если не может, ошибка в самой программе, и большие данные тут не помогут. Это странно звучит, ведь обычно переобучения избегают, но здесь мы проверяем код, а не качество.

**Шаг 1. Шесть запусков.** В программе маленькая сеть определяет, лежит ли точка внутри круга. Она та же самая, но каждый раз с одной поломкой. Создай файл `nano ~/ai-path/doctor.py`, вставь программу и запусти. Секунд двадцать идёт расчёт. В строке имя случая, затем три пары чисел: ошибка на обучении и на проверке в начале, на эпохе 100 и в конце, на эпохе 300. *Эпоха* это один проход по всем данным.

```python
import math

state = 4242


def uniform():
    global state
    state = state * 16807 % 2147483647
    return state / 2147483647


def points(count):
    result = []
    for _ in range(count):
        x, y = uniform() * 2 - 1, uniform() * 2 - 1
        result.append((x, y, 1 if x * x + y * y < 0.45 else 0))
    return result


TRAIN, CHECK = points(60), points(200)
FEW = TRAIN[:8]
WIDTH = 8


def fresh():
    return [[uniform() * 2 - 1 for _ in range(3)] for _ in range(WIDTH)], [uniform() * 2 - 1 for _ in range(WIDTH + 1)]


def forward(hidden, out, x, y):
    h = [math.tanh(n[0] * x + n[1] * y + n[2]) for n in hidden]
    z = sum(w * v for w, v in zip(out, h)) + out[-1]
    return h, 1 / (1 + math.exp(-max(min(z, 30), -30)))


def error(hidden, out, data):
    total = 0.0
    for x, y, t in data:
        p = forward(hidden, out, x, y)[1]
        p = min(max(p, 1e-9), 1 - 1e-9)
        total -= math.log(p if t else 1 - p)
    return total / len(data)


def train(data, rate=0.5, epochs=300, sign=-1):
    hidden, out = fresh()
    curve = []
    for epoch in range(epochs + 1):
        if epoch % 10 == 0:
            curve.append((round(error(hidden, out, data), 3), round(error(hidden, out, CHECK), 3)))
        gh = [[0.0] * 3 for _ in range(WIDTH)]
        go = [0.0] * (WIDTH + 1)
        for x, y, t in data:
            h, p = forward(hidden, out, x, y)
            miss = p - t
            for i in range(WIDTH):
                go[i] += miss * h[i] / len(data)
                d = miss * out[i] * (1 - h[i] ** 2) / len(data)
                gh[i][0] += d * x
                gh[i][1] += d * y
                gh[i][2] += d
            go[-1] += miss / len(data)
        for i in range(WIDTH):
            for j in range(3):
                hidden[i][j] += sign * rate * gh[i][j]
            out[i] += sign * rate * go[i]
        out[-1] += sign * rate * go[-1]
    return curve


CASES = {
    "healthy": dict(data=TRAIN),
    "rate_high": dict(data=TRAIN, rate=30.0),
    "rate_low": dict(data=TRAIN, rate=0.002),
    "labels_shuffled": dict(data=[(x, y, int(uniform() < 0.5)) for x, y, _ in TRAIN]),
    "wrong_sign": dict(data=TRAIN, sign=1),
    "too_little_data": dict(data=FEW, rate=2.0),
}
print("ln 2 =", round(math.log(2), 3))
curves = {}
for name, options in CASES.items():
    curves[name] = train(**options)
    print(name, curves[name][0], curves[name][10], curves[name][-1])
```

```output
ln 2 = 0.693
healthy (0.677, 0.774) (0.507, 0.611) (0.207, 0.333)
rate_high (0.751, 0.758) (8.98, 6.839) (8.98, 6.839)
rate_low (0.68, 0.719) (0.667, 0.701) (0.649, 0.677)
labels_shuffled (0.739, 0.833) (0.681, 0.698) (0.677, 0.702)
wrong_sign (0.66, 0.659) (11.743, 13.885) (11.743, 13.885)
too_little_data (0.62, 0.692) (0.021, 2.043) (0.004, 2.528)
```

Читаем таблицу и получаем признаки каждой болезни.

- **`healthy`, здоровая.** Обе кривые падают: с 0,677 до 0,207 и с 0,774 до 0,333. Проверочная идёт чуть выше, это нормально.
- **`rate_high`, шаг слишком большой.** Ошибка сразу выстрелила до 8,98 и там застыла. Такой скачок в первые же эпохи это главный признак. Лекарство: уменьшить шаг.
- **`rate_low`, шаг слишком маленький.** Ничего не сломано, но кривая почти лежит: 0,680 и 0,649 за 300 эпох. Обучать так можно почти вечно. Лекарство: увеличить шаг.
- **`labels_shuffled`, перепутаны ответы.** Обе кривые стоят около 0,69. Сети не на что опереться: связи между точкой и ответом нет. Если не учится даже маленький пакет, смотри на данные.
- **`wrong_sign`, перепутан знак.** Ошибка быстро растёт до 11,7: сеть идёт в гору. На начало смотреть бесполезно, там всё хорошо, а дальше кривая идёт не туда.
- **`too_little_data`, мало данных.** Обучающая ошибка падает до 0,004, а проверочная растёт до 2,528. Сеть заучила 8 примеров и на новых ошибается. Это *переобучение*. Лекарство: больше данных, ранняя остановка, ослабление весов.

**Важно.** Диагноз по кривым это гипотеза. У двух разных причин кривые могут быть похожи: если забыть обнулить градиенты, кривая тоже иногда напоминает переобучение. Проверяй гипотезу: поменяй одну вещь и посмотри, ушла ли болезнь. Меняй только по одной вещи за раз.

**Учись у тех, кто это создаёт.** Заметка Карпатого «A Recipe for Training Neural Networks» короткая и очень полезная, а в лекциях makemore 2 и 3 он сам читает такие графики. Ссылки в разделе источников.

### Исследуй и потренируйся

В тренажёре перед тобой шесть пациентов, настоящие запуски этой программы. По кривым поставь диагноз. Если не угадал, кнопка покраснеет, и можно попробовать снова. После верного ответа сравни кривые со здоровыми. Пунктир показывает `ln 2`, с которого должна начинаться ошибка.

В программе добавь седьмую болезнь: забудь обнулить `gh` и `go`, вынеся обнуление из цикла. На что похожи кривые?

### Вопрос

Ошибка на обучении падает почти до нуля, а на проверке растёт. Что это?

### Варианты

- Модель заучила мало данных и не работает на новых: это переобучение.
- Шаг обучения слишком велик, и модель скачет: надо просто его уменьшить.
- Знак в обновлении перепутан, и модель идёт по рельефу вверх, а не вниз.

### Ответ

1

### Разбор

При большом шаге или неверном знаке растёт и обучающая ошибка, а здесь она падает. Значит, обучение как таковое работает. Но то, что выучено, относится только к этим примерам.

### Границы модели

Все шесть поломок здесь в чистом виде и по одной. В настоящей работе их бывает несколько сразу. Сеть и данные у нас игрушечные, поэтому числа не переносятся на большие модели, а кривые на больших данных обычно шумнее. Шесть болезней не исчерпывают всех: есть ещё утечка проверочных данных в обучение, неверная предобработка и другие.

## English

### In plain words

Training rarely breaks loudly. More often the program runs but the model learns badly, and you have to find the cause from the error curves. It is like a doctor diagnosing from temperature and pulse. Two simple checks catch most bugs at once: the initial error should match random guessing, and the model should be able to memorise a small batch down to zero. In the lesson you diagnose six real runs.

**What to know first.** The lessons «Mini-Batches and Overfitting» (step 9) and «Classification and Softmax» (step 7): where the initial error `ln V` comes from.

**If something is unclear.** If it is unclear why the initial error equals `ln V`, go back to «Classification and Softmax»: with equal probabilities each of the `V` is `1/V`. If the two curves are unclear, reread «Mini-Batches and Overfitting». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Learn to tell from two curves what broke in training. Run two simple checks that catch most bugs at once. Diagnose six real runs. It takes about 40 minutes.

### Idea and mechanism

An ordinary program crashes on an error. A network with an error most often silently learns worse. Andrej Karpathy writes of this in his note "A Recipe for Training Neural Networks": a broken network usually gives no messages. So we need checks of our own.

**Two curves.** During training the error is computed on two sets: on the training data and on *check* data the model does not see. Both curves are drawn on one chart.

**Check 1: the starting error.** Before training you already know what it should be. For a two-class task random guessing gives a probability of 0.5, and the cross-entropy equals `−ln 0.5 = ln 2 ≈ 0.693`. If the error starts at 5, something is wrong with the data or the formula, and training further is pointless.

**Check 2: memorize a small batch.** Give the network 8 examples. A network with 33 weights should memorize them almost to zero. If it cannot, the bug is in the program itself, and big data will not help. This sounds odd, since overfitting is usually avoided, but here we test the code, not the quality.

**Step 1. Six runs.** In the program a small network decides whether a point lies inside a circle. It is the same each time, but with one fault. Create a file with `nano ~/ai-path/doctor.py`, paste the program, and run it. It computes for about twenty seconds. A line gives the name of the case, then three pairs of numbers: the error on training and on check data at the start, at epoch 100, and at the end, epoch 300. An *epoch* is one pass over all the data.

```python
import math

state = 4242


def uniform():
    global state
    state = state * 16807 % 2147483647
    return state / 2147483647


def points(count):
    result = []
    for _ in range(count):
        x, y = uniform() * 2 - 1, uniform() * 2 - 1
        result.append((x, y, 1 if x * x + y * y < 0.45 else 0))
    return result


TRAIN, CHECK = points(60), points(200)
FEW = TRAIN[:8]
WIDTH = 8


def fresh():
    return [[uniform() * 2 - 1 for _ in range(3)] for _ in range(WIDTH)], [uniform() * 2 - 1 for _ in range(WIDTH + 1)]


def forward(hidden, out, x, y):
    h = [math.tanh(n[0] * x + n[1] * y + n[2]) for n in hidden]
    z = sum(w * v for w, v in zip(out, h)) + out[-1]
    return h, 1 / (1 + math.exp(-max(min(z, 30), -30)))


def error(hidden, out, data):
    total = 0.0
    for x, y, t in data:
        p = forward(hidden, out, x, y)[1]
        p = min(max(p, 1e-9), 1 - 1e-9)
        total -= math.log(p if t else 1 - p)
    return total / len(data)


def train(data, rate=0.5, epochs=300, sign=-1):
    hidden, out = fresh()
    curve = []
    for epoch in range(epochs + 1):
        if epoch % 10 == 0:
            curve.append((round(error(hidden, out, data), 3), round(error(hidden, out, CHECK), 3)))
        gh = [[0.0] * 3 for _ in range(WIDTH)]
        go = [0.0] * (WIDTH + 1)
        for x, y, t in data:
            h, p = forward(hidden, out, x, y)
            miss = p - t
            for i in range(WIDTH):
                go[i] += miss * h[i] / len(data)
                d = miss * out[i] * (1 - h[i] ** 2) / len(data)
                gh[i][0] += d * x
                gh[i][1] += d * y
                gh[i][2] += d
            go[-1] += miss / len(data)
        for i in range(WIDTH):
            for j in range(3):
                hidden[i][j] += sign * rate * gh[i][j]
            out[i] += sign * rate * go[i]
        out[-1] += sign * rate * go[-1]
    return curve


CASES = {
    "healthy": dict(data=TRAIN),
    "rate_high": dict(data=TRAIN, rate=30.0),
    "rate_low": dict(data=TRAIN, rate=0.002),
    "labels_shuffled": dict(data=[(x, y, int(uniform() < 0.5)) for x, y, _ in TRAIN]),
    "wrong_sign": dict(data=TRAIN, sign=1),
    "too_little_data": dict(data=FEW, rate=2.0),
}
print("ln 2 =", round(math.log(2), 3))
curves = {}
for name, options in CASES.items():
    curves[name] = train(**options)
    print(name, curves[name][0], curves[name][10], curves[name][-1])
```

```output
ln 2 = 0.693
healthy (0.677, 0.774) (0.507, 0.611) (0.207, 0.333)
rate_high (0.751, 0.758) (8.98, 6.839) (8.98, 6.839)
rate_low (0.68, 0.719) (0.667, 0.701) (0.649, 0.677)
labels_shuffled (0.739, 0.833) (0.681, 0.698) (0.677, 0.702)
wrong_sign (0.66, 0.659) (11.743, 13.885) (11.743, 13.885)
too_little_data (0.62, 0.692) (0.021, 2.043) (0.004, 2.528)
```

We read the table and get the signs of each illness.

- **`healthy`.** Both curves fall: from 0.677 to 0.207 and from 0.774 to 0.333. The check curve runs a little higher, which is normal.
- **`rate_high`, the step is too large.** The error shot up to 8.98 at once and froze there. Such a jump in the first epochs is the main sign. The cure: lower the step.
- **`rate_low`, the step is too small.** Nothing is broken, but the curve almost lies flat: 0.680 and 0.649 over 300 epochs. Training this way could take nearly forever. The cure: raise the step.
- **`labels_shuffled`, the answers are mixed up.** Both curves stand near 0.69. The network has nothing to rely on: no link exists between a point and its answer. If even a small batch does not learn, look at the data.
- **`wrong_sign`, the sign is reversed.** The error quickly grows to 11.7: the network goes uphill. Looking at the start is useless, as all is well there, and later the curve goes the wrong way.
- **`too_little_data`.** The training error falls to 0.004 and the check error grows to 2.528. The network memorized 8 examples and errs on new ones. This is *overfitting*. The cure: more data, early stopping, weight decay.

**Important.** A diagnosis from curves is a hypothesis. Two different causes can give similar curves: if you forget to zero the gradients, the curve sometimes also resembles overfitting. Test your hypothesis: change one thing and see whether the illness has gone. Change only one thing at a time.

**Learn from those who build this.** Karpathy's note "A Recipe for Training Neural Networks" is short and very useful, and in the makemore 2 and 3 lectures he reads such charts himself. The links are in the sources.

### Explore and practise

In the lab you have six patients, real runs of this program. Diagnose them from the curves. If you miss, the button turns red and you can try again. After a right answer, compare the curves with healthy ones. The dashed line shows `ln 2`, where the error should start.

In the program, add a seventh illness: forget to zero `gh` and `go` by moving the zeroing out of the loop. What do the curves resemble?

### Question

The training error falls almost to zero and the check error grows. What is this?

### Options

- The model memorized too little data and fails on new data: it is overfitting.
- The training step is too large and the model jumps: just make the step smaller.
- The sign in the update is reversed, and the model goes up the relief, not down.

### Answer

1

### Explanation

With a large step or a wrong sign the training error grows too, and here it falls. So training as such works. But what was learned applies only to these examples.

### Limits

All six faults here are pure and one at a time. In real work several occur at once. Our network and data are toys, so the numbers do not carry over to large models, and curves on large data are usually noisier. Six illnesses do not exhaust them all: there is also check data leaking into training, wrong preprocessing, and others.

## Sources

- Andrej Karpathy, "A Recipe for Training Neural Networks" (2019, read 2026-11-02): training fails silently; checking the starting error; overfitting one batch; a baseline independent of the input: [the recipe](https://karpathy.github.io/2019/04/25/recipe/)
- Andrej Karpathy, the makemore lectures in Neural Networks: Zero to Hero (consulted 2026-11-02): [Zero to Hero](https://karpathy.ai/zero-to-hero.html)
- The program, the six runs, and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
