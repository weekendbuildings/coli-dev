---
subject: programming
lesson_id: programming.conditions_loops_functions
level: foundations
languages: ru, en
source_checked: 2026-10-15
source_review_interval_days: 90
---

# Условия, циклы и функции / Conditions, Loops, and Functions

## Русский

### Простыми словами

Условие выбирает, что делать: «если идёт дождь, взять зонт». Цикл повторяет шаги: «пока в списке есть числа, бери следующее». Функция это рецепт с именем: ей дают продукты, она возвращает блюдо, и рецепт можно использовать много раз. Из этих трёх деталей собраны все программы этого пути, включая твою языковую модель.

**Что нужно знать до.** Урок «Переменные и типы данных» (шаг 2).

**Если непонятно.** Если путаешься в значениях, вернись к уроку «Переменные и типы данных» и проследи по строкам, что лежит в каждой переменной. Помогает записать это на бумаге. Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Превратить задачу из нескольких повторяющихся шагов в функцию, которая принимает данные, выбирает ветку и возвращает проверяемый результат.

### Идея и механизм

Условие `if` выбирает ветвь по истинности выражения. Цикл `for` последовательно получает элементы последовательности; его переменная на каждом шаге указывает на текущий элемент. Функция объединяет шаги под именем: параметры — её входы, `return` — результат для вызывающего кода.

```python
def count_even(numbers):
    count = 0
    for number in numbers:
        if number % 2 == 0:
            count += 1
    return count
```

Для `[2, 5, 8]` функция возвращает `2`: цикл проверяет каждое число, а операция взятия остатка по модулю двух (`number % 2`) даёт ноль для чётных значений. Счётчик `count` увеличивается только в этой ветви. `return` завершает функцию и отдаёт значение; `print` лишь показывает текст и сам по себе не заменяет возвращаемый результат.

### Исследуй и потренируйся

Перед запуском предскажи значение `number` и `count` после каждого шага. Затем поменяй список, включая пустой список и числа `0`, `-2`, `3`. Проверь, что результат равен числу элементов, которые прошли условие.

Задача: измени функцию так, чтобы она считала числа больше 10. Замени условие внутри `if` на `if number > 10:` и переименуй функцию в `count_above_ten`. Цикл и логика накопления остаются прежними.

### Вопрос

Функция считает чётные числа в `[2, 5, 8]`. Что она должна вернуть?

### Варианты

- `1`
- `2`
- `None`

### Ответ

2

### Разбор

Чётные числа — `2` и `8`, поэтому функция возвращает `2`. Если она только печатает результат, вызывающая программа получит `None`, а не значение для дальнейшего использования.

### Границы и безопасный запуск

Для списка из `n` целых чисел фиксированного размера цикл делает `n` итераций и проверок; при обычном учебном предположении, что арифметические операции и сравнения стоят `O(1)`, время работы равно `O(n)`. У целых чисел произвольной длины стоимость `%` может зависеть от размера числа. Пример ожидает целые числа и не проверяет тип входных элементов; реальные функции должны явно документировать поддерживаемые типы или проверять вход. Код урока анализируй или запускай только в изолированной среде: произвольный код из чата нельзя исполнять без ограничений.

## English

### In plain words

A condition chooses what to do: "if it rains, take an umbrella". A loop repeats steps: "while the list still has numbers, take the next one". A function is a recipe with a name: you give it ingredients, it returns a dish, and you can use the recipe many times. All programs on this path, including your language model, are built from these three parts.

**What to know first.** The lesson «Variables and Data Types» (step 2).

**If something is unclear.** If you lose track of values, go back to «Variables and Data Types» and follow, line by line, what each variable holds. Writing it on paper helps. Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Turn repeated steps into a function that accepts data, selects a branch, and returns a result that can be checked.

### Idea and mechanism

An `if` statement selects a branch based on a condition. A `for` loop visits the items of a sequence in order; its loop variable refers to the current item. A function groups steps under a name: parameters are inputs, and `return` sends a result back to the caller.

```python
def count_even(numbers):
    count = 0
    for number in numbers:
        if number % 2 == 0:
            count += 1
    return count
```

For `[2, 5, 8]`, the function returns `2`: the loop checks each number, and the modulo-two operation (`number % 2`) leaves a zero remainder for even values. The `count` variable increases only in that branch. `return` ends the function and gives a value to the caller; `print` displays text and does not replace a returned result.

### Explore and practise

Before running the code, predict `number` and `count` after each step. Then change the list, including an empty list and the values `0`, `-2`, and `3`. Check that the result equals the number of items that pass the condition.

Change the function to count values greater than 10. Replace the condition inside `if` with `if number > 10:` and rename the function to `count_above_ten`. The loop and accumulation logic stay the same.

### Question

What should a function return when it counts the even numbers in `[2, 5, 8]`?

### Options

- `1`
- `2`
- `None`

### Answer

2

### Explanation

The even numbers are `2` and `8`, so the function returns `2`. If it only prints the result, the caller gets `None` rather than a value it can use.

### Limits and safe execution

For a list of `n` fixed-size integers, the loop makes `n` iterations and checks; under the usual introductory assumption that arithmetic operations and comparisons cost `O(1)`, its runtime is `O(n)`. For arbitrary-precision integers, the cost of `%` may depend on the number's size. The example expects integers and does not validate item types; real functions should document supported types or validate input. Analyse or run lesson code only in an isolated environment; never execute arbitrary chat code without restrictions.

## Sources

- Python Tutorial, “More Control Flow Tools” / Учебник Python, «Дополнительные средства управления потоком» — statements / операторы `if`, `for` and function definitions / и определения функций: <https://docs.python.org/3/tutorial/controlflow.html#if-statements>, <https://docs.python.org/3/tutorial/controlflow.html#for-statements>, <https://docs.python.org/3/tutorial/controlflow.html#defining-functions>
- Python Built-in Types / Встроенные типы Python — truth-value testing / проверка истинности и numeric types, including `%` / числовые типы, включая `%` (current docs; consulted / актуальная документация, проверена 2026-10-15): <https://docs.python.org/3/builtins/stdtypes.html#truth-value-testing>, <https://docs.python.org/3/builtins/stdtypes.html#numeric-types-int-float-complex>
- Python Built-in Functions, `print()` / Встроенные функции Python, `print()` (current docs; consulted / актуальная документация, проверена 2026-10-15): <https://docs.python.org/3/builtins/functions.html#print>
- Python Language Reference, the `return` statement / Справочник языка Python, оператор `return`: <https://docs.python.org/3/reference/simple_stmts.html#the-return-statement>
