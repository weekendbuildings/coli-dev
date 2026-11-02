"""The transformer block lesson: its checks, numbers and lab agree. / Урок о блоке трансформера: проверки, числа и тренажёр согласованы."""
from __future__ import annotations

import contextlib
import io
import math
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LESSON = ROOT / "02_Areas" / "Programming" / "lessons" / "transformer_block.md"
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


def test_the_weight_count_in_the_text_adds_up() -> None:
    assert 2 * 3 * 4 * 8 == 192 and 8 * 8 == 64 and 2 * 16 * 8 == 256
    assert 192 + 64 + 256 == 512
    assert "512" in RUSSIAN and "512" in ENGLISH
    assert "192" in RUSSIAN and "192" in ENGLISH


def test_the_mask_really_hides_the_future() -> None:
    _, program = _run_program(ENGLISH)
    text, block = program["text"], program["block"]
    base = block(text)
    for place in range(1, 6):
        changed = [row[:] for row in text]
        changed[place] = [a + 1 for a in changed[place]]
        after = block(changed)
        # Every place before the changed one is untouched, exactly.
        for t in range(place):
            assert after[t] == base[t], (place, t)
        assert after[place] != base[place]


def test_every_place_is_normalized() -> None:
    _, program = _run_program(ENGLISH)
    for row in program["output"]:
        assert abs(sum(row) / len(row)) < 1e-9
        assert abs(math.sqrt(sum(a * a for a in row) / len(row)) - 1) < 1e-3


def test_backward_pass_is_the_true_slope() -> None:
    _, program = _run_program(ENGLISH)
    layers, start = program["make_stack"](4)
    for bypass in (False, True):
        exact = program["gradient"](layers, start, bypass)
        for index in range(len(start)):
            up, down = start[:], start[:]
            up[index] += 1e-6
            down[index] -= 1e-6
            slope = (program["forward"](layers, up, bypass)[0][0] - program["forward"](layers, down, bypass)[0][0]) / 2e-6
            assert math.isclose(slope, exact[index], abs_tol=1e-6)


def test_the_arithmetic_of_fading() -> None:
    assert round(0.5 ** 12, 5) == 0.00024
    assert "0,00024" in RUSSIAN and "0.00024" in ENGLISH


def test_exercise_has_a_clear_answer_in_the_lab() -> None:
    _, program = _run_program(ENGLISH)
    crossing = None
    for depth in range(2, 17):
        layers, start = program["make_stack"](depth)
        g = program["gradient"](layers, start, False)
        if math.sqrt(sum(a * a for a in g)) < 1e-3:
            crossing = depth
            break
    assert crossing is not None and 3 <= crossing <= 8


def test_quiz_has_the_right_answer() -> None:
    for section, options, answer in ((RUSSIAN, "### Варианты", "### Ответ"), (ENGLISH, "### Options", "### Answer")):
        block = section.split(options, 1)[1].split("###", 1)[0]
        lines = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(lines) == 3 and section.split(answer, 1)[1].split("###", 1)[0].strip() == "1"
        assert "1 + F′" in lines[0]
        assert max(map(len, lines)) < 1.3 * min(map(len, lines))


def test_lab_uses_the_lessons_model_and_is_wired_in() -> None:
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (APP / "L10n.swift").read_text(encoding="utf-8")
    model = (APP / "GradientStack.swift").read_text(encoding="utf-8")
    assert 'moduleResource == "transformer_block"' in views and "GradientTowerLab()" in views
    assert "static let seed = 99" in model and "static let gain = 0.25" in model
    assert "bypass: Bool = false" in model, "the lab must open without the bypass, so it does not open solved"
    keys = set(re.findall(r'text\("(lab\.tower\.[A-Za-z0-9]+)"\)', views))
    assert keys
    for key in keys | {"lab.tower.topLabel", "lab.tower.bottomLabel"}:
        assert re.search(rf'"{re.escape(key)}": \("[^"]+", "[^"]+"\)', strings), key
    assert len(re.findall(r'^\s*"lab\.tower\.title":', strings, re.M)) == 1
    roadmap = (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
    assert "lesson:transformer_block" in roadmap.split("## Продвинутый уровень / Advanced", 1)[1]
    assert "verify_gradient_stack.swift" in (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    for link in ("1706.03762", "transformer.html", "multihead-attention", "1512.03385", "1607.06450"):
        assert link in SOURCES
