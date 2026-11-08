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
    assert len(LESSONS) == 74 and len({name for _, name in LESSONS}) == 74
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


MODULE_STEPS = {
    1: [1, 2], 2: [3, 4, 5, 6], 3: [7, 8, 9], 4: [10, 11, 12], 5: [13, 14],
    6: [15, 16], 7: [17, 18], 8: [19, 20, 21, 22], 9: [23, 24, 25, 26], 10: [],
}
MODULE_TITLES_RU = [
    "Python", "Математика для ИИ", "Машинное обучение и нейросети", "Своя языковая модель",
    "Улучшение моделей (RL, дообучение, RLHF)", "Применение (RAG, агенты, оценка)",
    "Внутри модели (интерпретируемость, безопасность)", "AGI", "Сознание", "Становление Творцом",
]


def _modules() -> dict[int, list[int]]:
    body = PATH_SOURCE.split("static let modules: [AIPathModule] = [", 1)[1].split("\n    ]\n", 1)[0]
    parts = re.split(r"AIPathModule\(number: (\d+), steps:", body)[1:]
    return {int(number): [int(step) for step in re.findall(r"AIPathStep\(number: (\d+), lessons:", chunk)]
            for number, chunk in zip(parts[::2], parts[1::2])}


def test_ten_creator_modules_in_order_with_every_step_once() -> None:
    assert _modules() == MODULE_STEPS
    assert "AIPathModule(number: 10, steps: [])" in PATH_SOURCE
    assert '"path.moduleLabel": ("' in STRINGS
    for number, title in enumerate(MODULE_TITLES_RU, start=1):
        assert f'"path.module{number}.title": ("{title}", "' in STRINGS
        assert f'"path.module{number}.why": ("' in STRINGS
        assert f"### Модуль {number}. {title}" in PLAN
    assert '"path.module10.empty": ("' in STRINGS and "части 3" in STRINGS.split('"path.module10.empty"', 1)[1].split("\n", 1)[0]
    assert "AIPathStage" not in PATH_SOURCE and '"path.stageLabel"' not in STRINGS


def test_glossary_keeps_its_own_five_stage_titles() -> None:
    glossary = (APP / "AIGlossaryLab.swift").read_text(encoding="utf-8")
    assert 'text("path.stage\\(number).title")' in glossary and "ForEach(1...5" in glossary
    for number in range(1, 6):
        assert f'"path.stage{number}.title": ("' in STRINGS


def test_home_next_step_opens_the_first_unfinished_path_lesson() -> None:
    view = (APP / "ContentView.swift").read_text(encoding="utf-8")
    card = PATH_SOURCE.split("struct CreatorNextStepCard: View {", 1)[1]
    assert "AIPathCatalog.next(completed: store.completedLessonIDs" in card
    assert "Button { openLesson(next) }" in card and '.accessibilityIdentifier("home.nextStep.open")' in card
    assert "CreatorNextStepCard(openLesson: openPathLesson, openPath: openPath)" in view
    today = view.split("private struct TodayView: View {", 1)[1]
    assert today.index("CreatorNextStepCard(") < today.index("progressCard\n")
    assert '"home.title": ("Путь Творца —\\nстановление Творцом"' in STRINGS
    assert '"home.nextStep.title": ("Твой следующий шаг"' in STRINGS


def test_path_opens_lessons_without_the_course_lock() -> None:
    view = (APP / "ContentView.swift").read_text(encoding="utf-8")
    opener = view.split("private func openPathLesson", 1)[1].split("\n    }\n", 1)[0]
    assert "selection = .courseLesson(lesson.subject, lesson.resource)" in opener
    assert "isAvailable" not in opener
    assert "AIPathView(openLesson: openPathLesson)" in view
    assert 'identifier: "sidebar.ai-path"' in view
