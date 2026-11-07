"""Строгая проверка: мера интеграции / Strict check: integration measure.

python3 01_Projects/creator_labs/check_consciousness_integrated_information.py [твой_файл.py]
"""

from _checklib import Checker, close

checker = Checker("Мера интеграции", "Integration measure")
lab = checker.load("phi_blank.py")

LESSON_NETWORKS = {
    "disconnected": ((lambda s: s[0], lambda s: s[1], lambda s: s[2]), 0.0),
    "chain": ((lambda s: s[2], lambda s: s[0], lambda s: s[1]), 2.0),
    "xor ring": ((lambda s: s[1] ^ s[2], lambda s: s[0] ^ s[2], lambda s: s[0] ^ s[1]), 2.0),
    "everyone copies node 0": ((lambda s: s[0], lambda s: s[0], lambda s: s[0]), 1.0),
}


def bipartitions_three():
    got = sorted(tuple(map(tuple, cut)) for cut in lab.all_bipartitions(3))
    want = sorted([((0,), (1, 2)), ((0, 1), (2,)), ((0, 2), (1,))])
    return None if got == want else f"all_bipartitions(3) = {got}, ждали {want}"


def bipartitions_count():
    for n, want in ((2, 1), (4, 7), (5, 15)):
        cuts = lab.all_bipartitions(n)
        if len(cuts) != want:
            return f"для {n} узлов разрезов {len(cuts)}, а должно быть 2^(n−1) − 1 = {want}"
        seen = set()
        for part, rest in cuts:
            if not part or not rest or sorted(part + rest) != list(range(n)) or 0 not in part:
                return f"неправильный разрез {part} | {rest}: обе части непустые, вместе все узлы, узел 0 в первой"
            seen.add(tuple(part))
        if len(seen) != want:
            return "один и тот же разрез встречается дважды"
    return None


def lesson_values():
    for name, (gates, want) in LESSON_NETWORKS.items():
        got = lab.integration(gates)
        if not close(got, want, 1e-9):
            return f"сеть «{name}»: {got:.3f} бита, в уроке {want}"
    return None


def and_ring_value():
    gates = (lambda s: s[1] & s[2], lambda s: s[0] & s[2], lambda s: s[0] & s[1])
    got = lab.integration(gates)
    return None if abs(got - 1.561) < 0.001 else f"кольцо И: {got:.3f} бита, в уроке 1,561"


def never_negative():
    gates = (lambda s: s[0] | s[1], lambda s: s[1], lambda s: s[2] ^ s[0], lambda s: s[3] & s[2])
    for cut in lab.all_bipartitions(4):
        loss = lab.lost_when_cut(gates, cut)
        if loss < -1e-12:
            return f"разрез {cut}: потеря {loss:.4f} меньше нуля"
    return None


def four_node_ring():
    ring = (lambda s: s[3], lambda s: s[0], lambda s: s[1], lambda s: s[2])
    got = lab.integration(ring)
    return None if close(got, 2.0, 1e-9) else f"кольцо из четырёх копирующих узлов: {got:.3f}, ждали 2 бита (самый слабый разрез рвёт две связи)"


def two_islands():
    islands = (lambda s: s[1], lambda s: s[0], lambda s: s[3], lambda s: s[2])
    got = lab.integration(islands)
    return None if close(got, 0.0, 1e-9) else f"два отдельных острова 0↔1 и 2↔3: {got:.3f}, а разрез между ними ничего не теряет"


def relabel_invariant():
    ring = (lambda s: s[3], lambda s: s[0], lambda s: s[1], lambda s: s[2])
    shuffled = (lambda s: s[2], lambda s: s[3], lambda s: s[1], lambda s: s[0])
    a, b = lab.integration(ring), lab.integration(shuffled)
    return None if close(a, b, 1e-9) else f"то же кольцо с другими номерами узлов дало {b:.3f} вместо {a:.3f}"


checker.check("разрезы трёх узлов", "cuts of three nodes", bipartitions_three)
checker.check("число разрезов 2^(n−1) − 1, без повторов", "2^(n−1) − 1 cuts, no repeats", bipartitions_count)
checker.check("значения сетей из урока", "the lesson's network values", lesson_values)
checker.check("кольцо И: 1,561 бита", "AND ring: 1.561 bits", and_ring_value)
checker.check("потеря не бывает отрицательной", "a loss is never negative", never_negative)
checker.check("кольцо из четырёх узлов", "a four-node ring", four_node_ring)
checker.check("два острова не интегрированы", "two islands are not integrated", two_islands)
checker.check("номера узлов не важны", "node labels do not matter", relabel_invariant)
checker.finish()
