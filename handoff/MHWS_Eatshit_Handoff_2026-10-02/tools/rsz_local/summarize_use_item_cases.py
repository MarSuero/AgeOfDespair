"""Summarize BTable item-use judge cases without modifying source files."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from file_handlers.rsz.rsz_data_types import GuidData, ObjectData
from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry


def value_of(value: Any) -> Any:
    if isinstance(value, (ObjectData,)) :
        return value.value
    if isinstance(value, GuidData):
        return value.guid_str
    if hasattr(value, "value"):
        return value.value
    return value


def type_name(registry: TypeRegistry, instance: Any) -> str:
    info = registry.get_type_info(instance.type_id) or {}
    return str(info.get("name", ""))


def read_file(registry: TypeRegistry, path: Path) -> RszFile:
    parsed = RszFile()
    parsed.filepath = str(path)
    parsed.type_registry = registry
    parsed.game_version = "MHWilds"
    parsed.read(path.read_bytes(), skip_data=False)
    return parsed


def guid_map(registry: TypeRegistry, paths: list[Path]) -> dict[str, str]:
    result: dict[str, str] = {}
    for path in paths:
        parsed = read_file(registry, path)
        for index, fields in parsed.parsed_elements.items():
            if not isinstance(fields, dict):
                continue
            guid = value_of(fields.get("_InstanceGuid"))
            class_name = value_of(fields.get("_Class"))
            if isinstance(guid, str) and isinstance(class_name, str):
                result[guid] = class_name.rstrip("\x00")
    return result


def resolve_edit_field(parsed: RszFile, fields: dict[str, Any], name: str) -> Any:
    ref = value_of(fields.get(name))
    if not isinstance(ref, int):
        return ref
    child = parsed.parsed_elements.get(ref)
    if not isinstance(child, dict):
        return ref
    return value_of(child.get("_Value"))


def summarize_file(
    registry: TypeRegistry,
    path: Path,
    actions: dict[str, str],
) -> list[dict[str, Any]]:
    parsed = read_file(registry, path)
    rows: list[dict[str, Any]] = []
    for index, fields in parsed.parsed_elements.items():
        if not isinstance(fields, dict):
            continue
        name = type_name(registry, parsed.instance_infos[index])
        if not name.endswith("cUseItemJudgeCaseArg"):
            continue

        action_guid = resolve_edit_field(parsed, fields, "_EditActionGuid")
        branch_guid = resolve_edit_field(parsed, fields, "_EditBranchedParamGuid")
        action_type = resolve_edit_field(parsed, fields, "_EditArg_1")
        asset_index = resolve_edit_field(parsed, fields, "_EditAssetIndex")

        row = {
            "file": path.name,
            "case_index": index,
            "asset_index": asset_index,
            "item_action_type": action_type,
            "item_action_type_hex": (
                f"0x{(int(action_type) & 0xFFFFFFFF):08X}"
                if isinstance(action_type, int)
                else None
            ),
            "action_guid": action_guid,
            "action_class": actions.get(action_guid),
            "branched_param_guid": branch_guid,
            "branched_param_class": actions.get(branch_guid),
        }
        rows.append(row)
    return rows


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("registry")
    parser.add_argument("action_files", nargs="+")
    parser.add_argument("--case-file", action="append", required=True)
    parser.add_argument("--output")
    args = parser.parse_args()

    registry = TypeRegistry(args.registry)
    actions = guid_map(registry, [Path(item) for item in args.action_files])
    rows: list[dict[str, Any]] = []
    for filename in args.case_file:
        rows.extend(summarize_file(registry, Path(filename), actions))

    payload = {
        "action_guid_count": len(actions),
        "case_count": len(rows),
        "cases": rows,
    }
    rendered = json.dumps(payload, ensure_ascii=False, indent=2)
    if args.output:
        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)


if __name__ == "__main__":
    main()
