---
subject: programming
lesson_id: programming.python_classes_and_composition
level: intermediate
languages: ru, en
source_checked: 2026-10-26
source_review_interval_days: 365
---

# Классы в Python: объекты, наследование и композиция / Python Classes: Objects, Inheritance, and Composition

## Русский

### Простыми словами

Класс это чертёж, а объект это вещь, построенная по чертежу. По одному чертежу счётчика можно сделать много счётчиков, и каждый считает своё. Данные объекта называют атрибутами, а его действия методами. Наследование значит «новый чертёж на основе старого», композиция значит «вещь собрана из других вещей». В твоей языковой модели слой, блок и модель будут такими объектами.

**Что нужно знать до.** Уроки «Условия, циклы и функции» и «Коллекции и циклы» (шаг 2).

**Если непонятно.** Если неясно, что такое `self`, читай его как «этот самый объект». Если неясны функции, вернись к уроку «Условия, циклы и функции». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Создавать класс с методом `__init__` и атрибутами экземпляра, понимать, что у каждого объекта своё состояние, выбирать между наследованием и композицией и знать, что делают аннотации типов.

### Идея и механизм

Класс — это шаблон, по которому создаются объекты. Метод `__init__` вызывается автоматически при создании объекта и задаёт его начальное состояние. Первый параметр методов, `self`, — это сам объект. Атрибуты, записанные через `self.имя`, принадлежат конкретному экземпляру: у двух объектов одного класса они независимы.

```python
class Counter:
    def __init__(self):
        self.count = 0

    def add(self):
        self.count += 1
```

Есть два способа строить классы из других. Наследование (`class Derived(Base):`) говорит «является»: производный класс получает методы базового и может их переопределить. Композиция говорит «содержит»: объект хранит другие объекты в своих атрибутах и поручает им работу. Например, класс `Lesson` может содержать список объектов `Question`, а не наследоваться от них. Композиция обычно гибче: части легко заменить, не меняя всю иерархию.

Аннотации типов, например `def add(self) -> None:` или `count: int`, описывают, каких значений мы ждём. Python при выполнении их не проверяет: их читают отдельные инструменты — проверщики типов, редакторы и линтеры, — чтобы найти ошибки до запуска.

### Исследуй и потренируйся

Создай два объекта `Counter`, вызови `add()` у первого дважды, а у второго один раз и выведи оба значения `count`. Затем напиши класс `Lesson`, который содержит список вопросов и метод, возвращающий их число, и объясни, почему здесь композиция понятнее наследования.

### Вопрос

```python
a = Counter()
b = Counter()
a.add()
a.add()
b.add()
print(a.count)
```

Что выведет программа?

### Варианты

- 2: у каждого объекта свой `count`, а `add()` у `a` вызвали дважды.
- 3: все объекты класса делят один счётчик, и `add()` вызвали трижды.
- 0: `__init__` сбрасывает счётчик при каждом вызове метода.

### Ответ

1

### Разбор

`__init__` выполняется один раз — при создании объекта — и записывает `self.count = 0` в каждый экземпляр отдельно. Вызовы `a.add()` увеличивают только `a.count`, поэтому он равен 2, а `b.count` равен 1. Ответ 3 был бы верен, если бы `count` был общим атрибутом класса и изменялся через класс, а не через `self`.

### Границы модели

Урок показывает основы; в Python есть ещё атрибуты класса, свойства, `dataclass` и множественное наследование со своими правилами. Совет предпочитать композицию — практическое правило, а не закон: иногда наследование проще и понятнее. Аннотации помогают находить ошибки, только если запускать проверщик типов.

## English

### In plain words

A class is a blueprint, and an object is a thing built from it. From one counter blueprint you can make many counters, and each counts its own. An object's data are called attributes, and its actions methods. Inheritance means "a new blueprint based on an old one"; composition means "a thing assembled from other things". In your language model, the layer, the block and the model will be such objects.

**What to know first.** The lessons «Conditions, Loops, and Functions» and «Collections and Loops» (step 2).

**If something is unclear.** If `self` is unclear, read it as "this very object". If functions are unclear, go back to «Conditions, Loops, and Functions». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Create a class with an `__init__` method and instance attributes, understand that each object has its own state, choose between inheritance and composition, and know what type annotations do.

### Idea and mechanism

A class is a template for creating objects. The `__init__` method runs automatically when an object is created and sets its initial state. The first parameter of methods, `self`, is the object itself. Attributes written as `self.name` belong to a particular instance: in two objects of the same class they are independent.

```python
class Counter:
    def __init__(self):
        self.count = 0

    def add(self):
        self.count += 1
```

There are two ways to build classes from others. Inheritance (`class Derived(Base):`) says "is a": the derived class gets the base class's methods and can override them. Composition says "has a": an object keeps other objects in its attributes and delegates work to them. For example, a `Lesson` class can contain a list of `Question` objects rather than inherit from them. Composition is usually more flexible: parts are easy to replace without changing the whole hierarchy.

Type annotations, such as `def add(self) -> None:` or `count: int`, describe which values we expect. Python does not check them at run time: separate tools, such as type checkers, editors, and linters, read them to find mistakes before the program runs.

### Explore and practise

Create two `Counter` objects, call `add()` twice on the first and once on the second, and print both `count` values. Then write a `Lesson` class that contains a list of questions and a method returning how many there are, and explain why composition is clearer than inheritance here.

### Question

```python
a = Counter()
b = Counter()
a.add()
a.add()
b.add()
print(a.count)
```

What does the program print?

### Options

- 2: each object has its own `count`, and `add()` ran twice on `a`.
- 3: all objects of the class share one counter, and `add()` ran three times.
- 0: `__init__` resets the counter on every method call.

### Answer

1

### Explanation

`__init__` runs once, when the object is created, and writes `self.count = 0` into each instance separately. The calls `a.add()` increase only `a.count`, so it is 2, while `b.count` is 1. The answer 3 would be right if `count` were a shared class attribute changed through the class rather than through `self`.

### Limits

The lesson covers the basics; Python also has class attributes, properties, `dataclass`, and multiple inheritance with its own rules. The advice to prefer composition is a rule of thumb, not a law: sometimes inheritance is simpler and clearer. Annotations help find mistakes only if you run a type checker.

## Sources

- Python Software Foundation, *The Python Tutorial*, section 9 “Classes” (consulted 2026-10-26): `__init__` running automatically at instantiation, `self`, instance data attributes, method objects, and derived class definitions with overriding: [docs.python.org, Classes](https://docs.python.org/3/tutorial/classes.html)
- Python Software Foundation, *The Python Standard Library*, “typing — Support for type hints” (consulted 2026-10-26): the Python runtime does not enforce type annotations; they are used by type checkers, IDEs, and linters: [docs.python.org, typing](https://docs.python.org/3/library/typing.html)
- The lesson paraphrases the documentation and does not copy its text.
