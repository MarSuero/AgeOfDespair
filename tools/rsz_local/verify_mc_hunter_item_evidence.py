"""Verify the static evidence boundary for app.mcHunterItem.

This is intentionally a read-only check. It prevents a future implementation
from treating the RSZ type dump as if it contained native method signatures.
"""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DUMP = ROOT / "tools" / "rsz_local" / "resources" / "data" / "dumps" / "rszmhwilds.json"


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

    print("mcHunterItem evidence boundary: PASS")
    print("type entry has no fields/method signatures; native bridge remains blocked")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
