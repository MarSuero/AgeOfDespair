# Read-Only Runtime Read: Plan and Rollback

Generated: 2026-10-01
Updated: 2026-10-01 (v3 ran; v4 corrects the trigger)

## Status

PREPARED, NOT DEPLOYED. No game launch is requested by this document alone.

## Result of the v3 run (2026-10-01 12:07)

v3 deployed and ran successfully, producing 100 log lines. It **missed its main
target for a timing reason**: it fired on a frame count (3600) 36 seconds after
script load, while the game was still initialising, so
`PlayerManager:getMasterPlayer()` returned `nil` and every `app.HunterCharacter`
instance method was skipped. The game kept running for another 14 minutes.

Full results and analysis: `analysis/gate_probe_v3_results.md`.

What v3 did establish:

- `app.ItemUtil.isAvailableItem` is static, returns `nil` for IDs `4/98/99/100`.
- `canUseItem` exists on `app.HunterCharacter` as an instance method.
- `notUseItem`, `checkNotUseItem_ItemWide`,
  `checkNotUseItem_ItemWide_NearOtherPl`, `addDisabledItem`, and the `canPut*`
  family are `method_missing` on all four probed types.
- `app.ItemUtil.STOCK_DISABLE_TYPE` and `STOCK_TYPE` members are now known exactly.
- `getItemActionTypeFromItemID` returns `4` for item `4`, and `1` for `98/99/100`.

## Why the next read is still needed

`app.HunterCharacter.canUseItem` — the one method that most plausibly rejects item
98 — has never been measured, because it needs a live player object.

## What will run

Probe source (project copy, currently disabled):

```text
scripts/discovery/gate_probe_v4.lua.disabled
```

v4 changes only the trigger and adds a baseline section:

- a **wall-clock deadline** (`os.clock`, 600 s) instead of a frame count, so a slow
  title screen cannot exhaust the budget;
- a **state-based gate** that polls `PlayerManager:getMasterPlayer():get_Character()`
  every 30 frames and fires as soon as the player exists;
- logging of each distinct waiting reason and of the moment the player is
  acquired, so a future run proves the trigger worked instead of silently timing out;
- a second section that records `app.ItemDef.isValidItem`, `NameString`, and the
  resolved `Data` fields for IDs `4/98/99/100` as a baseline;
- the same enum and method enumeration as v3, which is known-good.

`os.clock` availability was verified, not assumed: the installed
`_CatLib/utils/timer.lua` and `_CatLib/utils/logger.lua` use it.

It is read-only. No field assignment, no `changeActionRequest`, no item mutation,
no save write.

## How to deploy (only if the user approves a launch)

1. Close the game completely.
2. Copy the project file into the game autorun folder with a `.lua` extension:

```text
from: D:\mhws-eatshit\scripts\discovery\gate_probe_v4.lua.disabled
to:   E:\SteamLibrary\steamapps\common\MonsterHunterWilds\reframework\autorun\mhws_eatshit_gate_probe_v4.lua
```

3. Launch the game and **load a save so the item bar is reachable**. The probe
   fires automatically once the player character exists. It does not need you to
   press anything.
4. Read the results from the framework log:

```text
E:\SteamLibrary\steamapps\common\MonsterHunterWilds\re2_framework_log.txt
```

Search for `mhws-eatshit`.

5. Close the game and roll back (see below) before any other change.

## Exact rollback

1. Close the game.
2. Delete or rename the deployed file so it no longer ends in `.lua`:

```text
E:\SteamLibrary\steamapps\common\MonsterHunterWilds\reframework\autorun\mhws_eatshit_gate_probe_v4.lua
-> mhws_eatshit_gate_probe_v4.lua.disabled
```

3. Confirm no other project file is active in autorun:

```powershell
Get-ChildItem 'E:\SteamLibrary\steamapps\common\MonsterHunterWilds\reframework\autorun' -File -Filter *.lua |
  Where-Object { $_.Name -match 'mhws_eatshit' }
```

Expected result: no output.

No PAK, save, or original archive is touched by this read, so no other rollback
is required.

## Pre-flight checks already completed

- Block structure validated by `tools/rsz_local/check_lua_blocks.py`.
- Identifier and arity sanity validated by `tools/rsz_local/check_lua_sanity.py`.
  That checker is calibrated: it passes all project probes and flags a deliberately
  broken file.
- `os.clock` confirmed in use by installed working mods.
- Every chain step is null-guarded; a failure logs a reason and continues.

## Known limits of this read

- Neither checker is a full Lua parser. No Lua interpreter exists on this machine,
  so complete syntax acceptance cannot be proven statically; only the in-game load
  can confirm it.
- If the player chain still never resolves, v4 reports the last blocking reason and
  fires the baseline section anyway, so the run is not wasted. But the
  instance-method gate values would still be unavailable.
- The comparison item is Secret Potion (public `4`), which returns action type `4`
  while item `98` returns `1`. If `canUseItem` also differs between them, that
  difference is the lead to follow.

