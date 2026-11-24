# Core 账号主窗口布局验证

从仓库根目录运行 `lua _NonRelease/CoreEnglishLayout/Spec.lua`，检查三目标双语固定外框、预览恢复、导航与设置内容、滚动回退和小屏安全范围。

运行 `lua _NonRelease/CoreEnglishLayout/WorkspaceReplay.lua`，使用实际 Core 和业务页面回放已注册主窗口、设置工作台以及 MoP 装备、邮件、行动中心和待办的窄布局。Frame 和字体测量使用离线模拟。

## 2026-11-05 英文档案与导航边界历史验证

生产变更：AccountView导航列表复用、CharacterArchive最低内容宽度。13组源码回归通过；实际解包附加专项见Package-Checks-20261105.json。公开文档在候选冻结后补充了当前候选路径和相对链接，运行字节已逐项核对一致；最终发行重新构建记录完整快照。客户端绘制待用户reload。
