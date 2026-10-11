# API v11：视图可用高度

2026-10-09，Core 1.10.0 / API v11 工作树，未发布。能力 `account-surface-budget:1` 在 AccountView 加载后注册，是兼容现有页面的增量。

## 职责与契约

Core 负责窗口壳、屏幕安全区及入口定位；业务负责在可用空间内选择详细或压缩布局。真实需求来自行动中心密集悬停：先压缩行，再按实际行数申请高度，避免申请全部邮件明细高度后留下空白。

调用页面 `GetSurfaceMetrics(context)` 或既有 `GetHoverMetrics(context)` 前，Core 提供正数 `context.surfaceAvailableHeight`，单位为 UIParent 布局坐标：

- 主页面：屏幕安全高度减去标题栏及边框。
- 悬停：安全区域内、入口上方或下方可用高度减去标题栏及边框；无入口时使用完整安全区。原位重建沿用可夹取的完整安全区。

它是测量时的内容高度上限，不是最终 Frame 高度；业务返回自己的 naturalContentHeight，Core 保留原有最小尺寸、安全夹取与定位规则。字段与已有 surfaceAvailableWidth 并存；现有宽度语义不变。最终渲染读取实际 Frame 尺寸，不以预算字段假定窗口已经调整。不可测量的极端小空间钳为 1；业务应减少展示并明确剩余内容。

本能力不注册新服务、不读取业务数据、不发业务通知。页面原有失败隔离保持不变。依赖此预算的消费者须检查 API v11 与 account-surface-budget:1；不足时提示升级并停止依赖该能力的初始化，不复制屏幕几何或 Core 私有方法作回退。

## 接入与验证

- YiboTaskHub 0.2.1：Preview.GetMetrics 与 Refresh 共用 Plan，按预算先决定压缩，再申请已显示行的高度；CoreIntegration 显式检查新能力。
- SurfacesSpec 95 项包含真实 AccountView 主窗口／悬停预算、入口空间、压缩后窗口尺寸、缺失能力停止及原有准入／字段路径。旧 Service、Provider、名称及性能回归通过。
- 用户 0.2.0 截图证实修复前存在悬停空白；0.2.1 游戏内仍待核对。其他页面未触及，不要求主动迁移；今后需要按可用高度改变布局时复用本契约。
