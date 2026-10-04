# 绝望时代 0.3.5

这是一个独立于旧版 item98 可用性包的联机版本。它把公共物品 ID `98` 接入既有的 `successItem` 成功事件观察路径，并在每个客户端自己的角色状态更新中处理效果。

## 功能范围

- 两个客户端都安装时，观察物品 `98` 的成功使用事件
- 在本地角色上应用对应效果，不直接写入其他玩家的状态
- 按游戏现有的广域化技能、距离、任务和队伍状态做接收校验
- 提供免费进食判定和诊断导出
- 设置和诊断文件写入 `reframework/data/AgeOfDespair/`

## 安装

将 `reframework` 文件夹复制到 Monster Hunter Wilds 游戏目录并合并。联机时，每个参与者都需要安装本包：

```text
reframework/autorun/age_of_despair.lua
reframework/plugins/AgeOfDespair_Action.dll
reframework/plugins/AgeOfDespair_Availability.dll
```

首次运行后，脚本可能在 `reframework/data/AgeOfDespair/` 生成设置和诊断文件。

## 卸载

删除上面列出的三个文件即可。本包不修改 PAK、存档或原始游戏文件。

## 兼容性与验证边界

- 这是从外部交付压缩包整理出的发布包，当前仓库只完成了文件导入、清单和完整性验证。
- 本次没有启动游戏，因此没有在当前环境重新验证联机同步、广域化数值或免费进食表现。
- 两个 DLL 是随输入压缩包提供的预编译二进制；不要把它们当作本仓库现有 native bridge 的构建产物。
