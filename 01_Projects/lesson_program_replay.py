"""Run a lesson's programs on the real local model once, then check them against that recording.
Программы урока один раз работают на настоящей локальной модели, а дальше проверяются по этой записи.

To record and fill the lesson's output blocks (needs Ollama): / Записать и заполнить блоки вывода урока (нужна Ollama):
    python lesson_program_replay.py record <lesson.md> <recording.json>
"""
from __future__ import annotations

import contextlib
import hashlib
import io
import json
import re
import sys
import urllib.request
from pathlib import Path
from typing import Callable

_KEPT_FIELDS = ("message", "response", "prompt_eval_count", "eval_count", "logprobs", "done_reason", "embeddings", "embedding")


def sections(text: str) -> dict[str, str]:
    return {
        "ru": text.split("## Русский", 1)[1].split("## English", 1)[0],
        "en": text.split("## English", 1)[1].split("## Sources", 1)[0],
    }


def python_blocks(section: str) -> list[str]:
    return re.findall(r"```python\n(.*?)```", section, re.S)


def output_blocks(section: str) -> list[str]:
    return [block.strip() for block in re.findall(r"```output\n(.*?)```", section, re.S)]


def _key(request) -> str:
    body = json.loads(request.data.decode())
    canonical = json.dumps({"url": request.full_url, "body": body}, ensure_ascii=False, sort_keys=True)
    return hashlib.sha256(canonical.encode()).hexdigest()


class _Reply(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False


def _run(blocks: list[str], opener: Callable) -> list[str]:
    """Runs the blocks in one namespace, as one file; returns what each block printed. / Запускает блоки как один файл и возвращает вывод каждого."""
    original = urllib.request.urlopen
    urllib.request.urlopen = opener
    namespace: dict = {"__name__": "__lesson__"}
    outputs: list[str] = []
    try:
        for block in blocks:
            stream = io.StringIO()
            with contextlib.redirect_stdout(stream):
                exec(block, namespace)
            outputs.append(stream.getvalue().strip())
    finally:
        urllib.request.urlopen = original
    return outputs


def replay(section: str, recording: dict) -> list[str]:
    """Runs the section's programs against recorded answers. / Запускает программы раздела на записанных ответах."""

    def opener(request, timeout=None):
        key = _key(request)
        assert key in recording["calls"], f"The program asks what was not recorded / Программа просит то, чего нет в записи: {request.data[:200]!r}"
        return _Reply(json.dumps(recording["calls"][key]).encode())

    return _run(python_blocks(section), opener)


def record(lesson: Path, target: Path) -> None:
    original = urllib.request.urlopen
    calls: dict = {}

    def opener(request, timeout=None):
        key = _key(request)
        if key not in calls:
            with original(request, timeout=timeout or 900) as response:
                answer = json.load(response)
            calls[key] = {field: answer[field] for field in _KEPT_FIELDS if field in answer}
        return _Reply(json.dumps(calls[key]).encode())

    text = lesson.read_text(encoding="utf-8")
    parts = sections(text)
    previous = json.loads(target.read_text(encoding="utf-8")) if target.exists() else {}
    for section in parts.values():
        outputs = _run(python_blocks(section), opener)
        replaced = section
        for output in outputs:
            if "```output\n{{OUTPUT}}\n```" in replaced:
                replaced = replaced.replace("```output\n{{OUTPUT}}\n```", f"```output\n{output}\n```", 1)
        text = text.replace(section, replaced)
    assert "{{OUTPUT}}" not in text, "More output blocks than programs. / Блоков вывода больше, чем программ."
    lesson.write_text(text, encoding="utf-8")
    previous["calls"] = calls
    target.write_text(json.dumps(previous, ensure_ascii=False, indent=0) + "\n", encoding="utf-8")


if __name__ == "__main__":
    assert sys.argv[1] == "record"
    record(Path(sys.argv[2]), Path(sys.argv[3]))
