from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LESSON = ROOT / "02_Areas" / "Programming" / "lessons" / "gradient_descent_and_learning_rate.md"
APP_ROOT = ROOT / "macOS" / "ColiDev"


def _sections(markdown: str) -> tuple[str, str]:
    russian = markdown.split("## Русский", 1)[1].split("## English", 1)[0]
    english = markdown.split("## English", 1)[1].split("## Sources", 1)[0]
    return russian, english


def test_gradient_descent_lesson_is_routed_after_the_holdout_lesson() -> None:
    roadmap = (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
    intermediate = roadmap.split("## Углубление / Intermediate", 1)[1].split("## Продвинутый уровень", 1)[0]

    assert "lesson:gradient_descent_and_learning_rate" in intermediate
    assert intermediate.index("lesson:ml_baseline_and_holdout") < intermediate.index("lesson:gradient_descent_and_learning_rate")


def test_python_example_reproduces_the_stated_numbers() -> None:
    markdown = LESSON.read_text(encoding="utf-8")
    blocks = re.findall(r"```python\s*\n(.*?)\n```", markdown, re.DOTALL)
    assert len(blocks) == 2 and blocks[0] == blocks[1]

    result = subprocess.run([sys.executable, "-c", blocks[0]], capture_output=True, text=True, check=True)
    assert result.stdout.strip().splitlines() == [
        "0.01 1.913 0.069",
        "0.05 1.99 0.024",
        "0.12 1.967 0.028",
        "0.15 -170.615 223443.633",
    ]

    russian, english = _sections(markdown)
    for value in ("1,913", "1,99", "0,024", "1,967", "223 444", "−1,25", "0,25"):
        assert value in russian, value
    for value in ("1.913", "1.99", "0.024", "1.967", "223,444", "−1.25", "0.25"):
        assert value in english, value


def test_swift_model_uses_the_lesson_data_and_rates() -> None:
    model = (APP_ROOT / "App" / "GradientDescent.swift").read_text(encoding="utf-8")
    code = re.findall(r"```python\s*\n(.*?)\n```", LESSON.read_text(encoding="utf-8"), re.DOTALL)[0]

    assert "static let inputs: [Double] = [1, 2, 3, 4]" in model and "xs = [1, 2, 3, 4]" in code
    assert "static let targets: [Double] = [2.1, 3.9, 6.2, 7.8]" in model and "ys = [2.1, 3.9, 6.2, 7.8]" in code
    assert "static let learningRates: [Double] = [0.01, 0.05, 0.12, 0.15]" in model
    assert "for rate in (0.01, 0.05, 0.12, 0.15):" in code


def test_answer_is_the_too_large_learning_rate() -> None:
    russian, english = _sections(LESSON.read_text(encoding="utf-8"))
    assert russian.split("### Ответ", 1)[1].split("###", 1)[0].strip() == "1"
    assert english.split("### Answer", 1)[1].split("###", 1)[0].strip() == "1"
    assert "слишком большой" in russian.split("### Варианты", 1)[1].split("- ", 2)[1]
    assert "too large" in english.split("### Options", 1)[1].split("- ", 2)[1]


def test_gradient_descent_lab_is_wired_into_the_app_project_and_ci() -> None:
    views = (APP_ROOT / "App" / "LearningViews.swift").read_text(encoding="utf-8")
    project = (APP_ROOT / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    strings = (APP_ROOT / "App" / "L10n.swift").read_text(encoding="utf-8")

    assert 'moduleResource == "gradient_descent_and_learning_rate"' in views and "GradientDescentLab()" in views
    assert "GradientDescent.swift in Sources" in project
    assert "scripts/verify_gradient_descent.swift" in workflow
    used = set(re.findall(r'(?<!accessibilityIdentifier\()(?<!identifier: )"(lab\.gd\.[A-Za-z]+)"', views))
    defined = set(re.findall(r'^\s*"(lab\.gd\.[A-Za-z]+)":', strings, re.MULTILINE))
    assert used and used <= defined
