# YiboCurrency：Core 1.12.3 适配与货币数据归属审查

审查日期：2026-10-15。基线为当前工作树 YiboCurrency 0.9.1、YiboCore 1.12.3 / API13，包含尚未提交的改动；不代表远端或已安装客户端状态。本轮检查代码、运行既有测试和最小复现，未修改运行代码，未读取玩家实际 SavedVariables，未完成游戏内验收。

## 结论

YiboCurrency 已使用 Core 账号窗口、入口、设置工作台、物品控件和 Contracts，但仍是 API9 基础接入，不能记为最新 Core 全量适配。主要缺口为统一名称格式化、语言服务、显示与悬停设置归并，以及货币数据所有权。

当前是“Currency 定义目录与业务判断，Core 采集和保存余额，Vault 可选提供物品库存”的历史架构。它与现行“业务数据由业务插件权威拥有、Core 负责通用基础设施”的职责边界存在偏差；这不是将 Currency 接口门槛提高到 API13 就能解决的问题。

## 最新 Core 接入情况

| 范围 | 当前情况 | 结论 |
| --- | --- | --- |
| 版本检查 | CoreIntegration.lua:8–13 检查 API9、business-services:1 及部分物品控件；RegisterAddon.requiredAPI=9 | 基础旧接口仍存在；未建立 API13 集中接入门槛 |
| 账号页与入口 | 经 Core.AccountView、Core.Entry 注册；无本地 Broker/小地图壳 | 已接入旧契约；入口仍 defaultMode="none"，未显式检查 account-entry:2；三通道需客户端核验 |
| 名称格式化 CAP-001 | AccountPage.lua:9–13 本地拼接角色/服务器，:209 显式覆盖共享表头名称 | 待迁移 Core FormatName；短名、全服显示及测量一致性存在缺口 |
| 输入与物品 CAP-002/003 | Settings 复用 CreateItemPicker、ItemConfirmation 和公共输入 | 所列范围已接入，本轮控件测试通过 |
| 设置与悬停 CAP-004 | 主窗口 visible、悬停 monitored 和 hoverOrderOverride 由插件保存；业务设置页提供显示开关及监控排序；注册字段只有 value | 与统一“显示与入口”及预览字段管理尚未归并；并非现行 previewColumns 投影。若保留独立任务型布局，须明确例外理由 |
| 角色矩阵宽度 | GetCurrencySurfaceMetrics 按全部角色求自然宽度，渲染使用 Core GetColumnPage | 静态符合自然宽度与统一分页方向，真实屏幕边界待验；尺寸计算使用完整目录，渲染按 visible 筛选，可能多留宽度 |
| 跨插件 CAP-005 | VaultIntegration 每次经 Contracts.Resolve/Call；监听注册、注销、变更，缺失时用 Core 快照 | 连接方向正确，没有直接读取 Vault 全局实现或数据库；TOC OptionalDeps: YiboVault 仍应收拢 |
| 首次提示 CAP-006 | 无 firstUseTip | 当前无明确需求，不强制接入 |
| 轻量身份 CAP-007 | GoalTargets 使用 Characters:Get(id,{identityOnly=true}) | 有实际接入；启动增强检查未显式验证 character-identity:1 和所调用方法 |
| 主动目标 CAP-008 | GoalTargets 单独检查 API12 / business-item-actions:1；仅金币与原生货币，物品目标由 Vault 提供 | 保留文档化旧 Core 兼容例外；Core 能力3不要求所有旧消费者升到3，现有 v1 操作无需为简短提示增依赖 |
| 语言 CAP-009 | 无 Locale 文件或 owner 语言注册；目录、页面、设置、状态、目标提示存在中文硬编码 | 待迁移；整体接入 API13 时按区域使用 Core.Locale:Get 并检查 localization:1 |
| 新预览字段分组 | Core 1.12.3 提供 account-preview-field-groups:1 | 应先明确货币目录/预览字段模型，再决定是否使用分组；不能仅因 Core 新增就强制依赖 |

## 数据实际所在与建议归属

| 数据 | 当前位置/生产方 | 按现行约定的归属 |
| --- | --- | --- |
| 内置货币目录、状态分类 | YiboCurrency/Catalog.lua；稳定 money / currency:ID / item:ID | Currency 业务定义 |
| 自定义物品目录、显示及监控偏好 | YiboCurrencyDB.settings.customItems / visible / monitored / hoverOrderOverride / levelExpr | 自定义目录属 Currency；通用显示、预览字段与排序交 Core 公开注册框架管理 |
| 金币与原生货币余额 | YiboCoreDB.characters.byID[角色ID].domains.economy.data.money / currencies[货币ID] | 货币余额、上限和时效由 Currency 权威拥有；Core 档案金币需求通过公开货币能力消费 |
| 旧角色档案投影 | 同一 Core 角色记录的 profile.money / profile.currencies，以及 observedAt / availability | 现为 economy 的兼容投影，不是另一个独立采集器；后续需纳入消费者迁移 |
| Core 物品代币快照 | YiboCoreDB.characters.byID[角色ID].domains["economy-items"].data.items[物品ID] | 当前与 Vault 库存重叠；须确定物品数量唯一权威及可选 Vault 缺失策略 |
| Vault 个人库存 | YiboVaultDB.byCharacter；通过 vault.items.GetPersonalCounts 返回背包、银行、装备计数 | Vault 拥有库存采集、保存、覆盖状态；Currency 消费其公开结果 |
| Vault 位置明细 | vault.items.Query：背包、银行、装备、邮件、拍卖、公会银行 | Vault/对应业务来源拥有；Currency 的个人余额不直接加上邮件、拍卖、公会共享数量 |
| 页面计算缓存 | Projection.lua 的 context.currencyProjection | 单次刷新派生缓存，未保存第二份权威余额，这部分边界合理 |
| 目标版本信息 | YiboCurrencyDB.goalSourceEpoch / goalRevision | Currency 来源目标状态元数据，不是货币余额存档 |

Core 采集实现位于 Data/Domains/Economy.lua、EconomyItems.lua，均以 owner="YiboCore" 注册；Runtime/CurrencyCatalog.lua 保存运行期目录注册，目录本身不直接存为 Core SavedVariables。Data/DomainStore.lua 将快照提交到角色记录，并向消费方返回副本。

磁盘存档由 WoW 写到相应客户端的 `WTF/Account/<账号>/SavedVariables/YiboCore.lua`、`YiboCurrency.lua`、`YiboVault.lua`。这些是账号级 SavedVariables 文件；本轮未定位具体客户端与账号目录，也未验证其中真实余额。

## 发现的问题

### 1. 货币数据权威仍在 Core，物品库存存在两套来源

Currency 的余额主要不在 YiboCurrencyDB，而在 Core economy / economy-items。业务规则虽留在 Currency，采集、保存与旧档案投影仍在 Core。Currency Data.lua:195–203 还按来源拼合 Vault 与 Core，未选择统一快照时点。单个余额可能混用不同采集时间的背包和银行数据。

建议迁移时先定义货币公开契约与时效，再迁移存档和 Core 档案消费者。物品代币须明确二选一的产品边界：Vault 为数量唯一权威、缺失时显示增强不可用；或 Currency 在无 Vault 时拥有严格独立且不与 Vault 拼接的基础快照，并文档化来源切换/失效。不要先删除 Core 旧数据，也不要把同一库存复制成第二份权威数据库。

### 2. 未确认银行来源仍显示完整数值（应修复）

Data.lua:206 直接将 Core itemValue 返回为 known；:215 即使 bankKnown=false 也返回 known。ValueState 和 TotalFor 只依据 state 判断完整性，因此无 Vault 时未知银行范围不产生 `~`，合计可能 complete=true。与 README 对 `~` 的定义不一致。

最小复现：Core 物品快照 bankKnown=false，Currency GetValue 返回 state=known。应依据实际来源覆盖决定完整度，并贯通主表、悬停、合计及提示。

### 3. 容器 API 兼容路径丢失背包计数（应修复）

YiboCore/Data/Domains/EconomyItems.lua:30 和 YiboCurrency/Data.lua:29 均执行 carried=Scan(CARRIED_BAGS)，但 Scan 只累加 total，没有返回值。无 GetItemCount、使用容器 API 时，背包读数返回 nil；Core 将其归零。总数量可能仍正确，但背包/银行拆分错误，与 Vault 局部来源拼接时可能漏算。

实际代码最小复现：背包一格7件、无银行物品，Core 产出 carried=0、total=7、bankKnown=false；打开银行后的同一路径会把7件错误归为银行。Currency 当前角色直接读取兼容路径也可能返回未知。

### 4. 就绪与时效信息不足（待契约完善）

CoreIntegration 的角色准入只检查任一 economy 域是否存在，不能证明 Currency 专属货币已采集；仅有通用金币快照的角色也可进入页面。EconomyItems 每次登录重置 bankKnown，重采时可能覆盖此前银行覆盖状态。Vault 个人计数消费只使用 hasSnapshot，不比较来源时间，也未为组合余额建立统一时效语义。周上限状态直接消费已存周数量，未在 Currency 侧建立明确的跨周失效策略。迁移契约须区分未采集、过期、来源不完整和确认零。

### 5. Vault 集成测试夹具落后（验证维护问题）

VaultIntegrationSpec 原样运行在第65行失败：detail=nil。当前 Vault 的明确角色查询会使用 GetAllCached / Get(identityOnly)，测试仅模拟 GetAll。仅在内存中补齐这两个 mock 方法后，整组测试通过；未修改测试文件。不能将原测试记为当前工作树直接通过，也不能据此认定线上 Vault 查询已损坏。

## 本轮验证与后续顺序

- `lua YiboCurrency/_NonRelease/Tests/CoreItemControlsSpec.lua`：通过。
- `lua YiboCurrency/_NonRelease/Tests/VaultIntegrationSpec.lua`：原样失败；补齐内存夹具诊断运行通过。
- 原 Core EconomyItems / Currency Data 最小容器与完整度复现：确认上述第2、3项。
- 全仓正式 Lua 静态搜索：Currency 的 Vault 集成经 Core.Contracts；未发现其它业务插件直接读取 YiboCurrencyDB。
- 未进行游戏内中文/英文、入口八组合、跨周、银行覆盖、晚注册与注销的实际客户端验收。

建议先修复数量/完整度及测试夹具，再完成 API13 的名称、语言与设置适配；数据所有权迁移单独划定方案，包含旧 Core 存档导入、公开货币能力、Core 档案金币消费迁移、Vault 缺失策略和版本不兼容停止行为。审查并不授权删除历史存档。
