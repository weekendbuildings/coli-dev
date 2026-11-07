---
subject: programming
lesson_id: programming.attention_mechanism
level: advanced
languages: ru, en
source_checked: 2026-11-01
source_review_interval_days: 365
---

# Механизм внимания / The Attention Mechanism

## Русский

### Простыми словами

Чтобы понять слово, нужно знать, к чему оно относится в предложении. Внимание позволяет каждому токену самому решить, на какие прошлые токены смотреть. У каждого токена есть запрос («что я ищу»), ключ («что я предлагаю») и значение («что я передам»). Похоже на поиск в библиотеке: запрос сравнивают с надписями на корешках, и книги с подходящими надписями берут с большим весом. Маска будущего не даёт подглядывать в ещё не написанный текст.

**Что нужно знать до.** Уроки «Эмбеддинги и сходство» (шаг 10), «Классификация и softmax» (шаг 7) и «Векторы и матрицы» (шаг 3).

**Если непонятно.** Если неясны запрос и ключ, посчитай внимание для двух токенов руками по примеру урока. Если неясен softmax в формуле, вернись к уроку «Классификация и softmax». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Считать внимание по формуле с запросами, ключами и значениями, понять, зачем нужны деление на `√d`, маска будущего и номера мест, и написать на чистом Python модель, которая сама находит, куда в тексте смотреть.

### Идея и механизм

Счётчик пар букв видит только одну предыдущую букву. Но ответ часто лежит дальше: чтобы продолжить узор `ABCABCA`, нужно посмотреть на три буквы назад. Можно было бы склеить десять последних букв в один длинный вход, но тогда сеть будет учить каждое место отдельно, а длина окна будет жёстко задана. Внимание решает это иначе: модель сама считает, насколько важно каждое прочитанное место, и берёт взвешенное среднее. Идею предложили Дмитрий Богданов, Кёнхён Чо и Йошуа Бенджио в 2014 году для перевода, а в 2017 году Ашиш Васвани с коллегами построили на внимании всю архитектуру трансформера.

**Запрос, ключ, значение.** Это похоже на поиск. Текущее место задаёт вопрос, вектор запроса `q`. Каждое прочитанное место предлагает ключ `kⱼ`, который показывает, о чём оно, и значение `vⱼ`, которое оно отдаст. Сходство запроса с ключом превращается в веса через знакомый softmax, а результат — это взвешенное среднее значений:

`αⱼ = softmax(q · kⱼ / √d)`

`c = Σ αⱼ vⱼ`

Здесь `d` — длина векторов. Посчитаем на маленьком примере: `q = (1; 0)`, ключи `k₁ = (1; 0)`, `k₂ = (0; 1)`, `k₃ = (1; 1)`, поэтому `d = 2`. Скалярные произведения равны 1, 0 и 1. Делим на `√2` и получаем `0,707`, `0` и `0,707`. Softmax даёт веса `α = (0,401; 0,198; 0,401)`. Пусть значения совпадают с ключами. Тогда `c = 0,401 · (1; 0) + 0,198 · (0; 1) + 0,401 · (1; 1) = (0,802; 0,599)`. Первое и третье места сработали вдвое сильнее второго, потому что их ключи совпали с запросом. Сумма весов всегда равна 1, поэтому `c` не растёт от длины текста.

**Зачем делить на `√d`.** Если элементы векторов независимы, их среднее равно нулю, а дисперсия единице, то у скалярного произведения дисперсия равна `d`. При длинных векторах оценки становятся огромными, и softmax почти всю вероятность отдаёт одному месту, а его градиент почти исчезает. Деление на `√d` возвращает дисперсию к единице при любой длине векторов.

**Маска будущего.** Когда модель предсказывает следующую букву, смотреть вперёд нельзя: это было бы подглядыванием в ответ. Поэтому будущие места просто не участвуют в softmax. В больших программах им ставят оценку `−∞`, и их вес становится нулём, а сумма остальных весов по-прежнему равна 1.

**Нужны номера мест.** В самовнимании запросы, ключи и значения берутся из одного и того же текста. Но у этой формулы есть свойство: она не знает порядка. Перемешай места, и веса перемешаются вместе с ними, а взвешенная сумма не изменится. Чтобы узнать порядок, модель должна получить номер места. Его можно задать готовой формулой из синусов и косинусов или обучить. В нашей программе запрос и ключ зависят от номера места и обучаются.

**Как ошибка доходит до внимания.** Это снова правило цепочки. Выход считается как `zₘ = c · wₘ`, поэтому на контекст приходит вектор `g = Σₘ (qₘ − pₘ) wₘ`. Для каждого места считаем его действие `hⱼ = g · vⱼ`. Поскольку веса получены через softmax, в итоге производная ошибки по оценке места равна `αⱼ (hⱼ − Σᵢ αᵢhᵢ)`. Это значит, что вес растёт у тех мест, которые снижают ошибку сильнее среднего. Из этой производной получаются шаги для запроса и для ключа.

Вся модель на чистом Python. Каждый пример — узор длиной 8 из четырёх символов, который повторяется каждые 3 места. Модель обучается на 32 узорах, а проверяется на 100 новых:

```python
import math

symbols, length, size = 4, 8, 4  # символов, длина узора, длина вектора
period = 3  # узор повторяется каждые 3 символа
positions = True  # знает ли внимание номера мест
rate = 1.0
state = 4242


def next_value():
    global state
    state = state * 16807 % 2147483647
    return state / 2147483647


def table(rows):
    return [[next_value() - 0.5 for _ in range(size)] for _ in range(rows)]


query, key = table(8), table(8)  # векторы запросов и ключей
value, output = table(symbols), table(symbols)  # векторы значений и выходов
state = 777


def patterns(count):
    result = []
    for _ in range(count):
        pattern = [int(next_value() * symbols) for _ in range(period)]
        result.append([pattern[i % period] for i in range(length)])
    return result


train, unseen = patterns(32), patterns(100)


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def softmax(scores):
    top = max(scores)
    powers = [math.exp(s - top) for s in scores]
    total = sum(powers)
    return [p / total for p in powers]


def places(line, t):
    q = t if positions else line[t]
    return q, [j if positions else line[j] for j in range(t + 1)]  # маска: только уже прочитанное


def predict(line, t):
    q, keys = places(line, t)
    weights = softmax([dot(query[q], key[k]) / math.sqrt(size) for k in keys])
    context = [sum(weights[j] * value[line[j]][i] for j in range(t + 1)) for i in range(size)]
    return weights, context, softmax([dot(context, output[m]) for m in range(symbols)])


def train_step():
    grads = [[[0.0] * size for _ in tab] for tab in (query, key, value, output)]
    total, count = 0.0, 0
    for line in train:
        for t in range(period - 1, length - 1):
            weights, context, answer = predict(line, t)
            total -= math.log(answer[line[t + 1]])
            count += 1
            back = [0.0] * size  # ошибка, дошедшая до контекста
            for m in range(symbols):
                difference = answer[m] - (1 if m == line[t + 1] else 0)  # q − p
                for i in range(size):
                    grads[3][m][i] += difference * context[i]
                    back[i] += difference * output[m][i]
            q, keys = places(line, t)
            effect = [dot(back, value[line[j]]) for j in range(t + 1)]
            mean = dot(weights, effect)
            for j, k in enumerate(keys):
                pull = weights[j] * (effect[j] - mean) / math.sqrt(size)
                for i in range(size):
                    grads[2][line[j]][i] += weights[j] * back[i]
                    grads[0][q][i] += pull * key[k][i]
                    grads[1][k][i] += pull * query[q][i]
    for tab, grad in zip((query, key, value, output), grads):
        for row, slope in zip(tab, grad):
            for i in range(size):
                row[i] -= rate * slope[i] / count
    return total / count


def accuracy():
    right = total = 0
    for line in unseen:
        for t in range(period - 1, length - 1):
            answer = predict(line, t)[2]
            right += answer.index(max(answer)) == line[t + 1]
            total += 1
    return right / total


for step in range(301):
    loss = train_step()
    if step in (0, 100, 300):
        print(step, round(loss, 3), round(accuracy(), 2))
print("t=6", [round(w, 2) for w in predict(unseen[0], 6)[0]])
print("t=5", [round(w, 2) for w in predict(unseen[0], 5)[0]])
```

Программа печатает шаг, ошибку и долю верных ответов на новых узорах, а затем веса внимания для двух строк:

```text
0 1.406 0.2
100 0.005 1.0
300 0.001 1.0
t=6 [0.01, 0.78, 0.02, 0.04, 0.08, 0.02, 0.04]
t=5 [0.45, 0.02, 0.02, 0.36, 0.07, 0.08]
```

Начальная ошибка близка к `ln 4 ≈ 1,386`. Уже через 100 шагов модель верно продолжает все новые узоры. Посмотри на веса. На месте `t = 6` модель предсказывает символ номер 7, а в узоре с периодом 3 он совпадает с символами на местах 1 и 4. Именно там веса самые большие: 0,78 и 0,08. На месте `t = 5` ответ лежит на местах 0 и 3, и веса равны 0,45 и 0,36. Никто не говорил модели про три шага назад. Она нашла это сама, потому что только так можно снизить ошибку.

Поставь `positions = False`. Запросы и ключи теперь зависят только от символа, а не от места, и модель застревает: ошибка 0,567, а верных ответов всего 54 %. Без номеров мест она не может узнать, где три шага назад.

### Исследуй и потренируйся

В тренажёре настоящие веса внимания стоят на доске как башни. Строка — текущее место, столбец — место, на которое модель смотрит, а высота башни — вес. Будущие места закрыты маской. Сначала у модели нет номеров мест: нажми «Пуск» и посмотри, как она застрянет. Затем включи номера мест, обучи заново и посмотри, как на доске вырастает полоса. Щёлкни по башне, чтобы выбрать строку: от её высоких башен золотые дуги идут к ответу. Смени период: как переехала полоса?

Затем проверь свойство формулы в программе: выведи веса для `unseen[0]` при `positions = False`, а потом переставь в этом узоре два символа. Как изменились веса?

**Собери и проверь сам.** Код выше дан готовым. Теперь напиши ключевой шаг своими руками: softmax без переполнения, маску будущего и обратный проход через softmax. Заготовка и строгая проверка лежат в папке проекта `01_Projects/creator_labs`. Скопируй её к себе (уже написанные тобой файлы не перезапишутся) и запусти проверку:

```bash
mkdir -p ~/ai-path && cp -Rn ~/Desktop/"coli-dev 4"/coli-dev/01_Projects/creator_labs ~/ai-path/
cd ~/ai-path/creator_labs && python3 check_attention_mechanism.py
```

Сначала все строки будут с ✗. Открой `attention_blank.py`, допиши функции, где стоит `NotImplementedError`, и запускай проверку, пока все строки не станут ✓. Проверка сверяет твой код с численной производной, граничными случаями и свойствами, которые обязаны выполняться всегда. В самом файле проверки есть ответ: открывай его только после своей попытки.

### Вопрос

Модель без номеров мест читает `A B C`, а затем те же буквы в другом порядке: `C A B`. Что произойдёт с весами внимания, если запрос взять от одной и той же буквы?

### Варианты

- Веса останутся теми же числами, только переставятся вместе с буквами.
- Веса станут совсем другими: внимание зависит от порядка букв.
- Все веса станут равными: без номеров мест запрос не работает.

### Ответ

1

### Разбор

Вес места считается только из запроса и ключа этого места. Если буква с тем же ключом переехала, вместе с ней переехал и её вес, а взвешенная сумма осталась той же. Поэтому самовнимание само по себе не знает порядка, и ему нужны номера мест. Равными веса становятся только при равных оценках, а тут ключи разные.

### Границы модели

Узор с точным периодом — учебная задача: в настоящем тексте полезные места зависят от смысла, а не от постоянного сдвига. Наша модель содержит одну голову внимания и не имеет скрытых слоёв, а настоящие модели собирают много голов и слоёв, и это следующий урок. Внимание сравнивает каждое место с каждым, поэтому число операций растёт как квадрат длины текста. Веса внимания удобно рисовать, но они не обязательно объясняют решение модели: в исследованиях они часто расходились с другими мерами важности, поэтому к таким картинкам нужна осторожность.

## English

### In plain words

To understand a word, you need to know what it refers to in the sentence. Attention lets each token decide for itself which earlier tokens to look at. Each token has a query ("what I am looking for"), a key ("what I offer") and a value ("what I will pass on"). It is like searching a library: the query is compared with the labels on the spines, and books with matching labels are taken with more weight. The future mask stops peeking at text not yet written.

**What to know first.** «Embeddings and Similarity» (step 10), «Classification and Softmax» (step 7) and «Vectors and Matrices» (step 3).

**If something is unclear.** If query and key are unclear, compute attention for two tokens by hand following the lesson's example. If the softmax in the formula is unclear, go back to «Classification and Softmax». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Compute attention with queries, keys, and values, see why division by `√d`, a mask over the future, and position numbers are needed, and write in plain Python a model that finds by itself where to look in a text.

### Idea and mechanism

A letter-pair counter sees only one previous letter. But the answer often lies further back: to continue the pattern `ABCABCA`, you must look three letters back. We could glue the last ten letters into one long input, but then the network would learn each place separately, and the window length would be fixed. Attention solves this differently: the model itself computes how important each place already read is, and takes a weighted mean. Dzmitry Bahdanau, Kyunghyun Cho, and Yoshua Bengio proposed the idea in 2014 for translation, and in 2017 Ashish Vaswani and colleagues built the whole transformer architecture on attention.

**Query, key, value.** This resembles a search. The current place asks a question, the query vector `q`. Each place already read offers a key `kⱼ`, showing what it is about, and a value `vⱼ`, which it will give. The similarity of query and key becomes weights through the familiar softmax, and the result is a weighted mean of the values:

`αⱼ = softmax(q · kⱼ / √d)`

`c = Σ αⱼ vⱼ`

Here `d` is the vector length. Compute a small example: `q = (1, 0)`, keys `k₁ = (1, 0)`, `k₂ = (0, 1)`, `k₃ = (1, 1)`, so `d = 2`. The dot products are 1, 0, and 1. Divide by `√2` to get `0.707`, `0`, and `0.707`. Softmax gives the weights `α = (0.401, 0.198, 0.401)`. Let the values equal the keys. Then `c = 0.401 · (1, 0) + 0.198 · (0, 1) + 0.401 · (1, 1) = (0.802, 0.599)`. The first and third places worked twice as strongly as the second, because their keys matched the query. The weights always sum to 1, so `c` does not grow with the length of the text.

**Why divide by `√d`.** If the elements of the vectors are independent with mean zero and variance one, then a dot product has variance `d`. With long vectors the scores become huge, softmax gives almost all the probability to one place, and its gradient nearly vanishes. Dividing by `√d` returns the variance to one at any vector length.

**The mask over the future.** When a model predicts the next letter, it must not look ahead: that would be peeking at the answer. So future places simply do not take part in the softmax. In large programs they get a score of `−∞`, so their weight becomes zero, and the other weights still sum to 1.

**Position numbers are needed.** In self-attention, queries, keys, and values all come from the same text. But this formula has a property: it does not know order. Shuffle the places, and the weights shuffle along with them while the weighted sum stays the same. To learn the order, the model must receive the number of each place. It can be given by a ready formula of sines and cosines, or it can be trained. In our program the query and key depend on the place number and are trained.

**How the error reaches attention.** This is the chain rule again. The output is `zₘ = c · wₘ`, so the vector `g = Σₘ (qₘ − pₘ) wₘ` arrives at the context. For each place, compute its effect `hⱼ = g · vⱼ`. Since the weights come from softmax, the derivative of the error over a place's score works out to `αⱼ (hⱼ − Σᵢ αᵢhᵢ)`. So the weight grows at those places that lower the error more than average. The steps for the query and the key follow from this derivative.

The whole model in plain Python. Each example is a pattern of length 8 from four symbols that repeats every 3 places. The model trains on 32 patterns and is tested on 100 new ones:

```python
import math

symbols, length, size = 4, 8, 4  # symbols, pattern length, vector length
period = 3  # the pattern repeats every 3 symbols
positions = True  # whether attention knows place numbers
rate = 1.0
state = 4242


def next_value():
    global state
    state = state * 16807 % 2147483647
    return state / 2147483647


def table(rows):
    return [[next_value() - 0.5 for _ in range(size)] for _ in range(rows)]


query, key = table(8), table(8)  # query and key vectors
value, output = table(symbols), table(symbols)  # value and output vectors
state = 777


def patterns(count):
    result = []
    for _ in range(count):
        pattern = [int(next_value() * symbols) for _ in range(period)]
        result.append([pattern[i % period] for i in range(length)])
    return result


train, unseen = patterns(32), patterns(100)


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def softmax(scores):
    top = max(scores)
    powers = [math.exp(s - top) for s in scores]
    total = sum(powers)
    return [p / total for p in powers]


def places(line, t):
    q = t if positions else line[t]
    return q, [j if positions else line[j] for j in range(t + 1)]  # the mask: only what was already read


def predict(line, t):
    q, keys = places(line, t)
    weights = softmax([dot(query[q], key[k]) / math.sqrt(size) for k in keys])
    context = [sum(weights[j] * value[line[j]][i] for j in range(t + 1)) for i in range(size)]
    return weights, context, softmax([dot(context, output[m]) for m in range(symbols)])


def train_step():
    grads = [[[0.0] * size for _ in tab] for tab in (query, key, value, output)]
    total, count = 0.0, 0
    for line in train:
        for t in range(period - 1, length - 1):
            weights, context, answer = predict(line, t)
            total -= math.log(answer[line[t + 1]])
            count += 1
            back = [0.0] * size  # the error that reached the context
            for m in range(symbols):
                difference = answer[m] - (1 if m == line[t + 1] else 0)  # q − p
                for i in range(size):
                    grads[3][m][i] += difference * context[i]
                    back[i] += difference * output[m][i]
            q, keys = places(line, t)
            effect = [dot(back, value[line[j]]) for j in range(t + 1)]
            mean = dot(weights, effect)
            for j, k in enumerate(keys):
                pull = weights[j] * (effect[j] - mean) / math.sqrt(size)
                for i in range(size):
                    grads[2][line[j]][i] += weights[j] * back[i]
                    grads[0][q][i] += pull * key[k][i]
                    grads[1][k][i] += pull * query[q][i]
    for tab, grad in zip((query, key, value, output), grads):
        for row, slope in zip(tab, grad):
            for i in range(size):
                row[i] -= rate * slope[i] / count
    return total / count


def accuracy():
    right = total = 0
    for line in unseen:
        for t in range(period - 1, length - 1):
            answer = predict(line, t)[2]
            right += answer.index(max(answer)) == line[t + 1]
            total += 1
    return right / total


for step in range(301):
    loss = train_step()
    if step in (0, 100, 300):
        print(step, round(loss, 3), round(accuracy(), 2))
print("t=6", [round(w, 2) for w in predict(unseen[0], 6)[0]])
print("t=5", [round(w, 2) for w in predict(unseen[0], 5)[0]])
```

The program prints the step, the error, and the share of right answers on new patterns, then the attention weights for two rows:

```text
0 1.406 0.2
100 0.005 1.0
300 0.001 1.0
t=6 [0.01, 0.78, 0.02, 0.04, 0.08, 0.02, 0.04]
t=5 [0.45, 0.02, 0.02, 0.36, 0.07, 0.08]
```

The starting error is close to `ln 4 ≈ 1.386`. After only 100 steps the model continues all the new patterns correctly. Look at the weights. At place `t = 6` the model predicts symbol number 7, and in a pattern with period 3 this matches the symbols at places 1 and 4. The largest weights are exactly there: 0.78 and 0.08. At place `t = 5` the answer lies at places 0 and 3, and the weights are 0.45 and 0.36. Nobody told the model about three steps back. It found this by itself, because only this lowers the error.

Set `positions = False`. Queries and keys now depend only on the symbol, not the place, and the model gets stuck: the error is 0.567, and only 54% of its answers are right. Without place numbers it cannot find out where three steps back is.

### Explore and practise

In the lab, the true attention weights stand on a board as towers. A row is the current place, a column is the place the model looks at, and the height of a tower is the weight. Future places are closed by the mask. At first the model has no place numbers: press Play and see it get stuck. Then switch on place numbers, train again, and watch a stripe grow on the board. Click a tower to select its row: gold arcs run from its tall towers to the answer. Change the period: where did the stripe go?

Then check the formula's property in the program: print the weights for `unseen[0]` with `positions = False`, then swap two symbols in that pattern. How did the weights change?

**Build and check it yourself.** The code above was given ready-made. Now write the key step with your own hands: softmax without overflow, the future mask and the backward pass through softmax. The blank and a strict check are in the project folder `01_Projects/creator_labs`. Copy it (files you have already written are not overwritten) and run the check:

```bash
mkdir -p ~/ai-path && cp -Rn ~/Desktop/"coli-dev 4"/coli-dev/01_Projects/creator_labs ~/ai-path/
cd ~/ai-path/creator_labs && python3 check_attention_mechanism.py
```

At first every line shows ✗. Open `attention_blank.py`, fill in the functions that raise `NotImplementedError`, and rerun until every line shows ✓. The check compares your code with numerical derivatives, edge cases and invariants that must always hold. The check file itself contains the answer: open it only after your own attempt.

### Question

A model with no place numbers reads `A B C`, then the same letters in another order: `C A B`. What happens to the attention weights if the query comes from the same letter?

### Options

- The weights stay the same numbers and only move along with the letters.
- The weights become quite different: attention depends on letter order.
- All the weights become equal: without place numbers a query fails.

### Answer

1

### Explanation

A place's weight is computed only from the query and that place's key. If a letter with the same key moved, its weight moved with it, and the weighted sum stayed the same. So self-attention by itself does not know order and needs place numbers. Weights become equal only when scores are equal, and here the keys differ.

### Limits

A pattern with an exact period is a teaching task: in real text, useful places depend on meaning, not on a constant shift. Our model has one attention head and no hidden layers, while real models combine many heads and layers, and that is the next lesson. Attention compares every place with every other, so the number of operations grows as the square of the text length. Attention weights are handy to draw, but they do not necessarily explain a model's decision: in research they often disagreed with other measures of importance, so such pictures call for caution.

## Sources

- Dzmitry Bahdanau, Kyunghyun Cho, Yoshua Bengio, “Neural Machine Translation by Jointly Learning to Align and Translate”, arXiv:1409.0473 (2014), ICLR 2015, abstract read 2026-11-01: a decoder that softly focuses on relevant source words instead of one fixed-length vector: [arXiv:1409.0473](https://arxiv.org/abs/1409.0473)
- Ashish Vaswani and colleagues, “Attention Is All You Need”, arXiv:1706.03762 (2017), abstract read 2026-11-01: the transformer, built from attention with no recurrent or convolutional layers: [arXiv:1706.03762](https://arxiv.org/abs/1706.03762)
- Aston Zhang, Zachary C. Lipton, Mu Li, Alexander J. Smola, *Dive into Deep Learning* (version 1.0.3), “Attention Scoring Functions” (consulted 2026-11-01): scaled dot-product attention, the variance d of a dot product, the reason for dividing by √d, and masked softmax: [D2L, attention scoring](https://d2l.ai/chapter_attention-mechanisms-and-transformers/attention-scoring-functions.html)
- *Dive into Deep Learning*, “Self-Attention and Positional Encoding” (consulted 2026-11-01): self-attention, its indifference to order, and why position information is added: [D2L, self-attention](https://d2l.ai/chapter_attention-mechanisms-and-transformers/self-attention-and-positional-encoding.html)
- Sarthak Jain, Byron C. Wallace, “Attention is not Explanation”, NAACL 2019, arXiv:1902.10186, abstract read 2026-11-01: attention weights often disagree with other importance measures and can differ widely for the same output: [arXiv:1902.10186](https://arxiv.org/abs/1902.10186)
- The derivation, the program, and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
