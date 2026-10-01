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
- `build.ps1`: reproducible Windows build entry point; it fails clearly when
  CMake or the SDK is unavailable.
- `build-llvm-mingw.ps1`: fallback build entry point for the installed
  LLVM-MinGW toolchain; it statically links the C++ runtime.
- `Item98NotUseBridge.cpp`: first behavioral candidate, limited to the
  evidence-backed `notUseItem(app.ItemDef.ID)` gate.
- `build-llvm-mingw-behavior.ps1`: builds that behavioral candidate.

The current static build was checked as x64 and exports
`reframework_plugin_initialize` plus
`reframework_plugin_required_version`. Its imports are limited to Windows
system API sets and `KERNEL32.dll`; it has not been copied to the game's
`reframework/plugins` directory.

The first behavioral candidate hooks only
`app.mcHunterItem.notUseItem(app.ItemDef.ID)`. It skips the original gate for
public ID `98` and returns `false`; every other item calls the original method
unchanged. It does not mutate `_DisabledItemID`, `_ItemRequestMsg`, or any
action ID. It remains un-deployed until the runtime metadata report is
reviewed.

The source and SDK layout are checked by
`tools/rsz_local/verify_mc_hunter_item_evidence.py`.
