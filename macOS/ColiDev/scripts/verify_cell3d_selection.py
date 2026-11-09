"""Verify the 3D cell's scene, menu, labels, and hit-test IDs stay aligned."""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[3]
views = (ROOT / "macOS/ColiDev/App/LearningViews.swift").read_text(encoding="utf-8")
l10n = (ROOT / "macOS/ColiDev/App/L10n.swift").read_text(encoding="utf-8")
lesson = (ROOT / "02_Areas/Biology/lessons/eukaryotic_cell_organelles.md").read_text(encoding="utf-8")
ui_tests = (ROOT / "macOS/ColiDev/UITests/ManagementUITests.swift").read_text(encoding="utf-8")
content_view = (ROOT / "macOS/ColiDev/App/ContentView.swift").read_text(encoding="utf-8")
module_views = (ROOT / "macOS/ColiDev/App/LearningViews.swift").read_text(encoding="utf-8")
ids_start = views.index("private enum CellOrganelleID {")
ids_end = views.index("private struct EukaryoticCellLab: View {", ids_start)
ids_source = views[ids_start:ids_end]
ids_block = re.search(r"static let all: \[String\] = \[(.*?)\]", ids_source, re.S)
assert ids_block, "Missing canonical 3D cell organelle ID list"
declared_ids = tuple(re.findall(r'"([^\"]+)"', ids_block.group(1)))
ids = ("membrane", "nucleus", "rough_er", "golgi", "mitochondria", "ribosomes", "lysosome")
assert declared_ids == ids, f"Unexpected or out-of-order 3D cell IDs: {declared_ids}"

lab_start = views.index("private struct EukaryoticCellLab: View {")
lab_end = views.index("private struct AdaptationLab: View {", lab_start)
lab = views[lab_start:lab_end]
scene = views[views.index("private struct EukaryoticCellScene: NSViewRepresentable {"):lab_end]

for part in ids:
    assert f'"organelle-{part}"' in scene, f"Missing scene node for organelle ID: {part}"
    assert f'"biology.cell3d.{part}"' in l10n, f"Missing bilingual organelle label: {part}"
    assert f'"biology.cell3d.{part}.function"' in l10n, f"Missing bilingual organelle description: {part}"

for snippet in (
    "EukaryoticCellScene(",
    "tapSequence: $sceneTapSequence",
    "Picker(L10n.text(\"lab.cellPart\", store.language), selection: $selectedPart)",
    ".pickerStyle(.menu)",
    '.accessibilityIdentifier("biology.cell3d.organelles")',
    '.accessibilityIdentifier("biology.cell3d.scene")',
    ".accessibilityElement(children: .ignore)",
    '.accessibilityIdentifier("biology.cell3d.description")',
    '.accessibilityValue(Text(L10n.text("biology.cell3d.\\(selectedPart)", store.language)))',
    'Text(L10n.text("biology.cell3d.\\(selectedPart).function", store.language))',
    "lab.cell3d.interactionHint",
    'let diagnostic = "tap=\\(sceneTapSequence), part=\\(selectedPart), \\(sceneTapDiagnostic)"',
    "Text(diagnostic)",
    ".accessibilityValue(Text(diagnostic))",
    '.accessibilityIdentifier("biology.cell3d.tapState")',
):
    assert snippet in lab, f"3D cell lesson UI is missing: {snippet}"

for snippet in (
    "NSClickGestureRecognizer(",
    "action: #selector(Coordinator.selectOrganelle(_:))",
    "@objc func selectOrganelle(_ gesture: NSClickGestureRecognizer)",
    "gesture.location(in: view)",
    "shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer",
    "organelleCandidate(at: point, in: view)",
    "DispatchQueue.main.async { [weak self] in",
    'hitParts.joined(separator: ",")',
    "let rendererPoint = view.convertToBacking(point)",
    "let pickRadius = 44 * (view.window?.backingScaleFactor ?? 1)",
    "view.hitTest(rendererPoint, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])",
    "nearestOrganelle(to: rendererPoint, in: view)",
    "projectedTestTargetPoint(in: view)",
    'withName: "organelle-mitochondria"',
    "selectedPart.wrappedValue = part",
    "for child in node.childNodes",
    "view.projectPoint(node.presentation.worldPosition)",
):
    assert snippet in scene, f"3D cell scene selection wiring is missing: {snippet}"

assert "Нажми прямо на органеллу в 3D-сцене" in lesson, "Russian lesson does not explain direct scene selection"
assert "Click an organelle directly in the 3D scene" in lesson, "English lesson does not explain direct scene selection"
# The app starts on the workshop HUD; UI tests (and this lesson route) still start on Today with the sidebar visible.
# Приложение стартует на HUD Мастерской; UI-тесты (и этот маршрут урока) по-прежнему стартуют на «Сегодня» с боковой панелью.
assert "@State private var selection: AppSection? = ContentView.startSection" in content_view, "UI-test launch must start from a valid visible sidebar selection"
start_section = content_view.split("static var startSection: AppSection {", 1)[1].split("\n    }\n", 1)[0]
assert 'UserDefaults.standard.bool(forKey: "colidev.uiTestCell3D")' in start_section and "return .today" in start_section, "UI-test launch must start from a valid visible sidebar selection"
assert 'environment.keys.contains(where: { $0.hasPrefix("COLIDEV_UI_TEST") })' in start_section, "UI-test launches must start on Today / UI-тесты стартуют с «Сегодня»"
assert ".onAppear(perform: openCell3DUITestRouteIfNeeded)" in content_view, "UI-test lesson route must wait until the first screen appears"
assert "DispatchQueue.main.async" in content_view, "UI-test lesson route must be deferred until after the first render"
assert 'UserDefaults.standard.bool(forKey: "colidev.uiTestCell3D")' in content_view, "UI-test route must use a dedicated UserDefaults launch override. / Тестовый маршрут должен использовать отдельный флаг запуска UserDefaults."
test_route_start = content_view.index("private func openCell3DUITestRouteIfNeeded()")
test_route_end = content_view.index("private func openCustom", test_route_start)
test_route = content_view[test_route_start:test_route_end]
assert 'let route = StudyLessonRoute(subjectID: "biology", resource: "eukaryotic_cell_organelles")' in test_route, "UI-test route must identify the intended cell lesson. / Тестовый маршрут должен указывать нужный урок о клетке."
assert "practiceFocusRoute = route" in test_route, "UI-test route must scroll the practice anchor into view before clicking. / Тестовый маршрут должен прокрутить к практике перед нажатием."
assert "testClickingCellOrganelleUpdatesSelectionAndDescription" in ui_tests, "Missing macOS UI coverage for scene selection"
assert 'app.launchArguments = ["-colidev.uiTestCell3D", "YES"]' in ui_tests, "UI test must use a standard UserDefaults argument, not an unknown -- option. / UI-тест должен использовать стандартный аргумент UserDefaults, без неизвестной опции с --."
assert "app.activate()" in ui_tests, "UI test must bring ColiDev to the foreground before checking the window"
assert "window.waitForExistence(timeout: 10)" in ui_tests, "UI test must verify that the main window opens"
assert "description.value as? String" in ui_tests, "UI test must read the lesson text from its accessibility value. / UI-тест должен читать текст урока из значения accessibility."
assert 'NSPredicate(format: "value == %@", mitochondriaDescription)' in ui_tests, "UI test must wait for the selected description value. / UI-тест должен ждать изменения значения выбранного описания."
assert 'app.popUpButtons["biology.cell3d.organelles"]' in ui_tests, "UI test must verify that the accessible organelle menu follows the scene selection. / UI-тест должен проверять, что доступное меню следует за выбором в 3D-сцене."
assert '.id("module-interactive-practice")' in module_views, "The interactive lesson scroll anchor must remain available. / Якорь прокрутки к интерактиву должен сохраниться."
assert '.accessibilityIdentifier("module.interactive-practice")' not in module_views, "The practice container must not override child accessibility IDs. / Контейнер практики не должен перезаписывать ID вложенных элементов доступности."
assert "window.scrollViews.element(boundBy: 1)" in ui_tests, "UI test must scroll the lesson pane instead of the sidebar. / UI-тест должен прокручивать урок, а не боковую панель."
assert 'NSPredicate(format: "hittable == true")' in ui_tests, "UI test must wait for the 3D scene to become visible before clicking. / Перед нажатием UI-тест должен дождаться видимости 3D-сцены."
assert "swipeUp()" not in ui_tests and "swipeDown()" not in ui_tests, "UI test must not fling the long lesson past the 3D scene. / UI-тест не должен резкими свайпами прокручивать длинный урок мимо 3D-сцены."
assert 'hasPrefix("mitochondriaTarget=")' in ui_tests, "UI test must read the current projected mitochondrion point from the live click diagnostic. / UI-тест должен читать проекцию митохондрии из диагностики живого щелчка."
assert 'CGVector(dx: CGFloat(targetX), dy: CGFloat(targetY))' in ui_tests, "UI test must click using the projected organelle point instead of a guessed offset. / UI-тест должен нажимать на рассчитанную проекцию органеллы, а не на примерную точку."
assert "visibleFraction >= 0.9" in ui_tests and "viewport.contains(sceneCenter)" in ui_tests, "UI test must keep at least 90% of the 3D scene visible and its center inside the lesson viewport before clicking. / UI-тест должен удерживать не менее 90% 3D-сцены и её центр в видимой области урока перед нажатием."
assert 'scene.coordinate(withNormalizedOffset: CGVector(dx: CGFloat(targetX), dy: CGFloat(targetY))).click()' in ui_tests, "UI test does not click the projected mitochondrion in the scene"
assert 'app.staticTexts["biology.cell3d.description"]' in ui_tests, "UI test does not inspect the live organelle description"
assert 'app.staticTexts["biology.cell3d.tapState"]' in ui_tests, "UI test does not verify that the scene tap reaches SwiftUI"
assert "The click did not reach the native SceneKit click recognizer." in ui_tests, "UI test does not diagnose whether the native scene click was received"

print("3D cell selection IDs, bilingual labels, click handling, keyboard menu, and deferred UI-test routing are aligned. / Идентификаторы органелл, RU/EN-подписи, выбор щелчком, меню и отложенный тестовый маршрут согласованы.")
