"""Pixel-level alpha cleanup for the approved charcoal and gold icon."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
SOURCE = OUT.parent / "Stage5"


def font(size):
    for name in ("msyh.ttc", "Microsoft YaHei.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def polish(size):
    icon = Image.open(SOURCE / f"YiboCraftingIcon-field-charcoal-gold-{size}.png").convert("RGBA")
    pixels = icon.load()
    cleared = snapped = 0
    for y in range(size):
        for x in range(size):
            r, g, b, a = pixels[x, y]
            if 0 < a < 24:
                pixels[x, y] = (0, 0, 0, 0)
                cleared += 1
            elif 250 <= a < 255:
                pixels[x, y] = (r, g, b, 255)
                snapped += 1
    icon.save(OUT / f"YiboCraftingIcon-A-pixel-preview-{size}.png")
    return icon, cleared, snapped


icons = {}
for size in (24, 32):
    icon, cleared, snapped = polish(size)
    icons[size] = icon
    print(f"{size}px: cleared {cleared} faint-alpha pixels; snapped {snapped} near-opaque pixels")
icons[64] = Image.open(SOURCE / "YiboCraftingIcon-field-charcoal-gold-64.png").convert("RGBA")

sheet = Image.new("RGB", (830, 490), (21, 28, 31))
d = ImageDraw.Draw(sheet)
title, label, small = font(22), font(17), font(14)
d.text((22, 15), "YiboCrafting · 阶段 6 像素修整预览", font=title, fill=(239, 245, 243))
d.text((22, 47), "90% 书册 · 炭灰内底 · 纯色书页与金色书边", font=label, fill=(177, 199, 198))

for y, name, bg in ((83, "WoW 深色 UI", (32, 39, 40)), (180, "浅色背景", (206, 209, 199))):
    d.rounded_rectangle((22, y, 808, y + 84), 8, fill=bg, outline=(91, 107, 107), width=2)
    fg = (232, 238, 233) if y == 83 else (38, 50, 50)
    d.text((40, y + 12), name, font=label, fill=fg)
    for x, size in ((319, 24), (421, 32), (533, 64)):
        sheet.paste(icons[size], (x, y + 12), icons[size])
        d.text((x - 5, y + 62), f"{size}px", font=small, fill=fg)

d.rounded_rectangle((22, 282, 808, 467), 8, fill=(29, 37, 40), outline=(91, 107, 107), width=2)
d.text((40, 296), "逐像素放大检查（不作为实尺寸判断）", font=label, fill=(217, 230, 227))
for x, size, zoom in ((300, 24, 5), (489, 32, 4)):
    scaled = icons[size].resize((size * zoom, size * zoom), Image.Resampling.NEAREST)
    sheet.paste(scaled, (x, 323), scaled)

sheet.save(OUT / "YiboCrafting-stage6-pixel-final-preview.png")
print(OUT / "YiboCrafting-stage6-pixel-final-preview.png")

ui = Image.new("RGB", (820, 310), (19, 26, 29))
du = ImageDraw.Draw(ui)
du.text((20, 14), "YiboCrafting · 阶段 6 WoW UI 实尺寸复核", font=title, fill=(238, 245, 243))
du.rounded_rectangle((20, 55, 800, 113), 8, fill=(32, 40, 41), outline=(85, 102, 102), width=2)
du.text((36, 70), "Broker 24px", font=label, fill=(212, 226, 221))
ui.paste(icons[24], (248, 72), icons[24])
du.text((283, 74), "专业制造", font=label, fill=(232, 237, 232))

du.rounded_rectangle((20, 133, 395, 285), 8, fill=(27, 35, 38), outline=(85, 102, 102), width=2)
du.text((36, 148), "小地图按钮 32px", font=label, fill=(212, 226, 221))
du.ellipse((104, 190, 238, 274), fill=(43, 60, 48), outline=(104, 108, 78), width=4)
du.ellipse((224, 204, 276, 256), fill=(25, 31, 32), outline=(137, 130, 96), width=3)
ui.paste(icons[32], (234, 214), icons[32])

du.rounded_rectangle((415, 133, 800, 285), 8, fill=(28, 35, 39), outline=(85, 102, 102), width=2)
du.text((431, 148), "紧凑列表 24/32px", font=label, fill=(212, 226, 221))
du.rectangle((431, 185, 784, 226), fill=(40, 48, 51))
ui.paste(icons[24], (443, 194), icons[24])
du.text((480, 196), "专业制造 · 已学配方", font=label, fill=(233, 238, 232))
du.rectangle((431, 233, 784, 274), fill=(37, 45, 48))
ui.paste(icons[32], (443, 237), icons[32])
du.text((489, 244), "专业制造", font=label, fill=(233, 238, 232))

ui.save(OUT / "YiboCrafting-stage6-wow-ui-preview.png")
print(OUT / "YiboCrafting-stage6-wow-ui-preview.png")
