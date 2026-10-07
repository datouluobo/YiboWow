# API v8：批量物品确认

源码版本 Core 1.7.1，能力 `item-picker:2`，尚未发布。复用 `Core:CreateItemPicker(parent, config)`；旧调用仍按 [API v7](API-v7-物品选择与基础输入.md) 执行单物品操作。

## 配置与职责

- `multiple=true`：输入支持 `;`、`,` 及中文分隔符；合法物品链接内的分隔符保留。空项目或解析失败会提示项目序号，名称多个候选时要求使用 ID／链接。按 ID 去重并保持输入顺序。
- 批量模式下，`OnSelected`、操作的 `Validate`／`Execute`／`Confirm` 收到物品信息数组；单物品模式继续收到单个信息对象。业务在一次 Execute 中提交整批结果，负责事务与业务校验。
- `retainInput=true`：成功后保留已确认输入；默认仍清空输入。批量确认成功解析后将输入规范为分号分隔的 ID。业务不覆写 Finish。
- `dropMode` 与 `multiple=true` 同用时，拖放把新 ID 追加到当前输入，再确认整批；只读取光标身份，不执行背包或邮件操作。1024 字符输入上限。
- Core 负责解析、逐项加载、失败与重试、取消和控件生命周期；业务负责规则所有权、冲突检查、保存和匹配。整批加载成功前不调用 Execute；失败保留查询，重试仍是显式操作。
- 输入变化、隐藏、切换和解绑取消整批未完成请求。旧回调不得提交；重复确认受 busy 保护。

YiboMail 的指定规则控件已接入这两个配置；分类排除与全局黑名单继续采用单物品模式。Mail 检查 API v8、名称能力和 `item-picker:2`，缺失时提示升级并停止初始化；不提供本地兼容实现。

## 验证

`lua YiboCurrency/_NonRelease/Tests/CoreItemControlsSpec.lua` 覆盖默认单物品控件回归、批量分隔／链接／去重、连续拖放、异步成功／失败与旧回调取消。`lua YiboMail/_NonRelease/Tests/RuleSendUISpec.lua` 核对实际确认按钮、保存／重开、连续拖放与未确认输入保护。`InboxReleaseSpec` 覆盖最低版本与缺失能力停止行为；游戏内控件尚待验收。

接入与后续迁移见台账 CAP-003；有真实批量录入需求时采用该配置，业务数据仍由各插件保存。
