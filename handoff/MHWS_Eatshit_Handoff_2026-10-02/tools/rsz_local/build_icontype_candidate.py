"""Build a second standalone candidate with the consumable icon type."""

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
    "D:/mhws-eatshit/extracted/candidate/itemdata.user.icontype-candidate.3"
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
    "_IconType",
    "_Window",
    "_Eatable",
    "_Heal",
    "_EnableOnRaptor",
    "_OutBox",
):
    target[field].value = secret[field].value

for index, value in enumerate(secret["_GetRank"].values):
    target["_GetRank"].values[index].value = value.value

output.parent.mkdir(parents=True, exist_ok=True)
output.write_bytes(parsed.build())
print(output)
print(
    {
        "_ItemId": value_of(target["_ItemId"]),
        "_TextType": value_of(target["_TextType"]),
        "_IconType": value_of(target["_IconType"]),
        "_Window": value_of(target["_Window"]),
        "_Eatable": value_of(target["_Eatable"]),
        "_Heal": value_of(target["_Heal"]),
        "_EnableOnRaptor": value_of(target["_EnableOnRaptor"]),
        "_GetRank": [value_of(value) for value in target["_GetRank"].values],
    }
)
