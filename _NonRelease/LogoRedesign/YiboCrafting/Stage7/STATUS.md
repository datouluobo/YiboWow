# YiboCrafting Logo：阶段 7 最终导出

> 状态：阶段 7 — 最终导出（已完成）。新版材质与 3% 加宽骨架已作为 v2 导出并接入；此前 v1 资源保留。

## 历史版本：v1

最终版本：`YiboCraftingIcon-v1`。选定 D「炭灰内底 × 蓝钢书册封边」、90% 书册、暖金书页和青绿系列外框。

正式资源位于 `YiboCrafting/Media/`：24、32、64、128、512、1024px RGBA PNG，128px RGBA TGA，以及可编辑的 32px SVG master。24/32px PNG 直接来自用户批准的阶段 6 像素修整稿；64px 及以上从同一 D 版 SVG master 分尺寸渲染。128px TGA 与 128px PNG 像素完全一致。

导出脚本逐个校验 PNG 尺寸、RGBA 模式和四角透明；校验 TGA 尺寸、RGBA 模式及与 PNG 的像素一致性；SVG master 保留 `viewBox="0 0 32 32"`。已目视检查 24px 小图及 512px 展示图。`YiboCrafting.toc` 已新增 IconTexture 引用；README 已展示 128px 图标。尚未在实际游戏客户端加载验收。

## 2026-09-29：v2 最终导出与接入

用户以“阶段 7”批准阶段 6 像素级终稿。新版本为 `YiboCraftingIcon-v2`，保留已确认的全尺寸 3% 加宽书册、同心贴合正六边形、炭灰内底、青绿系列线和暖金书页，并使用已确认的新版材质与光照。

`ExportLogoV2.py` 将阶段 6 逐像素修整的 24/32px PNG 原样复制到 `YiboCrafting/Media/`；64/128/512/1024px PNG 从阶段 5 大图 SVG 分尺寸渲染。另提供 128px RGBA TGA、可编辑的大图与小图 SVG master。所有 PNG 尺寸、RGBA 模式与透明四角通过检查；24/32px 文件与批准稿逐像素一致；TGA 与 128px PNG 逐像素一致。已目视复核正式目录的 24px 与 512px 图片。

`YiboCrafting.toc` 的 `IconTexture` 与 `YiboCrafting/README.md` 图片引用已指向 v2。v1 文件仍在原路径。WoW 客户端实际加载尚未执行；Broker、小地图与紧凑列表此前只在阶段 6 模拟 UI 中验证。
