# Item 98 Stench Activation Result

Captured: 2026-10-01

## Result

The combined candidate did not activate player stench.

The log showed repeated successful `notUseItem(98)` bypasses, but no
`set_UsedItemID(98)` call and no `stench activated after public item 98 use`
message. Therefore the new bridge never reached
`get_HunterStatus() -> get_BadConditions() -> _Stench -> requestActivate()`.

## Conclusion

The current item-98 action can display the accepted drink-like animation, but
it does not enter the `set_UsedItemID` success boundary used by native
consumables. `set_UsedItemID` is not a reliable trigger for this modded item.

The player-side stench route itself remains valid:

```text
HunterCharacter.get_HunterStatus()
  -> cHunterStatus.get_BadConditions()
  -> cHunterBadConditions._Stench
  -> cStench.requestActivate()
```

The next candidate must trigger from the actual action completion/success
boundary, not from `set_UsedItemID`. No temporary files remain deployed.
