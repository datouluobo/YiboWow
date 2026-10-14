# Yibo 系列 Logo 资源

状态：已完成。2026-10-14 已按确认清单整理 15 个插件的资源。

当前 Logo、图标及已确认母版统一放在各插件 `Media/` 根目录，使用稳定文件名；历史使用版本位于各自 `Media/v1/`、`v2/` 等目录，原始路径见各目录 `Archive.json`。正式 Lua、TOC、README 与打包脚本同步使用当前路径。

本目录保留已确认总览 `ApprovedOverview.png`、实际尺寸预览 `NativeSizePreview.png`、导出清单 `Manifest.json` 和验证结果 `Validation.md`。正式母版以各插件 `Media/<Addon>Icon-master.png` 为准。

PNG：16/24/32/64/128/512/1024；TGA：16/32/64/128/512/1024；默认 PNG 为128px、默认游戏 TGA 为64px。512/1024 展示图由312px位图母版插值导出。

导出：`python Tools/Export-YiboIcons.py`；校验：`python Tools/Check-YiboIconAssets.py`。这两个工具不会重建已清理的过渡图，也不会修改历史版本。

整理清单与执行记录位于 `_NonRelease/LogoOrganization-20261014/`。
