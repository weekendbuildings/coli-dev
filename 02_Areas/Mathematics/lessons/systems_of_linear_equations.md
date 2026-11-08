---
subject: mathematics
lesson_id: mathematics.systems_of_linear_equations
level: intermediate
languages: ru, en
source_checked: 2026-10-26
source_review_interval_days: 365
---

# Системы линейных уравнений: одна точка, нет пересечения или одна прямая / Linear Systems: One Intersection, None, or the Same Line

## Русский

### Цель

Определить, сколько решений имеет система двух линейных уравнений, и объяснить результат сложением уравнений.

### Идея и механизм

Одно уравнение с двумя неизвестными, например `x + y = 10`, имеет бесконечно много решений: `(1, 9)`, `(4, 6)`, `(2,5; 7,5)` и так далее. Все они лежат на одной прямой. Второе уравнение добавляет ещё одно условие, и решением **системы** называется пара `(x, y)`, которая удовлетворяет обоим уравнениям одновременно, — общая точка двух прямых. Две прямые на плоскости могут пересечься в одной точке, не пересечься (параллельны) или совпасть.

Метод сложения: умножаем уравнения на подходящие числа и складываем так, чтобы одна переменная исчезла. Это законно, потому что к равным величинам прибавляются равные.

**Пример.** Возьмём `2x + y = 11` и `x − y = 1`. Коэффициенты при `y` противоположны, поэтому складываем левые и правые части: `3x = 12`, значит `x = 4`. Подстановка во второе уравнение даёт `4 − y = 1`, то есть `y = 3`. Проверка в первом: `2 · 4 + 3 = 11`. Пара `(4, 3)` подходит сразу к обоим уравнениям.

Если после исключения переменной получается `0 = число, не равное нулю`, система **несовместна**: прямые параллельны, общих точек нет. Пример: `x + y = 3` и `x + y = 5` — одна и та же сумма не может быть равна и 3, и 5. Если получается `0 = 0`, второе уравнение не добавило нового условия: прямые совпадают, и решений бесконечно много (такую систему называют **зависимой**).

**Типичная ошибка.** Найти одну координату и остановиться, или проверить пару только в одном уравнении. Ответ системы — это пара, и проверять её нужно в обоих исходных уравнениях.

**Зачем это дальше.** Системы уравнений — ядро линейной алгебры, следующей темы маршрута: в матричной записи система имеет вид `Ax = b`, а в Python её решают, например, функцией `numpy.linalg.solve`. Вопрос «одно решение, ни одного или бесконечно много» там превращается в вопрос о свойствах матрицы `A`.

### Исследуй и потренируйся

Выбери систему в тренажёре и сначала предскажи число решений. Затем сравни коэффициенты: для первого примера сложение убирает `y`; для параллельных прямых оно приводит к противоречию; для совпадающих прямых — к тождеству. Не считай одну найденную координату готовым ответом: подставь пару в оба исходных уравнения.

### Вопрос

Что означает результат `0 = 0` после сложения кратных уравнений системы?

### Варианты

- У системы нет решений: уравнения противоречат друг другу.
- У системы одна точка пересечения, и её даёт равенство 0 = 0.
- Уравнения задают одну прямую, поэтому решений бесконечно много.

### Ответ

3

### Разбор

Тождество `0 = 0` верно при любых `x` и `y`: исключение не дало ни противоречия, ни нового ограничения. Значит, одно уравнение получается из другого умножением на число, оба описывают одну и ту же прямую, и каждая её точка — решение. «Нет решений» соответствовало бы ложному равенству вроде `0 = 2`, а одна точка — равенству вида `x = число`.

### Границы модели

Тренажёр показывает три тщательно подобранных примера и не разбирает автоматически произвольный ввод, дробные коэффициенты, системы с тремя переменными или ошибки округления на графике. Для каждой новой задачи выпиши обе исходные строки, выполни допустимую операцию над ними и проверь найденную пару в исходной системе.

## English

### Goal

Classify a two-equation linear system and explain its result using elimination by addition.

### Idea and mechanism

A single equation in two unknowns, such as `x + y = 10`, has infinitely many solutions: `(1, 9)`, `(4, 6)`, `(2.5, 7.5)`, and so on. They all lie on one line. A second equation adds another condition, and a solution of the **system** is a pair `(x, y)` that satisfies both equations at once: a common point of two lines. Two lines in a plane can intersect once, never intersect (parallel), or coincide.

Elimination by addition: multiply the equations by suitable numbers and add them so that one variable disappears. This is valid because adding equal amounts to equal amounts keeps them equal.

**Example.** Take `2x + y = 11` and `x − y = 1`. The `y` coefficients are opposites, so add the left sides and the right sides: `3x = 12`, so `x = 4`. Substituting into the second equation gives `4 − y = 1`, so `y = 3`. Check the first: `2 · 4 + 3 = 11`. The pair `(4, 3)` satisfies both equations.

If elimination gives `0 = a nonzero number`, the system is **inconsistent**: the lines are parallel and have no common point. Example: `x + y = 3` and `x + y = 5`; the same sum cannot equal both 3 and 5. If it gives `0 = 0`, the second equation added no new condition: the lines coincide and there are infinitely many solutions (a **dependent** system).

**Common mistake.** Finding one coordinate and stopping, or checking the pair in only one equation. The answer to a system is a pair, and it must be checked in both original equations.

**Why it matters next.** Systems of equations are the core of linear algebra, the next topic on the route: in matrix form a system reads `Ax = b`, and in Python it can be solved with `numpy.linalg.solve`. The question “one solution, none, or infinitely many” there becomes a question about properties of the matrix `A`.

### Explore and practise

Choose a system in the trainer and predict its number of solutions first. Then compare the coefficients: adding removes `y` in the first example, produces a contradiction for parallel lines, and produces an identity for coincident lines. Do not stop after finding one coordinate; substitute the ordered pair into both original equations.

### Question

What does `0 = 0` after adding multiples of the equations tell you?

### Options

- The system has no solution: the two equations contradict each other.
- The system has one intersection, and 0 = 0 gives that point.
- Both equations give the same line, so there are infinitely many solutions.

### Answer

3

### Explanation

The identity `0 = 0` holds for every `x` and `y`: elimination produced neither a contradiction nor a new restriction. So one equation is a multiple of the other, both describe the same line, and every point on it is a solution. “No solution” would correspond to a false statement such as `0 = 2`, and one intersection to an equation of the form `x = number`.

### Limits

The trainer shows three selected examples. It does not solve arbitrary learner input, fractional coefficients, three-variable systems, or graph-rounding errors. For a new problem, write both original rows, apply a valid row operation, and check any proposed pair in the original system.

## Sources

- OpenStax, *College Algebra 2e*, [§7.1 Systems of Linear Equations: Two Variables](https://openstax.org/books/college-algebra-2e/pages/7-1-systems-of-linear-equations-two-variables) — independent, inconsistent, and dependent systems; elimination; a false statement or the identity `0 = 0`.
- NumPy documentation, [`numpy.linalg.solve`](https://numpy.org/doc/stable/reference/generated/numpy.linalg.solve.html) — solving a linear matrix equation `ax = b`.

OpenStax textbooks use CC BY-NC-SA 4.0. This explanation is original and does not copy the textbook; the source monitor keeps this page metadata-only and does not cache it for RAG.
