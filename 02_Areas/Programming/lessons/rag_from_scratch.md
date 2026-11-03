---
subject: programming
lesson_id: programming.rag_from_scratch
level: advanced
languages: ru, en
source_checked: 2026-11-03
source_review_interval_days: 365
---

# RAG с нуля: поиск и ответ / RAG from scratch: search and answer

## Русский

### Цель

Собрать весь RAG своими руками без библиотек: нарезать текст, получить векторы от `bge-m3`, искать, отвечать и честно измерить качество поиска. Нужно около 45 минут.

### Идея и механизм

**Шаг 1. Зачем это нужно.** Модель не знает твоих файлов. Спросишь о них, и она правдоподобно придумает. Ниже в опыте о векторе `bge-m3` она скажет: «три числа». Настоящее значение 1024. **RAG** (retrieval-augmented generation) это простая идея: сначала найди нужные куски текста, а потом дай их модели вместе с вопросом.

Четыре части: нарезать текст на **куски**, превратить куски в векторы, по вопросу найти самые близкие, ответить по найденному. Твой тьютор в этом приложении устроен так же.

**Шаг 2. Близость руками.** Косинус угла между векторами `a = (1; 0)` и `b = (0,8; 0,6)`: произведение `1 · 0,8 + 0 · 0,6 = 0,8`, длины по 1, значит, косинус `0,8`. У одинаковых по смыслу текстов он ближе к 1. Смысл векторов разбирался в уроке об эмбеддингах.

**Шаг 3. Запусти поиск.** Текст это 10 заметок по темам курса и одна о коте Барсике. Каждую режем на предложения. Создай файл `nano ~/ai-path/rag.py`, вставь и запусти. Нужна запущенная Ollama с `bge-m3`. Запись опыта лежит в уроке.

```python
import json
import math
import re
import urllib.request

DOCS = ["Токенизатор режет текст на части. BPE начинает с отдельных байтов и раз за разом склеивает самую частую пару. Поэтому редкие слова дробятся на много кусков.",
        "Внимание считает для каждого токена запрос, ключ и значение. Близость запроса и ключа даёт вес. Маска закрывает будущие токены, чтобы модель не подглядывала.",
        "Переобучение видно по двум кривым. Ошибка на обучении падает, а ошибка на отложенных данных растёт. Лечат большими данными, ранней остановкой и ослаблением весов.",
        "Градиентный спуск идёт против производной. Слишком большой шаг перепрыгивает долину и расходится. Слишком маленький шаг ползёт почти вечно.",
        "Температура делит логиты перед softmax. Низкая температура почти всегда берёт самый вероятный токен. Высокая делает выбор разнообразнее и чаще ошибается.",
        "Кот Барсик живёт у владельца курса и спит на клавиатуре. Он родился в марте. Его любимая еда это варёная курица.",
        "UCB1 добавляет к оценке надбавку за незнание. Автомат, который пробовали редко, получает большой бонус. Рост сожаления у него логарифмический.",
        "Уравнение Беллмана связывает ценность клетки с ценностью соседей. Итерация ценности повторяет это обновление для всех клеток. Скидка уменьшает далёкие награды.",
        "Контекст чата собирается из всех прошлых сообщений. Если их больше окна, старые сообщения отбрасываются. Поэтому модель может забыть начало разговора.",
        "Эмбеддинг это вектор, близкий у похожих по смыслу текстов. Близость часто считают косинусом угла. Модель bge-m3 выдаёт векторы из 1024 чисел."]
QUESTIONS = [("Почему длинные необычные слова превращаются в кучу токенов?", 0),
             ("Как не дать модели смотреть на следующие слова при обучении?", 1),
             ("По каким графикам понять, что сеть заучила примеры, а не правило?", 2),
             ("Что будет, если поставить чересчур большой learning rate?", 3),
             ("Как сделать ответы модели более предсказуемыми?", 4),
             ("Чем кормить Барсика?", 5),
             ("Что такое UCB1?", 6),
             ("Почему языковая модель перестаёт помнить, о чём говорили час назад?", 8),
             ("Сколько чисел в векторе bge-m3?", 9)]


def post(path, body):
    request = urllib.request.Request("http://localhost:11434/api/" + path, json.dumps(body).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=900) as response:
        return json.load(response)


def embed(texts):
    return post("embed", {"model": "bge-m3", "input": texts})["embeddings"]


def cosine(a, b):
    return sum(x * y for x, y in zip(a, b)) / math.sqrt(sum(x * x for x in a) * sum(y * y for y in b))


def sentences(doc):
    return [part.strip() + "." for part in doc.split(".") if part.strip()]


CHUNKS = [(i, s) for i, doc in enumerate(DOCS) for s in sentences(doc)]
vectors = embed([s for _, s in CHUNKS])
asked = embed([q for q, _ in QUESTIONS])
print("chunks", len(CHUNKS), "vector length", len(vectors[0]))
top = sorted(range(len(CHUNKS)), key=lambda c: -cosine(asked[0], vectors[c]))[:3]
for c in top:
    print(round(cosine(asked[0], vectors[c]), 3), CHUNKS[c][1])
```

```output
chunks 30 vector length 1024
0.681 Поэтому редкие слова дробятся на много кусков.
0.627 Токенизатор режет текст на части.
0.55 Низкая температура почти всегда берёт самый вероятный токен.
```

Вопрос был такой: «Почему длинные необычные слова превращаются в кучу токенов?». Первым нашёлся кусок «редкие слова дробятся на много кусков». Общих слов почти нет, а смысл совпал. Обрати внимание на третье место: кусок о температуре получил `0,55`. Близость никогда не равна нулю, поэтому **что-то найдётся всегда**, даже если ответа нет.

**Шаг 4. Измеряй поиск.** Глаза обманывают. Возьмём 9 вопросов, для каждого известно, какая заметка верна, и найдём место верного куска в выдаче. Отсчёт с нуля, значит, `0` это первое место. Сравним три поиска: по векторам, по общим словам и смесь обоих. Смесь складывает `1 / (60 + место)` из двух списков, это слияние рангов. Допиши и запусти.

```python
def words(text):
    return set(re.findall(r"\w+", text.lower()))


def by_vector(q):
    return sorted(range(len(CHUNKS)), key=lambda c: -cosine(asked[q], vectors[c]))


def by_words(q):
    return sorted(range(len(CHUNKS)), key=lambda c: -len(words(QUESTIONS[q][0]) & words(CHUNKS[c][1])))


def by_both(q):
    first, second = by_vector(q), by_words(q)
    return sorted(range(len(CHUNKS)), key=lambda c: -(1 / (60 + first.index(c)) + 1 / (60 + second.index(c))))


def score(rank):
    places = []
    for q, (_, gold) in enumerate(QUESTIONS):
        places.append(next(i for i, c in enumerate(rank(q)) if CHUNKS[c][0] == gold))
    n = len(places)
    return places, round(sum(p < 1 for p in places) / n, 2), round(sum(p < 3 for p in places) / n, 2), round(sum(1 / (p + 1) for p in places) / n, 2)


print("search, place of the right chunk per question, found at 1, found at 3, MRR")
for name, rank in (("vector", by_vector), ("words", by_words), ("both", by_both)):
    print(name, *score(rank))
```

```output
search, place of the right chunk per question, found at 1, found at 3, MRR
vector [0, 0, 0, 3, 4, 0, 0, 0, 0] 0.78 0.78 0.83
words [0, 3, 1, 0, 12, 15, 0, 1, 0] 0.44 0.67 0.6
both [0, 0, 0, 0, 7, 4, 0, 0, 0] 0.78 0.78 0.81
```

**MRR** считается как среднее от `1 / (место + 1)`. Для векторов руками: семь первых мест дают по `1`, место 3 даёт `1/4`, место 4 даёт `1/5`. Сумма `7 + 0,25 + 0,2 = 7,45`, делим на 9, выходит `0,83`. Совпало.

Векторы находят верный кусок первым в 78 % вопросов, слова в 44 %. На вопросе «Чем кормить Барсика?» слова ставят верный кусок на 15-е место: в нём написано «еда», а не «кормить». А вот смесь тут **не лучше** векторов, `0,81` против `0,83`, хотя её часто советуют. На больших базах с кодами и редкими именами она обычно помогает, но на твоих данных это нужно мерить. Девять вопросов это мало, и разница в `0,02` ничего не значит: вспомни урок об оценке.

**Шаг 5. Ответ.** Допиши и запусти. Спросим с поиском и без него. Модель получает правило: отвечать только по тексту, а если там нет ответа, так и сказать.

```python
def answer(question, context=None):
    rule = "Отвечай коротко, одним предложением."
    if context:
        rule += " Используй только этот текст, а если ответа там нет, напиши: нет в тексте.\nТекст:\n" + context
    reply = post("chat", {"model": "qwen2.5-coder:7b", "stream": False, "options": {"seed": 1, "temperature": 0, "num_predict": 80},
                          "messages": [{"role": "system", "content": rule}, {"role": "user", "content": question}]})
    return reply["message"]["content"].strip().replace("`", "'")


def retrieve(question_index, k=3):
    return "\n".join(CHUNKS[c][1] for c in by_vector(question_index)[:k])


for q in (5, 8):
    print("Q:", QUESTIONS[q][0])
    print(" no search:", answer(QUESTIONS[q][0]))
    print(" search:", answer(QUESTIONS[q][0], retrieve(q)))
question = "Как зовут собаку владельца курса?"
hit = embed([question])[0]
best = sorted(range(len(CHUNKS)), key=lambda c: -cosine(hit, vectors[c]))[:3]
print("Q:", question)
print(" no search:", answer(question))
print(" search:", answer(question, "\n".join(CHUNKS[c][1] for c in best)), "| best similarity", round(cosine(hit, vectors[best[0]]), 3))
```

```output
Q: Чем кормить Барсика?
 no search: Кормить Барсика можно кормом для кошек, в соответствии с рекомендациями ветеринара.
 search: Варёная курица.
Q: Сколько чисел в векторе bge-m3?
 no search: В векторе bge-m3 три числа.
 search: 1024
Q: Как зовут собаку владельца курса?
 no search: Извините, но я не могу ответить на этот вопрос, так как у меня нет информации о конкретном курсе или его владельце.
 search: нет в тексте | best similarity 0.643
```

Без поиска модель придумывает: советует корм от ветеринара и называет «три числа». С поиском отвечает «Варёная курица» и `1024`. На вопросе о собаке, которой нет в текстах, она верно пишет «нет в тексте». Но заметь число: самая большая близость `0,643`, почти как у верного куска в шаге 3, где было `0,681`. **Порог по близости не отличит хороший поиск от плохого.** Отказ здесь держится на послушании модели, и другая модель может на этом месте выдумать.

**Шаг 6. Что ломается на деле.** Куски слишком мелкие теряют смысл, слишком крупные разбавляют его. Таблицы и код режутся плохо. Вопрос может требовать двух кусков сразу. Текст с просьбой внутри может подменить инструкции: об этом урок о безопасности. Поэтому сначала измеряй поиск, а уже потом ответы: если куска нет, модель не поможет.

**Учись у тех, кто это создаёт.** Статья [Lewis и др.](https://arxiv.org/abs/2005.11401) ввела само слово RAG. Лекция об агентах и RAG в [Stanford CS224N](https://web.stanford.edu/class/cs224n/). Попробуй и настоящие тексты: замени `DOCS` на чтение своих файлов из `02_Areas/Programming/lessons`.

### Исследуй и потренируйся

В тренажёре настоящие близости этого опыта. Выбирай вопрос и способ поиска, двигай число кусков и смотри, что попадает в ответ. Верный кусок подсвечен.

В программе собери заметки в куски по два предложения. Какое станет MRR? Сначала запиши свой прогноз.

### Вопрос

Почему нельзя решить, что ответа в базе нет, просто по малой близости?

### Варианты

- Близость есть у любых текстов, и у неверных кусков она бывает почти как у верных.
- Близость считается только для верных кусков, поэтому у неверных её просто нет.
- Близость нельзя сравнивать между вопросами, так как векторы вопросов разной длины.

### Ответ

1

### Разбор

Косинус считается для любой пары текстов. В опыте кусок без ответа получил `0,643`, а верный кусок на другой вопрос `0,681`. Векторы `bge-m3` у всех текстов одной длины, 1024 числа. Поэтому порог тут плохо помогает, и нужна проверка ответа.

### Границы модели

Всего 10 заметок и 9 вопросов, и я написал их сам, поэтому числа нужны только для понимания метода. В настоящих базах кусков тысячи, и нужен быстрый приближённый поиск. Здесь нет переранжирования и обработки таблиц. Ответ зависит от модели и зерна. Округление векторов в записи немного меняет близости, это не меняет выводов.

## English

### Goal

Build all of RAG by hand without libraries: cut text, get vectors from `bge-m3`, search, answer, and honestly measure search quality. It takes about 45 minutes.

### Idea and mechanism

**Step 1. Why this is needed.** A model does not know your files. Ask about them and it plausibly makes things up. In the experiment below it says of the `bge-m3` vector: "three numbers". The real value is 1024. **RAG** (retrieval-augmented generation) is a simple idea: first find the needed pieces of text, then give them to the model along with the question.

Four parts: cut the text into **chunks**, turn chunks into vectors, find the closest ones for a question, answer from what was found. Your tutor in this app works the same way.

**Step 2. Closeness by hand.** The cosine of the angle between vectors `a = (1; 0)` and `b = (0.8; 0.6)`: the product `1 · 0.8 + 0 · 0.6 = 0.8`, each length is 1, so the cosine is `0.8`. For texts alike in meaning it is closer to 1. The embeddings lesson explained the meaning of the vectors.

**Step 3. Run a search.** The text is 10 notes on course topics, one of them about Barsik the cat. Each is cut into sentences. Create the file `nano ~/ai-path/rag.py`, paste and run it. Ollama with `bge-m3` must be running. The lesson holds a recording of the experiment.

```python
import json
import math
import re
import urllib.request

DOCS = ["Токенизатор режет текст на части. BPE начинает с отдельных байтов и раз за разом склеивает самую частую пару. Поэтому редкие слова дробятся на много кусков.",
        "Внимание считает для каждого токена запрос, ключ и значение. Близость запроса и ключа даёт вес. Маска закрывает будущие токены, чтобы модель не подглядывала.",
        "Переобучение видно по двум кривым. Ошибка на обучении падает, а ошибка на отложенных данных растёт. Лечат большими данными, ранней остановкой и ослаблением весов.",
        "Градиентный спуск идёт против производной. Слишком большой шаг перепрыгивает долину и расходится. Слишком маленький шаг ползёт почти вечно.",
        "Температура делит логиты перед softmax. Низкая температура почти всегда берёт самый вероятный токен. Высокая делает выбор разнообразнее и чаще ошибается.",
        "Кот Барсик живёт у владельца курса и спит на клавиатуре. Он родился в марте. Его любимая еда это варёная курица.",
        "UCB1 добавляет к оценке надбавку за незнание. Автомат, который пробовали редко, получает большой бонус. Рост сожаления у него логарифмический.",
        "Уравнение Беллмана связывает ценность клетки с ценностью соседей. Итерация ценности повторяет это обновление для всех клеток. Скидка уменьшает далёкие награды.",
        "Контекст чата собирается из всех прошлых сообщений. Если их больше окна, старые сообщения отбрасываются. Поэтому модель может забыть начало разговора.",
        "Эмбеддинг это вектор, близкий у похожих по смыслу текстов. Близость часто считают косинусом угла. Модель bge-m3 выдаёт векторы из 1024 чисел."]
QUESTIONS = [("Почему длинные необычные слова превращаются в кучу токенов?", 0),
             ("Как не дать модели смотреть на следующие слова при обучении?", 1),
             ("По каким графикам понять, что сеть заучила примеры, а не правило?", 2),
             ("Что будет, если поставить чересчур большой learning rate?", 3),
             ("Как сделать ответы модели более предсказуемыми?", 4),
             ("Чем кормить Барсика?", 5),
             ("Что такое UCB1?", 6),
             ("Почему языковая модель перестаёт помнить, о чём говорили час назад?", 8),
             ("Сколько чисел в векторе bge-m3?", 9)]


def post(path, body):
    request = urllib.request.Request("http://localhost:11434/api/" + path, json.dumps(body).encode(), {"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=900) as response:
        return json.load(response)


def embed(texts):
    return post("embed", {"model": "bge-m3", "input": texts})["embeddings"]


def cosine(a, b):
    return sum(x * y for x, y in zip(a, b)) / math.sqrt(sum(x * x for x in a) * sum(y * y for y in b))


def sentences(doc):
    return [part.strip() + "." for part in doc.split(".") if part.strip()]


CHUNKS = [(i, s) for i, doc in enumerate(DOCS) for s in sentences(doc)]
vectors = embed([s for _, s in CHUNKS])
asked = embed([q for q, _ in QUESTIONS])
print("chunks", len(CHUNKS), "vector length", len(vectors[0]))
top = sorted(range(len(CHUNKS)), key=lambda c: -cosine(asked[0], vectors[c]))[:3]
for c in top:
    print(round(cosine(asked[0], vectors[c]), 3), CHUNKS[c][1])
```

```output
chunks 30 vector length 1024
0.681 Поэтому редкие слова дробятся на много кусков.
0.627 Токенизатор режет текст на части.
0.55 Низкая температура почти всегда берёт самый вероятный токен.
```

The question was "Почему длинные необычные слова превращаются в кучу токенов?" ("Why do long unusual words turn into a heap of tokens?"). First came the chunk saying rare words split into many pieces. They share almost no words, yet the meaning matched. Note the third place: a chunk on temperature got `0.55`. Closeness is never zero, so **something is always found**, even when there is no answer.

**Step 4. Measure the search.** Eyes deceive. Take 9 questions, for each the right note is known, and find the place of the right chunk in the results. Counting from zero, `0` is first place. We compare three searches: by vectors, by shared words, and a mix of both. The mix adds `1 / (60 + place)` from the two lists, which is rank fusion. Add this and run it.

```python
def words(text):
    return set(re.findall(r"\w+", text.lower()))


def by_vector(q):
    return sorted(range(len(CHUNKS)), key=lambda c: -cosine(asked[q], vectors[c]))


def by_words(q):
    return sorted(range(len(CHUNKS)), key=lambda c: -len(words(QUESTIONS[q][0]) & words(CHUNKS[c][1])))


def by_both(q):
    first, second = by_vector(q), by_words(q)
    return sorted(range(len(CHUNKS)), key=lambda c: -(1 / (60 + first.index(c)) + 1 / (60 + second.index(c))))


def score(rank):
    places = []
    for q, (_, gold) in enumerate(QUESTIONS):
        places.append(next(i for i, c in enumerate(rank(q)) if CHUNKS[c][0] == gold))
    n = len(places)
    return places, round(sum(p < 1 for p in places) / n, 2), round(sum(p < 3 for p in places) / n, 2), round(sum(1 / (p + 1) for p in places) / n, 2)


print("search, place of the right chunk per question, found at 1, found at 3, MRR")
for name, rank in (("vector", by_vector), ("words", by_words), ("both", by_both)):
    print(name, *score(rank))
```

```output
search, place of the right chunk per question, found at 1, found at 3, MRR
vector [0, 0, 0, 3, 4, 0, 0, 0, 0] 0.78 0.78 0.83
words [0, 3, 1, 0, 12, 15, 0, 1, 0] 0.44 0.67 0.6
both [0, 0, 0, 0, 7, 4, 0, 0, 0] 0.78 0.78 0.81
```

**MRR** is the mean of `1 / (place + 1)`. For vectors by hand: seven first places give `1` each, place 3 gives `1/4`, place 4 gives `1/5`. The sum is `7 + 0.25 + 0.2 = 7.45`, divided by 9 gives `0.83`. It matches.

Vectors find the right chunk first in 78 % of questions, words in 44 %. On "Чем кормить Барсика?" ("What to feed Barsik?") words put the right chunk in 15th place: it says "еда" (food), not "кормить" (feed). But the mix here is **no better** than vectors, `0.81` against `0.83`, though it is often advised. On large bases with codes and rare names it usually helps, but on your data this must be measured. Nine questions are few, and a `0.02` difference means nothing: recall the evaluation lesson.

**Step 5. The answer.** Add this and run it. We ask with search and without. The model gets a rule: answer only from the text, and if the answer is not there, say so.

```python
def answer(question, context=None):
    rule = "Отвечай коротко, одним предложением."
    if context:
        rule += " Используй только этот текст, а если ответа там нет, напиши: нет в тексте.\nТекст:\n" + context
    reply = post("chat", {"model": "qwen2.5-coder:7b", "stream": False, "options": {"seed": 1, "temperature": 0, "num_predict": 80},
                          "messages": [{"role": "system", "content": rule}, {"role": "user", "content": question}]})
    return reply["message"]["content"].strip().replace("`", "'")


def retrieve(question_index, k=3):
    return "\n".join(CHUNKS[c][1] for c in by_vector(question_index)[:k])


for q in (5, 8):
    print("Q:", QUESTIONS[q][0])
    print(" no search:", answer(QUESTIONS[q][0]))
    print(" search:", answer(QUESTIONS[q][0], retrieve(q)))
question = "Как зовут собаку владельца курса?"
hit = embed([question])[0]
best = sorted(range(len(CHUNKS)), key=lambda c: -cosine(hit, vectors[c]))[:3]
print("Q:", question)
print(" no search:", answer(question))
print(" search:", answer(question, "\n".join(CHUNKS[c][1] for c in best)), "| best similarity", round(cosine(hit, vectors[best[0]]), 3))
```

```output
Q: Чем кормить Барсика?
 no search: Кормить Барсика можно кормом для кошек, в соответствии с рекомендациями ветеринара.
 search: Варёная курица.
Q: Сколько чисел в векторе bge-m3?
 no search: В векторе bge-m3 три числа.
 search: 1024
Q: Как зовут собаку владельца курса?
 no search: Извините, но я не могу ответить на этот вопрос, так как у меня нет информации о конкретном курсе или его владельце.
 search: нет в тексте | best similarity 0.643
```

Without search the model makes things up: it advises food from a vet and names "three numbers". With search it says "Варёная курица" (boiled chicken) and `1024`. On the question about a dog absent from the texts it rightly writes "нет в тексте" (not in the text). But note the number: the highest closeness is `0.643`, nearly as much as the right chunk in step 3, which had `0.681`. **A closeness threshold will not tell good search from bad.** The refusal here rests on the model's obedience, and another model may invent an answer at this point.

**Step 6. What breaks in practice.** Chunks too small lose meaning; too large dilute it. Tables and code cut badly. A question may need two chunks at once. Text with a request inside can override instructions: see the safety lesson. So measure search first and answers afterwards: if the chunk is absent, the model will not help.

**Learn from the people who build this.** The paper by [Lewis et al.](https://arxiv.org/abs/2005.11401) introduced the word RAG. The lecture on agents and RAG in [Stanford CS224N](https://web.stanford.edu/class/cs224n/). Try real texts too: replace `DOCS` with reading your files from `02_Areas/Programming/lessons`.

### Explore and practise

The lab holds this experiment's real closeness values. Pick a question and a search method, move the number of chunks, and see what enters the answer. The right chunk is highlighted.

In the program, group the notes into chunks of two sentences. What will MRR become? Write down your prediction first.

### Question

Why can you not decide that the base lacks an answer simply from low closeness?

### Options

- Any texts have closeness, and wrong chunks can have nearly as much as right ones.
- Closeness is computed only for right chunks, so wrong ones simply do not have any.
- Closeness cannot be compared across questions, as question vectors differ in length.

### Answer

1

### Explanation

A cosine exists for any pair of texts. In the experiment a chunk without the answer got `0.643`, and a right chunk for another question `0.681`. All `bge-m3` vectors have one length, 1024 numbers. So a threshold helps little here, and the answer needs checking.

### Limits

Just 10 notes and 9 questions, which I wrote myself, so the numbers serve only to explain the method. Real bases hold thousands of chunks and need fast approximate search. There is no reranking or table handling here. The answer depends on the model and seed. Rounding vectors in the recording shifts closeness slightly, without changing conclusions.

## Sources

- Patrick Lewis et al., "Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks", arXiv:2005.11401 (2020): [arXiv:2005.11401](https://arxiv.org/abs/2005.11401)
- Gordon V. Cormack, Charles L. A. Clarke, Stefan Büttcher, "Reciprocal Rank Fusion Outperforms Condorcet and Individual Rank Learning Methods", SIGIR (2009), for the mixing formula, recalled.
- Stanford CS224N, title read 2026-11-03: [course](https://web.stanford.edu/class/cs224n/)
- Ollama, embeddings API: [docs](https://docs.ollama.com/api/embed)
- The notes, questions, program and numbers were written and computed for this lesson with bge-m3 and qwen2.5-coder:7b on the owner's Mac. The lesson paraphrases these sources and does not copy their text.
