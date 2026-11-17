# YBP Mists 宠物 API 只读探针

P0-02 diagnostic, version 0.1.0. It is separate from the older Mists identification probe and is not part of YiboBeastPaths or any package.

## Safety and scope

The probe reads slot APIs and records observations only in `YiboBeastPathsMistsPetProbeDB`. It never writes `YiboBeastPathsDB` or the older `YiboBeastPathsPetProbeDB`, and does not move, summon, tame, release, rename or specialize pets. Wrong product, unknown Core API13/identity or unknown probe schema stops its own writes. Every sample says `complete=unverified`; the provisional slot range is a diagnostic search window, not proof of full coverage.

Probe `/ymx` is unique in this workspace. It records build/project/interface, `GetStablePetInfo` status for each candidate slot, active/stable counts, purchased slots, event sequence count, and occupied slot IDs. Names and slot records stay in this probe's SavedVariables; console output does not print names.

## Install when asked

On the current laptop, the same-name junction at `D:\Program\World of Warcraft\_classic_\Interface\AddOns\YiboBeastPathsMistsPetProbe` points to `D:\Development\YiboWow\_NonRelease\YiboBeastPathsMistsPetProbe`. It was created on 2026-11-12 while Mists was running; the client must be fully restarted to discover it. The former C: path was recorded on the previous computer and must not be assumed valid here.

Enable YiboCore and **YiboBeastPathsMistsPetProbe**. Start Mists fully, log in to a Hunter, and use `/ymx report` or `/ymx scan`. One login sample is automatic. `/ymx scan` records a new observation and `/ymx report` shows it.

## Sampling sequence and evidence

### 新驯服地点探针（2026-11-15）

本次只调查新驯服宠物，不回溯旧宠物，也不写 YiboBeastPaths 业务存档。探针监听猎人驯服野兽（技能 ID 1515）的施法事件，在开始及后续 60 秒记录目标／宠物 GUID、名称、地图 ID、坐标及相关事件；这些是待核实的诊断数据，不自动断言关联成功。失败或中断的尝试也会留下记录。最多保留最近 10 次，详细内容仅保存在本探针 SavedVariables。

准备：确认该探针已启用，`/reload` 加载新版；输入 `/ymx tame` 检查探针响应。选择野兽后正常驯服；看到 `tame capture started` 表示事件已触发。保持游戏运行约 60 秒，看到 `tame capture finished` 后输入 `/ymx tame`，再 `/reload` 写盘。把完成情况告诉开发者，由其检查本机探针存档及是否能可靠关联新宠；测试过程中无需移动或放生已有宠物。若未出现 started，也请告知，保留当次游戏状态以便排查。

2026-11-15 实机样本：用户确认成功驯服且目标只有一只。记录到地图 ID 433、目标 Creature GUID 和随后出现的 Pet GUID，两者中的生物编号一致；宠物默认名称与野兽名称不同。样本在 30 秒计时之后保存，没有记录到施法成功事件，也没有 60 秒计时样本。该证据支持当次驯服目标和地图的关联，不证明重载或更换槽位后如何将 Pet GUID 关联到离线兽栏条目。已记录样本的 `GetStablePetInfo` 只有图标、名称、等级、家族和空的第五返回值，未观察到宠物唯一编号；正式来源记录接入前须继续解决槽位识别和移动后的关联。

2026-11-15 补充只读核验：打开兽栏的样本中，新宠位于随身第 5 槽，名称在当次列表中唯一且外观 ID 为 40021。重载后当前召唤宠物的完整 GUID 与驯服样本一致；尚未测试重新召唤、重登、移动槽位、同名同外观或改名，不能由一次重载证明长期稳定。此后探针的扫描样本附带当前召唤宠物 GUID，便于后续对照；不修改业务数据。

2026-11-15 经用户授权移动验证：同一只山羊从随身槽 5 移到兽栏槽 9，再放回随身槽 5 并重新召唤，原位置和召唤状态均已恢复。保存的开栏样本分别记录随身／兽栏 5／65、4／66、5／65；名称、家族与图标可对照，等级从先前 88 升至 90。该宠物在多次扫描的外观 ID 出现 40021、45162、40024 和 40025，不能当作稳定身份。重新召唤后完整 Pet GUID 与驯服时不同，末尾部分一致；该相同部分的唯一性和生命周期尚未验证，不作为持久身份。召唤时 NDui 曾触发受保护操作阻止；重载后使用技能书重新召唤成功。样本说明可研究结合前后差异识别槽位变化，但不能证明同名冲突、离线移动、改名和重登时一定能识别。

Follow the shared [P0-02 sampling guide](../YiboBeastPathsPetProbe-P0-02/README.md). Existing 5.5.4 build 70531 reports are historical partial evidence only; this probe must report the current build. Candidate range constants and 5+200 fallback remain unverified until checked against the native stable UI and current client behavior.
