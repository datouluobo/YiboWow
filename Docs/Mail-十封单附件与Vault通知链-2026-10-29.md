# Mail 十封单附件与 Vault 通知链优化（2026-10-29）

用户实机基线：约10封信、每封1附件，批量收取后约170MB；关闭后44MB，继续自然回收至27MB，接近登录26.2MB。Alt单份约40MB的改善证据保留。本轮按十封单附件补齐真实Core→Mail→Vault通知链的离线回归，不以此前100封×12附件、无下游角色大数据的场景代替。

## 定位与改动

Vault的Mists MailProvider在业务变化、角色目录变化、提供者生命周期与安装路径，共四处使用GetAllCached()枚举角色。它只消费角色ID，却请求含domains的完整Core角色快照。背包域更新令Core缓存失效后，下一次Mail通知会重新复制全部无关业务数据；即使Mail自身的扫描和原生进度界面已减配，这项成本仍发生在联动回调中。

四处改用Core API13 / character-identity-cache:1的GetAllCached(identityOnly)只读目录。保持全部角色、隐藏/离线角色的原准入范围、顺序和刷新时机；不缩减需要重新查询在途的接收者。没有改变Mail业务通知、revision、transfersRevision、Contracts复制隔离、Vault状态/指纹/计数或回退到本地存档的既有规则。

该能力在Mists MailProvider的Connect/Install边界显式检查：不足时清除连接与派生查询缓存、只提示一次升级，停止这项可选集成；Vault已有本地邮件采集与历史存档保持。它不是并行的本地角色目录实现。能力恢复后可重新连接，不重复注册订阅。Vault基础Core门槛及Bootstrap保持，Forever使用独立MailProvider，不消费这项新要求。

## 十封单附件回归

TenLetterChainSpec使用真实Core Characters、Events、Contracts，真实Mail Store/Scanner/Queue与Vault MailProvider/Items。31角色共46500条无关Core业务记录；Mail有7812条既有历史（31×252，含682条在途寄信），再扫描10封每封1附件。逐封模拟原生成功和邮箱变化，并用DATA_DOMAIN_UPDATED令Core缓存失效。界面使用轻量呈现计数器，不包含真实WoW控件布局或外部Tooltip挂钩。

冻结本轮前MailProvider，其余代码、数据及事件相同。暂停GC累计分配，结束后恢复；这是整条Lua联动链的累计分配，不是游戏按插件归属的统计或实际最高峰。

| 同一10封×1附件场景 | 修改前 | 修改后 |
| --- | ---: | ---: |
| 收取阶段累计分配 | 110.673MB | 29.895MB |
| 完整角色目录构建 | 10次 | 0次 |
| 轻量身份目录构建 | 10次 | 10次 |
| Vault Refresh调用 | 342次 | 342次 |
| 收取阶段完整Native呈现 | 2次 | 2次 |
| 原生进度更新 | 20次 | 20次 |
| Header / Item / Link读取 | 39 / 624 / 39 | 39 / 624 / 39 |

累计分配减少约73%，消除了约80.8MB无关完整角色复制。原生读取计数包含测量前的首次扫描，两边范围相同。内部Publish调用22次，确认批次仍合并通知，不等于22次整箱呈现。Vault Refresh内含其他查询，分项是嵌套口径，不能与总量相加。

全部10次收取成功，10条完整原信归档、10条首次发现与7812条既有历史保留；682条未匹配在途数量仍可查询。测试还覆盖缺能力时无目录查询、提示一次、保留本地存档、恢复重连、重复Install不重复订阅，以及角色目录事件也不物化完整Core缓存。累计分配设置35MB上界防退化。

## 验证与兼容

- 综合79／79离线回归、373个加载引用Lua语法通过。既有Mail/Vault缺失、禁用/注销、晚注册、不兼容、旧提供方字段缺失、部分/未知/错误/关闭、真实跨角色在途与公开副本隔离用例继续通过。
- 仅Mists链引用的YiboVault/MailProvider.lua发生运行变更。Core与Mail运行代码本轮未变；Core能力迁移登记CAP-007，CAP-005仍经既有Contracts协作，CAP-004/009接口与语言门槛保持。其他Vault完整角色查询尚未触及，不登记为全插件迁移完成。
- 没有新增客户端专用API，不需目录迁移；TOC/XML、默认Mists加载链、实际客户端保护、Bootstrap、Core基础版本检查、SavedVariables身份、schema、完整历史与幂等注册结构保持。新增能力检查只停止依赖它的可选邮件集成。现有覆盖安装机制不变，新字节实机仍待。
- Vault Mists源码/玩家加载均沿用YiboVault.toc；Mail沿用YiboMail.toc。统一构建器对两者均已通过ValidateOnly目标、Interface、引用和包内容校验；不生成包、不提交推送或发布。Forever的独立提供者未修改，既有Smoke不扩大新验收范围。
- 使用既有BOOT.CORE_REQUIRED中英文资源，无新增玩家文案；静态报告已复核：Mail/Vault硬编码候选0，缺英文/参数差异0，6项未知key仍为未触及的AutoOpen。没有修改GC参数、强制回收、删除或压缩存档。

## 待实机

需同步使用修正后的Vault与具备character-identity-cache:1的Core；只替换Mail不会包含本轮修复。重载后复测约10封×1附件，记录即时最高值、关闭前后及自然回落。此处已确认通知链复制放大，不宣称已解释客户端170MB的全部归属，不能把110.7→29.9MB直接当成游戏峰值预测。
