---
subject: programming
lesson_id: programming.gradient_descent_and_learning_rate
level: intermediate
languages: ru, en
source_checked: 2026-10-24
source_review_interval_days: 365
---

# Градиентный спуск и шаг обучения / Gradient Descent and the Learning Rate

## Русский

### Простыми словами

Градиентный спуск это способ уменьшать ошибку маленькими шагами: смотришь, куда ошибка растёт, и шагаешь в обратную сторону. Шаг обучения решает, насколько далеко шагать. Как спуск с горы в темноте: слишком мелкие шаги, и ты идёшь до утра; слишком большие, и ты перепрыгиваешь долину и взлетаешь на другой склон. Так учится почти каждая нейросеть, включая твою.

**Что нужно знать до.** Уроки «Производная как мгновенная скорость изменения» и «Частные производные и градиент» (шаг 4).

**Если непонятно.** Если неясно, почему ошибка растёт при большом шаге, нарисуй параболу и сделай на ней два шага руками: маленький и большой. Если неясен градиент, вернись к уроку «Частные производные и градиент». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Объяснить, как градиентный спуск уменьшает ошибку модели, и предсказать, что произойдёт при слишком маленьком и слишком большом шаге обучения.

### Идея и механизм

У модели машинного обучения есть параметры. Обучение — это поиск таких значений, при которых ошибка на обучающих данных минимальна. В простейшей модели `y = w·x` один параметр `w`, а ошибку считают как среднее квадратов отклонений (MSE).

Градиент показывает, в какую сторону ошибка растёт быстрее всего. Градиентный спуск повторяет один шаг: посчитать ошибку и градиент для текущего `w`, немного сдвинуть `w` в противоположную сторону, туда, где ошибка уменьшается, и повторить. Величину сдвига задаёт шаг обучения `η`: `w ← w − η · градиент`. Когда новые итерации почти не уменьшают ошибку, говорят, что обучение сошлось.

Шаг обучения — гиперпараметр: его выбирает человек, а не модель. Слишком маленький шаг требует очень многих итераций. Слишком большой перескакивает минимум: ошибка колеблется или растёт с каждой итерацией.

Тот же опыт на чистом Python, 20 итераций из `w = 0`:

```python
xs = [1, 2, 3, 4]
ys = [2.1, 3.9, 6.2, 7.8]


def loss(w):
    return sum((w * x - y) ** 2 for x, y in zip(xs, ys)) / len(xs)


def gradient(w):
    return 2 * sum((w * x - y) * x for x, y in zip(xs, ys)) / len(xs)


for rate in (0.01, 0.05, 0.12, 0.15):
    w = 0.0
    for step in range(20):
        w -= rate * gradient(w)
    print(rate, round(w, 3), round(loss(w), 3))
```

Точки придуманы для урока. Минимум ошибки для них — при `w ≈ 1,99`. При `η = 0,01` модель за 20 итераций доходит только до `w ≈ 1,913`. При `η = 0,05` она уже практически в минимуме: `w ≈ 1,99`, ошибка ≈ 0,024. При `η = 0,12` значение `w` перескакивает минимум то в одну, то в другую сторону, но приближается к нему: `w ≈ 1,967`. При `η = 0,15` каждый шаг уводит всё дальше, и ошибка вырастает примерно до 223 444.

### Исследуй и потренируйся

В тренажёре выбери шаг `η` и двигай число итераций от 0 до 20. Сначала предскажи, при каком шаге ошибка будет расти. Сравни, сколько итераций нужно при `η = 0,01` и при `η = 0,05`, и посмотри, как при `η = 0,12` значение `w` колеблется вокруг минимума.

### Вопрос

При `η = 0,15` ошибка растёт с каждой итерацией. Что это значит?

### Варианты

- Шаг обучения слишком большой: каждое обновление перескакивает минимум всё дальше.
- Данных слишком мало, поэтому нужно просто сделать больше итераций с тем же шагом.
- Модель уже нашла минимум, а ошибка растёт из-за случайного шума в данных.

### Ответ

1

### Разбор

Для этих данных каждое обновление умножает отклонение `w` от минимума на `(1 − 15η)`. При `η = 0,15` множитель равен −1,25: отклонение меняет знак и растёт на четверть за итерацию, поэтому новые итерации только ухудшают результат. Шаг нужно уменьшить: при `η = 0,05` множитель равен 0,25, и отклонение быстро исчезает. Шум в данных не отменяет того, что при слишком большом шаге процесс расходится.

### Границы модели

Одна переменная, четыре придуманные точки и модель без свободного члена: у такой задачи один минимум, и его можно найти формулой. Настоящие модели обучают тысячи или миллионы параметров, форма ошибки бывает сложной, а шаг подбирают по ошибке на валидационных данных. Точные числа верны только для этих данных и начального `w = 0`.

## English

### In plain words

Gradient descent is a way to lower the error in small steps: you see which way the error grows and step the opposite way. The learning rate decides how far to step. Like walking down a mountain in the dark: steps too small and you walk till morning; steps too big and you jump over the valley and up the other side. Almost every neural network learns this way, yours included.

**What to know first.** The lessons «The Derivative as an Instantaneous Rate of Change» and «Partial Derivatives and the Gradient» (step 4).

**If something is unclear.** If it is unclear why the error grows with a big step, draw a parabola and take two steps on it by hand: a small one and a big one. If the gradient is unclear, go back to «Partial Derivatives and the Gradient». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Explain how gradient descent lowers a model's error, and predict what happens when the learning rate is too small or too large.

### Idea and mechanism

A machine learning model has parameters. Training means finding the values that minimize the error on the training data. The simplest model, `y = w·x`, has one parameter `w`, and the error is measured as the mean of squared deviations (MSE).

The gradient points in the direction where the error grows fastest. Gradient descent repeats one step: compute the error and gradient for the current `w`, move `w` a little in the opposite direction, where the error decreases, and repeat. The size of the move is set by the learning rate `η`: `w ← w − η · gradient`. When further iterations barely lower the error, training is said to have converged.

The learning rate is a hyperparameter: a person chooses it, not the model. Too small a rate needs a great many iterations. Too large a rate overshoots the minimum: the error bounces around or grows with every iteration.

The same experiment in plain Python, 20 iterations from `w = 0`:

```python
xs = [1, 2, 3, 4]
ys = [2.1, 3.9, 6.2, 7.8]


def loss(w):
    return sum((w * x - y) ** 2 for x, y in zip(xs, ys)) / len(xs)


def gradient(w):
    return 2 * sum((w * x - y) * x for x, y in zip(xs, ys)) / len(xs)


for rate in (0.01, 0.05, 0.12, 0.15):
    w = 0.0
    for step in range(20):
        w -= rate * gradient(w)
    print(rate, round(w, 3), round(loss(w), 3))
```

The points are invented for the lesson. Their error is lowest at `w ≈ 1.99`. With `η = 0.01` the model only reaches `w ≈ 1.913` in 20 iterations. With `η = 0.05` it is practically at the minimum: `w ≈ 1.99`, error ≈ 0.024. With `η = 0.12` the value of `w` overshoots the minimum on alternate sides but still approaches it: `w ≈ 1.967`. With `η = 0.15` every step moves further away, and the error grows to about 223,444.

### Explore and practise

In the lab, choose a rate `η` and move the number of iterations from 0 to 20. First predict which rate makes the error grow. Compare how many iterations `η = 0.01` and `η = 0.05` need, and watch how `w` oscillates around the minimum at `η = 0.12`.

### Question

With `η = 0.15` the error grows every iteration. What does that mean?

### Options

- The learning rate is too large: each update overshoots the minimum by more, so training diverges.
- There are too few data points, so you just need more iterations at the same rate.
- The model has already found the minimum, and the error grows because of random noise in the data.

### Answer

1

### Explanation

For these data each update multiplies the distance of `w` from the minimum by `(1 − 15η)`. At `η = 0.15` the factor is −1.25: the distance changes sign and grows by a quarter per iteration, so more iterations only make things worse. The rate has to be lowered: at `η = 0.05` the factor is 0.25, and the distance quickly disappears. Noise in the data does not change the fact that too large a rate makes the process diverge.

### Limits

One variable, four invented points, and no intercept: such a problem has a single minimum that a formula can find directly. Real models train thousands or millions of parameters, the error surface can be complex, and the rate is tuned by the error on validation data. The exact numbers hold only for these data and the starting value `w = 0`.

## Sources

- Google for Developers, *Machine Learning Crash Course*, “Linear regression: Gradient descent” (consulted 2026-10-24; page updated 2026-02-03): gradient descent iteratively finds parameter values with the lowest loss by moving them a small amount in the direction that reduces loss, until more iterations stop reducing it: <https://developers.google.com/machine-learning/crash-course/linear-regression/gradient-descent>
- Google for Developers, *Machine Learning Crash Course*, “Linear regression: Hyperparameters” (consulted 2026-10-24; page updated 2025-12-03): too small a learning rate takes too many iterations to converge; too large a rate never converges because the loss bounces around: <https://developers.google.com/machine-learning/crash-course/linear-regression/hyperparameters>
- Google publishes the course text under CC BY 4.0 and its code samples under Apache 2.0. The lesson paraphrases the course; the practice data are invented for this lesson.
