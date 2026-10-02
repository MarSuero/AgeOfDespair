"""Read-only RSZ inspection for the normal player item-use route.

This script deliberately reports data without editing or rebuilding any file.
It is aimed at correlating plcommonsub_actionid with its parameter records and
at exposing tiny/atypical user files such as itemsettingdata.user.3.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any
from collections.abc import Mapping

from file_handlers.rsz.rsz_data_types import (
    ArrayData,
    StructData,
    GuidData,
    UserDataData,
)
from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry


def plain(value: Any) -> Any:
    if value is None:
        return None
    if isinstance(value, Mapping):
        return {str(key): plain(item) for key, item in value.items()}
    if isinstance(value, (ArrayData, StructData)):
        return [plain(item) for item in value.values]
    if isinstance(value, GuidData):
        return value.guid_str
    if isinstance(value, UserDataData):
        return {"id": value.value, "string": value.string}
    if hasattr(value, "value"):
        return value.value
    if hasattr(value, "__dict__"):
        attrs = {}
        for name, item in vars(value).items():
            attrs[name] = plain(item)
        return attrs
    return value


def type_name(registry: TypeRegistry, instance: Any) -> str:
    info = registry.get_type_info(instance.type_id)
    if not info:
        return f"<missing 0x{instance.type_id:08X}>"
    return str(info.get("name", "<unnamed>"))


def parse_file(registry: TypeRegistry, path: Path) -> RszFile:
    parsed = RszFile()
    parsed.filepath = str(path)
    parsed.type_registry = registry
    parsed.game_version = "MHWilds"
    parsed.read(path.read_bytes(), skip_data=False)
    return parsed


def report_file(
    registry: TypeRegistry,
    path: Path,
    contains: str | None,
    indices: set[int] | None,
) -> dict[str, Any]:
    report: dict[str, Any] = {
        "file": str(path),
        "bytes": path.stat().st_size,
    }
    try:
        parsed = parse_file(registry, path)
    except Exception as exc:
        report["error"] = f"{type(exc).__name__}: {exc}"
        return report

    instances: list[dict[str, Any]] = []
    for index, instance in enumerate(parsed.instance_infos):
        name = type_name(registry, instance)
        fields = parsed.parsed_elements.get(index, {})
        fields_plain = {
            str(field): plain(value)
            for field, value in fields.items()
        } if isinstance(fields, dict) else plain(fields)
        class_name = str(fields_plain.get("_Class", "")).rstrip("\x00")
        haystack = (
            f"{name} {class_name} "
            f"{json.dumps(fields_plain, ensure_ascii=False, default=str)}"
        )
        if indices is not None and index not in indices:
            continue
        if contains and contains.lower() not in haystack.lower():
            continue
        instances.append(
            {
                "index": index,
                "type_id": f"0x{instance.type_id:08X}",
                "type": name,
                "class": class_name,
                "parent": parsed.instance_hierarchy.get(index, {}).get("parent"),
                "children": parsed.instance_hierarchy.get(index, {}).get("children", []),
                "fields": fields_plain,
            }
        )
    report["instances"] = instances
    report["instance_count"] = len(parsed.instance_infos)
    return report


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("registry")
    parser.add_argument("files", nargs="+")
    parser.add_argument("--contains")
    parser.add_argument(
        "--indices",
        help="Comma-separated instance indices to print, bypassing broad scans",
    )
    args = parser.parse_args()

    registry = TypeRegistry(args.registry)
    indices = None
    if args.indices:
        indices = {int(item.strip()) for item in args.indices.split(",") if item.strip()}
    for filename in args.files:
        result = report_file(registry, Path(filename), args.contains, indices)
        print(json.dumps(result, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
