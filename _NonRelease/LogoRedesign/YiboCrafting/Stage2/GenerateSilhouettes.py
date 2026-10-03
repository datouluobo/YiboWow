"""Stage 2 only: grayscale book silhouettes at actual 24/32 px sizes."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent
S = 12
WHITE = (242, 248, 247, 255)
MID = (157, 183, 185, 255)
DARK = (37, 55, 60, 255)
FRAME = (99, 126, 132, 255)


def points(seq):
    return [(round(x * S), round(y * S)) for x, y in seq]


def polygon(d, seq, fill):
    d.polygon(points(seq), fill=fill)


def line(d, seq, fill, width):
    d.line(points(seq), fill=fill, width=round(width * S), joint="curve")


def frame(d):
    p = [(16, 1.2), (29.5, 8.6), (29.5, 23.4), (16, 30.8), (2.5, 23.4), (2.5, 8.6)]
    line(d, p + [p[0]], FRAME, 2.3)


def a_open_v(d):
    polygon(d, [(5, 9), (14, 10), (16, 13), (18, 10), (27, 9), (27, 23), (18, 24), (16, 26), (14, 24), (5, 23)], DARK)
    polygon(d, [(7, 10), (14, 12), (15, 15), (15, 23), (7, 21)], WHITE)
    polygon(d, [(25, 10), (18, 12), (17, 15), (17, 23), (25, 21)], MID)
    line(d, [(16, 14), (16, 24)], WHITE, 1.5)


def b_diagonal_open(d):
    polygon(d, [(5, 16), (12, 7), (17, 10), (24, 7), (28, 13), (20, 24), (16, 22), (11, 26)], DARK)
    polygon(d, [(7, 16), (12, 9), (16, 12), (15, 20), (11, 23)], WHITE)
    polygon(d, [(18, 12), (24, 9), (26, 13), (19, 22), (17, 20)], MID)
    line(d, [(16, 12), (16, 21)], WHITE, 1.8)


def c_closed_book(d):
    polygon(d, [(9, 5), (24, 9), (24, 25), (9, 21)], DARK)
    polygon(d, [(10, 6), (22, 10), (22, 23), (10, 19)], WHITE)
    polygon(d, [(7, 8), (10, 6), (10, 19), (7, 22)], MID)
    line(d, [(9, 23), (23, 27)], MID, 2)


def d_fanned_pages(d):
    polygon(d, [(5, 8), (14, 10), (17, 23), (8, 21)], MID)
    polygon(d, [(11, 6), (22, 9), (22, 24), (11, 21)], WHITE)
    polygon(d, [(18, 10), (27, 8), (26, 22), (21, 24)], MID)
    line(d, [(10, 23), (21, 26)], DARK, 2.3)


def e_bookmark(d):
    polygon(d, [(6, 8), (12, 5), (25, 8), (25, 25), (12, 22), (6, 25)], DARK)
    polygon(d, [(8, 9), (12, 7), (23, 10), (23, 23), (12, 20), (8, 22)], WHITE)
    polygon(d, [(17, 6), (21, 7), (21, 15), (19, 13), (17, 15)], MID)
    line(d, [(12, 7), (12, 21)], DARK, 1.7)


def f_stacked_folios(d):
    polygon(d, [(6, 13), (19, 8), (24, 20), (11, 25)], DARK)
    polygon(d, [(7, 11), (20, 6), (25, 19), (12, 24)], MID)
    polygon(d, [(8, 9), (21, 5), (26, 17), (13, 22)], WHITE)
    line(d, [(8, 9), (13, 22)], DARK, 2)


def g_arch_open(d):
    polygon(d, [(5, 12), (11, 7), (16, 12), (21, 7), (27, 12), (26, 25), (20, 22), (16, 26), (12, 22), (6, 25)], DARK)
    polygon(d, [(7, 12), (11, 9), (15, 13), (15, 23), (11, 20), (8, 22)], WHITE)
    polygon(d, [(25, 12), (21, 9), (17, 13), (17, 23), (21, 20), (24, 22)], MID)


def h_spine_forward(d):
    polygon(d, [(11, 5), (22, 8), (25, 11), (25, 25), (14, 22), (10, 24), (7, 21), (7, 8)], DARK)
    polygon(d, [(10, 7), (21, 10), (21, 23), (10, 20)], WHITE)
    polygon(d, [(7, 8), (10, 7), (10, 20), (7, 22)], MID)
    polygon(d, [(21, 10), (24, 11), (24, 23), (21, 23)], MID)


def i_corner_fold(d):
    polygon(d, [(7, 6), (19, 5), (26, 12), (26, 24), (7, 25)], DARK)
    polygon(d, [(9, 8), (18, 7), (18, 14), (24, 14), (24, 22), (9, 23)], WHITE)
    polygon(d, [(18, 7), (24, 13), (18, 13)], MID)
    line(d, [(11, 18), (19, 18)], MID, 2)


def j_reciped_book(d):
    polygon(d, [(8, 5), (23, 7), (25, 24), (10, 26), (7, 22)], DARK)
    polygon(d, [(10, 7), (21, 9), (22, 22), (10, 24)], WHITE)
    polygon(d, [(7, 9), (10, 7), (10, 24), (7, 22)], MID)
    polygon(d, [(15, 13), (18, 16), (15, 19), (12, 16)], DARK)


CANDIDATES = [
    ("A", "Open V", a_open_v, "对称展开的书页", 4, "中心 V 形书脊"),
    ("B", "Diagonal Open", b_diagonal_open, "斜向展开的书页", 4, "向右上打开的姿态"),
    ("C", "Closed Book", c_closed_book, "斜置合拢的书册", 3, "厚书脊和页边"),
    ("D", "Fanned Pages", d_fanned_pages, "扇开的三层书页", 4, "错层翻页"),
    ("E", "Bookmark", e_bookmark, "带宽书签的书册", 4, "顶端书签缺口"),
    ("F", "Stacked Folios", f_stacked_folios, "斜叠的配方册页", 4, "阶梯形页缘"),
    ("G", "Arched Open", g_arch_open, "弧形展开的书册", 4, "外张书页与中缝"),
    ("H", "Spine Forward", h_spine_forward, "书脊朝前的厚册", 4, "明显厚度与封面"),
    ("I", "Corner Fold", i_corner_fold, "翻角的单页册封", 4, "右上翻页折角"),
    ("J", "Index Book", j_reciped_book, "带大索引标记的书册", 4, "封面中心菱形"),
]


def render(symbol, size):
    canvas = Image.new("RGBA", (32 * S, 32 * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(canvas)
    frame(d)
    symbol(d)
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def font(size):
    for name in ("msyh.ttc", "Microsoft YaHei.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


sheet = Image.new("RGB", (900, 1040), (19, 25, 29))
d = ImageDraw.Draw(sheet)
title_font, label_font = font(21), font(17)
for idx, (code, name, symbol, outline, blocks, cue) in enumerate(CANDIDATES):
    col, row = idx % 2, idx // 2
    x, y = col * 450 + 12, row * 208 + 10
    d.rounded_rectangle((x, y, x + 426, y + 188), 12, fill=(31, 40, 44), outline=(75, 93, 99), width=2)
    d.text((x + 16, y + 11), f"{code}  {name}", font=title_font, fill=(239, 244, 244))
    d.text((x + 16, y + 46), f"{outline} · {blocks}块", font=label_font, fill=(175, 193, 194))
    d.text((x + 16, y + 76), f"识别点：{cue}", font=label_font, fill=(175, 193, 194))
    icon32, icon24 = render(symbol, 32), render(symbol, 24)
    icon32.save(OUT / f"YiboCrafting-concept-{code.lower()}-32.png")
    icon24.save(OUT / f"YiboCrafting-concept-{code.lower()}-24.png")
    sheet.paste(icon32.resize((96, 96), Image.Resampling.NEAREST), (x + 192, y + 79), icon32.resize((96, 96), Image.Resampling.NEAREST))
    sheet.paste(icon24.resize((72, 72), Image.Resampling.NEAREST), (x + 319, y + 90), icon24.resize((72, 72), Image.Resampling.NEAREST))
    d.text((x + 212, y + 162), "32px", font=label_font, fill=(175, 193, 194))
    d.text((x + 331, y + 162), "24px", font=label_font, fill=(175, 193, 194))

sheet.save(OUT / "YiboCrafting-stage2-silhouettes-preview.png")
print(OUT / "YiboCrafting-stage2-silhouettes-preview.png")
