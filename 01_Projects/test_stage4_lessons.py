"""The stage 4 lessons: programs, numbers and labs agree. / Уроки этапа 4: программы, числа и тренажёры согласованы."""
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
    ("agi_what_is_intelligence", "IntelligenceLab", "intel", ("0712.3329", "1911.01547", "2311.02462")),
    ("agi_measuring_arc", "ArcPainterLab", "arc", ("1911.01547", "arcprize.org")),
    ("agi_world_models", "DynaLab", "dyna", ("1803.10122", "2301.04104", "BZ5a1r-kVsf", "2506.09985", "the-book-2nd")),
    ("agi_continual_learning", "ForgettingLab", "forget", ("1612.00796", "2208.11173")),
    ("agi_scaling_debate", "ScalingLab", "scale", ("2001.08361", "2203.15556", "2503.14499", "2507.09089", "BitterLesson", "cs336")),
]


def lesson(name: str) -> str:
    return (ROOT / "02_Areas" / "Programming" / "lessons" / f"{name}.md").read_text(encoding="utf-8")


def recording(name: str) -> dict:
    if name == "agi_measuring_arc":
        return json.loads((ROOT / "02_Areas" / "Programming" / "resources" / "arc_recording.json").read_text(encoding="utf-8"))
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
    assert f"lesson:{name}" in ROADMAP and "verify_stage4_labs.swift" in WORKFLOW
    sources = lesson(name).split("## Sources", 1)[1]
    for link in links:
        assert link in sources, link


def test_intelligence_numbers() -> None:
    parts = sections(lesson("agi_what_is_intelligence"))
    first, second, third = output_blocks(parts["en"])
    assert "specialist 0.493" in second and "learner 0.621" in second and "specialist 0.901" in second and "learner 0.855" in second
    assert "5 0.448 0.501" in third and "400 0.68 0.483" in third
    assert "learner [0.85, 0.74" in first
    assert round(2 ** -8, 4) == 0.0039
    for number in ("0,621", "0,901", "0,0039"):
        assert number in parts["ru"], number


def test_arc_numbers() -> None:
    parts = sections(lesson("agi_measuring_arc"))
    first, second = output_blocks(parts["en"])
    assert "search solved 9 of 10" in first and "count None False 132" in first
    assert second.count("solved 4 of 10") == 2 and "flip 043/700 430/007 False" in second
    recorded = (APP / "Stage4Recordings.swift").read_text(encoding="utf-8")
    assert 'testOut: "043/700"' in recorded
    assert "75,7" in parts["ru"] and "75.7" in parts["en"]


def test_world_model_numbers() -> None:
    parts = sections(lesson("agi_world_models"))
    first, second = output_blocks(parts["en"])
    assert "0 165 142 90 26 10" in first and "50 126 30 11 11 10" in first
    assert "0 10 188 153 67" in second and "50 10 115 65 20" in second
    assert round(0.5 * 0.95 * 0.8, 2) == 0.38 and round(0.38 + 0.5 * 0.38, 2) == 0.57
    for number in ("0,38", "0,57", "142", "153"):
        assert number in parts["ru"], number


def test_forgetting_numbers() -> None:
    parts = sections(lesson("agi_continual_learning"))
    first, second, third = output_blocks(parts["en"])
    assert "after task A: A 1.0" in first and "after task B: A 0.003" in first
    assert "20 0.5 0.853" in second and "200 0.5 0.973" in second
    assert "100 0.003" in third and "1000 0.48 0.483" in third
    for number in ("0,003", "0,853", "0,973", "0,48"):
        assert number in parts["ru"], number


def test_scaling_numbers() -> None:
    parts = sections(lesson("agi_scaling_debate"))
    first, second, third = output_blocks(parts["en"])
    assert "100000 0.587" in first and "1000 real 1.088 law 1.08" in second and "100000 real 0.587 law 0.265" in second
    assert "law at a billion characters 0.016" in second and "exponent -0.031" in second and "84 4096.0" in third
    words = ["кот", "пёс", "мама", "папа", "дед", "гусь", "ест", "видит", "любит", "ищет", "несёт", "рыбу", "воду", "кашу", "мяч", "дом", "траву"]
    assert round(sum(map(len, words)) / 17 + 1, 2) == 4.88
    for number in ("0,587", "0,265", "0,016", "4,88"):
        assert number in parts["ru"], number
