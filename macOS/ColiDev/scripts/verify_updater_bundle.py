"""Check updater metadata in the actual built ColiDev.app bundle."""

from __future__ import annotations

import base64
import plistlib
import sys
from pathlib import Path


def fail(message: str) -> None:
    raise SystemExit(f"Updater bundle verification failed: {message}")


def main() -> None:
    if len(sys.argv) != 4:
        fail("usage: verify_updater_bundle.py APP_PATH ARCH BUILD_NUMBER")

    app = Path(sys.argv[1])
    arch = sys.argv[2]
    expected_build = sys.argv[3]
    info_path = app / "Contents" / "Info.plist"
    if not info_path.is_file():
        fail(f"missing Info.plist: {info_path}")

    with info_path.open("rb") as stream:
        info = plistlib.load(stream)

    if info.get("CFBundleShortVersionString") != "0.1.0":
        fail("CFBundleShortVersionString must be 0.1.0")
    if info.get("CFBundleVersion") != expected_build:
        fail("CFBundleVersion does not match the CI build number")

    feed_name = "appcast-arm64.xml" if arch == "arm64" else "appcast-intel.xml"
    expected_feed = (
        "https://raw.githubusercontent.com/weekendbuildings/coli-dev/main/updates/"
        + feed_name
    )
    if info.get("SUFeedURL") != expected_feed:
        fail(f"SUFeedURL must point to the {arch} feed; found {info.get('SUFeedURL')!r}")
    for key in ("SUEnableAutomaticChecks", "SURequireSignedFeed", "SUVerifyUpdateBeforeExtraction"):
        if info.get(key) is not True:
            fail(f"{key} must be enabled")

    public_key = info.get("SUPublicEDKey", "")
    if not isinstance(public_key, str):
        fail("SUPublicEDKey must be a string")
    if public_key:
        try:
            decoded = base64.b64decode(public_key, validate=True)
        except ValueError:
            fail("SUPublicEDKey must be base64-encoded")
        if len(decoded) != 32:
            fail("SUPublicEDKey must decode to 32 bytes")

    print(
        "Updater bundle metadata is valid: "
        f"version={info['CFBundleShortVersionString']} "
        f"build={info['CFBundleVersion']} architecture={arch} "
        f"public_key_configured={bool(public_key)}"
    )


if __name__ == "__main__":
    main()
