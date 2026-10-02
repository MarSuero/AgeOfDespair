# Gate Probe v3: Runtime Read Results

Generated: 2026-10-01
Run: 2026-10-01 12:06:31 (game start) .. probe fired 12:07:25
Log: `docs/logs/gate_probe_v3_run_20261001_1207.txt`
Extracted output: `analysis/gate_probe_v3_output.txt` (100 lines)

## Executive summary

The probe loaded and ran, producing 100 log lines. It confirmed several things and
**failed to obtain the instance-method gate values** for a timing reason that is
now understood precisely.

Three findings matter:

1. `app.ItemUtil.isAvailableItem` is **static** and returned `nil` for every probed
   ID (`4`, `98`, `99`, `100`). It does not discriminate item 98.
2. `canUseItem` **exists on `app.HunterCharacter` and is an instance method** —
   confirming the risk identified during planning. It was **not** measured, because
   no player object was reachable yet.
3. `getItemActionTypeFromItemID` returned **`4` for item `4`** and **`1` for items
   `98`, `99`, `100`**.

## Timing failure (primary limitation of this run)

```text
12:06:49.574  ScriptRunner runs mhws_eatshit_gate_probe_v3.lua
12:07:25.210  probe fires at frame 3600: getMasterPlayer returned nil
```

The probe fired 36 seconds after script load, while the game was still
initialising. `PlayerManager:getMasterPlayer()` returned `nil` at that moment, so
every `app.HunterCharacter` instance method was logged as
`skipped=instance_unavailable:getMasterPlayer returned nil`.

This is exactly the failure mode `docs/runtime-findings.md` recorded before
("Final task-runtime probe result", 3600-frame timeout). The 3600-frame cap is
frame-based while the title screen and loading are wall-clock long, so 3600 frames
elapsed long before a save was loaded.

**The probe design was correct in degrading gracefully**: it still emitted the
type-level and enum results instead of producing nothing. That is why this run
produced usable evidence despite the miss.

## Confirmed results

### Enum members (new, previously unknown)

`app.ItemUtil.STOCK_DISABLE_TYPE` (6 members):

```text
NONE            = 0
ITEM_MAX        = 1
POUCH_FULL      = 2
DISABLE_POUCH   = 3
ITEM_GROUP      = 4
ERROR           = 5
```

`app.ItemUtil.STOCK_TYPE` (5 members):

```text
POUCH            = 0
BOX              = 1
BOTH             = 2
BOTH_POUCH_BOX   = 3
BOTH_BOX_POUCH   = 4
```

`STOCK_DISABLE_TYPE` is the "why can this item not be stocked/used" value. It
matches the `addDisabledItem` name found by static analysis. Its members are all
about pouch/stack limits — **none of them is a "this item is not usable" reason**,
which weakens `addDisabledItem` as the gate that rejects item 98.

### Method existence and kind

```text
app.ItemUtil.isAvailableItem               static=true    found
app.ItemUtil.isJudgeItem                   static=true    found
app.ItemUtil.isOpenMenuItem                static=true    found
app.ItemUtil.isDisableAtRidingItem         static=true    found
app.HunterItemActionTable.getItemActionTypeFromItemID  static=true  found
app.HunterCharacter.canUseItem             static=?       found  (instance)
```

Every other probed name was `method_missing` on every type:

```text
notUseItem, checkNotUseItem_ItemWide, checkNotUseItem_ItemWide_NearOtherPl,
addDisabledItem, canPutMeat, canPutBomb, canPutTrap, canUseBonfire
```

**Important correction to `analysis/static_gate_status.md`**: that file lists
`notUseItem`, `checkNotUseItem_ItemWide`, and
`checkNotUseItem_ItemWide_NearOtherPl` as methods to investigate. At runtime they
do not exist on `app.ItemUtil`, `app.ItemDef`, `app.HunterItemActionTable`, or
`app.HunterCharacter`. The static binary scan found their *names* in the global
string heap; those names belong to some other type, which is consistent with the
heap-adjacency correction in `native_gate_static_evidence.md`.

### Action type values

```text
id=4   -> 4
id=98  -> 1
id=99  -> 1
id=100 -> 1
```

BTable cross-reference (`analysis/patch014_use_item_cases.json`, 47 cases):

```text
type 1 -> cUseDrinkItem      (commonsub_pack.user.3, case 186)
type 1 -> cNoUseDrinkItem    (case 245)
type 2 -> cEatMeat           (case 191)
type 3 -> cUseTabletItem     (case 196)
type 5 -> cUsePowderItem     (case 201)
type 7 -> cUseSougankyou
type 8 -> cUseItemBarrelBombL
```

No case in the BTable carries type `4`, which is what Secret Potion returns.

## What this changes about the project's assumptions

`analysis/static_gate_status.md` states as "Confirmed":

> Public item `98` resolves through `app.HunterItemActionTable.getItemActionTypeFromItemID`
> to action type `1`. BTable action type `1` resolves to `cUseDrinkItem`.

Both halves are now directly confirmed by runtime measurement for the first time.
But the earlier reasoning drew an unstated conclusion from them — that item 98 is
therefore routed like a consumable. The measurement shows:

- Secret Potion returns **4**, not 1. So "type 1" is **not** "the consumable type".
- Type 1 maps to `cUseDrinkItem` **and also** to `cNoUseDrinkItem`, i.e. the same
  type is used for both a use case and a no-use case.
- Items `98`, `99`, and `100` — two of which are dung-related and one of which is a
  different item entirely — all return the same value `1`. The function is
  therefore **not discriminating between them**, and type 1 alone cannot be the
  reason item 98 works or fails.

Net: the action-type layer for item 98 looks no worse than the project believed,
and it is not the demonstrated cause of the failure. The gate remains unidentified.

## A retracted concern (recorded so it is not repeated)

While analysing this run, the base `itemdata.user.3` appeared to show that the
failed candidate patched the **wrong row**: the base file contains a row with
`_ItemId=98` (`_SortId=1025`, `_Type=2`, `_IconType=45`), while the candidate
patched the row with `_ItemId=99`.

That concern was **wrong**, and the reconciliation is exact:

```text
runtime Data(98)  -> _ItemId=99,  _SortId=76, get_Type()=0   matches instance 92
runtime Data(100) -> _ItemId=101, _SortId=75, get_Type()=0   matches instance 94
```

Both match. The documented mapping "public 98 -> row `_ItemId=99`" is correct, and
the candidate patched the right row. The base file simply contains rows whose
`_ItemId` field is not the public ID — instance 91 (`_ItemId=98`) is a different
item that happens to share the number.

## Next step

The gate is still unidentified, and the previous run could not measure the one
method that matters most (`app.HunterCharacter.canUseItem`, an instance method).
A corrected read needs:

1. A **state-based trigger** instead of a frame count: wait until
   `PlayerManager:getMasterPlayer()` returns non-nil, with a generous wall-clock
   bound rather than 3600 frames, and fire only once the player exists.
2. Explicit logging of when the player became available, so the next run proves
   the trigger worked rather than silently timing out.
3. The same type/enum enumeration (it worked and is now known-good), plus the
   instance-method calls that were skipped.

## Safety

Read-only. The probe was rolled back to `.disabled` immediately after the read and
the autorun directory was verified to contain no active project file. No PAK, save,
or original archive was modified.
