---
subject: mathematics
lesson_id: mathematics.gradient_and_partial_derivatives
level: advanced
languages: ru, en
source_checked: 2026-10-27
source_review_interval_days: 365
---

# Частные производные и градиент: как учится нейросеть / Partial Derivatives and the Gradient: How a Neural Network Learns

## Русский

### Цель

Вычислять частные производные функции нескольких переменных, собирать из них градиент, понимать, почему градиент указывает направление самого быстрого роста, и делать шаг градиентного спуска сразу по нескольким переменным.

### Идея и механизм

У функции нескольких переменных, например f(x, y), есть производная по каждой переменной отдельно — частная производная. Чтобы найти ∂f/∂x, все остальные переменные считают постоянными и дифференцируют как обычную функцию одной переменной. Для f(x, y) = x² + 3y² получаем ∂f/∂x = 2x и ∂f/∂y = 6y.

Градиент ∇f — вектор из всех частных производных: ∇f = (∂f/∂x, ∂f/∂y). У него особый смысл: функция быстрее всего растёт в направлении градиента, и скорость роста в этом направлении равна длине градиента. Значит, противоположное направление, −∇f, ведёт вниз быстрее всего. Это похоже на топографическую карту: самый крутой склон там, где линии уровня сгущаются.

Отсюда метод градиентного спуска: чтобы уменьшить функцию, делаем шаг против градиента, x′ = x − ε∇f(x), где ε — скорость обучения, небольшое положительное число. Нейросеть учится именно так: её ошибка — функция миллионов весов W и b, а обучение многократно сдвигает все веса против градиента ошибки. Урок о градиентном спуске в программировании показывал это для одной переменной; здесь та же идея для многих сразу.

### Исследуй и потренируйся

Для f(x, y) = x² + 3y² найди градиент в точке (2, −1). Сделай шаг градиентного спуска с ε = 0,1 и проверь, что значение функции уменьшилось. Затем попробуй ε = 0,5 и посмотри, что происходит с координатой y — почему слишком большой шаг перескакивает через минимум?

### Вопрос

Для f(x, y) = x² + 3y² в точке (1, 1) сделали один шаг градиентного спуска с ε = 0,1. Куда попала точка?

### Варианты

- В (0,8; 0,4): ∇f = (2, 6), и (1, 1) − 0,1 · (2, 6) = (0,8; 0,4).
- В (1,2; 1,6): шаг делают по направлению градиента.
- В (0,9; 0,9): обе координаты уменьшаются на одно и то же ε.

### Ответ

1

### Разбор

Частные производные в точке (1, 1): ∂f/∂x = 2 · 1 = 2, ∂f/∂y = 6 · 1 = 6, значит ∇f = (2, 6). Шаг спуска идёт против градиента: (1 − 0,2; 1 − 0,6) = (0,8; 0,4). Значение функции упало с 1 + 3 = 4 до 0,64 + 0,48 = 1,12. Шаг по градиенту увеличил бы функцию, а одинаковый сдвиг координат не учитывает, что по y функция растёт втрое быстрее.

### Границы модели

Градиентный спуск находит минимум надёжно только у «хороших» функций вроде этой; у сложных функций он может застрять в локальном минимуме или на плато. Выбор скорости обучения — отдельная задача: слишком маленькая замедляет обучение, слишком большая делает его неустойчивым. В настоящих нейросетях градиент считают алгоритмом обратного распространения, который урок не разбирает.

## English

### Goal

Calculate partial derivatives of a function of several variables, assemble them into the gradient, understand why the gradient points in the direction of fastest increase, and take a gradient descent step in several variables at once.

### Idea and mechanism

A function of several variables, such as f(x, y), has a derivative with respect to each variable separately: a partial derivative. To find ∂f/∂x, all other variables are treated as constants and you differentiate as for a function of one variable. For f(x, y) = x² + 3y² we get ∂f/∂x = 2x and ∂f/∂y = 6y.

The gradient ∇f is the vector of all partial derivatives: ∇f = (∂f/∂x, ∂f/∂y). It has a special meaning: the function increases fastest in the direction of the gradient, and the rate of increase in that direction equals the gradient's length. So the opposite direction, −∇f, leads downhill fastest. It is like a topographic map: the steepest slope is where the contour lines crowd together.

This gives the gradient descent method: to decrease a function, step against the gradient, x′ = x − ε∇f(x), where ε is the learning rate, a small positive number. This is exactly how a neural network learns: its error is a function of millions of weights W and b, and training repeatedly moves all the weights against the gradient of the error. The gradient descent lesson in programming showed this for one variable; here is the same idea for many at once.

### Explore and practise

For f(x, y) = x² + 3y², find the gradient at the point (2, −1). Take a gradient descent step with ε = 0.1 and check that the function's value decreased. Then try ε = 0.5 and see what happens to the y coordinate: why does too large a step jump over the minimum?

### Question

For f(x, y) = x² + 3y² at the point (1, 1), one gradient descent step with ε = 0.1 was taken. Where did the point end up?

### Options

- At (0.8, 0.4): ∇f = (2, 6), and (1, 1) − 0.1 · (2, 6) = (0.8, 0.4).
- At (1.2, 1.6): the step is taken along the gradient.
- At (0.9, 0.9): both coordinates decrease by the same ε.

### Answer

1

### Explanation

The partial derivatives at (1, 1) are ∂f/∂x = 2 · 1 = 2 and ∂f/∂y = 6 · 1 = 6, so ∇f = (2, 6). The descent step goes against the gradient: (1 − 0.2, 1 − 0.6) = (0.8, 0.4). The function's value fell from 1 + 3 = 4 to 0.64 + 0.48 = 1.12. A step along the gradient would increase the function, and an equal shift of both coordinates ignores that the function rises three times faster in y.

### Limits

Gradient descent reliably finds the minimum only for "nice" functions like this one; for complex functions it can get stuck in a local minimum or on a plateau. Choosing the learning rate is a problem of its own: too small slows learning, too large makes it unstable. In real neural networks the gradient is computed by the backpropagation algorithm, which this lesson does not cover.

## Sources

- Gilbert Strang, Edwin “Jed” Herman, *Calculus Volume 3*, OpenStax, 2016, section 4.3 “Partial Derivatives” (consulted 2026-10-27): partial derivatives computed by holding the other variables constant: [OpenStax Calculus Volume 3, 4.3](https://openstax.org/books/calculus-volume-3/pages/4-3-partial-derivatives)
- *Calculus Volume 3*, section 4.6 “Directional Derivatives and the Gradient” (consulted 2026-10-27): the directional derivative is maximised in the direction of ∇f with maximum value ‖∇f‖, and the steepest slope on a topographic map where contour lines are closest: [OpenStax Calculus Volume 3, 4.6](https://openstax.org/books/calculus-volume-3/pages/4-6-directional-derivatives-and-the-gradient)
- Ian Goodfellow, Yoshua Bengio, Aaron Courville, *Deep Learning*, MIT Press, 2016, chapter 4 “Numerical Computation” (consulted 2026-10-27): the negative gradient points downhill, and gradient descent proposes x′ = x − ε∇f(x) with learning rate ε: [Deep Learning, chapter 4](https://www.deeplearningbook.org/contents/numerical.html)
- The lesson paraphrases these sources and does not copy their text; the OpenStax pages state their own license terms: [OpenStax terms of use](https://openstax.org/terms-of-use)
