# API13：YBP 离线兽栏所需的公共支持契约

日期：2026-10-27。状态：R3 三目标非发布消费者验证完成；复用既有公开 API，未新增能力、宠物数据域或业务实现。实际验证及待验边界见[R3 验收记录](R3-YBP离线兽栏公共契约实施验收.md)。本页固定下一版 YBP 的接入基线，不表示 YBP 已接入。

R5复核：本页API13及12项能力／方法门槛保持，R4只补充Retail／Mists指定包的基本页面、覆盖和恢复证据，不证明真实兽栏接口集成或全部公共UI路径。Forever实机保留待测，整体未判定可发布；最新边界见[R5收尾](R5-文档与台账收尾验收.md)。

## 职责、目标与最低要求

提供方为 YiboCore；预期消费方为后续 YiboBeastPaths 离线兽栏。Core 拥有角色目录、通用偏好、窗口壳、统一设置、入口生命周期和清理调度；YBP 拥有宠物采集、快照、schema、时效、准入与拥有判断。无其它业务消费需求，本次不创建宠物 Service／Provider，不让 Core 读取 YBP 的实现或 SavedVariables。

Core 当前开发版本为 Retail0.1.0、Mists1.12.9、Forever0.2.0，API13／schema11。本契约的三个目标验证不增加 YBP 支持集合；YBP 仍仅为 Retail／Mists。消费方根据 API、能力版本和实际公开方法判断，不能用插件版本字符串代替。

| 必查能力 | 最低版本 | 本次用途 |
| --- | --- | --- |
| runtime / events | 1 / 1 | 初始化状态与变化订阅 |
| characters / character-identity | 1 / 1 | 当前 GUID、轻量目录与跨服务器关联 |
| character-name-format | 1 | 统一角色显示；显示名不作关联键 |
| character-cleanup | 2 | 业务所有者影响说明、删除与延后回放 |
| account-view | 2 | 统一业务页、范围、排序、字段与预览 |
| account-character-admission | 1 | 隐藏／等级筛选变化通知 |
| account-surface-budget | 2 | 业务内容尺寸与统一滚动表面预算 |
| account-entry | 2 | 业务入口创建、绑定和注销 |
| builtin-entry-bar | 3 | 三通道独立选择及总开关语义 |
| localization | 1 | owner 中英文资源和 Core 会话语言 |

预览沿用默认最多20名，不使用不限数量字段，故不把 `account-preview-characters:1` 列为必需。首期查看夹具无业务输入，不要求 `basic-input`；没有物品操作或跨业务消费，不要求物品选择／操作或 Service／Provider 能力。后续真实布局新增需求时再补相应最低检查。

消费方初始化前顺序检查：实际客户端目标 → Core 存在及公开门面 → `CheckAPIVersion(13)` → `IsInitialized()` → 上表能力 → 本页所用方法。Core 目标写库保护不替代 YBP 自己的业务目标保护。TOC OptionalDeps 或“已加载”都不能代替就绪检查。按已确认范围，原有路线保持独立；离线兽栏是可选增强，继续沿用[既有依赖边界](../../YiboBeastPaths/Docs/Core-API13-接入说明.md)，不把整个 YBP 改为强依赖。

## 方法、参数与数据范围

| 公开调用 | 输入／结果／失败语义 |
| --- | --- |
| `Characters:GetCurrentID()` | 当前角色唯一 ID；尚未观察到可用 GUID 时为 nil。YBP 不用名字临时建业务角色 |
| `Characters:GetCurrent/Get/GetAll({identityOnly=true})` | Get 另传 characterID；返回身份副本或列表，单角色不存在为 nil，空目录为空列表；含 id/name/realm/class/level/lastSeenAt/seenOrder，不含 domains |
| `Characters:FormatName(identity, options)` | 格式化身份显示；读取 Core 名称偏好。结果不用于持久化关联、匹配或业务操作地址 |
| `RegisterAddon(owner,{requiredAPI=13,...})` | 先登记技术 owner；API 不兼容返回失败。不是整个依赖门槛的替代品 |
| `AccountView:RegisterPage(owner, definition)` | 登记下文页面定义，成功返回页面；重复 ID 拒绝，消费方保证一次初始化 |
| `AccountView:BuildContext(page,{preview=boolean})` | 返回 Core 准入、等级、服务器范围、排序及字段处理后的视图上下文；角色记录按只读使用，不直接改其表 |
| `AccountView:NotifyPageChanged(pageID)` | YBP 提交业务快照后通知当前页面失效；不以刷新触发采集或循环广播 |
| `AccountView:GetScrollSurfaceWidth(context,parent,bodyHeight,fixedHeight)` | 渲染时读取 Core 预算宽度；尺寸定义与测量一致，不重复扣滚动槽 |
| `Entry:RegisterBusinessEntry(owner,definition)` | 绑定本 owner 已注册页面；Core 管理 Broker／小地图／内置条，默认三个独立通道均关 |
| `Locale:Register(owner,"zh"/"en",resources)`、`Locale:Get(owner,key,...)` | 使用稳定 ASCII key 和相同格式参数。会话语言由 Core 统一选择；动态宠物名称保持原文 |
| `Events:Register/Unregister(event,owner,callback)` | 按稳定 owner 与 callback 登记、清理；重复同一元组幂等，新建闭包不是同一订阅 |
| `CharacterCleanup:RegisterOwner(owner,{Inspect,Delete})` | 登记业务影响查询及所有者删除；同会话重复登记拒绝，无通用注销 owner API |
| `AccountView:UnregisterPage(pageID)` | 注销页面、释放实例并禁用关联入口，关闭对应预览。LibDataBroker 对象可保留但禁用交互，不要求物理删除对象 |

账号范围仅为本客户端本地已观察角色目录，不承诺跨客户端、Battle.net账号或设备同步。不同服务器同名角色必须按 GUID 分开；历史 Core 目录中的非猎人仍正常保留。

## 页面准入、两组快照与显示

`HasCharacterSnapshot(character)` 与 `GetEligibleCharacters(characters,context)` 必须消费同一 YBP 准入判断：猎人且已有成功采集的兽栏快照。只有随身数据、兽栏从未成功读取、只有 Core 角色记录时不加入。已成功确认的空兽栏仍是有效业务快照；暂不可读但保留历史兽栏的角色仍可显示。该准入由 YBP 负责，Core 不解释宠物规则。

页面声明 `scope={mode="realms"}`，服务器按钮同样使用 `HasCharacterSnapshot`；通过统一范围选择可查看所有服务器。Core 保留共享范围偏好，业务阶段须确认首次打开选中全部服务器的体验，不自行维护第二套范围过滤。`GetEligibleCharacters` 不能重新加入 Core 已隐藏角色；只过滤传入集合。Core 随后应用默认等级过滤与统一排序。

YBP 返回同一只读业务快照的主视图和预览投影，按角色 ID 关联。随身／兽栏分别携带上次成功时间、当前读取状态及必要的最近尝试信息；一组失败不修改另一组时间。失败保留旧记录并明确标注，不能把失败转换成已知空。夹具仅投影预先构造的两组值，未实现或验证宠物扫描、提交／迁移算法；最终业务 schema、完整性与跨组移动语义由 YBP 依据真实 API 样本确定。

`lastSeenAt` 是 Core 角色观察时间，不代替任一宠物组的采集时间。不因角色登录、排序、隐藏或显示名变化而改写业务时间。宠物数据没有 Core 统一重置周期；时效、陈旧性、部分扫描和跨组冲突由 YBP 解释，不能把两份异时快照当成同一时刻完整清单。路线“已拥有”留在后续版本，不根据缺失／未知推断未拥有。

页面提供 `Create/Refresh`、`GetSurfaceMetrics` 及实际内容布局；Core 负责安全屏幕边界和窗口壳。主窗口显示全部有效角色，普通预览是同一排序的最多前20名。`GetSurfaceMetrics` 的自然尺寸基于完整角色范围，成对提供 scrollContentHeight／scrollFixedHeight；实际长列表的控件滚动、屏幕可达性在 YBP 业务阶段实现并验收。

业务设置通过该页面的 `settings.CreateSettingsPanel` 提供内容，只有适用的业务设置与数据／缓存分区，不另注册一份同业务独立设置导航。通用入口、字段、悬停、角色／排序交给 Core。首期夹具不需要输入控件，也未新增设置窗口壳。

## 依赖、通知与生命周期

非发布夹具使用稳定诊断码 `core-missing / core-api-old / core-not-ready / core-capability-old / core-interface-missing` 表示停止原因。真实 YBP 须在对应增强入口给出中英文“安装／启用 Core”“升级 Core”或“等待 Core 就绪”提示；这些玩家提示尚未接入，不能把夹具诊断码记成真实提示验收通过。Core 不可用时不会建立兽栏窗口／存档；路线继续运行。既有路线语言维护例外不扩展为兽栏本地回退。

Core 已存在但未就绪时订阅 `CORE_READY`；Core 在消费方后加载时，由插件实际 ADDON_LOADED 入口重新发现门面、订阅并立即重试。没有可靠的缺失全局对象可供提前订阅。夹具通过换入真实 Core 实例并再次 Watch 验证发现／就绪协调；真实 YBP 的原生加载事件仍待业务接入。

`ACCOUNT_VIEW_CHARACTERS_CHANGED(change)` 描述隐藏或默认页面等级过滤已提交，change 包含 reason 及适用 characterID/pageID；同值和无效筛选不发变化。`CHARACTER_DISPLAY_UPDATED` 通知名称显示变化；`CHARACTER_CACHE_DELETED` 通知缓存删除事实。消费方只重读快照／使展示失效，不回发同类事件。接口细节见[准入通知](API-v11-角色准入通知.md)。

初始化用会话状态保护，同一页／入口／owner／订阅只登记一次；调用 Start 前仍校验依赖，不能只看本地 initialized 标记。停止增强时清理变化与就绪订阅、注销页面；重新启用创建新页面实例，复用当前会话单个清理 owner，不直接修改 Core 的私有 owner 表。失败注册要按实际结果停止并处理已完成的注册，不能用已加载或部分成功标记整个增强就绪。

## 清理所有权与延后回放

`Inspect(character,aliases)` 返回 hasData／label／detail 等影响说明，label 使用 owner 会话语言。Core 只询问回调；业务数据仍只归 YBP 保存。owner 不可用时影响为未知并进入 pending，不能当作无数据。

`Delete(character,aliases,context)` 的 context 含 `deletedAt/deletionID/replay`，返回 true 确认成功，nil/false 或异常保留待处理。直接删除按用户意图清理该角色业务数据；延后回放由 YBP 按分组成功时间决定旧数据清除与新观察保留，不能因为一组较新就无条件保留全部旧组。回放成功只确认清理，不恢复 Core 已删除角色目录。只有真实的新身份观察可以重新加入目录；已确认记录不重复执行。

清理 owner 在当前会话保持登记，即使业务页面关闭；停用页面不等于删除业务数据或注销清理责任。禁用插件的下一会话，Core 根据持久 owner／删除历史记录保留影响与待处理项，业务下次登记时回放。详见[角色清理 v2](API-v13-角色清理v2.md)。

## 兼容与后续触发

本轮不改变 Core API13、任何能力版本、三个目标 SavedVariables 身份、运行清单或 YBP 最低要求。后续 YBP 实施时按本页冻结所用能力与方法、补实际目标检查和双语提示、保存／恢复及晚加载幂等验证，并更新 CAP-001／004／007／009／010 的业务接入状态。当前台账只能记“Core 契约已验证、YBP 待接入”。真实实现需要额外控件或能力时，先评估已存在公共接口，避免并行实现。
