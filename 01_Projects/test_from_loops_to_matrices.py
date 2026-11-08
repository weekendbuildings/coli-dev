"""From loops to matrices: the NumPy model is the same model, and the lesson's numbers are real.
От циклов к матрицам: модель на NumPy та же самая, а числа урока настоящие."""

from __future__ import annotations

import contextlib
import io
import re
import subprocess
import sys
from pathlib import Path

import pytest

np = pytest.importorskip("numpy")

ROOT = Path(__file__).resolve().parents[1]
LESSON = (ROOT / "02_Areas" / "Programming" / "lessons" / "from_loops_to_matrices.md").read_text(encoding="utf-8")
RUSSIAN = LESSON.split("## Русский", 1)[1].split("## English", 1)[0]
ENGLISH = LESSON.split("## English", 1)[1].split("## Sources", 1)[0]
LOG = (ROOT / "02_Areas" / "Programming" / "resources" / "tiny_language_model_numpy_log.txt").read_text(encoding="utf-8")
MODELS = (ROOT / "macOS" / "ColiDev" / "App" / "LessonsFinalModels.swift").read_text(encoding="utf-8")
CONFIG = "SIZE, HEADS, BLOCKS, LENGTH, BATCH = 32, 2, 2, 32, 8"


def _load(name: str) -> dict:
    source = (ROOT / "01_Projects" / name).read_text(encoding="utf-8")
    assert CONFIG in source
    source = source.replace(CONFIG, "SIZE, HEADS, BLOCKS, LENGTH, BATCH = 8, 2, 2, 8, 2")
    namespace: dict = {"__name__": "lesson_check"}
    saved = sys.argv
    sys.argv = ["tiny", str(ROOT / "02_Areas"), "0"]
    try:
        with contextlib.redirect_stdout(io.StringIO()):
            exec(source, namespace)
    finally:
        sys.argv = saved
    return namespace


def _outputs(section: str) -> list[str]:
    return re.findall(r"```output\n(.*?)```", section, re.S)


def test_numpy_model_matches_the_plain_model_to_rounding() -> None:
    plain, fast = _load("tiny_language_model.py"), _load("tiny_language_model_numpy.py")
    for a, b in zip(plain["parameters"], fast["parameters"]):
        assert np.array_equal(np.array(a.data), b), "the starting weights must be the same numbers"
    x, y = plain["piece"](plain["train"])
    assert (x, y) == fast["piece"](fast["train"]), "both programs must draw the same pieces"
    logits = plain["forward"](x)
    loss, seed = plain["cross_entropy"](logits, y)
    for p in plain["parameters"]:
        p.grad = None
    plain["backward"](logits, seed)
    fast_logits, state = fast["forward"](x)
    fast_loss, fast_seed = fast["cross_entropy"](fast_logits, y)
    grads = fast["backward"](fast_seed, state, [np.zeros_like(p) for p in fast["parameters"]])
    assert np.abs(np.array(logits.data) - fast_logits).max() < 1e-12
    assert abs(loss - fast_loss) < 1e-12
    for p, g in zip(plain["parameters"], grads):
        expected = np.zeros_like(g) if p.grad is None else np.array(p.grad)
        assert np.abs(expected - g).max() < 1e-12


def test_three_adam_steps_stay_the_same() -> None:
    plain, fast = _load("tiny_language_model.py"), _load("tiny_language_model_numpy.py")
    for step in range(1, 4):
        for p in plain["parameters"]:
            p.grad = None
        for _ in range(plain["BATCH"]):
            x, y = plain["piece"](plain["train"])
            logits = plain["forward"](x)
            _, seed = plain["cross_entropy"](logits, y)
            plain["backward"](logits, [[v / plain["BATCH"] for v in row] for row in seed])
        plain["adam_step"](step, plain["RATE"])
        fast["train_step"](step, fast["RATE"])
    worst = max(np.abs(np.array(a.data) - b).max() for a, b in zip(plain["parameters"], fast["parameters"]))
    assert worst < 1e-12


def test_numpy_gradient_matches_numerical_slopes_for_every_weight_kind() -> None:
    fast = _load("tiny_language_model_numpy.py")
    x, y = fast["piece"](fast["train"])
    logits, state = fast["forward"](x)
    _, seed = fast["cross_entropy"](logits, y)
    grads = fast["backward"](seed, state, [np.zeros_like(p) for p in fast["parameters"]])
    for p, g in zip(fast["parameters"], grads):
        r, c = np.unravel_index(int(np.argmax(np.abs(g))), g.shape)
        keep = p[r, c]
        p[r, c] = keep + 1e-6
        up = fast["cross_entropy"](fast["forward"](x)[0], y)[0]
        p[r, c] = keep - 1e-6
        down = fast["cross_entropy"](fast["forward"](x)[0], y)[0]
        p[r, c] = keep
        assert abs((up - down) / 2e-6 - g[r, c]) < 1e-6


def test_lesson_shows_the_recorded_training_log_in_both_languages() -> None:
    for section in (RUSSIAN, ENGLISH):
        assert _outputs(section)[1].strip() == LOG.strip()
    assert "seconds 22.0" in LOG and "random 5.069 pairs 2.652" in LOG and "best 2.247 at step 6000" in LOG
    assert "22 секунды" in RUSSIAN and "47,2 минуты" in RUSSIAN and "2,247 против 2,652" in RUSSIAN
    assert "22 seconds" in ENGLISH and "47.2 minutes" in ENGLISH and "2.247 against 2.652" in ENGLISH
    assert round(47.2 * 60 / 22.0) == 129 and "примерно в 130 раз" in RUSSIAN and "about 130 times" in ENGLISH


def test_speed_table_matches_the_lab_and_the_code_really_agrees() -> None:
    table = _outputs(RUSSIAN)[0].strip().splitlines()[1:]
    assert table == _outputs(ENGLISH)[0].strip().splitlines()[1:]
    sizes = [int(row.split()[0]) for row in table]
    loops = [float(row.split()[2]) for row in table]
    fast = [float(row.split()[3]) for row in table]
    faster = [int(row.split()[4]) for row in table]
    assert all(row.split()[5] == "True" for row in table)
    swift = MODELS.split("enum LoopsMatrices", 1)[1]
    def array(name: str) -> list[float]:
        return [float(v) for v in re.search(rf"static let {name}: \[\w+\] = \[([^\]]+)\]", swift).group(1).split(",")]
    assert array("measuredSizes") == sizes and array("loopMilliseconds") == loops
    assert array("numpyMilliseconds") == fast and array("measuredTimesFaster") == faster
    code = re.search(r"```python\n(import time.*?)```", RUSSIAN, re.S).group(1)
    code = code.replace("for n in (16, 32, 64, 128, 256):", "for n in (8, 16, 24):").replace("200)", "5)")
    result = subprocess.run([sys.executable, "-c", code], capture_output=True, text=True, timeout=60)
    assert result.returncode == 0, result.stderr
    assert all(line.split()[-1] == "True" for line in result.stdout.strip().splitlines()[1:])


def test_question_is_about_why_small_matrices_gain_less() -> None:
    assert "по 32 строки и меньше" in RUSSIAN and "32 rows or fewer" in ENGLISH
    assert re.search(r"### Ответ\n\n1\n", RUSSIAN) and re.search(r"### Answer\n\n1\n", ENGLISH)
