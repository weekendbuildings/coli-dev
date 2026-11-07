"""Строгая проверка: градиент политики / Strict check: policy gradient.

python3 01_Projects/creator_labs/check_rl_policy_gradient.py [твой_файл.py]
"""

import math

from _checklib import Checker, Rand, all_close, close, numeric_gradient, show

checker = Checker("Градиент политики", "Policy gradient")
lab = checker.load("policy_gradient_blank.py")
rand = Rand(13)


def log_prob(logits, action):
    top = max(logits)
    return logits[action] - top - math.log(sum(math.exp(x - top) for x in logits))


def matches_numeric():
    for _ in range(15):
        n = rand.below(4) + 2
        logits = [rand.uniform(-3, 3) for _ in range(n)]
        action = rand.below(n)
        want = numeric_gradient(lambda z: log_prob(z, action), logits)
        got = lab.grad_log_prob(logits, action)
        if not all_close(got, want, 1e-5):
            return f"logits {show(logits)}, действие {action}: градиент {show(got)}, численно {show(want)}"
    return None


def score_has_zero_mean():
    logits = [rand.uniform(-2, 2) for _ in range(4)]
    p = lab.softmax(logits)
    mean = [sum(p[a] * lab.grad_log_prob(logits, a)[i] for a in range(4)) for i in range(4)]
    return None if all(abs(m) < 1e-9 for m in mean) else f"среднее Σ π(a)·∇log π(a) = {show(mean, 6)}, а должно быть 0"


def baseline_keeps_expected_step():
    logits = [0.3, -0.4, 1.1]
    rewards = [1.0, 0.2, -0.5]
    p = lab.softmax(logits)

    def expected_step(baseline):
        step = [0.0] * 3
        for a in range(3):
            new = lab.reinforce_update(logits, a, rewards[a], baseline, 1.0)
            for i in range(3):
                step[i] += p[a] * (new[i] - logits[i])
        return step

    a, b = expected_step(0.0), expected_step(5.0)
    if not all_close(a, b, 1e-9):
        return f"средний шаг без базовой линии {show(a)}, с ней {show(b)}: базовая линия не должна менять среднее"
    return None


def zero_advantage_no_change():
    logits = [0.5, -1.0, 0.25]
    new = lab.reinforce_update(logits, 1, 2.0, 2.0, 0.3)
    if not all_close(new, logits, 1e-12):
        return "при награде, равной базовой линии, политика не должна меняться"
    if logits != [0.5, -1.0, 0.25]:
        return "reinforce_update изменил входной список"
    return None


def good_action_more_likely():
    logits = [0.0, 0.0, 0.0]
    before = lab.softmax(logits)[2]
    after = lab.softmax(lab.reinforce_update(logits, 2, 1.0, 0.0, 0.5))[2]
    if not after > before:
        return f"после хорошей награды вероятность действия 2 была {before:.3f}, стала {after:.3f}"
    after_bad = lab.softmax(lab.reinforce_update(logits, 2, -1.0, 0.0, 0.5))[2]
    return None if after_bad < before else "после плохой награды вероятность действия должна упасть"


def learns_bandit():
    finals = [lab.train_bandit([0.2, 1.0, 0.5], 1500, 0.1, True, seed)[1] for seed in range(5)]
    worst = min(finals)
    return None if worst > 0.9 else f"после 1500 шагов вероятность лучшего действия {show(finals, 3)}, нужна больше 0,9 во всех пяти запусках"


checker.check("градиент log π совпадает с численным", "grad log π matches the numerical one", matches_numeric)
checker.check("в среднем по политике градиент log π равен 0", "the score has zero mean under the policy", score_has_zero_mean)
checker.check("базовая линия не меняет средний шаг", "a baseline keeps the expected step", baseline_keeps_expected_step)
checker.check("нулевое преимущество ничего не меняет", "zero advantage changes nothing", zero_advantage_no_change)
checker.check("хорошая награда повышает вероятность", "a good reward raises the probability", good_action_more_likely)
checker.check("агент находит лучшее действие у бандита", "the agent finds the bandit's best action", learns_bandit)
checker.finish()
