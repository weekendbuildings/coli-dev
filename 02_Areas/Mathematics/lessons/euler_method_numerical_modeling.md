---
subject: mathematics
lesson_id: mathematics.euler_method_numerical_modeling
level: advanced
languages: ru, en
source_checked: 2026-10-31
source_review_interval_days: 365
---

# Численное моделирование: метод Эйлера / Numerical Modelling: Euler's Method

## Русский

### Цель

Приближённо решать дифференциальное уравнение методом Эйлера, понимать, откуда берётся ошибка и как её уменьшить, и видеть в этом основу компьютерных моделей живых систем.

### Идея и механизм

Многие законы природы записываются дифференциальными уравнениями: они говорят не что такое величина, а как быстро она меняется. Рост популяции dN/dt = r · N, логистический рост, реакции с ферментами — всё это такие уравнения. Точное решение есть далеко не всегда, а компьютер может шагать по времени.

Метод Эйлера делает именно это. Пусть известно начальное значение y₀ в момент t₀ и правило изменения y′ = f(t, y). Выберем маленький шаг h и будем считать: tₙ = t₀ + n·h, yₙ = yₙ₋₁ + h · f(tₙ₋₁, yₙ₋₁). На каждом шаге мы идём вдоль касательной — так, будто скорость изменения на отрезке постоянна. Получается ломаная, приближающая настоящую кривую решения.

Поскольку скорость на самом деле меняется внутри шага, накапливается ошибка. Её уменьшают, уменьшая шаг: вычислений больше, зато результат точнее. Так устроены модели в физике, химии, экологии и биологии: если записать законы клетки или популяции в виде уравнений, компьютер может «прожить» их шаг за шагом.

### Исследуй и потренируйся

Для dN/dt = 0,1 · N и N(0) = 100 сделай два шага по h = 1, затем четыре шага по h = 0,5 и сравни оба результата при t = 2 с точным значением 100 · e^0,2 ≈ 122,14. Какой шаг ближе к точному ответу? Затем напиши цикл на Python, который делает 20 шагов по h = 0,1.

### Вопрос

Для dN/dt = 0,1 · N, N(0) = 100 сделали два шага метода Эйлера с h = 1. Какое значение получилось при t = 2?

### Варианты

- 121: N₁ = 100 + 1 · 0,1 · 100 = 110, N₂ = 110 + 1 · 0,1 · 110 = 121.
- 120: каждый шаг добавляет по 10.
- 122,14: метод Эйлера даёт точное решение.

### Ответ

1

### Разбор

Первый шаг: скорость в начале 0,1 · 100 = 10, значит N₁ = 110. Второй шаг: скорость уже 0,1 · 110 = 11, значит N₂ = 121. Ответ 120 забывает, что скорость растёт вместе с N. Точное значение 100 · e^0,2 ≈ 122,14 немного больше: метод Эйлера на каждом шаге берёт скорость из начала отрезка и потому отстаёт.

### Границы модели

Метод Эйлера — самый простой численный метод; при большом шаге он может сильно ошибаться или даже давать неустойчивый результат. Для точных расчётов используют более совершенные методы. Модель хороша настолько, насколько верны уравнения: численный метод решает уравнение, но не проверяет, правильно ли оно описывает природу.

## English

### Goal

Solve a differential equation approximately with Euler's method, understand where the error comes from and how to reduce it, and see in this the basis of computer models of living systems.

### Idea and mechanism

Many laws of nature are written as differential equations: they say not what a quantity is but how fast it changes. Population growth dN/dt = r · N, logistic growth, enzyme reactions are all such equations. An exact solution is far from always available, but a computer can step through time.

Euler's method does exactly that. Suppose the initial value y₀ at time t₀ and the rule of change y′ = f(t, y) are known. Choose a small step h and compute: tₙ = t₀ + n·h, yₙ = yₙ₋₁ + h · f(tₙ₋₁, yₙ₋₁). Each step follows the tangent line, as if the rate of change were constant over the interval. The result is a broken line approximating the true solution curve.

Because the rate actually changes within a step, error builds up. It is reduced by making the step smaller: more computation, but a more accurate result. This is how models in physics, chemistry, ecology, and biology work: write the laws of a cell or a population as equations, and a computer can "live through" them step by step.

### Explore and practise

For dN/dt = 0.1 · N and N(0) = 100, take two steps with h = 1, then four steps with h = 0.5, and compare both results at t = 2 with the exact value 100 · e^0.2 ≈ 122.14. Which step size is closer to the exact answer? Then write a Python loop that takes 20 steps with h = 0.1.

### Question

For dN/dt = 0.1 · N, N(0) = 100, two steps of Euler's method with h = 1 were taken. What value was obtained at t = 2?

### Options

- 121: N₁ = 100 + 1 · 0.1 · 100 = 110, N₂ = 110 + 1 · 0.1 · 110 = 121.
- 120: each step adds 10.
- 122.14: Euler's method gives the exact solution.

### Answer

1

### Explanation

First step: the rate at the start is 0.1 · 100 = 10, so N₁ = 110. Second step: the rate is now 0.1 · 110 = 11, so N₂ = 121. The answer 120 forgets that the rate grows with N. The exact value 100 · e^0.2 ≈ 122.14 is slightly larger: Euler's method takes the rate from the start of each interval and so lags behind.

### Limits

Euler's method is the simplest numerical method; with a large step it can be badly off or even unstable. Accurate calculations use more refined methods. A model is only as good as its equations: a numerical method solves an equation but does not check whether it describes nature correctly.

## Sources

- Gilbert Strang, Edwin “Jed” Herman, *Calculus Volume 2*, OpenStax, 2016, section 4.2 “Direction Fields and Numerical Methods” (consulted 2026-10-31): Euler's method xₙ = x₀ + nh, yₙ = yₙ₋₁ + h f(xₙ₋₁, yₙ₋₁) with step size h for approximating solutions of first-order differential equations: [OpenStax Calculus Volume 2, 4.2](https://openstax.org/books/calculus-volume-2/pages/4-2-direction-fields-and-numerical-methods)
- Mary Ann Clark, Matthew Douglas, Jung Choi, *Biology 2e*, OpenStax, 2018, section 45.3 “Environmental Limits to Population Growth” (consulted 2026-10-26): exponential population growth dN/dT = rmax N: [OpenStax Biology 2e, 45.3](https://openstax.org/books/biology-2e/pages/45-3-environmental-limits-to-population-growth)
- The OpenStax pages state their own license terms; the lesson paraphrases the sections and does not copy their text: [OpenStax terms of use](https://openstax.org/terms-of-use)
