"""Verify official page dates remain visible in tutor and RAG-inspection citations."""

from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
APP_MODELS = (ROOT / "macOS/ColiDev/App/AppModels.swift").read_text(encoding="utf-8")
LEARNING_VIEWS = (ROOT / "macOS/ColiDev/App/LearningViews.swift").read_text(encoding="utf-8")
CONTENT_VIEW = (ROOT / "macOS/ColiDev/App/ContentView.swift").read_text(encoding="utf-8")
LOCALIZATION = (ROOT / "macOS/ColiDev/App/L10n.swift").read_text(encoding="utf-8")


def require(source: str, fragments: tuple[str, ...], description: str) -> None:
    missing = [fragment for fragment in fragments if fragment not in source]
    if missing:
        raise AssertionError(f"{description} is missing required source-date wiring: {missing}")


require(
    APP_MODELS,
    (
        "let sourceSnapshotFetchedAt: String?",
        "let pagePublishedAt: String?",
        "let pageUpdatedAt: String?",
        'case sourceSnapshotFetchedAt = "source_snapshot_fetched_at"',
        'case pagePublishedAt = "page_published_at"',
        'case pageUpdatedAt = "page_updated_at"',
    ),
    "TutorSource decoding",
)
for view_name, view_source in (
    ("tutor citation cards", LEARNING_VIEWS),
    ("RAG inspection results", CONTENT_VIEW),
):
    require(
        view_source,
        (
            "sourceSnapshotFetchedAt",
            "pagePublishedAt",
            "pageUpdatedAt",
            '"tutor.sourceSnapshotFetchedAt"',
            '"tutor.publisherPublishedAt"',
            '"tutor.publisherUpdatedAt"',
            '"tutor.publisherDateCaveat"',
        ),
        view_name,
    )
require(
    LOCALIZATION,
    (
        '"tutor.sourceCheckedAt": ("Официальная страница проверена", "Official page checked")',
        '"tutor.sourceSnapshotFetchedAt": ("Текст страницы загружен", "Page text snapshot fetched")',
        '"tutor.publisherPublishedAt": ("Дата публикации по данным страницы", "Published (page-declared)")',
        '"tutor.publisherUpdatedAt": ("Дата обновления по данным страницы", "Updated (page-declared)")',
        '"tutor.publisherDateCaveat": ("Даты указаны страницей; Cause & Course не проверяет их независимо.", "Dates are declared by the page; Cause & Course does not independently verify them.")',
    ),
    "RU/EN source-date localization",
)

print("Verified publisher dates and distinct source-check/snapshot timestamps in RU/EN tutor and RAG citations.")
