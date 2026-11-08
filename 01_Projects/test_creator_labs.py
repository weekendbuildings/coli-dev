"""Проверки заданий «Собери и проверь сам» / Tests for the "build and check it yourself" labs.

Для каждой заготовки: проверка не проходит на пустой заготовке, проходит на эталонном решении и
ловит типичную ошибку. Эталон вставляется вместо строк `raise NotImplementedError("…")`.
Эталоны лежат здесь, а не рядом с заготовками, чтобы их не видеть во время работы.
For each blank: the check fails on the blank, passes on the reference solution and catches a
typical mistake. References replace the `raise NotImplementedError("…")` lines.
"""

from __future__ import annotations

import json
import os
import re
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


RESULTS = {"path": None}


@pytest.fixture(autouse=True)
def results_file(tmp_path: Path):
    """Тесты пишут итоги во временный файл, а не рядом с проверками в репозитории.
    Tests write results to a temporary file, never next to the checks in the repository."""
    RESULTS["path"] = tmp_path / "results.json"
    yield RESULTS["path"]
    RESULTS["path"] = None


def run_check(lab: str, source: Path, python: str = sys.executable) -> subprocess.CompletedProcess:
    env = dict(os.environ)
    env["CREATOR_LABS_RESULTS"] = str(RESULTS["path"])
    return subprocess.run(
        [python, str(LABS / CHECKS[lab]), str(source)],
        capture_output=True,
        text=True,
        timeout=120,
        env=env,
    )


def recorded_runs(path: Path) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    assert data["format"] == "creator-labs-results" and data["version"] == 1
    return data["runs"]


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


def test_every_run_appends_its_result_for_the_progress_screen(results_file: Path, tmp_path: Path) -> None:
    """Итог каждой проверки дописывается в `.results.json`: его читает экран «Прогресс Творца».
    Every check run appends its result to `.results.json`, which the Creator progress screen reads."""
    run_check("tokenizer", LABS / "tokenizer_blank.py")
    source = tmp_path / "tokenizer_solution.py"
    source.write_text(fill("tokenizer", SOLUTIONS["tokenizer"]), encoding="utf-8")
    run_check("tokenizer", source)
    first, second = recorded_runs(results_file)
    assert first["check"] == second["check"] == "check_tokenizer_bpe.py"
    assert first["lesson"] == second["lesson"] == "tokenizer_bpe"
    assert first["passed"] == 0 and first["total"] > 0
    assert second["passed"] == second["total"] == first["total"]
    for run in (first, second):
        assert re.fullmatch(r"\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ", run["at"]), run["at"]


@pytest.mark.parametrize("lab", sorted(CHECKS))
def test_each_check_names_its_lesson_in_the_results(lab: str, results_file: Path) -> None:
    run_check(lab, LABS / f"{lab}_blank.py")
    (run,) = recorded_runs(results_file)
    assert run["lesson"] == LESSON_OF[lab] and run["passed"] < run["total"]


def test_results_survive_a_broken_file_and_keep_only_the_latest_runs(tmp_path: Path) -> None:
    sys.path.insert(0, str(LABS))
    try:
        import _checklib
    finally:
        sys.path.remove(str(LABS))
    path = tmp_path / ".results.json"
    path.write_text("{not json", encoding="utf-8")
    _checklib.record_result("check_x.py", 1, 2, path=path, now=0)
    assert recorded_runs(path) == [{"check": "check_x.py", "lesson": "x", "passed": 1, "total": 2, "at": "1970-01-01T00:00:00Z"}]
    for index in range(_checklib.RESULTS_LIMIT + 5):
        _checklib.record_result("check_x.py", index, index, path=path, now=index)
    runs = recorded_runs(path)
    assert len(runs) == _checklib.RESULTS_LIMIT and runs[-1]["passed"] == _checklib.RESULTS_LIMIT + 4
    # A folder where the file cannot be written: the check still finishes. / Папка без записи: проверка всё равно идёт дальше.
    assert _checklib.record_result("check_x.py", 1, 1, path=tmp_path / "missing" / "r.json")["passed"] == 1
    # By default the file lies next to the checks: ~/ai-path/creator_labs/.results.json after copying.
    # По умолчанию файл лежит рядом с проверками.
    saved = os.environ.pop("CREATOR_LABS_RESULTS", None)
    try:
        assert _checklib.results_path() == (LABS / ".results.json").resolve()
    finally:
        if saved is not None:
            os.environ["CREATOR_LABS_RESULTS"] = saved


@pytest.mark.skipif(not Path("/usr/bin/python3").exists(), reason="system python3 of macOS")
def test_results_are_written_by_the_macs_system_python(results_file: Path) -> None:
    """Владелец запускает проверки системным python3 3.9. / The owner runs the checks with the system python3 3.9."""
    result = run_check("autograd", LABS / "autograd_blank.py", python="/usr/bin/python3")
    assert result.returncode == 1, result.stdout + result.stderr
    (run,) = recorded_runs(results_file)
    assert run["lesson"] == "autograd_engine"


def test_progress_screen_knows_every_lab_and_reads_the_results_file() -> None:
    """Экран «Прогресс Творца» знает все задания и читает файл итогов рядом с проверками.
    The Creator progress screen knows every lab and reads the results file next to the checks."""
    app = LABS.parent.parent / "macOS" / "ColiDev" / "App"
    logic = (app / "CreatorProgress.swift").read_text(encoding="utf-8")
    listed = logic.split("static let lessons: [String] = [", 1)[1].split("]", 1)[0]
    assert sorted(re.findall(r'"([a-z0-9_]+)"', listed)) == sorted(LESSON_OF.values())
    assert 'static let fileName = ".results.json"' in logic
    assert '.appendingPathComponent("ai-path", isDirectory: true)' in logic
    assert '.appendingPathComponent("creator_labs", isDirectory: true)' in logic
    view = (app / "CreatorProgressView.swift").read_text(encoding="utf-8")
    assert "reloadLabsIfChanged()" in view and "NSApplication.didBecomeActiveNotification" in view
    sidebar = (app / "ContentView.swift").read_text(encoding="utf-8").split("} detail: {", 1)[0]
    assert 'sidebarRow(.creatorProgress, L10n.text("nav.creatorProgress", store.language)' in sidebar
    # Skillbox topics have no "Ask Claude" that opens a website: a future in-app "Explain" plugs into `explain`.
    # У тем Skillbox нет «Спросить Claude», открывающей сайт: будущая «Объяснить» подключается через `explain`.
    assert "AskClaudePrompt" not in view and "NSWorkspace.shared.open" not in view
    assert "var explain: ((SkillboxItem, SkillboxCourse, SkillboxTrack) -> Void)? = nil" in view
    assert "if let explain {" in view
    assert "CreatorProgressView(openLesson: openPathLesson)" in (app / "ContentView.swift").read_text(encoding="utf-8")
    ignored = (LABS.parent.parent / ".gitignore").read_text(encoding="utf-8")
    assert "01_Projects/creator_labs/.results.json*" in ignored
