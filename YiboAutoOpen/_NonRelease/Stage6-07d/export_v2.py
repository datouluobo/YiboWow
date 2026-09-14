from pathlib import Path

import cairosvg
from PIL import Image

root = Path(__file__).parents[2]
source = root / "Media" / "YiboAutoOpenIcon-v2-master.svg"
sizes = (24, 32, 64, 128, 512, 1024)

for size in sizes:
    output = root / "Media" / f"YiboAutoOpenIcon-v2-{size}.png"
    cairosvg.svg2png(url=str(source), write_to=str(output), output_width=size, output_height=size)

image = Image.open(root / "Media" / "YiboAutoOpenIcon-v2-64.png").convert("RGBA")
image.save(root / "Media" / "YiboAutoOpenIcon-v2.tga")

for size in sizes:
    image = Image.open(root / "Media" / f"YiboAutoOpenIcon-v2-{size}.png").convert("RGBA")
    alpha = image.getchannel("A").getdata()
    print(f"{size}px PNG: {image.mode}, transparent={sum(value == 0 for value in alpha)}, opaque={sum(value == 255 for value in alpha)}")

tga = Image.open(root / "Media" / "YiboAutoOpenIcon-v2.tga")
print(f"TGA: {tga.size}, {tga.mode}")
