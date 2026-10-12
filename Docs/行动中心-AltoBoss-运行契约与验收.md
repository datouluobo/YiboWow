# TaskHub 与 AltoBoss：刷取目标运行契约

日期：2026-10-10。工作树版本：TaskHub **0.4.0**、AltoBoss **2.6.0**。代码及自动化已完成，未发布；真实客户端验收待执行。产品设计见 [接入方案](行动中心-AltoBoss接入方案.md)。

## 用户入口

`/yth` → **刷取目标**。左侧为所选角色的计划，右侧提供搜索、添加与编辑；世界／节日首领可跨页多选后一起添加。副本明确选择难度及整本／指定首领；点击已保存目标名称调整范围，暂停保留配置。

顶部提供“复制给…”和“从其它角色复制”。先显示各目的角色新增／合并／扩为整本数量，再确认提交。合并保留目的角色独有目标与暂停状态；部分重叠首领补齐，整本覆盖指定首领。任何目标修改使旧预览失效；应用前检查全部目的角色，一次写入，不会部分成功。

Core 设置工作台 → 行动中心 → 业务设置：**在首领追踪中自动显示刷取目标**，默认开启。关闭只撤下自动展示，计划、待办、手动列与实际击杀／锁定均保留。AltoBoss 世界首领单元格显示逐角色“目标”标记；副本追加精确难度目标列，没有安排的角色显示 `—`。主表和预览共用这些来源查询。

目标页按可用高度分页；来源和角色下拉复用 Core，搜索使用 `CreateInput(clearable=true)`，包含中文输入法处理。搜索支持中文、英文、常用缩写及首领名；首领命中显示所属副本与匹配首领。缩写碰撞返回相关条目，不推断难度。副本名称双语别名及常见团队首领别名由 AltoBoss 维护；未收录的首领仍支持客户端本地名称。`searchCoverage` 明确目录搜索覆盖，不宣称所有首领都有双语别名。

## 所有权和版本

| 所有者 | 权威数据 | 运行要求 |
| --- | --- | --- |
| TaskHub | 每个 Core 角色的计划、暂停与自动展示设置 | Core API11；business-services:1、business-providers:1、basic-input:1，以及既有页面／名称／准入／高度／物品能力 |
| AltoBoss | 目录、角色奖励观察、精确副本锁定、周期与完成判断 | 目标增强要求 Core API11 / business-services:1 / business-providers:1 / character-name-format:1；不足时提示升级并停止增强 |
| Core | 角色 ID、能力连接、窗口／设置／入口与共享控件 | 复用现有接口，本次没有扩展 Core 运行代码 |

AltoBoss 基础追踪仍要求 API5；API5～10 可继续独立使用基础功能。这是可选跨业务增强的版本边界，不保留第二套目标判断实现。Task 或 AltoBoss 缺失／禁用／未注册／主版本不兼容时，另一方基础功能正常，自动投影撤下或显示未连接；持久计划不清空。TOC 均只依赖 Core。

## Service 与 Provider v1.0

所有注册和调用经 `Core.Contracts`；调用双方均先由 Core 注册插件。方法返回值由 Core 隔离复制，不暴露内部数据库引用。

### `boss.target-catalog`：AltoBoss → Task

- Service ID：`YiboAltoBoss:target-catalog`，版本 `{major=1, minor=0}`。
- `Query({})` → `{targets={...}}`。
- 目录项：`id, kind, name, aliases, complete, available, reason?`；副本另有 `journalID?, mapID?, isRaid, expansion, difficulties, encounters, searchCoverage`。
- 难度：`id, name, complete, trackable, encounters`；首领：`id, name, journalID?, aliases?`。
- 世界 `id=world:<bossKey>`；节日使用来源既有稳定键；日志副本 `journal:<JournalInstanceID>`；旧副本 `instance:<mapID>`。地图映射的就绪不会改变目标 ID。
- EJ 首领 ID 使用 DungeonEncounterID，区分 JournalEncounterID。完整旧副本扫描建立 AltoBoss 持久分配的 `legacy:<mapID>:<sequence>` 业务键，不冒充原生 encounter ID。
- 每次完整旧副本采集核对副本地图、难度、首领数量及名称唯一性。锁定 API 的本地名称只在来源内部、精确副本／难度目录内解析成稳定键；跨插件和持久目标均使用稳定键。语言变化或名称无法唯一对应时不按列表位置猜测完成。
- 未验证目录／地图映射／难度不能保存；普通五人本没有周期锁定，首版不作为自动周期目标。旧副本首次完整扫描后开放该实际观察难度。缺少数据不会生成虚构首领或任意难度。
- 来源通过 `BUSINESS_CONTRACT_CHANGED` 通知目录失效；UPDATE_INSTANCE_INFO 允许刷新此前尚未就绪的 EJ 目录。Task 订阅注册／注销／变化后重查。

### `task.boss-targets`：Task → AltoBoss

- Service ID：`YiboTaskHub:boss-targets`，版本 `{major=1, minor=0}`。
- `Query({scope={characterIDs={...}}})`；显式空数组保持空范围，重复角色去重，非法范围返回 `nil,"invalid-request"`。
- 返回 `{sourceEpoch, revision, autoDisplay, characterIDs, targets={[characterID]={...}}}`。
- 目标：`id, catalogID, title, kind, active, scope, encounterIDs`；副本另有 `difficultyID, difficultyName`。`scope=all|boss`；全本在执行时使用该精确难度完整目录。
- 只返回配置，不触发目录／进度请求。AltoBoss 验证快照结构；无兼容 Service 或结构不合法视为不可用。
- 目标变化使用 `Core.Contracts:NotifyChanged`；自动显示设置也通知，但不改变计划或完成数据。
- Task DB schema2→3 保留已有显示／HUD 设置，新增 `bossTargets={sourceEpoch,revision,nextID,byCharacter}`。未来 schema 拒绝写入。Core 的角色删除清理对应计划，`CHARACTER_ID_CHANGED` 合并转移旧 ID 配置。

### `action.todo`：AltoBoss → Task

- Provider ID：`YiboAltoBoss:planned-targets`，版本 `{major=1, minor=0}`；沿用 [公共 action.todo v1](行动中心-最小能力契约-v1.md)。
- `Query({scope={characterIDs={...}}})` → 标准 `providerID, sourceTitle, sourceEpoch, revision, generatedAt, status, coverage, data.tasks`。
- 仅已安排且启用的角色目标生成任务；执行者及受益者为该 Core 角色。任务键为角色 ID＋目标 ID，周期由来源提供，标题／详情包含副本难度与整本／指定首领。
- 世界目标采用六组实际周常奖励标记，包括四天神共享标记。观察时间与周期持久保存在 AltoBoss；未观察或跨周失效保持未知。未完成时需已知等级资格；斡耳朵斯缺少准入依据时明确待核实，不把奖励标记 false 自动当作可做。
- 副本按地图、难度及稳定首领键判断；选定首领全部确认才完成整项。快照不完整、身份不明、过期或未扫描保持未知。完整扫描中没有该精确难度锁定才可解释为未完成，不能用其它难度完成记录代替。
- 副本采集保存 daily／weekly 周期；英雄五人本使用来源日常边界，团队本使用周常边界；延长锁定以当前来源扫描和 resetAt 为依据，跨边界仍需来源重新确认。
- 节日开窗采用既有来源日历和每日7点规则；未开放输出 paused，不进入当前工作列表。窗口内日历未就绪是 unknown；开放与关闭边界可触发缓存到期。手动显示开关不影响目标观察。
- completed 停止当前待办，目标与 AltoBoss 自动列保留。新的周期不能重用旧完成或自动把未知改成未完成。
- `freshness.observedAt` 为真实采集时间；`validUntil/nextChangeAt` 为来源边界；查询不采集、不给历史记录补新时间、不发送变化广播；仅按账号范围事实更新可再生指纹与来源版本，周期转移也会推进版本，版本不随请求角色范围变化。源变化合并比较事实指纹，更新独立 epoch／revision 并通知；注销使旧定时回调失效。

## 实施文件

- Task：[BossTargets](../YiboTaskHub/BossTargets.lua)、[TargetsPage](../YiboTaskHub/TargetsPage.lua)、[TargetTabs](../YiboTaskHub/TargetTabs.lua)、数据库／设置／初始化／TOC。
- AltoBoss：[TargetCatalog](../YiboAltoBoss/TargetCatalog.lua)、[PlannedTargets](../YiboAltoBoss/PlannedTargets.lua)、[TargetProjection](../YiboAltoBoss/TargetProjection.lua)、副本采集／节日观察／来源矩阵／初始化／TOC。
- 静态 API 对照参考：[Blizzard Encounter Journal UI](https://github.com/Gethe/wow-ui-source/blob/live/Interface/AddOns/Blizzard_EncounterJournal/Mainline/Blizzard_EncounterJournal.lua)。客户端返回值和业务目录最终以实际 MoP Classic 验收为准。

## 验证

2026-10-10：新增 `BossTargetsSpec.lua` **136 项**；原 Overview 链 **359 项**、TodoSources **177 项**继续通过，去除重复运行的基础检查后合计 **672 项**。新增测试使用实际 Core Contracts、实际 Task 模型／标签页、AltoBoss 目录／采集／投影和 Boss 状态渲染，控制 WoW API 返回及时间。

Core `ContractsSpec` 90项继续通过；Core／TaskHub／AltoBoss TOC 加载的73个 Lua 文件语法检查通过，相关 diff 空白检查通过。来源查询在周期转移时推进账号范围版本，查询本身不广播；提前查询不会吞掉待发送的合并通知。

覆盖迁移与未来版本拒绝、显式范围和返回隔离、CN／EN／缩写／首领搜索、逐角色计划、双向复制／部分重叠／整本扩展／暂停差异／陈旧预览／批量保存原子性、离线与低等级未知、奖励完成与周重置、错难度、指定首领与整本差异、缺首领证据、延长锁定、旧目录稳定键、角色 ID 转移与删除、节日开放／未就绪／日重置／未开放、关闭自动展示保留任务与手动数据、来源缺失／晚注册／注销／不兼容、Core 版本及共享输入缺失停止、真实页面交互及只读预览。

待游戏验收：完整退出并重新进入客户端以加载新增 TOC 文件；20角色及低分辨率布局、中文输入法与长名、EJ 地图／难度／首领映射、旧副本完整扫描、世界奖励与斡耳朵斯准入、节日真实日历及奖励、跨角色切号／重载、日周边界与延长锁定、主表／预览一致性。自动化不代替这些客户端证据。
# 性能修复补充（2026-10-10）

任务链已接入 Core `character-identity:1`，新增最低能力检查，并修复不变观察触发刷新、查询重复投影和跨来源扩大失效。219项专项断言与已有回归通过，实机内存／帧耗时待复测。实现、验证及兼容边界见 [性能修复记录](任务链-性能异常修复-2026-10-10.md)。
