---
subject: programming
lesson_id: programming.collections_and_loops
level: foundations
languages: ru, en
source_checked: 2026-10-13
source_review_interval_days: 90
---

# Коллекции и циклы / Collections and Loops

## Русский

### Простыми словами

Список это ряд значений по порядку, у каждого свой номер, индекс. Счёт номеров в Python начинается с нуля. Похоже на ряд почтовых ящиков: первый ящик номер 0, второй номер 1. Цикл `for` проходит ящики по очереди, а `while` повторяет шаги, пока условие верно. В нейросетях всё хранится в таких рядах чисел.

**Что нужно знать до.** Урок «Условия, циклы и функции» (шаг 2).

**Если непонятно.** Если путаешься в номерах, выпиши список на бумаге и подпиши под каждым элементом его индекс, начиная с 0. Если неясен сам цикл, вернись к уроку «Условия, циклы и функции». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Объяснять порядок и индексы элементов списка, изменять список добавлением, выбирать между обходом значений и пар «индекс — значение», а также трассировать цикл `while` с изменяющимся условием.

### Идея и механизм

Список (`list`) хранит упорядоченную последовательность значений. Позиции считаются с нуля: список из трёх элементов имеет индексы `0`, `1`, `2`, а `len(tasks)` возвращает `3`. `append()` добавляет элемент в конец и меняет исходный список. Цикл `for item in tasks` получает элементы по порядку; `enumerate(tasks)` удобно добавляет к каждому элементу его индекс.

```python
tasks = ["docs", "tests"]
tasks.append("build")

for index, task in enumerate(tasks):
    print(f"{index}: {task}")
```

Результат — `0: docs`, `1: tests`, `2: build`. Для простого обхода только по значениям не нужен `range(len(tasks))`; используй его, когда действительно нужна числовая последовательность. Если во время цикла менять размер той же коллекции, элементы можно пропустить или обработать неожиданно. Для отбора безопаснее собрать новый список.

### Исследуй и потренируйся

В тренажёре добавляй задачи в список и удаляй последнюю. Переключай режим обхода: только значения или пары с индексами. Следи, как операция меняет длину списка и строки результата; после удаления последнего элемента проверь, что пустой список не вызывает обращение по индексу.

#### Цикл `while`: повторение по условию

`while` перед каждым проходом проверяет условие. Если `remaining > 0`, тело выполняется и уменьшает значение; затем Python проверяет условие снова:

```python
remaining = 5
while remaining > 0:
    print(remaining)
    remaining -= 2
```

Будут напечатаны `5`, `3`, `1`. После третьего шага `remaining` станет `-1`; при следующей проверке условие ложно, поэтому тело уже не запустится. Если тело не приближает программу к ложному условию, цикл может продолжаться бесконечно. В тренажёре меняй старт от `0` до `9` и уменьшение от `1` до `3`, а затем выполняй ровно одну проверку за раз: так видны и каждый проход, и финальная проверка, которая останавливает цикл.

Практика: список `steps = ["measure", "calculate"]`; добавь `"check"`, затем предскажи длину и вывод `for index, step in enumerate(steps): print(index, step)`. После этого объясни, почему первый индекс — `0`, а последний — `len(steps) - 1`.

### Вопрос

Что напечатает этот код?

```python
items = ["a", "b"]
items.append("c")
for index, item in enumerate(items):
    print(index, item)
```

### Варианты

- `0 a`, `1 b`, `2 c`
- `1 a`, `2 b`, `3 c`
- `0 c`, `1 b`, `2 a`

### Ответ

1

### Разбор

Первый вариант верен: индексация начинается с нуля, `append()` добавляет `"c"` в конец, а `enumerate()` выдаёт пары индекса и значения в исходном порядке.

### Границы вывода

Тренажёр показывает только ограниченную учебную модель списка и цикла: он не запускает код ученика и не измеряет время выполнения. Индекс — это позиция в конкретной последовательности, а не постоянный идентификатор объекта. Индекс вне допустимого диапазона вызовет `IndexError`; удаление отсутствующего значения и изменение коллекции во время обхода требуют отдельной обработки.

## English

### In plain words

A list is a row of values in order, and each has its own number, an index. Counting in Python starts at zero. It is like a row of mailboxes: the first box is number 0, the second number 1. A `for` loop visits the boxes in turn, and `while` repeats steps while a condition is true. In neural networks everything is stored in such rows of numbers.

**What to know first.** The lesson «Conditions, Loops, and Functions» (step 2).

**If something is unclear.** If you mix up the numbers, write the list on paper and put each element's index under it, starting from 0. If the loop itself is unclear, go back to «Conditions, Loops, and Functions». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Explain list order and indexes, change a list by appending items, choose between value iteration and index–value iteration, and trace a `while` loop with a changing condition.

### Idea and mechanism

A list stores an ordered sequence of values. Positions start at zero: a three-item list has indexes `0`, `1`, and `2`, while `len(tasks)` returns `3`. `append()` adds an item to the end and mutates the original list. A `for item in tasks` loop receives values in order; `enumerate(tasks)` conveniently pairs each value with its index.

```python
tasks = ["docs", "tests"]
tasks.append("build")

for index, task in enumerate(tasks):
    print(f"{index}: {task}")
```

The output is `0: docs`, `1: tests`, `2: build`. A simple value-only loop does not need `range(len(tasks))`; use `range` when you actually need a numeric sequence. Changing the size of a collection while iterating over that same collection can skip items or produce surprising behavior. For filtering, building a new list is safer.

### Explore and practise

Add tasks to the trainer's list and remove the last one. Switch between value-only iteration and index–value pairs. Watch how each operation changes the list length and output; after removing the last item, check that an empty list is not indexed.

#### The `while` loop: repeat while a condition holds

`while` checks its condition before every iteration. If `remaining > 0`, the body runs and decreases the value; Python then checks the condition again:

```python
remaining = 5
while remaining > 0:
    print(remaining)
    remaining -= 2
```

The loop prints `5`, `3`, and `1`. After the third step, `remaining` becomes `-1`; the next check is false, so the body does not run again. If the body never moves the program toward a false condition, the loop can run forever. In the trainer, choose a start from `0` to `9` and a decrement from `1` to `3`, then advance one condition check at a time to see each iteration and the final check that stops the loop.

Practice: start with `steps = ["measure", "calculate"]`, append `"check"`, then predict the length and the output of `for index, step in enumerate(steps): print(index, step)`. Explain why the first index is `0` and the last one is `len(steps) - 1`.

### Question

What does this code print?

```python
items = ["a", "b"]
items.append("c")
for index, item in enumerate(items):
    print(index, item)
```

### Options

- `0 a`, `1 b`, `2 c`
- `1 a`, `2 b`, `3 c`
- `0 c`, `1 b`, `2 a`

### Answer

1

### Explanation

The first option is correct: indexing starts at zero, `append()` adds `"c"` at the end, and `enumerate()` yields index–value pairs in the original order.

### Limits

The trainer shows a small, bounded teaching model of a list and a loop; it does not run learner code or measure execution time. An index is a position in one particular sequence, not a permanent object identifier. An out-of-range index raises `IndexError`; handling missing values and modifying a collection while iterating need separate treatment.

## Sources

- [Python Tutorial: Lists and sequences — Python Software Foundation / Учебник Python: списки и последовательности — Фонд Python](https://docs.python.org/3/tutorial/introduction.html)
- [Python Tutorial: `for` Statements and `range` — Python Software Foundation / Учебник Python: оператор `for` и `range` — Фонд Python](https://docs.python.org/3/tutorial/controlflow.html)
- [Python Language Reference: The `while` statement — Python Software Foundation / Справочник по языку Python: оператор `while` — Фонд Python](https://docs.python.org/3/reference/compound_stmts.html#the-while-statement)
