"""Read-only dump of the auto-use item parameter files.

Purpose: the project needs to know whether the "auto use" tables reference item
98 or carry any use-pipeline field that the failed ItemData candidates lacked.

Usage:
  python dump_autouse.py <rszmhwilds.json> <file.user.3> [...]
"""
from __future__ import annotations

import sys
from pathlib import Path

from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry


def val(x):
    if x is None:
        return None
    if hasattr(x, "value"):
        return x.value
    if hasattr(x, "values"):
        return [val(v) for v in x.values]
    return str(x)


def main(argv: list[str]) -> int:
    if len(argv) < 3:
        print(__doc__)
        return 2

    registry_path = argv[1]
    reg = TypeRegistry(registry_path)

    for path in argv[2:]:
        print("=" * 70)
        print(Path(path).name)
        try:
            data = Path(path).read_bytes()
            r = RszFile()
            r.filepath = path
            r.type_registry = reg
            r.game_version = "MHWilds"
            r.read(data, skip_data=False)
        except Exception as exc:  # noqa: BLE001 - diagnostic tool
            print("  PARSE FAILED:", type(exc).__name__, exc)
            continue

        elems = getattr(r, "parsed_elements", None) or {}
        print("  parsed elements:", len(elems))

        shown = 0
        type_names: dict[str, int] = {}
        for idx, obj in elems.items():
            if not isinstance(obj, dict):
                continue
            tn = str(obj.get("__type", "") or obj.get("_Type", ""))
            if tn:
                type_names[tn] = type_names.get(tn, 0) + 1

            item_id = val(obj.get("_ItemId"))
            if item_id is None:
                item_id = val(obj.get("ItemId"))
            if item_id is None:
                continue

            fields = {
                k: val(v) for k, v in obj.items()
                if not k.startswith("__") and not isinstance(v, (bytes, bytearray))
            }
            print(f"  [{idx}] item_id={item_id} {fields}")
            shown += 1
            if shown >= 60:
                print("  ... (truncated)")
                break

        if shown == 0:
            print("  no _ItemId-bearing records; dumping first 8 objects raw:")
            for idx, obj in list(elems.items())[:8]:
                if isinstance(obj, dict):
                    flat = {
                        k: val(v) for k, v in obj.items()
                        if not k.startswith("__")
                    }
                    print(f"   [{idx}] {flat}")

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
