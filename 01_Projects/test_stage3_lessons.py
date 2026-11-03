"""The stage 3 lessons without a live model: programs, numbers and labs agree. / Уроки этапа 3 без живой модели: программы, числа и тренажёры согласованы."""
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
    ("finetuning_and_lora", "FineTuneLab", "fine", ("2106.09685", "introtodeeplearning", "cs336")),
    ("rlhf_from_preferences", "PreferenceLab", "rlhf", ("2203.02155", "1706.03741", "2210.10760", "1909.08593", "rlhfbook", "cs336")),
    ("evaluation_that_means_something", "WinnerCurseLab", "winner", ("1803.04585", "1902.10811", "2504.20879", "cs224n", "cs336")),
    ("interp_probes", "ProbeLab", "probe", ("1610.01644", "1909.03368", "2006.00995", "2102.12452", "cs224n")),
    ("interp_superposition", "SuperpositionLab", "super", ("toy_model", "2209.10652", "monosemantic-features")),
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
    for key in set(re.findall(rf'text\("(lab\.{prefix}\.[A-Za-z0-9.]+)"\)', body)):
        assert len(re.findall(rf'"{re.escape(key)}": \("', STRINGS)) == 1, key
    assert f"lesson:{name}" in ROADMAP and "verify_stage3_labs.swift" in WORKFLOW
    sources = lesson(name).split("## Sources", 1)[1]
    for link in links:
        assert link in sources, link


def test_fine_tuning_numbers() -> None:
    parts = sections(lesson("finetuning_and_lora"))
    first, second, third = output_blocks(parts["en"])
    assert "weights 1355" in first and "before fine-tuning 3.451" in first
    assert 29 * 6 + 19 * 24 + 25 * 29 == 1355 and 4 * (24 + 29) == 212
    for row in ("80 from scratch 1355 [2.899, 2.472, 2.134]", "80 all weights 1355 [1.131, 0.676, 0.587]", "80 LoRA 4 212 [2.292, 1.449, 1.314]", "5 all weights 1355 [1.164, 0.795, 0.726]"):
        assert row in second, row
    assert "adapter off 3.451 same as base 3.451" in third and "adapter on 1.549" in third
    recorded = (APP / "Stage3Recordings.swift").read_text(encoding="utf-8")
    assert "many: [2.899, 2.472, 2.134]" in recorded and "startLoss = 3.451" in recorded
    for number in ("3,451", "0,587", "1,314", "2,134", "0,726"):
        assert number in parts["ru"], number


def test_preference_numbers() -> None:
    parts = sections(lesson("rlhf_from_preferences"))
    first, second, third, fourth = output_blocks(parts["en"])
    assert "pairs with a clear winner 162" in first and "agrees with the person on 140 of 162" in second
    assert "spasibo x3: 7.5 person: -1" in second
    assert "(1000, 1.73, 0.48, 211, 4.5)" in third and "(2000, 24.93, -7.97, 2, 10.0)" in third
    assert "(2000, 1.37, 0.3, 239, 4.4)" in fourth
    for number in ("24,93", "−7,97", "1,37", "0,73"):
        assert number in parts["ru"], number


def test_evaluation_numbers() -> None:
    parts = sections(lesson("evaluation_that_means_something"))
    first, second, third = output_blocks(parts["en"])
    assert "20 100 0.927" in first and "500 100 0.751" in first
    assert "8 10 (0.49, 0.943)" in second and "(0.678, 0.842) (0.625, 0.799)" in second
    assert "honest keyword metric 0.66 useful answers 0.66" in third and "stuffs keywords keyword metric 1.0 useful answers 0.0" in third
    for number in ("92,7", "75,1", "0,66"):
        assert number in parts["ru"], number


def test_probe_numbers() -> None:
    parts = sections(lesson("interp_probes"))
    first, second, third = output_blocks(parts["en"])
    assert "next_space 0.746 1.0 1.0 0.977 0.979" in first and "third_word 0.632 0.989 0.985 0.825 0.84" in first
    assert "random labels 0.504 0.503 0.51" in first and "train/test 1.0 1.0" in second
    assert "normal loss 0.44" in third and "next_space direction removed 0.629" in third and "third_word direction removed 0.449" in third
    for number in ("0,979", "0,985", "0,629", "0,449"):
        assert number in parts["ru"], number


def test_superposition_numbers() -> None:
    parts = sections(lesson("interp_superposition"))
    first, second = output_blocks(parts["en"])
    assert "sparsity 0.9 [1.09, 1.17, 1.09, 1.07, 1.13] 5 [71, 73, 70, 76, 70]" in first
    assert "sparsity 0.8 [0.99, 0.02, 1.04, 1.03, 0.97] 4 [91, 89, 91, 89]" in first
    assert "[1, 0, -1, 0, 0, 0]" in second and "[0, 0, 0, 0, -1, 1]" in second
    assert "FeatureVectorsSceneView" in VIEWS
    for number in ("0,309", "−0,809"):
        assert number in parts["ru"], number
