from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import cairosvg

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Media" / "Concepts" / "Stage5" / "YiboBuildsIcon-styled.svg"
OUT = SOURCE.parent

icons = {}
for size in (24, 32, 64):
    target = OUT / f"YiboBuildsIcon-styled-{size}.png"
    cairosvg.svg2png(url=str(SOURCE), write_to=str(target), output_width=size, output_height=size)
    icons[size] = Image.open(target).convert("RGBA")

W, H = 820, 340
canvas = Image.new("RGBA", (W, H), (9, 14, 17, 255))
d = ImageDraw.Draw(canvas)

def font(size, bold=False):
    for name in ("arialbd.ttf" if bold else "arial.ttf", "segoeui.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()

title, head, body, small = font(21, True), font(15, True), font(14), font(12)
TEXT, MUTED = (233, 240, 239, 255), (142, 158, 161, 255)

d.text((22, 18), "YiboBuilds · Stage 5 styled preview", font=title, fill=TEXT)
d.text((22, 49), "Approved skeleton · teal Yibo frame · indigo archive accent", font=small, fill=MUTED)

# Enlarged inspection without changing the actual assets.
d.rounded_rectangle((20, 78, 405, 318), radius=9, fill=(19, 27, 31, 255), outline=(52, 68, 73, 255), width=1)
d.text((35, 92), "Structure inspection", font=head, fill=TEXT)
canvas.alpha_composite(icons[32].resize((192, 192), Image.Resampling.NEAREST), (115, 117))

# Native sizes on dark UI.
d.rounded_rectangle((425, 78, 800, 190), radius=9, fill=(19, 27, 31, 255), outline=(52, 68, 73, 255), width=1)
d.text((440, 92), "Native sizes", font=head, fill=TEXT)
positions = [(455, 132, 24), (555, 128, 32), (670, 112, 64)]
for x, y, size in positions:
    canvas.alpha_composite(icons[size], (x, y))
    d.text((x+size+8, 139), f"{size}", font=body, fill=TEXT)

# Two practical dark UI placements.
d.rounded_rectangle((425, 208, 800, 318), radius=9, fill=(19, 27, 31, 255), outline=(52, 68, 73, 255), width=1)
d.text((440, 222), "WoW UI placements", font=head, fill=TEXT)
d.rounded_rectangle((440, 255, 625, 295), radius=4, fill=(26, 36, 41, 255), outline=(65, 82, 88, 255), width=1)
canvas.alpha_composite(icons[24], (450, 263))
d.text((483, 266), "Character Builds", font=body, fill=TEXT)
d.ellipse((680, 242, 740, 302), fill=(14, 20, 23, 255), outline=(69, 87, 92, 255), width=2)
canvas.alpha_composite(icons[32], (694, 256))
d.text((653, 306), "minimap", font=small, fill=MUTED)

canvas.save(OUT / "YiboBuilds-stage5-styled-preview.png")
print(OUT / "YiboBuilds-stage5-styled-preview.png")
