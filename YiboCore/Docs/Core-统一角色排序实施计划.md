# YiboCore 统一角色排序实施计划

## 1. 文档目的

本文用于指导 Yibo 系列账号型插件落地统一角色排序功能。实施目标不是在每个业务插件中分别维护排序逻辑，而是扩展 `YiboCore.AccountView`：Core 负责角色排序设置、稳定排序、自定义顺序、页面覆盖和主视图/悬停一致性；业务插件继续只负责业务角色准入和页面渲染。

本文覆盖以下插件：

- `YiboAltoBoss`
- `YiboLegendary`
- `YiboQuestBlocker`

`YiboBeastPaths` 当前没有多角色账号视图，不纳入本次实施范围。

## 实施状态

截至 2026-08-13，阶段 A 至 D 的代码已经落地：排序内核、Schema v5、AccountView 排序管线、通用与页面设置、顶部快捷控件、自定义顺序编辑器和角色 ID 迁移均已实现。阶段 E 的静态回归和文档更新已完成；仍需在 WoW 5.5.4 客户端中执行本文件第 12 节的交互与持久化验收，验收通过后再标记完整交付。

### 自动验证记录

2026-08-13 已完成以下本地自动验证：

- 发布 `.toc` 实际引用的 50 个 Lua 文件全部通过 `luaparser` 语法解析；
- `CharacterSort` 在 Lua 运行时中通过最近登录升降序、名称稳定排序、等级升降序、自定义追加、当前角色置顶、自定义移动、ID 替换去重和异常顺序清理测试；
- Schema v5 通过旧 `seen`、`name`、`level`、未知模式和结构化新设置迁移测试；
- `git diff --check` 通过；
- 静态确认 AltoBoss、Legendary、QuestBlocker 均保持 `context.characters` 输入顺序。

自动测试期间发现升序比较器使用 Lua `and/or` 模拟条件表达式会在主比较结果为 `false` 时错误落入降序分支，造成非严格比较关系；现已改为显式条件分支并通过全部排序用例。

## 2. 当前基线

### 2.1 已有能力

`YiboCore.UI.AccountView` 当前已经：

- 在 `YiboCoreDB.settings.accountView.characterSort` 保存一个全局排序字符串；
- 支持 `seen`、`name`、`level` 三种模式；
- 在构造页面 `context` 前取得可见角色；
- 通过 `context.characters` 将角色列表传入业务页面；
- 在悬停预览中截取前 20 名有效角色。

三款账号型业务插件均保留了 `context.characters` 的输入顺序：

- AltoBoss 将 Core 角色顺序映射为旧业务角色键；
- Legendary 按输入顺序创建角色行；
- QuestBlocker 按输入顺序创建角色列。

因此，统一排序的正确扩展点已经存在于 Core，不需要业务插件重复排序。

### 2.2 已知问题

1. UI 中的“最近登录”实际使用 `seenOrder`，它表示首次登记顺序，不是 `lastSeenAt`。
2. 排序是全局单值，无法让单个业务页面覆盖通用选择。
3. 不支持升序/降序和“当前角色置顶”。
4. 名称相同时缺少服务器与角色 ID 的稳定次级比较。
5. 不支持玩家自定义角色顺序。
6. 当前排序发生在页面范围过滤与业务准入之前，不利于未来扩展页面业务排序。
7. QuestBlocker 的旧版 `YiboQuestBlocker_UI.lua` 仍含一套独立排序代码，但该文件已不在 `.toc` 中加载，不能作为现行实现基础。

## 3. 实施边界

### 3.1 Core 负责

- 通用角色排序设置；
- 页面级排序覆盖；
- 内置稳定比较器；
- 自定义角色顺序；
- 当前角色置顶；
- 排序设置迁移；
- 主视图与悬停预览使用同一排序结果；
- 角色 ID 变化时修复自定义顺序；
- 排序控件和设置界面。

### 3.2 业务插件负责

- 判断角色是否具有本插件业务快照；
- 应用等级、服务器或其它业务准入条件；
- 按 `context.characters` 的顺序渲染角色行或角色列；
- 不另存通用角色排序设置；
- 不在页面刷新阶段对 `context.characters` 再次排序。

### 3.3 本轮不做

- 不为不同插件实现“未击杀优先”“任务进度优先”“屏蔽数优先”等业务比较器；
- 不删除 QuestBlocker 未加载的旧 UI 源文件；
- 不改变业务快照结构；
- 不改变角色隐藏、页面范围和预览字段的既有语义；
- 不提升 YiboCore 公共 API 版本，除非实施中最终暴露插件可注册的业务比较器。

## 4. 功能定义

### 4.1 排序层级

采用“通用默认值 + 页面覆盖”两层结构：

1. 通用排序是所有账号业务页面的默认值；
2. 每个页面可以选择“跟随通用”或保存独立排序；
3. 页面没有有效覆盖值时自动回退到通用设置；
4. 页面被卸载或暂时不可用时保留其覆盖设置，不影响其它页面。

### 4.2 内置排序模式

| 模式 ID | 显示名称 | 默认方向 | 比较规则 |
|---|---|---|---|
| `recent` | 最近登录 | 降序 | `lastSeenAt` 新到旧；缺失时间排末尾 |
| `name` | 角色名称 | 升序 | 名称、服务器、角色 ID |
| `level` | 角色等级 | 降序 | 等级、名称、服务器、角色 ID |
| `custom` | 自定义 | 固定 | 自定义序号；未登记角色追加在末尾 |

旧模式 `seen` 在迁移后映射为 `custom`，并使用 Core 当前的 `seenOrder` 生成初始自定义顺序。这样旧用户看到的顺序不发生突变。

### 4.3 排序方向

- `recent`、`name`、`level` 支持 `asc` 和 `desc`；
- `custom` 不显示方向选项；
- 改变方向只反转主比较字段，稳定兜底字段保持确定性；
- 默认设置为 `recent + desc`。

### 4.4 当前角色置顶

- `pinCurrent = true` 时，当前登录角色始终排在该页面有效角色的第一位；
- 当前角色仍须通过隐藏、范围和业务准入条件；
- 当前角色被隐藏或没有业务快照时不得强行加入页面；
- 置顶判断先于具体排序模式。

### 4.5 自定义顺序

- 使用 Core character ID 保存账号级自定义顺序；
- 各业务页面共享同一份自定义顺序，并在过滤后保留相对次序；
- 新角色或尚未进入顺序表的角色追加到末尾；
- 末尾角色按 `seenOrder`、名称、服务器、ID 稳定排列；
- 自定义编辑器显示 Core 角色目录中的所有角色，包括当前被某个业务插件过滤掉的角色；
- 自定义顺序编辑不改变隐藏状态。

## 5. 数据结构与迁移

### 5.1 目标数据结构

```lua
YiboCoreDB.settings.accountView = {
    characterSort = {
        mode = "recent",
        direction = "desc",
        pinCurrent = false,
    },
    pageCharacterSorts = {
        ["alto-boss"] = {
            mode = "inherit",
        },
        ["legendary"] = {
            mode = "inherit",
        },
        ["quest-blocker"] = {
            mode = "inherit",
        },
    },
    customCharacterOrder = {
        "Player-...",
        "Player-...",
    },
}
```

页面覆盖在 `mode = "inherit"` 时不需要保存 `direction` 和 `pinCurrent`。切换回独立模式时可重新使用此前保存值，但读取层必须忽略继承状态下的残留字段。

### 5.2 Schema v5 迁移

修改 `YiboCore/Data/Migrations.lua`：

1. 将 `CURRENT_SCHEMA` 从 4 提升到 5；
2. 保证 `settings.accountView` 存在；
3. 读取旧的字符串 `characterSort`；
4. 生成结构化通用排序设置；
5. 初始化 `pageCharacterSorts`；
6. 初始化 `customCharacterOrder`；
7. 如果旧模式为 `seen`，按 `Core` 数据中的 `seenOrder` 生成初始自定义顺序，并设置 `mode = "custom"`；
8. 如果旧模式为 `name`，设置 `mode = "name"`、`direction = "asc"`；
9. 如果旧模式为 `level`，设置 `mode = "level"`、`direction = "desc"`；
10. 对未知旧值回退为 `recent + desc`。

迁移函数不得调用尚未初始化的 UI 或运行时模块，只能直接读取和整理 `db` 表。

### 5.3 运行时兼容归一化

`AccountView.Settings()` 仍需防御异常 SavedVariables：

- `characterSort` 仍为字符串时进行兼容转换；
- 非法模式回退到 `recent`；
- 非法方向按模式默认值修复；
- `pinCurrent` 归一化为布尔值；
- 非表类型的 `pageCharacterSorts` 和 `customCharacterOrder` 重建为空表；
- 自定义列表去重并忽略非字符串 ID。

运行时归一化用于容错，正式数据升级仍由 Schema 迁移负责。

## 6. 排序模块设计

### 6.1 新文件

新增：

```text
YiboCore/Util/CharacterSort.lua
```

并在 `YiboCore.toc` 中放在 `Data/Characters.lua` 之后、`UI/AccountView.lua` 之前加载。

### 6.2 模块职责

建议暴露以下 Core 内部方法：

```lua
Core.CharacterSort:NormalizeSettings(settings, fallback)
Core.CharacterSort:BuildCustomOrder(characters)
Core.CharacterSort:MoveCharacter(order, characterID, delta)
Core.CharacterSort:ReplaceCharacterID(order, oldID, newID)
Core.CharacterSort:Sort(characters, settings, currentCharacterID, customOrder)
```

本轮不将这些方法登记为公开 capability，避免业务插件直接依赖内部比较器。

### 6.3 稳定比较规则

所有比较器最终必须使用以下兜底顺序：

1. 角色名称；
2. 服务器名称；
3. Core character ID。

字符串统一使用 `tostring` 防御空值。名称相同的角色不能依赖 Lua `table.sort` 的不稳定行为。

### 6.4 输入输出约束

- 不修改调用方传入的角色数组；
- 返回新的有序数组；
- 不修改角色记录；
- 空数组和 `nil` 设置必须安全返回；
- 角色字段缺失时不得抛错；
- 比较器不得读取任何业务插件数据库。

## 7. AccountView 管线调整

### 7.1 新增内部接口

在 `YiboCore/UI/AccountView.lua` 增加：

```lua
AccountView:GetDefaultCharacterSort()
AccountView:GetPageCharacterSort(pageID)
AccountView:GetEffectiveCharacterSort(pageID)
AccountView:SetDefaultCharacterSort(settings)
AccountView:SetPageCharacterSort(pageID, settings)
AccountView:ResetPageCharacterSort(pageID)
AccountView:GetCustomCharacterOrder()
AccountView:MoveCustomCharacter(characterID, delta)
```

这些方法负责读取 Core 设置、调用排序模块，并在有效变化后刷新当前页面。

### 7.2 BuildContext 目标顺序

将当前管线调整为：

```text
Core.Characters:GetAll()
→ 应用 hiddenCharacters
→ 构造页面 scope
→ 应用页面 scope
→ 调用 page.GetEligibleCharacters
→ 应用页面有效排序
→ preview 模式截取前 20 名
→ 生成 context.characters
```

需要注意：当前部分插件在 `GetEligibleCharacters` 内部处理 scope。第一版允许保留这一现状，Core 不重复过滤，但排序必须移动到 `GetEligibleCharacters` 之后。后续若统一 scope 过滤契约，再独立实施。

### 7.3 context 扩展

为页面诊断和后续 UI 使用，可在 `context` 中增加：

```lua
context.characterSort = {
    mode = "recent",
    direction = "desc",
    pinCurrent = false,
    inherited = true,
}
```

业务页面只能读取该字段用于辅助显示，不应据此再次排序。

### 7.4 主窗口与悬停一致性

`ShowPage` 和 `ShowPreview` 必须继续共用 `BuildContext`。不得为预览单独生成或重新排序角色。预览只在统一排序完成后截取前 20 名。

## 8. UI 实施

### 8.1 顶部快捷控件

在账号主窗口顶部控制区、设置按钮左侧增加排序按钮：

```text
排序：最近登录 ↓
```

要求：

- 仅普通账号窗口显示；
- 悬停预览隐藏；
- “概览”和“角色档案”显示通用排序；
- 业务页面显示该页面的实际排序；
- 左键循环常用模式：最近登录 → 名称 → 等级 → 自定义；
- Shift+左键切换升降序，或通过菜单选择方向；
- 若页面跟随通用，在提示中明确显示“跟随通用”；
- 自定义模式没有方向箭头；
- 控件不得挤压窗口标题，最小窗口宽度下要验证文字截断。

如果循环按钮在可用性测试中不够清晰，应改成原生下拉菜单；不要同时保留两套交互。

### 8.2 通用设置页

在“通用设置 → 账号视图”中增加：

- 默认角色排序；
- 排序方向；
- 当前角色置顶；
- 打开自定义顺序编辑器；
- 恢复默认排序。

现有顶部和内容区重复出现的排序按钮应合并，避免一个页面出现两个功能相同的循环按钮。

### 8.3 插件设置页

在每个已注册业务页面的 Core 设置中增加“角色排序”分组：

- 跟随通用设置；
- 最近登录；
- 角色名称；
- 角色等级；
- 自定义顺序；
- 独立模式下的方向；
- 独立模式下的当前角色置顶。

业务插件自己的设置窗口不再增加同类控件。

### 8.4 自定义顺序编辑器

第一版采用上下移动按钮，避免引入拖拽状态和滚动容器冲突：

- 每行显示职业色角色名、服务器和等级；
- 提供上移、下移；
- 当前角色使用既有当前角色样式；
- 顶部提供“按当前最近登录顺序重建”；
- 提供“恢复初始登记顺序”；
- 超过可视高度时使用静态滚动；
- 编辑期间每次移动立即保存，但只刷新编辑器和当前业务页面；
- 不提供删除角色功能。

## 9. 角色 ID 变化处理

`Characters.ReplaceCharacterID` 会触发：

```lua
CHARACTER_ID_CHANGED(oldID, newID, record)
```

Core 初始化时注册内部监听：

1. 在 `customCharacterOrder` 中查找 `oldID`；
2. 如果 `newID` 尚不存在，将该项原位替换；
3. 如果 `newID` 已存在，删除旧 ID 项并保留新 ID 的较前位置；
4. 同步迁移 `hiddenCharacters[oldID]` 到 `hiddenCharacters[newID]`；
5. 刷新当前账号页面。

隐藏角色迁移虽然不是本功能新增需求，但与角色 ID 升级属于同一一致性问题，建议在本阶段一并修正。

## 10. 逐文件实施清单

### 10.1 YiboCore

#### `YiboCore/YiboCore.toc`

- [ ] 加载 `Util/CharacterSort.lua`；
- [ ] 确认加载顺序晚于 Defaults/Characters、早于 AccountView。

#### `YiboCore/Util/CharacterSort.lua`（新增）

- [ ] 实现设置归一化；
- [ ] 实现最近登录、名称、等级、自定义比较器；
- [ ] 实现当前角色置顶；
- [ ] 实现稳定兜底；
- [ ] 实现自定义顺序去重与移动；
- [ ] 实现角色 ID 替换。

#### `YiboCore/Data/Database.lua`

- [ ] 更新账号视图默认排序结构；
- [ ] 增加 `pageCharacterSorts`；
- [ ] 增加 `customCharacterOrder`。

#### `YiboCore/Data/Migrations.lua`

- [ ] Schema 提升到 v5；
- [ ] 迁移三个旧排序字符串；
- [ ] 从 `seenOrder` 生成兼容自定义顺序；
- [ ] 防御不完整旧数据库；
- [ ] 记录迁移历史。

#### `YiboCore/UI/AccountView.lua`

- [ ] 替换现有内联排序；
- [ ] 增加通用与页面排序读写接口；
- [ ] 将排序移动到业务准入之后；
- [ ] 在预览限制之前排序；
- [ ] 扩展 `context.characterSort`；
- [ ] 增加顶部快捷控件；
- [ ] 改造通用设置；
- [ ] 增加页面排序设置；
- [ ] 增加自定义顺序编辑器；
- [ ] 确保预览模式隐藏交互控件；
- [ ] 处理排序改变后的尺寸与滚动刷新。

#### `YiboCore/Runtime/Events.lua` 或适合的 Core 初始化位置

- [ ] 监听 `CHARACTER_ID_CHANGED`；
- [ ] 迁移自定义顺序；
- [ ] 迁移隐藏状态；
- [ ] 避免重复注册监听。

#### `YiboCore/README.md`

- [ ] 记录统一排序由 Core 管理；
- [ ] 说明业务插件必须保持 `context.characters` 顺序；
- [ ] 说明页面排序覆盖和悬停前 20 名规则。

#### `YiboCore/CHANGELOG.md`

- [ ] 记录结构化角色排序；
- [ ] 记录“最近登录”语义修正；
- [ ] 记录页面覆盖、自定义顺序和当前角色置顶。

### 10.2 YiboAltoBoss

#### `YiboAltoBoss/CoreIntegration.lua`

- [ ] 确认 `GetEligibleCharacters` 只过滤、不排序；
- [ ] 确认 `GetAccountCharacterKeys` 保持 `context.characters` 顺序；
- [ ] 不新增排序 SavedVariables。

#### `YiboAltoBoss/AccountPage.lua`

- [ ] 验证角色列按 Core 顺序生成；
- [ ] 验证当前角色列边框在置顶后正确移动；
- [ ] 验证页面宽度按过滤后的角色数计算。

### 10.3 YiboLegendary

#### `YiboLegendary/UI.lua`

- [ ] 确认 `GetEligibleCharacters` 只过滤、不排序；
- [ ] 验证角色行按 Core 顺序生成；
- [ ] 验证隔行底色按排序后的行索引重新计算；
- [ ] 验证当前角色标记随排序正确移动。

### 10.4 YiboQuestBlocker

#### `YiboQuestBlocker/CoreIntegration.lua`

- [ ] 确认服务器和等级过滤不改变输入顺序；
- [ ] 不新增排序 SavedVariables。

#### `YiboQuestBlocker/AccountPage.lua`

- [ ] 验证角色列按 `context.characters` 顺序生成；
- [ ] 验证列宽、矩阵宽度和横向滚动随排序保持正确；
- [ ] 验证主窗口与悬停使用相同列顺序。

#### `YiboQuestBlocker/YiboQuestBlocker_UI.lua`

- [ ] 本轮不修改、不加载、不删除；
- [ ] 在后续遗留代码清理任务中单独评估。

## 11. 分阶段执行

### 阶段 A：排序内核与数据迁移

交付内容：

- `CharacterSort` 模块；
- Schema v5；
- 稳定的四种排序模式；
- `lastSeenAt` 真正驱动“最近登录”；
- 旧用户排序无突变迁移。

完成标准：不增加新 UI，也能通过手动修改 SavedVariables 或调试入口验证排序结果。

### 阶段 B：AccountView 管线接入

交付内容：

- 业务准入后排序；
- 页面覆盖读取；
- 主窗口与预览统一；
- `context.characterSort`。

完成标准：三款业务插件无需自行排序即可显示预期顺序。

### 阶段 C：设置与快捷控件

交付内容：

- 顶部排序控件；
- 通用排序设置；
- 页面覆盖设置；
- 当前角色置顶。

完成标准：玩家无需编辑 SavedVariables 即可完成全部非自定义排序操作。

### 阶段 D：自定义顺序编辑器

交付内容：

- 上下移动角色；
- 自定义顺序重建和恢复；
- ID 变化迁移；
- 多角色静态滚动。

完成标准：新增角色、legacy ID 升级和页面过滤均不破坏现有自定义相对顺序。

### 阶段 E：插件回归与文档

交付内容：

- 三款业务插件逐项验收；
- Core README/CHANGELOG；
- 测试清单与实际结果记录。

完成标准：主视图、独立入口悬停、Core 入口和页面切换均无顺序分歧。

## 12. 验收测试矩阵

### 12.1 排序正确性

- [ ] 最近登录按 `lastSeenAt` 从新到旧；
- [ ] 缺少 `lastSeenAt` 的角色排在有时间角色之后；
- [ ] 名称升序和降序正确；
- [ ] 等级升序和降序正确；
- [ ] 同名不同服务器角色顺序稳定；
- [ ] 同名同服务器异常重复记录仍由 ID 稳定排序；
- [ ] 当前角色置顶不改变其余角色的相对顺序；
- [ ] 自定义列表之外的新角色稳定追加。

### 12.2 过滤与范围

- [ ] 隐藏角色不会因置顶或自定义顺序重新出现；
- [ ] 当前服务器范围只排序当前服务器角色；
- [ ] 所有服务器范围保持同一排序规则；
- [ ] 未通过等级过滤的角色不出现；
- [ ] 没有业务快照的角色不出现；
- [ ] 页面过滤后保留自定义相对顺序。

### 12.3 主窗口与悬停

- [ ] AltoBoss 主表与悬停角色列顺序一致；
- [ ] Legendary 主表与悬停角色行顺序一致；
- [ ] QuestBlocker 主表与悬停角色列顺序一致；
- [ ] 角色超过 20 名时，悬停取排序后的前 20 名；
- [ ] 第 21 名及以后仍在主窗口出现；
- [ ] 悬停不显示排序按钮或编辑控件。

### 12.4 数据迁移

- [ ] 旧 `seen` 用户升级后顺序不变；
- [ ] 旧 `name` 用户升级为名称升序；
- [ ] 旧 `level` 用户升级为等级降序；
- [ ] 未设置排序的用户获得最近登录降序默认值；
- [ ] 损坏或未知模式能够安全回退；
- [ ] migrationHistory 正确记录 v5；
- [ ] 角色 fallback ID 升级为 GUID 后顺序位置不变；
- [ ] ID 升级后隐藏状态不丢失。

### 12.5 UI 与布局

- [ ] 最小窗口宽度下标题和顶部按钮不重叠；
- [ ] 页面切换后按钮显示正确的有效排序；
- [ ] “跟随通用”页面随通用设置实时变化；
- [ ] 独立页面不受通用设置改变影响；
- [ ] 自定义编辑器超过可视高度时可滚动；
- [ ] 排序后表格滚动范围、固定表头和当前角色边框正常；
- [ ] `/reload` 后设置保持。

## 13. 风险与控制

### 13.1 旧用户顺序突变

风险：将旧 `seen` 直接解释为最近登录会立即改变现有角色排列。

控制：迁移为 `custom`，使用既有 `seenOrder` 生成初始顺序；只有新安装默认使用真正的最近登录。

### 13.2 排序前后页面尺寸变化

风险：排序本身不改变角色数，但刷新流程可能触发矩阵重建和自动适配。

控制：排序切换只刷新内容；除非过滤条件或角色数同时变化，否则不强制重新自动调整主窗口尺寸。悬停预览可重新测量，以确保边缘夹取正确。

### 13.3 业务插件二次排序

风险：业务页面未来新增局部 `table.sort`，导致主窗口和悬停不一致。

控制：在 Core README 和插件接入契约中明确禁止；回归检查三个插件的角色渲染入口。

### 13.4 Lua `table.sort` 不稳定

风险：比较器在主要字段相同时返回不确定结果。

控制：所有模式最终比较唯一 character ID；不得只比较名称或等级。

### 13.5 自定义 ID 失效

风险：早期 fallback/legacy ID 替换为 GUID 后，自定义顺序丢失。

控制：监听 `CHARACTER_ID_CHANGED` 并原位替换；排序时仍对失效 ID 做惰性清理。

## 14. 回滚策略

本功能只新增 Core 设置与排序模块，不改业务快照。若发布后需要回滚：

1. 保留 Schema v5 数据，不降低 `schemaVersion`；
2. 临时让 `GetEffectiveCharacterSort` 固定返回兼容的 `custom` 或 `name` 模式；
3. 隐藏新增 UI 控件；
4. 保留 `pageCharacterSorts` 和 `customCharacterOrder`，避免玩家配置丢失；
5. 不回写或删除业务插件 SavedVariables。

不得通过删除 `YiboCoreDB` 作为回滚手段。

## 15. 完成定义

只有同时满足以下条件，统一角色排序功能才视为完成：

- 排序逻辑只在 Core 维护；
- 三款账号型业务插件均按 Core 顺序显示；
- 主窗口与悬停预览顺序一致；
- 最近登录语义与 `lastSeenAt` 一致；
- 旧排序设置安全迁移；
- 页面可跟随通用设置或独立覆盖；
- 自定义顺序可编辑并能处理新角色与角色 ID 升级；
- 隐藏、服务器范围和业务准入优先级正确；
- 全部验收测试完成并记录结果；
- README 与 CHANGELOG 已更新。
