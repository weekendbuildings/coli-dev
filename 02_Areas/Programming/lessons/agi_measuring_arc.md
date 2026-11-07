---
subject: programming
lesson_id: programming.agi_measuring_arc
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# Как мерить общий интеллект: ARC / Measuring general intelligence: ARC

## Русский

### Простыми словами

ARC это набор головоломок на клетчатой сетке. Даны несколько примеров «было и стало», нужно самому угадать правило и применить его к новой сетке. Похоже на задание «продолжи ряд» на олимпиаде по смекалке, только задачи всякий раз новые, и заранее их не выучить. Поэтому ARC проверяет умение быстро осваивать новое, а не запас знаний. В уроке ты решишь такие задачи сам, дашь их перебору программ и локальным моделям и поймёшь, почему одно число результата значит меньше, чем кажется.

**Что нужно знать до.** Урок «Что такое интеллект: три определения» (шаг 19), особенно определение Шолле. Урок «Оценка, которая что-то значит» (шаг 15): почему одно число из теста может обманывать.

**Если непонятно.** Если неясно, как программа вызывает локальную модель, вернись к шагу 3 урока «Живая модель на твоём Mac» (шаг 1). Если неясно, почему маленький набор задач даёт шаткий результат, перечитай шаг 2 урока «Оценка, которая что-то значит». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Самому решить задачи в духе ARC, дать их перебору программ и локальным моделям, посчитать результат и честно понять, что эти числа значат, а чего нет. Нужно около 40 минут.

### Идея и механизм

**Шаг 1. Что такое ARC.** Большинство тестов проверяет то, что уже выучено. Chollet в 2019 году предложил ARC: несколько примеров «вход и выход» на цветной сетке, правило надо угадать самому и применить к новому входу. Настоящие задачи скрыты и всякий раз новые, поэтому заранее их не выучить. По его определению из прошлого урока это проверка именно способности быстро осваивать новое. Людям такие задачи обычно посильны.

Здесь задачи не настоящие, а мои, в том же духе: цвет заменён цифрой. Например, вход `12` и `34`, а выход `21` и `43`. Правило: отразить каждую строку слева направо.

**Шаг 2. Сначала сам.** Открой тренажёр и реши хотя бы 7 задач из 10. Заметь, что именно ты делаешь: выдвигаешь догадку о правиле, проверяешь её на другом примере и исправляешь.

**Шаг 3. Перебор программ.** Первая идея: написать набор простых операций и перебрать их, пока правило не подойдёт ко всем примерам. Создай файл `nano ~/ai-path/arc.py`, вставь и запусти.

```python
import json
import urllib.request

# Each task: training pairs and one test, where a grid is rows of digits.
TASKS = [
    ("flip", [("12\n34", "21\n43"), ("105\n020", "501\n020")], ("340\n007", "043\n700")),
    ("turn", [("12\n34", "31\n42"), ("10\n00", "01\n00")], ("56\n70", "75\n06")),
    ("recolor", [("121\n010", "323\n030"), ("11\n00", "33\n00")], ("0110\n2112", "0330\n2332")),
    ("fill row", [("000\n050\n000", "000\n555\n000"), ("70\n00", "77\n00")], ("000\n000\n400", "000\n000\n444")),
    ("double", [("12", "1122"), ("3\n4", "33\n44")], ("56\n70", "5566\n7700")),
    ("mirror", [("12", "1221"), ("34\n50", "3443\n5005")], ("601", "601106")),
    ("gravity", [("100\n000\n020", "000\n000\n120"), ("03\n00", "00\n03")], ("500\n070\n000", "000\n000\n570")),
    ("largest", [("11\n20", "1"), ("33\n32", "3")], ("4554\n5555", "5")),
    ("border", [("000\n000\n000", "111\n101\n111"), ("0000\n0000\n0000", "1111\n1001\n1111")], ("00000\n00000\n00000", "11111\n10001\n11111")),
    ("count", [("10\n01", "2"), ("111\n010", "4")], ("11\n11\n10", "5"))]


def grid(text):
    return [list(row) for row in text.split("\n")]


def show(rows):
    return "\n".join("".join(row) for row in rows)


OPERATIONS = {
    "flip": lambda g: [row[::-1] for row in g],
    "upside": lambda g: g[::-1],
    "turn": lambda g: [list(col) for col in zip(*g[::-1])],
    "swap axes": lambda g: [list(col) for col in zip(*g)],
    "double": lambda g: [[c for c in row for _ in (0, 1)] for row in g],
    "mirror": lambda g: [row + row[::-1] for row in g],
    "1 to 3": lambda g: [["3" if c == "1" else c for c in row] for row in g],
    "fill row": lambda g: [[max(row)] * len(row) if max(row) != "0" else row for row in g],
    "gravity": lambda g: [list(col) for col in zip(*[sorted(col, key=lambda c: c != "0") for col in zip(*g)])],
    "border": lambda g: [["1" if r in (0, len(g) - 1) or c in (0, len(g[0]) - 1) else "0" for c in range(len(g[0]))] for r in range(len(g))],
    "largest": lambda g: [[max("".join(map("".join, g)), key="".join(map("".join, g)).count)]],
}


def search(task, depth=2):
    pairs = [(grid(a), grid(b)) for a, b in task[1]]
    tried = 0
    plans = [[name] for name in OPERATIONS] + [[a, b] for a in OPERATIONS for b in OPERATIONS] if depth == 2 else [[name] for name in OPERATIONS]
    for plan in plans:
        tried += 1
        works = True
        for given, wanted in pairs:
            current = given
            for name in plan:
                current = OPERATIONS[name](current)
            if current != wanted:
                works = False
                break
        if works:
            current = grid(task[2][0])
            for name in plan:
                current = OPERATIONS[name](current)
            return plan, show(current) == task[2][1], tried
    return None, False, tried


print("task, program found, right, programs tried")
wins = 0
for task in TASKS:
    plan, right, tried = search(task)
    wins += right
    print(task[0], plan, right, tried)
print("search solved", wins, "of", len(TASKS))
```

```output
task, program found, right, programs tried
flip ['flip'] True 1
turn ['turn'] True 3
recolor ['1 to 3'] True 7
fill row ['fill row'] True 8
double ['double'] True 5
mirror ['mirror'] True 6
gravity ['gravity'] True 9
largest ['largest'] True 11
border ['border'] True 10
count None False 132
search solved 9 of 10
```

Перебор решил 9 из 10 задач и сделал это за десятки проб. Отличный результат? **Осторожно.** Операции я написал, уже зная задачи, поэтому всё сводилось к выбору из подготовленного. У настоящего ARC задачи скрыты именно для того, чтобы такого не было. Запомни это: **тот, кто пишет тест и решатель вместе, всегда выиграет.** Задача «count» не решилась: такой операции у меня просто нет. Это и есть тот случай, что встретится на настоящем тесте.

**Шаг 4. Локальные модели.** Допиши и запусти. Нужна запущенная Ollama. Запись опыта лежит в уроке.

```python
def ask(model, task, **extra):
    shots = "\n\n".join(f"Вход:\n{a}\nВыход:\n{b}" for a, b in task[1])
    prompt = "Найди правило и примени его. Сетка это строки из цифр. Ответь только сеткой выхода, без пояснений.\n\n" + shots + f"\n\nВход:\n{task[2][0]}\nВыход:"
    body = {"model": model, "stream": False, "options": {"seed": 1, "temperature": 0, "num_predict": 80}, "messages": [{"role": "user", "content": prompt}]}
    body.update(extra)
    request = urllib.request.Request("http://localhost:11434/api/chat", json.dumps(body).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=900) as response:
        return json.load(response)


def clean(text):
    lines = [line.strip().replace(" ", "") for line in text.strip().replace("`", "").split("\n")]
    return "\n".join(line for line in lines if line)


for model, extra in (("qwen2.5-coder:7b", {}), ("qwen3.5", {"think": False})):
    print(model)
    wins = 0
    for task in TASKS:
        reply = clean(ask(model, task, **extra)["message"]["content"])
        good = reply == task[2][1]
        wins += good
        print(task[0], task[2][1].replace("\n", "/"), reply.replace("\n", "/")[:30], good)
    print("solved", wins, "of", len(TASKS))
```

```output
qwen2.5-coder:7b
flip 043/700 430/007 False
turn 75/06 65/07 False
recolor 0330/2332 3223 False
fill row 000/000/444 000/000/444 True
double 5566/7700 5566/7700 True
mirror 601106 6011016 False
gravity 000/000/570 000/070/500 False
largest 5 5 True
border 11111/10001/11111 11111/10001/11111 True
count 5 6 False
solved 4 of 10
qwen3.5
flip 043/700 403/700 False
turn 75/06 65/07 False
recolor 0330/2332 3223/0330 False
fill row 000/000/444 000/000/444 True
double 5566/7700 5566/7700 True
mirror 601106 601106 True
gravity 000/000/570 000/000/070 False
largest 5 5554 False
border 11111/10001/11111 11111/10001/11111 True
count 5 6 False
solved 4 of 10
```

Обе модели решили по 4 из 10, с нулевой температурой и без рассуждения. Посмотри, как они ошибаются: у `flip` верный ответ `043/700`, а `qwen2.5-coder:7b` дала `430/007`, как будто отразила не то. На `mirror` одна модель верна, а другая нет. Ответ случайным заполнением был бы почти всегда неверен, потому что вариантов сетки очень много, поэтому `4 из 10` выше случая. Но десять задач мало, а простые модели без рассуждения это не лучшее, что есть сейчас.

**Шаг 5. Настоящие числа и что они значат.**

*Измерено:* в декабре 2024 года организаторы ARC Prize сообщили, что модель OpenAI o3 набрала `75,7 %` на открытой оценке ARC-AGI при ограничении цены и ещё больше при намного больших затратах. До неё годами лучшие системы были намного ниже.

*Что это значит:* большие модели научились тому, что раньше не умели. Вопрос только, какой ценой: решение одной задачи стоило очень дорого, в отличие от человека.

*Чего это не значит:* сами организаторы написали, что прохождение ARC-AGI ещё не означает AGI. Затем они выпустили ARC-AGI-2, где новые задачи снова оказались намного труднее для моделей. **Любой тест становится целью, и его начинают решать напрямую, а это закон Гудхарта из урока об оценке.** Поэтому Chollet и делает новые версии.

*Спорно:* что доказывает успех на таком тесте. Одни видят настоящий шаг к общему интеллекту, другие говорят о приспособлении к формату теста и огромных вычислениях.

**Учись у тех, кто это создаёт.** Статья [On the Measure of Intelligence](https://arxiv.org/abs/1911.01547), раздел об ARC. Сайт [ARC Prize](https://arcprize.org/): там можно попробовать настоящие задачи. Отчёт [об o3](https://arcprize.org/blog/oai-o3-pub-breakthrough).

### Исследуй и потренируйся

В тренажёре щёлкай по клеткам нижней сетки, пока цвет не станет нужным, и нажимай «Проверить». Потом сравни с ответами перебора и моделей.

В программе добавь свою операцию для задачи `count`. Затем придумай задачу, на которой перебор снова провалится. Это и есть настоящая игра ARC.

### Вопрос

Почему 9 из 10 у перебора программ здесь слабое доказательство его силы?

### Варианты

- Операции написаны под уже известные задачи, а настоящий тест скрыт как раз от этого.
- Перебор всегда находит случайное правило, поэтому его ответы на проверке почти неверны.
- Десяти задач достаточно только для людей, поскольку у программы нет настоящего внимания.

### Ответ

1

### Разбор

Перебор проверяет правило на всех примерах, и его ответы на проверке почти все верны, поэтому случайность тут ни при чём. Дело в подготовке: я знал задачи заранее. На скрытых задачах такой готовый набор почти наверняка бы провалился.

### Границы модели

Мои 10 задач много проще настоящего ARC и не проверены на людях. Модели работали с нулевой температурой, без рассуждения, и с другими настройками результат будет другим. Числа об o3 взяты из отчёта организаторов, и я их не проверял сам. Что это значит для AGI, открытый вопрос.

## English

### In plain words

ARC is a set of puzzles on a grid of coloured cells. You get a few "before and after" examples, must guess the rule yourself and apply it to a new grid. It is like a "continue the pattern" task in a wits contest, only the puzzles are new each time, so they cannot be learned in advance. That is why ARC tests how fast you learn something new rather than how much you know. In the lesson you solve such puzzles yourself, give them to a program search and to local models, and see why one score means less than it seems.

**What to know first.** The lesson «What is intelligence: three definitions» (step 19), especially Chollet's definition. The lesson «Evaluation that means something» (step 15): why one number from a test can mislead.

**If something is unclear.** If it is unclear how a program calls a local model, go back to step 3 of «A live model on your Mac» (step 1). If it is unclear why a small set of puzzles gives a shaky result, reread step 2 of «Evaluation that means something». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Solve ARC-style tasks yourself, give them to a program search and to local models, count the results, and honestly grasp what these numbers mean and what they do not. It takes about 40 minutes.

### Idea and mechanism

**Step 1. What ARC is.** Most tests check what has been learned already. In 2019 Chollet proposed ARC: a few "input and output" examples on a coloured grid, where you must guess the rule yourself and apply it to a new input. The real tasks are hidden and new each time, so they cannot be learned in advance. By his definition from the last lesson, this tests the very ability to master new things quickly. People can usually manage such tasks.

The tasks here are not the real ones but mine, in the same spirit: a digit replaces a colour. For example, the input `12` and `34`, and the output `21` and `43`. The rule: mirror each row left to right.

**Step 2. First by yourself.** Open the lab and solve at least 7 tasks of 10. Notice what exactly you do: you put forward a guess at the rule, test it on another example, and correct it.

**Step 3. A program search.** The first idea: write a set of simple operations and try them until a rule fits all examples. Create the file `nano ~/ai-path/arc.py`, paste and run it.

```python
import json
import urllib.request

# Each task: training pairs and one test, where a grid is rows of digits.
TASKS = [
    ("flip", [("12\n34", "21\n43"), ("105\n020", "501\n020")], ("340\n007", "043\n700")),
    ("turn", [("12\n34", "31\n42"), ("10\n00", "01\n00")], ("56\n70", "75\n06")),
    ("recolor", [("121\n010", "323\n030"), ("11\n00", "33\n00")], ("0110\n2112", "0330\n2332")),
    ("fill row", [("000\n050\n000", "000\n555\n000"), ("70\n00", "77\n00")], ("000\n000\n400", "000\n000\n444")),
    ("double", [("12", "1122"), ("3\n4", "33\n44")], ("56\n70", "5566\n7700")),
    ("mirror", [("12", "1221"), ("34\n50", "3443\n5005")], ("601", "601106")),
    ("gravity", [("100\n000\n020", "000\n000\n120"), ("03\n00", "00\n03")], ("500\n070\n000", "000\n000\n570")),
    ("largest", [("11\n20", "1"), ("33\n32", "3")], ("4554\n5555", "5")),
    ("border", [("000\n000\n000", "111\n101\n111"), ("0000\n0000\n0000", "1111\n1001\n1111")], ("00000\n00000\n00000", "11111\n10001\n11111")),
    ("count", [("10\n01", "2"), ("111\n010", "4")], ("11\n11\n10", "5"))]


def grid(text):
    return [list(row) for row in text.split("\n")]


def show(rows):
    return "\n".join("".join(row) for row in rows)


OPERATIONS = {
    "flip": lambda g: [row[::-1] for row in g],
    "upside": lambda g: g[::-1],
    "turn": lambda g: [list(col) for col in zip(*g[::-1])],
    "swap axes": lambda g: [list(col) for col in zip(*g)],
    "double": lambda g: [[c for c in row for _ in (0, 1)] for row in g],
    "mirror": lambda g: [row + row[::-1] for row in g],
    "1 to 3": lambda g: [["3" if c == "1" else c for c in row] for row in g],
    "fill row": lambda g: [[max(row)] * len(row) if max(row) != "0" else row for row in g],
    "gravity": lambda g: [list(col) for col in zip(*[sorted(col, key=lambda c: c != "0") for col in zip(*g)])],
    "border": lambda g: [["1" if r in (0, len(g) - 1) or c in (0, len(g[0]) - 1) else "0" for c in range(len(g[0]))] for r in range(len(g))],
    "largest": lambda g: [[max("".join(map("".join, g)), key="".join(map("".join, g)).count)]],
}


def search(task, depth=2):
    pairs = [(grid(a), grid(b)) for a, b in task[1]]
    tried = 0
    plans = [[name] for name in OPERATIONS] + [[a, b] for a in OPERATIONS for b in OPERATIONS] if depth == 2 else [[name] for name in OPERATIONS]
    for plan in plans:
        tried += 1
        works = True
        for given, wanted in pairs:
            current = given
            for name in plan:
                current = OPERATIONS[name](current)
            if current != wanted:
                works = False
                break
        if works:
            current = grid(task[2][0])
            for name in plan:
                current = OPERATIONS[name](current)
            return plan, show(current) == task[2][1], tried
    return None, False, tried


print("task, program found, right, programs tried")
wins = 0
for task in TASKS:
    plan, right, tried = search(task)
    wins += right
    print(task[0], plan, right, tried)
print("search solved", wins, "of", len(TASKS))
```

```output
task, program found, right, programs tried
flip ['flip'] True 1
turn ['turn'] True 3
recolor ['1 to 3'] True 7
fill row ['fill row'] True 8
double ['double'] True 5
mirror ['mirror'] True 6
gravity ['gravity'] True 9
largest ['largest'] True 11
border ['border'] True 10
count None False 132
search solved 9 of 10
```

The search solved 9 of 10 tasks, in tens of trials. An excellent result? **Careful.** I wrote the operations already knowing the tasks, so everything came down to choosing among prepared options. Real ARC tasks are hidden exactly to prevent this. Remember this: **whoever writes both the test and the solver always wins.** The "count" task was not solved: I simply have no such operation. That is the very case you would meet on the real test.

**Step 4. Local models.** Add this and run it. Ollama must be running. The lesson holds a recording of the experiment.

```python
def ask(model, task, **extra):
    shots = "\n\n".join(f"Вход:\n{a}\nВыход:\n{b}" for a, b in task[1])
    prompt = "Найди правило и примени его. Сетка это строки из цифр. Ответь только сеткой выхода, без пояснений.\n\n" + shots + f"\n\nВход:\n{task[2][0]}\nВыход:"
    body = {"model": model, "stream": False, "options": {"seed": 1, "temperature": 0, "num_predict": 80}, "messages": [{"role": "user", "content": prompt}]}
    body.update(extra)
    request = urllib.request.Request("http://localhost:11434/api/chat", json.dumps(body).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=900) as response:
        return json.load(response)


def clean(text):
    lines = [line.strip().replace(" ", "") for line in text.strip().replace("`", "").split("\n")]
    return "\n".join(line for line in lines if line)


for model, extra in (("qwen2.5-coder:7b", {}), ("qwen3.5", {"think": False})):
    print(model)
    wins = 0
    for task in TASKS:
        reply = clean(ask(model, task, **extra)["message"]["content"])
        good = reply == task[2][1]
        wins += good
        print(task[0], task[2][1].replace("\n", "/"), reply.replace("\n", "/")[:30], good)
    print("solved", wins, "of", len(TASKS))
```

```output
qwen2.5-coder:7b
flip 043/700 430/007 False
turn 75/06 65/07 False
recolor 0330/2332 3223 False
fill row 000/000/444 000/000/444 True
double 5566/7700 5566/7700 True
mirror 601106 6011016 False
gravity 000/000/570 000/070/500 False
largest 5 5 True
border 11111/10001/11111 11111/10001/11111 True
count 5 6 False
solved 4 of 10
qwen3.5
flip 043/700 403/700 False
turn 75/06 65/07 False
recolor 0330/2332 3223/0330 False
fill row 000/000/444 000/000/444 True
double 5566/7700 5566/7700 True
mirror 601106 601106 True
gravity 000/000/570 000/000/070 False
largest 5 5554 False
border 11111/10001/11111 11111/10001/11111 True
count 5 6 False
solved 4 of 10
```

Both models solved 4 of 10, at zero temperature and without reasoning. See how they err: for `flip` the right answer is `043/700`, and `qwen2.5-coder:7b` gave `430/007`, as if mirroring the wrong thing. On `mirror` one model is right and the other is not. A random filling would be almost always wrong, since there are very many possible grids, so `4 of 10` is above chance. But ten tasks are few, and simple models without reasoning are not the best available now.

**Step 5. Real numbers and what they mean.**

*Measured:* in December 2024 the ARC Prize organizers reported that OpenAI's o3 model scored `75.7 %` on the public ARC-AGI evaluation under a cost limit, and more at far greater cost. Before it, the best systems were far lower for years.

*What this means:* large models learned something they could not do before. The only question is the price: solving one task cost a great deal, unlike a person.

*What this does not mean:* the organizers themselves wrote that passing ARC-AGI does not yet mean AGI. They then released ARC-AGI-2, whose new tasks again proved far harder for models. **Any test becomes a target and gets solved directly, which is Goodhart's law from the evaluation lesson.** That is why Chollet keeps making new versions.

*Disputed:* what success on such a test proves. Some see a real step towards general intelligence; others speak of adapting to the test's format with vast computing.

**Learn from the people who build this.** [On the Measure of Intelligence](https://arxiv.org/abs/1911.01547), the section on ARC. The [ARC Prize](https://arcprize.org/) site: you can try real tasks there. The report [on o3](https://arcprize.org/blog/oai-o3-pub-breakthrough).

### Explore and practise

In the lab, click the cells of the lower grid until the colour is right, and press Check. Then compare with the answers of the search and the models.

In the program, add your own operation for the `count` task. Then invent a task on which the search fails again. That is the real ARC game.

### Question

Why is 9 of 10 for the program search weak evidence of its strength here?

### Options

- Operations were written for tasks already known, and a real test hides against exactly this.
- A search always finds a random rule, so nearly all its answers on the check are wrong.
- Ten tasks are enough only for people, since a program has no real attention at all.

### Answer

1

### Explanation

The search tests a rule on all examples, and nearly all its answers on the check are right, so chance has nothing to do with it. The point is preparation: I knew the tasks in advance. On hidden tasks such a ready set would almost surely fail.

### Limits

My 10 tasks are much simpler than real ARC and were not tested on people. The models ran at zero temperature, without reasoning, and other settings would give other results. The o3 numbers come from the organizers' report, and I did not check them myself. What this means for AGI is an open question.

## Sources

- François Chollet, "On the Measure of Intelligence", arXiv:1911.01547 (2019), title read 2026-11-03: [arXiv:1911.01547](https://arxiv.org/abs/1911.01547)
- ARC Prize, "OpenAI o3 Breakthrough High Score on ARC-AGI-Pub" (2024), description read 2026-11-03: [report](https://arcprize.org/blog/oai-o3-pub-breakthrough)
- ARC Prize, site and ARC-AGI-2: [arcprize.org](https://arcprize.org/)
- The tasks, programs and numbers were written and computed for this lesson with qwen2.5-coder:7b and qwen3.5 on the owner's Mac. The lesson paraphrases these sources and does not copy their text.
