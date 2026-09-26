from io import BytesIO
from pathlib import Path

import cairosvg
from PIL import Image


ROOT = Path(__file__).resolve().parents[3]
OUTPUT = ROOT / "YiboBuilds" / "Media" / "YiboBuildsSocketBases.tga"
TILE_SIZE = 64

# Keep the socket silhouettes readable at the 16px equipment-view size. The
# center is either a dark empty cavity or transparent beneath the real gem icon.
SOCKETS = [
    ("native", "#cf3542", "#ff7279"),
    ("native", "#c79a32", "#ffdb71"),
    ("native", "#347ec2", "#77ccff"),
    ("native", "#829ba5", "#d7f1f5"),
    ("meta", "#d3a62d", "#ffe27a"),
    ("forged", "#8799a5", "#d5e0e5"),
    ("sha", "#933ce0", "#cf88ff"),
    ("native", "#829ba5", "#d7f1f5"),
]


def svg_tile(shape, rim, highlight, empty):
    cavity = '<circle cx="32" cy="32" r="14" fill="#09131d"/>' if empty else ""
    if shape == "native":
        base = f'''
          <circle cx="32" cy="32" r="27" fill="#080d13"/>
          <circle cx="32" cy="32" r="24" fill="{rim}" stroke="#e8f2f5" stroke-width="2"/>
          <circle cx="32" cy="32" r="16" fill="#080d13" stroke="{highlight}" stroke-width="3"/>
          <path d="M17 12 Q32 5 47 12" fill="none" stroke="#ffffff" stroke-opacity=".42" stroke-width="2"/>
          {cavity}'''
    elif shape == "meta":
        base = f'''
          <path d="M32 3 39 21 59 22 44 35 49 56 32 45 15 56 20 35 5 22 25 21Z" fill="#080d13"/>
          <path d="M32 6 38 23 56 24 42 35 47 53 32 43 17 53 22 35 8 24 26 23Z" fill="{rim}" stroke="#f6e3a1" stroke-width="2" stroke-linejoin="round"/>
          <path d="M32 19 36 28 46 29 39 35 41 45 32 40 23 45 25 35 18 29 28 28Z" fill="#080d13" stroke="{highlight}" stroke-width="2" stroke-linejoin="round"/>
          {cavity}'''
    elif shape == "forged":
        base = f'''
          <path d="M15 4H49L60 15V49L49 60H15L4 49V15Z" fill="#080d13"/>
          <path d="M16 7H48L57 16V48L48 57H16L7 48V16Z" fill="{rim}" stroke="#e6eff2" stroke-width="2" stroke-linejoin="round"/>
          <path d="M19 15H45L49 19V45L45 49H19L15 45V19Z" fill="#080d13" stroke="{highlight}" stroke-width="2" stroke-linejoin="round"/>
          {cavity}'''
    else:
        base = f'''
          <path d="M30 4 55 13 49 30 56 43 34 60 8 49 18 34 5 22 24 17Z" fill="#080d13"/>
          <path d="M30 7 52 15 46 31 52 42 33 56 12 47 21 34 9 23 26 19Z" fill="{rim}" stroke="#e9d7ff" stroke-width="2" stroke-linejoin="round"/>
          <path d="M30 18 42 23 39 33 44 41 32 49 19 43 25 33 18 26Z" fill="#080d13" stroke="{highlight}" stroke-width="2" stroke-linejoin="round"/>
          {cavity}'''
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">{base}</svg>'


def render_atlas():
    atlas = Image.new("RGBA", (TILE_SIZE * len(SOCKETS), TILE_SIZE * 2), (0, 0, 0, 0))
    for column, (shape, rim, highlight) in enumerate(SOCKETS):
        for row, empty in enumerate((True, False)):
            rendered = cairosvg.svg2png(
                bytestring=svg_tile(shape, rim, highlight, empty).encode("utf-8"),
                output_width=TILE_SIZE,
                output_height=TILE_SIZE,
            )
            tile = Image.open(BytesIO(rendered)).convert("RGBA")
            atlas.alpha_composite(tile, (column * TILE_SIZE, row * TILE_SIZE))

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(OUTPUT, format="TGA")


if __name__ == "__main__":
    render_atlas()
