"""Plain-markdown RAG over the vault folder the owner picks for «Память» (no Obsidian REST key).

Files are re-read only when their modification time changes, so each search stays fast.
RAG по папке «Памяти», выбранной владельцем, — обычные файлы .md без ключа Obsidian; перечитываются только
изменённые файлы, поэтому поиск остаётся быстрым.
"""
from __future__ import annotations

import os
import re
import threading
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

MAX_FILES = 5000
MAX_BYTES = 200_000
EXCERPT = 900
_WORD = re.compile(r"[\w-]{3,}", re.UNICODE)


@dataclass
class _Note:
    mtime: float
    title: str
    text: str
    words: set[str]


def _words(text: str) -> set[str]:
    return {w.lower().replace("ё", "е") for w in _WORD.findall(text)}


def _body(text: str) -> str:
    if text.startswith("---"):
        parts = text.split("\n---", 1)
        if len(parts) == 2:
            text = parts[1]
    return re.sub(r"!?\[\[([^\]|]+)(?:\|([^\]]+))?\]\]", lambda m: m.group(2) or m.group(1), text).strip()


def safe_vault(path: str | None, home: Path | None = None) -> Path | None:
    """Only an existing folder inside the owner's home. / Только существующая папка внутри домашней."""
    if not path:
        return None
    try:
        folder = Path(path).expanduser().resolve()
        base = (home or Path.home()).resolve()
    except (OSError, RuntimeError):
        return None
    if not folder.is_dir() or (folder != base and base not in folder.parents):
        return None
    return folder


class VaultIndex:
    def __init__(self) -> None:
        self._notes: dict[str, _Note] = {}
        self._lock = threading.Lock()

    def _refresh(self, folder: Path) -> list[tuple[str, _Note]]:
        seen: list[tuple[str, _Note]] = []
        count = 0
        for root, dirs, files in os.walk(folder):
            dirs[:] = [d for d in dirs if not d.startswith(".")]
            for name in files:
                if not name.lower().endswith(".md") or name.startswith("."):
                    continue
                count += 1
                if count > MAX_FILES:
                    return seen
                path = os.path.join(root, name)
                try:
                    mtime = os.stat(path).st_mtime
                except OSError:
                    continue
                note = self._notes.get(path)
                if note is None or note.mtime != mtime:
                    try:
                        with open(path, "rb") as handle:
                            text = _body(handle.read(MAX_BYTES).decode("utf-8", "replace"))
                    except OSError:
                        continue
                    title = Path(name).stem
                    note = _Note(mtime, title, text, _words(title + " " + text))
                    self._notes[path] = note
                seen.append((path, note))
        return seen

    def search(self, query: str, folder: Path, limit: int = 2) -> list[dict[str, str]]:
        terms = _words(query)
        if not terms:
            return []
        with self._lock:
            notes = self._refresh(folder)
        scored = []
        for path, note in notes:
            hits = len(terms & note.words)
            if hits == 0:
                continue
            title_hits = len(terms & _words(note.title))
            scored.append((hits + 2 * title_hits, note.mtime, path, note))
        scored.sort(key=lambda item: (item[0], item[1]), reverse=True)
        results = []
        for _, mtime, path, note in scored[:limit]:
            lower = note.text.lower()
            start = min((lower.find(term) for term in terms if lower.find(term) >= 0), default=0)
            excerpt = note.text[max(0, start - 200): max(0, start - 200) + EXCERPT].strip()
            results.append({
                "source_type": "vault",
                "title": note.title,
                "path": os.path.relpath(path, folder),
                "modified_at": datetime.fromtimestamp(mtime, timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "excerpt": excerpt,
            })
        return results
