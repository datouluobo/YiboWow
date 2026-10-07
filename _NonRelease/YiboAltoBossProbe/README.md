# YiboAltoBossProbe

YiboAltoBoss 的非发布诊断探针，用于核对五人本 Boss 死亡时客户端实际派发的遭遇事件与战斗日志。它独立保存数据，不修改正式插件代码或 SavedVariables。

## 安装与采样

将此目录以同名目录联接到目标客户端 `Interface/AddOns/YiboAltoBossProbe/`，启用插件。进入暴风城监狱前运行 `/yip on`，正常击杀两只 Boss；如需探测重置，再使用游戏原生“重置所有副本”操作。最后运行 `/yip status` 并 `/reload`。样本保存在 `WTF/Account/<账号>/SavedVariables/YiboAltoBossProbe.lua`。

探针最多保留 500 条事件；普通战斗日志只记录 `UNIT_DIED`、`PARTY_KILL` 和 `UNIT_DESTROYED`，并随每条样本保存当时 `GetInstanceInfo()` 返回的副本信息。遭遇开始/结束、Boss 击杀、进出区域及系统/怪物喊话事件也会记录参数。探针观察游戏原生 `ResetInstances()` 调用，在调用前、相关更新事件后及 2 秒后抓取锁定快照（副本、难度、锁定状态和 Boss 进度）。它不会主动重置副本，也不会修改游戏进度。使用 `/yip off` 停止采样；`/yip clear` 清除本探针的本地样本。

将生成的 SavedVariables 文件发回即可分析。如果死亡战斗日志有 Boss 名称/GUID，而 `ENCOUNTER_END` 和 `BOSS_KILL` 缺席，就能确认正式插件遗漏的触发信号。
