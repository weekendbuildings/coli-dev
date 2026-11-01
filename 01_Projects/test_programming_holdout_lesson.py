from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LESSON = ROOT / "02_Areas" / "Programming" / "lessons" / "ml_baseline_and_holdout.md"
APP_ROOT = ROOT / "macOS" / "ColiDev"


def _sections(markdown: str) -> tuple[str, str]:
    russian = markdown.split("## Русский", 1)[1].split("## English", 1)[0]
    english = markdown.split("## English", 1)[1].split("## Sources", 1)[0]
    return russian, english


def test_holdout_lesson_is_routed_from_the_programming_roadmap() -> None:
    roadmap = (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
    intermediate = roadmap.split("## Углубление / Intermediate", 1)[1].split("## Продвинутый уровень", 1)[0]

    assert "lesson:ml_baseline_and_holdout" in intermediate
    assert "lesson_id: programming.ml_baseline_and_holdout" in LESSON.read_text(encoding="utf-8")


def test_python_example_reproduces_the_numbers_stated_in_both_languages() -> None:
    markdown = LESSON.read_text(encoding="utf-8")
    blocks = re.findall(r"```python\s*\n(.*?)\n```", markdown, re.DOTALL)
    assert len(blocks) == 2
    assert blocks[0] == blocks[1]

    result = subprocess.run([sys.executable, "-c", blocks[0]], capture_output=True, text=True, check=True)
    assert result.stdout.strip().splitlines() == [
        "1 13 / 13 8 / 12",
        "5 9 / 13 11 / 12",
        "13 7 / 13 5 / 12",
    ]

    russian, english = _sections(markdown)
    assert "8 из 12" in russian and "11 из 12" in russian and "5 из 12" in russian
    assert "8 of 12" in english and "11 of 12" in english and "5 of 12" in english


def test_lesson_and_swift_model_use_the_same_invented_examples() -> None:
    markdown = LESSON.read_text(encoding="utf-8")
    code = re.findall(r"```python\s*\n(.*?)\n```", markdown, re.DOTALL)[0]
    namespace: dict[str, object] = {}
    exec(code.split("\n\ndef predict", 1)[0], namespace)

    model = (APP_ROOT / "App" / "HeldOutEvaluation.swift").read_text(encoding="utf-8")
    training_block = model.split("static let trainingExamples", 1)[1].split("= [", 1)[1].split("]", 1)[0]
    held_out_block = model.split("static let heldOutExamples", 1)[1].split("= [", 1)[1].split("]", 1)[0]

    def swift_examples(block: str) -> list[tuple[int, int]]:
        return [
            (int(minutes), 1 if passed == "true" else 0)
            for minutes, passed in re.findall(r"minutes: (\d+), passed: (true|false)", block)
        ]

    assert swift_examples(training_block) == namespace["train"]
    assert swift_examples(held_out_block) == namespace["held_out"]


def test_baseline_is_described_as_ignoring_the_input_and_limits_name_a_test_set() -> None:
    russian, english = _sections(LESSON.read_text(encoding="utf-8"))

    assert 'DummyClassifier(strategy="most_frequent")' in russian
    assert 'DummyClassifier(strategy="most_frequent")' in english
    assert "придуманы" in russian
    assert "invented" in english
    assert "тестовой выборке" in russian.split("### Границы модели", 1)[1]
    assert "test set" in english.split("### Limits", 1)[1]


def test_holdout_lab_is_wired_into_the_app_project_and_ci() -> None:
    views = (APP_ROOT / "App" / "LearningViews.swift").read_text(encoding="utf-8")
    project = (APP_ROOT / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    strings = (APP_ROOT / "App" / "L10n.swift").read_text(encoding="utf-8")

    assert 'moduleResource == "ml_baseline_and_holdout"' in views
    assert "HeldOutEvaluationLab()" in views
    assert "HeldOutEvaluation.swift in Sources" in project
    assert "scripts/verify_held_out_evaluation.swift" in workflow

    used_keys = set(re.findall(r'(?<!accessibilityIdentifier\()(?<!identifier: )"(lab\.holdout\.[A-Za-z]+)"', views))
    defined_keys = set(re.findall(r'^\s*"(lab\.holdout\.[A-Za-z]+)":', strings, re.MULTILINE))
    assert used_keys
    assert used_keys <= defined_keys
