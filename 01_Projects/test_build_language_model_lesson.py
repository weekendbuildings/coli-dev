"""The final project: its program, gradients, real training results and lab agree. / Финальный проект: программа, градиенты, настоящие результаты и тренажёр согласованы."""
from __future__ import annotations

import contextlib
import io
import json
import math
import re
import sys
import tokenize
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LESSON = ROOT / "02_Areas" / "Programming" / "lessons" / "build_your_language_model.md"
PROGRAM = ROOT / "01_Projects" / "tiny_language_model.py"
RESOURCES = ROOT / "02_Areas" / "Programming" / "resources"
APP = ROOT / "macOS" / "ColiDev" / "App"
TEXT = LESSON.read_text(encoding="utf-8")
RUSSIAN = TEXT.split("## Русский", 1)[1].split("## English", 1)[0]
ENGLISH = TEXT.split("## English", 1)[1].split("## Sources", 1)[0]
SOURCES = TEXT.split("## Sources", 1)[1]
LOG = (RESOURCES / "tiny_language_model_log.txt").read_text(encoding="utf-8")


def _without_comments(source: str) -> list[tuple[int, str]]:
    tokens = tokenize.generate_tokens(io.StringIO(source).readline)
    return [(t.type, t.string) for t in tokens if t.type not in (tokenize.COMMENT, tokenize.NL, tokenize.ENCODING)]


def _loaded(size: int = 8, length: int = 8, batch: int = 2) -> dict:
    """Loads the program with a small model, reading the real course, without training it."""
    source = PROGRAM.read_text(encoding="utf-8")
    source = source.replace("SIZE, HEADS, BLOCKS, LENGTH, BATCH = 32, 2, 2, 32, 8", f"SIZE, HEADS, BLOCKS, LENGTH, BATCH = {size}, 2, 2, {length}, {batch}")
    namespace: dict = {"__name__": "lesson_check"}
    saved = sys.argv
    sys.argv = ["tiny", str(ROOT / "02_Areas"), "0"]
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            exec(source, namespace)
    finally:
        sys.argv = saved
    return namespace


def test_lesson_code_is_the_program_in_both_languages() -> None:
    program = PROGRAM.read_text(encoding="utf-8")
    body = program[program.index("import json"):]
    expected = _without_comments(body)
    for section in (RUSSIAN, ENGLISH):
        code = re.search(r"```python\n(.*?)```", section, re.S).group(1)
        assert _without_comments(code) == expected
    assert "numpy" not in program.lower().split("import json", 1)[1], "plain Python: no third-party imports"
    imports = set(re.findall(r"^(?:import|from) (\w+)", program, re.M))
    assert imports <= {"json", "math", "re", "sys", "time", "collections", "operator", "pathlib"}


def test_automatic_gradient_matches_numerical_slopes() -> None:
    program = _loaded()
    x, y = program["piece"](program["train"])
    for p in program["parameters"]:
        p.grad = None
    logits = program["forward"](x)
    _, seed = program["cross_entropy"](logits, y)
    program["backward"](logits, seed)
    generator = program["Generator"](77)
    checked = 0
    for p in program["parameters"]:
        if p.grad is None:
            continue
        for _ in range(2):
            r, c = generator.below(len(p.data)), generator.below(len(p.data[0]))
            keep = p.data[r][c]
            p.data[r][c] = keep + 1e-5
            up = program["cross_entropy"](program["forward"](x), y)[0]
            p.data[r][c] = keep - 1e-5
            down = program["cross_entropy"](program["forward"](x), y)[0]
            p.data[r][c] = keep
            # Central differences with h = 1e-5 err by about 1e-6 on slopes near 0.4, so the tolerance is relative too.
            assert math.isclose((up - down) / 2e-5, p.grad[r][c], rel_tol=1e-5, abs_tol=1e-6)
            checked += 1
    assert checked > 30


def test_the_mask_hides_the_future_in_the_whole_model() -> None:
    program = _loaded()
    text = program["train"][:8]
    changed = text[:7] + [(text[7] + 1) % program["V"]]
    base, after = program["forward"](text).data, program["forward"](changed).data
    assert base[:7] == after[:7]
    assert base[7] != after[7]


def test_a_few_steps_lower_the_error_on_the_small_model() -> None:
    program = _loaded(size=8, length=12, batch=4)
    forward, cross_entropy, backward, parameters = (program[k] for k in ("forward", "cross_entropy", "backward", "parameters"))
    x, y = program["piece"](program["train"])
    start = cross_entropy(forward(x), y)[0]
    for step in range(1, 16):
        for p in parameters:
            p.grad = None
        logits = forward(x)
        _, seed = cross_entropy(logits, y)
        backward(logits, seed)
        program["adam_step"](step, 0.01)
    assert cross_entropy(forward(x), y)[0] < start


def test_real_training_crossed_the_finish_line() -> None:
    random_error = float(re.search(r"random ([\d.]+) pairs", LOG).group(1))
    pairs = float(re.search(r"pairs ([\d.]+)", LOG).group(1))
    best = float(re.search(r"^best ([\d.]+) at step", LOG, re.M).group(1))
    held = float(re.search(r"^whole held-out text ([\d.]+)", LOG, re.M).group(1))
    assert best < pairs < random_error, "the first part of the finish line"
    assert held < pairs, "on the whole held-out text too"
    for section, decimal in ((RUSSIAN, ","), (ENGLISH, ".")):
        for value in (pairs, held, best):
            assert f"{value}".replace(".", decimal) in section, value
    # The lesson shows the true log. / В уроке настоящий журнал.
    for section in (RUSSIAN, ENGLISH):
        lines = [line for line in LOG.strip().split("\n") if " train " in line]
        assert lines and all(line in section for line in lines)


def test_bundled_weights_are_the_programs_and_write_like_the_lesson() -> None:
    data = json.loads((RESOURCES / "tiny_language_model.json").read_text(encoding="utf-8"))
    assert (data["size"], data["heads"], data["blocks"], data["length"]) == (32, 2, 2, 32)
    assert data["alphabet"][-1] == "□" and all(len(letter) == 1 for letter in data["alphabet"])
    assert sum(len(m) * len(m[0]) for m in data["weights"]) == 26624
    assert "26624" in RUSSIAN and "26624" in ENGLISH
    samples = re.findall(r"T = [\d.]+: (.+)", (RESOURCES / "tiny_language_model_log.txt").read_text(encoding="utf-8"))
    assert len(samples) >= 3
    for section in (RUSSIAN, ENGLISH):
        assert all(sample in section for sample in samples)


def test_quiz_has_the_right_answer() -> None:
    for section, options, answer in ((RUSSIAN, "### Варианты", "### Ответ"), (ENGLISH, "### Options", "### Answer")):
        block = section.split(options, 1)[1].split("###", 1)[0]
        lines = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(lines) == 3 and section.split(answer, 1)[1].split("###", 1)[0].strip() == "1"
        assert max(map(len, lines)) < 1.3 * min(map(len, lines))


def test_lab_is_wired_in_and_its_texts_exist() -> None:
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (APP / "L10n.swift").read_text(encoding="utf-8")
    assert 'moduleResource == "build_your_language_model"' in views and "TinyModelLab()" in views
    keys = set(re.findall(r'text\("(lab\.tiny\.[A-Za-z0-9]+)"\)', views))
    assert keys
    for key in keys:
        assert re.search(rf'"{re.escape(key)}": \("[^"]+", "[^"]+"\)', strings), key
    assert len(re.findall(r'^\s*"lab\.tiny\.title":', strings, re.M)) == 1
    roadmap = (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
    assert "lesson:build_your_language_model" in roadmap.split("## Продвинутый уровень / Advanced", 1)[1]
    assert "verify_tiny_language_model.swift" in (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    for link in ("1706.03762", "1412.6980", "optimization/adam", "preliminaries/autograd"):
        assert link in SOURCES
    assert "tiny_language_model.py" in RUSSIAN and "tiny_language_model.py" in ENGLISH


def test_layer_normalization_gradient_is_exact_even_for_a_small_spread() -> None:
    """Разброс σ входит дважды: значение делится на σ + ε, а изменение σ считается от σ.
    При малом σ старая формула ошибалась на ε/σ (здесь около 1 %), независимо от текстов курса.
    The spread enters twice; with a small σ the old formula was off by ε/σ, whatever the course text."""
    program = _loaded()
    Tensor, normalize = program["Tensor"], program["normalize"]
    rows = [[0.3, 0.3011, 0.2992, 0.3004], [1.0, -2.0, 0.5, 3.0]]
    upstream = [[0.7, -1.1, 0.4, 0.25], [-0.3, 0.9, 1.2, -0.6]]

    def loss(data):
        out = normalize(Tensor([row[:] for row in data])).data
        return sum(u * v for ur, vr in zip(upstream, out) for u, v in zip(ur, vr))

    source = Tensor([row[:] for row in rows])
    normalize(source).back(upstream)
    for r, row in enumerate(rows):
        for c in range(len(row)):
            up = [line[:] for line in rows]
            down = [line[:] for line in rows]
            up[r][c] += 1e-7
            down[r][c] -= 1e-7
            numeric = (loss(up) - loss(down)) / 2e-7
            assert math.isclose(source.grad[r][c], numeric, rel_tol=1e-5, abs_tol=1e-4), (r, c, source.grad[r][c], numeric)
