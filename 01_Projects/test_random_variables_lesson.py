"""The sampling lesson: its numbers, program and lab agree. / Урок о выборке: числа, программа и тренажёр согласованы."""
from __future__ import annotations

import contextlib
import io
import math
import re
from fractions import Fraction
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LESSON = ROOT / "02_Areas" / "Mathematics" / "lessons" / "random_variables_and_sampling.md"
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


def test_die_numbers_are_exact() -> None:
    faces = [Fraction(n) for n in range(1, 7)]
    mean = sum(faces) / 6
    variance = sum((f - mean) ** 2 for f in faces) / 6
    assert mean == Fraction(7, 2) and variance == Fraction(35, 12)
    assert round(float(variance), 3) == 2.917 and round(math.sqrt(variance), 2) == 1.71
    assert "2,917" in RUSSIAN and "1,71" in RUSSIAN and "2.917" in ENGLISH and "1.71" in ENGLISH


def test_temperature_numbers_and_the_cold_and_hot_ends() -> None:
    _, program = _run_program(ENGLISH)
    softmax = program["softmax"]
    assert [round(p, 3) for p in softmax([2, 1, 0], 0.5)] == [0.867, 0.117, 0.016]
    assert [round(p, 3) for p in softmax([2, 1, 0], 2)] == [0.506, 0.307, 0.186]
    assert softmax([2, 1, 0], 0.01)[0] > 0.999, "a low temperature picks the most likely"
    hot = softmax([2, 1, 0], 100)
    assert max(hot) - min(hot) < 0.03, "a high temperature is close to uniform"


def test_sampling_follows_the_segments_of_the_lesson() -> None:
    _, program = _run_program(ENGLISH)
    counts = [0, 0, 0]
    for _ in range(30000):
        counts[program["sample"]([0.6, 0.3, 0.1])] += 1
    assert all(abs(c / 30000 - p) < 0.012 for c, p in zip(counts, (0.6, 0.3, 0.1)))
    # The worked point u = 0.75 lands in the second segment, [0.6, 0.9).
    assert 0.6 <= 0.75 < 0.9


def test_exercise_shows_cold_and_hot_writing() -> None:
    _, program = _run_program(ENGLISH)
    cold = program["write"](0.1)
    hot = program["write"](10)
    # Cold text sticks to the pairs of the phrase, and hot text breaks them far more often.
    pairs = program["pairs"]
    def unseen(text: str) -> int:
        return sum(pairs[a, b] == 0 for a, b in zip(text, text[1:]))
    assert unseen(cold) < unseen(hot)


def test_quiz_uses_the_true_law() -> None:
    assert math.isclose(1 / math.sqrt(400), 0.5 / math.sqrt(100))
    for section, options, answer in ((RUSSIAN, "### Варианты", "### Ответ"), (ENGLISH, "### Options", "### Answer")):
        block = section.split(options, 1)[1].split("###", 1)[0]
        lines = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(lines) == 3 and section.split(answer, 1)[1].split("###", 1)[0].strip() == "2"
        assert "400" in lines[1]
        assert max(map(len, lines)) < 1.3 * min(map(len, lines))


def test_lab_is_wired_in_and_its_texts_exist() -> None:
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (APP / "L10n.swift").read_text(encoding="utf-8")
    assert 'subject == .mathematics, moduleResource == "random_variables_and_sampling"' in views and "GaltonBoardLab()" in views
    keys = set(re.findall(r'text\("(lab\.galton\.[A-Za-z0-9]+)"\)', views))
    assert keys
    for key in keys:
        assert re.search(rf'"{re.escape(key)}": \("[^"]+", "[^"]+"\)', strings), key
    assert len(re.findall(r'^\s*"lab\.galton\.title":', strings, re.M)) == 1
    roadmap = (ROOT / "02_Areas" / "Mathematics" / "curriculum.md").read_text(encoding="utf-8")
    assert "lesson:random_variables_and_sampling" in roadmap.split("## Продвинутый уровень / Advanced", 1)[1]
    assert "verify_galton_board.swift" in (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    for link in ("4-2-mean-or-expected-value", "4-3-binomial-distribution", "chapter_preliminaries/probability", "Galton_board", "Softmax_function"):
        assert link in SOURCES
