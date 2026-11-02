"""The cross-entropy lesson: its numbers, program, proof and lab agree. / Урок о кросс-энтропии: числа, программа, доказательство и тренажёр согласованы."""
from __future__ import annotations

import contextlib
import io
import itertools
import math
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LESSON = ROOT / "02_Areas" / "Mathematics" / "lessons" / "information_and_cross_entropy.md"
APP = ROOT / "macOS" / "ColiDev" / "App"
TEXT = LESSON.read_text(encoding="utf-8")
RUSSIAN = TEXT.split("## Русский", 1)[1].split("## English", 1)[0]
ENGLISH = TEXT.split("## English", 1)[1].split("## Sources", 1)[0]
SOURCES = TEXT.split("## Sources", 1)[1]


def _run_program(section: str) -> tuple[str, dict]:
    code = re.search(r"```python\n(.*?)```", section, re.S).group(1)
    namespace: dict = {}
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        exec(code, namespace)
    return output.getvalue(), namespace


def _entropy(p: list[float]) -> float:
    return -sum(a * math.log2(a) for a in p if a > 0)


def _cross(p: list[float], q: list[float]) -> float:
    return -sum(a * math.log2(b) for a, b in zip(p, q) if a > 0)


def test_program_prints_what_the_lesson_says_in_both_languages() -> None:
    expected = ["alphabet 13", "uniform 3.7", "letters 3.341", "pairs 2.442"]
    for section in (RUSSIAN, ENGLISH):
        output, _ = _run_program(section)
        assert output.strip().split("\n") == expected
        printed = re.search(r"```text\n(.*?)```", section, re.S).group(1).strip().split("\n")
        assert printed == expected
    assert "3,341" in RUSSIAN and "2,442" in RUSSIAN and "3.341" in ENGLISH and "2.442" in ENGLISH
    assert abs(math.log2(13) - 3.7) < 0.001


def test_each_better_model_is_less_surprised() -> None:
    _, program = _run_program(ENGLISH)
    errors = [program["cross_entropy"](program[name], program["test"]) for name in ("uniform", "by_letter", "by_pair")]
    assert errors[0] > errors[1] > errors[2]
    # The exercise of the lesson has a real answer: the pair model does better on the text it counted.
    assert program["cross_entropy"](program["by_pair"], program["train"]) < errors[2] + 0.1


def test_worked_numbers() -> None:
    p = [1 / 2, 1 / 4, 1 / 8, 1 / 8]
    assert _entropy(p) == 1.75
    assert _cross(p, [1 / 4] * 4) == 2
    assert _cross(p, [1 / 8, 1 / 8, 1 / 4, 1 / 2]) == 2.625
    assert _cross(p, p) == 1.75
    # The prefix code of the lesson: its mean length is the entropy.
    codes = ["0", "10", "110", "111"]
    assert sum(a * len(c) for a, c in zip(p, codes)) == 1.75
    assert not any(a != b and b.startswith(a) for a, b in itertools.product(codes, repeat=2))
    assert "1,75" in RUSSIAN and "2,625" in RUSSIAN and "1.75" in ENGLISH and "2.625" in ENGLISH
    assert round(1 / math.log(2), 2) == 1.44 and "1,44" in RUSSIAN and "1.44" in ENGLISH


def test_the_proof_holds_cross_entropy_is_never_below_entropy() -> None:
    p = [0.6, 0.3, 0.1]
    grid = [i / 40 for i in range(1, 40)]
    for a, b in itertools.product(grid, repeat=2):
        c = 1 - a - b
        if c <= 0:
            continue
        q = [a, b, c]
        assert _cross(p, q) >= _entropy(p) - 1e-12
        # The inequality step of the proof, ln t ≤ t − 1.
        assert all(math.log(y / x) <= y / x - 1 + 1e-12 for x, y in zip(p, q))
    for section in (RUSSIAN, ENGLISH):
        assert "ln t ≤ t − 1" in section


def test_quiz_answer_is_the_true_minimum() -> None:
    for section, options, answer in ((RUSSIAN, "### Варианты", "### Ответ"), (ENGLISH, "### Options", "### Answer")):
        block = section.split(options, 1)[1].split("###", 1)[0]
        lines = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(lines) == 3
        assert section.split(answer, 1)[1].split("###", 1)[0].strip() == "3"
        assert "`P`" in lines[2]
        assert max(map(len, lines)) < 1.3 * min(map(len, lines))


def test_sources_are_ones_the_lesson_can_stand_on() -> None:
    for link in ("10.1002/j.1538-7305.1948.tb01338.x", "d2l.ai/chapter_appendix-mathematics-for-deep-learning/information-theory",
                 "wikipedia.org/wiki/Cross-entropy", "source_coding_theorem"):
        assert link in SOURCES


def test_lab_is_wired_in_and_its_texts_exist() -> None:
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (APP / "L10n.swift").read_text(encoding="utf-8")
    model = (APP / "CrossEntropyBowl.swift").read_text(encoding="utf-8")
    assert 'subject == .mathematics, moduleResource == "information_and_cross_entropy"' in views
    assert "CrossEntropyBowlLab()" in views
    assert "[[0.6, 0.3, 0.1]" in model
    keys = set(re.findall(r'text\("(lab\.bowl\.[A-Za-z0-9]+)"\)', views))
    assert keys
    for key in keys | {"lab.bowl.axis", "lab.bowl.bottom"}:
        assert re.search(rf'"{re.escape(key)}": \("[^"]+", "[^"]+"\)', strings), key
    assert len(re.findall(r'^\s*"lab\.bowl\.title":', strings, re.M)) == 1
    roadmap = (ROOT / "02_Areas" / "Mathematics" / "curriculum.md").read_text(encoding="utf-8")
    assert "lesson:information_and_cross_entropy" in roadmap.split("## Продвинутый уровень / Advanced", 1)[1]
    workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    assert "verify_cross_entropy_bowl.swift" in workflow
