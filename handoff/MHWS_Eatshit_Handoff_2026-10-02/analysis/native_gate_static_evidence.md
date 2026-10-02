# Native Gate Static Evidence

Generated: 2026-10-01
Method: read-only static inspection only. No game launch, no PAK change, no save change.

## Scope

This pass re-examined the unresolved native availability/use gate for public
item ID `98` (`怪物的粪`, fixed ItemData row `_ItemId=99`) without launching the
game. It adds binary-level evidence that was not recorded in
`analysis/static_gate_status.md`.

## Evidence 1: gate methods share one contiguous name cluster

The game executable `MonsterHunterWilds.exe` (539,469,728 bytes) stores REFramework
method-name strings in a contiguous pool. Reading the pool as ASCII at
`0x12C3F6F2` yields this exact sequence:

```text
canUseItem
notUseItem
receiveGuiActionMessage
checkNotUseItem_ItemWide
checkNotUseItem_ItemWide_NearOtherPl
addDisabledItem
canPutMeat
canPutBomb
canPutTrap
canUseBonfire
isEnableExEmote00
isEnableExEmote00Slinger
```

Interpretation: the four gate methods named in `static_gate_status.md`
(`canUseItem`, `notUseItem`, `checkNotUseItem_ItemWide`,
`checkNotUseItem_ItemWide_NearOtherPl`) belong to one method cluster that also
contains `addDisabledItem` and the placement-item checks `canPutMeat`,
`canPutBomb`, `canPutTrap`, `canUseBonfire`.

`addDisabledItem` is the notable new name: it implies the engine maintains an
explicit "disabled item" set that is separate from ItemData flags. This is a
concrete, checkable candidate for why fixed row `99` is rejected even when all
consumable ItemData flags are copied.

The immediately preceding names in the same pool are weapon-change closures
(`<changeWeaponCharm>b__100_0`, `<changeWeaponCharm>b__100_1`). Name pools are
concatenated per-assembly, so adjacency proves shared ownership only weakly; it
does not by itself prove the owning type.

### Correction (same pass): the pool is global, so adjacency proves nothing

A follow-up measurement resolved how much this adjacency is worth. Reading the
NUL-separated string heap that contains `addDisabledItem` (offset `0x12C3F75E`)
shows:

```text
heap extent          0x12A726BC .. 0x13159150   (7,236,245 bytes)
string count         342,386 NUL-terminated strings
addDisabledItem      string index 91,589
```

The heap begins immediately after non-string binary metadata and at the point
where `System.Private.CoreLib` first appears (`0x12A726C1`). It is therefore one
flat, assembly-wide string heap, not a per-type member list.

Neighbouring strings in heap order confirm this:

```text
index 91,529-91,583   weapon-asset and weapon-change members
                      (changeWeapon, get_ReserveWeapon, clearWeaponAssets, ...)
index 91,584-91,595   the gate methods (canUseItem ... canUseBonfire)
index 91,596+         camera and interpolation members
                      (get_SkipLength, setCameraLayerTarget, startCameraInterpolation, ...)
```

Consequence: the gate methods sit between a weapon block and a camera block in a
global heap. **Heap adjacency does not establish which type owns them**, and the
earlier phrasing here ("proves shared ownership only weakly") understated the
problem. Treat the cluster as evidence that these names exist and are related by
purpose, not as evidence of a common declaring type.

## Evidence 2: `app.ItemUtil` is a real type with stock-state enums

The Wilds RSZ type dump `tools/rsz_local/resources/data/dumps/rszmhwilds.json`
contains these exact type names:

```text
app.ItemUtil
app.ItemUtil.<>c__DisplayClass15_0
app.ItemUtil.<>c__DisplayClass37_0
app.ItemUtil.<>c__DisplayClass77_0
app.ItemUtil.PickResult
app.ItemUtil.POUCH_TYPE
app.ItemUtil.SETUP_CAMP_STATE
app.ItemUtil.STOCK_DISABLE_TYPE
app.ItemUtil.STOCK_TYPE
app.ItemUtil.STORAGE_TYPE
```

Findings:

- `app.ItemUtil` is a confirmed type, not a namespace fragment.
- Its compiler-generated `<...>c__DisplayClass77_0` closure proves the type has at
  least 77 members with lambda captures.
- `STOCK_DISABLE_TYPE` is a nested enum whose name directly matches the
  `addDisabledItem` / disabled-item concept found in Evidence 1.
- Enum member *names* and enum *values* are not present in the RSZ dump; the dump
  records field layout only (`value__` : `S32`). The enum's actual members remain
  unknown from static data.

## Evidence 3: RSZ dump cannot answer method signatures

The RSZ dump is a field-layout dictionary keyed by CRC. Confirmed searches:

```text
isAvailableItem       0 occurrences
canUseItem            0 occurrences
notUseItem            0 occurrences
checkNotUseItem       0 occurrences
HunterItemActionTable 1 occurrence (type name only)
app.HunterCharacter   fields only, no "methods" key
```

Therefore no method signature, parameter list, or return type for the gate
methods can be recovered from the RSZ dump. Static extraction of the current
dump set is exhausted for this question.

Confirmed exhaustively in the same pass: parsing the whole dump and collecting
the union of every object key yields exactly

```text
['crc', 'fields', 'name', 'parent']
```

across all 322,731 entries (47,856 of which carry `fields`). There is no
`method`, `methods`, or method-name key anywhere in the schema. This is not a
limitation of how the dump was searched; the format cannot represent methods.

## Evidence 4: binary contains no fully qualified `app.` type strings for these types

ASCII search of `MonsterHunterWilds.exe`:

```text
app.ItemUtil       NOT FOUND
app.ItemDef        NOT FOUND
ItemUtil           found (bare name)
ItemDef            found (bare name)
HunterItemActionTable found (bare name)
app.               found (bare prefix)
```

Method and type names are stored bare, without the `app.` prefix. Any future
binary string search must therefore search bare names, not fully qualified ones.

## Evidence 5: deployment log independently re-confirmed

`re2_framework_log.txt` (396,111 bytes, last write 2026-10-01 02:59) records the
2026-10-01 02:57:17 run. Verified lines:

```text
line 666  Cached custom pak with name: z9999_mhws_eatshit_getrank_candidate.pak
line 1615 Redirecting load of re_chunk_000.pak.sub_000.pak.patch_026.pak to custom pak
          at path: ...\pak_mods\z9999_mhws_eatshit_getrank_candidate.pak
```

This independently confirms the recorded conclusion that the failed candidate was
actually loaded by the integrity-pak hook.

Additional verified facts from the same log:

- The run loaded exactly 8 autorun scripts, none of them belonging to this project:
  `artian_editor.lua`, `charm_editor.lua`, `enemy_scar_highlight.lua`,
  `FieldEventSpawner.lua`, `Invisible Mantles.lua`,
  `MHWilds_DisablePostProcessingEffects.lua`,
  `mhwilds_tweak_volumetric_fogs.lua`, `reframework-d2d.lua`.
- Zero `mhws-eatshit` lines exist in the log. This is fully explained: every
  project probe was already renamed to `.lua.disabled` before that run, so
  REFramework never executed them. It is not evidence of probe failure.
- The log ends at 02:59:41 with `Hooked DirectX 12`; the recorded session did not
  necessarily reach a loaded save with the item bar open.

## Evidence 6: the auto-use tables do not reference item 98

The extracted base data contains two "auto use" parameter files. Both were parsed
with the existing project RSZ parser (read-only, via the new
`tools/rsz_local/dump_autouse.py`):

```text
autousehealthitemdata.user.3    5 records   _ItemId = 198, 3, 120, 67, 2
autousestatusitemdata.user.3   26 records   _ItemId = 163, 179, 212, 4, 113, 272,
                                            685, 632, 8, 165, 10, 9, 7, 114,
                                            127, 171, 173, 172
```

Each record is a two-field tuple:

```text
autousehealthitemdata : { _ItemId, _LackHealth }
autousestatusitemdata : { _ItemId, _BadConditionFixed }
```

Findings:

- Public IDs `98`, `99`, and `100` appear in neither file.
- These tables describe the "automatically use an item when a condition is met"
  feature (low health, or a matching bad condition), keyed by `_LackHealth` and
  `_BadConditionFixed`.
- They are therefore **not** the manual item-use action selector, and cannot
  explain or fix the item-98 rejection.

This is a negative result that closes another hypothesis without a game launch.
`_BadConditionFixed` belongs to the same bad-condition enum family mapped in
`analysis/stench_mechanism_map.md`.

## Consequences for the next step

Static analysis is exhausted for the current artifact set:

- The gate's rejection reason cannot be read from ItemData (already proven).
- The RSZ dump has no methods (Evidence 3), and its schema cannot represent them.
- The binary stores bare names in one global heap, so heap adjacency localizes
  nothing (Evidence 1 correction, 4).
- The auto-use tables do not reference item 98 and are not the use selector
  (Evidence 6).
- `addDisabledItem` and `app.ItemUtil.STOCK_DISABLE_TYPE` are new, concrete names
  worth probing at runtime, but they are not yet confirmed as the rejecting gate.

The only remaining route that can produce a definitive answer is the explicitly
authorized read-only runtime read. The prepared probe is now
`scripts/discovery/gate_probe_v3.lua.disabled`, which supersedes the v1/v2 probes;
deployment and rollback steps are in `docs/readonly_runtime_read_plan.md`.

## Safety

No game archive, PAK, save, or deployed script was modified by this pass. All
project probes and candidates remain disabled.
