"""Review the consistent 3% width across small and large icon previews."""

from io import BytesIO
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
PREVIOUS = OUT / "YiboCraftingIcon-large-refined-v1.svg"
REFINED = OUT / "YiboCraftingIcon-large-refined-v3.svg"


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


sheet = Image.new("RGB", (1160, 805), (20, 27, 30))
d = ImageDraw.Draw(sheet)
title, label, small = font(23), font(18), font(15)
d.text((26, 14), "YiboCrafting · 中图与大图书页修整", font=title, fill=(239, 245, 243))
d.text((26, 48), "24/32/64/128/512px 均采用书册横向加宽 3% 的骨架，高度保持不变。", font=label, fill=(181, 203, 201))

approved = {
    24: Image.open(OUT / "YiboCraftingIcon-field-charcoal-gold-24.png").convert("RGBA"),
    32: Image.open(OUT / "YiboCraftingIcon-field-charcoal-gold-32.png").convert("RGBA"),
}
for x, size in ((164, 24), (236, 32)):
    icon = approved[size]
    sheet.paste(icon, (x, 111), icon)
    d.text((x - 6, 151), f"{size}px", font=small, fill=(178, 201, 199))
d.text((27, 112), "小图预览", font=label, fill=(224, 235, 230))
for x, size in ((455, 64), (566, 128)):
    icon = render(REFINED, size)
    sheet.paste(icon, (x, 91), icon)
    d.text((x - 3, 166 if size == 64 else 224), f"{size}px", font=small, fill=(178, 201, 199))
d.text((340, 112), "修整后", font=label, fill=(224, 235, 230))

d.text((35, 255), "原大图 · 512px", font=label, fill=(183, 202, 202))
d.text((620, 255), "统一 3% 宽度 · 512px", font=label, fill=(230, 239, 233))
d.rounded_rectangle((25, 283, 565, 782), 10, fill=(31, 39, 42), outline=(84, 100, 101), width=2)
d.rounded_rectangle((610, 283, 1150, 782), 10, fill=(31, 39, 42), outline=(84, 100, 101), width=2)
old = render(PREVIOUS, 448)
new = render(REFINED, 448)
sheet.paste(old, (69, 302), old)
sheet.paste(new, (654, 302), new)

sheet.save(OUT / "YiboCrafting-stage5-large-refinement-review.png")
print(OUT / "YiboCrafting-stage5-large-refinement-review.png")
