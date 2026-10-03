"""Export approved YiboCrafting icon assets and verify dimensions and alpha."""

from io import BytesIO
from pathlib import Path
import re
import shutil

import cairosvg
from PIL import Image

ROOT = Path(__file__).resolve().parents[4]
DEST = ROOT / "YiboCrafting" / "Media"
STAGE5 = Path(__file__).resolve().parent.parent / "Stage5"
STAGE6 = Path(__file__).resolve().parent.parent / "Stage6"
STEM = "YiboCraftingIcon-v1"

DEST.mkdir(parents=True, exist_ok=True)

source = (STAGE5 / "YiboCraftingIcon-color-d.svg").read_text(encoding="utf-8")
source = re.sub(r"<title>.*?</title>", "<title>YiboCrafting icon</title>", source)
source = re.sub(r"<desc>.*?</desc>", "<desc>Open recipe book within a Yibo hexagonal badge.</desc>", source)
source = re.sub(r"\s*<!--.*?-->", "", source, flags=re.DOTALL)
master = DEST / f"{STEM}-master.svg"
master.write_text(source, encoding="utf-8")

for size in (24, 32):
    shutil.copyfile(
        STAGE6 / f"YiboCraftingIcon-A-pixel-preview-{size}.png",
        DEST / f"{STEM}-{size}.png",
    )

for size in (64, 128, 512, 1024):
    raw = cairosvg.svg2png(bytestring=source.encode("utf-8"), output_width=size, output_height=size)
    im = Image.open(BytesIO(raw)).convert("RGBA")
    im.save(DEST / f"{STEM}-{size}.png")

png128 = Image.open(DEST / f"{STEM}-128.png").convert("RGBA")
png128.save(DEST / f"{STEM}.tga", format="TGA")

for size in (24, 32, 64, 128, 512, 1024):
    path = DEST / f"{STEM}-{size}.png"
    with Image.open(path) as im:
        if im.size != (size, size) or im.mode != "RGBA":
            raise AssertionError(f"Invalid PNG format: {path}")
        rgba = im.convert("RGBA")
        corners = [(0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)]
        if any(rgba.getpixel(point)[3] != 0 for point in corners):
            raise AssertionError(f"Nontransparent corner: {path}")
        print(f"OK {path.name}: {size}x{size} RGBA, transparent corners")

with Image.open(DEST / f"{STEM}.tga") as im:
    if im.size != (128, 128) or im.mode != "RGBA":
        raise AssertionError("Invalid TGA format")
    if list(im.getdata()) != list(png128.getdata()):
        raise AssertionError("TGA pixels differ from 128px PNG")
    print(f"OK {STEM}.tga: 128x128 RGBA, matches PNG")

if "viewBox=\"0 0 32 32\"" not in master.read_text(encoding="utf-8"):
    raise AssertionError("SVG master missing expected viewBox")
print(f"OK {master.name}: editable 32px SVG master")
