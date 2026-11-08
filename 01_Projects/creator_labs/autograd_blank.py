"""Собери и проверь сам: механизм градиентов / Build and check it yourself: an autograd engine.

Урок: «Свой механизм градиентов» (autograd_engine). Сложение уже написано как образец.
Допиши, где стоит NotImplementedError: передачу градиента в умножении и в tanh и сам
обратный проход. Проверка:
    python3 01_Projects/creator_labs/check_autograd_engine.py
Lesson: autograd_engine. Addition is done as an example. Fill in the gradient push for
multiplication and tanh, and the backward pass itself.
"""

import math


class Value:
    def __init__(self, data, parents=()):
        self.data = float(data)
        self.grad = 0.0
        self.parents = parents
        self.push = lambda: None  # передаёт result.grad родителям / passes result.grad to the parents

    def __add__(self, other):
        other = other if isinstance(other, Value) else Value(other)
        result = Value(self.data + other.data, (self, other))

        def push():
            # Образец: d(a + b)/da = 1 и d(a + b)/db = 1. «+=», потому что узел может
            # использоваться несколько раз. / "+=" because a node can be used many times.
            self.grad += result.grad
            other.grad += result.grad

        result.push = push
        return result

    def __mul__(self, other):
        other = other if isinstance(other, Value) else Value(other)
        result = Value(self.data * other.data, (self, other))

        def push():
            # Твой шаг: сколько градиента получают self и other? / Your step.
            raise NotImplementedError("__mul__ push")

        result.push = push
        return result

    def tanh(self):
        result = Value(math.tanh(self.data), (self,))

        def push():
            # Твой шаг: производная tanh. Подсказка: её можно выразить через result.data.
            # Your step: the derivative of tanh, expressible through result.data.
            raise NotImplementedError("tanh push")

        result.push = push
        return result

    def backward(self):
        """Твой шаг: градиент self по себе равен 1. Затем вызови push у каждого узла так, чтобы
        узел отдавал градиент только после того, как получил его от всех, кто его использует.
        Каждый узел ровно один раз.
        Your step: set self.grad = 1, then call push on every node exactly once, each node only
        after every node that uses it has already pushed (reverse topological order).
        """
        raise NotImplementedError("backward")

    # Удобства, готовы. / Conveniences, done.
    def __radd__(self, other):
        return self + other

    def __rmul__(self, other):
        return self * other

    def __neg__(self):
        return self * -1

    def __sub__(self, other):
        return self + (-other if isinstance(other, Value) else Value(-other))
