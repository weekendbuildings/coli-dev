"""The embeddings lesson: its numbers, program and lab agree. / Урок об эмбеддингах: числа, программа и тренажёр согласованы."""
from __future__ import annotations

import contextlib
import io
import math
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LESSON = ROOT / "02_Areas" / "Programming" / "lessons" / "embeddings_and_similarity.md"
APP = ROOT / "macOS" / "ColiDev" / "App"
TEXT = LESSON.read_text(encoding="utf-8")
RUSSIAN = TEXT.split("## Русский", 1)[1].split("## English", 1)[0]
ENGLISH = TEXT.split("## English", 1)[1].split("## Sources", 1)[0]
SOURCES = TEXT.split("## Sources", 1)[1]


def _run_program(section: str, sentences_extra: str = "") -> tuple[str, dict]:
    code = re.search(r"```python\n(.*?)```", section, re.S).group(1)
    if sentences_extra:
        code = code.replace('stands here"]', f'stands here", "{sentences_extra}"]')
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
    numbers = re.findall(r"-?\d+\.?\d*", re.search(r"```text\n(.*?)```", RUSSIAN, re.S).group(1))
    assert numbers == re.findall(r"-?\d+\.?\d*", re.search(r"```text\n(.*?)```", ENGLISH, re.S).group(1)), "the same model in both languages"
    assert round(math.log(16), 3) == 2.773


def test_the_program_trains_what_the_text_claims() -> None:
    _, program = _run_program(ENGLISH)
    cosine = program["cosine"]
    assert cosine("cat", "dog") > 0.99 and cosine("cat", "horse") > 0.99 and cosine("car", "bus") > 0.99
    assert abs(cosine("cat", "car")) < 0.05
    assert len(program["vocab"]) == 16 and len(program["vocab"]) * program["size"] == 48
    for number in ("0,01", "−0,99", "2,758", "48"):
        assert number in RUSSIAN
    for number in ("0.01", "−0.99", "2.758", "48"):
        assert number in ENGLISH


def test_worked_cosine_numbers() -> None:
    a, b, c = (1, 2, 2), (2, 1, 2), (-2, 1, 0)
    dot = lambda x, y: sum(p * q for p, q in zip(x, y))
    assert dot(a, b) == 8 and dot(a, a) == 9 and dot(b, b) == 9 and dot(a, c) == 0
    assert round(8 / 9, 3) == 0.889
    assert "0,889" in RUSSIAN and "0.889" in ENGLISH


def test_exercise_has_a_real_answer() -> None:
    _, plain = _run_program(ENGLISH)
    _, changed = _run_program(ENGLISH, "cat drives fast")
    assert changed["cosine"]("cat", "car") > plain["cosine"]("cat", "car") + 0.1


def test_one_hot_vectors_have_zero_similarity() -> None:
    first, second = [0, 1, 0, 0], [0, 0, 1, 0]
    assert sum(a * b for a, b in zip(first, second)) == 0


def test_quiz_has_the_right_answer() -> None:
    for section, options, answer, word in ((RUSSIAN, "### Варианты", "### Ответ", "сосед"), (ENGLISH, "### Options", "### Answer", "neighbours")):
        block = section.split(options, 1)[1].split("###", 1)[0]
        lines = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(lines) == 3 and section.split(answer, 1)[1].split("###", 1)[0].strip() == "2"
        assert word in lines[1].lower()
        assert max(map(len, lines)) < 1.3 * min(map(len, lines))


def test_lab_uses_the_lessons_model_and_is_wired_in() -> None:
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (APP / "L10n.swift").read_text(encoding="utf-8")
    model = (APP / "WordEmbedding.swift").read_text(encoding="utf-8")
    assert 'moduleResource == "embeddings_and_similarity"' in views and "EmbeddingSpaceLab()" in views
    for section, name in ((RUSSIAN, "sentencesRussian"), (ENGLISH, "sentencesEnglish")):
        _, program = _run_program(section)
        block = model.split(f"static let {name} = [", 1)[1].split("]", 1)[0]
        assert re.findall(r'"([^"]+)"', block) == program["sentences"], name
    assert "static let seed = 12345" in model and "state * 16807 % 2147483647" in model
    keys = set(re.findall(r'text\("(lab\.embed\.[A-Za-z0-9]+)"\)', views))
    assert keys
    for key in keys:
        assert re.search(rf'"{re.escape(key)}": \("[^"]+", "[^"]+"\)', strings), key
    assert len(re.findall(r'^\s*"lab\.embed\.title":', strings, re.M)) == 1
    roadmap = (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
    assert "lesson:embeddings_and_similarity" in roadmap.split("## Продвинутый уровень / Advanced", 1)[1]
    assert "verify_word_embedding.swift" in (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    for link in ("1301.3781", "word2vec", "Distributional_semantics", "1605.07766", "1607.06520"):
        assert link in SOURCES
