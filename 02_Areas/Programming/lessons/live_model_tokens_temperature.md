---
subject: programming
lesson_id: programming.live_model_tokens_temperature
level: advanced
languages: ru, en
source_checked: 2026-11-02
source_review_interval_days: 180
---

# Живая модель на твоём Mac: токены и температура / A live model on your Mac: tokens and temperature

## Русский

### Цель

Запустить настоящую языковую модель на своём Mac, вызвать её из своей программы на Python и самому проверить три вещи: модель это файл с числами; читает и пишет она кусочками текста, токенами; температура меняет выбор по простой формуле. Писать код с нуля не нужно: программу ты скопируешь и будешь менять в ней по одному значению. Нужно около часа. Всё работает бесплатно и без интернета.

### Идея и механизм

Урок идёт шагами. После каждого шага написано, что ты должен увидеть. Если у тебя вышло немного другое, это нормально: значит, другая версия модели или программы.

**Шаг 1. Модель это файл.** Открой Терминал: нажми `⌘` и пробел, напиши «Терминал», нажми Enter. В Терминал вводят команды. Нажми «Скопировать» у команды ниже, вставь её в Терминал через `⌘V` и нажми Enter:

```bash
ollama list
```

Ты увидишь примерно такую таблицу:

```text
NAME                ID              SIZE      MODIFIED
bge-m3:latest       790764642607    1.2 GB    7 days ago
qwen3.5:latest      d63f830f28d5    7.6 GB    7 days ago
qwen2.5-coder:7b    dae161e27b0e    4.7 GB    7 days ago
```

Каждая строка это файл на твоём диске. Мы берём `qwen2.5-coder:7b`, в нём 4,7 ГБ. Внутри лежат 7,6 миллиарда чисел. Их называют *весами* или *параметрами*. Всё, что модель «знает» и «умеет», записано только в них. *Ollama* это программа, которая загружает такой файл в память Mac и считает по нему. Интернет для этого не нужен: можешь выключить Wi-Fi и повторить следующий шаг.

**Шаг 2. Первый разговор.** Введи:

```bash
ollama run qwen2.5-coder:7b "Столица Франции?"
```

Подожди несколько секунд: первый раз модель загружается в память. Ответ будет примерно такой:

```text
Столица Франции - Париж (Paris).
```

Похоже на разговор с человеком. Дальше посмотрим, что происходит на самом деле.

**Шаг 3. Вызов из своей программы.** Ollama работает на Mac как маленький *сервер*: это программа, которая ждёт запросов и отвечает на них. Её адрес `localhost:11434`. Слово `localhost` значит «этот же компьютер», а 11434 это номер входа, *порт*. Твоя программа пошлёт ей запрос и получит ответ, оба в формате *JSON*: это обычный текст, похожий на словарь Python.

Создай папку и файл:

```bash
mkdir -p ~/ai-path && cd ~/ai-path && nano first_model.py
```

Откроется простой редактор `nano`. Скопируй программу ниже и вставь через `⌘V`. Чтобы сохранить, нажми `Ctrl` + `O`, затем Enter. Чтобы выйти, нажми `Ctrl` + `X`.

```python
import json
import math
import random
import urllib.request

MODEL = "qwen2.5-coder:7b"
PROMPT = "The capital of France is"


def ask(prompt, temperature, seed=1, tokens=1):
    body = {
        "model": MODEL,
        "prompt": prompt,
        "raw": True,  # без обёртки чата: модель просто продолжает текст
        "stream": False,  # дождаться всего ответа сразу
        "logprobs": True,  # вернуть вероятности токенов
        "top_logprobs": 5,  # и пять лучших кандидатов
        "options": {
            "temperature": temperature,
            "seed": seed,  # номер броска: тот же номер даёт тот же выбор
            "num_predict": tokens,  # сколько токенов дописать
            # выключаем другие фильтры, чтобы видеть чистую температуру
            "top_k": 0, "top_p": 1, "min_p": 0, "repeat_penalty": 1,
        },
    }
    request = urllib.request.Request(
        "http://localhost:11434/api/generate",
        json.dumps(body).encode(),
        {"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        return json.load(response)


answer = ask(PROMPT, temperature=0)
print("Токенов в запросе:", answer["prompt_eval_count"])
print("Самые вероятные следующие токены:")
for candidate in answer["logprobs"][0]["top_logprobs"]:
    probability = math.exp(candidate["logprob"])  # logprob это логарифм вероятности
    print(f"  {candidate['token']!r:10} {probability:6.1%}")
```

Запусти её:

```bash
python3 first_model.py
```

Ты должен увидеть:

```text
Токенов в запросе: 5
Самые вероятные следующие токены:
  ' Paris'    63.1%
  ' __'        4.7%
  ':\n'        4.4%
  ' ______'    4.2%
  ' a'         2.9%
```

**Что ты сейчас увидел.** Это главное в уроке. Мы ничего не спрашивали, а дали начало фразы: настройка `"raw": True` убирает обёртку чата. И модель не «ответила». Для каждого токена из своего словаря, а их 152 064, она посчитала вероятность того, что он идёт следующим. За один шаг модель делает только это. Затем один токен выбирается, дописывается к тексту, и всё повторяется. Любой разговор с ИИ состоит из таких шагов.

Посмотри на числа. ` Paris` получил 63,1 %, а второе место занял ` __`, будто это задание с пропуском. Видимо, в текстах, на которых её учили, такое встречалось часто, но это только догадка. Вероятность здесь значит не «это правда», а «так текст обычно продолжается».

**Что такое токен.** Токен это кусочек текста, который модель видит как один знак своего словаря. Это не буква и не слово. Заметь, что ` Paris` начинается с пробела: пробел входит в токен. Поменяй `PROMPT` в программе и посмотри на первую строку вывода. У этой модели получается так:

- `Hello`: 1 токен
- `hello world`: 2
- `Привет`: 3
- `The capital of France is`: 5
- `антидепрессант`: 7
- `1234567`: 7, каждая цифра отдельно
- `Столица Франции —`: 8

Слово «Париж» модель пишет тремя токенами: ` П`, `ари`, `ж`. Отсюда два настоящих следствия. Русский текст у этой модели занимает больше токенов, чем такой же по длине английский. И модель не видит букв внутри токена, поэтому считать буквы в слове ей трудно. Андрей Карпатый посвятил токенизации отдельную лекцию: многие странности моделей идут отсюда.

**Температура на маленьком примере.** Модель посчитала вероятности, но один токен ещё надо выбрать. Температура `T` решает, насколько строго держаться самых вероятных. Пусть кандидатов три: 60 %, 30 % и 10 %. Каждую вероятность возводим в степень `1/T`, а потом делим на сумму, чтобы снова вышло 100 %.

- `T = 1`: степень 1, ничего не меняется: 60 %, 30 %, 10 %.
- `T = 0,5`: степень 2. Получаем 0,36; 0,09; 0,01, сумма 0,46. После деления: 78,3 %, 19,6 %, 2,2 %. Сильный стал сильнее.
- `T = 2`: степень ½, то есть корень. Получаем 0,775; 0,548; 0,316, сумма 1,639. После деления: 47,3 %, 33,4 %, 19,3 %. Слабые подросли.
- `T = 0`: делить на ноль нельзя, поэтому просто всегда берут самого вероятного.

Теперь то же формулой: `pᵢ(T) = pᵢ^(1/T) / Σⱼ pⱼ^(1/T)`. Здесь `pᵢ` это вероятность токена номер `i`, а `Σⱼ` значит «сумма по всем токенам». Когда дойдёшь до урока о softmax, увидишь, что это то же самое, что разделить на `T` оценки модели перед softmax: в такой записи температуру дали Джеффри Хинтон и соавторы в 2015 году.

**Шаг 4. Проверка на настоящей модели.** Если всё это правда, то 63,1 % должно значить: из 200 бросков при `T = 1` токен ` Paris` выпадет примерно 126 раз. Проверим. Открой файл снова той же командой `nano first_model.py`, стрелкой вниз дойди до конца, вставь этот код, сохрани и выйди, как раньше:

```python
dice = random.Random(5)  # случайные номера бросков, один и тот же набор при каждом запуске
for temperature in (0, 0.5, 1, 1.5, 2):
    hits = 0
    for _ in range(200):
        seed = dice.randrange(1, 2**31)
        if ask(PROMPT, temperature, seed)["response"] == " Paris":
            hits += 1
    print(f"T = {temperature}: Paris — {hits} из 200")
```

Запусти снова. Программа будет работать около полутора минут: это 1000 настоящих обращений к модели. К прежним строкам добавятся такие:

```text
T = 0: Paris — 200 из 200
T = 0.5: Paris — 198 из 200
T = 1: Paris — 122 из 200
T = 1.5: Paris — 29 из 200
T = 2: Paris — 3 из 200
```

При `T = 1` выпало 122 из 200, это 61 %, рядом с посчитанными 63,1 %. На 1000 бросков у меня вышло 636, это 63,6 %. Значит, число модели не оборот речи, а настоящая вероятность. При `T = 0` токен выпал все 200 раз: выбор больше не случаен, и один и тот же текст всегда даёт одно и то же.

**Сюрприз при `T = 2`.** По примеру с тремя кандидатами лучший должен был остаться около половины. А он выпал 3 раза из 200, это 1,5 %. Формула не сломалась: просто кандидатов не три, а 152 064. У редкого токена вероятность крошечная, например 0,000001. Корень из неё равен 0,001: она выросла в тысячу раз. А у ` Paris` корень даёт 0,794 вместо 0,631, рост меньше чем в полтора раза. Редких токенов очень много, и их толпа забирает почти всю вероятность. В опыте на 1000 бросков при `T = 2` выпал 871 разный токен, и 88,7 % бросков ушли дальше 20 лучших кандидатов.

Отношение двух токенов формула предсказывает напрямую, это можно проверить. При `T = 1,5` в 1500 бросках ` Paris` выпал 241 раз, а ` __` 38 раз, отношение 6,3. Формула даёт `(0,631 / 0,047)^(1 / 1,5) = 5,6`. С учётом случайности при таком малом числе это совпадение.

Вот что пишет модель с одним и тем же началом и одним номером броска:

- `T = 0`: ` Paris. Paris is located in the northern part of France, on the`
- `T = 0,7`: пишет тест с вариантами `A. Berlin`, `B. Madrid`, `C. Paris`
- `T = 1`: ` [city name]`, то есть заготовку с пропуском
- `T = 2`: ` so boo-tناemic-and的最后一剩下_from发音中的异常演讲 Pai`, кашу из разных языков

Поэтому настоящие программы редко поднимают температуру выше 1 и ещё отрезают хвост настройками `top_k` и `top_p`. В Ollama по умолчанию `T = 0,8`, `top_k = 40`, `top_p = 0,9`. В нашей программе они выключены, чтобы видеть чистую формулу.

**Откуда берётся чат.** Поставь в программе `"raw": False` и попроси дописать `Столица Франции —`, указав `tokens=40`. Модель напишет `Столица Франции — Париж.` и остановится сама. С `"raw": True` она пишет ` Париж. Париж является крупнейшим город…`, пока не кончится лимит токенов: обрыв посреди слова получается потому, что лимит считается в токенах. Механизм тот же, разница только в служебной обёртке вокруг твоего текста. Её мы разберём в следующем уроке этого этапа.

**Учись у тех, кто это создаёт.** Андрей Карпатый, один из основателей OpenAI, записал для широкой аудитории два видео: «How I use LLMs» о том, как он сам работает с моделями, и «Deep Dive into LLMs like ChatGPT» о том, как они устроены. Лекция о токенах и первая лекция стэнфордского курса CS336 идут глубже. Ссылки в разделе источников.

### Исследуй и потренируйся

В тренажёре работает та же модель, и копировать ничего не надо. Серая полоса показывает, что посчитала модель, а цветная показывает, что выпало в настоящих бросках.

1. Нажми «Бросить 100 раз» при `T = 0`, `T = 1` и `T = 2`. На графике появятся три настоящие точки.
2. Поставь `T = 1` и понажимай «Следующий токен»: модель дописывает текст по кусочку.
3. Щёлкни по странному кандидату, например `␣__`. Текст пойдёт в другую сторону: модель продолжит любое начало.
4. Впиши своё начало фразы и сравни. У `Столица Франции —` лучший токен ` П` получает 96,4 %: модель почти уверена. У `Кошка сидела на` лучший ` л` получает 31,1 %: вариантов много.

Если Ollama выключена, тренажёр показывает записанные ответы этой же модели и прямо об этом пишет.

### Вопрос

При `T = 2` лучший токен ` Paris` выпадает намного реже, чем обещает пример с тремя кандидатами. Почему?

### Варианты

- Формула поднимает 152 тысячи редких токенов, и их толпа забирает вероятность.
- При высокой температуре модель считает всё заново и забывает про Францию.
- При `T = 2` вероятности больше не важны, и модель выбирает токены вслепую.

### Ответ

1

### Разбор

Вероятности модель считает одинаково при любой температуре: температура меняет только выбор токена, поэтому серая полоса в тренажёре стоит на месте. И вслепую выбор не идёт: в 1000 бросках при `T = 2` токен ` Paris` выпал 32 раза, а следующий за ним всего 11. Но формула поднимает редкие токены намного сильнее, чем лучший, а редких очень много.

### Границы модели

Это небольшая модель для кода, а не лучшая из существующих. У больших моделей числа другие, механизм тот же. Все числа измерены на одной версии: Ollama 0.40.13, модель из таблицы выше. Другая версия может дать другие числа. Ollama показывает вероятности только 20 лучших кандидатов, поэтому хвост мы видим только по броскам. Брать номера бросков подряд нельзя: в моём опыте при номерах 0, 1, 2… частоты редких токенов заметно искажались, поэтому программа берёт случайные. Вероятность токена не значит, что утверждение истинно: как модель уверенно ошибается, мы посмотрим дальше. Температура это не «творчество», а только разброс выбора.

## English

### Goal

Run a real language model on your Mac, call it from your own Python program, and check three things yourself: a model is a file of numbers; it reads and writes in pieces of text called tokens; temperature changes the choice by a simple formula. You do not write code from scratch: you copy a program and change one value at a time. It takes about an hour. Everything is free and works with no internet.

### Idea and mechanism

The lesson goes in steps. After each step it says what you should see. If yours differs a little, that is fine: you have another version of the model or the program.

**Step 1. A model is a file.** Open Terminal: press `⌘` and space, type "Terminal", press Enter. You enter commands in Terminal. Press Copy on the command below, paste it into Terminal with `⌘V`, and press Enter:

```bash
ollama list
```

You will see a table like this:

```text
NAME                ID              SIZE      MODIFIED
bge-m3:latest       790764642607    1.2 GB    7 days ago
qwen3.5:latest      d63f830f28d5    7.6 GB    7 days ago
qwen2.5-coder:7b    dae161e27b0e    4.7 GB    7 days ago
```

Each row is a file on your disk. We take `qwen2.5-coder:7b`, which is 4.7 GB. Inside are 7.6 billion numbers. They are called *weights* or *parameters*. All that the model "knows" and "can do" is stored only in them. *Ollama* is a program that loads such a file into your Mac's memory and computes with it. This needs no internet: you can switch Wi-Fi off and repeat the next step.

**Step 2. The first conversation.** Enter:

```bash
ollama run qwen2.5-coder:7b "Столица Франции?"
```

Wait a few seconds: the first time, the model loads into memory. The answer will be something like this:

```text
Столица Франции - Париж (Paris).
```

It looks like talking to a person. Next we look at what really happens.

**Step 3. A call from your own program.** Ollama runs on your Mac as a small *server*: a program that waits for requests and answers them. Its address is `localhost:11434`. The word `localhost` means "this same computer", and 11434 is the number of an entrance, a *port*. Your program sends it a request and gets an answer, both in *JSON*: plain text that looks like a Python dictionary.

Create a folder and a file:

```bash
mkdir -p ~/ai-path && cd ~/ai-path && nano first_model.py
```

The simple editor `nano` opens. Copy the program below and paste it with `⌘V`. To save, press `Ctrl` + `O`, then Enter. To quit, press `Ctrl` + `X`.

```python
import json
import math
import random
import urllib.request

MODEL = "qwen2.5-coder:7b"
PROMPT = "The capital of France is"


def ask(prompt, temperature, seed=1, tokens=1):
    body = {
        "model": MODEL,
        "prompt": prompt,
        "raw": True,  # no chat wrapper: the model simply continues the text
        "stream": False,  # wait for the whole answer at once
        "logprobs": True,  # return the token probabilities
        "top_logprobs": 5,  # and the five best candidates
        "options": {
            "temperature": temperature,
            "seed": seed,  # the throw number: the same number gives the same choice
            "num_predict": tokens,  # how many tokens to write
            # other filters are off, to see pure temperature
            "top_k": 0, "top_p": 1, "min_p": 0, "repeat_penalty": 1,
        },
    }
    request = urllib.request.Request(
        "http://localhost:11434/api/generate",
        json.dumps(body).encode(),
        {"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=180) as response:
        return json.load(response)


answer = ask(PROMPT, temperature=0)
print("Tokens in the prompt:", answer["prompt_eval_count"])
print("The most likely next tokens:")
for candidate in answer["logprobs"][0]["top_logprobs"]:
    probability = math.exp(candidate["logprob"])  # logprob is the logarithm of the probability
    print(f"  {candidate['token']!r:10} {probability:6.1%}")
```

Run it:

```bash
python3 first_model.py
```

You should see:

```text
Tokens in the prompt: 5
The most likely next tokens:
  ' Paris'    63.1%
  ' __'        4.7%
  ':\n'        4.4%
  ' ______'    4.2%
  ' a'         2.9%
```

**What you just saw.** This is the heart of the lesson. We asked nothing and only gave the start of a phrase: the setting `"raw": True` removes the chat wrapper. And the model did not "answer". For each token in its dictionary, all 152,064 of them, it computed the probability that it comes next. In one step a model does only this. Then one token is chosen and added to the text, and everything repeats. Any conversation with an AI is made of such steps.

Look at the numbers. ` Paris` got 63.1%, while second place went to ` __`, as if this were a fill-in-the-blank task. Probably such tasks were common in the texts it trained on, but that is only a guess. A probability here means not "this is true" but "this is how the text usually goes on".

**What a token is.** A token is a piece of text that the model sees as one sign of its dictionary. It is neither a letter nor a word. Notice that ` Paris` begins with a space: the space is part of the token. Change `PROMPT` in the program and look at the first line of output. With this model you get:

- `Hello`: 1 token
- `hello world`: 2
- `Привет`: 3
- `The capital of France is`: 5
- `антидепрессант`: 7
- `1234567`: 7, each digit alone
- `Столица Франции —`: 8

The word «Париж» takes the model three tokens: ` П`, `ари`, `ж`. This has two real consequences. Russian text takes more tokens with this model than English text of the same length. And the model does not see letters inside a token, so counting the letters of a word is hard for it. Andrej Karpathy gave tokenization a whole lecture: many oddities of models come from here.

**Temperature on a small example.** The model has computed probabilities, but one token must still be chosen. Temperature `T` decides how strictly to keep to the most likely ones. Say there are three candidates: 60%, 30%, and 10%. Raise each probability to the power `1/T`, then divide by the sum to get 100% again.

- `T = 1`: power 1, nothing changes: 60%, 30%, 10%.
- `T = 0.5`: power 2. We get 0.36, 0.09, 0.01, with sum 0.46. After dividing: 78.3%, 19.6%, 2.2%. The strong got stronger.
- `T = 2`: power ½, that is, the square root. We get 0.775, 0.548, 0.316, with sum 1.639. After dividing: 47.3%, 33.4%, 19.3%. The weak grew.
- `T = 0`: we cannot divide by zero, so the most likely one is simply always taken.

Now the same as a formula: `pᵢ(T) = pᵢ^(1/T) / Σⱼ pⱼ^(1/T)`. Here `pᵢ` is the probability of token number `i`, and `Σⱼ` means "the sum over all tokens". When you reach the softmax lesson, you will see that this equals dividing the model's scores by `T` before softmax: Geoffrey Hinton and colleagues wrote temperature that way in 2015.

**Step 4. A check on the real model.** If all this is true, then 63.1% must mean: out of 200 throws at `T = 1`, the token ` Paris` falls about 126 times. Let us check. Open the file again with the same command `nano first_model.py`, go to the end with the down arrow, paste this code, then save and quit as before:

```python
dice = random.Random(5)  # random throw numbers, the same set on every run
for temperature in (0, 0.5, 1, 1.5, 2):
    hits = 0
    for _ in range(200):
        seed = dice.randrange(1, 2**31)
        if ask(PROMPT, temperature, seed)["response"] == " Paris":
            hits += 1
    print(f"T = {temperature}: Paris {hits} of 200")
```

Run it again. The program works for about a minute and a half: that is 1000 real calls to the model. These lines join the earlier ones:

```text
T = 0: Paris 200 of 200
T = 0.5: Paris 198 of 200
T = 1: Paris 122 of 200
T = 1.5: Paris 29 of 200
T = 2: Paris 3 of 200
```

At `T = 1` it fell 122 times out of 200, which is 61%, close to the computed 63.1%. In 1000 throws I got 636, which is 63.6%. So the model's number is no figure of speech but a real probability. At `T = 0` the token fell all 200 times: the choice is no longer random, and the same text always gives the same result.

**The surprise at `T = 2`.** By the three-candidate example, the best should have stayed near half. Yet it fell 3 times out of 200, which is 1.5%. The formula is not broken: there are simply not three candidates but 152,064. A rare token has a tiny probability, say 0.000001. Its square root is 0.001: it grew a thousand times. For ` Paris` the root gives 0.794 instead of 0.631, growth of less than one and a half times. Rare tokens are very many, and their crowd takes nearly all the probability. In an experiment of 1000 throws at `T = 2`, 871 different tokens fell, and 88.7% of the throws went beyond the 20 best candidates.

The formula predicts the ratio of two tokens directly, and this can be checked. At `T = 1.5`, in 1500 throws, ` Paris` fell 241 times and ` __` 38 times, a ratio of 6.3. The formula gives `(0.631 / 0.047)^(1 / 1.5) = 5.6`. Given the randomness at such small counts, this is agreement.

Here is what the model writes with the same start and the same throw number:

- `T = 0`: ` Paris. Paris is located in the northern part of France, on the`
- `T = 0.7`: writes a test with the options `A. Berlin`, `B. Madrid`, `C. Paris`
- `T = 1`: ` [city name]`, that is, a template with a blank
- `T = 2`: ` so boo-tناemic-and的最后一剩下_from发音中的异常演讲 Pai`, a mash of several languages

So real programs rarely raise the temperature above 1, and they also cut off the tail with the `top_k` and `top_p` settings. In Ollama the defaults are `T = 0.8`, `top_k = 40`, `top_p = 0.9`. In our program they are off, to see the pure formula.

**Where chat comes from.** Set `"raw": False` in the program and ask it to continue `Столица Франции —` with `tokens=40`. The model writes `Столица Франции — Париж.` and stops by itself. With `"raw": True` it writes ` Париж. Париж является крупнейшим город…` until the token limit ends: it breaks off mid-word because the limit counts tokens. The mechanism is the same, and the only difference is a service wrapper around your text. We take it apart in the next lesson of this stage.

**Learn from those who build this.** Andrej Karpathy, a founding member of OpenAI, recorded two videos for a wide audience: "How I use LLMs" on how he works with models himself, and "Deep Dive into LLMs like ChatGPT" on how they are built. His lecture on tokens and the first lecture of Stanford's CS336 go deeper. The links are in the sources.

### Explore and practise

The lab runs the same model, and there is nothing to copy. The grey bar shows what the model computed, and the coloured bar shows what fell in real throws.

1. Press "Throw 100 times" at `T = 0`, `T = 1`, and `T = 2`. Three real points appear on the chart.
2. Set `T = 1` and press "Next token" a few times: the model continues the text piece by piece.
3. Click an odd candidate, such as `␣__`. The text goes another way: the model continues any start.
4. Type your own start of a phrase and compare. With `Столица Франции —` the best token ` П` gets 96.4%: the model is nearly sure. With `Кошка сидела на` the best ` л` gets 31.1%: there are many options.

If Ollama is off, the lab shows recorded answers of this same model and says so plainly.

### Question

At `T = 2` the best token ` Paris` falls far less often than the three-candidate example promises. Why?

### Options

- The formula raises 152 thousand rare tokens, and their crowd takes the probability.
- At high temperature the model recomputes everything and forgets about France.
- At `T = 2` probabilities stop mattering, and the model picks tokens blindly.

### Answer

1

### Explanation

The model computes probabilities the same way at any temperature: temperature changes only the choice of token, so the grey bar in the lab stays put. And the choice is not blind: in 1000 throws at `T = 2` the token ` Paris` fell 32 times and the next one only 11. But the formula raises rare tokens far more than the best one, and the rare ones are very many.

### Limits

This is a small model for code, not the best that exists. Large models have other numbers and the same mechanism. All numbers were measured on one version: Ollama 0.40.13 and the model in the table above. Another version may give other numbers. Ollama shows probabilities only for the 20 best candidates, so we see the tail only through throws. Throw numbers must not run in order: in my experiment with numbers 0, 1, 2… the rare tokens' frequencies were noticeably distorted, so the program takes random ones. A token's probability does not mean a statement is true: how a model errs confidently comes later. Temperature is not "creativity", only the spread of the choice.

## Sources

- Ollama documentation, "Generate a response" (consulted 2026-11-02): the fields `raw`, `logprobs`, `top_logprobs`, `temperature`, `seed`, `prompt_eval_count`, and `eval_count`: [Ollama API](https://docs.ollama.com/api/generate)
- Ollama documentation, Modelfile parameters (consulted 2026-11-02): the defaults temperature 0.8, top_k 40, top_p 0.9: [Modelfile](https://docs.ollama.com/modelfile)
- Binyuan Hui and colleagues, "Qwen2.5-Coder Technical Report", arXiv:2409.12186 (2024), abstract read 2026-11-02: the model family used here, pretrained further for code: [arXiv:2409.12186](https://arxiv.org/abs/2409.12186)
- Ari Holtzman, Jan Buys, Li Du, Maxwell Forbes, Yejin Choi, "The Curious Case of Neural Text Degeneration", arXiv:1904.09751 (2019), ICLR 2020, abstract read 2026-11-02: decoding methods, and sampling from a nucleus that cuts off the unreliable tail: [arXiv:1904.09751](https://arxiv.org/abs/1904.09751)
- Geoffrey Hinton, Oriol Vinyals, Jeff Dean, "Distilling the Knowledge in a Neural Network", arXiv:1503.02531 (2015), section 2, equation (1), read 2026-11-02 in the HTML version: softmax with temperature, qᵢ = exp(zᵢ/T) / Σⱼ exp(zⱼ/T), where a higher T gives a softer distribution: [arXiv:1503.02531](https://arxiv.org/abs/1503.02531)
- Andrej Karpathy, lectures listed on his site (consulted 2026-11-02): [How I use LLMs](https://www.youtube.com/watch?v=EWvNQjAaOHw), [Deep Dive into LLMs like ChatGPT](https://www.youtube.com/watch?v=7xTGNNLPyMI), and "Let's build the GPT Tokenizer" in [Neural Networks: Zero to Hero](https://karpathy.ai/zero-to-hero.html), which explains why tokenization causes many oddities of models
- Tatsunori Hashimoto, Percy Liang, Stanford CS336 "Language Modeling from Scratch", spring 2026 (schedule read 2026-11-02): lecture 1 is the overview and tokenization: [CS336](https://cs336.stanford.edu/)
- All model numbers in this lesson were measured for it on 2026-11-02 with Ollama 0.40.13 and `qwen2.5-coder:7b`; they are kept in `02_Areas/Programming/resources/live_model_recording.json`. The lesson paraphrases these sources and does not copy their text.
