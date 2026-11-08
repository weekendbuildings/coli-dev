#!/usr/bin/env bash
# Полная сборка ColiDev на этом Mac, без ожидания GitHub Actions.
# Full ColiDev build on this Mac, without waiting for GitHub Actions.
#
# Что делает / What it does:
#   1. Собирает приложение через xcodebuild (как CI, только arm64).
#      Builds the app with xcodebuild (like CI, arm64 only).
#   2. Встраивает ColiDevBackend. Готовый backend берётся из кэша, если файлы,
#      из которых он собирается (01_Projects без тестов и requirements-*.txt), не менялись.
#      Embeds ColiDevBackend. A cached backend is reused while its inputs
#      (01_Projects without tests, requirements-*.txt) are unchanged.
#   3. Проверяет архитектуру, метаданные обновлений и backend (smoke_test_backend_runtime.sh).
#      Verifies architectures, updater metadata and the backend smoke test.
#   4. Делает копию /Applications/ColiDev.app и данных, ставит новую версию,
#      снова проверяет backend и при ошибке возвращает копию.
#      Backs up /Applications/ColiDev.app and the data, installs the new build,
#      re-runs the backend smoke test and restores the backup on failure.
#
# Использование / Usage:
#   build_local_full_app.sh [--no-install] [--no-open] [--rebuild-backend]
#                           [--seed-backend-from APP [--seed-commit SHA]]
#
#   --seed-backend-from APP  Положить в кэш backend из готового приложения (например,
#                            установленной сборки CI). Принимается, только если файлы backend
#                            в коммите сборки совпадают с текущими. Коммит берётся из
#                            --seed-commit или по номеру сборки CI через gh.
#                            Seed the cache from an existing app (e.g. the installed CI build).
#                            Accepted only when the backend inputs at that build's commit match
#                            the current ones; the commit comes from --seed-commit or from the
#                            CI build number via gh.
#   --rebuild-backend        Собрать backend заново через PyInstaller (нужен в venv).
#                            Rebuild the backend with PyInstaller (must be in the venv).
#   --no-install             Только собрать и проверить. / Build and verify only.
#   --no-open                Не открывать приложение после установки. / Do not open the app.
#
# Переменные / Environment:
#   COLIDEV_PYTHON              Python с зависимостями backend (по умолчанию ищется .venv).
#   COLIDEV_LOCAL_BUILD_CACHE   Кэш сборки (~/Library/Caches/ColiDev-local-build).
#   COLIDEV_BACKUP_DIR          Папка копий (~/ColiDev-backups), хранятся 3 последние.
#   COLIDEV_INSTALL_PATH        Куда ставить (/Applications/ColiDev.app).
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd -- "$script_dir/../../.." && pwd)"
cache_root="${COLIDEV_LOCAL_BUILD_CACHE:-$HOME/Library/Caches/ColiDev-local-build}"
backup_root="${COLIDEV_BACKUP_DIR:-$HOME/ColiDev-backups}"
install_path="${COLIDEV_INSTALL_PATH:-/Applications/ColiDev.app}"
data_dir="$HOME/Library/Application Support/coli-dev"
bundle_id="com.colidev.learningstudio"
feed_url="https://raw.githubusercontent.com/weekendbuildings/coli-dev/main/updates/appcast-arm64.xml"
backend_paths=(01_Projects requirements-orchestrator.txt requirements-macos-runtime.txt)

do_install=1
do_open=1
rebuild_backend=0
seed_app=""
seed_commit=""

say() { printf '\n==> %s\n' "$*"; }
die() { printf '\nОшибка / Error: %s\n' "$*" >&2; exit 1; }

while (( $# > 0 )); do
    case "$1" in
        --no-install) do_install=0 ;;
        --no-open) do_open=0 ;;
        --rebuild-backend) rebuild_backend=1 ;;
        --seed-backend-from) seed_app="${2:?--seed-backend-from needs an app path}"; shift ;;
        --seed-commit) seed_commit="${2:?--seed-commit needs a commit}"; shift ;;
        -h|--help) sed -n '2,40p' "$0"; exit 0 ;;
        *) die "неизвестный параметр / unknown option: $1" ;;
    esac
    shift
done

[[ "$(uname -m)" == "arm64" ]] || die "сборка только для Apple Silicon / Apple Silicon only"
command -v xcodebuild >/dev/null || die "нет xcodebuild / xcodebuild not found"
git -C "$project_root" rev-parse --git-dir >/dev/null 2>&1 || die "не git-репозиторий / not a git checkout: $project_root"

find_python() {
    if [[ -n "${COLIDEV_PYTHON:-}" ]]; then printf '%s\n' "$COLIDEV_PYTHON"; return; fi
    local common candidate
    common="$(cd "$project_root" && cd "$(git rev-parse --git-common-dir)" && pwd)"
    for candidate in "$project_root/.venv/bin/python" "$common/../.venv/bin/python" "$common/../../.venv/bin/python"; do
        if [[ -x "$candidate" ]]; then printf '%s\n' "$candidate"; return; fi
    done
    printf '%s\n' python3
}
python_bin="$(find_python)"

# Файлы, из которых PyInstaller собирает backend. Тесты, creator_labs и программа урока
# tiny_language_model.py (её не импортирует ни один модуль backend) в него не входят.
# Files PyInstaller builds the backend from. Tests, creator_labs and the lesson program
# tiny_language_model.py (no backend module imports it) are not part of it.
keep_backend_input() {
    grep -Ev '(^|/)test_[^/]*\.py$|(^|/)conftest\.py$|^01_Projects/creator_labs/|^01_Projects/tiny_language_model\.py$|(^|/)__pycache__/|\.pyc$|(^|/)\.pytest_cache/' || true
}

# Отпечаток рабочей папки / Fingerprint of the working tree.
worktree_fingerprint() {
    (
        cd "$project_root"
        git ls-files -co --exclude-standard -- "${backend_paths[@]}" | keep_backend_input | LC_ALL=C sort -u |
            while IFS= read -r path; do
                [[ -f "$path" ]] || continue
                printf '%s %s\n' "$(shasum -a 256 < "$path" | cut -d' ' -f1)" "$path"
            done
    ) | shasum -a 256 | cut -c1-16
}

# Отпечаток тех же файлов в коммите / Fingerprint of the same files in a commit.
commit_fingerprint() {
    local commit="$1"
    (
        cd "$project_root"
        git ls-tree -r --name-only "$commit" -- "${backend_paths[@]}" | keep_backend_input | LC_ALL=C sort -u |
            while IFS= read -r path; do
                printf '%s %s\n' "$(git cat-file blob "$commit:$path" | shasum -a 256 | cut -d' ' -f1)" "$path"
            done
    ) | shasum -a 256 | cut -c1-16
}

plist_value() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist" 2>/dev/null || true; }

# Номер сборки CI = дата + номер запуска / CI build number = date + run number.
commit_for_ci_build() {
    local version="$1" run_number
    [[ "$version" =~ ^[0-9]{9,}$ ]] || return 1
    run_number="$((10#${version:8}))"
    command -v gh >/dev/null || return 1
    (cd "$project_root" && gh run list --workflow ci.yml --limit 300 --json number,headSha \
        --jq ".[] | select(.number == $run_number) | .headSha" 2>/dev/null | head -1)
}

check_arm64() {
    local binary="$1" archs
    archs="$(lipo -archs "$binary")"
    [[ "$archs" == "arm64" ]] || die "ожидалась arm64, найдено / expected arm64, got '$archs': $binary"
}

current_fingerprint="$(worktree_fingerprint)"
backend_cache="$cache_root/backend/$current_fingerprint/ColiDevBackend"
say "Отпечаток backend / Backend fingerprint: $current_fingerprint"

if [[ -n "$seed_app" ]]; then
    seed_backend="$seed_app/Contents/Resources/ColiDevBackend"
    [[ -x "$seed_backend/ColiDevBackend" ]] || die "в приложении нет backend / no backend in: $seed_app"
    if [[ -z "$seed_commit" ]]; then
        seed_version="$(plist_value "$seed_app" CFBundleVersion)"
        seed_commit="$(commit_for_ci_build "$seed_version" || true)"
        [[ -n "$seed_commit" ]] || die "не нашёл коммит сборки $seed_version, укажи --seed-commit / build commit not found, pass --seed-commit"
        say "Сборка $seed_version собрана CI из / was built by CI from $seed_commit"
    fi
    seed_fingerprint="$(commit_fingerprint "$seed_commit")"
    if [[ "$seed_fingerprint" != "$current_fingerprint" ]]; then
        die "backend в $seed_app собран из других файлов ($seed_fingerprint), текущие: $current_fingerprint / backend inputs differ"
    fi
    check_arm64 "$seed_backend/ColiDevBackend"
    rm -rf "$backend_cache"
    mkdir -p "$(dirname "$backend_cache")"
    ditto "$seed_backend" "$backend_cache"
    say "Backend взят из / seeded from $seed_app"
fi

if [[ "$rebuild_backend" == 1 || ! -x "$backend_cache/ColiDevBackend" ]]; then
    if ! "$python_bin" -c 'import PyInstaller' >/dev/null 2>&1; then
        cat >&2 <<EOF

Файлы backend изменились, а готового backend для них нет. Нужен PyInstaller в venv.
Его ставит владелец (одна команда, пакеты из requirements-macos-runtime.txt):
The backend inputs changed and no cached backend matches. PyInstaller is needed in the venv:

  "$python_bin" -m pip install -r "$project_root/requirements-macos-runtime.txt"

Или возьми backend из сборки CI с теми же файлами / Or seed from a CI build with the same inputs:
  $0 --seed-backend-from /path/to/ColiDev.app
EOF
        exit 3
    fi
    say "Собираю backend через PyInstaller / Building the backend with PyInstaller"
    scratch="$(mktemp -d "${TMPDIR:-/tmp}/colidev-backend-local.XXXXXX")"
    mkdir -p "$scratch/Backend.app/Contents/Resources"
    PATH="$(dirname "$python_bin"):$PATH" "$script_dir/package_backend_runtime.sh" "$scratch/Backend.app"
    rm -rf "$backend_cache"
    mkdir -p "$(dirname "$backend_cache")"
    ditto "$scratch/Backend.app/Contents/Resources/ColiDevBackend" "$backend_cache"
    rm -rf "$scratch"
else
    say "Backend не менялся, беру из кэша / Backend unchanged, reusing the cache"
fi
check_arm64 "$backend_cache/ColiDevBackend"

# Ключ проверки обновлений публичный, как в CI (vars.SPARKLE_PUBLIC_ED_KEY); значение не печатаем.
# Пустой ключ допустим: так сейчас собирает и CI, verify_updater_bundle.py это разрешает.
# The update verification key is public, as in CI; never printed. Empty is allowed, as in CI today.
public_key="${SPARKLE_PUBLIC_ED_KEY:-}"
if [[ -z "$public_key" && -d "$install_path" ]]; then public_key="$(plist_value "$install_path" SUPublicEDKey)"; fi
if [[ -z "$public_key" ]] && command -v gh >/dev/null; then
    public_key="$(cd "$project_root" && gh variable get SPARKLE_PUBLIC_ED_KEY 2>/dev/null || true)"
fi

# Номер ниже сборок CI того же дня и выше прошлых: обновления из CI будут предлагаться дальше.
# Lower than CI builds of the same day and higher than earlier ones, so CI updates still apply.
build_version="$(date -u +%Y%m%d)000"
derived="$cache_root/DerivedData-full-app"
say "Собираю приложение / Building the app (сборка / build $build_version)"
xcodebuild \
    -project "$project_root/macOS/ColiDev/ColiDev.xcodeproj" \
    -scheme ColiDev \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$derived" \
    ARCHS=arm64 \
    CURRENT_PROJECT_VERSION="$build_version" \
    SUFeedURL="$feed_url" \
    SUPublicEDKey="$public_key" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet \
    build
built_app="$derived/Build/Products/Debug/ColiDev.app"
[[ -d "$built_app" ]] || die "xcodebuild не создал приложение / no app produced"

staging_root="$cache_root/staging"
staging="$staging_root/ColiDev.app"
rm -rf "$staging_root"
mkdir -p "$staging_root"
ditto "$built_app" "$staging"
# Xcode не кладёт backend в приложение. Если он там есть, это остаток чужой сборки в той же
# папке DerivedData: убираем его только из нашей копии и ставим backend из кэша.
# Xcode never puts a backend in the app; one found here is left over from another build in the
# same DerivedData. Remove it from our copy only and use the cached backend.
if [[ -e "$staging/Contents/Resources/ColiDevBackend" ]]; then
    echo "В продукте Xcode найден старый backend, заменяю / Replacing a stale backend from the Xcode product"
    rm -rf "$staging/Contents/Resources/ColiDevBackend"
fi
ditto "$backend_cache" "$staging/Contents/Resources/ColiDevBackend"

say "Проверяю сборку / Verifying the build"
check_arm64 "$staging/Contents/MacOS/ColiDev"
check_arm64 "$staging/Contents/Resources/ColiDevBackend/ColiDevBackend"
"$python_bin" "$script_dir/verify_updater_bundle.py" "$staging" arm64 "$build_version"
codesign --force --deep --sign - "$staging"
COLIDEV_SMOKE_DENY_KEYCHAIN=1 "$script_dir/smoke_test_backend_runtime.sh" "$staging"

if [[ "$do_install" == 0 ]]; then
    say "Готово без установки / Done without installing: $staging"
    exit 0
fi

app_running() { pgrep -f "$install_path/Contents/MacOS/ColiDev" >/dev/null 2>&1; }
if app_running; then
    say "Закрываю ColiDev / Quitting ColiDev"
    osascript -e "tell application id \"$bundle_id\" to quit" >/dev/null 2>&1 || true
    for _ in $(seq 1 30); do app_running || break; sleep 1; done
    app_running && die "ColiDev не закрылся, закрой его сам и запусти скрипт снова / quit ColiDev and rerun"
fi
for _ in $(seq 1 10); do pgrep -f "$install_path/Contents/Resources/ColiDevBackend" >/dev/null 2>&1 || break; sleep 1; done

stamp="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup_root"
app_backup=""
if [[ -d "$install_path" ]]; then
    old_version="$(plist_value "$install_path" CFBundleVersion)"
    app_backup="$backup_root/ColiDev-app-$stamp-${old_version:-unknown}.app"
    say "Копия приложения / App backup: $app_backup"
    ditto "$install_path" "$app_backup"
fi
if [[ -d "$data_dir" ]]; then
    say "Копия данных (оригинал не меняется) / Data backup (original untouched): $backup_root/coli-dev-data-$stamp"
    ditto "$data_dir" "$backup_root/coli-dev-data-$stamp"
fi
# Храним три последние копии каждого вида / Keep the three newest backups of each kind.
prune_backups() {
    local pattern="$1"
    ls -1d "$backup_root"/$pattern 2>/dev/null | LC_ALL=C sort -r | tail -n +4 | while IFS= read -r old; do rm -rf "$old"; done
}
prune_backups 'ColiDev-app-*.app'
prune_backups 'coli-dev-data-*'

restore_backup() {
    if [[ -n "$app_backup" && -d "$app_backup" ]]; then
        echo "Возвращаю прежнюю версию / Restoring the previous app" >&2
        rm -rf "$install_path"
        ditto "$app_backup" "$install_path"
    fi
}

say "Ставлю / Installing $install_path"
rm -rf "$install_path"
if ! ditto "$staging" "$install_path"; then restore_backup; die "копирование не удалось / copy failed"; fi
if ! COLIDEV_SMOKE_DENY_KEYCHAIN=1 "$script_dir/smoke_test_backend_runtime.sh" "$install_path"; then
    restore_backup
    die "backend установленной версии не прошёл проверку / installed backend failed the smoke test"
fi

say "Установлено / Installed: $(plist_value "$install_path" CFBundleShortVersionString) ($(plist_value "$install_path" CFBundleVersion)), backend $current_fingerprint"
if [[ "$do_open" == 1 ]]; then open "$install_path"; fi
