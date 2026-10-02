# Static Gate Status

## Confirmed

- Public item `98` resolves through `app.HunterItemActionTable.getItemActionTypeFromItemID` to action type `1`.
- BTable action type `1` resolves to `cUseDrinkItem`.
- The candidate PAK was actually loaded by the REFramework integrity-pak hook.
- The installed `infinity_consumables.json` configuration is enabled, but no matching `infinity_consumables` or `auto_item_buff` Lua script exists in the current autorun tree. Its item-98 entry remains `Eatable=false`; this is configuration residue, not confirmed runtime interference.
- Copying all native consumable ItemData invariants, including `_GetRank=[0,0]`, still produced no item-use action.
- `fixitems.user.3` contains no fixed row `99`.
- `itemrecipe.user.3` is unrelated recipe data and contains no use-action selection field.

## Static Exhaustion

The remaining public ItemData fields do not explain the failure:

- `_Type=0` and `_ItemGroup=0` already match native consumables.
- `_TextType`, `_Window`, `_Eatable`, `_Heal`, `_EnableOnRaptor`, `_GetRank` were copied.
- `_IconType=40` is the only remaining consumable-distribution outlier, but it is an icon/UI field and has no demonstrated relation to the use gate.
- No BTable `cItemIDJudgeCaseArg` for fixed row `99` exists in base or patch-014.

## Remaining Gate

The binary exposes separate methods:

- `app.ItemUtil.isAvailableItem`
- `app.HunterCharacter.canUseItem`
- `app.HunterCharacter.notUseItem`
- `app.HunterCharacter.checkNotUseItem_ItemWide`
- `app.HunterCharacter.checkNotUseItem_ItemWide_NearOtherPl`

The current evidence does not establish which argument or condition rejects item `98`. Do not make another speculative PAK candidate from ItemData alone.

### Partial runtime correction (2026-10-01 12:07 run)

A read-only runtime read was executed. See `analysis/gate_probe_v3_results.md`.
It corrects part of the list above:

- `app.HunterCharacter.canUseItem` **exists and is an instance method** (confirmed).
- `notUseItem`, `checkNotUseItem_ItemWide`, and
  `checkNotUseItem_ItemWide_NearOtherPl` are **`method_missing` on all four probed
  types** (`app.ItemUtil`, `app.ItemDef`, `app.HunterItemActionTable`,
  `app.HunterCharacter`). Their names exist in the binary's global string heap, but
  they are not methods of these types.
- `app.ItemUtil.isAvailableItem` is **static** and returned `nil` for IDs `4`, `98`,
  `99`, and `100` — it does not discriminate item 98.
- `app.ItemUtil.STOCK_DISABLE_TYPE` has members `NONE=0`, `ITEM_MAX=1`,
  `POUCH_FULL=2`, `DISABLE_POUCH=3`, `ITEM_GROUP=4`, `ERROR=5` — all of them are
  pouch/stack concerns, none is a "not usable" reason.

The run could **not** measure `canUseItem`, because it fired on a frame count
(3600) while the game was still initialising and `getMasterPlayer()` returned nil.
The game continued for another 14 minutes, so the trigger was at fault.

A corrected probe, `scripts/discovery/gate_probe_v4.lua.disabled`, uses a
wall-clock deadline plus a state-based gate that fires when the player exists.

## Safe Next Routes

1. Native disassembly/signature recovery for the availability gate.
2. One explicitly authorized runtime read of `isAvailableItem` and `canUseItem` for public IDs `4`, `98`, `100`.

No new game launch is scheduled by this static pass.

## 2026-10-01 update: binary-level evidence added

A second static pass (see `analysis/native_gate_static_evidence.md`) added the
following, which this file previously did not record:

- The gate methods are stored in one global NUL-separated string heap in
  `MonsterHunterWilds.exe`: heap extent `0x12A726BC`..`0x13159150`,
  342,386 strings. `addDisabledItem` is at heap index 91,589.
- Because the heap is assembly-wide, and the strings around the gate names are
  weapon members before them and camera members after them, **heap adjacency
  identifies no declaring type**. Treat the cluster as a list of related names,
  not as one type's members.
- `addDisabledItem` is a new name. It implies an explicit disabled-item set that
  is separate from ItemData flags, and is a concrete new candidate for the gate.
- `app.ItemUtil` is confirmed as a real type. The RSZ dump lists it plus
  `app.ItemUtil.STOCK_DISABLE_TYPE`, `STOCK_TYPE`, `POUCH_TYPE`, `STORAGE_TYPE`,
  `SETUP_CAMP_STATE`, `PickResult`, and closure classes up to
  `<>c__DisplayClass77_0`.
- The RSZ dump cannot supply method signatures: `isAvailableItem`, `canUseItem`,
  `notUseItem`, and `checkNotUseItem` all have zero occurrences there.
- The executable stores bare names without the `app.` prefix; `app.ItemUtil` and
  `app.ItemDef` do not appear as strings at all.

Consequence: static data is exhausted for this question. The authorized read-only
runtime read is now the only route that can identify the rejecting condition. A
corrected and extended probe is prepared at
`scripts/discovery/gate_probe_v3.lua.disabled`, with deployment and rollback steps
in `docs/readonly_runtime_read_plan.md`. It is not deployed.

Also confirmed in the same pass: the auto-use tables do not reference item `98`
(`analysis/native_gate_static_evidence.md`, Evidence 6), and the `恶臭` mechanism
family is mapped in `analysis/stench_mechanism_map.md`.

## 2026-10-01 correction to the earlier probe's call form

The v1 probe's method-call form was wrong and is now documented:

- v1 called every gate method as `method(nil, item_id)`, which is only valid for
  static methods, and it never checked `is_static`.
- v2 resolves and logs the receiver kind before calling.

This is recorded because it is a plausible reason the earlier read produced no
usable gate values, independently of whether the read ever ran.
