"""Render Stage 5 material study at actual icon sizes and on dark/light UI."""

from io import BytesIO
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw, ImageFont


OUT = Path(__file__).resolve().parent
SMALL = OUT / "YiboCraftingIcon-wow-material-small-v1.svg"
LARGE = OUT / "YiboCraftingIcon-wow-material-v1.svg"


def font(size):
    for name in ("msyh.ttc", "Microsoft YaHei.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def render(path, size):
    raw = cairosvg.svg2png(url=str(path), output_width=size, output_height=size)
    return Image.open(BytesIO(raw)).convert("RGBA")


icons = {}
for size in (24, 32, 64, 128, 512):
    source = SMALL if size <= 32 else LARGE
    icon = render(source, size)
    icon.save(OUT / f"YiboCraftingIcon-wow-material-v1-{size}.png")
    icons[size] = icon
    assert all(icon.getpixel(pt)[3] == 0 for pt in ((0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)))

sheet = Image.new("RGB", (1190, 875), (19, 27, 30))
d = ImageDraw.Draw(sheet)
title, body, tiny = font(24), font(17), font(14)
d.text((28, 14), "YiboCrafting · 阶段 5 材质返工", font=title, fill=(243, 246, 238))
d.text((28, 49), "保留 3% 加宽骨架；书页与金属使用左上主光、厚边和明暗切面。", font=body, fill=(182, 205, 201))

for x, label, bg, fg in (
    (26, "WoW 深色 UI · 原尺寸", (29, 38, 42), (232, 240, 236)),
    (600, "浅色背景 · 原尺寸", (210, 214, 208), (42, 54, 55)),
):
    d.rounded_rectangle((x, 91, x + 560, 264), 10, fill=bg, outline=(95, 111, 112), width=2)
    d.text((x + 17, 105), label, font=body, fill=fg)
    for dx, y, size in ((34, 165, 24), (125, 161, 32), (244, 144, 64)):
        icon = icons[size]
        sheet.paste(icon, (x + dx, y), icon)
        d.text((x + dx - 3, 221), f"{size}px", font=tiny, fill=fg)

d.rounded_rectangle((26, 284, 586, 855), 10, fill=(31, 40, 43), outline=(95, 111, 112), width=2)
d.rounded_rectangle((600, 284, 1164, 855), 10, fill=(31, 40, 43), outline=(95, 111, 112), width=2)
d.text((44, 300), "返工前 · 512px", font=body, fill=(188, 207, 206))
d.text((620, 300), "材质返工 · 512px", font=body, fill=(235, 241, 232))
previous = Image.open(OUT / "YiboCraftingIcon-large-refined-v3-512.png").convert("RGBA")
sheet.paste(previous, (50, 327), previous)
sheet.paste(icons[512], (626, 327), icons[512])

sheet.save(OUT / "YiboCrafting-stage5-wow-material-review.png")
print(OUT / "YiboCrafting-stage5-wow-material-review.png")
