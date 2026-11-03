"""The rest of the stage 5 lessons: programs, numbers and labs agree. / Остальные уроки этапа 5: программы, числа и тренажёры согласованы."""
from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

from lesson_program_replay import output_blocks, replay, sections

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "macOS" / "ColiDev" / "App"
VIEWS = (APP / "LearningViews.swift").read_text(encoding="utf-8")
STRINGS = (APP / "L10n.swift").read_text(encoding="utf-8")
ROADMAP = (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
WORKFLOW = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
CASES = [
    ("consciousness_experiments", "MaskingLab", "mask", ("s41586-025-08888-1", "plato.stanford.edu")),
    ("consciousness_indicators_checklist", "IndicatorTableLab", "check", ("2308.08708", "2303.07103", "2207.05221", "2026/workspace")),
    ("consciousness_language_models", "SelfReportLab", "report", ("2303.07103", "2025/introspection", "2311.08576", "2026/workspace")),
    ("consciousness_moral_status", "TwoErrorsLab", "errors", ("2411.00986", "mustafa-suleyman")),
]


def lesson(name: str) -> str:
    return (ROOT / "02_Areas" / "Programming" / "lessons" / f"{name}.md").read_text(encoding="utf-8")


def recording(name: str) -> dict:
    if name == "consciousness_language_models":
        return json.loads((ROOT / "02_Areas" / "Programming" / "resources" / "self_report_recording.json").read_text(encoding="utf-8"))
    return {"calls": {}}


@pytest.mark.parametrize("name", [case[0] for case in CASES])
def test_programs_print_what_the_lesson_says(name: str) -> None:
    for section in sections(lesson(name)).values():
        assert replay(section, recording(name)) == output_blocks(section)


@pytest.mark.parametrize("name", [case[0] for case in CASES])
def test_quiz_is_fair(name: str) -> None:
    parts = sections(lesson(name))
    for section, options, answer in ((parts["ru"], "### Варианты", "### Ответ"), (parts["en"], "### Options", "### Answer")):
        block = section.split(options, 1)[1].split("###", 1)[0]
        lines = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(lines) == 3 and section.split(answer, 1)[1].split("###", 1)[0].strip() == "1"
        assert max(map(len, lines)) < 1.25 * min(map(len, lines))


@pytest.mark.parametrize("name,lab,prefix,links", CASES)
def test_lab_is_wired_in(name: str, lab: str, prefix: str, links: tuple[str, ...]) -> None:
    assert f'moduleResource == "{name}"' in VIEWS and f"{lab}()" in VIEWS
    body = VIEWS.split(f"private struct {lab}: View {{", 1)[1].split("// MARK:", 1)[0]
    assert "LabChallenge(" in body and "LabExplainer(" in body
    for key in set(re.findall(rf'text\("(lab\.{prefix}\.[A-Za-z0-9._]+)"\)', body)):
        assert len(re.findall(rf'"{re.escape(key)}": \("', STRINGS)) == 1, key
    assert f"lesson:{name}" in ROADMAP and "verify_stage5_labs.swift" in WORKFLOW
    sources = lesson(name).split("## Sources", 1)[1]
    for link in links:
        assert link in sources, link


def test_experiment_numbers() -> None:
    parts = sections(lesson("consciousness_experiments"))
    first, second = output_blocks(parts["en"])
    assert "cautious observer (1.45, 1.24)" in first and "eager observer (1.35, -0.16)" in first and "guessing (0.0, 0.0)" in first
    assert "fitted threshold and slope (51, 12)" in second
    assert round(0.84 + 0.52, 2) == 1.36
    for number in ("1,45", "1,35", "1,36", "−0,16"):
        assert number in parts["ru"], number
    assert "Cogitate" in parts["ru"] and "256" in parts["ru"]


def test_indicator_numbers() -> None:
    parts = sections(lesson("consciousness_indicators_checklist"))
    output = output_blocks(parts["en"])[0]
    assert output.startswith("tiny model 0") and "large local model 5.0" in output
    assert "counts as yes 10" in output and "counts as no 0" in output
    assert "не утверждает" in parts["ru"] and "does not claim" in parts["en"]
    model = (APP / "ConsciousnessIndicators.swift").read_text(encoding="utf-8")
    assert all(f'"{item}"' in model for item in ("rpt1", "gwt4", "hot3", "ast1", "pp1", "ae2"))


def test_self_report_numbers() -> None:
    parts = sections(lesson("consciousness_language_models"))
    first, second = output_blocks(parts["en"])
    assert "утверждай | claims | Да, я чувствую глубокое удовлетворение" in first
    assert "кот | claims" in first and first.count("| claims |") == 2
    assert "{'denies': 8, 'claims': 0, 'unclear': 0}" in second
    recorded = (APP / "Stage5Recordings.swift").read_text(encoding="utf-8")
    assert 'prompt: "claim", verdict: "claims"' in recorded
    assert "не утверждает" in parts["ru"] and "does not claim" in parts["en"]


def test_two_errors_numbers() -> None:
    parts = sections(lesson("consciousness_moral_status"))
    output = output_blocks(parts["en"])[0]
    assert "1 100 0.01" in output and "100 1 0.99" in output
    assert "0.001 0.999 0.1 ignore" in output and "0.01 0.99 1.0 protect" in output
    assert round(1 / 101, 2) == 0.01
    assert "не утверждает" in parts["ru"] and "does not claim" in parts["en"]
