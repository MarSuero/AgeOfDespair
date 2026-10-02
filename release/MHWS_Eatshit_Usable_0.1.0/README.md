# MHWS Eatshit Usable 0.1.0

This package makes public item `98` (`怪物的粪`) appear under `狩猎道具`
and routes it through the currently accepted drink-like use animation.

## Compatibility

- Monster Hunter Wilds `1.42.0.2`
- REFramework `v1.5.9.1` or compatible native-plugin API
- PC version

## Install

Copy the `reframework` folder into the Monster Hunter Wilds installation
directory and merge the folders:

```text
reframework/autorun/mhws_eatshit_item98_usable_bridge.lua
reframework/plugins/mhws_eatshit_item98_notuse_bridge.dll
reframework/plugins/mhws_eatshit_item98_eat_action_bridge.dll
```

Restart the game after installing.

## Uninstall

Delete only the three files listed above. This package does not modify PAK
archives, saves, or original game files.

## Scope

This release does not implement the player-side `恶臭` status or Wide-Range.
The current item animation is intentionally preserved.
