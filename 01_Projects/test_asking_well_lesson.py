"""The asking lesson: its programs, recording and lab agree. / Урок о том, как просить: программы, запись и тренажёр согласованы."""
from __future__ import annotations

import json
import re
from pathlib import Path

from lesson_program_replay import output_blocks, replay, sections

ROOT = Path(__file__).resolve().parents[1]
LESSON = (ROOT / "02_Areas" / "Programming" / "lessons" / "asking_well_and_structured_output.md").read_text(encoding="utf-8")
RECORDING = json.loads((ROOT / "02_Areas" / "Programming" / "resources" / "asking_well_recording.json").read_text(encoding="utf-8"))
APP = ROOT / "macOS" / "ColiDev" / "App"
PARTS = sections(LESSON)
SOURCES = LESSON.split("## Sources", 1)[1]


def test_programs_print_what_the_lesson_says_in_both_languages() -> None:
    for section in PARTS.values():
        assert replay(section, RECORDING) == output_blocks(section)


def test_claims_in_the_text() -> None:
    combos = {(c["rule"], c["examples"], c["shape"]): c for c in RECORDING["combos"]}
    assert combos[(True, False, False)]["marks"].count("broken") == 12
    assert RECORDING["rule_without_fences_right"] == 12, "The text says the answers were right under the signs. / В тексте сказано, что под значками ответы верны."
    assert combos[(False, True, False)]["marks"].count("right") == 12
    assert combos[(False, False, True)]["marks"].count("right") == 10 and combos[(False, False, True)]["marks"].count("wrong") == 2
    full = [c for c in RECORDING["combos"] if c["marks"].count("right") == 12]
    assert min(c["tokens"] for c in full) == 101 and sorted(c["tokens"] for c in full)[1] == 143
    wrong = [a for a, m in zip(combos[(False, False, True)]["answers"], combos[(False, False, True)]["marks"]) if m == "wrong"]
    assert all("купил" in a or "берёт" in a for a in wrong), "The whole phrase in the name field. / Вся фраза в поле имени."
    for section in PARTS.values():
        assert "```" not in "".join(output_blocks(section))


def test_quiz_is_fair() -> None:
    for section, options, answer in ((PARTS["ru"], "### Варианты", "### Ответ"), (PARTS["en"], "### Options", "### Answer")):
        block = section.split(options, 1)[1].split("###", 1)[0]
        lines = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(lines) == 3 and section.split(answer, 1)[1].split("###", 1)[0].strip() == "1"
        assert max(map(len, lines)) < 1.25 * min(map(len, lines))


def test_lab_is_wired_in() -> None:
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (APP / "L10n.swift").read_text(encoding="utf-8")
    assert 'moduleResource == "asking_well_and_structured_output"' in views and "PromptToggleLab()" in views
    lab = views.split("private struct PromptToggleLab: View {", 1)[1]
    assert "LabChallenge(" in lab and "LabExplainer(" in lab
    for key in set(re.findall(r'text\("(lab\.prompt\.[A-Za-z0-9.]+)"\)', lab)):
        assert len(re.findall(rf'"{re.escape(key)}": \("', strings)) == 1, key
    assert "lesson:asking_well_and_structured_output" in (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
    assert "verify_prompt_lab.swift" in (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    for link in ("structured-outputs", "cs224n", "2005.14165"):
        assert link in SOURCES, link
