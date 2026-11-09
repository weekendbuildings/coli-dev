"""Tests for the assistant model router: fake providers only, no real calls.

Тесты маршрутизатора моделей ассистента: только поддельные провайдеры, без настоящих вызовов.
"""

from __future__ import annotations

import asyncio
import json
from pathlib import Path

import httpx
import pytest
from fastapi.testclient import TestClient

import assistant_router as ar
import orchestrator


def collect(agen):
    async def run():
        return [event async for event in agen]
    return asyncio.run(run())


class FakeProvider(ar.AssistantProvider):
    def __init__(self, id, *, chunks=(), fail=None, fail_after=0, tier=ar.TIER_FREE_CLOUD, configured=True,
                 model="m", needs_network=True):
        self.id = id
        self.label = id.title()
        self.chunks = list(chunks)
        self.fail = fail
        self.fail_after = fail_after
        self.tier = tier
        self._configured = configured
        self.model = model
        self.needs_network = needs_network
        self.calls = 0

    def configured(self):
        return self._configured

    async def stream(self, system, messages):
        self.calls += 1
        for index, chunk in enumerate(self.chunks):
            if self.fail and index == self.fail_after:
                raise self.fail
            yield chunk
        if self.fail and self.fail_after >= len(self.chunks):
            raise self.fail


MESSAGES = [{"role": "user", "content": "Что такое список?"}]


# ─── Router chain / цепочка ───────────────────────────────────────────────


def test_first_provider_answers_and_router_stops():
    first = FakeProvider("claude_cli", chunks=["Спи", "сок"], tier=ar.TIER_SUBSCRIPTION)
    second = FakeProvider("ollama_local", chunks=["x"], tier=ar.TIER_LOCAL)
    events = collect(ar.route_stream([first, second], "sys", MESSAGES))
    done = events[-1]
    assert done["type"] == "done" and done["provider"] == "claude_cli" and done["answer"] == "Список"
    assert [e["content"] for e in events if e["type"] == "token"] == ["Спи", "сок"]
    assert second.calls == 0


def test_rate_limit_moves_to_next_provider_and_says_why():
    limited = FakeProvider("openrouter", fail=ar.ProviderFailure("rate_limited"))
    local = FakeProvider("ollama_local", chunks=["ok"], tier=ar.TIER_LOCAL, model="qwen3.5:latest")
    events = collect(ar.route_stream([limited, local], "sys", MESSAGES))
    fallback = next(e for e in events if e["type"] == "fallback")
    assert fallback == {"type": "fallback", "provider": "openrouter", "label": "Openrouter", "reason": "rate_limited"}
    assert events[-1]["provider"] == "ollama_local" and events[-1]["model"] == "qwen3.5:latest"
    assert events[-1]["attempts"][0]["result"] == "rate_limited"


def test_no_network_skips_cloud_without_calling_it_and_local_answers():
    cloud = FakeProvider("claude_cli", chunks=["x"], tier=ar.TIER_SUBSCRIPTION)
    gemini = FakeProvider("gemini", chunks=["x"])
    local = FakeProvider("ollama_local", chunks=["локально"], tier=ar.TIER_LOCAL, needs_network=False)
    checks = []

    async def offline():
        checks.append(1)
        return False

    events = collect(ar.route_stream([cloud, gemini, local], "sys", MESSAGES, network_ok=offline))
    assert cloud.calls == 0 and gemini.calls == 0 and len(checks) == 1
    assert [e["reason"] for e in events if e["type"] == "fallback"] == ["offline", "offline"]
    assert events[-1]["provider"] == "ollama_local" and events[-1]["answer"] == "локально"


def test_connection_error_mid_stream_resets_partial_answer():
    broken = FakeProvider("groq", chunks=["полу", "ответ"], fail=httpx.ConnectError("down"), fail_after=1)
    local = FakeProvider("ollama_local", chunks=["целый ответ"], tier=ar.TIER_LOCAL)
    events = collect(ar.route_stream([broken, local], "sys", MESSAGES))
    kinds = [e["type"] for e in events]
    assert kinds.index("reset") < kinds.index("fallback")
    assert next(e for e in events if e["type"] == "fallback")["reason"] == "offline"
    assert events[-1]["answer"] == "целый ответ"


def test_paid_disabled_unconfigured_and_empty_providers_are_skipped():
    paid = FakeProvider("ollama_cloud", chunks=["$"], tier=ar.TIER_PAID)
    off = FakeProvider("gemini", chunks=["x"])
    no_key = FakeProvider("openrouter", chunks=["x"], configured=False)
    empty = FakeProvider("groq", chunks=["  "])
    events = collect(ar.route_stream([paid, off, no_key, empty], "sys", MESSAGES, disabled=["gemini"]))
    assert paid.calls == 0 and off.calls == 0 and no_key.calls == 0
    assert events[-1]["type"] == "error"
    assert [a["result"] for a in events[-1]["attempts"]] == ["paid_blocked", "disabled", "not_configured", "empty"]


def test_timeout_is_reported_as_timeout():
    slow = FakeProvider("claude_cli", fail=asyncio.TimeoutError())
    events = collect(ar.route_stream([slow], "sys", MESSAGES))
    assert events[-2]["reason"] == "timeout" and events[-1]["type"] == "error"


# ─── `claude -p` output samples / образцы вывода `claude -p` ──────────────

CLAUDE_OK = [
    {"type": "system", "subtype": "init", "model": "claude-sonnet-5-5", "apiKeySource": "none", "tools": []},
    {"type": "stream_event", "event": {"type": "message_start", "message": {"model": "claude-sonnet-5-5"}}},
    {"type": "stream_event", "event": {"type": "content_block_delta", "index": 0,
                                       "delta": {"type": "text_delta", "text": "Список — "}}},
    {"type": "stream_event", "event": {"type": "content_block_delta", "index": 0,
                                       "delta": {"type": "text_delta", "text": "это упорядоченная коллекция."}}},
    {"type": "assistant", "message": {"model": "claude-sonnet-5-5",
                                      "content": [{"type": "text", "text": "Список — это упорядоченная коллекция."}]}},
    {"type": "result", "subtype": "success", "is_error": False, "result": "Список — это упорядоченная коллекция."},
]


def parse_lines(lines):
    parser = ar.ClaudeStreamParser()
    out = []
    for line in lines:
        out.extend(parser.feed(json.dumps(line, ensure_ascii=False) if isinstance(line, dict) else line))
    return parser, out


def test_claude_stream_text_comes_once_from_partials():
    parser, out = parse_lines(CLAUDE_OK)
    text = "".join(item for item in out if isinstance(item, str))
    assert text == "Список — это упорядоченная коллекция."
    assert parser.model == "claude-sonnet-5-5" and parser.finished


def test_claude_without_partials_uses_assistant_or_result_text():
    _, out = parse_lines([CLAUDE_OK[0], CLAUDE_OK[4], CLAUDE_OK[5]])
    assert [x for x in out if isinstance(x, str)] == ["Список — это упорядоченная коллекция."]
    _, out = parse_lines([CLAUDE_OK[0], CLAUDE_OK[5]])
    assert [x for x in out if isinstance(x, str)] == ["Список — это упорядоченная коллекция."]


def test_claude_api_key_source_is_refused_as_paid():
    with pytest.raises(ar.ProviderFailure) as error:
        parse_lines([{"type": "system", "subtype": "init", "model": "x", "apiKeySource": "ANTHROPIC_API_KEY"}])
    assert error.value.kind == "paid_blocked"


@pytest.mark.parametrize("result,kind", [
    ("Claude AI usage limit reached|1762621200", "rate_limited"),
    ("You've hit your limit · resets 3pm (Asia/Tashkent)", "rate_limited"),
    ("Not logged in · Please run /login", "not_signed_in"),
    ("Invalid API key · Please run /login", "not_signed_in"),
    ("API Error: Unable to connect to API (ENOTFOUND)", "offline"),
    ("Credit balance is too low", "paid_blocked"),
    ("Something odd", "failed"),
])
def test_claude_error_results_are_classified(result, kind):
    with pytest.raises(ar.ProviderFailure) as error:
        parse_lines([{"type": "result", "subtype": "success", "is_error": True, "result": result}])
    assert error.value.kind == kind


def test_claude_not_signed_in_notice_is_not_shown_as_an_answer():
    # Real `claude -p` output on this Mac before `claude auth login` (2026-11-08).
    # Настоящий вывод `claude -p` на этом Mac до `claude auth login`.
    lines = [
        {"type": "system", "subtype": "init", "model": "claude-sonnet-5-5", "apiKeySource": "none"},
        {"type": "system", "subtype": "status"},
        {"type": "assistant", "message": {"model": "<synthetic>", "role": "assistant",
                                          "content": [{"type": "text", "text": "Not logged in · Please run /login"}]}},
    ]
    _, out = parse_lines(lines)
    assert [x for x in out if isinstance(x, str)] == []
    with pytest.raises(ar.ProviderFailure) as error:
        parse_lines(lines + [{"type": "result", "subtype": "success", "is_error": True,
                              "result": "Not logged in · Please run /login", "total_cost_usd": 0}])
    assert error.value.kind == "not_signed_in"


def test_claude_rejected_rate_limit_event_and_garbage_lines():
    _, out = parse_lines(["not json", "", "[1,2]"])
    assert out == []
    with pytest.raises(ar.ProviderFailure) as error:
        parse_lines([{"type": "rate_limit_event", "rate_limit_info": {"status": "rejected"}}])
    assert error.value.kind == "rate_limited"


def test_claude_environment_drops_api_key_and_bare_mode():
    env = ar.claude_environment({"HOME": "/Users/x", "PATH": "/usr/bin", "ANTHROPIC_API_KEY": "secret",
                                 "ANTHROPIC_BASE_URL": "http://x", "CLAUDE_CODE_SIMPLE": "1", "CLAUDECODE": "1",
                                 "LANG": "ru_RU.UTF-8"})
    assert not any(key.startswith("ANTHROPIC_") for key in env)
    assert "CLAUDE_CODE_SIMPLE" not in env and "CLAUDECODE" not in env
    assert env["LANG"] == "ru_RU.UTF-8" and "/Users/x/.local/bin" in env["PATH"].split(":")


def test_claude_transcript_keeps_follow_up_context():
    text = ar.claude_transcript([
        {"role": "user", "content": "Что такое список?"},
        {"role": "assistant", "content": "Коллекция."},
        {"role": "user", "content": "А кортеж?"},
    ])
    assert "Ученик: Что такое список?" in text and "Наставник: Коллекция." in text
    assert text.endswith("А кортеж?")


class FakeStream:
    def __init__(self, lines, delay=0.0):
        self.lines = [(json.dumps(x, ensure_ascii=False) + "\n").encode() for x in lines]
        self.delay = delay

    async def readline(self):
        if self.delay:
            await asyncio.sleep(self.delay)
        return self.lines.pop(0) if self.lines else b""

    async def read(self, n=-1):
        return b""


class FakeStdin:
    def __init__(self):
        self.data = b""

    def write(self, data):
        self.data += data

    async def drain(self):
        pass

    def close(self):
        pass


class FakeProcess:
    def __init__(self, lines, delay=0.0):
        self.stdin = FakeStdin()
        self.stdout = FakeStream(lines, delay)
        self.stderr = FakeStream([])
        self.returncode = None
        self.killed = False

    def kill(self):
        self.killed = True
        self.returncode = -9

    async def wait(self):
        if self.returncode is None:
            self.returncode = 0
        return self.returncode


def test_claude_provider_runs_cli_with_subscription_safe_flags(tmp_path):
    seen = {}
    process = FakeProcess(CLAUDE_OK)

    async def spawn(command, env, cwd):
        seen.update(command=command, env=env, cwd=cwd)
        return process

    provider = ar.ClaudeCLIProvider(binary="/fake/claude", spawn=spawn, workdir=tmp_path)
    events = collect(ar.route_stream([provider], "Ты наставник", MESSAGES))
    assert events[-1]["type"] == "done" and events[-1]["model"] == "claude-sonnet-5-5"
    command = seen["command"]
    assert command[:2] == ["/fake/claude", "-p"] and "stream-json" in command
    assert command[command.index("--tools") + 1] == "" and "--no-session-persistence" in command
    assert command[command.index("--model") + 1] == "sonnet"
    assert process.stdin.data.decode() == "Что такое список?"
    assert seen["cwd"] == str(tmp_path) and "ANTHROPIC_API_KEY" not in seen["env"]


def test_claude_provider_silence_times_out_and_kills_process(tmp_path):
    process = FakeProcess(CLAUDE_OK, delay=1.0)

    async def spawn(command, env, cwd):
        return process

    provider = ar.ClaudeCLIProvider(binary="/fake/claude", spawn=spawn, workdir=tmp_path, first_output_timeout=0.05)
    events = collect(ar.route_stream([provider], "s", MESSAGES))
    assert events[-2]["reason"] == "timeout" and process.killed


def test_claude_without_sign_in_is_skipped_at_once_without_spawning(tmp_path):
    spawned = []

    async def spawn(command, env, cwd):
        spawned.append(command)
        raise AssertionError("claude -p must not start without a sign-in")

    async def not_signed_in():
        return "not_signed_in"

    provider = ar.ClaudeCLIProvider(binary="/fake/claude", spawn=spawn, workdir=tmp_path, signin_check=not_signed_in)
    events = collect(ar.route_stream([provider], "s", MESSAGES))
    assert [e["reason"] for e in events if e["type"] == "fallback"] == ["not_signed_in"] and spawned == []


def test_claude_sign_in_state_is_cached_per_binary(tmp_path, monkeypatch):
    calls = []

    async def status(self):
        calls.append(1)
        return {"configured": True, "reachable": False, "detail": "not_signed_in"}

    monkeypatch.setattr(ar.ClaudeCLIProvider, "status", status)
    monkeypatch.setattr(ar, "_claude_signin_cache", {})
    provider = ar.ClaudeCLIProvider(binary="/fake/claude-cache", workdir=tmp_path)

    async def twice():
        return [await provider.signin_state("/fake/claude-cache"), await provider.signin_state("/fake/claude-cache")]

    assert asyncio.run(twice()) == ["not_signed_in", "not_signed_in"] and len(calls) == 1


def test_claude_missing_binary_is_not_configured():
    provider = ar.ClaudeCLIProvider(binary=None)
    assert not provider.configured()
    assert collect(ar.route_stream([provider], "s", MESSAGES))[-1]["attempts"][0]["result"] == "not_configured"


# ─── HTTP providers with mock transport / HTTP-провайдеры с поддельным транспортом ─


def sse(*payloads):
    return "".join(f"data: {p}\n\n" for p in payloads).encode()


def test_openrouter_streams_free_model_and_reports_actual_model():
    def handler(request):
        body = json.loads(request.content)
        assert body["model"] == "openrouter/free" and body["messages"][0]["role"] == "system"
        return httpx.Response(200, content=sse(
            json.dumps({"model": "google/gemma-4-31b-it:free", "choices": [{"delta": {"content": "При"}}]}),
            json.dumps({"model": "google/gemma-4-31b-it:free", "choices": [{"delta": {"content": "вет"}}]}),
            "[DONE]",
        ))

    provider = ar.OpenAICompatibleFreeProvider(
        id="openrouter", label="OpenRouter", base_url="https://openrouter.test/api/v1", status_path="/key",
        key=lambda: "k", model="openrouter/free", free_model_check=ar.is_free_openrouter_model,
        transport=httpx.MockTransport(handler))
    done = collect(ar.route_stream([provider], "s", MESSAGES))[-1]
    assert done["answer"] == "Привет" and done["model"] == "google/gemma-4-31b-it:free"


def test_openrouter_429_and_paid_model_fall_back():
    provider = ar.OpenAICompatibleFreeProvider(
        id="openrouter", label="OpenRouter", base_url="https://openrouter.test/api/v1", status_path="/key",
        key=lambda: "k", model="openrouter/free", transport=httpx.MockTransport(lambda r: httpx.Response(429)))
    paid = ar.OpenAICompatibleFreeProvider(
        id="openrouter", label="OpenRouter", base_url="https://openrouter.test/api/v1", status_path="/key",
        key=lambda: "k", model="anthropic/claude-opus", free_model_check=ar.is_free_openrouter_model,
        transport=httpx.MockTransport(lambda r: pytest.fail("paid model must not be called")))
    events = collect(ar.route_stream([provider, paid], "s", MESSAGES))
    assert [e["reason"] for e in events if e["type"] == "fallback"] == ["rate_limited", "paid_blocked"]


def test_openrouter_status_reports_remaining_free_requests_without_key_value():
    def handler(request):
        assert request.url.path.endswith("/key")
        return httpx.Response(200, json={"data": {"free_model_daily_requests": {"used": 3, "limit": 50, "remaining": 47}}})

    provider = ar.OpenAICompatibleFreeProvider(
        id="openrouter", label="OpenRouter", base_url="https://openrouter.test/api/v1", status_path="/key",
        key=lambda: "secret-value", model="openrouter/free", transport=httpx.MockTransport(handler))
    status = asyncio.run(provider.status())
    assert status == {"configured": True, "reachable": True, "detail": "ok", "remaining_today": 47}
    assert "secret-value" not in json.dumps(status)


def test_gemini_streams_text_and_skips_thoughts():
    def handler(request):
        assert request.headers["x-goog-api-key"] == "g" and "alt=sse" in str(request.url)
        body = json.loads(request.content)
        assert body["contents"][-1]["role"] == "user"
        return httpx.Response(200, content=sse(
            json.dumps({"modelVersion": "gemini-3-flash-preview", "candidates": [
                {"content": {"parts": [{"text": "думаю", "thought": True}, {"text": "Ответ"}]}}]}),
        ))

    provider = ar.GeminiProvider(key=lambda: "g", model="gemini-3-flash-preview",
                                 transport=httpx.MockTransport(handler))
    done = collect(ar.route_stream([provider], "s", MESSAGES))[-1]
    assert done["answer"] == "Ответ" and done["model"] == "gemini-3-flash-preview"


def test_local_ollama_picks_first_installed_model_and_streams():
    def handler(request):
        if request.url.path == "/api/tags":
            return httpx.Response(200, json={"models": [{"name": "qwen2.5-coder:7b"}]})
        body = json.loads(request.content)
        assert body["model"] == "qwen2.5-coder:7b" and body["think"] is False
        lines = [{"message": {"content": "Лок"}}, {"message": {"content": "ально"}, "done": True}]
        return httpx.Response(200, content="\n".join(json.dumps(x, ensure_ascii=False) for x in lines).encode())

    provider = ar.OllamaProvider(id="ollama_local", label="Ollama", base_url="http://127.0.0.1:11434",
                                 models=["qwen3.5", "qwen2.5-coder:7b"], transport=httpx.MockTransport(handler))
    done = collect(ar.route_stream([provider], "s", MESSAGES))[-1]
    assert done["answer"] == "Локально" and done["model"] == "qwen2.5-coder:7b"


def test_ollama_must_be_loopback():
    provider = ar.OllamaProvider(id="ollama_local", label="Ollama", base_url="http://example.com:11434",
                                 models=["qwen3.5"])
    assert not provider.configured()


# ─── Prompts and settings / подсказки и настройки ─────────────────────────


def test_system_prompt_has_lesson_context_and_skillbox_asks_what_is_outdated():
    lesson = ar.build_system_prompt({"kind": "lesson", "title": "Списки", "subject": "Python",
                                     "goal": "Понять списки", "position": "Шаг 3 из 26"}, "ru")
    assert "Тема: Списки" in lesson and "Где ученик сейчас: Шаг 3 из 26" in lesson and "2026" not in lesson
    skillbox = ar.build_system_prompt({"kind": "skillbox", "title": "Декораторы", "course": "Python Advanced",
                                       "track": "Инженерная"}, "ru")
    assert "Skillbox «Python Advanced»" in skillbox and "устареть к 2026 году" in skillbox
    english = ar.build_system_prompt({"kind": "skillbox", "title": "Decorators"}, "en")
    assert "out of date by 2026" in english


def test_messages_keep_recent_history_and_attach_code():
    history = [{"role": "assistant", "content": "orphan"}] + [
        {"role": "user" if i % 2 == 0 else "assistant", "content": f"t{i}"} for i in range(30)
    ]
    messages = ar.build_messages(history, "Проверь мой код", "print(1)\n", "ru")
    assert messages[0]["role"] == "user" and len(messages) <= 13
    assert messages[-1]["content"].endswith("Мой код:\n```python\nprint(1)\n```")


def test_settings_store_normalizes_order(tmp_path):
    store = ar.AssistantSettingsStore(tmp_path / "assistant-models.json")
    assert store.get().order == list(ar.DEFAULT_ORDER)
    saved = store.save(["ollama_local", "bogus", "ollama_local", "claude_cli"], ["gemini", "bogus"])
    assert saved.order[:2] == ["ollama_local", "claude_cli"] and set(saved.order) == set(ar.DEFAULT_ORDER)
    assert store.get().disabled == ["gemini"]
    (tmp_path / "assistant-models.json").write_text("{broken")
    assert store.get().order == list(ar.DEFAULT_ORDER)


# ─── Endpoints / конечные точки ───────────────────────────────────────────


@pytest.fixture()
def api(tmp_path, monkeypatch):
    fakes = {
        "claude_cli": FakeProvider("claude_cli", fail=ar.ProviderFailure("not_signed_in"), tier=ar.TIER_SUBSCRIPTION),
        "ollama_local": FakeProvider("ollama_local", chunks=["Ответ ", "локальной модели"], tier=ar.TIER_LOCAL,
                                     model="qwen3.5:latest", needs_network=False),
        "ollama_cloud": FakeProvider("ollama_cloud", chunks=["$"], tier=ar.TIER_PAID),
    }
    monkeypatch.setattr(orchestrator, "assistant_settings", ar.AssistantSettingsStore(tmp_path / "a.json"))
    monkeypatch.setattr(orchestrator, "_assistant_provider_factory", lambda language="ru": fakes)

    async def online():
        return True

    monkeypatch.setattr(orchestrator, "_assistant_network_ok", online)
    return TestClient(orchestrator.app, client=("127.0.0.1", 50000)), fakes


def stream_events(response):
    return [json.loads(line[5:]) for line in response.text.splitlines() if line.startswith("data:")]


def test_ask_endpoint_streams_fallback_and_who_answered(api):
    client, fakes = api
    response = client.post("/assistant/ask/stream", json={
        "language": "ru",
        "context": {"kind": "lesson", "title": "Списки", "subject": "Python", "goal": "Понять списки"},
        "question": "Объясни",
        "code": "x = [1, 2]",
        "history": [{"role": "user", "content": "Привет"}, {"role": "assistant", "content": "Здравствуй"}],
    })
    assert response.status_code == 200 and response.headers["content-type"].startswith("text/event-stream")
    events = stream_events(response)
    assert events[1] == {"type": "fallback", "provider": "claude_cli", "label": "Claude_Cli", "reason": "not_signed_in"}
    assert events[-1]["type"] == "done" and events[-1]["provider"] == "ollama_local"
    assert events[-1]["answer"] == "Ответ локальной модели" and fakes["ollama_cloud"].calls == 0


def test_ask_endpoint_explains_when_nobody_answers(api):
    client, fakes = api
    fakes["ollama_local"].fail = ar.ProviderFailure("failed")
    events = stream_events(client.post("/assistant/ask/stream", json={
        "language": "en", "context": {"title": "Lists"}, "question": "Explain"}))
    assert events[-1]["type"] == "error" and "claude auth login" in events[-1]["error"]


def test_ask_endpoint_rejects_remote_clients(api):
    _, _ = api
    remote = TestClient(orchestrator.app, client=("203.0.113.9", 50000))
    response = remote.post("/assistant/ask/stream", json={"context": {"title": "x"}, "question": "y"})
    assert response.status_code == 403


def test_settings_endpoint_saves_order_and_hides_keys(api):
    client, _ = api
    saved = client.put("/settings/assistant-models", json={"order": ["ollama_local", "claude_cli"],
                                                           "disabled": ["claude_cli"]}).json()
    assert saved["order"][:2] == ["ollama_local", "claude_cli"] and saved["disabled"] == ["claude_cli"]
    rows = {row["id"]: row for row in saved["providers"]}
    assert rows["claude_cli"]["enabled"] is False and rows["ollama_cloud"]["enabled"] is False
    assert rows["ollama_cloud"]["tier"] == "paid"
    checked = client.get("/settings/assistant-models", params={"check": "true"}).json()
    assert {row["id"]: row["detail"] for row in checked["providers"]}["ollama_cloud"] == "paid_blocked"
    assert all("key" not in name or name == "key_provider" for row in checked["providers"] for name in row)


def test_real_provider_list_has_no_paid_route_enabled_and_free_openrouter_model():
    providers = orchestrator._assistant_providers("ru")
    assert list(providers) == list(ar.DEFAULT_ORDER)
    assert providers["ollama_cloud"].tier == ar.TIER_PAID
    assert ar.is_free_openrouter_model(providers["openrouter"].model)
    assert providers["claude_cli"].model == "sonnet"
    assert "groq" in orchestrator.PROVIDER_ENV_NAMES


# ─── OmniRoute and Kimi / OmniRoute и Kimi ──────────────────────────────────

def test_local_gateway_needs_no_key_and_only_loopback_is_local():
    assert ar.is_loopback_url("http://127.0.0.1:20128/v1") and ar.is_loopback_url("http://localhost:20128/v1")
    assert not ar.is_loopback_url("https://api.openai.com/v1") and not ar.is_loopback_url("not a url")
    gateway = ar.OpenAICompatibleFreeProvider(id="omniroute", label="OmniRoute", base_url="http://127.0.0.1:20128/v1",
                                              status_path="/models", key=lambda: "", model="auto",
                                              tier=ar.TIER_LOCAL, needs_network=False, key_required=False)
    assert gateway.configured() and "Authorization" not in gateway._headers()
    assert not ar.OpenAICompatibleFreeProvider(id="omniroute", label="OmniRoute", base_url="http://127.0.0.1:20128/v1",
                                               status_path="/models", key=lambda: "", model="", key_required=False).configured()
    keyed = ar.OpenAICompatibleFreeProvider(id="groq", label="Groq", base_url="https://x/v1", status_path="/models",
                                            key=lambda: "", model="m")
    assert not keyed.configured()


def test_assistant_providers_list_omniroute_local_and_kimi_paid(monkeypatch):
    import orchestrator
    monkeypatch.setattr(orchestrator.openai_compatible_settings, "get", lambda: {"base_url": "", "model": "auto"})
    providers = orchestrator._assistant_providers()
    assert list(ar.DEFAULT_ORDER) == ["claude_cli", "gemini", "groq", "openrouter", "omniroute", "ollama_local", "kimi", "ollama_cloud"]
    assert set(providers) == set(ar.DEFAULT_ORDER)
    assert providers["omniroute"].tier == ar.TIER_LOCAL and providers["omniroute"].needs_network is False
    assert providers["omniroute"].base_url == "http://127.0.0.1:20128/v1"
    assert providers["kimi"].tier == ar.TIER_PAID
    monkeypatch.setattr(orchestrator.openai_compatible_settings, "get",
                        lambda: {"base_url": "https://api.example.com/v1", "model": "gpt"})
    assert orchestrator._assistant_providers()["omniroute"].tier == ar.TIER_PAID, "a remote gateway may be paid"


def test_kimi_is_never_called():
    kimi = FakeProvider("kimi", chunks=["¥"], tier=ar.TIER_PAID)
    local = FakeProvider("ollama_local", chunks=["ok"])
    events = collect(ar.route_stream([kimi, local], "sys", MESSAGES))
    assert kimi.calls == 0 and events[-1]["provider"] == "ollama_local"
    assert {"provider": "kimi", "model": kimi.model, "result": "paid_blocked"} in events[-1]["attempts"]


# ─── Smart fallback / умный откат ───────────────────────────────────────────

def test_rate_limited_provider_rests_and_is_skipped_at_once():
    now = [1000.0]
    cooldowns = ar.ProviderCooldowns(clock=lambda: now[0])
    limited = FakeProvider("gemini", fail=ar.ProviderFailure("rate_limited"))
    groq = FakeProvider("groq", chunks=["ответ"])
    first = collect(ar.route_stream([limited, groq], "sys", MESSAGES, cooldowns=cooldowns))
    assert first[-1]["provider"] == "groq" and limited.calls == 1
    second = collect(ar.route_stream([limited, groq], "sys", MESSAGES, cooldowns=cooldowns))
    assert limited.calls == 1, "a rate-limited provider is not asked again for 10 min"
    assert {"provider": "gemini", "model": "m", "result": "cooling_down"} in second[-1]["attempts"]
    now[0] += 601
    limited.fail = None
    limited.chunks = ["снова"]
    third = collect(ar.route_stream([limited, groq], "sys", MESSAGES, cooldowns=cooldowns))
    assert third[-1]["provider"] == "gemini" and not cooldowns.active("gemini")


def test_lost_network_sends_the_rest_of_the_route_to_the_local_model_without_new_checks():
    checks = []

    async def probe():
        checks.append(1)
        return True

    network = ar.CachedReachability(probe)
    dropped = FakeProvider("gemini", fail=ar.ProviderFailure("offline"))
    cloud = FakeProvider("groq", chunks=["облако"])
    local = FakeProvider("ollama_local", chunks=["локально"], needs_network=False)
    events = collect(ar.route_stream([dropped, cloud, local], "sys", MESSAGES, network_ok=network))
    assert events[-1]["provider"] == "ollama_local" and cloud.calls == 0
    assert len(checks) == 1, "the network check ran once and was then marked offline"
    assert asyncio.run(network()) is False and len(checks) == 1, "offline is remembered for a few seconds"


def test_network_check_is_remembered_and_expires():
    now = [0.0]
    answers = [True, False]

    async def probe():
        return answers.pop(0)

    network = ar.CachedReachability(probe, online_ttl=30, offline_ttl=5, clock=lambda: now[0])
    assert asyncio.run(network()) is True
    now[0] = 29
    assert asyncio.run(network()) is True and answers == [False]
    now[0] = 31
    assert asyncio.run(network()) is False


def test_code_model_only_for_the_learners_code():
    assert ar.has_code("Почему падает?\n```python\nprint(1/0)\n```")
    assert not ar.has_code("Чем список отличается от кортежа в Python?")
    augmented = 'JSON [{"excerpt": "import sys; print(sys.argv)"}]\n\nСообщение ученика:\nЧем список отличается от кортежа?'
    assert not ar.has_code(augmented), "code in RAG excerpts must not switch to the coder model"
