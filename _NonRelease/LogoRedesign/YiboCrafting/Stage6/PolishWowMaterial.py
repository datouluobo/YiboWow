"""Stage 6 pixel cleanup for the approved WoW material direction."""

from pathlib import Path
from collections import deque

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


def clean_alpha(size):
    icon = Image.open(SOURCE / f"YiboCraftingIcon-wow-material-v1-{size}.png").convert("RGBA")
    data = icon.load()
    faint = nearly_opaque = 0
    for y in range(size):
        for x in range(size):
            r, g, b, a = data[x, y]
            if 0 < a < 24:
                data[x, y] = (0, 0, 0, 0)
                faint += 1
            elif 250 <= a < 255:
                data[x, y] = (r, g, b, 255)
                nearly_opaque += 1
    icon.save(OUT / f"YiboCraftingIcon-wow-material-pixel-v1-{size}.png")
    alpha = icon.getchannel("A")
    assert all(icon.getpixel(point)[3] == 0 for point in ((0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)))
    assert not any(0 < value < 24 for value in alpha.getdata())
    opaque = alpha.load()
    unseen = {(x, y) for y in range(size) for x in range(size) if opaque[x, y] > 0}
    components = []
    while unseen:
        seed = unseen.pop()
        queue = deque([seed])
        count = 0
        while queue:
            x, y = queue.popleft()
            count += 1
            for neighbor in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if neighbor in unseen:
                    unseen.remove(neighbor)
                    queue.append(neighbor)
        components.append(count)
    assert len(components) == 1, f"{size}px has detached alpha islands: {components}"
    print(f"{size}px: removed {faint} faint pixels, snapped {nearly_opaque} nearly opaque pixels, bbox {alpha.getbbox()}, connected components {components}")
    return icon


icons = {size: clean_alpha(size) for size in (24, 32)}
icons[64] = Image.open(SOURCE / "YiboCraftingIcon-wow-material-v1-64.png").convert("RGBA")

sheet = Image.new("RGB", (980, 560), (19, 27, 30))
d = ImageDraw.Draw(sheet)
title, label, tiny = font(23), font(17), font(14)
d.text((25, 14), "YiboCrafting · 阶段 6 像素修整", font=title, fill=(241, 245, 239))
d.text((25, 47), "3% 加宽书册 · WoW 材质 · 24/32px 独立小图", font=label, fill=(179, 202, 199))

for y, name, bg, fg in (
    (84, "深色 UI · 原尺寸", (30, 39, 42), (235, 241, 236)),
    (186, "浅色界面 · 原尺寸", (207, 212, 207), (39, 53, 54)),
):
    d.rounded_rectangle((23, y, 957, y + 87), 8, fill=bg, outline=(93, 109, 109), width=2)
    d.text((39, y + 14), name, font=label, fill=fg)
    for x, size in ((347, 24), (471, 32), (624, 64)):
        sheet.paste(icons[size], (x, y + 13), icons[size])
        d.text((x - 5, y + 64), f"{size}px", font=tiny, fill=fg)

d.rounded_rectangle((23, 296, 957, 538), 8, fill=(30, 38, 41), outline=(93, 109, 109), width=2)
d.text((40, 309), "逐像素放大检查 · 放大图不用于实尺寸验收", font=label, fill=(222, 233, 228))
for x, size, zoom in ((344, 24, 7), (619, 32, 6)):
    zoomed = icons[size].resize((size * zoom, size * zoom), Image.Resampling.NEAREST)
    sheet.paste(zoomed, (x, 344), zoomed)
    d.text((x + 40, 518), f"{size}px", font=tiny, fill=(185, 207, 205))
sheet.save(OUT / "YiboCrafting-stage6-wow-material-pixel-preview.png")

ui = Image.new("RGB", (920, 346), (18, 26, 29))
du = ImageDraw.Draw(ui)
du.text((22, 15), "YiboCrafting · 阶段 6 WoW UI 实尺寸复核", font=title, fill=(237, 244, 239))
du.rounded_rectangle((22, 60, 898, 118), 8, fill=(31, 40, 41), outline=(87, 103, 103), width=2)
du.text((39, 76), "Broker 24px", font=label, fill=(205, 224, 220))
ui.paste(icons[24], (270, 77), icons[24])
du.text((306, 79), "专业制造 · 配方索引", font=label, fill=(232, 238, 233))
du.rounded_rectangle((22, 137, 439, 321), 8, fill=(27, 35, 38), outline=(87, 103, 103), width=2)
du.text((40, 153), "小地图按钮 32px", font=label, fill=(207, 222, 217))
du.ellipse((111, 206, 264, 305), fill=(42, 59, 47), outline=(105, 110, 77), width=4)
du.ellipse((245, 220, 305, 280), fill=(24, 31, 32), outline=(138, 130, 96), width=3)
ui.paste(icons[32], (259, 233), icons[32])
du.rounded_rectangle((456, 137, 898, 321), 8, fill=(28, 36, 39), outline=(87, 103, 103), width=2)
du.text((474, 153), "紧凑列表", font=label, fill=(207, 222, 217))
du.rectangle((474, 195, 880, 238), fill=(42, 49, 51))
ui.paste(icons[24], (485, 204), icons[24])
du.text((521, 207), "专业制造 · 已学配方", font=label, fill=(232, 238, 233))
du.rectangle((474, 248, 880, 305), fill=(37, 44, 48))
ui.paste(icons[32], (485, 260), icons[32])
du.text((530, 267), "专业制造", font=label, fill=(232, 238, 233))
ui.save(OUT / "YiboCrafting-stage6-wow-material-ui-preview.png")
print(OUT / "YiboCrafting-stage6-wow-material-pixel-preview.png")
print(OUT / "YiboCrafting-stage6-wow-material-ui-preview.png")
