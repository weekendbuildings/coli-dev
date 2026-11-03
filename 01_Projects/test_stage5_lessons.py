"""The stage 5 lessons: programs, numbers and labs agree, and no lesson claims a system is conscious. / Уроки этапа 5: программы, числа и тренажёры согласованы, и ни один урок не утверждает, что система сознательна."""
from __future__ import annotations

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
    ("consciousness_hard_problem", "HardProblemLab", "hard", ("consc.net", "plato.stanford.edu", "ted.com")),
    ("consciousness_global_workspace", "WorkspaceLab", "work", ("s41586-025-08888-1", "2026/workspace", "S0896-6273(20)30052-3")),
    ("consciousness_integrated_information", "IntegrationLab", "phi", ("2212.14787", "zsr78", "scottaaronson", "s41586-025-08888-1")),
    ("consciousness_higher_order_and_prediction", "ConfidenceLab", "meta", ("1706.04599", "2207.05221", "S1364-6613(19)30161-4")),
]


def lesson(name: str) -> str:
    return (ROOT / "02_Areas" / "Programming" / "lessons" / f"{name}.md").read_text(encoding="utf-8")


@pytest.mark.parametrize("name", [case[0] for case in CASES])
def test_programs_print_what_the_lesson_says(name: str) -> None:
    for section in sections(lesson(name)).values():
        assert replay(section, {"calls": {}}) == output_blocks(section)


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


def test_hard_problem_numbers() -> None:
    parts = sections(lesson("consciousness_hard_problem"))
    output = output_blocks(parts["en"])[0]
    assert output.startswith("first report: всё хорошо") and "'плита': 0.75" in output and "мне больно" in output
    assert 0.5 + 0.5 * (1 - 0.5) == 0.75
    assert "0,75" in parts["ru"] and "0.75" in parts["en"]
    assert "не утверждает" in parts["ru"] and "does not claim" in parts["en"]


def test_workspace_numbers() -> None:
    parts = sections(lesson("consciousness_global_workspace"))
    first, second, third = output_blocks(parts["en"])
    assert first.startswith("0.3 [") and "0.9 [0.57, 1.0" in first
    assert "0.4 0.04" in second and "0.5 0.45" in second and "0.6 0.93" in second
    assert "both 0" in third and "first 184 second 2" in third
    assert round(2.4 * 0.7, 2) == 1.68
    for number in ("0,04", "0,45", "0,93", "1,68"):
        assert number in parts["ru"], number


def test_integration_numbers() -> None:
    parts = sections(lesson("consciousness_integrated_information"))
    output = output_blocks(parts["en"])[0]
    assert "disconnected [0.0, 0.0, 0.0] 0.0" in output and "chain [2.0, 2.0, 2.0] 2.0" in output
    assert "xor ring [2.0, 2.0, 2.0] 2.0" in output and "and ring [1.561, 1.561, 1.561] 1.561" in output
    assert "это не настоящее Φ" in parts["ru"] and "not the real Φ" in parts["en"]
    assert "1,561" in parts["ru"]


def test_confidence_numbers() -> None:
    parts = sections(lesson("consciousness_higher_order_and_prediction"))
    first, second, third = output_blocks(parts["en"])
    assert "accuracy on new points 0.717" in first and "gap 0.099" in first and "(391, 0.87, 0.96)" in first
    assert "temperature 2.0 gap 0.031" in second and "temperature 16.0 gap 0.185" in second
    assert third.endswith("0.726")
    for number in ("0,717", "0,099", "0,031", "0,185", "0,726"):
        assert number in parts["ru"], number
