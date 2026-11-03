"""The tokenizer lesson: its programs and lab agree. / Урок о токенизаторе: программы и тренажёр согласованы."""
from __future__ import annotations

import re
from pathlib import Path

from lesson_program_replay import output_blocks, replay, sections

ROOT = Path(__file__).resolve().parents[1]
LESSON = (ROOT / "02_Areas" / "Programming" / "lessons" / "tokenizer_bpe.md").read_text(encoding="utf-8")
APP = ROOT / "macOS" / "ColiDev" / "App"
PARTS = sections(LESSON)
SOURCES = LESSON.split("## Sources", 1)[1]


def test_programs_print_what_the_lesson_says() -> None:
    for section in PARTS.values():
        assert replay(section, {"calls": {}}) == output_blocks(section)


def test_numbers_in_the_text() -> None:
    first, second = output_blocks(PARTS["en"])
    lines = first.split("\n")
    assert lines[0] == "216 334"
    assert len("Привет".encode("utf-8")) == 12 and len("Hi".encode("utf-8")) == 2
    assert [line.split()[1].strip("\'") for line in lines[2:7]] == ["т", "а", "с", "и", "о"]
    assert "'Модель '" in lines[-1]
    rows = second.split("\n")
    assert rows[0].startswith("38 9 ") and rows[1].startswith("15 14 ") and rows[2].startswith("33 23 ")
    assert all(row.endswith("True") for row in rows), "Nothing may be lost. / Ничего не теряется."


def test_quiz_is_fair() -> None:
    for section, options, answer in ((PARTS["ru"], "### Варианты", "### Ответ"), (PARTS["en"], "### Options", "### Answer")):
        block = section.split(options, 1)[1].split("###", 1)[0]
        lines = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(lines) == 3 and section.split(answer, 1)[1].split("###", 1)[0].strip() == "1"
        assert max(map(len, lines)) < 1.25 * min(map(len, lines))


def test_lab_is_wired_in() -> None:
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (APP / "L10n.swift").read_text(encoding="utf-8")
    assert 'moduleResource == "tokenizer_bpe"' in views and "BPEMergeLab()" in views
    lab = views.split("private struct BPEMergeLab: View {", 1)[1]
    assert "LabChallenge(" in lab and "LabExplainer(" in lab
    for key in set(re.findall(r'text\("(lab\.bpe\.[A-Za-z0-9]+)"\)', lab)):
        assert len(re.findall(rf'"{re.escape(key)}": \("', strings)) == 1, key
    assert "lesson:tokenizer_bpe" in (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
    assert "verify_bpe_merge.swift" in (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    for link in ("zero-to-hero", "minbpe", "1508.07909", "cs336.stanford.edu"):
        assert link in SOURCES, link
