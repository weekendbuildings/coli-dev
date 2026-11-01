"""Every lab must show real text and give the learner a task. / Каждый тренажёр показывает настоящий текст и даёт задание."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "macOS" / "ColiDev" / "App"
VIEWS = (APP / "LearningViews.swift").read_text(encoding="utf-8")
L10N = (APP / "L10n.swift").read_text(encoding="utf-8")
LAB_BOUNDARY = re.compile(r"\n(?=(?:private |fileprivate )?(?:struct|enum|final class|class|extension) )")


def _defined_keys() -> set[str]:
    # Some lines of the dictionary hold several keys, so the match is not anchored to the line start.
    return set(re.findall(r'"([^"\\]+)": \(', L10N))


def _lab_source(name: str) -> str:
    start = VIEWS.index(f"private struct {name}: View {{")
    end = LAB_BOUNDARY.search(VIEWS, start + 10)
    return VIEWS[start : end.start() if end else len(VIEWS)]


def _routed_labs() -> list[tuple[str, str]]:
    routes = re.findall(r'subject == \.(\w+), moduleResource == "[^"]+" \{\n\s+(\w+)\(', VIEWS)
    return sorted({(subject, name) for subject, name in routes if f"private struct {name}: View {{" in VIEWS})


def test_every_literal_text_key_in_the_labs_is_defined() -> None:
    used = set(re.findall(r'\btext\("([^"\\]+)"\)', VIEWS)) | set(re.findall(r'L10n\.text\("([^"\\]+)"', VIEWS))
    missing = sorted(used - _defined_keys())
    assert not missing, f"Keys would show as raw text / Ключи показались бы сырым текстом: {missing}"


def test_every_lab_outside_paused_english_has_a_task() -> None:
    labs = _routed_labs()
    assert len(labs) > 40
    without_task = [name for subject, name in labs if subject != "english" and "LabChallenge(" not in _lab_source(name)]
    assert not without_task, f"Labs without a task / Тренажёры без задания: {without_task}"


def test_osmosis_water_moves_toward_more_solute() -> None:
    model = (APP / "AnswerChoiceOrder.swift").read_text(encoding="utf-8")
    assert "if insideSolute > outsideSolute { return .waterEntersCell }" in model
    assert "if outsideSolute > insideSolute { return .waterLeavesCell }" in model
