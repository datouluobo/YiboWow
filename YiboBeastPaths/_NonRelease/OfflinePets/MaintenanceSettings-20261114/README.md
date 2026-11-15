# 维护设置迁移：2026-11-14 实机证据

结论和限制见 [实施与验收记录](../../../Docs/1.9-维护面板迁入设置页-20261114.md)。本目录不打包进玩家安装包。

- `RuntimeHashes.json`：最终五个运行文件的 SHA256，Retail／Mists 源码联接使用同一组文件。截图不代替摘要核对。
- `Mists-calibrate/fusion/footprints/export/export-bottom.png`：首次迁移 UI 检查；当时尚未加入导出文本框的一行绑定修正，证明四页签与设置滚动布局，不作为最终导出交互证据。
- `Mists-final-reload.png`、`Mists-main-without-maintenance.png`：加入导出绑定后重载最终代码，验证设置入口及主页面；前者可见 `YiboErrors 0`，后者保留已有历史观察。
- `Mists-restored-addon-state.png`：原生角色插件列表确认 YBP 恢复为禁用；退出后另核对 `AddOns.txt` 为 disabled，没有回写历史 WTF 备份。
- `Mists-error-summary.txt`：正常注销后的错误库摘要。1 条 other 为尝试脚本退出触发 ForceTaint 的保护拦截，无 YBP 文件栈；不是迁移页面错误。`InspectErrors.lua` 只读本地错误库并输出脱敏计数，不输出账号、角色或 locals。
- `Retail-calibrate/fusion/footprints/export-current/export-footprints/export-select-all/export-bottom.png`：最终代码的四页签、旧路线参数、类别刷新、实际全选与底部可达。
- `Retail-main-without-maintenance.png`、`Retail-final-settings.png`：`/ybp stable` 主页面及其设置按钮的目的地，设置导航只有一个 YBP 项。

截图来自 computer-use 的实际客户端窗口，未重绘。未测试路线参数编辑或破坏性按钮，没有执行释放宠物、路线清空或导入存档；示意方案中的新兽栏布局未接入。
