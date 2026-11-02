from __future__ import annotations

import math
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LESSON = ROOT / "02_Areas" / "Biology" / "lessons" / "what_is_life_and_its_origin.md"
APP_ROOT = ROOT / "macOS" / "ColiDev"


def _sections(markdown: str) -> tuple[str, str]:
    russian = markdown.split("## Русский", 1)[1].split("## English", 1)[0]
    english = markdown.split("## English", 1)[1].split("## Sources", 1)[0]
    return russian, english


def test_origin_lesson_follows_gene_expression_in_the_biology_roadmap() -> None:
    roadmap = (ROOT / "02_Areas" / "Biology" / "curriculum.md").read_text(encoding="utf-8")
    intermediate = roadmap.split("## Углубление / Intermediate", 1)[1].split("## Продвинутый уровень", 1)[0]
    assert intermediate.index("lesson:gene_expression_and_regulation") < intermediate.index("lesson:what_is_life_and_its_origin")


def test_question_arithmetic_matches_the_error_threshold() -> None:
    exact = 0.99**300
    assert round(exact, 3) == 0.049 and 10 * exact < 1
    # The largest length with 10 · 0.99^L > 1, quoted in the explanation.
    assert max(length for length in range(1, 1000) if 10 * 0.99**length > 1) == 229
    assert math.floor(math.log(10) / -math.log(0.99)) == 229

    russian, english = _sections(LESSON.read_text(encoding="utf-8"))
    assert "0,99³⁰⁰ ≈ 0,049" in russian and "229 букв" in russian
    assert "0.99³⁰⁰ ≈ 0.049" in english and "229 letters" in english
    assert russian.split("### Ответ", 1)[1].split("###", 1)[0].strip() == "1"
    assert english.split("### Answer", 1)[1].split("###", 1)[0].strip() == "1"


def test_lesson_separates_tested_steps_from_open_questions() -> None:
    russian, english = _sections(LESSON.read_text(encoding="utf-8"))
    assert "открытый научный вопрос" in russian and "open scientific question" in english
    # Synthetic genomes still needed a living recipient cell; the lesson must not overclaim.
    assert "пока не удалось никому" in russian and "no one has yet built a living cell" in english
    ru_limits = russian.split("### Границы модели", 1)[1]
    en_limits = english.split("### Limits", 1)[1]
    assert "условными" in ru_limits and "сознание" in ru_limits
    assert "illustrative" in en_limits and "consciousness" in en_limits


def test_every_source_is_a_resolvable_doi() -> None:
    sources = LESSON.read_text(encoding="utf-8").split("## Sources", 1)[1]
    dois = re.findall(r"\(https://doi\.org/(10\.[^)]+)\)", sources)
    assert len(dois) == 8 and len(set(dois)) == 8


def test_replicator_lab_is_wired_into_the_app_project_and_ci() -> None:
    views = (APP_ROOT / "App" / "LearningViews.swift").read_text(encoding="utf-8")
    project = (APP_ROOT / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    strings = (APP_ROOT / "App" / "L10n.swift").read_text(encoding="utf-8")
    journey = (APP_ROOT / "App" / "ContentView.swift").read_text(encoding="utf-8")

    assert 'moduleResource == "what_is_life_and_its_origin"' in views and "ReplicatorErrorThresholdLab()" in views
    assert "ReplicatorErrorThreshold.swift in Sources" in project
    assert "scripts/verify_replicator_error_threshold.swift" in workflow
    used = set(re.findall(r'(?<!accessibilityIdentifier\()(?<!identifier: )"(lab\.replicator\.[A-Za-z]+)"', views))
    defined = re.findall(r'^\s*"(lab\.replicator\.[A-Za-z]+)":', strings, re.MULTILINE)
    assert used and used <= set(defined) and len(defined) == len(set(defined))
    biology_stage = journey.split('id: "biology"', 1)[1].split("),\n        .init(", 1)[0]
    assert "Что такое жизнь и как она могла возникнуть" in biology_stage and "What life is and how it might have begun" in biology_stage
