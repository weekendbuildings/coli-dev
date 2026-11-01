from __future__ import annotations

import math
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LESSON = ROOT / "02_Areas" / "Physics" / "lessons" / "oscillations_and_waves.md"
APP_ROOT = ROOT / "macOS" / "ColiDev"
G = 9.81


def _period(length: float) -> float:
    return 2 * math.pi * math.sqrt(length / G)


def _sections(markdown: str) -> tuple[str, str]:
    russian = markdown.split("## Русский", 1)[1].split("## English", 1)[0]
    english = markdown.split("## English", 1)[1].split("## Sources", 1)[0]
    return russian, english


def test_oscillations_lesson_fills_the_physics_foundations_gap() -> None:
    roadmap = (ROOT / "02_Areas" / "Physics" / "curriculum.md").read_text(encoding="utf-8")
    foundations = roadmap.split("## База / Foundations", 1)[1].split("## Углубление", 1)[0]
    assert "| Колебания и волны / Oscillations and waves |" in foundations
    assert "lesson:oscillations_and_waves" in foundations
    assert "level: foundations" in LESSON.read_text(encoding="utf-8")


def test_stated_periods_and_wave_speed_follow_the_formulas() -> None:
    assert f"{_period(0.25):.2f}" == "1.00"
    assert f"{_period(1.0):.2f}" == "2.01"
    assert math.isclose(_period(1.0) / _period(0.25), 2.0)
    assert 2 * 3 == 6

    russian, english = _sections(LESSON.read_text(encoding="utf-8"))
    assert "1,00 с при 0,25 м и 2,01 с при 1,00 м" in russian
    assert "1.00 s at 0.25 m and 2.01 s at 1.00 m" in english
    assert "6 м/с" in russian and "6 m/s" in english
    assert russian.split("### Ответ", 1)[1].split("###", 1)[0].strip() == "1"
    assert english.split("### Answer", 1)[1].split("###", 1)[0].strip() == "1"
    assert "2 раза" in russian.split("### Варианты", 1)[1].split("- ", 2)[1]
    assert "doubles" in english.split("### Options", 1)[1].split("- ", 2)[1]


def test_lab_challenge_and_model_agree_with_the_lesson() -> None:
    model = (APP_ROOT / "App" / "Pendulum.swift").read_text(encoding="utf-8")
    strings = (APP_ROOT / "App" / "L10n.swift").read_text(encoding="utf-8")
    assert "static let gravity = 9.81" in model
    assert "static let amplitudeDegrees = 10.0" in model
    challenge = re.search(r'"lab\.pendulum\.challenge": \("([^"]+)", "([^"]+)"\)', strings)
    assert challenge and "1,00 с и 2,01 с" in challenge.group(1) and "1.00 s and 2.01 s" in challenge.group(2)


def test_pendulum_lab_is_wired_into_the_app_project_and_ci() -> None:
    views = (APP_ROOT / "App" / "LearningViews.swift").read_text(encoding="utf-8")
    project = (APP_ROOT / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    strings = (APP_ROOT / "App" / "L10n.swift").read_text(encoding="utf-8")

    assert 'moduleResource == "oscillations_and_waves"' in views and "PendulumLab()" in views
    assert "accessibilityReduceMotion" in views.split("private struct PendulumLab", 1)[1].split("private struct PendulumDrawing", 1)[0]
    assert "Pendulum.swift in Sources" in project
    assert "scripts/verify_pendulum.swift" in workflow
    used = set(re.findall(r'(?<!accessibilityIdentifier\()(?<!identifier: )"(lab\.pendulum\.[A-Za-z]+)"', views))
    defined = set(re.findall(r'^\s*"(lab\.pendulum\.[A-Za-z]+)":', strings, re.MULTILINE))
    assert used and used <= defined
