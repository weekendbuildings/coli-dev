"""The softmax lesson: its numbers, derivation, program and lab agree. / Урок о softmax: числа, вывод, программа и тренажёр согласованы."""
from __future__ import annotations

import contextlib
import io
import math
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LESSON = ROOT / "02_Areas" / "Programming" / "lessons" / "classification_and_softmax.md"
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


def test_program_prints_what_the_lesson_says_in_both_languages() -> None:
    for section in (RUSSIAN, ENGLISH):
        output, _ = _run_program(section)
        printed = re.search(r"```text\n(.*?)```", section, re.S).group(1).strip()
        assert output.strip() == printed
    assert abs(math.log(3) - 1.099) < 0.001


def test_worked_softmax_numbers() -> None:
    _, program = _run_program(ENGLISH)
    softmax = program["softmax"]
    q = softmax([2, 1, 0])
    assert [round(p, 3) for p in q] == [0.665, 0.245, 0.09]
    assert [round(p, 9) for p in softmax([3, 2, 1])] == [round(p, 9) for p in q]
    assert [round(p, 3) for p in softmax([4, 2, 0])] == [0.867, 0.117, 0.016]
    assert round(-math.log(q[0]), 3) == 0.408 and round(-math.log(q[2]), 3) == 2.408
    for number in ("0,665", "0,867", "0,408", "2,408", "1,099"):
        assert number in RUSSIAN
    for number in ("0.665", "0.867", "0.408", "2.408", "1.099"):
        assert number in ENGLISH


def test_gradient_is_q_minus_p_and_matches_a_numerical_slope() -> None:
    _, program = _run_program(ENGLISH)
    weights = [[0.3, -0.2, 0.1], [-0.5, 0.4, 0.2], [0.1, 0.1, -0.3]]
    exact = program["gradient"](weights)
    for k in range(3):
        for i in range(3):
            moved = [row[:] for row in weights]
            moved[k][i] += 1e-6
            numerical = (program["loss"](moved) - program["loss"](weights)) / 1e-6
            assert math.isclose(numerical, exact[k][i], abs_tol=1e-5)
    for section in (RUSSIAN, ENGLISH):
        assert "∂L/∂zₖ = qₖ − pₖ" in section


def test_cross_entropy_does_not_saturate_like_squared_error() -> None:
    y, target = 0.01, 1
    squared = 2 * (y - target) * y * (1 - y)
    cross = y - target
    assert round(squared, 4) == -0.0196 and cross == -0.99
    assert 49 < cross / squared < 52
    assert "−0,0196" in RUSSIAN and "−0,99" in RUSSIAN and "−0.0196" in ENGLISH and "−0.99" in ENGLISH


def test_the_quiz_answer_has_the_true_signs() -> None:
    q, p = (0.8, 0.1, 0.1), (0, 1, 0)
    gradient = [a - b for a, b in zip(q, p)]
    assert [value > 0 for value in gradient] == [True, False, True]
    assert abs(sum(gradient)) < 1e-12
    for section, options, answer in ((RUSSIAN, "### Варианты", "### Ответ"), (ENGLISH, "### Options", "### Answer")):
        block = section.split(options, 1)[1].split("###", 1)[0]
        lines = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(lines) == 3 and lines[2].startswith("`(+")
        assert section.split(answer, 1)[1].split("###", 1)[0].strip() == "3"
        assert max(map(len, lines)) < 1.5 * min(map(len, lines))


def test_exercise_has_a_real_answer() -> None:
    _, program = _run_program(ENGLISH)
    weights = [[0.0] * 3 for _ in range(3)]
    steps = 0
    while program["loss"](weights) >= 0.1:
        gradient = program["gradient"](weights)
        weights = [[weights[k][i] - 3.0 * gradient[k][i] for i in range(3)] for k in range(3)]
        steps += 1
    assert 3 <= steps <= 40


def test_lab_uses_the_lessons_data_and_is_wired_in() -> None:
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (APP / "L10n.swift").read_text(encoding="utf-8")
    model = (APP / "SoftmaxClassifier.swift").read_text(encoding="utf-8")
    assert 'subject == .programming, moduleResource == "classification_and_softmax"' in views and "SoftmaxReliefLab()" in views
    _, program = _run_program(ENGLISH)
    for x1, x2, label in program["data"]:
        assert f"Sample(x1: {x1}, x2: {x2}, label: {label})" in model
    keys = set(re.findall(r'text\("(lab\.softmax\.[A-Za-z0-9]+)"\)', views))
    assert keys
    for key in keys | {"lab.softmax.axis"}:
        assert re.search(rf'"{re.escape(key)}": \("[^"]+", "[^"]+"\)', strings), key
    assert len(re.findall(r'^\s*"lab\.softmax\.title":', strings, re.M)) == 1
    roadmap = (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
    assert "lesson:classification_and_softmax" in roadmap.split("## Продвинутый уровень / Advanced", 1)[1]
    assert "verify_softmax_classifier.swift" in (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    for link in ("softmax-regression", "cs231n.github.io/linear-classify"):
        assert link in SOURCES
