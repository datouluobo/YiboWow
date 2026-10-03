"""Stage 5 styled icon previews at real sizes, with Builds as quality reference."""

from io import BytesIO
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
SVG = OUT / "YiboCraftingIcon-A-styled.svg"
BUILDS = Path(__file__).resolve().parents[4] / "YiboBuilds" / "Media"


def font(size):
    for name in ("msyh.ttc", "Microsoft YaHei.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def render(size):
    png = cairosvg.svg2png(url=str(SVG), output_width=size, output_height=size)
    im = Image.open(BytesIO(png)).convert("RGBA")
    im.save(OUT / f"YiboCraftingIcon-A-styled-{size}.png")
    return im


icons = {s: render(s) for s in (24, 32, 64)}
builds = {s: Image.open(BUILDS / f"YiboBuildsIcon-v1-{s}.png").convert("RGBA") for s in (24, 32, 64)}

sheet = Image.new("RGB", (880, 575), (20, 27, 31))
d = ImageDraw.Draw(sheet)
title, label, small = font(22), font(17), font(14)
d.text((24, 17), "YiboCrafting · 阶段 5 风格化实尺寸预览", font=title, fill=(239, 245, 244))
d.text((24, 51), "A 骨架 · 90% 书册 · 青绿系列外框 + 暖金配方书页", font=label, fill=(174, 198, 198))

for y, caption, bg in ((91, "WoW 深色 UI", (35, 42, 41)), (229, "浅色背景检查", (203, 206, 193))):
    d.rounded_rectangle((24, y, 856, y + 121), 9, fill=bg, outline=(91, 110, 109), width=2)
    fg = (231, 237, 232) if y == 91 else (34, 48, 50)
    d.text((42, y + 13), caption, font=label, fill=fg)
    d.text((215, y + 13), "Crafting", font=label, fill=fg)
    d.text((555, y + 13), "Builds 参照", font=label, fill=fg)
    for x, size in ((285, 24), (352, 32), (432, 64)):
        sheet.paste(icons[size], (x, y + 47), icons[size])
    for x, size in ((625, 24), (692, 32), (772, 64)):
        sheet.paste(builds[size], (x, y + 47), builds[size])

d.rounded_rectangle((24, 371, 856, 548), 9, fill=(30, 38, 40), outline=(91, 110, 109), width=2)
d.text((42, 383), "实际尺寸对照", font=label, fill=(231, 237, 232))
for x, size in ((268, 24), (360, 32), (468, 64)):
    sheet.paste(icons[size], (x, 424), icons[size])
    d.text((x - 5, 509), f"{size}px", font=small, fill=(176, 197, 198))
d.text((52, 435), "YiboCrafting", font=label, fill=(231, 237, 232))

sheet.save(OUT / "YiboCrafting-stage5-styled-preview.png")
print(OUT / "YiboCrafting-stage5-styled-preview.png")
