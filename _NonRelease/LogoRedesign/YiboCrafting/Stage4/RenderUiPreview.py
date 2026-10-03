"""Stage 4 review only: actual-size icon in compact WoW-like UI positions."""

from io import BytesIO
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
SVG = OUT.parent / "Stage3" / "YiboCraftingIcon-A-skeleton.svg"
BUILDS = Path(__file__).resolve().parents[4] / "YiboBuilds" / "Media"


def font(size):
    for name in ("msyh.ttc", "Microsoft YaHei.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def render(size):
    raw = cairosvg.svg2png(url=str(SVG), output_width=size, output_height=size)
    icon = Image.open(BytesIO(raw)).convert("RGBA")
    icon.save(OUT / f"YiboCraftingIcon-A-ui-preview-{size}.png")
    return icon


icons = {s: render(s) for s in (24, 32, 64)}
builds = {s: Image.open(BUILDS / f"YiboBuildsIcon-v1-{s}.png").convert("RGBA") for s in (24, 32, 64)}

im = Image.new("RGB", (890, 560), (17, 23, 26))
d = ImageDraw.Draw(im)
title, label, small = font(22), font(17), font(14)
d.text((25, 16), "YiboCrafting · A 骨架 / 阶段 4 实尺寸预览", font=title, fill=(240, 246, 245))
d.text((25, 52), "所有图标按实际 24 / 32 / 64px 显示；右侧 Builds 为已发布质量参照。", font=label, fill=(169, 193, 196))

# Dark Broker strip: actual 24px icons.
d.rounded_rectangle((25, 94, 865, 157), radius=8, fill=(32, 39, 39), outline=(82, 93, 87), width=2)
d.text((42, 104), "Broker 栏 · 24px", font=label, fill=(209, 218, 207))
im.paste(icons[24], (265, 113), icons[24])
d.text((298, 114), "专业制造", font=label, fill=(231, 235, 228))
im.paste(builds[24], (559, 113), builds[24])
d.text((592, 114), "Builds 参照", font=label, fill=(231, 235, 228))

# Minimap-like dark well: actual 32px icon.
d.rounded_rectangle((25, 180, 422, 365), radius=9, fill=(27, 34, 37), outline=(77, 89, 91), width=2)
d.text((42, 195), "小地图按钮 · 32px", font=label, fill=(209, 218, 207))
d.ellipse((107, 232, 245, 350), fill=(36, 53, 43), outline=(97, 105, 73), width=4)
d.ellipse((143, 234, 271, 350), outline=(70, 81, 65), width=2)
d.ellipse((250, 253, 294, 297), fill=(28, 32, 34), outline=(149, 141, 101), width=3)
im.paste(icons[32], (256, 259), icons[32])
d.text((309, 260), "Crafting", font=label, fill=(232, 234, 220))

# Compact row: 24 and 32 respectively, on the same dark background.
d.rounded_rectangle((444, 180, 865, 365), radius=9, fill=(29, 34, 39), outline=(77, 89, 91), width=2)
d.text((462, 195), "紧凑列表 · 24/32px", font=label, fill=(209, 218, 207))
d.rectangle((462, 235, 848, 277), fill=(39, 47, 51))
im.paste(icons[24], (475, 244), icons[24])
d.text((514, 246), "专业制造  ·  已学配方索引", font=label, fill=(235, 239, 236))
d.rectangle((462, 290, 848, 336), fill=(37, 44, 48))
im.paste(icons[32], (475, 297), icons[32])
d.text((522, 302), "专业制造", font=label, fill=(235, 239, 236))

# Actual-size scale row and neutral comparison.
d.rounded_rectangle((25, 385, 865, 531), radius=9, fill=(30, 37, 41), outline=(77, 89, 91), width=2)
d.text((42, 399), "同骨架尺寸对照", font=label, fill=(209, 218, 207))
for x, size in ((222, 24), (320, 32), (420, 64)):
    im.paste(icons[size], (x, 440), icons[size])
    d.text((x - 5, 506), f"{size}px", font=small, fill=(168, 190, 192))
for x, size in ((575, 24), (655, 32), (745, 64)):
    im.paste(builds[size], (x, 440), builds[size])
    d.text((x - 5, 506), f"{size}px", font=small, fill=(168, 190, 192))
d.text((49, 462), "Crafting", font=label, fill=(235, 239, 236))
d.text((512, 462), "Builds", font=label, fill=(235, 239, 236))

im.save(OUT / "YiboCrafting-stage4-wow-ui-preview.png")
print(OUT / "YiboCrafting-stage4-wow-ui-preview.png")
