"""Verify the static evidence boundary for app.mcHunterItem.

This is intentionally a read-only check. It prevents a future implementation
from treating the RSZ type dump as if it contained native method signatures.
"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DUMP = ROOT / "tools" / "rsz_local" / "resources" / "data" / "dumps" / "rszmhwilds.json"
BRIDGE = ROOT / "native_bridge" / "Item98Bridge.cpp"
CMAKE = ROOT / "native_bridge" / "CMakeLists.txt"
BUILD = ROOT / "native_bridge" / "build.ps1"
MINGW_BUILD = ROOT / "native_bridge" / "build-llvm-mingw.ps1"
BEHAVIOR = ROOT / "native_bridge" / "Item98NotUseBridge.cpp"
BEHAVIOR_BUILD = ROOT / "native_bridge" / "build-llvm-mingw-behavior.ps1"
SDK_API = ROOT / "tools" / "REFramework-sdk" / "include" / "reframework" / "API.hpp"


def main() -> int:
    data = json.loads(DUMP.read_text(encoding="utf-8"))
    matches = [entry for entry in data.values() if entry.get("name") == "app.mcHunterItem"]
    assert len(matches) == 1, f"expected one app.mcHunterItem entry, found {len(matches)}"

    entry = matches[0]
    assert entry.get("fields") == [], "RSZ dump unexpectedly gained field metadata"
    assert "methods" not in entry and "method" not in entry

    serialized = DUMP.read_text(encoding="utf-8")
    for name in (
        "_ItemRequestMsg",
        "_DisabledItemID",
        "_DisabledItemIDLock",
        "canUseItem",
        "addDisabledItem",
    ):
        assert name not in serialized, f"{name} unexpectedly appears in RSZ metadata"

    bridge = BRIDGE.read_text(encoding="utf-8")
    cmake = CMAKE.read_text(encoding="utf-8")
    build = BUILD.read_text(encoding="utf-8")
    mingw_build = MINGW_BUILD.read_text(encoding="utf-8")
    behavior = BEHAVIOR.read_text(encoding="utf-8")
    behavior_build = BEHAVIOR_BUILD.read_text(encoding="utf-8")
    assert SDK_API.exists(), "official REFramework SDK checkout is missing"
    assert "add_library(mhws_eatshit_native_bridge SHARED Item98Bridge.cpp)" in cmake
    assert "REFramework-sdk" in cmake
    assert "mhws_eatshit_native_bridge" in build
    assert "CMake was not found on PATH" in build
    assert "x86_64-w64-mingw32-clang++.exe" in mingw_build
    assert "-static-libstdc++" in mingw_build
    assert "notUseItem" in behavior
    assert "REFRAMEWORK_HOOK_SKIP_ORIGINAL" in behavior
    assert "item_id != 98" in behavior
    assert "_DisabledItemID" not in behavior
    assert "_ItemRequestMsg" not in behavior
    assert "build-llvm-mingw-behavior.ps1" in behavior_build or "Item98NotUseBridge.cpp" in behavior_build
    assert "reframework_plugin_initialize" in bridge
    assert "app.mcHunterItem" in bridge
    assert "get_function_raw" in bridge
    assert "add_hook" not in bridge
    assert "set_field" not in bridge

    print("mcHunterItem evidence boundary: PASS")
    print("type entry has no fields/method signatures; read-only SDK bridge is unarmed")
    print("official SDK checkout and CMake layout: PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
