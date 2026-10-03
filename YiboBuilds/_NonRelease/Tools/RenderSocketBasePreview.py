"""Render a review sheet from the selected socket-base SVG, without exporting game assets."""

from io import BytesIO
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[3]
SOURCE = ROOT / "Docs" / "YiboBuilds-孔底座-03厚重锻造座.svg"
OUTPUT = ROOT / "Docs" / "YiboBuilds-孔底座-实尺寸预览.png"
SHAPES = [
    ("原生红", "native", "gemRound"),
    ("多彩", "meta", "gemStar"),
    ("锻造棱彩", "forged", "gemSquare"),
    ("染煞", "sha", "gemSha"),
]


def render(defs, shape, gem, size):
    gem_use = f'<use href="#{gem}"/>' if gem else ""
    image_svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" '
        f'viewBox="1 1 46 46"><defs>{defs}</defs>'
        f'<use href="#{shape}"/>{gem_use}</svg>'
    )
    png = cairosvg.svg2png(bytestring=image_svg.encode(), output_width=size, output_height=size)
    return Image.open(BytesIO(png)).convert("RGBA")


def main():
    source = SOURCE.read_text(encoding="utf-8")
    defs = source.split("<defs>", 1)[1].split("</defs>", 1)[0]
    sizes = (20, 24, 32, 64)
    canvas = Image.new("RGBA", (720, 494), (7, 21, 27, 255))
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 16)
    small = ImageFont.truetype("C:/Windows/Fonts/msyh.ttc", 12)
    draw.text((20, 15), "孔底座 · 选定 SVG 实尺寸预览", font=font, fill=(220, 237, 238, 255))
    for row, size in enumerate(sizes):
        y = 64 + row * 104
        draw.text((20, y + 13), f"{size}px", font=font, fill=(150, 184, 192, 255))
        for column, (label, shape, gem) in enumerate(SHAPES):
            x = 84 + column * 155
            draw.rounded_rectangle((x - 9, y - 8, x + 140, y + 80), 8, fill=(16, 36, 43, 255), outline=(49, 81, 90, 255))
            empty = render(defs, shape, None, size)
            installed = render(defs, shape, gem, size)
            canvas.alpha_composite(empty, (x, y))
            canvas.alpha_composite(installed, (x + 70, y))
            draw.text((x, y + 67), label, font=small, fill=(169, 194, 200, 255))
    draw.text((20, 472), "左：空孔；右：示意宝石。游戏内已镶状态使用真实物品图标。", font=small, fill=(143, 177, 184, 255))
    canvas.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    main()
