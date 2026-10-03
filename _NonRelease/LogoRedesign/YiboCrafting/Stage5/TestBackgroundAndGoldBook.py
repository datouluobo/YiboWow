"""Stage 5: adjacent regular hexagons, flat pages, and two field colors."""

from io import BytesIO
from pathlib import Path
import re

import cairosvg
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
BASE = (OUT / "YiboCraftingIcon-color-d.svg").read_text(encoding="utf-8")
SHAPE = {
    "M16 1.2 30 9v14L16 30.8 2 23V9Z": "M16 1.4 28.64 8.7v14.6L16 30.6 3.36 23.3V8.7Z",
    "M16 3.6 27.6 10.1v11.8L16 28.4 4.4 21.9V10.1Z": "M16 3.05 27.21 9.525v12.95L16 28.95 4.79 22.475V9.525Z",
    'fill="url(#pageLeft)"': 'fill="#FFE3A0"',
    'fill="url(#pageRight)"': 'fill="#F1B859"',
    'scale(0.90)': 'scale(0.927 0.90)',
}
for old, new in SHAPE.items():
    if BASE.count(old) != 1:
        raise ValueError(f"Expected one {old}, found {BASE.count(old)}")
    BASE = BASE.replace(old, new)
BASE = re.sub(r'    <linearGradient id="pageLeft".*?</linearGradient>\n', "", BASE, flags=re.DOTALL)
BASE = re.sub(r'    <linearGradient id="pageRight".*?</linearGradient>\n', "", BASE, flags=re.DOTALL)
BASE = BASE.replace('  <path d="m8.3 11.7 4.2.6" fill="none" stroke="#FFFCE9" stroke-width="1.3" stroke-linecap="round" opacity=".83"/>', "")


def font(size):
    for name in ("msyh.ttc", "Microsoft YaHei.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def render(svg, size):
    raw = cairosvg.svg2png(bytestring=svg.encode("utf-8"), output_width=size, output_height=size)
    return Image.open(BytesIO(raw)).convert("RGBA")


GOLD = {
    "#4D7890": "#FFD272",  # the book's outer cover edge
    "#1D4053": "#C58B31",  # broad warm edge outline
    "#315B70": "#D09A3A",  # center fold belongs to the page palette
}
VARIANTS = [
    ("charcoal", "A  炭灰内底 + 黄色书边", "#344044", "#121E25"),
    ("white", "B  白色内底 + 黄色书边", "#FFFFFF", "#FFFFFF"),
]

sheet = Image.new("RGB", (1070, 835), (20, 27, 31))
d = ImageDraw.Draw(sheet)
title, label, small = font(22), font(17), font(14)
d.text((24, 15), "YiboCrafting · 阶段 5 简化书页配色测试", font=title, fill=(239, 245, 244))
d.text((24, 48), "两块纯色书页 · 金色书边 · 贴合正六边形框；对照炭灰与白色内底。", font=label, fill=(181, 200, 200))

for idx, (code, name, top, bottom) in enumerate(VARIANTS):
    svg = BASE
    replacements = {"#344044": top, "#121E25": bottom, **GOLD}
    for before, after in replacements.items():
        if svg.count(before) != 1:
            raise ValueError(f"Expected one {before}, found {svg.count(before)}")
        svg = svg.replace(before, after)
    svg = svg.replace("<title>YiboCrafting open recipe book styled preview</title>",
                      f"<title>YiboCrafting {code} field with gold book edge</title>")
    (OUT / f"YiboCraftingIcon-field-{code}-gold.svg").write_text(svg, encoding="utf-8")

    icons = {}
    for size in (24, 32, 64):
        icons[size] = render(svg, size)
        icons[size].save(OUT / f"YiboCraftingIcon-field-{code}-gold-{size}.png")
    detail = render(svg, 256)

    y = 83 + idx * 370
    d.rounded_rectangle((24, y, 1046, y + 350), 10, fill=(31, 39, 42), outline=(90, 107, 107), width=2)
    d.text((42, y + 16), name, font=title, fill=(237, 243, 239))
    d.text((42, y + 58), "256px 颜色观察", font=small, fill=(181, 202, 201))
    sheet.paste(detail, (37, y + 75), detail)

    for bg_x, bg_name, bg, fg in (
        (320, "深色界面 · 实际尺寸", (34, 42, 43), (230, 238, 233)),
        (684, "浅色界面 · 实际尺寸", (209, 213, 205), (42, 55, 54)),
    ):
        d.rounded_rectangle((bg_x, y + 64, bg_x + 343, y + 248), 8, fill=bg, outline=(91, 107, 106), width=1)
        d.text((bg_x + 16, y + 80), bg_name, font=small, fill=fg)
        for offset, size in ((18, 24), (105, 32), (208, 64)):
            icon = icons[size]
            sheet.paste(icon, (bg_x + offset, y + 126), icon)
            d.text((bg_x + offset - 4, y + 207), f"{size}px", font=small, fill=fg)

sheet.save(OUT / "YiboCrafting-stage5-background-and-gold-book-test.png")
print(OUT / "YiboCrafting-stage5-background-and-gold-book-test.png")
