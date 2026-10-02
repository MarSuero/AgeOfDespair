# MHWS Eatshit Usable 0.1.0

这个 Mod 让公共物品 ID `98`「怪物的粪」出现在「狩猎道具」栏，并沿用当前已经验证的喝药样使用动作。

## 兼容环境

- 怪物猎人：荒野 `1.42.0.2`
- REFramework `v1.5.9.1` 或兼容的原生插件接口
- Steam PC 版

## 安装

将压缩包里的 `reframework` 文件夹复制到游戏安装目录并合并文件夹：

```text
reframework/autorun/mhws_eatshit_item98_usable_bridge.lua
reframework/plugins/mhws_eatshit_item98_notuse_bridge.dll
reframework/plugins/mhws_eatshit_item98_eat_action_bridge.dll
```

安装后重新启动游戏。

## 卸载

只删除上面列出的三个文件即可。本 Mod 不会修改 PAK、存档或原始游戏文件。

## 当前范围

本版本暂未实现玩家侧「恶臭」状态，也未实现广域化。当前物品动作保持已经验证过的表现。
