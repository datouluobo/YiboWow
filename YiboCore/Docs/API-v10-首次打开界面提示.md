# API v10：首次打开界面提示

2026-10-08 工作树：Core 1.9.0 / API v10，尚未发布、游戏内待验收。

## 用途与范围

`account-view:2` 为账号页面提供一次性短时引导泡泡。业务页面通过注册定义中的可选 `firstUseTip` 提供标题和文本；Core 只负责显示与记录是否已显示，不解释业务内容，也不迁移业务数据。

```lua
Core.AccountView:RegisterPage("YiboExample", {
    id = "example",
    title = "示例页面",
    firstUseTip = {
        title = "页面操作",
        lines = { "第一次打开页面时显示的简短提示。" },
    },
})
```

主账号视图首次打开该页面时，提示锚定在窗口标题栏下方显示 6 秒。悬停预览不触发提示。Core 在成功显示后将 `settings.accountView.firstUseHints[pageID]` 标记为已显示；已显示的页面不再自动弹出。用户仍可在帮助页查看完整说明。

缺少 `firstUseTip` 时不显示提示；没有 GameTooltip 或 Core 数据库不可用时不写入已显示标记。文本应简短，只解释低频操作；必需状态、风险、输入约束和数据时效说明仍保留在原界面。

## 最低版本与接入

依赖本行为的插件须在初始化时检查 YiboCore API v10 及 `account-view:2`，并在 `RegisterAddon` 声明 `requiredAPI = 10`。旧 Core 不兼容时提示升级并停止依赖该页面契约的初始化。

本轮接入：

- `YiboBuilds`：装备模型旋转与缩放。
- `YiboReputation`：矩阵星标和设置页监控列表。
- `YiboTodo`：设置开关与矩阵列的关系。
- Core 概览：业务页入口用途。

对应原文与键鼠操作保存在 Core 帮助页。空状态中的待办同步说明、邮件寄送安全回退、过滤规则语义和数据可靠性说明继续常显。

## 验证

本轮静态核对 `Theme:ShowTooltip`、`Theme:ShowFirstUseTooltip`、`AccountView:ShowPage` 与四个页面定义；游戏内仍需确认每个页面只提示一次、预览不触发、6 秒后关闭和帮助页内容可读。
