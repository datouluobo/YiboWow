# YiboMounts

## Register

product

## 产品身份

- 技术名与插件目录名：`YiboMounts`
- 插件列表显示名：`|cff20e070[Yibo]|r YiboMounts - 坐骑图鉴`
- 目标客户端：World of Warcraft: Mists of Pandaria Classic 5.5.4
- Interface：`50504`
- V1 核心依赖：无
- V1 SavedVariables：无游戏状态；Alpha 的 `/ymt inventory` 可选写入一次性诊断快照 `YiboMountsDiagnostics`，仅用于生成全量目录基线。
- V1 正式设置命令：无；Alpha 诊断命令：`/ymt`

插件列表显示名遵循 Yibo 系列的“技术名 - 中文功能名”格式，不提供本地化 Title。英文与简体中文客户端仅对说明、来源路径和获取条件进行本地化。

## Users

在 MoP Classic 中看到自己或当前目标的坐骑 Aura，并希望不离开当前界面就知道该坐骑如何获得的玩家。

玩家可能使用暴雪默认单位框架或 NDui。插件不要求玩家安装坐骑收藏插件、YiboCore 或 ALL THE THINGS。

## Product Purpose

在自己或当前目标的坐骑 Aura Tooltip 中追加紧凑、可信且可本地化的获取来源，让玩家直接回答：

1. 这是什么来源类型？
2. 需要去哪个副本、首领、商人、阵营、成就、任务或活动？
3. 是否存在必须知道的难度、声望、价格、职业或阵营条件？
4. 如果坐骑已经绝版，它过去如何获得，当前是否仍可获取？

V1 是轻量来源速查工具，不是完整收藏管理器。完整坐骑目录与收藏状态属于后续 YiboCore 页面。

## Product Promise

1. **零依赖可用。** 未安装 YiboCore 或 ATT 时，自己与当前目标的已收录坐骑 Aura 仍能显示来源。
2. **只增强明确识别的坐骑。** 未命中本地 `spellID` 索引时完全静默，不污染普通 Aura Tooltip。
3. **信息紧凑。** 不显示插件品牌标题；来源路径占一条逻辑行，必要条件最多再占一条逻辑行。
4. **数据可追溯。** 每条来源由多来源交叉核验；证据、核验日期和备注留在非发布资料中。
5. **语义先于文案。** 数据保存来源层级、条件和可获取状态，运行时再生成 `enUS` 或 `zhCN` 文案。
6. **为完整目录留出演进路径。** 坐骑实体与 `spellID`、`itemID`、可选 `mountJournalID` 分离，不把 V1 的 Tooltip 形态固化为唯一消费者。

## Version Roadmap

### 0.1.0-alpha：技术验证

- 使用 30～50 只坐骑的来源类型验证集。
- 跑通 Aura Tooltip → `spellID` → 本地索引 → 紧凑来源文本。
- 支持自己与当前目标。
- 未命中时静默。
- 核心链路在 MoP Classic 5.5.4 实机可用后即可发布 Alpha。

Alpha 是公开技术验证版本，不承诺完整坐骑覆盖、全部来源逐条实机验证或所有第三方单位框架兼容。

### 1.0.0：正式 V1

- 覆盖 MoP Classic 5.5.4 客户端 Mount Journal API 返回的完整坐骑目录；以 API 原始 spellID 集合作为覆盖基线，不以任意角色 UI 中的可见数量为准。
- 完成 `enUS` 与 `zhCN` 来源文案。
- 完成暴雪默认 UI 与 NDui 验收。
- 覆盖自己与当前目标的 Aura Tooltip。
- 完成结构化数据生成、重复 ID 和必填字段校验。
- 预留只读目录查询与格式化接口，但不注册 YiboCore 页面。

### V2：可选 YiboCore 页面

- 插件仍可独立运行。
- 检测到兼容的 YiboCore 时注册业务页面。
- 页面只展示当前已经收录的坐骑，不暗示全量覆盖。
- 展示图标、名称、来源、条件和当时能够可靠读取的收藏事实。
- 是否加入 `.toc` 的 `OptionalDeps: YiboCore`，由接入时的加载顺序验证决定；不得改成 `RequiredDeps`。

### V3：完整坐骑手册

- 在 V1 全量 Aura 目录之上补充无法由 Aura 直接观察的历史、绝版及非当前坐骑日志条目。
- 展示收藏状态、完整多来源信息、绝版状态与历史来源。
- 收录无法通过自己或当前目标 Aura 直接观察到的坐骑。
- Core 页面升级为完整坐骑手册；Aura Tooltip 继续保持紧凑，不承载全量详情。

## V1 Scope

### Included

- 自己单位框架上的坐骑 Aura Tooltip。
- 当前目标单位框架上的坐骑 Aura Tooltip。
- 暴雪默认 UI。
- NDui，优先通过标准 Tooltip 生命周期兼容；只有实测失败时才增加最小适配。
- `enUS` 和 `zhCN`。
- 本地结构化坐骑目录与按 `spellID` 生成的运行时索引。
- MoP Classic 5.5.4 当前坐骑日志的完整目录；每条均以 Aura `spellID` 映射到一个有具体路径的主要来源。
- 以下来源类型：
  - 副本或团队首领掉落；
  - 世界稀有掉落；
  - 成就奖励；
  - 声望商人；
  - 普通商人；
  - 任务奖励；
  - 职业限定；
  - 阵营限定；
  - 节日或限时活动；
  - 商城、推广或已经绝版的历史来源。
  - 专业制造坐骑。

### Explicitly Deferred

- YiboCore 页面与注册逻辑。
- 收藏状态、账号完成度和稀有度。
- Tooltip 中的完整备选来源。
- 焦点、队伍、团队、姓名板及任意第三方单位框架的兼容承诺。
- 用户设置、SavedVariables、字段开关和正式设置命令。
- 跌落率、坐标、刷新时间、路线和完整攻略。

### Permanently Out of Scope for the Aura Tooltip

- 在玩家 Unit Tooltip、法术链接、物品链接或聊天链接中追加来源。
- 扫描目标全部 Aura 后主动修改玩家 Tooltip。
- 把未知 Aura 显示为“未收录”或暴露 Spell ID 等诊断信息。
- 在 Tooltip 中显示插件标题、调试状态或重复说明。
- 将完整坐骑手册塞入 Aura Tooltip。

## Interaction Contract

只有同时满足以下条件时才修改 Tooltip：

1. Tooltip 来自 `player` 或 `target` 的 Aura；
2. 能可靠取得 Aura 的 `spellID`；
3. `spellID` 命中生成后的坐骑索引；
4. 记录通过目录校验且存在当前 Locale 或 `enUS` 回退文本；
5. 当前 Tooltip 尚未追加同一条记录。

未满足任一条件时保持原 Tooltip 不变。

## Alpha Diagnostics

`/ymt` 只用于 Alpha 技术验证，不保存开关，也不改变玩家看到的 Tooltip 内容：

- `/ymt debug`：输出后续 Aura Tooltip 回调中实际取得的 `unit`、`spellID` 和目录命中状态。
- `/ymt probe`：检查当前 Tooltip 的相同信息。

正式 V1 是否保留该诊断入口，由实机回调核验完成后决定；它不是设置界面或常规交互入口。

## Tooltip Presentation

来源使用紧凑的层级路径，视觉含义类似面包屑，但不承担导航交互：

```text
Drop > Mogu'shan Vaults > Elegon
Normal / Heroic
```

```text
Vendor > The Klaxxi Quartermaster
Exalted > 10,000 Gold
```

```text
Promotion > Annual Pass
No longer obtainable
```

展示规则：

- 不增加插件标题行。
- 第一条逻辑行只显示主要来源路径。
- 第二条逻辑行只在存在关键条件或不可获取状态时显示。
- 长路径允许由 Tooltip 根据安全宽度自然换行，不截断关键实体名称。
- 多来源记录只显示当前有效且优先级最高的一条；完整来源留给未来目录页面。
- 绝版记录显示历史主要来源，并在条件行明确当前不可获取。
- 原始结构字段不直接拼成不可本地化的自由文本。

## Data Ownership

YiboMounts 负责：

- 坐骑实体、ID 映射、来源、条件、可获取状态和本地化。
- 数据生成、验证和运行时查询。
- Aura Tooltip 的识别、去重与格式化。
- 后续 Core 页面需要的只读目录接口。

YiboCore 在 V2 以后负责：

- 统一窗口壳、页面生命周期、设置工作台和公共视觉组件。
- 业务页面的承载，不接管 YiboMounts 的目录和来源数据。

ATT、Wowhead 或其它资料不成为运行时依赖，也不在发布包中复制其说明文案、路径或数据库。Alpha 可由 ATT 的转换后标量类别生成明确标记的候选提示；正式 V1 仍须以独立证据逐条核验为准。

## Data Quality Policy

- `spellID` 与坐骑身份优先通过目标客户端数据或实机探针确认。
- 获取条件优先核对 MoP Classic 对应版本资料。
- 绝版、推广和版本差异必须增加第二来源复核。
- 每条原始记录保存证据 URL、核验日期、目标客户端构建号和核验状态。
- 发布文案由本项目根据事实字段自行编写。
- 未确认数据不得标记为 `verified`，也不得进入正式生成目录。
- Alpha 可以包含明确标记为 `candidate` 的验证记录；若只确认来源类别，Tooltip 必须显示“详细地点待核实”。生成器和构建流程必须把它与正式 V1 数据区分。

## Brand Personality

轻量、克制、可信、像原生 Tooltip 的自然补充。信息层级接近 ATT 的紧凑来源路径，但不复制其代码、数据库或文案。

## Anti-references

- 不在每个 Tooltip 重复显示插件名。
- 不把每个字段机械拆成一行。
- 不把未收录当作错误提示给玩家。
- 不为了“信息完整”加入收藏率、路线和长攻略。
- 不依赖 Retail Mount Journal API 的存在来定义核心能力。
- 不因未来 Core 页面而让 V1 依赖 YiboCore。
- 不把本地化名称、显示文案或客户端临时索引作为稳定主键。

## Success Criteria

### Alpha

- MoP Classic 5.5.4 中，至少一只已收录坐骑能在自己 Aura 上显示正确来源。
- 至少一只已收录坐骑能在当前目标 Aura 上显示正确来源。
- 未收录 Aura 保持原样。
- 重复触发同一个 Tooltip 不会重复追加来源。
- 禁用或移除插件后不影响原 Tooltip。

### 正式 V1

- 以 MoP Classic 5.5.4 客户端 API 实机导出的原始坐骑清单为基线，目录覆盖率为 100%；当前快照为 526 个唯一 spellID。角色 UI 中约 335 条的可见数量仅用于角色条件诊断。
- 每条记录均通过 Schema、重复 ID、必填字段、Locale 和来源路径校验。
- 每种已声明来源类型至少有一条可渲染记录。
- `enUS` 与 `zhCN` 均能生成来源路径和条件行。
- 暴雪默认 UI 与 NDui 均通过自己和当前目标的实机验证。
- 绝版、多 ID、阵营/职业限制和多来源优先级等边界记录可正确格式化。
- 发布说明明确这是精选验证集，不宣称全量坐骑覆盖。

## Change Gate

后续新增需求进入实施前必须回答：

1. 它是否仍然帮助玩家判断坐骑如何获得？
2. 它属于紧凑 Aura 来源，还是应进入未来完整目录页面？
3. 它能否用稳定 ID 与结构化事实表达？
4. 它是否会让独立模式依赖 YiboCore、ATT 或其它大型插件？
5. 它是否会让未知 Aura、调试信息或完整攻略污染 Tooltip？

任一需求破坏零依赖、静默未命中或紧凑 Tooltip 契约时，应拒绝加入 V1，或移入 V2/V3 目录页面。
