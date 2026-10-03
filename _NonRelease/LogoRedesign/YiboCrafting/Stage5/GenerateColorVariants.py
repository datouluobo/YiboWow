"""Stage 5 color study: separate the hexagon field from the book cover edge."""

from io import BytesIO
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
BASE = (OUT / "YiboCraftingIcon-A-styled.svg").read_text(encoding="utf-8")


def font(size):
    for name in ("msyh.ttc", "Microsoft YaHei.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


# Hexagon top/bottom, book edge fill/stroke, center spine.
VARIANTS = [
    ("A", "夜蓝 × 铜棕", "#183748", "#0A1726", "#76503B", "#39231B", "#503529"),
    ("B", "深紫 × 青钢", "#29223E", "#110F25", "#4E8286", "#183B42", "#2B555C"),
    ("C", "墨绿 × 赤铜", "#1B3B34", "#0A1C1A", "#916143", "#45291E", "#65452E"),
    ("D", "炭灰 × 蓝钢", "#344044", "#121E25", "#4D7890", "#1D4053", "#315B70"),
]

sheet = Image.new("RGB", (940, 800), (20, 27, 31))
d = ImageDraw.Draw(sheet)
title, label, small = font(22), font(17), font(14)
d.text((23, 15), "YiboCrafting · 阶段 5 双色分离方案", font=title, fill=(240, 245, 243))
d.text((23, 49), "固定 90% 书册、暖金书页与青绿外框；仅调整六边形内底色和书册封边。", font=label, fill=(179, 200, 199))

replacements = ("#173E45", "#08191E", "#10272D", "#061B21", "#16343A")
for i, (code, name, bg_top, bg_bottom, book_edge, edge_shadow, spine) in enumerate(VARIANTS):
    svg = BASE
    for old, new in zip(replacements, (bg_top, bg_bottom, book_edge, edge_shadow, spine)):
        if svg.count(old) != 1:
            raise ValueError(f"Expected one {old} in base SVG, found {svg.count(old)}")
        svg = svg.replace(old, new)
    path = OUT / f"YiboCraftingIcon-color-{code.lower()}.svg"
    path.write_text(svg, encoding="utf-8")

    icons = {}
    for size in (24, 32, 64):
        png = cairosvg.svg2png(bytestring=svg.encode("utf-8"), output_width=size, output_height=size)
        icon = Image.open(BytesIO(png)).convert("RGBA")
        icon.save(OUT / f"YiboCraftingIcon-color-{code.lower()}-{size}.png")
        icons[size] = icon

    y = 86 + i * 175
    d.rounded_rectangle((23, y, 916, y + 165), 9, fill=(31, 39, 42), outline=(89, 106, 107), width=2)
    d.text((40, y + 13), f"{code}  {name}", font=label, fill=(235, 241, 237))
    d.text((40, y + 46), "六边形内底色  /  书册封边", font=small, fill=(174, 195, 194))

    d.rounded_rectangle((290, y + 12, 585, y + 148), 7, fill=(33, 42, 42), outline=(92, 107, 105))
    d.text((304, y + 19), "深色 UI · 实际尺寸", font=small, fill=(222, 233, 227))
    d.rounded_rectangle((602, y + 12, 900, y + 148), 7, fill=(205, 210, 201), outline=(98, 108, 104))
    d.text((616, y + 19), "浅色背景 · 实际尺寸", font=small, fill=(46, 60, 58))
    for base_x in (315, 627):
        for dx, size in ((0, 24), (72, 32), (150, 64)):
            icon = icons[size]
            sheet.paste(icon, (base_x + dx, y + 56), icon)
            fg = (189, 208, 206) if base_x == 315 else (54, 69, 67)
            d.text((base_x + dx - 5, y + 129), f"{size}", font=small, fill=fg)

sheet.save(OUT / "YiboCrafting-stage5-four-color-variants.png")
print(OUT / "YiboCrafting-stage5-four-color-variants.png")
