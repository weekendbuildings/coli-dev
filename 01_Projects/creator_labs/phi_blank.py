"""Собери и проверь сам: мера интеграции для любого числа узлов
Build and check it yourself: an integration measure for any number of nodes.

Урок: «Интегрированная информация» (consciousness_integrated_information). В уроке три узла и
три разреза. Здесь шаг дальше: n узлов и все разрезы на две части. Честно: это упрощённая мера,
не полный Φ теории IIT. Допиши две функции. Проверка:
    python3 01_Projects/creator_labs/check_consciousness_integrated_information.py
Lesson: consciousness_integrated_information. The lesson has three nodes and three cuts; here you
go further: n nodes and every cut into two parts. Honestly: a simplified measure, not full IIT Φ.

Сеть это кортеж функций gates: gates[i](state) даёт следующее значение узла i (0 или 1).
A network is a tuple of gates: gates[i](state) gives node i's next value.
"""

import itertools
import math


def states(n):
    return list(itertools.product((0, 1), repeat=n))


def next_state(gates, state):
    return tuple(gate(state) for gate in gates)


def all_bipartitions(n):
    """Все способы разрезать узлы 0..n−1 на две непустые части, каждый ровно один раз.
    Верни список пар (part, rest) отсортированных кортежей; часть с узлом 0 идёт первой.
    Для n = 3 это ((0,), (1, 2)), ((0, 1), (2,)), ((0, 2), (1,)).
    Every way to split nodes 0..n−1 into two non-empty parts, each once; the part with node 0 first.
    """
    raise NotImplementedError("all_bipartitions")


def part_distribution(gates, part, state):
    """Готово, как в уроке: узлы части видят своё прошлое, а остальные узлы для них случайны.
    Done, as in the lesson: a part sees its own past; the other nodes look random to it.
    """
    n = len(state)
    others = [i for i in range(n) if i not in part]
    choices = list(itertools.product((0, 1), repeat=len(others)))
    outs = {}
    for choice in choices:
        filled = list(state)
        for i, value in zip(others, choice):
            filled[i] = value
        result = tuple(gates[i](tuple(filled)) for i in part)
        outs[result] = outs.get(result, 0.0) + 1 / len(choices)
    return outs


def lost_when_cut(gates, cut):
    """Средняя по всем состояниям потеря в битах при разрезе cut = (part, rest):
    log₂(1 / вероятность настоящего следующего состояния, если части предсказывают отдельно).
    Если вероятность 0, считай потерю равной n битам.
    Mean loss in bits over all states: log₂(1 / chance of the real next state when the parts
    predict separately). If the chance is 0, count the loss as n bits.
    """
    raise NotImplementedError("lost_when_cut")


def integration(gates):
    """Готово: самый слабый разрез. / Done: the weakest cut."""
    n = len(gates)
    losses = [lost_when_cut(gates, cut) for cut in all_bipartitions(n)]
    return min(losses)
