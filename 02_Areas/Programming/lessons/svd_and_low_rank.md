---
subject: programming
lesson_id: programming.svd_and_low_rank
level: advanced
languages: ru, en
source_checked: 2026-11-07
source_review_interval_days: 180
---

# SVD и малоранговые матрицы / SVD and low-rank matrices

## Русский

### Простыми словами

Любую матрицу можно разложить на простые слои: каждый слой это «направление на входе, направление на выходе и сила». Это разложение называют *сингулярным*, коротко SVD. Если сильных слоёв мало, матрицу можно почти без потерь хранить через них, а не целиком. Похоже на рецепт супа: можно записать, сколько каждого продукта в каждой ложке, а можно сказать «в основном бульон, немного моркови», и почти ничего не потерять. Именно на этой мысли стоит LoRA: изменение весов при дообучении обычно состоит из немногих сильных слоёв.

**Что нужно знать до.** Урок «Векторы и матрицы» (шаг 3): умножение матрицы на вектор и длина вектора. Урок «Дообучение и LoRA» (шаг 14) идёт сразу после этого урока и опирается на него.

**Если непонятно.** Если неясно, что делает матрица с вектором, вернись к уроку «Векторы и матрицы». Внешнее произведение `u · vᵀ` это таблица, где в клетке `i, j` стоит `uᵢ · vⱼ`; оно встречается в шаге 3 урока «Дообучение и LoRA». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Понять SVD как разложение матрицы на слои «вход, выход, сила», найти сингулярные числа степенным методом на чистом Python, сжать матрицу до ранга 1 и 2 и посчитать, сколько чисел это экономит и чего стоит. Связать это с LoRA. Нужно около 40 минут.

### Идея и механизм

**Шаг 1. Слой матрицы руками.** Возьмём столбец `u = (1; 2)` и строку `v = (3; 4)`. Их внешнее произведение `u · vᵀ` это матрица `2 × 2`: в первой строке `1 · 3 = 3` и `1 · 4 = 4`, во второй `6` и `8`. Четыре числа, а описаны двумя парами. Такая матрица называется *матрицей ранга 1*: все её строки пропорциональны. *Ранг* это наименьшее число таких слоёв, из которых матрица складывается. SVD говорит: любая матрица `M` равна сумме `σ₁ · u₁ · v₁ᵀ + σ₂ · u₂ · v₂ᵀ + …`, где `u` и `v` это направления длины 1, а `σ` это *сингулярные числа*, сила слоя, от большей к меньшей.

Создай файл `nano ~/ai-path/svd.py`, вставь и запусти. Матрица `6 × 6` здесь сделана из двух слоёв и небольшого шума, как изменение весов при дообучении.

```python
import math


def matmul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(len(b))) for j in range(len(b[0]))] for i in range(len(a))]


def transpose(a):
    return [list(row) for row in zip(*a)]


def frobenius(a):
    return math.sqrt(sum(v * v for row in a for v in row))


# a weight change made of two "directions" plus a little noise
u1, v1 = [1, 2, 0, 1, 1, 0], [2, 1, 1, 0, 0, 1]
u2, v2 = [0, 1, 1, -1, 0, 1], [1, -1, 0, 1, 1, 0]
noise = [[0.02 * ((3 * i + 5 * j) % 7 - 3) for j in range(6)] for i in range(6)]
M = [[u1[i] * v1[j] + 0.5 * u2[i] * v2[j] + noise[i][j] for j in range(6)] for i in range(6)]
print("M is 6 x 6:", 36, "numbers")
```

```output
M is 6 x 6: 36 numbers
```

**Шаг 2. Найти слои.** Самый сильный слой ищут *степенным методом*: берут любой вектор и много раз умножают его на `Mᵀ · M`, каждый раз приводя к длине 1. Вектор сам поворачивается к самому сильному направлению. Потом этот слой вычитают и ищут следующий. Допиши и запусти.

```python
def top_singular(a, steps=200):
    # power iteration on A^T A gives the strongest direction
    v = [1.0] * len(a[0])
    for _ in range(steps):
        w = [sum(a[i][j] * v[j] for j in range(len(v))) for i in range(len(a))]
        v = [sum(a[i][j] * w[i] for i in range(len(a))) for j in range(len(v))]
        norm = math.sqrt(sum(x * x for x in v))
        v = [x / norm for x in v]
    av = [sum(a[i][j] * v[j] for j in range(len(v))) for i in range(len(a))]
    sigma = math.sqrt(sum(x * x for x in av))
    return sigma, [x / sigma for x in av], v


rest = [row[:] for row in M]
parts = []
for _ in range(4):
    sigma, u, v = top_singular(rest)
    parts.append((sigma, u, v))
    rest = [[rest[i][j] - sigma * u[i] * v[j] for j in range(6)] for i in range(6)]
print("singular values:", [round(p[0], 3) for p in parts])
```

```output
singular values: [7.085, 1.862, 0.128, 0.093]
```

Два больших числа, 7,09 и 1,86, и дальше почти ноль. Это и видно: матрица в основном двухслойная, а остальное шум.

**Шаг 3. Сжатие.** Оставим только `k` сильнейших слоёв. Каждый слой это `6 + 6 = 12` чисел и одно `σ`, которое можно вложить в направление. Допиши и запусти.

```python
approx = [[0.0] * 6 for _ in range(6)]
for rank, (sigma, u, v) in enumerate(parts[:3], start=1):
    approx = [[approx[i][j] + sigma * u[i] * v[j] for j in range(6)] for i in range(6)]
    error = frobenius([[M[i][j] - approx[i][j] for j in range(6)] for i in range(6)]) / frobenius(M)
    print(f"rank {rank}: {rank * (6 + 6)} numbers instead of 36, relative error {error:.3f}")
```

```output
rank 1: 12 numbers instead of 36, relative error 0.255
rank 2: 24 numbers instead of 36, relative error 0.025
rank 3: 36 numbers instead of 36, relative error 0.018
```

Ранг 2 хранит 24 числа вместо 36 и теряет всего 2,5 %. Ранг 3 уже ничего не экономит: 36 чисел, как у целой матрицы. Эккарт и Янг в 1936 году доказали, что такое сжатие лучшее из возможных: никакая матрица ранга `k` не ближе к `M`, чем сумма её `k` сильнейших слоёв. На больших матрицах выигрыш огромный: для `4096 × 4096` слой ранга 8 хранит `8 · (4096 + 4096) = 65 536` чисел вместо 16,8 миллиона, в 256 раз меньше.

**Шаг 4. Мост к LoRA.** Hu и соавторы в 2021 году предположили, что изменение весов при дообучении имеет низкий «внутренний ранг». Поэтому LoRA не учит всю `ΔW`, а сразу записывает её как `B · A` с узким рангом `r`. Это та же мысль, что в шаге 3: сильных слоёв мало. Заметь разницу. SVD раскладывает уже готовую матрицу, а LoRA с самого начала учит матрицу в виде двух узких, не вычисляя SVD.

**Учись у тех, кто это создаёт.** Статья [LoRA](https://arxiv.org/abs/2106.09685), разделы о низком ранге. Видео 3Blue1Brown о линейной алгебре из урока «Векторы и матрицы».

### Исследуй и потренируйся

В тренажёре ниже матрица `2 × 2` превращает круг в эллипс. Стрелки это сильнейшие направления, их длины это сингулярные числа. Двигай четыре числа матрицы. В начале матрица почти поворот, и оба числа равны. Найди матрицу, у которой второе сингулярное число меньше 5 % первого: тогда её почти без потерь можно хранить как ранг 1.

### Вопрос

У матрицы `6 × 6` сингулярные числа 7,09, 1,86, 0,13 и 0,09. Почему ранг 2 почти ничего не теряет?

### Варианты

- Два первых слоя гораздо сильнее остальных, и отброшенные слои дают лишь малую долю матрицы
- Любую матрицу 6 × 6 можно точно записать двумя слоями, если правильно выбрать направления
- Ранг 2 хранит больше чисел, чем исходная матрица, поэтому он и восстанавливает её точнее

### Ответ

1

### Разбор

Ошибка сжатия складывается из отброшенных сингулярных чисел, а они здесь малы: 0,13 и 0,09 против 7,09. Не всякая матрица `6 × 6` двухслойная: у случайной все шесть чисел обычно сравнимы, и ранг 2 потерял бы много. А ранг 2 хранит 24 числа, меньше чем 36.

### Границы модели

Степенной метод здесь простой и для учёбы; настоящие программы считают SVD точнее и быстрее. Наша матрица нарочно сделана двухслойной. Есть ли низкий ранг у изменения весов в конкретной модели, проверяют опытом, как это сделали авторы LoRA.

## English

### In plain words

Any matrix can be split into simple layers: each layer is "a direction at the input, a direction at the output and a strength". This splitting is called the *singular value decomposition*, SVD for short. If there are only a few strong layers, the matrix can be stored almost without loss through them instead of in full. It is like a soup recipe: you can write how much of each ingredient is in every spoonful, or say "mostly broth, a little carrot" and lose almost nothing. LoRA rests on exactly this idea: the change of weights during fine-tuning usually consists of a few strong layers.

**What to know first.** «Vectors and Matrices» (step 3): multiplying a matrix by a vector and a vector's length. «Fine-tuning and LoRA» (step 14) comes right after this lesson and builds on it.

**If something is unclear.** If it is unclear what a matrix does to a vector, go back to «Vectors and Matrices». The outer product `u · vᵀ` is a table with `uᵢ · vⱼ` in cell `i, j`; it appears in step 3 of «Fine-tuning and LoRA». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Understand SVD as splitting a matrix into "input, output, strength" layers, find the singular values by the power method in pure Python, compress a matrix to rank 1 and 2 and count how many numbers this saves and what it costs. Link this to LoRA. It takes about 40 minutes.

### Idea and mechanism

**Step 1. A layer by hand.** Take the column `u = (1; 2)` and the row `v = (3; 4)`. Their outer product `u · vᵀ` is a `2 × 2` matrix: in the first row `1 · 3 = 3` and `1 · 4 = 4`, in the second `6` and `8`. Four numbers, described by two pairs. Such a matrix is called a *rank 1 matrix*: all its rows are proportional. The *rank* is the smallest number of such layers the matrix is made of. SVD says: any matrix `M` equals the sum `σ₁ · u₁ · v₁ᵀ + σ₂ · u₂ · v₂ᵀ + …`, where `u` and `v` are directions of length 1 and the `σ` are the *singular values*, the strength of each layer, from largest to smallest.

Create the file `nano ~/ai-path/svd.py`, paste and run it. The `6 × 6` matrix here is made of two layers and a little noise, like a weight change during fine-tuning.

```python
import math


def matmul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(len(b))) for j in range(len(b[0]))] for i in range(len(a))]


def transpose(a):
    return [list(row) for row in zip(*a)]


def frobenius(a):
    return math.sqrt(sum(v * v for row in a for v in row))


# a weight change made of two "directions" plus a little noise
u1, v1 = [1, 2, 0, 1, 1, 0], [2, 1, 1, 0, 0, 1]
u2, v2 = [0, 1, 1, -1, 0, 1], [1, -1, 0, 1, 1, 0]
noise = [[0.02 * ((3 * i + 5 * j) % 7 - 3) for j in range(6)] for i in range(6)]
M = [[u1[i] * v1[j] + 0.5 * u2[i] * v2[j] + noise[i][j] for j in range(6)] for i in range(6)]
print("M is 6 x 6:", 36, "numbers")
```

```output
M is 6 x 6: 36 numbers
```

**Step 2. Finding the layers.** The strongest layer is found by the *power method*: take any vector and multiply it many times by `Mᵀ · M`, each time scaling it back to length 1. The vector turns by itself towards the strongest direction. Then this layer is subtracted and the next is sought. Add this and run it.

```python
def top_singular(a, steps=200):
    # power iteration on A^T A gives the strongest direction
    v = [1.0] * len(a[0])
    for _ in range(steps):
        w = [sum(a[i][j] * v[j] for j in range(len(v))) for i in range(len(a))]
        v = [sum(a[i][j] * w[i] for i in range(len(a))) for j in range(len(v))]
        norm = math.sqrt(sum(x * x for x in v))
        v = [x / norm for x in v]
    av = [sum(a[i][j] * v[j] for j in range(len(v))) for i in range(len(a))]
    sigma = math.sqrt(sum(x * x for x in av))
    return sigma, [x / sigma for x in av], v


rest = [row[:] for row in M]
parts = []
for _ in range(4):
    sigma, u, v = top_singular(rest)
    parts.append((sigma, u, v))
    rest = [[rest[i][j] - sigma * u[i] * v[j] for j in range(6)] for i in range(6)]
print("singular values:", [round(p[0], 3) for p in parts])
```

```output
singular values: [7.085, 1.862, 0.128, 0.093]
```

Two large numbers, 7.09 and 1.86, and then almost zero. This is what we see: the matrix is mostly two layers, and the rest is noise.

**Step 3. Compression.** Keep only the `k` strongest layers. Each layer is `6 + 6 = 12` numbers plus one `σ`, which can be folded into a direction. Add this and run it.

```python
approx = [[0.0] * 6 for _ in range(6)]
for rank, (sigma, u, v) in enumerate(parts[:3], start=1):
    approx = [[approx[i][j] + sigma * u[i] * v[j] for j in range(6)] for i in range(6)]
    error = frobenius([[M[i][j] - approx[i][j] for j in range(6)] for i in range(6)]) / frobenius(M)
    print(f"rank {rank}: {rank * (6 + 6)} numbers instead of 36, relative error {error:.3f}")
```

```output
rank 1: 12 numbers instead of 36, relative error 0.255
rank 2: 24 numbers instead of 36, relative error 0.025
rank 3: 36 numbers instead of 36, relative error 0.018
```

Rank 2 stores 24 numbers instead of 36 and loses only 2.5 %. Rank 3 saves nothing: 36 numbers, like the whole matrix. Eckart and Young proved in 1936 that this compression is the best possible: no rank `k` matrix is closer to `M` than the sum of its `k` strongest layers. On large matrices the gain is huge: for `4096 × 4096`, a rank 8 layer stores `8 · (4096 + 4096) = 65,536` numbers instead of 16.8 million, 256 times fewer.

**Step 4. The bridge to LoRA.** Hu and co-authors hypothesised in 2021 that the change of weights during fine-tuning has a low "intrinsic rank". So LoRA does not train the whole `ΔW` but writes it from the start as `B · A` with a narrow rank `r`. This is the same idea as in step 3: strong layers are few. Note the difference. SVD splits an existing matrix, while LoRA learns the matrix from the start in the form of two narrow ones, without computing an SVD.

**Learn from the people who build this.** The [LoRA](https://arxiv.org/abs/2106.09685) paper, the sections on low rank. The 3Blue1Brown videos on linear algebra from «Vectors and Matrices».

### Explore and practise

In the lab below a `2 × 2` matrix turns a circle into an ellipse. The arrows are the strongest directions, and their lengths are the singular values. Move the four numbers of the matrix. At the start the matrix is almost a rotation, and both values are equal. Find a matrix whose second singular value is under 5 % of the first: then it can be stored almost without loss as rank 1.

### Question

A `6 × 6` matrix has singular values 7.09, 1.86, 0.13 and 0.09. Why does rank 2 lose almost nothing?

### Options

- The first two layers are far stronger than the rest, and the dropped layers make up only a small share
- Any 6 × 6 matrix can be written exactly with two layers if the directions are chosen correctly
- Rank 2 stores more numbers than the original matrix, so it rebuilds the matrix more accurately

### Answer

1

### Explanation

The compression error is made up of the dropped singular values, and they are small here: 0.13 and 0.09 against 7.09. Not every `6 × 6` matrix is two-layered: in a random one all six values are usually comparable, and rank 2 would lose a lot. And rank 2 stores 24 numbers, fewer than 36.

### Limits

The power method here is simple and for learning; real programs compute the SVD more accurately and faster. Our matrix was made two-layered on purpose. Whether the weight change of a particular model has low rank is checked by experiment, as the LoRA authors did.

## Sources

- Carl Eckart, Gale Young, "The Approximation of One Matrix by Another of Lower Rank", Psychometrika 1, 211–218 (1936), title and journal confirmed in Crossref on 2026-11-07: [doi:10.1007/BF02288367](https://doi.org/10.1007/BF02288367)
- Edward J. Hu et al., "LoRA: Low-Rank Adaptation of Large Language Models", arXiv:2106.09685 (2021): the hypothesis that weight updates have a low "intrinsic rank" and W0 + BA with r ≪ min(d, k), read on pages 2 and 4 on 2026-11-07: [arXiv:2106.09685](https://arxiv.org/abs/2106.09685)
- The matrix, the program and all numbers were written for this lesson on 2026-11-07.
