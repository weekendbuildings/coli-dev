from __future__ import annotations

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LESSON = ROOT / "02_Areas" / "Biology" / "lessons" / "synapses_and_signal_summation.md"
APP_ROOT = ROOT / "macOS" / "ColiDev"


def _sections(markdown: str) -> tuple[str, str]:
    russian = markdown.split("## Русский", 1)[1].split("## English", 1)[0]
    english = markdown.split("## English", 1)[1].split("## Sources", 1)[0]
    return russian, english


def _model_value(name: str) -> float:
    model = (APP_ROOT / "App" / "SynapticSummation.swift").read_text(encoding="utf-8")
    return float(re.search(rf"static let {name} = (-?[0-9.]+)", model).group(1))


def test_synapse_lesson_follows_the_neuron_lesson_in_the_biology_roadmap() -> None:
    roadmap = (ROOT / "02_Areas" / "Biology" / "curriculum.md").read_text(encoding="utf-8")
    intermediate = roadmap.split("## Углубление / Intermediate", 1)[1].split("## Продвинутый уровень", 1)[0]
    assert intermediate.index("lesson:neurons_and_action_potentials") < intermediate.index("lesson:synapses_and_signal_summation")


def test_question_arithmetic_matches_the_swift_model() -> None:
    rest = _model_value("restingPotential")
    threshold = _model_value("thresholdPotential")
    excitatory = _model_value("excitatoryStep")
    inhibitory = _model_value("inhibitoryStep")
    assert (rest, threshold, excitatory, inhibitory) == (-70, -55, 4, 4)

    total = rest + 5 * excitatory - 2 * inhibitory
    assert total == -58 and total < threshold
    minimum = next(n for n in range(0, 7) if rest + n * excitatory >= threshold)
    assert minimum == 4

    russian, english = _sections(LESSON.read_text(encoding="utf-8"))
    assert "−70 + 20 − 8 = −58 мВ" in russian and "минимум четыре" in russian
    assert "−70 + 20 − 8 = −58 mV" in english and "at least four" in english
    assert russian.split("### Ответ", 1)[1].split("###", 1)[0].strip() == "1"
    assert english.split("### Answer", 1)[1].split("###", 1)[0].strip() == "1"


def test_limits_mark_the_input_size_as_illustrative_and_keep_consciousness_out() -> None:
    russian, english = _sections(LESSON.read_text(encoding="utf-8"))
    ru_limits = russian.split("### Границы модели", 1)[1]
    en_limits = english.split("### Limits", 1)[1]
    assert "условная" in ru_limits and "сознание" in ru_limits
    assert "illustrative" in en_limits and "consciousness" in en_limits


def test_synapse_lab_is_wired_into_the_app_project_and_ci() -> None:
    views = (APP_ROOT / "App" / "LearningViews.swift").read_text(encoding="utf-8")
    project = (APP_ROOT / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    strings = (APP_ROOT / "App" / "L10n.swift").read_text(encoding="utf-8")
    journey = (APP_ROOT / "App" / "ContentView.swift").read_text(encoding="utf-8")

    assert 'moduleResource == "synapses_and_signal_summation"' in views and "SynapticSummationLab()" in views
    assert "SynapticSummation.swift in Sources" in project
    assert "scripts/verify_synaptic_summation.swift" in workflow
    used = set(re.findall(r'(?<!accessibilityIdentifier\()(?<!identifier: )"(lab\.synapse\.[A-Za-z]+)"', views))
    defined = set(re.findall(r'^\s*"(lab\.synapse\.[A-Za-z]+)":', strings, re.MULTILINE))
    assert used and used <= defined
    brain_stage = journey.split('id: "brain_science"', 1)[1].split("),\n        .init(", 1)[0]
    assert "Синапс и суммация сигналов" in brain_stage and "Synapses and signal summation" in brain_stage
