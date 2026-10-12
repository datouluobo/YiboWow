# Mail 内存与首次打开性能修复

日期：2026-10-12。版本：YiboMail 1.2.10-api1。状态：代码与模拟验证完成，客户端待复验。

用户反馈 Mail 计量为 84.8 MB，第一次打开明显卡顿。截图只能确认该次计量，不能单独证明内存泄漏或常驻数据大小。

## 原因与修改

Core `Characters:GetCurrent()` 默认深复制完整角色记录，包括 domains 中的背包、专业等数据。Mail 在名称格式化、邮箱状态检查、联系人地址与列表构建中反复调用它。之前历史布局优化减少了隐藏行格式化，仍未消除可见行和原生邮箱路径的完整角色复制；邮箱上下文还会让行回调保留这些无关数据。

本轮这些身份查询复用 Core `GetCurrent({identityOnly=true})`：ViewModel、Items、Scanner、NativeUI、AccountPage、CacheUI、Queue、ActionTodo、WorkspaceState 与新建历史角色占位。联系人内部 `Current()` 返回轻量身份，并从 Core 公开 `GetAllCached()` 只读目录补充 faction；Compose、SendRules、RuleSendUI 复用这个投影，保留跨阵营判断。未改变已有邮件、历史、附件与保留天数，也未清理用户缓存。

共享目录仍遵守 Core 原有缓存与失效语义。插件不建立第二份角色目录、不访问 Core 内部数据库、不返回共享目录给可变的联系人调用方。设置页和诊断 Slash 的未触及低频完整读取保留为后续审查库存。

## Core 公共能力复核

本轮接入 CAP-007，继续使用已有 `character-identity:1`，最低版本为既有 Core 1.12.0 / API13。Bootstrap 已检查该能力及 API，缺失时提示升级并停止初始化，无本地回退或新 Core 接口。阵营是轻量身份契约之外的字段，因此通过既有公开只读目录补充，不假定 identityOnly 返回 faction。名称仍经 FormatName，账号壳与输入继续由 Core 提供。同步更新公共能力迁移台账中的 Mail 状态。

## 验证

- 新增 `YiboMail/_NonRelease/Tests/IdentityPerformanceSpec.lua`，加载真实 Core Characters 与 Defaults，在角色中放入 10,000 条无关物品。关闭 GC 的测量窗口仅用于统计累计分配，结束立即恢复，不是插件运行策略。
- 100 次默认完整读取累计分配 116.6 MB，约 0.66–1.27 秒；100 轮邮箱上下文、名称、状态和联系人查询约 179.7 KB、约 0.001 秒，领域深复制为 0。邮箱上下文不保留 domains，联系人阵营投影修改不污染目录；known／stale／error 与缺失角色行为通过。这是独立 Lua 的对照实验，不代表游戏内最终占用或耗时。
- MailRuntimeSpec、MailAPIConsumerSpec、NativeInboxSpec、WorkspaceSpec、RecipientsSpec、RecipientUISpec、RuleSendUISpec 通过，覆盖扫描、收取、API 隔离、联系人与阵营、规则 UI 和连续历史滚动。
- InboxReleaseSpec 在第 51 行失败，夹具仍只支持 API9，与现有 API13 启动要求不符；RuleSendSpec 在第 255 行失败，旧夹具未加载语言资源却断言中文错误。已分别用 HEAD 的全部 Mail 运行源码重跑，均在同一位置失败，属于既有测试夹具问题，不作为本轮通过证据。

客户端需重载后比较首次打开、关闭再打开、账号历史／联系人／规则页及批量收取；分别记录打开耗时、打开后和回收后的 Mail 内存。游戏中的内存数值与首次打开体验仍待实际验收。

## 1.2.11：打开／关闭整帧停顿的后续修复

用户复验仍报告打开／关闭时游戏停住数秒，截图 Mail 为111.4MB。1.2.10 的角色复制对照实验只能证明一处开销已消除，不能据此认定客户端问题完成。

继续检查发现：Scanner 打开／关闭通过 `mail.items` 发布状态，Vault 经 Core Contracts 同步刷新全账号；旧 GetTransfers 为每个接收角色遍历全部发件，并为每条相关发件再次扫描发件方的收件／历史寻找退回。自动查看多封邮件还逐封 Publish，使这条同步链反复执行。

现在按真实邮件数据版本和角色目录建立一次全账号证据索引：按接收者、发件者、主题与完整附件签名分桶，证据按时间排序，二分查找与已消费位置压缩避免重复邮件的逐次扫描。所有接收角色复用索引；结果仍逐次复制，消费方无法修改内部缓存。匹配仍要求账号角色、完整附件、发送后的收件或退回证据，重复邮件按出现次数消耗；证据选取改为最早符合时间条件的尚未消耗记录，取代无稳定顺序的 pairs 遍历。原始邮件与历史不变。

Store Publish 内部区分纯状态／已读变化和数据变更。前者保留在途数据版本，公共 API revision 继续最新；扫描提交、归档、清理默认失效索引，角色目录身份变化也失效。没有为 Mail/Vault 新增公共契约或反向依赖。自动确认只合并同轮、同角色的通知，所有成功确认的邮件先写入 Mail，再一次发布完整 changedMailKeys；确认失败不进入批次，已确认邮件重复刷新不再通知。

验证：新增 TransfersPerformanceSpec（可传 baseline 载入 HEAD 的旧 Items），20角色、3411条发件方历史、300条收件证据，1200次同签名发件中500次退回、300次收件后保留400个在途记录。旧实现约0.725秒、累计分配6.96MB、59020次地址解析；修复约0.042秒、2.83MB、3711次解析。关闭GC仅用于测量累计分配，结束恢复；这些数值不代表游戏内内存常驻量。

30轮纯状态更新不重新解析历史，返回revision仍最新；实际新收件、未来发件、角色更名触发正确匹配，结果复制隔离通过。真实 NativeUI 自动确认100封邮件只发布1次完整通知，重复刷新0新增通知。MailRuntimeSpec、MailAPIConsumerSpec、IdentityPerformanceSpec、WorkspaceSpec、NativeInboxSpec通过；修正既有 MailProviderSpec 的角色Get／FormatName与语言夹具后，真实 Mail→Core Contracts→Vault 集成通过，并补验新发件在途增加、收件核实移除、历史保留及缺失／不兼容／晚注册行为。Vault运行源码未改。

本轮仅涉及 CAP-005 的既有 mail.items 服务消费与 CAP-007 的已接入身份调用；最低 API13／能力检查不变，已同步台账。发布Lua语法、diff空白和本地化报告检查通过。游戏内首次打开、重复打开、关闭的整帧耗时及回收前后内存仍待复测。

## 1.2.12／Vault 1.2.2：批量取件过程

用户继续反馈批量取件仍有卡顿。队列每确认一个附件时，扫描提交、已读状态保留和成功归档原先分别 Publish，重复驱动 Core Service 消费者处理同一确认。Queue:Notify 还对开始下一动作及确认进度触发账号／原生界面的完整刷新。

现在 Scanner 在同一轮提交与 Queue:OnScan 确认内暂存通知；数据库与revision即时推进，完成后每角色合并变更键和物品ID、去重排序，并发布完整状态。归档发生时reason为archive，公共revision保持最新。批次在通知消费者前解除，支持重入；回调异常时也解除批次并通知已提交变化，再抛出错误，不吞掉后续发布。扫描就绪失效、错误及暂停的安全语义保留，不将未知结果当成功，不增加自动收取重试。

挂载稳定列表取件期间，队列通知仅更新原生进度页脚；对应邮件行仍由既有OnCollected刷新，完成／暂停恢复完整刷新。数据变化继续走Core公开通知。Prepare与Start对同封邮件的多个动作只复制一份各自私有的原始邮件快照；调用方不能通过修改准备结果改变已启动队列。

Mail公开通知增加可选transfersUnchanged提示；明确为true时Vault只刷新对应角色，缺失／false或混合真实数据变更仍刷新全账号。生命周期、来源缺失与不兼容沿用原有行为；Mail与Vault互不访问私有对象或SavedVariables。最低Core API13／business-services:1不变，旧消费者忽略提示仍正确，契约已更新；CAP-005台账同步。

MailRuntimeSpec新增30封／90附件测试，使用真实Scanner分块、Queue事件确认与Store：完整取完、90条成功归档、库存归零、索引移动及调用方隔离通过；通知180次（每动作就绪失效一次、完整确认一次），队列完整刷新1次。模拟耗时约0.09–0.19秒，不含服务器延迟，不代表游戏内速度。新增回调失败后批次释放验证通过。MailProviderSpec验证纯状态刷新1角色、无提示／数据变更刷新全账号、混合批次不错误保留提示；实际接口的在途增加／收件核实、缺失／不兼容／晚注册通过。既有收取超时、背包空间、战斗、到付排除与原生收件回归通过。

Mail 1.2.12-api1与Vault 1.2.2-api1需一起重载复验多邮件／多附件批量收取。客户端帧耗时与流畅度尚未验收。
