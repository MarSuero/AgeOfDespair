# Native Bridge Status

The directory now contains an unbuilt, un-deployed read-only metadata bridge.
It uses the official REFramework SDK checkout in `tools/REFramework-sdk` and
asks REFramework's TDB for the actual `app.mcHunterItem` and
`app.HunterCharacter` methods, parameters, return types, field offsets, and
function addresses.

It does not install hooks, mutate objects, touch ItemData, or route item `98`.
That is deliberate: the next safe step is recovering the real request method
signature from the game metadata before writing a behavioral hook.

Files:

- `Item98Bridge.cpp`: one-shot metadata logger, not deployed.
- `CMakeLists.txt`: x64 shared-library build definition against the official
  REFramework SDK.

The behavioral bridge remains blocked until the metadata identifies a concrete
request gate and its exact arguments. The first behavioral implementation must
only route public item `98` through the verified `cUseDrinkItem` path, with all
other requests passed through unchanged.
