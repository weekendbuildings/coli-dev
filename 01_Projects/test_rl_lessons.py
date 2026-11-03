"""The reinforcement learning lessons: programs, numbers and labs agree. / Уроки обучения с подкреплением: программы, числа и тренажёры согласованы."""
from __future__ import annotations

import re
from pathlib import Path

import pytest

from lesson_program_replay import output_blocks, replay, sections

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "macOS" / "ColiDev" / "App"
VIEWS = (APP / "LearningViews.swift").read_text(encoding="utf-8")
STRINGS = (APP / "L10n.swift").read_text(encoding="utf-8")
ROADMAP = (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
WORKFLOW = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
CASES = [
    ("rl_bandits", "BanditLab", "bandit", ("the-book-2nd", "A:1013689704352", "davidsilver.uk")),
    ("rl_mdp_bellman", "ValueTowersLab", "mdp", ("the-book-2nd", "davidsilver.uk", "cs234")),
    ("rl_q_learning", "QMazeLab", "qmaze", ("the-book-2nd", "BF00992698", "1312.5602", "deep-rl-course")),
    ("rl_policy_gradient", "CorridorLab", "corridor", ("the-book-2nd", "BF00992696", "1707.06347", "2203.02155", "rlhfbook", "rl_intro3")),
]


def lesson(name: str) -> str:
    return (ROOT / "02_Areas" / "Programming" / "lessons" / f"{name}.md").read_text(encoding="utf-8")


@pytest.mark.parametrize("name", [case[0] for case in CASES])
def test_programs_print_what_the_lesson_says(name: str) -> None:
    for section in sections(lesson(name)).values():
        assert replay(section, {"calls": {}}) == output_blocks(section)


@pytest.mark.parametrize("name", [case[0] for case in CASES])
def test_quiz_is_fair(name: str) -> None:
    parts = sections(lesson(name))
    for section, options, answer in ((parts["ru"], "### Варианты", "### Ответ"), (parts["en"], "### Options", "### Answer")):
        block = section.split(options, 1)[1].split("###", 1)[0]
        lines = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(lines) == 3 and section.split(answer, 1)[1].split("###", 1)[0].strip() == "1"
        assert max(map(len, lines)) < 1.25 * min(map(len, lines))


@pytest.mark.parametrize("name,lab,prefix,links", CASES)
def test_lab_is_wired_in(name: str, lab: str, prefix: str, links: tuple[str, ...]) -> None:
    assert f'moduleResource == "{name}"' in VIEWS and f"{lab}()" in VIEWS
    body = VIEWS.split(f"private struct {lab}: View {{", 1)[1].split("// MARK:", 1)[0]
    assert "LabChallenge(" in body and "LabExplainer(" in body
    for key in set(re.findall(rf'text\("(lab\.{prefix}\.[A-Za-z0-9.]+)"\)', body)):
        assert len(re.findall(rf'"{re.escape(key)}": \("', STRINGS)) == 1, key
    assert f"lesson:{name}" in ROADMAP and "verify_rl_labs.swift" in WORKFLOW
    sources = lesson(name).split("## Sources", 1)[1]
    for link in links:
        assert link in sources, link


def test_bandit_numbers_in_the_text() -> None:
    parts = sections(lesson("rl_bandits"))
    game, table = output_blocks(parts["en"])
    assert game.split("\n")[0] == "(4, 0, 0.0, 0.0)" and "counts [0, 7, 0, 0, 1]" in game
    for row in ("greedy 21.2 210.2 630.2 0.32", "eps 0.1 13.4 52.4 112.2 0.88", "eps 0.5 18.6 156.0 455.5 0.59", "UCB1 18.7 80.6 126.1 0.83"):
        assert row in table, row
    assert round(0.3 * 3000) == 900 and round(0.03 * 2000) == 60
    assert round((2 * 4.605 / 4) ** 0.5, 2) == 1.52 and round((9.21 / 50) ** 0.5, 2) == 0.43
    for number in ("455,5", "59,8", "45,5", "1,52", "0,43"):
        assert number in parts["ru"], number


def test_bellman_numbers_in_the_text() -> None:
    parts = sections(lesson("rl_mdp_bellman"))
    first, second, third, fourth = output_blocks(parts["en"])
    assert first.split("sweep 1\n")[1].split("\n")[3].endswith("1.00")
    assert second.startswith("sweeps 10") and "  0.52   0.00" in second
    assert "0.0 0.523 10 7 3" in third and "0.2 0.065 26 9 2" in third and "0.3 -0.112 42 waits at the wall -" in third
    assert third.rstrip().endswith("< P P P P G")
    assert "random policy V(S) -0.936" in fourth and "gamma 0.5 sweeps 12 V(S) -0.08" in fourth
    assert round(0.8 * (-0.04 + 0.95 * 0.82) + 0.1 * (-0.04 + 0.95 * 0.67) - 0.1, 2) == 0.55
    for number in ("−0,936", "0,523", "0,55", "0,19"):
        assert number in parts["ru"], number
    assert "ValueTowersSceneView" in VIEWS and "LabSceneView" in (APP / "ValueTowers3DView.swift").read_text(encoding="utf-8")


def test_q_learning_numbers_in_the_text() -> None:
    parts = sections(lesson("rl_q_learning"))
    first, second = output_blocks(parts["en"])
    assert "route steps 7 Q at start 0.523" in first
    assert "Q-learning 0.208 78.9 7.0 3.0" in second and "SARSA 0.269 63.0 9.9 2.63" in second
    assert round(0.5 * 0.72, 2) == 0.36 and round(0.36 + 0.5 * 0.36, 2) == 0.54
    for number in ("0,523", "78,9", "0,269", "0,208"):
        assert number in parts["ru"], number


def test_policy_gradient_numbers_in_the_text() -> None:
    parts = sections(lesson("rl_policy_gradient"))
    first, second, third = output_blocks(parts["en"])
    assert "best p 0.5858 -11.657" in first and "0.5 -12.0" in first
    assert "plain 2^-9, one run: [0.1, 1.0, 1.0, 1.0]" in third
    rows = {row.split(" [")[0]: float(row.split(" p ")[1].split()[0]) for row in third.split("\n")[:3]}
    assert 0.35 < rows["plain 2^-13"] < 0.45 and 0.45 < rows["plain 2^-12"] < 0.56 and 0.55 < rows["baseline 2^-10"] < 0.63
    for number in ("−11,66", "0,586", "0,55", "0,45"):
        assert number in parts["ru"], number
    for row in second.split("\n"):
        p, value = row.split()
        assert abs(-2 * (2 - float(p)) / (float(p) * (1 - float(p))) - float(value)) < 1, row
