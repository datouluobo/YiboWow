from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import cairosvg

ROOT = Path(__file__).resolve().parents[2]
STAGE = ROOT / "Media" / "Concepts" / "Stage3"
SVG = STAGE / "YiboBuildsIcon-cluster-skeleton.svg"

for size in (24, 32):
    cairosvg.svg2png(url=str(SVG), write_to=str(STAGE / f"YiboBuildsIcon-cluster-skeleton-{size}.png"),
                     output_width=size, output_height=size)

icon32 = Image.open(STAGE / "YiboBuildsIcon-cluster-skeleton-32.png").convert("RGBA")
icon24 = Image.open(STAGE / "YiboBuildsIcon-cluster-skeleton-24.png").convert("RGBA")
sheet = Image.new("RGBA", (440, 220), (18, 23, 26, 255))
d = ImageDraw.Draw(sheet)
try:
    title = ImageFont.truetype("arial.ttf", 18)
    label = ImageFont.truetype("arial.ttf", 13)
except OSError:
    title = label = ImageFont.load_default()

d.text((18, 14), "G — Cluster Badge · vector skeleton", font=title, fill=(238, 243, 242, 255))
d.text((28, 185), "8× inspection", font=label, fill=(146, 163, 166, 255))
d.text((292, 70), "actual size", font=label, fill=(146, 163, 166, 255))
d.text((292, 96), "32 px", font=label, fill=(220, 228, 227, 255))
d.text((292, 137), "24 px", font=label, fill=(220, 228, 227, 255))

sheet.alpha_composite(icon32.resize((128, 128), Image.Resampling.NEAREST), (42, 48))
sheet.alpha_composite(icon24.resize((96, 96), Image.Resampling.NEAREST), (180, 64))
sheet.alpha_composite(icon32, (362, 91))
sheet.alpha_composite(icon24, (366, 132))
sheet.save(STAGE / "YiboBuilds-stage3-skeleton-preview.png")
print(STAGE / "YiboBuilds-stage3-skeleton-preview.png")
