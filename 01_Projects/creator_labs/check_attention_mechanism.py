"""Строгая проверка: внимание / Strict check: attention.

python3 01_Projects/creator_labs/check_attention_mechanism.py [твой_файл.py]
Не подглядывай в эту проверку до своей попытки: здесь есть ответ. / Do not read before trying.
"""

import math

from _checklib import Checker, Rand, all_close, close, numeric_gradient, show

checker = Checker("Внимание", "Attention")
lab = checker.load("attention_blank.py")
rand = Rand(7)


def random_vectors(count, size):
    return [[rand.uniform(-2, 2) for _ in range(size)] for _ in range(count)]


def softmax_sums_to_one():
    for _ in range(20):
        scores = [rand.uniform(-5, 5) for _ in range(rand.below(6) + 1)]
        p = lab.softmax(scores)
        if len(p) != len(scores) or not close(sum(p), 1.0) or min(p) <= 0:
            return f"softmax({show(scores)}) = {show(p)}: сумма {sum(p):.6f}"
    return None


def softmax_matches_definition():
    scores = [0.5, -1.0, 2.0]
    total = sum(math.exp(s) for s in scores)
    expected = [math.exp(s) / total for s in scores]
    p = lab.softmax(scores)
    return None if all_close(p, expected, 1e-9) else f"ждали {show(expected)}, получили {show(p)}"


def softmax_large_scores():
    p = lab.softmax([1000.0, 1000.0, 999.0])
    e = math.exp(-1)
    expected = [1 / (2 + e), 1 / (2 + e), e / (2 + e)]
    return None if all_close(p, expected, 1e-9) else f"для [1000, 1000, 999] ждали {show(expected)}, получили {show(p)}"


def softmax_shift_invariant():
    scores = [rand.uniform(-3, 3) for _ in range(5)]
    a, b = lab.softmax(scores), lab.softmax([s + 37.5 for s in scores])
    return None if all_close(a, b, 1e-9) else "прибавка одного числа ко всем оценкам изменила вероятности"


def attention_reference(queries, keys, values, causal):
    weights, outputs = [], []
    for t, q in enumerate(queries):
        visible = range(t + 1) if causal else range(len(keys))
        scores = [sum(x * y for x, y in zip(q, keys[j])) / math.sqrt(len(q)) for j in visible]
        top = max(scores)
        powers = [math.exp(s - top) for s in scores]
        w = [p / sum(powers) for p in powers]
        weights.append(w)
        outputs.append([sum(w[i] * values[j][k] for i, j in enumerate(visible)) for k in range(len(values[0]))])
    return weights, outputs


def attention_causal_shape():
    q, k, v = random_vectors(5, 4), random_vectors(5, 4), random_vectors(5, 3)
    weights, outputs = lab.attention(q, k, v, causal=True)
    lengths = [len(w) for w in weights]
    if lengths != [1, 2, 3, 4, 5]:
        return f"при causal=True длины весов должны быть [1, 2, 3, 4, 5], а не {lengths}: позиция видит будущее"
    if not close(weights[0][0], 1.0):
        return "первая позиция видит только себя, её вес должен быть 1"
    if [len(o) for o in outputs] != [3] * 5:
        return "длина выхода должна совпадать с длиной векторов values"
    return None


def attention_matches_reference(causal):
    def run():
        for _ in range(10):
            n, d, m = rand.below(5) + 2, rand.below(4) + 2, rand.below(3) + 1
            q, k, v = random_vectors(n, d), random_vectors(n, d), random_vectors(n, m)
            got_w, got_o = lab.attention(q, k, v, causal=causal)
            want_w, want_o = attention_reference(q, k, v, causal)
            for t in range(n):
                if not all_close(got_w[t], want_w[t], 1e-7):
                    return f"позиция {t}: веса {show(got_w[t])}, ждали {show(want_w[t])}. Проверь деление на √d"
                if not all_close(got_o[t], want_o[t], 1e-7):
                    return f"позиция {t}: выход {show(got_o[t])}, ждали {show(want_o[t])}"
        return None
    return run


def attention_same_values():
    q, k = random_vectors(4, 3), random_vectors(4, 3)
    v = [[1.5, -2.0]] * 4
    _, outputs = lab.attention(q, k, v, causal=False)
    return None if all(all_close(o, [1.5, -2.0], 1e-9) for o in outputs) else "если все values одинаковы, выход обязан быть этим же вектором"


def backward_matches_numeric():
    for _ in range(10):
        n = rand.below(5) + 2
        scores = [rand.uniform(-3, 3) for _ in range(n)]
        c = [rand.uniform(-2, 2) for _ in range(n)]
        loss = lambda s: sum(ci * wi for ci, wi in zip(c, lab.softmax(s)))
        want = numeric_gradient(loss, scores)
        got = lab.softmax_backward(lab.softmax(scores), c)
        if not all_close(got, want, 1e-5):
            return f"градиент {show(got)}, численно {show(want)}"
    return None


def backward_sums_to_zero():
    scores = [rand.uniform(-3, 3) for _ in range(6)]
    got = lab.softmax_backward(lab.softmax(scores), [rand.uniform(-2, 2) for _ in range(6)])
    return None if abs(sum(got)) < 1e-9 else f"сумма градиента по оценкам {sum(got):.2e}, а должна быть 0: сдвиг всех оценок ничего не меняет"


checker.check("softmax: сумма 1 и все больше нуля", "softmax: sums to 1, all positive", softmax_sums_to_one)
checker.check("softmax совпадает с определением", "softmax matches the definition", softmax_matches_definition)
checker.check("softmax не ломается на оценках 1000", "softmax survives scores of 1000", softmax_large_scores)
checker.check("softmax не меняется от общей прибавки", "softmax ignores a common shift", softmax_shift_invariant)
checker.check("маска: позиция не видит будущее", "mask: no position sees the future", attention_causal_shape)
checker.check("внимание с маской совпадает с эталоном", "masked attention matches the reference", attention_matches_reference(True))
checker.check("внимание без маски совпадает с эталоном", "unmasked attention matches the reference", attention_matches_reference(False))
checker.check("одинаковые values дают тот же вектор", "equal values give that same vector", attention_same_values)
checker.check("обратный проход совпадает с численной производной", "backward matches the numerical derivative", backward_matches_numeric)
checker.check("градиент по оценкам в сумме 0", "score gradient sums to zero", backward_sums_to_zero)
checker.finish()
