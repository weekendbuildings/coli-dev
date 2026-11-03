"""Source-level guardrails for the shared macOS visual system.

SwiftUI cannot be executed in the Windows development checkout, so these
checks protect the cross-version design contract while the macOS CI build
validates the actual SwiftUI API usage.
"""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "macOS" / "ColiDev" / "App"


def test_each_core_subject_has_a_distinct_color_token():
    source = (APP / "AppVisualSystem.swift").read_text(encoding="utf-8")
    tokens = {
        subject: (light.lower(), dark.lower())
        for subject, light, dark in re.findall(
            r'case "([a-z]+)":\s*return ColorToken\('
            r'lightHex: 0x([0-9A-Fa-f]{6}),\s*darkHex: 0x([0-9A-Fa-f]{6})\)',
            source,
        )
    }

    expected = {
        "mathematics",
        "english",
        "physics",
        "chemistry",
        "biology",
        "zoology",
        "programming",
    }
    assert expected <= tokens.keys()
    assert len({tokens[subject][0] for subject in expected}) == len(expected)
    assert len({tokens[subject][1] for subject in expected}) == len(expected)


def test_glass_controls_have_a_legacy_material_fallback():
    source = (APP / "AppVisualSystem.swift").read_text(encoding="utf-8")

    assert "#if compiler(>=6.2)" in source
    assert "#available(macOS 26.0, *)" in source
    assert ".glassEffect(.regular" in source
    assert "AppPalette.raised.color" in source


def test_visual_system_verifier_has_explicit_entry_point_for_multi_file_swiftc():
    verifier = (ROOT / "macOS" / "ColiDev" / "scripts" / "verify_app_visual_system.swift").read_text(
        encoding="utf-8"
    )

    assert "@main" in verifier
    assert "static func main()" in verifier


def test_control_center_exposes_a_visible_and_accessible_overview():
    source = (APP / "ContentView.swift").read_text(encoding="utf-8")

    assert '.accessibilityIdentifier("control-center.root")' in source
    assert '.accessibilityIdentifier("control-center.overview")' in source
    assert "minHeight: 260" in source


def test_sidebar_uses_the_palette_accent_color():
    source = (APP / "ContentView.swift").read_text(encoding="utf-8")
    sidebar_subjects = source.split("ForEach(Subject.allCases) { subject in", 1)[1].split(
        "ForEach(store.customCurriculum.subjects)", 1
    )[0]

    assert "tint: AppPalette.accent.color" in sidebar_subjects
    assert "ColiDevVisualSystem.subjectColor(subject.rawValue)" not in sidebar_subjects


def test_today_information_cards_use_tinted_content_surfaces():
    source = (APP / "ContentView.swift").read_text(encoding="utf-8")

    assert ".coliContentCard(tint: featuredStudyAccent, cornerRadius: 20)" in source
    assert "studyAccent(for: snapshot.nextRoute), cornerRadius: 16" in source
    assert "studyAccent(for: activeGoalOption?.route ?? studyRecommendation?.route), cornerRadius: 18" in source


def test_subject_tiles_use_glass_color_and_reduce_motion_aware_hover():
    source = (APP / "ContentView.swift").read_text(encoding="utf-8")
    card = source.split("private struct SubjectCard:", 1)[1].split("private struct SettingsView:", 1)[0]

    assert "@Environment(\\.accessibilityReduceMotion)" in card
    assert "subject.tint.opacity(isHovered && !reduceMotion ? 0.22 : 0.15)" in card
    assert "subject.tint.opacity(0.035)" in card
    assert ".coliGlassControl(cornerRadius: 18)" in card
    assert ".onHover" in card
    assert "reduceMotion ? nil : .easeOut" in card


def test_control_center_metrics_use_tinted_glass_cards():
    source = (APP / "ContentView.swift").read_text(encoding="utf-8")
    metric = source.split("private func metric(title:", 1)[1].split("private func statusRow", 1)[0]

    assert "tint.opacity(0.18)" in metric
    assert ".coliGlassControl(cornerRadius: 14)" in metric


def test_ci_parses_visual_verifier_as_library():
    workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")

    assert "swiftc -parse-as-library macOS/ColiDev/App/AppVisualSystem.swift" in workflow


def test_ci_artifact_names_distinguish_macos_runner_versions():
    workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")

    assert "name: ColiDev-${{ matrix.runner }}-${{ steps.package.outputs.arch }}" in workflow


def test_completion_sound_is_opt_in_and_exposed_in_both_languages():
    visual_system = (APP / "AppVisualSystem.swift").read_text(encoding="utf-8")
    settings = (APP / "ContentView.swift").read_text(encoding="utf-8")
    localization = (APP / "L10n.swift").read_text(encoding="utf-8")
    models = (APP / "AppModels.swift").read_text(encoding="utf-8")

    assert 'static let soundPreferenceKey = "colidev.soundEffectsEnabled"' in visual_system
    assert "@AppStorage(ColiDevVisualSystem.soundPreferenceKey) private var soundEffectsEnabled = false" in settings
    assert 'L10n.text("settings.soundEffects", store.language)' in settings
    assert '"settings.soundEffects":' in localization
    assert "AppSoundFeedback.playCompletion()" in models
