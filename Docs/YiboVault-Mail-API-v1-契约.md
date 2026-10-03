# YiboVault / YiboMail Public API v1 契约

> 状态：YiboVault `1.0.0-api1` 的 Items API v1 已实施；YiboMail `0.4.0-api1` 已实施公开附件接口、原生邮箱增强、Core 业务面板及三标签设置，游戏内验收及 Vault 双插件适配待完成。2026-10-01。
>
> 适用范围：YiboVault 物品查询 API、YiboMail 邮件附件来源 API，以及二者的状态、范围和变更通知语义。
>
> 决策门：字段与接口形状已冻结；标记为“待客户端验证”的采集字段在 5.5.4 客户端实测前保持可空，不能成为阶段 1 的强依赖。

## 1. 版本、命名与所有权

- `YiboVault.Items.API_VERSION = 1`；`YiboMail.Items.API_VERSION = 1`。业务 API 版本独立于 `YiboCore.API_VERSION`。
- `YiboVaultDB` 保存 Vault 采集的实体容器、本人拍卖行和精简邮箱附件快照；`YiboMailDB` 保存 Mail 自己的邮件快照、归档和规则。两个插件均可独立安装、独立采集。
- 双插件共存时，Vault 对每个角色优先选择兼容的 `YiboMail.Items` 公开附件来源；Mail 数据不可用时使用 Vault 自有快照。一个角色一次查询只能选择一份邮箱来源，不能叠加。Vault 不读取 `YiboMailDB` 私有表。Vault 的 `MailProvider` 已接入 v1，并复用同一来源供查询、仓储页和 tooltip；Mail 的变更只在 Vault 邮件投影实际改变时转发一次事件。
- 所有公共查询返回新建的 Lua table 投影。调用方可以修改返回值，但修改不会写回提供者。
- 时间戳均为 Unix 秒；优先使用 `GetServerTime()`，不可用时使用 `time()`，并在记录的 `clockSource` 中注明 `server` 或 `client`。

## 2. 公共枚举

### 2.1 来源 ID

| `source` | 所有者 | 类别 | 是否进入实体小计 |
|---|---|---|---|
| `bags` | Vault | `physical` | 是 |
| `equipment` | Vault | `physical` | 是 |
| `bank` | Vault | `physical` | 是 |
| `guild-bank` | Vault | `physical` | 是 |
| `auction` | Vault | `listed` | 否 |
| `mail` | Vault 自有快照；未来可切换至 Mail 公共来源 | `external` | 否 |

`totalQuantity = physicalQuantity + listedQuantity + externalQuantity`。接口必须同时返回三类小计，调用方不得把 AH 上架或待取邮件描述成背包/银行实体库存。

### 2.2 来源状态

| `status` | 语义 | 可否把数量当作零 |
|---|---|---|
| `not-installed` | 可选提供者未安装 | 否 |
| `incompatible` | 提供者存在但 API/能力不兼容 | 否 |
| `not-yet-scanned` | 该位置或邮箱从未成功采集 | 否 |
| `unavailable` | 当前场景或权限不允许读取 | 否 |
| `partial` | 已读取可见部分，仍有明确未暴露内容 | 否 |
| `error` | 最近一次采集失败 | 否 |
| `stale` | 有旧缓存，但当前状态未知 | 否；可显示旧缓存 |
| `known-empty` | 最近一次完整采集成功且没有记录 | 是，仅限对应位置 |
| `known` | 最近一次完整采集成功且有记录 | 是 |

只有同一个位置完成一次成功扫描，才能写入 `known-empty`。其它来源的变化不能推断本来源变空。

### 2.3 记录状态

- Vault 实体与 AH 当前记录使用 `observed`；旧但仍保留的记录使用 `stale`。
- Mail 待取附件使用 `observed`；邮件归档后不再出现在 `YiboMail.Items` 当前来源查询中。
- `collected-archived`、`return-confirmed`、`unverified` 等邮件生命周期状态属于 Mail 邮件查询，不作为 Vault 当前持有量记录返回。

## 3. 物品身份

每条物品记录必须包含：

```lua
{
  itemID = 12345,                 -- 正整数，必填
  itemLink = "|c...|Hitem:...|h...|h|r", -- 可空
  itemKey = "item:12345",        -- itemID 汇总键，必填
  variantKey = "link:item:item-string", -- 严格变体键，必填
  identityQuality = "full-link", -- full-link | item-id-only
}
```

- `itemKey` 固定为 `item:<itemID>`，用于普通物品 ID 汇总。
- 能取得链接时，`variantKey` 使用 `link:<hyperlinkType>:<完整 payload>`。普通物品链接的类型为 `item`，payload 是 `Hitem:` 与 `|h` 之间的完整 item string；宠物笼等来源可能返回 `battlepet` 或其它链接类型，同样保留完整 payload。v1 不删除 enchant、gem、suffix、upgrade 或其它字段，优先避免把不等价变体错误合并。
- 不能取得链接时，`variantKey = itemKey`，同时 `identityQuality = "item-id-only"`。
- `identityMode = "item-id"` 按 `itemKey` 汇总；`identityMode = "strict"` 按 `variantKey` 汇总。默认是 `item-id`。
- 阶段 0 客户端验证会记录完整 item string 中哪些字段仅造成过度拆分；v1 只能通过新增可选字段优化，不得改变既有 key 的含义。

## 4. 范围契约

公共查询统一接受：

```lua
scope = nil
-- 或
scope = { mode = "characters", characterIDs = { "Name-Realm", ... } }
-- 或
scope = { mode = "realm", realm = "Realm Name" }
-- 或
scope = { mode = "account" }
```

- `scope == nil` 固定表示 Core 当前登录角色，不读取任何页面的暂存选择。
- 后台消费者必须显式传入范围；`account` 表示 Core 角色目录中未被统一隐藏的角色。`realm` 也只从未隐藏角色中精确匹配服务器。`characters` 只按传入的 ID 选择 Core 已记录角色，允许调用方显式查询被界面隐藏的角色；重复 ID 只返回一次，并保留首次出现的顺序。空 `characterIDs` 返回空范围。
- Core 页面和悬停必须从同一次 `context.characters` 构造 `characters` 范围，因此页面、预览与 API 使用完全相同的角色切片和顺序。
- `realm` 使用 Core 角色记录中的原始 `realm` 字符串精确匹配。Vault/Mail 不另造服务器合并或别名规则。
- Vault 的 `scope` 必须是上述形状。非法模式、缺少 `realm`、非字符串角色 ID、稀疏角色数组等返回 `nil, "invalid-scope"`；有效但当前目录中找不到的 ID 返回正常的空结果，不视为参数错误。
- 公会银行记录按 `guildKey` 过滤和计数，不因访问角色同时落入多个角色范围而重复计数。默认只有查询允许 `guild-bank` 且范围中至少有一个对应公会角色时才纳入；显式指定 `guildKey` 时可读取该公会的已存快照。
- 被用户隐藏的公会银行快照仍会采集和保存，但默认 `Query`、`GetSourceState`、`GetStorageSummary` 均排除它。`Query({ includeHiddenGuilds = true })` 将范围内关联的隐藏公会纳入结果；`Query({ guildKey = key })` 只读取指定的已缓存公会银行，即使它被隐藏或当前角色目录已无法关联。显式 `guildKey` 不改变角色个人库存的范围。`GetSourceState(source, scope, options)` 与 `GetStorageSummary(scope, options)` 的可选 `options` 支持同样两个字段。参数类型错误分别返回 `invalid-include-hidden-guilds`、`invalid-guild-key`。
- `guildKey` 由 Core 角色档案中精确的 `realm` 与 `guild` 共同生成稳定的不透明键；不得包含访问角色 ID。相同服务器、相同公会名的角色必须命中同一键，公会名缺失时不得创建新的公会银行快照。旧版快照若保存了访问角色 ID，且该角色当前无公会名、服务器一致，可作为历史关联读取；其记录保持 `stale`，当前已有公会名时不得用历史关联覆盖。

## 5. 通用来源记录

```lua
{
  sourceID = "bags:Name-Realm:0:12", -- 提供者内稳定匹配键
  source = "bags",
  sourceClass = "physical",
  itemID = 12345,
  itemLink = nil,
  itemKey = "item:12345",
  variantKey = "item:12345",
  identityQuality = "item-id-only",
  quantity = 20,
  characterID = "Name-Realm",       -- 角色来源必填
  realm = "Realm Name",
  guildKey = nil,                    -- 公会银行来源使用
  location = { container = 0, slot = 12 },
  observedAt = 1790200000,
  clockSource = "server",
  state = "observed",
}
```

- `quantity` 必须是大于 0 的整数。空位置不生成记录，由位置覆盖状态表达。
- `sourceID` 只用于同一提供者内定位和替换，不宣称为暴雪永久 ID。
- 公会银行记录以 `guildKey` 与 `location.tabID` 标识共享页签，不设置角色库存归属；`visitorCharacterID` 仅记录最近一次改变该快照的访问角色，查询须按范围内角色的服务器与公会名匹配，并对同一 `guildKey` 只计一次。
- Mail 提供者的记录可额外包含 `mailKey`、`attachmentIndex`、`expiresAtEstimate`、`daysLeftAtScan`、`sender`、`subject` 与 `mailType`；Vault 自有精简附件记录仅保证位置中的 `attachmentIndex`，不伪造邮件生命周期字段。
- AH 记录额外包含可取得的 `auctionID`、`stackCount`、`unitPrice`、`buyoutAmount`、`timeLeft`；字段均待客户端验证并保持可空。

## 6. YiboMail.Items v1

### 6.1 能力

```lua
YiboMail.Items:GetAPIVersion()                         -- 1
YiboMail.Items:GetCapabilities()                       -- 返回副本
YiboMail.Items:HasCapability(name, minimumVersion)     -- boolean, availableVersion
```

v1 冻结能力：

```lua
{
  ["mail-items.query"] = 1,
  ["mail-items.state"] = 1,
  ["mail-items.events"] = 1,
}
```

### 6.2 查询

```lua
YiboMail.Items:GetByCharacter(characterID, options)
YiboMail.Items:Query({
  scope = scope,
  itemID = 12345,              -- 可空
  identityMode = "item-id",   -- item-id | strict
  variantKey = nil,            -- strict 查询可传
  includeStale = true,         -- 默认 true
})
YiboMail.Items:GetState(characterID)
YiboMail.Items:GetRevision()
```

`Query` 返回：

```lua
{
  apiVersion = 1,
  revision = 42,
  generatedAt = 1790200100,
  records = { ... },
  quantity = 20,
  coverage = {
    [characterID] = {
      status = "known", currentCount = 3, totalCount = 3,
      unscannedCount = 0, observedAt = 1790200000, revision = 7,
    },
  },
}
```

`GetByCharacter(characterID, options)` 等价于把 `scope = { mode = "characters", characterIDs = { characterID } }` 合入 `options` 后调用 `Query`，返回相同结构。

`currentCount` 是本次客户端可见且已扫描的邮件数；`totalCount` 是客户端返回的总数。仅当 `currentCount < totalCount` 时写入 `partial` 与 `unscannedCount`。不能把未扫描数量转换为虚构附件。
`unscannedCount` 精确表示**本轮未暴露**的数量，不声明这些邮件是否曾在以前的批次被本地缓存。Mail 可为先前已见、当前被 100 封上限遮住的邮件保留历史／待核实记录；当前附件来源查询仍仅返回最近一次有效可见扫描中的附件。后续批次一旦显现，Mail 应读取其明细并纳入持久缓存。

### 6.3 事件

```lua
YiboMail.Items.Events:Register(owner, callback)
YiboMail.Items.Events:Unregister(owner, callback) -- callback 可空，表示注销 owner 全部订阅
```

回调签名为 `callback(eventName, payload)`；v1 事件名固定为 `MAIL_ITEMS_CHANGED`：

```lua
{
  apiVersion = 1,
  revision = 42,
  characterID = "Name-Realm",
  changedMailKeys = { ... },
  changedItemIDs = { 12345, 67890 },
  reason = "scan", -- scan | collect | archive | cleanup | migration
  observedAt = 1790200000,
}
```

同内容扫描不得增加 revision 或广播事件。数组去重并升序排序，保证消费者可以稳定比较。

## 7. YiboVault.Items v1

### 7.1 能力

```lua
YiboVault.Items:GetAPIVersion()
YiboVault.Items:GetCapabilities()
YiboVault.Items:HasCapability(name, minimumVersion)
```

当前已声明能力：

```lua
{
  ["items.query"] = 1,
  ["items.personal-counts"] = 1,
  ["items.state"] = 1,
  ["items.events"] = 1,
  ["storage.summary"] = 1,
  ["source.bags"] = 1,
  ["source.equipment"] = 1,
  ["source.bank"] = 1,
  ["source.guild-bank"] = 1,
  ["source.auction"] = 1,
  ["source.mail"] = 1,
}
```

`source.auction` 已通过客户端检查；`source.mail` 已接入 Vault 精简采集，基础游戏内附件扫描已由截图确认，大量邮件仅部分可见的边界仍待验收。未声明的能力不得按已知空处理。个人银行采集仅在 `BANKFRAME_OPENED` 后完成稳定扫描时写入已知快照；公会银行按页签更新，以 `guildKey + tabID` 去重，绝不按访问角色重复累计。

### 7.2 个人库存批量计数

```lua
local result, errorCode = YiboVault.Items:GetPersonalCounts({
  scope = { mode = "characters", characterIDs = { "角色 ID", ... } },
  itemIDs = { 72988, 888 },
})
-- result = {
--   apiVersion = 1, revision = 42,
--   characters = {
--     [characterID] = {
--       coverage = { bags = { hasSnapshot = true }, bank = { hasSnapshot = false },
--         equipment = { hasSnapshot = true } },
--       items = { [72988] = { bags = 4, bank = nil, equipment = 1 } },
--     },
--   },
-- }
```

范围规则与 `Query` 相同。`itemIDs` 是正整数连续数组，重复 ID 只返回一次；空数组只返回覆盖状态。非法参数返回 `nil, "invalid-options"`、`nil, "invalid-scope"` 或 `nil, "invalid-item-ids"`。背包、个人银行与装备各来源独立判断：已扫描且没有该物品返回 `0`，未扫描返回 `nil`。邮件、拍卖和公会银行不进入此计数。结果是新建投影，调用方修改不会写回 Vault。

Vault 在加载后跨帧建立只含数量的运行时索引；索引尚未就绪时返回 `nil, "index-pending"`，不在调用栈中扫描全账号物品。建成后发出 `VAULT_PERSONAL_COUNTS_READY`，之后个人来源变化会先更新对应角色与来源的索引，再发出 `VAULT_ITEMS_CHANGED`。调用方可在这两个事件后重新构建视图。索引不写入 SavedVariables；`revision` 与 Vault 全局修订一致。

### 7.3 查询

```lua
YiboVault.Items:Query({
  scope = scope,
  itemID = 12345,                 -- 可空；为空时用于搜索/全量浏览
  identityMode = "item-id",
  variantKey = nil,
  sources = { "bags", "equipment" }, -- 可空，默认全部已实现来源
  includeStale = true,
})
YiboVault.Items:GetSourceState(source, scope)
YiboVault.Items:GetRevision()
```

`Query` 可省略 `options`，等同 `{}`。`itemID` 如提供必须是正整数；`identityMode` 只能是 `item-id` 或 `strict`；`variantKey` 只允许与 `strict` 一起使用且必须为非空字符串；`includeStale` 必须为布尔值；`sources` 必须是已声明来源 ID 构成的连续数组，空数组表示不查询任何来源，重复 ID 只查询一次。`strict` 未给 `variantKey` 时返回各变体的原始记录，不自动按变体合并。`totals` 只对返回的记录求和。

无效参数返回 `nil, errorCode`，不返回伪装成零库存的空结果。错误码固定为 `invalid-options`、`invalid-scope`、`invalid-item-id`、`invalid-identity-mode`、`invalid-variant-key`、`invalid-include-stale`、`invalid-sources`、`invalid-include-hidden-guilds`、`invalid-guild-key`；`GetSourceState` 对未知来源返回 `nil, "invalid-source"`。`GetStorageSummary(scope, options)` 使用同一范围校验。查询为只读操作，不触发采集。

返回：

```lua
{
  apiVersion = 1,
  revision = 9,
  generatedAt = 1790200100,
  identityMode = "item-id",
  records = { ... },
  totals = {
    totalQuantity = 25,
    physicalQuantity = 20,
    listedQuantity = 3,
    externalQuantity = 2,
    bySource = { bags = 20, auction = 3, mail = 2 },
  },
  coverage = {
    bags = {
      ["Name-Realm"] = {
        locations = {
          ["0"] = { status = "known", completedScan = true,
                    revision = 4, observedAt = 1790200000 },
        },
      },
    },
    mail = {
      ["Name-Realm"] = { status = "not-yet-scanned", locations = {} },
    },
  },
}
```

`coverage[source][characterID]` 与 `GetSourceState(source, scope)[characterID]` 采用相同结构：`locations[locationKey]` 保存逐位置状态；从未扫描时才在持有者层设置 `status = "not-yet-scanned"`，并返回空 `locations`。已扫描持有者不提供合成的总状态，调用方逐位置读取 `status`。公会银行以 `guildKey` 代替 `characterID`；位置键为页签 ID 字符串。`GetSourceState` 返回所选来源的所有范围内持有者，`Query.coverage` 只返回所选来源。返回表及其子表均是副本，修改结果不会写回缓存。

空 `records` 只表示当前查询范围与已选来源没有匹配缓存。调用方必须结合 `coverage` 判断是否存在 `known-empty`，不能把空数组描述成全账号零库存。

`totals` 始终只汇总本次返回的 `records`。当 `includeStale = true` 时可能包含不同时间采集的旧记录；调用方必须保留各记录与 coverage 的 `observedAt/status`，不得将合计描述成服务器实时精确库存。

### 7.4 仓储容量摘要

调用前检查 `Items:HasCapability("storage.summary", 1)`。`Items:GetStorageSummary(scope)` 使用第 4 节的同一范围规则；无效范围返回 `nil, "invalid-scope"`。不传 `scope` 只查询当前角色及其公会。接口只读，不触发采集，结果及嵌套表均为副本。

```lua
{
  apiVersion = 1,
  revision = 9,
  characters = {
    { characterID = "Name-Realm", realm = "Realm Name",
      bags = area, bank = area, equipment = area, mail = area },
  },
  guilds = {
    { guildKey = "opaque-key", guildName = "Guild", realm = "Realm Name",
      tabs = area },
  },
}

area = {
  locations = {
    { locationKey = "0", status = "known", completedScan = true,
      capacity = { totalSlots = 20, freeSlots = 8, bagName = "Herb", bagType = 2 } },
  },
  totalSlots = 20,       -- 没有任何已知容量时为 nil
  freeSlots = 8,         -- 已知容量中缺失空槽信息时为 nil
  capacityLocations = 1,
  freeLocations = 1,
  hasStale = false,
  completeCapacity = true,
}
```

`characters` 只列出至少一个区域有完整扫描记录的角色；未扫描区域的字段为 `nil`，不得解释为容量 0。`guilds` 按范围内角色所关联的 `guildKey` 去重，不把公会共享容量累计到个人角色。区域仅纳入 `completedScan` 的位置；有历史记录可验证的旧版公会页签保留为 `stale`，其未知容量仍为 `nil`。`locations` 按位置键排序，单位置容量字段来自采集快照。部分位置缺失容量时，`totalSlots` 仅为已知位置的小计，`completeCapacity = false`；`freeSlots` 只有所有已知容量位置均有空槽数据时才返回。调用方不得根据物品记录数推算容量。

### 7.5 事件

```lua
YiboVault.Items.Events:Register(owner, callback)
YiboVault.Items.Events:Unregister(owner, callback)
```

库存变更事件为 `VAULT_ITEMS_CHANGED`；payload 含 `apiVersion`、全局 `revision`、`source`、可空 `characterID`/`guildKey`、去重升序的 `changedItemIDs`、`reason` 与 `observedAt`。`reason` 目前为 `scan`、`visibility` 或 `cleanup`。物品、容量、页签名称、可见邮件数或位置覆盖状态改变时，先提交记录与覆盖状态，再增加全局 revision 并通知；回调可立即查询到与 payload.revision 一致的快照。只有状态或容量改变时，`changedItemIDs` 可以是空数组。Mail 适配器收到 `MAIL_ITEMS_CHANGED` 后只失效 `mail` 聚合，并在查询结果实际变化时广播一次 Vault 事件。个人库存运行时索引首次建成后另发 `VAULT_PERSONAL_COUNTS_READY`，payload 为 `{ apiVersion = 1, revision = 当前修订 }`；该通知不会改变 revision。

## 8. 缓存替换、revision 与幂等

1. 采集器先建立完整的单位置候选快照，再原子替换该位置；不得边遍历边删除旧记录。
2. 比较时忽略 `observedAt`、`clockSource` 和访问公会银行的角色 ID。同内容、同容量、同位置元数据、同覆盖状态的重复扫描只更新观测时间，不增加 revision、不广播变更；`stale/error → known/known-empty`、扫描失败、银行位置失去可见性、容量或页签名称变化均属于可观察变化，须增加 revision 并广播。相同错误重复出现不重复通知。位置 `coverage.revision` 与该次事件的全局 revision 一致。
3. 更新 `bags` 的一个 container 不能改写 `equipment`、`bank`、其它角色或其它 bag container。
   - `equipment` 以角色槽位 `1..19` 的一次完整读取为替换边界。`UNIT_INVENTORY_CHANGED` 的参数不作为槽位定位依据；收到事件后重扫整套装备，已卸下槽位必须从新快照消失，未变化槽位保持相同业务身份。
4. 个人银行只有在收到 `BANKFRAME_OPENED` 后完成的稳定扫描才能替换正式缓存。银行关闭时客户端可能仍暴露基础银行容器；该可读性不能建立 `known/known-empty`，也不能清空未暴露的银行包。
   - 银行打开期间，`PLAYERBANKSLOTS_CHANGED(slot)` 标记基础银行容器，`BAG_UPDATE(bagID)` 标记对应的银行包或同时受影响的角色背包；`BAG_UPDATE_DELAYED` 是统一读取并提交脏容器的稳定边界。
   - `BANKFRAME_CLOSED` 只结束开放状态。若没有在关闭前完成稳定扫描，不得用关闭后的残留可读容器替换正式银行缓存。
5. 公会银行以 `guildKey + tabID` 为替换边界；访问角色只记入 `observedByCharacterID`，不参与数量主键。
   - 打开公会银行后，Vault 应按权限顺序调用 `QueryGuildBankTab(tabID)` 请求全部可查看页签，并在每次异步更新完成后再读取和推进下一页；玩家不需要手动切换页签。
   - 单页请求失败、超时或无权限时只把该页标为 `unavailable/error`，不得清空旧页签缓存，也不得阻塞其它页签完成。
   - 同一公会的其它角色再次扫描时，逐页替换同一组公会快照并更新 `observedByCharacterID`；不得新增一组角色私有副本，也不得把两次扫描数量相加。
6. 本人 AH 列表以一次主动查询完成后的结果为替换边界。
   - 收到 `AUCTION_HOUSE_SHOW` 后，Vault 应调用 `C_AuctionHouse.QueryOwnedAuctions({{ sortOrder = 1, reverseSort = false }})`；该流程不得依赖玩家进入“取消”页或任何特定 AH 页签。
   - 只有对应的 `OWNED_AUCTIONS_UPDATED` 到达后，才读取本人拍卖并建立 `known/known-empty`。打开瞬间尚未查询的 0 条不得覆盖旧缓存。
   - 查询失败、超时或在完成前关闭 AH 时保留旧缓存，并把本次覆盖状态标为 `unavailable/error`。
   - AH 关闭后，本人拍卖 API 可能返回空列表；关闭状态下的读取不得建立 `known-empty`、刷新 `observedAt` 或覆盖最后一次成功查询。移除/成交记录只根据 AH 开放状态下完成的新查询判断。
7. Vault 精简采集以当前客户端可见收件箱的一次成功扫描为替换边界。`partial` 是当前可见附件的下界快照，不能声明未暴露邮件为空；因邮箱索引会变化且缺乏稳定邮件 ID，不将旧的未暴露记录拼接进当前数量。Mail 自身可采用邮件匹配与归档模型，但不能把未证实的旧邮件并入当前持有量。
   - 只有具备 `MAIL_SHOW` 或可见邮箱框体的开放证据时，完整 `0/0` 扫描才能建立 `known-empty`。邮箱关闭后客户端仍可能返回残留的数量和邮件数据；该可读性不得刷新缓存时间、提高 revision 或覆盖正式快照。
   - `MAIL_CLOSED` 不得作为唯一的关闭证据；替代界面可能隐藏邮箱框体但不产生该事件。每次扫描均须记录当时的开放证据，失去开放证据后停止正式采集。
8. revision 是持久化、单调递增的非负整数。迁移保留或提高 revision，不回绕。

## 9. Mail 邮件匹配规则

- `mailKey` 是 YiboMail 分配的本地 opaque ID，例如 `m:42`，不由消费者解析。
- 匹配签名至少使用角色、邮件类型、发件人、主题、COD/金币、退回标记和附件多重集合；剩余时间只用于容差匹配，不进入永久身份。
- 同签名重复邮件按数量保留为多条记录，不能合并数量或复用一个 `mailKey`。
- 新扫描与旧记录存在多个等价候选且无法唯一匹配时，新建 `mailKey`，旧候选转为 `unverified`；不能静默认定收取、删除或退回。
- 邮件从当前扫描消失，仅表示 `unverified`。只有收取动作结果或明确退回匹配才能进入对应确认状态。

## 10. 兼容承诺

- v1 只增可选字段和新 capability；既有字段类型、枚举含义、默认范围和事件名不变。
- 需要删除字段、改变默认范围、改变 item/variant key 含义或复用来源 ID 时，提升业务 API 主版本。
- 尚未通过阶段验收的 capability 只出现在文档的“规划”部分，运行时不得声明。
- Core v6 是接入前置条件，但 Core 不代理、缓存或改写两套业务 API 的结果。
