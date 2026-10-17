# YiboSuite 发布 Logo

MoP 版已于 2026-10-18 获用户批准定稿，资源位于 `Mists/`。

- `YiboSuite-Mists-Logo-512.png`：透明发布 Logo，供 CF 项目头像等使用。
- `YiboSuite-Mists-Logo-1024.png`：透明展示版本。
- `YiboSuite-Mists-Logo-master.svg`：自包含母版，文字使用矢量轮廓。

统一模板由 `../Design/Client-Themes.psd1` 与 `../Design/Build-LogoPreview.ps1` 管理。Core 主体固定；标签按各客户端主题色填充，含描边的右缘与底缘对齐 Core 外框可见包围盒，标签向左展开。MoP 为翡翠绿，TBC 为邪能绿，Era 为古铜色，Retail 为金色。

在仓库根目录使用 PowerShell 7.2+：

```powershell
pwsh -File YiboSuite/Tools/Export-SuiteLogo.ps1 -Target Mists -OutputRoot <新输出目录>
```

需要 Windows System.Drawing / Arial、Python CairoSVG 和 Pillow。导出器使用共用模板生成 SVG，再栅格化为 512/1024 PNG，保留透明通道；已存在的同名资源会阻止覆盖。其它客户端暂只保留模板与设计预览，不因配置存在而自动发布或导出。

这些资源属于 Suite 发布资料，当前未上传 CF，也未写入既有 v1.0.0 ZIP。
