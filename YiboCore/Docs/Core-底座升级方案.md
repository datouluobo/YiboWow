# YiboCore 底座升级方案

> 方案基线：YiboCore `0.5.1` / Public API v4 / Database Schema v6  
> 建议目标：YiboCore `0.6.0` / Public API v5 / Database Schema v7  
> 本方案只升级 Core 底座，不迁移业务插件，不改变业务 SavedVariables 的归属。

## 1. 结论

本轮不是增加页面，而是把 Core 从“一个包含采集、字段、设置和页面实现的大型账号窗口”升级为“由注册信息驱动的账号数据平台”。

完成后，Core 的依赖方向应固定为：

```text
WoW 事件
  -> 数据域采集器
  -> 领域存储与变更通知
  -> 资源定义 / 字段定义
  -> 角色档案页、设置工作台、入口预览等消费者
```

新增一种 Core 中性资源时，正常改动范围应只有：

1. 新增一个领域或资源定义模块；
2. 在 `YiboCore.toc` 中加载该模块；
3. 如资源确实需要新展示形态，在资源自身定义中提供格式化或单元格渲染信息。

不应再修改 `UI/AccountView.lua`、设置工作台、`UI/Entry.lua` 的核心分支。

## 2. 当前基线与主要问题

当前 Core 已经具备插件注册、通用资源占用、页面注册、入口注册、能力查询和内部事件总线，原有基础可以保留。问题主要在更上层的“定义、存储和消费”仍然耦合：

- `Data/Profile.lua` 的 `RefreshCurrent()` 同时采集身份、经济、专业、装备、地点和专精；`RegisterCollector` 只有回调，没有完整的数据域定义、状态和独立更新时间。
- 角色档案字段由 `UI/AccountView.lua` 内的 `CHARACTER_ARCHIVE_FIELDS` 写死；增加资源通常还要继续修改读取、表头、设置、预览和宽度计算。
- Core 内置页面直接写入 `AccountView._pages`，没有使用与业务页面等价的模块注册和生命周期契约。
- `CHARACTER_PROFILE_UPDATED` 是整份角色档案级通知，消费者无法判断具体变化的是货币、专业还是地点，也没有版本、变更字段和批处理语义。
- 设置工作台虽已能托管业务设置，但 Core 内部分区和通用字段开关仍由一个大型刷新函数按分支绘制，缺少正式的设置分区注册表。
- `Registry:ClaimResource()` 能做名称占用，但它不是“资源类型定义”。目前无法描述一种资源的领域、值读取、显示字段、默认可见性和格式化规则。

因此，本轮应保留已有页面和入口能力，将改造重点放在它们的上游。

## 3. 设计边界

### 3.1 Core 拥有的内容

- 跨业务可复用的中性角色事实：身份、经济、声望、专业、装备、地点等。
- 数据域定义、当前角色采集、可用状态、更新时间、快照读取和统一变更通知。
- Core 中性资源定义及其通用显示字段。
- Core 内置功能模块、统一窗口壳、角色档案页和设置工作台。
- 页面、入口、字段、设置分区等全局标识符的注册与冲突诊断。

### 3.2 业务插件继续拥有的内容

- 任务、Boss、收藏、路线、解锁进度等业务事实和规则。
- 业务采集器、业务 SavedVariables、业务页面行渲染器和业务设置校验。
- 业务页面的主表字段和 `settings.previewColumns`。

本轮不得把业务插件的 SavedVariables 搬进 `YiboCoreDB`，也不得要求现有 `RegisterPage`、`RegisterBusinessEntry` 调用立即改写。

### 3.3 “数据域”与“资源”必须区分

- **数据域 Domain**：一组具有共同采集时机、存储边界和可用状态的事实，例如 `economy`、`reputation`、`professions`。
- **资源 Resource**：数据域中的一个可声明、可展示的具体对象，例如金币、某货币、某阵营声望、第一专业。
- **字段 Field**：资源在某个消费者中的显示投影，例如“金币”“地点”“装等”这一列。

三者不能继续混为页面里的硬编码列。

## 4. 目标架构

### 4.1 数据域注册表 `DataDomains`

新增 `Runtime/DataDomains.lua`，管理领域契约，不直接负责 UI。

建议接口：

```lua
YiboCore.DataDomains:Register("YiboCore", {
    id = "economy",
    version = 1,
    events = {
        PLAYER_LOGIN = true,
        PLAYER_ENTERING_WORLD = true,
        PLAYER_MONEY = true,
        CURRENCY_DISPLAY_UPDATE = true,
    },
    Collect = function(context)
        return {
            money = GetMoney(),
            currencies = CollectCurrencies(),
        }, "known"
    end,
})
```

注册校验至少包含：

- `id` 全局唯一，并通过现有 `Registry` 记录 owner；
- `version` 为正整数；
- `events` 只能是事件名集合；
- `Collect` 必须返回领域数据和合法可用状态；
- 一个领域采集失败不得阻塞其它领域；
- 禁止领域直接创建 Frame、页面或入口。

领域公开读取接口：

```lua
local snapshot = YiboCore.DataDomains:Get(characterID, "economy")
local state = YiboCore.DataDomains:GetState(characterID, "economy")
local all = YiboCore.DataDomains:GetDefinitions()
```

每个领域独立维护数据、状态、更新时间和 schema 版本。

### 4.2 领域存储 `DomainStore`

新增 `Data/DomainStore.lua`，是写入 Core 角色事实的唯一入口。数据库建议结构：

```lua
characters.byID[characterID].domains = {
    identity = {
        schemaVersion = 1,
        state = "known",
        updatedAt = 1780000000,
        revision = 8,
        data = { ... },
    },
    economy = {
        schemaVersion = 1,
        state = "known",
        updatedAt = 1780000010,
        revision = 21,
        data = { money = 12345, currencies = { ... } },
    },
}
```

合法状态固定为：

|状态|含义|
|-|-|
|`known`|本次成功采集，数据可用|
|`not-yet-scanned`|当前角色尚未满足采集条件|
|`unavailable`|当前客户端或版本不支持|
|`stale`|保留旧值，但本次无法确认新值|
|`error`|采集器执行失败，保留旧值|

写入必须通过 `DomainStore:Commit(characterID, domainID, data, state, context)` 完成。`Commit` 负责：

- 深比较或由采集器提供 `changedKeys`，无变化时不增加 revision；
- 保存独立更新时间和状态；
- 返回不可变快照副本；
- 生成统一领域变更通知；
- 不允许消费者直接修改数据库中的领域表。

### 4.3 资源注册表 `Resources`

新增 `Runtime/Resources.lua`，用于描述“领域中有哪些可被其它层消费的中性资源”。它与现有 `Registry:ClaimResource()` 的关系是：前者保存完整定义，后者继续负责全局占用和 owner 校验。

建议接口：

```lua
YiboCore.Resources:Register("YiboCore", {
    id = "currency:789",
    domain = "economy",
    kind = "currency",
    title = "勇气点数",
    icon = 463447,
    Read = function(domainData)
        return domainData.currencies and domainData.currencies[789]
    end,
    Format = function(value)
        return value and value.quantity or nil
    end,
})
```

资源定义应当是稳定元数据，不保存角色值。角色值始终保存在领域存储中。资源可来自 Core 内置模块；未来如允许业务插件声明资源，也必须先明确其数据归属，不能借注册表把业务数据变成 Core 数据。

### 4.4 动态字段注册表 `Fields`

新增 `Runtime/Fields.lua`，使角色档案页和设置页读取字段注册结果，而不是读取 `CHARACTER_ARCHIVE_FIELDS`。

建议定义：

```lua
YiboCore.Fields:Register("YiboCore", {
    id = "character.money",
    consumer = "character-archive",
    domain = "economy",
    resource = "money",
    title = "金币",
    order = 30,
    width = 88,
    minWidth = 72,
    maxWidth = 110,
    defaultVisible = true,
    defaultPreviewVisible = true,
    align = "RIGHT",
    Read = function(character, domainData)
        return domainData and domainData.money
    end,
    Format = FormatMoney,
})
```

字段契约包括：

- `id` 全局唯一，`consumer`、`domain` 必须存在；
- `order` 只决定显示顺序，不依赖注册先后；
- 字段自带宽度、默认主表/预览可见性、对齐和格式化信息；
- 简单字段使用通用文本/图标渲染；特殊字段可提供受限的 `RenderCell`，但不得控制窗口壳；
- 字段设置按字段 ID 持久化，未保存时读取定义中的默认值；
- 一个领域缺失或不可用时，字段使用统一的空值/状态呈现。

角色档案页只保留通用表格能力：取得字段列表、计算宽度、创建表头、逐角色读取字段、绘制行。所有具体字段定义移出 `AccountView.lua`。

### 4.5 Core 内置功能模块注册表 `Modules`

新增 `Runtime/Modules.lua`，管理 Core 自己的功能模块及启动顺序。它不是插件加载器，而是消除 `AccountView._pages.xxx = ...` 和初始化分支的内部契约。

建议接口：

```lua
YiboCore.Modules:Register({
    id = "character-archive",
    order = 20,
    requires = { "data-domains", "fields", "account-view" },
    Initialize = function(core)
        core.AccountView:RegisterInternalPage({ ... })
    end,
    Shutdown = function(core) end,
})
```

规则：

- Core 内置页通过 `RegisterInternalPage` 注册，业务页继续使用 `RegisterPage(addonName, definition)`；
- 模块按 `requires` 做拓扑排序，循环依赖和缺失能力必须给出明确诊断；
- `Initialize` 只能执行一次，单模块失败不得产生半注册资源；
- 本轮内置模块至少拆为 `overview`、`character-archive`、`settings-workbench`、`about`。

### 4.6 统一变化通知

保留 `Core.Events` 作为底层事件总线，新增正式的数据变化协议，不再让消费者猜测 WoW 原始事件。

统一事件：

```lua
Core.Events:Fire("DATA_DOMAIN_UPDATED", {
    characterID = characterID,
    domainID = "economy",
    revision = 21,
    changedKeys = { money = true },
    reason = "PLAYER_MONEY",
    updatedAt = now,
})
```

通知链固定为：

```text
WoW 原始事件
  -> DataDomains 只调度订阅该事件的采集器
  -> DomainStore:Commit
  -> DATA_DOMAIN_UPDATED
  -> AccountView / 当前可见预览按需刷新
```

为避免 `PLAYER_ENTERING_WORLD` 等事件导致连续重绘，应增加同帧合并：同一角色、同一领域在一次 UI tick 内只刷新一次；账号窗口隐藏时只记录 dirty 标记，打开时再刷新。

兼容期继续发送 `CHARACTER_PROFILE_UPDATED`，但它由领域通知适配器合并产生，不再由每个采集函数直接触发。新代码只订阅 `DATA_DOMAIN_UPDATED`。

### 4.7 设置分区注册表 `SettingsRegistry`

新增 `Runtime/SettingsRegistry.lua` 和独立的 `UI/SettingsWorkbench.lua`。设置定义负责“有哪些分区和控件”，工作台负责统一渲染、滚动、双栏布局和持久化。

建议接口：

```lua
YiboCore.SettingsRegistry:RegisterSection("YiboCore", {
    id = "character-archive.fields",
    group = "display-entry",
    title = "角色档案字段",
    order = 30,
    Build = function(context)
        return context:BuildFieldToggles("character-archive")
    end,
})
```

固定分区仍遵循仓库约定：

- Core 常规设置：`窗口`、`角色与排序`、`显示与入口`；
- 业务插件页：`页面与入口`、`显示与排序`、`业务设置`、`数据与缓存`；
- 插件导航按技术名字母序排列；
- 破坏性动作只能位于 `数据与缓存` 末尾。

动态字段开关由 `Fields:GetByConsumer()` 自动生成，新增字段不需要再修改设置刷新函数。现有业务插件的 `settings.CreateSettingsPanel` 由兼容适配器继续托管。

## 5. 内置领域拆分

建议把当前 `Profile:RefreshCurrent()` 拆为以下 Core 内置领域：

|领域 ID|负责数据|主要事件|
|-|-|-|
|`identity`|角色 ID、名称、服务器、等级、阵营、种族、性别、公会|登录、进入世界、升级|
|`economy`|金币、货币|登录、进入世界、金钱、货币变化|
|`reputation`|声望快照及可用状态|登录、进入世界、声望变化|
|`professions`|主副专业及技能等级|登录、进入世界、技能变化|
|`equipment`|装等及以后可扩展的装备摘要|登录、进入世界、装备变化|
|`location`|区域、子区域、地图 ID|登录、进入世界、区域变化|
|`specialization`|当前专精|登录、进入世界、专精变化|

身份领域与 `Characters` 的关系：`Characters` 继续负责稳定角色目录和别名；`identity` 保存可展示的身份事实。两者不能各自生成角色 ID。

声望领域可以先只建立注册、状态和通知能力，不要求本轮一次性实现所有阵营数据。底座验收关注的是以后添加声望资源时不再修改账号窗口核心。

## 6. 兼容与迁移策略

### 6.1 Public API

- Public API 从 v4 升为 v5；v4 页面和入口 API 在整个 `0.6.x` 保持可用。
- `Profile:Get(characterID)` 继续返回旧的聚合快照结构，由各领域投影生成。
- `Profile:RegisterCollector(name, callback, events)` 标记为兼容 API；内部转接到一个 `legacy-collectors` 扩展阶段，不再允许它写入新的领域元数据。
- `AccountView:RegisterPage`、`Entry:RegisterBusinessEntry`、`CharacterCleanup:RegisterOwner` 不改签名。
- `CHARACTER_PROFILE_UPDATED` 在 `0.6.x` 保留；文档明确新订阅者改用 `DATA_DOMAIN_UPDATED`。

不在本轮保留旧 Slash 命令别名；Core 正式命令仍为三字母 `/yco`，无需变更。

### 6.2 Database Schema v7

迁移步骤只新增 `character.domains` 容器，不立即删除旧的 `profile`、`observedAt`、`availability` 字段：

1. v7 迁移为每个角色建立 `domains`；
2. 首次读取时可从旧字段投影出领域快照；
3. 当前角色首次成功采集某领域后，以新领域数据为准；
4. `Profile:Get` 优先读新领域，缺失时回退旧字段；
5. 只有在后续独立版本确认所有已发布版本均已完成迁移后，才另立任务删除旧字段。

该策略避免一次迁移中重写大量用户存档，也保留降级到 `0.5.1` 的最大可读性。

### 6.3 设置迁移

现有 `settings.accountView.characterArchive.fields` 与 `previewFields` 按旧字段 ID 映射到新字段 ID：

```text
identity -> character.identity
level -> character.level
itemLevel -> character.item-level
zone -> character.zone
primary -> character.profession-primary
secondary -> character.profession-secondary
```

未列出的旧字段继续通过固定映射迁移。迁移不得因为字段暂时未注册而丢弃用户选择；未知字段保留，待相应模块重新出现后恢复。

## 7. 文件与加载顺序

建议目标结构：

```text
YiboCore/
  Runtime/
    Registry.lua                 # 保留：owner 与全局 ID 占用
    Events.lua                   # 保留：底层事件总线
    DataDomains.lua              # 新增：领域定义与事件调度
    Resources.lua                # 新增：资源定义
    Fields.lua                   # 新增：字段定义
    Modules.lua                  # 新增：Core 内置模块生命周期
    SettingsRegistry.lua         # 新增：设置分区定义
  Data/
    DomainStore.lua              # 新增：领域快照、状态、revision、通知
    Profile.lua                  # 收缩为旧 API 聚合适配器
    Domains/
      Identity.lua
      Economy.lua
      Reputation.lua
      Professions.lua
      Equipment.lua
      Location.lua
      Specialization.lua
  UI/
    AccountView.lua              # 收缩为窗口壳、导航、页面 host
    CharacterArchive.lua         # 新增：注册驱动的通用角色档案表
    SettingsWorkbench.lua        # 新增：注册驱动的设置工作台
    Overview.lua
    About.lua
    Entry.lua                    # 保持入口职责，不读取具体领域
```

`YiboCore.toc` 的顺序必须保证：基础工具 -> Registry/Events -> 各注册表 -> Database/Migrations/DomainStore -> 内置领域 -> UI host -> 内置模块 -> Entry -> Bootstrap 生命周期。

## 8. 分阶段实施

### 阶段 A：冻结契约并建立测试脚手架

- 固化 v4 兼容面和 v5 新接口草案。
- 增加可在 WoW 外运行的 Lua 注册表测试，模拟 `CreateFrame`、时间函数和事件分发。
- 为重复 ID、错误 owner、依赖缺失、回调异常和注册排序建立测试。

验收：现有三个依赖 Core 的业务插件无需修改即可完成注册；测试能验证失败注册不会污染注册表。

### 阶段 B：领域存储与统一通知

- 实现 `DataDomains`、`DomainStore`、状态枚举、revision 和同帧通知合并。
- 生命周期 Frame 不再无条件调用整个 `Profile:RefreshCurrent()`，改为按事件调度领域。
- 建立 `CHARACTER_PROFILE_UPDATED` 兼容适配器。

验收：`PLAYER_MONEY` 只采集 `economy`；其余领域 revision 不变；账号窗口打开时自动刷新，隐藏时不产生无效重绘。

### 阶段 C：拆分现有角色档案采集

- 依次迁移 identity、location、equipment、specialization、professions、economy。
- 增加 reputation 空壳和首个可验证资源，确认扩展路径成立。
- `Profile.lua` 收缩为聚合读取与旧采集器适配。

验收：迁移前后 `Profile:Get()` 的公开字段兼容；每个领域有独立状态和更新时间；单个领域报错不会阻断其它领域。

### 阶段 D：资源与动态字段

- 实现 `Resources`、`Fields` 及冲突校验。
- 将角色档案硬编码字段迁移为字段定义模块。
- 新建通用角色档案表，仅消费注册字段。

验收：新增一个测试货币字段只增加定义模块和 TOC 行；主表、悬停字段清单及宽度计算自动出现，不修改 AccountView。

### 阶段 E：设置分区与内置模块

- 实现 `SettingsRegistry`、`SettingsWorkbench` 和 `Modules`。
- 将四个 Core 内置页面迁移到模块注册。
- 将角色档案字段、预览字段开关改为动态生成。
- 通过适配器继续承载业务插件 `CreateSettingsPanel`。

验收：Core 内部不再直接写 `AccountView._pages`；设置导航顺序稳定；新增字段无需修改设置代码；业务设置页面外观与行为不退化。

### 阶段 F：兼容回归与发布

- 执行无业务插件、单插件、三个业务插件组合测试。
- 验证窗口、Core/业务 Broker、小地图悬停、字段设置、角色排序和缓存删除。
- 验证 schema v6 -> v7、旧设置字段映射、降级可读性和 `/reload` 持久化。
- 更新 README、CHANGELOG、Public API 示例和完整验收清单。

验收：所有回归通过后再发布 `0.6.0`；业务插件迁移新 API 另开任务，不能混入本轮底座改造。

## 9. 验收清单

### 9.1 架构验收

- [ ] `Profile:RefreshCurrent()` 不再包含所有领域的采集分支。
- [ ] `AccountView.lua` 不再定义角色档案具体字段。
- [ ] Core 内置页面不再直接写入 `AccountView._pages`。
- [ ] 设置工作台不再逐字段硬编码角色档案开关。
- [ ] `Entry.lua` 不读取任何具体领域或资源。

### 9.2 扩展性验收

- [ ] 新增一种领域只需领域模块和 TOC 加载项。
- [ ] 新增一种普通资源及字段只需资源/字段定义和 TOC 加载项。
- [ ] 新增字段后主表、设置与悬停预览使用同一个字段定义。
- [ ] 重复领域、资源、字段、设置分区或模块 ID 会失败并返回 owner 诊断。

### 9.3 数据与通知验收

- [ ] 每个领域独立保存 `state`、`updatedAt`、`revision` 和 `schemaVersion`。
- [ ] 数据无变化时不触发领域更新通知。
- [ ] 领域更新只刷新相关的可见页面/预览。
- [ ] 单领域异常保留旧数据并标为 `error` 或 `stale`，其它领域继续更新。
- [ ] 旧 `Profile:Get` 与 `CHARACTER_PROFILE_UPDATED` 在兼容期保持可用。

### 9.4 UI 与设置验收

- [ ] 角色档案主表和悬停使用同一字段集合与格式化逻辑。
- [ ] 字段显示设置按稳定字段 ID 持久化。
- [ ] Core 设置导航和业务插件顺序符合统一设置工作台约定。
- [ ] 页面、Broker 和小地图入口行为无回归。
- [ ] 最多 20 名角色的悬停预览与正式账号快照一致。

## 10. 风险与控制

|风险|控制方式|
|-|-|
|一次性拆分 `AccountView.lua` 导致 UI 回归|先建立注册层和兼容层，再逐个迁移内置页面；每阶段保持可运行|
|领域拆分产生重复采集或事件风暴|事件到领域建立静态索引；同帧合并通知；无变化不递增 revision|
|迁移破坏用户旧存档|Schema v7 只增不删；新读旧写兼容；删除旧字段另立版本|
|通用字段契约过度复杂|v1 只支持文本、图标、状态色和受限自定义单元格；不设计通用页面 DSL|
|资源注册被误用来收编业务数据|注册时校验 owner 和 domain；文档明确 Core 中性资源边界|
|新 API 迫使业务插件同步发布|v4 API 在整个 0.6.x 保持可用；业务迁移单独排期|

## 11. 本轮明确不做

- 不新增大量账号页面。
- 不统一所有业务页面的矩阵布局。
- 不把业务数据迁入 `YiboCoreDB`。
- 不重写三个业务插件的页面、入口或设置。
- 不在第一版字段系统中实现任意布局 DSL。
- 不删除旧档案字段、旧事件或旧 API。
- 不把测试资源或诊断资源默认显示给正式用户。

## 12. 完成定义

本轮只有在以下场景成立时才算完成：新增一种 Core 中性资源时，开发者只新增领域/资源/字段定义模块并在 TOC 中加载；角色档案页、悬停预览和设置工作台能够自动识别它，领域数据变化能够自动通知并刷新相关消费者，同时现有业务插件无需同步修改即可继续运行。
