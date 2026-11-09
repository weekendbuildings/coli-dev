from __future__ import annotations

import re
from pathlib import Path


CONTENT = Path(__file__).resolve().parents[1] / "macOS" / "ColiDev" / "App" / "ContentView.swift"


def test_sidebar_column_is_wide_enough_for_the_longest_labels() -> None:
    content = CONTENT.read_text(encoding="utf-8")
    # The sidebar can be hidden for the workshop HUD, so the split view takes a visibility binding.
    # Боковую панель можно скрыть для HUD Мастерской, поэтому у NavigationSplitView есть привязка видимости.
    sidebar = content.split("NavigationSplitView(columnVisibility: $columns) {", 1)[1].split("} detail: {", 1)[0]
    width = re.search(r"\.navigationSplitViewColumnWidth\(min: (\d+), ideal: (\d+)\)", sidebar)
    assert width, "the sidebar needs an explicit column width"
    minimum, ideal = int(width.group(1)), int(width.group(2))
    # “Программирование” and “Локальные модели” with icons need about 190 pt.
    assert minimum >= 200 and ideal >= minimum
