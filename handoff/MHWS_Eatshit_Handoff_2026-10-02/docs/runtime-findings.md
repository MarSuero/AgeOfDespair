# Runtime Findings

## 2026-09-30: Local installation inventory

- `MonsterHunterWilds.exe` reports version `1.42.0.2`.
- Steam manifest `appmanifest_2246340.acf` identifies AppID `2246340`, BuildID `24705561`, and language `schinese`.
- `re2_framework_log.txt` reports REFramework `v1.5.9.1`, game name `mhwilds`, and successful framework initialization/D3D12 hook.
- Existing files include `reframework/autorun/reframework-d2d.lua`, `reframework/plugins/reframework-d2d.dll`, `pak_mods`, and `ModdedByFluffyModManager.txt`.
- The log is dated 2026-09-27. It proves a prior initialized run, not the current session's state.
- No game objects, save data, or game files have been modified by this project.

## Pending read-only probe

`scripts/discovery/load_probe.lua` only emits a one-time log marker when loaded. It must be copied to the game's autorun folder before it can run. No object/API investigation has yet occurred.

## 2026-09-30: Lua API and mod inventory probe

- The probe loaded successfully after a fresh game start.
- `sdk.find_type_definition`, `sdk.get_managed_singleton`, `sdk.hook`, and `re.on_draw_ui` are exposed as Lua functions in this runtime.
- No error line was emitted by this project's probe.
- Existing autorun scripts include `auto_item_buff.lua` and `infinity_consumables.lua`, both of which interact with item data or item use and can affect tests.
- `auto_item_buff.lua` contains independently authored examples using `app.ItemDef`, `app.ItemUtil`, `app.PlayerManager`, `app.HunterStatus`, `sdk.get_managed_singleton`, `sdk.find_type_definition`, and `sdk.hook`. These are evidence of existing local usage, not yet proof that every method is safe for this project.
- `infinity_consumables.lua` edits item `_Infinit` and `_MaxCount` values. It must be disabled for a clean item-behavior baseline.
- The same launch logged pre-existing REFramework scan/integrity messages and JSON parse errors for other mods. They are outside this project and were not changed.

## 2026-09-30: Item data evidence

## 2026-09-30: Runtime item name validation

- `app.ItemDef.NameString(app.ItemDef.ID)` lookup succeeded.
- Runtime item ID `98` resolved to `怪物的粪`.
- Runtime item ID `100` resolved to `滚成球的粪`.
- The item IDs from the pre-existing data file are validated for the current runtime.
- No item property, inventory count, use action, or save data was changed.

## 2026-09-30: Probe timing correction

- A later launch showed `Invoke threw an exception` when `NameString` and `Data` were called immediately on the first frame.
- `isValidItem` still returned `true` for both IDs.
- The earlier successful calls are therefore valid evidence of a working path, but not yet stable evidence across initialization timing.
- The probe is being changed to wait 300 frames before the single combined read-only collection.

## 2026-09-30: Delayed ItemData validation

- After waiting 300 frames, both `NameString` and `Data` resolved successfully.
- Item `98` (`怪物的粪`): `_ItemId=99`, `_SortId=76`, `_Eatable=false`, `_Heal=false`, `_Infinit=false`, `_MaxCount=10`, `get_Type()=0`.
- Item `100` (`滚成球的粪`): `_ItemId=101`, `_SortId=75`, `_Eatable=false`, `_Heal=false`, `_Infinit=false`, `_MaxCount=10`, `get_Type()=0`.
- `isValidItem` returned `true` for both IDs.
- The runtime data uses an internal `_ItemId` offset relative to the public lookup ID. Do not substitute `_ItemId` for the public `app.ItemDef.ID` without further evidence.
- The delayed probe completed without a project-script error.

## 2026-09-30: First feature boundary

- The first feature changes only the runtime `_Eatable` field for public item ID `98`.
- It does not write PAK files, save data, inventory counts, status effects, or Wide-Range behavior.
- The feature script waits 300 frames, records the prior and resulting `_Eatable` value, and logs success or failure.

## 2026-09-30: First feature result

- Setting `_Eatable=true` did not make item `98` appear in the usable item list.
- Local comparison data reports both `怪物的粪` and `回复药` with `get_Type()=0`; this field does not explain the UI labels `调合素材` and `狩猎道具`.
- The deployed patch was disabled and moved to `backups/disabled-dung-make-eatable.lua`.
- The next investigation must compare the complete runtime ItemData field set for IDs `98` and `1` before changing another field.

## 2026-09-30: Item window/category field comparison

- The complete ItemData type contains 39 fields.
- `怪物的粪` and `回复药` both use `_Type=0`.
- `怪物的粪` has `_TextType=5`, `_Window=false`, `_Eatable=false`.
- `回复药` has `_TextType=1`, `_Window=true`, `_Eatable=true`.
- The next reversible test copies only `_TextType`, `_Window`, and `_Eatable` from the known usable item behavior. `_Heal` remains false.

## 2026-09-30: Action probe result

- The player action probe observed ordinary action changes while the item key was pressed, but it did not expose the selected item ID.
- `PlayerItemParam` has 118 fields; the filtered fields did not include a reliable current/selected item field.
- The completed probe was moved to `backups/selected_item_probe.lua`.
- The next investigation target is the method list of the item parameter and item-bar/controller objects, specifically methods that select or request item use. No action ID will be hard-coded before its call path is identified.

## 2026-09-30: Static investigation checkpoint

- Local autorun scripts expose no verified generic `useItem`, `consumeItem`, or item-action function for this feature.
- `PlayerItemParam` exposes parameter getters and item timing data, but the title-screen method inventory did not expose a use request.
- The task-runtime method inventory was not completed because the earlier version could stop before logging when a runtime call failed. Its scripts are now disabled and preserved as `.lua.disabled` files in the game autorun directory.
- No item-use API, action-table mapping, or status-application call is confirmed yet. Do not hard-code the observed Secret Potion action indices.
- Current safe state: only `dung_make_eatable.lua` remains active; the three read-only probes are disabled.

## 2026-09-30: Final task-runtime probe

- A final task-runtime inventory was prepared with per-call protection and a timeout.
- It waits for `MasterPlayer`, `HunterCharacter`, and `BaseActionController` to exist, then logs relevant methods for player, item, and action objects.
- It does not invoke item-use methods, change action IDs, modify item data, or write save data.

## 2026-09-30: Final task-runtime probe result

- The probe timed out after 3600 frames without obtaining `MasterPlayer`, `HunterCharacter`, or `BaseActionController` through the `PlayerManager:getMasterPlayer()` chain.
- This is a failed object-discovery path, not evidence that the objects do not exist in the game.
- The probe was disabled and moved to `backups/task_runtime_inventory.lua`.
- No item-use method, action-table mapping, or status-application method is confirmed.

## 2026-09-30: Static action-request entry

- The pre-existing local `_CatLib/fsm.lua` calls the real method `app.HunterCharacter.changeActionRequest(app.AppActionDef.LAYER, ace.ACTION_ID, System.Boolean)`.
- The same file constructs `ace.ACTION_ID` values through REFramework's native value-type APIs and passes them to the character action request.
- This is confirmed local usage, not a guessed API.
- It proves a possible action-request mechanism, but not the correct item-use action layer or the complete Secret Potion action mapping.
- The previously observed indices `128`, `130`, `131`, and `129` are `cTentSitDown`, `cGetOutTent`, `cTentTea`, and `cGetInTent` in `plcommon_actionid.user.3`; they are not Secret Potion item-use IDs. That old runtime observation is therefore not evidence of a potion action.
- Do not hard-code those indices.

## 2026-09-30: Static consumable-flag correlation

- The local generated `infinity_consumables.json` contains 764 item records.
- Of these, 32 have `Eatable=true`; all 32 also have `IsHeal=true`.
- Item `98` (怪物的粪) has both flags false in the source data.
- This is a strong correlation that `_Heal` participates in the consumable/use pipeline, but it does not prove that setting it on item `98` safely produces the desired action or effect.
- Do not set `_Heal=true` without a controlled test: it could route item `98` into a healing handler or another item-effect path.

## 2026-09-30: Consumable candidate

- The active candidate now tests `_TextType=1`, `_Window=true`, `_Eatable=true`, and `_Heal=true` for item `98`.
- It does not set a heal amount, status, inventory count, or save data.
- This is a diagnostic candidate based on the observed consumable-flag correlation, not a completed feature.
- The single validation must check whether item `98` enters the normal consumable action and whether it causes an unintended healing effect.

## 2026-09-30: Consumable candidate result

- Setting `_Heal=true` together with `_TextType=1`, `_Window=true`, and `_Eatable=true` still produced no item-use action.
- The candidate was disabled and moved to `backups/dung_make_eatable-heal-candidate.lua`.
- ItemData flags alone are insufficient to route item `98` through the normal consumable action pipeline.
- Further field guessing is suspended. The next route is static extraction of the item-use/action parameter data.

## 2026-10-01: RSZ field confirmation

- RSZ decoding with the Wilds type dump succeeded for `itemdata.user.3`.
- Public item `98` maps to the fixed row `_ItemId=99`, `_Index=80`.
- Secret Potion public item `4` maps to `_ItemId=5`, `_Index=6`.
- The target row has `_TextType=5`, `_Window=false`, `_Eatable=false`, `_Heal=false`, `_EnableOnRaptor=false`, `_OutBox=false`.
- The Secret Potion row has `_TextType=1`, `_Window=true`, `_Eatable=true`, `_Heal=true`, `_EnableOnRaptor=true`, `_OutBox=false`.
- The active candidate now applies the complete confirmed consumable-flag set, without changing name, icon, prices, max count, or save data.

## 2026-09-30: Local static-data availability

- The installation has a `natives` tree, but no extracted `natives/stm/GameDesign/Common/ItemData.user.3`, item text table, or action/item data files were found under `natives`.
- Relevant game data remains inside the packed game archives; current local static files are not enough to identify the exact consumable action mapping or Stench application method without a separate archive-extraction workflow.
- A public MHDB Wilds data toolkit documents a static pipeline that extracts `.user.3` and `.msg.23` files from PAKs and converts them to JSON. This route does not require launching the game, but using it locally would require bringing its extractor tooling/data into the workspace.
- The public merged item JSON can help validate item definitions, but it is not yet evidence of the runtime item-use action or Stench application path.

## 2026-09-30: Static extraction inventory

- No local command or tool matching a PAK/RE Engine data extractor was found.
- `pak_mods` contains only unrelated texture/equipment PAKs from existing mods.
- `natives/stm/GameDesign` contains only a small `Equip` prefab subset in this installation; no extracted item or action tables are present.
- Static progress is blocked on obtaining or using an extractor/data dump, not on another in-game startup.

## 2026-09-30: External static-tool references

- `dtlnor/MonsterHunterWildsModding` documents `ree-pak-gui`, RE Tool plus `mhwilds.list`, RE Editor, and REMSG Converter for extracting and inspecting Wilds data.
- `seifhassine/REasy` documents PAK extraction, User/MSG inspection, and MHWilds RSZ/file-list updates.
- `kassent/mhwilds_data` contains item dumps and a Lua script that enumerates item definitions through `app.VariousDataManager`, resolves names, and maps fixed item IDs to public IDs.
- These references make static extraction feasible, but no tool has been installed or executed in this workspace.

## 2026-09-30: REasy source checkout

- A sparse source checkout of REasy was created under `D:\mhws-eatshit\tools\REasy`.
- It recognizes `MHWilds`, supports PAK extraction and RSZ/User/MSG inspection, and points Wilds at `natives/stm`.
- The checkout is source-only at commit `392b3b1bd6d2c5e3befeafb8a7ee9fc25be7f15b`.
- Python/native dependencies were not installed, and no PAK was opened or modified.
- Local Python versions are 3.14, 3.11, and 3.10; REasy documents Python 3.12+.
- Completing the extractor setup is blocked on obtaining a supported Python runtime and the full REasy resource/build tree. This is a tooling blocker, not a game-runtime blocker.

## 2026-09-30: Wilds archive targets identified

- `tools/REE.PAK.Tool/Projects/MHWs_STM_Release.list` is available locally.
- The list confirms concrete item, player-action, `PlayerItemParam`, and `plc_itemuse` resources inside the official archives.
- `7z` cannot read these PAKs as ordinary archives; a RE Engine PAK reader is required.
- A project-local Python 3.12 environment could not install `zstandard` and `mmh3` because package download was blocked by environment policy. No workaround or system install was attempted.

## 2026-09-30: PAK reader source status

- `tools/REE.PAK.Tool/REE.Packer` is present locally and contains the PAK reader, Murmur3, and Zstandard implementations.
- The project targets .NET Framework 4.7.2; no matching reference assemblies are installed on this machine.
- `dotnet build` cannot compile the legacy project, and no prebuilt binary was downloaded because the package-download proxy rejected the request.
- No PAK content has been modified; extraction remains read-only once a compatible binary is available.

## 2026-09-30: Filtered PAK extraction completed

- Installed the Microsoft .NET Framework 4.7.2 Developer Pack targeting pack.
- Built `REE.Unpacker` successfully at `tools/REE.PAK.Tool/REE.Unpacker/REE.Unpacker/bin/Release/REE.Unpacker.exe`.
- Added a local `REE_UNPACK_FILTER` filter to the project copy so only requested entries are extracted.
- Extracted the base PAK targets into `D:\mhws-eatshit\extracted\base`, including `itemdata.user.3`, `autousehealthitemdata.user.3`, `autousestatusitemdata.user.3`, `playeritemparam.user.3`, common action ID/param files, and `plc_itemuse` motion resources.
- No game archive was modified.
- The files are RSZ/User binary data; the next step is RSZ decoding and field comparison, not another game launch.

## 2026-09-30: ItemData access validation

- `app.ItemDef.Data(app.ItemDef.ID)` lookup succeeded.
- Item IDs `98` and `100` both returned managed ItemData objects.
- `app.ItemDef.isValidItem(app.ItemDef.ID)` returned `true` for both IDs.
- The next probe reads only fields already used by the pre-existing local item-data script; it does not write them.

- The generated `reframework/data/infinity_consumables.json` contains `怪物的粪` with item ID `98`.
- The same data contains `滚成球的粪` with item ID `100`.
- Both entries report item type `0`, `Eatable: false`, and maximum count `10`.
- This is strong local evidence for the item IDs, but the JSON was generated by a pre-existing mod. The next read-only runtime probe validates the names through `app.ItemDef.NameString(app.ItemDef.ID)` before any implementation work.

## 2026-09-30: BTable item-action mapping

- Read-only extraction added the common player BTable files:
  - `gamedesign/player/actiondata/common/btable/common.user.3`
  - `common_pack.user.3`
  - `commonorderbank.user.3`
  - `commonorderlist.user.3`
  - `commonsub.user.3`
  - `commonsub_pack.user.3`
  - `commonsuborderbank.user.3`
- `commonsub_pack.user.3` contains concrete `app.btable.PlCommand.cUseItemJudgeCaseArg` records whose `ITEM_ACTION_TYPE_Fixed` values resolve through `plcommonsub_actionid.user.3`:
  - `1` -> `cUseDrinkItem`
  - `3` -> `cUseTabletItem`
  - `2` -> `cEatMeat`
  - `5` -> `cUsePowderItem`
- The value `0x771B0780` also appears in the sub-action pack, but it is reused in different no-use/use groups and must not be treated as a generic drink/tablet type without the surrounding BTable row context.
- `common_pack.user.3` maps other action types to `cUseItemBonfire`, `cUseItemBarrelBombL`, `cUseItemToishi`, `cUseItemTrap`, `cUseItemBarrelBombS`, `cUseItemTrapMeat`, and `cUseItemModoridama`.
- The four `cUseItemJudgeCaseArg` records in `common.user.3` point to `cDamageSticky*` and `cDamageFrozen*` action GUIDs; they are shared definitions, not the consumable drink mapping.
- The decoded `app.user_data.ItemData.cData` type has no item-action-type field. Action classification is therefore external to `itemdata.user.3` and cannot be completed by copying more ItemData flags.
- `commonorderlist.user.3` is identified as `ace.btable.user_data.BTableOrderList`, but the current local RSZ parser reaches the final data block at offset `30404` and then requests four bytes past the file. Its command-factory/order-hash arrays remain unresolved.
- No direct mapping for fixed Item ID `99` has been confirmed yet. Do not build or deploy a candidate from the action-type values alone.

The read-only summarizers and report are preserved at:

- `tools/rsz_local/inspect_item_use.py`
- `tools/rsz_local/summarize_use_item_cases.py`
- `analysis/use_item_cases.json`

## 2026-09-30: Patch-014 comparison

- The current install's `re_chunk_000.pak.patch_014.pak` contains updated copies of `itemdata.user.3`, `common.user.3`, and `common_pack.user.3`.
- Patch-014 still leaves fixed row `_ItemId=99` with `_TextType=5`, `_Window=false`, `_Eatable=false`, and `_Heal=false`.
- Patch-014 adds more `cUseItemJudgeCaseArg` records, but its `cItemIDJudgeCaseArg` values remain `9`, `10`, `11`, and `13`; no fixed Item ID `99` row was found.
- The base `commonsub_pack.user.3` remains the source that explicitly resolves action types `1`, `2`, `3`, and `5` to the normal sub-actions.
- The patch comparison therefore rules out a stale-base explanation for the missing Item `99` mapping.

Additional read-only artifacts:

- `tools/rsz_local/inspect_orderlist.py`
- `analysis/commonorderlist_usejudge.json`
- `analysis/patch014_use_item_cases.json`
- `scripts/discovery/hunter_item_action_table_inventory.lua.disabled`

## 2026-09-30: GetRank candidate validation

- Static analysis of patch-014 found 32 native consumable rows. Every one has `_Window=true`, `_Eatable=true`, `_Heal=true`, `_EnableOnRaptor=true`, and `_GetRank=[0,0]`.
- Fixed row `_ItemId=99` was the only row-level outlier on `_GetRank`, with `[1,1]`.
- A standalone candidate copied the common consumable flags and changed only `_GetRank` to `[0,0]`.
- The candidate was packed, round-tripped through the local PAK tool, installed as `z9999_mhws_eatshit_getrank_candidate.pak`, and the REFramework integrity log confirmed that the game loaded it.
- Pressing the item-use key still produced no use action. The candidate was renamed to `.pak.disabled` after the test.
- This rules out both PAK deployment failure and `_GetRank` as the sole missing gate. Further blind ItemData flag copying is suspended.

## 2026-10-01: Residual config check

- `reframework/data/infinity_consumables.json` is present and reports `Enabled=true`, but the current autorun tree contains no matching `infinity_consumables` or `auto_item_buff` script.
- Its item-98 entry remains `Eatable=false`; because no loader script is present, this file is not confirmed to affect the failed PAK test.
- The failed candidate therefore remains attributable to an unresolved native availability/use gate, not to a proven competing Lua hook.

## 2026-09-30: Static icon-type candidate

- Across the 32 native consumable rows, `_IconType` only uses `10`, `13`, `15`, `37`, `43`, `71`, and `72`.
- Fixed row `_ItemId=99` uses `_IconType=40`, the only remaining static ItemData value outside the consumable icon set.
- A second project-only candidate copies `_IconType=13` from Secret Potion while retaining the confirmed consumable flags and `_GetRank=[0,0]`.
- The candidate is packed and round-trip verified at:
  - `candidates/dung_icontype_candidate.pak`
- It is not installed or deployed. No further launch is scheduled until the static review decides this is justified.

## 2026-10-01: Use-path trace v5

- The state trigger acquired the player at 81.8 seconds and installed hooks successfully for `app.HunterCharacter.canUseItem`, `app.GUIManager.requestUseItem`, and `app.GUIManager.onPlEquipChange()`.
- The attempted session produced one `onPlEquipChange()` call when the selected item/equipment changed.
- No `requestUseItem`, `useItem`, `successItem`, or `onSuccessItem` call was observed.
- No project state was mutated; the probe was disabled immediately after the run.
- The failure is upstream of the request path, or the selected-item state was not exposed by the probe. This does not justify another ItemData or PAK candidate.

## 2026-10-01: Use-path trace with ACTION_ID decoding

- The trace acquired the player and installed the read-only hooks successfully.
- Secret Potion use produced the expected action sequence: bank 0, indices `128 -> 130 -> 131 -> 129`.
- No distinct action sequence followed the Monster Dung use attempt; the trace only showed ordinary item/character actions afterward.
- `requestUseItem`, `receiveGuiActionMessage`, and `sendMessageToPL` produced no trace entries during the session.
- This confirms the normal use request reaches `changeActionRequest` for Secret Potion but does not reach it for item 98.
- The failure is before action selection for item 98. ItemData flags and `canUseItem` are already excluded.
- The trace probe is disabled and retained as `mhws_eatshit_use_path_trace_v5.lua.disabled`.

## 2026-10-01: Use-path trace v6

- The combined trace acquired `app.mcHunterItem` through `HunterCharacter:get_Item()`.
- The item object exposes `_ItemRequestMsg`, `_DisabledItemID`, and `_DisabledItemIDLock` fields.
- It also exposes methods `canUseItem`, `notUseItem`, `checkNotUseItem_ItemWide`, `checkNotUseItem_ItemWide_NearOtherPl`, and `addDisabledItem`.
- `set_UsedItemID` and `requestUseItem` hooks installed, but no calls were observed during the comparison session.
- `changeActionRequest` continued to show normal action traffic, but no item-use-specific request appeared for item 98.
- This is the first direct runtime evidence of an item-side disabled-item/request-message subsystem. The next static/runtime target is `_DisabledItemID` and `_ItemRequestMsg`, not ItemData flags.
- The v6 probe is disabled and retained as `mhws_eatshit_use_path_trace_v6.lua.disabled`.
