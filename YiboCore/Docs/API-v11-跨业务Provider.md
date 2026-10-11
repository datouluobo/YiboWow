# API v11：跨业务 Provider

2026-10-09：工作树 Core 1.10.0 / Public API v11 已实现 `business-providers:1`。尚未发布，游戏内待验收。原 `business-services:1` 与 v9／v10 调用保持兼容。O2 已接入 YiboTodo 的 action.todo 输出与 TaskHub 消费，见 [实施验证](../../Docs/行动中心-O2-实施与验证记录.md)。

## 需求与边界

真实消费者为 YiboTaskHub 的来源任务总览，YiboTodo 已提供专业冷却与诺米两个来源。多个业务按同一 action.todo 契约提供工作，Core 只提供注册、版本枚举、隔离调用与生命周期；任务、角色资格、冷却、完成判断及 SavedVariables 由各业务所有者负责。字段映射见 [O1 专业冷却映射](../../Docs/行动中心-O1-专业冷却字段映射.md) 与 [O3 诺米映射](../../Docs/行动中心-O3-诺米字段映射.md)。

Core 不预注册 action.todo，不自动扫描业务数据，不保存任务，也不按业务插件技术名分支。公开业务契约的方法和返回 schema 由提供者与消费者明确，Provider 机制不替代业务校验。

O5 已按原契约接入第二个业务所有者：Mail 1.2.3-api1 输出 `YiboMail:inbox-collection`，TASK 自动枚举第三个真实来源，无 Core 或 TASK 运行改动。新增 46 项检查、合计 265 项通过，见 [邮件来源](../../Docs/行动中心-O5-邮件待收取.md)；邮件基础 Service 和 Items API v1 保持兼容，客户端待验收。

## 最低版本与失败行为

新增 Provider 注册／枚举的使用者检查 `CheckAPIVersion(11)`、`HasCapability("business-providers", 1)` 和实际方法，并在业务接入模块记录最低版本。旧 Core 提示升级并停止新增集成；可独立运行的来源基础业务继续按原最低要求运行，不通过业务全局对象回退。

仅使用既有 Service 的消费者继续检查 API v9 / business-services:1。Provider 版本与 Core API 版本分别检查；完整业务工作流不因 Core 升级而视为已提供。

## 公开接口

| 方法 | 语义 |
| --- | --- |
| `Register(owner, definition)` | owner 已登记；接受 kind=service 或 provider。name 非空，providerID 以 owner 加冒号为前缀，major 为正整数、minor 为非负整数，methods 为非空方法表。返回运行期 registrationRef 或 nil,code |
| `Resolve(name, {major,minMinor})` | 继续只发现单 Service，不把唯一 Provider 转换为 Service |
| `List(name, {major,minMinor})` | 新增；枚举该能力与主版本下次版本符合要求的 Provider 描述符，按 providerID 字符串升序返回副本；无符合者返回空数组，Service 不进入数组。非法版本返回 nil,invalid-version |
| `Call(caller, descriptor, method, request)` | 复用；按 descriptor.kind 定位 Service 或 Provider，检查注册令牌和身份，隔离请求、调用异常及返回值 |
| `NotifyChanged(owner, ref, change)` | 复用；只有登记所有者可提交变更通知，业务先保存数据再通知 |
| `Unregister(owner, ref)` | 复用；先移除注册再通知，旧描述符立即失效，重新注册获得新令牌 |

版本查询的 major 为正整数，minMinor 默认 0，显式提供时为非负整数。不同 major 不互相兼容。

描述符保持 `{name,kind,owner,providerID,version={major,minor},registrationRef}`。List／Resolve 不暴露回调或内部表；修改描述符不能修改注册。Provider 描述符须保留 kind=provider；既有 Service 的旧描述符省略 kind 的调用保持兼容。

回调收到 `handler(requestCopy, context)`，context 沿用 callerAddon、name、providerID、registrationRef。返回 result,code,details，各自复制；未登记调用方、缺方法、旧句柄分别返回 caller-unregistered、method-unavailable、unregistered。提供方异常或非值数据返回 provider-error，不影响其他来源。

## 冲突与稳定身份

- Service 在 name／major 下唯一，另一所有者或来源冲突仍为 service-conflict。
- Provider 在 name／major／providerID 下唯一，可有多个不同来源；重叠所有者前缀也不能覆盖同一 providerID，返回 provider-conflict。
- 同一 name／major 不同时使用 Service 和 Provider，冲突返回 kind-conflict；不按最后加载者覆盖。不同 major 可独立注册。
- 相同 owner、providerID、版本及同一方法函数重复注册返回同一 ref，不重复通知；定义改变返回 definition-changed，须先注销再注册。
- providerID 由来源保持稳定，registrationRef 仅表示本次运行连接，不保存进业务数据库。sourceEpoch／业务 revision 仍归业务，不由 Core 生成。

## 生命周期与查询流程

继续使用 `BUSINESS_CONTRACT_REGISTERED(descriptor)`、`BUSINESS_CONTRACT_UNREGISTERED(descriptor,reason)`、`BUSINESS_CONTRACT_CHANGED(descriptor,change)`。kind 在描述符内区分机制，业务 epoch、revision、原因与影响范围在 change 值表内。

消费者先订阅，再 List 当前来源；REGISTERED 表示可以发现，不保证业务数据已采集。CHANGED 只是结果失效通知，消费者合并请求后查询。注销移除描述符并使缓存失效；晚注册与重注册重新发现，避免沿用旧 ref。不依赖广播顺序，查询和缓存重算不广播同一变化。

每个监听者获得独立副本，异常由现有 FireIsolated 隔离；清理使用 Events:Unregister(event,owner,callback)。同 owner／callback 登记幂等，新闭包仍须清理旧订阅。

纯值复制边界沿用 v9：无环表、字符串／数值键与基础值，拒绝函数等非值类型。此次没有新增有限数值、元表或深度／规模上限保证；涉及业务规模时按真实输入另评估。

## 验证与迁移

工作树已通过 ContractsSpec（90 项检查）、RuntimePerformanceSpec、CharacterNamesSpec（77 项）、MailProviderSpec、VaultIntegrationSpec、InboxReleaseSpec 和 Core TOC 45 个 Lua 文件的 5.1 语法检查。覆盖稳定枚举、次版本过滤、冲突／幂等、晚注册、注销重注册、旧令牌、输入输出副本、异常隔离、订阅清理及既有 Service 链。

同时修复旧名称测试将当前 API v10 当作未来版本拒绝的过期断言；现在显式接受 v10 与当前版本，拒绝 API_VERSION+1。

当前 YiboTodo 1.1.4 输出 `YiboTodo:profession-cooldown` 神纹布与 `YiboTodo:nomi` 诺米，TaskHub 0.2.0 通用枚举并消费于主页面、只读账号悬停、HUD 和登录提醒；双方检查 API v11 / business-providers:1。ActionIntegrationSpec 133 项及 O4 展示 86 项共 219 项通过，CAP-005 已同步。两个真实来源同属 Todo，其他业务插件按真实场景渐进接入。用户已确认 0.1.1 主页面外观；来源切号、交付／重置与 O4 新行为仍待游戏验收，未构建或发布安装包。O4 的通用角色准入通知属于独立 [account-character-admission:1](API-v11-角色准入通知.md)，未改变本 Provider 契约。
