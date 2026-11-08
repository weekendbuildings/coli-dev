---
subject: mathematics
lesson_id: mathematics.rates_of_change_and_derivative
level: intermediate
languages: ru, en
source_checked: 2026-10-26
source_review_interval_days: 180
---

# Производная как мгновенная скорость изменения / The Derivative as an Instantaneous Rate of Change

## Русский

### Простыми словами

Производная говорит, как быстро что-то меняется прямо сейчас. Спидометр показывает именно её: не средняя скорость за поездку, а скорость в этот миг. Чтобы найти её, берут два всё более близких момента и делят изменение на время между ними. Для обучения нейросети производная главное: она говорит, в какую сторону и насколько менять число, чтобы ошибка уменьшилась.

**Что нужно знать до.** Деление и понятие графика функции. Отдельных уроков пути не нужно.

**Если непонятно.** Если неясна идея «всё ближе», посчитай наклон для точек `x = 2` и `x = 2,1`, потом `x = 2,01`, и посмотри, к чему он стремится. Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Объяснить производную в точке через предел наклонов секущих, вычислить её для `f(x)=x²` и связать наклон графика с единицами измерения скорости изменения.

### Идея и механизм

Средняя скорость поездки — это путь, делённый на время: 120 км за 2 часа дают 60 км/ч. Но спидометр показывает скорость **в данный момент**. Как получить её из одних только измерений положения? Нужно брать всё более короткие промежутки времени и смотреть, к какому числу стремится средняя скорость. Это число и есть производная.

У прямой наклон одинаков везде (урок о наклоне). У кривой наклон меняется от точки к точке, поэтому его определяют через предел. Средняя скорость изменения функции на отрезке от `x` до `x+h` — это наклон секущей, проходящей через две точки графика; его задаёт разностное отношение:

`(f(x+h) − f(x)) / h`, где `h ≠ 0`.

Чтобы получить мгновенную скорость изменения в точке `x`, уменьшаем шаг `h` к нулю и ищем предел этих наклонов:

`f′(x) = lim(h→0) (f(x+h) − f(x)) / h`.

Геометрически секущие при этом поворачиваются и приближаются к касательной, а `f′(x)` — наклон касательной.

**Пример.** Для `f(x)=x²`:

`((x+h)² − x²) / h = (x² + 2xh + h² − x²) / h = (2xh + h²) / h = 2x + h` (при `h ≠ 0`).

При `h → 0` выражение `2x+h` стремится к `2x`, поэтому `f′(x)=2x`. Например, в точке `x=3` наклон касательной равен `6`.

**Типичная ошибка.** Подставить `h=0` прямо в дробь: получится `0/0`, которое ничего не говорит. Сначала упрости выражение при `h≠0` (как в уроке о рациональных выражениях), и только потом вычисляй предел.

Единицы производной — единицы выхода на единицу входа. Если `s(t)` — положение в метрах, а `t` — время в секундах, то `s′(t)` измеряется в метрах в секунду: это скорость.

**Зачем это дальше.** В физике производная положения по времени — скорость, а производная скорости — ускорение. В машинном обучении градиентный спуск вычисляет наклон функции потерь по каждому параметру и сдвигает параметры в сторону уменьшения потерь (урок «Градиентный спуск и шаг обучения» в разделе «Программирование»). В Python производную можно приближённо проверить разностным отношением с малым `h`, например `(f(2 + 1e-6) - f(2)) / 1e-6 ≈ 4`.

### Исследуй и потренируйся

В тренажёре выбери точку `x`, затем меняй положительный шаг `h`. Для `f(x)=x²` наклон секущей равен `2x+h`, а наклон касательной — `2x`. Например, при `x=2` и `h=1` секущая имеет наклон `5`; при `h=0,1` — `4,1`; касательная в `x=2` имеет наклон `4`. Наблюдай, как секущая поворачивается к касательной при уменьшении `h`, не делая шаг равным нулю.

### Вопрос

Для `f(x)=x²` чему равна производная в точке `x=2`?

### Варианты

- `2`
- `4`
- `8`

### Ответ

2

### Разбор

Из определения получается `f′(x)=2x`. Поэтому `f′(2)=2·2=4`. Геометрически это наклон касательной к параболе в точке `(2, 4)`. Ответ `2` — это само значение `x`, а не наклон; `8` — это `2 · f(2) = 2 · 4`: так выходит, если умножить на 2 значение функции вместо входа `x`.

### Границы модели

Производная существует не во всех точках. В точке разрыва производной нет никогда: дифференцируемая функция обязана быть непрерывной. Производной нет и в непрерывных точках с изломом (острым углом, как у `|x|` в нуле) или с вертикальной касательной (как у кубического корня в нуле). Производная в точке описывает локальное изменение и не гарантирует поведение функции далеко от этой точки. Для вычисленного наклона указывай единицы и область, где функция определена.

## English

### In plain words

A derivative tells how fast something is changing right now. A speedometer shows exactly that: not the average speed over the trip, but the speed at this moment. To find it, you take two moments ever closer together and divide the change by the time between them. For training a neural network the derivative is key: it tells which way and how much to change a number so the error goes down.

**What to know first.** Division and the idea of a function's graph. No other path lessons are needed.

**If something is unclear.** If the idea of "ever closer" is unclear, compute the slope for the points `x = 2` and `x = 2.1`, then `x = 2.01`, and see what it approaches. Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Explain a derivative at a point as the limit of secant slopes, find it for `f(x)=x²`, and connect graph slope to the units of a rate of change.

### Idea and mechanism

Average speed on a trip is distance divided by time: 120 km in 2 hours is 60 km/h. A speedometer, however, shows the speed **at this moment**. How can we get that from position measurements alone? Take shorter and shorter time intervals and see which number the average speed approaches. That number is the derivative.

A line has the same slope everywhere (see the slope lesson). A curve's slope changes from point to point, so it is defined through a limit. The average rate of change of a function from `x` to `x+h` is the slope of the secant line through two points on the graph, given by the difference quotient:

`(f(x+h) − f(x)) / h`, where `h ≠ 0`.

To find the instantaneous rate of change at `x`, shrink the step `h` toward zero and take the limit of those slopes:

`f′(x) = lim(h→0) (f(x+h) − f(x)) / h`.

Geometrically, the secant lines turn and approach the tangent line, and `f′(x)` is the tangent slope.

**Example.** For `f(x)=x²`:

`((x+h)² − x²) / h = (x² + 2xh + h² − x²) / h = (2xh + h²) / h = 2x + h` (for `h ≠ 0`).

As `h → 0`, `2x+h` approaches `2x`, so `f′(x)=2x`. At `x=3`, for example, the tangent slope is `6`.

**Common mistake.** Substituting `h=0` straight into the quotient: that gives `0/0`, which says nothing. First simplify while `h≠0` (as in the rational expressions lesson), then evaluate the limit.

Derivative units are output units per input unit. If `s(t)` gives position in metres and `t` is time in seconds, then `s′(t)` is measured in metres per second: it is velocity.

**Why it matters next.** In physics, the derivative of position with respect to time is velocity, and the derivative of velocity is acceleration. In machine learning, gradient descent computes the slope of the loss with respect to each parameter and moves the parameters in the direction that reduces the loss (see the “Gradient Descent and the Learning Rate” lesson in Programming). In Python, you can check a derivative numerically with a small `h`: `(f(2 + 1e-6) - f(2)) / 1e-6 ≈ 4`.

### Explore and practise

Choose a point `x` in the trainer and vary the positive step `h`. For `f(x)=x²`, the secant slope is `2x+h`, while the tangent slope is `2x`. At `x=2`, a step of `h=1` gives secant slope `5`; `h=0.1` gives `4.1`; the tangent at `x=2` has slope `4`. Watch the secant turn toward the tangent as `h` shrinks, without setting the step to zero.

### Question

For `f(x)=x²`, what is the derivative at `x=2`?

### Options

- `2`
- `4`
- `8`

### Answer

2

### Explanation

The definition gives `f′(x)=2x`, so `f′(2)=2·2=4`. Geometrically, this is the tangent slope to the parabola at `(2, 4)`. The answer `2` is the value of `x` itself, not the slope; `8` is `2 · f(2) = 2 · 4`, which comes from doubling the function value instead of the input `x`.

### Limits

A derivative does not exist at every point. At a discontinuity there is never a derivative: a differentiable function must be continuous. A derivative also fails to exist at continuous points with a corner (a sharp turn, like `|x|` at zero) or a vertical tangent (like the cube root at zero). A derivative describes local change; it does not guarantee how the function behaves far from that point. Include units and the domain on which the function is defined.

## Sources

- OpenStax, *Calculus Volume 1*, [3.1 Defining the Derivative](https://openstax.org/books/calculus-volume-1/pages/3-1-defining-the-derivative) — derivative as the limit of a difference quotient (secant slopes), tangent line, instantaneous rate of change and velocity.
- OpenStax, *Calculus Volume 1*, [3.2 The Derivative as a Function](https://openstax.org/books/calculus-volume-1/pages/3-2-the-derivative-as-a-function) — differentiability implies continuity; corners and vertical tangents.
- OpenStax, *Calculus Volume 1*, [3.4 Derivatives as Rates of Change](https://openstax.org/books/calculus-volume-1/pages/3-4-derivatives-as-rates-of-change) — velocity as the derivative of position and acceleration as the derivative of velocity.
- Google for Developers, *Machine Learning Crash Course*, [Linear regression: Gradient descent](https://developers.google.com/machine-learning/crash-course/linear-regression/gradient-descent) — gradient descent uses the slope of the loss to move parameters in the direction that reduces loss.

OpenStax books are licensed CC BY-NC-SA 4.0. This lesson is written in original wording and does not copy textbook text or figures.
