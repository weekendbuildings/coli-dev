"""Free fresh lookup for the workshop: the Wikimedia REST API (no key), Russian first, then English.

Only https sources with the page's last-edit date; any error simply means no web source.
Бесплатная свежая справка: REST API Википедии без ключа, сначала русская, потом английская; только https-источники
с датой последней правки; любая ошибка просто значит «нет веб-источника».
"""
from __future__ import annotations

from datetime import datetime, timezone
from urllib.parse import quote

import httpx

USER_AGENT = "CreatorsPath/0.1 (educational macOS app; https://github.com/weekendbuildings/coli-dev)"
EXCERPT = 900


async def wikipedia_sources(query: str, languages: tuple[str, ...] = ("ru", "en"), limit: int = 2,
                            transport: httpx.AsyncBaseTransport | None = None, timeout: float = 4.0) -> list[dict[str, str]]:
    query = " ".join(query.split())[:200]
    if not query:
        return []
    found: list[dict[str, str]] = []
    retrieved = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    async with httpx.AsyncClient(transport=transport, timeout=timeout, headers={"User-Agent": USER_AGENT}) as client:
        for language in languages:
            try:
                search = await client.get(f"https://{language}.wikipedia.org/w/rest.php/v1/search/page",
                                          params={"q": query, "limit": limit})
                pages = search.json().get("pages", []) if search.status_code == 200 else []
            except (httpx.HTTPError, ValueError):
                continue
            for page in pages[:limit]:
                key = page.get("key")
                if not isinstance(key, str) or not key:
                    continue
                try:
                    summary = await client.get(f"https://{language}.wikipedia.org/api/rest_v1/page/summary/{quote(key, safe='')}")
                    data = summary.json() if summary.status_code == 200 else {}
                except (httpx.HTTPError, ValueError):
                    continue
                url = ((data.get("content_urls") or {}).get("desktop") or {}).get("page", "")
                extract = str(data.get("extract") or "").strip()
                if not url.startswith("https://") or not extract:
                    continue
                found.append({
                    "source_type": "wikipedia",
                    "title": str(data.get("title") or key)[:200],
                    "location": url,
                    "page_updated_at": str(data.get("timestamp") or ""),
                    "retrieved_at": retrieved,
                    "license": "CC BY-SA 4.0",
                    "attribution": f"Wikipedia ({language})",
                    "excerpt": extract[:EXCERPT],
                })
            if found:
                break
    return found[:limit]
