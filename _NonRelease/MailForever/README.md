# Mail Forever 模拟验证

`lua _NonRelease/MailForever/Smoke.lua` 通过Core真实两端清单加载Mail，包含69项启动、采集、存档、窗口与Vault公开契约联动检查。全部数据只在隔离Lua环境内，未写入游戏WTF。

`BaselineRunner.lua` 为诊断中间文件：从当前文件逆向剥离本轮Namespace／Bootstrap／Store／Items改动，在内存dofile路由中重建任务前态，其余工作区保持当前状态。它不是完整历史仓库；[LegacyTestComparison.json](LegacyTestComparison.json)记录旧测试两处相同失败，不能计作全量通过。

实现、契约与待实机边界见[验收记录](../../YiboMail/Docs/Forever-最小适配与验收.md)。
