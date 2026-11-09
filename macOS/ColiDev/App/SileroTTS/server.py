"""Local Silero speech for Creator's Path: POST /tts {"text", "lang": "ru"|"en", "speaker"} → WAV; GET /health.

Runs only on 127.0.0.1 with the models from install.sh, exits when the app that started it is gone.
Локальный синтез речи Silero: только 127.0.0.1, модели из install.sh, завершается вместе с приложением.
"""
from __future__ import annotations

import argparse
import io
import json
import os
import sys
import threading
import time
import wave
from array import array
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

import torch

MODELS = {"ru": ("v5_6_ru.pt", "eugene"), "en": ("v3_en.pt", "en_0")}
SAMPLE_RATE = 48000
MAX_TEXT = 900
_loaded: dict[str, object] = {}
_lock = threading.Lock()
torch.set_num_threads(max(1, min(4, os.cpu_count() or 1)))


def model(lang: str, folder: Path):
    with _lock:
        if lang not in _loaded:
            name, _ = MODELS[lang]
            importer = torch.package.PackageImporter(str(folder / name))
            loaded = importer.load_pickle("tts_models", "model")
            loaded.to(torch.device("cpu"))
            _loaded[lang] = loaded
        return _loaded[lang]


def speakers(lang: str, folder: Path) -> list[str]:
    return [s for s in getattr(model(lang, folder), "speakers", []) if s != "random"]


def synthesize(text: str, lang: str, speaker: str, folder: Path) -> bytes:
    tts = model(lang, folder)
    known = getattr(tts, "speakers", [])
    if speaker not in known:
        speaker = MODELS[lang][1]
    kwargs = {"text": text[:MAX_TEXT], "speaker": speaker, "sample_rate": SAMPLE_RATE}
    if lang == "ru":
        kwargs.update(put_accent=True, put_yo=True)
    with _lock:
        audio = tts.apply_tts(**kwargs)
    samples = array("h", (max(-32767, min(32767, int(value * 32767))) for value in audio.tolist()))
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(SAMPLE_RATE)
        out.writeframes(samples.tobytes())
    return buffer.getvalue()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--models", required=True)
    parser.add_argument("--port-file", required=True)
    parser.add_argument("--parent-pid", type=int, default=0)
    args = parser.parse_args()
    folder = Path(args.models)

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass

        def _send(self, status: int, body: bytes, kind: str) -> None:
            self.send_response(status)
            self.send_header("Content-Type", kind)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            if self.path != "/health":
                return self._send(404, b"{}", "application/json")
            ready = {lang: (folder / name).exists() for lang, (name, _) in MODELS.items()}
            self._send(200, json.dumps({"ok": True, "models": ready}).encode(), "application/json")

        def do_POST(self):
            try:
                length = min(int(self.headers.get("Content-Length", "0")), 20_000)
                payload = json.loads(self.rfile.read(length) or b"{}")
                lang = payload.get("lang") if payload.get("lang") in MODELS else "ru"
                text = str(payload.get("text", "")).strip()
                if self.path == "/speakers":
                    return self._send(200, json.dumps(speakers(lang, folder)).encode(), "application/json")
                if self.path != "/tts" or not text:
                    return self._send(400, b"{}", "application/json")
                self._send(200, synthesize(text, lang, str(payload.get("speaker", "")), folder), "audio/wav")
            except Exception as error:  # noqa: BLE001 — the app falls back to the macOS voice
                self._send(500, json.dumps({"error": type(error).__name__}).encode(), "application/json")

    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    Path(args.port_file).write_text(str(server.server_address[1]))

    def watch_parent() -> None:
        while True:
            time.sleep(2)
            if args.parent_pid and os.getppid() != args.parent_pid:
                os._exit(0)

    threading.Thread(target=watch_parent, daemon=True).start()
    server.serve_forever()


if __name__ == "__main__":
    sys.exit(main())
