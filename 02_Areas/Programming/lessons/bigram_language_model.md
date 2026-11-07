---
subject: programming
lesson_id: programming.bigram_language_model
level: intermediate
languages: ru, en
source_checked: 2026-11-07
source_review_interval_days: 180
---

# Счётчик пар: первая языковая модель / A pair counter: the first language model

## Русский

### Простыми словами

Самая простая языковая модель смотрит только на последнюю букву и угадывает следующую. Для этого она один раз пересчитывает в тексте, какая буква за какой идёт. Похоже на то, как ты угадываешь слово по первым буквам в кроссворде: после «щ» почти всегда идёт гласная. Такая модель пишет похожие на язык обрывки, но смысла в них нет. Зато на ней видны три вещи, которые есть и у больших моделей: вероятности, температура и проверка на тексте, которого модель не видела.

**Что нужно знать до.** Урок «Вероятность и формула Байеса» (шаг 5): условная вероятность. Урок «Информация, энтропия и кросс-энтропия» (шаг 6): ошибка как удивление. Урок «Свой токенизатор» (шаг 10): из чего состоит текст.

**Если непонятно.** Если неясно, почему вероятность это доля, вернись к уроку «Вероятность и формула Байеса». Если неясна ошибка в натах, перечитай урок «Информация, энтропия и кросс-энтропия». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Построить первую языковую модель целиком своими руками: посчитать пары букв, получить из них вероятности, написать текст с разной температурой и честно проверить модель на новом тексте. Понять, почему без сглаживания модель ломается на первой незнакомой паре. Нужно около 30 минут.

### Идея и механизм

**Шаг 1. Пары руками.** Возьмём фразу «мама мыла раму». Выпиши, что идёт после каждой буквы «м»: «а», «а», «ы», «у». Всего 4 раза. Значит, после «м» буква «а» идёт в 2 случаях из 4, и её вероятность `P(а | м) = 2 / 4 = 0,5`. Запись `P(а | м)` читается «вероятность „а“ при условии, что перед ней „м“». Модель, которая хранит такие доли для всех пар, называют *биграммной*, или *счётчиком пар*. Это первая модель из курса Карпатого makemore.

**Шаг 2. Программа.** Создай файл `nano ~/ai-path/bigram.py`, вставь и запусти командой `python3 ~/ai-path/bigram.py`. Текст для обучения небольшой и записан прямо в программе, чтобы всё считалось за долю секунды.

```python
import math

TRAIN = (
    "мама мыла раму. папа читал книгу. мама читала книгу сыну. "
    "кот спал на окне. пёс спал у двери. кот видел пса, а пёс видел кота. "
    "сын читал книгу коту. мама мыла окно. папа мыл пол. кот мыл лапу. "
    "утром мама пила чай, а папа пил кофе. вечером сын пил молоко. "
    "пёс любил гулять, а кот любил спать. мама любила книги. "
)
TEST = "папа читал книгу маме. кот спал у окна. сын любил молоко. "
LETTERS = sorted(set(TRAIN + TEST))

counts = {}
for a, b in zip(TRAIN, TRAIN[1:]):
    counts.setdefault(a, {})
    counts[a][b] = counts[a].get(b, 0) + 1

row = counts["м"]
total = sum(row.values())
print("letters in the alphabet:", len(LETTERS))
print("after 'м' seen", total, "times:")
for b, c in sorted(row.items(), key=lambda kv: (-kv[1], kv[0]))[:5]:
    print(f"  {b!r}: {c} times, P = {c / total:.3f}")
```

```output
letters in the alphabet: 28
after 'м' seen 18 times:
  'а': 10 times, P = 0.556
  'ы': 4 times, P = 0.222
  ' ': 2 times, P = 0.111
  'о': 1 times, P = 0.056
  'у': 1 times, P = 0.056
```

Что ты увидел: в нашем тексте после «м» буква «а» идёт 10 раз из 18, поэтому `P(а | м) = 10 / 18 = 0,556`. Вся модель это таблица таких чисел: 28 строк и 28 столбцов, по одной строке на каждую букву.

**Шаг 3. Пишем текст.** Чтобы написать текст, модель берёт последнюю букву, смотрит её строку и бросает «кубик» с неравными гранями: частая буква выпадает чаще. *Температура* `T` меняет неравенство граней. Здесь вес каждой буквы равен числу её появлений в степени `1 / T`. Руками: после «м» у «а» 10 раз, у «ы» 4 раза. При `T = 1` отношение весов `10 / 4 = 2,5`. При `T = 0,5` веса возводятся в квадрат: `100 / 16 = 6,25`, частая буква выигрывает ещё чаще. При `T = 2` берётся корень: `3,16 / 2 = 1,58`, выбор ровнее. Это та же температура, что в уроке «Живая модель на твоём Mac» (шаг 1), только на своей модели. Допиши в файл и запусти.

```python
class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


def next_letter(a, temperature, rand):
    row = counts.get(a, {" ": 1})
    weights = {b: c ** (1 / temperature) for b, c in row.items()}
    total = sum(weights.values())
    r = rand.next() * total
    for b in sorted(weights):
        r -= weights[b]
        if r <= 0:
            return b
    return b


for temperature in (0.3, 1.0, 3.0):
    rand = Rand(7)
    text = "м"
    for _ in range(45):
        text += next_letter(text[-1], temperature, rand)
    print(f"T = {temperature}: {text}")
```

```output
T = 0.3: мала книла ма па па сыл кот па книл л книгу. ч
T = 1.0: мапёс кнечиде. кнокнутал сыла па кота а л коть
T = 3.0: мофел гу. пил па у витамапу рал гилюби. л деро
```

При низкой температуре текст повторяет частые куски, при высокой рассыпается на случайные буквы. Слова похожи на русские только кусками: модель помнит одну букву назад и не знает, где начало слова.

**Шаг 4. Честная проверка.** Ошибка модели это среднее удивление настоящим текстом: `−ln P(следующая | текущая)`, в натах. Её меряют на тексте, которого модель не видела, иначе проверяется память. Для сравнения: если угадывать все 28 букв одинаково, ошибка равна `ln 28 = 3,332`. Допиши и запусти.

```python
def loss(text, alpha):
    V = len(LETTERS)
    total = 0.0
    pairs = list(zip(text, text[1:]))
    for a, b in pairs:
        row = counts.get(a, {})
        p = (row.get(b, 0) + alpha) / (sum(row.values()) + alpha * V)
        if p == 0:
            return math.inf
        total -= math.log(p)
    return total / len(pairs)


print("guessing at random:", round(math.log(len(LETTERS)), 3))
for alpha in (0, 0.001, 0.01, 0.1, 1, 3):
    print(f"alpha = {alpha}: train {loss(TRAIN, alpha):.3f}, test {loss(TEST, alpha):.3f}")
unseen = [(a, b) for a, b in zip(TEST, TEST[1:]) if counts.get(a, {}).get(b, 0) == 0]
print("pairs in the test never seen in training:", len(unseen), unseen[:4])
```

```output
guessing at random: 3.332
alpha = 0: train 1.371, test inf
alpha = 0.001: train 1.373, test 1.563
alpha = 0.01: train 1.392, test 1.538
alpha = 0.1: train 1.542, test 1.627
alpha = 1: train 2.154, test 2.186
alpha = 3: train 2.585, test 2.610
pairs in the test never seen in training: 1 [('м', 'е')]
```

Главное здесь первая строка. При `α = 0` ошибка на проверке бесконечна. Причина одна-единственная пара: «ме» из слова «маме» ни разу не встретилась в обучении, модель дала ей вероятность ноль, а `−ln 0` это бесконечность. Это тот же «ноль смертелен» из урока «Информация, энтропия и кросс-энтропия». Лечение называют *сглаживанием*: к каждому счёту прибавляют маленькое `α`, и формула становится `P(b | a) = (c(a, b) + α) / (c(a) + α · V)`, где `c` это счёт, а `V = 28` число букв. Руками: для «ме» при `α = 0,01` выходит `(0 + 0,01) / (18 + 0,28) ≈ 0,00055`. Мало, но не ноль.

Заметь цену: чем больше `α`, тем хуже ошибка на обучении, потому что модель всё ровнее и всё меньше помнит текст. На проверке лучше всего здесь `α = 0,01`: ошибка `1,538`, намного ниже случайных `3,332`. Это и есть компромисс из урока «Мини-батчи и переобучение» (шаг 9), только в самой простой модели.

**Шаг 5. Тренажёр.** В тренажёре ниже нажми на букву и посмотри её строку вероятностей. Подвигай температуру и сглаживание, найди, где ошибка на проверке бесконечна и где она меньше всего.

**Что дальше.** Счётчик пар не видит дальше одной буквы. Можно считать тройки и четвёрки, но таблица растёт как `28³`, `28⁴`, а большинство клеток остаются пустыми. Нейросеть решает это иначе: вместо таблицы она учит векторы и сама находит, что похоже. Это следующий урок, «Эмбеддинги и сходство».

**Учись у тех, кто это создаёт.** Андрей Карпатый строит ровно такую модель в первом видео курса [makemore](https://www.youtube.com/watch?v=PaCmpygFfXo), а потом заменяет её нейросетью. Его курс целиком: [Neural Networks: Zero to Hero](https://karpathy.ai/zero-to-hero.html).

### Исследуй и потренируйся

Открой тренажёр. Нажми на «м» и сравни вероятности с числами из программы. Поставь температуру 0,3 и нажми «Написать текст» несколько раз, потом поставь 3. Затем сдвинь сглаживание в ноль и найди наименьшую ошибку на проверке.

### Вопрос

При `α = 0` ошибка счётчика пар на проверочном тексте оказалась бесконечной. Почему?

### Варианты

- В проверке встретилась пара букв, которой не было в обучении, и её вероятность стала нулём
- Проверочный текст оказался длиннее обучающего, и средняя ошибка сложилась в бесконечность
- Температура при проверке была слишком низкой, и модель выбрала одну букву вместо всех

### Ответ

1

### Разбор

Ошибка это среднее от `−ln P`. Если хоть одна пара получила `P = 0`, одно слагаемое равно бесконечности, и среднее тоже. Длина текста делит сумму, а не умножает. Температура нужна только при написании текста, на подсчёт ошибки она здесь не влияет. Поэтому любой модели нельзя давать нулевую вероятность: у счётчика это сглаживание, у нейросети softmax, который никогда не даёт точного нуля.

### Границы модели

Обучающий текст здесь крошечный, около 300 знаков, поэтому числа шумные: другой абзац даст другое лучшее `α`. Модель видит одну букву назад и ничего не знает о словах и смысле. Одинаковое прибавление `α` ко всем парам это самое простое сглаживание; на практике используют более тонкие способы, например учёт более коротких контекстов.

## English

### In plain words

The simplest language model looks only at the last letter and guesses the next one. To do this it counts once, in a text, which letter follows which. It is like guessing a word from its first letters in a crossword: after "q" there is almost always a "u". Such a model writes scraps that look like language but have no meaning. Still, it shows three things large models have too: probabilities, temperature, and a check on text the model has not seen.

**What to know first.** «Probability and Bayes' Rule» (step 5): conditional probability. «Information, Entropy, and Cross-Entropy» (step 6): error as surprise. «Your own tokenizer» (step 10): what text is made of.

**If something is unclear.** If it is unclear why a probability is a share, go back to «Probability and Bayes' Rule». If the error in nats is unclear, reread «Information, Entropy, and Cross-Entropy». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Build your first language model entirely by hand: count letter pairs, turn them into probabilities, write text at different temperatures and honestly test the model on new text. See why, without smoothing, the model breaks on the first unfamiliar pair. It takes about 30 minutes.

### Idea and mechanism

**Step 1. Pairs by hand.** Take the Russian phrase «мама мыла раму» ("mum washed the frame"). Write down what follows each letter «м»: «а», «а», «ы», «у». Four times in all. So after «м» the letter «а» comes in 2 cases out of 4, and its probability is `P(а | м) = 2 / 4 = 0.5`. The notation `P(а | м)` reads "the probability of «а» given that «м» comes before it". A model that keeps such shares for all pairs is called a *bigram* model, or a *pair counter*. It is the first model in Karpathy's makemore course. The texts are Russian because the course is written for a Russian speaker; the method does not depend on the language.

**Step 2. The program.** Create the file `nano ~/ai-path/bigram.py`, paste and run it with `python3 ~/ai-path/bigram.py`. The training text is small and written into the program, so everything is computed in a fraction of a second.

```python
import math

TRAIN = (
    "мама мыла раму. папа читал книгу. мама читала книгу сыну. "
    "кот спал на окне. пёс спал у двери. кот видел пса, а пёс видел кота. "
    "сын читал книгу коту. мама мыла окно. папа мыл пол. кот мыл лапу. "
    "утром мама пила чай, а папа пил кофе. вечером сын пил молоко. "
    "пёс любил гулять, а кот любил спать. мама любила книги. "
)
TEST = "папа читал книгу маме. кот спал у окна. сын любил молоко. "
LETTERS = sorted(set(TRAIN + TEST))

counts = {}
for a, b in zip(TRAIN, TRAIN[1:]):
    counts.setdefault(a, {})
    counts[a][b] = counts[a].get(b, 0) + 1

row = counts["м"]
total = sum(row.values())
print("letters in the alphabet:", len(LETTERS))
print("after 'м' seen", total, "times:")
for b, c in sorted(row.items(), key=lambda kv: (-kv[1], kv[0]))[:5]:
    print(f"  {b!r}: {c} times, P = {c / total:.3f}")
```

```output
letters in the alphabet: 28
after 'м' seen 18 times:
  'а': 10 times, P = 0.556
  'ы': 4 times, P = 0.222
  ' ': 2 times, P = 0.111
  'о': 1 times, P = 0.056
  'у': 1 times, P = 0.056
```

What you saw: in our text «а» follows «м» 10 times out of 18, so `P(а | м) = 10 / 18 = 0.556`. The whole model is a table of such numbers: 28 rows and 28 columns, one row per letter.

**Step 3. Writing text.** To write, the model takes the last letter, looks at its row and throws a "die" with unequal faces: a frequent letter comes up more often. *Temperature* `T` changes how unequal the faces are. Here each letter's weight is its count raised to the power `1 / T`. By hand: after «м», «а» appears 10 times and «ы» 4 times. At `T = 1` the weight ratio is `10 / 4 = 2.5`. At `T = 0.5` the weights are squared: `100 / 16 = 6.25`, so the frequent letter wins even more often. At `T = 2` the square root is taken: `3.16 / 2 = 1.58`, a more even choice. This is the same temperature as in «A live model on your Mac» (step 1), only on your own model. Add this to the file and run it.

```python
class Rand:
    def __init__(self, seed):
        self.state = seed

    def next(self):
        self.state = (self.state * 6364136223846793005 + 1442695040888963407) % 2**64
        return (self.state >> 11) / 2**53


def next_letter(a, temperature, rand):
    row = counts.get(a, {" ": 1})
    weights = {b: c ** (1 / temperature) for b, c in row.items()}
    total = sum(weights.values())
    r = rand.next() * total
    for b in sorted(weights):
        r -= weights[b]
        if r <= 0:
            return b
    return b


for temperature in (0.3, 1.0, 3.0):
    rand = Rand(7)
    text = "м"
    for _ in range(45):
        text += next_letter(text[-1], temperature, rand)
    print(f"T = {temperature}: {text}")
```

```output
T = 0.3: мала книла ма па па сыл кот па книл л книгу. ч
T = 1.0: мапёс кнечиде. кнокнутал сыла па кота а л коть
T = 3.0: мофел гу. пил па у витамапу рал гилюби. л деро
```

At low temperature the text repeats frequent pieces; at high temperature it falls apart into random letters. The words look Russian only in pieces: the model remembers one letter back and does not know where a word begins.

**Step 4. An honest check.** The model's error is the average surprise at real text: `−ln P(next | current)`, in nats. It is measured on text the model has not seen, otherwise you are testing memory. For comparison: guessing all 28 letters equally gives an error of `ln 28 = 3.332`. Add this and run it.

```python
def loss(text, alpha):
    V = len(LETTERS)
    total = 0.0
    pairs = list(zip(text, text[1:]))
    for a, b in pairs:
        row = counts.get(a, {})
        p = (row.get(b, 0) + alpha) / (sum(row.values()) + alpha * V)
        if p == 0:
            return math.inf
        total -= math.log(p)
    return total / len(pairs)


print("guessing at random:", round(math.log(len(LETTERS)), 3))
for alpha in (0, 0.001, 0.01, 0.1, 1, 3):
    print(f"alpha = {alpha}: train {loss(TRAIN, alpha):.3f}, test {loss(TEST, alpha):.3f}")
unseen = [(a, b) for a, b in zip(TEST, TEST[1:]) if counts.get(a, {}).get(b, 0) == 0]
print("pairs in the test never seen in training:", len(unseen), unseen[:4])
```

```output
guessing at random: 3.332
alpha = 0: train 1.371, test inf
alpha = 0.001: train 1.373, test 1.563
alpha = 0.01: train 1.392, test 1.538
alpha = 0.1: train 1.542, test 1.627
alpha = 1: train 2.154, test 2.186
alpha = 3: train 2.585, test 2.610
pairs in the test never seen in training: 1 [('м', 'е')]
```

The key is the first line. At `α = 0` the test error is infinite. The cause is a single pair: «ме» from the word «маме» never appeared in training, the model gave it probability zero, and `−ln 0` is infinity. This is the same "zero is deadly" as in «Information, Entropy, and Cross-Entropy». The cure is called *smoothing*: a small `α` is added to every count, and the formula becomes `P(b | a) = (c(a, b) + α) / (c(a) + α · V)`, where `c` is a count and `V = 28` the number of letters. By hand: for «ме» at `α = 0.01` this gives `(0 + 0.01) / (18 + 0.28) ≈ 0.00055`. Small, but not zero.

Note the price: the larger `α`, the worse the training error, because the model becomes ever more even and remembers ever less of the text. On the test the best here is `α = 0.01`: an error of `1.538`, far below the random `3.332`. This is the trade-off from «Mini-Batches and Overfitting» (step 9), in the simplest possible model.

**Step 5. The lab.** In the lab below, click a letter and look at its row of probabilities. Move the temperature and the smoothing, and find where the test error is infinite and where it is smallest.

**What next.** A pair counter cannot see further than one letter. You could count triples and quadruples, but the table grows as `28³`, `28⁴`, and most cells stay empty. A neural network solves this differently: instead of a table it learns vectors and finds what is similar by itself. That is the next lesson, «Embeddings and Similarity».

**Learn from the people who build this.** Andrej Karpathy builds exactly this model in the first video of the [makemore](https://www.youtube.com/watch?v=PaCmpygFfXo) course and then replaces it with a neural network. His whole course: [Neural Networks: Zero to Hero](https://karpathy.ai/zero-to-hero.html).

### Explore and practise

Open the lab. Click «м» and compare the probabilities with the program's numbers. Set the temperature to 0.3 and press "Write text" a few times, then set it to 3. Then move the smoothing to zero and find the smallest test error.

### Question

At `α = 0` the pair counter's error on the test text came out infinite. Why?

### Options

- The test contained a letter pair that never appeared in training, so its probability became zero
- The test text was longer than the training text, so the average error added up to infinity
- The temperature during the test was too low, so the model picked one letter instead of all

### Answer

1

### Explanation

The error is the average of `−ln P`. If even one pair got `P = 0`, one term is infinite, and so is the average. The text length divides the sum, it does not multiply it. Temperature is used only when writing text; it does not affect the error here. That is why no model may give a probability of exactly zero: a counter uses smoothing, a neural network uses softmax, which never gives an exact zero.

### Limits

The training text here is tiny, about 300 characters, so the numbers are noisy: another paragraph would give a different best `α`. The model sees one letter back and knows nothing about words or meaning. Adding the same `α` to every pair is the simplest smoothing; in practice finer methods are used, for example falling back on shorter contexts.

## Sources

- Andrej Karpathy, "The spelled-out intro to language modeling: building makemore" (video, 2022), the bigram model: [YouTube](https://www.youtube.com/watch?v=PaCmpygFfXo); course page opened 2026-11-02: [Zero to Hero](https://karpathy.ai/zero-to-hero.html)
- The program, the training text and all numbers were written and computed for this lesson on 2026-11-07; the smoothing formula is the standard additive (Laplace) smoothing.
