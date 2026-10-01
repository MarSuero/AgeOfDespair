# Deployment Status

Generated: 2026-10-01

Game:

- Install: `E:\SteamLibrary\steamapps\common\MonsterHunterWilds`
- REFramework autorun: `E:\SteamLibrary\steamapps\common\MonsterHunterWilds\reframework\autorun`
- Game version: `1.42.0.2`
- REFramework: `v1.5.9.1`

Project deployment:

- `dung_make_eatable.lua`: NOT ACTIVE.
- Read-only probes: disabled. Any remaining probe files have `.lua.disabled` suffix.
- Candidate PAK tested and disabled:
  - `E:\SteamLibrary\steamapps\common\MonsterHunterWilds\pak_mods\z9999_mhws_eatshit_getrank_candidate.pak.disabled`
  - Source: `D:\mhws-eatshit\candidates\dung_getrank_itemdata.pak`
  - Scope: fixed ItemData row `_ItemId=99`; copies the confirmed consumable flags and `_GetRank=[0,0]`.
- No original game archive has been modified.
- No save data has been modified.
- Result: PAK loaded successfully, but pressing the item-use key produced no use action.
- No status-effect or Wide-Range behavior is included in this candidate.

Verified on 2026-10-01 (read-only inspection):

- The autorun directory contains no active project `.lua` file. All six project
  probe files exist only with a `.lua.disabled` suffix:
  `item_action_probe`, `item_method_inventory`,
  `mhws_eatshit_hunter_item_action_table_inventory`,
  `mhws_eatshit_hunter_item_action_type_probe`,
  `mhws_eatshit_item_use_readonly_checks`, `mhws_eatshit_load_probe`.
- `pak_mods` contains no active project PAK. Only eight unrelated pre-existing
  mod PAKs (`x0000`..`x0007`) plus the disabled project candidate are present.
- The 2026-10-01 02:57 framework run independently confirms the candidate load:
  the log caches `z9999_mhws_eatshit_getrank_candidate.pak` and redirects
  `re_chunk_000.pak.sub_000.pak.patch_026.pak` onto it.
- That same log lists exactly eight loaded autorun scripts, none from this
  project, and contains zero `mhws-eatshit` lines. This matches the disabled
  state above and is not evidence of probe failure.
- The game was not running during this inspection.

Prepared but NOT deployed:

- `scripts/discovery/item_use_readonly_checks_v2.lua.disabled`
  - Corrected read-only gate probe. Deployment and rollback steps:
    `docs/readonly_runtime_read_plan.md`.
- `native_bridge/`
  - `Item98Bridge.cpp` and `CMakeLists.txt` are prepared but unbuilt and
    undeployed.
  - The bridge only reads REFramework TDB metadata for `app.mcHunterItem` and
    `app.HunterCharacter`; it installs no hooks and mutates no game state.
  - The behavioral bridge remains blocked until a real request-gate address and
    signature are recovered.
  - This host has no CMake or C++ compiler on `PATH`, so no DLL artifact exists.
  - `native_bridge/build.ps1` is the only supported local build entry point.
  - `native_bridge/build-llvm-mingw.ps1` is the fallback entry point used to
    produce the current static x64 DLL. The DLL remains outside the game
    plugin directory.

Known pre-existing autorun files:

- `item_action_probe.lua.disabled`
- `mhws_eatshit_load_probe.lua.disabled`

Manual rollback:

1. Do not delete the project backups.
2. The tested candidate is already disabled as `z9999_mhws_eatshit_getrank_candidate.pak.disabled`.
3. If a future candidate is enabled, close the game and move its `.pak` out of `pak_mods`.
4. If a project Lua file appears in `autorun`, move it out of `autorun`.
5. Do not restore old candidates without checking `PROJECT_STATUS.md`.

- `use_path_trace_v5.lua`: deployed for one trace run, then disabled and retained as `.lua.disabled`.
