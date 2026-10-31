"""Bounded freshness signals for official references in bundled lessons.

Only pages on a code-owned allowlist are fetched. A small HTML response is
processed in memory to extract public page metadata and a normalized text
fingerprint. Full bounded text snapshots enter RAG only for exact paths whose
reuse terms are documented below; all other approved pages remain
metadata/preview-only. Freshness signals help editors decide what to review
and do not verify lesson facts.
"""

from __future__ import annotations

import asyncio
import hashlib
import math
from collections import Counter
from collections.abc import Iterator
from contextlib import contextmanager
from html.parser import HTMLParser
import os
import re
import sqlite3
import threading
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit

import httpx
from lesson_metadata import (
    _source_checked_date,
    _source_review_interval_days,
    _source_review_schedule,
)

_URL_RE = re.compile(r"https?://[^\s<>)\]\"`]+", re.IGNORECASE)
_RAG_TOKEN_RE = re.compile(r"[^\W_]+", re.UNICODE)
_MARKDOWN_LINK_RE = re.compile(r"\[([^\]]{1,200})\]\(\s*(https://[^)\s]+)\s*\)", re.IGNORECASE)
_TRAILING_PUNCTUATION = ".,;:!?"
_MAX_LESSON_FILES = 200
_MAX_LESSON_FILE_BYTES = 256 * 1024
# Bounds the daily automatic check (at most five requests at a time). Raised from 150 and then 200
# when the bundled lessons outgrew it; keep headroom so a new lesson's sources are not silently omitted.
_MAX_SOURCES = 300
_MAX_CONCURRENT_REQUESTS = 5
_MAX_TITLE_LENGTH = 200
_MAX_PAGE_DESCRIPTION_LENGTH = 500
_MAX_VALIDATOR_LENGTH = 512
_MAX_SOURCE_PAGE_BYTES = 512 * 1024
_MAX_EXTRACTED_TEXT_CHARS = 200_000
_MAX_SOURCE_PREVIEW_CHARS = 4_000
_MAX_RAG_SOURCE_CHARS = 120_000
_MAX_RAG_RESULTS = 2
_MAX_RAG_EXCERPT_CHARS = 1_400
_MAX_RAG_CHECK_AGE = timedelta(hours=48)
_BM25_K1 = 1.2
_BM25_B = 0.75
_AUTO_CHECK_INTERVAL = timedelta(hours=24)
_AUTO_RETRY_INTERVAL = timedelta(hours=6)
_ISO_SOURCE_DATE = re.compile(
    r"^\d{4}-\d{2}-\d{2}(?:T\d{2}:\d{2}(?::\d{2}(?:\.\d{1,6})?)?(?:Z|[+-]\d{2}:\d{2})?)?$"
)
_TRANSIENT_SOURCE_STATES = frozenset({"network_error", "unavailable"})
_TRUSTED_HOSTS = frozenset(
    {
        "animaldiversity.org",
        "csed.acm.org",
        "csrc.nist.gov",
        "dictionary.cambridge.org",
        "docs.github.com",
        "docs.python.org",
        "git-scm.com",
        "learnenglish.britishcouncil.org",
        "legacy.bas.ac.uk",
        "medlineplus.gov",
        "online.stat.psu.edu",
        "raw.githubusercontent.com",
        "www.nist.gov",
        "www.genome.gov",
        "www.ncbi.nlm.nih.gov",
        "www.sqlite.org",
        "sqlite.org",
        "openstax.org",
        "www.sciencedirect.com",
        "pubmed.ncbi.nlm.nih.gov",
    }
)
_ALLOWED_PATHS = {
    "animaldiversity.org": re.compile(r"^/accounts/[A-Za-z0-9_.-]+/?$"),
    "csed.acm.org": re.compile(r"^/final-report/$"),
    "csrc.nist.gov": re.compile(r"^/glossary/term/algorithm$"),
    "docs.python.org": re.compile(
        r"^(?:/3/(?:tutorial/[A-Za-z0-9_.-]+\.html|reference/(?:simple_stmts|compound_stmts)\.html|"
        r"library/(?:bisect|sys)\.html|builtins/(?:functions|exceptions|stdtypes)\.html)|"
        r"/3\.14/builtins/(?:functions|exceptions)\.html)$"
    ),
    "docs.github.com": re.compile(
        r"^/en/pull-requests/(?:how-tos/create-pull-requests/creating-a-pull-request|"
        r"concepts/writing-code-for-a-project)$"
    ),
    "dictionary.cambridge.org": re.compile(
        r"^/(?:dictionary/english/stress|pronunciation/english/(?:present|record)|help/phonetics\.html|"
        r"grammar/british-grammar/reporting-clauses)$"
    ),
    "git-scm.com": re.compile(
        r"^/(?:book/en/v2/(?:Git-Basics-Recording-Changes-to-the-Repository|Git-Branching-Branches-in-a-Nutshell)|"
        r"docs/(?:git-switch|git-push))$"
    ),
    "learnenglish.britishcouncil.org": re.compile(
        r"^/(?:free-resources/(?:grammar/(?:(?:english-grammar-reference|b1-b2)/[A-Za-z0-9-]+|a1-a2/present-simple-be)|"
        r"vocabulary/a1-a2(?:/daily-routine-vocabulary-a1-beginner-english-vocabulary-lesson)?|reading/a1)|"
        r"level/improve-your-english-level/how-start-reading-english|"
        r"english-levels/improve-your-english-level/easy-way-work-out-how-pronounce-new-words)/?$"
    ),
    "legacy.bas.ac.uk": re.compile(
        r"^/about_antarctica/wildlife/birds/penguins/(?:emperor\.php|index\.php)$"
    ),
    "medlineplus.gov": re.compile(
        r"^(?:/genetics/understanding/(?:basics/(?:dna|gene)|howgeneswork/makingprotein)/?|"
        r"/about/using/usingcontent/)$"
    ),
    "online.stat.psu.edu": re.compile(r"^/stat502/Lesson07$"),
    "www.genome.gov": re.compile(
        r"^/genetics-glossary/(?:Gene-Expression|Gene-Regulation|Promoter|Chromatid|Gene|Phenotype|genotype)$"
    ),
    "www.ncbi.nlm.nih.gov": re.compile(
        r"^/books/(?:NBK26825|NBK26854|NBK550206|NBK9842)/?$"
    ),
    "www.nist.gov": re.compile(
        r"^(?:/pml/special-publication-811/nist-guide-si-appendix-b-conversion-factors/"
        r"nist-guide-si-appendix-b9|/pml/owm/metric-si-prefixes|/copyrights-disclaimers)$"
    ),
    "www.sqlite.org": re.compile(
        r"^/(?:lang_createtable|lang_select|queryplanner|lang_transaction)\.html$"
    ),
    "sqlite.org": re.compile(r"^/copyright\.html$"),
    "openstax.org": re.compile(r"^(?:/books/[a-z0-9-]+/pages/[a-z0-9-]+/?|/terms-of-use)$"),
    "www.sciencedirect.com": re.compile(r"^/science/article/pii/S1095643325000789$"),
    "pubmed.ncbi.nlm.nih.gov": re.compile(r"^/40393560/$"),
    "raw.githubusercontent.com": re.compile(
        r"^/elifesciences/elife-article-xml/master/articles/elife-81613-v1\.xml$"
    ),
}

# Only pages with a documented reuse license enter the automatic RAG cache.
# Other approved official sources remain metadata/preview-only pending review.
_RAG_SOURCE_POLICIES = {
    "docs.python.org": {
        "path": re.compile(
            r"^(?:/3/(?:tutorial/[A-Za-z0-9_.-]+\.html|reference/(?:simple_stmts|compound_stmts)\.html|"
            r"library/(?:bisect|sys)\.html|builtins/(?:functions|exceptions|stdtypes)\.html)|"
            r"/3\.14/builtins/(?:functions|exceptions)\.html)$"
        ),
        "license": "Python Software Foundation License Version 2",
        "license_url": "https://docs.python.org/3/license.html",
        "attribution": "Copyright © 2001 Python Software Foundation; All Rights Reserved. Python 3 documentation; PSF License Version 2.",
    },
    "www.sqlite.org": {
        "path": re.compile(
            r"^/(?:lang_createtable|lang_select|queryplanner|lang_transaction)\.html$"
        ),
        "license": "SQLite documentation dedicated to the public domain",
        "license_url": "https://sqlite.org/copyright.html",
        "attribution": (
            "Source: SQLite documentation. The authors dedicated SQLite code and documentation "
            "to the public domain."
        ),
    },
    "medlineplus.gov": {
        "path": re.compile(r"^/genetics/understanding/basics/(?:dna|gene)/?$"),
        "license": "U.S. federal government work; public-domain MedlinePlus Genetics summary",
        "license_url": "https://medlineplus.gov/about/using/usingcontent/",
        "attribution": "Source: MedlinePlus, National Library of Medicine (NLM), National Institutes of Health (NIH). Public-domain Genetics summary.",
    },
    "www.genome.gov": {
        "path": re.compile(
            r"^/genetics-glossary/(?:Gene-Expression|Gene-Regulation|Promoter|Chromatid|Gene|Phenotype|genotype)$"
        ),
        "license": "NHGRI website material is public domain unless otherwise indicated on the page",
        "license_url": "https://www.genome.gov/about-nhgri/Policies-Guidance/Copyright",
        "attribution": (
            "Courtesy: National Human Genome Research Institute (NHGRI), genome.gov. "
            "Public-domain web content unless otherwise marked; no government endorsement implied."
        ),
    },
    "www.nist.gov": {
        "path": re.compile(
            r"^(?:/pml/special-publication-811/nist-guide-si-appendix-b-conversion-factors/"
            r"nist-guide-si-appendix-b9|/pml/owm/metric-si-prefixes)$"
        ),
        "license": "NIST public information; may be distributed or copied unless marked copyrighted",
        "license_url": "https://www.nist.gov/copyrights-disclaimers",
        "attribution": "Source: National Institute of Standards and Technology (NIST). Credit the linked page; no endorsement implied.",
    },
    "raw.githubusercontent.com": {
        "path": re.compile(
            r"^/elifesciences/elife-article-xml/master/articles/elife-81613-v1\.xml$"
        ),
        "license": "Creative Commons Attribution 4.0 International (CC BY 4.0), eLife article",
        "license_url": "https://elifesciences.org/terms",
        "attribution": "Source: eLife Research Article, DOI 10.7554/eLife.81613. Full article XML from the continuously updated elifesciences/elife-article-xml archive. Licensed CC BY 4.0; credit the article authors and eLife.",
    },
}


@dataclass(frozen=True)
class SourceLessonReview:
    lesson_path: str
    reviewed_on: str | None
    interval_days: int | None


@dataclass(frozen=True)
class SourceReference:
    url: str
    title: str
    lesson_reviews: tuple[SourceLessonReview, ...]

    @property
    def lesson_path(self) -> str:
        """Keep the original single-lesson field for the check-result API."""
        return self.lesson_reviews[0].lesson_path


class SourceSnapshotChanged(RuntimeError):
    """Raised when a source changed between preview and editorial confirmation."""


def _publisher_declared_date(value: str | None) -> str | None:
    """Accept bounded ISO date signals while preserving their declared timezone."""
    if value is None:
        return None
    candidate = " ".join(value.split())
    if len(candidate) > 40 or not _ISO_SOURCE_DATE.fullmatch(candidate):
        return None
    try:
        if "T" in candidate:
            datetime.fromisoformat(candidate[:-1] + "+00:00" if candidate.endswith("Z") else candidate)
        else:
            date.fromisoformat(candidate)
    except ValueError:
        return None
    return candidate


class _SourcePageParser(HTMLParser):
    """Extract bounded, human-readable metadata and visible text from HTML."""

    _SKIPPED_TAGS = frozenset({
        "script", "style", "noscript", "svg", "nav", "header", "footer", "aside", "form", "button",
    })
    _SEMANTIC_TAGS = frozenset({"main", "article"})
    _VOID_TAGS = frozenset({
        "area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta",
        "param", "source", "track", "wbr",
    })

    def __init__(self, *, xml_article: bool = False) -> None:
        super().__init__(convert_charrefs=True)
        self.xml_article = xml_article
        self.title_parts: list[str] = []
        self.description: str | None = None
        self.page_published_at: str | None = None
        self.page_updated_at: str | None = None
        self.fallback_parts: list[str] = []
        self.semantic_parts: list[str] = []
        self.in_title = False
        self.in_body = False
        self.semantic_depth = 0
        self.skip_depth = 0
        self.text_size = 0

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        tag = tag.casefold()
        attributes = {key.casefold(): value for key, value in attrs}
        if tag in self._SKIPPED_TAGS:
            self.skip_depth += 1
            return
        if self.skip_depth:
            if tag not in self._VOID_TAGS:
                self.skip_depth += 1
            return
        if tag == ("article-title" if self.xml_article else "title"):
            self.in_title = True
        elif tag == "body":
            self.in_body = True
        elif tag in self._SEMANTIC_TAGS:
            self.semantic_depth += 1
        elif tag == "meta":
            name = (attributes.get("name") or "").casefold()
            prop = (attributes.get("property") or "").casefold()
            itemprop = (attributes.get("itemprop") or "").casefold()
            content = " ".join((attributes.get("content") or "").split())
            if (
                content
                and len(content) <= _MAX_PAGE_DESCRIPTION_LENGTH * 3
                and (name == "description" or prop == "og:description")
                and self.description is None
            ):
                self.description = content[:_MAX_PAGE_DESCRIPTION_LENGTH]
            self._record_publisher_date(prop or itemprop or name, content)
        elif tag == "time":
            itemprop = (attributes.get("itemprop") or "").casefold()
            self._record_publisher_date(itemprop, attributes.get("datetime"))

    def _record_publisher_date(self, key: str, value: str | None) -> None:
        field = {
            "article:published_time": "page_published_at",
            "datepublished": "page_published_at",
            "article:modified_time": "page_updated_at",
            "og:updated_time": "page_updated_at",
            "datemodified": "page_updated_at",
        }.get(key)
        if field is None or getattr(self, field) is not None:
            return
        parsed = _publisher_declared_date(value)
        if parsed is not None:
            setattr(self, field, parsed)

    def handle_endtag(self, tag: str) -> None:
        tag = tag.casefold()
        if self.skip_depth:
            self.skip_depth -= 1
            return
        if tag == ("article-title" if self.xml_article else "title"):
            self.in_title = False
        elif tag == "body":
            self.in_body = False
        elif tag in self._SEMANTIC_TAGS and self.semantic_depth:
            self.semantic_depth -= 1

    def handle_data(self, data: str) -> None:
        if not data.strip() or self.skip_depth:
            return
        if self.in_title:
            self.title_parts.append(data)
            return
        if not self.in_body:
            return
        remaining = _MAX_EXTRACTED_TEXT_CHARS - self.text_size
        if remaining <= 0:
            return
        value = data[:remaining]
        self.text_size += len(value)
        self.fallback_parts.append(value)
        if self.semantic_depth:
            self.semantic_parts.append(value)

    @staticmethod
    def _normalize(parts: list[str]) -> str:
        return " ".join(" ".join(parts).split())

    def visible_text(self) -> str:
        return self._normalize(self.semantic_parts or self.fallback_parts)

    def publisher_dates(self) -> tuple[str | None, str | None]:
        return self.page_published_at, self.page_updated_at

    def result(self) -> tuple[str | None, str | None, str | None]:
        title = self._normalize(self.title_parts)[:_MAX_TITLE_LENGTH] or None
        description = self.description
        visible_text = self.visible_text()
        if not visible_text:
            return title, description, None
        digest = hashlib.sha256(visible_text.encode("utf-8")).hexdigest()
        return title, description, digest


class TrustedSourceMonitor:
    """Check only fixed-domain links authored in bundled course lessons."""

    def __init__(self, project_root: Path, database_path: Path) -> None:
        self.project_root = project_root.resolve()
        self.database_path = database_path.expanduser()
        self._db_lock = threading.RLock()

    @staticmethod
    def _canonical_url(value: str) -> str | None:
        value = value.strip().rstrip(_TRAILING_PUNCTUATION)
        try:
            parsed = urlsplit(value)
            port = parsed.port
        except ValueError:
            return None
        host = (parsed.hostname or "").casefold()
        if (
            parsed.scheme.casefold() != "https"
            or host not in _TRUSTED_HOSTS
            or parsed.username is not None
            or parsed.password is not None
            or port not in {None, 443}
            or parsed.query
            or len(value) > 2048
            or not _ALLOWED_PATHS[host].fullmatch(parsed.path)
        ):
            return None
        return urlunsplit(("https", host, parsed.path, "", ""))

    @classmethod
    def _is_approved_xml_source(cls, url: str) -> bool:
        """Allow XML/plain-text parsing only for the exact licensed eLife article archive file."""
        canonical = cls._canonical_url(url)
        if canonical is None:
            return False
        parsed = urlsplit(canonical)
        return parsed.hostname == "raw.githubusercontent.com" and parsed.path == (
            "/elifesciences/elife-article-xml/master/articles/elife-81613-v1.xml"
        )

    @classmethod
    def approved_markdown_links(
        cls, content: str, *, limit: int | None = 20
    ) -> list[dict[str, str]]:
        """Extract bounded titles and canonical URLs from approved official sources."""
        if limit is not None:
            limit = max(0, limit)
            if limit == 0:
                return []
        references: dict[str, dict[str, str]] = {}
        for line in content.splitlines():
            labels = {
                canonical: match.group(1).strip()
                for match in _MARKDOWN_LINK_RE.finditer(line)
                if (canonical := cls._canonical_url(match.group(2))) is not None
            }
            for match in _URL_RE.finditer(line):
                canonical = cls._canonical_url(match.group(0).rstrip(_TRAILING_PUNCTUATION))
                if canonical is None:
                    continue
                title = labels.get(canonical)
                if not title:
                    title = re.sub(r"[*_`]+", "", line[:match.start()]).strip(" \t-*•:;.,<>")
                if not title:
                    title = urlsplit(canonical).hostname or canonical
                references.setdefault(canonical, {
                    "title": title[:_MAX_TITLE_LENGTH],
                    "url": canonical,
                })
                if limit is not None and len(references) >= limit:
                    break
            if limit is not None and len(references) >= limit:
                break
        return [references[url] for url in sorted(references)]

    def _lesson_files(self) -> list[Path]:
        root = self.project_root / "02_Areas"
        if root.is_symlink() or not root.is_dir():
            return []
        files: list[Path] = []
        for current_root, directory_names, file_names in os.walk(root, followlinks=False):
            current = Path(current_root)
            directory_names.sort()
            directory_names[:] = [
                name for name in directory_names if not (current / name).is_symlink()
            ]
            if current.name.casefold() != "lessons":
                continue
            for file_name in sorted(file_names):
                path = current / file_name
                if path.suffix.casefold() == ".md" and not path.is_symlink():
                    files.append(path)
                    if len(files) >= _MAX_LESSON_FILES:
                        return sorted(files)
        return sorted(files)

    @staticmethod
    def _lesson_reviewed_on(content: str) -> str | None:
        """Read one valid source_checked date from the lesson's YAML front matter."""
        return _source_checked_date(content)

    def _references(self) -> tuple[list[SourceReference], int, int]:
        titles: dict[str, str] = {}
        lesson_reviews: dict[str, dict[str, SourceLessonReview]] = {}
        unsupported_urls: set[str] = set()
        for path in self._lesson_files():
            try:
                if path.stat().st_size > _MAX_LESSON_FILE_BYTES:
                    continue
                content = path.read_text(encoding="utf-8", errors="replace")
            except OSError:
                continue

            relative_path = path.relative_to(self.project_root).as_posix()
            lesson_review = SourceLessonReview(
                lesson_path=relative_path,
                reviewed_on=self._lesson_reviewed_on(content),
                interval_days=_source_review_interval_days(content),
            )
            for source in self.approved_markdown_links(content, limit=None):
                canonical = source["url"]
                titles.setdefault(canonical, source["title"])
                lesson_reviews.setdefault(canonical, {})[relative_path] = lesson_review
            for line in content.splitlines():
                for match in _URL_RE.finditer(line):
                    raw_url = match.group(0).rstrip(_TRAILING_PUNCTUATION)
                    canonical = self._canonical_url(raw_url)
                    if canonical is None:
                        if raw_url.casefold().startswith(("https://", "http://")):
                            unsupported_urls.add(raw_url[:2048])
                        continue
        ordered_refs = [
            SourceReference(
                url=url,
                title=titles[url],
                lesson_reviews=tuple(
                    lesson_reviews[url][path] for path in sorted(lesson_reviews[url])
                ),
            )
            for url in sorted(titles)
        ]
        omitted_count = max(0, len(ordered_refs) - _MAX_SOURCES)
        if omitted_count:
            # Keep the HTTP work bounded, but never permanently starve links
            # beyond the alphabetical batch. Unchecked and oldest references
            # get the next slots so the scheduler eventually visits the tail.
            with self._db_lock, self._connection() as connection:
                previous_checks = {
                    str(row["url"]): str(row["last_checked_at"])
                    for row in connection.execute(
                        "SELECT url, last_checked_at FROM trusted_source_checks"
                    ).fetchall()
                }

            minimum_time = datetime.min.replace(tzinfo=timezone.utc)

            def oldest_check_first(reference: SourceReference) -> tuple[int, datetime, str]:
                checked_text = previous_checks.get(reference.url)
                if checked_text is None:
                    return (0, minimum_time, reference.url)
                try:
                    checked_at = datetime.fromisoformat(checked_text.replace("Z", "+00:00"))
                except ValueError:
                    return (0, minimum_time, reference.url)
                if checked_at.tzinfo is None:
                    checked_at = checked_at.replace(tzinfo=timezone.utc)
                return (1, checked_at.astimezone(timezone.utc), reference.url)

            ordered_refs.sort(key=oldest_check_first)
        return ordered_refs[:_MAX_SOURCES], len(unsupported_urls), omitted_count

    def _connect(self) -> sqlite3.Connection:
        self.database_path.parent.mkdir(parents=True, exist_ok=True)
        connection = sqlite3.connect(self.database_path, timeout=10)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA busy_timeout = 10000")
        connection.execute(
            """CREATE TABLE IF NOT EXISTS trusted_source_checks (
                url TEXT PRIMARY KEY,
                etag TEXT,
                last_modified TEXT,
                last_checked_at TEXT NOT NULL,
                last_http_status INTEGER,
                state TEXT NOT NULL,
                pending_review_digest TEXT
            )"""
        )
        connection.execute(
            """CREATE TABLE IF NOT EXISTS trusted_source_rag_snapshots (
                url TEXT PRIMARY KEY,
                page_title TEXT NOT NULL,
                page_text TEXT NOT NULL,
                content_digest TEXT NOT NULL,
                fetched_at TEXT NOT NULL,
                license_name TEXT NOT NULL,
                license_url TEXT NOT NULL,
                attribution TEXT NOT NULL
            )"""
        )
        columns = {
            str(row["name"])
            for row in connection.execute("PRAGMA table_info(trusted_source_checks)").fetchall()
        }
        for column, declaration in (
            ("page_title", "TEXT"),
            ("page_description", "TEXT"),
            ("page_published_at", "TEXT"),
            ("page_updated_at", "TEXT"),
            ("content_digest", "TEXT"),
            ("content_checked_at", "TEXT"),
            ("pending_review_digest", "TEXT"),
        ):
            if column not in columns:
                connection.execute(
                    f"ALTER TABLE trusted_source_checks ADD COLUMN {column} {declaration}"
                )
        connection.execute(
            "UPDATE trusted_source_checks SET pending_review_digest = content_digest "
            "WHERE state = 'changed' AND pending_review_digest IS NULL AND content_digest IS NOT NULL"
        )
        connection.execute(
            """CREATE TABLE IF NOT EXISTS trusted_source_editorial_reviews (
                review_id INTEGER PRIMARY KEY AUTOINCREMENT,
                url TEXT NOT NULL,
                lesson_path TEXT NOT NULL,
                reviewed_digest TEXT NOT NULL,
                reviewed_on TEXT NOT NULL,
                reviewed_at TEXT NOT NULL
            )"""
        )
        connection.execute(
            "CREATE INDEX IF NOT EXISTS idx_source_editorial_reviews_latest "
            "ON trusted_source_editorial_reviews(url, lesson_path, review_id DESC)"
        )
        connection.execute(
            "CREATE INDEX IF NOT EXISTS idx_source_editorial_reviews_history "
            "ON trusted_source_editorial_reviews(url, review_id DESC)"
        )
        return connection

    @contextmanager
    def _connection(self) -> Iterator[sqlite3.Connection]:
        """Commit or roll back a SQLite unit of work, then always close its handle."""
        connection = self._connect()
        try:
            with connection:
                yield connection
        finally:
            connection.close()

    def inventory(self, *, today: date | None = None) -> dict[str, object]:
        """Return the approved source registry and saved check metadata without network access."""
        references, unsupported_count, omitted_count = self._references()
        with self._db_lock, self._connection() as connection:
            previous_checks = {
                str(row["url"]): row
                for row in connection.execute(
                    "SELECT url, etag, last_modified, last_checked_at, last_http_status, state, "
                    "page_title, page_description, page_published_at, page_updated_at, "
                    "content_digest, content_checked_at, "
                    "pending_review_digest "
                    "FROM trusted_source_checks"
                ).fetchall()
            }
            rag_snapshots = {
                str(row["url"]): row
                for row in connection.execute(
                    "SELECT url, fetched_at, license_name FROM trusted_source_rag_snapshots"
                ).fetchall()
            }
            manual_reviews = {
                (str(row["url"]), str(row["lesson_path"])): row
                for row in connection.execute(
                    """SELECT review_id, url, lesson_path, reviewed_digest, reviewed_on, reviewed_at
                    FROM trusted_source_editorial_reviews AS review
                    WHERE review_id = (
                        SELECT MAX(latest.review_id) FROM trusted_source_editorial_reviews AS latest
                        WHERE latest.url = review.url AND latest.lesson_path = review.lesson_path
                    )"""
                ).fetchall()
            }

        items: list[dict[str, object]] = []
        for reference in references:
            previous = previous_checks.get(reference.url)
            lesson_review_items: list[dict[str, object]] = []
            for lesson_review in reference.lesson_reviews:
                reviewed_on = lesson_review.reviewed_on
                manual_review = manual_reviews.get((reference.url, lesson_review.lesson_path))
                if (
                    manual_review is not None
                    and previous is not None
                    and previous["content_digest"]
                    and str(manual_review["reviewed_digest"]) == str(previous["content_digest"])
                    and (
                        reviewed_on is None
                        or str(manual_review["reviewed_on"]) >= reviewed_on
                    )
                ):
                    reviewed_on = str(manual_review["reviewed_on"])
                due_on, schedule_status = _source_review_schedule(
                    reviewed_on,
                    lesson_review.interval_days,
                    today,
                )
                if reviewed_on is None:
                    editorial_status = "review_missing"
                elif schedule_status is None:
                    editorial_status = "review_unscheduled"
                else:
                    editorial_status = f"review_{schedule_status}"
                lesson_review_items.append({
                    "lesson_path": lesson_review.lesson_path,
                    "lesson_reviewed_on": reviewed_on,
                    "editorial_review_interval_days": lesson_review.interval_days,
                    "editorial_review_due_on": due_on,
                    "editorial_review_status": editorial_status,
                })
            lesson_review_statuses = [
                str(item["editorial_review_status"]) for item in lesson_review_items
            ]
            editorial_review_status = next(
                (
                    status for status in (
                        "review_due", "review_missing", "review_unscheduled", "review_scheduled"
                    ) if status in lesson_review_statuses
                ),
                "review_missing",
            )
            due_dates = [
                str(item["editorial_review_due_on"])
                for item in lesson_review_items
                if item["editorial_review_due_on"] is not None
            ]
            first_review = reference.lesson_reviews[0]
            rag_policy = self._rag_policy(reference.url)
            rag_snapshot = rag_snapshots.get(reference.url)
            items.append({
                "url": reference.url,
                "title": reference.title[:_MAX_TITLE_LENGTH],
                "lesson_path": reference.lesson_path,
                "lesson_paths": [item.lesson_path for item in reference.lesson_reviews],
                "lesson_reviews": lesson_review_items,
                "lesson_reviewed_on": first_review.reviewed_on,
                "editorial_review_interval_days": first_review.interval_days,
                "editorial_review_due_on": min(due_dates) if due_dates else None,
                "editorial_review_status": editorial_review_status,
                "state": str(previous["state"]) if previous is not None else "not_checked",
                "last_checked_at": str(previous["last_checked_at"]) if previous is not None else None,
                "last_http_status": int(previous["last_http_status"])
                    if previous is not None and previous["last_http_status"] is not None else None,
                "last_modified": str(previous["last_modified"])
                    if previous is not None and previous["last_modified"] else None,
                "has_etag": bool(previous["etag"]) if previous is not None else False,
                "page_title": str(previous["page_title"])
                    if previous is not None and previous["page_title"] else None,
                "page_description": str(previous["page_description"])
                    if previous is not None and previous["page_description"] else None,
                "page_published_at": str(previous["page_published_at"])
                    if previous is not None and previous["page_published_at"] else None,
                "page_updated_at": str(previous["page_updated_at"])
                    if previous is not None and previous["page_updated_at"] else None,
                "content_checked_at": str(previous["content_checked_at"])
                    if previous is not None and previous["content_checked_at"] else None,
                "rag_content_state": (
                    "cached" if rag_snapshot is not None
                    else "license_approved_pending_check" if rag_policy is not None
                    else "metadata_only_rights_review" if urlsplit(reference.url).hostname == "openstax.org"
                    else "metadata_only"
                ),
                "rag_content_fetched_at": (
                    str(rag_snapshot["fetched_at"]) if rag_snapshot is not None else None
                ),
                "rag_license": (
                    rag_policy["license"] if rag_policy is not None else None
                ),
                "rag_license_url": (
                    rag_policy["license_url"] if rag_policy is not None else None
                ),
                "rag_restriction_url": (
                    "https://help.openstax.org/s/article/Licensing-information-of-OpenStax-textbooks"
                    if urlsplit(reference.url).hostname == "openstax.org" else None
                ),
            })

            pending_review_digest = (
                str(previous["pending_review_digest"])
                if previous is not None and previous["pending_review_digest"] else None
            )
            if pending_review_digest is not None:
                all_lessons_reviewed = all(
                    manual_reviews.get((reference.url, lesson.lesson_path)) is not None
                    and str(manual_reviews[(reference.url, lesson.lesson_path)]["reviewed_digest"])
                    == pending_review_digest
                    for lesson in reference.lesson_reviews
                )
                if all_lessons_reviewed:
                    if items[-1]["state"] == "changed":
                        items[-1]["state"] = "unchanged"
                else:
                    items[-1]["state"] = "changed"

        states = [str(item["state"]) for item in items]
        attention_states = {
            "changed", "content_baseline", "content_unavailable", "content_too_large",
            "unsupported_content_type", "redirect_review", "unexpected_not_modified",
            "unavailable", "network_error",
        }
        editorial_states = [str(item["editorial_review_status"]) for item in items]
        return {
            "status": "ok",
            "supported_count": len(references) + omitted_count,
            "listed_count": len(references),
            "unchecked_count": states.count("not_checked"),
            "changed_count": states.count("changed"),
            "needs_attention_count": sum(state in attention_states for state in states),
            "editorial_review_due_count": editorial_states.count("review_due"),
            "editorial_review_scheduled_count": editorial_states.count("review_scheduled"),
            "editorial_review_missing_count": editorial_states.count("review_missing"),
            "editorial_review_unscheduled_count": editorial_states.count("review_unscheduled"),
            "unsupported_count": unsupported_count,
            "omitted_count": omitted_count,
            "sources": items,
        }

    def _save_editorial_review(
        self, url: str, lesson_path: str, digest: str, reviewed_on: str, reviewed_at: str
    ) -> None:
        with self._db_lock, self._connection() as connection:
            connection.execute(
                """INSERT INTO trusted_source_editorial_reviews(
                    url, lesson_path, reviewed_digest, reviewed_on, reviewed_at
                ) VALUES (?, ?, ?, ?, ?)""",
                (url, lesson_path, digest, reviewed_on, reviewed_at),
            )
            connection.execute(
                """DELETE FROM trusted_source_editorial_reviews
                WHERE review_id NOT IN (
                    SELECT review_id FROM trusted_source_editorial_reviews
                    ORDER BY review_id DESC LIMIT 10000
                )"""
            )

    def _clear_pending_review_if_complete(self, reference: SourceReference) -> None:
        previous = self._previous_check(reference.url)
        if previous is None or not previous["pending_review_digest"]:
            return
        pending_digest = str(previous["pending_review_digest"])
        with self._db_lock, self._connection() as connection:
            latest_reviews = {
                str(row["lesson_path"]): str(row["reviewed_digest"])
                for row in connection.execute(
                    """SELECT review.lesson_path, review.reviewed_digest
                    FROM trusted_source_editorial_reviews AS review
                    WHERE review.url = ? AND review.review_id = (
                        SELECT MAX(latest.review_id) FROM trusted_source_editorial_reviews AS latest
                        WHERE latest.url = review.url AND latest.lesson_path = review.lesson_path
                    )""",
                    (reference.url,),
                ).fetchall()
            }
            if not all(
                latest_reviews.get(lesson.lesson_path) == pending_digest
                for lesson in reference.lesson_reviews
            ):
                return
            connection.execute(
                """UPDATE trusted_source_checks
                SET pending_review_digest = NULL,
                    state = CASE WHEN state = 'changed' THEN 'unchanged' ELSE state END
                WHERE url = ? AND pending_review_digest = ?""",
                (reference.url, pending_digest),
            )

    def _automatic_check_schedule(
        self,
        references: list[SourceReference],
        current: datetime,
    ) -> list[tuple[SourceReference, float]]:
        """Pair each approved source with its own delay before its next check."""
        if current.tzinfo is None:
            current = current.replace(tzinfo=timezone.utc)
        with self._db_lock, self._connection() as connection:
            previous_checks = {
                str(row["url"]): row
                for row in connection.execute(
                    "SELECT url, last_checked_at, state FROM trusted_source_checks"
                ).fetchall()
            }

        schedule: list[tuple[SourceReference, float]] = []
        for reference in references:
            previous = previous_checks.get(reference.url)
            if previous is None:
                schedule.append((reference, 0.0))
                continue
            try:
                checked_at = datetime.fromisoformat(
                    str(previous["last_checked_at"]).replace("Z", "+00:00")
                )
            except (TypeError, ValueError):
                schedule.append((reference, 0.0))
                continue
            if checked_at.tzinfo is None:
                checked_at = checked_at.replace(tzinfo=timezone.utc)
            interval = (
                _AUTO_RETRY_INTERVAL
                if str(previous["state"]) in _TRANSIENT_SOURCE_STATES
                else _AUTO_CHECK_INTERVAL
            )
            schedule.append((reference, (checked_at + interval - current).total_seconds()))
        return schedule

    def seconds_until_automatic_check(self, *, now: datetime | None = None) -> float | None:
        """Return delay until the next bounded check, retrying transient failures sooner."""
        references, _, _ = self._references()
        if not references:
            return None
        current = now or datetime.now(timezone.utc)
        if current.tzinfo is None:
            current = current.replace(tzinfo=timezone.utc)
        delays = [delay for _, delay in self._automatic_check_schedule(references, current)]
        return max(0.0, min(delays)) if delays else None

    def _previous_check(self, url: str) -> sqlite3.Row | None:
        with self._db_lock, self._connection() as connection:
            return connection.execute(
                "SELECT * FROM trusted_source_checks WHERE url = ?", (url,)
            ).fetchone()

    def _has_rag_snapshot(self, url: str) -> bool:
        if self._rag_policy(url) is None:
            return False
        with self._db_lock, self._connection() as connection:
            return connection.execute(
                "SELECT 1 FROM trusted_source_rag_snapshots WHERE url = ?", (url,)
            ).fetchone() is not None

    @classmethod
    def _rag_policy(cls, url: str) -> dict[str, str] | None:
        canonical = cls._canonical_url(url)
        if canonical is None:
            return None
        parsed = urlsplit(canonical)
        policy = _RAG_SOURCE_POLICIES.get(parsed.hostname or "")
        if policy is None or not policy["path"].fullmatch(parsed.path):
            return None
        return {key: value for key, value in policy.items() if key != "path"}

    def _save_rag_snapshot(
        self,
        url: str,
        *,
        title: str,
        text: str,
        digest: str,
        fetched_at: str,
    ) -> None:
        policy = self._rag_policy(url)
        if policy is None or not text:
            return
        with self._db_lock, self._connection() as connection:
            connection.execute(
                """INSERT INTO trusted_source_rag_snapshots(
                    url, page_title, page_text, content_digest, fetched_at,
                    license_name, license_url, attribution
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(url) DO UPDATE SET
                    page_title = excluded.page_title,
                    page_text = excluded.page_text,
                    content_digest = excluded.content_digest,
                    fetched_at = excluded.fetched_at,
                    license_name = excluded.license_name,
                    license_url = excluded.license_url,
                    attribution = excluded.attribution""",
                (
                    url, title[:_MAX_TITLE_LENGTH], text[:_MAX_RAG_SOURCE_CHARS], digest,
                    fetched_at, policy["license"], policy["license_url"], policy["attribution"],
                ),
            )

    def search_rag_sources(
        self, query: str, limit: int = _MAX_RAG_RESULTS
    ) -> list[dict[str, str]]:
        """Return relevant excerpts from fresh snapshots with an explicit reuse license."""
        terms = tuple(sorted({
            token.casefold()
            for token in _RAG_TOKEN_RE.findall(query)
            if len(token) > 2
        }))
        if not terms or limit <= 0:
            return []
        references, _, _ = self._references()
        eligible_urls = [
            reference.url for reference in references
            if self._rag_policy(reference.url) is not None
        ]
        if not eligible_urls:
            return []
        now = datetime.now(timezone.utc)
        cutoff = (now - _MAX_RAG_CHECK_AGE).isoformat(timespec="seconds").replace("+00:00", "Z")
        placeholders = ",".join("?" for _ in eligible_urls)
        with self._db_lock, self._connection() as connection:
            rows = connection.execute(
                f"""SELECT snapshot.url, snapshot.page_title, snapshot.page_text,
                           snapshot.fetched_at, snapshot.license_name, snapshot.license_url,
                           snapshot.attribution, check_record.state,
                           check_record.last_checked_at, check_record.page_published_at,
                           check_record.page_updated_at
                    FROM trusted_source_rag_snapshots AS snapshot
                    JOIN trusted_source_checks AS check_record ON check_record.url = snapshot.url
                    WHERE snapshot.url IN ({placeholders})
                      AND check_record.last_checked_at >= ?
                      AND check_record.state IN (
                          'available_untracked', 'content_baseline', 'changed', 'unchanged'
                      )
                    ORDER BY snapshot.url""",
                (*eligible_urls, cutoff),
            ).fetchall()

        def excerpt_documents(row: sqlite3.Row):
            sentences = [
                part.strip() for part in re.split(r"(?<=[.!?])\s+", str(row["page_text"]))
                if part.strip()
            ]
            for start in range(0, len(sentences), 3):
                excerpt = " ".join(sentences[start:start + 5])[:_MAX_RAG_EXCERPT_CHARS]
                excerpt_terms = Counter(
                    token.casefold() for token in _RAG_TOKEN_RE.findall(excerpt)
                )
                yield excerpt, excerpt_terms

        document_frequency: Counter[str] = Counter()
        document_count = 0
        total_document_length = 0
        for row in rows:
            for _, excerpt_terms in excerpt_documents(row):
                document_count += 1
                total_document_length += sum(excerpt_terms.values())
                document_frequency.update(
                    term for term in terms if excerpt_terms[term] > 0
                )
        if document_count == 0:
            return []
        average_length = total_document_length / document_count
        if average_length <= 0:
            return []

        ranked_by_url: dict[str, tuple[float, dict[str, str]]] = {}
        for row in rows:
            for excerpt, excerpt_terms in excerpt_documents(row):
                document_length = sum(excerpt_terms.values())
                score = 0.0
                for term in terms:
                    frequency = excerpt_terms[term]
                    if frequency <= 0:
                        continue
                    frequency_in_corpus = document_frequency[term]
                    inverse_document_frequency = math.log(
                        1
                        + (document_count - frequency_in_corpus + 0.5)
                        / (frequency_in_corpus + 0.5)
                    )
                    length_normalization = _BM25_K1 * (
                        1 - _BM25_B + _BM25_B * document_length / average_length
                    )
                    score += (
                        inverse_document_frequency
                        * frequency
                        * (_BM25_K1 + 1)
                        / (frequency + length_normalization)
                    )
                if score <= 0:
                    continue
                source = {
                    "id": "",
                    "title": str(row["page_title"] or row["url"])[:_MAX_TITLE_LENGTH],
                    "path": str(row["url"]),
                    "location": str(row["url"]),
                    "excerpt": excerpt,
                    "retrieved_at": now.isoformat(timespec="seconds"),
                    "source_type": "official_web",
                    "source_checked_at": str(row["last_checked_at"]),
                    "source_snapshot_fetched_at": str(row["fetched_at"]),
                    "license": str(row["license_name"]),
                    "license_url": str(row["license_url"]),
                    "attribution": str(row["attribution"]),
                }
                if row["page_published_at"]:
                    source["page_published_at"] = str(row["page_published_at"])
                if row["page_updated_at"]:
                    source["page_updated_at"] = str(row["page_updated_at"])
                previous = ranked_by_url.get(source["path"])
                if previous is None or score > previous[0]:
                    ranked_by_url[source["path"]] = (score, source)

        ranked = sorted(ranked_by_url.values(), key=lambda item: (-item[0], item[1]["path"]))
        return [item for _, item in ranked[:min(limit, _MAX_RAG_RESULTS)]]

    def _save_check(
        self,
        reference: SourceReference,
        *,
        etag: str | None,
        last_modified: str | None,
        checked_at: str,
        http_status: int | None,
        state: str,
        page_title: str | None = None,
        page_description: str | None = None,
        page_published_at: str | None = None,
        page_updated_at: str | None = None,
        content_digest: str | None = None,
        content_checked_at: str | None = None,
        preserve_content_metadata: bool = False,
    ) -> None:
        with self._db_lock, self._connection() as connection:
            connection.execute(
                """INSERT INTO trusted_source_checks(
                    url, etag, last_modified, last_checked_at, last_http_status, state,
                    page_title, page_description, page_published_at, page_updated_at,
                    content_digest, content_checked_at,
                    pending_review_digest
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                    CASE WHEN ? = 'changed' THEN ? ELSE NULL END)
                ON CONFLICT(url) DO UPDATE SET
                    etag = excluded.etag,
                    last_modified = excluded.last_modified,
                    last_checked_at = excluded.last_checked_at,
                    last_http_status = excluded.last_http_status,
                    state = excluded.state,
                    page_title = CASE WHEN ? THEN trusted_source_checks.page_title ELSE excluded.page_title END,
                    page_description = CASE WHEN ? THEN trusted_source_checks.page_description ELSE excluded.page_description END,
                    page_published_at = CASE WHEN ? THEN trusted_source_checks.page_published_at ELSE excluded.page_published_at END,
                    page_updated_at = CASE WHEN ? THEN trusted_source_checks.page_updated_at ELSE excluded.page_updated_at END,
                    content_digest = CASE WHEN ? THEN trusted_source_checks.content_digest ELSE excluded.content_digest END,
                    content_checked_at = CASE WHEN ? THEN trusted_source_checks.content_checked_at ELSE excluded.content_checked_at END,
                    pending_review_digest = CASE
                        WHEN excluded.state = 'changed' THEN excluded.content_digest
                        ELSE trusted_source_checks.pending_review_digest END""",
                (
                    reference.url, etag, last_modified, checked_at, http_status, state,
                    page_title, page_description, page_published_at, page_updated_at,
                    content_digest, content_checked_at,
                    state, content_digest,
                    preserve_content_metadata, preserve_content_metadata,
                    preserve_content_metadata, preserve_content_metadata,
                    preserve_content_metadata, preserve_content_metadata,
                ),
            )

    @staticmethod
    def _bounded_header(value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = " ".join(value.split())
        return cleaned[:_MAX_VALIDATOR_LENGTH] or None

    @staticmethod
    async def _read_bounded_html(response: httpx.Response) -> tuple[bytes | None, bool]:
        """Read at most a fixed number of decoded response bytes into memory."""
        content_length = response.headers.get("content-length")
        if content_length:
            try:
                if int(content_length) > _MAX_SOURCE_PAGE_BYTES:
                    return None, True
            except ValueError:
                pass

        body = bytearray()
        async for chunk in response.aiter_bytes(chunk_size=16 * 1024):
            if len(body) + len(chunk) > _MAX_SOURCE_PAGE_BYTES:
                return None, True
            body.extend(chunk)
        return bytes(body), False

    @staticmethod
    def _parse_source_page(
        body: bytes, encoding: str | None, *, xml_article: bool = False
    ) -> tuple[str | None, str | None, str | None]:
        try:
            decoded = body.decode(encoding or "utf-8", errors="replace")
        except LookupError:
            decoded = body.decode("utf-8", errors="replace")
        parser = _SourcePageParser(xml_article=xml_article)
        parser.feed(decoded)
        parser.close()
        return parser.result()

    @staticmethod
    def _parse_source_page_preview(
        body: bytes, encoding: str | None, *, xml_article: bool = False
    ) -> tuple[str | None, str | None, str | None, str | None, str | None, str]:
        try:
            decoded = body.decode(encoding or "utf-8", errors="replace")
        except LookupError:
            decoded = body.decode("utf-8", errors="replace")
        parser = _SourcePageParser(xml_article=xml_article)
        parser.feed(decoded)
        parser.close()
        title, description, digest = parser.result()
        published_at, updated_at = parser.publisher_dates()
        return title, description, digest, published_at, updated_at, parser.visible_text()

    @staticmethod
    def _validator_changed(
        previous: sqlite3.Row | None, etag: str | None, last_modified: str | None
    ) -> bool | None:
        if previous is None:
            return None
        comparisons: list[bool] = []
        for name, current in (("etag", etag), ("last_modified", last_modified)):
            old = previous[name]
            if old and current:
                comparisons.append(old != current)
        if not comparisons:
            return None
        return any(comparisons)

    async def _check_one(
        self,
        client: httpx.AsyncClient,
        reference: SourceReference,
        semaphore: asyncio.Semaphore,
    ) -> dict[str, object]:
        previous = self._previous_check(reference.url)
        accept = "text/html,application/xhtml+xml;q=0.9"
        if self._is_approved_xml_source(reference.url):
            accept = "application/xml,text/xml,text/plain;q=0.9"
        headers = {
            "Accept": accept,
            "Accept-Encoding": "identity",
            "User-Agent": "ColiDev-Reference-Check/1.0",
        }
        # Legacy rows have HTTP validators but no content fingerprint. Fetch a
        # bounded page once to establish a content baseline before using 304.
        if previous is not None and previous["content_digest"] and (
            self._rag_policy(reference.url) is None or self._has_rag_snapshot(reference.url)
        ):
            if previous["etag"]:
                headers["If-None-Match"] = str(previous["etag"])
            elif previous["last_modified"]:
                headers["If-Modified-Since"] = str(previous["last_modified"])

        checked_at = datetime.now(timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")
        page_title = str(previous["page_title"]) if previous is not None and previous["page_title"] else None
        page_description = (
            str(previous["page_description"])
            if previous is not None and previous["page_description"] else None
        )
        page_published_at = (
            str(previous["page_published_at"])
            if previous is not None and previous["page_published_at"] else None
        )
        page_updated_at = (
            str(previous["page_updated_at"])
            if previous is not None and previous["page_updated_at"] else None
        )
        content_digest = (
            str(previous["content_digest"])
            if previous is not None and previous["content_digest"] else None
        )
        content_checked_at = (
            str(previous["content_checked_at"])
            if previous is not None and previous["content_checked_at"] else None
        )
        preserve_content_metadata = True
        rag_page_text: str | None = None
        async with semaphore:
            try:
                async with client.stream(
                    "GET", reference.url, headers=headers, follow_redirects=False
                ) as response:
                    http_status = response.status_code
                    etag = self._bounded_header(response.headers.get("etag"))
                    last_modified = self._bounded_header(response.headers.get("last-modified"))
                    if http_status == 304 and previous is not None and previous["content_digest"]:
                        state = "unchanged"
                        etag = etag or previous["etag"]
                        last_modified = last_modified or previous["last_modified"]
                        content_checked_at = checked_at
                        preserve_content_metadata = False
                    elif 200 <= http_status < 300:
                        content_type = (
                            response.headers.get("content-type", "")
                            .split(";", 1)[0]
                            .strip()
                            .casefold()
                        )
                        if http_status != 200:
                            state = "content_unavailable"
                        elif content_type not in {"text/html", "application/xhtml+xml"} and not (
                            self._is_approved_xml_source(reference.url)
                            and content_type in {"text/plain", "text/xml", "application/xml"}
                        ):
                            state = "unsupported_content_type"
                        else:
                            body, too_large = await self._read_bounded_html(response)
                            if too_large:
                                state = "content_too_large"
                            elif not body:
                                state = "content_unavailable"
                            else:
                                (
                                    parsed_title,
                                    parsed_description,
                                    parsed_digest,
                                    parsed_published_at,
                                    parsed_updated_at,
                                    parsed_text,
                                ) = self._parse_source_page_preview(
                                    body,
                                    response.encoding,
                                    xml_article=self._is_approved_xml_source(reference.url),
                                )
                                if parsed_digest is None:
                                    state = "content_unavailable"
                                else:
                                    effective_title = parsed_title or reference.title
                                    metadata_changed = previous is not None and (
                                        effective_title != previous["page_title"]
                                        or parsed_description != previous["page_description"]
                                    )
                                    page_title = effective_title
                                    page_description = parsed_description
                                    page_published_at = parsed_published_at
                                    page_updated_at = parsed_updated_at
                                    content_digest = parsed_digest
                                    content_checked_at = checked_at
                                    if self._rag_policy(reference.url) is not None:
                                        rag_page_text = parsed_text
                                    preserve_content_metadata = False
                                    validator_changed = self._validator_changed(
                                        previous, etag, last_modified
                                    )
                                    if previous is None:
                                        state = "available_untracked"
                                    elif previous["content_digest"] is None:
                                        state = "content_baseline"
                                    elif (
                                        parsed_digest != previous["content_digest"]
                                        or validator_changed is True
                                        or metadata_changed
                                    ):
                                        state = "changed"
                                    else:
                                        state = "unchanged"
                    elif http_status == 304:
                        state = "unexpected_not_modified"
                    elif 300 <= http_status < 400:
                        state = "redirect_review"
                    else:
                        state = "unavailable"
            except httpx.HTTPError:
                state = "network_error"
                etag = previous["etag"] if previous is not None else None
                last_modified = previous["last_modified"] if previous is not None else None
                http_status = None
                preserve_content_metadata = True

            if state in {
                "unsupported_content_type", "content_too_large", "content_unavailable",
                "unexpected_not_modified", "redirect_review", "unavailable", "network_error",
            }:
                etag = previous["etag"] if previous is not None else None
                last_modified = previous["last_modified"] if previous is not None else None
                preserve_content_metadata = True

            self._save_check(
                reference,
                etag=etag,
                last_modified=last_modified,
                checked_at=checked_at,
                http_status=http_status,
                state=state,
                page_title=page_title,
                page_description=page_description,
                page_published_at=page_published_at,
                page_updated_at=page_updated_at,
                content_digest=content_digest,
                content_checked_at=content_checked_at,
                preserve_content_metadata=preserve_content_metadata,
            )
            if rag_page_text is not None and content_digest is not None:
                self._save_rag_snapshot(
                    reference.url,
                    title=page_title or reference.title,
                    text=rag_page_text,
                    digest=content_digest,
                    fetched_at=checked_at,
                )
        return {
            "url": reference.url,
            "title": reference.title[:_MAX_TITLE_LENGTH],
            "lesson_path": reference.lesson_path,
            "state": state,
            "http_status": http_status,
            "etag": etag,
            "last_modified": last_modified,
            "checked_at": checked_at,
            "page_title": page_title,
            "page_description": page_description,
            "page_published_at": page_published_at,
            "page_updated_at": page_updated_at,
            "content_checked_at": content_checked_at,
        }

    async def check_sources(
        self,
        client: httpx.AsyncClient | None = None,
        *,
        due_only: bool = False,
    ) -> dict[str, object]:
        references, unsupported_count, omitted_count = self._references()
        supported_count = len(references) + omitted_count
        if due_only and references:
            current = datetime.now(timezone.utc)
            schedule = self._automatic_check_schedule(references, current)
            references = [reference for reference, delay in schedule if delay <= 0]
        semaphore = asyncio.Semaphore(_MAX_CONCURRENT_REQUESTS)
        if client is None:
            async with httpx.AsyncClient(
                timeout=httpx.Timeout(connect=3.0, read=6.0, write=3.0, pool=3.0),
                limits=httpx.Limits(max_connections=_MAX_CONCURRENT_REQUESTS),
                follow_redirects=False,
                trust_env=False,
            ) as owned_client:
                results = await asyncio.gather(
                    *(self._check_one(owned_client, ref, semaphore) for ref in references)
                )
        else:
            results = await asyncio.gather(
                *(self._check_one(client, ref, semaphore) for ref in references)
            )

        counts = {state: sum(item["state"] == state for item in results) for state in (
            "available_untracked", "content_baseline", "changed", "unchanged",
            "content_unavailable", "content_too_large", "unsupported_content_type",
            "redirect_review", "unexpected_not_modified", "unavailable", "network_error",
        )}
        return {
            "status": "ok",
            "supported_count": supported_count,
            "checked_count": (
                counts["available_untracked"] + counts["content_baseline"]
                + counts["changed"] + counts["unchanged"]
            ),
            "changed_count": counts["changed"],
            "unchanged_count": counts["unchanged"],
            "available_untracked_count": counts["available_untracked"],
            "needs_attention_count": (
                counts["content_baseline"] + counts["content_unavailable"]
                + counts["content_too_large"] + counts["unsupported_content_type"]
                + counts["redirect_review"] + counts["unexpected_not_modified"]
                + counts["unavailable"] + counts["network_error"]
            ),
            "unsupported_count": unsupported_count,
            "omitted_count": omitted_count,
            "checks": results,
        }

    async def preview_source(
        self, url: str, client: httpx.AsyncClient | None = None
    ) -> dict[str, object]:
        """Fetch a short, non-persistent preview for one exact approved lesson URL."""
        canonical = self._canonical_url(url)
        references, _, _ = self._references()
        reference = next((item for item in references if item.url == canonical), None)
        if reference is None:
            raise ValueError("Source is not in the approved lesson inventory")

        headers = {
            "Accept": "text/html,application/xhtml+xml;q=0.9",
            "Accept-Encoding": "identity",
            "User-Agent": "ColiDev-Reference-Preview/1.0",
        }

        async def fetch(active_client: httpx.AsyncClient) -> dict[str, object]:
            async with active_client.stream(
                "GET", reference.url, headers=headers, follow_redirects=False
            ) as response:
                if response.status_code != 200:
                    raise RuntimeError("Approved source did not return HTTP 200")
                content_type = (
                    response.headers.get("content-type", "")
                    .split(";", 1)[0]
                    .strip()
                    .casefold()
                )
                if content_type not in {"text/html", "application/xhtml+xml"} and not (
                    self._is_approved_xml_source(reference.url)
                    and content_type in {"text/plain", "text/xml", "application/xml"}
                ):
                    raise RuntimeError("Approved source returned an unsupported content type")
                body, too_large = await self._read_bounded_html(response)
                if too_large or not body:
                    raise RuntimeError("Approved source preview is unavailable")
                encoding = response.encoding

            (
                title,
                description,
                digest,
                page_published_at,
                page_updated_at,
                visible_text,
            ) = self._parse_source_page_preview(
                body,
                encoding,
                xml_article=self._is_approved_xml_source(reference.url),
            )
            if digest is None:
                raise RuntimeError("Approved source has no readable text")
            return {
                "url": reference.url,
                "title": reference.title,
                "lesson_paths": [review.lesson_path for review in reference.lesson_reviews],
                "page_title": title or reference.title,
                "page_description": description,
                "page_published_at": page_published_at,
                "page_updated_at": page_updated_at,
                "etag": self._bounded_header(response.headers.get("etag")),
                "last_modified": self._bounded_header(response.headers.get("last-modified")),
                "excerpt": visible_text[:_MAX_SOURCE_PREVIEW_CHARS],
                "excerpt_truncated": len(visible_text) > _MAX_SOURCE_PREVIEW_CHARS,
                "content_digest": digest,
                "fetched_at": datetime.now(timezone.utc).isoformat(timespec="seconds").replace(
                    "+00:00", "Z"
                ),
            }

        if client is not None:
            return await fetch(client)
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(connect=3.0, read=6.0, write=3.0, pool=3.0),
            follow_redirects=False,
            trust_env=False,
        ) as owned_client:
            return await fetch(owned_client)

    async def review_source(
        self,
        url: str,
        lesson_path: str,
        preview_digest: str,
        client: httpx.AsyncClient | None = None,
    ) -> dict[str, object]:
        """Re-fetch a preview, compare its digest, and save an editorial review event."""
        canonical = self._canonical_url(url)
        references, _, _ = self._references()
        reference = next((item for item in references if item.url == canonical), None)
        if reference is None or lesson_path not in {
            item.lesson_path for item in reference.lesson_reviews
        }:
            raise ValueError("Source and lesson are not in the approved inventory")

        fresh = await self.preview_source(url, client)
        digest = str(fresh["content_digest"])
        if digest != preview_digest:
            raise SourceSnapshotChanged("Source changed after the displayed preview")

        reviewed_at = str(fresh["fetched_at"])
        reviewed_on = reviewed_at[:10]
        previous = self._previous_check(reference.url)
        previous_digest = str(previous["content_digest"]) if previous and previous["content_digest"] else None
        if previous is None:
            state = "available_untracked"
        elif previous_digest is None:
            state = "content_baseline"
        elif previous_digest != digest:
            state = "changed"
        else:
            state = "unchanged"
        self._save_check(
            reference,
            etag=str(fresh["etag"]) if fresh["etag"] else None,
            last_modified=str(fresh["last_modified"]) if fresh["last_modified"] else None,
            checked_at=reviewed_at,
            http_status=200,
            state=state,
            page_title=str(fresh["page_title"]) if fresh["page_title"] else None,
            page_description=str(fresh["page_description"]) if fresh["page_description"] else None,
            page_published_at=(
                str(fresh["page_published_at"]) if fresh["page_published_at"] else None
            ),
            page_updated_at=(
                str(fresh["page_updated_at"]) if fresh["page_updated_at"] else None
            ),
            content_digest=digest,
            content_checked_at=reviewed_at,
        )
        self._save_editorial_review(reference.url, lesson_path, digest, reviewed_on, reviewed_at)
        self._clear_pending_review_if_complete(reference)
        return {
            "status": "ok",
            "url": reference.url,
            "lesson_path": lesson_path,
            "reviewed_on": reviewed_on,
            "reviewed_at": reviewed_at,
            "review_id": self._latest_editorial_review_id(reference.url, lesson_path),
        }

    def _latest_editorial_review_id(self, url: str, lesson_path: str) -> int | None:
        with self._db_lock, self._connection() as connection:
            row = connection.execute(
                """SELECT review_id FROM trusted_source_editorial_reviews
                WHERE url = ? AND lesson_path = ? ORDER BY review_id DESC LIMIT 1""",
                (url, lesson_path),
            ).fetchone()
        return int(row["review_id"]) if row is not None else None

    def editorial_review_history(
        self,
        url: str,
        *,
        limit: int = 50,
        before_review_id: int | None = None,
    ) -> dict[str, object]:
        """Return a bounded page of local editorial review events for one approved URL."""
        canonical = self._canonical_url(url)
        references, _, _ = self._references()
        if not any(item.url == canonical for item in references):
            raise ValueError("Source is not in the approved inventory")

        if isinstance(limit, bool) or not 1 <= limit <= 100:
            raise ValueError("History page size is outside the supported range")
        with self._db_lock, self._connection() as connection:
            if before_review_id is None:
                rows = connection.execute(
                    """SELECT review_id, url, lesson_path, reviewed_digest, reviewed_on, reviewed_at
                    FROM trusted_source_editorial_reviews WHERE url = ?
                    ORDER BY review_id DESC LIMIT ?""",
                    (canonical, limit + 1),
                ).fetchall()
            else:
                rows = connection.execute(
                    """SELECT review_id, url, lesson_path, reviewed_digest, reviewed_on, reviewed_at
                    FROM trusted_source_editorial_reviews WHERE url = ? AND review_id < ?
                    ORDER BY review_id DESC LIMIT ?""",
                    (canonical, before_review_id, limit + 1),
                ).fetchall()

        has_more = len(rows) > limit
        page = rows[:limit]
        return {
            "status": "ok",
            "url": canonical,
            "reviews": [dict(row) for row in page],
            "has_more": has_more,
            "next_before_review_id": int(page[-1]["review_id"]) if has_more and page else None,
        }
