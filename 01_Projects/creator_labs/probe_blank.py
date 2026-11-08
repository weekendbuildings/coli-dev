"""Собери и проверь сам: линейный зонд / Build and check it yourself: a linear probe.

Урок: «Зонды: что знает модель внутри» (interp_probes). Зонд это логистическая регрессия на
активациях: по вектору h угадать да или нет. Допиши loss_and_grad, остальное готово. Проверка:
    python3 01_Projects/creator_labs/check_interp_probes.py
Lesson: interp_probes. A probe is logistic regression on activations. Fill in loss_and_grad.
"""

import math


def sigmoid(s):
    s = max(-30.0, min(30.0, s))
    return 1 / (1 + math.exp(-s))


def loss_and_grad(weights, bias, features, labels):
    """Средняя логистическая ошибка и её градиент. / Mean logistic loss and its gradient.

    Для примера (x, y) с y = 0 или 1: p = sigmoid(w · x + b), ошибка −(y·ln p + (1 − y)·ln(1 − p)).
    Верни (средняя ошибка, градиент по weights списком, градиент по bias числом).
    Градиент выведи сам. / Derive the gradient yourself.
    """
    raise NotImplementedError("loss_and_grad")


def train_probe(features, labels, epochs=300, rate=0.5):
    """Готово: полный градиентный спуск. / Done: full-batch gradient descent."""
    weights, bias = [0.0] * len(features[0]), 0.0
    for _ in range(epochs):
        _, grad_w, grad_b = loss_and_grad(weights, bias, features, labels)
        weights = [w - rate * g for w, g in zip(weights, grad_w)]
        bias -= rate * grad_b
    return weights, bias


def accuracy(weights, bias, features, labels):
    """Готово. / Done."""
    right = sum((sum(w * v for w, v in zip(weights, x)) + bias > 0) == bool(y) for x, y in zip(features, labels))
    return right / len(labels)
