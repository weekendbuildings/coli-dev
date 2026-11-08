---
subject: programming
lesson_id: programming.from_loops_to_matrices
level: advanced
languages: ru, en
source_checked: 2026-11-08
source_review_interval_days: 180
---

# От циклов к матрицам: та же модель в сотню раз быстрее / From loops to matrices: the same model a hundred times faster

## Русский

### Простыми словами

Твоя модель училась 47 минут не потому, что она большая: в ней всего 26 тысяч весов. Медленно считает сам Python: каждое умножение он выполняет отдельной командой и каждый раз проверяет, что за числа перед ним. NumPy отдаёт всю матрицу сразу готовой программе на C, и на этом Mac она пользуется библиотекой Apple Accelerate. Та перемножает тысячи чисел за время, которое Python тратит на одно. Это как носить кирпичи по одному в руках или подвезти весь поддон погрузчиком. Математика та же, и ответ тот же до последних знаков.

**Что нужно знать до.** Урок «Своя языковая модель» (шаг 12): программа `tiny_language_model.py`. Урок «Матричные производные и якобианы» (шаг 8): для `Y = A B` градиенты равны `G Bᵀ` и `Aᵀ G`.

**Если непонятно.** Если неясно, что такое произведение матриц, вернись к уроку «Векторы и матрицы» (шаг 3). Если неясно, откуда в обратном проходе берутся транспонированные матрицы, вернись к уроку о якобианах: здесь все правила взяты оттуда без изменений.

### Цель

Измерить на своём Mac, во сколько раз NumPy перемножает матрицы быстрее циклов, переписать свою модель на матрицах так, чтобы она давала те же числа с точностью до 10⁻¹⁶, и обучить её за 22 секунды вместо 47 минут.

### Идея и механизм

**Шаг 1. Где тратится время.** Перемножим две случайные матрицы `n × n` двумя способами: циклами, как в твоей модели, и одной операцией `a @ b`. Для умножения `n × n` нужно `n³` умножений чисел. NumPy на этом Mac уже установлен. Если на другом Mac его нет, команда такая: `python3 -m pip install --user "numpy==2.0.2"`. Создай файл `nano ~/ai-path/speed.py`, вставь и запусти:

```python
import time
from operator import mul

import numpy as np


def multiply(a, b):  # как в твоей модели: строка на столбец
    columns = list(zip(*b))
    return [[sum(map(mul, row, c)) for c in columns] for row in a]


def best_time(job, repeat):
    best = float("inf")
    for _ in range(repeat):
        start = time.perf_counter()
        job()
        best = min(best, time.perf_counter() - start)
    return best


rng = np.random.default_rng(0)
print("n, multiplications, loops ms, numpy ms, times faster, same answer")
for n in (16, 32, 64, 128, 256):
    a, b = rng.standard_normal((n, n)), rng.standard_normal((n, n))
    la, lb = a.tolist(), b.tolist()
    loops = best_time(lambda: multiply(la, lb), 3)
    fast = best_time(lambda: a @ b, 200)
    same = np.allclose(np.array(multiply(la, lb)), a @ b)
    print(n, n ** 3, round(loops * 1000, 3), round(fast * 1000, 4), round(loops / fast), same)
```

```output
n, multiplications, loops ms, numpy ms, times faster, same answer
16 4096 0.128 0.001 133 True
32 32768 0.801 0.0013 620 True
64 262144 5.736 0.003 1912 True
128 2097152 42.816 0.0142 3005 True
256 16777216 326.877 0.0976 3348 True
```

При `n = 256` матрицы быстрее примерно в 3300 раз. Циклы тратят около 19,5 наносекунды на одно умножение: 327 мс на 16,8 миллиона умножений. Accelerate делает примерно 170 миллиардов умножений в секунду. При `n = 16` выигрыш всего в 133 раза. Здесь важна другая цена: сам вызов NumPy стоит около микросекунды, что бы ни считалось внутри. Маленькую матрицу программа успевает перемножить быстрее, чем длится этот вызов. Малые времена шумят: в соседнем запуске на этом же Mac строка `n = 16` дала 0,386 мс для циклов. Сравнивай порядок величины, а не последнюю цифру.

**Шаг 2. Та же строка, только матрицами.** Каждый цикл модели становится одной операцией над целой матрицей. Веса внимания для всех мест сразу и маска будущего:

```python
scores = np.where(mask, -np.inf, q @ k.T / root_part)  # mask: True над диагональю, будущее закрыто
weights = np.exp(scores - scores.max(axis=1, keepdims=True))
weights /= weights.sum(axis=1, keepdims=True)
```

Обратный проход берёт правила из урока о якобианах как есть. Для `Y = X W` градиент веса равен `Xᵀ G`, а градиент входа `G Wᵀ`. В программе это две строки: `grads[i] += x.T @ g` и `g = g @ w.T`. Градиент через softmax внимания, который в уроке о внимании занимал вложенный цикл, тоже становится одной строкой: `weights * (g_w − (g_w * weights).sum(axis=1, keepdims=True))`.

**Шаг 3. Та же модель.** Вся программа лежит в `01_Projects/tiny_language_model_numpy.py`. Её начальные веса, случайные куски текста и шаги Adam совпадают с версией на чистом Python, потому что она пользуется тем же генератором случайных чисел в том же порядке. Запусти её из корня репозитория:

```bash
cd ~/Desktop/"coli-dev 4"/coli-dev && python3 01_Projects/tiny_language_model_numpy.py
```

```output
characters 720706 alphabet 159
random 5.069 pairs 2.652
weights 27584
start 5.173
500 train 2.775 held 2.761 seconds 1.8
1000 train 2.553 held 2.637 seconds 3.7
1500 train 2.358 held 2.529 seconds 5.6
2000 train 2.31 held 2.46 seconds 7.4
2500 train 2.444 held 2.429 seconds 9.2
3000 train 2.218 held 2.408 seconds 11.1
3500 train 2.146 held 2.384 seconds 12.9
4000 train 2.156 held 2.356 seconds 14.7
4500 train 2.181 held 2.333 seconds 16.5
5000 train 1.988 held 2.277 seconds 18.3
5500 train 2.044 held 2.26 seconds 20.2
6000 train 1.737 held 2.247 seconds 22.0
best 2.247 at step 6000
```

Те же 6000 шагов, что в уроке «Своя языковая модель», заняли 22 секунды. Там было 47,2 минуты, то есть разница примерно в 130 раз. Модель снова обошла счётчик пар: 2,247 против 2,652 на том же незнакомом тексте.

**Шаг 4. Та же арифметика.** Проверка курса загружает обе программы, даёт им один кусок текста и сравнивает. Выходы модели расходятся не больше чем на 4 · 10⁻¹⁶, градиенты всех весов не больше чем на 3 · 10⁻¹⁶, веса после трёх шагов Adam не больше чем на 1,1 · 10⁻¹⁶. Это ошибки округления: числа с плавающей точкой складываются в другом порядке. Модель та же самая, изменилась только скорость счёта.

**Почему не в 3000 раз.** Матрицы модели маленькие, `32 × 32` и меньше. Кроме того, программа по-прежнему обходит в цикле Python 8 кусков пакета и 2 головы внимания. Каждая операция NumPy стоит около микросекунды на вызов, а за один шаг их сотни. Отсюда следующий выигрыш: собрать 8 кусков в одну трёхмерную матрицу и считать их одной операцией.

**Честное сравнение ошибок.** В прошлом уроке опубликована ошибка 2,127, а здесь получилось 2,247. Сравнивать эти два числа напрямую нельзя: с тех пор курс вырос с 382 107 до 720 706 знаков, в алфавите теперь 159 символов вместо 144, и незнакомый текст, последние 10 %, стал другим. Честная линейка — счётчик пар на том же тексте. Модель обходит его в обоих случаях.

### Исследуй и потренируйся

В тренажёре двигай размер матрицы и смотри, куда уходит время NumPy: на вызов или на сам счёт. Точки на графике — измерения на этом Mac, линии — простая модель из двух чисел: 19,5 нс на умножение в цикле, 1 мкс на вызов NumPy и 170 миллиардов умножений в секунду внутри.

Попробуй сам:

1. Собери 8 кусков пакета в массив формы `(8, 32)` для индексов и `(8, 32, 32)` для векторов, а внимание посчитай сразу для всего пакета: `q @ k.transpose(0, 2, 1)`. Сравни с результатом обычной программы: числа должны совпасть до 10⁻¹², а время уменьшиться. Запиши, во сколько раз.
2. Поставь `SIZE` 64 и `STEPS` 20000. Сначала запиши прогноз: сколько секунд займёт обучение и какой станет ошибка на незнакомом тексте. Затем запусти. На чистом Python такой опыт занял бы часы.
3. Следующий шаг — PyTorch. Там те же матрицы, плюс автоматический обратный проход, как в уроке о механизме градиентов, и видеокарта M1 через бэкенд MPS. Ставить его стоит, когда секунд NumPy станет мало.

### Вопрос

Почему обучение своей модели ускорилось примерно в 130 раз, а умножение матриц `256 × 256` больше чем в 3000 раз?

### Варианты

- Матрицы модели маленькие, по 32 строки и меньше: время уходит на вызовы NumPy и на циклы Python по кускам и головам.
- NumPy считает с меньшей точностью, и обучению приходится делать больше шагов, чтобы дойти до той же ошибки.
- Обратный проход нельзя записать матрицами, поэтому половина программы так и осталась на циклах Python.

### Ответ

1

### Разбор

Внутри одной большой операции Accelerate почти не тратит время впустую, поэтому при `n = 256` выигрыш огромный. В модели операций много и все они маленькие: у каждой есть цена вызова около микросекунды, а 8 кусков и 2 головы обходятся циклом Python. Точность здесь та же, двойная, и числа совпадают до 10⁻¹⁶. Обратный проход тоже записан матрицами, по правилам из урока о якобианах.

### Границы модели

Все времена измерены на этом Mac с M1 8 ноября 2026 года, системным `python3` 3.9.6 и NumPy 2.0.2. Команда `numpy.show_config()` называет библиотекой BLAS Accelerate. На другом компьютере числа будут другими, а малые времена меняются даже между соседними запусками. Модель «вызов плюс счёт» в тренажёре описывает измерения грубо, это не закон. Программа считает на одном ядре процессора; видеокарту M1 используют PyTorch через MPS или MLX, в этом уроке их нет. Ошибки моделей сравниваются только со счётчиком пар на том же тексте.

## English

### In plain words

Your model took 47 minutes to train not because it is big: it has only 26 thousand weights. What is slow is Python itself: it runs every multiplication as a separate command and checks each time what kind of numbers it has. NumPy hands the whole matrix to a ready-made program in C, which on this Mac uses Apple's Accelerate library. It multiplies thousands of numbers in the time Python spends on one. It is like carrying bricks one at a time by hand versus bringing the whole pallet on a forklift. The mathematics is the same, and so is the answer down to the last digits.

**What to know first.** The lesson "Your own language model" (step 12): the program `tiny_language_model.py`. The lesson "Matrix derivatives and Jacobians" (step 8): for `Y = A B` the gradients are `G Bᵀ` and `Aᵀ G`.

**If something is unclear.** If matrix multiplication is unclear, go back to "Vectors and matrices" (step 3). If it is unclear where the transposed matrices in the backward pass come from, go back to the Jacobians lesson: every rule here is taken from there unchanged.

### Goal

Measure on your own Mac how many times faster NumPy multiplies matrices than loops do, rewrite your model with matrices so that it gives the same numbers to within 10⁻¹⁶, and train it in 22 seconds instead of 47 minutes.

### Idea and mechanism

**Step 1. Where the time goes.** Multiply two random `n × n` matrices in two ways: with loops, as in your model, and with one operation `a @ b`. Multiplying `n × n` matrices takes `n³` multiplications of numbers. NumPy is already installed on this Mac. If another Mac lacks it, the command is `python3 -m pip install --user "numpy==2.0.2"`. Create the file `nano ~/ai-path/speed.py`, paste and run:

```python
import time
from operator import mul

import numpy as np


def multiply(a, b):  # as in your model: row by column
    columns = list(zip(*b))
    return [[sum(map(mul, row, c)) for c in columns] for row in a]


def best_time(job, repeat):
    best = float("inf")
    for _ in range(repeat):
        start = time.perf_counter()
        job()
        best = min(best, time.perf_counter() - start)
    return best


rng = np.random.default_rng(0)
print("n, multiplications, loops ms, numpy ms, times faster, same answer")
for n in (16, 32, 64, 128, 256):
    a, b = rng.standard_normal((n, n)), rng.standard_normal((n, n))
    la, lb = a.tolist(), b.tolist()
    loops = best_time(lambda: multiply(la, lb), 3)
    fast = best_time(lambda: a @ b, 200)
    same = np.allclose(np.array(multiply(la, lb)), a @ b)
    print(n, n ** 3, round(loops * 1000, 3), round(fast * 1000, 4), round(loops / fast), same)
```

```output
n, multiplications, loops ms, numpy ms, times faster, same answer
16 4096 0.128 0.001 133 True
32 32768 0.801 0.0013 620 True
64 262144 5.736 0.003 1912 True
128 2097152 42.816 0.0142 3005 True
256 16777216 326.877 0.0976 3348 True
```

At `n = 256` matrices are about 3300 times faster. Loops spend about 19.5 nanoseconds per multiplication: 327 ms for 16.8 million multiplications. Accelerate does about 170 billion multiplications per second. At `n = 16` the gain is only 133 times. Here another cost matters: the NumPy call itself costs about a microsecond, whatever it computes inside. A small matrix gets multiplied faster than that call takes. Small times are noisy: in the neighbouring run on the same Mac the `n = 16` row gave 0.386 ms for the loops. Compare orders of magnitude, not the last digit.

**Step 2. The same line, with matrices.** Every loop of the model becomes one operation on a whole matrix. The attention weights for all places at once, with the future mask:

```python
scores = np.where(mask, -np.inf, q @ k.T / root_part)  # mask: True above the diagonal, the future is closed
weights = np.exp(scores - scores.max(axis=1, keepdims=True))
weights /= weights.sum(axis=1, keepdims=True)
```

The backward pass takes the rules from the Jacobians lesson as they are. For `Y = X W` the weight gradient is `Xᵀ G` and the input gradient is `G Wᵀ`. In the program these are two lines: `grads[i] += x.T @ g` and `g = g @ w.T`. The gradient through the attention softmax, which took a nested loop in the attention lesson, also becomes one line: `weights * (g_w − (g_w * weights).sum(axis=1, keepdims=True))`.

**Step 3. The same model.** The whole program is in `01_Projects/tiny_language_model_numpy.py`. Its starting weights, random text pieces and Adam steps match the plain Python version, because it uses the same random number generator in the same order. Run it from the repository root:

```bash
cd ~/Desktop/"coli-dev 4"/coli-dev && python3 01_Projects/tiny_language_model_numpy.py
```

```output
characters 720706 alphabet 159
random 5.069 pairs 2.652
weights 27584
start 5.173
500 train 2.775 held 2.761 seconds 1.8
1000 train 2.553 held 2.637 seconds 3.7
1500 train 2.358 held 2.529 seconds 5.6
2000 train 2.31 held 2.46 seconds 7.4
2500 train 2.444 held 2.429 seconds 9.2
3000 train 2.218 held 2.408 seconds 11.1
3500 train 2.146 held 2.384 seconds 12.9
4000 train 2.156 held 2.356 seconds 14.7
4500 train 2.181 held 2.333 seconds 16.5
5000 train 1.988 held 2.277 seconds 18.3
5500 train 2.044 held 2.26 seconds 20.2
6000 train 1.737 held 2.247 seconds 22.0
best 2.247 at step 6000
```

The same 6000 steps as in "Your own language model" took 22 seconds. There it was 47.2 minutes, so the difference is about 130 times. The model again beat the pair counter: 2.247 against 2.652 on the same unseen text.

**Step 4. The same arithmetic.** The course check loads both programs, gives them the same text piece and compares. The model outputs differ by at most 4 · 10⁻¹⁶, the gradients of all weights by at most 3 · 10⁻¹⁶, and the weights after three Adam steps by at most 1.1 · 10⁻¹⁶. These are rounding errors: floating-point numbers are added in a different order. The model is the same; only the speed of the arithmetic changed.

**Why not 3000 times.** The model's matrices are small, `32 × 32` and smaller. Besides, the program still loops in Python over the 8 pieces of a batch and the 2 attention heads. Every NumPy operation costs about a microsecond per call, and one step has hundreds of them. That points to the next gain: put the 8 pieces into one three-dimensional array and compute them in one operation.

**A fair comparison of errors.** The previous lesson published an error of 2.127, and here it is 2.247. These two numbers cannot be compared directly: since then the course grew from 382,107 to 720,706 characters, the alphabet now has 159 symbols instead of 144, and the unseen text, the last 10%, is different. The fair yardstick is the pair counter on the same text. The model beats it in both cases.

### Explore and practise

In the lab, move the matrix size and watch where NumPy's time goes: into the call or into the arithmetic itself. The dots on the chart are measurements on this Mac; the lines are a simple model with two numbers: 19.5 ns per multiplication in a loop, 1 µs per NumPy call and 170 billion multiplications per second inside.

Try it yourself:

1. Put the 8 pieces of a batch into an array of shape `(8, 32)` for the indices and `(8, 32, 32)` for the vectors, and compute attention for the whole batch at once: `q @ k.transpose(0, 2, 1)`. Compare with the result of the usual program: the numbers should match to 10⁻¹², and the time should drop. Write down by how much.
2. Set `SIZE` to 64 and `STEPS` to 20000. First write a prediction: how many seconds the training will take and what the unseen-text error will be. Then run it. In plain Python this experiment would take hours.
3. The next step is PyTorch. It has the same matrices, plus an automatic backward pass, as in the autograd lesson, and the M1 graphics processor through the MPS backend. It is worth installing when NumPy's seconds are no longer enough.

### Question

Why did training your model get about 130 times faster, while multiplying `256 × 256` matrices got more than 3000 times faster?

### Options

- The model's matrices are small, 32 rows or fewer: time goes into NumPy calls and Python loops over pieces and heads.
- NumPy computes with lower precision, so training needs many more steps to reach the same error level.
- The backward pass cannot be written with matrices, so about half of the program stayed on Python loops.

### Answer

1

### Explanation

Inside one big operation Accelerate wastes almost no time, so at `n = 256` the gain is huge. The model has many operations, all of them small: each has a call cost of about a microsecond, and the 8 pieces and 2 heads are walked by a Python loop. The precision here is the same, double, and the numbers match to 10⁻¹⁶. The backward pass is written with matrices too, by the rules from the Jacobians lesson.

### Limits

All times were measured on this M1 Mac on 8 November 2026 with the system `python3` 3.9.6 and NumPy 2.0.2. The command `numpy.show_config()` names Accelerate as the BLAS library. On another computer the numbers will differ, and small times change even between neighbouring runs. The lab's "call plus arithmetic" model describes the measurements roughly; it is not a law. The program uses one processor core; the M1 graphics processor is used by PyTorch through MPS or by MLX, and neither is in this lesson. The models' errors are compared only with the pair counter on the same text.

## Sources

- Charles R. Harris et al., "Array programming with NumPy", Nature 585, 357–362 (2020), title, journal, volume and pages confirmed in Crossref on 2026-11-08: [doi:10.1038/s41586-020-2649-2](https://doi.org/10.1038/s41586-020-2649-2).
- NumPy documentation, `numpy.matmul`, "Matrix product of two arrays", page opened on 2026-11-08: [numpy.org](https://numpy.org/doc/stable/reference/generated/numpy.matmul.html).
- NumPy documentation, broadcasting, page opened on 2026-11-08: [numpy.org](https://numpy.org/doc/stable/user/basics.broadcasting.html).
- PyTorch documentation, MPS backend, page opened on 2026-11-08: [docs.pytorch.org](https://docs.pytorch.org/docs/stable/notes/mps.html).
- Andrej Karpathy, Neural Networks: Zero to Hero, where the same steps go on to PyTorch: [karpathy.ai](https://karpathy.ai/zero-to-hero.html).
- The programs, the measurements on this Mac and the training log `02_Areas/Programming/resources/tiny_language_model_numpy_log.txt` were made for this lesson on 2026-11-08.
