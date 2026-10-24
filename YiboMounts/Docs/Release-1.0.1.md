# YiboMounts 1.0.1

目标：Mists / MoP Classic 5.5.4。日期：2026-10-25。

减益光环的 Tooltip 跳过坐骑来源追加。增益光环、鼠标指向单位、坐骑聊天链接和坐骑面板继续显示坐骑来源。

光环解析和增益入口适配归入 `Mists/AuraTooltip.lua`，加载清单同步更新。读取失败时保持原生提示，避免将时间等数值误识别为坐骑法术。

Lua 5.1 冒烟回归和正式加载文件语法检查通过；减益及组合过滤器覆盖读取前拒绝测试。实机减益／正常坐骑回归、重载及完整退出恢复仍待完成。离线包检查不代替客户端验收，生成安装包不代表已上传或发布。

安装目录与 SavedVariables 身份保持 `YiboMounts`、`YiboMountsDB` 和 `YiboMountsDiagnostics`。手动安装使用 Mists CurseForge ZIP，覆盖同名目录并保留 WTF 存档；GitHub ZIP 用于源码查阅。一个安装目录使用一个更新管理来源，整合包与单体同时管理尚未验证。

详细行为、迁移与验收范围见 [减益提示修复记录](Mists-万圣节减益提示误报修复.md)。
