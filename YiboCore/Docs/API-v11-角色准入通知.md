# API v11：角色准入变化通知

2026-10-09，未发布工作树 Core 1.10.0 / API v11。O4 行动中心常驻面板是首个真实消费者；原窗口刷新行为保持兼容。本项不涉及专业、任务或离线业务状态。

## 职责和最低要求

Core 拥有账号隐藏角色与默认页面等级筛选，修改这些偏好后发事实通知，使窗口外的消费者及时重新读取角色准入。消费方检查 API v11、`account-character-admission:1` 与所需 AccountView 公开方法；能力缺失提示升级并停止相应初始化，不使用私有函数或轮询回退。

能力在 AccountView 实际加载后注册；通知经现有 Events:FireIsolated 分发，每个监听者得到负载副本，异常隔离。它是本次未发布 API v11 的非破坏性增量，不改变旧版 account-view:2 的方法或事件意义。

## 契约

`ACCOUNT_VIEW_CHARACTERS_CHANGED(change)`：Core 的相关角色准入偏好已提交，负载为普通值表。

| reason | 可选范围 | 发出时机 |
| --- | --- | --- |
| visibility | characterID | SetCharacterHidden 实际改变隐藏偏好后 |
| page-filter | pageID | Core 为页面提供的默认 characterFilter.SetExpression 校验并提交新表达式后 |

设置相同值不发变化通知。错误等级表达式不提交、不发变化通知。通知不携带角色数据库，也不指令某个业务执行私有方法；消费者在下一帧合并刷新，通过 `AccountView:GetVisibleCharacters()` 和页面公开的 `characterFilter.GetExpression()` 重新读取。

业务自行保存的 characterFilter 不由 Core 代为判定或发出此事实；本次真实消费页面 taskhub 使用 Core 默认筛选。其他页面的业务筛选仍按其自身刷新机制处理。角色短名的既有 CHARACTER_DISPLAY_UPDATED 独立保留；角色排序不改变工作资格，本次未新增排序事件。

来源注销与重载不保存订阅；消费者用 Events:Unregister(event, owner, callback) 清理。注册订阅须幂等，不能以查询或展示刷新再次发布准入变化。

## 接入与验证

- Core：AccountView 提交隐藏／默认页面筛选偏好后通知，保持原 RefreshPage／NotifyPageChanged。
- YiboTaskHub 0.2.0：Displays 订阅准入及既有名称变化，Presentation 当前角色投影复用 Core 隐藏和等级条件，忽略主页面服务器／来源选择；隐藏当前角色后关闭面板。
- SurfacesSpec 新增 86 项展示检查包含实际 AccountView 能力注册、隐藏变化、相同／错误筛选不广播、默认页面筛选、面板关闭和缺失能力停止；并复用原集成 133 项。Core ContractsSpec（90）、CharacterNamesSpec（77）、RuntimePerformanceSpec 回归通过。
- 客户端新增面板及设置交互待验收，未发布。后续外部面板需要同样准入事实时复用该事件，不读取 Core 内部设置表。
