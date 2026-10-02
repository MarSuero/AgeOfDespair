# Stench (恶臭) Mechanism: Static Type Map

Generated: 2026-10-01
Method: read-only inspection of the Wilds RSZ type dump
(`tools/rsz_local/resources/data/dumps/rszmhwilds.json`). No game launch.

## Purpose

Pre-research for step 4 of the project plan (apply `恶臭` after normal item use
works). This file records what the type system proves about how a
monster-repelling effect is modelled, so the later implementation does not start
from guesswork.

## Status of this document

This is a **type map, not an implementation plan**. Nothing here is yet wired to
item `98`, and no runtime call is confirmed. Field layouts and parent chains are
proven; behaviour and call paths are not.

## 1. The effect family is `EnemyBadCondition`

The dump contains a coherent family of monster "bad condition" types:

```text
app.cEnemyBadCondition                        (base)
app.cEnemyBadConditionKoyasi                  parent: app.cEnemyBadCondition
app.cEnemyBadConditionSmokeBall               parent: cEnemyBadCondition_ResistLevel`1<...cSmokeBall.cPresetData>
app.cEnemyBadConditionStun
app.cEnemyBadConditionFlash
app.cEnemyBadConditionScar
app.cEnemyBadConditionPoison
app.cEnemyBadConditionParalyse
app.cEnemyBadConditionSleep
app.cEnemyBadConditionStamina
app.cEnemyBadConditionCapture
app.cEnemyBadConditionFieldPitfall
app.cEnemyBadConditionBlock
app.cEnemyBadConditionEar
app.cEnemyBadConditionEmLead
app.cEnemyBadConditionLightPlant
app.cEnemyBadConditionSandDig
app.cEnemyBadConditionSkillRyuki
app.cEnemyBadConditionSkillStabbing
app.cEnemyBadConditionWeakAttr
app.cEnemyBadConditionParryNpc
app.cEnemyBadConditionBlockNpc
```

All members of this family share the same six-field shape, inherited from
`app.cEnemyActivateValueBase`:

```text
_State            : app.cEnemyActivateValueBase.STATE
_Value            : app.cValueHolderF
_ValueDireciton   : app.cEnemyActivateValueBase.DIRECTION
_TimerRate        : ace.cSafeContinueValue`1<System.Single>
_TimerStop        : ace.cSafeContinueValue`1<System.Boolean>
_DisableActivate  : ace.cSafeContinueValue`1<app.cEnemyActivateValueBase.DISABLE_ACTIVATE>
```

Verified for `app.cEnemyBadCondition`, `app.cEnemyBadConditionKoyasi`, and
`app.cEnemyBadConditionSmokeBall` directly.

## 2. The two candidates for the Stench effect

### `app.cEnemyBadConditionKoyasi`

"Koyasi" (退かす) means to drive away / repel. In Monster Hunter, the dung-adjacent
effect that makes a monster leave the area is exactly this: the monster is not
damaged, it is driven off.

This is the closest semantic match found for the project's `恶臭` goal.

### `app.cEnemyBadConditionSmokeBall`

Its parent is a **resistance-level** generic:

```text
app.cEnemyBadCondition_ResistLevel`1<app.user_data.EmParamBadConditionPreset.cSmokeBall.cPresetData>
```

This proves the effect is data-driven with a per-monster resistance table, not a
fixed global constant.

## 3. The preset data chain

```text
app.user_data.EmParamBadConditionPreset.cSmokeBall
    parent: app.user_data.EmParamBadConditionPreset.cBadConditionBase
    fields: _PresetArray : ace.cInstanceGuidArray`1<...cSmokeBall.cPresetData>

app.user_data.EmParamBadConditionPreset.cSmokeBall.cPresetData
    parent: System.Object
    fields: _InstanceGuid : System.Guid
            _ResistTable  : app.user_data.EmParamBadConditionPreset.cResistData

app.cEmParamGuid_SmokeBallPreset
    parent: app.cEmParamGuidBase
    fields: Value : System.Guid
```

So a monster points at a smoke-ball preset through a `System.Guid`, and that
preset carries its own resistance table. `app.cEmParamGuid_SmokeBallPreset` is the
GUID-bearing reference type.

The preset container sits inside the enemy parameter set:

```text
app.user_data.EmParamBadConditionPreset   (contains cSmokeBall, cStun, cFlash, ...)
app.user_data.EmParamBadCondition2        (contains EnemyBadConditionSetting)
```

## 4. Immediate consequence for the project

This map changes what "apply 恶臭" should mean. There are two distinct readings,
and they are not interchangeable:

1. **Apply the native repelling condition to the monster** — the `cEnemyBadCondition`
   family. Semantically correct for dung, and the resistance table is honoured by
   the game.
2. **Apply a hunter-side buff/status** — a different subsystem entirely
   (`app.HunterCharacter.cBuffIconInfo.INFO_LIST`,
   `app.HunterDef.ITEM_BUFF_TYPE`, `app.HunterBadConditions.*`).

Reading 1 is the one this project wants. Reading 2 would produce a hunter buff,
which is not what "the monster is driven off by the stench" means.

Related hunter-side types, recorded only to mark the boundary of this family:

```text
app.HunterBadConditions.cHunterBadConditions
app.HunterBadConditions.cHunterBadConditionBase
app.HunterCharacter.cBuffIconInfo.INFO_LIST
app.HunterDef.ITEM_BUFF_TYPE
app.GUI020901.BadConditionInfoBase
app.user_data.EmParamCombat.cBadConditionHateData_PL
app.user_data.EmParamCombat.cBadConditionHateData_NPC
```

`cBadConditionHateData_PL` / `_NPC` is worth noting separately: hate/aggro data tied
to bad conditions, which is the mechanism by which a repelled monster changes its
behaviour toward the player.

## 5. What this does NOT establish

- No method names or signatures. The dump has no method metadata at all
  (schema keys are exactly `crc`, `fields`, `name`, `parent`).
- No confirmed runtime handle to the per-monster condition instance.
- No link yet from item `98` to any of these condition types.
- No evidence about whether the repelling condition can be applied from Lua
  rather than only through the native item-use pipeline.

## 6. Recommended next step for this workstream

Do not implement yet. Once the item-use gate is resolved, extend the read-only
probe to resolve `app.cEnemyBadConditionKoyasi`, `app.cEnemyBadConditionSmokeBall`,
and `app.cEmParamGuid_SmokeBallPreset`, and record their method signatures and
whether the owning objects are reachable at runtime. That mirrors the approach
already taken for the gate, and keeps the work evidence-driven.

## Safety

Read-only. No PAK, save, or deployed file was modified.
