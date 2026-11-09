#!/bin/bash
# Офлайн-голос Silero для «Creator's Path»: отдельное окружение Python, PyTorch и две модели Silero.
# Offline Silero voice for Creator's Path: an isolated Python environment, PyTorch and two Silero models.
#
# Что скачивается / What is downloaded (2026-11-09):
#   PyTorch 2.15.0 для Apple Silicon (PyPI, ~139 МБ) и его зависимости (~15 МБ);
#   v5_6_ru.pt — лучшая русская модель Silero (~148 МБ, голоса aidar, baya, kseniya, xenia, eugene);
#   v3_en.pt — английская модель Silero (~57 МБ).
# Всё ставится в ~/Library/Caches/ColiDev-tts; системный Python и данные приложения не трогаются.
# Everything goes to ~/Library/Caches/ColiDev-tts; the system Python and the app data are untouched.
set -euo pipefail
root="${COLIDEV_TTS_DIR:-$HOME/Library/Caches/ColiDev-tts}"
python="${PYTHON:-/opt/homebrew/bin/python3.14}"
mkdir -p "$root/models"
[ -x "$root/venv/bin/python" ] || "$python" -m venv "$root/venv"
"$root/venv/bin/pip" install --disable-pip-version-check torch==2.15.0
for model in ru/v5_6_ru.pt en/v3_en.pt; do
    file="$root/models/$(basename "$model")"
    if [ ! -s "$file" ]; then
        curl -fL --progress-bar -o "$file.part" "https://models.silero.ai/models/tts/$model"
        mv -f "$file.part" "$file"
    fi
done
du -sh "$root/venv" "$root/models"/*
echo "Готово: офлайн-голос Silero включится в приложении сам. / Done: the app picks up the Silero voice by itself."
