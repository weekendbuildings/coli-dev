"""The Creator's workshop: the assistant chat with the learner's progress and the model council.

Мастерская Творца: чат ассистента, который знает прогресс ученика, и «совет» моделей.

The assistant never runs anything itself. It may propose an action in an ```action block;
the app shows it to the owner and runs dangerous actions only after the owner confirms.
Ассистент сам ничего не выполняет. Он может предложить действие в блоке ```action;
приложение показывает его владельцу, а опасное выполняет только после подтверждения.
"""

from __future__ import annotations

import asyncio
from typing import Any, AsyncIterator, Awaitable, Callable, Iterable

from assistant_router import (
    TIER_PAID,
    AssistantProvider,
    ModelInfo,
    classify_exception,
    route_stream,
)

COUNCIL_MAX_MEMBERS = 3
COUNCIL_MEMBER_TIMEOUT = 180.0
COUNCIL_ANSWER_LIMIT = 6000


def _clean(value: Any, limit: int) -> str:
    return " ".join(str(value or "").split())[:limit]


# ─── Progress / прогресс ──────────────────────────────────────────────────


def summarize_progress(progress: dict[str, Any] | None, language: str = "ru") -> str:
    """A few lines about `/learning/progress` for the prompt; never the raw records.

    Несколько строк о `/learning/progress` для подсказки, без сырых записей.
    """
    if not isinstance(progress, dict):
        return ""
    records = [record for record in progress.get("records") or [] if isinstance(record, dict)]
    completed = [record for record in records if record.get("completed")]
    recent = sorted(completed, key=lambda record: str(record.get("updated_at") or ""), reverse=True)[:5]
    weak = [
        record for record in records
        if isinstance(record.get("last_quality"), (int, float)) and record["last_quality"] < 3
    ][:5]
    due = int(progress.get("due_count") or 0)

    def ids(items: list[dict[str, Any]]) -> str:
        return ", ".join(_clean(item.get("lesson_id"), 80) for item in items)

    if language == "ru":
        lines = [f"Пройдено уроков: {len(completed)}.", f"Повторений на сегодня: {due}."]
        if recent:
            lines.append(f"Последние пройденные: {ids(recent)}.")
        if weak:
            lines.append(f"Где были трудности (оценка ниже 3): {ids(weak)}.")
    else:
        lines = [f"Lessons completed: {len(completed)}.", f"Reviews due today: {due}."]
        if recent:
            lines.append(f"Recently completed: {ids(recent)}.")
        if weak:
            lines.append(f"Where it was hard (grade below 3): {ids(weak)}.")
    return "\n".join(lines)


def describe_next_step(next_step: dict[str, Any] | None, language: str = "ru") -> str:
    """The next step of the path as the home screen shows it. Следующий шаг пути, как на главном экране."""
    if not isinstance(next_step, dict):
        return ""
    lesson = _clean(next_step.get("lesson"), 300)
    module = _clean(next_step.get("module"), 200)
    step = _clean(next_step.get("step"), 40)
    why = _clean(next_step.get("why"), 600)
    finished = next_step.get("finished")
    total = next_step.get("total")
    if language == "ru":
        lines = [f"Следующий шаг: «{lesson}»." if lesson else "Все готовые уроки пути пройдены."]
        if module:
            lines.append(f"Модуль: {module}" + (f", шаг {step}." if step else "."))
        if why:
            lines.append(f"Зачем: {why}")
        if isinstance(finished, int) and isinstance(total, int) and total > 0:
            lines.append(f"Путь пройден: {finished} из {total} уроков.")
    else:
        lines = [f"Next step: “{lesson}”." if lesson else "All written lessons of the path are done."]
        if module:
            lines.append(f"Module: {module}" + (f", step {step}." if step else "."))
        if why:
            lines.append(f"Why: {why}")
        if isinstance(finished, int) and isinstance(total, int) and total > 0:
            lines.append(f"Path done: {finished} of {total} lessons.")
    return "\n".join(lines)


# ─── Prompt / подсказка ───────────────────────────────────────────────────

ACTION_TOOLS_RU = """Действия на Mac. Ты сам ничего не выполняешь. Если владелец просит что-то сделать на Mac, коротко скажи, что предлагаешь, и добавь в конце ответа один блок:
```action
{"tool": "open_app", "app": "Safari"}
```
Инструменты (одно действие на блок, не больше трёх блоков):
- {"tool": "open_app", "app": "<имя программы>"} — открыть программу;
- {"tool": "open", "target": "<путь к файлу, папке или ссылка https://…>"} — открыть файл, папку или ссылку;
- {"tool": "find_files", "query": "<что искать>"} — найти файлы через Spotlight;
- {"tool": "write_note", "title": "<заголовок>", "text": "<текст заметки>"} — записать заметку в Obsidian;
- {"tool": "run_check", "lab": "<id задания «Собери и проверь сам»>"} — запустить проверку задания;
- {"tool": "shell", "command": "<команда zsh>"} — выполнить команду в Терминале.
Приложение покажет действие владельцу. Всё, что удаляет, перезаписывает, отправляет, устанавливает или меняет настройки, выполнится только после его подтверждения. Пароли никогда не спрашивай; для sudo macOS сама покажет окно пароля. Не предлагай действие, если владелец о нём не просил."""

ACTION_TOOLS_EN = """Actions on the Mac. You never run anything yourself. If the owner asks to do something on the Mac, briefly say what you propose and add one block at the end of the answer:
```action
{"tool": "open_app", "app": "Safari"}
```
Tools (one action per block, at most three blocks):
- {"tool": "open_app", "app": "<app name>"} — open an app;
- {"tool": "open", "target": "<file or folder path, or an https://… link>"} — open a file, folder or link;
- {"tool": "find_files", "query": "<what to find>"} — find files with Spotlight;
- {"tool": "write_note", "title": "<title>", "text": "<note text>"} — write a note to Obsidian;
- {"tool": "run_check", "lab": "<id of a build-and-check-it-yourself lab>"} — run a lab check;
- {"tool": "shell", "command": "<zsh command>"} — run a command in Terminal.
The app shows the action to the owner. Anything that deletes, overwrites, sends, installs or changes settings runs only after the owner confirms. Never ask for passwords; for sudo macOS shows its own password window. Do not propose an action the owner did not ask for."""


def build_workshop_system_prompt(progress_summary: str, next_step: str, language: str = "ru",
                                 labs: Iterable[str] = ()) -> str:
    """The Creator persona, mentor rules, action protocol and the learner's progress.

    Образ «Творца», правила наставника, протокол действий и прогресс ученика.
    """
    lab_ids = ", ".join(_clean(lab, 60) for lab in labs if _clean(lab, 60))
    if language == "ru":
        lines = [
            "Ты — «Творец», личный ассистент владельца этого Mac, как Jarvis: спокойный, точный, краткий, "
            "отвечаешь по делу и по-русски. Владелец идёт по пути Творца: Python → математика → машинное "
            "обучение → своя языковая модель → AGI → сознание.",
            "Ты наставник, а не исполнитель: объясняешь, задаёшь вопросы и проверяешь. Ключевой шаг в заданиях "
            "«Собери и проверь сам» и Skillbox не пишешь за ученика — даёшь подсказку и следующий вопрос.",
            "Не выдумывай факты, функции и ссылки. Если не уверен — так и скажи.",
            "Отвечай в Markdown, код — в блоках ```python. Если ответ будут слушать голосом, говори короче.",
            "",
            ACTION_TOOLS_RU,
        ]
        if lab_ids:
            lines.append(f"Задания для run_check: {lab_ids}.")
        lines += ["", "Что ты знаешь о пути владельца:", next_step or "Следующий шаг неизвестен.",
                  progress_summary or "Прогресс недоступен."]
    else:
        lines = [
            "You are “Creator”, the personal assistant of this Mac's owner, like Jarvis: calm, precise, brief, "
            "to the point, in English. The owner follows the Creator path: Python → mathematics → machine "
            "learning → their own language model → AGI → consciousness.",
            "You are a mentor, not a doer: you explain, ask questions and check. You never write the key step of "
            "build-and-check-it-yourself labs or Skillbox tasks for the learner — give a hint and the next question.",
            "Do not invent facts, functions or links. If you are not sure, say so.",
            "Answer in Markdown, code in ```python blocks. If the answer will be heard by voice, keep it shorter.",
            "",
            ACTION_TOOLS_EN,
        ]
        if lab_ids:
            lines.append(f"Labs for run_check: {lab_ids}.")
        lines += ["", "What you know about the owner's path:", next_step or "The next step is unknown.",
                  progress_summary or "Progress is unavailable."]
    return "\n".join(lines).strip()


def build_workshop_messages(history: Iterable[dict[str, str]], question: str, voice: bool = False,
                            language: str = "ru", max_turns: int = 16) -> list[dict[str, str]]:
    """Last turns plus the new question. Последние реплики и новый вопрос."""
    turns = [
        {"role": turn["role"], "content": str(turn["content"])[:20000]}
        for turn in history
        if isinstance(turn, dict) and turn.get("role") in ("user", "assistant") and str(turn.get("content", "")).strip()
    ][-max_turns:]
    while turns and turns[0]["role"] != "user":
        turns.pop(0)
    content = question.strip()
    if voice:
        content += ("\n\n(Вопрос задан голосом: ответь коротко, 2–4 предложения.)" if language == "ru"
                    else "\n\n(Asked by voice: answer briefly, 2–4 sentences.)")
    # The language and length rule sits right after the question: local models follow the last instruction best.
    # Правило языка и длины — сразу после вопроса: локальные модели лучше всего слушают последнюю инструкцию.
    content += ("\n\n(Ответь по-русски, ясно и коротко — обычно 3–8 предложений, если не просят подробнее. "
                "Если не знаешь — так и скажи.)" if language == "ru"
                else "\n\n(Answer in English, clearly and briefly — usually 3–8 sentences unless asked for more. "
                     "If you do not know, say so.)")
    return [*turns, {"role": "user", "content": content}]


# ─── Council / совет моделей ──────────────────────────────────────────────


async def choose_council(
    providers: Iterable[AssistantProvider],
    *,
    disabled: Iterable[str] = (),
    network_ok: Callable[[], Awaitable[bool]] | None = None,
    limit: int = COUNCIL_MAX_MEMBERS,
) -> tuple[list[AssistantProvider], list[dict[str, str]]]:
    """Up to `limit` free, configured, switched-on providers; network ones only when online.

    До `limit` бесплатных, настроенных и включённых провайдеров; сетевые — только при интернете.
    """
    switched_off = set(disabled)
    chosen: list[AssistantProvider] = []
    skipped: list[dict[str, str]] = []
    online: bool | None = None
    for provider in providers:
        if len(chosen) >= max(1, limit):
            break
        if provider.id in switched_off:
            skipped.append({"provider": provider.id, "reason": "disabled"})
            continue
        if provider.tier == TIER_PAID:
            skipped.append({"provider": provider.id, "reason": "paid_blocked"})
            continue
        if not provider.configured():
            skipped.append({"provider": provider.id, "reason": "not_configured"})
            continue
        if provider.needs_network and network_ok is not None:
            if online is None:
                try:
                    online = bool(await network_ok())
                except Exception:
                    online = False
            if not online:
                skipped.append({"provider": provider.id, "reason": "offline"})
                continue
        chosen.append(provider)
    return chosen, skipped


def build_council_summary_prompt(question: str, answers: list[dict[str, str]], language: str = "ru") -> str:
    """Ask one model to merge the answers and show agreement and disagreement.

    Просим одну модель свести ответы и показать, где модели согласны и где спорят.
    """
    blocks = []
    for index, answer in enumerate(answers, start=1):
        name = _clean(answer.get("label"), 80) or f"#{index}"
        blocks.append(f"### {name}\n{str(answer.get('answer') or '')[:COUNCIL_ANSWER_LIMIT]}")
    joined = "\n\n".join(blocks)
    if language == "ru":
        return (
            f"Вопрос владельца:\n{question.strip()}\n\nОтветы моделей совета:\n\n{joined}\n\n"
            "Сведи их в один ответ по-русски. Структура:\n"
            "1. **Итог** — лучший общий ответ коротко.\n"
            "2. **Где согласны** — пункты, в которых модели сходятся.\n"
            "3. **Где спорят** — расхождения: кто что говорит и кто, вероятно, прав и почему. "
            "Если проверить нельзя — так и скажи.\n"
            "4. **Что проверить самому** — один-два способа проверить ответ.\n"
            "Не добавляй фактов, которых нет ни в одном ответе, кроме явных исправлений ошибок."
        )
    return (
        f"The owner's question:\n{question.strip()}\n\nAnswers of the council models:\n\n{joined}\n\n"
        "Merge them into one answer in English. Structure:\n"
        "1. **Bottom line** — the best common answer, briefly.\n"
        "2. **Where they agree** — points the models share.\n"
        "3. **Where they disagree** — who says what, who is probably right and why. "
        "If it cannot be checked, say so.\n"
        "4. **What to check yourself** — one or two ways to verify the answer.\n"
        "Do not add facts that are in none of the answers, except clear corrections of mistakes."
    )


async def _member_answer(provider: AssistantProvider, system: str, messages: list[dict[str, str]],
                         queue: asyncio.Queue, timeout: float) -> None:
    parts: list[str] = []
    model = provider.model

    async def consume() -> None:
        nonlocal model
        async for item in provider.stream(system, messages):
            if isinstance(item, ModelInfo):
                model = item.model
                continue
            if item:
                parts.append(item)
                await queue.put({"type": "member_token", "provider": provider.id, "content": item})

    try:
        await asyncio.wait_for(consume(), timeout=timeout)
        answer = "".join(parts).strip()
        if not answer:
            raise RuntimeError("empty")
        await queue.put({"type": "member_done", "provider": provider.id, "label": provider.label,
                         "model": model, "answer": answer})
    except asyncio.CancelledError:
        raise
    except Exception as exc:  # noqa: BLE001 — one failing member must not stop the council
        reason = "empty" if str(exc) == "empty" else classify_exception(exc)
        await queue.put({"type": "member_failed", "provider": provider.id, "label": provider.label,
                         "reason": reason})


async def council_stream(
    members: list[AssistantProvider],
    summarizers: list[AssistantProvider],
    system: str,
    question: str,
    *,
    language: str = "ru",
    disabled: Iterable[str] = (),
    network_ok: Callable[[], Awaitable[bool]] | None = None,
    member_timeout: float = COUNCIL_MEMBER_TIMEOUT,
) -> AsyncIterator[dict[str, Any]]:
    """Ask the members in parallel, then let the first available summarizer merge the answers.

    Спрашиваем участников параллельно, затем первый доступный сводит ответы.
    Events: members, member_token, member_done, member_failed, then summary events of
    `route_stream` with `phase: "summary"`, or `error` / `single` when there is nothing to merge.
    """
    yield {"type": "members", "members": [
        {"provider": provider.id, "label": provider.label, "model": provider.model} for provider in members
    ]}
    if not members:
        yield {"type": "error", "reason": "no_members"}
        return
    messages = [{"role": "user", "content": question.strip()}]
    queue: asyncio.Queue = asyncio.Queue()
    tasks = [asyncio.create_task(_member_answer(provider, system, messages, queue, member_timeout))
             for provider in members]
    answers: list[dict[str, str]] = []
    finished = 0
    try:
        while finished < len(tasks):
            event = await queue.get()
            if event["type"] in ("member_done", "member_failed"):
                finished += 1
                if event["type"] == "member_done":
                    answers.append(event)
            yield event
    finally:
        for task in tasks:
            if not task.done():
                task.cancel()
    if not answers:
        yield {"type": "error", "reason": "no_answers"}
        return
    if len(answers) == 1:
        yield {"type": "single", "provider": answers[0]["provider"], "label": answers[0]["label"]}
        return
    summary_messages = [{"role": "user", "content": build_council_summary_prompt(question, answers, language)}]
    async for event in route_stream(summarizers, system, summary_messages, disabled=disabled, network_ok=network_ok):
        yield {**event, "phase": "summary"}
