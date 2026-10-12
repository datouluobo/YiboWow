# 行动中心：Todo 全量接入

日期：2026-10-09。状态：**代码与自动化已完成，客户端待验收**。Todo 1.2.0，未发布。

## 范围与所有权

需求：行动中心展示 YiboTodo 已有的全部适用监控任务。Todo 是业务数据、监控、资格、完成与重置规则的唯一所有者；Core 仅连接，TaskHub 使用既有通用消费和四个展示面。未修改 TaskHub 运行代码，不新增业务技术名分支。

| 来源 | 输出范围 | 身份与状态 |
| --- | --- | --- |
| `YiboTodo:profession-cooldown` | 全部 active、已监控且符合 Core 专业资格的冷却组，含各 MoP 冷却与旧版铭文研究 | 保持既有 Provider ID、角色＋组 itemKey 和持久 epoch；冷却就绪仍为准备动作，不能证明材料齐全 |
| `YiboTodo:nomi` | 已有诺米日常 | 保持原身份、资格、周期与状态 |
| `YiboTodo:activities` | 农场、各版本烹饪／珠宝／钓鱼日常、纳特三鱼、开放期暗月、布林顿；以当前 monitoringProjects 为准 | 角色项目使用角色＋活动 ID；账号项目使用 account＋活动 ID，独立 epoch／revision |

农场沿用原有一次操作的乐观投影。未观察的农场不凭空新增工作；来源完成的任务输出 completed，中心已有过滤将其移出待办。未确认的远端日常保持 unknown，不作为可做。候选目录和注册门槛保持来源原有规则，不将本轮接入视为新的客户端采集确认。

## 公开契约与生命周期

全部使用 `action.todo` v1.0 / `Query({scope={characterIDs={...}}})`。最低 Core API v11 / business-providers:1；版本不足提示升级并停止任务集成，Todo 原有 API v10 基础功能保持。重复角色去重，空范围返回空任务，无效请求拒绝；结果经复制返回，不暴露源数据库。

返回 Provider ID、sourceEpoch、revision、generatedAt、来源状态、逐角色 coverage 与 tasks。任务保留来源状态、观察时间、周期、下次变化、业务引用和打开 todo 页的动作；物品／纹理由来源快照提供。三来源拥有独立版本元数据，业务变化合并通知，注册幂等，注销清理排队生命周期。提供方缺失、晚注册或不兼容继续由 TaskHub 原有通用连接处理。

`SpecialActivity:GetProject` 在同一主视图项目上补充 scope、period、cycleKey、nextChangeAt、observedAt。每日活动沿用服务器日；暗月沿用来源 EventKey 的月份／周四周期，并在午夜重新核对窗口。账号完成时间来自原账号记录，逐角色观察时间来自对应周期的原记录。查询时间不伪装为观察时间。

布林顿使用 execution.mode=account、beneficiary.mode=account。同一请求只输出一条，candidateCharacterIDs 为请求内具备同一项目的角色；重复范围不重复候选。账号完成时，原模型完成者输出 completed，其他角色不适用；下一日原模型恢复可领取。中心统计一次，角色列表可按候选投影。

普通日常／特殊活动的 actionable 是来源模型按自身规则生成的可处理提醒，可没有现场观察时间；未知状态保留 partial。专业冷却继续采用较严格的观察有效性，未观察、冲突或跨重置保持未知／过期。适用范围内没有项目返回 known-empty，不将缺失的专业资格推断为可制作。

## 文件与验证

新增 `YiboTodo/ActionActivities.lua`，扩展 `ActionTodo.lua` 的多任务输出，复用其 Query、版本与缓存框架；注册与 TOC 增加真实来源。特殊活动元数据补充位于原业务 Provider。基础 API、Slash 与跨插件依赖方向不变。

`TodoSourcesSpec.lua` 使用真实 Core Contracts、Todo 目录／快照／Provider 和 TaskHub 消费链，177 项检查通过：全部适用专业组、监控及视图一致性、返回隔离、稳定查询、账号去重与候选范围、纳特交付、暗月关闭／周四周期、农场跨日、低版本停止及三来源注销／重注册。原 ActionIntegration 134、Surfaces 95、MailSource 80、Overview 50 项仍通过；合计 536 项。Todo 全部 10 个烟雾测试文件通过，修改运行文件 Lua 5.1 语法检查通过。

实际 diff 的 Core 公共能力审查：本轮继续使用 CAP-005 Provider 注册／通知与 Core 副本、角色目录及专业域；无新增 Core 公共能力，台账已更新本轮业务接入范围。其它公共能力未出现新接入变化。

## 客户端验收

TOC 新增加载文件，需完整退出游戏后重新进入。核对不同专业角色、监控全关／子项关闭、农场前日种植、纳特交付、账号布林顿完成后的多角色移除，以及暗月开放／关闭／周四恢复；同时对照 Todo 主视图、行动中心、悬停、面板与登录摘要。仍需核对离线角色、切号与重载，自动化不替代真实客户端验收。
