---
subject: mathematics
lesson_id: mathematics.information_and_cross_entropy
level: advanced
languages: ru, en
source_checked: 2026-11-01
source_review_interval_days: 365
---

# Информация, энтропия и кросс-энтропия / Information, Entropy, and Cross-Entropy

## Русский

### Цель

Считать удивление, энтропию и кросс-энтропию в битах, доказать, что кросс-энтропия не может опуститься ниже энтропии, и понять, почему именно эту величину минимизируют при обучении языковых моделей.

### Идея и механизм

Языковая модель получает начало текста и отвечает не одной буквой, а вероятностями всех возможных следующих букв. Как измерить, хорошо ли она ответила? Нужно число, которое мало, когда верной букве дана большая вероятность, и велико, когда маленькая. Такое число дала теория информации, основанная Клодом Шенноном в 1948 году.

**Удивление.** Событие с вероятностью `p` несёт удивление `I = −log₂ p` бит. Честная монета: `p = 1/2`, удивление 1 бит. Событие с `p = 1/8`: 3 бита, как три броска монеты подряд. Событие с `p = 1`: 0 бит, потому что ничего нового мы не узнали. Логарифм взят не случайно. Вероятности независимых событий умножаются, а логарифм превращает умножение в сложение, поэтому удивления складываются: `−log₂(p·q) = −log₂ p − log₂ q`.

**Энтропия.** Это среднее удивление по распределению `P`:

`H(P) = −Σ p(x) log₂ p(x)`

Пусть четыре буквы встречаются с вероятностями `P = (1/2; 1/4; 1/8; 1/8)`. Тогда `H(P) = 1/2 · 1 + 1/4 · 2 + 1/8 · 3 + 1/8 · 3 = 1,75` бита. У этого числа есть прямой смысл: длина кода. Обычным кодом на четыре буквы нужно по 2 бита на букву. Но можно частой букве дать короткий код, а редкой длинный: `0`, `10`, `110`, `111`. Средняя длина как раз 1,75 бита. Теорема Шеннона об источнике говорит, что однозначно декодируемый код в среднем не может быть короче энтропии. Энтропия — это мера неопределённости: у равномерного распределения на четыре буквы она 2 бита, а если одна буква встречается всегда, она равна 0.

**Кросс-энтропия.** Теперь пусть данные идут из `P`, а модель считает, что они идут из `Q`. Среднее удивление модели равно

`H(P, Q) = −Σ p(x) log₂ q(x)`

Это средняя длина кода, построенного для `Q`, на данных из `P`. Посчитаем для того же `P`. Модель не знает частот и считает все буквы равновероятными, `Q = (1/4; 1/4; 1/4; 1/4)`: удивление всегда 2 бита, поэтому `H(P, Q) = 2`. Модель перепутала порядок, `Q = (1/8; 1/8; 1/4; 1/2)`: `1/2 · 3 + 1/4 · 3 + 1/8 · 2 + 1/8 · 1 = 2,625` бита. А модель с `Q = P` получает ровно 1,75.

**Ниже энтропии опуститься нельзя.** Разрыв между кросс-энтропией и энтропией называется расхождением Кульбака — Лейблера: `D(P‖Q) = H(P, Q) − H(P) = Σ p(x) log₂ (p(x)/q(x))`. Докажем, что он не отрицателен. Для любого `t > 0` верно `ln t ≤ t − 1`, а равенство бывает только при `t = 1`. Подставим `t = q/p` и просуммируем по буквам с `p > 0`:

`Σ p ln(q/p) ≤ Σ p (q/p − 1) = Σ q − Σ p ≤ 1 − 1 = 0`

Значит, `−D · ln 2 ≤ 0`, то есть `D ≥ 0`, а ноль бывает только при `q = p` для всех букв. Отсюда главный вывод: кросс-энтропия как функция `Q` имеет единственный минимум, и он достигается там, где модель угадала настоящие вероятности. Высота этого дна равна энтропии данных. Лучше стать нельзя: остаток неопределённости принадлежит самим данным.

**Ноль смертелен.** Если модель дала букве `q = 0`, а эта буква всё же встретилась, удивление `−log₂ 0` бесконечно. Одна такая ошибка делает бесконечной всю среднюю ошибку. Поэтому модели никогда не говорят «невозможно»: при подсчётах прибавляют единицу к каждому счётчику, а softmax в нейросети ноля вообще не выдаёт.

**Проверим на настоящем тексте.** Обучим три модели на короткой фразе и сравним их на другой фразе. Ошибка считается в битах на букву, то есть это кросс-энтропия:

```python
import math
from collections import Counter

train = "the cat sat on the mat and the dog sat on the log"
test = "the dog sat on the mat"

alphabet = sorted(set(train + test))
size = len(alphabet)
letters = Counter(train)
pairs = Counter(zip(train, train[1:]))
starts = Counter(train[:-1])


def uniform(previous, letter):
    return 1 / size  # все буквы равновероятны


def by_letter(previous, letter):
    return (letters[letter] + 1) / (len(train) + size)  # частота буквы, с прибавлением единицы


def by_pair(previous, letter):
    return (pairs[previous, letter] + 1) / (starts[previous] + size)  # частота буквы после предыдущей


def cross_entropy(model, text):
    surprises = [-math.log2(model(a, b)) for a, b in zip(text, text[1:])]
    return sum(surprises) / len(surprises)


print("alphabet", size)
for name, model in (("uniform", uniform), ("letters", by_letter), ("pairs", by_pair)):
    print(name, round(cross_entropy(model, test), 3))
```

Программа печатает:

```text
alphabet 13
uniform 3.7
letters 3.341
pairs 2.442
```

Случайное угадывание из 13 символов даёт `log₂ 13 ≈ 3,7` бита. Частоты букв снижают ошибку до 3,341 бита, а пары букв до 2,442. Каждая новая модель знает о языке больше, поэтому меньше удивляется. Этот же ряд станет линейкой финального проекта: твоя модель должна обойти и случайное угадывание, и счётчик пар.

**Как это становится функцией ошибки.** В обучении настоящих частот обычно нет, есть только примеры. Для одного примера вся вероятность лежит на верной букве, поэтому кросс-энтропия превращается в `−log q(верная буква)`. Усредняем по примерам:

`L = −(1/N) Σ log q(xᵢ)`

Минимизировать это число значит максимизировать вероятность данных при модели. Чаще берут натуральный логарифм, тогда ошибка в натах: 1 нат ≈ 1,44 бита. Отсюда полезная проверка: необученная модель с `V` символами должна начинать примерно с ошибки `ln V`. Если ошибка в начале намного больше, в программе что-то не так.

### Исследуй и потренируйся

В тренажёре настоящая кросс-энтропия построена как объёмная чаша над треугольником. Каждая точка треугольника — это вера модели `Q` в три символа: угол A значит «точно A». Высота — кросс-энтропия. Покрути чашу мышью. Найди зелёное кольцо: это настоящие частоты `P`, и дно чаши ровно там. Поставь шарик на склон и запусти обучение. Затем смени `P`: куда переехало дно и как изменилась его высота?

Затем допиши программу: посчитай `cross_entropy(by_pair, train)` и сравни с ошибкой на `test`. Какая меньше и почему?

### Вопрос

Данные идут из распределения `P`. При каком распределении `Q` кросс-энтропия `H(P, Q)` будет наименьшей?

### Варианты

- При равномерном `Q`: так модель не ошибается слишком сильно.
- При `Q` с единицей на самой частой букве и нулём на других.
- При `Q`, равном `P`: разрыв до энтропии тогда становится нулём.

### Ответ

3

### Разбор

Разрыв `H(P, Q) − H(P)` не отрицателен и равен нулю только при `Q = P`. Равномерное `Q` даёт разрыв, если `P` неравномерно. Единица на самой частой букве хуже всего: остальным буквам досталась вероятность 0, и любая из них, встретившись, сделает ошибку бесконечной.

### Границы модели

Энтропия измеряет неопределённость, а не смысл: Шеннон прямо отделял передачу сообщений от их значения. Настоящие частоты языка неизвестны, поэтому энтропию текста можно только оценить. На короткой выборке оценки занижены: модель с большим числом параметров может запомнить эту выборку, поэтому ошибку честно мерить только на данных, которых модель не видела. Наши три фразовые модели учебные: они видят лишь одну предыдущую букву и не учатся смыслу. Кросс-энтропия не единственная возможная функция ошибки, но для вероятностных ответов она самая обычная.

## English

### Goal

Compute surprise, entropy, and cross-entropy in bits, prove that cross-entropy cannot fall below entropy, and see why this is the quantity minimized when training language models.

### Idea and mechanism

A language model takes the start of a text and answers not with one letter but with probabilities for every possible next letter. How do we measure whether it answered well? We need a number that is small when the right letter gets a high probability and large when it gets a low one. Information theory, founded by Claude Shannon in 1948, provides that number.

**Surprise.** An event with probability `p` carries a surprise of `I = −log₂ p` bits. A fair coin: `p = 1/2`, a surprise of 1 bit. An event with `p = 1/8`: 3 bits, like three coin flips in a row. An event with `p = 1`: 0 bits, because we learned nothing new. The logarithm is no accident. Probabilities of independent events multiply, and a logarithm turns multiplication into addition, so surprises add up: `−log₂(p·q) = −log₂ p − log₂ q`.

**Entropy.** This is the mean surprise over a distribution `P`:

`H(P) = −Σ p(x) log₂ p(x)`

Let four letters occur with probabilities `P = (1/2, 1/4, 1/8, 1/8)`. Then `H(P) = 1/2 · 1 + 1/4 · 2 + 1/8 · 3 + 1/8 · 3 = 1.75` bits. This number has a direct meaning: code length. A plain code for four letters needs 2 bits per letter. But we can give the frequent letter a short code and the rare ones long codes: `0`, `10`, `110`, `111`. The mean length is exactly 1.75 bits. Shannon's source coding theorem says that a uniquely decodable code cannot on average be shorter than the entropy. Entropy is a measure of uncertainty: a uniform distribution over four letters has 2 bits, and if one letter always occurs, it has 0.

**Cross-entropy.** Now let the data come from `P` while the model believes it comes from `Q`. The model's mean surprise is

`H(P, Q) = −Σ p(x) log₂ q(x)`

This is the mean length of a code built for `Q`, used on data from `P`. Compute it for the same `P`. A model that knows no frequencies treats all letters as equally likely, `Q = (1/4, 1/4, 1/4, 1/4)`: its surprise is always 2 bits, so `H(P, Q) = 2`. A model that mixed up the order, `Q = (1/8, 1/8, 1/4, 1/2)`, gets `1/2 · 3 + 1/4 · 3 + 1/8 · 2 + 1/8 · 1 = 2.625` bits. A model with `Q = P` gets exactly 1.75.

**You cannot go below entropy.** The gap between cross-entropy and entropy is called the Kullback–Leibler divergence: `D(P‖Q) = H(P, Q) − H(P) = Σ p(x) log₂ (p(x)/q(x))`. Let us prove it is not negative. For any `t > 0`, `ln t ≤ t − 1`, with equality only at `t = 1`. Put `t = q/p` and sum over the letters with `p > 0`:

`Σ p ln(q/p) ≤ Σ p (q/p − 1) = Σ q − Σ p ≤ 1 − 1 = 0`

So `−D · ln 2 ≤ 0`, that is, `D ≥ 0`, and zero happens only when `q = p` for all letters. This gives the main result: cross-entropy as a function of `Q` has a single minimum, reached where the model has found the true probabilities. The height of that bottom equals the entropy of the data. You cannot do better: the remaining uncertainty belongs to the data itself.

**Zero is fatal.** If a model gave a letter `q = 0` and that letter still occurs, the surprise `−log₂ 0` is infinite. One such mistake makes the whole mean error infinite. So models never say "impossible": count-based models add one to every count, and the softmax of a neural network never outputs zero at all.

**Check it on real text.** Train three models on a short phrase and compare them on another phrase. The error is in bits per letter, so it is a cross-entropy:

```python
import math
from collections import Counter

train = "the cat sat on the mat and the dog sat on the log"
test = "the dog sat on the mat"

alphabet = sorted(set(train + test))
size = len(alphabet)
letters = Counter(train)
pairs = Counter(zip(train, train[1:]))
starts = Counter(train[:-1])


def uniform(previous, letter):
    return 1 / size  # all letters equally likely


def by_letter(previous, letter):
    return (letters[letter] + 1) / (len(train) + size)  # letter frequency, with one added


def by_pair(previous, letter):
    return (pairs[previous, letter] + 1) / (starts[previous] + size)  # frequency after the previous letter


def cross_entropy(model, text):
    surprises = [-math.log2(model(a, b)) for a, b in zip(text, text[1:])]
    return sum(surprises) / len(surprises)


print("alphabet", size)
for name, model in (("uniform", uniform), ("letters", by_letter), ("pairs", by_pair)):
    print(name, round(cross_entropy(model, test), 3))
```

The program prints:

```text
alphabet 13
uniform 3.7
letters 3.341
pairs 2.442
```

Random guessing among 13 symbols gives `log₂ 13 ≈ 3.7` bits. Letter frequencies lower the error to 3.341 bits, and letter pairs to 2.442. Each new model knows more about the language, so it is less surprised. This same series becomes the yardstick of the final project: your model must beat both random guessing and the pair counter.

**How this becomes an error function.** In training we usually have no true frequencies, only examples. For one example all the probability sits on the right letter, so cross-entropy becomes `−log q(right letter)`. Average over the examples:

`L = −(1/N) Σ log q(xᵢ)`

Minimizing this number means maximizing the probability of the data under the model. The natural logarithm is more common, which puts the error in nats: 1 nat ≈ 1.44 bits. This gives a useful check: an untrained model with `V` symbols should start near an error of `ln V`. If the starting error is much larger, something in the program is wrong.

### Explore and practise

In the lab, true cross-entropy is built as a solid bowl over a triangle. Each point of the triangle is a model's belief `Q` in three symbols: corner A means "certainly A". The height is cross-entropy. Turn the bowl with the mouse. Find the green ring: these are the true frequencies `P`, and the bottom of the bowl is exactly there. Put the ball on a slope and start training. Then change `P`: where did the bottom move, and how did its height change?

Then extend the program: compute `cross_entropy(by_pair, train)` and compare it with the error on `test`. Which is smaller, and why?

### Question

The data comes from a distribution `P`. For which distribution `Q` is the cross-entropy `H(P, Q)` the smallest?

### Options

- For a uniform `Q`: that way the model is never very wrong.
- For a `Q` with one on the most frequent letter and zero elsewhere.
- For `Q` equal to `P`: the gap to the entropy then becomes zero.

### Answer

3

### Explanation

The gap `H(P, Q) − H(P)` is not negative and is zero only when `Q = P`. A uniform `Q` leaves a gap whenever `P` is not uniform. One on the most frequent letter is the worst: the other letters got probability 0, and any of them, when it occurs, makes the error infinite.

### Limits

Entropy measures uncertainty, not meaning: Shannon explicitly separated the transmission of messages from what they mean. The true frequencies of a language are unknown, so the entropy of a text can only be estimated. On a short sample the estimates run low: a model with many parameters can memorize that sample, so the error is measured honestly only on data the model has not seen. Our three phrase models are for teaching: they see only one previous letter and learn no meaning. Cross-entropy is not the only possible error function, but for probabilistic answers it is the most usual one.

## Sources

- Claude E. Shannon, “A Mathematical Theory of Communication”, *Bell System Technical Journal* 27 (3), 379–423 (July 1948), citation checked on Crossref 2026-11-01: the founding paper of information theory, which sets the semantic meaning of messages aside: [doi:10.1002/j.1538-7305.1948.tb01338.x](https://doi.org/10.1002/j.1538-7305.1948.tb01338.x)
- Aston Zhang, Zachary C. Lipton, Mu Li, Alexander J. Smola, *Dive into Deep Learning*, “Information Theory” (consulted 2026-11-01): self-information, entropy in bits, cross-entropy, KL divergence, its non-negativity and infinity where q is zero, and the equivalence of minimizing cross-entropy and maximizing log-likelihood: [D2L, Information Theory](https://d2l.ai/chapter_appendix-mathematics-for-deep-learning/information-theory.html)
- Wikipedia, “Cross-entropy” (consulted 2026-11-01): expected code length when the code is designed for q and events come from p, and H(p, q) = H(p) + D_KL(p‖q): [Cross-entropy](https://en.wikipedia.org/wiki/Cross-entropy)
- Wikipedia, “Shannon's source coding theorem” (consulted 2026-11-01): the expected length of a uniquely decodable code is at least the entropy of the source: [Source coding theorem](https://en.wikipedia.org/wiki/Shannon%27s_source_coding_theorem)
- The proof, the program, and all numbers were written and computed for this lesson. The lesson paraphrases these sources and does not copy their text.
