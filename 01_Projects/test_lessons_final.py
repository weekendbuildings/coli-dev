"""The importance B and C lessons of the AI path: programs, quiz and labs agree.

Уроки важности B и C пути ИИ: программы, вопрос и тренажёры согласованы.
"""
from __future__ import annotations

import json
import re
from pathlib import Path

import pytest

from lesson_program_replay import output_blocks, replay, sections

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "macOS" / "ColiDev" / "App"
VIEWS = (APP / "LearningViews.swift").read_text(encoding="utf-8")
LABS = (APP / "LessonsFinalLabs.swift").read_text(encoding="utf-8")
STRINGS = (APP / "L10n.swift").read_text(encoding="utf-8")
ROADMAP = (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
PLAN = (ROOT / "project-plan" / "AI_PATH_RU_EN.md").read_text(encoding="utf-8")
WORKFLOW = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
RESOURCES = ROOT / "02_Areas" / "Programming" / "resources"

# lesson, lab view, string prefix, links that must be in Sources
CASES = [
    ("bigram_language_model", "BigramLab", "bigram", ("PaCmpygFfXo", "zero-to-hero")),
    ("constitutional_ai_and_dpo", "DPOLab", "dpo", ("2212.08073", "2305.18290", "2310.12036")),
    ("scaling_laws_and_resources", "ComputeBudgetLab", "scaling", ("2203.15556", "2001.08361", "apple-unleashes-m1")),
    ("data_for_language_models", "DedupLab", "dedup", ("2107.06499", "2406.17557", "2104.08758")),
    ("sampling_and_generation", "SamplingLab", "sampling", ("1904.09751", "docs.ollama.com/modelfile", "live_model_recording.json")),
]


def lesson(name: str) -> str:
    return (ROOT / "02_Areas" / "Programming" / "lessons" / f"{name}.md").read_text(encoding="utf-8")


def recording(name: str) -> dict:
    path = RESOURCES / f"{name}_recording.json"
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {"calls": {}}


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
    body = LABS.split(f"struct {lab}: View {{", 1)[1].split("// MARK:", 1)[0]
    assert "LabChallenge(" in body and "LabExplainer(" in body
    keys = set(re.findall(rf'text\("(lab\.{prefix}\.[A-Za-z0-9._]+)"\)', body))
    assert keys
    for key in keys:
        assert len(re.findall(rf'"{re.escape(key)}": \("', STRINGS)) == 1, key
    assert f"lesson:{name}" in ROADMAP and "verify_lessons_final_labs.swift" in WORKFLOW
    assert re.search(rf"\| `{name}` \|[^\n]*\| есть \|", PLAN), name
    sources = lesson(name).split("## Sources", 1)[1]
    for link in links:
        assert link in sources, link


def test_real_top20_in_the_lab_equals_the_recording() -> None:
    record = json.loads((RESOURCES / "live_model_recording.json").read_text(encoding="utf-8"))
    models = (APP / "LessonsFinalModels.swift").read_text(encoding="utf-8")
    body = models.split("enum RealTop20 {", 1)[1].split("static var probabilities", 1)[0]
    pairs = re.findall(r'\("((?:[^"\\]|\\.)*)", (-?\d+\.\d+)\)', body)
    swift = [(token.encode().decode("unicode_escape"), float(logprob)) for token, logprob in pairs]
    assert swift == [(item["token"], item["logprob"]) for item in record["top20"]]
