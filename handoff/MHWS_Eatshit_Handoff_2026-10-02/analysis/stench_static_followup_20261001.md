# Stench Follow-up

Captured: 2026-10-01

## Static findings

- The requested effect is the player-side condition
  `app.HunterBadConditions.cStench`.
- The executable string pool contains the relevant player-status route names:
  `requestBadCondition`, `cureBadCondition`, `get_Stench`,
  `get_StenchParam`, `checkSkillStench`, `getIsCheckStench`,
  `set_IsCheckStench`, and `CleanBadConditions`.
- The same pool contains the semantic identifiers `STENCH`,
  `PL_DEBUF_STENCH`, `MODORIDAMA`, and `CleanBadConditions`.
- This matches the requested behavior: the condition is attached to the hunter,
  disables item use through a stench check, and is cleared by the deodorant
  item path.
- The earlier monster-side `cEnemyBadConditionKoyasi` investigation is not the
  requested feature and is no longer the implementation target.

## What this suggests

The safest implementation route is:

1. keep item 98's currently accepted item-use behavior;
2. after the use-success boundary, call the native hunter-side
   `requestBadCondition` route with the verified `STENCH` condition;
3. let the existing `checkSkillStench` item lock and `cureBadCondition` /
   `CleanBadConditions` deodorant path handle the rest.

The exact method signatures and receiver objects are still unverified. Do not
call these names from Lua or fabricate enum values yet.

The first metadata capture additionally confirmed:

- `app.HunterCharacter.get_HunterStatus()` returns `app.cHunterStatus`.
- `app.HunterBadConditions.cHunterBadConditions` exposes
  `get_Item(app.HunterDef.BAD_CONDITION)` and
  `get_Item(app.HunterDef.BAD_CONDITION_Fixed)`.
- `cStench` is reached through that indexed bad-condition collection; it does
  not expose a direct `get_Stench()` property in this build.

The read-only bridge now includes `app.cHunterStatus` and both bad-condition
enum types so the next capture can recover the receiver path and the numeric
`STENCH` enum value.

## Prepared next evidence

`native_bridge/StenchMetadataBridge.cpp` is a read-only runtime metadata bridge
for `HunterCharacter`, `HunterBadConditions`, `cStench`, and the hunter status
watchers.

It installs no hooks and applies no status. One future targeted runtime
validation can recover the actual apply/request method signatures before any
effect implementation.
