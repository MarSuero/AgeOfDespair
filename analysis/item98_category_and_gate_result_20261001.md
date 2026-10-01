# Item 98 Category and Gate Result

Captured: 2026-10-01

## What changed

The paired candidate applied the previously verified runtime ItemData category
fields to public item `98`:

- `_TextType=1`
- `_Window=true`
- `_Eatable=true`
- `_Heal=true`
- `_EnableOnRaptor=true`

The item appeared under `狩猎道具`, proving the category/UI gate was crossed.

The native bridge hooked
`app.mcHunterItem.notUseItem(app.ItemDef.ID)` and returned `false` for public
item `98`. The framework log contains repeated:

```text
notUseItem returned false for public item 98
```

## Result

Pressing the use key still produced no drink action. Therefore:

- Item category is no longer the blocker.
- `canUseItem(98)` was already proven true.
- `notUseItem(98)` is now proven bypassed.
- The remaining failure is after the gate, in request generation, request
  message handling, or item-to-action dispatch.

The Lua and DLL were removed after the test. No candidate remains active in the
game directory.

## Next target

Inspect `_ItemRequestMsg` and `receiveGuiActionMessage(...)` as one request
chain. The next probe must be read-only and must identify the request object's
type and fields before any request mutation or action override is attempted.
