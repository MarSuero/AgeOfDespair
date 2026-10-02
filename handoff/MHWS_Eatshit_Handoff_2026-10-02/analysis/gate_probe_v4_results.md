# Gate Probe v4: Runtime Read Results

Generated: 2026-10-01
Run: 2026-10-01 12:29 (game start .. probe fired 88.1 s later)
Log: `docs/logs/gate_probe_v4_run_20261001_1230.txt`
Extracted output: `analysis/gate_probe_v4_output.txt` (113 lines)

## Executive summary

The state-based trigger worked. The probe fired when the player existed
(`player acquired elapsed=88.1s frame=7650`) and measured the instance method that
v3 missed.

**The headline result: `app.HunterCharacter.canUseItem` does not reject item 98.**

```text
canUseItem id=4   -> true    (Secret Potion, control)
canUseItem id=98  -> true    (怪物的粪)
canUseItem id=99  -> nil
canUseItem id=100 -> true
```

Item 98 is reported as usable by the native gate. The reason the item-use key does
nothing therefore lies **elsewhere** — not in `canUseItem`.

## Identity of the probed IDs, confirmed at runtime

```text
NameString id=4   -> 秘药
NameString id=98  -> 怪物的粪
NameString id=99  -> <COLOR FF0000>#Rejected#</COLOR> Item_IT_100
NameString id=100 -> 滚成球的粪
```

And the resolved data rows:

```text
Data id=4   -> _ItemId=5    _SortId=3     _Type=0 _TextType=1 _IconType=13
Data id=98  -> _ItemId=99   _SortId=76    _Type=0 _TextType=5 _IconType=40
Data id=99  -> _ItemId=100  _SortId=5001  _Type=1 _TextType=0 _IconType=66
Data id=100 -> _ItemId=101  _SortId=75    _Type=0 _TextType=5 _IconType=40
```

This confirms the documented mapping "public 98 -> row `_ItemId=99`" and shows that
probing ID `99` reaches an internal `#Rejected#` placeholder rather than a real
item. **Future probes should not treat ID 99 as a dung variant.**

## What was re-confirmed from v3

- `app.ItemUtil.isAvailableItem` is static and returns `nil` for `4/98/99/100`.
- `notUseItem`, `checkNotUseItem_ItemWide`,
  `checkNotUseItem_ItemWide_NearOtherPl`, `addDisabledItem`, and the `canPut*`
  family are `method_missing` on all four probed types.
- `app.ItemUtil.STOCK_DISABLE_TYPE`: `NONE=0`, `ITEM_MAX=1`, `POUCH_FULL=2`,
  `DISABLE_POUCH=3`, `ITEM_GROUP=4`, `ERROR=5`.
- `getItemActionTypeFromItemID`: `4 -> 4`, `98 -> 1`, `99 -> 1`, `100 -> 1`.

## A probe artefact that must NOT be over-read

The baseline section reported:

```text
Data id=4   ... _Eatable=true  _Heal=true  _Window=true
Data id=98  ... _Eatable=<err> _Heal=<err> _Window=<err>
Data id=100 ... _Eatable=<err> _Heal=<err> _Window=<err>
```

It is tempting to read this as "item 98 has no eatable field". That reading is
**wrong**, and it was checked before being reported:

- All 652 rows in `itemdata.user.3` have an identical 31-field layout, across every
  `_TextType` value from 0 to 13. No row type is missing these fields.
- Row `_ItemId=99` and row `_ItemId=5` both contain `_Eatable`, `_Heal`, and
  `_Window`, with the same underlying type (`BoolData`).
- On the *same* runtime object, `_ItemId`, `_SortId`, `_Type`, `_ItemGroup`,
  `_TextType`, `_IconType`, and `_GetRank` all read successfully.

So `<err>` is a **read artefact of this probe** (a `get_field` quirk for those three
names on those objects), not a property of the item data. It is recorded here only
so a future run does not mistake it for evidence. The probe should be changed to
report the actual error text instead of a bare `<err>`.

## Consequence: where the failure is NOT

The following are now excluded by direct measurement rather than inference:

```text
ItemData flags      - copying them all changed nothing (earlier PAK test)
Item identity       - 98 resolves to the real 怪物的粪 with the expected row
Action type         - returns 1, and type 1 maps to cUseDrinkItem in the BTable
canUseItem          - returns true for 98
isAvailableItem     - returns nil for everything, so it is not discriminating
PAK deployment      - the earlier candidate was confirmed loaded by the game
```

The failing layer is downstream of "the game agrees the item is available and can
be used": it is the **selection/trigger path that turns a use request into an
action**, or the **UI/pouch category gate** that decides whether pressing the use
key even emits a request for this item.

## Recommended next step

Do not make another PAK candidate. Instead, instrument the *actual use attempt*:

1. Hook the item-use entry points (e.g. `app.HunterCharacter.canUseItem` and the
   use/consume request path) and log when the player presses the use key while
   item 98 is selected — this shows whether a request is emitted at all.
2. Compare that trace against Secret Potion (item `4`) in the same session, so the
   difference is measured rather than assumed.
3. Only then decide whether the missing piece is a UI category, a request guard,
   or the action-layer binding.

This is a different probe shape from v4 (a hook plus a user action, rather than a
one-shot read), and it should be planned and approved separately.

## Safety

Read-only. The probe was rolled back to `.disabled` and the autorun directory was
verified to contain no active project file. No PAK, save, or original archive was
modified.
