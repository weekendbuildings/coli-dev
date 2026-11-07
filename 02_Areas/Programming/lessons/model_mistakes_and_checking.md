---
subject: programming
lesson_id: programming.model_mistakes_and_checking
level: advanced
languages: ru, en
source_checked: 2026-11-02
source_review_interval_days: 180
---

# Как модель ошибается и как это проверить / How a model errs and how to check it

## Русский

### Простыми словами

Модель пишет правдоподобный текст, а не проверенный факт. Поэтому она может ошибаться тем же уверенным тоном, каким говорит правду. Похоже на бойкого ученика на экзамене: отвечает гладко даже тогда, когда не знает. Чтобы понять, насколько модели верить, ей задают вопросы с заранее известными ответами и считают долю верных. Ещё помогает спросить несколько раз: если ответы расходятся, верить нельзя.

**Что нужно знать до.** Урок «Живая модель на твоём Mac» (шаг 1): вероятность токена и температура.

**Если непонятно.** Если неясно, откуда у ответа «уверенность», вернись к шагу 4 урока «Живая модель на твоём Mac». Доля, проценты и вероятность подробнее в уроке «Вероятность и формула Байеса» (шаг 5). Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Проверить настоящую модель своими вопросами, честно посчитать, как часто она права, и увидеть главное: уверенный тон и высокая вероятность не значат, что ответ верный. Ты узнаешь четыре вида ошибок и два простых способа их ловить. Нужно около 40 минут, из них минут пять работает сама программа.

### Идея и механизм

**Шаг 1. Экзамен.** Создай файл:

```bash
cd ~/ai-path && nano exam.py
```

В программе 20 вопросов с заранее известным ответом. К каждому записан образец верного ответа: шаблон поиска в тексте, который проверяет `re.search`. Модель отвечает, а код сам ставит оценку. Такой набор вопросов с проверкой называют *оценкой*, по-английски *eval*. Вставь программу, сохрани и запусти командой `python3 exam.py`:

```python
import json
import math
import re
import urllib.request

CODER = "qwen2.5-coder:7b"
BIGGER = "qwen3.5:latest"
HINT = " Ответь коротко, одной строкой."
# вопрос и образец верного ответа
QUESTIONS = [
    ("Столица Австралии?", r"канберр"),
    ("Столица Узбекистана?", r"ташкент"),
    ("Химический символ золота?", r"\bau\b"),
    ("Кто написал роман «Война и мир»?", r"толст"),
    ("Сколько планет в Солнечной системе?", r"\b8\b|восемь"),
    ("Сколько будет 17 умножить на 24?", r"\b408\b"),
    ("Сколько будет 2 в степени 16?", r"65[\s,]?536"),
    ("Сколько будет 7 в степени 5?", r"16[\s,]?807"),
    ("Сколько будет 48271 умножить на 9173?", r"442[\s,]?789[\s,]?883"),
    ("Сколько будет 123456 умножить на 654321?", r"80[\s,]?779[\s,]?853[\s,]?376"),
    ("Сколько букв «р» в слове «программирование»?", r"\b3\b|три"),
    ("Сколько букв «r» в слове strawberry?", r"\b3\b|three|три"),
    ("Напиши слово «модель» задом наперёд.", r"ьледом"),
    ("Что тяжелее: килограмм железа или килограмм ваты?", r"одинаков|равн|столько же|весят"),
    ("У Маши три брата, и у каждого брата две сестры. Сколько сестёр у Маши?", r"\b1\b|одна"),
    ("В каком году физик Иван Петрович Карасёв получил Нобелевскую премию?", r"не получал|нет информации|не знаю|не существует|нет данных|не могу"),
    ("Кто написал роман «Тихий берег Альдебарана»?", r"не знаю|нет информации|не существует|нет данных|не могу|неизвест"),
    ("Что делает функция numpy.quantum_sort?", r"не существует|нет такой|нет функции|не знаю|отсутств"),
    ("Какой сегодня год? Ответь только числом.", r"2026"),
    ("Кто сейчас президент США? Ответь только именем.", r"трамп|trump"),
]


def ask(model, question, temperature=0, seed=1):
    body = {
        "model": model,
        "prompt": question + HINT,
        "stream": False,
        "options": {"temperature": temperature, "seed": seed, "num_predict": 90},
    }
    if model == CODER:
        body["logprobs"] = True  # вернуть вероятности токенов
    else:
        body["think"] = False  # без длинных рассуждений
    request = urllib.request.Request(
        "http://localhost:11434/api/generate", json.dumps(body).encode(), {"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(request, timeout=900) as response:
        return json.load(response)


def is_right(text, pattern):
    return re.search(pattern, text.lower()) is not None


def confidence(answer):
    # средняя вероятность токенов ответа
    logs = [token["logprob"] for token in answer["logprobs"]]
    return math.exp(sum(logs) / len(logs))


results = []
for question, pattern in QUESTIONS:
    answer = ask(CODER, question)
    text = answer["response"].strip().split("\n")[0]
    results.append((is_right(text, pattern), confidence(answer), question))
    mark = "+" if results[-1][0] else "-"
    print(f"{mark} {results[-1][1]:.2f} {question[:30]:30} {text[:42]}")
right = sum(item[0] for item in results)
print(f"Верно: {right} из {len(results)}")
```

Первый столбец: плюс значит верно, минус значит нет. Второй столбец: *уверенность*. Это средняя вероятность токенов ответа, которые ты видел в первом уроке. Число 1,00 значит, что модель не сомневалась почти ни в одном токене.

```output
+ 0.87 Столица Австралии?             Канберра
+ 0.95 Столица Узбекистана?           Ташкент
+ 0.94 Химический символ золота?      Au
- 0.80 Кто написал роман «Война и мир Роман "Война и мир" написал Львов Николаев
+ 0.90 Сколько планет в Солнечной сис 8 планет в Солнечной системе.
+ 0.99 Сколько будет 17 умножить на 2 408
+ 1.00 Сколько будет 2 в степени 16?  65536
+ 0.99 Сколько будет 7 в степени 5?   16807
- 0.34 Сколько будет 48271 умножить н 442,000,011
- 0.63 Сколько будет 123456 умножить  8077985276
- 0.36 Сколько букв «р» в слове «прог 2
- 0.56 Сколько букв «r» в слове straw 2
- 0.60 Напиши слово «модель» задом на льдом
+ 0.74 Что тяжелее: килограмм железа  Оба тяжелее, так как оба равны одному кило
- 0.77 У Маши три брата, и у каждого  У Маши две сестры.
- 0.88 В каком году физик Иван Петров Иван Петрович Карасёв получил Нобелевскую 
- 0.89 Кто написал роман «Тихий берег Роман "Тихий берег Альдебарана" написал Ал
+ 0.90 Что делает функция numpy.quant Функция numpy.quantum_sort не существует в
- 0.99 Какой сегодня год? Ответь толь 2023
- 0.96 Кто сейчас президент США? Отве Джо Байден
Верно: 9 из 20
```

Меньше половины. При этом та же модель верно посчитала 2 в степени 16. Посмотри на минусы, в них четыре разных вида ошибок.

- **Выдумка.** Физика Карасёва и роман об Альдебаране я придумал сам для этого опыта, их нет. Но модель назвала год и автора. Связный текст без опоры на факты называют *галлюцинацией*. Она случается и с известным: автором «Войны и мира» модель назвала какого-то «Львова Николаевича Лермонтова».
- **Устаревшее.** Модель уверенно называет 2023 год. Часов у неё нет, а веса застыли в момент обучения.
- **Длинный счёт.** Короткие примеры она знает, а умножить длинные числа не может. Правильный ответ `442789883`, а она написала `442,000,011`: начало похоже, остальное придумано.
- **Буквы внутри токенов.** Из первого урока ты знаешь причину: модель видит токены, а не буквы.

**Шаг 2. Можно ли верить уверенности?** Отберём только те ответы, где уверенность выше порога, и посмотрим, сколько среди них верных. Допиши в конец файла:

```python
for limit in (0.5, 0.7, 0.8, 0.9, 0.95):
    trusted = [item for item in results if item[1] > limit]
    good = sum(item[0] for item in trusted)
    print(f"уверенность выше {limit}: {len(trusted)} ответов, верных {good}")
```

```output
уверенность выше 0.5: 18 ответов, верных 9
уверенность выше 0.7: 15 ответов, верных 9
уверенность выше 0.8: 12 ответов, верных 8
уверенность выше 0.9: 7 ответов, верных 5
уверенность выше 0.95: 5 ответов, верных 3
```

Выше порога 0,8 верны только 8 из 12 ответов. Выше 0,95 верны 3 из 5: год и президент получили около 0,99 и 0,96, и оба неверны. Зато все 5 ответов с уверенностью ниже 0,7 неверны. Вывод такой: низкая уверенность это хороший сигнал тревоги, а высокая ничего не гарантирует. Причина из первого урока: вероятность отвечает на вопрос «как обычно продолжается такой текст», а не «правда ли это». Исследователи измеряют это как *калибровку*: совпадает ли уверенность с настоящей долей верных ответов.

**Шаг 3. Спроси пять раз.** Попросим модель ответить 5 раз с температурой 0,8 и посчитаем, сколько разных ответов получилось. Допиши:

```python
for question, pattern in QUESTIONS:
    tries = [ask(CODER, question, 0.8, 11 * i + 1)["response"].strip().lower().rstrip(".") for i in range(5)]
    hits = sum(is_right(text, pattern) for text in tries)
    print(f"{len(set(tries))} разных, верных {hits} из 5: {question[:34]}")
```

```output
2 разных, верных 4 из 5: Столица Австралии?
2 разных, верных 4 из 5: Столица Узбекистана?
1 разных, верных 5 из 5: Химический символ золота?
5 разных, верных 2 из 5: Кто написал роман «Война и мир»?
3 разных, верных 4 из 5: Сколько планет в Солнечной системе
1 разных, верных 5 из 5: Сколько будет 17 умножить на 24?
1 разных, верных 5 из 5: Сколько будет 2 в степени 16?
1 разных, верных 5 из 5: Сколько будет 7 в степени 5?
5 разных, верных 0 из 5: Сколько будет 48271 умножить на 91
5 разных, верных 0 из 5: Сколько будет 123456 умножить на 6
3 разных, верных 2 из 5: Сколько букв «р» в слове «программ
3 разных, верных 1 из 5: Сколько букв «r» в слове strawberr
4 разных, верных 0 из 5: Напиши слово «модель» задом наперё
5 разных, верных 3 из 5: Что тяжелее: килограмм железа или 
4 разных, верных 1 из 5: У Маши три брата, и у каждого брат
5 разных, верных 0 из 5: В каком году физик Иван Петрович К
4 разных, верных 0 из 5: Кто написал роман «Тихий берег Аль
5 разных, верных 5 из 5: Что делает функция numpy.quantum_s
1 разных, верных 0 из 5: Какой сегодня год? Ответь только ч
2 разных, верных 0 из 5: Кто сейчас президент США? Ответь т
```

Там, где модель знает ответ, он повторяется: на `17 умножить на 24` все 5 раз один и тот же. Там, где она выдумывает, ответы расходятся: о Карасёве 5 разных. На этой идее работает метод SelfCheckGPT: выдумка плохо повторяется. По моим данным, у 9 верных ответов в среднем 2,3 разных варианта, а у 11 неверных 3,7. Но это сигнал, а не доказательство. Про год модель 5 раз подряд пишет одно и то же, и это неверно: одинаково устарела. А про `numpy.quantum_sort` дала 5 разных формулировок одной верной мысли.

**Шаг 4. Другая модель.** Сравним с `qwen3.5`, она занимает 7,6 ГБ вместо 4,7. Допиши и запусти, это займёт пару минут:

```python
score = 0
for question, pattern in QUESTIONS:
    text = ask(BIGGER, question)["response"].strip().split("\n")[0]
    score += is_right(text, pattern)
    print("+" if is_right(text, pattern) else "-", question[:30].ljust(30), text[:50])
print(f"Верно: {score} из {len(QUESTIONS)}")
```

```output
+ Столица Австралии?             Столицей Австралии является город Канберра.
+ Столица Узбекистана?           Столицей Узбекистана является город Ташкент.
+ Химический символ золота?      Au
+ Кто написал роман «Война и мир Роман «Война и мир» написал Лев Николаевич Толстой
+ Сколько планет в Солнечной сис В Солнечной системе 8 планет.
+ Сколько будет 17 умножить на 2 17 умножить на 24 равно 408.
+ Сколько будет 2 в степени 16?  2 в степени 16 равно 65536.
+ Сколько будет 7 в степени 5?   16807
- Сколько будет 48271 умножить н 48271 × 9173 = 442799883
- Сколько будет 123456 умножить  80281279956
- Сколько букв «р» в слове «прог В слове «программирование» одна буква «р».
+ Сколько букв «r» в слове straw В слове strawberry 3 буквы «r».
- Напиши слово «модель» задом на ледоМ
+ Что тяжелее: килограмм железа  Они весят одинаково — по одному килограмму.
+ У Маши три брата, и у каждого  У Маши одна сестра — это она сама.
+ В каком году физик Иван Петров Иван Петрович Карасёв не получал Нобелевской преми
- Кто написал роман «Тихий берег Роман «Тихий берег Альдебарана» написал американск
+ Что делает функция numpy.quant Такой функции не существует в библиотеке NumPy.
- Какой сегодня год? Ответь толь 2024
+ Кто сейчас президент США? Отве Дональд Трамп
Верно: 14 из 20
```

Вторая модель верна в 14 вопросах из 20, но отвечает примерно в 5 раз медленнее: около 5 секунд против 1. И она тоже выдумала автора несуществующего романа. Посмотри на умножение: `442799883` неверно всего в одной цифре. Это самая коварная ошибка, потому что на глаз её не увидеть.

И посмотри на Машу: «У Маши одна сестра — это она сама». Число верное, но объяснение неверно: сама себе Маша не сестра. А наш код поставил плюс, потому что проверяет только число. Оценка измеряет лишь то, что ты в неё заложил.

**Как с этим работать.**

- Что можно посчитать, считай кодом, а не проси модель.
- Что можно проверить по источнику, проверяй. Уверенный тон это не проверка.
- Для важного спрашивай несколько раз и смотри, сходятся ли ответы.
- Помни про дату: модель не знает, что случилось после её обучения.
- Прежде чем менять модель или подсказку, прогони свой экзамен: иначе улучшение не отличить от удачи.

**Учись у тех, кто это создаёт.** В стэнфордском курсе CS224N 2026 года есть отдельная лекция об оценке. Андрей Карпатый разбирает галлюцинации в «Deep Dive into LLMs like ChatGPT». Работа TruthfulQA показала, что модели повторяют человеческие заблуждения. Ссылки в разделе источников.

### Исследуй и потренируйся

Тренажёр проверяет тебя самого: угадай раньше, чем узнаешь правду. Щёлкни по плитке и прочитай ответ модели и её уверенность. Нажми «Верю» или «Не верю». Только после этого станет видно, верен ли ответ, что сказала вторая модель и чем закончились пять попыток. Ставь порог на графике и смотри, сколько ответов он пропускает.

В программе добавь три своих вопроса о том, что ты хорошо знаешь, с образцом верного ответа. Где модель ошиблась, а где нет?

### Вопрос

Модель назвала текущим годом 2023 с уверенностью 0,99, а сейчас 2026. Что это показывает?

### Варианты

- Уверенность показывает, как обычно идёт текст, а не то, правда ли это.
- Модель знает настоящий год, но при нулевой температуре выдаёт старый.
- Такая уверенность бывает только у верных ответов, значит, ошибка в записи.

### Ответ

1

### Разбор

Часов у модели нет, настоящего года она знать не может, и температура этого не меняет: пять попыток при температуре 0,8 дали тот же год. Высокая уверенность бывает и у неверных ответов, мы только что это посчитали. Она значит, что в текстах, на которых училась модель, так и писали.

### Границы модели

Двадцать вопросов это очень мало: один вопрос меняет итог на 5 %. Я подобрал вопросы так, чтобы показать виды ошибок, поэтому 45 % и 70 % не значат, что эти модели вообще верны так часто. Образцы проверки грубые: плюс получили и ответ про Машу с неверным объяснением, и странное «Оба тяжелее». У больших моделей ошибок обычно меньше, но выдумки не исчезли полностью. Как те же модели отвечают на английском, я не измерял. Ответы о годе и президенте проверены на дату 2026-11-02 и со временем станут другими.

## English

### In plain words

A model writes plausible text, not a checked fact. So it can be wrong in the same confident tone it uses for the truth. It is like a glib student in an exam: the answer sounds smooth even when they do not know. To see how far to trust a model, you ask it questions whose answers you already know and count the share it gets right. It also helps to ask several times: if the answers differ, you cannot trust them.

**What to know first.** The lesson «A live model on your Mac» (step 1): token probability and temperature.

**If something is unclear.** If it is unclear where an answer's "confidence" comes from, go back to step 4 of «A live model on your Mac». Shares, percentages and probability are covered in «Probability and Bayes' Rule» (step 5). Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Test a real model with your own questions, honestly count how often it is right, and see the main thing: a confident tone and a high probability do not mean the answer is right. You will learn four kinds of errors and two simple ways to catch them. It takes about 40 minutes, about five of which the program runs by itself.

### Idea and mechanism

**Step 1. An exam.** Create a file:

```bash
cd ~/ai-path && nano exam.py
```

The program has 20 questions with answers known in advance. The questions stay in Russian, as they were recorded. Each comes with a pattern of the right answer: a text search pattern checked by `re.search`. The model answers, and the code gives the mark by itself. Such a set of questions with checks is called an *evaluation*, or *eval*. Paste the program, save it, and run it with `python3 exam.py`:

```python
import json
import math
import re
import urllib.request

CODER = "qwen2.5-coder:7b"
BIGGER = "qwen3.5:latest"
HINT = " Ответь коротко, одной строкой."
# a question and a pattern of the right answer
QUESTIONS = [
    ("Столица Австралии?", r"канберр"),
    ("Столица Узбекистана?", r"ташкент"),
    ("Химический символ золота?", r"\bau\b"),
    ("Кто написал роман «Война и мир»?", r"толст"),
    ("Сколько планет в Солнечной системе?", r"\b8\b|восемь"),
    ("Сколько будет 17 умножить на 24?", r"\b408\b"),
    ("Сколько будет 2 в степени 16?", r"65[\s,]?536"),
    ("Сколько будет 7 в степени 5?", r"16[\s,]?807"),
    ("Сколько будет 48271 умножить на 9173?", r"442[\s,]?789[\s,]?883"),
    ("Сколько будет 123456 умножить на 654321?", r"80[\s,]?779[\s,]?853[\s,]?376"),
    ("Сколько букв «р» в слове «программирование»?", r"\b3\b|три"),
    ("Сколько букв «r» в слове strawberry?", r"\b3\b|three|три"),
    ("Напиши слово «модель» задом наперёд.", r"ьледом"),
    ("Что тяжелее: килограмм железа или килограмм ваты?", r"одинаков|равн|столько же|весят"),
    ("У Маши три брата, и у каждого брата две сестры. Сколько сестёр у Маши?", r"\b1\b|одна"),
    ("В каком году физик Иван Петрович Карасёв получил Нобелевскую премию?", r"не получал|нет информации|не знаю|не существует|нет данных|не могу"),
    ("Кто написал роман «Тихий берег Альдебарана»?", r"не знаю|нет информации|не существует|нет данных|не могу|неизвест"),
    ("Что делает функция numpy.quantum_sort?", r"не существует|нет такой|нет функции|не знаю|отсутств"),
    ("Какой сегодня год? Ответь только числом.", r"2026"),
    ("Кто сейчас президент США? Ответь только именем.", r"трамп|trump"),
]


def ask(model, question, temperature=0, seed=1):
    body = {
        "model": model,
        "prompt": question + HINT,
        "stream": False,
        "options": {"temperature": temperature, "seed": seed, "num_predict": 90},
    }
    if model == CODER:
        body["logprobs"] = True  # return the token probabilities
    else:
        body["think"] = False  # no long reasoning
    request = urllib.request.Request(
        "http://localhost:11434/api/generate", json.dumps(body).encode(), {"Content-Type": "application/json"}
    )
    with urllib.request.urlopen(request, timeout=900) as response:
        return json.load(response)


def is_right(text, pattern):
    return re.search(pattern, text.lower()) is not None


def confidence(answer):
    # the mean probability of the answer's tokens
    logs = [token["logprob"] for token in answer["logprobs"]]
    return math.exp(sum(logs) / len(logs))


results = []
for question, pattern in QUESTIONS:
    answer = ask(CODER, question)
    text = answer["response"].strip().split("\n")[0]
    results.append((is_right(text, pattern), confidence(answer), question))
    mark = "+" if results[-1][0] else "-"
    print(f"{mark} {results[-1][1]:.2f} {question[:30]:30} {text[:42]}")
right = sum(item[0] for item in results)
print(f"Right: {right} of {len(results)}")
```

The first column: plus means right, minus means wrong. The second column is *confidence*: the mean probability of the answer's tokens, which you saw in the first lesson. A value of 1.00 means the model hardly doubted any token.

```output
+ 0.87 Столица Австралии?             Канберра
+ 0.95 Столица Узбекистана?           Ташкент
+ 0.94 Химический символ золота?      Au
- 0.80 Кто написал роман «Война и мир Роман "Война и мир" написал Львов Николаев
+ 0.90 Сколько планет в Солнечной сис 8 планет в Солнечной системе.
+ 0.99 Сколько будет 17 умножить на 2 408
+ 1.00 Сколько будет 2 в степени 16?  65536
+ 0.99 Сколько будет 7 в степени 5?   16807
- 0.34 Сколько будет 48271 умножить н 442,000,011
- 0.63 Сколько будет 123456 умножить  8077985276
- 0.36 Сколько букв «р» в слове «прог 2
- 0.56 Сколько букв «r» в слове straw 2
- 0.60 Напиши слово «модель» задом на льдом
+ 0.74 Что тяжелее: килограмм железа  Оба тяжелее, так как оба равны одному кило
- 0.77 У Маши три брата, и у каждого  У Маши две сестры.
- 0.88 В каком году физик Иван Петров Иван Петрович Карасёв получил Нобелевскую 
- 0.89 Кто написал роман «Тихий берег Роман "Тихий берег Альдебарана" написал Ал
+ 0.90 Что делает функция numpy.quant Функция numpy.quantum_sort не существует в
- 0.99 Какой сегодня год? Ответь толь 2023
- 0.96 Кто сейчас президент США? Отве Джо Байден
Right: 9 of 20
```

Fewer than half. Yet the same model correctly computed 2 to the power 16. Look at the minuses: they hold four different kinds of errors.

- **Invention.** I made up the physicist Karasyov and the novel about Aldebaran for this experiment; they do not exist. But the model named a year and an author. Coherent text with no basis in fact is called a *hallucination*. It happens with known things too: the model named some "Lvov Nikolaevich Lermontov" as the author of War and Peace.
- **Out of date.** The model confidently names the year 2023. It has no clock, and its weights froze at training time.
- **Long arithmetic.** It knows short examples but cannot multiply long numbers. The right answer is `442789883`, and it wrote `442,000,011`: the start looks right and the rest is invented.
- **Letters inside tokens.** You know the reason from the first lesson: the model sees tokens, not letters.

**Step 2. Can you trust confidence?** Let us take only the answers with confidence above a threshold and see how many of them are right. Add this to the end of the file:

```python
for limit in (0.5, 0.7, 0.8, 0.9, 0.95):
    trusted = [item for item in results if item[1] > limit]
    good = sum(item[0] for item in trusted)
    print(f"confidence above {limit}: {len(trusted)} answers, right {good}")
```

```output
confidence above 0.5: 18 answers, right 9
confidence above 0.7: 15 answers, right 9
confidence above 0.8: 12 answers, right 8
confidence above 0.9: 7 answers, right 5
confidence above 0.95: 5 answers, right 3
```

Above the threshold 0.8, only 8 of 12 answers are right. Above 0.95, 3 of 5 are right: the year and the president got about 0.99 and 0.96, and both are wrong. Yet all 5 answers with confidence below 0.7 are wrong. The conclusion: low confidence is a good alarm signal, and high confidence guarantees nothing. The reason comes from the first lesson: a probability answers "how does such a text usually go on", not "is this true". Researchers measure this as *calibration*: whether confidence matches the real share of right answers.

**Step 3. Ask five times.** Let us ask the model to answer 5 times at temperature 0.8 and count how many different answers we get. Add this:

```python
for question, pattern in QUESTIONS:
    tries = [ask(CODER, question, 0.8, 11 * i + 1)["response"].strip().lower().rstrip(".") for i in range(5)]
    hits = sum(is_right(text, pattern) for text in tries)
    print(f"{len(set(tries))} different, right {hits} of 5: {question[:34]}")
```

```output
2 different, right 4 of 5: Столица Австралии?
2 different, right 4 of 5: Столица Узбекистана?
1 different, right 5 of 5: Химический символ золота?
5 different, right 2 of 5: Кто написал роман «Война и мир»?
3 different, right 4 of 5: Сколько планет в Солнечной системе
1 different, right 5 of 5: Сколько будет 17 умножить на 24?
1 different, right 5 of 5: Сколько будет 2 в степени 16?
1 different, right 5 of 5: Сколько будет 7 в степени 5?
5 different, right 0 of 5: Сколько будет 48271 умножить на 91
5 different, right 0 of 5: Сколько будет 123456 умножить на 6
3 different, right 2 of 5: Сколько букв «р» в слове «программ
3 different, right 1 of 5: Сколько букв «r» в слове strawberr
4 different, right 0 of 5: Напиши слово «модель» задом наперё
5 different, right 3 of 5: Что тяжелее: килограмм железа или 
4 different, right 1 of 5: У Маши три брата, и у каждого брат
5 different, right 0 of 5: В каком году физик Иван Петрович К
4 different, right 0 of 5: Кто написал роман «Тихий берег Аль
5 different, right 5 of 5: Что делает функция numpy.quantum_s
1 different, right 0 of 5: Какой сегодня год? Ответь только ч
2 different, right 0 of 5: Кто сейчас президент США? Ответь т
```

Where the model knows the answer, it repeats: `17 умножить на 24` gives the same answer all 5 times. Where it invents, the answers diverge: about Karasyov there are 5 different ones. The SelfCheckGPT method rests on this idea: an invention repeats poorly. In my data, the 9 right answers have 2.3 different variants on average, and the 11 wrong ones 3.7. But this is a signal, not proof. About the year the model writes the same thing 5 times in a row, and it is wrong: it is out of date the same way each time. And about `numpy.quantum_sort` it gave 5 different wordings of one right idea.

**Step 4. Another model.** Let us compare with `qwen3.5`, which takes 7.6 GB instead of 4.7. Add this and run it; it takes a couple of minutes:

```python
score = 0
for question, pattern in QUESTIONS:
    text = ask(BIGGER, question)["response"].strip().split("\n")[0]
    score += is_right(text, pattern)
    print("+" if is_right(text, pattern) else "-", question[:30].ljust(30), text[:50])
print(f"Right: {score} of {len(QUESTIONS)}")
```

```output
+ Столица Австралии?             Столицей Австралии является город Канберра.
+ Столица Узбекистана?           Столицей Узбекистана является город Ташкент.
+ Химический символ золота?      Au
+ Кто написал роман «Война и мир Роман «Война и мир» написал Лев Николаевич Толстой
+ Сколько планет в Солнечной сис В Солнечной системе 8 планет.
+ Сколько будет 17 умножить на 2 17 умножить на 24 равно 408.
+ Сколько будет 2 в степени 16?  2 в степени 16 равно 65536.
+ Сколько будет 7 в степени 5?   16807
- Сколько будет 48271 умножить н 48271 × 9173 = 442799883
- Сколько будет 123456 умножить  80281279956
- Сколько букв «р» в слове «прог В слове «программирование» одна буква «р».
+ Сколько букв «r» в слове straw В слове strawberry 3 буквы «r».
- Напиши слово «модель» задом на ледоМ
+ Что тяжелее: килограмм железа  Они весят одинаково — по одному килограмму.
+ У Маши три брата, и у каждого  У Маши одна сестра — это она сама.
+ В каком году физик Иван Петров Иван Петрович Карасёв не получал Нобелевской преми
- Кто написал роман «Тихий берег Роман «Тихий берег Альдебарана» написал американск
+ Что делает функция numpy.quant Такой функции не существует в библиотеке NumPy.
- Какой сегодня год? Ответь толь 2024
+ Кто сейчас президент США? Отве Дональд Трамп
Right: 14 of 20
```

The second model is right on 14 questions of 20 but answers about 5 times slower: around 5 seconds against 1. And it too invented an author for a novel that does not exist. Look at the multiplication: `442799883` is wrong in only one digit. This is the most treacherous error, since you cannot see it by eye.

And look at Masha: «У Маши одна сестра — это она сама» (Masha has one sister, herself). The number is right, but the explanation is wrong: Masha is not her own sister. Yet our code gave a plus, because it checks only the number. An evaluation measures only what you put into it.

**How to work with this.**

- What you can compute, compute with code rather than asking the model.
- What you can check against a source, check. A confident tone is no check.
- For what matters, ask several times and see whether the answers agree.
- Remember the date: a model does not know what happened after its training.
- Before changing a model or a prompt, run your exam: otherwise an improvement cannot be told from luck.

**Learn from those who build this.** Stanford's CS224N of 2026 has a whole lecture on evaluation. Andrej Karpathy takes hallucinations apart in "Deep Dive into LLMs like ChatGPT". The TruthfulQA work showed that models repeat human misconceptions. The links are in the sources.

### Explore and practise

The lab tests you yourself: guess before you learn the truth. Click a tile and read the model's answer and its confidence. Press "I trust it" or "I do not". Only then do you see whether the answer is right, what the second model said, and how the five tries ended. Set the threshold on the chart and see how many answers it lets through.

In the program, add three questions of your own about what you know well, with a pattern of the right answer. Where did the model err and where not?

### Question

The model named 2023 as the current year with confidence 0.99, and it is now 2026. What does this show?

### Options

- Confidence shows how a text usually goes on, not whether it is true.
- The model knows the real year but gives an old one at zero temperature.
- Such confidence belongs only to right answers, so the recording is wrong.

### Answer

1

### Explanation

A model has no clock and cannot know the real year, and temperature does not change this: five tries at temperature 0.8 gave the same year. High confidence happens with wrong answers too, as we just counted. It means that the texts the model trained on said so.

### Limits

Twenty questions are very few: one question changes the result by 5%. I chose the questions to show kinds of errors, so 45% and 70% do not mean these models are right that often in general. The check patterns are crude: both the Masha answer with the wrong explanation and the odd «Оба тяжелее» got a plus. Large models usually err less, but inventions have not vanished fully. I did not measure how the same models answer in English. The answers about the year and the president were checked on 2026-11-02 and will change with time.

## Sources

- Ollama documentation, "Generate a response" (consulted 2026-11-02): `logprobs`, `think`, and `options`: [Ollama API](https://docs.ollama.com/api/generate)
- Diyi Yang, Yejin Choi, Stanford CS224N, winter 2026 (schedule read 2026-11-02): the lecture "Benchmarking and Evaluation": [CS224N](https://web.stanford.edu/class/cs224n/)
- Andrej Karpathy, "Deep Dive into LLMs like ChatGPT" (listed on his site, consulted 2026-11-02): [video](https://www.youtube.com/watch?v=7xTGNNLPyMI)
- Stephanie Lin, Jacob Hilton, Owain Evans, "TruthfulQA: Measuring How Models Mimic Human Falsehoods", arXiv:2109.07958 (2021), abstract read 2026-11-02: models repeat falsehoods learned from imitating human texts: [arXiv:2109.07958](https://arxiv.org/abs/2109.07958)
- Chuan Guo and colleagues, "On Calibration of Modern Neural Networks", arXiv:1706.04599 (2017), abstract read 2026-11-02: what calibration is, and that modern networks are poorly calibrated: [arXiv:1706.04599](https://arxiv.org/abs/1706.04599)
- Saurav Kadavath and colleagues, "Language Models (Mostly) Know What They Know", arXiv:2207.05221 (2022), abstract read 2026-11-02: larger models can be well calibrated in the right format, which is a different setting from this lesson's: [arXiv:2207.05221](https://arxiv.org/abs/2207.05221)
- Potsawee Manakul and colleagues, "SelfCheckGPT", arXiv:2303.08896 (2023), abstract read 2026-11-02: detecting hallucinations by comparing sampled answers: [arXiv:2303.08896](https://arxiv.org/abs/2303.08896)
- Lei Huang and colleagues, "A Survey on Hallucination in Large Language Models", arXiv:2311.05232 (2023), abstract read 2026-11-02: [arXiv:2311.05232](https://arxiv.org/abs/2311.05232)
- All answers in this lesson were measured for it on 2026-11-02 with Ollama 0.40.13 and are kept in `02_Areas/Programming/resources/model_mistakes_recording.json`. The lesson paraphrases these sources and does not copy their text.
