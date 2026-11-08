"""Собери и проверь сам: внимание / Build and check it yourself: attention.

Урок: «Механизм внимания» (attention_mechanism). Допиши три функции, где стоит
`raise NotImplementedError`. Ничего не копируй из урока: напиши по описанию и проверь:
    python3 01_Projects/creator_labs/check_attention_mechanism.py
Lesson: attention_mechanism. Fill in the three functions that raise NotImplementedError,
from the description, not from the lesson's code, then run the check above.

Векторы это списки чисел. / Vectors are lists of numbers.
"""

import math


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def softmax(scores):
    """Оценки → вероятности: все больше нуля, сумма 1, больше оценка → больше вероятность.
    Должна работать и для оценок вроде [1000, 1000]: math.exp(1000) переполняется.
    Scores → probabilities: all positive, sum 1, order kept. Must work for [1000, 1000] too.
    """
    raise NotImplementedError("softmax")


def attention(queries, keys, values, causal=True):
    """Масштабированное скалярное внимание. / Scaled dot-product attention.

    Для каждой позиции t: оценка позиции j равна dot(q_t, k_j), делённому на корень из
    длины вектора запроса. При causal=True позиция t смотрит только на j от 0 до t.
    Веса это softmax оценок, выход это сумма весов, умноженных на векторы values[j].
    For each position t: the score of position j is dot(q_t, k_j) divided by the square root
    of the query length. With causal=True position t sees only j = 0..t. Weights are the
    softmax of the scores; the output is the weighted sum of values[j].

    Верни (weights, outputs): weights[t] это список весов, outputs[t] это вектор.
    Return (weights, outputs): weights[t] is a list of weights, outputs[t] is a vector.
    """
    raise NotImplementedError("attention")


def softmax_backward(weights, upstream):
    """Обратный проход через softmax. / Backward pass through softmax.

    weights = softmax(scores), upstream[k] = dL/dweights[k]. Верни список dL/dscores[j].
    Выведи формулу сам: как меняется weights[k], если чуть сдвинуть scores[j]?
    Return dL/dscores[j]. Derive it yourself: how does weights[k] move when scores[j] moves?
    Именно эта формула учит запросы и ключи в уроке. / This is what trains queries and keys.
    """
    raise NotImplementedError("softmax_backward")
