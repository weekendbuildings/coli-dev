"""The same small language model as tiny_language_model.py, rewritten with NumPy matrices.
Та же маленькая языковая модель, что в tiny_language_model.py, но на матрицах NumPy.
Run from the repository root / Запуск из корня репозитория: python3 01_Projects/tiny_language_model_numpy.py
The explanation is in the lesson from_loops_to_matrices. / Объяснение в уроке from_loops_to_matrices.

Same text, same starting weights, same random pieces and the same Adam steps: only the arithmetic
moves from Python loops to whole matrices. / Тот же текст, те же начальные веса, те же случайные куски
и те же шаги Adam: меняется только то, как считается арифметика.
"""

import json
import math
import re
import sys
import time
from collections import Counter
from pathlib import Path

import numpy as np

FOLDER = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("02_Areas")
STEPS = int(sys.argv[2]) if len(sys.argv) > 2 else 6000
SIZE, HEADS, BLOCKS, LENGTH, BATCH = 32, 2, 2, 32, 8  # как в чистом Python / as in plain Python
RATE = 0.003


class Generator:  # тот же генератор, что в чистой версии / the same generator as the plain version
    def __init__(self, seed):
        self.state = seed

    def number(self):
        self.state = self.state * 16807 % 2147483647
        return self.state / 2147483647

    def below(self, limit):
        return int(self.number() * limit)

    def bell(self):
        return sum(self.number() for _ in range(12)) - 6


def read_course(folder):  # тот же текст курса / the same course text
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
alphabet = sorted(c for c, n in counts.items() if n >= 40) + ["□"]
code = {c: i for i, c in enumerate(alphabet)}
numbers = [code.get(c, code["□"]) for c in text]
split = len(numbers) * 9 // 10
train, held = numbers[:split], numbers[split:]
V = len(alphabet)
print("characters", len(numbers), "alphabet", V, flush=True)


def pair_error():  # та же линейка: счётчик пар букв / the same yardstick: the letter-pair counter
    pairs = Counter(zip(train, train[1:]))
    starts = Counter(train[:-1])
    total = sum(-math.log((pairs[a, b] + 0.1) / (starts[a] + 0.1 * V)) for a, b in zip(held, held[1:]))
    return total / (len(held) - 1)


print("random", round(math.log(V), 3), "pairs", round(pair_error(), 3), flush=True)

random = Generator(20261102)
part = SIZE // HEADS
root_part = math.sqrt(part)


def table(rows, cols, scale=None):  # те же числа в том же порядке / the same numbers in the same order
    scale = scale if scale is not None else 1 / math.sqrt(cols)
    return np.array([[random.bell() * scale for _ in range(cols)] for _ in range(rows)])


letters, places = table(V, SIZE, 0.1), table(LENGTH, SIZE, 0.1)
blocks = [{"q": [table(SIZE, part) for _ in range(HEADS)],
           "k": [table(SIZE, part) for _ in range(HEADS)],
           "v": [table(SIZE, part) for _ in range(HEADS)],
           "mix": table(SIZE, SIZE), "wide": table(SIZE, 2 * SIZE), "narrow": table(2 * SIZE, SIZE)}
          for _ in range(BLOCKS)]
out_weights = table(SIZE, V)
parameters = [letters, places, out_weights]
for block in blocks:
    parameters += block["q"] + block["k"] + block["v"] + [block["mix"], block["wide"], block["narrow"]]
print("weights", sum(p.size for p in parameters), flush=True)
future = np.triu(np.ones((LENGTH, LENGTH), dtype=bool), 1)  # маска: места после t / the mask: places after t


def normalize(a):  # нормализация слоя сразу для всех мест / layer normalization for all places at once
    centered = a - a.mean(axis=1, keepdims=True)
    sigma = np.sqrt((centered ** 2).mean(axis=1, keepdims=True))
    spread = sigma + 1e-5
    result = centered / spread
    return result, (result, spread, sigma)


def normalize_back(g, saved):  # точная производная: σ + ε у значения и σ у изменения σ / the exact derivative
    result, spread, sigma = saved
    gm = g.mean(axis=1, keepdims=True)
    gs = (g * result).mean(axis=1, keepdims=True)
    return (g - gm) / spread - gs * result / np.where(sigma > 0, sigma, 1.0)


def forward(indices):  # вся модель: каждая строка цикла стала одной операцией над матрицей / the whole model
    t = len(indices)
    x = letters[indices] + places[:t]
    mask, saved = future[:t, :t], []
    for block in blocks:
        heads = []
        for q_w, k_w, v_w in zip(block["q"], block["k"], block["v"]):
            q, k, v = x @ q_w, x @ k_w, x @ v_w
            scores = np.where(mask, -np.inf, q @ k.T / root_part)
            weights = np.exp(scores - scores.max(axis=1, keepdims=True))
            weights /= weights.sum(axis=1, keepdims=True)
            heads.append((q, k, v, weights, weights @ v))
        joined = np.concatenate([h[4] for h in heads], axis=1)
        x1, norm1 = normalize(x + joined @ block["mix"])
        wide = x1 @ block["wide"]
        active = np.maximum(wide, 0.0)
        x2, norm2 = normalize(x1 + active @ block["narrow"])
        saved.append((x, heads, joined, x1, norm1, wide, active, norm2))
        x = x2
    return x @ out_weights, (indices, saved, x)


def cross_entropy(logits, targets):  # средняя кросс-энтропия и её градиент q − p / the mean cross-entropy and q − p
    n = len(targets)
    shifted = logits - logits.max(axis=1, keepdims=True)
    q = np.exp(shifted)
    q /= q.sum(axis=1, keepdims=True)
    rows = np.arange(n)
    loss = -np.log(q[rows, targets]).mean()
    grad = q / n
    grad[rows, targets] -= 1 / n
    return loss, grad


def backward(g, state, grads):  # обратный проход матрицами: Y = A B даёт G Bᵀ и Aᵀ G / Y = A B gives G Bᵀ and Aᵀ G
    indices, saved, last = state
    grads[2] += last.T @ g
    g = g @ out_weights.T
    for number in reversed(range(BLOCKS)):
        block = blocks[number]
        x, heads, joined, x1, norm1, wide, active, norm2 = saved[number]
        first = 3 + number * (3 * HEADS + 3)
        g2 = normalize_back(g, norm2)
        grads[first + 3 * HEADS + 2] += active.T @ g2
        g_wide = (g2 @ block["narrow"].T) * (wide > 0)
        grads[first + 3 * HEADS + 1] += x1.T @ g_wide
        g1 = normalize_back(g2 + g_wide @ block["wide"].T, norm1)
        grads[first + 3 * HEADS] += joined.T @ g1
        g_joined = g1 @ block["mix"].T
        g_x = g1.copy()
        for h, (q, k, v, weights, _) in enumerate(heads):
            g_out = g_joined[:, h * part:(h + 1) * part]
            g_v = weights.T @ g_out
            g_w = g_out @ v.T
            g_s = weights * (g_w - (g_w * weights).sum(axis=1, keepdims=True)) / root_part
            g_q, g_k = g_s @ k, g_s.T @ q
            grads[first + h] += x.T @ g_q
            grads[first + HEADS + h] += x.T @ g_k
            grads[first + 2 * HEADS + h] += x.T @ g_v
            g_x += g_q @ block["q"][h].T + g_k @ block["k"][h].T + g_v @ block["v"][h].T
        g = g_x
    np.add.at(grads[0], indices, g)
    grads[1][:len(indices)] += g
    return grads


first_moment = [np.zeros_like(p) for p in parameters]
second_moment = [np.zeros_like(p) for p in parameters]


def adam_step(grads, step, rate):  # тот же Adam, но на целых массивах / the same Adam on whole arrays
    b1, b2 = 0.9, 0.999
    c1, c2 = 1 - b1 ** step, 1 - b2 ** step
    for p, g, m, s in zip(parameters, grads, first_moment, second_moment):
        m *= b1
        m += (1 - b1) * g
        s *= b2
        s += (1 - b2) * g * g
        p -= rate * (m / c1) / (np.sqrt(s / c2) + 1e-8)


def piece(data):
    start = random.below(len(data) - LENGTH - 1)
    return data[start:start + LENGTH], data[start + 1:start + LENGTH + 1]


def measure(data, count=40):
    saved = random.state
    random.state = 987654
    total = 0.0
    for _ in range(count):
        x, y = piece(data)
        total += cross_entropy(forward(x)[0], y)[0]
    random.state = saved
    return total / count


def train_step(step, rate):
    grads = [np.zeros_like(p) for p in parameters]
    total = 0.0
    for _ in range(BATCH):
        x, y = piece(train)
        logits, state = forward(x)
        loss, seed = cross_entropy(logits, y)
        total += loss
        backward(seed / BATCH, state, grads)
    adam_step(grads, step, rate)
    return total / BATCH


def save(path):
    data = {"alphabet": alphabet, "size": SIZE, "heads": HEADS, "blocks": BLOCKS, "length": LENGTH,
            "weights": [p.tolist() for p in parameters]}
    Path(path).write_text(json.dumps(data, ensure_ascii=False))


if __name__ == "__main__":
    begin, best = time.time(), (9.0, 0)
    print("start", round(measure(held), 3), flush=True)
    for step in range(1, STEPS + 1):
        loss = train_step(step, RATE if step < STEPS * 0.8 else RATE / 3)
        if step % 500 == 0 or step == STEPS:
            checked = measure(held)
            if checked < best[0]:
                best = (checked, step)
                save("tiny_model_numpy_best.json")
            print(step, "train", round(loss, 3), "held", round(checked, 3), "seconds", round(time.time() - begin, 1), flush=True)
    print("best", round(best[0], 3), "at step", best[1], flush=True)
