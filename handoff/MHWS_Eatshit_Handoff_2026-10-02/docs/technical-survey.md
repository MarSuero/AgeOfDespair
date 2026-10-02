# Technical Survey

## Verified local baseline

- Platform: Steam PC
- Steam AppID: 2246340
- Steam BuildID: 24705561
- Game executable: `E:\SteamLibrary\steamapps\common\MonsterHunterWilds\MonsterHunterWilds.exe`
- Executable file and product version: 1.42.0.2
- Game language: Simplified Chinese
- REFramework log reports tag `v1.5.9.1`, game name `mhwilds`, and `REFramework initialized`
- Existing `pak_mods`, Fluffy Mod Manager marker, and REFramework autorun content were present before this project

## Read-only runtime investigation

The runtime also resolved `app.ItemDef.NameString(app.ItemDef.ID)` successfully: ID `98` is `怪物的粪`, and ID `100` is `滚成球的粪`.

`app.ItemDef.Data(app.ItemDef.ID)` and `app.ItemDef.isValidItem(app.ItemDef.ID)` also resolved successfully. Both target IDs returned managed data objects and were valid according to the runtime.

After a 300-frame delay, the runtime reported both target items as non-eatable, non-healing, finite-count items with maximum count 10 and type 0. The returned data objects expose `_ItemId` values 99 and 101 while public lookup IDs are 98 and 100; this offset is recorded but not yet explained.

The first probe is intentionally limited to a one-time log marker. It does not inspect or mutate game objects. A successful marker confirms that this project's Lua file loaded; it does not establish that item or status APIs are known.

The probe loaded successfully on 2026-09-30. The runtime exposed the documented Lua entry points `sdk.find_type_definition`, `sdk.get_managed_singleton`, `sdk.hook`, and `re.on_draw_ui`.

The installation contains pre-existing item-affecting scripts. Tests involving item usability or consumption must first isolate this project from `auto_item_buff.lua` and `infinity_consumables.lua`, otherwise their hooks and item edits can invalidate results.

The runtime investigation has not yet confirmed a callable item-use API or action-table mapping. Observed Secret Potion action indices are diagnostic only and must not be hard-coded. Read-only probes are disabled after each investigation pass; only the current display/classification patch remains active.

Static review of the pre-existing `_CatLib/fsm.lua` found a verified action-request call on `app.HunterCharacter`: `changeActionRequest(app.AppActionDef.LAYER, ace.ACTION_ID, System.Boolean)`. This is a candidate mechanism for reusing an existing eating animation, but the correct layer and item-use transition still require confirmation.

The local generated item dataset has 764 records; all 32 records with `Eatable=true` also have `IsHeal=true`. This suggests `_Heal` may be part of the consumable pipeline, but the correlation is not proof of safe behavior for item 98. The required GameDesign item/action data is not unpacked in the local `natives` tree.

The controlled `_Heal=true` candidate did not enter the normal item-use action. ItemData flags alone are therefore insufficient; stop guessing flags and resolve the separate item-use/action parameter data.

A public MHDB Wilds data toolkit documents a no-game-launch route for extracting `.user.3` and `.msg.23` data from PAKs into JSON. This is the next static investigation path; it has not been installed or run in this workspace.

The static-tooling survey found three useful references:

- `dtlnor/MonsterHunterWildsModding` lists `ree-pak-gui`, RE Tool plus `mhwilds.list`, RE Editor, and REMSG Converter for Wilds data work.
- `seifhassine/REasy` supports PAK extraction and RSZ/User/MSG inspection, and its releases mention updated MHWilds file lists and RSZ dumps.
- `kassent/mhwilds_data` provides item/quest/enemy dumps and an REFramework Lua dump script that enumerates `app.VariousDataManager` item data and converts fixed item IDs to public IDs.

The `kassent` dump is useful for item identity and fixed-ID mapping, but it does not expose the missing item-use action or Stench application path.

## Tooling workspace

- `REE.Unpacker` is compiled under `tools/REE.PAK.Tool` and uses the locally installed .NET Framework 4.7.2 Developer Pack.
- A project-local Python 3.12 environment at `.venv312` contains the `zstandard` and `mmh3` packages.
- A filtered, read-only extraction of target item and player action resources is under `extracted/base`.
- The RSZ parser and Wilds type dump are under `tools/rsz_local`.

## Static extraction requirements

To identify the missing use path without launching the game, the next data set must include:

- Item definition data for IDs 1, 4, 5, 98, and 100
- Item effect/use parameter records
- Common action and common sub-action BTable records
- `app.AppActionDef.LAYER` values
- Text/message records for item categories and use prompts
- Hunter action or item-use transition records

The official Wilds file list now identifies concrete sources:

- `gamedesign/common/item/itemdata.user.3`
- `gamedesign/common/item/autousehealthitemdata.user.3`
- `gamedesign/common/item/autousestatusitemdata.user.3`
- `gamedesign/player/actiondata/common/action/plcommon_actionid.user.3`
- `gamedesign/player/actiondata/common/action/plcommon_actionparam.user.3`
- `gamedesign/player/actiondata/common/action/plcommonsub_actionid.user.3`
- `gamedesign/player/actiondata/common/action/plcommonsub_actionparam.user.3`
- `gamedesign/player/actiondata/common/globalparam/playeritemparam.user.3`
- `motion/player/common/plc_itemuse/plc_itemuse_mct.user.3`
- `motion/player/common/plc_itemuse/plc_itemuse_mex.user.3`
- `motion/player/common/plc_itemuse_tree/plc_itemuse_tree_mct.user.3`
- `motion/player/common/plc_itemuse_tree/plc_itemuse_tree_mex.user.3`

`tools/REE.PAK.Tool/REE.Packer` contains the original C# PAK reader, Murmur3 hashing, and Zstandard support. It targets .NET Framework 4.7.2. The current machine has .NET SDKs but no 4.7.2 reference assemblies, so the source cannot be built locally without an additional framework/toolchain.

The official .NET Framework 4.7.2 Developer Pack was installed, `REE.Unpacker` was compiled locally, and a filtered read-only extraction was completed against the base PAK. The extracted RSZ/User files now live under `D:\mhws-eatshit\extracted\base`.

The current install does not contain these extracted files. `natives/stm/GameDesign` only exposes a small Equip prefab subset, and no local PAK extractor was found. No implementation should proceed from guessed action indices or guessed field names.

## Functional direction

Prefer REFramework Lua for runtime discovery and, if the required supported game methods are identified, the first implementation. Do not add C++ or replace resources unless evidence shows Lua cannot implement a required behavior.

## Unknowns

- Runtime type and methods for the dung item, hunter item use, status application, and Wide-Range propagation
- Stench's internal status identifier and whether it blocks all items or only a subset
- Whether the game's existing Wide-Range pipeline accepts this status effect
- Compatibility of the current REFramework build with every aspect of game build 1.42.0.2

## Safety

- Do not write save data or edit core game archives.
- Keep this project's scripts separate from pre-existing mods.
- Preserve logs and do not overwrite existing log files.
- Disable this probe by moving its single Lua file out of `reframework/autorun`.
