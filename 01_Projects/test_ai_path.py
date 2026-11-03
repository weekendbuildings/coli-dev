"""The AI path screen, the plan and the curricula agree. / Экран пути ИИ, план и карты курсов согласованы."""
from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "macOS" / "ColiDev" / "App"
PATH_SOURCE = (APP / "AIPath.swift").read_text(encoding="utf-8")
STRINGS = (APP / "L10n.swift").read_text(encoding="utf-8")
PLAN = (ROOT / "project-plan" / "AI_PATH_RU_EN.md").read_text(encoding="utf-8")
FOLDERS = {"math": "Mathematics", "code": "Programming"}
LESSONS = re.findall(r'\b(math|code)\("([a-z0-9_]+)"\)', PATH_SOURCE)


def test_every_lesson_is_written_or_announced() -> None:
    assert len(LESSONS) == 69 and len({name for _, name in LESSONS}) == 69
    for kind, name in LESSONS:
        folder = ROOT / "02_Areas" / FOLDERS[kind]
        written = f"lesson:{name}" in (folder / "curriculum.md").read_text(encoding="utf-8")
        if written:
            assert (folder / "lessons" / f"{name}.md").exists(), name
        else:
            assert f'"path.lesson.{name}": ("' in STRINGS, name


def test_path_screen_follows_the_plan() -> None:
    for _, name in LESSONS:
        assert f"`{name}`" in PLAN, name
    for number in range(1, 27):
        assert f"AIPathStep(number: {number}, lessons:" in PATH_SOURCE
        assert f'"path.step{number}.title": ("' in STRINGS
        assert f'"path.step{number}.why": ("' in STRINGS
    assert "AIPathStep(number: 27" not in PATH_SOURCE


def test_five_stages_with_a_title_each() -> None:
    assert re.findall(r"AIPathStage\(number: (\d+), steps:", PATH_SOURCE) == ["1", "2", "3", "4", "5"]
    assert '"path.stageLabel": ("' in STRINGS
    for number in range(1, 6):
        assert f'"path.stage{number}.title": ("' in STRINGS
        assert f'"path.stage{number}.why": ("' in STRINGS
    for number in range(1, 6):
        assert f"Этап {number}." in PLAN


def test_path_opens_lessons_without_the_course_lock() -> None:
    view = (APP / "ContentView.swift").read_text(encoding="utf-8")
    opener = view.split("private func openPathLesson", 1)[1].split("\n    }\n", 1)[0]
    assert "selection = .courseLesson(lesson.subject, lesson.resource)" in opener
    assert "isAvailable" not in opener
    assert "AIPathView(openLesson: openPathLesson)" in view
    assert '.accessibilityIdentifier("sidebar.ai-path")' in view
