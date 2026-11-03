"""The live model lesson: its numbers, program, recording and lab agree. / Урок о живой модели: числа, программа, запись и тренажёр согласованы."""
from __future__ import annotations

import contextlib
import io
import json
import math
import re
import urllib.error
import urllib.request
from pathlib import Path

import pytest


ROOT = Path(__file__).resolve().parents[1]
LESSON = ROOT / "02_Areas" / "Programming" / "lessons" / "live_model_tokens_temperature.md"
RECORDING = json.loads((ROOT / "02_Areas" / "Programming" / "resources" / "live_model_recording.json").read_text(encoding="utf-8"))
APP = ROOT / "macOS" / "ColiDev" / "App"
TEXT = LESSON.read_text(encoding="utf-8")
RUSSIAN = TEXT.split("## Русский", 1)[1].split("## English", 1)[0]
ENGLISH = TEXT.split("## English", 1)[1].split("## Sources", 1)[0]
SOURCES = TEXT.split("## Sources", 1)[1]
LOCAL_OLLAMA = "http://localhost:11434"


def _blocks(section: str, kind: str) -> list[str]:
    return re.findall(rf"```{kind}\n(.*?)```", section, re.S)


class _Reply(io.BytesIO):
    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False


def _run_program(section: str, monkeypatch: pytest.MonkeyPatch, with_experiment: bool = False) -> tuple[str, list[dict]]:
    """Runs the lesson's program against the recorded answers. / Запускает программу урока на записанных ответах."""
    hits = {row["temperature"]: row["hits"] for row in RECORDING["draws"]}
    used = {temperature: 0 for temperature in hits}
    requests: list[dict] = []

    def fake_urlopen(request, timeout=None):
        body = json.loads(request.data.decode())
        requests.append(body)
        assert request.full_url == "http://localhost:11434/api/generate"
        temperature = body["options"]["temperature"]
        answer = dict(RECORDING["lesson_answer"])
        if with_experiment and len(requests) > 1:
            answer["response"] = " Paris" if used[temperature] < hits[temperature] else " other"
            used[temperature] += 1
        return _Reply(json.dumps(answer).encode())

    monkeypatch.setattr(urllib.request, "urlopen", fake_urlopen)
    programs = _blocks(section, "python")
    code = "\n".join(programs) if with_experiment else programs[0]
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        exec(code, {})
    return output.getvalue(), requests


def _printed(section: str, marker: str) -> str:
    return next(block for block in _blocks(section, "text") if marker in block).strip()


def _probability(top: list[dict], token: str) -> float:
    return math.exp(next(item["logprob"] for item in top if item["token"] == token))


def test_program_prints_what_the_lesson_says(monkeypatch: pytest.MonkeyPatch) -> None:
    for section, marker in ((RUSSIAN, "Токенов в запросе"), (ENGLISH, "Tokens in the prompt")):
        output, _ = _run_program(section, monkeypatch)
        assert output.strip() == _printed(section, marker)


def test_experiment_prints_what_the_lesson_says(monkeypatch: pytest.MonkeyPatch) -> None:
    for section, marker in ((RUSSIAN, "из 200"), (ENGLISH, "of 200")):
        output, requests = _run_program(section, monkeypatch, with_experiment=True)
        assert len(requests) == 1 + 5 * 200
        lines = output.strip().split("\n")[-5:]
        assert "\n".join(lines) == _printed(section, marker)
        seeds = [body["options"]["seed"] for body in requests[1:]]
        assert len(set(seeds)) > 950, "Throw numbers must be random, not in order. / Номера бросков случайны, не подряд."
        assert min(seeds) > 1000


def test_program_switches_other_filters_off(monkeypatch: pytest.MonkeyPatch) -> None:
    _, requests = _run_program(ENGLISH, monkeypatch)
    options = requests[0]["options"]
    assert (options["top_k"], options["top_p"], options["min_p"], options["repeat_penalty"]) == (0, 1, 0, 1)
    assert requests[0]["raw"] is True and requests[0]["model"] == "qwen2.5-coder:7b"


def test_worked_example_numbers() -> None:
    def reshape(probabilities, temperature):
        powered = [p ** (1 / temperature) for p in probabilities]
        return [p / sum(powered) for p in powered]

    assert [round(p * 100, 1) for p in reshape([0.6, 0.3, 0.1], 0.5)] == [78.3, 19.6, 2.2]
    assert [round(p * 100, 1) for p in reshape([0.6, 0.3, 0.1], 2)] == [47.3, 33.4, 19.3]
    for number in ("78,3 %", "19,6 %", "2,2 %", "47,3 %", "33,4 %", "19,3 %", "0,775", "0,548", "0,316", "1,639"):
        assert number in RUSSIAN, number
    for number in ("78.3%", "19.6%", "2.2%", "47.3%", "33.4%", "19.3%", "0.775", "0.548", "0.316", "1.639"):
        assert number in ENGLISH, number
    assert round(math.sqrt(0.000001), 3) == 0.001 and round(math.sqrt(0.631), 3) == 0.794


def test_recorded_frequencies_match_the_models_probability() -> None:
    computed = _probability(RECORDING["top20"], " Paris")
    assert round(computed * 100, 1) == 63.1 and "63,1 %" in RUSSIAN and "63.1%" in ENGLISH
    for row in RECORDING["large"]:
        if row["temperature"] == 1:
            deviation = math.sqrt(computed * (1 - computed) / row["n"])
            assert abs(row["hits"] / row["n"] - computed) < 3 * deviation
    assert sum(math.exp(item["logprob"]) for item in RECORDING["top20"]) < 1


def test_long_tail_numbers_in_the_text() -> None:
    hot = next(row for row in RECORDING["large"] if row["temperature"] == 2)
    assert (hot["n"], hot["distinct"], hot["outside_top20"]) == (1000, 871, 887)
    assert hot["hits"] == 32 and hot["most_common"][0][0] == " Paris" and hot["most_common"][1][1] == 11
    warm = next(row for row in RECORDING["large"] if row["temperature"] == 1)
    assert warm["hits"] == 636 and "636" in RUSSIAN and "636" in ENGLISH
    assert RECORDING["vocabulary"] == 152064 and "152 064" in RUSSIAN and "152,064" in ENGLISH
    assert "88,7 %" in RUSSIAN and "88.7%" in ENGLISH and "871" in RUSSIAN and "871" in ENGLISH
    assert round(RECORDING["parameters"] / 1e9, 1) == 7.6 and "7,6 миллиарда" in RUSSIAN and "7.6 billion" in ENGLISH


def test_formula_predicts_the_ratio_of_two_tokens() -> None:
    check = RECORDING["ratio_check"]
    assert round(check["paris"] / check["blank"], 1) == 6.3
    predicted = (_probability(RECORDING["top20"], " Paris") / _probability(RECORDING["top20"], " __")) ** (1 / check["temperature"])
    assert round(predicted, 1) == 5.6
    # The predicted ratio lies inside the noise of the small count. / Предсказание лежит в пределах шума малого числа.
    spread = math.sqrt(check["blank"])
    assert check["paris"] / (check["blank"] + 2 * spread) < predicted < check["paris"] / (check["blank"] - 2 * spread)
    for section in (RUSSIAN, ENGLISH):
        assert "241" in section and "38" in section


def test_token_counts_in_the_text() -> None:
    for token_text, count in RECORDING["token_counts"].items():
        if token_text == "12345678":
            continue
        ru = {1: f"`{token_text}`: 1 токен"}.get(count, f"`{token_text}`: {count}")
        en = {1: f"`{token_text}`: 1 token"}.get(count, f"`{token_text}`: {count}")
        assert ru in RUSSIAN, ru
        assert en in ENGLISH, en
    assert RECORDING["paris_tokens"] == [" П", "ари", "ж"]
    assert round(math.exp(RECORDING["russian_top"][0]["logprob"]) * 100, 1) == 96.4 and "96,4 %" in RUSSIAN and "96.4%" in ENGLISH
    assert round(math.exp(RECORDING["cat_top"][0]["logprob"]) * 100, 1) == 31.1 and "31,1 %" in RUSSIAN and "31.1%" in ENGLISH


def test_samples_in_the_text_are_real() -> None:
    samples = RECORDING["samples"]
    assert samples["0"] == " Paris. Paris is located in the northern part of France, on the"
    assert "A. Berlin" in samples["0.7"] and "B. Madrid" in samples["0.7"] and "C. Paris" in samples["0.7"]
    assert samples["1"].startswith(" [city name]")
    for section in (RUSSIAN, ENGLISH):
        assert samples["0"] in section and samples["2"] in section
    assert "Париж." in RECORDING["raw_vs_chat"]["chat"] and RECORDING["raw_vs_chat"]["raw"].startswith(" Париж. Париж является")


def test_quiz_is_fair() -> None:
    for section, options, answer in ((RUSSIAN, "### Варианты", "### Ответ"), (ENGLISH, "### Options", "### Answer")):
        block = section.split(options, 1)[1].split("###", 1)[0]
        lines = [line[2:] for line in block.strip().split("\n") if line.startswith("- ")]
        assert len(lines) == 3 and section.split(answer, 1)[1].split("###", 1)[0].strip() == "1"
        assert max(map(len, lines)) < 1.25 * min(map(len, lines))


def test_code_does_not_break_the_lesson_parser() -> None:
    for section in (RUSSIAN, ENGLISH):
        for code in _blocks(section, "python") + _blocks(section, "bash") + _blocks(section, "text"):
            assert "## " not in code and "```" not in code
    assert "{{" not in TEXT and "PLACEHOLDER" not in TEXT and "HINTON_NOTE" not in TEXT


def test_lab_uses_the_recording_and_is_wired_in() -> None:
    views = (APP / "LearningViews.swift").read_text(encoding="utf-8")
    strings = (APP / "L10n.swift").read_text(encoding="utf-8")
    model = (APP / "LiveModelLabModel.swift").read_text(encoding="utf-8")
    assert 'moduleResource == "live_model_tokens_temperature"' in views and "LiveModelLab()" in views
    lab = views.split("private struct LiveModelLab: View {", 1)[1]
    assert "LabChallenge(" in lab and "LabExplainer(" in lab
    keys = set(re.findall(r'text\("(lab\.liveModel\.[A-Za-z0-9]+)"\)', lab))
    assert len(keys) > 20
    for key in keys:
        assert len(re.findall(rf'"{re.escape(key)}": \("[^"]+", "[^"]+"\)', strings)) == 1, key
    assert "static let vocabulary = 152064" in model
    for row in RECORDING["draws"]:
        temperature = float(row["temperature"])
        assert f"Draw(temperature: {temperature}, counts: [" in model
    for step in RECORDING["greedy_path"]:
        assert json.dumps(step["prefix"], ensure_ascii=False) in model
    assert "lesson:live_model_tokens_temperature" in (ROOT / "02_Areas" / "Programming" / "curriculum.md").read_text(encoding="utf-8")
    workflow = (ROOT / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    assert "verify_live_model.swift" in workflow
    for link in ("docs.ollama.com/api/generate", "docs.ollama.com/modelfile", "2409.12186", "1904.09751", "1503.02531", "EWvNQjAaOHw", "7xTGNNLPyMI", "zero-to-hero", "cs336.stanford.edu"):
        assert link in SOURCES, link


def _ollama_has_the_model() -> bool:
    try:
        with urllib.request.urlopen(f"{LOCAL_OLLAMA}/api/tags", timeout=2) as response:
            return any(model["name"] == RECORDING["model"] for model in json.load(response)["models"])
    except (urllib.error.URLError, OSError, ValueError):
        return False


@pytest.mark.skipif(not _ollama_has_the_model(), reason="needs local Ollama and the model / нужна локальная Ollama с моделью")
def test_real_model_still_gives_the_recorded_numbers() -> None:
    namespace: dict = {}
    program = _blocks(ENGLISH, "python")[0]
    with contextlib.redirect_stdout(io.StringIO()):
        exec(program, namespace)
    answer = namespace["ask"]("The capital of France is", temperature=0)
    assert answer["prompt_eval_count"] == RECORDING["prompt_tokens"]
    assert answer["response"] == " Paris"
    assert abs(math.exp(answer["logprobs"][0]["top_logprobs"][0]["logprob"]) - _probability(RECORDING["top20"], " Paris")) < 0.02
