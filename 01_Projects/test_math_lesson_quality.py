from __future__ import annotations

import math
import re
import statistics
from datetime import date
from pathlib import Path

import pytest

from curriculum_routes import _section_body


ROOT = Path(__file__).resolve().parents[1]
LESSONS = ROOT / "02_Areas" / "Mathematics" / "lessons"
MATH_LESSONS = sorted(LESSONS.glob("*.md"))
# CurriculumLessonDocument.load in LearningViews.swift shows only these headings; any other
# `### ...` section is silently dropped from the lesson screen.
DISPLAYED_HEADINGS = {
    "Русский": {
        "Цель", "Идея и механизм", "Исследуй и потренируйся", "Вопрос", "Варианты", "Ответ",
        "Разбор", "Границы модели", "Границы правила", "Границы вывода",
        "Границы и безопасный запуск", "Видео и наблюдение", "Простыми словами",
    },
    "English": {
        "Goal", "Idea and mechanism", "Explore and practise", "Explore and practice", "Question",
        "Options", "Answer", "Explanation", "Limits", "Limits of the inference",
        "Limits and safe execution", "Video and observation", "In plain words",
    },
}


def _language_section(markdown: str, language: str) -> str:
    return markdown.split(f"## {language}", 1)[1].split("\n## ", 1)[0]


def _choices(markdown: str, language: str) -> tuple[list[str], int]:
    options_heading, answer_heading = ("Варианты", "Ответ") if language == "Русский" else ("Options", "Answer")
    options = _section_body(markdown, language, options_heading) or ""
    answer = _section_body(markdown, language, answer_heading) or ""
    return [line.strip()[2:].strip() for line in options.splitlines() if line.strip().startswith("- ")], int(answer)


@pytest.mark.parametrize("lesson", MATH_LESSONS, ids=lambda path: path.stem)
def test_math_lessons_use_only_headings_the_app_displays(lesson: Path) -> None:
    markdown = lesson.read_text(encoding="utf-8")
    for language, allowed in DISPLAYED_HEADINGS.items():
        headings = re.findall(r"^### (.+?)\s*$", _language_section(markdown, language), re.MULTILINE)
        assert set(headings) <= allowed, f"{lesson.name} {language}: hidden sections {set(headings) - allowed}"


@pytest.mark.parametrize("lesson", MATH_LESSONS, ids=lambda path: path.stem)
def test_math_lessons_keep_bilingual_answer_keys_aligned(lesson: Path) -> None:
    markdown = lesson.read_text(encoding="utf-8")
    russian, russian_answer = _choices(markdown, "Русский")
    english, english_answer = _choices(markdown, "English")

    assert len(russian) == len(english) == 3 or len(russian) == len(english) == 2
    assert russian_answer == english_answer
    assert 1 <= russian_answer <= len(russian)


@pytest.mark.parametrize("lesson", MATH_LESSONS, ids=lambda path: path.stem)
def test_math_lesson_sources_match_the_cited_edition(lesson: Path) -> None:
    markdown = lesson.read_text(encoding="utf-8")
    frontmatter = markdown.split("---", 2)[1]
    checked = re.search(r"^source_checked:\s*(\S+)", frontmatter, re.MULTILINE)
    assert checked is not None
    date.fromisoformat(checked.group(1))

    sources = markdown.split("## Sources", 1)[1]
    for line in sources.splitlines():
        # A source labelled "2e" must not link to the first edition, which has a different licence.
        if re.search(r"\b2e\b", line):
            for slug in re.findall(r"openstax\.org/books/([a-z0-9-]+)/pages/", line):
                assert slug.endswith("-2e"), f"{lesson.name}: 2e label links to {slug}"
    assert "*(" not in sources, f"{lesson.name}: stray label in the Sources block"


def test_statistics_lesson_numbers_follow_the_median_of_halves_rule() -> None:
    data = [4, 5, 5, 6, 6, 20]
    q1, q3 = statistics.median(data[:3]), statistics.median(data[3:])
    assert (round(statistics.mean(data), 2), statistics.median(data), q1, q3) == (7.67, 5.5, 5, 6)
    assert (q1 - 1.5 * (q3 - q1), q3 + 1.5 * (q3 - q1)) == (3.5, 7.5)
    assert statistics.quantiles(data, n=4)[0::2] == [4.75, 9.5]

    markdown = (LESSONS / "descriptive_statistics_and_potential_outliers.md").read_text(encoding="utf-8")
    russian, english = _language_section(markdown, "Русский"), _language_section(markdown, "English")
    for value in ("7,67", "5,5", "3,5", "7,5", "4,75", "9,5"):
        assert value in russian
    for value in ("7.67", "5.5", "3.5", "7.5", "4.75", "9.5"):
        assert value in english


def test_worked_examples_do_not_reveal_the_check_answers() -> None:
    trigonometry = (LESSONS / "trigonometry_and_periodic_functions.md").read_text(encoding="utf-8")
    assert round(math.sin(7 * math.pi / 6), 12) == -0.5
    for language in ("Русский", "English"):
        theory = _section_body(trigonometry, language, "Идея и механизм" if language == "Русский" else "Idea and mechanism")
        assert "7π/6" in theory and "5π/6" not in theory

    intro = (LESSONS / "intro.md").read_text(encoding="utf-8")
    assert "y = −2x + 5" in intro and intro.count("y = 3x + 1") == 2

    geometry = (LESSONS / "geometry_area_perimeter.md").read_text(encoding="utf-8")
    assert math.hypot(9, 12) == 15 and 9 * 12 / 2 == 54
    for language, heading in (("Русский", "Исследуй и потренируйся"), ("English", "Explore and practise")):
        practice = _section_body(geometry, language, heading)
        assert "8 м" not in practice and "8 m" not in practice
