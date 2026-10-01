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
    assert "reframework_plugin_initialize" in bridge
    assert "app.mcHunterItem" in bridge
    assert "get_function_raw" in bridge
    assert "add_hook" not in bridge
    assert "set_field" not in bridge

    print("mcHunterItem evidence boundary: PASS")
    print("type entry has no fields/method signatures; read-only SDK bridge is unarmed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
