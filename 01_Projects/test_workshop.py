"""Tests of the Creator's workshop: progress in the prompt, chat endpoint and the model council.

Тесты Мастерской Творца: прогресс в подсказке, конечная точка чата и совет моделей.
"""

from __future__ import annotations

import asyncio

import pytest
from fastapi.testclient import TestClient

import assistant_router as ar
import orchestrator
import workshop as ws
from test_assistant_router import FakeProvider, collect, stream_events


class RecordingProvider(FakeProvider):
    """Remembers the system prompt and messages it got. Запоминает подсказку и сообщения."""

    def __init__(self, *args, delay=0.0, **kwargs):
        super().__init__(*args, **kwargs)
        self.delay = delay
        self.systems: list[str] = []
        self.messages: list[list[dict]] = []

    async def stream(self, system, messages):
        self.systems.append(system)
        self.messages.append(messages)
        if self.delay:
            await asyncio.sleep(self.delay)
        async for chunk in super().stream(system, messages):
            yield chunk


PROGRESS = {
    "records": [
        {"lesson_id": "ai-path/python-lists", "completed": True, "updated_at": "2026-11-07T10:00:00Z", "last_quality": 5},
        {"lesson_id": "ai-path/numpy-arrays", "completed": True, "updated_at": "2026-11-08T09:00:00Z", "last_quality": 2},
        {"lesson_id": "ai-path/gradients", "completed": False, "updated_at": "2026-11-06T09:00:00Z"},
    ],
    "due_count": 2,
}


# ─── Progress and prompt / прогресс и подсказка ───────────────────────────


def test_progress_summary_counts_completed_due_recent_and_weak():
    text = ws.summarize_progress(PROGRESS, "ru")
    assert "Пройдено уроков: 2." in text and "Повторений на сегодня: 2." in text
    # Most recent first. Сначала последний пройденный.
    assert "Последние пройденные: ai-path/numpy-arrays, ai-path/python-lists." in text
    assert "оценка ниже 3): ai-path/numpy-arrays." in text
    assert ws.summarize_progress(None) == "" and ws.summarize_progress({"records": "bad"}, "en").startswith("Lessons completed: 0.")


def test_next_step_and_system_prompt_carry_path_mentor_rule_and_action_protocol():
    step = ws.describe_next_step({"lesson": "Градиент", "module": "2 · Математика", "step": "3",
                                  "why": "Без градиента нет обучения", "finished": 4, "total": 30}, "ru")
    assert step.splitlines() == ["Следующий шаг: «Градиент».", "Модуль: 2 · Математика, шаг 3.",
                                 "Зачем: Без градиента нет обучения", "Путь пройден: 4 из 30 уроков."]
    assert ws.describe_next_step({}, "en") == "All written lessons of the path are done."
    prompt = ws.build_workshop_system_prompt("Пройдено уроков: 2.", step, "ru", labs=["autograd", "bpe"])
    assert "Jarvis" in prompt and "наставник, а не исполнитель" in prompt
    assert "```action" in prompt and '"tool": "shell"' in prompt and "только после его подтверждения" in prompt
    assert "Задания для run_check: autograd, bpe." in prompt
    assert "Следующий шаг: «Градиент»." in prompt and "Пройдено уроков: 2." in prompt
    english = ws.build_workshop_system_prompt("", "", "en")
    assert "mentor, not a doer" in english and "Progress is unavailable." in english


def test_workshop_messages_keep_last_turns_and_mark_voice_questions():
    history = [{"role": "assistant", "content": "лишнее"}] + [
        {"role": "user" if index % 2 == 0 else "assistant", "content": f"r{index}"} for index in range(40)
    ]
    messages = ws.build_workshop_messages(history, "Как дела?", voice=True, language="ru", max_turns=4)
    assert messages[0]["role"] == "user" and len(messages) == 5
    assert messages[-1]["content"].startswith("Как дела?") and "голосом" in messages[-1]["content"]
    assert "voice" not in ws.build_workshop_messages([], "Hi", language="en")[-1]["content"]


# ─── Council / совет ──────────────────────────────────────────────────────


def test_council_takes_free_configured_switched_on_members_and_skips_network_offline():
    providers = [
        FakeProvider("claude_cli", tier=ar.TIER_SUBSCRIPTION),
        FakeProvider("ollama_cloud", tier=ar.TIER_PAID),
        FakeProvider("openrouter", configured=False),
        FakeProvider("gemini"),
        FakeProvider("groq"),
        FakeProvider("ollama_local", tier=ar.TIER_LOCAL, needs_network=False),
    ]

    async def online():
        return True

    async def offline():
        return False

    chosen, skipped = asyncio.run(ws.choose_council(providers, disabled=["gemini"], network_ok=online, limit=3))
    assert [provider.id for provider in chosen] == ["claude_cli", "groq", "ollama_local"]
    assert {"provider": "ollama_cloud", "reason": "paid_blocked"} in skipped
    assert {"provider": "openrouter", "reason": "not_configured"} in skipped
    chosen, _ = asyncio.run(ws.choose_council(providers, network_ok=offline, limit=3))
    assert [provider.id for provider in chosen] == ["ollama_local"]


def test_council_runs_members_in_parallel_and_summarizes_with_agreement_prompt():
    slow_a = RecordingProvider("claude_cli", chunks=["Список ", "изменяемый"], delay=0.3)
    slow_b = RecordingProvider("ollama_local", chunks=["Кортеж неизменяемый"], delay=0.3, needs_network=False)
    broken = RecordingProvider("groq", fail=ar.ProviderFailure("rate_limited"))
    judge = RecordingProvider("judge", chunks=["**Итог**: оба правы"])

    async def run():
        loop = asyncio.get_running_loop()
        started = loop.time()
        events = [event async for event in ws.council_stream([slow_a, slow_b, broken], [judge], "SYS",
                                                             "Список или кортеж?", language="ru")]
        return events, loop.time() - started

    events, elapsed = asyncio.run(run())
    # Two 0.3 s members finish together, not one after another. Участники идут параллельно.
    assert elapsed < 0.55
    assert events[0]["type"] == "members" and [m["provider"] for m in events[0]["members"]] == ["claude_cli", "ollama_local", "groq"]
    failed = [event for event in events if event["type"] == "member_failed"]
    assert failed == [{"type": "member_failed", "provider": "groq", "label": "Groq", "reason": "rate_limited"}]
    done = {event["provider"]: event["answer"] for event in events if event["type"] == "member_done"}
    assert done == {"claude_cli": "Список изменяемый", "ollama_local": "Кортеж неизменяемый"}
    summary = [event for event in events if event.get("phase") == "summary"]
    assert summary[-1]["type"] == "done" and summary[-1]["answer"] == "**Итог**: оба правы"
    prompt = judge.messages[0][0]["content"]
    assert "Где согласны" in prompt and "Где спорят" in prompt
    assert "### Claude_Cli\nСписок изменяемый" in prompt and "Кортеж неизменяемый" in prompt and "Groq" not in prompt


def test_council_with_one_answer_reports_single_and_with_none_reports_error():
    one = FakeProvider("ollama_local", chunks=["ответ"], needs_network=False)
    none = FakeProvider("groq", fail=ar.ProviderFailure("offline"))
    events = collect(ws.council_stream([one, none], [one], "S", "?"))
    assert events[-1] == {"type": "single", "provider": "ollama_local", "label": "Ollama_Local"}
    events = collect(ws.council_stream([none], [one], "S", "?"))
    assert events[-1] == {"type": "error", "reason": "no_answers"}
    assert collect(ws.council_stream([], [one], "S", "?"))[-1] == {"type": "error", "reason": "no_members"}


def test_council_member_timeout_counts_as_failure():
    stuck = RecordingProvider("claude_cli", chunks=["…"], delay=5)
    events = collect(ws.council_stream([stuck], [], "S", "?", member_timeout=0.1))
    assert {"type": "member_failed", "provider": "claude_cli", "label": "Claude_Cli", "reason": "timeout"} in events


# ─── Endpoints / конечные точки ───────────────────────────────────────────


@pytest.fixture()
def api(tmp_path, monkeypatch):
    fakes = {
        "claude_cli": RecordingProvider("claude_cli", fail=ar.ProviderFailure("not_signed_in"), tier=ar.TIER_SUBSCRIPTION),
        "gemini": RecordingProvider("gemini", chunks=["Облако: да"]),
        "ollama_local": RecordingProvider("ollama_local", chunks=["Локально: да"], tier=ar.TIER_LOCAL,
                                          model="qwen3.5:latest", needs_network=False),
    }
    monkeypatch.setattr(orchestrator, "assistant_settings", ar.AssistantSettingsStore(tmp_path / "a.json"))
    monkeypatch.setattr(orchestrator, "_assistant_provider_factory", lambda language="ru": fakes)

    async def no_sources(*args):
        return []

    monkeypatch.setattr(orchestrator, "_workshop_sources", no_sources)

    class Store:
        def get_progress(self):
            return PROGRESS

    monkeypatch.setattr(orchestrator, "study_progress_store", Store())

    async def online():
        return True

    monkeypatch.setattr(orchestrator, "_assistant_network_ok", online)
    return TestClient(orchestrator.app, client=("127.0.0.1", 50000)), fakes


def test_workshop_ask_knows_progress_and_next_step(api):
    client, fakes = api
    response = client.post("/workshop/ask/stream", json={
        "language": "ru", "question": "Что мне делать дальше?", "voice": True,
        "next_step": {"lesson": "Градиент", "module": "2 · Математика", "step": "3", "finished": 4, "total": 30},
        "labs": ["autograd"],
        "history": [{"role": "user", "content": "Привет"}, {"role": "assistant", "content": "Здравствуй"}],
    })
    assert response.status_code == 200 and response.headers["content-type"].startswith("text/event-stream")
    events = stream_events(response)
    assert events[-1]["type"] == "done" and events[-1]["provider"] == "gemini" and events[-1]["answer"] == "Облако: да"
    system = fakes["gemini"].systems[0]
    assert "Следующий шаг: «Градиент»." in system and "Пройдено уроков: 2." in system and "autograd" in system
    assert fakes["gemini"].messages[0][-1]["content"].startswith("Что мне делать дальше?")


def test_workshop_ask_works_offline_with_the_local_model(api, monkeypatch):
    client, fakes = api

    async def offline():
        return False

    monkeypatch.setattr(orchestrator, "_assistant_network_ok", offline)
    events = stream_events(client.post("/workshop/ask/stream", json={"language": "en", "question": "Hi"}))
    assert events[-1]["provider"] == "ollama_local" and fakes["gemini"].calls == 0


def test_workshop_council_endpoint_streams_members_and_summary(api):
    client, fakes = api
    fakes["claude_cli"].fail = None
    fakes["claude_cli"].chunks = ["Claude: да"]
    events = stream_events(client.post("/workshop/council/stream", json={"language": "ru", "question": "Да?", "members": 2}))
    assert events[0]["type"] == "members" and [m["provider"] for m in events[0]["members"]] == ["claude_cli", "gemini"]
    assert sum(event["type"] == "member_done" for event in events) == 2
    assert events[-1]["type"] == "done" and events[-1]["phase"] == "summary"


def test_workshop_endpoints_reject_remote_clients(api):
    remote = TestClient(orchestrator.app, client=("203.0.113.9", 50000))
    assert remote.post("/workshop/ask/stream", json={"question": "Hi"}).status_code == 403
    assert remote.post("/workshop/council/stream", json={"question": "Hi"}).status_code == 403


def test_workshop_ask_uses_rag_sources_and_shows_only_safe_fields(api, monkeypatch):
    client, fakes = api

    async def found(*args):
        return [{"id": "K1", "source_type": "course", "title": "Градиент", "path": "/secret/lesson.md",
                 "excerpt": "Градиент показывает направление роста.", "source_checked_at": "2026-11-01"}]

    monkeypatch.setattr(orchestrator, "_workshop_sources", found)
    events = stream_events(client.post("/workshop/ask/stream", json={"language": "ru", "question": "Что такое градиент?"}))
    assert events[0]["type"] == "sources"
    shown = events[0]["sources"][0]
    assert shown["id"] == "K1" and shown["title"] == "Градиент" and shown["date"] == "2026-11-01"
    assert "excerpt" not in shown and "/secret" not in str(events[0])
    sent = fakes["gemini"].messages[0][-1]["content"]
    assert "[K#]" in sent and "Градиент показывает направление роста." in sent and "Что такое градиент?" in sent
    assert "Ответь по-русски" in sent


def test_practice_hints_are_parsed_and_capped():
    parsed = orchestrator.parse_practice_hints('Вот: {"hints": ["Строка 2: нужен отступ", "", "Хорошо", "Ещё", "Лишнее"], "fixed": "print(1)"} конец')
    assert parsed == {"hints": ["Строка 2: нужен отступ", "Хорошо", "Ещё"], "fixed": "print(1)\n"}
    assert orchestrator.parse_practice_hints("не JSON") == {"hints": [], "fixed": ""}


def test_practice_hints_use_only_the_local_model(api):
    client, fakes = api
    fakes["ollama_local"].chunks = ['{"hints": ["Строка 1: опечатка"], "fixed": ""}']
    response = client.post("/practice/hints", json={"language": "ru", "code": "pritn(1)", "output": "NameError"})
    assert response.status_code == 200 and response.json()["hints"] == ["Строка 1: опечатка"]
    assert fakes["gemini"].calls == 0 and fakes["ollama_local"].calls == 1


def test_practice_fix_returns_only_the_code():
    assert orchestrator.parse_fixed_code("Вот:\n```python\nfor i in range(3):\n    print(i)\n```") == "for i in range(3):\n    print(i)\n"
    assert orchestrator.parse_fixed_code("") == ""
