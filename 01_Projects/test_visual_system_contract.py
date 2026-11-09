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
    sidebar_subjects = source.split("ForEach(Subject.visible(showAll: showAllSubjects)) { subject in", 1)[1].split(
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


def test_arc_painter_can_paint_every_answer_color():
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")
    painter = views.split("private struct ArcPainterLab:", 1)[1].split("private func color(", 1)[0]

    assert "set.formUnion(task.testOut.filter" in painter


def test_obsidian_save_remembers_the_copy_instead_of_adding_silently():
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")

    assert "ObsidianLessonCopyMemory.remember(path: path" in views
    assert '"module.obsidianAlreadySaved"' in views
    assert "notebook.google.com" in views
    assert "notebooklm.google.com" not in views


def test_app_shows_the_new_name_but_keeps_the_identifiers_that_hold_user_data():
    plist = (APP / "Info.plist").read_text(encoding="utf-8")
    project = (ROOT / "macOS" / "ColiDev" / "ColiDev.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")
    orchestrator = (ROOT / "01_Projects" / "orchestrator.py").read_text(encoding="utf-8")
    strings_source = (APP / "L10n.swift").read_text(encoding="utf-8")

    # Finder shows the localized name only while CFBundleDisplayName equals the file name ColiDev.app.
    # Finder показывает перевод имени, только пока CFBundleDisplayName совпадает с именем файла ColiDev.app.
    assert "<key>CFBundleDisplayName</key>\n    <string>ColiDev</string>" in plist
    assert "<key>CFBundleName</key>\n    <string>Creator</string>" in plist
    assert "<key>LSHasLocalizedDisplayName</key>\n    <true/>" in plist
    assert "PRODUCT_BUNDLE_IDENTIFIER = com.colidev.learningstudio;" in project
    assert '_KEYCHAIN_SERVICE = "ColiDev"' in orchestrator
    # The name is not translated: Finder shows «Творец» on an English macOS too (owner's decision, 2026-11-08).
    # Имя не переводится: Finder показывает «Творец» и на английской macOS (решение владельца 2026-11-08).
    for language, name in (("en", "Творец"), ("ru", "Творец")):
        strings = (APP / f"{language}.lproj" / "InfoPlist.strings").read_text(encoding="utf-8")
        assert f'"CFBundleName" = "{name}";' in strings
        assert f'"CFBundleDisplayName" = "{name}";' in strings
    assert '"app.name": ("Творец", "Creator")' in strings_source
    assert "Cause & Course" not in strings_source
    view = (APP / "ContentView.swift").read_text(encoding="utf-8")
    assert view.count('.navigationTitle(L10n.text("app.name", store.language))') == 2


def test_extra_subjects_hide_by_default_and_tools_never_hide():
    basics = (APP / "CreatorBasics.swift").read_text(encoding="utf-8")
    view = (APP / "ContentView.swift").read_text(encoding="utf-8")

    assert 'static let hiddenByDefault: Set<String> = ["zoology", "chemistry", "physics", "biology"]' in basics
    assert view.count("@AppStorage(SubjectVisibility.showAllDefaultsKey) private var showAllSubjects = false") == 4
    assert view.count("ForEach(Subject.visible(showAll: showAllSubjects))") == 3
    assert '.accessibilityIdentifier("settings.showAllSubjects")' in view
    sidebar = view.split("NavigationSplitView(columnVisibility: $columns) {", 1)[1].split("} detail: {", 1)[0]
    for identifier in ("sidebar.management", "sidebar.local-models", "sidebar.tools", "sidebar.settings"):
        row = sidebar.split(f'identifier: "{identifier}"', 1)[0].rsplit("\n", 1)[1]
        assert "if " not in row and "showAll" not in row, identifier
    assert "ForEach(store.customCurriculum.subjects)" in sidebar


def test_lesson_has_in_app_assistant_and_freshness_label():
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (APP / "L10n.swift").read_text(encoding="utf-8")
    assistant = (APP / "LessonAssistantView.swift").read_text(encoding="utf-8")
    request = views.split("private func assistantRequest(for document: CurriculumLessonDocument) -> LessonAssistantRequest {", 1)[1].split("\n    }\n", 1)[0]

    # The old "Ask Claude" opened claude.ai in Safari; part 3 answers inside the app.
    # Старая «Спросить Claude» открывала claude.ai в Safari; часть 3 отвечает внутри приложения.
    assert "lesson.askClaude" not in views and "lesson.askClaude" not in strings
    assert "claude.ai" not in views and "NSWorkspace.shared.open(AssistantExplainPrompt" not in views
    assert '.accessibilityIdentifier("lesson.assistant")' in views
    assert ".sheet(item: $assistantRequest)" in views and "LessonAssistantView(request: request)" in views
    assert "AssistantExplainPrompt.make(" in request and '"assistant.position.path"' in request
    assert "OrchestratorClient.streamAssistant(" in assistant and "/assistant/ask/stream" in assistant
    assert "OrchestratorClient.saveObsidianNote(path: path, content: note)" in assistant
    assert "NSWorkspace.shared.open" not in assistant and "api.anthropic" not in views
    prompt = strings.split('"assistant.explain.prompt": ("', 1)[1].split("\n", 1)[0]
    assert prompt.count("%@") == 6 and "простым русским языком" in prompt and "задание для практики" in prompt
    assert 'hasPrefix("source_review_interval_days:")' in views
    assert "LessonFreshness.make(" in views and '.accessibilityIdentifier("lesson.freshness.overdue")' in views
    badge = views.split("private struct LessonFreshnessBadge: View {", 1)[1].split("\n}\n", 1)[0]
    assert ".foregroundStyle(.orange)" in badge
    for key in ("today", "days.one", "days.few", "days.many", "overdue"):
        assert f'"lesson.freshness.{key}": ("' in strings
    assert '"lesson.freshness.overdue": ("Пора перепроверить источники"' in strings
