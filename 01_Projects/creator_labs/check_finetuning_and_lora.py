"""Строгая проверка: LoRA / Strict check: LoRA.

python3 01_Projects/creator_labs/check_finetuning_and_lora.py [твой_файл.py]
"""

import copy

from _checklib import Checker, Rand, all_close, numeric_gradient, show

checker = Checker("LoRA", "LoRA")
lab = checker.load("lora_blank.py")
rand = Rand(17)


def matrix(rows, cols):
    return [[rand.uniform(-1, 1) for _ in range(cols)] for _ in range(rows)]


def flat(m):
    return [v for row in m for v in row]


def shape(flat_values, rows, cols):
    return [flat_values[r * cols:(r + 1) * cols] for r in range(rows)]


def zero_b_is_base():
    W, A, x = matrix(4, 5), matrix(2, 5), [rand.uniform(-1, 1) for _ in range(5)]
    B = [[0.0, 0.0] for _ in range(4)]
    got, want = lab.lora_forward(W, A, B, x, 2.0), lab.matvec(W, x)
    return None if all_close(got, want, 1e-12) else "при B = 0 выход обязан совпасть с W x: поэтому B начинают с нулей"


def forward_matches_definition():
    for _ in range(5):
        m, n, r = rand.below(4) + 2, rand.below(4) + 2, rand.below(2) + 1
        W, A, B, x = matrix(m, n), matrix(r, n), matrix(m, r), [rand.uniform(-1, 1) for _ in range(n)]
        scale = rand.uniform(0.2, 2.0)
        low = lab.matvec(A, x)
        want = [wx + scale * bl for wx, bl in zip(lab.matvec(W, x), lab.matvec(B, low))]
        got = lab.lora_forward(W, A, B, x, scale)
        if not all_close(got, want, 1e-9):
            return f"выход {show(got)}, ждали {show(want)}"
    return None


def merged_same_output():
    W, A, B, x = matrix(3, 4), matrix(1, 4), matrix(3, 1), [rand.uniform(-1, 1) for _ in range(4)]
    W_before = copy.deepcopy(W)
    merged = lab.merged_weights(W, A, B, 0.5)
    if W != W_before:
        return "merged_weights изменил W, а W заморожена"
    got, want = lab.matvec(merged, x), lab.lora_forward(W, A, B, x, 0.5)
    return None if all_close(got, want, 1e-9) else "слитая матрица даёт другой выход, чем W и адаптер по отдельности"


def update_has_low_rank():
    W, A, B = matrix(4, 4), matrix(1, 4), matrix(4, 1)
    delta = [[m - w for m, w in zip(mr, wr)] for mr, wr in zip(lab.merged_weights(W, A, B, 1.0), W)]
    for i in range(4):
        for j in range(i + 1, 4):
            for k in range(4):
                for l in range(k + 1, 4):
                    minor = delta[i][k] * delta[j][l] - delta[i][l] * delta[j][k]
                    if abs(minor) > 1e-9:
                        return f"при r = 1 изменение W должно иметь ранг 1, но минор строк {i},{j} и столбцов {k},{l} равен {minor:.2e}"
    return None


def grads_match_numeric():
    for _ in range(5):
        m, n, r = rand.below(3) + 2, rand.below(3) + 2, rand.below(2) + 1
        W, A, B, x = matrix(m, n), matrix(r, n), matrix(m, r), [rand.uniform(-1, 1) for _ in range(n)]
        c, scale = [rand.uniform(-1, 1) for _ in range(m)], rand.uniform(0.5, 2.0)
        loss_a = lambda a: sum(ci * yi for ci, yi in zip(c, lab.lora_forward(W, shape(a, r, n), B, x, scale)))
        loss_b = lambda b: sum(ci * yi for ci, yi in zip(c, lab.lora_forward(W, A, shape(b, m, r), x, scale)))
        dA, dB = lab.lora_grads(A, B, x, c, scale)
        if [len(row) for row in dA] != [n] * r or [len(row) for row in dB] != [r] * m:
            return "форма dA или dB не совпадает с A или B"
        if not all_close(flat(dA), numeric_gradient(loss_a, flat(A)), 1e-5):
            return f"dA {show(flat(dA))}, численно {show(numeric_gradient(loss_a, flat(A)))}"
        if not all_close(flat(dB), numeric_gradient(loss_b, flat(B)), 1e-5):
            return f"dB {show(flat(dB))}, численно {show(numeric_gradient(loss_b, flat(B)))}"
    return None


def zero_b_still_trains_b():
    A, x = matrix(2, 3), [0.5, -1.0, 2.0]
    B = [[0.0, 0.0] for _ in range(3)]
    dA, dB = lab.lora_grads(A, B, x, [1.0, 0.0, -1.0], 1.0)
    if any(abs(v) > 1e-12 for v in flat(dA)):
        return "при B = 0 градиент по A должен быть 0"
    if all(abs(v) < 1e-12 for v in flat(dB)):
        return "при B = 0 градиент по B не должен быть нулём, иначе адаптер никогда не начнёт учиться"
    return None


def parameter_saving():
    m = n = 512
    r = 8
    full, adapter = m * n, r * (m + n)
    print(f"      справка: W {m}×{n} = {full} весов, адаптер r = {r}: {adapter} весов, это {100 * adapter / full:.1f} %")
    return None


checker.check("при B = 0 модель не меняется", "with B = 0 the model is unchanged", zero_b_is_base)
checker.check("выход совпадает с определением", "the output matches the definition", forward_matches_definition)
checker.check("слитая матрица даёт тот же выход, W не тронута", "the merged matrix gives the same output, W untouched", merged_same_output)
checker.check("изменение W имеет ранг не выше r", "the change to W has rank at most r", update_has_low_rank)
checker.check("градиенты по A и B совпадают с численными", "gradients for A and B match the numerical ones", grads_match_numeric)
checker.check("при B = 0 учится B, а не A", "with B = 0, B learns first, not A", zero_b_still_trains_b)
checker.check("сколько весов экономит адаптер", "how many weights the adapter saves", parameter_saving)
checker.finish()
