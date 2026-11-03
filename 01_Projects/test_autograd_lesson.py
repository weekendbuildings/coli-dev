"""The gradient engine lesson: its programs and lab agree. / Урок о механизме градиентов: программы и тренажёр согласованы."""
from __future__ import annotations

import ast
import re
from pathlib import Path

from lesson_program_replay import output_blocks, replay, sections

ROOT = Path(__file__).resolve().parents[1]
LESSON = (ROOT / "02_Areas" / "Programming" / "lessons" / "autograd_engine.md").read_text(encoding="utf-8")
APP = ROOT / "macOS" / "ColiDev" / "App"
PARTS = sections(LESSON)
SOURCES = LESSON.split("## Sources", 1)[1]


def test_programs_print_what_the_lesson_says() -> None:
    for section in PARTS.values():
        assert replay(section, {"calls": {}}) == output_blocks(section)


def test_the_engine_gets_the_hand_numbers() -> None:
    first, numeric, twice, network = output_blocks(PARTS["en"])
    assert first == "L = 4.0\na, b, c, d: -3.0 2.0 1.0 1.0"
    assert numeric == "a: -3.0\nb: 2.0\nc: 1.0"
    assert twice == "x * x, x = 3: 6.0"
    lines = network.split("\n")
    assert float(lines[-2].split()[1]) < 0.01, "The network must really learn. / Сеть должна действительно обучиться."
    answers = ast.literal_eval(lines[-1])
    assert all(abs(a - b) < 0.1 for a, b in zip(answers, [-1, 1, 1, -1]))
    assert round(2.1 * -3 + 10, 1) == 3.7 and "3,7" in PARTS["ru"] and "3.7" in PARTS["en"]


def test_quiz_is_fair() -> None:
    for section, options, answer in ((PARTS["ru"], "### Варианты", "### Ответ"), (PARTS["en"], "### Options", "### Answer")):
        block = section.split(options, 1)[1].split("###", 1)[0]
        lines = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(lines) == 3 and section.split(answer, 1)[1].split("###", 1)[0].strip() == "1"
        assert max(map(len, lines)) < 1.25 * min(map(len, lines))


def test_lab_is_wired_in() -> None:
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (APP / "L10n.swift").read_text(encoding="utf-8")
    assert 'moduleResource == "autograd_engine"' in views and "GradGraphLab()" in views
    lab = views.split("private struct GradGraphLab: View {", 1)[1].split("// MARK: - BPE merge lab", 1)[0]
    assert "LabChallenge(" in lab and "LabExplainer(" in lab
    keys = set(re.findall(r'text\("(lab\.gradGraph\.[A-Za-z0-9]+)"\)', lab)) | {f"lab.gradGraph.rule{n}" for n in range(5)}
    for key in keys:
        assert len(re.findall(rf'"{re.escape(key)}": \("', strings)) == 1, key
    assert "lesson:autograd_engine" in (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
    assert "verify_grad_graph.swift" in (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    for link in ("zero-to-hero", "micrograd", "microgpt"):
        assert link in SOURCES, link
