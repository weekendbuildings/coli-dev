"""The chat lesson: its programs, recording and lab agree. / Урок о чате: программы, запись и тренажёр согласованы."""
from __future__ import annotations

import json
import re
from pathlib import Path

from lesson_program_replay import output_blocks, python_blocks, replay, sections

ROOT = Path(__file__).resolve().parents[1]
LESSON = (ROOT / "02_Areas" / "Programming" / "lessons" / "chat_roles_and_context.md").read_text(encoding="utf-8")
RECORDING = json.loads((ROOT / "02_Areas" / "Programming" / "resources" / "chat_anatomy_recording.json").read_text(encoding="utf-8"))
APP = ROOT / "macOS" / "ColiDev" / "App"
PARTS = sections(LESSON)
SOURCES = LESSON.split("## Sources", 1)[1]


def test_programs_print_what_the_lesson_says_in_both_languages() -> None:
    for section in PARTS.values():
        outputs = replay(section, RECORDING)
        assert outputs == output_blocks(section)
    assert python_blocks(PARTS["ru"]) == python_blocks(PARTS["en"])


def test_the_experiments_show_what_the_text_claims() -> None:
    outputs = replay(PARTS["en"], RECORDING)
    assert outputs[0].startswith("(32,"), "32 tokens for one word / 32 токена на одно слово"
    first, second = outputs[1].split("\n")
    assert first == second == "(28, 'Париж')", "The chat and the hand-written text must match. / Чат и текст вручную совпадают."
    alone, history = outputs[2].split("\n")
    assert "Тимур" not in alone and "Тимур" in history
    assert "2 + 2 = 5." in outputs[3].split("\n")[0] and "4" in outputs[3].split("\n")[1]
    rows = outputs[4].split("\n")
    assert "кактус" not in rows[3].lower() and "кактус" in rows[4].lower()
    assert all("2070" not in row for row in rows[:4]) and "(2070," in rows[4]
    assert int(outputs[5].split(",")[0].strip("(")) < 60, "The huge message must vanish. / Огромное сообщение исчезает."
    assert "кактус" in outputs[6].lower()
    for section in PARTS.values():
        assert "2070" in section


def test_quiz_is_fair() -> None:
    for section, options, answer in ((PARTS["ru"], "### Варианты", "### Ответ"), (PARTS["en"], "### Options", "### Answer")):
        block = section.split(options, 1)[1].split("###", 1)[0]
        lines = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(lines) == 3 and section.split(answer, 1)[1].split("###", 1)[0].strip() == "1"
        assert max(map(len, lines)) < 1.25 * min(map(len, lines))


def test_lab_uses_the_lesson_and_is_wired_in() -> None:
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (APP / "L10n.swift").read_text(encoding="utf-8")
    model = (APP / "ChatLabModel.swift").read_text(encoding="utf-8")
    assert 'moduleResource == "chat_roles_and_context"' in views and "ChatAnatomyLab()" in views
    lab = views.split("private struct ChatAnatomyLab: View {", 1)[1].split("\n}\n", 1)[0]
    assert "LabChallenge(" in lab and "LabExplainer(" in lab
    for key in set(re.findall(r'text\("(lab\.chat\.[A-Za-z0-9]+)"\)', lab)):
        assert len(re.findall(rf'"{re.escape(key)}": \("', strings)) == 1, key
    for scenario in ("memory", "forged", "wrapper", "window"):
        assert f'"lab.chat.tab.{scenario}": ("' in strings and f'"lab.chat.hint.{scenario}": ("' in strings
    for row in RECORDING["window"]:
        assert f'"window.{row["num_ctx"]}": (' in model
    assert "lesson:chat_roles_and_context" in (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
    assert "verify_chat_lab.swift" in (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    for link in ("docs.ollama.com/api/chat", "docs.ollama.com/context-length", "7xTGNNLPyMI", "EWvNQjAaOHw", "2211.09527", "2302.12173"):
        assert link in SOURCES, link
