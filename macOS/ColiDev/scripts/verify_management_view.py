"""Проверяет доступность панелей Центра управления / Verify accessible Control Center panes."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
CONTENT_VIEW = ROOT / "macOS" / "ColiDev" / "App" / "ContentView.swift"
source = CONTENT_VIEW.read_text(encoding="utf-8")
APP_MODELS = ROOT / "macOS" / "ColiDev" / "App" / "AppModels.swift"
LOCALIZATION = ROOT / "macOS" / "ColiDev" / "App" / "L10n.swift"
app_models = APP_MODELS.read_text(encoding="utf-8")
localization = LOCALIZATION.read_text(encoding="utf-8")


def property_block(name: str) -> str:
    marker = f"private var {name}: some View"
    start = source.find(marker)
    if start < 0:
        raise AssertionError(f"Не найдена панель ManagementView / Missing ManagementView pane: {name}")
    candidates = [
        index
        for token in ("\n    private var ", "\n    private func ")
        if (index := source.find(token, start + len(marker))) >= 0
    ]
    end = min(candidates) if candidates else len(source)
    return source[start:end]


panes = {
    "overviewPane": "control-center.overview",
    "coursesPane": "control-center.courses",
    "modelsPane": "control-center.models",
    "ragPane": "control-center.rag",
    "sourcesPane": "control-center.sources",
    "integrationsPane": "control-center.integrations",
}

for pane_name, identifier in panes.items():
    if identifier not in property_block(pane_name):
        raise AssertionError(
            f"ID {identifier} должен принадлежать панели {pane_name} / "
            f"ID {identifier} must identify its own {pane_name} view"
        )

if '.accessibilityIdentifier("control-center.pane-picker")' not in source:
    raise AssertionError(
        "Переключателю Центра управления нужен стабильный accessibility ID / "
        "Control Center pane picker needs a stable accessibility identifier"
    )

management_row = source.find("sidebarRow(.management,")
management_id = source.find('identifier: "sidebar.management"')
if management_row < 0 or management_id < 0 or abs(management_row - management_id) > 220:
    raise AssertionError(
        "Пункт Центра управления в боковой панели должен иметь стабильный ID / "
        "Management sidebar item needs a stable accessibility identifier"
    )

sources_pane = property_block("sourcesPane")
if "sourceInventory?.automaticCheckDueAt" not in sources_pane:
    raise AssertionError(
        "Панель источников должна показывать следующую авто-проверку / "
        "Sources pane must show the next automatic check"
    )
for pane_name in ("ragPane", "sourcesPane"):
    if ".accessibilityElement(children: .contain)" not in property_block(pane_name):
        raise AssertionError(
            f"Панель {pane_name} должна сохранять отдельные ID вложенных элементов / "
            f"Pane {pane_name} must preserve child accessibility identifiers"
        )
if '"control-center.sources.next-check"' not in sources_pane:
    raise AssertionError(
        "Строке следующей проверки нужен accessibility ID / "
        "The next-check row needs an accessibility identifier"
    )
if '"management.autoSourceCheckDue"' not in localization:
    raise AssertionError(
        "Для времени следующей авто-проверки нужны RU/EN подписи / "
        "The next automatic check needs RU/EN labels"
    )
if "automaticCheckDueAt" not in app_models or '"automatic_check_due_at"' not in app_models:
    raise AssertionError(
        "Модель источников должна декодировать следующее время проверки / "
        "The source inventory model must decode the next check time"
    )
management_view_start = source.find("private struct ManagementView: View")
management_view_end = source.find("private enum SourceRegistrySheet", management_view_start)
management_view = source[management_view_start:management_view_end]
if "formatManagementDate(dueAt)" not in sources_pane or "private func formatManagementDate(" not in management_view:
    raise AssertionError(
        "Форматтер срока должен принадлежать ManagementView / "
        "The due-date formatter must be scoped to ManagementView"
    )
if '"management.sourcesAttention": ("Ссылки без проверки или с предупреждением", "Unchecked or flagged source links")' not in localization:
    raise AssertionError(
        "Счётчик сетевого статуса ссылок должен отличаться от редакторского срока проверки / "
        "The network source-status metric must be distinct from editorial review due dates"
    )

print("Доступность панелей Центра управления проверена / Control Center pane accessibility mapping is consistent.")
