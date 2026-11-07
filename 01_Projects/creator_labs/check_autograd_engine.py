"""Строгая проверка: механизм градиентов / Strict check: autograd engine.

python3 01_Projects/creator_labs/check_autograd_engine.py [твой_файл.py]
"""

import math

from _checklib import Checker, Rand, all_close, close, numeric_gradient, show

checker = Checker("Механизм градиентов", "Autograd engine")
lab = checker.load("autograd_blank.py")
Value = lab.Value
rand = Rand(11)


def grads_of(build, point):
    leaves = [Value(x) for x in point]
    out = build(leaves)
    out.backward()
    return out.data, [leaf.grad for leaf in leaves]


def plain(build):
    """Та же формула на обычных числах. / The same formula on plain floats."""
    class Number(float):
        def tanh(self):
            return Number(math.tanh(self))

        def __add__(self, o):
            return Number(float(self) + float(o))

        __radd__ = __add__

        def __mul__(self, o):
            return Number(float(self) * float(o))

        __rmul__ = __mul__

        def __neg__(self):
            return Number(-float(self))

        def __sub__(self, o):
            return Number(float(self) - float(o))

    return lambda point: float(build([Number(x) for x in point]))


def product_rule():
    _, g = grads_of(lambda v: v[0] * v[1], [3.0, -2.0])
    return None if all_close(g, [-2.0, 3.0]) else f"для a·b при a=3, b=−2 ждали [−2, 3], получили {show(g)}"


def reuse_accumulates():
    _, g = grads_of(lambda v: v[0] * v[0], [1.5])
    return None if close(g[0], 3.0) else f"для x·x при x=1,5 ждали 3, получили {g[0]:.4f}: узел использован дважды"


def tanh_rule():
    for x in (-2.0, -0.3, 0.0, 0.7, 3.0):
        _, g = grads_of(lambda v: v[0].tanh(), [x])
        want = 1 - math.tanh(x) ** 2
        if not close(g[0], want):
            return f"tanh'({x}) = {want:.6f}, получили {g[0]:.6f}"
    return None


def diamond_once():
    def build(v):
        h = (v[0] * 3.0).tanh()  # общий промежуточный узел / a shared inner node
        return h * h + h * 2.0

    x = 0.2
    _, g = grads_of(build, [x])
    h = math.tanh(3 * x)
    want = (2 * h + 2) * 3 * (1 - h * h)
    if not close(g[0], want):
        return f"для h = tanh(3x), h·h + 2h при x = 0,2 ждали {want:.5f}, получили {g[0]:.5f}: общий узел h отдал градиент не один раз или раньше, чем получил весь"
    return None


def random_graphs():
    formulas = [
        lambda v: (v[0] * v[1] + v[2]).tanh() * v[0],
        lambda v: (v[0] - v[1] * v[1]).tanh() + v[2] * v[0] * 0.5,
        lambda v: ((v[0] * v[1]).tanh() * (v[1] + v[2]).tanh()) * (v[2] - v[0]),
        lambda v: v[0] * v[1] * v[2] + (v[0] * 2.0 + v[1]).tanh() * v[2],
    ]
    for formula in formulas:
        for _ in range(5):
            point = [rand.uniform(-1.5, 1.5) for _ in range(3)]
            _, got = grads_of(formula, point)
            want = numeric_gradient(plain(formula), point)
            if not all_close(got, want, 1e-5):
                return f"в точке {show(point)} градиент {show(got)}, численно {show(want)}"
    return None


def deep_chain():
    x = Value(0.3)
    y = x
    for _ in range(100):
        y = (y * 0.9 + 0.05).tanh()
    y.backward()
    value = 0.3
    derivative = 1.0
    for _ in range(100):
        t = math.tanh(value * 0.9 + 0.05)
        derivative *= 0.9 * (1 - t * t)
        value = t
    return None if close(x.grad, derivative, 1e-6) else f"в цепочке из 100 шагов градиент {x.grad:.3e}, ждали {derivative:.3e}"


def fresh_backward():
    a, b = Value(2.0), Value(5.0)
    (a * b).backward()
    if not (close(a.grad, 5.0) and close(b.grad, 2.0)):
        return f"после одного backward a.grad={a.grad}, b.grad={b.grad}"
    out = a * b
    return None if close(out.grad, 0.0) else "новый узел должен начинать с grad = 0"


checker.check("умножение: правило произведения", "multiplication: product rule", product_rule)
checker.check("узел, использованный дважды, копит градиент", "a node used twice accumulates its gradient", reuse_accumulates)
checker.check("tanh: производная", "tanh: derivative", tanh_rule)
checker.check("ромб: каждый узел один раз и в верном порядке", "diamond: each node once, in order", diamond_once)
checker.check("случайные графы совпадают с численной производной", "random graphs match the numerical derivative", random_graphs)
checker.check("цепочка из 100 шагов", "a 100-step chain", deep_chain)
checker.check("градиенты начинаются с нуля", "gradients start at zero", fresh_backward)
checker.finish()
