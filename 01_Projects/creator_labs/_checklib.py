"""Общие помощники проверок «Собери и проверь сам» / Shared helpers for the "build and check it yourself" labs.

Проверка загружает твой файл, гоняет его на заданных и случайных входах и сверяет с численной
производной, граничными случаями и свойствами, которые должны выполняться всегда.
A check loads your file, runs it on fixed and random inputs, and compares it with numerical
derivatives, edge cases and invariants that must always hold.

Работает в обычном python3 этого Mac (3.9 и новее), без пакетов. / Runs on plain python3 3.9+.
"""

import importlib.util
import json
import math
import os
import sys
import time
import traceback
from pathlib import Path

# Итог каждой проверки дописывается сюда, его показывает экран «Прогресс Творца».
# Every check appends its result here; the Creator progress screen shows it.
RESULTS_NAME = ".results.json"
RESULTS_ENV = "CREATOR_LABS_RESULTS"  # другой путь для тестов / another path for tests
RESULTS_LIMIT = 1000  # старые записи отбрасываются / older runs are dropped


def results_path():
    override = os.environ.get(RESULTS_ENV)
    return Path(override).expanduser() if override else Path(__file__).resolve().with_name(RESULTS_NAME)


def record_result(check, passed, total, path=None, now=None):
    """Дописывает итог в файл результатов. Ошибка записи не ломает проверку.
    Appends the result to the results file. A write error never breaks the check."""
    path = Path(path) if path else results_path()
    stamp = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(now if now is not None else time.time()))
    lesson = check[len("check_"):-len(".py")] if check.startswith("check_") and check.endswith(".py") else ""
    run = {"check": check, "lesson": lesson, "passed": passed, "total": total, "at": stamp}
    try:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
            runs = data.get("runs") if isinstance(data, dict) else None
            runs = [r for r in runs if isinstance(r, dict)] if isinstance(runs, list) else []
        except (OSError, ValueError):
            runs = []
        runs = (runs + [run])[-RESULTS_LIMIT:]
        text = json.dumps({"format": "creator-labs-results", "version": 1, "runs": runs}, ensure_ascii=False, indent=1)
        temporary = path.with_name(path.name + ".tmp")
        temporary.write_text(text + "\n", encoding="utf-8")
        os.replace(str(temporary), str(path))
    except OSError as exc:
        print(f"(Итог не записан / Result not saved: {exc})")
    return run


class Checker:
    def __init__(self, title_ru, title_en):
        self.passed = 0
        self.failed = 0
        print(f"{title_ru} / {title_en}")

    def load(self, default_name):
        """Твой файл: первый аргумент или заготовка рядом. / Your file: first argument or the blank next to this script."""
        path = Path(sys.argv[1]).expanduser() if len(sys.argv) > 1 else Path(__file__).with_name(default_name)
        print(f"Файл / File: {path}\n")
        spec = importlib.util.spec_from_file_location(f"learner_{path.stem}", path)
        if spec is None or spec.loader is None:
            print("✗ Файл не найден / File not found")
            sys.exit(1)
        module = importlib.util.module_from_spec(spec)
        try:
            spec.loader.exec_module(module)
        except Exception:
            print("✗ Файл не запускается, ошибка ниже / The file does not run, error below\n")
            traceback.print_exc(limit=3)
            sys.exit(1)
        return module

    def check(self, ru, en, test):
        """test() возвращает None при успехе или строку с подробностью. / test() returns None or a detail string."""
        try:
            detail = test()
        except NotImplementedError as exc:
            detail = f"не реализовано / not implemented: {exc}"
        except Exception as exc:  # noqa: BLE001 - any learner error is a failed check
            detail = f"{type(exc).__name__}: {exc}"
        if detail is None:
            self.passed += 1
            print(f"  ✓ {ru} / {en}")
        else:
            self.failed += 1
            print(f"  ✗ {ru} / {en}\n      {detail}")

    def finish(self):
        total = self.passed + self.failed
        record_result(Path(sys.argv[0]).name, self.passed, total)
        if self.failed:
            print(f"\nПройдено {self.passed} из {total}. Исправь первую ✗ и запусти снова.")
            print(f"Passed {self.passed} of {total}. Fix the first ✗ and run again.")
            sys.exit(1)
        print(f"\nВсе {total} проверок пройдены. / All {total} checks passed.")
        sys.exit(0)


class Rand:
    """Тот же простой генератор, что в уроках: одинаковый результат на любом Mac. / The lessons' generator."""

    def __init__(self, seed):
        self.state = seed * 2654435761 % 2**32 or 1

    def next(self):
        self.state = (1103515245 * self.state + 12345) % 2**31
        return self.state / 2**31

    def uniform(self, low, high):
        return low + (high - low) * self.next()

    def below(self, limit):
        return int(self.next() * limit) % limit


def close(a, b, tolerance=1e-6):
    return abs(a - b) <= tolerance * max(1.0, abs(a), abs(b))


def all_close(xs, ys, tolerance=1e-6):
    xs, ys = list(xs), list(ys)
    return len(xs) == len(ys) and all(close(x, y, tolerance) for x, y in zip(xs, ys))


def numeric_gradient(function, point, step=1e-6):
    """Центральная разность по каждой координате. / Central difference along each coordinate."""
    gradient = []
    for i in range(len(point)):
        up, down = list(point), list(point)
        up[i] += step
        down[i] -= step
        gradient.append((function(up) - function(down)) / (2 * step))
    return gradient


def show(values, digits=4):
    return "[" + ", ".join(f"{v:.{digits}f}" for v in values) + "]"


def is_finite(values):
    return all(isinstance(v, (int, float)) and math.isfinite(v) for v in values)
