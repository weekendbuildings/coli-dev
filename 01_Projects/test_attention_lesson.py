"""The attention lesson: its numbers, program and lab agree. / Урок о внимании: числа, программа и тренажёр согласованы."""
from __future__ import annotations

import contextlib
import io
import math
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LESSON = ROOT / "02_Areas" / "Programming" / "lessons" / "attention_mechanism.md"
APP = ROOT / "macOS" / "ColiDev" / "App"
TEXT = LESSON.read_text(encoding="utf-8")
RUSSIAN = TEXT.split("## Русский", 1)[1].split("## English", 1)[0]
ENGLISH = TEXT.split("## English", 1)[1].split("## Sources", 1)[0]
SOURCES = TEXT.split("## Sources", 1)[1]


def _run_program(section: str, positions: bool = True) -> tuple[str, dict]:
    code = re.search(r"```python\n(.*?)```", section, re.S).group(1)
    if not positions:
        assert "positions = True" in code
        code = code.replace("positions = True", "positions = False")
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
    assert round(math.log(4), 3) == 1.386 and "1,386" in RUSSIAN and "1.386" in ENGLISH


def test_without_positions_the_model_is_stuck_as_the_text_says() -> None:
    output, _ = _run_program(ENGLISH, positions=False)
    assert "300 0.567 0.54" in output
    assert "0,567" in RUSSIAN and "54 %" in RUSSIAN
    assert "0.567" in ENGLISH and "54%" in ENGLISH


def test_weights_lie_where_the_answer_is() -> None:
    _, program = _run_program(ENGLISH)
    line = program["unseen"][0]
    for t in (6, 5):
        weights = program["predict"](line, t)[0]
        assert abs(sum(weights) - 1) < 1e-12 and len(weights) == t + 1
        top = weights.index(max(weights))
        assert (t + 1 - top) % 3 == 0
        assert line[top] == line[t + 1]


def test_worked_example_numbers() -> None:
    scores = [1 / math.sqrt(2), 0, 1 / math.sqrt(2)]
    powers = [math.exp(s) for s in scores]
    alpha = [p / sum(powers) for p in powers]
    assert [round(a, 3) for a in alpha] == [0.401, 0.198, 0.401]
    keys = [(1, 0), (0, 1), (1, 1)]
    context = [sum(a * k[i] for a, k in zip(alpha, keys)) for i in range(2)]
    assert [round(c, 3) for c in context] == [0.802, 0.599]
    for number in ("0,707", "0,401", "0,198", "0,802", "0,599"):
        assert number in RUSSIAN
    for number in ("0.707", "0.401", "0.198", "0.802", "0.599"):
        assert number in ENGLISH


def test_dot_product_variance_grows_with_length() -> None:
    # The claim behind √d, computed from the formula: Var(Σ aᵢbᵢ) = d when the elements have mean 0 and variance 1.
    # With elements ±1 the variance of a product is exactly 1, and independent terms add up.
    for d in (4, 16, 64):
        assert sum((a * b) ** 2 for a, b in zip([1] * d, [1] * d)) == d
        assert d / math.sqrt(d) ** 2 == 1


def test_attention_ignores_order_without_positions() -> None:
    # The quiz: with fixed keys per letter, moved letters take their weights along.
    query = [1.0, 0.5]
    keys = {"A": [0.2, 0.9], "B": [1.0, -0.3], "C": [-0.4, 0.1]}

    def weights(order: str) -> dict[str, float]:
        scores = [sum(a * b for a, b in zip(query, keys[letter])) / math.sqrt(2) for letter in order]
        powers = [math.exp(s) for s in scores]
        return {letter: p / sum(powers) for letter, p in zip(order, powers)}

    first, second = weights("ABC"), weights("CAB")
    assert all(abs(first[letter] - second[letter]) < 1e-12 for letter in "ABC")
    for section, options, answer in ((RUSSIAN, "### Варианты", "### Ответ"), (ENGLISH, "### Options", "### Answer")):
        block = section.split(options, 1)[1].split("###", 1)[0]
        lines = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(lines) == 3 and section.split(answer, 1)[1].split("###", 1)[0].strip() == "1"
        assert max(map(len, lines)) < 1.3 * min(map(len, lines))


def test_lab_uses_the_lessons_model_and_is_wired_in() -> None:
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (APP / "L10n.swift").read_text(encoding="utf-8")
    model = (APP / "PatternAttention.swift").read_text(encoding="utf-8")
    assert 'moduleResource == "attention_mechanism"' in views and "AttentionTowersLab()" in views
    assert "static let weightSeed = 4242" in model and "static let dataSeed = 777" in model
    assert "usesPositions: Bool = false" in model, "the lab must open without place numbers, so it does not open solved"
    keys = set(re.findall(r'text\("(lab\.attention\.[A-Za-z0-9]+)"\)', views))
    assert keys
    for key in keys | {"lab.attention.answerLabel"}:
        assert re.search(rf'"{re.escape(key)}": \("[^"]+", "[^"]+"\)', strings), key
    assert len(re.findall(r'^\s*"lab\.attention\.title":', strings, re.M)) == 1
    roadmap = (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
    assert "lesson:attention_mechanism" in roadmap.split("## Продвинутый уровень / Advanced", 1)[1]
    assert "verify_pattern_attention.swift" in (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    for link in ("1409.0473", "1706.03762", "attention-scoring-functions", "self-attention-and-positional-encoding", "1902.10186"):
        assert link in SOURCES
