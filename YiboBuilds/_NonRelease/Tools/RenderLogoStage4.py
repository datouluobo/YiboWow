from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import cairosvg

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Media" / "Concepts" / "Stage3" / "YiboBuildsIcon-cluster-skeleton.svg"
OUT = ROOT / "Media" / "Concepts" / "Stage4"
OUT.mkdir(parents=True, exist_ok=True)

icons = {}
for size in (24, 32, 64):
    target = OUT / f"YiboBuildsIcon-ui-preview-{size}.png"
    cairosvg.svg2png(url=str(SOURCE), write_to=str(target), output_width=size, output_height=size)
    icons[size] = Image.open(target).convert("RGBA")

W, H = 900, 500
canvas = Image.new("RGBA", (W, H), (10, 15, 18, 255))
d = ImageDraw.Draw(canvas)

def font(size, bold=False):
    names = ["arialbd.ttf" if bold else "arial.ttf", "segoeui.ttf"]
    for name in names:
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()

F_TITLE, F_HEAD, F_BODY, F_SMALL = font(22, True), font(16, True), font(15), font(12)
TEXT, MUTED, LINE = (231, 238, 237, 255), (143, 159, 162, 255), (53, 69, 74, 255)
PANEL, PANEL_2 = (20, 28, 32, 255), (25, 34, 39, 255)

def panel(box, title):
    d.rounded_rectangle(box, radius=9, fill=PANEL, outline=LINE, width=1)
    d.text((box[0]+14, box[1]+11), title, font=F_HEAD, fill=TEXT)

d.text((22, 17), "YiboBuilds · Stage 4 UI readability", font=F_TITLE, fill=TEXT)
d.text((22, 47), "Same vector skeleton at native sizes; grayscale structure only", font=F_SMALL, fill=MUTED)

# Native-size strip.
panel((20, 76, 880, 164), "Native sizes")
x = 190
for size in (24, 32, 64):
    y = 116 - size // 2
    canvas.alpha_composite(icons[size], (x, y))
    d.text((x + size + 12, 111), f"{size} px", font=F_BODY, fill=TEXT)
    x += 210

# Broker row.
panel((20, 182, 430, 272), "Broker row · 24 px")
d.rounded_rectangle((36, 224, 414, 258), radius=4, fill=PANEL_2, outline=(68, 85, 91, 255), width=1)
canvas.alpha_composite(icons[24], (46, 229))
d.text((82, 232), "[Yibo] Character Builds", font=F_BODY, fill=TEXT)
d.text((344, 233), "12 chars", font=F_SMALL, fill=MUTED)

# Compact roster/list.
panel((20, 290, 430, 474), "Compact account list · 24 px")
rows = [("Aster", "Updated 2m ago"), ("Brumal", "Updated 1d ago"), ("Cinder", "Not synced")]
for i, (name, state) in enumerate(rows):
    top = 332 + i * 42
    d.rounded_rectangle((36, top, 414, top+34), radius=4, fill=PANEL_2 if i % 2 == 0 else (22, 31, 35, 255))
    canvas.alpha_composite(icons[24], (44, top+5))
    d.text((78, top+6), name, font=F_BODY, fill=TEXT)
    d.text((270, top+8), state, font=F_SMALL, fill=MUTED)

# Minimap and settings/sidebar examples.
panel((450, 182, 880, 474), "Minimap button and page navigation")
d.ellipse((482, 224, 658, 400), fill=(17, 30, 31, 255), outline=(93, 106, 91, 255), width=4)
d.ellipse((497, 239, 643, 385), fill=(31, 49, 43, 255))
d.polygon([(511, 327), (540, 270), (584, 260), (628, 310), (608, 364), (548, 375)], fill=(49, 70, 57, 255))
d.ellipse((616, 205, 670, 259), fill=(15, 20, 23, 255), outline=(79, 93, 98, 255), width=2)
canvas.alpha_composite(icons[32], (627, 216))
d.text((493, 414), "32 px minimap entry", font=F_SMALL, fill=MUTED)

d.rounded_rectangle((692, 224, 854, 300), radius=5, fill=PANEL_2, outline=(68, 85, 91, 255), width=1)
canvas.alpha_composite(icons[32], (706, 244))
d.text((748, 238), "Character", font=F_BODY, fill=TEXT)
d.text((748, 258), "Builds", font=F_BODY, fill=TEXT)
d.text((706, 310), "32 px page navigation", font=F_SMALL, fill=MUTED)

d.rounded_rectangle((692, 347, 854, 445), radius=5, fill=PANEL_2, outline=(68, 85, 91, 255), width=1)
canvas.alpha_composite(icons[64], (706, 364))
d.text((780, 374), "Character", font=F_BODY, fill=TEXT)
d.text((780, 394), "Builds", font=F_BODY, fill=TEXT)
d.text((706, 454), "64 px settings header", font=F_SMALL, fill=MUTED)

canvas.save(OUT / "YiboBuilds-stage4-wow-ui-preview.png")
print(OUT / "YiboBuilds-stage4-wow-ui-preview.png")
