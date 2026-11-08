"""Проверки заданий «Собери и проверь сам» / Tests for the "build and check it yourself" labs.

Для каждой заготовки: проверка не проходит на пустой заготовке, проходит на эталонном решении и
ловит типичную ошибку. Эталон вставляется вместо строк `raise NotImplementedError("…")`.
Эталоны лежат здесь, а не рядом с заготовками, чтобы их не видеть во время работы.
For each blank: the check fails on the blank, passes on the reference solution and catches a
typical mistake. References replace the `raise NotImplementedError("…")` lines.
"""

from __future__ import annotations

import subprocess
import sys
import textwrap
from pathlib import Path

import pytest

LABS = Path(__file__).resolve().parent / "creator_labs"

SOLUTIONS = {
    "attention": {
        "softmax": """
            top = max(scores)
            powers = [math.exp(s - top) for s in scores]
            total = sum(powers)
            return [p / total for p in powers]
        """,
        "attention": """
            weights, outputs = [], []
            for t, q in enumerate(queries):
                visible = list(range(t + 1)) if causal else list(range(len(keys)))
                w = softmax([dot(q, keys[j]) / math.sqrt(len(q)) for j in visible])
                weights.append(w)
                outputs.append([sum(wi * values[j][k] for wi, j in zip(w, visible)) for k in range(len(values[0]))])
            return weights, outputs
        """,
        "softmax_backward": """
            mean = sum(w * g for w, g in zip(weights, upstream))
            return [w * (g - mean) for w, g in zip(weights, upstream)]
        """,
    },
    "autograd": {
        "__mul__ push": """
            self.grad += other.data * result.grad
            other.grad += self.data * result.grad
        """,
        "tanh push": """
            self.grad += (1 - result.data ** 2) * result.grad
        """,
        "backward": """
            order, seen = [], set()

            def visit(node):
                if node not in seen:
                    seen.add(node)
                    for parent in node.parents:
                        visit(parent)
                    order.append(node)

            visit(self)
            self.grad = 1.0
            for node in reversed(order):
                node.push()
        """,
    },
    "tokenizer": {
        "count_pairs": """
            counts = {}
            for pair in zip(ids, ids[1:]):
                counts[pair] = counts.get(pair, 0) + 1
            return counts
        """,
        "merge": """
            result, i = [], 0
            while i < len(ids):
                if i + 1 < len(ids) and (ids[i], ids[i + 1]) == pair:
                    result.append(new)
                    i += 2
                else:
                    result.append(ids[i])
                    i += 1
            return result
        """,
        "encode": """
            ids = list(text.encode("utf-8"))
            while len(ids) > 1:
                pairs = count_pairs(ids)
                pair = min(pairs, key=lambda p: merges.get(p, float("inf")))
                if pair not in merges:
                    break
                ids = merge(ids, pair, merges[pair])
            return ids
        """,
    },
    "policy_gradient": {
        "grad_log_prob": """
            p = softmax(logits)
            return [(1.0 if i == action else 0.0) - p[i] for i in range(len(logits))]
        """,
        "reinforce_update": """
            grad = grad_log_prob(logits, action)
            advantage = reward - baseline
            return [x + rate * advantage * g for x, g in zip(logits, grad)]
        """,
    },
    "lora": {
        "lora_forward": """
            low = matvec(A, x)
            return [wx + scale * bl for wx, bl in zip(matvec(W, x), matvec(B, low))]
        """,
        "lora_grads": """
            low = matvec(A, x)
            back = [sum(upstream[i] * B[i][k] for i in range(len(B))) for k in range(len(A))]
            dA = [[scale * back[k] * xj for xj in x] for k in range(len(A))]
            dB = [[scale * upstream[i] * low[k] for k in range(len(A))] for i in range(len(B))]
            return dA, dB
        """,
        "merged_weights": """
            rank = len(A)
            return [[W[i][j] + scale * sum(B[i][k] * A[k][j] for k in range(rank)) for j in range(len(W[0]))] for i in range(len(W))]
        """,
    },
    "probe": {
        "loss_and_grad": """
            count = len(labels)
            grad_w, grad_b, loss = [0.0] * len(weights), 0.0, 0.0
            for x, y in zip(features, labels):
                p = sigmoid(sum(w * v for w, v in zip(weights, x)) + bias)
                p = min(max(p, 1e-12), 1 - 1e-12)
                loss -= y * math.log(p) + (1 - y) * math.log(1 - p)
                for j, v in enumerate(x):
                    grad_w[j] += (p - y) * v
                grad_b += p - y
            return loss / count, [g / count for g in grad_w], grad_b / count
        """,
    },
    "phi": {
        "all_bipartitions": """
            cuts = []
            for size in range(0, n - 1):
                for chosen in itertools.combinations(range(1, n), size):
                    part = (0,) + chosen
                    cuts.append((part, tuple(i for i in range(n) if i not in part)))
            return cuts
        """,
        "lost_when_cut": """
            n = len(gates)
            total, every = 0.0, states(n)
            for state in every:
                real = next_state(gates, state)
                chance = 1.0
                for part in cut:
                    chance *= part_distribution(gates, part, state).get(tuple(real[i] for i in part), 0.0)
                total += math.log2(1 / chance) if chance > 0 else float(n)
            return total / len(every)
        """,
    },
}

# Типичные ошибки: (лаборатория, функция, неверное тело). / Typical mistakes.
MISTAKES = [
    ("attention", "softmax", "return [math.exp(s) / sum(math.exp(t) for t in scores) for s in scores]"),
    ("attention", "attention", SOLUTIONS["attention"]["attention"].replace(" / math.sqrt(len(q))", "")),
    ("attention", "attention", SOLUTIONS["attention"]["attention"].replace("if causal else", "if False else")),
    ("attention", "softmax_backward", "return [w * g for w, g in zip(weights, upstream)]"),
    ("autograd", "__mul__ push", "self.grad = other.data * result.grad\nother.grad = self.data * result.grad"),
    ("autograd", "tanh push", "self.grad += (1 - self.data ** 2) * result.grad"),
    ("autograd", "backward", SOLUTIONS["autograd"]["backward"].replace("if node not in seen:", "if True:")),
    ("tokenizer", "merge", SOLUTIONS["tokenizer"]["merge"].replace("i += 2", "i += 1")),
    ("tokenizer", "encode", "return list(text.encode('utf-8'))"),
    ("policy_gradient", "grad_log_prob", "p = softmax(logits)\nreturn [p[i] - (1.0 if i == action else 0.0) for i in range(len(logits))]"),
    ("policy_gradient", "reinforce_update", "grad = grad_log_prob(logits, action)\nreturn [x + rate * reward * g for x, g in zip(logits, grad)]"),
    ("lora", "lora_grads", SOLUTIONS["lora"]["lora_grads"].replace("scale * ", "")),
    ("lora", "merged_weights", "return [row[:] for row in W]"),
    ("probe", "loss_and_grad", SOLUTIONS["probe"]["loss_and_grad"].replace("[g / count for g in grad_w], grad_b / count", "grad_w, grad_b")),
    ("phi", "all_bipartitions", "return [((i,), tuple(j for j in range(n) if j != i)) for i in range(n)]"),
    ("phi", "lost_when_cut", SOLUTIONS["phi"]["lost_when_cut"].replace("for part in cut:", "for part in cut[:1]:")),
]

CHECKS = {
    "attention": "check_attention_mechanism.py",
    "autograd": "check_autograd_engine.py",
    "tokenizer": "check_tokenizer_bpe.py",
    "policy_gradient": "check_rl_policy_gradient.py",
    "lora": "check_finetuning_and_lora.py",
    "probe": "check_interp_probes.py",
    "phi": "check_consciousness_integrated_information.py",
}


def fill(lab: str, bodies: dict[str, str]) -> str:
    text = (LABS / f"{lab}_blank.py").read_text(encoding="utf-8")
    for marker, body in bodies.items():
        needle = f'raise NotImplementedError("{marker}")'
        lines = text.split("\n")
        hits = [i for i, line in enumerate(lines) if line.strip() == needle]
        assert len(hits) == 1, f"{lab}: marker {marker!r} found {len(hits)} times"
        indent = lines[hits[0]][: len(lines[hits[0]]) - len(lines[hits[0]].lstrip())]
        code = textwrap.dedent(body).strip("\n").split("\n")
        lines[hits[0] : hits[0] + 1] = [indent + line if line.strip() else "" for line in code]
        text = "\n".join(lines)
    return text


def run_check(lab: str, source: Path) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(LABS / CHECKS[lab]), str(source)],
        capture_output=True,
        text=True,
        timeout=120,
    )


def test_every_blank_has_a_check_and_a_reference() -> None:
    blanks = {path.name[: -len("_blank.py")] for path in LABS.glob("*_blank.py")}
    assert blanks == set(SOLUTIONS) == set(CHECKS)
    for lab, bodies in SOLUTIONS.items():
        text = (LABS / f"{lab}_blank.py").read_text(encoding="utf-8")
        markers = {line.strip()[len('raise NotImplementedError("') : -2] for line in text.splitlines() if "raise NotImplementedError(" in line}
        assert markers == set(bodies), lab


@pytest.mark.parametrize("lab", sorted(SOLUTIONS))
def test_blank_fails_the_check(lab: str) -> None:
    result = run_check(lab, LABS / f"{lab}_blank.py")
    assert result.returncode == 1, result.stdout + result.stderr
    assert "не реализовано / not implemented" in result.stdout


@pytest.mark.parametrize("lab", sorted(SOLUTIONS))
def test_reference_passes_the_check(lab: str, tmp_path: Path) -> None:
    source = tmp_path / f"{lab}_solution.py"
    source.write_text(fill(lab, SOLUTIONS[lab]), encoding="utf-8")
    result = run_check(lab, source)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "✗" not in result.stdout


@pytest.mark.parametrize("lab,marker,wrong", MISTAKES, ids=[f"{lab}-{marker}-{i}" for i, (lab, marker, _) in enumerate(MISTAKES)])
def test_typical_mistake_is_caught(lab: str, marker: str, wrong: str, tmp_path: Path) -> None:
    bodies = dict(SOLUTIONS[lab])
    bodies[marker] = wrong
    source = tmp_path / f"{lab}_mistake.py"
    source.write_text(fill(lab, bodies), encoding="utf-8")
    result = run_check(lab, source)
    assert result.returncode == 1, f"the check missed a mistake in {marker}:\n{result.stdout}"
    assert "✗" in result.stdout


def test_checks_run_on_the_macs_plain_python() -> None:
    """Владелец запускает проверки системным python3 3.9: без синтаксиса новее. / Plain python3 3.9 syntax."""
    import ast

    for path in LABS.glob("*.py"):
        ast.parse(path.read_text(encoding="utf-8"), feature_version=(3, 9))


LESSON_OF = {
    "attention": "attention_mechanism",
    "autograd": "autograd_engine",
    "tokenizer": "tokenizer_bpe",
    "policy_gradient": "rl_policy_gradient",
    "lora": "finetuning_and_lora",
    "probe": "interp_probes",
    "phi": "consciousness_integrated_information",
}


@pytest.mark.parametrize("lab", sorted(LESSON_OF))
def test_lesson_points_to_its_lab_inside_the_practice_section(lab: str) -> None:
    lesson = (LABS.parent.parent / "02_Areas" / "Programming" / "lessons" / f"{LESSON_OF[lab]}.md").read_text(encoding="utf-8")
    for start, block, end in (
        ("### Исследуй и потренируйся", "**Собери и проверь сам.**", "### Вопрос"),
        ("### Explore and practise", "**Build and check it yourself.**", "### Question"),
    ):
        section = lesson[lesson.index(start) : lesson.index(end, lesson.index(start))]
        assert block in section, f"{lab}: the block must sit in the practice section the app shows"
        assert f"python3 {CHECKS[lab]}" in section and f"`{lab}_blank.py`" in section
        assert "cp -Rn " in section, "copying must never overwrite the learner's files"
