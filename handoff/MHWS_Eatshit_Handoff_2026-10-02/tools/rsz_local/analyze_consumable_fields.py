"""Analyze static ItemData patterns without editing the source resource."""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry


def value_of(value: Any) -> Any:
    if hasattr(value, "value"):
        return value.value
    if hasattr(value, "values"):
        return [value_of(item) for item in value.values]
    if hasattr(value, "guid_str"):
        return value.guid_str
    return value


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("registry")
    parser.add_argument("itemdata")
    parser.add_argument("--output")
    args = parser.parse_args()

    registry = TypeRegistry(args.registry)
    parsed = RszFile()
    parsed.filepath = args.itemdata
    parsed.type_registry = registry
    parsed.game_version = "MHWilds"
    parsed.read(Path(args.itemdata).read_bytes(), skip_data=False)

    rows = []
    for index, fields in parsed.parsed_elements.items():
        if not isinstance(fields, dict):
            continue
        row = {name: value_of(value) for name, value in fields.items()}
        if row.get("_ItemId") is not None:
            row["instance"] = index
            rows.append(row)

    eatable = [row for row in rows if row.get("_Eatable") is True]
    keys = [
        "_Type",
        "_ItemGroup",
        "_TextType",
        "_Window",
        "_Heal",
        "_EnableOnRaptor",
        "_Battle",
        "_Special",
        "_ForMoney",
        "_OutBox",
        "_NonLevelShell",
        "_GetRank",
        "_MaxCount",
        "_OtomoMax",
    ]
    distributions = {}
    for key in keys:
        distributions[key] = Counter(
            json.dumps(row.get(key), ensure_ascii=False, sort_keys=True)
            for row in eatable
        )

    target = next((row for row in rows if row.get("_ItemId") == 99), None)
    secret = next((row for row in rows if row.get("_ItemId") == 5), None)
    result = {
        "row_count": len(rows),
        "eatable_count": len(eatable),
        "eatable_rows": eatable,
        "target_99": target,
        "secret_5": secret,
        "eatable_distributions": {
            key: dict(counter) for key, counter in distributions.items()
        },
    }
    rendered = json.dumps(result, ensure_ascii=False, indent=2)
    if args.output:
        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)


if __name__ == "__main__":
    main()
