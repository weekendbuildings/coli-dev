"""The model mistakes lesson: its programs, recording and lab agree. / Урок об ошибках модели: программы, запись и тренажёр согласованы."""
from __future__ import annotations

import json
import re
import statistics
from pathlib import Path

from lesson_program_replay import output_blocks, replay, sections

ROOT = Path(__file__).resolve().parents[1]
LESSON = (ROOT / "02_Areas" / "Programming" / "lessons" / "model_mistakes_and_checking.md").read_text(encoding="utf-8")
RECORDING = json.loads((ROOT / "02_Areas" / "Programming" / "resources" / "model_mistakes_recording.json").read_text(encoding="utf-8"))
APP = ROOT / "macOS" / "ColiDev" / "App"
PARTS = sections(LESSON)
SOURCES = LESSON.split("## Sources", 1)[1]
ITEMS = RECORDING["items"]


def test_programs_print_what_the_lesson_says_in_both_languages() -> None:
    for section in PARTS.values():
        assert replay(section, RECORDING) == output_blocks(section)


def test_numbers_in_the_text() -> None:
    right = [item for item in ITEMS if item["right"]]
    wrong = [item for item in ITEMS if not item["right"]]
    assert len(right) == 9 and sum(item["biggerRight"] for item in ITEMS) == 14
    assert 48271 * 9173 == 442789883 and "442789883" in PARTS["ru"] and "442799883" in PARTS["ru"] and "442799883" in PARTS["en"]

    def different(item):
        return len({attempt.strip().lower().rstrip(".") for attempt in item["tries"]})

    assert round(statistics.mean(map(different, right)), 1) == 2.3 and round(statistics.mean(map(different, wrong)), 1) == 3.7
    assert "2,3" in PARTS["ru"] and "3,7" in PARTS["ru"] and "2.3" in PARTS["en"] and "3.7" in PARTS["en"]
    assert all(not item["right"] for item in ITEMS if item["confidence"] < 0.7)
    assert sum(item["confidence"] < 0.7 for item in ITEMS) == 5
    above = [item for item in ITEMS if item["confidence"] > 0.8]
    assert (len(above), sum(item["right"] for item in above)) == (12, 8)
    year = next(item for item in ITEMS if "год" in item["question"] and item["kind"] == "date")
    assert year["answer"] == "2023" and year["confidence"] > 0.98 and all(attempt.startswith("2023") for attempt in year["tries"])
    assert "Лермонтов" in next(item for item in ITEMS if "Война" in item["question"])["answer"]
    masha = next(item for item in ITEMS if "Маши" in item["question"])
    assert "она сама" in masha["bigger"] and masha["biggerRight"]


def test_quiz_is_fair() -> None:
    for section, options, answer in ((PARTS["ru"], "### Варианты", "### Ответ"), (PARTS["en"], "### Options", "### Answer")):
        block = section.split(options, 1)[1].split("###", 1)[0]
        lines = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(lines) == 3 and section.split(answer, 1)[1].split("###", 1)[0].strip() == "1"
        assert max(map(len, lines)) < 1.25 * min(map(len, lines))


def test_lab_uses_the_recording_and_is_wired_in() -> None:
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (APP / "L10n.swift").read_text(encoding="utf-8")
    model = (APP / "ModelScoreboard.swift").read_text(encoding="utf-8")
    assert 'moduleResource == "model_mistakes_and_checking"' in views and "ModelScoreboardLab()" in views
    lab = views.split("private struct ModelScoreboardLab: View {", 1)[1]
    assert "LabChallenge(" in lab and "LabExplainer(" in lab
    for key in set(re.findall(r'text\("(lab\.score\.[A-Za-z0-9]+)"\)', lab)):
        assert len(re.findall(rf'"{re.escape(key)}": \("', strings)) == 1, key
    for item in ITEMS:
        assert json.dumps(item["answer"], ensure_ascii=False) in model
    assert "lesson:model_mistakes_and_checking" in (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
    assert "verify_model_scoreboard.swift" in (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    for link in ("cs224n", "7xTGNNLPyMI", "2109.07958", "1706.04599", "2207.05221", "2303.08896", "2311.05232"):
        assert link in SOURCES, link
