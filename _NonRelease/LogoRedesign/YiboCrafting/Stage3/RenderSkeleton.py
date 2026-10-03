"""Render stage 3 skeleton at actual size and assemble a review sheet."""

from io import BytesIO
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
SVG = OUT / "YiboCraftingIcon-A-skeleton.svg"


def render(size):
    png = cairosvg.svg2png(url=str(SVG), output_width=size, output_height=size)
    im = Image.open(BytesIO(png)).convert("RGBA")
    im.save(OUT / f"YiboCraftingIcon-A-skeleton-{size}.png")
    return im


icon24, icon32 = render(24), render(32)
sheet = Image.new("RGB", (620, 320), (24, 31, 35))
d = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("msyh.ttc", 19)
except OSError:
    font = ImageFont.load_default()

d.text((24, 16), "A  书册横向 +3% · 高度不变", font=font, fill=(239, 245, 245))
d.text((24, 57), "实际尺寸", font=font, fill=(184, 205, 207))
sheet.paste(icon24, (46, 95), icon24)
sheet.paste(icon32, (130, 91), icon32)
d.text((37, 130), "24px", font=font, fill=(184, 205, 207))
d.text((121, 130), "32px", font=font, fill=(184, 205, 207))

d.text((292, 57), "仅供查看像素轮廓的放大图", font=font, fill=(184, 205, 207))
large24 = icon24.resize((144, 144), Image.Resampling.NEAREST)
large32 = icon32.resize((144, 144), Image.Resampling.NEAREST)
sheet.paste(large24, (282, 104), large24)
sheet.paste(large32, (452, 104), large32)
d.text((311, 261), "24px ×6", font=font, fill=(184, 205, 207))
d.text((481, 261), "32px ×4.5", font=font, fill=(184, 205, 207))

sheet.save(OUT / "YiboCrafting-stage3-skeleton-preview.png")
print(OUT / "YiboCrafting-stage3-skeleton-preview.png")
