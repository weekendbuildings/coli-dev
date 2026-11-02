"""The consciousness lesson: careful claims, a working program, and a wired lab. / Урок о сознании: осторожные утверждения, программа и тренажёр."""
from __future__ import annotations

import contextlib
import io
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LESSON = ROOT / "02_Areas" / "Programming" / "lessons" / "consciousness_known_and_unknown.md"
APP = ROOT / "macOS" / "ColiDev" / "App"
TEXT = LESSON.read_text(encoding="utf-8")
RUSSIAN = TEXT.split("## Русский", 1)[1].split("## English", 1)[0]
ENGLISH = TEXT.split("## English", 1)[1].split("## Sources", 1)[0]
SOURCES = TEXT.split("## Sources", 1)[1]


def _run_program(section: str, text: str | None = None) -> tuple[str, dict]:
    code = re.search(r"```python\n(.*?)```", section, re.S).group(1)
    if text:
        code = re.sub(r'^text = ".*"$', f'text = "{text}"', code, flags=re.M)
    namespace: dict = {}
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        exec(code, namespace)
    return output.getvalue(), namespace


def test_program_prints_what_the_lesson_says_in_both_languages() -> None:
    for section, word in ((RUSSIAN, "чувствую"), (ENGLISH, "feel")):
        output, program = _run_program(section)
        printed = re.search(r"```text\n(.*?)```", section, re.S).group(1).strip()
        assert output.strip() == printed
        assert word in output
        assert str(len(program["pairs"])) in section


def test_the_table_has_no_feelings_of_its_own_to_report() -> None:
    # The exercise: with other sentences the very same table writes about the other subject.
    output, _ = _run_program(ENGLISH, "the sky is grey . the rain is cold . the sky is clear .")
    assert "feel" not in output and "sky" in output


def test_the_lesson_makes_no_overclaims() -> None:
    # The honest frame of the lesson. / Честная рамка урока.
    assert "рабочую гипотезу" in RUSSIAN and "working hypothesis" in ENGLISH
    assert "спорная гипотеза" in RUSSIAN and "disputed hypothesis" in ENGLISH
    assert "не является оценкой экспертов" in RUSSIAN and "not an expert assessment" in ENGLISH
    assert "открытой исследовательской задачей" in RUSSIAN and "open research problem" in ENGLISH
    for section in (RUSSIAN, ENGLISH):
        assert "256" in section and "2025" in section and "2023" in section and "1995" in section
    # The Butlin report has 19 authors: the five named and 14 others.
    assert "19 авторов" in RUSSIAN and "19 authors" in ENGLISH and "14 others" in SOURCES


def test_quiz_rejects_both_overclaims() -> None:
    for section, options, answer in ((RUSSIAN, "### Варианты", "### Ответ"), (ENGLISH, "### Options", "### Answer")):
        block = section.split(options, 1)[1].split("###", 1)[0]
        lines = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(lines) == 3 and section.split(answer, 1)[1].split("###", 1)[0].strip() == "2"
        assert max(map(len, lines)) < 1.3 * min(map(len, lines))


def test_lab_covers_every_indicator_and_is_wired_in() -> None:
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (APP / "L10n.swift").read_text(encoding="utf-8")
    model = (APP / "ConsciousnessIndicators.swift").read_text(encoding="utf-8")
    assert 'moduleResource == "consciousness_known_and_unknown"' in views and "ConsciousnessIndicatorLab()" in views
    indicators = re.findall(r'"((?:rpt|gwt|hot|ast|pp|ae)\d)"', model)
    assert len(indicators) == 14
    for indicator in indicators:
        for suffix in ("", "Why"):
            key = f"lab.mind.{indicator}{suffix}"
            assert re.search(rf'"{re.escape(key)}": \("[^"]+", "[^"]+"\)', strings), key
    for key in set(re.findall(r'text\("(lab\.mind\.[A-Za-z0-9]+)"\)', views)):
        assert re.search(rf'"{re.escape(key)}": \("[^"]+", "[^"]+"\)', strings), key
    assert len(re.findall(r'^\s*"lab\.mind\.title":', strings, re.M)) == 1
    roadmap = (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
    assert "lesson:consciousness_known_and_unknown" in roadmap.split("## Продвинутый уровень / Advanced", 1)[1]
    assert "verify_consciousness_indicators.swift" in (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    for link in ("2308.08708", "plato.stanford.edu/entries/consciousness", "s41583-022-00587-4", "arc-cogitate"):
        assert link in SOURCES
