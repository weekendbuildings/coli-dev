---
subject: mathematics
lesson_id: mathematics.vectors_and_matrices
level: intermediate
languages: ru, en
source_checked: 2026-10-26
source_review_interval_days: 365
---

# Векторы и матрицы: скалярное произведение и слой нейросети / Vectors and Matrices: The Dot Product and a Neural-Network Layer

## Русский

### Простыми словами

Вектор это просто ряд чисел, например `(3, 4)`. Скалярное произведение двух векторов: перемножить числа попарно и сложить. Похоже на чек в магазине: количество каждого товара умножают на его цену и складывают в итог. Матрица это таблица чисел, а умножить её на вектор значит сделать много таких «чеков» сразу. Ровно это и считает один слой нейросети.

**Что нужно знать до.** Таблица умножения и сложение. Для программ полезен урок «Коллекции и циклы» (шаг 2).

**Если непонятно.** Если неясно, какие числа перемножать, выпиши строку матрицы над вектором и соедини пары стрелками. Если неясны списки в коде, вернись к уроку «Коллекции и циклы». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Вычислять скалярное произведение векторов и произведение матрицы на вектор, проверять, можно ли перемножить матрицы, и видеть в этих операциях то, что считает один слой нейронной сети.

### Идея и механизм

Вектор — упорядоченный набор чисел, например u = (u₁, u₂, u₃). Скалярное произведение двух векторов одинаковой длины — сумма произведений соответствующих компонент: u · v = u₁v₁ + u₂v₂ + u₃v₃. Результат — одно число. Если оно равно нулю, ненулевые векторы перпендикулярны.

Матрица — прямоугольная таблица чисел размером m × n: m строк и n столбцов. Произведение матрицы на вектор считается по строкам: каждый элемент результата — скалярное произведение одной строки матрицы на вектор. Поэтому перемножать можно, только если число столбцов матрицы равно длине вектора; в общем случае матрицу m × r можно умножить на матрицу r × n, и получится m × n.

В этом и есть связь с искусственным интеллектом. Вспомни нейрон из уроков биологии: он складывает входные сигналы с разными весами. Искусственный нейрон делает то же самое — считает скалярное произведение вектора весов на вектор входов и добавляет смещение. Слой из многих таких нейронов — это матрица весов W: слой вычисляет Wx + b, а затем применяет к каждому числу нелинейную функцию g, то есть h = g(Wx + b). Обучение сети — это подбор чисел в матрицах W и векторах b.

### Исследуй и потренируйся

Посчитай скалярное произведение (1, 2, 3) · (4, −5, 6) и проверь, перпендикулярны ли векторы (2, 1) и (−1, 2). Затем определи, можно ли умножить матрицу 2 × 3 на матрицу 3 × 4 и какого размера будет результат.

### Вопрос

Слой с матрицей весов W = [[1, 2], [0, −1]] получил вход x = (3, 4). Чему равно Wx?

### Варианты

- (11, −4): строка (1, 2) даёт 1 · 3 + 2 · 4 = 11, строка (0, −1) даёт 0 · 3 − 1 · 4 = −4.
- (11, 4): знак второй компоненты не важен.
- (3, −4): каждое число входа умножается только на число на диагонали.

### Ответ

1

### Разбор

Каждый элемент результата — скалярное произведение строки матрицы на вход. Первая строка: 1 · 3 + 2 · 4 = 3 + 8 = 11. Вторая: 0 · 3 + (−1) · 4 = −4. Получается (11, −4). Ответ (3, −4) учитывает только диагональ и теряет вклад второго входа в первый нейрон, а ответ (11, 4) теряет знак отрицательного веса — тормозящего, как ТПСП у настоящего нейрона.

### Границы модели

Модель «слой = матрица весов» описывает самые простые полносвязные сети; у сверточных и других архитектур есть своя структура, хотя внутри тоже много умножений матриц. Искусственный нейрон — сильное упрощение биологического: настоящий нейрон работает во времени, а его синапсы различаются по типу и меняются. Урок не объясняет, как сеть обучается, — это тема урока о градиентном спуске.

## English

### In plain words

A vector is just a row of numbers, for example `(3, 4)`. The dot product of two vectors: multiply the numbers in pairs and add them up. It is like a shop receipt: each item's quantity is multiplied by its price and added into the total. A matrix is a table of numbers, and multiplying it by a vector means making many such "receipts" at once. That is exactly what one layer of a neural network computes.

**What to know first.** Multiplication and addition. For the programs, «Collections and Loops» (step 2) helps.

**If something is unclear.** If it is unclear which numbers to multiply, write a matrix row above the vector and join the pairs with arrows. If lists in code are unclear, go back to «Collections and Loops». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Compute the dot product of vectors and the product of a matrix and a vector, check whether matrices can be multiplied, and recognise in these operations what one layer of a neural network computes.

### Idea and mechanism

A vector is an ordered list of numbers, for example u = (u₁, u₂, u₃). The dot product of two vectors of the same length is the sum of the products of matching components: u · v = u₁v₁ + u₂v₂ + u₃v₃. The result is a single number. If it is zero, the nonzero vectors are perpendicular.

A matrix is a rectangular table of numbers of size m × n: m rows and n columns. A matrix times a vector is computed row by row: each entry of the result is the dot product of one row of the matrix with the vector. So the product exists only if the number of columns of the matrix equals the length of the vector; in general an m × r matrix can multiply an r × n matrix, giving m × n.

This is the link to artificial intelligence. Recall the neuron from the biology lessons: it adds up incoming signals with different weights. An artificial neuron does the same: it takes the dot product of a weight vector with the input vector and adds a bias. A layer of many such neurons is a weight matrix W: the layer computes Wx + b and then applies a nonlinear function g to each number, that is h = g(Wx + b). Training a network means finding the numbers in the matrices W and vectors b.

### Explore and practise

Compute the dot product (1, 2, 3) · (4, −5, 6) and check whether the vectors (2, 1) and (−1, 2) are perpendicular. Then decide whether a 2 × 3 matrix can multiply a 3 × 4 matrix and what size the result would be.

### Question

A layer with weight matrix W = [[1, 2], [0, −1]] receives the input x = (3, 4). What is Wx?

### Options

- (11, −4): row (1, 2) gives 1 · 3 + 2 · 4 = 11, row (0, −1) gives 0 · 3 − 1 · 4 = −4.
- (11, 4): the sign of the second component does not matter.
- (3, −4): each input number is multiplied only by the number on the diagonal.

### Answer

1

### Explanation

Each entry of the result is the dot product of a matrix row with the input. First row: 1 · 3 + 2 · 4 = 3 + 8 = 11. Second: 0 · 3 + (−1) · 4 = −4. The result is (11, −4). The answer (3, −4) uses only the diagonal and loses the second input's contribution to the first neuron, and the answer (11, 4) loses the sign of the negative weight, an inhibitory one, like an IPSP in a real neuron.

### Limits

The "layer = weight matrix" model describes the simplest fully connected networks; convolutional and other architectures have their own structure, although they too contain many matrix multiplications. An artificial neuron is a strong simplification of a biological one: a real neuron works in time, and its synapses differ in type and change. The lesson does not explain how a network learns; that is the topic of the gradient descent lesson.

## Sources

- Gilbert Strang, Edwin “Jed” Herman, *Calculus Volume 3*, OpenStax, 2016, section 2.3 “The Dot Product” (consulted 2026-10-26): the dot product as the sum of products of components, and zero dot product for perpendicular vectors: [OpenStax Calculus Volume 3, 2.3](https://openstax.org/books/calculus-volume-3/pages/2-3-the-dot-product)
- Jay Abramson, *College Algebra 2e*, OpenStax, 2021, section 7.5 “Matrices and Matrix Operations” (consulted 2026-10-26): matrix dimensions m × n, and matrix products existing only when the number of columns of the first equals the number of rows of the second: [OpenStax College Algebra 2e, 7.5](https://openstax.org/books/college-algebra-2e/pages/7-5-matrices-and-matrix-operations)
- Ian Goodfellow, Yoshua Bengio, Aaron Courville, *Deep Learning*, MIT Press, 2016, chapter 6 “Deep Feedforward Networks” (consulted 2026-10-26): a network layer computing h = g(Wx + b) from a weight matrix, bias, and nonlinear activation: [Deep Learning, chapter 6](https://www.deeplearningbook.org/contents/mlp.html)
- The lesson paraphrases these sources and does not copy their text; the OpenStax pages state their own license terms: [OpenStax terms of use](https://openstax.org/terms-of-use)
