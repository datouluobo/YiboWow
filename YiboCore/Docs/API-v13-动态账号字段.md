# API13：动态账号字段

2026-10-15，Core 1.12.4 工作树；能力 `account-dynamic-fields:1`。业务插件初始化须检查 API13、能力版本及实际方法。已接入 YiboCurrency 0.10.0；客户端待验收。

## 需求与职责

自定义货币可在运行时增删，Core 的统一显示与入口设置需要立即获得完整的主表／悬停选项。Core 提供通用字段定义读取，不查询具体插件、目录或 SavedVariables；业务提供稳定字段 ID、会话语言标签与默认值。无需新增 Service 或业务分支。

`Core.AccountView:RegisterPage(owner, definition)` 新增可选回调：

```lua
GetFieldDefinitions = function()
    return { { id = "item:123", title = "Token", group = "Custom", defaultVisible = true } }
end
```

回调在字段读取／设置页刷新时调用，必须是只读操作，不触发采集、注册或刷新；返回顺序即选项顺序。每项 id 为非空稳定字符串，title 为字符串；group、defaultVisible、preview 等沿用静态 fields 语义。字段 ID 不随语言变化，group 只参与显示。返回值为连续数组，不允许重复 ID、非数组属性或空洞。

`Core.AccountView:GetFieldDefinitions(pageID)` 返回字段定义的深拷贝。无动态回调时沿用原 `page.fields`；动态回调存在时，其结果完整替代静态 fields。未注册页面返回空数组；回调抛错返回 `{}, "field-definitions-error"`，无效结果返回 `{}, "invalid-field-definitions"`。失败不覆盖保存的显示选择，不静默退回过时的静态目录。

Core 的 `GetFieldVisible`、`GetVisibleFields` 和统一显示／悬停设置均通过本方法读取。显示选择仍由 Core AccountView 保存；默认值只在 Core 没有显式选择时生效。已移除字段的保存偏好不由 Core 自动清除，业务需要重置时可通过既有 `SetFieldVisible` 指定下一次出现的默认选择。

悬停继续使用既有 `GetPreviewFields` / `SetPreviewFieldVisible`；业务保存 `settings.previewColumns`，读取时返回副本。分组菜单另要求 `account-preview-field-groups:1`。动态目录变更由业务调用既有 `NotifyPageChanged`，设置页再次打开或刷新时重新读取目录。

## 兼容与验证

现有静态字段注册不变，不要求其它插件集中迁移。Currency 使用稳定 money / currency:ID / item:ID 字段，旧 visible 作为默认值种子，Core 显式选择优先；monitored 一次性导入 previewColumns，显式 false 与用户修改保留。

Currency API13Spec 四种客户端／手动语言组合各37项检查通过：实际 Core 字段读取、静态消费者兼容、增删自定义项、副本隔离、错误回调、旧API／缺能力停止、名称和主表／悬停一致性。EntryBarSpec 1133项通过。界面测量使用模拟帧，不代表真实游戏字体、菜单和屏幕边界已验收。
