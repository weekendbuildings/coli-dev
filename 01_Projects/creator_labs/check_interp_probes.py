"""Строгая проверка: линейный зонд / Strict check: linear probe.

python3 01_Projects/creator_labs/check_interp_probes.py [твой_файл.py]
"""

import math

from _checklib import Checker, Rand, all_close, close, numeric_gradient, show

checker = Checker("Линейный зонд", "Linear probe")
lab = checker.load("probe_blank.py")
rand = Rand(19)


def dataset(count, size, rule):
    xs = [[rand.uniform(-1, 1) for _ in range(size)] for _ in range(count)]
    return xs, [rule(x) for x in xs]


def zero_weights_loss():
    xs, ys = dataset(30, 4, lambda x: int(x[0] > 0))
    loss, grad_w, grad_b = lab.loss_and_grad([0.0] * 4, 0.0, xs, ys)
    if not close(loss, math.log(2), 1e-9):
        return f"при нулевых весах p = 1/2 и ошибка ln 2 ≈ 0,6931, получили {loss:.4f}"
    if len(grad_w) != 4:
        return "градиент по весам должен иметь столько же чисел, сколько признаков"
    return None


def grad_matches_numeric():
    for _ in range(5):
        xs, ys = dataset(20, 3, lambda x: int(x[0] + 0.5 * x[1] > 0))
        point = [rand.uniform(-1, 1) for _ in range(4)]
        loss = lambda p: lab.loss_and_grad(p[:3], p[3], xs, ys)[0]
        want = numeric_gradient(loss, point)
        _, grad_w, grad_b = lab.loss_and_grad(point[:3], point[3], xs, ys)
        got = list(grad_w) + [grad_b]
        if not all_close(got, want, 1e-5):
            return f"градиент {show(got)}, численно {show(want)}. Проверь деление на число примеров"
    return None


def loss_goes_down():
    xs, ys = dataset(40, 3, lambda x: int(x[1] > 0.1))
    weights, bias, previous = [0.0] * 3, 0.0, None
    for _ in range(50):
        loss, grad_w, grad_b = lab.loss_and_grad(weights, bias, xs, ys)
        if previous is not None and loss > previous + 1e-12:
            return f"при малом шаге ошибка выросла с {previous:.5f} до {loss:.5f}: знак градиента?"
        previous = loss
        weights = [w - 0.1 * g for w, g in zip(weights, grad_w)]
        bias -= 0.1 * grad_b
    return None


def finds_a_real_direction():
    rule = lambda x: int(0.8 * x[2] - 0.6 * x[5] > 0.05)
    train_x, train_y = dataset(200, 8, rule)
    test_x, test_y = dataset(200, 8, rule)
    weights, bias = lab.train_probe(train_x, train_y)
    score = lab.accuracy(weights, bias, test_x, test_y)
    return None if score >= 0.95 else f"на новых примерах точность {score:.3f}, а признак линейный: нужно не меньше 0,95"


def control_task_stays_at_chance():
    train_x, _ = dataset(60, 20, lambda x: 0)
    test_x, _ = dataset(400, 20, lambda x: 0)
    train_y = [int(rand.next() < 0.5) for _ in train_x]
    test_y = [int(rand.next() < 0.5) for _ in test_x]
    weights, bias = lab.train_probe(train_x, train_y)
    seen, unseen = lab.accuracy(weights, bias, train_x, train_y), lab.accuracy(weights, bias, test_x, test_y)
    print(f"      случайные метки: на обучении {seen:.2f}, на новых {unseen:.2f}. Высокая точность на обучении ещё ничего не значит")
    return None if 0.35 <= unseen <= 0.65 else f"на случайных метках точность на новых примерах {unseen:.2f}, а должна быть около 0,5"


checker.check("при нулевых весах ошибка ln 2", "with zero weights the loss is ln 2", zero_weights_loss)
checker.check("градиент совпадает с численным", "the gradient matches the numerical one", grad_matches_numeric)
checker.check("малый шаг по градиенту снижает ошибку", "a small gradient step lowers the loss", loss_goes_down)
checker.check("зонд находит настоящее направление", "the probe finds a real direction", finds_a_real_direction)
checker.check("контроль: на случайных метках угадывания нет", "control: no guessing on random labels", control_task_stays_at_chance)
checker.finish()
