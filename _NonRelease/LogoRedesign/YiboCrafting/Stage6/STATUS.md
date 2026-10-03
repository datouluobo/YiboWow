# YiboCrafting Logo：阶段 6 像素级修整

> 状态：阶段 6 — 像素级修整（已确认）。用户以“阶段 7”批准新版 24/32px 像素稿，进入最终导出。

从阶段 5 已确认的 A「炭灰内底 × 黄色书边」、两块纯色书页、贴合正六边形外框与 90% 书册骨架生成独立的 24/32px 像素修整稿。逐像素检查外框、书页中缝、上下尖角、半透明边缘和暗色 UI 对比；清除 Alpha 低于 24 的极淡边缘像素（24px 为 12 个，32px 为 14 个），把 Alpha 250–254 的近不透明像素归一为 255（24px 为 20 个，32px 为 2 个）。保留主体轮廓与书页结构。

`YiboCrafting-stage6-pixel-final-preview.png` 展示 24/32/64px 原尺寸及放大像素检查；`YiboCrafting-stage6-wow-ui-preview.png` 把修整版放回 Broker、小地图与紧凑列表。64px 延续同骨架风格化稿。检查结果：24/32px 均为 RGBA，四角 Alpha 为 0，已无 Alpha 低于 24 的残留像素；暗色 UI 中书页、中缝和六边形外框保持可辨。

用户已认可此前 24/32px 小图的配色和可读性，但新要求将书册横向加宽 3% 应用于全部尺寸。待阶段 5 全尺寸预览确认后，重新修整 24/32px 并复核 64px 边缘，再进入阶段 7 更新 PNG、TGA 与 SVG master。正式资源目前仍为此前确认的版本。

## 2026-09-29：新版材质的像素级终稿候选

阶段 5 的 `YiboCraftingIcon-wow-material-small-v1.svg` 已获用户确认。`PolishWowMaterial.py` 从其 24/32px 草稿生成独立的 `YiboCraftingIcon-wow-material-pixel-v1-24.png` 和 `YiboCraftingIcon-wow-material-pixel-v1-32.png`；64px 使用同阶段的大图材质骨架。`YiboCrafting-stage6-wow-material-pixel-preview.png` 同时展示深/浅界面原尺寸和逐像素放大检查；`YiboCrafting-stage6-wow-material-ui-preview.png` 展示 Broker、小地图按钮和紧凑列表。

24px 清除 12 个 Alpha 低于 24 的极淡边缘像素，归一 20 个 Alpha 250–254 的近不透明像素；32px 分别处理 14 个和 2 个。两图四角 Alpha 为 0，不再有 Alpha 1–23 的残留像素，且各自只有一个连通的非透明主体（24px 为 408 像素，32px 为 696 像素）。非透明包围框保持 `22×24px` 与 `28×32px`，书页、中央书脊和青绿六边形在实际尺寸及 WoW UI 模拟里仍可辨。

用户已批准阶段 6 像素级终稿，进入阶段 7 导出 PNG/TGA、更新 SVG master 与正式插件引用。
