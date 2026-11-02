---
subject: programming
lesson_id: programming.embeddings_and_similarity
level: advanced
languages: ru, en
source_checked: 2026-11-01
source_review_interval_days: 365
---

# Эмбеддинги и сходство / Embeddings and Similarity

## Русский

### Цель

Понять, как слово или символ становится вектором, считать косинусное сходство и написать на чистом Python модель, которая сама располагает похожие слова рядом, зная только их соседей в тексте.

### Идея и механизм

Нейросеть работает с числами, а текст состоит из символов и слов. Как их превратить в числа? Первая мысль — пронумеровать. Но номер обманывает: если «кот» это 5, а «пёс» 6, то выйдет, будто пёс немного больше кота. Вторая мысль — унитарный код (one-hot): вектор длиной со словарь, где на месте слова стоит 1, а остальное нули. Теперь ложного порядка нет, но нет и сходства: любые два разных слова перпендикулярны, и их сходство равно нулю. «Кот» оказывается так же далёк от «пса», как от «поезда».

**Эмбеддинг.** Заведём таблицу: `V` строк по числу слов и `d` столбцов. Строка таблицы и есть вектор слова, обычно намного короче словаря. Числа в таблице — это веса модели: сначала случайные, потом обученные. Таблица размером `V × d` содержит `V · d` весов. У словаря из 16 слов и векторов длиной 3 это 48 чисел. Умножение унитарного вектора на такую матрицу просто достаёт из неё одну строку, поэтому эмбеддинг — это обычный слой сети, только считается он быстро.

**Сходство.** Меру сходства даёт угол между векторами:

`cos θ = (a · b) / (|a| · |b|)`

Косинус равен 1, если векторы смотрят в одну сторону, 0, если они перпендикулярны, и −1, если они смотрят в противоположные стороны. Длина векторов на него не влияет. Посчитаем: `a = (1; 2; 2)`, `b = (2; 1; 2)`. Скалярное произведение `2 + 2 + 4 = 8`, длины обоих равны 3, значит, `cos θ = 8/9 ≈ 0,889`. Для `c = (−2; 1; 0)` получим `a · c = −2 + 2 + 0 = 0`, то есть `a` и `c` перпендикулярны и сходство равно 0.

**Откуда берётся смысл.** Никто не сообщает модели, что кот и пёс похожи. Идею подсказала лингвистика 1950-х годов: у слов, которые встречаются в похожем окружении, смысл обычно близок. Значит, можно учить модель предсказывать соседей слова. Так устроена модель skip-gram из семейства word2vec, которую предложил Томаш Миколов с коллегами в 2013 году. У каждого слова два вектора: `v`, когда оно стоит в центре, и `u`, когда оно сосед. Вероятность того, что рядом со словом `w` стоит слово `k`, считается знакомым способом:

`q(k | w) = softmax(v_w · u₁; v_w · u₂; …)`

Ошибка — знакомая кросс-энтропия `−ln q(сосед | w)`, а градиент — знакомая разность `q − p`:

`∂L/∂v_w = Σₖ (qₖ − pₖ) uₖ`

`∂L/∂uₖ = (qₖ − pₖ) v_w`

Новых математических идей здесь нет. Новое только в том, что обучаются сами входные векторы. Чтобы слово хорошо предсказывало своих соседей, его вектор должен смотреть туда же, куда векторы этих соседей. Если у двух слов соседи одни и те же, их векторы тянет в одну и ту же сторону.

Вся модель на чистом Python. Двенадцать коротких предложений, вектор длиной 3, начальные числа из простого генератора, поэтому результат всегда один и тот же:

```python
import math

sentences = ["кот ест рыбу", "пёс ест мясо", "конь ест сено",
             "кот спит дома", "пёс спит дома", "конь спит дома",
             "машина едет быстро", "поезд едет быстро", "автобус едет быстро",
             "машина стоит тут", "поезд стоит тут", "автобус стоит тут"]
size = 3  # длина вектора
rate = 1.0

lines = [s.split() for s in sentences]
vocab = list(dict.fromkeys(word for line in lines for word in line))
index = {word: i for i, word in enumerate(vocab)}
pairs = [(index[line[i]], index[line[j]])
         for line in lines for i in range(len(line)) for j in (i - 1, i + 1) if 0 <= j < len(line)]

state = 12345


def next_value():
    global state
    state = state * 16807 % 2147483647
    return state / 2147483647 - 0.5


v = [[next_value() for _ in range(size)] for _ in vocab]  # векторы слов
u = [[next_value() for _ in range(size)] for _ in vocab]  # векторы соседей


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def softmax(scores):
    top = max(scores)
    powers = [math.exp(z - top) for z in scores]
    total = sum(powers)
    return [p / total for p in powers]


def train_step():
    grad_v = [[0.0] * size for _ in vocab]
    grad_u = [[0.0] * size for _ in vocab]
    loss = 0.0
    for word, neighbour in pairs:
        q = softmax([dot(v[word], u[k]) for k in range(len(vocab))])
        loss -= math.log(q[neighbour]) / len(pairs)
        for k in range(len(vocab)):
            difference = q[k] - (1 if k == neighbour else 0)  # q − p
            for i in range(size):
                grad_v[word][i] += difference * u[k][i] / len(pairs)
                grad_u[k][i] += difference * v[word][i] / len(pairs)
    for k in range(len(vocab)):
        for i in range(size):
            v[k][i] -= rate * grad_v[k][i]
            u[k][i] -= rate * grad_u[k][i]
    return loss


def cosine(a, b):
    return dot(v[index[a]], v[index[b]]) / math.sqrt(dot(v[index[a]], v[index[a]]) * dot(v[index[b]], v[index[b]]))


print("кот пёс", round(cosine("кот", "пёс"), 2), "кот машина", round(cosine("кот", "машина"), 2))
for step in range(601):
    loss = train_step()
    if step in (0, 100, 600):
        print(step, round(loss, 3))
print("кот пёс", round(cosine("кот", "пёс"), 2))
print("кот машина", round(cosine("кот", "машина"), 2))
print("рыбу мясо", round(cosine("рыбу", "мясо"), 2))
```

Программа печатает:

```text
кот пёс -0.99 кот машина -0.81
0 2.758
100 0.937
600 0.867
кот пёс 1.0
кот машина 0.01
рыбу мясо 1.0
```

До обучения векторы случайны: кот и пёс смотрят почти в противоположные стороны. Начальная ошибка 2,758 близка к `ln 16 ≈ 2,773`, как и должно быть при 16 словах. После обучения сходство кота и пса 1,0, потому что соседи у них одинаковые: «ест» и «спит». Кот и машина стали почти перпендикулярны, 0,01: общих соседей у них нет. «Рыбу» и «мясо» тоже сошлись, потому что обоим предшествует «ест». Модель не читала определений, она только считала соседей.

**Зачем это языковой модели.** В финальном проекте у каждого символа будет свой вектор, и это будет первый слой сети. Обучать таблицу отдельно не придётся: она учится вместе со всей моделью, по той же ошибке. Символы, которые ведут себя похоже, сами окажутся рядом.

### Исследуй и потренируйся

В тренажёре настоящие векторы из этой программы стоят в настоящем трёхмерном пространстве: длина вектора равна 3, поэтому ничего сжимать не приходится. Покрути пространство мышью. Нажми «Пуск» и смотри, как случайное облако собирается в группы. Цвета поставили люди для удобства, а модель о них не знает. Щёлкни по слову: лучи из центра покажут его направление и направление ближайшего соседа. Затем включи новые предложения про коня и обучи ещё. Куда он ушёл и почему?

Затем измени программу: добавь в `sentences` строку `"кот едет быстро"` и посмотри, как изменилось сходство кота и машины.

### Вопрос

Модель не видела ни определений, ни групп слов, только предложения. Откуда взялось большое сходство слов «кот» и «пёс»?

### Варианты

- Из букв в словах: похожие слова пишутся похоже.
- Из соседей в тексте: они стоят рядом с теми же словами.
- Из начальных весов: похожим словам достались близкие числа.

### Ответ

2

### Разбор

Модель получает только номера слов, поэтому буквы ей неизвестны. Начальные веса случайны: в нашей программе кот и пёс начали со сходства −0,99. Вектор слова учится предсказывать его соседей, поэтому слова с одинаковыми соседями тянет в одну сторону.

### Границы модели

Двенадцать предложений — игрушка: сходство 1,0 вышло потому, что контексты кота и пса совпадают полностью. Настоящие модели учатся на миллиардах слов и используют векторы длиной в сотни чисел, а вместо полного softmax применяют ускорения, например отрицательные примеры. Близкий контекст не всегда значит близкий смысл: антонимы вроде «горячий» и «холодный» встречаются в похожем окружении, поэтому эмбеддинги плохо их различают. Эмбеддинги перенимают и перекосы текстов: в векторах из новостей нашли гендерные стереотипы. Вектор хранит статистику употребления слова, а не понимание.

## English

### Goal

Understand how a word or character becomes a vector, compute cosine similarity, and write in plain Python a model that places similar words close together by itself, knowing only their neighbours in the text.

### Idea and mechanism

A neural network works with numbers, while text is made of characters and words. How do we turn them into numbers? The first thought is to number them. But a number misleads: if "cat" is 5 and "dog" is 6, it looks as if a dog is slightly more than a cat. The second thought is one-hot encoding: a vector as long as the vocabulary, with a 1 in the word's place and zeros elsewhere. Now there is no false order, but there is no similarity either: any two different words are perpendicular, and their similarity is zero. "Cat" is as far from "dog" as from "train".

**The embedding.** Make a table with `V` rows, one per word, and `d` columns. A row of the table is the word's vector, usually far shorter than the vocabulary. The numbers in the table are model weights: random at first, then trained. A `V × d` table holds `V · d` weights. For a vocabulary of 16 words and vectors of length 3, that is 48 numbers. Multiplying a one-hot vector by such a matrix simply pulls out one row, so an embedding is an ordinary network layer that happens to be fast to compute.

**Similarity.** The angle between vectors gives a measure of similarity:

`cos θ = (a · b) / (|a| · |b|)`

The cosine is 1 when the vectors point the same way, 0 when they are perpendicular, and −1 when they point in opposite directions. Their length does not affect it. Compute it: `a = (1, 2, 2)`, `b = (2, 1, 2)`. The dot product is `2 + 2 + 4 = 8`, both lengths are 3, so `cos θ = 8/9 ≈ 0.889`. For `c = (−2, 1, 0)` we get `a · c = −2 + 2 + 0 = 0`, so `a` and `c` are perpendicular and their similarity is 0.

**Where meaning comes from.** Nobody tells the model that cats and dogs are alike. The idea came from the linguistics of the 1950s: words that occur in similar surroundings usually have related meanings. So we can train a model to predict a word's neighbours. This is how the skip-gram model of the word2vec family works, proposed by Tomáš Mikolov and colleagues in 2013. Each word has two vectors: `v` when it is in the centre and `u` when it is a neighbour. The probability that word `k` stands next to word `w` is computed in a familiar way:

`q(k | w) = softmax(v_w · u₁, v_w · u₂, …)`

The error is the familiar cross-entropy `−ln q(neighbour | w)`, and the gradient is the familiar difference `q − p`:

`∂L/∂v_w = Σₖ (qₖ − pₖ) uₖ`

`∂L/∂uₖ = (qₖ − pₖ) v_w`

There are no new mathematical ideas here. The only new thing is that the input vectors themselves are trained. For a word to predict its neighbours well, its vector must point where those neighbours' vectors point. If two words have the same neighbours, their vectors are pulled the same way.

The whole model in plain Python. Twelve short sentences, vectors of length 3, and starting numbers from a simple generator, so the result is always the same:

```python
import math

sentences = ["cat eats fish", "dog eats meat", "horse eats hay",
             "cat sleeps home", "dog sleeps home", "horse sleeps home",
             "car drives fast", "train drives fast", "bus drives fast",
             "car stands here", "train stands here", "bus stands here"]
size = 3  # vector length
rate = 1.0

lines = [s.split() for s in sentences]
vocab = list(dict.fromkeys(word for line in lines for word in line))
index = {word: i for i, word in enumerate(vocab)}
pairs = [(index[line[i]], index[line[j]])
         for line in lines for i in range(len(line)) for j in (i - 1, i + 1) if 0 <= j < len(line)]

state = 12345


def next_value():
    global state
    state = state * 16807 % 2147483647
    return state / 2147483647 - 0.5


v = [[next_value() for _ in range(size)] for _ in vocab]  # word vectors
u = [[next_value() for _ in range(size)] for _ in vocab]  # neighbour vectors


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def softmax(scores):
    top = max(scores)
    powers = [math.exp(z - top) for z in scores]
    total = sum(powers)
    return [p / total for p in powers]


def train_step():
    grad_v = [[0.0] * size for _ in vocab]
    grad_u = [[0.0] * size for _ in vocab]
    loss = 0.0
    for word, neighbour in pairs:
        q = softmax([dot(v[word], u[k]) for k in range(len(vocab))])
        loss -= math.log(q[neighbour]) / len(pairs)
        for k in range(len(vocab)):
            difference = q[k] - (1 if k == neighbour else 0)  # q − p
            for i in range(size):
                grad_v[word][i] += difference * u[k][i] / len(pairs)
                grad_u[k][i] += difference * v[word][i] / len(pairs)
    for k in range(len(vocab)):
        for i in range(size):
            v[k][i] -= rate * grad_v[k][i]
            u[k][i] -= rate * grad_u[k][i]
    return loss


def cosine(a, b):
    return dot(v[index[a]], v[index[b]]) / math.sqrt(dot(v[index[a]], v[index[a]]) * dot(v[index[b]], v[index[b]]))


print("cat dog", round(cosine("cat", "dog"), 2), "cat car", round(cosine("cat", "car"), 2))
for step in range(601):
    loss = train_step()
    if step in (0, 100, 600):
        print(step, round(loss, 3))
print("cat dog", round(cosine("cat", "dog"), 2))
print("cat car", round(cosine("cat", "car"), 2))
print("fish meat", round(cosine("fish", "meat"), 2))
```

The program prints:

```text
cat dog -0.99 cat car -0.81
0 2.758
100 0.937
600 0.867
cat dog 1.0
cat car 0.01
fish meat 1.0
```

Before training the vectors are random: cat and dog point in nearly opposite directions. The starting error of 2.758 is close to `ln 16 ≈ 2.773`, as it should be with 16 words. After training the similarity of cat and dog is 1.0, because their neighbours are the same: "eats" and "sleeps". Cat and car have become almost perpendicular, 0.01: they share no neighbours. "Fish" and "meat" also came together, because "eats" precedes both. The model read no definitions; it only counted neighbours.

**Why a language model needs this.** In the final project each character will have its own vector, and this will be the first layer of the network. The table needs no separate training: it learns along with the whole model, from the same error. Characters that behave alike will end up close together by themselves.

### Explore and practise

In the lab, the true vectors of this program stand in a true three-dimensional space: the vector length is 3, so nothing needs to be squeezed. Turn the space with the mouse. Press Play and watch a random cloud gather into groups. People chose the colours for convenience, and the model knows nothing of them. Click a word: rays from the centre show its direction and that of its nearest neighbour. Then switch on the new sentences about the horse and train some more. Where did it go, and why?

Then change the program: add the line `"cat drives fast"` to `sentences` and see how the similarity of cat and car changes.

### Question

The model saw no definitions and no word groups, only sentences. Where did the high similarity of "cat" and "dog" come from?

### Options

- From the letters: similar words are spelled similarly.
- From neighbours in the text: both stand next to the same words.
- From the starting weights: similar words got close numbers.

### Answer

2

### Explanation

The model receives only word numbers, so it knows nothing of letters. The starting weights are random: in our program, cat and dog began at a similarity of −0.99. A word's vector learns to predict its neighbours, so words with the same neighbours are pulled the same way.

### Limits

Twelve sentences are a toy: the similarity of 1.0 came out because the contexts of cat and dog match completely. Real models learn from billions of words, use vectors hundreds of numbers long, and replace the full softmax with shortcuts such as negative sampling. Similar context does not always mean similar meaning: antonyms like "hot" and "cold" occur in similar surroundings, so embeddings separate them poorly. Embeddings also absorb the biases of texts: gender stereotypes were found in vectors trained on news. A vector stores statistics of how a word is used, not understanding.

## Sources

- Tomas Mikolov, Kai Chen, Greg Corrado, Jeffrey Dean, “Efficient Estimation of Word Representations in Vector Space”, arXiv:1301.3781 (2013), abstract read 2026-11-01: learning word vectors from large data sets at low computational cost: [arXiv:1301.3781](https://arxiv.org/abs/1301.3781)
- Aston Zhang, Zachary C. Lipton, Mu Li, Alexander J. Smola, *Dive into Deep Learning* (version 1.0.3), “Word Embedding (word2vec)” (consulted 2026-11-01): why one-hot vectors cannot express similarity, the two vectors per word in skip-gram, softmax over dot products, and the gradient: [D2L, word2vec](https://d2l.ai/chapter_natural-language-processing-pretraining/word2vec.html)
- Wikipedia, “Distributional semantics” (consulted 2026-11-01): the distributional hypothesis, Firth's popularization of it in the 1950s, and Harris's 1954 work: [Distributional semantics](https://en.wikipedia.org/wiki/Distributional_semantics)
- Kim Anh Nguyen, Sabine Schulte im Walde, Ngoc Thang Vu, “Integrating Distributional Lexical Contrast into Word Embeddings for Antonym–Synonym Distinction”, ACL 2016, arXiv:1605.07766 (consulted 2026-11-01): antonyms and synonyms are hard to separate with standard distributional models: [arXiv:1605.07766](https://arxiv.org/abs/1605.07766)
- Tolga Bolukbasi, Kai-Wei Chang, James Zou, Venkatesh Saligrama, Adam Kalai, “Man is to Computer Programmer as Woman is to Homemaker? Debiasing Word Embeddings”, arXiv:1607.06520 (2016), abstract read 2026-11-01: embeddings trained on Google News text encode gender stereotypes: [arXiv:1607.06520](https://arxiv.org/abs/1607.06520)
- The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
