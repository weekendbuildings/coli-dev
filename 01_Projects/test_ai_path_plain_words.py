"""Every AI path lesson opens with a plain-words block, and every lesson reference points to a real lesson.

Каждый урок пути ИИ начинается с блока «Простыми словами», а каждая ссылка «урок (шаг N)» ведёт на настоящий урок.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH_SWIFT = ROOT / "macOS/ColiDev/App/AIPath.swift"


def _path_lessons() -> list[tuple[int, str, Path]]:
    source = PATH_SWIFT.read_text(encoding="utf-8")
    lessons = []
    for step in re.finditer(r"AIPathStep\(number: (\d+), lessons: \[(.*?)\]\)", source, re.S):
        for kind, resource in re.findall(r"(math|code)\(\"([a-z_0-9]+)\"\)", step.group(2)):
            folder = "Mathematics" if kind == "math" else "Programming"
            lessons.append((int(step.group(1)), resource, ROOT / f"02_Areas/{folder}/lessons/{resource}.md"))
    return lessons


def _titles() -> dict[int, list[tuple[str, str]]]:
    by_step: dict[int, list[tuple[str, str]]] = {}
    for step, _, path in _path_lessons():
        if path.exists():
            title = re.search(r"^# (.*)$", path.read_text(encoding="utf-8"), re.M).group(1)
            ru, _, en = title.partition(" / ")
            by_step.setdefault(step, []).append((ru.strip(), en.strip()))
    return by_step


def _part(text: str, heading: str) -> str:
    match = re.search(rf"^## {heading}\n(.*?)(?=^## )", text, re.S | re.M)
    assert match, heading
    return match.group(1)


def test_every_written_path_lesson_opens_with_plain_words() -> None:
    written = [(step, resource, path) for step, resource, path in _path_lessons() if path.exists()]
    assert len(written) >= 59
    for _, resource, path in written:
        text = path.read_text(encoding="utf-8")
        for heading, block, before, unclear in (
            ("Русский", "### Простыми словами", "**Что нужно знать до.**", "**Если непонятно.**"),
            ("English", "### In plain words", "**What to know first.**", "**If something is unclear.**"),
        ):
            part = _part(text, heading)
            assert part.lstrip().startswith(block), (resource, heading)
            body = part.split(block, 1)[1].split("\n### ", 1)[0]
            assert before in body and unclear in body, (resource, heading)
            plain = body.split(before, 1)[0].strip()
            sentences = [s for s in re.split(r"(?<=[.!?])\s+", plain) if s]
            assert 3 <= len(sentences) <= 7, (resource, heading, len(sentences))


def test_step_references_name_real_lessons_at_that_step() -> None:
    titles = _titles()
    checked = 0
    for _, resource, path in _path_lessons():
        if not path.exists() or resource == "ai_path_glossary":  # the glossary has its own test
            continue
        text = path.read_text(encoding="utf-8")
        for index, (heading, word) in enumerate((("Русский", "шаг"), ("English", "step"))):
            part = _part(text, heading)
            for name, step in re.findall(rf"«([^»]+)»(?:, | \(){word} (\d+)", part):
                names = [pair[index] for pair in titles.get(int(step), [])]
                assert any(n == name or n.startswith(name) for n in names), (resource, name, step)
                checked += 1
    assert checked >= 150


def test_new_lesson_titles_used_by_the_glossary_match_once_written() -> None:
    glossary = (ROOT / "02_Areas/Programming/lessons/ai_path_glossary.md").read_text(encoding="utf-8")
    titles = _titles()
    for index, (heading, word) in enumerate((("Русский", "шаг"), ("English", "step"))):
        part = _part(glossary, heading)
        entries = re.findall(rf"^- \*\*(.+?)\.\*\* .+ (?:Подробно|In detail): «([^»]+)», {word} (\d+)\.$", part, re.M)
        assert len(entries) >= 100
        for term, name, step in entries:
            names = [pair[index] for pair in titles.get(int(step), [])]
            if names:
                # Lessons not written yet are allowed; written ones must match exactly.
                written = any(n == name for n in names)
                missing = any(not (ROOT / f"02_Areas/Programming/lessons/{r}.md").exists()
                              for s, r, _ in _path_lessons() if s == int(step))
                assert written or missing, (term, name, step)
