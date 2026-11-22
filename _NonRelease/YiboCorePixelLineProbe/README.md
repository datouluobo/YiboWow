# YiboCorePixelLineProbe

非发布阶段 0 探针，用于验证 YiboCore `pixel-line:1`（API 14）在三端的前提条件。不依赖、不加载 YiboCore，只观察客户端本身；使用独立 SavedVariables `YiboCorePixelLineProbeDB`，不写业务存档。

- 目标清单：`_Mists`（50504）、`_Forever`（16001）、`_Mainline`（120105）；默认 `YiboCorePixelLineProbe.toc` 只输出缺目标提示。三端后缀选择沿用 YiboCore 已实测的规则，但本探针在各端首次加载时仍须确认实际加载的是对应目标清单（聊天框应出现 `/ypx` 报告中的 Interface 与目标一致）。
- 命令：`/ypx`（已登记于 `Docs/Yibo系列插件命令清单.md`）。
- 联接：需要时以同名 Junction 联接到目标客户端 `Interface/AddOns/YiboCorePixelLineProbe`，来源为本目录。
  - 2026-11-21 MoP：`D:\Program\World of Warcraft\_classic_\Interface\AddOns\YiboCorePixelLineProbe` → `D:\Development\YiboWow\_NonRelease\YiboCorePixelLineProbe`，用途为阶段 0 Mists 采样；已运行，首组结果见 [Evidence-Mists-20261121.md](Evidence-Mists-20261121.md)。
  - 2026-11-21 Forever：`D:\Program\World of Warcraft Forever\World of Warcraft\_forever_\Interface\AddOns\YiboCorePixelLineProbe` → 本目录，已核对 Junction 目标，尚未运行。
  - 2026-11-21 Retail：`D:\Program\World of Warcraft\_retail_\Interface\AddOns\YiboCorePixelLineProbe` → 本目录，已核对 Junction 目标，尚未运行。两端 YiboCore 均为指向仓库源码的 Junction。

## 命令

| 命令 | 作用 |
| --- | --- |
| `/ypx` | 输出并保存一份报告：客户端 build、Interface、`GetPhysicalScreenSize` 是否存在及返回值、`GetScreenWidth/Height`、UIParent 有效缩放、`useUiScale`/`uiScale`、每 UI 单位像素数、1 像素对应 UI 单位、`PixelUtil`、`SetSnapToPixelGrid`、`SetTexelSnappingBias` 是否存在，以及自加载以来缩放事件次数。 |
| `/ypx show` | 显示／隐藏对照板：A/B 为现行 1 UI 单位线（整数与 +0.5 偏移），C/D 为按公式换算的 1 像素线，E 为关闭纹理吸附后的 1 像素线；F 为相邻四边 Backdrop（左 1 单位、右 1 像素），G 为只画需要边的单线边框。对照板随缩放事件即时重排。 |
| `/ypx events` | 列出本次加载后的 `UI_SCALE_CHANGED`、`DISPLAY_SIZE_CHANGED` 事件及当时的物理尺寸和缩放。 |
| `/ypx clear` | 清空已保存报告与事件计数。 |

## 测试清单（由用户手动执行）

每端、每种组合各执行一次 `/ypx`，并对 `/ypx show` 截取原尺寸截图：

1. 分辨率 `1280×720`、`1920×1080`、`2560×1440`；每档使用默认 UI 缩放，并另取一档较小缩放（例如 1440p 下 0.71）。
2. 对照板检查：C/D/E 每条线是否都恰好 1 像素且粗细一致；A/B 是否出现变淡、断线或 1/2 像素交替；F 左列相邻行之间是否为双线、右列是否仍为双线（两条 1 像素线）、G 是否全部为单线。
3. 打开对照板后，在游戏设置中修改 UI 缩放（不重载），再修改分辨率或窗口模式；随后执行 `/ypx events`，记录每次操作触发的事件名称与次数，并确认对照板线宽已随之更新。
4. 记录：客户端、build、分辨率、UI 缩放、截图文件名，以及报告中的 `1px = … UI units`。

## 判定

- 若某端 `GetPhysicalScreenSize` 不存在或返回非法值，Core 在该端回退为 1 UI 单位（状态 `unknown`），需在 Core 文档中登记该端吸附路径。
- 若 C/D 已稳定为 1 像素，Core 采用“按像素换算线宽与内缩”的路径；若 D 与 E 结果不同，记录纹理吸附对小数偏移的影响，再决定是否在 Core 中对线纹理关闭吸附。
- 缩放事件不触发的端，Core 依赖窗口重新显示时的刷新，须单独登记。
