"""Build a standalone ItemData candidate with the missing consumable rank flags."""

from __future__ import annotations

from pathlib import Path

from file_handlers.rsz.rsz_file import RszFile
from utils.type_registry import TypeRegistry


def value_of(value):
    if hasattr(value, "value"):
        return value.value
    return value


registry = TypeRegistry("D:/mhws-eatshit/tools/rsz_local/resources/data/dumps/rszmhwilds.json")
source = Path(
    "D:/mhws-eatshit/extracted/patch_014/natives/stm/gamedesign/common/item/itemdata.user.3"
)
output = Path(
    "D:/mhws-eatshit/extracted/candidate/itemdata.user.getrank-candidate.3"
)

parsed = RszFile()
parsed.filepath = str(source)
parsed.type_registry = registry
parsed.game_version = "MHWilds"
parsed.read(source.read_bytes(), skip_data=False)

rows = {
    value_of(fields.get("_ItemId")): fields
    for fields in parsed.parsed_elements.values()
    if isinstance(fields, dict) and "_ItemId" in fields
}
target = rows[99]
secret = rows[5]

for field in (
    "_TextType",
    "_Window",
    "_Eatable",
    "_Heal",
    "_EnableOnRaptor",
    "_OutBox",
):
    target[field].value = secret[field].value

target_rank = target["_GetRank"].values
secret_rank = secret["_GetRank"].values
for index, value in enumerate(secret_rank):
    target_rank[index].value = value.value

output.parent.mkdir(parents=True, exist_ok=True)
output.write_bytes(parsed.build())
print(output)
print(
    {
        "_ItemId": value_of(target["_ItemId"]),
        "_TextType": value_of(target["_TextType"]),
        "_Window": value_of(target["_Window"]),
        "_Eatable": value_of(target["_Eatable"]),
        "_Heal": value_of(target["_Heal"]),
        "_EnableOnRaptor": value_of(target["_EnableOnRaptor"]),
        "_GetRank": [value_of(value) for value in target["_GetRank"].values],
    }
)
