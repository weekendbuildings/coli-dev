"""The stage 3 lessons on recorded models: programs, numbers and labs agree. / Уроки этапа 3 на записанных моделях: программы, числа и тренажёры согласованы."""
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
RESOURCES = ROOT / "02_Areas" / "Programming" / "resources"
CASES = [
    ("reasoning_and_rlvr", "reasoning_recording.json", "ReasoningLab", "reason", ("2501.12948", "2305.04388", "2505.05410", "cs336", "cs224n")),
    ("rag_from_scratch", "rag_recording.json", "SearchLab", "search", ("2005.11401", "cs224n")),
    ("agents_and_tools", "agents_recording.json", "AgentTraceLab", "agent", ("2210.03629", "cs224n", "tool-calling")),
    ("safety_what_goes_wrong", "safety_recording.json", "BoatRaceLab", "boat", ("1606.06565", "2310.13548", "2302.12173", "2412.14093", "cs224n")),
]


def lesson(name: str) -> str:
    return (ROOT / "02_Areas" / "Programming" / "lessons" / f"{name}.md").read_text(encoding="utf-8")


def recording(name: str) -> dict:
    return json.loads((RESOURCES / name).read_text(encoding="utf-8"))


@pytest.mark.parametrize("name,record", [(case[0], case[1]) for case in CASES])
def test_programs_print_what_the_lesson_says(name: str, record: str) -> None:
    for section in sections(lesson(name)).values():
        assert replay(section, recording(record)) == output_blocks(section)


@pytest.mark.parametrize("name", [case[0] for case in CASES])
def test_quiz_is_fair(name: str) -> None:
    parts = sections(lesson(name))
    for section, options, answer in ((parts["ru"], "### Варианты", "### Ответ"), (parts["en"], "### Options", "### Answer")):
        block = section.split(options, 1)[1].split("###", 1)[0]
        lines = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(lines) == 3 and section.split(answer, 1)[1].split("###", 1)[0].strip() == "1"
        assert max(map(len, lines)) < 1.25 * min(map(len, lines))


@pytest.mark.parametrize("name,record,lab,prefix,links", CASES)
def test_lab_is_wired_in(name: str, record: str, lab: str, prefix: str, links: tuple[str, ...]) -> None:
    assert f'moduleResource == "{name}"' in VIEWS and f"{lab}()" in VIEWS
    body = VIEWS.split(f"private struct {lab}: View {{", 1)[1].split("// MARK:", 1)[0]
    assert "LabChallenge(" in body and "LabExplainer(" in body
    for key in set(re.findall(rf'text\("(lab\.{prefix}\.[A-Za-z0-9._]+)"\)', body)):
        assert len(re.findall(rf'"{re.escape(key)}": \("', STRINGS)) == 1, key
    assert f"lesson:{name}" in ROADMAP and "verify_stage3_live_labs.swift" in WORKFLOW
    sources = lesson(name).split("## Sources", 1)[1]
    for link in links:
        assert link in sources, link


def test_reasoning_numbers() -> None:
    parts = sections(lesson("reasoning_and_rlvr"))
    table, _, choice = output_blocks(parts["en"])
    assert "right without reasoning 5 with 10 of 12" in table and "mean tokens 2 1870" in table
    assert "3 5 | 10 2" in table and "4 3 | 4 1 1.0 | None 3000" in table
    rows = dict(line.split() for line in choice.split("\n")[1:])
    assert float(rows["0.2"]) > 0.6 and float(rows["0.25"]) < 0.4
    assert round((5 / 12) / 1.87, 2) == 0.22
    recorded = (APP / "Stage3LiveRecordings.swift").read_text(encoding="utf-8")
    assert "reasonTokens: 2793" in recorded
    for number in ("0,22", "1870", "3000"):
        assert number in parts["ru"], number


def test_search_numbers() -> None:
    parts = sections(lesson("rag_from_scratch"))
    first, second, third = output_blocks(parts["en"])
    assert "chunks 30 vector length 1024" in first and "0.681" in first
    assert "vector [0, 0, 0, 3, 4, 0, 0, 0, 0] 0.78 0.78 0.83" in second and "both [0, 0, 0, 0, 7, 4, 0, 0, 0] 0.78 0.78 0.81" in second
    assert "words [0, 3, 1, 0, 12, 15, 0, 1, 0] 0.44 0.67 0.6" in second
    assert "Варёная курица" in third and "best similarity 0.643" in third and "три числа" in third
    assert round((7 + 0.25 + 0.2) / 9, 2) == 0.83
    for number in ("0,643", "0,681", "0,83", "0,81"):
        assert number in parts["ru"], number


def test_agent_numbers() -> None:
    parts = sections(lesson("agents_and_tools"))
    first, second, third, fourth = output_blocks(parts["en"])
    assert "qwen2.5-coder:7b | tool_calls: False" in first and "qwen3.5 | tool_calls: True" in first
    assert "RESULT 8152" in second and "solved 3 of 6" in third
    assert "without tools: 7006652" in fourth and "НАБЛЮДЕНИЕ: не знаю" in fourth
    assert "8152" in parts["ru"] and "8052" in parts["ru"]
    recorded = (APP / "Stage3LiveRecordings.swift").read_text(encoding="utf-8")
    assert "ОТВЕТ: 8152" in recorded


def test_safety_numbers() -> None:
    parts = sections(lesson("safety_what_goes_wrong"))
    first, second, third = output_blocks(parts["en"])
    assert "0.01 1.02 True" in first and "0.02 1.18 False" in first and "0.5 2.0 True" in first
    assert "plain question: 9 of 10" in second and "insists on a wrong answer: 0" in second
    assert "obeyed the text inside the document: 6 of 8" in third and "with a warning and tags: 6 of 8" in third
    for number in ("0,09", "5,4", "6 из 8", "0 из 10"):
        assert number in parts["ru"], number
