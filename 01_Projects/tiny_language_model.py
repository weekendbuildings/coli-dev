"""The final project of the AI path: a small language model in plain Python, trained on the course texts.
Финальный проект пути ИИ: маленькая языковая модель на чистом Python, обучается на текстах курса.

Run from the repository root / Запуск из корня репозитория: python3 01_Projects/tiny_language_model.py
The explanation is in the lesson build_your_language_model. / Объяснение в уроке build_your_language_model.
"""
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
SIZE, HEADS, BLOCKS, LENGTH, BATCH = 32, 2, 2, 32, 8  # длина вектора, головы, блоки, длина куска, размер пакета / vector length, heads, blocks, piece length, batch size
RATE = 0.003


class Generator:  # простой генератор случайных чисел / a simple random number generator
    def __init__(self, seed):
        self.state = seed

    def number(self):
        self.state = self.state * 16807 % 2147483647
        return self.state / 2147483647

    def below(self, limit):
        return int(self.number() * limit)

    def bell(self):  # примерно нормальное число: сумма 12 равномерных / a roughly normal number: a sum of 12 uniform ones
        return sum(self.number() for _ in range(12)) - 6


def read_course(folder):  # русские части уроков без кода и заголовков / the Russian parts of the lessons, without code and headings
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
alphabet = sorted(c for c, n in counts.items() if n >= 40) + ["□"]  # редкие символы заменяем на □ / rare characters are replaced by □
code = {c: i for i, c in enumerate(alphabet)}
numbers = [code.get(c, code["□"]) for c in text]
split = len(numbers) * 9 // 10
train, held = numbers[:split], numbers[split:]  # последние 10 % модель не видит при обучении / the model never sees the last 10% in training
V = len(alphabet)
print("characters", len(numbers), "alphabet", V, flush=True)


def pair_error():  # счётчик пар букв: линейка, которую надо обойти / the letter-pair counter: the yardstick to beat
    pairs = Counter(zip(train, train[1:]))
    starts = Counter(train[:-1])
    total = sum(-math.log((pairs[a, b] + 0.1) / (starts[a] + 0.1 * V)) for a, b in zip(held, held[1:]))
    return total / (len(held) - 1)


print("random", round(math.log(V), 3), "pairs", round(pair_error(), 3), flush=True)


class Tensor:  # число-матрица, которая помнит, откуда взялась / a matrix of numbers that remembers where it came from
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


def matmul(a, b):  # Y = A B: градиенты G Bᵀ и Aᵀ G / Y = A B: the gradients G Bᵀ and Aᵀ G
    def back(g):
        a.add_grad(multiply(g, flip(b.data)))
        b.add_grad(multiply(flip(a.data), g))
    return Tensor(multiply(a.data, b.data), (a, b), back)


def plus(a, b):  # обходной путь: градиент идёт в обе стороны как есть / a bypass: the gradient goes both ways unchanged
    def back(g):
        a.add_grad(g)
        b.add_grad(g)
    return Tensor([[x + y for x, y in zip(r, s)] for r, s in zip(a.data, b.data)], (a, b), back)


def relu(a):
    def back(g):
        a.add_grad([[v if x > 0 else 0.0 for v, x in zip(r, s)] for r, s in zip(g, a.data)])
    return Tensor([[x if x > 0 else 0.0 for x in r] for r in a.data], (a,), back)


def normalize(a):  # нормализация слоя по каждому месту / layer normalization at each place
    rows, infos = [], []
    for row in a.data:
        n = len(row)
        mean = sum(row) / n
        spread = math.sqrt(sum((x - mean) ** 2 for x in row) / n) + 1e-5
        result = [(x - mean) / spread for x in row]
        rows.append(result)
        infos.append((spread, result))

    def back(g):
        out = []
        for gr, (spread, res) in zip(g, infos):
            n = len(gr)
            gm = sum(gr) / n
            gs = sum(map(mul, gr, res)) / n
            out.append([(v - gm - gs * r) / spread for v, r in zip(gr, res)])
        a.add_grad(out)
    return Tensor(rows, (a,), back)


def attention_weights(q, k, root):  # маска: только уже прочитанные места / the mask: only places already read
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

    def back(g):  # тот же обратный проход, что в уроке о внимании / the same backward pass as in the attention lesson
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


def join(parts):  # склейка ответов голов / joining the answers of the heads
    def back(g):
        start = 0
        for part in parts:
            width = len(part.data[0])
            part.add_grad([r[start:start + width] for r in g])
            start += width
    return Tensor([sum((p.data[t] for p in parts), []) for t in range(len(parts[0].data))], tuple(parts), back)


def lookup(table, indices):  # таблица эмбеддингов: строка на символ / the embedding table: a row per character
    def back(g):
        out = [[0.0] * len(table.data[0]) for _ in table.data]
        for index, row in zip(indices, g):
            target = out[index]
            for i, value in enumerate(row):
                target[i] += value
        table.add_grad(out)
    return Tensor([table.data[i][:] for i in indices], (table,), back)


def cross_entropy(logits, targets):  # средняя кросс-энтропия и её градиент q − p / the mean cross-entropy and its gradient q − p
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


def backward(root, seed):  # обходим граф так, чтобы узел получил весь свой градиент раньше родителей / walk the graph so that a node gets all its gradient before its parents
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


def table(rows, cols, scale=None):  # случайные начальные веса / random starting weights
    scale = scale if scale is not None else 1 / math.sqrt(cols)
    return Tensor([[random.bell() * scale for _ in range(cols)] for _ in range(rows)])


letters, places = table(V, SIZE, 0.1), table(LENGTH, SIZE, 0.1)  # символы и номера мест / characters and place numbers
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


def forward(indices):  # вся модель: два блока и выход / the whole model: two blocks and the output
    x = plus(lookup(letters, indices), lookup(places, list(range(len(indices)))))
    for block in blocks:
        heads = [attend(matmul(x, q), matmul(x, k), matmul(x, v), root_part)
                 for q, k, v in zip(block["q"], block["k"], block["v"])]
        x = normalize(plus(x, matmul(join(heads), block["mix"])))
        x = normalize(plus(x, matmul(relu(matmul(x, block["wide"])), block["narrow"])))
    return matmul(x, out_weights)


first = [[[0.0] * len(p.data[0]) for _ in p.data] for p in parameters]
second = [[[0.0] * len(p.data[0]) for _ in p.data] for p in parameters]


def adam_step(step, rate):  # шаг Adam: средний градиент и его размер у каждого веса / the Adam step: the mean gradient and its size for each weight
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


def piece(data):  # случайный кусок текста и он же со сдвигом на символ / a random piece of text and the same shifted by one character
    start = random.below(len(data) - LENGTH - 1)
    return data[start:start + LENGTH], data[start + 1:start + LENGTH + 1]


def measure(data, count=40):  # ошибка на одних и тех же 40 кусках / the error on the same 40 pieces
    saved = random.state
    random.state = 987654
    total = 0.0
    for _ in range(count):
        x, y = piece(data)
        total += cross_entropy(forward(x), y)[0]
    random.state = saved
    return total / count


def write(start, count, temperature):  # модель пишет: выбор символа по вероятностям с температурой / the model writes: drawing a character by probability with a temperature
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
        adam_step(step, RATE if step < STEPS * 0.8 else RATE / 3)  # под конец шаг меньше / a smaller step toward the end
        if step % 500 == 0 or step == STEPS:
            checked = measure(held)
            if checked < best[0]:  # ранняя остановка: храним лучшие веса / early stopping: keep the best weights
                best = (checked, step)
                save("tiny_model_best.json")
            print(step, "train", round(total / BATCH, 3), "held", round(checked, 3), "minutes", round((time.time() - begin) / 60, 1), flush=True)
    print("best", round(best[0], 3), "at step", best[1], flush=True)
