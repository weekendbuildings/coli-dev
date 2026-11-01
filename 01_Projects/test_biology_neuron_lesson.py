from __future__ import annotations

import re
from pathlib import Path

from trusted_sources import TrustedSourceMonitor


ROOT = Path(__file__).resolve().parents[1]
LESSON = ROOT / "02_Areas" / "Biology" / "lessons" / "neurons_and_action_potentials.md"
APP_ROOT = ROOT / "macOS" / "ColiDev"
OPENSTAX_SECTION = "https://openstax.org/books/biology-2e/pages/35-2-how-neurons-communicate"


def _sections(markdown: str) -> tuple[str, str]:
    russian = markdown.split("## Русский", 1)[1].split("## English", 1)[0]
    english = markdown.split("## English", 1)[1].split("## Sources", 1)[0]
    return russian, english


def test_neuron_lesson_is_routed_from_the_biology_roadmap() -> None:
    roadmap = (ROOT / "02_Areas" / "Biology" / "curriculum.md").read_text(encoding="utf-8")
    intermediate = roadmap.split("## Углубление / Intermediate", 1)[1].split("## Продвинутый уровень", 1)[0]

    assert "lesson:neurons_and_action_potentials" in intermediate
    assert "lesson_id: biology.neurons_and_action_potentials" in LESSON.read_text(encoding="utf-8")


def test_lesson_values_match_the_swift_model() -> None:
    model = (APP_ROOT / "App" / "NeuronSignal.swift").read_text(encoding="utf-8")
    russian, english = _sections(LESSON.read_text(encoding="utf-8"))

    assert "static let restingPotential = -70.0" in model
    assert "static let thresholdPotential = -55.0" in model
    assert "static let peakPotential = 40.0" in model
    for section in (russian, english):
        assert "−70" in section
        assert "−55" in section
        assert "+40" in section
        assert "−60" in section


def test_answer_follows_from_threshold_and_all_or_none() -> None:
    russian, english = _sections(LESSON.read_text(encoding="utf-8"))

    assert russian.split("### Ответ", 1)[1].split("###", 1)[0].strip() == "1"
    assert english.split("### Answer", 1)[1].split("###", 1)[0].strip() == "1"
    first_russian_option = russian.split("### Варианты", 1)[1].split("- ", 2)[1]
    first_english_option = english.split("### Options", 1)[1].split("- ", 2)[1]
    assert "не возникает" in first_russian_option
    assert "no action potential" in first_english_option
    assert "всё или ничего" in russian
    assert "all-or-none" in english


def test_limits_keep_consciousness_out_of_the_model_claims() -> None:
    russian, english = _sections(LESSON.read_text(encoding="utf-8"))

    assert "сознание" in russian.split("### Границы модели", 1)[1]
    assert "consciousness" in english.split("### Limits", 1)[1]
    assert "вид" in russian.split("### Границы модели", 1)[1]
    assert "species" in english.split("### Limits", 1)[1]


def test_openstax_section_reaches_the_trusted_source_inventory() -> None:
    assert TrustedSourceMonitor._canonical_url(OPENSTAX_SECTION) == OPENSTAX_SECTION
    assert f"]({OPENSTAX_SECTION})" in LESSON.read_text(encoding="utf-8")


def test_neuron_lab_is_wired_into_the_app_project_and_ci() -> None:
    views = (APP_ROOT / "App" / "LearningViews.swift").read_text(encoding="utf-8")
    project = (APP_ROOT / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    strings = (APP_ROOT / "App" / "L10n.swift").read_text(encoding="utf-8")
    journey = (APP_ROOT / "App" / "ContentView.swift").read_text(encoding="utf-8")

    assert 'moduleResource == "neurons_and_action_potentials"' in views
    assert "NeuronSignalLab()" in views
    assert "NeuronSignal.swift in Sources" in project
    assert "scripts/verify_neuron_signal.swift" in workflow

    used_keys = set(re.findall(r'(?<!accessibilityIdentifier\()(?<!identifier: )"(lab\.neuron\.[A-Za-z]+)"', views))
    defined_keys = set(re.findall(r'^\s*"(lab\.neuron\.[A-Za-z]+)":', strings, re.MULTILINE))
    assert used_keys
    assert used_keys <= defined_keys

    brain_stage = journey.split('id: "brain_science"', 1)[1].split("),\n        .init(", 1)[0]
    assert "subjects: [.biology]" in brain_stage
