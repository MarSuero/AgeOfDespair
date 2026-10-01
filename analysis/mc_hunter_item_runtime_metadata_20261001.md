# `mcHunterItem` Runtime Metadata

Captured: 2026-10-01 20:10:21
Game: Monster Hunter Wilds `1.42.0.2`
REFramework: `v1.5.9.1`

## `app.mcHunterItem`

Fields:

| Field | Offset | Static |
|---|---:|---:|
| `_Chara` | `48` | no |
| `_GuiActionMessageHandler` | `56` | no |
| `_ItemRequestMsg` | `64` | no |
| `_DisabledItemID` | `72` | no |
| `_DisabledItemIDLock` | `80` | no |

Methods:

| Method | Return | Address |
|---|---|---:|
| `canUseItem(app.ItemDef.ID)` | `System.Boolean` | `0x140535310` |
| `notUseItem(app.ItemDef.ID)` | `System.Boolean` | `0x140507140` |
| `receiveGuiActionMessage(app.gui_action_message.cGUIActionMessageBaseToPl)` | `System.Void` | `0x1449FA440` |
| `checkNotUseItem_ItemWide(System.Func<System.Boolean>)` | `System.Boolean` | `0x1449FA510` |
| `checkNotUseItem_ItemWide_NearOtherPl()` | `System.Boolean` | `0x1449FA5F0` |
| `addDisabledItem(app.ItemDef.ID)` | `System.Void` | `0x1449FABE0` |
| `addDisabledItem(app.ItemDef.ID[])` | `System.Void` | `0x1449FAC60` |

All listed methods are instance methods. The addresses are valid only for the
captured executable build and must not be reused for another game version.

## Related `app.HunterCharacter` methods

| Method | Return | Address |
|---|---|---:|
| `get_Item()` | `app.mcHunterItem` | `0x14871C3B0` |
| `set_UsedItemID(app.ItemDef.ID)` | `System.Void` | `0x14C741D20` |
| `changeActionRequest(app.AppActionDef.LAYER, ace.ACTION_ID, System.Boolean)` | `System.Boolean` | `0x1486504C0` |
| `canUseItem(app.ItemDef.ID)` | `System.Boolean` | `0x148723540` |

## Consequence

The previous “unknown signature” blocker is closed for the current executable:
the request-side methods and their managed parameter types are now known.

The next bridge must hook `mcHunterItem.notUseItem(app.ItemDef.ID)` first. Its
contract is a boolean gate, so the minimal behavioral candidate should preserve
all original behavior except public item `98`, and should not touch
`_DisabledItemID` or `_ItemRequestMsg` directly.

The hook must still verify the actual `app.ItemDef.ID` argument representation
and the pre-hook argument layout before skipping the original. No action ID,
fixed-row conversion, or status effect is to be added yet.

The metadata DLL was removed immediately after capture. No project plugin is
currently installed in the game directory.
