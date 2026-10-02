# `mcHunterItem` Static Analysis

Generated: 2026-10-01

## Result

The current local artifacts do not contain enough information to implement a
native request bridge safely.

The Wilds RSZ dump contains the type name
`app.mcHunterItem`, but its entry has no fields and no method metadata. The
runtime names `_ItemRequestMsg`, `_DisabledItemID`, `_DisabledItemIDLock`,
`canUseItem`, and `addDisabledItem` came from REFramework reflection, not from
recoverable native signatures.

The executable string heap contains the method names, but no declaring type,
function address, x64 parameter list, or call-site relationship. The official
REFramework native-plugin SDK is now available under `tools/REFramework-sdk`;
it can expose runtime TDB metadata and method addresses, but it does not
contain Wilds-specific request signatures or a PDB. The workspace still has no
native disassembler capable of recovering those facts offline.

## Confirmed facts

- Public item `98` resolves to fixed ItemData row `99`.
- `canUseItem(98)` returns `true`.
- `getItemActionTypeFromItemID(98)` returns action type `1`.
- The extracted BTable maps action type `1` to `cUseDrinkItem`.
- The failed item-98 attempt never reaches `set_UsedItemID` or the observed
  item-use `changeActionRequest` sequence.
- `_DisabledItemID` is a managed `HashSet<int>`, but its population,
  synchronization, and relation to `_ItemRequestMsg` are unproven.

## Deliberately not implemented

- No native hook address was guessed.
- No x64 function signature was invented.
- No direct mutation of `_DisabledItemID` was added.
- No request message or action object was fabricated.
- No DLL was built or deployed.

The existing Lua files that remove item `98` from `_DisabledItemID` remain
disabled and are not evidence that the set is the rejecting gate. Removing an
entry without the lock and request-path ordering could race the game or leave
the request state inconsistent.

## Required evidence before a DLL

1. A concrete function address or stable signature for the request gate.
2. The exact x64 calling convention and parameter order.
3. Evidence showing whether the request carries public ID `98` or fixed row `99`.
4. The lock scope around `_DisabledItemID`.
5. A post-request trace proving the existing `cUseDrinkItem` route is reached.

Until those are available, the safe implementation state is unchanged: all
project probes and candidates remain disabled, and no game launch is required.

The unbuilt read-only SDK bridge at `native_bridge/Item98Bridge.cpp` is prepared
to collect that metadata in one targeted run. It installs no hooks and does not
mutate the game.
