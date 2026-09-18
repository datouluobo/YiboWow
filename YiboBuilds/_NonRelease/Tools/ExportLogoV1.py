from pathlib import Path
from PIL import Image
import cairosvg
import shutil

ROOT = Path(__file__).resolve().parents[2]
MEDIA = ROOT / "Media"
STAGE6 = MEDIA / "Concepts" / "Stage6"
SOURCE = STAGE6 / "YiboBuildsIcon-pixel-master.svg"
MASTER = MEDIA / "YiboBuildsIcon-v1-master.svg"

assert SOURCE.is_file()
assert not MASTER.exists(), MASTER
shutil.copyfile(SOURCE, MASTER)

for size in (24, 32, 64, 128, 512, 1024):
    target = MEDIA / f"YiboBuildsIcon-v1-{size}.png"
    assert not target.exists(), target
    if size <= 64:
        with Image.open(STAGE6 / f"YiboBuildsIcon-pixel-preview-{size}.png") as source:
            image = source.convert("RGBA")
    else:
        cairosvg.svg2png(url=str(MASTER), write_to=str(target),
                         output_width=size, output_height=size)
        with Image.open(target) as source:
            image = source.convert("RGBA")
        pixels = image.load()
        for y in range(size):
            for x in range(size):
                if pixels[x, y][3] < 16:
                    pixels[x, y] = (0, 0, 0, 0)
    image.save(target)
    print(target)

# Use 128px as the WoW texture: a power-of-two RGBA TGA with the same master.
tga = MEDIA / "YiboBuildsIcon-v1.tga"
assert not tga.exists(), tga
with Image.open(MEDIA / "YiboBuildsIcon-v1-128.png") as image:
    image.convert("RGBA").save(tga, format="TGA")
print(tga)
print(MASTER)
