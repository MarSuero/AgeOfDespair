# MHWS Eatshit Project Handoff

Updated: 2026-10-01 23:55

## Goal

Make public item ID `98` (`怪物的粪`) enter the game's normal item-use flow, then apply the existing `恶臭` effect, and only afterward investigate Wide-Range.

## Environment

- Game: Monster Hunter Wilds Steam PC
- Install: `E:\SteamLibrary\steamapps\common\MonsterHunterWilds`
- Game version: `1.42.0.2`
- REFramework: `v1.5.9.1`
- Public item `98`: `怪物的粪`
- Public item `100`: `滚成球的粪`
- Public item `4`: `秘药`
- Public item `98` resolves at runtime to ItemData row `_ItemId=99`
- Public item `4` resolves to row `_ItemId=5`

## What Is Proven

- Changing ItemData fields can move item 98 into the item bar, but cannot make it execute the normal use flow.
- Copying the consumable flags from Secret Potion did not fix use.
- A candidate PAK was actually loaded by REFramework and still failed.
- `app.HunterCharacter.canUseItem(4)` returns `true`.
- `app.HunterCharacter.canUseItem(98)` returns `true`.
- `app.HunterItemActionTable.getItemActionTypeFromItemID(98)` returns action type `1`.
- BTable action type `1` maps to `cUseDrinkItem`.
- Secret Potion produces `changeActionRequest` actions; item 98 produces no corresponding use action.
- `set_UsedItemID` is never called for the item 98 attempt.
- `app.mcHunterItem` is the actual item subsystem. Its confirmed fields/methods include:
  - `_ItemRequestMsg`
  - `_DisabledItemID` (`HashSet<int>`)
  - `_DisabledItemIDLock`
  - `canUseItem`
  - `notUseItem`
  - `checkNotUseItem_ItemWide`
  - `checkNotUseItem_ItemWide_NearOtherPl`
  - `addDisabledItem`

## Current Conclusion

The failure is before normal action selection, inside the `mcHunterItem` request/disabled-item path or the UI input path. Do not make more ItemData or icon/PAK guesses.

## Current Files

- Read-only probes are all disabled.
- The last failed runtime bridge is disabled:
  `E:\SteamLibrary\steamapps\common\MonsterHunterWilds\reframework\autorun\mhws_eatshit_dung_use_bridge.lua.disabled`
- Failed PAK candidate is disabled:
  `E:\SteamLibrary\steamapps\common\MonsterHunterWilds\pak_mods\z9999_mhws_eatshit_getrank_candidate.pak.disabled`
- Extracted RSZ data:
  `D:\mhws-eatshit\extracted\base`
- RSZ parser and Wilds dump:
  `D:\mhws-eatshit\tools\rsz_local`
- Analysis:
  - `analysis/gate_probe_v4_results.md`
  - `analysis/native_gate_static_evidence.md`
  - `analysis/stench_mechanism_map.md`
  - `analysis/use_item_cases.json`
  - `analysis/patch014_use_item_cases.json`

## Next Implementation

Do not ask the user to launch another probe immediately.

1. Use static/runtime evidence to identify the `mcHunterItem` request path.
2. Prefer a small native REFramework DLL if Lua cannot safely intercept the request.
3. The first implementation must only route item 98 into the existing drink action.
4. Do not implement `恶臭` or Wide-Range until normal item use is confirmed.
5. Keep every candidate isolated and reversible.

## Hard Rules

- Do not guess method signatures.
- Do not hard-code unverified action IDs.
- Do not modify original PAK archives or saves.
- Do not leave probes or candidates active after a test.
- Do not make the user repeat low-value diagnostic launches.

## New Chat Prompt

Read this file first, then `PROJECT_STATUS.md`, `DEPLOYMENT_STATUS.md`, and `CHECKSUMS.txt`.

Continue from the current evidence. Do not repeat old probes. Do not change ItemData again. Locate the `app.mcHunterItem` request/disabled-item path and implement the smallest evidence-backed bridge for item 98. Prefer static analysis or a native REFramework DLL over another Lua guessing loop. Only request one game validation after a concrete candidate is ready.

## Latest Handoff: 2026-10-01 23:55

### User decision

Pause this project. Do not deploy or launch anything until the user explicitly
resumes it.

### What is currently proven

- Runtime ItemData fields can move public item `98` into `狩猎道具`.
- `canUseItem(98)` is `true`.
- `notUseItem(98)` can be bypassed with a native REFramework hook.
- The current item-98 action visibly plays a drink-like animation. The user
  accepts that behavior for now and does not want it changed.
- Overriding the action type to `2` (`cEatMeat`) was prepared, but the user
  accepted the existing drink-like behavior instead. Do not revisit this unless
  explicitly requested.
- `set_UsedItemID(98)` never fires for the current item-98 action.
- A hook on `set_UsedItemID` therefore cannot trigger the status effect.
- The first action-end candidate hooked
  `cHunterSubActionBase.isSubActionEnd` for
  `cUseDrinkItem`, but the user reported that player stench still did not
  activate. Its logs must be reviewed before any new candidate.

### Correct meaning of 恶臭

This is the **player-side** status applied by 桃毛兽王/Congalala:

- `app.HunterBadConditions.cStench`
- `cHunterStatus.get_BadConditions()`
- `cHunterBadConditions._Stench` at field offset `24`
- `cStench.requestActivate()`
- `cStench.cure()`
- `checkAndCureConditions(...)`, `deactivateAllConditions()`,
  `onWaterWash()`
- `HunterCharacter.checkSkillStench` exists in the executable string pool and
  is the item-use restriction path
- `BAD_CONDITION.STENCH` exists in both `BAD_CONDITION` and
  `BAD_CONDITION_Fixed`

Do not use the unrelated monster-side `cEnemyBadConditionKoyasi`; that means
repel/drive-away and is not the requested effect.

### Current filesystem safety

- All project Lua and DLL files have been removed from the game directory.
- No project PAK is active.
- The built candidates remain only under `D:\mhws-eatshit\native_bridge\build-manual`.
- Current important candidates:
  - `mhws_eatshit_item98_notuse_bridge.dll`
  - `mhws_eatshit_item98_eat_action_bridge.dll`
  - `mhws_eatshit_item98_stench_bridge.dll`
  - `mhws_eatshit_item98_action_end_stench_bridge.dll`

### Next agent prompt

Read `HANDOFF_NEW_CHAT.md`, `PROJECT_STATUS.md`, `DEPLOYMENT_STATUS.md`, and
`CHECKSUMS.txt` first. The user has paused work and does not want another
launch now.

When the user resumes, inspect the logs from the last
`mhws_eatshit_item98_action_end_stench_bridge.dll` run before writing more
code. Determine whether `cHunterSubActionBase.isSubActionEnd` was actually
hooked and whether the `cUseDrinkItem` receiver type matched. Do not assume
that the current drink-like animation means the sub-action object is
`app.PlayerCommonSubAction.cUseDrinkItem`.

The accepted item behavior is the existing drink-like animation. Do not change
it to `cEatMeat` unless the user asks. The only requested next feature is the
player-side Congalala-style `cStench` status, activated after a real item-98
success boundary and still removable by the native deodorant path.

Avoid another runtime launch until a concrete, log-backed completion hook is
ready. Prefer static analysis of `successItem`, `onSuccessItem`,
`isSubActionEnd`, action-layer transitions, and the existing item-success
message path. Every candidate must be reversible, and every repository change
must be committed with tests/checks and synchronized checksums.
