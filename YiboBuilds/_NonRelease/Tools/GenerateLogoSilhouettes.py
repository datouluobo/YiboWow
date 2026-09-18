from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import math

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "Media" / "Concepts" / "Stage2"
OUT.mkdir(parents=True, exist_ok=True)

S = 10
INK = (241, 246, 245, 255)
MID = (137, 157, 161, 255)
FRAME = (47, 62, 68, 255)


def pts(values):
    return [(round(x * S), round(y * S)) for x, y in values]


def ellipse(d, box, fill):
    d.ellipse(tuple(round(v * S) for v in box), fill=fill)


def rr(d, box, radius, fill=None, outline=None, width=1):
    d.rounded_rectangle(tuple(round(v * S) for v in box), radius=round(radius * S), fill=fill,
                        outline=outline, width=round(width * S))


def line(d, values, fill, width):
    d.line(pts(values), fill=fill, width=round(width * S), joint="curve")


def bust(d, cx, cy, scale=1.0, fill=INK):
    r = 2.45 * scale
    ellipse(d, (cx-r, cy-r, cx+r, cy+r), fill)
    w, h = 5.8 * scale, 3.8 * scale
    rr(d, (cx-w, cy+r-0.2*scale, cx+w, cy+r+h), 2.0*scale, fill=fill)


def frame(d):
    outer = [(16, 1.4), (29.1, 8.8), (29.1, 23.2), (16, 30.6), (2.9, 23.2), (2.9, 8.8)]
    inner = [(16, 3.4), (27.2, 9.8), (27.2, 22.2), (16, 28.6), (4.8, 22.2), (4.8, 9.8)]
    line(d, outer + [outer[0]], FRAME, 2.2)
    line(d, inner + [inner[0]], MID, 1.0)


def render(draw_symbol):
    im = Image.new("RGBA", (32*S, 32*S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    frame(d)
    draw_symbol(d)
    return im.resize((32, 32), Image.Resampling.LANCZOS)


def a_triad(d):
    bust(d, 10.0, 12.0, .72, MID); bust(d, 22.0, 12.0, .72, MID)
    bust(d, 16.0, 11.0, 1.0, INK)
    rr(d, (8.0, 22.0, 24.0, 25.4), 1.4, fill=INK)


def b_fan_cards(d):
    left = [(7.0, 9.2), (13.0, 7.2), (16.6, 21.5), (10.4, 23.0)]
    right = [(19.0, 7.2), (25.0, 9.2), (21.6, 23.0), (15.4, 21.5)]
    d.polygon(pts(left), fill=MID); d.polygon(pts(right), fill=MID)
    rr(d, (11.3, 6.2, 20.7, 24.3), 1.8, fill=INK)
    ellipse(d, (14.2, 9.0, 17.8, 12.6), FRAME)
    rr(d, (13.5, 13.2, 18.5, 17.5), 1.7, fill=FRAME)


def c_archive_tray(d):
    bust(d, 9.8, 12.0, .68, MID); bust(d, 16.0, 10.5, .86, INK); bust(d, 22.2, 12.0, .68, MID)
    d.polygon(pts([(6.8, 19.0), (25.2, 19.0), (22.5, 25.2), (9.5, 25.2)]), fill=INK)
    rr(d, (10.6, 20.3, 21.4, 22.0), .7, fill=FRAME)


def d_profile_shields(d):
    d.polygon(pts([(8.0, 8.0), (15.0, 10.2), (14.0, 22.0), (10.7, 25.0), (7.2, 22.0)]), fill=MID)
    d.polygon(pts([(24.0, 8.0), (17.0, 10.2), (18.0, 22.0), (21.3, 25.0), (24.8, 22.0)]), fill=MID)
    d.polygon(pts([(16.0, 6.0), (22.0, 8.2), (21.0, 20.8), (16.0, 25.8), (11.0, 20.8), (10.0, 8.2)]), fill=INK)
    ellipse(d, (13.5, 9.0, 18.5, 14.0), FRAME)
    rr(d, (12.5, 14.3, 19.5, 19.0), 2.0, fill=FRAME)


def e_linked_roster(d):
    for cx, cy in [(9.0, 11.0), (16.0, 8.5), (23.0, 11.0)]:
        ellipse(d, (cx-2.7, cy-2.7, cx+2.7, cy+2.7), INK if cx == 16 else MID)
        line(d, [(cx, cy+2.4), (cx, 19.0)], INK if cx == 16 else MID, 2.0)
    line(d, [(9.0, 19.0), (23.0, 19.0)], INK, 2.2)
    d.polygon(pts([(16, 18), (20, 22), (16, 26), (12, 22)]), fill=INK)


def f_stepped_tabs(d):
    rr(d, (6.7, 13.0, 12.2, 24.5), 1.3, fill=MID)
    rr(d, (13.2, 7.2, 18.8, 24.5), 1.3, fill=INK)
    rr(d, (19.8, 10.2, 25.3, 24.5), 1.3, fill=MID)
    ellipse(d, (8.0, 15.0, 10.9, 17.9), FRAME)
    ellipse(d, (14.4, 9.2, 17.6, 12.4), FRAME)
    ellipse(d, (21.1, 12.2, 24.0, 15.1), FRAME)


def g_cluster_badge(d):
    ellipse(d, (6.0, 9.0, 14.0, 17.0), MID); ellipse(d, (18.0, 9.0, 26.0, 17.0), MID)
    ellipse(d, (10.4, 6.0, 21.6, 17.2), INK)
    d.polygon(pts([(8.0, 24.5), (9.0, 17.0), (16.0, 14.0), (23.0, 17.0), (24.0, 24.5)]), fill=INK)
    line(d, [(11.0, 21.8), (21.0, 21.8)], FRAME, 1.7)


def h_roster_strip(d):
    for cx in (9.0, 16.0, 23.0):
        bust(d, cx, 11.8, .57, INK if cx == 16 else MID)
    rr(d, (6.0, 18.0, 26.0, 24.2), 1.8, fill=INK)
    for cx in (9.0, 16.0, 23.0): ellipse(d, (cx-1.0, 20.1, cx+1.0, 22.1), FRAME)


def i_portrait_fan(d):
    d.polygon(pts([(5.8, 10.2), (12.0, 6.6), (17.0, 21.3), (10.2, 24.0)]), fill=MID)
    d.polygon(pts([(20.0, 6.6), (26.2, 10.2), (21.8, 24.0), (15.0, 21.3)]), fill=MID)
    rr(d, (11.2, 5.8, 20.8, 24.8), 1.5, fill=INK)
    bust(d, 16.0, 10.2, .60, FRAME)


def j_catalog_tabs(d):
    rr(d, (6.5, 10.0, 12.4, 24.7), 1.1, fill=MID)
    rr(d, (19.6, 10.0, 25.5, 24.7), 1.1, fill=MID)
    rr(d, (10.8, 6.2, 21.2, 25.0), 1.6, fill=INK)
    bust(d, 16.0, 10.0, .70, FRAME)
    rr(d, (13.0, 18.6, 19.0, 20.3), .7, fill=FRAME)


CANDIDATES = [
    ("A", "Triad", a_triad), ("B", "Fan Cards", b_fan_cards),
    ("C", "Archive Tray", c_archive_tray), ("D", "Profile Shields", d_profile_shields),
    ("E", "Linked Roster", e_linked_roster), ("F", "Stepped Tabs", f_stepped_tabs),
    ("G", "Cluster Badge", g_cluster_badge), ("H", "Roster Strip", h_roster_strip),
    ("I", "Portrait Fan", i_portrait_fan), ("J", "Catalog Tabs", j_catalog_tabs),
]

icons = {}
for code, name, fn in CANDIDATES:
    icon32 = render(fn)
    icon24 = icon32.resize((24, 24), Image.Resampling.LANCZOS)
    icon32.save(OUT / f"YiboBuilds-concept-{code.lower()}-32.png")
    icon24.save(OUT / f"YiboBuilds-concept-{code.lower()}-24.png")
    icons[code] = (name, icon32, icon24)

cell_w, cell_h = 184, 104
sheet = Image.new("RGBA", (cell_w * 2, cell_h * 5), (18, 23, 26, 255))
d = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("arial.ttf", 15)
    small = ImageFont.truetype("arial.ttf", 11)
except OSError:
    font = ImageFont.load_default(); small = ImageFont.load_default()

for idx, (code, name, _) in enumerate(CANDIDATES):
    col, row = idx % 2, idx // 2
    x, y = col * cell_w, row * cell_h
    d.rounded_rectangle((x+6, y+6, x+cell_w-6, y+cell_h-6), radius=8, fill=(27, 35, 39, 255), outline=(62, 78, 84, 255), width=1)
    d.text((x+14, y+12), f"{code}  {name}", font=font, fill=(235, 242, 241, 255))
    d.text((x+18, y+78), "32 px", font=small, fill=(150, 168, 170, 255))
    d.text((x+103, y+78), "24 px", font=small, fill=(150, 168, 170, 255))
    p32 = icons[code][1].resize((64, 64), Image.Resampling.NEAREST)
    p24 = icons[code][2].resize((48, 48), Image.Resampling.NEAREST)
    sheet.alpha_composite(p32, (x+43, y+30))
    sheet.alpha_composite(p24, (x+120, y+38))

sheet.save(OUT / "YiboBuilds-stage2-silhouettes-preview.png")
print(OUT / "YiboBuilds-stage2-silhouettes-preview.png")
