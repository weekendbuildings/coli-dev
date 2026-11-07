"""Проверки скрипта быстрой локальной сборки / Checks for the fast local build script.

Скрипт ставит приложение в /Applications, поэтому здесь проверяется его безопасный порядок:
копия до удаления, проверка backend до и после установки, возврат копии при ошибке, и что
тесты не меняют отпечаток backend. Сама сборка здесь не запускается.
The script installs into /Applications, so these tests check its safe order: backup before
removal, backend smoke test before and after installing, restore on failure, and that tests
do not change the backend fingerprint. The build itself is not run here.
"""

from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parents[1] / "macOS" / "ColiDev" / "scripts" / "build_local_full_app.sh"


def script_text() -> str:
    return SCRIPT.read_text(encoding="utf-8")


def test_script_is_valid_bash_and_executable() -> None:
    assert SCRIPT.exists()
    assert SCRIPT.stat().st_mode & 0o111, "script must be executable"
    bash = shutil.which("bash")
    if bash is None:
        pytest.skip("bash is not available")
    result = subprocess.run([bash, "-n", str(SCRIPT)], capture_output=True, text=True)
    assert result.returncode == 0, result.stderr


def test_backup_happens_before_the_installed_app_is_removed() -> None:
    text = script_text()
    backup = text.index('ditto "$install_path" "$app_backup"')
    removal = text.index('rm -rf "$install_path"\nif ! ditto "$staging" "$install_path"')
    assert backup < removal


def test_backend_is_smoke_tested_before_and_after_install_with_restore() -> None:
    text = script_text()
    before = text.index('COLIDEV_SMOKE_DENY_KEYCHAIN=1 "$script_dir/smoke_test_backend_runtime.sh" "$staging"')
    install = text.index('if ! ditto "$staging" "$install_path"')
    after = text.index('if ! COLIDEV_SMOKE_DENY_KEYCHAIN=1 "$script_dir/smoke_test_backend_runtime.sh" "$install_path"; then\n    restore_backup')
    assert before < install < after


def test_data_directory_is_only_copied() -> None:
    text = script_text()
    data_lines = [line for line in text.splitlines() if "$data_dir" in line and not line.lstrip().startswith("#")]
    assert data_lines, "the data backup must exist"
    for line in data_lines:
        assert "rm " not in line and "mv " not in line, line


def test_tests_and_creator_labs_do_not_change_the_backend_fingerprint() -> None:
    text = script_text()
    pattern = re.search(r"grep -Ev '([^']+)'", text)
    assert pattern, "backend input filter not found"
    excluded = re.compile(pattern.group(1))
    for path in (
        "01_Projects/test_ai_path.py",
        "01_Projects/conftest.py",
        "01_Projects/creator_labs/attention_blank.py",
        "01_Projects/__pycache__/orchestrator.cpython-312.pyc",
    ):
        assert excluded.search(path), path
    for path in ("01_Projects/orchestrator.py", "01_Projects/ui.html", "requirements-macos-runtime.txt", "01_Projects/fastapi_app/routes.py"):
        assert not excluded.search(path), path


def test_build_is_arm64_only_and_keeps_the_ci_update_feed() -> None:
    text = script_text()
    assert "ARCHS=arm64" in text
    assert "updates/appcast-arm64.xml" in text
    assert 'verify_updater_bundle.py" "$staging" arm64 "$build_version"' in text


def test_smoke_test_can_run_without_the_real_keychain_and_ci_is_unchanged() -> None:
    smoke = (SCRIPT.parent / "smoke_test_backend_runtime.sh").read_text(encoding="utf-8")
    assert '"${COLIDEV_SMOKE_DENY_KEYCHAIN:-0}" == "1"' in smoke
    assert '(deny mach-lookup (global-name "com.apple.SecurityServer")' in smoke
    assert '${launcher[@]+"${launcher[@]}"} "$executable"' in smoke
    ci = (SCRIPT.parents[3] / ".github" / "workflows" / "ci.yml").read_text(encoding="utf-8")
    assert "COLIDEV_SMOKE_DENY_KEYCHAIN" not in ci
