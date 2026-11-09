"""«Память» in RAG, the free Wikipedia lookup and Gemini grounding sources. / Память в RAG, Википедия и поиск Gemini."""
import asyncio
import json
import os
import time

import httpx

import assistant_router as ar
from vault_index import VaultIndex, safe_vault
from web_lookup import wikipedia_sources


def test_vault_search_cites_title_and_date_and_rereads_only_changed_files(tmp_path):
    (tmp_path / ".obsidian").mkdir()
    (tmp_path / ".obsidian" / "hidden.md").write_text("градиент секрет", encoding="utf-8")
    note = tmp_path / "ML" / "Градиент.md"
    note.parent.mkdir()
    note.write_text("---\ntags: [ml]\n---\nГрадиент показывает направление роста функции. См. [[Производная|производную]].", encoding="utf-8")
    (tmp_path / "Другое.md").write_text("Про кошек.", encoding="utf-8")
    index = VaultIndex()
    found = index.search("Что такое градиент?", tmp_path)
    assert len(found) == 1 and found[0]["title"] == "Градиент" and found[0]["source_type"] == "vault"
    assert found[0]["path"] == os.path.join("ML", "Градиент.md") and found[0]["modified_at"].endswith("Z")
    assert "tags" not in found[0]["excerpt"] and "производную" in found[0]["excerpt"]
    cached = index._notes[str(note)]
    index.search("градиент", tmp_path)
    assert index._notes[str(note)] is cached, "unchanged files are not re-read"
    time.sleep(0.01)
    note.write_text("Градиент теперь новый.", encoding="utf-8")
    os.utime(note, (time.time() + 5, time.time() + 5))
    assert "новый" in index.search("градиент", tmp_path)[0]["excerpt"]


def test_vault_must_be_inside_home(tmp_path):
    assert safe_vault(str(tmp_path), home=tmp_path) == tmp_path.resolve()
    assert safe_vault("/etc", home=tmp_path) is None and safe_vault(None) is None
    assert safe_vault(str(tmp_path / "missing"), home=tmp_path) is None


def test_wikipedia_lookup_returns_dated_https_sources_and_falls_back_to_english():
    def handler(request: httpx.Request) -> httpx.Response:
        host, path = request.url.host, request.url.path
        assert request.headers["User-Agent"].startswith("CreatorsPath/")
        if host == "ru.wikipedia.org" and path.endswith("/search/page"):
            return httpx.Response(200, json={"pages": []})
        if host == "en.wikipedia.org" and path.endswith("/search/page"):
            return httpx.Response(200, json={"pages": [{"key": "Gradient_descent"}]})
        if host == "en.wikipedia.org" and "/page/summary/" in path:
            return httpx.Response(200, json={"title": "Gradient descent", "extract": "An optimization method.",
                                             "timestamp": "2026-11-01T10:00:00Z",
                                             "content_urls": {"desktop": {"page": "https://en.wikipedia.org/wiki/Gradient_descent"}}})
        return httpx.Response(404)

    found = asyncio.run(wikipedia_sources("градиентный спуск", transport=httpx.MockTransport(handler)))
    assert found and found[0]["location"] == "https://en.wikipedia.org/wiki/Gradient_descent"
    assert found[0]["page_updated_at"] == "2026-11-01T10:00:00Z" and found[0]["source_type"] == "wikipedia"


def test_wikipedia_lookup_failure_means_no_sources():
    def broken(request):
        raise httpx.ConnectError("offline")

    assert asyncio.run(wikipedia_sources("что угодно", transport=httpx.MockTransport(broken))) == []


def test_gemini_grounding_adds_dated_google_sources():
    seen = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen["body"] = json.loads(request.content)
        event = {"candidates": [{"content": {"parts": [{"text": "Ответ."}]},
                                 "groundingMetadata": {"groundingChunks": [{"web": {"uri": "https://example.org/a", "title": "A"}},
                                                                            {"web": {"uri": "http://plain.org", "title": "B"}}]}}]}
        return httpx.Response(200, text="data: " + json.dumps(event) + "\n\n", headers={"content-type": "text/event-stream"})

    gemini = ar.GeminiProvider(key=lambda: "k", model="m", transport=httpx.MockTransport(handler))
    gemini.grounding = True
    events = []

    async def run():
        async for event in ar.route_stream([gemini], "sys", [{"role": "user", "content": "q"}]):
            events.append(event)

    asyncio.run(run())
    assert seen["body"]["tools"] == [{"google_search": {}}]
    added = next(e for e in events if e["type"] == "sources")
    assert added["append"] is True and added["sources"] == [
        {"id": "G1", "title": "A", "kind": "google", "url": "https://example.org/a", "date": added["sources"][0]["date"]}]
    assert events[-1]["type"] == "done" and events[-1]["answer"] == "Ответ."
