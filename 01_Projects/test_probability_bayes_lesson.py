"""The Bayes lesson: its numbers, program and lab agree. / Урок о Байесе: числа, программа и тренажёр согласованы."""
from __future__ import annotations

import contextlib
import io
import re
from fractions import Fraction
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LESSON = ROOT / "02_Areas" / "Mathematics" / "lessons" / "probability_and_bayes.md"
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


def test_letter_counts_in_the_text() -> None:
    _, program = _run_program(ENGLISH)
    assert len(program["text"]) == 49
    assert program["letters"]["h"] == 4 and program["letters"]["t"] == 8 and program["pairs"]["t", "h"] == 4
    assert 5.5 < 0.5 / (4 / 49) < 6.5, "raised the probability sixfold"
    # The exercise: chance_after("a", "t") differs from chance("t").
    assert program["chance_after"]("a", "t") > program["chance"]("t")


def test_worked_example_in_exact_numbers() -> None:
    prior, hit, alarm = Fraction(1, 100), Fraction(99, 100), Fraction(5, 100)
    sick, false_alarms = 1000 * prior * hit, 1000 * (1 - prior) * alarm
    assert float(sick) == 9.9 and float(false_alarms) == 49.5 and float(sick + false_alarms) == 59.4
    first = sick / (sick + false_alarms)
    assert round(float(first), 3) == 0.167
    second = first * hit / (first * hit + (1 - first) * alarm)
    assert round(float(second), 3) == 0.798
    assert float(prior * hit / (prior * hit + (1 - prior) * Fraction(1, 100))) == 0.5
    for number in ("9,9", "49,5", "59,4", "0,167", "0,798"):
        assert number in RUSSIAN
    for number in ("9.9", "49.5", "59.4", "0.167", "0.798"):
        assert number in ENGLISH


def test_bayes_rule_holds_on_a_real_table() -> None:
    joint = {("a", "x"): Fraction(1, 8), ("a", "y"): Fraction(1, 4), ("b", "x"): Fraction(3, 8), ("b", "y"): Fraction(1, 4)}
    p_a = sum(v for (a, _), v in joint.items() if a == "a")
    p_x = sum(v for (_, b), v in joint.items() if b == "x")
    a_given_x = joint["a", "x"] / p_x
    x_given_a = joint["a", "x"] / p_a
    assert a_given_x == x_given_a * p_a / p_x
    assert a_given_x != p_a, "these events are not independent"


def test_quiz_has_the_right_answer() -> None:
    for section, options, answer in ((RUSSIAN, "### Варианты", "### Ответ"), (ENGLISH, "### Options", "### Answer")):
        block = section.split(options, 1)[1].split("###", 1)[0]
        lines = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(lines) == 3 and section.split(answer, 1)[1].split("###", 1)[0].strip() == "2"
        assert max(map(len, lines)) < 1.3 * min(map(len, lines))


def test_lab_uses_the_lessons_numbers_and_is_wired_in() -> None:
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (APP / "L10n.swift").read_text(encoding="utf-8")
    model = (APP / "BayesTown.swift").read_text(encoding="utf-8")
    assert 'subject == .mathematics, moduleResource == "probability_and_bayes"' in views and "BayesTownLab()" in views
    for default in ("diseaseRate = 0.01", "hitRate = 0.99", "falseAlarmRate = 0.05"):
        assert default in model
    keys = set(re.findall(r'text\("(lab\.town\.[A-Za-z0-9]+)"\)', views))
    assert keys
    for key in keys | {"lab.town.raised"}:
        assert re.search(rf'"{re.escape(key)}": \("[^"]+", "[^"]+"\)', strings), key
    assert len(re.findall(r'^\s*"lab\.town\.title":', strings, re.M)) == 1
    roadmap = (ROOT / "02_Areas" / "Mathematics" / "curriculum.md").read_text(encoding="utf-8")
    assert "lesson:probability_and_bayes" in roadmap.split("## Продвинутый уровень / Advanced", 1)[1]
    assert "verify_bayes_town.swift" in (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    for link in ("introductory-statistics-2e", "chapter_preliminaries/probability", "Base_rate_fallacy"):
        assert link in SOURCES
