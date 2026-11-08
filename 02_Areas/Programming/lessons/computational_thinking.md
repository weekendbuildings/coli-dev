---
subject: programming
lesson_id: programming.computational_thinking
level: foundations
languages: ru, en
source_checked: 2026-10-17
source_review_interval_days: 90
---

# Алгоритмическое мышление и псевдокод / Computational Thinking and Pseudocode

## Русский

### Цель

Задать контракт задачи, разложить её на однозначные шаги до выбора языка программирования и проверить обычные, граничные и недопустимые входы.

### Идея и механизм

Алгоритм задаёт правила, которые ведут от входных данных к определённому результату. Перед записью кода уточни вход, результат и ограничение задачи. Затем распиши шаги в правильном порядке и проверь каждый переход: условие должно иметь понятный исход, а программа — завершиться.

Псевдокод — это краткое описание логики обычными словами и знакомыми конструкциями вроде «если» и «иначе». У него нет единого синтаксиса: его цель — договориться о поведении до деталей Python, Swift или другого языка.

Пример: найти большее из двух чисел `a` и `b`.

```text
получи a и b
если a больше b:
    выбери a
иначе:
    выбери b
покажи выбранное число
```

Разбивка работает для обычных значений и для границы: если числа равны, ветка «иначе» всё равно возвращает такое же по значению число. Этот пример решает только задачу выбора максимума из двух чисел; следующий раздел обобщает её на непустой список, а ошибки типов и произвольный ввод остаются за пределами контракта.

### Обобщи максимум до списка

Теперь измени контракт: принять непустой список целых чисел и вернуть наибольшее значение. Отрицательные и повторяющиеся числа допустимы, пустой список — нет. Перед чтением первого элемента проверь контракт; пустой список должен приводить к `ValueError`.

```text
проверь, что список не пуст
установи current_maximum = первый элемент списка
для каждого следующего значения:
    если оно больше current_maximum:
        замени current_maximum этим значением
верни current_maximum
```

Начинай с первого элемента, а не с нуля: для `[-8, -2, -5]` правильный максимум равен `-2`, а старт с `0` вернул бы число, которого нет в списке. Трассировка: начальное значение `-8`; `-2` больше и становится максимумом; `-5` меньше и ничего не меняет; результат `-2`.

Спланируй результаты до трассировки и сверь их после неё:

| Назначение теста | Ввод | Ожидаемый результат |
| --- | --- | --- |
| Обычный, максимум в конце | `[2, 4, 9]` | `9` |
| Граница: один допустимый элемент | `[7]` | `7` |
| Все значения отрицательные | `[-8, -2, -5]` | `-2` |
| Максимум повторяется | `[3, 9, 9]` | `9` |
| Недопустимый ввод вне контракта | `[]` | Явная ошибка, например `ValueError` |

Эти примеры проверяют разные ветви и условия цикла, включая ошибочную инициализацию максимума нулём. Они помогают находить дефекты, но не доказывают корректность для всех списков.

### Другой тип задачи: среднее непустого списка

Сначала задай контракт функции: она принимает список целых чисел длиной не меньше одного и возвращает арифметическое среднее. Пустой список этому контракту не соответствует. Разложи вычисление на проверку контракта, накопление суммы, деление на число элементов и возврат результата:

```text
проверь, что список не пуст
установи total = 0
для каждого значения прибавь его к total
раздели total на количество значений
верни среднее
```

Тот же порядок можно выразить на Python:

```python
def mean(values):
    if not values:
        raise ValueError("values must not be empty")
    total = 0
    for value in values:
        total += value
    return total / len(values)
```

Для `[2, 4, 6]` сумма равна `12`, поэтому функция возвращает `4.0`. Для `[7]` результат `7.0`: один элемент проверяет границу допустимой длины. Пустой список вызывает `ValueError`, потому что в этом примере функция заранее обещает работать только с непустым списком.

### Декомпозиция: разные задачи — разные шаги

У задачи нет универсального порядка шагов. Сначала задай контракт, затем выбери операции, нужные именно для него.

**Посчитать жаркие дни.** Контракт: принять список целых дневных температур, посчитать значения не ниже `30 °C`; пустой список допустим и даёт `0`. Это задача на накопление счётчика:

```text
установи hot_days = 0
для каждой температуры:
    если температура ≥ 30:
        увеличь hot_days на 1
верни hot_days
```

Для `[28, 30, 34, 29]` результат равен `2`: значение ровно `30` подходит, а сортировать список или считать среднее не требуется. В приложении собери шаги проверки контракта, обхода всех значений, сравнения с порогом и возврата счётчика.

**Масштабировать рецепт.** Здесь требуется преобразовать каждое количество, а не посчитать подходящие значения. Контракт: базовое и нужное число порций должны быть положительными. Сохрани пропорции; в примере оставляем дробные количества и не решаем задачу перевода единиц:

```text
проверь, что оба числа порций больше 0
factor = нужное число порций / базовое число порций
для каждого ингредиента умножь его количество на factor
покажи обновлённый рецепт
```

Если рецепт рассчитан на `4` порции, а нужно `6`, коэффициент равен `1,5`. Сначала проверь входы, потом вычисли коэффициент и лишь затем примени его к каждому ингредиенту. Это другая схема декомпозиции: преобразование набора без проверки условия `≥ 30`.

### Классы входов и значения у границы

Для каждого задания сначала задай допустимую область и ожидаемое поведение. Возьмём **условное учебное правило**, а не настоящее право на скидку: возраст — целое число от `0` до `120` включительно; скидка положена с `65` лет.

| Вход | Класс теста | Ожидаемое поведение |
| --- | --- | --- |
| `40` | Обычный допустимый | Скидка не положена |
| `64` | Граница, ниже порога | Скидка не положена |
| `65` | Граница, на пороге | Скидка положена по правилу `≥ 65` |
| `66` | Обычный допустимый | Скидка положена |
| `-1` и `121` | Недопустимые: за диапазоном `0…120` | Отклонить до проверки скидки |

Пара `64`/`65` проверяет, не перепутан ли оператор `≥` с `>` или `=`. Значения `-1` и `121` проверяют обе стороны допустимого диапазона. В глоссарии ISTQB анализ граничных значений определяется как чёрноящичный метод, при котором тестируют значения на границах. Выбранные примеры помогают найти некоторые ошибки, но не доказывают отсутствие всех дефектов. Для более строгой проверки можно дополнительно взять соседей `63` и `66`.

### Подбери тесты

Тесты должны проверять разные свойства контракта, а не только ещё один обычный пример:

- **Обычный случай:** `[2, 4, 6] → 4.0`; проходит полный цикл и деление на несколько элементов.
- **Граничный случай:** `[7] → 7.0`; подтверждает поведение для одного допустимого значения.
- **Недопустимый случай:** `[] → ValueError`; проверяет отклонение входа за границей контракта.
- **Дополнительный вариант:** `[-2, 2] → 0.0`; это допустимый обычный тест, который отдельно проверяет отрицательные значения и взаимное сокращение.

Каждый тест отвечает на свой вопрос и помогает обнаружить конкретную ошибку; ни три, ни десять примеров не доказывают правильность для всех возможных входов.

### Исследуй и потренируйся

В тренажёре собери алгоритмы максимума, найди ошибку инициализации нулём, затем разложи вычисление среднего. Классифицируй тесты среднего как обычные, граничные или недопустимые. После этого собери разные последовательности для подсчёта жарких дней и масштабирования рецепта. В последнем задании классифицируй возраста `40`, `64`, `65`, `66`, `-1` и `121`; после ответа сравни пример с допустимым диапазоном и правилом скидки. Неверные ответы сохраняются как отдельные попытки, а правильный ответ объясняет проверяемую границу.

### Вопрос

Почему полезно проверить случай `a = b`, даже если задача звучит как «найти большее число»?

### Варианты

- Чтобы проверить, что равенство попадает в определённую ветку и ответ всё равно верен.
- Потому что сравнение `a > b` становится истинным, когда числа равны друг другу.
- Чтобы тот же алгоритм без изменений заработал для любого количества чисел.

### Ответ

1

### Разбор

Первый вариант верен: при равных числах условие `a > b` ложно, срабатывает ветка «иначе» и возвращается `b`, равное `a`. Это проверяет граничное поведение именно этой задачи; такой тест не доказывает корректность для любых других входов.

### Границы вывода

Псевдокод сам по себе не проверяет типы данных, производительность или корректность программной реализации. Алгоритм для двух чисел нельзя без изменений применять к списку; вариант ниже принимает только непустые списки целых чисел и считает пустой список недопустимым. Другие типы и некорректный ввод здесь не рассматриваются. Тщательно выбранные примеры помогают обнаружить дефекты, но не доказывают математическую корректность во всех случаях.

Правило возраста условное и иллюстрирует классы входов и проверки у порога; оно не описывает реальную скидку или закон. Примеры с рецептом не задают правила округления и перевода единиц: их нужно определить отдельно.

## English

### Goal

Define the task contract, break it into unambiguous steps before choosing a programming language, and check typical, boundary, and invalid inputs.

### Idea and mechanism

An algorithm defines rules that turn input into a specified result. Before writing code, state the input, the required output, and the task's limits. Put the steps in order and check each transition: every condition needs a clear outcome, and the process should finish.

Pseudocode describes logic with concise everyday language and familiar structures such as “if” and “otherwise.” It has no single required syntax; its purpose is to agree on behavior before details of Python, Swift, or another language get in the way.

Example: choose the greater of two numbers, `a` and `b`.

```text
read a and b
if a is greater than b:
    choose a
otherwise:
    choose b
show the chosen number
```

The steps handle ordinary values and the boundary: when the numbers are equal, the “otherwise” branch still returns a number with the correct maximum value. This example only chooses the maximum of two numbers; the next section extends it to a non-empty list, while type errors and arbitrary malformed input remain outside the contract.

### Generalize the maximum to a list

Change the contract: accept a non-empty list of integers and return its greatest value. Negative and repeated values are valid; an empty list is not. Check the contract before reading the first item, and report an empty list with `ValueError`.

```text
check that the list is not empty
set current_maximum = the first item
for each remaining value:
    if it is greater than current_maximum:
        replace current_maximum with it
return current_maximum
```

Start with the first item, not zero. For `[-8, -2, -5]`, the correct maximum is `-2`; starting at `0` would return a value that is not in the list. Trace: start at `-8`; `-2` is greater, so update; `-5` is smaller, so leave the maximum unchanged; return `-2`.

Plan the expected outcomes before tracing, then compare them with the result:

| Test purpose | Input | Expected result |
| --- | --- | --- |
| Typical, maximum at the end | `[2, 4, 9]` | `9` |
| Boundary: one valid item | `[7]` | `7` |
| All values are negative | `[-8, -2, -5]` | `-2` |
| The maximum is repeated | `[3, 9, 9]` | `9` |
| Invalid input outside the contract | `[]` | Explicit error, such as `ValueError` |

These cases exercise different parts of the contract and loop. They can expose defects such as initializing the maximum to zero, but they do not prove correctness for every possible list.

### A different task: the mean of a non-empty list

Start with a function contract: it accepts a list of integers containing at least one item and returns their arithmetic mean. An empty list does not satisfy that contract. Break the calculation into a contract check, sum accumulation, division by the item count, and returning the result:

```text
check that the list is not empty
set total = 0
add each value to total
divide total by the number of values
return the mean
```

The same order can be expressed in Python:

```python
def mean(values):
    if not values:
        raise ValueError("values must not be empty")
    total = 0
    for value in values:
        total += value
    return total / len(values)
```

For `[2, 4, 6]`, the sum is `12`, so the function returns `4.0`. For `[7]`, the result is `7.0`: one item checks the smallest valid list length. An empty list raises `ValueError` because this example's contract explicitly requires a non-empty list.

### Decomposition: different tasks need different steps

There is no universal order of steps. Start with the contract, then choose the operations required by that task.

**Count hot days.** Contract: accept a list of integer daily temperatures and count values at least `30 °C`; an empty list is valid and returns `0`. This task accumulates a counter:

```text
set hot_days = 0
for each temperature:
    if temperature ≥ 30:
        increment hot_days
return hot_days
```

For `[28, 30, 34, 29]`, the result is `2`: a value exactly equal to `30` counts, and there is no need to sort the list or calculate its mean. In the app, assemble the contract check, scan every value, compare with the threshold, and return the counter.

**Scale a recipe.** This task transforms each quantity instead of counting matching values. Contract: the base and requested serving counts must be positive. Preserve proportions; this example keeps fractional quantities and does not handle unit conversion:

```text
check that both serving counts are greater than 0
factor = requested servings / base servings
for each ingredient, multiply its quantity by factor
present the adjusted recipe
```

If the base recipe serves `4` and the target is `6`, the factor is `1.5`. Validate inputs first, calculate the factor, and only then apply it to each ingredient. This is a different decomposition pattern: transform a collection without the `≥ 30` condition.

### Input partitions and values around a boundary

For every task, define the valid domain and expected behavior first. Consider a **hypothetical teaching rule**, not a real legal discount: age is an integer from `0` through `120`, inclusive; a discount applies from age `65`.

| Input | Test class | Expected behavior |
| --- | --- | --- |
| `40` | Typical valid | No discount |
| `64` | Boundary, below threshold | No discount |
| `65` | Boundary, at threshold | Discount applies under `≥ 65` |
| `66` | Typical valid | Discount applies |
| `-1` and `121` | Invalid: outside `0…120` | Reject before checking the discount |

The `64`/`65` pair checks whether `≥` was mistakenly changed to `>` or `=`. Values `-1` and `121` check both sides of the valid domain. The ISTQB glossary defines boundary-value analysis as a black-box technique that tests boundary values. Chosen examples can reveal some errors but cannot prove that every defect is absent. For a stricter check, also try neighbors `63` and `66`.

### Choose test cases

Tests should check different parts of the contract, not just another ordinary example:

- **Typical case:** `[2, 4, 6] → 4.0`; exercises the full loop and division over several items.
- **Boundary case:** `[7] → 7.0`; checks behavior at the smallest valid input length.
- **Invalid case:** `[] → ValueError`; checks rejection of input outside the contract.
- **Additional variation:** `[-2, 2] → 0.0`; this is a valid typical test that separately checks negative values and cancellation.

Each test answers a different question and can expose a specific defect; three or ten examples still do not prove correctness for every possible input.

### Explore and practise

In the trainer, assemble the maximum algorithms, find the zero-initialization defect, then decompose the mean calculation. Classify mean tests as typical, boundary, or invalid. Next, assemble distinct step sequences for counting hot days and scaling a recipe. In the final task, classify ages `40`, `64`, `65`, `66`, `-1`, and `121`; after each answer, compare it with the valid domain and discount rule. Incorrect answers are saved as separate attempts, and a correct answer explains which boundary the example checks.

### Question

Why is it useful to check the case `a = b` when the task asks you to find the greater number?

### Options

- To make sure equality takes a defined branch and the answer is still valid.
- Because the comparison `a > b` becomes true when the numbers are equal.
- So the same algorithm works unchanged for any number of inputs.

### Answer

1

### Explanation

The first option is correct: when the numbers are equal, `a > b` is false, so the “otherwise” branch returns `b`, which equals `a`. This checks a boundary for this particular task; it does not prove correctness for every possible input.

### Limits

Pseudocode alone does not validate data types, performance, or a program implementation. The two-number algorithm cannot be applied unchanged to a list; the list version in this lesson accepts only non-empty integer lists and reports an empty list as invalid. Other types and malformed input are not covered. Carefully chosen examples can expose defects, but they do not constitute a mathematical proof for every case.

The age rule is hypothetical and only illustrates input partitions and tests near a threshold; it does not describe a real discount program or law. The recipe examples do not define rounding or unit-conversion rules; those must be specified separately.

## Sources

- NIST CSRC Glossary, “Algorithm” (official definition; consulted 2026-10-06) / Глоссарий NIST CSRC, “Algorithm” (официальное определение; проверен 2026-10-06): <https://csrc.nist.gov/glossary/term/algorithm>
- CSTA, 2026 PK–12 Computer Science Standards, algorithmic problem-solving practices (official standards; consulted 2026-10-16) / CSTA, стандарты информатики для школ 2026 года, практики алгоритмического решения задач (официальный стандарт; проверен 2026-10-16): <https://csteachers.org/pk12standards/view/>
- College Board, AP Computer Science Principles Course and Exam Description, CRD-2.J (expected outputs or behaviors for checking correctness; consulted 2026-10-16) / College Board, описание курса и экзамена AP Computer Science Principles, CRD-2.J (ожидаемые результаты или поведение для проверки корректности; проверено 2026-10-16): <https://apcentral.collegeboard.org/media/pdf/ap-computer-science-principles-course-and-exam-description.pdf>
- Python 3 Tutorial, “More Control Flow Tools” (official Python documentation; consulted 2026-10-16) / Руководство Python 3, «Дополнительные средства управления потоком выполнения» (официальная документация Python; проверена 2026-10-16): <https://docs.python.org/3/tutorial/controlflow.html>
- Python 3 built-in exceptions, “ValueError” (official Python documentation; consulted 2026-10-16) / Встроенные исключения Python 3, “ValueError” (официальная документация Python; проверена 2026-10-16): <https://docs.python.org/3/library/exceptions.html#ValueError>
- Python 3 `unittest` documentation (unit-test cases and expected results; consulted 2026-10-16) / Документация Python 3 `unittest` (тест-кейсы и ожидаемые результаты; проверена 2026-10-16): <https://docs.python.org/3/library/unittest.html>
- ACM/IEEE-CS/AAAI, CS2023 Computer Science Curricula (problem-solving through decomposition and algorithmic thinking; consulted 2026-10-17) / ACM/IEEE-CS/AAAI, учебная программа информатики CS2023 (декомпозиция задач и алгоритмическое мышление; проверена 2026-10-17): <https://csed.acm.org/final-report/>
- ISTQB Glossary, “Boundary value analysis” (boundary-value testing definition; consulted 2026-10-17) / Глоссарий ISTQB, «Анализ граничных значений» (определение тестирования границ; проверен 2026-10-17): <https://glossary.istqb.org/en_US/term/boundary-value-analysis>
