# API v9：业务服务与刷新

2026-10-08 工作树：Core 1.8.0 / API v9。尚未发布、游戏内待验收。

## 最小边界

真实需求是邮件与仓库共用邮箱采集，以及货币读取仓库库存。Core 只负责版本化连接、调用隔离和生命周期，数据、SavedVariables、采集及业务时效仍由业务插件所有。公开入口为 `Core.Contracts`，能力 `business-services:1`，当前只支持单一 Service；行动中心草案中的 Provider、List 和 `business-contracts:1` 尚未实现。

依赖本能力的 Mail、Vault、Currency 检查 API v9 与能力版本；旧 Core 会提示升级并停止初始化。业务提供方缺失、尚未注册或主版本不兼容时只失去相应增强，基础功能继续；不得直接访问其它业务全局对象或存档。Crafting 本轮只接入现有 `ItemResolver`，最低 API v7 / `item-resolver:1`。

## 公开接口

| 方法 | 输入与输出 |
| --- | --- |
| `Register(owner, definition)` | owner 必须已在 Core 注册；definition 包含 kind=`service`、name、owner 前缀的 providerID、version={major,minor}、methods。返回 registrationRef 或 nil,error |
| `Resolve(name, {major,minMinor})` | 主版本严格匹配，次版本至少 minMinor（默认 0）；返回描述符副本或 nil,error。描述符含 name/kind/owner/providerID/version/registrationRef，不暴露实现 |
| `Call(caller, descriptor, method, request)` | caller 必须已注册；校验当前注册令牌；提供方方法收到 request 副本和调用上下文，返回 result,code,details 的独立副本 |
| `NotifyChanged(owner, ref, change)` | 只有所有者可发变更；change 是纯值数据；先完成业务提交再通知 |
| `Unregister(owner, ref)` | 注销使旧描述符立即失效，发送注销事件；消费方下次调用重新发现 |

相同 owner/providerID/版本/方法重复注册返回同一 ref，不重复通知。相同服务名与主版本只能有一个提供方；冲突返回 `service-conflict`，修改定义需先注销。调用失效返回 `unregistered`；未注册调用方返回 `caller-unregistered`；未提供方法返回 `method-unavailable`；提供方异常或非纯值输出返回 `provider-error`。输入输出只允许 nil、布尔、数值、字符串及字符串/数值键的无环表，拒绝函数、对象和内部引用外泄。

Core.Events 发送 `BUSINESS_CONTRACT_REGISTERED(descriptor)`、`BUSINESS_CONTRACT_UNREGISTERED(descriptor,reason)`、`BUSINESS_CONTRACT_CHANGED(descriptor,change)`。每个回调收到独立副本，异常不阻止其他订阅者。订阅使用 `Register(event,owner,callback)`，同 owner/同 callback 幂等；清理用 `Unregister(event,owner,callback)`。消费方不得依赖回调顺序。

## 本轮业务契约

| 能力 | 所有者 / 提供者 | 消费方 | 方法 |
| --- | --- | --- | --- |
| `mail.items` v1.0 | YiboMail / `YiboMail:inbox` | YiboVault | GetState({characterID})、GetByCharacter({characterID,options})、GetRevision() |
| `vault.items` v1.0 | YiboVault / `YiboVault:inventory` | YiboCurrency | Query(options)、GetPersonalCounts(options)、HasCapability({name,minimumVersion}) |

角色使用 Core characterID，账号范围和过滤复用原业务 Items API；Mail 方法返回语义见 Mail 的 API 文档，Vault 查询与 personal-counts 语义见 Vault 文档。本次只注册已有方法，不扩大库存来源或引入第二份权威缓存。变更负载保留业务 eventName、characterID、revision、来源与涉及 itemID；Vault 只对其有效投影视图改变发布变更，避免通知循环。

Mail 通过 observedAt、status、lastScanStatus、revision 表达就绪与时效。已注册但未完成扫描时 Vault 等待 Mail 采集，可读自身此前缓存，但不开始第二轮采集，也不认定邮箱为空。成功快照关闭邮箱后变为 stale，仍可作为明确的上次观测；失败保留 Mail 的最后数据及 error 覆盖，不切换到另一份更老缓存。Tooltip 对已完成且上次结果 known/known-empty/partial 的关闭邮箱保留可见数量；error 和没有成功观测的 stale 继续显示未知。partial 仅是可见范围下限，不冒充完整邮箱。

Mail 缺失、禁用、注销或主版本不兼容时，Vault 独立采集继续可用；晚注册立即切换来源、取消待执行本地扫描并重新投影。Currency 每次能力查询重新发现 Vault，缺失或库存子能力不足时使用原有 Core 快照。返回副本防止消费方修改所有者数据。

## 刷新与物品加载

`AccountView:NotifyPageChanged(pageID)` 改为下一帧合并同页面突发通知，执行时复核窗口可见性及当前页面/悬停页面。业务要求立即显示的交互仍可调用原有 `RefreshPage`，战斗保护保留在原刷新路径。

`ItemResolver:Request` 沿用 v7 接口及超时/显式重试语义。同一 itemID 只有一次底层加载，等待者共享结果；轮询按 0.1 秒检查，仅有 pending 时启用，清空时停止。等待者异常独立处理。Mail 附件、Vault 格子、Crafting 产出名称本轮接入；业务规则、配方和物品身份判断仍由原插件负责。

## 验证与迁移

`RuntimePerformanceSpec` 覆盖冲突/幂等/版本/副本/异常/注销重注册，页面突发、隐藏、切页与悬停，物品共享加载、空闲和超时，副本响应不回发请求，货币增量不丢失与装备稳定确认。`MailProviderSpec` 覆盖提供方缺失、不兼容、晚注册、注销、错误、partial/stale/empty 和查询不触发重复扫描；`VaultIntegrationSpec` 验证货币结果、来源隔离及能力缺失回退；`TooltipSpec` 验证关闭邮箱保留数量和错误时未知。Mail/Currency 的启动测试覆盖旧 Core 的升级提示与停止。

迁移登记于 CAP-003、CAP-005。未涉及的旧模块按后续真实协作需求迁移；行动中心不得把本轮最小 Service 能力当成已实现的完整连接草案。游戏内仍需核对：邮箱打开/关闭/收附件，Tooltip 与主视图数量和 partial 提示一致；战斗切页与关闭窗口；锁定响应和双天赋切换。没有实测 FPS、CPU 或通讯量降幅。
