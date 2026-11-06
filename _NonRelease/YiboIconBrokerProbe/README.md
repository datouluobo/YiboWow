# Yibo 图标客户端探针

探针代码保留在本目录，游戏中的同名目录联接已移除。探针默认关闭，不覆盖正式插件入口；显式开启时读取各插件 `Media/<Addon>Icon-32.tga` 或 `Icon-64.tga`，不再自带纹理副本。

`/yig on` 开启，`/yig off` 还原，`/yig 32`、`/yig 64` 切换对照尺寸。运行前需将本目录以同名目录联接到客户端 `Interface/AddOns/`。

验证：在仓库根运行 `lua _NonRelease/YiboIconBrokerProbe/Smoke.lua`。

此前的导出/预览脚本与记录保留为历史工作记录；其过渡图像已按确认清单清理，不作为当前制作入口。当前正式导出与校验使用 `Tools/Export-YiboIcons.py` 和 `Tools/Check-YiboIconAssets.py`。客户端验证 JPG 截图保留。
