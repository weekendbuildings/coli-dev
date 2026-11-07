---
subject: programming
lesson_id: programming.tokenizer_bpe
level: advanced
languages: ru, en
source_checked: 2026-11-02
source_review_interval_days: 365
---

# Свой токенизатор / Your own tokenizer

## Русский

### Простыми словами

Модель не читает буквы и слова, она читает токены: кусочки текста из своего словаря. Токенизатор BPE строит этот словарь сам. Он находит пару кусочков, которая встречается чаще всего, склеивает её в один новый кусочек и повторяет. Похоже на стенографию: частые сочетания получают свой короткий значок. Поэтому частые слова становятся одним токеном, а редкие и русские разбиваются на много кусочков.

**Что нужно знать до.** Урок «Живая модель на твоём Mac» (шаг 1): что такое токен. Урок «Строки, файлы и исключения» (шаг 2).

**Если непонятно.** Если неясно, что такое байт, считай так: каждая буква хранится как одно или несколько чисел от 0 до 255, и русская буква занимает два таких числа. Если неясна программа, вернись к урокам шага 2. Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Написать на чистом Python токенизатор BPE, обучить его на тексте и своими глазами увидеть, откуда берутся токены и почему русский текст у моделей занимает больше токенов. Это первая часть первого задания стэнфордского курса CS336. Нужно около 40 минут.

### Идея и механизм

В первом уроке ты видел, что `Привет` это 3 токена, а `Hello` один. Сегодня выясним почему. Модель работает с числами, поэтому текст нужно превратить в числа. Можно взять буквы, но тогда словарь короткий, а текст длинный. Можно взять целые слова, но слов слишком много, и новое слово модель не поймёт. Нужна середина, и её находят по самому тексту.

**Шаг 1. Пример руками.** Возьмём текст `hug hug pug`. В нём 11 знаков. Посчитаем соседние пары: `ug` встречается 3 раза, чаще всех. Дадим этой паре новый знак и заменим везде:

- было `h u g ␣ h u g ␣ p u g`, 11 токенов;
- стало `h ug ␣ h ug ␣ p ug`, 8 токенов;
- теперь чаще всех `h` и `ug`, по 2 раза; сливаем: `hug ␣ hug ␣ p ug`, 6 токенов.

Это и есть *BPE*, byte pair encoding. Весь алгоритм: найди самую частую пару, дай ей новый номер, повтори. Токенами становятся те куски, что часто встречаются.

**Шаг 2. Текст это байты.** Компьютер хранит текст как *байты*, числа от 0 до 255. Латинская буква занимает один байт, а русская два. Создай файл, вставь программу, сохрани и запусти:

```bash
cd ~/ai-path && nano tokenizer.py
```

```python
TEXT = (
    "Модель читает текст кусочками. Кусочки называют токенами. "
    "Модель учится на текстах, и текст становится токенами, а токены становятся числами. "
    "The model reads text in pieces, and the pieces of text are called tokens. "
)
tokens = list(TEXT.encode("utf-8"))
print(len(TEXT), len(tokens))
print(list("Привет".encode("utf-8")), list("Hi".encode("utf-8")))


def count_pairs(ids):
    counts = {}
    for pair in zip(ids, ids[1:]):
        counts[pair] = counts.get(pair, 0) + 1
    return counts


def merge(ids, pair, new):
    result, i = [], 0
    while i < len(ids):
        if i + 1 < len(ids) and (ids[i], ids[i + 1]) == pair:
            result.append(new)
            i += 2
        else:
            result.append(ids[i])
            i += 1
    return result


vocab = {i: bytes([i]) for i in range(256)}
merges = {}
for number in range(40):
    counts = count_pairs(tokens)
    best = max(counts, key=counts.get)
    new = 256 + number
    tokens = merge(tokens, best, new)
    merges[best] = new
    vocab[new] = vocab[best[0]] + vocab[best[1]]
    if number < 5 or (number + 1) % 10 == 0:
        print(number + 1, repr(vocab[new].decode("utf-8", "replace")), counts[best], len(tokens))
```

```output
216 334
[208, 159, 209, 128, 208, 184, 208, 178, 208, 181, 209, 130] [72, 105]
1 'т' 17 317
2 'а' 12 305
3 'с' 11 294
4 'и' 10 284
5 'о' 9 275
10 'е�' 5 239
20 ' те' 3 199
30 'тся' 3 169
40 'Модель ' 2 147
```

Первая строка вывода: в тексте 216 знаков, но 334 байта. Вторая: `Привет` занимает 12 байтов, а `Hi` два. В следующих строках номер слияния, новый токен, сколько раз встретилась пара и сколько токенов осталось в тексте.

Посмотри, что склеилось первым: `т`, `а`, `с`, `и`, `о`. Это русские буквы: каждая состоит из двух байтов, и эта пара встречается очень часто. Значит, первые слияния уходят только на то, чтобы собрать буквы. Англичанину они не нужны: его буква и так один байт. Вот первая причина, почему русский «дороже». Значок `�` в строке 10 это половина буквы: токену необязательно совпадать с границами букв.

К слиянию 40 появился токен `Модель ` с пробелом на конце. Вот почему в первом уроке ` Paris` начинался с пробела: частые слова склеиваются вместе с пробелом рядом.

**Шаг 3. Кодирование и обратно.** Теперь токенизатор надо применить к новому тексту. Функция `encode` применяет слияния в том порядке, в каком они выучены, а `decode` склеивает байты обратно. Допиши:

```python
def encode(text):
    ids = list(text.encode("utf-8"))
    while len(ids) > 1:
        pairs = count_pairs(ids)
        pair = min(pairs, key=lambda p: merges.get(p, float("inf")))
        if pair not in merges:
            break
        ids = merge(ids, pair, merges[pair])
    return ids


def decode(ids):
    return b"".join(vocab[i] for i in ids).decode("utf-8", "replace")


for sample in ("Модель читает токены", "The model reads", "Кошка спит на окне"):
    ids = encode(sample)
    print(len(sample.encode("utf-8")), len(ids), [decode([i]) for i in ids][:9], decode(ids) == sample)
```

```output
38 9 ['Модель ', 'чи', 'т', 'а', 'е', 'т', ' токен', '�', '�'] True
15 14 ['T', 'h', 'e ', 'm', 'o', 'd', 'e', 'l', ' '] True
33 23 ['�', '�', 'о', '�', '�', 'к', 'а', ' ', 'с'] True
```

В строке сначала байты, потом токены, потом первые токены и проверка, что текст вернулся без потерь. Главное здесь: **токены зависят от текста, на котором токенизатор учился.** Похожая на обучающий текст фраза сжалась с 38 байтов до 9 токенов. Английская сжалась слабо, с 15 до 14: английских слов в нашем тексте мало. А новые русские слова сжались плохо, с 33 до 23, и некоторые буквы остались по кускам.

Вот и вторая причина, почему у `qwen2.5-coder:7b` слово `Привет` занимает 3 токена. Её словарь из 152 064 токенов выучен на текстах, где, судя по всему, намного больше английского и кода. Для другой модели число будет другим.

**Учись у тех, кто это создаёт.** Андрей Карпатый посвятил этому лекцию на 2 часа 13 минут, «Let's build the GPT Tokenizer», а его код лежит в проекте minbpe. В переводчиках метод предложили Рико Зеннрих и соавторы в 2015 году. Токенизатор входит в первое задание стэнфордского CS336. Ссылки в разделе источников.

### Исследуй и потренируйся

В тренажёре текст разбит на плитки. Сначала видны байты: половинки русских букв показаны шестнадцатеричными числами, например `D0`. Жёлтым отмечена пара, которая сольётся следующей. Нажимай «Слить пару» и смотри, как байты собираются в буквы, буквы в слоги, слоги в слова. Попробуй свой текст и сравни русский с английским.

В программе поменяй число слияний с 40 на 100. Как изменились новые русские слова? Что будет, если обучить токенизатор только на английском и подать русскую фразу?

**Собери и проверь сам.** Код выше дан готовым. Теперь напиши ключевой шаг своими руками: подсчёт пар, слияние без перекрытий и кодирование в порядке выученных слияний. Заготовка и строгая проверка лежат в папке проекта `01_Projects/creator_labs`. Скопируй её к себе (уже написанные тобой файлы не перезапишутся) и запусти проверку:

```bash
mkdir -p ~/ai-path && cp -Rn ~/Desktop/"coli-dev 4"/coli-dev/01_Projects/creator_labs ~/ai-path/
cd ~/ai-path/creator_labs && python3 check_tokenizer_bpe.py
```

Сначала все строки будут с ✗. Открой `tokenizer_blank.py`, допиши функции, где стоит `NotImplementedError`, и запускай проверку, пока все строки не станут ✓. Проверка сверяет твой код с численной производной, граничными случаями и свойствами, которые обязаны выполняться всегда. В самом файле проверки есть ответ: открывай его только после своей попытки.

### Вопрос

Почему первыми слияниями в нашем тексте стали отдельные русские буквы?

### Варианты

- Русская буква занимает два байта, и эта пара байтов встречается чаще других.
- Токенизатор заранее знает русский алфавит и собирает его буквы раньше всего.
- Русские буквы редки в тексте, и алгоритм в первую очередь сливает редкие пары.

### Ответ

1

### Разбор

Алгоритм не знает ни букв, ни языков, он только считает пары чисел. Пара байтов одной частой буквы встречается чаще всего, поэтому она и сливается первой. Редкие пары он как раз сливает последними.

### Границы модели

Наш текст крошечный, поэтому и словарь учебный. Настоящие токенизаторы сначала делят текст на части по шаблону, например отдельно слова и знаки, чтобы слияния не шли через границу слова, и имеют особые токены вроде `<|im_start|>` из урока о чате. Наша функция заново считает все пары на каждом слиянии, и на больших текстах это слишком медленно. Почему именно у этой модели `Привет` занимает 3 токена, я объясняю по косвенным признакам: состав её обучающих текстов я не проверял.

## English

### In plain words

A model does not read letters or words; it reads tokens: pieces of text from its vocabulary. The BPE tokenizer builds that vocabulary itself. It finds the pair of pieces that occurs most often, glues it into one new piece and repeats. It is like shorthand: frequent combinations get their own short sign. That is why frequent words become one token, while rare and Russian words split into many pieces.

**What to know first.** «A live model on your Mac» (step 1): what a token is. «Strings, Files, and Exceptions» (step 2).

**If something is unclear.** If a byte is unclear, think of it this way: each letter is stored as one or more numbers from 0 to 255, and a Russian letter takes two such numbers. If the program is unclear, go back to the lessons of step 2. Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Write a BPE tokenizer in plain Python, train it on a text, and see with your own eyes where tokens come from and why Russian text takes more tokens in models. This is the first part of the first assignment of Stanford's CS336 course. It takes about 40 minutes.

### Idea and mechanism

In the first lesson you saw that `Привет` is 3 tokens and `Hello` is one. Today we find out why. A model works with numbers, so a text must become numbers. We could take letters, but then the dictionary is short and the text long. We could take whole words, but there are too many, and the model would not understand a new word. We need a middle, and it is found from the text itself.

**Step 1. An example by hand.** Take the text `hug hug pug`. It has 11 signs. Count neighbouring pairs: `ug` occurs 3 times, more than any other. Give this pair a new sign and replace it everywhere:

- it was `h u g ␣ h u g ␣ p u g`, 11 tokens;
- it became `h ug ␣ h ug ␣ p ug`, 8 tokens;
- now `h` and `ug` are most frequent, 2 times each; merge them: `hug ␣ hug ␣ p ug`, 6 tokens.

This is *BPE*, byte pair encoding. The whole algorithm: find the most frequent pair, give it a new number, repeat. Tokens become the pieces that occur often.

**Step 2. A text is bytes.** A computer stores a text as *bytes*, numbers from 0 to 255. A Latin letter takes one byte and a Russian letter two. Create a file, paste the program, save it, and run it:

```bash
cd ~/ai-path && nano tokenizer.py
```

```python
TEXT = (
    "Модель читает текст кусочками. Кусочки называют токенами. "
    "Модель учится на текстах, и текст становится токенами, а токены становятся числами. "
    "The model reads text in pieces, and the pieces of text are called tokens. "
)
tokens = list(TEXT.encode("utf-8"))
print(len(TEXT), len(tokens))
print(list("Привет".encode("utf-8")), list("Hi".encode("utf-8")))


def count_pairs(ids):
    counts = {}
    for pair in zip(ids, ids[1:]):
        counts[pair] = counts.get(pair, 0) + 1
    return counts


def merge(ids, pair, new):
    result, i = [], 0
    while i < len(ids):
        if i + 1 < len(ids) and (ids[i], ids[i + 1]) == pair:
            result.append(new)
            i += 2
        else:
            result.append(ids[i])
            i += 1
    return result


vocab = {i: bytes([i]) for i in range(256)}
merges = {}
for number in range(40):
    counts = count_pairs(tokens)
    best = max(counts, key=counts.get)
    new = 256 + number
    tokens = merge(tokens, best, new)
    merges[best] = new
    vocab[new] = vocab[best[0]] + vocab[best[1]]
    if number < 5 or (number + 1) % 10 == 0:
        print(number + 1, repr(vocab[new].decode("utf-8", "replace")), counts[best], len(tokens))
```

```output
216 334
[208, 159, 209, 128, 208, 184, 208, 178, 208, 181, 209, 130] [72, 105]
1 'т' 17 317
2 'а' 12 305
3 'с' 11 294
4 'и' 10 284
5 'о' 9 275
10 'е�' 5 239
20 ' те' 3 199
30 'тся' 3 169
40 'Модель ' 2 147
```

The first line of output: the text has 216 signs but 334 bytes. The second: `Привет` takes 12 bytes and `Hi` two. The next lines give the merge number, the new token, how many times the pair occurred, and how many tokens remain in the text.

Look at what was glued first: `т`, `а`, `с`, `и`, `о`. These are Russian letters: each is two bytes, and this pair occurs very often. So the first merges go only to assembling letters. An English speaker does not need them: a letter is already one byte. That is the first reason Russian is "costlier". The sign `�` in line 10 is half a letter: a token need not match letter boundaries.

By merge 40 the token `Модель ` appeared, with a space at the end. That is why ` Paris` in the first lesson began with a space: frequent words are glued together with a nearby space.

**Step 3. Encoding and back.** Now the tokenizer must be applied to a new text. The function `encode` applies merges in the order they were learned, and `decode` glues the bytes back. Add this:

```python
def encode(text):
    ids = list(text.encode("utf-8"))
    while len(ids) > 1:
        pairs = count_pairs(ids)
        pair = min(pairs, key=lambda p: merges.get(p, float("inf")))
        if pair not in merges:
            break
        ids = merge(ids, pair, merges[pair])
    return ids


def decode(ids):
    return b"".join(vocab[i] for i in ids).decode("utf-8", "replace")


for sample in ("Модель читает токены", "The model reads", "Кошка спит на окне"):
    ids = encode(sample)
    print(len(sample.encode("utf-8")), len(ids), [decode([i]) for i in ids][:9], decode(ids) == sample)
```

```output
38 9 ['Модель ', 'чи', 'т', 'а', 'е', 'т', ' токен', '�', '�'] True
15 14 ['T', 'h', 'e ', 'm', 'o', 'd', 'e', 'l', ' '] True
33 23 ['�', '�', 'о', '�', '�', 'к', 'а', ' ', 'с'] True
```

A line gives the bytes, then the tokens, then the first tokens and a check that the text came back without loss. The main thing: **tokens depend on the text the tokenizer learned from.** A phrase like the training text shrank from 38 bytes to 9 tokens. An English one shrank little, from 15 to 14: our text has few English words. And new Russian words shrank poorly, from 33 to 23, with some letters left in pieces.

That is the second reason `Привет` takes 3 tokens in `qwen2.5-coder:7b`. Its dictionary of 152,064 tokens was learned on texts with, it seems, far more English and code. For another model the number will differ.

**Learn from those who build this.** Andrej Karpathy gave this a lecture of 2 hours 13 minutes, "Let's build the GPT Tokenizer", and his code is in the minbpe project. For translators the method was proposed by Rico Sennrich and colleagues in 2015. A tokenizer is part of the first assignment of Stanford's CS336. The links are in the sources.

### Explore and practise

In the lab the text is cut into tiles. At first you see bytes: halves of Russian letters show as hexadecimal numbers, such as `D0`. Yellow marks the pair that merges next. Press "Merge the pair" and watch bytes gather into letters, letters into syllables, syllables into words. Try your own text and compare Russian with English.

In the program, change the number of merges from 40 to 100. How did the new Russian words change? What happens if you train the tokenizer on English only and give it a Russian phrase?

**Build and check it yourself.** The code above was given ready-made. Now write the key step with your own hands: pair counting, merging without overlaps and encoding in the learned merge order. The blank and a strict check are in the project folder `01_Projects/creator_labs`. Copy it (files you have already written are not overwritten) and run the check:

```bash
mkdir -p ~/ai-path && cp -Rn ~/Desktop/"coli-dev 4"/coli-dev/01_Projects/creator_labs ~/ai-path/
cd ~/ai-path/creator_labs && python3 check_tokenizer_bpe.py
```

At first every line shows ✗. Open `tokenizer_blank.py`, fill in the functions that raise `NotImplementedError`, and rerun until every line shows ✓. The check compares your code with numerical derivatives, edge cases and invariants that must always hold. The check file itself contains the answer: open it only after your own attempt.

### Question

Why were the first merges in our text separate Russian letters?

### Options

- A Russian letter takes two bytes, and this pair of bytes occurs more than others.
- The tokenizer knows the Russian alphabet in advance and gathers its letters first.
- Russian letters are rare in the text, and the algorithm merges rare pairs first.

### Answer

1

### Explanation

The algorithm knows neither letters nor languages; it only counts pairs of numbers. The pair of bytes of one frequent letter occurs most often, so it merges first. Rare pairs it merges last.

### Limits

Our text is tiny, so the dictionary is a teaching one. Real tokenizers first divide a text into parts by a pattern, such as words and signs apart, so that merges do not cross a word boundary, and they have special tokens like `<|im_start|>` from the chat lesson. Our function recounts all pairs at each merge, which is too slow on large texts. Why `Привет` takes 3 tokens in this model I explain by indirect signs: I did not check what texts it trained on.

## Sources

- Andrej Karpathy, "Let's build the GPT Tokenizer", in Neural Networks: Zero to Hero (consulted 2026-11-02): [Zero to Hero](https://karpathy.ai/zero-to-hero.html), [minbpe](https://github.com/karpathy/minbpe)
- Rico Sennrich, Barry Haddow, Alexandra Birch, "Neural Machine Translation of Rare Words with Subword Units", arXiv:1508.07909 (2015), title read 2026-11-02: [arXiv:1508.07909](https://arxiv.org/abs/1508.07909)
- Tatsunori Hashimoto, Percy Liang, Stanford CS336, spring 2026 (schedule read 2026-11-02): lecture 1 and assignment 1, which implements a tokenizer: [CS336](https://cs336.stanford.edu/)
- The size of the dictionary was read from this model with `/api/show` on 2026-11-02. The program and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
