# MHWS Eatshit Mod Project Status

## Goal

Create a PC mod for Monster Hunter Wilds:

1. Make item `怪物的粪` usable through the game's normal item-use flow.
2. After use, apply the existing `恶臭` status.
3. Allow the effect to work through Wide-Range where the game's normal pipeline supports it.

Constraints:

- Prefer runtime Lua/REFramework.
- No core PAK/save modification unless explicitly justified.
- Every change must be reversible.
- Do not guess APIs or hard-code unverified action IDs.
- Test one small behavior at a time.

## Verified Baseline

- Install path: `E:\SteamLibrary\steamapps\common\MonsterHunterWilds`
- Platform: Steam PC
- AppID: `2246340`
- Steam BuildID: `24705561`
- Executable version: `1.42.0.2`
- Language: Simplified Chinese
- REFramework: `v1.5.9.1`
- REFramework Lua loading works.

## Verified Item Facts

- Public item ID `98`: `怪物的粪`
- Public item ID `100`: `滚成球的粪`
- Runtime `app.ItemDef.NameString` resolves both names.
- Runtime `app.ItemDef.Data` and `isValidItem` work after initialization delay.
- Runtime data uses an offset:
  - public ID `98` maps to RSZ row `_ItemId=99`
  - public ID `100` maps to RSZ row `_ItemId=101`

RSZ item data:

- Secret Potion, fixed `_ItemId=5`:
  - `_TextType=1`
  - `_Window=true`
  - `_Eatable=true`
  - `_Heal=true`
  - `_EnableOnRaptor=true`
  - `_OutBox=false`
- Monster dung, fixed `_ItemId=99`:
  - `_TextType=5`
  - `_Window=false`
  - `_Eatable=false`
  - `_Heal=false`
  - `_EnableOnRaptor=false`
  - `_OutBox=false`

## Completed Experiments

### Successful

Changing runtime fields:

```text
_TextType=1
_Window=true
_Eatable=true
```

makes item `98` appear in the item bar under `狩猎道具`.

### Failed

The following did not make the item enter the normal use action:

- `_Eatable=true` alone
- `_TextType=1`, `_Window=true`, `_Eatable=true`
- The above plus `_Heal=true`

The last candidate was disabled and backed up. Do not deploy speculative broader flag changes without explicit confirmation.

## Action Findings

Earlier action probe changes:

```text
bank=0 index=128
bank=0 index=130
bank=0 index=131
bank=0 index=129
```

Static cross-check now identifies these indices as tent actions (`cTentSitDown`, `cGetOutTent`, `cTentTea`, `cGetInTent`), not Secret Potion use. They are discarded as item-use evidence and must not be hard-coded.

Verified local action API from an existing mod:

```text
app.HunterCharacter.changeActionRequest(
    app.AppActionDef.LAYER,
    ace.ACTION_ID,
    System.Boolean
)
```

RSZ action classes include:

- `cUseDrinkItem`
- `cUseTabletItem`
- `cUsePowderItem`
- `cUseItemToishi`
- `cUseItemTrap`

The normal item-use route likely selects among these sub-actions through separate item/action configuration. The exact item-to-sub-action selection condition is still unresolved.

Decoded BTable mapping now confirms the action-type layer:

- `ITEM_ACTION_TYPE_Fixed=1` -> `cUseDrinkItem`
- `ITEM_ACTION_TYPE_Fixed=3` -> `cUseTabletItem`
- `ITEM_ACTION_TYPE_Fixed=2` -> `cEatMeat`
- `ITEM_ACTION_TYPE_Fixed=5` -> `cUsePowderItem`

This does not yet identify the action type selected for fixed item row `99`. The item data record itself has no action-type field; the remaining source is the BTable order/row configuration or the runtime `HunterItemActionTable`.

RSZ decoding confirms the player sub-action classes `cUseDrinkItem` and `cUseTabletItem`. The exact item-to-sub-action selection condition remains unknown.

## Extracted Game Data

Official PAK files were read-only extracted with a locally compiled `REE.Unpacker`.

Tool:

```text
D:\mhws-eatshit\tools\REE.PAK.Tool\REE.Unpacker\REE.Unpacker\bin\Release\REE.Unpacker.exe
```

Extracted data:

```text
D:\mhws-eatshit\extracted\base
```

Important files:

```text
natives/stm/gamedesign/common/item/itemdata.user.3
natives/stm/gamedesign/common/item/autousehealthitemdata.user.3
natives/stm/gamedesign/common/item/autousestatusitemdata.user.3
natives/stm/gamedesign/player/actiondata/common/action/plcommon_actionid.user.3
natives/stm/gamedesign/player/actiondata/common/action/plcommon_actionparam.user.3
natives/stm/gamedesign/player/actiondata/common/action/plcommonsub_actionid.user.3
natives/stm/gamedesign/player/actiondata/common/action/plcommonsub_actionparam.user.3
natives/stm/gamedesign/player/actiondata/common/globalparam/playeritemparam.user.3
natives/stm/motion/player/common/plc_itemuse/*
natives/stm/motion/player/common/plc_itemuse_tree/*
natives/stm/system/systemsetting/itemsettingdata.user.3
```

## Local Parsing Tools

- `.NET Framework 4.7.2 Developer Pack` installed.
- `REE.Unpacker` compiled successfully.
- Python 3.12 project environment:

```text
D:\mhws-eatshit\.venv312
```

- Installed Python packages:
  - `zstandard`
  - `mmh3`

- Local RSZ parser sources:

```text
D:\mhws-eatshit\tools\rsz_local
```

- Wilds RSZ dump:

```text
D:\mhws-eatshit\tools\rsz_local\resources\data\dumps\rszmhwilds.json
```

The parser successfully decodes the extracted item data, automatic-use parameter files, PlayerItemParam, and player action ID files. The extracted data is under `D:\mhws-eatshit\extracted\base`.

## Current Project Files

- `scripts/feature/dung_make_eatable.lua`
  - Local candidate source.
  - The deployed copy is currently not guaranteed active; check the game `autorun` directory before testing.
- `scripts/discovery/gate_probe_v4.lua.disabled`
  - Corrected read-only gate probe with a state-based trigger. Not deployed.
- `scripts/discovery/gate_probe_v3.lua.disabled`
  - Previous probe. Ran 2026-10-01 12:07; kept as a comparison artifact.
- `analysis/gate_probe_v3_results.md`
  - What that run established and why it missed `canUseItem`.
- `analysis/gate_probe_v3_output.txt`
  - The extracted 100-line probe output.
- `docs/logs/gate_probe_v3_run_20261001_1207.txt`
  - Full framework log from that run.
- `docs/readonly_runtime_read_plan.md`
  - Deployment and rollback steps for the next read.
- `analysis/native_gate_static_evidence.md`
  - Binary-level gate evidence from the 2026-10-01 static pass.
- `analysis/stench_mechanism_map.md`
  - Static type map of the `恶臭` mechanism. Pre-research only; nothing implemented.
- `tools/rsz_local/check_lua_blocks.py`, `tools/rsz_local/check_lua_sanity.py`
  - Probe validators (block structure; identifiers and arity).
- `tools/rsz_local/dump_autouse.py`
  - Read-only dumper for the auto-use item tables.
- `docs/technical-survey.md`
  - Technical route and risk record.
- `docs/runtime-findings.md`
  - Chronological investigation findings.
- `backups/`
  - Disabled probes and failed candidates.
- `extracted/candidate/itemdata.user.3`
  - Locally generated RSZ candidate with consumable flags copied from Secret Potion for fixed row `_ItemId=99`.
  - Not deployed to the game.

## Safe Current State

- No PAK archive has been modified.
- No save data has been modified.
- All investigation probes should remain disabled.
  - Verified on 2026-10-01: the autorun directory contains no active project
    `.lua` file. All six project probes are present only with a `.lua.disabled`
    suffix.
  - Verified on 2026-10-01: `pak_mods` contains no active project PAK; the tested
    candidate exists only as
    `z9999_mhws_eatshit_getrank_candidate.pak.disabled`.
- The first normal-use candidate was tested from `pak_mods` and is now disabled.
- The candidate did not include `恶臭` or Wide-Range changes.
- The first launch-worthy `_GetRank=[0,0]` candidate was loaded by the game but still produced no use action. It is now disabled and retained as a rollback artifact.
- The framework log independently confirms that load: it caches and redirects
  `z9999_mhws_eatshit_getrank_candidate.pak` onto patch_026.

## Next Task

The first ItemData candidate loaded but still did not use. Static review found one remaining consumable-only ItemData outlier, `_IconType=40` versus the consumable set; a second project-only icon-type candidate is ready but not deployed. Do not launch it yet.

## 2026-10-01: Native bridge boundary

- Static inspection of the local Wilds RSZ dump confirms that `app.mcHunterItem`
  has no field or method metadata in the dump.
- The executable string heap exposes names such as `_ItemRequestMsg`,
  `_DisabledItemID`, `canUseItem`, and `addDisabledItem`, but not declaring
  types, native addresses, signatures, or call relationships.
- No REFramework native-plugin SDK, import library, PDB, or local disassembler
  is available in this workspace.
- A guessed DLL hook would violate the handoff rules. No DLL was created or
  deployed, and the disabled Lua candidates remain untouched.
- The official REFramework SDK is now available at `tools/REFramework-sdk`.
  `native_bridge/Item98Bridge.cpp` is an unbuilt, un-deployed, read-only
  metadata bridge that can report real TDB method signatures and addresses
  without inventing native call conventions.
- The current host has no CMake or C++ compiler on `PATH`; source-layout
  validation passes, but no DLL artifact can be produced locally yet.
- `native_bridge/build.ps1` now provides the reproducible Windows build entry
  point and fails explicitly when CMake or the SDK is unavailable.
- LLVM-MinGW was installed as a fallback toolchain. The read-only bridge now
  builds as an x64 statically linked DLL; the artifact exports the two
  REFramework plugin entry points and has not been deployed.
- A single successful runtime metadata capture closed the native-signature
  blocker. Exact `mcHunterItem` fields, methods, managed parameter types, and
  current-build addresses are recorded in
  `analysis/mc_hunter_item_runtime_metadata_20261001.md`.
- The temporary metadata DLL was removed after capture. The next candidate is a
  narrowly scoped hook of `notUseItem(app.ItemDef.ID)`; it must verify the hook
  argument layout before skipping the gate for public item `98`.
- The official REFramework HookManager source confirms the hook argument layout:
  for this instance method, `[0]` is VM context, `[1]` is `this`, and `[2]` is
  the `app.ItemDef.ID` value. The first behavior candidate is implemented in
  `native_bridge/Item98NotUseBridge.cpp`, but remains undeployed.
- The first behavior validation confirmed the gate hook installed but never
  received item `98`, because the item remained under `调合素材`. The next
  candidate combines the previously verified runtime category field bridge with
  the native `notUseItem(98)` bypass.
- The combined validation succeeded on both prerequisites: 98 appeared under
  `狩猎道具`, and `notUseItem(98)` returned `false`. The use key still
  produced no action. This closes the category and disabled-gate hypotheses;
  the remaining target is `_ItemRequestMsg` / `receiveGuiActionMessage` request
  generation and dispatch.
- Goal correction from the user: the desired action is `cEatMeat`, not
  `cUseDrinkItem`. Action type `2` is already verified to map to `cEatMeat`.
  `native_bridge/Item98EatActionBridge.cpp` is the next candidate and
  overrides only item 98's action-type result to `2`.
- User correction: the requested effect is the player-side
  `app.HunterBadConditions.cStench` caused by 桃毛兽王, not monster repelling.
  Static executable strings identify `requestBadCondition`, `cureBadCondition`,
  `checkSkillStench`, `STENCH`, `PL_DEBUF_STENCH`, `MODORIDAMA`, and
  `CleanBadConditions`. The read-only bridge now targets hunter status types;
  no status effect is implemented or deployed.
- Runtime metadata also confirms `HunterCharacter.get_HunterStatus()` returns
  `app.cHunterStatus`, while the bad-condition container indexes
  `cStench` through `get_Item(app.HunterDef.BAD_CONDITION)`. The next read only
  adds `cHunterStatus` and both bad-condition enum types to recover the receiver
  path and `STENCH` numeric value.
- The read-only boundary check is
  `tools/rsz_local/verify_mc_hunter_item_evidence.py`; its required result is
  `mcHunterItem evidence boundary: PASS`.

The next implementation prerequisite is concrete native evidence: a stable
request-gate address/signature, public-versus-fixed item-ID handling, and the
lock scope around `_DisabledItemID`. Until then, do not launch another probe or
mutate the disabled-item set.

### Runtime reads executed on 2026-10-01

Two read-only runtime probes were run. Full results:
`analysis/gate_probe_v3_results.md`, `analysis/gate_probe_v4_results.md`.

**v3 (12:07)** fired on a frame count while the game was still initialising, so
`getMasterPlayer()` returned nil and the instance-method values were missed. It
still established the enum members and which names exist on which types.

**v4 (12:29)** used a state-based trigger, fired correctly at 88.1 s, and measured
the method v3 missed. Headline result:

```text
canUseItem id=4   -> true    (Secret Potion, control)
canUseItem id=98  -> true    (怪物的粪)
canUseItem id=100 -> true
```

**`app.HunterCharacter.canUseItem` does not reject item 98.** The failure is
downstream of the availability check.

Runtime identity was also confirmed: `NameString(98) = 怪物的粪` and
`Data(98)` resolves to `_ItemId=99, _SortId=76`. Probing ID `99` reaches an
internal `#Rejected#` placeholder, not a dung variant.

### Excluded by direct measurement

```text
ItemData flags    - copying them all changed nothing
Item identity     - 98 resolves to the real 怪物的粪
Action type       - returns 1; type 1 maps to cUseDrinkItem
canUseItem        - returns true for 98
isAvailableItem   - returns nil for everything; not discriminating
PAK deployment    - earlier candidate was confirmed loaded
```

The failing layer is the **selection/trigger path that turns a use request into an
action**, or the UI/pouch category gate — not the availability gate.

### Prepared next step (needs separate approval)

Instrument the actual use attempt rather than reading state: hook the item-use
entry points and log what happens when the use key is pressed with item 98
selected, comparing against Secret Potion in the same session. This is a different
probe shape (hook plus user action) and needs its own plan.

Preferred order:

1. Plan and run the use-attempt trace above.
2. Recover the missing condition from that evidence without guessing signatures.
3. Only if a new evidence-backed candidate exists, generate a standalone PAK and
   test once.
4. Only after normal use works, implement `恶臭` (mechanism map in
   `analysis/stench_mechanism_map.md`).
5. Investigate Wide-Range last.
