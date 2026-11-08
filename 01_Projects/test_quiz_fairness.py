"""Честные вопросы: правильный ответ нельзя угадать по виду / Fair questions: the right option must not give itself away.

Аудит курса (project-plan/COURSE_AUDIT_RU_EN.md) нашёл две подсказки: правильный вариант заметно
длиннее остальных, и расчёт записан только в нём. Эти проверки не дают подсказкам вернуться.
Английский и зоология в аудит не входили и здесь не проверяются.
The course audit found two tells: the correct option is clearly the longest, and only it shows a
calculation. These checks keep both tells out. English and Zoology were outside the audit.
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1] / "02_Areas"
OUT_OF_AUDIT = {"English", "Zoology"}
BLOCK = re.compile(
    r"### (Вопрос|Question)\n\n(?P<question>.*?)\n\n### (Варианты|Options)\n\n(?P<options>.*?)\n\n### (Ответ|Answer)\n\n(?P<answer>\d+)",
    re.S,
)
# Число, знак действия, число: «8 − 2», «4 · 4», «= 3», «(1,5 ×».
# Number, operator, number: "8 − 2", "4 · 4", "= 3", "(1.5 ×".
CALCULATION = re.compile(r"\d\s*[=≈×·/*+−-]\s*\d|\(\s*[\d,.]+\s*[×·*/+−-]")
MIN_LENGTH_FOR_LENGTH_TELL = 20
LENGTH_RATIO = 0.85


def questions():
    for lesson in sorted(ROOT.glob("*/lessons/*.md")):
        if lesson.parts[-3] in OUT_OF_AUDIT:
            continue
        text = lesson.read_text(encoding="utf-8")
        for match in BLOCK.finditer(text):
            options = [line[2:].strip() for line in match.group("options").splitlines() if line.startswith("- ")]
            yield lesson.relative_to(ROOT).as_posix(), match.group(1), options, int(match.group("answer")) - 1


ALL_QUESTIONS = list(questions())


def test_questions_were_found() -> None:
    assert len(ALL_QUESTIONS) >= 100


@pytest.mark.parametrize("lesson,language,options,answer", ALL_QUESTIONS)
def test_correct_option_is_not_the_obviously_longest(lesson, language, options, answer) -> None:
    assert 0 <= answer < len(options), f"{lesson} [{language}]: answer number out of range"
    correct = len(options[answer])
    if correct < MIN_LENGTH_FOR_LENGTH_TELL:
        return
    others = [len(option) for index, option in enumerate(options) if index != answer]
    assert max(others) >= LENGTH_RATIO * correct, (
        f"{lesson} [{language}]: the correct option ({correct} chars) is much longer than the rest {others}"
    )


@pytest.mark.parametrize("lesson,language,options,answer", ALL_QUESTIONS)
def test_calculation_is_not_only_in_the_correct_option(lesson, language, options, answer) -> None:
    if not CALCULATION.search(options[answer]):
        return
    assert any(CALCULATION.search(option) for index, option in enumerate(options) if index != answer), (
        f"{lesson} [{language}]: only the correct option shows a calculation"
    )
