---
subject: programming
lesson_id: programming.build_your_language_model
level: advanced
languages: ru, en
source_checked: 2026-11-02
source_review_interval_days: 365
---

# Своя языковая модель / Your Own Language Model

## Русский

### Простыми словами

Здесь все детали собираются в одну программу: токены, эмбеддинги, блоки трансформера, механизм градиентов и Adam. Модель учится на текстах этого курса угадывать следующий символ. Как сборка велосипеда из деталей, каждую из которых ты уже делал и проверял. Финиш засчитывается только по тексту, которого модель не видела: ошибка там должна быть ниже случайного угадывания и ниже простого счётчика пар.

**Что нужно знать до.** Все уроки этапа 2, особенно «Свой механизм градиентов» (шаг 8), «Блок трансформера» (шаг 11) и «Как читать обучение» (шаг 9).

**Если непонятно.** Если непонятна какая-то деталь программы, найди урок, где она появилась впервые: градиенты в шаге 8, оптимизатор в шаге 9, внимание и блок в шаге 11. Если неясно, почему важен незнакомый текст, перечитай урок «Машинное обучение: baseline». Незнакомое слово ищи в «Словаре пути ИИ», это первый пункт пути.

### Цель

Собрать всё пройденное в одну программу на чистом Python: свой механизм градиентов, блоки трансформера и обучение на текстах курса. Обучить модель на своём Mac и честно проверить её на тексте, которого она не видела.

### Идея и механизм

Это финиш пути. Ничего нового в математике здесь нет, а новая только сборка. Мы не используем ни готовых библиотек для ИИ, ни платных сервисов, ни даже NumPy: только стандартный Python. Поэтому можно объяснить каждую строку.

**Черта финиша.** Заранее скажем, что будем считать успехом. Модель должна ошибаться на незнакомом тексте реже, чем случайное угадывание и счётчик пар букв. Она должна писать новый текст, похожий на обучающий. А ты должен суметь объяснить, как она устроена и чего не умеет. Текст берём из русских частей 134 уроков этого курса: 382 107 символов и алфавит из 144 знаков. Последние 10 % модель не видит при обучении. Случайное угадывание даёт ошибку `ln 144 ≈ 4,97`, а счётчик пар 2,651. Это в натах, то есть с натуральным логарифмом.

**Свой механизм градиентов.** В уроке о внимании мы вели обратный проход вручную, и это было долго. Теперь напишем общий механизм. Каждая матрица в программе это объект `Tensor`, который хранит свои числа, родителей, из которых она получилась, и функцию `back`, которая передаёт градиент этим родителям. Когда считается ошибка, такие объекты сами складываются в граф вычислений. Затем `backward` обходит его от ошибки к весам. Обход идёт в таком порядке, чтобы каждый узел успел получить весь свой градиент раньше, чем передаст его дальше. Именно поэтому там есть проход `visit`.

Каждая операция знает только своё правило, и это правила из прошлых уроков. Для произведения матриц `Y = AB` с градиентом `G` по `Y` получается `∂L/∂A = G Bᵀ` и `∂L/∂B = Aᵀ G`. Сумма передаёт градиент обоим слагаемым как есть: поэтому обходной путь и несёт сигнал без потерь. `ReLU` пропускает градиент только там, где вход положителен. Нормализация `y = (x − m)/s` передаёт `(g − ḡ − c·y)/s`, где `ḡ` это среднее `g`, а `c` это среднее произведений `g·y`. Внимание использует формулу из своего урока. Прежде чем запускать долгое обучение, мы проверили механизм численно: сравнили его ответы с наклоном ошибки на 63 случайных весах, и наибольшее расхождение равно 5,5·10⁻⁸.

**Модель.** Каждый символ получает вектор длиной 32, а каждое из 32 мест свой вектор места. Их сумма идёт в два блока трансформера, по две головы внимания в каждом, с обходами и нормализацией. Сверху стоит матрица, которая превращает вектор в 144 оценок, по одной на символ. Всего 26624 весов.

**Шаг Adam.** Простой спуск на таких сетях идёт медленно, потому что удобный размер шага у разных весов очень разный. Метод Adam хранит для каждого веса скользящее среднее его градиента `m` и скользящее среднее его квадрата `s`, а затем делает шаг `η · m / √s`. Вес с большими градиентами получает шаг поменьше, а с маленькими побольше, поэтому шаги становятся соразмерны. Множители `1 − βᵗ` исправляют смещение первых шагов, пока средние ещё близки к нулю.

**Обучение.** На каждом шаге берём 8 случайных кусков по 32 символа. Цель для каждого места — следующий символ. Складываем градиенты, делаем шаг Adam, и так 6000 раз. Каждые 500 шагов меряем ошибку на отложенном тексте и храним лучшие веса: это ранняя остановка из урока о переобучении.

Вот вся программа. Она лежит в `01_Projects/tiny_language_model.py`, а запускается из корня репозитория командой `python3 01_Projects/tiny_language_model.py`:

```python
import json
import math
import re
import sys
import time
from collections import Counter
from operator import mul
from pathlib import Path

FOLDER = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("02_Areas")
STEPS = int(sys.argv[2]) if len(sys.argv) > 2 else 6000
SIZE, HEADS, BLOCKS, LENGTH, BATCH = 32, 2, 2, 32, 8  # длина вектора, головы, блоки, длина куска, размер пакета
RATE = 0.003


class Generator:  # простой генератор случайных чисел
    def __init__(self, seed):
        self.state = seed

    def number(self):
        self.state = self.state * 16807 % 2147483647
        return self.state / 2147483647

    def below(self, limit):
        return int(self.number() * limit)

    def bell(self):  # примерно нормальное число: сумма 12 равномерных
        return sum(self.number() for _ in range(12)) - 6


def read_course(folder):  # русские части уроков без кода и заголовков
    parts, fence = [], "`" * 3
    for path in sorted(folder.glob("*/lessons/*.md")):
        sections = re.split(r"^#{2} (.+)$", path.read_text(encoding="utf-8"), flags=re.M)
        if "Русский" not in sections or "English" not in sections:
            continue
        russian = sections[sections.index("Русский") + 1]
        russian = re.sub(fence + ".*?" + fence, " ", russian, flags=re.S)
        russian = "\n".join(line for line in russian.split("\n") if not line.startswith(("#", "|")))
        parts.append(russian)
    return re.sub(r"[ \t]+", " ", re.sub(r"\n+", "\n", "\n".join(parts)))


text = read_course(FOLDER)
counts = Counter(text)
alphabet = sorted(c for c, n in counts.items() if n >= 40) + ["□"]  # редкие символы заменяем на □
code = {c: i for i, c in enumerate(alphabet)}
numbers = [code.get(c, code["□"]) for c in text]
split = len(numbers) * 9 // 10
train, held = numbers[:split], numbers[split:]  # последние 10 % модель не видит при обучении
V = len(alphabet)
print("characters", len(numbers), "alphabet", V, flush=True)


def pair_error():  # счётчик пар букв: линейка, которую надо обойти
    pairs = Counter(zip(train, train[1:]))
    starts = Counter(train[:-1])
    total = sum(-math.log((pairs[a, b] + 0.1) / (starts[a] + 0.1 * V)) for a, b in zip(held, held[1:]))
    return total / (len(held) - 1)


print("random", round(math.log(V), 3), "pairs", round(pair_error(), 3), flush=True)


class Tensor:  # число-матрица, которая помнит, откуда взялась
    __slots__ = ("data", "grad", "parents", "back")

    def __init__(self, data, parents=(), back=None):
        self.data = data
        self.grad = None
        self.parents = parents
        self.back = back

    def add_grad(self, g):
        if self.grad is None:
            self.grad = g
        else:
            self.grad = [[a + b for a, b in zip(r, s)] for r, s in zip(self.grad, g)]


def multiply(a, b):
    columns = list(zip(*b))
    return [[sum(map(mul, row, c)) for c in columns] for row in a]


def flip(a):
    return [list(c) for c in zip(*a)]


def matmul(a, b):  # Y = A B: градиенты G Bᵀ и Aᵀ G
    def back(g):
        a.add_grad(multiply(g, flip(b.data)))
        b.add_grad(multiply(flip(a.data), g))
    return Tensor(multiply(a.data, b.data), (a, b), back)


def plus(a, b):  # обходной путь: градиент идёт в обе стороны как есть
    def back(g):
        a.add_grad(g)
        b.add_grad(g)
    return Tensor([[x + y for x, y in zip(r, s)] for r, s in zip(a.data, b.data)], (a, b), back)


def relu(a):
    def back(g):
        a.add_grad([[v if x > 0 else 0.0 for v, x in zip(r, s)] for r, s in zip(g, a.data)])
    return Tensor([[x if x > 0 else 0.0 for x in r] for r in a.data], (a,), back)


def normalize(a):  # нормализация слоя по каждому месту
    rows, infos = [], []
    for row in a.data:
        n = len(row)
        mean = sum(row) / n
        sigma = math.sqrt(sum((x - mean) ** 2 for x in row) / n)
        spread = sigma + 1e-5
        result = [(x - mean) / spread for x in row]
        rows.append(result)
        infos.append((spread, sigma, result))

    def back(g):
        out = []
        for gr, (spread, sigma, res) in zip(g, infos):
            n = len(gr)
            gm = sum(gr) / n
            gs = sum(map(mul, gr, res)) / n
            out.append([(v - gm) / spread - (gs * r / sigma if sigma else 0.0) for v, r in zip(gr, res)])
        a.add_grad(out)
    return Tensor(rows, (a,), back)


def attention_weights(q, k, root):  # маска: только уже прочитанные места
    weights = []
    for t, qt in enumerate(q):
        scores = [sum(map(mul, qt, k[j])) / root for j in range(t + 1)]
        top = max(scores)
        powers = [math.exp(s - top) for s in scores]
        total = sum(powers)
        weights.append([p / total for p in powers])
    return weights


def attend(q, k, v, root):
    size = len(v.data[0])
    weights = attention_weights(q.data, k.data, root)
    out = [[sum(map(mul, wt, column)) for column in (cv[:t + 1] for cv in zip(*v.data))] for t, wt in enumerate(weights)]

    def back(g):  # тот же обратный проход, что в уроке о внимании
        count = len(weights)
        gq = [[0.0] * size for _ in range(count)]
        gk = [[0.0] * size for _ in range(count)]
        gv = [[0.0] * size for _ in range(count)]
        for t, wt in enumerate(weights):
            gt, qt, gqt = g[t], q.data[t], gq[t]
            effect = [sum(map(mul, gt, v.data[j])) for j in range(t + 1)]
            mean = sum(map(mul, wt, effect))
            for j, w in enumerate(wt):
                pull = w * (effect[j] - mean) / root
                kj, gkj, gvj = k.data[j], gk[j], gv[j]
                for i in range(size):
                    gvj[i] += w * gt[i]
                    gqt[i] += pull * kj[i]
                    gkj[i] += pull * qt[i]
        v.add_grad(gv)
        q.add_grad(gq)
        k.add_grad(gk)
    return Tensor(out, (q, k, v), back)


def join(parts):  # склейка ответов голов
    def back(g):
        start = 0
        for part in parts:
            width = len(part.data[0])
            part.add_grad([r[start:start + width] for r in g])
            start += width
    return Tensor([sum((p.data[t] for p in parts), []) for t in range(len(parts[0].data))], tuple(parts), back)


def lookup(table, indices):  # таблица эмбеддингов: строка на символ
    def back(g):
        out = [[0.0] * len(table.data[0]) for _ in table.data]
        for index, row in zip(indices, g):
            target = out[index]
            for i, value in enumerate(row):
                target[i] += value
        table.add_grad(out)
    return Tensor([table.data[i][:] for i in indices], (table,), back)


def cross_entropy(logits, targets):  # средняя кросс-энтропия и её градиент q − p
    total, grads, n = 0.0, [], len(targets)
    for row, target in zip(logits.data, targets):
        top = max(row)
        powers = [math.exp(z - top) for z in row]
        whole = sum(powers)
        q = [p / whole for p in powers]
        total -= math.log(q[target])
        g = [x / n for x in q]
        g[target] -= 1 / n
        grads.append(g)
    return total / n, grads


def backward(root, seed):  # обходим граф так, чтобы узел получил весь свой градиент раньше родителей
    order, seen = [], set()

    def visit(node):
        if id(node) in seen:
            return
        seen.add(id(node))
        for parent in node.parents:
            visit(parent)
        order.append(node)
    visit(root)
    root.grad = seed
    for node in reversed(order):
        if node.back is not None and node.grad is not None:
            node.back(node.grad)


random = Generator(20261102)
part = SIZE // HEADS
root_part = math.sqrt(part)


def table(rows, cols, scale=None):  # случайные начальные веса
    scale = scale if scale is not None else 1 / math.sqrt(cols)
    return Tensor([[random.bell() * scale for _ in range(cols)] for _ in range(rows)])


letters, places = table(V, SIZE, 0.1), table(LENGTH, SIZE, 0.1)  # символы и номера мест
blocks = [{"q": [table(SIZE, part) for _ in range(HEADS)],
           "k": [table(SIZE, part) for _ in range(HEADS)],
           "v": [table(SIZE, part) for _ in range(HEADS)],
           "mix": table(SIZE, SIZE), "wide": table(SIZE, 2 * SIZE), "narrow": table(2 * SIZE, SIZE)}
          for _ in range(BLOCKS)]
out_weights = table(SIZE, V)
parameters = [letters, places, out_weights]
for block in blocks:
    parameters += block["q"] + block["k"] + block["v"] + [block["mix"], block["wide"], block["narrow"]]
print("weights", sum(len(p.data) * len(p.data[0]) for p in parameters), flush=True)


def forward(indices):  # вся модель: два блока и выход
    x = plus(lookup(letters, indices), lookup(places, list(range(len(indices)))))
    for block in blocks:
        heads = [attend(matmul(x, q), matmul(x, k), matmul(x, v), root_part)
                 for q, k, v in zip(block["q"], block["k"], block["v"])]
        x = normalize(plus(x, matmul(join(heads), block["mix"])))
        x = normalize(plus(x, matmul(relu(matmul(x, block["wide"])), block["narrow"])))
    return matmul(x, out_weights)


first = [[[0.0] * len(p.data[0]) for _ in p.data] for p in parameters]
second = [[[0.0] * len(p.data[0]) for _ in p.data] for p in parameters]


def adam_step(step, rate):  # шаг Adam: средний градиент и его размер у каждого веса
    b1, b2 = 0.9, 0.999
    c1, c2 = 1 - b1 ** step, 1 - b2 ** step
    for p, m, s in zip(parameters, first, second):
        if p.grad is None:
            continue
        for row, gr, mr, sr in zip(p.data, p.grad, m, s):
            for i, g in enumerate(gr):
                mr[i] = b1 * mr[i] + (1 - b1) * g
                sr[i] = b2 * sr[i] + (1 - b2) * g * g
                row[i] -= rate * (mr[i] / c1) / (math.sqrt(sr[i] / c2) + 1e-8)


def piece(data):  # случайный кусок текста и он же со сдвигом на символ
    start = random.below(len(data) - LENGTH - 1)
    return data[start:start + LENGTH], data[start + 1:start + LENGTH + 1]


def measure(data, count=40):  # ошибка на одних и тех же 40 кусках
    saved = random.state
    random.state = 987654
    total = 0.0
    for _ in range(count):
        x, y = piece(data)
        total += cross_entropy(forward(x), y)[0]
    random.state = saved
    return total / count


def write(start, count, temperature):  # модель пишет: выбор символа по вероятностям с температурой
    result = [code.get(c, code["□"]) for c in start]
    for _ in range(count):
        row = forward(result[-LENGTH:]).data[-1]
        top = max(row)
        powers = [math.exp((z - top) / temperature) for z in row]
        point = random.number() * sum(powers)
        for index, power in enumerate(powers):
            point -= power
            if point < 0:
                result.append(index)
                break
    return "".join(alphabet[i] for i in result)


def save(path):
    data = {"alphabet": alphabet, "size": SIZE, "heads": HEADS, "blocks": BLOCKS, "length": LENGTH, "weights": [p.data for p in parameters]}
    Path(path).write_text(json.dumps(data, ensure_ascii=False))


if __name__ == "__main__":
    begin, best = time.time(), (9.0, 0)
    print("start", round(measure(held), 3), flush=True)
    for step in range(1, STEPS + 1):
        for p in parameters:
            p.grad = None
        total = 0.0
        for _ in range(BATCH):
            x, y = piece(train)
            logits = forward(x)
            loss, seed = cross_entropy(logits, y)
            total += loss
            backward(logits, [[g / BATCH for g in row] for row in seed])
        adam_step(step, RATE if step < STEPS * 0.8 else RATE / 3)  # под конец шаг меньше
        if step % 500 == 0 or step == STEPS:
            checked = measure(held)
            if checked < best[0]:  # ранняя остановка: храним лучшие веса
                best = (checked, step)
                save("tiny_model_best.json")
            print(step, "train", round(total / BATCH, 3), "held", round(checked, 3), "minutes", round((time.time() - begin) / 60, 1), flush=True)
    print("best", round(best[0], 3), "at step", best[1], flush=True)
```

**Что получилось.** Эта программа обучалась на MacBook Air M1 47 минут, на одном ядре. Вот настоящий журнал обучения:

```text
characters 382107 alphabet 144
random 4.97 pairs 2.651
weights 26624
start 5.039
500 train 2.571 held 2.582 minutes 3.8
1000 train 2.357 held 2.434 minutes 8.4
1500 train 2.415 held 2.379 minutes 12.5
2000 train 2.374 held 2.354 minutes 16.8
2500 train 2.345 held 2.283 minutes 20.7
3000 train 2.264 held 2.261 minutes 24.5
3500 train 2.231 held 2.234 minutes 28.3
4000 train 2.264 held 2.256 minutes 32.0
4500 train 2.206 held 2.237 minutes 35.8
5000 train 2.098 held 2.141 minutes 39.6
5500 train 2.02 held 2.149 minutes 43.4
6000 train 2.207 held 2.127 minutes 47.2
best 2.127 at step 6000
```

В начале ошибка равна 5,039, близко к `ln 144`. Лучшая ошибка на отложенных кусках равна 2,127 на шаге 6000. На всём отложенном тексте она равна 2,218, а у счётчика пар 2,651. Первая часть черты пройдена: модель лучше случайного угадывания и лучше счётчика пар. Число на 40 кусках чуть ниже, чем на всём тексте, потому что 40 кусков это малая выборка.

А вот что она пишет, начав со слов «Нейронная сеть», при разной температуре:

```text
T = 1.0: Нейронная сеть понясть `15T к5`.: «Опри `ass □ Bshas` и раска, корестся — меники нак пригость отатк по вледей. Пходять  `c5 же утаждиа. Для снига бупыложим гаращего подов в рассчен ракисловаль равняться смдель учит
T = 0.7: Нейронная сеть здели словерь а `2 м`, `ue` — `t = c`. Проверь се отвсетвает `1 рузата прывановрание окормение поредится сложную проверние функция вызать отста дво донят всю транные `uuy = 1` и `□□ модно из прос и п
T = 0.4: Нейронная сеть положить вредель при кледельном следу проверь на проверь простания только и сточно исть для предскольно следу словет все уго стремения собщений и и проверь при привает простать случается соти стровня
```

Это не связный текст, и важно назвать это честно. Вторая часть черты пройдена только по форме: текст новый и внешне похож на обучающий, но смысла в нём нет. Модель выучила буквы и слоги русского языка, отдельные частые слова этого курса, такие как «функция» и «проверь», и привычку ставить формулы в обратные кавычки. Она не понимает смысла, не следит за фактами и часто придумывает несуществующие слова. Настоящие большие модели устроены по той же схеме, но содержат в миллионы раз больше весов и учатся на намного большем объёме текста.

### Исследуй и потренируйся

В тренажёре работает эта самая обученная модель. Измени текст: доска покажет её настоящее внимание, а столбы вероятности следующего символа. Нажми «Писать» и подвигай температуру. Найди начала слов, в которых модель уверена. Переключай блоки и головы.

Затем обучи свою модель. Это и есть твой финиш. Из корня репозитория запусти команду ниже и дождись конца. Файл `tiny_model_best.json` появится в той же папке. Открой его кнопкой в тренажёре: дальше будут работать уже твои веса, а не веса курса.

`python3 01_Projects/tiny_language_model.py`

Попробуй изменить `SIZE`, `BLOCKS` или `LENGTH` и сравни время и ошибку. Для первой проверки можно передать маленькое число шагов вторым аргументом.

### Вопрос

Модель дала низкую ошибку на обучающем тексте. Почему этого мало, чтобы считать финиш пройденным?

### Варианты

- Низкая ошибка на своём тексте может значить запоминание, а не умение.
- Обучающий текст надо было взять длиннее, чем у счётчика пар букв.
- Ошибка на обучении всегда выше, чем на любом незнакомом тексте.

### Ответ

1

### Разбор

Гибкая модель может запомнить свои примеры, как в уроке о переобучении. Поэтому сравнивать надо на тексте, которого она не видела: и с угадыванием, и со счётчиком пар. Длина текста сама по себе ничего не докажет. Ошибка на незнакомых данных обычно выше, а не ниже, чем на обучающих.

### Границы модели

26624 весов — очень мало. Модель видит только 32 последних символа и не помнит ничего дальше. Весь текст взят из одного курса, поэтому она учит его стиль и повторяет его обороты. Чистый Python медленный: библиотеки вроде NumPy считают те же матрицы во много раз быстрее, и механизм при этом не меняется. Числа зависят от начальных весов, выбранных кусков и самого курса: при новом запуске в обучающий текст попадёт и этот урок, поэтому результат будет немного другим. Это не сознательный ИИ: о том, что наука знает и чего не знает о сознании, рассказывает следующий шаг пути.

## English

### In plain words

Here all the parts come together in one program: tokens, embeddings, transformer blocks, the gradient engine and Adam. The model learns on this course's texts to guess the next character. Like assembling a bicycle from parts you have each already made and tested. The finish counts only on text the model has not seen: the error there must be below random guessing and below a simple pair counter.

**What to know first.** All lessons of stage 2, especially «Your own gradient engine» (step 8), «The Transformer Block» (step 11) and «Reading training» (step 9).

**If something is unclear.** If some part of the program is unclear, find the lesson where it first appeared: gradients in step 8, the optimizer in step 9, attention and the block in step 11. If it is unclear why unseen text matters, reread «Machine Learning: Baselines». Look up any unfamiliar word in «The AI path glossary», the first item of the path.

### Goal

Gather everything learned into one program in plain Python: your own gradient mechanism, transformer blocks, and training on the course texts. Train the model on your own Mac and test it honestly on text it has not seen.

### Idea and mechanism

This is the finish of the path. There is no new mathematics here, only the assembly is new. We use no ready-made AI libraries, no paid services, not even NumPy: only standard Python. So every line can be explained.

**The finish line.** Let us say in advance what counts as success. The model must make fewer errors on unseen text than random guessing and the letter-pair counter. It must write new text resembling its training text. And you must be able to explain how it is built and what it cannot do. The text comes from the Russian parts of 134 lessons of this course: 382,107 characters and an alphabet of 144 signs. The model does not see the last 10% in training. Random guessing gives an error of `ln 144 ≈ 4.97`, and the pair counter 2.651. These are in nats, with the natural logarithm.

**Your own gradient mechanism.** In the attention lesson we ran the backward pass by hand, and it took long. Now we write a general mechanism. Each matrix in the program is a `Tensor` object that stores its numbers, the parents it came from, and a function `back` that passes the gradient to those parents. As the error is computed, these objects assemble themselves into a computation graph. Then `backward` walks it from the error to the weights. The walk goes in an order such that each node receives all its gradient before passing it on. That is why the `visit` pass is there.

Each operation knows only its own rule, and these are rules from earlier lessons. For a matrix product `Y = AB` with gradient `G` over `Y`, we get `∂L/∂A = G Bᵀ` and `∂L/∂B = Aᵀ G`. A sum passes the gradient to both terms unchanged: that is why a bypass carries the signal without loss. `ReLU` passes the gradient only where the input is positive. Normalization `y = (x − m)/s` passes `(g − ḡ − c·y)/s`, where `ḡ` is the mean of `g` and `c` is the mean of the products `g·y`. Attention uses the formula from its lesson. Before starting a long training run, we checked the mechanism numerically: we compared its answers with the slope of the error on 63 random weights, and the largest difference is 5.5·10⁻⁸.

**The model.** Each character gets a vector of length 32, and each of the 32 places its own place vector. Their sum goes into two transformer blocks, with two attention heads each, with bypasses and normalization. On top stands a matrix that turns a vector into 144 scores, one per character. That is 26624 weights in all.

**The Adam step.** Plain descent is slow on such networks, because the convenient step size differs greatly among weights. The Adam method keeps for each weight a running mean of its gradient `m` and a running mean of its square `s`, then makes a step of `η · m / √s`. A weight with large gradients gets a smaller step, and one with small gradients a larger step, so steps become commensurate. The factors `1 − βᵗ` correct the bias of the first steps, while the means are still close to zero.

**Training.** At each step we take 8 random pieces of 32 characters. The target at each place is the next character. We sum the gradients, make an Adam step, and repeat 6000 times. Every 500 steps we measure the error on the held-out text and keep the best weights: this is early stopping from the overfitting lesson.

Here is the whole program. It lives in `01_Projects/tiny_language_model.py` and runs from the repository root with `python3 01_Projects/tiny_language_model.py`:

```python
import json
import math
import re
import sys
import time
from collections import Counter
from operator import mul
from pathlib import Path

FOLDER = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("02_Areas")
STEPS = int(sys.argv[2]) if len(sys.argv) > 2 else 6000
SIZE, HEADS, BLOCKS, LENGTH, BATCH = 32, 2, 2, 32, 8  # vector length, heads, blocks, piece length, batch size
RATE = 0.003


class Generator:  # a simple random number generator
    def __init__(self, seed):
        self.state = seed

    def number(self):
        self.state = self.state * 16807 % 2147483647
        return self.state / 2147483647

    def below(self, limit):
        return int(self.number() * limit)

    def bell(self):  # a roughly normal number: a sum of 12 uniform ones
        return sum(self.number() for _ in range(12)) - 6


def read_course(folder):  # the Russian parts of the lessons, without code and headings
    parts, fence = [], "`" * 3
    for path in sorted(folder.glob("*/lessons/*.md")):
        sections = re.split(r"^#{2} (.+)$", path.read_text(encoding="utf-8"), flags=re.M)
        if "Русский" not in sections or "English" not in sections:
            continue
        russian = sections[sections.index("Русский") + 1]
        russian = re.sub(fence + ".*?" + fence, " ", russian, flags=re.S)
        russian = "\n".join(line for line in russian.split("\n") if not line.startswith(("#", "|")))
        parts.append(russian)
    return re.sub(r"[ \t]+", " ", re.sub(r"\n+", "\n", "\n".join(parts)))


text = read_course(FOLDER)
counts = Counter(text)
alphabet = sorted(c for c, n in counts.items() if n >= 40) + ["□"]  # rare characters are replaced by □
code = {c: i for i, c in enumerate(alphabet)}
numbers = [code.get(c, code["□"]) for c in text]
split = len(numbers) * 9 // 10
train, held = numbers[:split], numbers[split:]  # the model never sees the last 10% in training
V = len(alphabet)
print("characters", len(numbers), "alphabet", V, flush=True)


def pair_error():  # the letter-pair counter: the yardstick to beat
    pairs = Counter(zip(train, train[1:]))
    starts = Counter(train[:-1])
    total = sum(-math.log((pairs[a, b] + 0.1) / (starts[a] + 0.1 * V)) for a, b in zip(held, held[1:]))
    return total / (len(held) - 1)


print("random", round(math.log(V), 3), "pairs", round(pair_error(), 3), flush=True)


class Tensor:  # a matrix of numbers that remembers where it came from
    __slots__ = ("data", "grad", "parents", "back")

    def __init__(self, data, parents=(), back=None):
        self.data = data
        self.grad = None
        self.parents = parents
        self.back = back

    def add_grad(self, g):
        if self.grad is None:
            self.grad = g
        else:
            self.grad = [[a + b for a, b in zip(r, s)] for r, s in zip(self.grad, g)]


def multiply(a, b):
    columns = list(zip(*b))
    return [[sum(map(mul, row, c)) for c in columns] for row in a]


def flip(a):
    return [list(c) for c in zip(*a)]


def matmul(a, b):  # Y = A B: the gradients G Bᵀ and Aᵀ G
    def back(g):
        a.add_grad(multiply(g, flip(b.data)))
        b.add_grad(multiply(flip(a.data), g))
    return Tensor(multiply(a.data, b.data), (a, b), back)


def plus(a, b):  # a bypass: the gradient goes both ways unchanged
    def back(g):
        a.add_grad(g)
        b.add_grad(g)
    return Tensor([[x + y for x, y in zip(r, s)] for r, s in zip(a.data, b.data)], (a, b), back)


def relu(a):
    def back(g):
        a.add_grad([[v if x > 0 else 0.0 for v, x in zip(r, s)] for r, s in zip(g, a.data)])
    return Tensor([[x if x > 0 else 0.0 for x in r] for r in a.data], (a,), back)


def normalize(a):  # layer normalization at each place
    rows, infos = [], []
    for row in a.data:
        n = len(row)
        mean = sum(row) / n
        sigma = math.sqrt(sum((x - mean) ** 2 for x in row) / n)
        spread = sigma + 1e-5
        result = [(x - mean) / spread for x in row]
        rows.append(result)
        infos.append((spread, sigma, result))

    def back(g):
        out = []
        for gr, (spread, sigma, res) in zip(g, infos):
            n = len(gr)
            gm = sum(gr) / n
            gs = sum(map(mul, gr, res)) / n
            out.append([(v - gm) / spread - (gs * r / sigma if sigma else 0.0) for v, r in zip(gr, res)])
        a.add_grad(out)
    return Tensor(rows, (a,), back)


def attention_weights(q, k, root):  # the mask: only places already read
    weights = []
    for t, qt in enumerate(q):
        scores = [sum(map(mul, qt, k[j])) / root for j in range(t + 1)]
        top = max(scores)
        powers = [math.exp(s - top) for s in scores]
        total = sum(powers)
        weights.append([p / total for p in powers])
    return weights


def attend(q, k, v, root):
    size = len(v.data[0])
    weights = attention_weights(q.data, k.data, root)
    out = [[sum(map(mul, wt, column)) for column in (cv[:t + 1] for cv in zip(*v.data))] for t, wt in enumerate(weights)]

    def back(g):  # the same backward pass as in the attention lesson
        count = len(weights)
        gq = [[0.0] * size for _ in range(count)]
        gk = [[0.0] * size for _ in range(count)]
        gv = [[0.0] * size for _ in range(count)]
        for t, wt in enumerate(weights):
            gt, qt, gqt = g[t], q.data[t], gq[t]
            effect = [sum(map(mul, gt, v.data[j])) for j in range(t + 1)]
            mean = sum(map(mul, wt, effect))
            for j, w in enumerate(wt):
                pull = w * (effect[j] - mean) / root
                kj, gkj, gvj = k.data[j], gk[j], gv[j]
                for i in range(size):
                    gvj[i] += w * gt[i]
                    gqt[i] += pull * kj[i]
                    gkj[i] += pull * qt[i]
        v.add_grad(gv)
        q.add_grad(gq)
        k.add_grad(gk)
    return Tensor(out, (q, k, v), back)


def join(parts):  # joining the answers of the heads
    def back(g):
        start = 0
        for part in parts:
            width = len(part.data[0])
            part.add_grad([r[start:start + width] for r in g])
            start += width
    return Tensor([sum((p.data[t] for p in parts), []) for t in range(len(parts[0].data))], tuple(parts), back)


def lookup(table, indices):  # the embedding table: a row per character
    def back(g):
        out = [[0.0] * len(table.data[0]) for _ in table.data]
        for index, row in zip(indices, g):
            target = out[index]
            for i, value in enumerate(row):
                target[i] += value
        table.add_grad(out)
    return Tensor([table.data[i][:] for i in indices], (table,), back)


def cross_entropy(logits, targets):  # the mean cross-entropy and its gradient q − p
    total, grads, n = 0.0, [], len(targets)
    for row, target in zip(logits.data, targets):
        top = max(row)
        powers = [math.exp(z - top) for z in row]
        whole = sum(powers)
        q = [p / whole for p in powers]
        total -= math.log(q[target])
        g = [x / n for x in q]
        g[target] -= 1 / n
        grads.append(g)
    return total / n, grads


def backward(root, seed):  # walk the graph so that a node gets all its gradient before its parents
    order, seen = [], set()

    def visit(node):
        if id(node) in seen:
            return
        seen.add(id(node))
        for parent in node.parents:
            visit(parent)
        order.append(node)
    visit(root)
    root.grad = seed
    for node in reversed(order):
        if node.back is not None and node.grad is not None:
            node.back(node.grad)


random = Generator(20261102)
part = SIZE // HEADS
root_part = math.sqrt(part)


def table(rows, cols, scale=None):  # random starting weights
    scale = scale if scale is not None else 1 / math.sqrt(cols)
    return Tensor([[random.bell() * scale for _ in range(cols)] for _ in range(rows)])


letters, places = table(V, SIZE, 0.1), table(LENGTH, SIZE, 0.1)  # characters and place numbers
blocks = [{"q": [table(SIZE, part) for _ in range(HEADS)],
           "k": [table(SIZE, part) for _ in range(HEADS)],
           "v": [table(SIZE, part) for _ in range(HEADS)],
           "mix": table(SIZE, SIZE), "wide": table(SIZE, 2 * SIZE), "narrow": table(2 * SIZE, SIZE)}
          for _ in range(BLOCKS)]
out_weights = table(SIZE, V)
parameters = [letters, places, out_weights]
for block in blocks:
    parameters += block["q"] + block["k"] + block["v"] + [block["mix"], block["wide"], block["narrow"]]
print("weights", sum(len(p.data) * len(p.data[0]) for p in parameters), flush=True)


def forward(indices):  # the whole model: two blocks and the output
    x = plus(lookup(letters, indices), lookup(places, list(range(len(indices)))))
    for block in blocks:
        heads = [attend(matmul(x, q), matmul(x, k), matmul(x, v), root_part)
                 for q, k, v in zip(block["q"], block["k"], block["v"])]
        x = normalize(plus(x, matmul(join(heads), block["mix"])))
        x = normalize(plus(x, matmul(relu(matmul(x, block["wide"])), block["narrow"])))
    return matmul(x, out_weights)


first = [[[0.0] * len(p.data[0]) for _ in p.data] for p in parameters]
second = [[[0.0] * len(p.data[0]) for _ in p.data] for p in parameters]


def adam_step(step, rate):  # the Adam step: the mean gradient and its size for each weight
    b1, b2 = 0.9, 0.999
    c1, c2 = 1 - b1 ** step, 1 - b2 ** step
    for p, m, s in zip(parameters, first, second):
        if p.grad is None:
            continue
        for row, gr, mr, sr in zip(p.data, p.grad, m, s):
            for i, g in enumerate(gr):
                mr[i] = b1 * mr[i] + (1 - b1) * g
                sr[i] = b2 * sr[i] + (1 - b2) * g * g
                row[i] -= rate * (mr[i] / c1) / (math.sqrt(sr[i] / c2) + 1e-8)


def piece(data):  # a random piece of text and the same shifted by one character
    start = random.below(len(data) - LENGTH - 1)
    return data[start:start + LENGTH], data[start + 1:start + LENGTH + 1]


def measure(data, count=40):  # the error on the same 40 pieces
    saved = random.state
    random.state = 987654
    total = 0.0
    for _ in range(count):
        x, y = piece(data)
        total += cross_entropy(forward(x), y)[0]
    random.state = saved
    return total / count


def write(start, count, temperature):  # the model writes: drawing a character by probability with a temperature
    result = [code.get(c, code["□"]) for c in start]
    for _ in range(count):
        row = forward(result[-LENGTH:]).data[-1]
        top = max(row)
        powers = [math.exp((z - top) / temperature) for z in row]
        point = random.number() * sum(powers)
        for index, power in enumerate(powers):
            point -= power
            if point < 0:
                result.append(index)
                break
    return "".join(alphabet[i] for i in result)


def save(path):
    data = {"alphabet": alphabet, "size": SIZE, "heads": HEADS, "blocks": BLOCKS, "length": LENGTH, "weights": [p.data for p in parameters]}
    Path(path).write_text(json.dumps(data, ensure_ascii=False))


if __name__ == "__main__":
    begin, best = time.time(), (9.0, 0)
    print("start", round(measure(held), 3), flush=True)
    for step in range(1, STEPS + 1):
        for p in parameters:
            p.grad = None
        total = 0.0
        for _ in range(BATCH):
            x, y = piece(train)
            logits = forward(x)
            loss, seed = cross_entropy(logits, y)
            total += loss
            backward(logits, [[g / BATCH for g in row] for row in seed])
        adam_step(step, RATE if step < STEPS * 0.8 else RATE / 3)  # a smaller step toward the end
        if step % 500 == 0 or step == STEPS:
            checked = measure(held)
            if checked < best[0]:  # early stopping: keep the best weights
                best = (checked, step)
                save("tiny_model_best.json")
            print(step, "train", round(total / BATCH, 3), "held", round(checked, 3), "minutes", round((time.time() - begin) / 60, 1), flush=True)
    print("best", round(best[0], 3), "at step", best[1], flush=True)
```

**What came out.** This program trained on a MacBook Air M1 for 47 minutes, on one core. Here is the true training log:

```text
characters 382107 alphabet 144
random 4.97 pairs 2.651
weights 26624
start 5.039
500 train 2.571 held 2.582 minutes 3.8
1000 train 2.357 held 2.434 minutes 8.4
1500 train 2.415 held 2.379 minutes 12.5
2000 train 2.374 held 2.354 minutes 16.8
2500 train 2.345 held 2.283 minutes 20.7
3000 train 2.264 held 2.261 minutes 24.5
3500 train 2.231 held 2.234 minutes 28.3
4000 train 2.264 held 2.256 minutes 32.0
4500 train 2.206 held 2.237 minutes 35.8
5000 train 2.098 held 2.141 minutes 39.6
5500 train 2.02 held 2.149 minutes 43.4
6000 train 2.207 held 2.127 minutes 47.2
best 2.127 at step 6000
```

At the start the error is 5.039, close to `ln 144`. The best error on the held-out pieces is 2.127 at step 6000. On the whole held-out text it is 2.218, against 2.651 for the pair counter. The first part of the line is crossed: the model beats random guessing and the pair counter. The number on 40 pieces is slightly lower than on the whole text, because 40 pieces are a small sample.

And here is what it writes, starting from the words "Нейронная сеть" ("a neural network"), at different temperatures:

```text
T = 1.0: Нейронная сеть понясть `15T к5`.: «Опри `ass □ Bshas` и раска, корестся — меники нак пригость отатк по вледей. Пходять  `c5 же утаждиа. Для снига бупыложим гаращего подов в рассчен ракисловаль равняться смдель учит
T = 0.7: Нейронная сеть здели словерь а `2 м`, `ue` — `t = c`. Проверь се отвсетвает `1 рузата прывановрание окормение поредится сложную проверние функция вызать отста дво донят всю транные `uuy = 1` и `□□ модно из прос и п
T = 0.4: Нейронная сеть положить вредель при кледельном следу проверь на проверь простания только и сточно исть для предскольно следу словет все уго стремения собщений и и проверь при привает простать случается соти стровня
```

This is not coherent text, and it matters to say so honestly. The second part of the line is crossed in form only: the text is new and looks like the training text on the surface, but it has no meaning. The model has learned the letters and syllables of Russian, some frequent words of this course, such as «функция» and «проверь», and the habit of putting formulas in backticks. It does not understand meaning, does not track facts, and often invents words that do not exist. Real large models follow the same scheme but hold millions of times more weights and learn from far more text.

### Explore and practise

In the lab, this very trained model is at work. Change the text: the board shows its true attention, and the pillars the probabilities of the next character. Press Write and move the temperature. Find word beginnings the model is sure of. Switch blocks and heads.

Then train your own model. This is your finish. From the repository root run the command below and wait for the end. The file `tiny_model_best.json` appears in the same folder. Open it with the button in the lab: from then on your weights work, not the course's.

`python3 01_Projects/tiny_language_model.py`

Try changing `SIZE`, `BLOCKS`, or `LENGTH` and compare the time and the error. For a first check you can pass a small number of steps as the second argument.

### Question

A model reached a low error on its training text. Why is this not enough to count the finish as crossed?

### Options

- A low error on its own text can mean memorizing rather than skill.
- The training text should have been longer than the pair counter's.
- The training error is always higher than on any unseen text.

### Answer

1

### Explanation

A flexible model can memorize its examples, as in the overfitting lesson. So the comparison must be on text it has not seen: with both guessing and the pair counter. Text length alone proves nothing. The error on unseen data is usually higher, not lower, than on training data.

### Limits

26624 weights are very few. The model sees only the last 32 characters and remembers nothing further back. All the text comes from one course, so it learns its style and repeats its turns of phrase. Plain Python is slow: libraries like NumPy compute the same matrices many times faster, and the mechanism stays the same. The numbers depend on the starting weights, the pieces chosen, and the course itself: a new run also takes this lesson into the training text, so the result will differ slightly. This is not a conscious AI: the next step of the path tells what science knows and does not know about consciousness.

## Sources

- Ashish Vaswani and colleagues, “Attention Is All You Need”, arXiv:1706.03762 (2017), abstract read 2026-11-02: the transformer, built from attention: [arXiv:1706.03762](https://arxiv.org/abs/1706.03762)
- Diederik P. Kingma, Jimmy Ba, “Adam: A Method for Stochastic Optimization”, arXiv:1412.6980 (2014), ICLR 2015, abstract read 2026-11-02: step sizes adapted from running estimates of the moments of the gradients: [arXiv:1412.6980](https://arxiv.org/abs/1412.6980)
- Aston Zhang, Zachary C. Lipton, Mu Li, Alexander J. Smola, *Dive into Deep Learning* (version 1.0.3), “Adam” (consulted 2026-11-02): the two running averages, their typical constants, and the bias correction: [D2L, Adam](https://d2l.ai/chapter_optimization/adam.html)
- *Dive into Deep Learning*, “Automatic Differentiation” (consulted 2026-11-02): recording a computation graph and walking it backward by the chain rule: [D2L, autograd](https://d2l.ai/chapter_preliminaries/autograd.html)
- The program, the gradient check, the training log, and the samples were written and produced for this lesson on a MacBook Air M1. After the run, the function that reads the course was reworded so that this lesson displays correctly, and a check confirmed it gives the very same text. The lesson paraphrases these sources and does not copy their text.
