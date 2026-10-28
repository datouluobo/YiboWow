# R3：YBP 离线兽栏公共能力与消费者契约验收

日期：2026-10-27。状态：**R3 非发布消费者契约验证及 Mists／Forever 适用离线回归完成；无新增 Core 运行代码，YBP 业务未接入；R4 客户端／安装／恢复与发行检查仍待，未发布。**

前置为[R2 目标与构建验收](R2-01-02-Retail目标与构建实施验收.md)。本次落实[总方案](Retail-共享底座适配实施与验收方案.md)的 R3，只验证 Core 公共支持，不实现宠物采集、业务持久化或路线“已拥有”。固定的消费接口与失败语义见[API13 公共支持契约](API-v13-YBP离线兽栏公共支持契约.md)。

## 审查结论与产出

现有 API13 与12项能力已能满足本阶段需求，不新增宠物域、通用 Service／Provider、占位模块或版本号。Core 目录不限制职业，YBP 未来通过业务准入选择猎人。三目标生产 Lua／TOC 共87个物理文件的摘要与 R2 完全一致；schema11、能力版本与运行加载图保持，机器结果见[Results](../../_NonRelease/CoreConsumerR3/Results.json)。

新增根目录非发布夹具 `_NonRelease/CoreConsumerR3/`，分别加载真实 Retail／Mists／Forever 清单。`CoreR3Consumer` 是独立测试 owner，未冒用 YiboBeastPaths 注册，未执行 YBP 源码。测试宠物行、两个分组、时间与状态均为合成内存数据，没有原生宠物 API、业务 SavedVariables、客户端探针 TOC 或游戏联接。夹具代码不进入正式加载链／包内容。

公开支持基线：runtime:1、events:1、characters:1、character-identity:1、character-name-format:1、character-cleanup:2、account-view:2、account-character-admission:1、account-surface-budget:2、account-entry:2、builtin-entry-bar:3、localization:1，并显式检查实际使用的方法。预览沿用默认20名，无需不限预览能力；无业务输入、物品或跨业务查询，不增加相应依赖。

## R3 专项结果

三目标 × 五种语言组合：zhCN／zhTW／enUS自动、中文客户端手动英文、英文客户端手动中文；手动模式使用合成 Core 存档重新启动。专项当前 **2,463项通过**，见[Spec](../../_NonRelease/CoreConsumerR3/Spec.lua)和[原始结果](../../_NonRelease/CoreConsumerR3/TestResults.json)。

| 范围 | 已验证行为 |
| --- | --- |
| 缺失／旧版／未就绪 | Core 缺失不登记消费者；已加载但未就绪停止；旧 API、缺失或过低能力、能力已声明但方法不存在均停止；基础路线替身仍能调用 |
| 晚到／重复就绪 | 替换可发现 Core 后协调 CORE_READY；重复 Watch／通知／Start 只创建一个页、owner、入口和订阅；真实 YBP ADDON_LOADED 尚未接入 |
| 跨服与身份 | 通过原生读取替身观察角色，两个同名猎人不同 GUID 分离；Core 保留非猎人；轻量身份返回副本且不含 domains，未知角色为 nil |
| 业务准入 | 同一判断供 GetEligibleCharacters／HasCharacterSnapshot；无快照、只有随身、从未成功读取兽栏与非猎人排除；已知空兽栏和失败保留历史的兽栏准入 |
| 范围／显示／排序 | 全服务器与单服务器集合、有效服务器按钮、隐藏与同值不通知、有效／无效等级筛选、升降序、短名／服务器显示；这些偏好不改写历史分组 |
| 两组投影 | 随身／兽栏独立时间、最近尝试与不可读状态原样投影，历史名称保持；可修改投影不污染 owner 数据；不据此证明真实采集保存算法 |
| 主窗口与预览 | 实际 Core Create／Refresh 与 Entry 预览使用同一投影；25个有效角色主窗口完整，默认预览为同顺序前20名；安全边界和内容预算走 Core |
| 入口／设置 | Broker／小地图／内置条八组合、总开关保留选择、内置条默认关闭；左右键打开业务页／统一设置；页面托管业务设置，不重复登记独立导航 |
| 注销／重开 | 清理变化与就绪订阅、注销页面、禁用关联入口；重开建立新页面实例，清理 owner 保持当前会话单次登记 |
| 清理与失败 | Core 调用 owner 影响查询／删除；同名另一 GUID 不受影响；当前角色不能删；失败保留业务数据与 pending；成功回放不再重复 |
| 跨会话 owner | 合成存档重新启动，owner 缺失显示未知并 pending；晚登记重放，逐组清除删除前快照，保留删除后新观察；不恢复已删 Core 目录 |
| 语言 | owner 中英文资源齐全、格式参数一致，未知／保留与采集时间文案按会话语言解析；真实字体、IME及 YBP 缺依赖提示不在此结果内 |

已明确的调用约束：Core 对重复页面、重复清理 owner 返回错误，不将它们解释为全局幂等；消费方自行保护初始化。清理 owner 无通用注销接口，页面关闭后继续负责当前会话清理；重新打开不能重复登记。`GetAllCached`／BuildContext 角色按只读使用，要求可修改身份时用 identityOnly 副本。名称格式化使用 nameMode／realmMode，不把显示名当 GUID。

## 旧目标及构建回归

本阶段共执行 **34条命令，28条通过，6条非零退出**；6条为既有5组失败加1条诊断，未新增失败。日志逐条保留，无跳过失败断言。当前专项、回归结果及源文件摘要位于[非发布记录](../../_NonRelease/CoreConsumerR3/README.md)。

| 回归 | 结果 |
| --- | --- |
| Retail R2／索引 | 115／11项通过 |
| R1 语言／元数据／通用契约／原生边界 | 791／389／465／192项通过 |
| 启动／身份／TOC入口 | 334／133／149项通过 |
| Mists／Forever Smoke、Forever联合、专业消费者 | 70／268／92项通过 |
| 公共契约／角色名／清理v2 | 90／77／59项通过 |
| Currency控件、API13、迁移；Reputation迁移 | 控件通过；1102／23／88项通过 |
| Goals／GoalSurfaces／BossGoals | 94／30／19项通过 |
| 三目标统一构建 | R3计划26项、既有计划148＋154＋16＋36项、别名验证2项通过；只 ValidateOnly，不生成或移动包 |
| Lua5.1／本地化 | Core5个TOC共74文件通过；563key缺英文／格式错／重复均0，原6个AutoOpen未知key与27个Core候选不变 |

扩展回归原失败：EntryBar／Layout均止于Mail WorkspaceSpec:349；ItemActionSettings止于GoalSourcesSpec:156，独立诊断为Vault夹具缺少T方法；RuntimePerformance:109定时器断言；LocaleSpec:57旧字段nil。与 R2 位置一致，详细输出保留；TaskChain历史问题本轮未重跑。适用回归通过不等于全仓全部测试通过。

R3生产运行字节未变，复用 R2 的正式服12.1.5.70575／Interface120105基础源码启动及中文页面证据，不重复请用户测试。R3没有新增客户端消费者实测，不将其投影、语言或合成恢复记为实机通过。R2本地ZIP仍是原哈希快照；本轮新增公开文档使完整源码归档摘要变化，R3没有重建或覆盖旧ZIP。最终包检查及安装由 R4 按实际构建产物执行。

## 加载、数据身份与迁移收尾

| 项目 | 本轮结论 |
| --- | --- |
| 插件／目标 | Core公共契约在Retail／Mists／Forever离线验证；不新增YBP Forever支持 |
| 源清单／实际加载名 | Mists／Forever用对应目标源清单；Retail标准YiboCore_Retail.toc与开发YiboCore_Mainline.toc一致；玩家包默认YiboCore.toc。R3不改任何TOC／XML／运行入口，无需新增原生发现测试 |
| 误目标保护 | 沿用R2写库前产品身份与存档预检，R2专项本轮复跑；真实YBP须自行校验实际目标 |
| 就绪／版本 | API13及12项能力、所用方法在夹具中逐一校验；就绪之前不注册增强；真实YBP玩家提示仍待接入 |
| 初始化 | 消费方会话幂等、同一回调订阅、注销与重新登记已验证；不更改Core既有重复注册错误契约 |
| 存档身份 | YiboCoreDB／YiboCoreForeverDB／YiboCoreRetailDB、schema11保持；只使用合成数据，未读取或修改玩家WTF |
| 旧文件覆盖 | 无运行文件迁移或加载图变化，既有保留文件图测试通过；最终包真实覆盖继续R4，不以纯文档变更重新要求旧探针测试 |
| 构建引用 | 三目标统一ValidateOnly通过，62／59／56个运行引用不变；非发布夹具不进入生产TOC，无新资源引用 |
| 公共能力接入 | CAP-001／004／007／009／010：Core契约验证增加，真实业务接入状态不变；YBP离线兽栏仍待实施 |
| 版本／Git／发布 | Mists1.12.9／Forever0.2.0／Retail0.1.0／API13保持；本地main未提交、未推送、未发布，无删除或客户端目录操作 |

## 后续待验

- R4：最终包真实干净／保留旧文件覆盖、测试存档副本的reload与完整退出恢复；新增UI／语言／战斗／宿主／IME等未验范围按既有矩阵执行。
- DEV-002：真实Retail／Mists宠物API采证、两组快照提交与迁移、读取失败保留、跨组移动陈旧语义、首次全服务器查看、真实Core缺失／旧版提示和路线独立运行、实际滚动控件及业务存档恢复。
- DEV-005：后续路线“已拥有”可靠匹配与未知状态，不纳入R3完成项。

R3作为独立阶段完成；Core整体验收与发行门槛仍未闭环，不宣告可发布。YBP任务仍见[版本任务清单](../../YiboBeastPaths/Docs/离线兽栏与拥有状态-版本任务清单.md)。
