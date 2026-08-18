# YiboCore 缓存角色删除实施计划

## 1. 文档目的

本文用于指导 Yibo 系列插件实现统一的缓存角色删除功能。

功能由 `YiboCore` 提供统一入口和删除协调机制。Core 负责角色身份、档案、别名、排序状态与删除记录；业务插件只清理自己保存的角色级业务快照，不得由 Core 直接读取或修改业务插件内部数据库结构。

适用插件：

- `YiboCore`
- `YiboAltoBoss`
- `YiboLegendary`
- `YiboQuestBlocker`

`YiboBeastPaths` 当前没有账号角色缓存，不参与本功能。

## 实施状态

截至 2026-08-13，阶段 A 至 D 的代码已经落地：Schema v6、Core 清理协调模块、Core 单角色删除原语、三款业务插件数据所有者、延迟重放、legacy 防复活检查、角色档案管理列和不可撤销确认框均已实现。AltoBoss 原有批量清理入口已停用，角色删除统一收口到 Core。阶段 E 的自动验证完成后仍需在 WoW 5.5.4 客户端执行本文第 19 节的 UI 与 `/reload` 验收。

### 自动验证记录

2026-08-13 已完成：

- 发布 `.toc` 实际引用的 52 个 Lua 文件全部通过 `luaparser` 语法解析；
- Schema v6 从 v5 升级并正确初始化删除协调记录；
- Lua 运行时验证单角色协调删除会清理 Core 身份、别名、隐藏和自定义排序引用；
- 验证当前登录角色无法删除；
- 验证业务所有者失败后保持待处理，并可在以后重试成功；
- 验证业务插件晚加载时自动重放删除；
- 验证 legacy 数据不能使已删除角色复活；
- 验证被删除角色真实重新登录后可以建立新缓存；
- 静态确认 AltoBoss、Legendary、QuestBlocker 删除回调只修改角色级数据；
- `git diff --check` 通过。

## 2. 固定功能边界

本功能只支持：

- 用户在 Core 角色档案中选择一个离线角色；
- 查看该角色在 Core 与各业务插件中的缓存影响；
- 经过明确二次确认后删除该角色缓存；
- 删除失败的插件缓存由 Core 记录并在插件可用时重试；
- 被删除角色以后再次登录时，作为新的缓存重新采集。

### 2.1 永久非目标

以下能力永久不支持，不属于首版、后续版本或待定增强项：

- **批量删除**；
- **按天数或最后登录时间自动清理**；
- **自动判断游戏角色是否仍然存在**；
- **自动合并转服、改名或 GUID 变化前后的角色**；
- **撤销删除**。

产品文案、代码注释和后续计划不得将这些项目描述为“暂不支持”“首版不做”或“以后考虑”。

### 2.2 不允许隐式扩大范围

- 不提供“一键清理全部旧角色”；
- 不提供多选框或连续删除队列；
- 不根据角色多久未登录主动推荐删除；
- 不调用或模拟暴雪角色列表来验证角色是否存在；
- 不根据名称、服务器、职业或等级推断两条记录属于同一角色；
- 不把删除实现成可恢复的回收站；
- 不删除账号级共享业务数据；
- 不删除游戏角色，也不宣称能够删除游戏角色。

## 3. 用户场景

缓存角色可能因为以下原因成为无效或重复记录：

- 游戏角色已被用户删除；
- 角色转服后产生新的缓存身份；
- 改名或客户端身份变化后留下旧记录；
- 早期版本使用 legacy ID，迁移后仍残留重复记录；
- 用户明确不再需要某个角色的历史缓存。

插件无法可靠判断这些情况。最终选择与删除责任始终属于用户。

## 4. 删除语义

### 4.1 删除对象

删除对象是一个明确的 Core `characterID` 及其关联别名和角色级业务缓存。

同名角色、同服角色或相似档案不得连带删除。所有删除操作以选中的 `characterID` 为唯一主目标。

### 4.2 当前角色保护

当前登录角色禁止删除：

```lua
characterID == Core.Characters:GetCurrentID()
```

即使当前角色没有业务快照、被隐藏或不符合页面等级条件，也必须禁止删除。

### 4.3 不可撤销

删除成功后：

- 不提供撤销按钮；
- 不保留可恢复的完整角色快照；
- 不提供回收站页面；
- 不自动重新导入旧业务快照；
- 用户如需恢复，只能依赖其自行保存的 SavedVariables 外部备份。

Core 可以保留精简的删除协调记录，但该记录只用于阻止旧数据复活和完成延迟清理，不构成数据备份，也不能用于恢复。

### 4.4 再次登录

如果被删除角色以后再次登录：

- Core 允许重新创建角色记录；
- 业务插件从当前客户端状态重新采集；
- 不恢复被删除的历史业务快照；
- 角色按当前排序设置重新加入账号视图；
- 自定义排序中作为新加入角色追加。

## 5. 数据影响范围

### 5.1 YiboCore

删除：

- `characters.byID[characterID]`；
- `characters.seenOrder[characterID]`；
- 所有值等于该 `characterID` 的 `characters.aliases[alias]`；
- 角色记录内嵌的 `profile`；
- 角色记录内嵌的 `observedAt`；
- 角色记录内嵌的 `availability`；
- `settings.accountView.hiddenCharacters[characterID]`；
- `settings.accountView.customCharacterOrder` 中的该 ID。

保留：

- Core 窗口布局；
- 页面开关；
- 页面字段设置；
- 页面排序覆盖；
- 入口设置；
- 其它角色数据；
- 精简删除协调记录。

### 5.2 YiboAltoBoss

删除：

- 与 Core 角色对应的 `knownChars[legacyKey]`；
- 与 Core 角色对应的 `characters[legacyKey]`。

保留：

- 账号共享位面观测；
- 账号共享刷新历史；
- Boss 与自定义目标配置；
- 等级过滤与显示设置；
- 页面、入口和预览字段设置。

现有 `YAB.CanDeleteCharacter`、`YAB.DeleteCharacter` 和 `YAB.DeleteCharacters` 不作为统一功能的最终入口。单角色删除逻辑应复用到 Core 清理回调；批量删除能力不得接入 Core，也不得在本功能中扩展。

### 5.3 YiboLegendary

删除：

- `db.byCharacter[characterID]`。

保留：

- 阶段开放设置；
- 预览字段设置；
- 客户端能力探针 `probes`；
- 其它角色进度。

`probes` 当前属于客户端能力检测，不是角色业务快照，因此不随角色删除。

### 5.4 YiboQuestBlocker

删除：

- `characterData[characterID]`；
- 其中的个人拒绝列表 `blocked`；
- 其中的角色任务名称缓存 `cache`。

保留：

- `globalBlocked`；
- `globalCache`；
- 自动放弃与聊天报告设置；
- 等级过滤器；
- 页面、入口和预览字段设置；
- 其它角色数据。

## 6. 为什么不能只删除 Core 记录

如果只执行：

```lua
db.characters.byID[characterID] = nil
```

将产生以下问题：

- AltoBoss 仍可能通过 `knownChars` 和 `ImportLegacyCharacter` 重新创建 Core 角色；
- Legendary 的 `byCharacter[characterID]` 仍保留完整业务进度；
- QuestBlocker 的个人拒绝列表仍保留；
- 自定义排序和隐藏设置可能留下失效 ID；
- 未加载插件以后重新启用时可能使旧角色缓存复活。

因此删除必须由 Core 记录意图，并通过标准契约通知所有角色数据所有者清理自己的数据。

## 7. Core 清理契约

### 7.1 新模块

新增：

```text
YiboCore/Data/CharacterCleanup.lua
```

建议内部接口：

```lua
Core.CharacterCleanup:RegisterOwner(addonName, {
    Inspect = function(character, aliases)
        -- 返回该插件持有的角色缓存摘要。
    end,
    Delete = function(character, aliases)
        -- 幂等删除角色缓存。
        -- 成功返回 true；失败返回 nil, errorMessage。
    end,
})

Core.CharacterCleanup:GetImpact(characterID)
Core.CharacterCleanup:CanDelete(characterID)
Core.CharacterCleanup:Delete(characterID)
Core.CharacterCleanup:RetryPending()
```

该模块属于 Core 内部协作契约。第一阶段无需提升公开 API 版本；如果未来作为第三方业务插件正式接入能力公开，再单独评估 API 版本。

### 7.2 注册要求

- `addonName` 必须已通过 `Core:RegisterAddon` 注册；
- 每个插件只能注册一个角色数据所有者；
- `Inspect` 与 `Delete` 必须是函数；
- 注册重复时返回错误，不静默覆盖；
- `Delete` 必须幂等；
- 数据已不存在时也必须返回成功；
- 回调不得删除账号级共享数据；
- 回调不得操作其它插件 SavedVariables；
- 回调失败不得抛出到 WoW UI 主循环，由 Core 捕获并记录。

### 7.3 Inspect 返回值

建议结构：

```lua
{
    hasData = true,
    label = "Boss 周常角色记录",
    detail = "6 个 Boss 状态",
}
```

`Inspect` 只为确认框提供摘要，不影响删除资格。摘要读取失败时，确认框显示“状态未知”，但仍允许用户决定是否删除；删除阶段继续调用 `Delete` 并记录结果。

## 8. 删除协调记录

### 8.1 Schema v6

在 `YiboCoreDB` 新增：

```lua
characterDeletionHistory = {
    [deletionID] = {
        id = "delete:时间戳:characterID",
        characterID = "Player-...",
        name = "角色名",
        realm = "服务器",
        aliases = {
            ["角色名-服务器"] = true,
            ["服务器-角色名"] = true,
        },
        deletedAt = 1234567890,
        acknowledgedOwners = {
            YiboAltoBoss = true,
            YiboLegendary = true,
            YiboQuestBlocker = true,
        },
        failures = {
            -- [addonName] = "错误信息"
        },
    },
}
```

该表是删除协调日志，不是角色备份。

### 8.2 保留策略

- 只保留协调所需的身份摘要、别名、时间和插件确认状态；
- 不保存角色档案、任务状态、Boss 状态或个人屏蔽列表；
- 已由所有当前数据所有者确认的记录仍可保留精简条目用于防止旧导入；
- 设置固定上限，例如最近 100 条；
- 超过上限时，只能淘汰已完全确认且不再有失败状态的最旧记录；
- 不提供用户可操作的恢复入口。

## 9. 防止旧缓存复活

### 9.1 已加载插件

删除时直接调用其 `Delete` 回调。成功后在 `acknowledgedOwners` 中记录 `true`。

### 9.2 未加载或以后重新安装的插件

插件注册数据所有者时，Core 扫描删除协调记录：

1. 查找该插件尚未确认的记录；
2. 调用其幂等 `Delete`；
3. 成功后写入确认状态；
4. 失败则保留错误并等待以后重试。

### 9.3 legacy 导入保护

`Core.Characters:ImportLegacyCharacter` 在导入前检查：

- `characterID` 是否属于待处理删除记录；
- `legacyKey` 是否命中删除记录别名；
- 传入的名称与服务器组合是否命中删除记录别名。

命中尚未由来源插件确认的删除记录时，拒绝导入并返回可诊断错误。来源插件完成清理并确认后，旧数据应已不存在。

### 9.4 再次登录解锁

真实玩家登录不走 legacy 导入保护。`Characters:RefreshCurrent()` 可以重新建立当前 GUID 的角色记录。

重新建立只代表允许采集新数据，不代表恢复旧数据。业务插件在写入新快照前，应确保自己已经处理该角色 ID 对应的未确认删除记录。

## 10. 删除执行顺序

固定流程：

```text
用户点击删除缓存
→ Core 检查目标角色存在
→ Core 拒绝当前登录角色
→ 收集 Core aliases 与各插件 Inspect 摘要
→ 显示二次确认
→ 用户确认
→ 先写入 characterDeletionHistory
→ 逐个调用已注册数据所有者 Delete
→ 记录成功、失败与待重试状态
→ 删除 Core 角色记录和 UI 设置引用
→ 触发 CHARACTER_CACHE_DELETED
→ 刷新账号视图和设置页
→ 显示逐插件结果
```

必须先写删除协调记录，再删除任何缓存。

## 11. 部分失败语义

SavedVariables 不提供跨插件事务，不能保证真正的原子回滚。因此采用可恢复的协调流程：

- Core 删除成功但某个插件失败时，不恢复 Core 角色；
- 失败插件保持未确认状态；
- 下次插件注册、重载或用户触发重试时再次执行；
- UI 必须明确显示部分完成，不得显示为完整成功；
- 回调重复执行不能造成额外损坏。

示例：

```text
角色缓存已从账号视图移除。

Core 角色档案：已删除
Boss 周常：已删除
传说之路：已删除
任务屏蔽：等待重试
```

## 12. Core 自身删除实现

建议在 `YiboCore/Data/Characters.lua` 增加内部方法：

```lua
Characters:CanDelete(characterID)
Characters:GetAliases(characterID)
Characters:DeleteCached(characterID)
```

`DeleteCached` 只负责 Core 自己的数据：

1. 再次检查不是当前角色；
2. 删除 `byID[characterID]`；
3. 删除 `seenOrder[characterID]`；
4. 遍历并删除所有值为该 ID 的 aliases；
5. 删除 `hiddenCharacters[characterID]`；
6. 从 `customCharacterOrder` 移除该 ID；
7. 返回被删除身份的精简摘要。

跨插件协调由 `CharacterCleanup` 调用，不应由 `Characters:DeleteCached` 直接访问业务插件。

## 13. 事件设计

删除完成 Core 自身数据后触发：

```lua
Core.Events:Fire("CHARACTER_CACHE_DELETED", characterID, summary, result)
```

其中：

```lua
result = {
    complete = false,
    owners = {
        YiboAltoBoss = { status = "deleted" },
        YiboLegendary = { status = "deleted" },
        YiboQuestBlocker = { status = "pending", error = "..." },
    },
}
```

该事件用于刷新和诊断，不替代数据所有者的 `Delete` 回调。

## 14. UI 设计

### 14.1 放置位置

删除入口只放在 Core 的“角色档案”页面。

业务插件页面和各插件独立设置中不再新增统一角色删除入口。AltoBoss 现有角色缓存删除 UI 后续需要评估收口，避免玩家看到两套含义不同的角色删除操作。

### 14.2 角色列表

角色档案表新增“管理”列：

- 当前角色：显示“当前”，按钮禁用；
- 其它角色：显示“删除缓存”；
- 按钮使用危险样式；
- 删除按钮必须绑定当前行的准确 `characterID`；
- 搜索和排序后不得错误复用上一行 ID；
- 删除完成后列表保持合理滚动位置。

### 14.3 删除前摘要

确认框展示：

- 角色名与服务器；
- 等级；
- 最后登录时间；
- Core 是否有档案；
- 每个已注册业务插件是否有角色缓存；
- 哪些账号共享数据不会删除。

### 14.4 确认文案

建议：

```text
确定删除“角色名-服务器”的插件缓存吗？

将删除：
• Core 角色档案
• Boss 周常角色记录
• 传说之路角色进度
• 任务屏蔽个人设置

不会删除账号共享设置，也不会删除游戏角色。
删除后不可撤销。
```

按钮：

- `删除缓存`
- `取消`

确认框不得提供“同时删除类似角色”“以后自动清理”等选项。

## 15. 改名、转服与重复记录规则

### 15.1 同 GUID 更新

如果客户端继续提供同一个 GUID，Core 更新同一角色记录的名称和服务器。旧别名可以保留用于业务键迁移。

这属于现有身份刷新，不是自动合并。

### 15.2 GUID 变化

如果 GUID 变化，Core 将其视为新角色。旧缓存继续保留，直到用户明确删除。

Core 永远不根据以下信息自动判定两条记录属于同一角色：

- 名称；
- 服务器；
- 职业；
- 等级；
- 最后登录时间；
- 相似业务进度。

### 15.3 不提供合并功能

转服、改名或重复记录之间不提供自动合并，也不规划手动合并。用户只能保留各自缓存，或逐个删除不再需要的旧记录。

## 16. 数据迁移

将 Core Schema 从 v5 提升到 v6：

- 初始化 `characterDeletionHistory`；
- 不自动删除任何现有角色；
- 不根据最后登录时间生成候选；
- 不导入 AltoBoss 既有删除操作历史；
- 不创建可恢复备份；
- 不改变现有角色排序设置。

运行时仍需防御 `characterDeletionHistory` 类型错误，并确保单条损坏记录不会阻止 Core 加载。

## 17. 逐文件实施清单

### 17.1 YiboCore

#### `YiboCore/Data/CharacterCleanup.lua`（新增）

- [ ] 实现数据所有者注册；
- [ ] 实现影响摘要；
- [ ] 实现删除协调；
- [ ] 实现删除记录；
- [ ] 实现未确认任务重放；
- [ ] 捕获 Inspect/Delete 错误；
- [ ] 实现删除记录上限；
- [ ] 提供 legacy 导入检查。

#### `YiboCore/YiboCore.toc`

- [ ] 在 `Characters.lua` 和 `AccountView.lua` 之间加载 `CharacterCleanup.lua`；
- [ ] 确保业务插件初始化前契约已可用。

#### `YiboCore/Data/Database.lua`

- [ ] 增加 `characterDeletionHistory` 默认值。

#### `YiboCore/Data/Migrations.lua`

- [ ] Schema 提升到 v6；
- [ ] 初始化删除协调表；
- [ ] 不修改现有角色记录。

#### `YiboCore/Data/Characters.lua`

- [ ] 增加当前角色删除保护；
- [ ] 增加别名收集；
- [ ] 实现 Core 自身缓存删除；
- [ ] 在 legacy 导入前检查待处理删除记录；
- [ ] 真实角色重新登录时允许建立新缓存。

#### `YiboCore/UI/AccountView.lua`

- [ ] 角色档案新增管理列；
- [ ] 当前角色禁用删除；
- [ ] 展示删除影响；
- [ ] 增加不可撤销确认框；
- [ ] 显示逐插件删除结果；
- [ ] 删除后刷新角色列表、业务页面和排序编辑器；
- [ ] 保持搜索和滚动状态合理。

#### `YiboCore/Runtime/Registry.lua`

- [ ] 如有必要，登记角色数据所有者资源；
- [ ] 检查 addonName 归属和重复注册。

#### `YiboCore/README.md`

- [ ] 记录 Core 统一管理单角色缓存删除；
- [ ] 明确业务插件只删除角色级数据；
- [ ] 明确永久非目标。

#### `YiboCore/CHANGELOG.md`

- [ ] 记录 Schema v6；
- [ ] 记录角色缓存删除与延迟清理机制。

### 17.2 YiboAltoBoss

#### `YiboAltoBoss/CoreIntegration.lua`

- [ ] 注册角色数据所有者；
- [ ] 将 Core characterID 映射到一个或多个 legacy key；
- [ ] Inspect 返回 Boss 角色缓存摘要；
- [ ] Delete 删除对应 `knownChars` 和 `characters`；
- [ ] 删除成功后持久化并刷新 Core 页面。

#### `YiboAltoBoss/Core.lua`

- [ ] 抽取单角色幂等删除内部函数；
- [ ] 保证共享位面和刷新历史不受影响；
- [ ] 复查现有删除入口，避免与 Core 统一入口语义冲突；
- [ ] 不扩展批量删除能力。

### 17.3 YiboLegendary

#### `YiboLegendary/Bootstrap.lua`

- [ ] 注册角色数据所有者；
- [ ] Inspect 检查 `byCharacter[characterID]`；
- [ ] Delete 幂等删除对应记录；
- [ ] 保留 `probes` 和设置；
- [ ] 删除后刷新 Core 页面。

### 17.4 YiboQuestBlocker

#### `YiboQuestBlocker/CoreIntegration.lua` 或 `YiboQuestBlocker_Core.lua`

- [ ] 注册角色数据所有者；
- [ ] Inspect 统计个人拒绝数量；
- [ ] Delete 幂等删除 `characterData[characterID]`；
- [ ] 保留全局拒绝与设置；
- [ ] 如目标不是当前角色，不影响自动放弃队列；
- [ ] 删除后持久化并刷新 Core 页面。

## 18. 分阶段实施

### 阶段 A：Core 删除基础

- Schema v6；
- `CharacterCleanup` 模块；
- 数据所有者注册；
- Core 自身缓存删除；
- 当前角色保护；
- 删除事件。

完成标准：使用调试调用可安全删除一个离线 Core 角色，并清除别名、隐藏和排序引用。

### 阶段 B：业务插件接入

- AltoBoss 单角色清理回调；
- Legendary 单角色清理回调；
- QuestBlocker 单角色清理回调；
- 业务回调幂等验证。

完成标准：删除一个三插件均有快照的角色后，只移除角色级数据，账号共享数据完整保留。

### 阶段 C：延迟清理和防复活

- 删除协调历史；
- 未加载插件重放；
- legacy 导入保护；
- 失败重试；
- 重新登录后创建新缓存。

完成标准：插件禁用后删除角色，再启用插件时旧业务记录被清理且不会重新导入旧角色。

### 阶段 D：角色档案 UI

- 管理列；
- 删除影响摘要；
- 二次确认；
- 不可撤销提示；
- 逐插件结果。

完成标准：用户可以从角色档案中明确、安全地删除一个非当前角色缓存。

### 阶段 E：验证与文档

- Lua 语法解析；
- 清理契约行为测试；
- Schema v6 迁移测试；
- WoW 客户端 UI 与 `/reload` 验收；
- README、CHANGELOG 和测试记录。

## 19. 验收测试矩阵

### 19.1 删除保护

- [ ] 当前登录角色按钮禁用；
- [ ] 直接调用 API 删除当前角色也被拒绝；
- [ ] 空 ID、未知 ID 和损坏记录返回明确错误；
- [ ] 同名不同服角色只删除选定 ID；
- [ ] 重复点击确认不会重复破坏数据。

### 19.2 Core 数据

- [ ] `byID` 记录删除；
- [ ] `seenOrder` 删除；
- [ ] 所有指向目标 ID 的 aliases 删除；
- [ ] 隐藏状态删除；
- [ ] 自定义排序引用删除；
- [ ] 其它角色排序保持稳定；
- [ ] 页面排序覆盖和窗口设置保留。

### 19.3 业务数据

- [ ] AltoBoss 角色击杀数据删除；
- [ ] AltoBoss 共享位面与刷新历史保留；
- [ ] Legendary 角色任务进度删除；
- [ ] Legendary 探针和设置保留；
- [ ] QuestBlocker 个人拒绝数据删除；
- [ ] QuestBlocker 全局拒绝数据保留；
- [ ] 所有业务回调在数据已不存在时仍返回成功。

### 19.4 延迟清理

- [ ] 某个数据所有者未注册时记录待处理；
- [ ] 所有者以后注册时自动重放；
- [ ] 删除回调失败后保留错误；
- [ ] `/reload` 后继续重试；
- [ ] 清理成功后写入确认状态；
- [ ] AltoBoss 旧 legacy 数据不能重新导入目标角色。

### 19.5 重新登录

- [ ] 被删除角色再次登录后 Core 重新创建记录；
- [ ] 旧业务快照不恢复；
- [ ] 新业务快照从当前状态生成；
- [ ] 角色重新加入当前排序；
- [ ] 自定义顺序中作为新角色追加。

### 19.6 UI

- [ ] 删除前展示准确角色和插件影响；
- [ ] 确认框明确说明不会删除游戏角色；
- [ ] 确认框明确说明不可撤销；
- [ ] 删除结果逐插件展示；
- [ ] 部分失败不显示为完整成功；
- [ ] 删除后搜索结果、滚动和行复用正确；
- [ ] 主窗口、悬停和排序编辑器不再显示目标角色。

### 19.7 永久非目标检查

- [ ] UI 没有多选或批量删除；
- [ ] 没有按天数自动删除逻辑；
- [ ] 没有角色存在性自动判断；
- [ ] 没有转服或改名角色自动合并；
- [ ] 没有撤销、恢复或回收站入口；
- [ ] 文档没有把以上功能列为后续候选。

## 20. 风险与控制

### 20.1 业务缓存重新导入

风险：Core 记录删除后，业务插件从旧 SavedVariables 再次导入。

控制：先写删除协调记录；业务所有者注册时重放；legacy 导入前检查未确认删除记录。

### 20.2 删除共享数据

风险：业务回调删除超出角色范围的数据。

控制：每个插件清理函数使用明确角色键；验收共享表前后结构；Core 不直接调用现有含混的批量清理函数。

### 20.3 当前角色运行时损坏

风险：删除当前角色导致插件事件继续写入失效引用。

控制：UI 和底层 API 双重禁止删除当前角色。

### 20.4 部分失败

风险：Core 已删除但业务插件仍残留数据。

控制：删除历史、幂等回调、失败状态和重试，不伪造事务回滚。

### 20.5 用户误解为删除游戏角色

风险：玩家认为插件会删除游戏内角色。

控制：所有按钮和确认文案统一使用“删除缓存”，并明确“不会删除游戏角色”。

### 20.6 误删不可恢复

风险：用户确认了错误角色。

控制：一次只允许一个明确角色、显示完整名称和服务器、二次确认、危险按钮样式。产品不提供撤销或回收站。

## 21. 回滚策略

如果功能发布后需要停用：

1. 隐藏角色档案中的删除按钮；
2. 停止接受新的删除请求；
3. 保留 `characterDeletionHistory`；
4. 继续允许已注册插件完成未确认清理；
5. 不降低 Schema v6；
6. 不尝试恢复已删除业务缓存；
7. 不删除用户的其它角色或账号共享数据。

回滚功能代码不等于撤销用户已经确认的删除。

## 22. 完成定义

只有同时满足以下条件，缓存角色删除功能才视为完成：

- 删除入口只位于 Core 角色档案；
- 一次只能删除一个明确的非当前角色；
- 删除前展示影响并进行二次确认；
- Core 身份、档案、别名、隐藏和排序引用全部清理；
- AltoBoss、Legendary、QuestBlocker 角色级缓存全部接入统一契约；
- 账号级共享数据完整保留；
- 未加载插件能够延迟清理；
- legacy 数据不能使目标角色复活；
- 被删除角色再次登录时作为新缓存重新建立；
- 部分失败能够重试并清晰展示；
- 删除不可撤销；
- 永久不提供批量删除、按天数自动清理、角色存在性自动判断、转服角色自动合并或撤销删除；
- 自动测试和 WoW 客户端验收全部通过；
- README 与 CHANGELOG 已更新。
