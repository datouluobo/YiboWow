# YiboAltoBossProbe

YiboAltoBoss 的非发布诊断探针，用于核对五人本 Boss 死亡时客户端实际派发的遭遇事件与战斗日志。它独立保存数据，不修改正式插件代码或 SavedVariables。

将目录联接或复制到 `Interface/AddOns/YiboAltoBossProbe/` 并启用。进入暴风城监狱前运行 `/yip on`，击杀两只 Boss；如需探测重置，再使用游戏原生“重置所有副本”操作。完成后输入 `/yip status` 并 `/reload`。样本保存在 `WTF/Account/<账号>/SavedVariables/YiboAltoBossProbe.lua`。

探针最多保留 500 条事件；记录遭遇事件、Boss 击杀、Boss 死亡战斗日志、区域变化及重置相关反馈。它观察游戏原生 `ResetInstances()` 调用，在调用后即时、相关更新事件后及 2 秒后抓取锁定快照（副本、难度、锁定状态和 Boss 进度）。探针不会主动重置副本，也不会修改游戏进度。使用 `/yip off` 停止采样；`/yip clear` 清除探针本地样本。
