# YiboCurrency 0.10.0：Core API13 接入与数量修复

日期：2026-10-15。本文记录0.10.0阶段。当前未发布工作树已继续实施[数据归属迁移](货币数据归属迁移-实施与验收记录.md)，最低Core1.12.4工作树；下文版本和测试为当时证据。未操作玩家实际存档。

## 基线与改动

本轮最初审查 Core1.12.3 / API13；执行期间工作树已为 Core1.12.4。本轮沿用1.12.4版本号，新增通用 `account-dynamic-fields:1`，不改变总 API。Currency 最低要求 Core1.12.4 / API13 及所声明能力，旧API或缺少必要能力／方法时明确提示升级并停止初始化。

- 容器兼容计数修正于 Core EconomyItems 与 Currency 当前角色直接读取：扫描背包后保存累计计数，避免 nil 导致背包归零或被归到银行。读取 API 存在但无结果时不生成确认零。
- Core 旧物品快照只计已确认来源；未确认银行不计入显示总量。Core 旧快照没有独立装备覆盖证明，因此无 Vault 时显示 `~`；它表示来源不完整，不是估算。Vault 背包、银行和装备均已确认时才显示完整余额，全部扫描为空时可显示确认零。
- 物品主表、悬停、合计共用 Projection / GetValue / 格式化。Vault 缺失、注销、主版本不兼容、调用异常或返回不合规时仅失去增强，基础数量继续可用；不直接读取 Vault 实现或存档。
- 主表及悬停均使用货币为行、角色为列的同一矩阵、表头、状态色及分页。先按全部准入角色计算自然宽度，完整矩阵达到 Core 屏幕安全边界后再分页。空选择显示 Core 设置路径提示。
- 主表／悬停的货币选择移入 Core“显示与入口”；目录项用 money / currency:ID / item:ID 注册为动态字段，并按目录分组。运行中增删自定义项无需重载即可进入下一次字段读取。
- 旧 visible 只为主表字段提供默认值种子，已有 Core 显式选择优先；monitored 一次性导入 settings.previewColumns，显式 false 与新表优先，重复初始化不覆盖用户选择。旧监控排序保留为历史配置，当前主表／悬停均按同一目录顺序显示。
- 业务设置页只保留数据与缓存内的自定义物品选择器和确认删除；使用 Core 物品解析、输入、操作确认与窗口工作台。主矩阵右键可切换悬停选择，删除入口集中于数据区。
- 角色显示使用 Core FormatName／共享表头，目标校验使用 identityOnly；角色 ID 不受短名影响。页面、设置、悬停、目录、状态、目标与诊断使用 owner 中英文资源。原生客户端名称、既有自定义文本和历史存档保留。
- 业务入口显式默认关闭 minimap / broker / builtinBar；入口创建、设置、交互与生命周期继续由 Core 管理。移除 TOC 的 Vault 加载顺序依赖，依靠 Contracts 就绪通知和每次查询发现。
- 主动目标继续消费 `business-item-actions:1`，另检查 Provider、身份与实际绑定方法。缺失时停止目标增强，基础矩阵可用；未启用 v3 简短提示，无需依赖 v3。原 API9 基础／API12 增强的旧 Core 兼容例外已收拢到 API13。

## 公共能力逐项核对

| 台账项 | 本轮实际接入 | 边界 |
| --- | --- | --- |
| CAP-001 | 主表共享角色表头、货币和库存提示的角色标签经 Core 格式化 | 完整身份提示由共享表头提供，客户端待验 |
| CAP-002 | Core 物品选择器内的公共输入；Core 统一角色过滤 | 无本地独立输入／设置窗口 |
| CAP-003 | CreateItemPicker、ItemResolver、ItemConfirmation | 单物品目录编辑，不增加无需求批量流程 |
| CAP-004 | 动态字段、统一显示与入口、previewColumns、共享矩阵／入口／设置、角色变化通知 | API13 + account-entry:2 / account-dynamic-fields:1 / account-preview-field-groups:1 等实际所需能力；内置条拖拽由 Core 管理 |
| CAP-005 | vault.items Resolve / Call，注册／注销／变化通知；目标 Provider | 业务数据所有权迁移尚未实施 |
| CAP-006 | 不适用 | 当前无独立首次提示需求，空状态必要提示常显 |
| CAP-007 | GoalTargets Get(identityOnly=true)，检查 character-identity:1 | 不以显示名关联角色 |
| CAP-008 | 原生货币／金币角色目标，API13 / business-item-actions:1 | 物品目标由 Vault；账号合计目标不在当前范围 |
| CAP-009 | 全部正式 Lua 的界面、设置、目录、状态、目标、诊断与数字单位 | Core Locale 会话语言；缺 Locale 的启动停止提示仅使用英文 ASCII，不提供本地语言回退 |

## 离线验证

| 检查 | 结果 |
| --- | --- |
| BalanceSpec | 21项：新旧容器API、确认零／未知、银行与装备覆盖、合计、来源副本和投影 |
| VaultIntegrationSpec | 通过：现有夹具补齐身份接口，新增晚注册／注销、契约主版本不兼容、异常与不合规覆盖回归 |
| CoreItemControlsSpec | 中文／英文两次通过；物品解析、输入、取消／失效、目录增删、窄宽布局及低版本停止 |
| API13Spec | zhCN自动、enUS自动、zhCN手动英文、enUS手动中文，每组37项；实际 Core 运行模块与模拟帧 |
| Core CharacterNamesSpec / ContractsSpec | 77项／90项通过 |
| EntryBarSpec | 1133项入口与工作台回归通过；关联 Mail 矩阵回归同时通过 |
| Lua语法／语言报告 | Core与Currency正式TOC Lua语法通过；报告见 `_NonRelease/Localization/YiboCurrency-API13-Report.md`，两插件零硬编码候选、缺英文、未知key和格式差异 |
| Core RuntimePerformanceSpec | 此前脚本在AltoBoss计时断言停止；用户随后确认实测无问题，该项不作为当前工作阻断。保留当时自动化证据，不推定本次新Currency迁移已做客户端验收 |

## 客户端验收清单

- zhCN、enUS及两种手动语言覆盖：重载后页面、目录、提示和数字单位正确；原生名称与自定义文字保持原样。
- Core低版本、缺dynamic-fields、缺Locale与缺目标增强：升级提示明确，基础或相应增强按所需契约停止，无Lua异常。
- 初次升级与再次重载：旧显隐和悬停选择保留，Core新设置不被旧monitored覆盖；自定义代币增删后菜单、主表与预览同步。
- Vault安装／缺失／禁用／晚注册／注销：余额、来源明细与不完整标记一致；未扫描银行／装备不当作0。进入银行、装备变化及切角色后复核。
- 超20角色、全服、长角色名／短名、小屏幕与UI缩放：自然宽度、表头／数据／分页一致；没有被裁切的控件或横向设置操作。
- 三入口八种选择组合：独立入口默认全关，左键打开本页、右键进入Core入口设置，静止悬停时变化及时刷新。
- 设置选择器在窄／宽窗口、中英文的确认／取消／隐藏后回调与删除末位操作可用。

本轮保持 Core economy / economy-items 的现有存储和 Vault／Core 混合来源兼容边界。离线历史时效与跨周失效没有被本次 UI 接入宣称解决；下一阶段方案见[货币数据归属迁移方案](货币数据归属迁移方案.md)。
