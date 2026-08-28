# YiboTodo - 账号待办实施方案

## 1. 文档职责

本文把 [PRODUCT.md](PRODUCT.md) 的产品功能与边界，以及 [版本规划.md](版本规划.md) 的版本顺序，转换为可以直接执行的工程方案。

三份文档的职责与优先级如下：

1. `PRODUCT.md` 决定产品为什么存在、允许做什么和永久不做什么；
2. `版本规划.md` 决定各版本交付顺序；
3. `IMPLEMENTATION.md` 决定当前范围如何落到目录、代码、数据、界面和验收。

实施方案不得自行扩大产品范围。若技术实现需要改变准入规则、状态含义、作用域或版本范围，应先修改产品文档或版本规划，再修改本文。

## 2. 0.1 交付定义

`0.1` 的唯一业务能力是监控熊猫人之谜经典版 `5.5.4` 中已验证的商业技能制作冷却，并通过 YiboCore 统一账号视图帮助玩家选择下一名应登录的角色。

### 2.1 必须交付

- 可维护的通用活动目录、MoP 冷却目录、公共冷却组目录和 `5.5.4` 客户端规则集；
- 能区分当前角色自己的专业窗口、他人或链接专业窗口及不可用数据源的配方冷却采集器；
- 公共冷却组级聚合，成员配方不得重复增加摘要数量；
- `actionable`、`cooldown`、`estimated`、`locked`、`unknown`、`not-applicable` 的首版状态映射；
- 角色扫描记录、绝对恢复时间、数据来源、确认时间和目录版本的持久化；
- 角色为行的账号摘要、单角色详情和同源悬停预览；
- 按专业、公共冷却组和单项显示或隐藏，并保留三态继承升级能力；
- YiboCore API v5 页面、入口、角色缓存清理和统一设置工作台接入；
- `/ytd` 主命令及只通过 Slash 命令触发的状态、目录校验和探针诊断；
- 目录校验、数据库迁移和 2、10、20、21 名角色验收。

### 2.2 明确不交付

- 农场、诺米、烹饪日常、布林顿、暗月马戏团和任何普通任务采集器；
- 1.x–4.x 冷却数据；
- 材料数量、制造成本、拍卖价格、利润或赚钱建议；
- 自动打开专业、自动制造、自动交互或代替玩家完成动作；
- 独立窗口壳、独立角色目录、独立 Broker 生命周期或小地图拖拽逻辑；
- 未经 `5.5.4` 实机验证便作为正式状态来源的冷却条目。

## 3. 工程约束

- 客户端：MoP Classic `5.5.4`，`.toc` Interface 为 `50504`；
- 核心依赖：YiboCore Public API v5；
- 技术名：`YiboTodo`；
- 页面名：`账号待办`；
- 正式命令：`/ytd`，不保留其它正式别名；
- SavedVariables：`YiboTodoDB`，业务数据不得写入 `YiboCoreDB`；
- `.toc` 标题：`|cff20e070[Yibo]|r YiboTodo - 账号待办`；
- `.toc` 声明 `## RequiredDeps: YiboCore` 和 `## Group: YiboCore`；
- 不新增 Ace 等框架依赖；优先复用 YiboCore 的角色、主题、窗口、入口和设置能力；
- 所有时间计算使用服务器时间；SavedVariables 只保存绝对时间和观察时间，不持续保存倒计时文本或每秒剩余值。

图标资源尚未确定。在透明边界合规的正式资源加入前，不在 `.toc` 或入口定义中引用不存在的图标路径。

## 4. 总体架构

数据流固定为：

```text
版本化目录与规则集
        ↓
配方冷却 Provider ──→ 原始观察记录 ──→ 状态评估器
                                            ↓
角色活动快照 ──→ 公共冷却组聚合 ──→ 账号摘要投影
                                            ├─→ Core 主页面
                                            └─→ Core 悬停预览
```

核心原则：

1. 目录描述“可能存在什么”，观察记录描述“角色最后确认了什么”；
2. 状态评估器是状态语义的唯一实现，UI 不自行推断状态；
3. 摘要和详情都消费同一角色活动快照，悬停只隐藏字段，不重算业务；
4. 公共冷却组是摘要统计单位，配方只是组成员；
5. 目录、规则、采集、状态、投影和呈现分层，避免后续新增日常时修改冷却采集器。

## 5. 计划目录结构

```text
YiboTodo/
├─ YiboTodo.toc
├─ Bootstrap.lua                 # 命名空间、数据库初始化、事件启动
├─ Database.lua                  # 默认值、迁移、角色数据读写
├─ Catalog/
│  ├─ ActivityCatalog.lua        # 通用活动注册与查询
│  ├─ CooldownGroupCatalog.lua   # 公共冷却组
│  ├─ CooldownCatalog_MoP.lua    # MoP 配方成员基线
│  ├─ Ruleset_50504.lua          # 当前客户端实际规则
│  └─ Validator.lua              # 目录一致性校验
├─ Model/
│  ├─ Schedule.lua               # 重置与绝对恢复时间语义
│  ├─ State.lua                  # 统一状态评估
│  └─ Snapshot.lua               # 角色、账号摘要及行动排序
├─ Providers/
│  ├─ Registry.lua               # Provider 最小注册契约
│  └─ ProfessionCooldown.lua     # 0.1 唯一正式采集器
├─ Probe.lua                     # API 能力和实机基线诊断
├─ Settings.lua                  # 业务目录继承与设置面板内容
├─ AccountPage.lua               # 主表、详情、预览共用呈现
├─ CoreIntegration.lua           # API v5 页面、入口、清理注册
├─ Commands.lua                  # /ytd、status、validate、probe
├─ PRODUCT.md
├─ IMPLEMENTATION.md
└─ 版本规划.md
```

目录可在实现中合并过短文件，但以下边界不得合并：目录定义不得写进 UI；状态判断不得写进 Provider 或单元格；Core 注册不得拥有业务扫描数据。

`.toc` 的 Lua 加载顺序必须遵守“数据库与目录 → 模型 → Provider → UI → Core 接入 → 命令 → Bootstrap 启动”。如果 `Bootstrap.lua` 负责最早创建命名空间，则拆成首个 `Namespace.lua`，不得依赖 Lua 文件加载偶然顺序。

## 6. 目录契约

### 6.1 ActivityCatalog

`ActivityCatalog` 是所有周期待办的通用入口。`0.1` 中每个公共冷却组生成一个可配置活动，成员配方不各自生成摘要待办。

```lua
{
    id = "profession.cooldown.<stable-group-id>",
    kind = "profession-cooldown",
    provider = "profession-cooldown",
    scope = "character",
    sourceExpansion = "mop",
    scheduleKind = "api-reported",
    completionMode = "any-member-starts-group",
    groupPath = { "profession", "mop", "<profession-id>", "<group-id>" },
    defaultMode = "required",
    active = true,
}
```

预留枚举包括：

- `provider`：`profession-cooldown`、未来的 `daily-quest`、`farm-observation` 等；
- `scope`：`character`、`account`；
- `scheduleKind`：`server-daily`、`server-weekly`、`fixed-duration`、`calendar-window`、`api-reported`、`observed`；
- `completionMode`：`single`、`any-member`、`all-members`、`count-target`。

预留枚举不代表 0.1 已实现对应业务。未被当前 Provider 与状态评估器声明支持的组合必须由校验器拒绝激活。

### 6.2 CooldownCatalog

冷却目录每条记录只描述稳定配方身份和组成员关系：

```lua
{
    id = "mop.<profession>.<stable-recipe-name>",
    introducedIn = "5.x",
    professionID = 0,
    recipeSpellID = 0,
    resultItemID = 0,
    cooldownGroupID = "mop.<profession>.<stable-group-name>",
    verificationStatus = "verified",
    verifiedBuild = "5.5.4.xxxxx",
    evidence = "probe:<baseline-revision>",
    active = true,
}
```

要求：

- `id`、`recipeSpellID` 和组关系不得由本地化名称推导；
- `professionID`、`recipeSpellID`、`resultItemID` 在进入正式目录前必须实机核对；
- `verificationStatus` 允许 `candidate`、`verified`、`conflict`、`no-current-cooldown`、`excluded`；
- 只有 `verified` 且被当前规则集激活的记录参与正式扫描与 UI；
- 失效项目改为 inactive 或规则集禁用，不删除历史身份，不复用稳定 ID。

### 6.3 CooldownGroupCatalog

```lua
{
    id = "mop.<profession>.<stable-group-name>",
    activityID = "profession.cooldown.<stable-group-id>",
    professionID = 0,
    aggregation = "shared-cooldown",
    resetPolicyID = "<ruleset-policy-id>",
    defaultMode = "required",
    order = 0,
    active = true,
}
```

组目录拥有聚合和重置语义；成员目录不得复制公共规则。一个活动可以展示多个成员配方，但摘要中最多产生一个 `可制作`、`冷却中`、`预计可用`或`待确认`结果。

### 6.4 Ruleset_50504

来源资料片和当前客户端行为必须分开保存。`introducedIn = "3.x"` 只说明来源，不说明它在 `5.5.4` 仍有冷却。

规则集负责：

- 当前 Interface 和客户端构建适用范围；
- 冷却组当前是否启用；
- API 返回值如何解释；
- 组或成员的当前版本覆盖；
- 已取消冷却、共享关系变化和上游冲突；
- Provider 支持的 schedule 组合。

0.1 不根据旧资料站的原始持续时间自行推算当前规则。若客户端 API 能直接报告剩余冷却，以本次可靠扫描结果生成 `readyAt`；固定时长或服务器日重置分类只有在基线确认后才能写入规则集。

### 6.5 目录校验

启动时校验：

1. 所有活动 ID、冷却 ID、组 ID 和激活的 `recipeSpellID` 唯一；
2. 冷却成员引用的活动、专业和组存在且相容；
3. 一个激活配方不能同时属于多个激活公共冷却组；
4. 激活组至少有一个当前规则集中的 verified 成员；
5. 重置策略和 Provider 能力相容；
6. verified 条目包含验证构建和证据修订；
7. 默认设置值和分组路径合法；
8. inactive、excluded 和 no-current-cooldown 条目不进入正式扫描集合。

单个条目校验失败时应隔离该条目并输出一次汇总错误，不得让错误条目污染统计；结构级错误导致整个 Provider 进入 unavailable，但不得破坏其它插件或 YiboCore。

## 7. Provider 契约与采集流程

### 7.1 最小 Provider 接口

```lua
ProviderRegistry:Register({
    id = "profession-cooldown",
    schemaVersion = 1,
    activityKinds = { "profession-cooldown" },
    CanCollect = function(context) end,
    Collect = function(context) end,
})
```

Provider 只负责把可靠客户端事实写成原始观察记录，不负责决定待做数量、颜色、排序或 UI 文案。

### 7.2 可采集条件

配方冷却扫描必须同时满足：

- 当前玩家角色已经由 YiboCore 建立稳定 `characterID`；
- 专业窗口数据已经加载完成；
- 窗口属于当前角色自己，不是链接、他人、公会或其它只读来源；
- 当前专业可以被稳定识别；
- API 能力与返回值通过当前构建探针验证；
- 目录条目通过校验并在当前规则集中激活。

任一条件不满足时不得覆盖上一次已确认数据。Provider 只更新数据源状态和失败原因；链接或他人专业窗口永远不能写入当前角色记录。

### 7.3 事件流程

预期流程如下，具体 API 和事件名以 `5.5.4` 探针基线为准：

1. `ADDON_LOADED`：创建数据库、迁移、装载并校验目录；
2. `PLAYER_LOGIN` / `PLAYER_ENTERING_WORLD`：取得 Core 当前角色，重建内存投影，不把离线到期当作已重新扫描；
3. 自己的专业窗口打开或配方列表更新：等待数据 ready 后进行一次节流扫描；
4. 制造成功或专业数据变化：只标记相关 Provider dirty，并在数据源再次 ready 时重扫；
5. 专业窗口关闭：保留最后一次完整观察，不进行猜测性覆盖；
6. 扫描提交：一次性写入完整专业观察、递增 revision，并通知 Core 页面刷新。

事件风暴只允许合并为一次扫描。禁止 OnUpdate 每帧扫描专业 API；倒计时文字只在可见页面的低频刷新中重算。

### 7.4 原始观察记录

```lua
{
    provider = "profession-cooldown",
    providerSchemaVersion = 1,
    catalogVersion = 1,
    rulesetID = "mop-classic-50504",
    observedAt = 0,
    sourceState = "known",
    source = "own-tradeskill-window",
    professionID = 0,
    recipes = {
        [recipeSpellID] = {
            learned = true,
            cooldownKnown = true,
            remainingAtScan = 0,
            readyAt = 0,
        },
    },
}
```

持久化要求：

- `readyAt = observedAt + remainingAtScan`，保存绝对服务器时间；
- `remainingAtScan` 只用于诊断和迁移，不作为离线后的动态剩余时间；
- API 的 nil、0、不可用和未枚举必须在探针确认语义后分别归一化；
- 扫描不完整时整批记录 sourceState 为 unavailable 或 error，不用半批新数据覆盖完整旧记录；
- 本地化配方名、图标、格式化时间和摘要数量不进入 SavedVariables。

## 8. 数据库与迁移

首版数据库结构：

```lua
YiboTodoDB = {
    schemaVersion = 1,
    catalogVersion = 1,
    settings = {
        modeOverrides = {
            activityType = {},
            expansion = {},
            profession = {},
            cooldownGroup = {},
            activity = {},
        },
        previewColumnsVersion = 1,
        previewColumns = {},
    },
    byCharacter = {
        [characterID] = {
            lastSeenAt = 0,
            providers = {
                [providerID] = {
                    revision = 0,
                    lastAttemptAt = 0,
                    lastSuccessAt = 0,
                    state = "not-yet-scanned",
                    errorCode = nil,
                    observations = {},
                },
            },
        },
    },
    byAccount = {},
}
```

`byAccount` 在 0.1 不写入伪造的 `default` 账号键。加入布林顿等账号级项目时，必须先确认 Core 提供的稳定账号作用域身份，再启用该区域。

数据库不得保存：

- Core 已拥有的角色姓名、职业、等级、服务器和排序副本；
- 当前倒计时字符串；
- 可由目录、观察记录和当前时间重新生成的摘要；
- 主页面窗口位置、尺寸、入口位置或角色范围；
- 未分类的探针日志无限历史。

迁移规则：

1. 迁移函数按 `schemaVersion` 逐级执行，必须幂等；
2. 目录升级只迁移失效 ID 和设置覆盖，不清空角色观察；
3. stable ID 改名必须提供显式映射，禁止静默丢弃覆盖；
4. 配方 inactive 后保留历史观察，但不进入当前摘要；
5. 不可恢复的数据只隔离到有界诊断区，并向用户说明，不自动删除整库。

## 9. 状态评估

状态评估器输入目录活动、当前规则、角色观察和当前服务器时间，输出统一状态及解释字段。UI 不可根据 `readyAt` 再实现第二套判断。

### 9.1 冷却组状态优先级

1. 角色明确没有对应专业：`not-applicable`；
2. 尚无可靠专业扫描或数据源不可用：`unknown`；
3. 专业存在，但组内所有当前成员都明确未学习：`locked`；
4. 任一成员被确认处于公共冷却，且 `readyAt > now`：`cooldown`；
5. 上次确认的 `readyAt <= now`，但尚未重新扫描：`estimated`；
6. 本次完整扫描确认任一已学习成员没有冷却：`actionable`；
7. 成员结果冲突或无法按组规则解释：`unknown`，同时记录诊断码。

`completed`、`in-progress` 会保留在统一模型中，但 0.1 的制作冷却不使用它们伪装“今天做过”。制作后进入 `cooldown` 已足以表达本轮处理结果；未来每日任务与农场活动再启用这两个状态。

### 9.2 可信度

每个状态同时输出：

- `confirmed`：本次可靠扫描直接确认；
- `estimated`：由历史绝对时间推导；
- `unknown`：当前无法支持结论。

`estimated` 必须显示“预计”标记，不得使用与 confirmed actionable 完全相同的文字、图标或颜色。

### 9.3 摘要统计

0.1 统一使用以下统计口径：

- `待做`：设置为必做且状态为 `actionable` 或 `estimated` 的公共冷却组数；
- `可制作`：状态为 confirmed `actionable` 的公共冷却组数；
- `冷却中`：状态为 confirmed `cooldown` 的公共冷却组数；
- `最近恢复`：所有纳入显示的 cooldown 组中最早的 `readyAt`；
- `待做项目`：按 actionable、estimated、unknown 的顺序列出简短活动名；unknown 显示为“待确认”，但不虚增待做或可制作数量。

`locked` 和 `not-applicable` 默认只进入详情，不进入行动摘要。公共冷却组无论包含多少成员都只计一次。

## 10. 内存快照与刷新

`Snapshot` 层从 SavedVariables 的观察记录构建只读业务快照：

```lua
{
    revision = 0,
    builtAt = 0,
    characters = {
        [characterID] = {
            updatedAt = 0,
            providerState = "known",
            activities = {},
            summary = {},
        },
    },
    accountActivities = {},
}
```

要求：

- 主窗口、悬停、Broker 文本、详情和 `GetActions` 消费同一 revision 的快照；
- 数据写入、目录变更、设置变更和跨过最近 `readyAt` 时使投影失效；
- 页面不可见时不进行每秒重建；
- 到期只把 confirmed cooldown 转成 estimated，不能修改原始观察为“已确认可用”；
- `HasCharacterSnapshot` 只对确有 YiboTodo 业务记录的角色返回 true；
- 超过 20 名角色由 Core 页面滚动或分页继续展示，不在插件中静默截断。

## 11. YiboCore API v5 接入

初始化顺序：

1. `Core:CheckAPIVersion(5)`；
2. `Core:RegisterAddon("YiboTodo", { version = "0.1", requiredAPI = 5 })`；
3. `Core.CharacterCleanup:RegisterOwner()` 注册业务角色缓存检查与删除；
4. `Core.AccountView:RegisterPage()` 注册 `todo` 页面；
5. `Core.Entry:RegisterBusinessEntry()` 注册可选独立入口；
6. 注册 `/ytd`；
7. 首次投影完成后调用 `AccountView:NotifyPageChanged("todo")`。

页面定义：

- page id：`todo`；
- title：`账号待办`；
- scope：Core 管理的服务器/账号角色范围；
- business fields：`todo`、`actionable`、`cooldown`、`nearestReady`、`items`；
- 完整页面默认显示全部五个业务字段；
- 悬停默认显示 `todo`、`actionable`、`nearestReady`、`items`，用户可由 Core 设置工作台调整；
- `HasCharacterSnapshot` 和 `GetEligibleCharacters` 只纳入有业务快照且符合 Core 角色筛选的角色；
- `GetSummary`、`GetActions`、页面 Refresh 和预览投影必须读取同一 Snapshot；
- `CreateSettingsPanel` 只提供业务目录设置，不创建设置窗口壳。

入口定义使用 id `ytd`、pageID `todo`、Broker name `YiboTodo`。Core 负责“不显示 / 仅 Broker / 仅小地图 / 两者都显示”、位置、点击和右键设置行为。

当前 API v5 由业务插件通过 `GetPreviewFields` / `SetPreviewFieldVisible` 提供 `settings.previewColumns` 的读写适配，Core 负责渲染设置控件。若后续 Core 将持久化完全收回，应只替换该适配层，不迁移业务目录设置。

YiboTodo 不需要读取任何 Core 中性领域即可完成 0.1；因此不要为了形式接入 `DATA_DOMAIN_UPDATED`。角色身份通过 `Core.Characters` 获取，业务扫描后只调用本页刷新通知。

## 12. 页面与交互

### 12.1 主页面

主表结构固定为：

|角色|待做|可制作|冷却中|最近恢复|待做项目|
|---|---:|---:|---:|---|---|

排序默认遵循 Core 的统一角色排序。业务页不保存第二套角色顺序。可行动角色的强调应通过状态单元格和行动列表表达，不偷偷改写 Core 顺序。

一次只展开一名角色详情。详情顺序为：

1. 数据时间与可信度；
2. 专业分组；
3. 公共冷却组；
4. 组状态和恢复时间；
5. 已学习成员与未学习成员；
6. 数据来源或异常解释。

禁止为每个专业或资料片持续增加主表列。新增条目只进入详情分组和摘要项目列表。

### 12.2 悬停预览

预览是主表快照的字段投影：

- 角色准入、状态、数量、时间格式和排序与主页面一致；
- 只按 `previewColumns` 隐藏字段；
- 默认最多 20 名有效角色时完整展示；
- 不显示探针、目录版本、调试码、无数据角色或装饰性说明；
- estimated 和 unknown 保留与主页面相同的可信度标记。

### 12.3 时间格式

- 24 小时内显示相对时长并可附绝对时刻；
- 超过 24 小时显示日期与时刻；
- 已跨过恢复时间但未重扫显示“预计可用”；
- 未知显示“待扫描”或“待确认”，不显示 `0`、空字符串或“已完成”。

具体格式化函数由 AccountPage 与预览共用。

## 13. 设置实施

### 13.1 层级

设置解析顺序从具体到一般：

1. 单项活动；
2. 公共冷却组；
3. 专业；
4. 资料片；
5. 活动类型；
6. 目录默认值。

SavedVariables 只保存用户覆盖；不存在的键表示继承。新增项目因此自动取得父级策略。

### 13.2 底层模式

从 0.1 起底层只接受字符串枚举：

- `required`：必做；
- `display`：仅显示；
- `hidden`：隐藏。

0.1 的业务设置面板只提供“显示 / 隐藏 / 恢复继承”，其中“显示”写入或解析为 `required`。不得保存布尔值，以免 0.7 加入“仅显示”时重做数据库。

若父组隐藏而用户明确显示子项，子项 `required` 覆盖父组；点击“恢复继承”删除子项覆盖。设置写入后重建投影并通知 Core 页面刷新，不重新扫描专业 API。

### 13.3 Core 与业务设置分工

Core 管理：

- 页面是否显示；
- 独立入口模式；
- 主表字段；
- 悬停字段控件；
- 角色范围、排序和缓存管理入口。

YiboTodo 的 `业务设置` 分区管理：

- 专业、公共冷却组和单项的显示/隐藏/继承；
- 目录版本、最后扫描时间和数据可信度只读说明；
- 如需清除 YiboTodo 全部业务缓存，必须位于 `数据与缓存` 末尾并使用确认框。

设置内容优先两栏和自动分栏；不得创建横向滚动、第二个标题栏、第二个关闭按钮或独立窗口位置。

## 14. 数据基线与探针

### 14.1 基线表

每个候选配方在进入正式目录前记录：

|字段|说明|
|---|---|
|稳定 ID|不随本地化变化的插件身份|
|专业 ID|客户端实际专业身份|
|配方 spellID|客户端实际配方身份|
|结果 itemID|用于交叉核对，不作为唯一身份|
|来源资料片|历史来源|
|当前规则|`5.5.4` 中的实际行为|
|公共组|是否与其它配方共享冷却|
|API 原始结果|ready、cooldown、nil 和异常情况|
|验证构建|完整客户端 build|
|证据修订|对应探针输出版本|
|结论|verified、conflict、no-current-cooldown 或 excluded|

候选可以保留在基线文件，但只有 verified 条目进入 shipped active 集合。

### 14.2 `/ytd probe`

探针仅由命令触发，不占用普通入口交互。输出至少包括：

- 客户端版本、Interface、Locale 和服务器时间；
- 相关专业 API 是否存在；
- 当前窗口来源判断；
- 专业 ID、配方 ID 和目录命中情况；
- 冷却 API 的原始返回值及归一化结果；
- 组成员之间的返回值是否一致；
- 未识别配方、重复成员和规则冲突。

默认只输出当前专业的简明结果；详细原始数据可以保存为有界诊断快照，但不得永久累积。探针不得修改正式状态，除非随后执行了一次满足完整采集条件的正常扫描。

### 14.3 其它命令

- `/ytd`：打开 Core 中的账号待办页面；
- `/ytd status`：打印当前角色的扫描时间、Provider 状态和摘要；
- `/ytd validate`：执行目录与规则集校验并打印汇总；
- `/ytd probe`：开发构建使用的实机 API 诊断；它不是玩家首次使用或日常使用流程的一部分。

不注册旧命令别名。

## 15. 异常与数据新鲜度

以下情况不能转成“没有冷却”或“已完成”：

- 角色从未打开过对应专业；
- 专业窗口尚未 ready；
- 打开的是链接、他人或公会专业；
- API 在当前构建不存在或返回语义未验证；
- 目录冲突、成员缺失或规则不支持；
- SavedVariables 迁移失败；
- 上次冷却已经到期但角色未重新扫描。

统一 Provider 数据源状态：

- `known`：最近一次完整采集成功；
- `not-yet-scanned`：从未可靠采集；
- `unavailable`：当前数据源不可用，保留旧数据；
- `stale`：历史数据仍可解释，但需要重新确认；
- `error`：代码或规则异常，附稳定错误码。

用户可见文案使用普通语言；稳定错误码只在 `/ytd status` 或 `/ytd probe` 中出现。

## 16. 实施阶段

### 阶段 A：项目骨架与契约

交付：

- `.toc`、命名空间、数据库默认值和逐级迁移框架；
- 四类目录文件、Provider Registry 和状态枚举；
- Core API v5 最小注册、`/ytd` 和空状态页面；
- 本文所列 schema 固化为 Lua 数据结构和校验规则。

退出条件：插件可在无业务目录时安全加载；Core 页面、入口和缓存清理注册成功；无独立窗口。

### 阶段 B：MoP 数据基线

交付：

- 候选冷却清单；
- `/ytd probe`；
- 每项 verified、conflict、no-current-cooldown 或 excluded 结论；
- 已验证公共冷却关系和 `Ruleset_50504`。

退出条件：所有 active 条目有稳定 ID、真实客户端 ID、验证构建和证据修订；目录校验无错误。

### 阶段 C：Provider 与状态模型

交付：

- 自有专业窗口守卫；
- 完整扫描、原子提交、节流和 revision；
- readyAt、离线到期和公共组聚合；
- actionable、cooldown、estimated、locked、unknown、not-applicable 状态。

退出条件：不会由链接专业污染当前角色；公共组只计一次；离线到期只变 estimated。

### 阶段 D：账号快照与页面

交付：

- 角色业务快照和摘要；
- 主表、单角色详情、时间格式化；
- 同源 Broker/小地图预览；
- Core 的 GetSummary、GetActions、可见字段和页面刷新。

退出条件：主页面和悬停在同一 revision 下给出完全一致的角色、状态和数量。

### 阶段 E：业务设置与维护能力

交付：

- 专业、组和单项的显示/隐藏/继承；
- previewColumns 适配；
- `/ytd status` 与 `/ytd validate`；
- 角色缓存检查和删除；
- 目录升级后设置覆盖保持。

退出条件：新增测试目录项自动继承父级策略；删除单角色缓存不影响 Core 角色或其它业务插件。

### 阶段 F：验收与 0.1 发布

交付：

- 自动目录校验；
- 游戏内测试记录；
- 版本、说明、变更记录和发布包检查；
- 0.1 已知限制列表。

退出条件：第 17 节所有阻断级用例通过，发布包不包含探针中间输出和未分类测试文件。

## 17. 测试与验收矩阵

### 17.1 目录与迁移

- 重复 activity ID、group ID、recipeSpellID 会被发现；
- 缺失组、空 active 组和冲突规则不会进入正式统计；
- inactive 项目历史仍可迁移，但不显示；
- schema 迁移重复执行结果相同；
- catalogVersion 升级不清空用户设置和角色观察；
- 新项目未设置覆盖时继承专业或上级策略。

### 17.2 采集

- 自己的专业窗口完整扫描成功；
- 数据尚未 ready 时不写半批记录；
- 链接、他人和公会专业不覆盖当前角色；
- 事件连续触发只提交一次完整 revision；
- 制造后能够重扫到冷却；
- API 缺失、返回冲突和目录未命中进入 unknown 或 unavailable；
- 重载界面后保留绝对恢复时间与确认时间。

### 17.3 状态

- 当前确认可用为 actionable；
- 当前确认未到期为 cooldown；
- 离线跨过 readyAt 后为 estimated，不变成 confirmed actionable；
- 无扫描为 unknown；
- 有专业但所有成员未学习为 locked；
- 无对应专业为 not-applicable；
- 多个共享成员只生成一个组状态；
- 组成员原始结果冲突时不选择“更乐观”的结果。

### 17.4 页面与预览

- 2、10、20 名角色时单页信息稳定；
- 21 名角色不会静默丢失，滚动或分页保留固定表头；
- 只有有业务快照且满足准入的角色进入页面与悬停；
- 主表、详情、GetSummary、GetActions 和悬停数量一致；
- estimated、unknown 和 confirmed 不只靠颜色区分；
- 隐藏字段只改变投影，不改变业务状态或数量；
- 账号级区域在 0.1 没有项目时不保留空白。

### 17.5 设置与 Core

- YiboTodo 按技术名字母序进入 Core 设置和业务列表；
- 页面、入口、主表字段、悬停字段和角色排序由 Core 工作台管理；
- 业务设置没有第二套窗口壳；
- 父组隐藏、子项显示和恢复继承行为正确；
- 删除 YiboTodo 角色缓存不删除 Core 角色资料或其它插件数据；
- `/ytd` 打开统一页面，右键入口进入 Core 设置；
- 未启用独立入口时默认只保留 Core 总入口。

### 17.6 性能与可靠性

- 无每帧专业扫描；
- 页面隐藏时无持续倒计时写库；
- 一次完整扫描只产生一次数据库提交和一次页面变更通知；
- 目录校验失败不会阻止 YiboCore 或其它 Yibo 插件加载；
- 无数据、旧数据和错误数据均不会显示成零或已完成。

## 18. 0.1 发布阻断条件

出现以下任一情况不得发布：

- active 冷却条目缺少实机构建验证；
- 链接或他人专业可能污染当前角色；
- 公共冷却成员重复计数；
- estimated 被显示成 confirmed actionable；
- unknown 被显示成完成、零或无待办；
- 主页面与悬停使用不同状态或摘要逻辑；
- 设置升级会重置用户覆盖；
- YiboTodo 创建自己的窗口壳、入口生命周期或角色目录；
- 0.1 包含产品与版本规划明确排除的活动。

## 19. 后续扩展方式

### 19.1 0.2 日常与农场

新增 `DailyQuestProvider` 和 `FarmObservationProvider`，活动继续进入 ActivityCatalog。任务完成用 `completed`，作物生长用 `in-progress` 或 `cooldown`，无法确认的观察用 `unknown`。不得把任务 API 判断塞进 ProfessionCooldown Provider。

### 19.2 账号级项目

布林顿等项目声明 `scope = "account"`，由稳定账号身份保存到 `byAccount`，只进入账号摘要一次。未取得稳定账号身份前不得复制到每个角色模拟账号状态。

### 19.3 1.x–4.x 冷却

按版本规划逐个增加基线文件和当前客户端规则覆盖，不改变 State、Snapshot、页面主列或数据库顶层结构。旧配方仍须按 `5.5.4` 实际行为验证，不能照抄历史持续时间。

### 19.4 事件窗口与三态设置

暗月马戏团等使用 `calendar-window` Schedule；事件关闭时不继续显示为当前待做。0.7 开放已预留的 `display` 模式，只扩展设置控件和统计过滤，不迁移布尔值。

## 20. 开工前检查清单

- [ ] 再次全工作区确认 `/ytd` 未被占用；
- [ ] 确认目标 YiboCore 版本仍为 Public API v5；
- [ ] 确认 Core 当前页面、入口、设置宿主和 CharacterCleanup 签名；
- [ ] 建立 MoP 冷却候选基线，但不把候选直接标记 active；
- [ ] 先完成 Probe 与目录校验，再实现正式状态统计；
- [ ] 确认图标资源存在且外围透明后再写入资源路径；
- [ ] 每个新增活动通过 PRODUCT.md 的 Change Gate；
- [ ] 每阶段完成后更新本文的实际差异和已知限制。

## 21. 实施记录

### 2026-08-28：阶段 A 完成，阶段 B 已启动

- 已创建 `YiboTodo` 插件骨架：`.toc`、命名空间、独立 `YiboTodoDB`、幂等 schema 默认值、目录/规则/校验器、Provider Registry、统一状态模型、内存快照、Core API v5 页面/入口/角色缓存清理和 `/ytd` 命令。
- 已完成全工作区 Slash 注册搜索；`/ytd` 未被其它插件占用。
- 已建立首批 MoP 候选台账和代码目录项，但所有条目均保持 `candidate` 与 `active = false`；规则集的 active 集合为空。这样不会违反“未经 5.5.4 实机验证不得作为正式状态来源”的发布条件。
- `/ytd probe`、`/ytd validate` 与 `/ytd status` 已可用作骨架诊断。正式 Provider 尚拒绝写入观察，因为自有专业窗口归属和当前 API 返回语义尚未取得实机基线。

当前已知限制：尚未有经 5.5.4 实机验证并随发行版启用的冷却条目；因此本开发起点不会把候选条目显示为可制作、冷却中或已完成。专业窗口事件已自动触发采集路径；玩家无需执行探针命令。

### 2026-08-29：首个正式冷却条目

- 根据 5.5.4 游戏内工程学窗口观察，`贾德的特制能量源`（spell `139176`、item `94113`）已进入 active 目录和独立公共冷却组。
- 打开自己的工程学面板后，Provider 会自动找到该配方、读取 API 报告的冷却、写入当前角色的绝对 `readyAt`，并刷新账号待办；未命中配方的其它专业窗口不会创建伪造的“未学习”状态。

### 2026-08-29：锻造独立冷却与行动导向摘要

- `霹雳钢锭`（spell `138646`、item `94111`）与 `两仪延极锭`（spell `143255`、item `98717`）是两个独立的每日冷却组，角色摘要分别显示和统计两项状态。
- 账号页主表改为“角色 / 制造项目 / 状态”。它直接列出项目名称及“需要制作、冷却中、预计可制作”等语义，不再将精确恢复时刻和单纯数量作为主字段。

### 2026-08-29：临时专业槽位矩阵

- 账号页已改为固定行高的“角色 / 专业槽位 1 / 专业槽位 2 / 通用项目”图标矩阵。角色的槽位只读取 `YiboCore.DataDomains` 的 `professions.primaryProfessions`；目录和专业窗口采集器均不能推断或改写专业归属。
- 项目只投影到其 `professionID` 匹配的槽位；同专业的独立冷却在同一单元格横排，溢出以 `+N` 收纳并提供完整悬停说明。无对应专业为 `—`，已确认专业但未采集到支持项目为 `?`，未学习的配方不占图标位。
- 全彩图标表示可制作，灰化加勾表示冷却，细边框表示每日 07:00 重置后的预计可做；项目悬停提供周期、状态、最后确认时间和适用时的恢复时间。账号级项目已预留为矩阵外的单行投影。
