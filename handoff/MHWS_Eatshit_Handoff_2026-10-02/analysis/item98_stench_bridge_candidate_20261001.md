# Item 98 Hunter Stench Candidate

Prepared: 2026-10-01

## Evidence chain

- Public item `98` already reaches the successful `set_UsedItemID(app.ItemDef.ID)`
  boundary in the working item-use path.
- `HunterCharacter.get_HunterStatus()` returns `app.cHunterStatus`.
- `cHunterStatus.get_BadConditions()` returns
  `app.HunterBadConditions.cHunterBadConditions`.
- The bad-condition container has `_Stench` at field offset `24`.
- `cStench.requestActivate()` is the native activation method.
- The normal cleanup path remains native: `cStench.cure()`,
  `checkAndCureConditions(...)`, `deactivateAllConditions()`, and
  `onWaterWash()`.

## Candidate behavior

`native_bridge/Item98StenchBridge.cpp` hooks only
`HunterCharacter.set_UsedItemID(app.ItemDef.ID)`.

When the argument is public item `98`, the post-hook follows:

```text
HunterCharacter
  -> get_HunterStatus()
  -> get_BadConditions()
  -> _Stench
  -> requestActivate()
```

All other item IDs call the original method unchanged. The candidate does not
touch ItemData, `_DisabledItemID`, the action table, enum values, or the
deodorant cleanup route.

## Safety boundary

The DLL is compiled x64 and exports the REFramework plugin entry points. It is
not deployed yet. One validation should confirm that using item `98` activates
the same player-side stench state that Peach/桃毛兽王 applies, and that the
normal deodorant item still cures it. If any receiver lookup fails, the bridge
logs the failure and leaves the game state unchanged.
