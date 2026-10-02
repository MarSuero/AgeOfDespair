"""Inspect BTableOrderList with support for Wilds files with omitted hash arrays."""

from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path
from typing import Any

from file_handlers.rsz.rsz_data_types import RuntimeTypeData
from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry


def plain(value: Any) -> Any:
    if isinstance(value, RuntimeTypeData):
        return value.value
    if hasattr(value, "value"):
        return value.value
    return value


def type_name(registry: TypeRegistry, instance: Any) -> str:
    return str((registry.get_type_info(instance.type_id) or {}).get("name", ""))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("registry")
    parser.add_argument("path")
    parser.add_argument("--contains")
    parser.add_argument("--output")
    args = parser.parse_args()

    registry = TypeRegistry(args.registry)
    path = Path(args.path)
    parsed = RszFile()
    parsed.filepath = str(path)
    parsed.type_registry = registry
    parsed.game_version = "MHWilds"
    parse_error = None
    try:
        parsed.read(path.read_bytes(), skip_data=False)
    except Exception as exc:
        parse_error = f"{type(exc).__name__}: {exc}"

    final_index = len(parsed.instance_infos) - 1
    final_type = type_name(registry, parsed.instance_infos[final_index])
    if final_type != "ace.btable.user_data.BTableOrderList":
        raise RuntimeError(f"unexpected final type: {final_type}")

    # The Wilds file ends after the two factory arrays. Treat omitted hash
    # arrays as empty instead of asking the generic RSZ parser to read past EOF.
    final_offset = 0
    for index in range(final_index):
        if index not in parsed.parsed_elements:
            continue
        fields = parsed.parsed_elements[index]
        if fields is None:
            continue
        # The parser stores no public offset table, so use the known failure
        # boundary recorded by the file layout and report the raw tail below.
    raw_tail = bytes(parsed.data[29520:])
    operator_count = struct.unpack_from("<I", raw_tail, 0)[0]
    cursor = 4
    operator_refs = list(struct.unpack_from(f"<{operator_count}I", raw_tail, cursor))
    cursor += operator_count * 4
    command_count = struct.unpack_from("<I", raw_tail, cursor)[0]
    cursor += 4
    command_refs = list(struct.unpack_from(f"<{command_count}I", raw_tail, cursor))
    cursor += command_count * 4

    factories = []
    for factory_index in command_refs:
        fields = parsed.parsed_elements.get(factory_index, {})
        row = {
            "instance_index": factory_index,
            "type": type_name(registry, parsed.instance_infos[factory_index]),
            "fields": {
                str(key): plain(value)
                for key, value in fields.items()
            } if isinstance(fields, dict) else {},
        }
        if args.contains and args.contains.lower() not in json.dumps(
            row, ensure_ascii=False
        ).lower():
            continue
        factories.append(row)

    report = {
        "file": str(path),
        "parse_error": parse_error,
        "final_type": final_type,
        "raw_tail_offset": 29520,
        "raw_tail_bytes": len(raw_tail),
        "operator_count": operator_count,
        "command_count": command_count,
        "operator_refs": operator_refs,
        "command_refs": command_refs,
        "factories": factories,
        "unconsumed_tail_bytes": len(raw_tail) - cursor,
    }
    rendered = json.dumps(report, ensure_ascii=False, indent=2)
    if args.output:
        output = Path(args.output)
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(rendered + "\n", encoding="utf-8")
    print(rendered)


if __name__ == "__main__":
    main()
