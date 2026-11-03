"""The stage 2 lessons on training: programs, numbers and labs agree. / Уроки этапа 2 об обучении: программы, числа и тренажёры согласованы."""
from __future__ import annotations

import re
from pathlib import Path

import pytest

from lesson_program_replay import output_blocks, python_blocks, replay, sections

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "macOS" / "ColiDev" / "App"
VIEWS = (APP / "LearningViews.swift").read_text(encoding="utf-8")
STRINGS = (APP / "L10n.swift").read_text(encoding="utf-8")
ROADMAP = (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
WORKFLOW = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
CASES = [
    ("initialization_and_normalization", "InitHeatLab", "initHeat", "verify_init_norm.swift", ("glorot10a", "1502.03167", "1607.06450", "1502.01852", "zero-to-hero")),
    ("optimizers_momentum_adam", "OptimizerRaceLab", "opt", "verify_optimizer_valley.swift", ("1412.6980", "1609.04747", "zero-to-hero")),
    ("training_recipe_and_diagnostics", "TrainingDoctorLab", "doctor", "verify_training_doctor.swift", ("2019/04/25/recipe", "zero-to-hero")),
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


@pytest.mark.parametrize("name,lab,prefix,script,links", CASES)
def test_lab_is_wired_in(name: str, lab: str, prefix: str, script: str, links: tuple[str, ...]) -> None:
    assert f'moduleResource == "{name}"' in VIEWS and f"{lab}()" in VIEWS
    body = VIEWS.split(f"private struct {lab}: View {{", 1)[1].split("// MARK:", 1)[0]
    assert "LabChallenge(" in body and "LabExplainer(" in body
    for key in set(re.findall(rf'text\("(lab\.{prefix}\.[A-Za-z0-9.]+)"\)', body)):
        assert len(re.findall(rf'"{re.escape(key)}": \("', STRINGS)) == 1, key
    assert f"lesson:{name}" in ROADMAP and script in WORKFLOW
    sources = lesson(name).split("## Sources", 1)[1]
    for link in links:
        assert link in sources, link


def test_initialization_numbers_in_the_text() -> None:
    parts = sections(lesson("initialization_and_normalization"))
    first, second = output_blocks(parts["en"])
    assert "0.232" in first and "1.65e-05" in first and "7.06" in first and "0.618" in first and "0.259" in first
    assert first.count("act") == 3 and second.count("act") == 3
    acts = re.findall(r"act  (.*)", second)
    assert acts[0] == acts[1] == acts[2], "Normalization removes the scale. / Нормализация убирает масштаб."
    assert abs(0.25 ** 8 - 0.000015) < 1e-6
    for number in ("0,232", "0,618", "0,259", "7,06", "0,35"):
        assert number in parts["ru"], number
    for option, text in (("tanh", parts["ru"]),):
        assert option in text


def test_optimizer_numbers_in_the_text() -> None:
    parts = sections(lesson("optimizers_momentum_adam"))
    table, steps = output_blocks(parts["en"])
    for row in ("plain 0.99 187", "plain 1.01 None", "momentum 0.5 36", "adam 1.0 9", "adam 0.1 87"):
        assert row in table, row
    assert "(-7.5, 1.5)" in steps.split("\n")[2]
    assert round(1 - 2 * 0.9, 1) == -0.8 and round(1 - 2 * 1.01, 2) == -1.02
    for number in ("187", "36", "87", "−0,8", "−1,02"):
        assert number in parts["ru"], number
    assert "OptimizerValleySceneView" in VIEWS and "LabSceneView" in (APP / "OptimizerValley3DView.swift").read_text(encoding="utf-8")


def test_doctor_numbers_and_recording() -> None:
    text = lesson("training_recipe_and_diagnostics")
    parts = sections(text)
    table = output_blocks(parts["en"])[0]
    namespace: dict = {"__name__": "x"}
    import contextlib
    import io
    with contextlib.redirect_stdout(io.StringIO()):
        exec(python_blocks(parts["en"])[0], namespace)
    curves = namespace["curves"]
    assert list(curves) == ["healthy", "rate_high", "rate_low", "labels_shuffled", "wrong_sign", "too_little_data"]
    assert curves["healthy"][-1] == (0.207, 0.333) and curves["too_little_data"][-1] == (0.004, 2.528)
    assert curves["rate_high"][-1][0] == 8.98 and round(curves["wrong_sign"][-1][0], 1) == 11.7
    model = (APP / "TrainingDoctorModel.swift").read_text(encoding="utf-8")
    for name, curve in curves.items():
        assert f"({curve[-1][0]}, {curve[-1][1]})" in model, name
    assert "ln 2 = 0.693" in table and "2,528" in parts["ru"] and "2.528" in parts["en"]
    weights = 8 * 3 + 9
    assert weights == 33 and "33" in parts["ru"]
