from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw

source = Path(__file__).parents[1] / "YiboAutoOpenIcon-stage5-07d-stylized-master.svg"
output_dir = Path(__file__).parent
sizes = (24, 32, 64)
images = []

for size in sizes:
    output = output_dir / f"YiboAutoOpenIcon-stage6-07d-{size}.png"
    cairosvg.svg2png(url=str(source), write_to=str(output), output_width=size, output_height=size)
    images.append(Image.open(output).convert("RGBA"))

sheet = Image.new("RGBA", (620, 210), (16, 23, 25, 255))
draw = ImageDraw.Draw(sheet)
draw.text((18, 14), "YAO 07D - Stage 6 pixel check (native / 2x nearest)", fill=(225, 245, 240, 255))

for index, (image, size) in enumerate(zip(images, sizes)):
    x = 22 + index * 200
    sheet.paste(image, (x, 58), image)
    enlarged = image.resize((size * 2, size * 2), Image.Resampling.NEAREST)
    sheet.paste(enlarged, (x + 90, 42), enlarged)
    draw.text((x, 170), f"{size}px", fill=(160, 187, 180, 255))

sheet.save(output_dir / "YiboAutoOpenIcon-stage6-07d-pixel-preview.png")

for image, size in zip(images, sizes):
    alpha = image.getchannel("A").getdata()
    transparent = sum(value == 0 for value in alpha)
    partial = sum(0 < value < 255 for value in alpha)
    opaque = sum(value == 255 for value in alpha)
    print(f"{size}px alpha: transparent={transparent}, partial={partial}, opaque={opaque}")
