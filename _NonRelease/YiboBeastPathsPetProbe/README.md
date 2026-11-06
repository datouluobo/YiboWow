# BeastPaths Mists 宠物采集探针

状态：探针 0.1.1 已实现；Mists 5.5.4 build 70531 的随身／兽栏及两只噩兆点选读取已有实机样本，颜色标注与四色识别 **待验收**。实际采集报告保存 `GetBuildInfo()` 返回值。

## 安装与启动

源码位于仓库根目录 `_NonRelease/YiboBeastPathsPetProbe/`，同名 TOC 为 `YiboBeastPathsPetProbe.toc`。本机 Mists 安装路径：

```text
C:\Program Files (x86)\World of Warcraft\_classic_\Interface\AddOns\YiboBeastPathsPetProbe
    -> E:\Development\YiboWow\_NonRelease\YiboBeastPathsPetProbe
```

启用 **YiboCore** 与 **BeastPaths 宠物采集探针**，使用猎人角色进入游戏。新增插件以及本次 0.1.1 加载路径调整后，需要完整退出并重新启动客户端；仅 `/reload` 可能无法发现新目录或刷新加载清单。探针要求 Core API13、`localization:1` 和 `character-identity:1`。Core 负责角色 ID 与会话语言；扫描和存档属于探针。API/能力不足时显示升级提示并停止，Core 未就绪时不采集。

探针通过原生 API 只读观察，不调整兽栏槽位、不改宠物名、不召唤或放生宠物。阶段 0 采用诊断聊天报告，没有玩家账号页面或设置控件。正式 BeastPaths 无需启用。探针目录不加入任何正式插件 TOC 或发布配置。

## 命令

唯一命令 `/yhp`；已于 2026-10-15 搜索工作区全部 Lua `SLASH_*` 注册，确认无占用。

| 命令 | 用途 |
|---|---|
| `/yhp scan before` | 立即扫描，并给本次诊断样本加标签；标签可自行替换 |
| `/yhp report` | 最近扫描摘要、所有有宠物的槽位、四色匹配统计 |
| `/yhp selected` | 自动读取兽栏当前点选宠物，输出名字和外观 ID |
| `/yhp color cobalt` | 目视确认当前点选宠物为钴蓝色后，记录其外观 ID |
| `/yhp slot 6` | 立即只读核对指定槽位，输出原始信息与外观 ID |
| `/yhp color 6 jade` | 显式槽位诊断：将该槽位的外观 ID 标注为翡翠色 |
| `/yhp status` | 探针版本、诊断样本数量与当前构建已标注的颜色数 |

四色参数为 `jade`（翡翠）、`amethyst`（紫晶）、`cobalt`（钴蓝）、`jasper`（碧玉／红铜）。参数是稳定 ID，名称使用中英文资源。动态宠物名与家族名保持客户端 API 原文。

## 第一轮实机操作

1. **打开兽栏前**：运行 `/yhp scan before`，再运行 `/yhp report`。记录随身、兽栏能否读取，以及是否缺外观 ID。
2. **打开兽栏**：等待约 2 秒，运行 `/yhp scan open`、`/yhp report`。对照原生界面核对全部随身与兽栏数量；查看后面的兽栏页，特别核对最后一个有宠物的槽位。报告槽位编号为全局索引，不是当前页格子编号。
3. **核对噩兆颜色**：在兽栏中点选一只噩兆，让它出现在模型预览中。运行 `/yhp selected`，确认输出名字就是刚点选的宠物，再根据目视颜色运行 `/yhp color jade`、`/yhp color amethyst`、`/yhp color cobalt` 或 `/yhp color jasper`。已有的其它颜色同样逐一标注。没有持有的颜色保留待验收，无需为测试放生或重新抓宠。关闭兽栏、未选择或选中空格时停止标注。
4. **验证识别稳定性**：使用原生界面把已标注宠物在随身与兽栏间移动，等待更新后运行 `/yhp scan moved`、`/yhp report`；应保持外观 ID 与颜色不变，位置和数量同步更新。条件允许时核对改名后的识别；探针自身不执行这些操作。
5. **关闭兽栏后**：运行 `/yhp scan closed`、`/yhp report`，比较关闭前后的可读范围。再 `/reload`，运行 `/yhp scan reloaded`。所有完整性仍为 `unverified`，由客户端证据决定今后正式采集何时可建立可靠快照。
6. 最后 `/reload` 或正常退出游戏，让数据落盘；按 [验收记录](Validation.md) 填写结果。

四色映射起初为空，避免使用未经 Mists 目标构建验证的外观 ID。`color` 是人工目视标注，后续扫描使用 ID 自动匹配；它不等同于独立证据已经证明四色正确。需要各颜色真实样本、移动／改名／重载对照才能完成验收。一个外观 ID 被标注为多个颜色时保留诊断观察、暂停该 ID 的自动匹配并报告冲突；一个颜色标到不同外观 ID 时拒绝覆盖，需检查样本后决定是否存在多外观别名。

点选读取使用暴雪 `PetStableFrame.selectedPet`，不按名字或外观 ID 搜索宠物。本机 NDui Plus 的 `ImprovedStableFrame` 沿用原生按钮模板，并将原生兽栏常量改为每页 200 格、一页；探针消费当前原生范围和选中索引，不绑定 NDui 私有实现。同名或同外观的宠物也由当前选中索引区分。2026-10-23 两只噩兆的点选输出已与模型预览标题对应，颜色标注与更多 UI 状态仍需核对。

**外观匹配只证明外观一致，无法独立证明宠物最初来自噩兆 NPC。** Mists 的这些接口没有直接提供原始 NPC ID。来源核对与颜色核对分别记录，不用宠物名字、图标或家族名作为身份键。

## 数据与采集时机

存档全局为 `YiboBeastPathsPetProbeDB`，对应文件：

```text
<Mists>\WTF\Account\<账号>\SavedVariables\YiboBeastPathsPetProbe.lua
```

- `characters[Core characterID].latest`：当前角色最近一次扫描。
- `lastOpenStable`：最近一次兽栏打开时的诊断快照，与 `latest` 分开，避免关闭后 API 无返回值掩盖打开时的观察证据。
- `samples`：每角色最多 24 次诊断样本，用于比较读取时机；没有业务完成判断。旧样本达到上限时被新样本替换。
- `colorMappings[projectID:interface:build][displayID]`：当前构建的人工目视标注、时间、角色、槽位和外观 ID。客户端构建变化后需要重新核对，不跨构建自动沿用。
- `lastSelection`：最近一次选中宠物核对；`colorObservations` 每角色保留最多 24 次颜色目视标注，包括冲突样本。它们是识别验证证据。
- 每个槽位保存 `GetStablePetInfo` 的标量原始返回值、返回数量（保留 nil 空洞）、外观 API 返回、读取状态与错误；空返回、缺 API、读取异常分开表达。
- 记录槽位、名字、图标、等级、家族、外观 ID、客户端构建、Core 角色 ID 和当前召唤宠物 GUID。报告含角色与宠物信息，提交给外部服务前自行核对内容。

登录自动扫描一次；打开兽栏后延迟约 0.25 秒和 1.25 秒各采一次。兽栏更新、关闭、自己的宠物变化和改名事件合并到下一次 0.25 秒读数；没有待处理事件时关闭更新回调。原生界面常量可用时扫描其范围，否则使用 Mists 候选范围：随身 1–5，兽栏 6–205。候选范围、API 数量与实际读到的数量均单独记录；常量可用、零错误或返回空值都不作为完整扫描证明。

## 验证与资料

从仓库根运行：

```powershell
lua _NonRelease/YiboBeastPathsPetProbe/Tests/ProbeSpec.lua
luac -p _NonRelease/YiboBeastPathsPetProbe/Locale.lua
luac -p _NonRelease/YiboBeastPathsPetProbe/Mists/Probe.lua
```

模拟测试使用真实 Core Locale 模块和合成宠物 ID，验证双语资源／格式参数、随身与兽栏边界、缺 API／错误／空返回、延迟／合并、改名／换槽位、映射冲突、跨角色隔离及构建变化。模拟通过不能代替客户端验收。

0.1.1 将 Mists 专用采集、原生兽栏选择读取、事件和命令职责归入 `Mists/Probe.lua`，TOC 和测试同步引用；根 `Probe.lua` 保留为空操作兼容路径。覆盖安装保留旧路径也不会重复执行。安装目录、技术名、`YiboBeastPathsPetProbeDB` 与 schema 1 保持稳定。本轮只影响此 Mists 探针，不改正式 BeastPaths 或其它客户端。

运行仓库本地化检查所得 [基线报告](../Localization/BeastPaths-PetProbe-Baseline-Report.md)覆盖正式 BeastPaths，仍有 254 个既有硬编码候选；不作为本探针的语言检查证据。探针目录不在该检查器支持的根插件范围内，其语言资源以真实 Core Locale 测试和源码审查核对。

接口依据（访问日期 2026-10-15；实际形态以目标客户端为准）：

- [Blizzard Mists 共用兽栏界面源码](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_UIPanels_Game/Cata/PetStable.lua)：`GetStablePetInfo(index)`、槽位常量、兽栏事件，以及按槽位调用外观 ID 接口。
- [PlayerInfo API 文档源码](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_APIDocumentationGenerated/PlayerInfoDocumentation.lua)：`C_PlayerInfo.GetPetStableCreatureDisplayInfoID(index)`。
- [StableInfo API 文档源码](https://github.com/Gethe/wow-ui-source/blob/classic/Interface/AddOns/Blizzard_APIDocumentationGenerated/StableInfoDocumentation.lua)：数量接口；不把正式服的宠物列表结构当成 Mists 已提供的能力。
- [Core 轻量角色身份契约](../../YiboCore/Docs/API-v11-轻量角色身份.md)及 `Core.Characters:GetCurrentID()` 实现。
