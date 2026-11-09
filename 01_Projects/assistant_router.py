"""Assistant model router for the Creator app.

Маршрутизатор моделей ассистента «Творца».

Order by default / порядок по умолчанию:
Claude by the owner's subscription (`claude -p`) → free cloud quotas
(OpenRouter `:free`, Gemini, Groq) → local Ollama without internet.
If a provider fails, hits its limit or there is no network, the router moves on
to the next one and reports which model answered. Paid routes are never called.

Claude по подписке владельца (`claude -p`) → бесплатные облачные квоты
(OpenRouter `:free`, Gemini, Groq) → локальная Ollama без интернета.
Если провайдер упал, кончился лимит или нет сети, маршрутизатор переходит к
следующему и сообщает, какая модель ответила. Платные маршруты не вызываются.

Quotas and rules: project-plan/FREE_MODELS_RU_EN.md.
"""

from __future__ import annotations

import asyncio
import json
import os
import shutil
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, AsyncIterator, Awaitable, Callable, Iterable

import httpx

from network_safety import is_loopback_http_url

# Failure kinds shown to the owner / виды отказов, которые видит владелец.
FAILURE_KINDS = (
    "not_configured",  # no key / нет ключа
    "not_signed_in",  # `claude auth login` not done / вход не выполнен
    "rate_limited",  # quota or limit reached / кончился лимит
    "offline",  # no network / нет сети
    "timeout",  # no answer in time / нет ответа вовремя
    "paid_blocked",  # would be a paid call / был бы платный вызов
    "empty",  # empty answer / пустой ответ
    "disabled",  # switched off in settings / выключен в настройках
    "failed",  # anything else / прочее
)

TIER_SUBSCRIPTION = "subscription"
TIER_FREE_CLOUD = "free_cloud"
TIER_LOCAL = "local"
TIER_PAID = "paid"

# OmniRoute (a local OpenAI-style gateway) comes after the free clouds; Kimi (Moonshot API) and Ollama Cloud are
# paid and only listed. / OmniRoute (локальный шлюз) после бесплатных облаков; Kimi и Ollama Cloud платные, только в списке.
DEFAULT_ORDER = ("claude_cli", "openrouter", "gemini", "groq", "omniroute", "ollama_local", "kimi", "ollama_cloud")

# Environment variables that would make `claude` bill an API key or run in bare
# mode (bare mode accepts only an API key). Они переключили бы `claude` на ключ API.
_CLAUDE_ENV_PREFIXES = ("ANTHROPIC_", "CLAUDE_CODE_", "CLAUDE_AGENT_SDK")
_CLAUDE_ENV_NAMES = {"CLAUDECODE", "CLAUDE_PID", "CLAUDE_EFFORT", "CLAUDE_CONFIG_DIR_OVERRIDE"}


class ProviderFailure(Exception):
    """A provider could not answer; `kind` is one of FAILURE_KINDS."""

    def __init__(self, kind: str, detail: str = "") -> None:
        super().__init__(detail or kind)
        self.kind = kind if kind in FAILURE_KINDS else "failed"
        self.detail = detail[:300]


def classify_http_status(status: int) -> str:
    if status == 429:
        return "rate_limited"
    if status in (401, 403):
        return "not_configured"
    if status == 402:
        return "paid_blocked"
    return "failed"


def classify_exception(exc: BaseException) -> str:
    if isinstance(exc, ProviderFailure):
        return exc.kind
    if isinstance(exc, (httpx.TimeoutException, asyncio.TimeoutError, TimeoutError)):
        return "timeout"
    if isinstance(exc, FileNotFoundError):
        return "not_configured"
    if isinstance(exc, (httpx.ConnectError, httpx.NetworkError, OSError)):
        return "offline"
    if isinstance(exc, httpx.HTTPStatusError):
        return classify_http_status(exc.response.status_code)
    return "failed"


def classify_claude_error(text: str) -> str:
    """Map a `claude -p` error message to a failure kind (checked on samples in tests)."""
    lowered = (text or "").lower()
    if "credit balance" in lowered or "api usage billing" in lowered:
        return "paid_blocked"
    if ("limit" in lowered and any(word in lowered for word in ("usage", "reached", "hit", "rate", "exceeded")))\
            or "resets" in lowered or "overloaded" in lowered:
        return "rate_limited"
    if any(word in lowered for word in ("/login", "not logged", "log in", "login", "authenticat", "oauth", "invalid api key")):
        return "not_signed_in"
    if any(word in lowered for word in ("enotfound", "econnrefused", "network", "unable to connect", "fetch failed", "offline", "getaddrinfo")):
        return "offline"
    if "timed out" in lowered or "timeout" in lowered:
        return "timeout"
    return "failed"


@dataclass
class ModelInfo:
    """Yielded by a provider stream when it learns the exact model name."""

    model: str


class AssistantProvider:
    id: str = ""
    label: str = ""
    tier: str = TIER_FREE_CLOUD
    needs_network: bool = True
    model: str = ""

    def configured(self) -> bool:
        return True

    async def status(self) -> dict[str, Any]:
        return {"configured": self.configured(), "reachable": None, "detail": ""}

    def stream(self, system: str, messages: list[dict[str, str]]) -> AsyncIterator[str | ModelInfo]:
        raise NotImplementedError


# ─── Claude by subscription / Claude по подписке ───────────────────────────


class ClaudeStreamParser:
    """Parse `claude -p --output-format stream-json --include-partial-messages` lines.

    Разбирает строки потокового JSON из `claude -p`. Текст приходит частями
    (`stream_event` → `text_delta`); если частей не было, берётся текст из
    `assistant` или `result`. Ключ API (`apiKeySource` ≠ `none`) — сразу отказ:
    это был бы платный вызов.
    """

    def __init__(self) -> None:
        self.model: str | None = None
        self.emitted_text = False
        self.saw_partial = False
        self.finished = False

    def feed(self, line: str) -> list[str | ModelInfo]:
        line = line.strip()
        if not line:
            return []
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            return []
        if not isinstance(event, dict):
            return []
        kind = event.get("type")
        out: list[str | ModelInfo] = []
        if kind == "system" and event.get("subtype") == "init":
            source = event.get("apiKeySource")
            if isinstance(source, str) and source not in ("none", ""):
                raise ProviderFailure("paid_blocked", "claude reported an API key source")
            model = event.get("model")
            if isinstance(model, str) and model:
                self.model = model
                out.append(ModelInfo(model))
        elif kind == "stream_event":
            inner = event.get("event") or {}
            delta = inner.get("delta") if isinstance(inner, dict) else None
            if isinstance(delta, dict) and delta.get("type") == "text_delta":
                text = delta.get("text")
                if isinstance(text, str) and text:
                    self.saw_partial = True
                    self.emitted_text = True
                    out.append(text)
        elif kind == "assistant":
            message = event.get("message") or {}
            if isinstance(message, dict):
                model = message.get("model")
                if isinstance(model, str) and model and model != self.model and not model.startswith("<"):
                    self.model = model
                    out.append(ModelInfo(model))
                # `<synthetic>` messages are CLI notices such as "Not logged in", not answers.
                # Сообщения `<synthetic>` — уведомления CLI вроде «Not logged in», а не ответ.
                synthetic = isinstance(model, str) and model.startswith("<")
                if not self.saw_partial and not synthetic:
                    for block in message.get("content") or []:
                        if isinstance(block, dict) and block.get("type") == "text" and block.get("text"):
                            self.emitted_text = True
                            out.append(block["text"])
        elif kind == "rate_limit_event":
            info = event.get("rate_limit_info") or {}
            if isinstance(info, dict) and info.get("status") == "rejected":
                raise ProviderFailure("rate_limited", "claude subscription limit reached")
        elif kind == "result":
            self.finished = True
            result_text = event.get("result") if isinstance(event.get("result"), str) else ""
            if event.get("is_error") or event.get("subtype") not in (None, "success"):
                raise ProviderFailure(classify_claude_error(result_text), result_text)
            if not self.emitted_text and result_text:
                self.emitted_text = True
                out.append(result_text)
        return out


def claude_transcript(messages: list[dict[str, str]], language: str = "ru") -> str:
    """One prompt text from the dialogue: `claude -p` takes a single message."""
    if len(messages) == 1:
        return messages[0]["content"]
    learner, mentor = ("Ученик", "Наставник") if language == "ru" else ("Learner", "Mentor")
    lines = []
    for message in messages[:-1]:
        who = learner if message["role"] == "user" else mentor
        lines.append(f"{who}: {message['content']}")
    header = "Предыдущий разговор:" if language == "ru" else "Earlier conversation:"
    now = "Новый вопрос ученика:" if language == "ru" else "The learner's new question:"
    return f"{header}\n\n" + "\n\n".join(lines) + f"\n\n{now}\n{messages[-1]['content']}"


def claude_environment(base: dict[str, str] | None = None) -> dict[str, str]:
    """Environment without API-key and bare-mode variables, so the subscription login is used."""
    source = dict(os.environ if base is None else base)
    env = {
        key: value for key, value in source.items()
        if not key.startswith(_CLAUDE_ENV_PREFIXES) and key not in _CLAUDE_ENV_NAMES
    }
    home = env.get("HOME") or str(Path.home())
    env["HOME"] = home
    extra_path = [f"{home}/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin"]
    env["PATH"] = ":".join(dict.fromkeys([*filter(None, env.get("PATH", "").split(":")), *extra_path]))
    env["DISABLE_AUTOUPDATER"] = "1"
    env["CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"] = "1"
    return env


def find_claude_binary(home: Path | None = None) -> str | None:
    home = home or Path.home()
    for candidate in (home / ".local/bin/claude", Path("/opt/homebrew/bin/claude"), Path("/usr/local/bin/claude")):
        if candidate.exists() and os.access(candidate, os.X_OK):
            return str(candidate)
    return shutil.which("claude")


Spawn = Callable[[list[str], dict[str, str], str], Awaitable[Any]]


async def _default_spawn(command: list[str], env: dict[str, str], cwd: str) -> Any:
    return await asyncio.create_subprocess_exec(
        *command,
        stdin=asyncio.subprocess.PIPE,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        env=env,
        cwd=cwd,
        limit=4 * 1024 * 1024,
    )


# `claude -p` without a sign-in waits until the timeout instead of failing (CLI 2026-11), so the
# provider asks `claude auth status` first (0.1 s) and remembers the answer for a short while.
# `claude -p` без входа ждёт до тайм-аута, а не падает, поэтому сначала спрашиваем `claude auth status`
# (0,1 с) и ненадолго запоминаем ответ.
CLAUDE_SIGNIN_TTL = {"signed_in": 300.0, "not_signed_in": 20.0, "paid_blocked": 60.0}
_claude_signin_cache: dict[str, tuple[float, str]] = {}


class ClaudeCLIProvider(AssistantProvider):
    id = "claude_cli"
    label = "Claude"
    tier = TIER_SUBSCRIPTION

    def __init__(
        self,
        *,
        binary: str | None | Callable[[], str | None] = find_claude_binary,
        model: str = "sonnet",
        workdir: Path | None = None,
        language: str = "ru",
        first_output_timeout: float = 90,
        idle_timeout: float = 60,
        total_timeout: float = 300,
        spawn: Spawn | None = None,
        signin_check: Callable[[], Awaitable[str]] | None = None,
    ) -> None:
        self._binary = binary
        self._signin_check = signin_check
        self.model = model
        self.workdir = workdir
        self.language = language
        self.first_output_timeout = first_output_timeout
        self.idle_timeout = idle_timeout
        self.total_timeout = total_timeout
        self.spawn = spawn or _default_spawn

    def binary(self) -> str | None:
        return self._binary() if callable(self._binary) else self._binary

    def configured(self) -> bool:
        return bool(self.binary())

    def command(self, binary: str, system: str) -> list[str]:
        return [
            binary, "-p",
            "--output-format", "stream-json",
            "--include-partial-messages",
            "--verbose",
            "--model", self.model,
            "--tools", "",
            "--strict-mcp-config",
            "--setting-sources", "project",
            "--no-session-persistence",
            "--system-prompt", system,
        ]

    def _workdir(self) -> str:
        path = self.workdir or Path(os.environ.get("TMPDIR", "/tmp")) / "coli-dev-assistant"
        path.mkdir(parents=True, exist_ok=True)
        return str(path)

    async def status(self) -> dict[str, Any]:
        binary = self.binary()
        if not binary:
            return {"configured": False, "reachable": False, "detail": "not_installed"}
        try:
            process = await asyncio.create_subprocess_exec(
                binary, "auth", "status", "--json",
                stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.DEVNULL,
                env=claude_environment(), cwd=self._workdir(),
            )
            stdout, _ = await asyncio.wait_for(process.communicate(), timeout=15)
            payload = json.loads(stdout.decode("utf-8", "replace") or "{}")
        except Exception:
            return {"configured": True, "reachable": None, "detail": "status_unknown"}
        signed_in = bool(payload.get("loggedIn"))
        if signed_in and "key" in str(payload.get("authMethod", "")).lower():
            # An API key would be billed: the router refuses it.
            # Ключ API оплачивается отдельно: маршрутизатор его не использует.
            return {"configured": True, "reachable": False, "detail": "paid_blocked"}
        return {"configured": True, "reachable": signed_in, "detail": "signed_in" if signed_in else "not_signed_in"}

    async def signin_state(self, binary: str) -> str:
        """`signed_in`, `not_signed_in`, `paid_blocked` or `status_unknown`, cached per binary."""
        if self._signin_check is not None:
            return await self._signin_check()
        loop = asyncio.get_running_loop()
        cached = _claude_signin_cache.get(binary)
        if cached and loop.time() < cached[0]:
            return cached[1]
        detail = str((await self.status()).get("detail", "status_unknown"))
        ttl = CLAUDE_SIGNIN_TTL.get(detail)
        if ttl:
            _claude_signin_cache[binary] = (loop.time() + ttl, detail)
        return detail

    async def stream(self, system: str, messages: list[dict[str, str]]) -> AsyncIterator[str | ModelInfo]:
        binary = self.binary()
        if not binary:
            raise ProviderFailure("not_configured", "claude CLI not found")
        state = await self.signin_state(binary)
        if state in ("not_signed_in", "paid_blocked"):
            raise ProviderFailure(state, "claude auth status")
        prompt = claude_transcript(messages, self.language)
        process = await self.spawn(self.command(binary, system), claude_environment(), self._workdir())
        parser = ClaudeStreamParser()
        loop = asyncio.get_running_loop()
        deadline = loop.time() + self.total_timeout
        try:
            process.stdin.write(prompt.encode("utf-8"))
            await process.stdin.drain()
            process.stdin.close()
            while True:
                wait = self.idle_timeout if parser.emitted_text else self.first_output_timeout
                wait = min(wait, deadline - loop.time())
                if wait <= 0:
                    raise ProviderFailure("timeout", "claude answer took too long")
                try:
                    raw = await asyncio.wait_for(process.stdout.readline(), timeout=wait)
                except asyncio.TimeoutError:
                    raise ProviderFailure("timeout", "claude stopped answering") from None
                if not raw:
                    break
                for item in parser.feed(raw.decode("utf-8", "replace")):
                    yield item
                if parser.finished:
                    break
            if not parser.finished:
                await asyncio.wait_for(process.wait(), timeout=10)
                stderr = b""
                if process.stderr is not None:
                    try:
                        stderr = await asyncio.wait_for(process.stderr.read(4000), timeout=2)
                    except asyncio.TimeoutError:
                        pass
                text = stderr.decode("utf-8", "replace")
                raise ProviderFailure(classify_claude_error(text) if text else "failed", text or "claude exited")
        finally:
            if getattr(process, "returncode", None) is None:
                try:
                    process.kill()
                except ProcessLookupError:
                    pass
                try:
                    await asyncio.wait_for(process.wait(), timeout=5)
                except Exception:
                    pass


# ─── HTTP providers / провайдеры по HTTP ──────────────────────────────────


KeyGetter = Callable[[], str]


class _HTTPProvider(AssistantProvider):
    def __init__(self, *, key: KeyGetter, model: str, transport: httpx.AsyncBaseTransport | None = None,
                 timeout: float = 90) -> None:
        self.key = key
        self.model = model
        self.transport = transport
        self.timeout = timeout

    def configured(self) -> bool:
        return bool(self.key())

    def _client(self) -> httpx.AsyncClient:
        return httpx.AsyncClient(transport=self.transport, timeout=httpx.Timeout(self.timeout, connect=10))

    async def _probe(self, url: str, headers: dict[str, str]) -> dict[str, Any]:
        if not self.configured():
            return {"configured": False, "reachable": None, "detail": "no_key"}
        try:
            async with self._client() as client:
                response = await client.get(url, headers=headers)
        except Exception as exc:
            return {"configured": True, "reachable": False, "detail": classify_exception(exc)}
        if response.status_code == 200:
            return {"configured": True, "reachable": True, "detail": "ok", "json": _safe_json(response)}
        return {"configured": True, "reachable": False, "detail": classify_http_status(response.status_code)}


def _safe_json(response: httpx.Response) -> Any:
    try:
        return response.json()
    except Exception:
        return None


async def _sse_payloads(response: httpx.Response) -> AsyncIterator[str]:
    async for line in response.aiter_lines():
        if line.startswith("data:"):
            yield line[5:].strip()


class OpenAICompatibleFreeProvider(_HTTPProvider):
    """OpenRouter `:free`, Groq, Kimi and a local gateway such as OmniRoute: OpenAI-style streaming chat."""

    def __init__(self, *, id: str, label: str, base_url: str, status_path: str, key: KeyGetter, model: str,
                 extra_headers: dict[str, str] | None = None, free_model_check: Callable[[str], bool] | None = None,
                 transport: httpx.AsyncBaseTransport | None = None, tier: str = TIER_FREE_CLOUD,
                 needs_network: bool = True, key_required: bool = True) -> None:
        super().__init__(key=key, model=model, transport=transport)
        self.id = id
        self.label = label
        self.base_url = base_url.rstrip("/")
        self.status_path = status_path
        self.extra_headers = extra_headers or {}
        self.free_model_check = free_model_check
        self.tier = tier
        self.needs_network = needs_network
        self.key_required = key_required

    def configured(self) -> bool:
        # A local gateway may run without a key. / Локальный шлюз может работать без ключа.
        return bool(self.base_url and self.model) and (not self.key_required or bool(self.key()))

    def _headers(self) -> dict[str, str]:
        key = self.key()
        return {**({"Authorization": f"Bearer {key}"} if key else {}), **self.extra_headers}

    async def status(self) -> dict[str, Any]:
        result = await self._probe(self.base_url + self.status_path, self._headers())
        payload = result.pop("json", None)
        if isinstance(payload, dict) and isinstance(payload.get("data"), dict):
            daily = payload["data"].get("free_model_daily_requests")
            if isinstance(daily, dict) and isinstance(daily.get("remaining"), int):
                result["remaining_today"] = daily["remaining"]
        return result

    async def stream(self, system: str, messages: list[dict[str, str]]) -> AsyncIterator[str | ModelInfo]:
        if not self.configured():
            raise ProviderFailure("not_configured")
        if self.free_model_check and not self.free_model_check(self.model):
            raise ProviderFailure("paid_blocked", "model is not free")
        body = {
            "model": self.model,
            "stream": True,
            "max_tokens": 2048,
            "messages": [{"role": "system", "content": system}, *messages],
        }
        async with self._client() as client:
            async with client.stream("POST", self.base_url + "/chat/completions", json=body,
                                     headers=self._headers()) as response:
                if response.status_code != 200:
                    raise ProviderFailure(classify_http_status(response.status_code), f"HTTP {response.status_code}")
                reported = None
                async for payload in _sse_payloads(response):
                    if payload == "[DONE]":
                        break
                    try:
                        event = json.loads(payload)
                    except json.JSONDecodeError:
                        continue
                    if not isinstance(event, dict):
                        continue
                    error = event.get("error")
                    if error:
                        code = error.get("code") if isinstance(error, dict) else None
                        raise ProviderFailure(classify_http_status(code) if isinstance(code, int) else "failed",
                                              "stream error")
                    model = event.get("model")
                    if isinstance(model, str) and model and model != reported:
                        reported = model
                        yield ModelInfo(model)
                    for choice in event.get("choices") or []:
                        delta = choice.get("delta") if isinstance(choice, dict) else None
                        content = delta.get("content") if isinstance(delta, dict) else None
                        if isinstance(content, str) and content:
                            yield content


def is_loopback_url(url: str) -> bool:
    """Only a gateway on this Mac counts as local; any other address may be a paid API.
    Локальным считается только шлюз на этом Mac; другой адрес может оказаться платным API."""
    try:
        host = (httpx.URL(url).host or "").lower()
    except Exception:  # noqa: BLE001 — a broken address is simply not local
        return False
    return host in {"127.0.0.1", "localhost", "::1", "[::1]"}


def is_free_openrouter_model(model: str) -> bool:
    return model == "openrouter/free" or model.endswith(":free")


class GeminiProvider(_HTTPProvider):
    id = "gemini"
    label = "Gemini"
    base_url = "https://generativelanguage.googleapis.com/v1beta"

    async def status(self) -> dict[str, Any]:
        result = await self._probe(f"{self.base_url}/models/{self.model}", {"x-goog-api-key": self.key()})
        result.pop("json", None)
        return result

    async def stream(self, system: str, messages: list[dict[str, str]]) -> AsyncIterator[str | ModelInfo]:
        if not self.configured():
            raise ProviderFailure("not_configured")
        body = {
            "systemInstruction": {"parts": [{"text": system}]},
            "contents": [
                {"role": "model" if m["role"] == "assistant" else "user", "parts": [{"text": m["content"]}]}
                for m in messages
            ],
            "generationConfig": {"maxOutputTokens": 4096},
        }
        url = f"{self.base_url}/models/{self.model}:streamGenerateContent?alt=sse"
        async with self._client() as client:
            async with client.stream("POST", url, json=body, headers={"x-goog-api-key": self.key()}) as response:
                if response.status_code != 200:
                    raise ProviderFailure(classify_http_status(response.status_code), f"HTTP {response.status_code}")
                reported = None
                async for payload in _sse_payloads(response):
                    try:
                        event = json.loads(payload)
                    except json.JSONDecodeError:
                        continue
                    if not isinstance(event, dict):
                        continue
                    if event.get("error"):
                        code = event["error"].get("code") if isinstance(event["error"], dict) else None
                        raise ProviderFailure(classify_http_status(code) if isinstance(code, int) else "failed")
                    version = event.get("modelVersion")
                    if isinstance(version, str) and version and version != reported:
                        reported = version
                        yield ModelInfo(version)
                    for candidate in event.get("candidates") or []:
                        content = candidate.get("content") if isinstance(candidate, dict) else None
                        for part in (content or {}).get("parts") or []:
                            text = part.get("text") if isinstance(part, dict) else None
                            if isinstance(text, str) and text and not part.get("thought"):
                                yield text


class OllamaProvider(_HTTPProvider):
    """Local Ollama (and, marked paid, Ollama Cloud models through the same server)."""

    def __init__(self, *, id: str, label: str, base_url: str, models: Iterable[str], tier: str = TIER_LOCAL,
                 num_predict: int = 1536, transport: httpx.AsyncBaseTransport | None = None) -> None:
        self.models = [m for m in models if m]
        super().__init__(key=lambda: "local", model=self.models[0] if self.models else "", transport=transport,
                         timeout=120)
        self.id = id
        self.label = label
        self.base_url = base_url.rstrip("/")
        self.tier = tier
        self.needs_network = tier != TIER_LOCAL
        self.num_predict = num_predict

    def configured(self) -> bool:
        return bool(self.models) and is_loopback_http_url(self.base_url)

    async def installed(self) -> list[str]:
        async with self._client() as client:
            response = await client.get(self.base_url + "/api/tags", timeout=5)
            response.raise_for_status()
            return [m.get("name", "") for m in response.json().get("models", []) if isinstance(m, dict)]

    @staticmethod
    def _matches(wanted: str, installed: list[str]) -> str | None:
        for name in installed:
            if name == wanted or (":" not in wanted and name == f"{wanted}:latest"):
                return name
        return None

    async def status(self) -> dict[str, Any]:
        if not self.configured():
            return {"configured": False, "reachable": None, "detail": "no_model"}
        try:
            installed = await self.installed()
        except Exception as exc:
            return {"configured": True, "reachable": False, "detail": classify_exception(exc)}
        found = [m for m in self.models if self._matches(m, installed)]
        return {"configured": True, "reachable": bool(found), "detail": "ok" if found else "no_model",
                "models": found}

    async def stream(self, system: str, messages: list[dict[str, str]]) -> AsyncIterator[str | ModelInfo]:
        if not self.configured():
            raise ProviderFailure("not_configured", "Ollama must be on localhost")
        try:
            installed = await self.installed()
        except Exception as exc:
            raise ProviderFailure("failed" if self.tier == TIER_LOCAL else classify_exception(exc),
                                  "Ollama is not running") from None
        model = next((found for m in self.models if (found := self._matches(m, installed))), None)
        if not model:
            raise ProviderFailure("not_configured", "no listed model is installed")
        yield ModelInfo(model)
        body = {
            "model": model,
            "stream": True,
            "think": False,
            "options": {"num_predict": self.num_predict},
            "messages": [{"role": "system", "content": system}, *messages],
        }
        async with self._client() as client:
            async with client.stream("POST", self.base_url + "/api/chat", json=body) as response:
                if response.status_code != 200:
                    raise ProviderFailure(classify_http_status(response.status_code), f"HTTP {response.status_code}")
                async for line in response.aiter_lines():
                    if not line.strip():
                        continue
                    try:
                        event = json.loads(line)
                    except json.JSONDecodeError:
                        raise ProviderFailure("failed", "malformed Ollama event") from None
                    if isinstance(event, dict) and event.get("error"):
                        raise ProviderFailure("failed", "Ollama error")
                    message = event.get("message") if isinstance(event, dict) else None
                    content = message.get("content") if isinstance(message, dict) else None
                    if isinstance(content, str) and content:
                        yield content
                    if isinstance(event, dict) and event.get("done") is True:
                        break


# ─── Router / маршрутизатор ───────────────────────────────────────────────


@dataclass
class RouterSettings:
    order: list[str] = field(default_factory=lambda: list(DEFAULT_ORDER))
    disabled: list[str] = field(default_factory=list)


def normalize_order(order: Iterable[str] | None, known: Iterable[str] = DEFAULT_ORDER) -> list[str]:
    """Known ids only, no repeats; missing ids are appended in default order."""
    known_list = list(known)
    result: list[str] = []
    for provider_id in order or []:
        if provider_id in known_list and provider_id not in result:
            result.append(provider_id)
    result.extend(p for p in known_list if p not in result)
    return result


class AssistantSettingsStore:
    """Order and switched-off providers in `assistant-models.json` (no secrets)."""

    def __init__(self, path: Path) -> None:
        self.path = Path(path).expanduser()

    def get(self) -> RouterSettings:
        try:
            payload = json.loads(self.path.read_text(encoding="utf-8"))
        except (OSError, UnicodeDecodeError, json.JSONDecodeError):
            return RouterSettings()
        if not isinstance(payload, dict):
            return RouterSettings()
        order = payload.get("order") if isinstance(payload.get("order"), list) else None
        disabled = payload.get("disabled") if isinstance(payload.get("disabled"), list) else []
        return RouterSettings(
            order=normalize_order([p for p in order or [] if isinstance(p, str)]),
            disabled=[p for p in disabled if isinstance(p, str) and p in DEFAULT_ORDER],
        )

    def save(self, order: Iterable[str], disabled: Iterable[str]) -> RouterSettings:
        settings = RouterSettings(
            order=normalize_order(order),
            disabled=sorted({p for p in disabled if p in DEFAULT_ORDER}),
        )
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temporary = self.path.with_suffix(".tmp")
        temporary.write_text(json.dumps({"order": settings.order, "disabled": settings.disabled}, ensure_ascii=False),
                             encoding="utf-8")
        temporary.replace(self.path)
        return settings


async def route_stream(
    providers: Iterable[AssistantProvider],
    system: str,
    messages: list[dict[str, str]],
    *,
    disabled: Iterable[str] = (),
    network_ok: Callable[[], Awaitable[bool]] | None = None,
) -> AsyncIterator[dict[str, Any]]:
    """Try providers in order and stream events.

    Events: `provider` (trying it), `token`, `reset` (drop the partial answer of
    a provider that failed midway), `fallback` (moving on, with the reason),
    `done` (who answered, with all attempts) or `error` (nobody answered).
    События: пробуем провайдера, кусок ответа, сброс частичного ответа, переход
    к следующему с причиной, готово (кто ответил) или ошибка (никто не ответил).
    """
    switched_off = set(disabled)
    attempts: list[dict[str, str]] = []
    online: bool | None = None
    for provider in providers:
        def skip(reason: str) -> dict[str, Any]:
            attempts.append({"provider": provider.id, "model": provider.model, "result": reason})
            return {"type": "fallback", "provider": provider.id, "label": provider.label, "reason": reason}

        if provider.id in switched_off:
            attempts.append({"provider": provider.id, "model": provider.model, "result": "disabled"})
            continue
        if provider.tier == TIER_PAID:
            attempts.append({"provider": provider.id, "model": provider.model, "result": "paid_blocked"})
            continue
        if not provider.configured():
            attempts.append({"provider": provider.id, "model": provider.model, "result": "not_configured"})
            continue
        if provider.needs_network and network_ok is not None:
            if online is None:
                try:
                    online = bool(await network_ok())
                except Exception:
                    online = False
            if not online:
                yield skip("offline")
                continue

        model = provider.model
        yield {"type": "provider", "provider": provider.id, "label": provider.label, "model": model}
        parts: list[str] = []
        try:
            async for item in provider.stream(system, messages):
                if isinstance(item, ModelInfo):
                    model = item.model
                    continue
                if item:
                    parts.append(item)
                    yield {"type": "token", "content": item}
            if not "".join(parts).strip():
                raise ProviderFailure("empty")
        except asyncio.CancelledError:
            raise
        except Exception as exc:  # noqa: BLE001 — every failure moves on to the next provider
            if parts:
                yield {"type": "reset", "provider": provider.id}
            yield skip(classify_exception(exc))
            continue
        attempts.append({"provider": provider.id, "model": model, "result": "ok"})
        yield {
            "type": "done",
            "provider": provider.id,
            "label": provider.label,
            "tier": provider.tier,
            "model": model,
            "answer": "".join(parts).strip(),
            "attempts": attempts,
        }
        return
    yield {"type": "error", "attempts": attempts}


# ─── Prompts / подсказки ──────────────────────────────────────────────────


def _clean(value: Any, limit: int) -> str:
    return " ".join(str(value or "").split())[:limit]


def build_system_prompt(context: dict[str, Any], language: str = "ru") -> str:
    """Mentor rules plus the lesson context. Правила наставника и контекст урока."""
    title = _clean(context.get("title"), 300)
    subject = _clean(context.get("subject"), 120)
    goal = _clean(context.get("goal"), 2000)
    position = _clean(context.get("position"), 300)
    course = _clean(context.get("course"), 200)
    track = _clean(context.get("track"), 200)
    skillbox = context.get("kind") == "skillbox"
    if language == "ru":
        lines = [
            "Ты — наставник в учебном приложении «Творец». Ученик идёт по пути Творца: "
            "Python → математика → машинное обучение → своя языковая модель.",
            "Отвечай по-русски простыми словами, как новичку: коротко, точно, с примером.",
            "Не выдумывай факты, функции и ссылки. Если не уверен — так и скажи.",
            "Если ученик прислал код: найди ошибки и слабые места, объясни почему и подскажи, "
            "как исправить, но не переписывай всё решение за него.",
            "Не давай готовый ответ к заданию, пока ученик сам не попросит.",
            "Пиши в Markdown, код — в блоках ```python.",
            "",
            f"Тема: {title}" if title else "",
            f"Предмет: {subject}" if subject else "",
            f"Цель урока: {goal}" if goal else "",
            f"Где ученик сейчас: {position}" if position else "",
        ]
        if skillbox:
            lines += [
                f"Это тема курса Skillbox «{course}» ({track})." if course else "Это тема курса Skillbox.",
                "Отдельно скажи, что в этой теме могло устареть к 2026 году и как это пишут сейчас, "
                "со ссылкой на официальную документацию (docs.python.org и т. п.). Если не уверен — так и скажи.",
            ]
    else:
        lines = [
            "You are the mentor in the learning app Creator. The learner follows the Creator path: "
            "Python → mathematics → machine learning → their own language model.",
            "Answer in plain English, as to a beginner: short, accurate, with an example.",
            "Do not invent facts, functions or links. If you are not sure, say so.",
            "If the learner sends code: find mistakes and weak spots, explain why and hint how to fix them, "
            "but do not rewrite the whole solution for them.",
            "Do not give the finished answer to an exercise until the learner asks.",
            "Write Markdown, code in ```python blocks.",
            "",
            f"Topic: {title}" if title else "",
            f"Subject: {subject}" if subject else "",
            f"Lesson goal: {goal}" if goal else "",
            f"Where the learner is now: {position}" if position else "",
        ]
        if skillbox:
            lines += [
                f"This is a topic of the Skillbox course “{course}” ({track})." if course else
                "This is a Skillbox course topic.",
                "Also say what in this topic may be out of date by 2026 and how it is written now, "
                "with a link to the official documentation (docs.python.org etc.). If you are not sure, say so.",
            ]
    return "\n".join(line for line in lines if line is not None).strip()


def build_messages(history: Iterable[dict[str, str]], question: str, code: str | None,
                   language: str = "ru", max_turns: int = 12) -> list[dict[str, str]]:
    """Dialogue for the model: last turns of history plus the new question (and code)."""
    turns = [
        {"role": turn["role"], "content": str(turn["content"])[:20000]}
        for turn in history
        if isinstance(turn, dict) and turn.get("role") in ("user", "assistant") and str(turn.get("content", "")).strip()
    ][-max_turns:]
    while turns and turns[0]["role"] != "user":
        turns.pop(0)
    content = question.strip()
    if code and code.strip():
        label = "Мой код:" if language == "ru" else "My code:"
        content += f"\n\n{label}\n```python\n{code.rstrip()}\n```"
    return [*turns, {"role": "user", "content": content}]


async def internet_reachable(hosts: Iterable[tuple[str, int]] = (("api.anthropic.com", 443), ("openrouter.ai", 443),
                                                                ("1.1.1.1", 443)), timeout: float = 3) -> bool:
    """A TCP connection to any well-known host means the internet is up (no request is sent).

    Если удалось открыть TCP-соединение хоть с одним известным узлом, интернет есть (запрос не отправляется).
    """
    for host, port in hosts:
        try:
            _, writer = await asyncio.wait_for(asyncio.open_connection(host, port), timeout=timeout)
        except Exception:
            continue
        writer.close()
        try:
            await writer.wait_closed()
        except Exception:
            pass
        return True
    return False
