from collections import deque
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import cairosvg

ROOT = Path(__file__).resolve().parents[2]
STAGE5 = ROOT / "Media" / "Concepts" / "Stage5" / "YiboBuildsIcon-styled.svg"
OUT = ROOT / "Media" / "Concepts" / "Stage6"
OUT.mkdir(parents=True, exist_ok=True)

# Move only the two vertical badge tips inward so even the 24px asset keeps
# a fully transparent outermost row; all character geometry stays unchanged.
source = STAGE5.read_text(encoding="utf-8")
old = 'M16 1.6 29 9v14L16 30.4 3 23V9Z'
new = 'M16 2.8 29 9v14L16 29.2 3 23V9Z'
assert source.count(old) == 1
svg = OUT / "YiboBuildsIcon-pixel-master.svg"
svg.write_text(source.replace(old, new).replace("styled icon preview", "pixel-adjusted icon preview"), encoding="utf-8")

icons = {}
for size in (24, 32, 64):
    target = OUT / f"YiboBuildsIcon-pixel-preview-{size}.png"
    cairosvg.svg2png(url=str(svg), write_to=str(target), output_width=size, output_height=size)
    image = Image.open(target).convert("RGBA")
    pixels = image.load()
    removed = 0
    for y in range(size):
        for x in range(size):
            r, g, b, a = pixels[x, y]
            if a < 16:
                if a:
                    removed += 1
                pixels[x, y] = (0, 0, 0, 0)
    image.save(target)
    icons[size] = image

    alpha = image.getchannel("A")
    assert alpha.getextrema() == (0, 255)
    assert all(alpha.getpixel((x, 0)) == alpha.getpixel((x, size - 1)) == 0 for x in range(size))
    assert all(alpha.getpixel((0, y)) == alpha.getpixel((size - 1, y)) == 0 for y in range(size))
    assert alpha.getbbox() is not None

    # Strong-alpha pixels must belong to a substantial connected shape.
    visible = {(x, y) for y in range(size) for x in range(size) if alpha.getpixel((x, y)) >= 48}
    components = []
    while visible:
        start = visible.pop()
        queue = deque([start])
        count = 1
        while queue:
            x, y = queue.popleft()
            for nx, ny in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
                if (nx, ny) in visible:
                    visible.remove((nx, ny))
                    queue.append((nx, ny))
                    count += 1
        components.append(count)
    assert min(components) >= 2, (size, components)
    print(f"{size}px: bbox={alpha.getbbox()}, removed faint pixels={removed}, components={components}")

try:
    title = ImageFont.truetype("arialbd.ttf", 19)
    body = ImageFont.truetype("arial.ttf", 13)
except OSError:
    title = body = ImageFont.load_default()

sheet = Image.new("RGBA", (760, 332), (11, 17, 20, 255))
d = ImageDraw.Draw(sheet)
d.text((18, 14), "YiboBuilds · Stage 6 pixel review", font=title, fill=(234, 241, 240, 255))
d.text((18, 42), "Native sizes plus 8x pixel inspection · transparent outer border", font=body, fill=(145, 162, 165, 255))
d.rounded_rectangle((18, 70, 376, 315), radius=8, fill=(22, 31, 35, 255), outline=(59, 77, 82, 255))
d.text((32, 84), "24px and 32px pixel inspection", font=body, fill=(230, 237, 236, 255))
sheet.alpha_composite(icons[24].resize((144, 144), Image.Resampling.NEAREST), (36, 120))
sheet.alpha_composite(icons[32].resize((144, 144), Image.Resampling.NEAREST), (212, 120))
d.text((84, 275), "24 px", font=body, fill=(155, 174, 177, 255))
d.text((262, 275), "32 px", font=body, fill=(155, 174, 177, 255))

d.rounded_rectangle((396, 70, 742, 160), radius=8, fill=(22, 31, 35, 255), outline=(59, 77, 82, 255))
d.text((410, 83), "Native sizes", font=body, fill=(230, 237, 236, 255))
for size, x, y in ((24, 425, 115), (32, 510, 111), (64, 622, 92)):
    sheet.alpha_composite(icons[size], (x, y))
    d.text((x+size+5, 119), str(size), font=body, fill=(230, 237, 236, 255))

d.rounded_rectangle((396, 178, 742, 315), radius=8, fill=(22, 31, 35, 255), outline=(59, 77, 82, 255))
d.text((410, 191), "Dark UI placements", font=body, fill=(230, 237, 236, 255))
d.rounded_rectangle((410, 225, 605, 270), radius=5, fill=(29, 40, 45, 255), outline=(64, 84, 89, 255))
sheet.alpha_composite(icons[24], (421, 235))
d.text((453, 239), "Character Builds", font=body, fill=(235, 241, 240, 255))
d.ellipse((641, 217, 708, 284), fill=(13, 20, 22, 255), outline=(75, 95, 99, 255), width=2)
sheet.alpha_composite(icons[32], (659, 235))
sheet.save(OUT / "YiboBuilds-stage6-pixel-final-preview.png")
print(OUT / "YiboBuilds-stage6-pixel-final-preview.png")
