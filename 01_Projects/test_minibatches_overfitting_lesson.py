"""The mini-batch lesson: its numbers, program and labs agree. / Урок о мини-батчах: числа, программа и тренажёры согласованы."""
from __future__ import annotations

import contextlib
import io
import math
import random
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LESSON = ROOT / "02_Areas" / "Programming" / "lessons" / "minibatches_and_overfitting.md"
APP = ROOT / "macOS" / "ColiDev" / "App"
TEXT = LESSON.read_text(encoding="utf-8")
RUSSIAN = TEXT.split("## Русский", 1)[1].split("## English", 1)[0]
ENGLISH = TEXT.split("## English", 1)[1].split("## Sources", 1)[0]
SOURCES = TEXT.split("## Sources", 1)[1]


def _run_program(section: str) -> tuple[str, dict]:
    code = re.search(r"```python\n(.*?)```", section, re.S).group(1)
    namespace: dict = {}
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        exec(code, namespace)
    return output.getvalue(), namespace


def test_program_prints_what_the_lesson_says_in_both_languages() -> None:
    for section in (RUSSIAN, ENGLISH):
        output, _ = _run_program(section)
        printed = re.search(r"```text\n(.*?)```", section, re.S).group(1).strip()
        assert output.strip() == printed
    for number in ("0,005", "0,427", "0,316", "0,074", "0,338"):
        assert number in RUSSIAN
    for number in ("0.005", "0.427", "0.316", "0.074", "0.338"):
        assert number in ENGLISH


def test_batch_gradient_noise_falls_as_the_lesson_says() -> None:
    # The mean of b independent examples: its variance is the variance of one over b.
    generator = random.Random(7)
    values = [generator.gauss(0, 1) for _ in range(200_000)]
    def variance(size: int) -> float:
        means = [sum(values[i:i + size]) / size for i in range(0, len(values) - size, size)]
        center = sum(means) / len(means)
        return sum((m - center) ** 2 for m in means) / len(means)
    one = variance(1)
    assert 3.6 < one / variance(4) < 4.4
    assert 90 < one / variance(100) < 110
    assert "1/√b" in RUSSIAN and "1/√b" in ENGLISH


def test_exercise_has_a_real_answer() -> None:
    _, program = _run_program(ENGLISH)
    # A batch of 8 falls between the batches of 4 and 24 at rate 0.2.
    assert program["reads_to_target"](4, 0.2) <= program["reads_to_target"](8, 0.2) <= program["reads_to_target"](24, 0.2)


def test_decay_and_curves_behave_as_the_text_says() -> None:
    _, program = _run_program(ENGLISH)
    no_decay = program["train_model"](0.0)
    decay = program["train_model"](0.1)
    assert no_decay[0] < decay[0], "decay raises the training error"
    assert no_decay[1] > decay[1], "decay lowers the final held-out error"
    assert no_decay[1] > no_decay[2], "the held-out error rose after its best moment"
    assert decay[1] - decay[2] < no_decay[1] - no_decay[2], "with decay it rises less"
    assert len(program["held"]) == 40 and len(program["train"]) == 12 and len(program["features"](0.3)) == 21


def test_quiz_has_the_right_answer() -> None:
    for section, options, answer in ((RUSSIAN, "### Варианты", "### Ответ"), (ENGLISH, "### Options", "### Answer")):
        block = section.split(options, 1)[1].split("###", 1)[0]
        lines = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(lines) == 3 and section.split(answer, 1)[1].split("###", 1)[0].strip() == "2"
        assert max(map(len, lines)) < 1.3 * min(map(len, lines))


def test_labs_use_the_lessons_models_and_are_wired_in() -> None:
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (APP / "L10n.swift").read_text(encoding="utf-8")
    model = (APP / "TrainingPractice.swift").read_text(encoding="utf-8")
    assert 'moduleResource == "minibatches_and_overfitting"' in views
    assert "MinibatchReliefLab()" in views and "WaveFitLab()" in views
    for constant in ("dataSeed = 31337", "shuffleSeed = 555", "static let seed = 2718", "stepLimit = 600", "static let rate = 0.05"):
        assert constant in model
    keys = set(re.findall(r'text\("(lab\.(?:batch|waves)\.[A-Za-z0-9]+)"\)', views))
    assert keys
    for key in keys | {"lab.batch.bestLabel"}:
        assert re.search(rf'"{re.escape(key)}": \("[^"]+", "[^"]+"\)', strings), key
    assert len(re.findall(r'^\s*"lab\.batch\.title":', strings, re.M)) == 1
    assert len(re.findall(r'^\s*"lab\.waves\.title":', strings, re.M)) == 1
    roadmap = (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
    assert "lesson:minibatches_and_overfitting" in roadmap.split("## Продвинутый уровень / Advanced", 1)[1]
    assert "verify_training_practice.swift" in (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    for link in ("minibatch-sgd", "weight-decay", "overfitting/overfitting"):
        assert link in SOURCES
