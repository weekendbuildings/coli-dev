"""Собери и проверь сам: градиент политики / Build and check it yourself: policy gradient (REINFORCE).

Урок: «Градиент политики» (rl_policy_gradient). Политика выбирает одно из действий с
вероятностями softmax(logits). Допиши grad_log_prob и reinforce_update. Проверка:
    python3 01_Projects/creator_labs/check_rl_policy_gradient.py
Lesson: rl_policy_gradient. The policy picks an action with probabilities softmax(logits).
Fill in grad_log_prob and reinforce_update.
"""

import math


def softmax(logits):
    top = max(logits)
    powers = [math.exp(x - top) for x in logits]
    total = sum(powers)
    return [p / total for p in powers]


def grad_log_prob(logits, action):
    """Градиент log π(action) по каждому logit. Выведи сам: log π(a) = logits[a] − log Σ exp(logits).
    Gradient of log π(action) with respect to each logit. Derive it from the line above.
    """
    raise NotImplementedError("grad_log_prob")


def reinforce_update(logits, action, reward, baseline, rate):
    """Один шаг REINFORCE: сдвинуть logits по градиенту log π(action), умноженному на
    преимущество (награда минус базовая линия) и на rate. Верни новый список, старый не меняй.
    One REINFORCE step: move logits along grad log π(action) times the advantage
    (reward minus baseline) times rate. Return a new list; do not modify the old one.
    """
    raise NotImplementedError("reinforce_update")


class Rand:
    def __init__(self, seed):
        self.state = seed * 2654435761 % 2**32 or 1

    def next(self):
        self.state = (1103515245 * self.state + 12345) % 2**31
        return self.state / 2**31


def train_bandit(mean_rewards, steps, rate, use_baseline, seed):
    """Готово. Многорукий бандит: награда действия это его среднее плюс шум.
    Done. A bandit: an action's reward is its mean plus noise. Returns the final probabilities.
    """
    rand = Rand(seed)
    logits = [0.0] * len(mean_rewards)
    baseline = 0.0
    for _ in range(steps):
        p = softmax(logits)
        pick, total = rand.next(), 0.0
        action = len(p) - 1
        for i, value in enumerate(p):
            total += value
            if pick < total:
                action = i
                break
        reward = mean_rewards[action] + (rand.next() - 0.5)
        logits = reinforce_update(logits, action, reward, baseline if use_baseline else 0.0, rate)
        baseline += 0.05 * (reward - baseline)
    return softmax(logits)
