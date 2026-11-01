---
subject: physics
lesson_id: physics.fitting_pendulum_data_least_squares
level: advanced
languages: ru, en
source_checked: 2026-10-31
source_review_interval_days: 365
---

# Эксперимент и вычисление: g по данным маятника методом наименьших квадратов / Experiment and Computation: Finding g from Pendulum Data by Least Squares

## Русский

### Цель

Превращать формулу в план измерения, подгонять прямую к данным методом наименьших квадратов и извлекать из её наклона физическую величину — ускорение свободного падения g.

### Идея и механизм

Период малых колебаний простого маятника T = 2π√(L/g), где L — длина нити до центра груза. Если возвести обе части в квадрат, получится T² = (4π²/g)·L: квадрат периода растёт пропорционально длине. Значит, точки (L, T²) должны лечь на прямую, а её наклон k = 4π²/g. Отсюда g = 4π²/k.

Из одного измерения g тоже можно найти: при L = 0,75000 м и T = 1,7357 с получается g = 4π²·0,75000/1,7357² ≈ 9,828 м/с². Но у любого измерения есть ошибка. Надёжнее измерить несколько длин и провести через все точки лучшую прямую. Метод наименьших квадратов выбирает прямую y = a + b·x, у которой сумма квадратов отклонений точек от прямой (SSE) минимальна: любая другая прямая дала бы большую SSE.

```python
import math

lengths = [0.25, 0.50, 0.75, 1.00]  # m
periods = [1.00, 1.42, 1.74, 2.01]  # s, measured with a stopwatch
squares = [t * t for t in periods]

n = len(lengths)
mean_x = sum(lengths) / n
mean_y = sum(squares) / n
slope = sum((x - mean_x) * (y - mean_y) for x, y in zip(lengths, squares)) / sum((x - mean_x) ** 2 for x in lengths)
intercept = mean_y - slope * mean_x
print(round(slope, 3), round(intercept, 3), round(4 * math.pi ** 2 / slope, 2))
```

Программа печатает 4.053 -0.012 9.74: наклон 4,053 с²/м, свободный член почти ноль, как и предсказывает формула, и g ≈ 9,74 м/с². Отличие от 9,8 м/с² — это след ошибок измерения: периоды записаны лишь до сотых долей секунды.

### Исследуй и потренируйся

Добавь к каждой длине по 0,02 м, будто все длины измерены до верха груза, а не до центра, и снова запусти программу. Наклон не изменится, а сдвиг уйдёт в свободный член: поэтому g берут из наклона. Затем испорти одно измерение периода и посмотри, насколько сильнее меняется g из одной точки, чем g из наклона.

### Вопрос

Подгонка точек (L, T²) прямой дала наклон 4,00 с²/м. Чему примерно равно g?

### Варианты

- Около 9,87 м/с²: g = 4π²/наклон = 4π²/4,00 = π².
- 4,00 м/с²: наклон прямой и есть g.
- Около 0,10 м/с²: g = наклон/4π².

### Ответ

1

### Разбор

Из T² = (4π²/g)·L наклон прямой k = 4π²/g, поэтому g = 4π²/k. При k = 4,00 с²/м получаем g = π² ≈ 9,87 м/с². Наклон сам по себе измеряется в с²/м, а не в м/с², — это сразу показывает, что он не может быть g.

### Границы модели

Формула верна только для малых углов отклонения — источник говорит об углах меньше 15° — и для груза, размер которого мал по сравнению с длиной. Метод наименьших квадратов усредняет случайные ошибки, но не исправляет систематические: если секундомер всегда запаздывает, прямая честно подгонится к неверным данным. Полная оценка неопределённости наклона — отдельная тема статистики, которую урок не разбирает.

## English

### Goal

Turn a formula into a measurement plan, fit a straight line to data by least squares, and extract a physical quantity from its slope: the acceleration due to gravity g.

### Idea and mechanism

The period of small oscillations of a simple pendulum is T = 2π√(L/g), where L is the length of the string to the centre of the bob. Squaring both sides gives T² = (4π²/g)·L: the square of the period grows in proportion to the length. So the points (L, T²) should lie on a straight line whose slope is k = 4π²/g. Hence g = 4π²/k.

g can be found from a single measurement too: with L = 0.75000 m and T = 1.7357 s, g = 4π²·0.75000/1.7357² ≈ 9.828 m/s². But every measurement has an error. It is more reliable to measure several lengths and draw the best line through all the points. The least-squares method chooses the line y = a + b·x for which the sum of the squared deviations of the points from the line (SSE) is as small as possible: any other line would give a larger SSE.

```python
import math

lengths = [0.25, 0.50, 0.75, 1.00]  # m
periods = [1.00, 1.42, 1.74, 2.01]  # s, measured with a stopwatch
squares = [t * t for t in periods]

n = len(lengths)
mean_x = sum(lengths) / n
mean_y = sum(squares) / n
slope = sum((x - mean_x) * (y - mean_y) for x, y in zip(lengths, squares)) / sum((x - mean_x) ** 2 for x in lengths)
intercept = mean_y - slope * mean_x
print(round(slope, 3), round(intercept, 3), round(4 * math.pi ** 2 / slope, 2))
```

The program prints 4.053 -0.012 9.74: a slope of 4.053 s²/m, an intercept close to zero as the formula predicts, and g ≈ 9.74 m/s². The difference from 9.8 m/s² is the trace of measurement errors: the periods were recorded only to hundredths of a second.

### Explore and practise

Add 0.02 m to every length, as if all lengths were measured to the top of the bob instead of its centre, and run the program again. The slope does not change and the offset moves into the intercept: that is why g is taken from the slope. Then spoil one period measurement and see how much more g from a single point changes than g from the slope.

### Question

Fitting a line to the points (L, T²) gave a slope of 4.00 s²/m. What is g, approximately?

### Options

- About 9.87 m/s²: g = 4π²/slope = 4π²/4.00 = π².
- 4.00 m/s²: the slope of the line is g itself.
- About 0.10 m/s²: g = slope/4π².

### Answer

1

### Explanation

From T² = (4π²/g)·L the slope of the line is k = 4π²/g, so g = 4π²/k. With k = 4.00 s²/m we get g = π² ≈ 9.87 m/s². The slope itself is measured in s²/m, not m/s², which shows straight away that it cannot be g.

### Limits

The formula holds only for small angles of swing, under 15° according to the source, and for a bob that is small compared with the length. Least squares averages out random errors but does not correct systematic ones: if the stopwatch always starts late, the line will faithfully fit the wrong data. A full estimate of the slope's uncertainty is a separate statistics topic that this lesson does not cover.

## Sources

- Paul Peter Urone, Roger Hinrichs, *College Physics 2e*, OpenStax, 2022, section 16.4 “The Simple Pendulum” (consulted 2026-10-31): T = 2π√(L/g) for angles under about 15°, solving for g = 4π²L/T², and the worked example with L = 0.75000 m and T = 1.7357 s giving g = 9.8281 m/s²: [OpenStax College Physics 2e, 16.4](https://openstax.org/books/college-physics-2e/pages/16-4-the-simple-pendulum)
- Barbara Illowsky, Susan Dean, *Introductory Statistics 2e*, OpenStax, 2023, section 12.3 “The Regression Equation” (consulted 2026-10-31): the least-squares regression line as the line that minimises the sum of squared errors (SSE), with any other line giving a larger SSE: [OpenStax Introductory Statistics 2e, 12.3](https://openstax.org/books/introductory-statistics-2e/pages/12-3-the-regression-equation)
- The OpenStax pages state their own license terms; the lesson paraphrases the sections and does not copy their text: [OpenStax terms of use](https://openstax.org/terms-of-use)
