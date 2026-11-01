from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
APP_ROOT = ROOT / "macOS" / "ColiDev"
HEAT = ROOT / "02_Areas" / "Physics" / "lessons" / "temperature_and_heat.md"
MESSAGE = ROOT / "02_Areas" / "English" / "lessons" / "short_message_to_a_friend.md"
WATER_SPECIFIC_HEAT = 4186


def _sections(markdown: str) -> tuple[str, str]:
    russian = markdown.split("## Русский", 1)[1].split("## English", 1)[0]
    english = markdown.split("## English", 1)[1].split("## Sources", 1)[0]
    return russian, english


def _first_option_and_answer(section: str, answer_heading: str, options_heading: str) -> tuple[str, str]:
    answer = section.split(answer_heading, 1)[1].split("###", 1)[0].strip()
    option = section.split(options_heading, 1)[1].split("- ", 2)[1].splitlines()[0]
    return answer, option


def _strings() -> dict[str, tuple[str, str]]:
    text = (APP_ROOT / "App" / "L10n.swift").read_text(encoding="utf-8")
    return {key: (ru, en) for key, ru, en in re.findall(r'^\s*"([^"]+)": \("([^"]*)", "([^"]*)"\)', text, re.MULTILINE)}


def test_every_foundations_topic_now_links_a_lesson() -> None:
    gaps = []
    for subject in ("Mathematics", "English", "Physics", "Chemistry", "Biology", "Zoology", "Programming"):
        roadmap = (ROOT / "02_Areas" / subject / "curriculum.md").read_text(encoding="utf-8")
        foundations = roadmap.split("## База / Foundations", 1)[1].split("\n## ", 1)[0]
        for line in foundations.splitlines():
            if line.startswith("|") and not line.startswith("|---") and "Модуль / Module" not in line and "lesson:" not in line:
                gaps.append((subject, line.split("|")[1].strip()))
    assert gaps == []


def test_heat_lesson_numbers_follow_q_equals_mc_delta_t() -> None:
    assert (1 * 20 + 1 * 80) / 2 == 50
    assert (2 * 20 + 1 * 80) / 3 == 40
    assert 1 * WATER_SPECIFIC_HEAT * 30 == 125_580

    russian, english = _sections(HEAT.read_text(encoding="utf-8"))
    assert "125 580 Дж" in russian and "125,580 J" in english
    assert "50 °C" in russian and "40 °C" in russian
    answer, option = _first_option_and_answer(russian, "### Ответ", "### Варианты")
    assert (answer, option) == ("1", "50 °C")
    answer, option = _first_option_and_answer(english, "### Answer", "### Options")
    assert (answer, option) == ("1", "50 °C")

    model = (APP_ROOT / "App" / "HeatMixing.swift").read_text(encoding="utf-8")
    assert "static let waterSpecificHeat = 4186.0" in model
    assert "50 °C и 40 °C" in _strings()["lab.heat.challenge"][0]


def test_message_lesson_and_lab_share_the_friendly_structure() -> None:
    markdown = MESSAGE.read_text(encoding="utf-8")
    russian, english = _sections(markdown)
    for section in (russian, english):
        assert "`Hi Anna,`" in section
        assert "`See you soon!`" in section
        assert "`Yours faithfully,`" in section
    answer, option = _first_option_and_answer(russian, "### Ответ", "### Варианты")
    assert (answer, option) == ("1", "`See you soon! Max`")
    answer, option = _first_option_and_answer(english, "### Answer", "### Options")
    assert (answer, option) == ("1", "`See you soon! Max`")

    model = (APP_ROOT / "App" / "ShortMessagePractice.swift").read_text(encoding="utf-8")
    strings = _strings()
    steps = re.findall(r'promptKey: "(lab\.message\.[a-z]+)\.prompt".*?correctOptionIndex: (\d)', model, re.DOTALL)
    assert [name.split(".")[-1] for name, _ in steps] == ["greeting", "reason", "details", "wish", "closing"]
    correct = {name: strings[f"{name}.option{index}"][1] for name, index in steps}
    assert correct["lab.message.greeting"] == "Hi Anna,"
    assert correct["lab.message.reason"] in markdown
    assert correct["lab.message.details"] in markdown
    assert correct["lab.message.wish"] in markdown
    assert correct["lab.message.closing"] == "See you soon! Max"
    for name, _ in steps:
        for index in range(3):
            ru, en = strings[f"{name}.option{index}"]
            assert ru == en, "English example phrases stay in English in both interface languages"


def test_new_foundation_labs_are_wired_into_the_app_project_and_ci() -> None:
    views = (APP_ROOT / "App" / "LearningViews.swift").read_text(encoding="utf-8")
    project = (APP_ROOT / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    strings = set(_strings())

    assert 'moduleResource == "temperature_and_heat"' in views and "HeatMixingLab()" in views
    assert 'moduleResource == "short_message_to_a_friend"' in views and "ShortMessageLab()" in views
    assert "HeatMixing.swift in Sources" in project and "ShortMessagePractice.swift in Sources" in project
    assert "scripts/verify_heat_mixing.swift" in workflow and "scripts/verify_short_message.swift" in workflow
    for prefix in ("lab.heat.", "lab.message."):
        used = {key for key in re.findall(r'(?<!accessibilityIdentifier\()(?<!identifier: )"(lab\.(?:heat|message)\.[A-Za-z.0-9]+)"', views) if key.startswith(prefix)}
        assert used and used <= strings, used - strings
    model = (APP_ROOT / "App" / "ShortMessagePractice.swift").read_text(encoding="utf-8")
    assert set(re.findall(r'"(lab\.message\.[a-z]+\.[a-z0-9]+)"', model)) <= strings
