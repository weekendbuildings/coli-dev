---
subject: programming
lesson_id: programming.data_for_language_models
level: intermediate
languages: ru, en
source_checked: 2026-11-07
source_review_interval_days: 180
---

# Данные для языковой модели: фильтры и повторы / Data for a language model: filters and duplicates

## Русский

### Простыми словами

Модель учится на том, что ей дали. Если в текстах много мусора и повторов, она выучит мусор и повторы. Поэтому до обучения тексты чистят: выбрасывают обрывки, меню сайтов и спам, а копии оставляют по одной. Похоже на подготовку к экзамену по конспектам однокурсников: десять одинаковых ксерокопий одной лекции не делают тебя умнее, а только отнимают время. В уроке ты почистишь маленькую коллекцию текстов тремя способами и найдёшь почти-копии, которые простое сравнение не видит.

**Что нужно знать до.** Урок «Строки, файлы и исключения» (шаг 2): работа с текстом. Урок «Коллекции и циклы» (шаг 2): множества и словари. Урок «Законы масштабирования и цена обучения» (шаг 16): зачем моделям так много текста.

**Если непонятно.** Если неясно, что такое множество в Python, вернись к уроку «Коллекции и циклы»: это набор без повторов. Хеш это короткий отпечаток текста: одинаковые тексты дают одинаковый отпечаток. Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Пройти три шага очистки данных, как в настоящих наборах для обучения: фильтры качества, удаление точных копий по хешу и поиск почти-копий по сходству Жаккара и MinHash. Понять, почему повторы вредят и почему порог сходства это решение человека. Нужно около 30 минут.

### Идея и механизм

**Шаг 1. Фильтры.** Настоящие наборы собирают из веба, а там много мусора. Набор C4 оставлял только строки, которые заканчиваются знаком конца предложения, и выбрасывал слишком короткие. Мы возьмём три простых правила: в тексте не меньше 5 слов, он кончается точкой, восклицательным или вопросительным знаком, и разных слов в нём хотя бы половина. Создай файл `nano ~/ai-path/data.py`, вставь и запусти.

```python
import hashlib

DOCS = [
    "Кот спал на тёплом окне и смотрел, как падает снег.",
    "Градиентный спуск уменьшает ошибку маленькими шагами против градиента.",
    "Главная | Новости | Контакты | Войти | Корзина",
    "Кот спал на тёплом окне и смотрел, как падает снег.",
    "Купить дёшево! Купить дёшево! Купить дёшево! Купить дёшево!",
    "Градиентный спуск уменьшает ошибку небольшими шагами против градиента.",
    "Ок",
    "Модель внимания сама выбирает, на какие прошлые токены смотреть.",
    "Пёс гулял во дворе и искал свой мяч под старой скамейкой.",
    "Кот спал на тёплом окне и смотрел, как падал снег.",
    "Токенизатор BPE склеивает самую частую пару кусочков текста.",
    "Пёс гулял по двору и искал мяч под скамейкой у подъезда.",
]


def quality(doc):
    words = doc.split()
    if len(words) < 5:
        return "too short"
    if doc[-1] not in ".!?":
        return "no full stop at the end"
    if len(set(words)) / len(words) < 0.5:
        return "repeats itself"
    return None


kept = []
for index, doc in enumerate(DOCS):
    reason = quality(doc)
    if reason:
        print(f"[{index}] removed: {reason}")
    else:
        kept.append(index)
print("kept after filters:", kept)
```

```output
[2] removed: no full stop at the end
[4] removed: repeats itself
[6] removed: too short
kept after filters: [0, 1, 3, 5, 7, 8, 9, 10, 11]
```

Меню сайта ушло, потому что не кончается точкой. Спам «Купить дёшево!» ушёл, потому что в нём 2 разных слова из 8. Обрывок «Ок» слишком короткий. Заметь: правила грубые, и они ошибаются в обе стороны. Стихотворение без точки в конце тоже ушло бы.

**Шаг 2. Точные копии.** Текст [3] это точная копия [0]. Сравнивать каждый текст с каждым долго, поэтому от каждого берут *хеш*, короткий отпечаток, и складывают отпечатки во множество. Если отпечаток уже был, это копия. Допиши и запусти.

```python
seen, unique = set(), []
for index in kept:
    key = hashlib.sha1(" ".join(DOCS[index].lower().split()).encode()).hexdigest()
    if key in seen:
        print(f"[{index}] exact copy removed")
    else:
        seen.add(key)
        unique.append(index)
print("unique:", unique)
```

```output
[3] exact copy removed
unique: [0, 1, 5, 7, 8, 9, 10, 11]
```

**Шаг 3. Почти-копии.** Тексты [0] и [9] отличаются одним словом: «падает» и «падал». Хеш у них разный, и шаг 2 их не поймал. Чтобы найти такие пары, текст режут на *кусочки* по 5 знаков, и сравнивают наборы кусочков. *Сходство Жаккара* это доля общих кусочков среди всех: `|A ∩ B| / |A ∪ B|`. Руками на маленьком примере: у слова «мама» кусочки по 2 знака это «ма», «ам», «ма», то есть набор {«ма», «ам»}. У слова «мамы» набор {«ма», «ам», «мы»}. Общих 2, всего разных 3, сходство `2 / 3 ≈ 0,67`.

Для миллиардов текстов и это слишком долго, поэтому используют *MinHash*. Для каждого текста считают 64 разных хеш-функции по всем его кусочкам и запоминают наименьшее значение каждой. Доля совпавших наименьших значений у двух текстов примерно равна их сходству Жаккара. Допиши и запусти.

```python
def shingles(doc, size=5):
    text = " ".join(doc.lower().split())
    return {text[i:i + size] for i in range(len(text) - size + 1)}


def jaccard(a, b):
    return len(a & b) / len(a | b)


def minhash(pieces, count=64):
    return [min(int(hashlib.md5(f"{seed}:{piece}".encode()).hexdigest()[:12], 16) for piece in pieces) for seed in range(count)]


sets = {i: shingles(DOCS[i]) for i in unique}
signs = {i: minhash(sets[i]) for i in unique}
for a in unique:
    for b in unique:
        if a < b:
            exact = jaccard(sets[a], sets[b])
            estimate = sum(x == y for x, y in zip(signs[a], signs[b])) / 64
            if exact > 0.2:
                print(f"[{a}] and [{b}]: Jaccard {exact:.2f}, MinHash estimate {estimate:.2f}")
```

```output
[0] and [9]: Jaccard 0.79, MinHash estimate 0.72
[1] and [5]: Jaccard 0.70, MinHash estimate 0.72
[8] and [11]: Jaccard 0.31, MinHash estimate 0.36
```

Пары [0] и [9] и [1] и [5] это почти-копии: сходство 0,79 и 0,70. Пара [8] и [11] про пса похожа на 0,31: это пересказ, а не копия. Оценка MinHash отличается от точного числа на 0,02–0,07: это цена скорости. Где поставить порог, решает человек. При пороге 0,6 уходят две почти-копии, а пересказ остаётся.

**Шаг 4. Почему это важно.** Lee и соавторы в 2021 году почистили от повторов настоящие наборы. Они нашли в наборе C4 строку из 61 слова, которая повторялась 61 036 раз. После очистки модели выдавали заученный текст в 10 раз реже, а для той же точности им хватало меньше шагов обучения. Повторы плохи ещё и для проверки: если проверочный текст лежит и в обучении, ошибка на проверке врёт, как в уроке «Машинное обучение: baseline и отложенная проверка» (шаг 9).

Настоящие наборы большие. FineWeb, открытый набор 2024 года, это 15 триллионов токенов из 96 снимков Common Crawl, большого архива веба. Его авторы тоже чистили почти-копии через MinHash и подробно описали, какие фильтры помогли, а какие нет.

**Что здесь спорно.** Какой текст считать хорошим, решают люди, и фильтры несут их взгляды. Dodge и соавторы в 2021 году показали, что фильтр запрещённых слов в C4 непропорционально выбрасывал тексты меньшинств и о меньшинствах, например на афроамериканском английском и о ЛГБТ. Поэтому авторы хороших наборов проверяют каждый фильтр опытом: учат модель с ним и без него.

**Учись у тех, кто это создаёт.** Статьи [Deduplicating Training Data Makes Language Models Better](https://arxiv.org/abs/2107.06499) и [The FineWeb Datasets](https://arxiv.org/abs/2406.17557). Курс [Stanford CS336](https://cs336.stanford.edu/), лекции о данных.

### Исследуй и потренируйся

В тренажёре ниже клетка таблицы это сходство двух текстов, чем ярче, тем ближе. Двигай порог: тексты, похожие сильнее порога, выпадают. В начале порог 0,95, и ничего не выпадает. Найди порог, при котором уходят обе почти-копии, а пересказ про пса остаётся.

### Вопрос

Тексты «Кот спал на тёплом окне и смотрел, как падает снег.» и «…как падал снег.» не поймала проверка по хешу. Почему?

### Варианты

- Хеш одинаков только у совершенно одинаковых текстов, а здесь отличается одно слово
- Хеш-функция ошиблась, и с правильной функцией эти тексты дали бы один отпечаток
- Перед хешем тексты не привели к нижнему регистру, поэтому они и вышли разными

### Ответ

1

### Разбор

Хеш меняется целиком от изменения одной буквы, так он и устроен. Поэтому он ловит только точные копии. Регистр здесь ни при чём: программа приводит тексты к нижнему регистру, и в этих двух текстах регистр одинаков. Для почти-копий нужно сравнивать содержимое, например наборы кусочков по Жаккару.

### Границы модели

Коллекция из 12 строк выбрана так, чтобы показать каждый случай. В настоящих наборах миллиарды документов, и там важны скорость, память и ошибки самих фильтров. Мы не разбирали фильтры по языку и качеству на основе моделей, а также смесь источников: сколько брать кода, книг и веба.

## English

### In plain words

A model learns from what it is given. If the texts are full of junk and repeats, it learns junk and repeats. So before training the texts are cleaned: scraps, site menus and spam are thrown out, and only one of each copy is kept. It is like preparing for an exam from classmates' notes: ten identical photocopies of one lecture do not make you smarter, they only take time. In the lesson you clean a small collection of texts in three ways and find near-copies that a plain comparison cannot see. The texts are in Russian, as everywhere in this course; the methods do not depend on the language.

**What to know first.** «Strings, Files, and Exceptions» (step 2): working with text. «Collections and Loops» (step 2): sets and dictionaries. «Scaling laws and the cost of training» (step 16): why models need so much text.

**If something is unclear.** If it is unclear what a set is in Python, go back to «Collections and Loops»: it is a collection without repeats. A hash is a short fingerprint of a text: identical texts give identical fingerprints. Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Go through three steps of data cleaning, as in real training sets: quality filters, removal of exact copies by hash, and finding near-copies by Jaccard similarity and MinHash. Understand why repeats do harm and why the similarity threshold is a human decision. It takes about 30 minutes.

### Idea and mechanism

**Step 1. Filters.** Real sets are collected from the web, which holds a lot of junk. The C4 set kept only lines ending in a terminal punctuation mark and dropped too-short ones. We take three simple rules: a text has at least 5 words, it ends with a full stop, exclamation or question mark, and at least half of its words are different. Create the file `nano ~/ai-path/data.py`, paste and run it.

```python
import hashlib

DOCS = [
    "Кот спал на тёплом окне и смотрел, как падает снег.",
    "Градиентный спуск уменьшает ошибку маленькими шагами против градиента.",
    "Главная | Новости | Контакты | Войти | Корзина",
    "Кот спал на тёплом окне и смотрел, как падает снег.",
    "Купить дёшево! Купить дёшево! Купить дёшево! Купить дёшево!",
    "Градиентный спуск уменьшает ошибку небольшими шагами против градиента.",
    "Ок",
    "Модель внимания сама выбирает, на какие прошлые токены смотреть.",
    "Пёс гулял во дворе и искал свой мяч под старой скамейкой.",
    "Кот спал на тёплом окне и смотрел, как падал снег.",
    "Токенизатор BPE склеивает самую частую пару кусочков текста.",
    "Пёс гулял по двору и искал мяч под скамейкой у подъезда.",
]


def quality(doc):
    words = doc.split()
    if len(words) < 5:
        return "too short"
    if doc[-1] not in ".!?":
        return "no full stop at the end"
    if len(set(words)) / len(words) < 0.5:
        return "repeats itself"
    return None


kept = []
for index, doc in enumerate(DOCS):
    reason = quality(doc)
    if reason:
        print(f"[{index}] removed: {reason}")
    else:
        kept.append(index)
print("kept after filters:", kept)
```

```output
[2] removed: no full stop at the end
[4] removed: repeats itself
[6] removed: too short
kept after filters: [0, 1, 3, 5, 7, 8, 9, 10, 11]
```

The site menu went because it does not end with a full stop. The spam «Купить дёшево!» ("buy cheap!") went because it has 2 different words out of 8. The scrap «Ок» is too short. Note: the rules are crude and they err both ways. A poem without a full stop at the end would go too.

**Step 2. Exact copies.** Text [3] is an exact copy of [0]. Comparing every text with every other is slow, so each text gets a *hash*, a short fingerprint, and the fingerprints go into a set. If a fingerprint is already there, it is a copy. Add this and run it.

```python
seen, unique = set(), []
for index in kept:
    key = hashlib.sha1(" ".join(DOCS[index].lower().split()).encode()).hexdigest()
    if key in seen:
        print(f"[{index}] exact copy removed")
    else:
        seen.add(key)
        unique.append(index)
print("unique:", unique)
```

```output
[3] exact copy removed
unique: [0, 1, 5, 7, 8, 9, 10, 11]
```

**Step 3. Near-copies.** Texts [0] and [9] differ in one word: «падает» and «падал» ("is falling" and "was falling"). Their hashes differ, and step 2 did not catch them. To find such pairs, a text is cut into *pieces* of 5 characters, and the sets of pieces are compared. *Jaccard similarity* is the share of shared pieces among all of them: `|A ∩ B| / |A ∪ B|`. By hand on a small example: the 2-character pieces of «мама» are «ма», «ам», «ма», that is the set {«ма», «ам»}. For «мамы» the set is {«ма», «ам», «мы»}. Two are shared, three differ in all, similarity `2 / 3 ≈ 0.67`.

For billions of texts even this is too slow, so *MinHash* is used. For each text, 64 different hash functions are computed over all its pieces, and the smallest value of each is kept. The share of matching smallest values of two texts is roughly their Jaccard similarity. Add this and run it.

```python
def shingles(doc, size=5):
    text = " ".join(doc.lower().split())
    return {text[i:i + size] for i in range(len(text) - size + 1)}


def jaccard(a, b):
    return len(a & b) / len(a | b)


def minhash(pieces, count=64):
    return [min(int(hashlib.md5(f"{seed}:{piece}".encode()).hexdigest()[:12], 16) for piece in pieces) for seed in range(count)]


sets = {i: shingles(DOCS[i]) for i in unique}
signs = {i: minhash(sets[i]) for i in unique}
for a in unique:
    for b in unique:
        if a < b:
            exact = jaccard(sets[a], sets[b])
            estimate = sum(x == y for x, y in zip(signs[a], signs[b])) / 64
            if exact > 0.2:
                print(f"[{a}] and [{b}]: Jaccard {exact:.2f}, MinHash estimate {estimate:.2f}")
```

```output
[0] and [9]: Jaccard 0.79, MinHash estimate 0.72
[1] and [5]: Jaccard 0.70, MinHash estimate 0.72
[8] and [11]: Jaccard 0.31, MinHash estimate 0.36
```

The pairs [0] and [9] and [1] and [5] are near-copies: similarity 0.79 and 0.70. The dog pair [8] and [11] is similar at 0.31: it is a retelling, not a copy. The MinHash estimate differs from the exact number by 0.02–0.07: that is the price of speed. Where to set the threshold is a human decision. At a threshold of 0.6 the two near-copies go and the retelling stays.

**Step 4. Why this matters.** Lee and co-authors deduplicated real sets in 2021. In the C4 set they found a 61-word sequence repeated 61,036 times. After cleaning, models emitted memorised text 10 times less often and needed fewer training steps for the same accuracy. Repeats also hurt evaluation: if a test text is also in training, the test error lies, as in «Machine Learning: Baselines and Held-out Evaluation» (step 9).

Real sets are large. FineWeb, an open set from 2024, is 15 trillion tokens from 96 snapshots of Common Crawl, a big archive of the web. Its authors also removed near-copies with MinHash and described in detail which filters helped and which did not.

**What is disputed.** Which text counts as good is decided by people, and filters carry their views. Dodge and co-authors showed in 2021 that the banned-word filter of C4 disproportionately removed text from and about minority individuals, for example African American English and text about LGBTQ+ identities. So the authors of good sets test each filter by experiment: they train a model with it and without it.

**Learn from the people who build this.** The papers [Deduplicating Training Data Makes Language Models Better](https://arxiv.org/abs/2107.06499) and [The FineWeb Datasets](https://arxiv.org/abs/2406.17557). The [Stanford CS336](https://cs336.stanford.edu/) course, the lectures on data.

### Explore and practise

In the lab below a table cell is the similarity of two texts; the brighter, the closer. Move the threshold: texts more similar than the threshold drop out. At the start the threshold is 0.95 and nothing drops. Find a threshold at which both near-copies go while the dog retelling stays.

### Question

The texts «Кот спал на тёплом окне и смотрел, как падает снег.» and «…как падал снег.» were not caught by the hash check. Why?

### Options

- A hash is equal only for exactly identical texts, and here one word is different
- The hash function made a mistake; a correct one would give these texts one fingerprint
- The texts were not lowercased before hashing, and that is why they came out different

### Answer

1

### Explanation

A hash changes completely when one letter changes; that is how it is built. So it catches only exact copies. Case has nothing to do with it: the program lowercases the texts, and these two texts have the same case anyway. Near-copies need a comparison of content, for example sets of pieces by Jaccard.

### Limits

The 12-line collection was chosen to show each case. Real sets hold billions of documents, and speed, memory and the errors of the filters themselves matter there. We did not cover language and quality filters based on models, nor the mix of sources: how much code, books and web to take.

## Sources

- Katherine Lee et al., "Deduplicating Training Data Makes Language Models Better", arXiv:2107.06499 (2021): NearDup with MinHash, the 61-word sequence repeated 61,036 times in C4, ten times less memorised text, read 2026-11-07: [arXiv:2107.06499](https://arxiv.org/abs/2107.06499)
- Guilherme Penedo et al., "The FineWeb Datasets: Decanting the Web for the Finest Text Data at Scale", arXiv:2406.17557 (2024): 15 trillion tokens from 96 Common Crawl snapshots, MinHash deduplication, and the description of the C4 filters (lines ending in a terminal punctuation mark), read 2026-11-07: [arXiv:2406.17557](https://arxiv.org/abs/2406.17557)
- Jesse Dodge et al., "Documenting Large Webtext Corpora: A Case Study on the Colossal Clean Crawled Corpus", arXiv:2104.08758 (2021): blocklist filtering disproportionately removes text from and about minority individuals, read in the abstract and introduction on 2026-11-07: [arXiv:2104.08758](https://arxiv.org/abs/2104.08758)
- The 12 texts, the program and all numbers were written for this lesson on 2026-11-07.
