"""The hidden layer lesson: its proof, program, numbers and lab agree. / Урок о скрытом слое: доказательство, программа, числа и тренажёр согласованы."""
from __future__ import annotations

import contextlib
import io
import itertools
import math
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LESSON = ROOT / "02_Areas" / "Programming" / "lessons" / "neural_network_hidden_layer_xor.md"
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


def _train(weights: list[float], gradient, iterations: int) -> list[float]:
    for _ in range(iterations):
        weights = [a - g for a, g in zip(weights, gradient(weights))]
    return weights


def test_program_prints_what_the_lesson_says_in_both_languages() -> None:
    for section in (RUSSIAN, ENGLISH):
        output, _ = _run_program(section)
        lines = output.strip().split("\n")
        assert lines[:4] == ["0 0.2483", "500 0.1734", "1000 0.0272", "3000 0.0026"]
        printed = re.search(r"```text\n(.*?)```", section, re.S).group(1).strip().split("\n")
        assert lines[4:] == printed
    assert all(n in RUSSIAN for n in ("0,2483", "0,1734", "0,0272", "0,0026"))
    assert all(n in ENGLISH for n in ("0.2483", "0.1734", "0.0272", "0.0026"))


def test_hidden_neurons_come_to_resemble_or_and_nand() -> None:
    _, program = _run_program(ENGLISH)
    answers = [program["forward"](program["w"], x) for x, _ in program["data"]]
    assert [round(a[0]) for a in answers] == [0, 1, 1, 1]
    assert [round(a[1]) for a in answers] == [1, 1, 1, 0]
    assert [round(a[2]) for a in answers] == [t for _, t in program["data"]]


def test_no_threshold_neuron_computes_xor() -> None:
    # The lesson's proof: the two pairs of conditions force w₁ + w₂ + 2b to be both positive and negative.
    grid = [value / 4 for value in range(-20, 21)]
    for w1, w2, b in itertools.product(grid, repeat=3):
        answers = [w1 * x1 + w2 * x2 + b > 0 for x1, x2 in ((0, 0), (0, 1), (1, 0), (1, 1))]
        assert answers != [False, True, True, False]
    assert "w₁ + w₂ + 2b > 0" in RUSSIAN and "w₁ + w₂ + 2b < 0" in RUSSIAN
    assert "w₁ + w₂ + 2b > 0" in ENGLISH and "w₁ + w₂ + 2b < 0" in ENGLISH


def test_worked_example_numbers() -> None:
    sigma = lambda z: 1 / (1 + math.exp(-z))
    h1, h2 = sigma(0.7 + 0.6), sigma(0.1 + 0.5)
    y = sigma(0.7 * h1 + 0.7 * h2 - 0.9)
    out = 2 * (y - 1) * y * (1 - y)
    assert (round(h1, 3), round(h2, 3), round(y, 3)) == (0.786, 0.646, 0.525)
    assert round((y - 1) ** 2, 3) == 0.225
    assert round(out, 3) == -0.237 and round(out * h1, 3) == -0.186
    hidden_gradient = out * 0.7 * h1 * (1 - h1)
    assert round(hidden_gradient, 3) == -0.028
    assert 7.5 < out / hidden_gradient < 9  # "about eightfold"
    for number in ("0,786", "0,646", "0,525", "0,225", "−0,237", "−0,186", "−0,028"):
        assert number in RUSSIAN
    for number in ("0.786", "0.646", "0.525", "0.225", "−0.237", "−0.186", "−0.028"):
        assert number in ENGLISH


def test_backpropagation_matches_a_numerical_gradient() -> None:
    _, program = _run_program(ENGLISH)
    weights = [0.7, 0.7, 0.6, 0.1, -0.9, 0.5, 0.7, 0.7, -0.9]
    gradient = program["gradient"](weights)
    for index in range(9):
        shifted = list(weights)
        shifted[index] += 1e-6
        numerical = (program["loss"](shifted) - program["loss"](weights)) / 1e-6
        assert math.isclose(numerical, gradient[index], abs_tol=1e-5)


def test_plateau_and_identical_starts_behave_as_the_lesson_says() -> None:
    _, program = _run_program(ENGLISH)
    plateau = _train([0.2, -0.7, -0.5, 0.8, 0.9, -0.9, -0.6, -0.1, -0.5], program["gradient"], 50_000)
    assert 0.166 < program["loss"](plateau) < 0.168
    assert "0,167" in RUSSIAN and "50 000" in RUSSIAN and "0.167" in ENGLISH and "50,000" in ENGLISH
    identical = _train([0.5, 0.5, -0.2, 0.5, 0.5, -0.2, 0.5, 0.5, -0.2], program["gradient"], 3000)
    assert identical[:3] == identical[3:6] and identical[6] == identical[7]


def test_single_neuron_reaches_one_half_for_every_input() -> None:
    sigma = lambda z: 1 / (1 + math.exp(-z))
    w1, w2, b = 0.5, -0.5, 0.2
    data = ((0, 0, 0), (0, 1, 1), (1, 0, 1), (1, 1, 0))
    for _ in range(1000):
        g1 = g2 = gb = 0.0
        for x1, x2, t in data:
            y = sigma(w1 * x1 + w2 * x2 + b)
            out = 2 * (y - t) * y * (1 - y) / 4
            g1, g2, gb = g1 + out * x1, g2 + out * x2, gb + out
        w1, w2, b = w1 - g1, w2 - g2, b - gb
    answers = [sigma(w1 * x1 + w2 * x2 + b) for x1, x2, _ in data]
    assert all(abs(answer - 0.5) < 0.01 for answer in answers)


def test_quiz_checks_understanding_without_showing_the_calculation() -> None:
    for section, heading, answer_heading in ((RUSSIAN, "### Варианты", "### Ответ"), (ENGLISH, "### Options", "### Answer")):
        block = section.split(heading, 1)[1].split("###", 1)[0]
        options = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(options) == 3
        assert section.split(answer_heading, 1)[1].split("###", 1)[0].strip() == "2"
        assert "скрыт" in options[1].lower() or "hidden" in options[1].lower()
        assert max(map(len, options)) < 1.3 * min(map(len, options))
        assert not any("=" in option for option in options)


def test_sources_are_ones_the_lesson_can_stand_on() -> None:
    for link in ("d2l.ai/chapter_multilayer-perceptrons/mlp.html", "numerical-stability-and-init", "cs231n.github.io/optimization-2",
                 "neural-networks/backpropagation", "10.1038/323533a0", "Perceptrons_(book)"):
        assert link in SOURCES


def test_lab_matches_the_lesson_and_is_wired_in() -> None:
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (APP / "L10n.swift").read_text(encoding="utf-8")
    model = (APP / "NeuronTraining.swift").read_text(encoding="utf-8")
    assert 'moduleResource == "neural_network_hidden_layer_xor"' in views and "XORNetworkLab()" in views
    assert "[0.7, 0.7, 0.6, 0.1, -0.9, 0.5, 0.7, 0.7, -0.9]" in RUSSIAN.replace("−", "-")
    assert "[0.7, 0.7, 0.6, 0.1, -0.9, 0.5, 0.7, 0.7, -0.9]" in model
    assert "[0.2, -0.7, -0.5, 0.8, 0.9, -0.9, -0.6, -0.1, -0.5]" in model
    roadmap = (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
    advanced = roadmap.split("## Продвинутый уровень / Advanced", 1)[1].split("\n## ", 1)[0]
    assert "lesson:neural_network_hidden_layer_xor" in advanced
    keys = set(re.findall(r'text\("(lab\.xor\.[A-Za-z0-9]+)"\)', views))
    assert keys
    for key in keys:
        match = re.search(rf'"{re.escape(key)}": \("([^"]+)", "([^"]+)"\)', strings)
        assert match, key
    assert len(re.findall(r'^\s*"lab\.xor\.title":', strings, re.M)) == 1
    previous = (ROOT / "02_Areas" / "Programming" / "lessons" / "neural_network_backpropagation.md").read_text(encoding="utf-8")
    assert "«Скрытый слой: нейросеть учит XOR»" in previous and "A Network Learns XOR" in previous
