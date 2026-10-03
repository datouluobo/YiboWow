"""Export the approved YiboCrafting v2 icon and verify all release assets."""

from io import BytesIO
from pathlib import Path
import shutil

import cairosvg
from PIL import Image


ROOT = Path(__file__).resolve().parents[4]
DEST = ROOT / "YiboCrafting" / "Media"
STAGE5 = Path(__file__).resolve().parent.parent / "Stage5"
STAGE6 = Path(__file__).resolve().parent.parent / "Stage6"
STEM = "YiboCraftingIcon-v2"

DEST.mkdir(parents=True, exist_ok=True)

large_svg = STAGE5 / "YiboCraftingIcon-wow-material-v1.svg"
small_svg = STAGE5 / "YiboCraftingIcon-wow-material-small-v1.svg"
master = DEST / f"{STEM}-master.svg"
small_master = DEST / f"{STEM}-small-master.svg"
shutil.copyfile(large_svg, master)
shutil.copyfile(small_svg, small_master)

for size in (24, 32):
    shutil.copyfile(
        STAGE6 / f"YiboCraftingIcon-wow-material-pixel-v1-{size}.png",
        DEST / f"{STEM}-{size}.png",
    )

for size in (64, 128, 512, 1024):
    raw = cairosvg.svg2png(url=str(master), output_width=size, output_height=size)
    image = Image.open(BytesIO(raw)).convert("RGBA")
    image.save(DEST / f"{STEM}-{size}.png")

png128 = Image.open(DEST / f"{STEM}-128.png").convert("RGBA")
png128.save(DEST / f"{STEM}.tga", format="TGA")

for size in (24, 32, 64, 128, 512, 1024):
    path = DEST / f"{STEM}-{size}.png"
    with Image.open(path) as image:
        if image.size != (size, size) or image.mode != "RGBA":
            raise AssertionError(f"Invalid PNG format: {path}")
        rgba = image.convert("RGBA")
        corners = ((0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1))
        if any(rgba.getpixel(point)[3] != 0 for point in corners):
            raise AssertionError(f"Nontransparent corner: {path}")
        if size in (24, 32):
            source = Image.open(STAGE6 / f"YiboCraftingIcon-wow-material-pixel-v1-{size}.png").convert("RGBA")
            if list(rgba.getdata()) != list(source.getdata()):
                raise AssertionError(f"Small PNG differs from approved pixel asset: {path}")
        print(f"OK {path.name}: {size}x{size} RGBA, transparent corners")

with Image.open(DEST / f"{STEM}.tga") as image:
    if image.size != (128, 128) or image.mode != "RGBA":
        raise AssertionError("Invalid TGA format")
    if list(image.getdata()) != list(png128.getdata()):
        raise AssertionError("TGA pixels differ from 128px PNG")
    print(f"OK {STEM}.tga: 128x128 RGBA, matches PNG")

for svg_path in (master, small_master):
    if 'viewBox="0 0 32 32"' not in svg_path.read_text(encoding="utf-8"):
        raise AssertionError(f"SVG master missing expected viewBox: {svg_path}")
    print(f"OK {svg_path.name}: editable 32px SVG master")
