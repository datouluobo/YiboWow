# YiboTodo - MoP 5.5.4 冷却基线

此文件是 `0.1` 目录激活前的证据台账，不是可直接发布的冷却清单。所有条目都必须在目标客户端中经 `/ytd probe` 和自有专业窗口来源守卫验证后，才可写入 `Ruleset_50504.lua` 的 `activeGroups` 并标记为 `verified`。

|稳定 ID|专业 ID|候选 spellID|候选物品 ID|公共组|当前结论|验证构建|证据|
|---|---:|---:|---:|---|---|---|---|
|`mop.engineering.jards-energy-source`|202|139176|94113|`mop.engineering.jards-energy-source`|verified|5.5.4|`live-observation:2026-08-29`|
|`mop.blacksmithing.lightning-steel-ingot`|164|138646|94111|`mop.blacksmithing.lightning-steel-ingot`|verified|5.5.4|`live-observation:2026-08-29`|
|`mop.blacksmithing.balanced-trillium-ingot`|164|143255|98717|`mop.blacksmithing.balanced-trillium-ingot`|verified|5.5.4|`live-observation:2026-08-29`|
|`mop.alchemy.living-steel`|171|114780|72104|`mop.alchemy.transmute`|candidate|待实机确认|待 `/ytd probe` 输出|
|`mop.tailoring.imperial-silk`|197|125557|82441|`mop.tailoring.imperial-silk`|candidate|待实机确认|待 `/ytd probe` 输出|

验收时必须补齐：完整 `5.5.4` build、专业窗口归属、配方是否已学习、API 原始冷却值、`readyAt` 归一化结果，以及同一公共组成员是否一致。任何无法验证、当前已无冷却或发生冲突的条目都保留在此台账，但不得变成 active 项目。
