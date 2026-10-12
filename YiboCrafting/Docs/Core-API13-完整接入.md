# Crafting 1.2.0：Core API13 接入基线

日期：2026-10-12。基线固定为 Core 1.12.0 / API13 当前公开接口，包括 builtin-entry-bar:3。代码接入及离线检查完成，游戏内验收待完成；尚未发布。后续 Core 新能力按触及范围继续迁移。

“全部接入”指覆盖本插件所有实际适用的公共能力；没有业务操作的接口注明不适用，不创建占位服务或重复设置。配方查询 Service 仍是后续产品功能，不因 Core 支持 Service 而自动交付。

## 接入清单

| API / 能力 | Crafting 调用与边界 |
|---|---|
| 基础注册 / 角色目录 / 领域 / 事件 | RequiredDeps；Initialize 与 RegisterAddon 均要求 API13；检查 Core:IsInitialized 与所需能力后才写业务库、注册页面。CORE_READY 支持晚就绪重试；专业领域变化合并刷新页面。身份只用 Core ID，数据由 Crafting 持有 |
| API5–6 账号页、矩阵与统一设置 | AccountView:RegisterPage；共享角色表头、行／列底纹、当前角色轮廓、Core 滚动沟槽及表头分页。页面自然宽度按全部有效角色报告；设置嵌入 Core 工作台，无独立窗口壳或入口设置 |
| API7 basic-input:1 | 搜索使用 CreateInput，保留防抖、回车和清空；字体、IME 和基础生命周期由 Core 管理 |
| API7–9 item-resolver:1 | 名称读取经 ItemResolver:GetInfo；搜索先确认原生缓存标记，再访问已缓存资料，不批量 Request。只有实际游戏 Tooltip 继续使用原生 SetItem/SetSpell，瞬时图标 API 只取元数据，不触发全目录加载 |
| API7–8 item-picker / 批量物品确认 / 图标选择 | 不适用：没有按物品编辑目录或执行批量物品操作的功能，也没有用户自定义图标。缓存删除复用 CharacterCleanup 的确认链 |
| API8 character-name-format:1 | 所有角色标签与真实身份显示复用 FormatName／SetCharacterHeader，不把格式化结果用作关联键 |
| API9 business-services:1 / API11 business-providers:1 | action.targets 通过 Contracts 注册、发现和调用；库存缺失、晚注册、注销或不兼容只影响持有模式。无直接业务全局对象或 SavedVariables 访问 |
| API9 合并刷新 | 采集、领域变化、身份迁移和缓存清理经 NotifyPageChanged；物品事件按目录、名称匹配和缓存去重，避免循环重绘 |
| API10 首次提示 | 不适用：状态说明、搜索和动作提示常显；没有需要一次性提示才能完成的隐藏操作 |
| API11 character-identity:1 | 目标观察与配置读取 identityOnly，不复制背包等完整角色领域 |
| API11 account-character-admission:1 | 页面和悬停由 Core 构造角色准入、范围与排序；没有窗口外角色面板，不新增重复通知订阅。悬停额外要求业务快照，角色顺序不另排 |
| API11 account-surface-budget:1 | 悬停按 surfaceAvailableHeight 计算有限配方行，复用主矩阵和同一状态数据，显示已展示／总项数。Core 管理定位、生命周期和最多20角色范围 |
| API12 business-item-actions:2 | 名称、产物、已学角色格使用 Core 绑定、手势、标记和旁侧按钮；默认数量1，产物不明确时直接配置。无本地按钮实现 |
| API13 localization:1 | 页面、状态、错误、设置、入口、目标和静态分类使用 owner=YiboCrafting 的中英文资源。会话语言由 Core 决定；无业务语言开关。动态 WoW 名称和历史快照不翻译 |
| API13 account-entry:2 / builtin-entry-bar:1–3 | defaultChannels 注册默认全关闭；三处入口由 Core 创建和管理。业务不直接修改条、排序或位置；v2外观／v3拖拽自动继承 Core 的已注册入口行为，不调用无需求的配置接口 |

## 角色迁移与数据所有权

CHARACTER_ID_CHANGED 时，Crafting 搬迁自身配方快照和制造计数，保存自己的旧→新 ID 别名；重复计数合并取最大值以避免相同事实重复累加。目标 Normalize 通过别名解析自身制造基线，包括指定角色 baselineCharacterID 与共享 startCounts，保持原目标起点。TaskHub 继续只迁移公开角色范围，不读取 Crafting 数据或重算业务规则。迁移后发布来源变化并刷新账号页。

角色配方缓存清理使学习资格失效并通知来源／页面；制造计数是目标观察事实，清理配方快照不伪装成重新开始目标。重新执行仍通过目标操作重设起点。

## 预览与设置

Broker、小地图与内置条复用同一 Core 账号窗口、相同配方快照、搜索与专业筛选、学习状态判断和矩阵绘制。previewColumns 保存 recipe-name／recipe-state 的显隐；Core 统一设置渲染开关，主表字段也遵循 Core 字段投影。悬停只显示有 Crafting 专业快照的角色，按预算截取配方行；角色很多时由同一个 Core 列切片分页。悬停隐藏专业布局切换按钮，避免改变正式页面浏览模式。

## 语言与静态数据审查

Locales/Interface、Targets、Categories 注册插件资源。分类以稳定 ASCII ID 保存静态目录索引；未知原生分类仍保持客户端 API 原文。BuildCategoryCatalog 生成器同步读取双语分类资源映射，未定义新分类时拒绝生成，避免重新写回显示名称索引；100项资源映射及唯一性检查通过。输入“全部／搜索”等为中文客户端采集别名，RecipeCatalog 的产物名与历史审计证据为固定来源数据，均保持原文，不当作界面翻译。

已生成并查看 Workspace-Report：缺英文、未知 key 和格式差异均为0；残余 Crafting 中文候选限于原生采集别名和固定客户端／历史来源资料。动态 key 包装不以静态引用数量证明覆盖率；CoreAdaptation 对 owner 双语资源逐 key 检查并实际创建两种语言页面。

旧 Core 没有 Locale 时只显示同一资源文件提供的双语升级要求并停止初始化，不选择本地语言或运行本地替代界面。Core 已有 Locale 时所有运行错误沿会话语言显示。Core 未就绪时不写业务库，等待 CORE_READY；失败不宣称初始化成功。

## 离线检查与客户端门禁

- CoreNameIntegration：API12拒绝、API13接受、能力缺失与未就绪时停止、初始化幂等、共享角色表头。
- CoreAdaptation：真实 Core 输入模块、双语页面、资源对称、稳定分类 ID、预览快照准入／字段副本／高度预算、统一设置与三通道注册。
- GoalTargets：学习资格与制造计数、指定／共享基线的角色迁移。
- Smoke、RecipeStateScanner、RecipeScanScheduling、SearchPerformance：原缓存／原子状态／事件合并／无批量物品加载回归。
- action.targets 来源集成72项（含公开库存证据过期不可完成目标）及相关按键／设置回归；TOC 12个文件 Lua 5.1 语法检查。

以上不能替代客户端验收。新增资源文件后完整重启游戏，确认1.2.0：

1. 中文模式检查搜索“灯”、已学／未学／未知、名称／产物／已学格添加，确认无持续掉帧。
2. Core 语言设英文并重载，检查工具栏、目标配置、详情、分类与设置；缩窄窗口检查工具栏换行和角色列分页。物品／法术名称保留客户端原文。
3. 开启 Crafting 的 Broker／小地图／内置条任一入口，确认悬停显示有快照的角色及有限配方行；左键打开完整页。切预览字段后检查内容对应隐藏。
4. Core 中切服务器范围、隐藏角色、修改短名和排序，确认主页面与悬停一致；无需人为删除真实缓存或模拟角色 ID 迁移。

真实 enUS 客户端和英文客户端手动中文的字体／原生名称验收仍需对应客户端证据；手动英文不能替代该项。未通过前不标为已发布或客户端完整验收。

### 2026-10-12 客户端反馈修正

手动英文截图暴露专业显示优先使用原生中文快照的问题，已改为已知专业 ID 优先读取 owner 语言资源，统一覆盖专业选择、列表、矩阵分组与详情；未知专业继续使用原生名称，不改写历史快照。截图中的原生物品、配方、角色及服务器名称保持客户端原文，其它业务插件导航由各自 owner 负责。

下拉展开复用 Core Theme 统一互斥生命周期，普通／多选菜单切换自动关闭前一个菜单，嵌套分组选项保留父菜单并随父菜单关闭。CoreAdaptation 通过中文快照下英文专业显示检查；LocaleLayoutSpec 213项通过，包含菜单互斥、嵌套、隐藏、切换及选中收起。仍需 `/reload` 后确认英文专业显示与连续切换各筛选下拉，Core 设置多选内部分组可正常展开。
