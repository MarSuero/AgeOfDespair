# Item 98 Action Completion Follow-up

The current item-98 animation does not call `set_UsedItemID(98)`, so that
property setter cannot trigger stench activation.

The next evidence target is the actual player sub-action implementation:

- `app.PlayerCommonSubAction.cUseDrinkItem`
- `app.PlayerCommonSubAction.cEatMeat`
- their common/base action types
- `HunterCharacter` action completion methods

`native_bridge/UseActionMetadataBridge.cpp` is a read-only metadata bridge for
those types. It installs no hooks and applies no item or status mutation.
