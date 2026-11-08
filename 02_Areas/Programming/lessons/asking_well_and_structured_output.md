---
subject: programming
lesson_id: programming.asking_well_and_structured_output
level: advanced
languages: ru, en
source_checked: 2026-11-02
source_review_interval_days: 180
---

# Как просить: инструкции, примеры, JSON / How to ask: instructions, examples, JSON

## Русский

### Простыми словами

Модель выполняет просьбу лучше, если сказать точно, что нужно, показать пример и задать форму ответа. Это как бланк с полями вместо письма в свободной форме: заполнить бланк проще, и проверить его тоже проще. JSON это такая строгая форма для данных: программа читает её без догадок. В уроке ты измеришь, какой из трёх приёмов помогает на самом деле, а не поверишь на слово.

**Что нужно знать до.** Уроки «Живая модель на твоём Mac» и «Чат это текст» (шаг 1): как вызвать модель и что такое системная подсказка. Из урока «Как модель ошибается» берётся счёт верных ответов.

**Если непонятно.** Если непонятен JSON, вернись к шагу 3 урока «Живая модель на твоём Mac». Словари Python, на которые похож JSON, разобраны в уроке «Коллекции и циклы» (шаг 2). Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Научиться просить модель так, чтобы её ответ могла прочитать программа, и честно измерить, что помогает: правило, примеры или заданная форма ответа. Это пригодится для агентов на следующих этапах. Нужно около 30 минут.

### Идея и механизм

Часто ответ модели нужен не человеку, а другой программе. Например, из текста заказа надо достать имя, количество и цену, чтобы посчитать сумму. Программе нужен точный формат, и здесь заметны все мелочи. Ответы будем проверять кодом.

**Шаг 1. Первая попытка.** Создай файл:

```bash
cd ~/ai-path && nano orders.py
```

В программе 12 заказов с верными ответами. *JSON* ты уже видел: это текст, похожий на словарь Python. Функция `json.loads` разбирает его строго и при любой лишней букве выдаёт ошибку. Вставь программу, сохрани и запусти командой `python3 orders.py`:

```python
import json
import urllib.request

MODEL = "qwen2.5-coder:7b"
# текст заказа и верный ответ: имя, количество, цена
ORDERS = [
    ("Анна заказала 3 книги по 250 рублей.", "Анна", 3, 250),
    ("Тимур купил 12 ручек, каждая стоит 40 рублей.", "Тимур", 12, 40),
    ("Мне нужно пять тетрадей по 60 рублей, пишет Мария.", "Мария", 5, 60),
    ("Цена 1500 за штуку, брать будет Олег, две штуки.", "Олег", 2, 1500),
    ("Заказ от Лейлы: 7 карандашей, 15 рублей за один.", "Лейла", 7, 15),
    ("Сергей берёт десяток яблок по 30 рублей.", "Сергей", 10, 30),
    ("От Дилшода: 4 кружки, по 350 рублей каждая.", "Дилшод", 4, 350),
    ("Ирина, 2 рюкзака, 2300 рублей штука.", "Ирина", 2, 2300),
    ("Купить 6 лампочек по 120 рублей просил Азиз.", "Азиз", 6, 120),
    ("Вера заказала 3 кг муки, за килограмм 90 рублей.", "Вера", 3, 90),
    ("Пётр хочет 20 конвертов по 5 рублей.", "Пётр", 20, 5),
    ("Для Камиллы 1 ноутбук за 54000 рублей.", "Камилла", 1, 54000),
]

RULE = (
    "Выпиши из текста заказа имя покупателя, количество и цену за штуку. "
    'Ответь только JSON вида {"name": "...", "count": 0, "price": 0} и ничего больше.\n'
)
EXAMPLES = (
    "Текст: Роза взяла 8 чашек по 70 рублей.\n"
    'Ответ: {"name": "Роза", "count": 8, "price": 70}\n'
    "Текст: Триста рублей за штуку, две штуки, для Ильи.\n"
    'Ответ: {"name": "Илья", "count": 2, "price": 300}\n'
)
SHAPE = {
    "type": "object",
    "properties": {"name": {"type": "string"}, "count": {"type": "integer"}, "price": {"type": "integer"}},
    "required": ["name", "count", "price"],
}


def ask(order, rule, examples, shape):
    text = (RULE if rule else "") + (EXAMPLES if examples else "") + "Текст: " + order + "\nОтвет:"
    body = {
        "model": MODEL,
        "prompt": text,
        "stream": False,
        "options": {"temperature": 0, "seed": 1, "num_predict": 80},
    }
    if shape:
        body["format"] = SHAPE  # Ollama заставит ответ подойти под эту форму
    request = urllib.request.Request(
        "http://localhost:11434/api/generate", json.dumps(body).encode(), {"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(request, timeout=300) as response:
        return json.load(response)


def check(answer, name, count, price):
    try:
        data = json.loads(answer)  # разбор строго по правилам JSON
    except ValueError:
        return "broken"
    if not isinstance(data, dict):
        return "broken"
    return "right" if (data.get("name"), data.get("count"), data.get("price")) == (name, count, price) else "wrong"


for rule in (False, True):
    answer = ask(ORDERS[0][0], rule, False, False)
    print(answer["prompt_eval_count"], repr(answer["response"][:70]).replace("`", "^"))
```

```output
50 'Анна заплатила 750 рублей за книги.'
101 '^^^json\n{"name": "Анна", "count": 3, "price": 250}\n^^^'
```

Без указаний модель просто продолжила текст, и она даже посчитала сумму, о которой её не просили. А с правилом ответ начинается со значков `^^^json`: в программе я заменил ими обратные кавычки, которыми в тексте оформляют код. Человек их не заметит, а `json.loads` на них сломается.

**Шаг 2. Три приёма и замер.**

- *Правило*: сказать словами, что нужно.
- *Примеры*: показать две готовые пары «текст и ответ». По-английски это называют *few-shot*.
- *Форма*: дать Ollama описание ответа, `format`. Это *JSON-схема*: какие поля и какого типа. Ollama следит за этим при выборе токенов.

Проверим все 8 сочетаний на всех заказах. Функция `check` даёт три исхода: верно, неверно по смыслу или сбой разбора. Допиши и запусти:

```python
for rule, examples, shape in (
    (False, False, False), (True, False, False), (False, True, False), (True, True, False),
    (False, False, True), (True, False, True), (False, True, True), (True, True, True),
):
    marks = [check(ask(order, rule, examples, shape)["response"].strip(), name, count, price) for order, name, count, price in ORDERS]
    tokens = ask(ORDERS[0][0], rule, examples, shape)["prompt_eval_count"]
    print(f"правило {rule!s:5} примеры {examples!s:5} форма {shape!s:5} токенов {tokens:3}: верно {marks.count('right'):2}, сбоев {marks.count('broken'):2}")
```

```output
правило False примеры False форма False токенов  50: верно  0, сбоев 12
правило True  примеры False форма False токенов 101: верно  0, сбоев 12
правило False примеры True  форма False токенов 143: верно 12, сбоев  0
правило True  примеры True  форма False токенов 194: верно 12, сбоев  0
правило False примеры False форма True  токенов  50: верно 10, сбоев  0
правило True  примеры False форма True  токенов 101: верно 12, сбоев  0
правило False примеры True  форма True  токенов 143: верно 12, сбоев  0
правило True  примеры True  форма True  токенов 194: верно 12, сбоев  0
```

Читаем таблицу.

- **Правило без примеров дало 0 из 12.** Содержание ответов было верным: если снять значки, верны все 12. Подвела одна мелочь в оформлении.
- **Примеры без правила дали 12 из 12.** Вспомни первый урок: модель продолжает текст. После двух пар «Текст» и «Ответ» самое вероятное продолжение это такая же пара. Примеры работают не как просьба, а как начало текста, который естественно продолжить.
- **Форма без всего дала 10 из 12.** Сбоев нет, JSON всегда правильный, но 2 ответа неверны по смыслу: в двух заказах модель записала в поле `name` всю фразу целиком. Форма отвечает за вид ответа, а не за правду.
- **Правило и форма вместе дали 12 из 12 при 101 токене.** Это самое дешёвое из полных решений: с примерами токенов 143 и больше.

**Шаг 3. Как просить.**

- Говори, что нужно получить и в каком виде.
- Если важен точный вид, задай форму, а не проси словами.
- Покажи пример, особенно трудный: примеры часто сильнее объяснений.
- Всегда проверяй ответ кодом: форму, диапазон чисел, то, что можно пересчитать.
- Меняя подсказку, прогоняй тот же набор задач. Одна удачная попытка ничего не доказывает.

**Учись у тех, кто это создаёт.** В стэнфордском CS224N 2026 года есть лекция о подсказках и настройке моделей. Силу примеров показала работа Тома Брауна и соавторов о GPT-3. Ссылки в разделе источников.

### Исследуй и потренируйся

В тренажёре записаны настоящие ответы модели на все сочетания. Включай и выключай правило, примеры и форму. Плитки показывают результат по каждому заказу: зелёная верно, красная неверно, серая сбой разбора. Щёлкни по плитке, чтобы увидеть настоящий ответ. На графике каждое сочетание это точка: правее значит дороже, выше значит точнее. Щёлкни по точке, чтобы её выбрать.

В программе добавь свой заказ с необычной записью, например `Дюжина ложек по 100 рублей для Нигоры`. Какие сочетания справятся?

### Вопрос

С одним только правилом вышло 0 верных из 12, хотя данные в ответах были верными. Что случилось?

### Варианты

- Модель обернула JSON в значки разметки, и строгий разбор на них сломался.
- Правило было коротким, и модель неверно поняла, что надо достать из текста.
- Температура 0 не даёт модели писать JSON, пока не задана форма ответа.

### Ответ

1

### Разбор

Если снять эти значки, ответы окажутся верными, значит, задачу модель поняла. Температура тут ни при чём: с примерами при той же температуре она написала чистый JSON. Поэтому проверяй не только смысл, но и вид ответа, а там, где можно, задавай форму.

### Границы модели

Заказов всего 12, и они простые, поэтому «12 из 12» не значит, что так будет всегда. Результат относится к этой модели и этой подсказке: у другой модели лучшим может оказаться другое сочетание, а значки разметки она может и не ставить. Токены я считал на первом заказе. Форма не делает ответ правдой, и на сложных схемах она может замедлять работу, чего я здесь не измерял.

## English

### In plain words

A model follows a request better if you say exactly what you need, show an example and set the form of the answer. It is like a form with fields instead of a free-style letter: a form is easier to fill in and easier to check. JSON is such a strict form for data: a program reads it without guessing. In this lesson you measure which of three tricks really helps instead of taking it on trust.

**What to know first.** The lessons «A live model on your Mac» and «A chat is text» (step 1): how to call a model and what a system prompt is. Counting correct answers comes from «How a model errs».

**If something is unclear.** If JSON is unclear, go back to step 3 of «A live model on your Mac». Python dictionaries, which JSON resembles, are covered in «Collections and Loops» (step 2). Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Learn to ask a model so that a program can read its answer, and honestly measure what helps: a rule, examples, or a set shape of the answer. This will serve for agents in the coming stages. It takes about 30 minutes.

### Idea and mechanism

Often a model's answer is needed not by a person but by another program. For example, you must pull the name, count, and price from an order's text to compute a sum. A program needs an exact format, and here all the small things show. We will check the answers with code. The orders stay in Russian, as they were recorded.

**Step 1. A first try.** Create a file:

```bash
cd ~/ai-path && nano orders.py
```

The program has 12 orders with right answers. You have seen *JSON*: plain text that looks like a Python dictionary. The function `json.loads` parses it strictly and gives an error at any extra letter. Paste the program, save it, and run it with `python3 orders.py`:

```python
import json
import urllib.request

MODEL = "qwen2.5-coder:7b"
# an order's text and the right answer: name, count, price
ORDERS = [
    ("Анна заказала 3 книги по 250 рублей.", "Анна", 3, 250),
    ("Тимур купил 12 ручек, каждая стоит 40 рублей.", "Тимур", 12, 40),
    ("Мне нужно пять тетрадей по 60 рублей, пишет Мария.", "Мария", 5, 60),
    ("Цена 1500 за штуку, брать будет Олег, две штуки.", "Олег", 2, 1500),
    ("Заказ от Лейлы: 7 карандашей, 15 рублей за один.", "Лейла", 7, 15),
    ("Сергей берёт десяток яблок по 30 рублей.", "Сергей", 10, 30),
    ("От Дилшода: 4 кружки, по 350 рублей каждая.", "Дилшод", 4, 350),
    ("Ирина, 2 рюкзака, 2300 рублей штука.", "Ирина", 2, 2300),
    ("Купить 6 лампочек по 120 рублей просил Азиз.", "Азиз", 6, 120),
    ("Вера заказала 3 кг муки, за килограмм 90 рублей.", "Вера", 3, 90),
    ("Пётр хочет 20 конвертов по 5 рублей.", "Пётр", 20, 5),
    ("Для Камиллы 1 ноутбук за 54000 рублей.", "Камилла", 1, 54000),
]

RULE = (
    "Выпиши из текста заказа имя покупателя, количество и цену за штуку. "
    'Ответь только JSON вида {"name": "...", "count": 0, "price": 0} и ничего больше.\n'
)
EXAMPLES = (
    "Текст: Роза взяла 8 чашек по 70 рублей.\n"
    'Ответ: {"name": "Роза", "count": 8, "price": 70}\n'
    "Текст: Триста рублей за штуку, две штуки, для Ильи.\n"
    'Ответ: {"name": "Илья", "count": 2, "price": 300}\n'
)
SHAPE = {
    "type": "object",
    "properties": {"name": {"type": "string"}, "count": {"type": "integer"}, "price": {"type": "integer"}},
    "required": ["name", "count", "price"],
}


def ask(order, rule, examples, shape):
    text = (RULE if rule else "") + (EXAMPLES if examples else "") + "Текст: " + order + "\nОтвет:"
    body = {
        "model": MODEL,
        "prompt": text,
        "stream": False,
        "options": {"temperature": 0, "seed": 1, "num_predict": 80},
    }
    if shape:
        body["format"] = SHAPE  # Ollama forces the answer to fit this shape
    request = urllib.request.Request(
        "http://localhost:11434/api/generate", json.dumps(body).encode(), {"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(request, timeout=300) as response:
        return json.load(response)


def check(answer, name, count, price):
    try:
        data = json.loads(answer)  # strict parsing by the rules of JSON
    except ValueError:
        return "broken"
    if not isinstance(data, dict):
        return "broken"
    return "right" if (data.get("name"), data.get("count"), data.get("price")) == (name, count, price) else "wrong"


for rule in (False, True):
    answer = ask(ORDERS[0][0], rule, False, False)
    print(answer["prompt_eval_count"], repr(answer["response"][:70]).replace("`", "^"))
```

```output
50 'Анна заплатила 750 рублей за книги.'
101 '^^^json\n{"name": "Анна", "count": 3, "price": 250}\n^^^'
```

With no directions the model simply continued the text, and it even computed a sum nobody asked for. With a rule, the answer begins with the marks `^^^json`: in the program I replaced with them the backticks that format code in a text. A person will not notice them, but `json.loads` breaks on them.

**Step 2. Three techniques and a measurement.**

- A *rule*: say in words what you need.
- *Examples*: show two ready pairs of a text and an answer. This is called *few-shot*.
- A *shape*: give Ollama a description of the answer, `format`. This is a *JSON schema*: which fields and of which type. Ollama watches for this when choosing tokens.

Let us test all 8 combinations on all orders. The function `check` gives three outcomes: right, wrong in meaning, or a parsing failure. Add this and run it:

```python
for rule, examples, shape in (
    (False, False, False), (True, False, False), (False, True, False), (True, True, False),
    (False, False, True), (True, False, True), (False, True, True), (True, True, True),
):
    marks = [check(ask(order, rule, examples, shape)["response"].strip(), name, count, price) for order, name, count, price in ORDERS]
    tokens = ask(ORDERS[0][0], rule, examples, shape)["prompt_eval_count"]
    print(f"rule {rule!s:5} examples {examples!s:5} shape {shape!s:5} tokens {tokens:3}: right {marks.count('right'):2}, broken {marks.count('broken'):2}")
```

```output
rule False examples False shape False tokens  50: right  0, broken 12
rule True  examples False shape False tokens 101: right  0, broken 12
rule False examples True  shape False tokens 143: right 12, broken  0
rule True  examples True  shape False tokens 194: right 12, broken  0
rule False examples False shape True  tokens  50: right 10, broken  0
rule True  examples False shape True  tokens 101: right 12, broken  0
rule False examples True  shape True  tokens 143: right 12, broken  0
rule True  examples True  shape True  tokens 194: right 12, broken  0
```

Let us read the table.

- **A rule without examples gave 0 of 12.** The content of the answers was right: with the signs removed, all 12 are right. One small detail of formatting failed.
- **Examples without a rule gave 12 of 12.** Recall the first lesson: a model continues a text. After two pairs of a text and an answer, the most likely continuation is one more such pair. Examples work not as a request but as the start of a text that is natural to continue.
- **A shape with nothing else gave 10 of 12.** There are no failures and the JSON is always valid, but 2 answers are wrong in meaning: in two orders the model wrote the whole phrase into the `name` field. A shape answers for the form of the answer, not for truth.
- **A rule and a shape together gave 12 of 12 at 101 tokens.** This is the cheapest of the full solutions: with examples there are 143 tokens or more.

**Step 3. How to ask.**

- Say what you need and in what form.
- If the exact form matters, set a shape instead of asking in words.
- Show an example, especially a hard one: examples are often stronger than explanations.
- Always check the answer with code: the form, the range of numbers, what can be recomputed.
- When you change a prompt, run the same set of tasks. One lucky try proves nothing.

**Learn from those who build this.** Stanford's CS224N of 2026 has a lecture on prompting and adapting models. The strength of examples was shown by Tom Brown and colleagues in the GPT-3 work. The links are in the sources.

### Explore and practise

The lab holds the model's real answers for all combinations. Switch the rule, examples, and shape on and off. The tiles show the result for each order: green is right, red is wrong, grey is a parsing failure. Click a tile to see the real answer. On the chart each combination is a point: further right is costlier, higher is more accurate. Click a point to select it.

In the program, add an order of your own with an unusual form, such as `Дюжина ложек по 100 рублей для Нигоры` (a dozen spoons at 100 roubles for Nigora). Which combinations cope?

### Question

With only a rule, 0 of 12 were right, though the data in the answers were right. What happened?

### Options

- The model wrapped the JSON in markup signs, and strict parsing broke on them.
- The rule was short, and the model misunderstood what to pull from the text.
- Temperature 0 stops the model writing JSON until an answer shape is set.

### Answer

1

### Explanation

If you remove these signs, the answers turn out right, so the model understood the task. Temperature plays no part: with examples at the same temperature it wrote clean JSON. So check not only the meaning but also the form of an answer, and set a shape where you can.

### Limits

There are only 12 orders and they are simple, so "12 of 12" does not mean it will always be so. The result belongs to this model and this prompt: with another model another combination may be best, and it may not add the markup signs at all. I counted tokens on the first order. A shape does not make an answer true, and with complex schemas it may slow the work, which I did not measure here.

## Sources

- Ollama documentation, "Structured outputs" and "Generate a response" (consulted 2026-11-02): the `format` field with a JSON schema: [Structured outputs](https://docs.ollama.com/capabilities/structured-outputs), [Ollama API](https://docs.ollama.com/api/generate)
- Diyi Yang, Yejin Choi, Stanford CS224N, winter 2026 (schedule read 2026-11-02): the lecture "Efficient Adaptation (Prompting + PEFT)": [CS224N](https://web.stanford.edu/class/cs224n/)
- Tom B. Brown and colleagues, "Language Models are Few-Shot Learners", arXiv:2005.14165 (2020), abstract read 2026-11-02: a model performs new tasks from a few examples or simple instructions: [arXiv:2005.14165](https://arxiv.org/abs/2005.14165)
- All answers in this lesson were measured for it on 2026-11-02 with Ollama 0.40.13 and `qwen2.5-coder:7b`; they are kept in `02_Areas/Programming/resources/asking_well_recording.json`. The lesson paraphrases these sources and does not copy their text.
