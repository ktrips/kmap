"""Asia・America の古地図を、OpenStreetMap のデータから各地域の古地図の様式で描く。

    python3 render_world.py [city ...]

描画の共通部分（投影・水面・道路・建物・方位記号・配置）は render.py を使い、
都市ごとの配色・縁取り・題名の枠・飾りだけを STYLES で切り替える。
"""
import math
import random
import sys

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

import render as R
from render import S, rgb, font, JP_FONT

BOUNDS = {
    "beijing": (39.862, 116.333, 39.952, 116.450),
    "xian": (34.212, 108.898, 34.287, 108.9885),
    "lhasa": (29.632, 91.086, 29.679, 91.140),
    "angkor": (13.404, 103.848, 13.447, 103.8923),
    "delhi": (28.640, 77.215, 28.672, 77.2515),
    "isfahan": (32.640, 51.656, 32.674, 51.6965),
    "jerusalem": (31.767, 35.2185, 31.789, 35.2444),
    "boston": (42.348, -71.0745, 42.372, -71.042),
    "newyork": (40.698, -74.024, 40.718, -73.9977),
    "mexico": (19.425, -99.1478, 19.445, -99.1266),
    "cusco": (-13.527, -71.9895, -13.504, -71.9659),
    "buenosaires": (-34.626, -58.389, -34.597, -58.354),
    "paris": (48.880, 2.3290, 48.892, 2.3472),
    "london": (51.4990, -0.1080, 51.5208, -0.0730),
}

CHECKPOINTS = {
    "beijing": [(39.9163, 116.3908), (39.9075, 116.3910), (39.8822, 116.4007), (39.9245, 116.3904), (39.9393, 116.3897)],
    "xian": [(34.2610, 108.9423), (34.2618, 108.9388), (34.2531, 108.9423), (34.2550, 108.9481), (34.2198, 108.9594)],
    "lhasa": [(29.6576, 91.1170), (29.6529, 91.1318), (29.6520, 91.1330), (29.6546, 91.0900), (29.6586, 91.1304)],
    "angkor": [(13.4125, 103.8666), (13.4288, 103.8597), (13.4412, 103.8591), (13.4349, 103.8896), (13.4238, 103.8562)],
    "delhi": [(28.6561, 77.2408), (28.6507, 77.2330), (28.6560, 77.2322), (28.6567, 77.2223), (28.6668, 77.2291)],
    "isfahan": [(32.6581, 51.6774), (32.6548, 51.6784), (32.6574, 51.6720), (32.6446, 51.6675), (32.6700, 51.6855)],
    "jerusalem": [(31.7780, 35.2353), (31.7767, 35.2344), (31.7784, 35.2298), (31.7766, 35.2273), (31.7817, 35.2305)],
    "boston": [(42.3587, -71.0575), (42.3600, -71.0562), (42.3637, -71.0537), (42.3663, -71.0544), (42.3586, -71.0639)],
    "newyork": [(40.7035, -74.0166), (40.7034, -74.0113), (40.7073, -74.0103), (40.7081, -74.0122), (40.7127, -74.0059)],
    "mexico": [(19.4326, -99.1332), (19.4344, -99.1331), (19.4351, -99.1314), (19.4355, -99.1413), (19.4373, -99.1339)],
    "cusco": [(-13.5168, -71.9788), (-13.5203, -71.9751), (-13.5157, -71.9765), (-13.5152, -71.9742), (-13.5068, -71.9802)],
    "buenosaires": [(-34.6084, -58.3722), (-34.6089, -58.3737), (-34.6205, -58.3718), (-34.6011, -58.3832), (-34.6037, -58.3816)],
    "paris": [(48.8861, 2.3375), (48.8865, 2.3339), (48.8880, 2.3406), (48.8877, 2.3363), (48.8886, 2.3400), (48.8841, 2.3324)],
    "london": [(51.5081, -0.0972), (51.5074, -0.0939), (51.5061, -0.0896), (51.5080, -0.0877), (51.5138, -0.0985), (51.5082, -0.0762)],
}


# ---------------------------------------------------------------- 縁取りの文様

def border_meander(color, bg):
    """中国の回紋（雷文）。"""
    def draw(d, band, pal):
        d.rectangle([6, 6, S - 7, S - 7], outline=bg, width=band - 12)
        step = band - 16
        def spiral(x, y, horiz):
            s = step
            pts = [(0, s), (0, 0), (s, 0), (s, s * 0.75), (s * 0.25, s * 0.75), (s * 0.25, s * 0.25), (s * 0.6, s * 0.25), (s * 0.6, s * 0.5)]
            if horiz:
                p = [(x + px, y + py) for px, py in pts]
            else:
                p = [(x + py, y + px) for px, py in pts]
            d.line(p, fill=color, width=4)
        for i in range(8, S - step, step + 6):
            spiral(i, 8, True)
            spiral(i, S - 8 - step, True)
            spiral(8, i, False)
            spiral(S - 8 - step, i, False)
    return draw


def border_prayer_flags():
    """チベットの祈祷旗（タルチョ）の五色。"""
    colors = [rgb("2f5fa8"), (246, 244, 236), rgb("b8342c"), rgb("3f7d4a"), rgb("e0b030")]
    def draw(d, band, pal):
        step = 56
        for k, i in enumerate(range(0, S, step)):
            c = colors[k % 5]
            d.rectangle([i, 6, i + step, band - 6], fill=c)
            d.rectangle([i, S - band + 6, i + step, S - 6], fill=c)
            d.rectangle([6, i, band - 6, i + step], fill=colors[(k + 2) % 5])
            d.rectangle([S - band + 6, i, S - 6, i + step], fill=colors[(k + 2) % 5])
        d.rectangle([4, 4, S - 5, S - 5], outline=pal["ink"], width=4)
    return draw


def border_steps(color, bg):
    """アステカの階段雷文（シカルコリウキ）。"""
    def draw(d, band, pal):
        d.rectangle([6, 6, S - 7, S - 7], outline=bg, width=band - 12)
        u = (band - 20) / 4
        for i in range(0, S, int(u * 8)):
            for (ox, oy, horiz, flip) in ((i, 10, True, False), (i, S - 10, True, True), (10, i, False, False), (S - 10, i, False, True)):
                pts = [(0, 0), (u * 2, 0), (u * 2, u), (u * 3, u), (u * 3, u * 2), (u * 4, u * 2), (u * 4, u * 4), (0, u * 4)]
                out = []
                for px, py in pts:
                    py = -py if flip else py
                    out.append((ox + px, oy + py) if horiz else (ox + (py if not flip else py), oy + px))
                d.polygon(out, fill=color)
    return draw


def border_tocapu(rng):
    """インカの織物の文様（トカプ）。小さな四角に幾何学模様を並べる。"""
    fills = [rgb("a8322a"), rgb("e0a93a"), rgb("2b2622"), rgb("f1e6cc"), rgb("3f6e8c")]
    def draw(d, band, pal):
        cell = (band - 12) / 2
        for pos in range(0, S, int(cell)):
            for row in range(2):
                for (x, y) in ((pos, 6 + row * cell), (pos, S - 6 - (row + 1) * cell), (6 + row * cell, pos), (S - 6 - (row + 1) * cell, pos)):
                    c1, c2 = rng.choice(len(fills), 2, replace=False)
                    d.rectangle([x, y, x + cell, y + cell], fill=fills[c1], outline=pal["ink"])
                    m = rng.integers(0, 3)
                    if m == 0:
                        d.polygon([(x + cell / 2, y + 3), (x + cell - 3, y + cell / 2), (x + cell / 2, y + cell - 3), (x + 3, y + cell / 2)], fill=fills[c2])
                    elif m == 1:
                        d.rectangle([x + cell / 4, y + cell / 4, x + cell * 3 / 4, y + cell * 3 / 4], fill=fills[c2])
                    else:
                        d.line([(x, y), (x + cell, y + cell)], fill=fills[c2], width=4)
                        d.line([(x + cell, y), (x, y + cell)], fill=fills[c2], width=4)
    return draw


def border_stars(color, bg):
    """ペルシャのタイルの八芒星。"""
    def draw(d, band, pal):
        d.rectangle([6, 6, S - 7, S - 7], outline=bg, width=band - 12)
        r = (band - 16) / 2
        for i in range(int(r), S, int(r * 2.4)):
            for (x, y) in ((i, band / 2), (i, S - band / 2), (band / 2, i), (S - band / 2, i)):
                d.polygon(R.star_path(x, y, r, r * 0.55, 8), fill=color, outline=pal["ink"])
    return draw


def border_arches(color, outline):
    """ムガルの多弁アーチ（赤砂岩に白大理石の縁）。"""
    def draw(d, band, pal):
        d.rectangle([6, 6, S - 7, S - 7], outline=color, width=band - 12)
        w = band * 0.9
        for i in range(0, S, int(w)):
            for (x, y, horiz) in ((i, band / 2, True), (i, S - band / 2, True), (band / 2, i, False), (S - band / 2, i, False)):
                if horiz:
                    d.arc([x + 6, y - w * 0.35, x + w - 6, y + w * 0.45], 180, 360, fill=outline, width=4)
                else:
                    d.arc([x - w * 0.35, y + 6, x + w * 0.45, y + w - 6], 90, 270, fill=outline, width=4)
    return draw


def border_lotus(color, bg):
    """クメールの蓮弁の連続文様。"""
    def draw(d, band, pal):
        d.rectangle([6, 6, S - 7, S - 7], outline=bg, width=band - 12)
        w = band * 0.7
        for i in range(0, S, int(w)):
            for (x, y, horiz) in ((i, band / 2, True), (i, S - band / 2, True), (band / 2, i, False), (S - band / 2, i, False)):
                if horiz:
                    d.ellipse([x + 4, y - band * 0.32, x + w - 4, y + band * 0.32], fill=color, outline=pal["ink"])
                else:
                    d.ellipse([x - band * 0.32, y + 4, x + band * 0.32, y + w - 4], fill=color, outline=pal["ink"])
    return draw


def border_graduated(dark, light):
    """18世紀の英国の都市図にある、目盛りのような白黒の細い帯。"""
    def draw(d, band, pal):
        d.rectangle([6, 6, S - 7, S - 7], outline=pal["ink"], width=3)
        step = 48
        for i in range(0, S, step):
            f = dark if (i // step) % 2 == 0 else light
            d.rectangle([i, 14, i + step, band - 12], fill=f)
            d.rectangle([i, S - band + 12, i + step, S - 14], fill=f)
            d.rectangle([14, i, band - 12, i + step], fill=f)
            d.rectangle([S - band + 12, i, S - 14, i + step], fill=f)
    return draw


def border_roundels(color, bg):
    """中世の聖地図風の、円を連ねた縁取り。"""
    def draw(d, band, pal):
        d.rectangle([6, 6, S - 7, S - 7], outline=bg, width=band - 12)
        r = (band - 18) / 2
        for i in range(int(r) + 8, S, int(r * 2.2)):
            for (x, y) in ((i, band / 2), (i, S - band / 2), (band / 2, i), (S - band / 2, i)):
                d.ellipse([x - r, y - r, x + r, y + r], outline=color, width=4)
                d.ellipse([x - r * 0.35, y - r * 0.35, x + r * 0.35, y + r * 0.35], fill=color)
    return draw


def border_stripes(colors):
    def draw(d, band, pal):
        w = band / len(colors)
        for k, c in enumerate(colors):
            o = 4 + k * w
            d.rectangle([o, o, S - 1 - o, S - 1 - o], outline=c, width=int(w) + 1)
    return draw


def border_art_nouveau(line, leaf, bg):
    """アール・ヌーヴォーの、しなやかにうねる蔓と葉（ミュシャのポスターの縁取り風）。"""
    def draw(d, band, pal):
        d.rectangle([6, 6, S - 7, S - 7], outline=bg, width=band - 12)
        amp = band * 0.22
        for horiz, fixed in ((True, band / 2), (True, S - band / 2), (False, band / 2), (False, S - band / 2)):
            pts = []
            for t in range(0, S + 1, 8):
                off = amp * math.sin(t / 55)
                pts.append((t, fixed + off) if horiz else (fixed + off, t))
            d.line(pts, fill=line, width=4)
            for t in range(40, S, 110):
                off = amp * math.sin(t / 55)
                cx, cy = (t, fixed + off) if horiz else (fixed + off, t)
                d.ellipse([cx - 9, cy - 5, cx + 9, cy + 5] if horiz else [cx - 5, cy - 9, cx + 5, cy + 9], fill=leaf, outline=line)
        for (x, y) in ((band / 2, band / 2), (S - band / 2, band / 2), (band / 2, S - band / 2), (S - band / 2, S - band / 2)):
            d.ellipse([x - 16, y - 16, x + 16, y + 16], fill=leaf, outline=line, width=3)
    return draw


def border_tudor(rose, bg):
    """テューダー朝の、バラを並べた帯と組紐（ストラップワーク）。"""
    def draw(d, band, pal):
        d.rectangle([6, 6, S - 7, S - 7], outline=bg, width=band - 12)
        r = (band - 18) / 2
        for i in range(int(r) + 10, S, int(r * 3)):
            for (x, y) in ((i, band / 2), (i, S - band / 2), (band / 2, i), (S - band / 2, i)):
                tudor_rose(d, x, y, r, rose, pal["ink"])
        d.rectangle([band - 10, band - 10, S - band + 9, S - band + 9], outline=pal["ink"], width=2)
    return draw


def tudor_rose(d, cx, cy, r, red, ink):
    for i in range(5):
        a = -math.pi / 2 + i * math.tau / 5
        px, py = cx + r * 0.55 * math.cos(a), cy + r * 0.55 * math.sin(a)
        d.ellipse([px - r * 0.48, py - r * 0.48, px + r * 0.48, py + r * 0.48], fill=red, outline=ink)
    for i in range(5):
        a = -math.pi / 2 + math.pi / 5 + i * math.tau / 5
        px, py = cx + r * 0.3 * math.cos(a), cy + r * 0.3 * math.sin(a)
        d.ellipse([px - r * 0.28, py - r * 0.28, px + r * 0.28, py + r * 0.28], fill=(246, 242, 232), outline=ink)
    d.ellipse([cx - r * 0.16, cy - r * 0.16, cx + r * 0.16, cy + r * 0.16], fill=rgb("d9a42a"), outline=ink)


# ---------------------------------------------------------------- 題名の枠の紋章

def emblem_palette():
    """画家のパレットと絵筆。"""
    def draw(d, x, y, size, pal):
        cx, cy = x + size / 2, y + size / 2
        d.ellipse([x + 6, y + size * 0.15, x + size - 6, y + size * 0.85], fill=(236, 214, 170), outline=pal["ink"], width=3)
        d.ellipse([cx + size * 0.12, cy + size * 0.05, cx + size * 0.28, cy + size * 0.2], fill=(246, 240, 226), outline=pal["ink"])
        for k, c in enumerate([rgb("b8302a"), rgb("e0b030"), rgb("2f5fa8"), rgb("3f7d4a"), rgb("8a4a9a")]):
            a = math.radians(200 + k * 32)
            px, py = cx + size * 0.28 * math.cos(a), cy + size * 0.22 * math.sin(a)
            d.ellipse([px - 11, py - 11, px + 11, py + 11], fill=c)
        d.line([(x + size * 0.2, y + size * 0.95), (x + size * 0.85, y + size * 0.1)], fill=rgb("6a4a2a"), width=7)
        d.polygon([(x + size * 0.85, y + size * 0.1), (x + size * 0.92, y + size * 0.02), (x + size * 0.8, y + size * 0.14)], fill=pal["ink"])
    return draw


def emblem_tudor_rose():
    def draw(d, x, y, size, pal):
        tudor_rose(d, x + size / 2, y + size / 2, size * 0.46, rgb("b8302a"), pal["ink"])
    return draw




def emblem_seal(text):
    """中国の朱印（四文字を2x2で白抜き）。"""
    def draw(d, x, y, size, pal):
        d.rounded_rectangle([x, y, x + size, y + size], radius=8, fill=rgb("b8302a"))
        f = ImageFont.truetype(JP_FONT, int(size * 0.38), index=1)
        for k, ch in enumerate(text[:4]):
            cx = x + size * (0.72 if k < 2 else 0.28)
            cy = y + size * (0.28 if k % 2 == 0 else 0.72)
            w = d.textlength(ch, font=f)
            d.text((cx - w / 2, cy - f.size * 0.6), ch, font=f, fill=(250, 240, 228))
    return draw


def emblem_sun(rays=16, color=rgb("d9a42a"), wavy=True):
    """太陽（インカのインティ／アルゼンチンの五月の太陽）。"""
    def draw(d, x, y, size, pal):
        cx, cy, r = x + size / 2, y + size / 2, size * 0.2
        for i in range(rays):
            a = i * math.tau / rays
            if wavy and i % 2:
                pts = [(cx + (r + t) * math.cos(a) + 5 * math.sin(t / 6) * -math.sin(a),
                        cy + (r + t) * math.sin(a) + 5 * math.sin(t / 6) * math.cos(a)) for t in range(0, int(size * 0.28), 4)]
                d.line(pts, fill=color, width=5)
            else:
                d.polygon([(cx + r * math.cos(a - 0.12), cy + r * math.sin(a - 0.12)),
                           (cx + size * 0.48 * math.cos(a), cy + size * 0.48 * math.sin(a)),
                           (cx + r * math.cos(a + 0.12), cy + r * math.sin(a + 0.12))], fill=color)
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=color, outline=pal["ink"], width=3)
        # 顔（目と口）
        d.ellipse([cx - r * 0.45, cy - r * 0.25, cx - r * 0.2, cy], fill=pal["ink"])
        d.ellipse([cx + r * 0.2, cy - r * 0.25, cx + r * 0.45, cy], fill=pal["ink"])
        d.arc([cx - r * 0.4, cy, cx + r * 0.4, cy + r * 0.55], 20, 160, fill=pal["ink"], width=3)
    return draw


def emblem_star8(color, inner):
    def draw(d, x, y, size, pal):
        cx, cy = x + size / 2, y + size / 2
        d.polygon(R.star_path(cx, cy, size * 0.48, size * 0.3, 8), fill=color, outline=pal["ink"], width=3)
        d.polygon(R.star_path(cx, cy, size * 0.26, size * 0.16, 8), fill=inner, outline=pal["ink"], width=2)
    return draw


def emblem_wheel(color):
    """法輪（チベット）。"""
    def draw(d, x, y, size, pal):
        cx, cy, r = x + size / 2, y + size / 2, size * 0.42
        d.ellipse([cx - r, cy - r, cx + r, cy + r], outline=color, width=8)
        d.ellipse([cx - r * 0.2, cy - r * 0.2, cx + r * 0.2, cy + r * 0.2], fill=color)
        for i in range(8):
            a = i * math.pi / 4
            d.line([(cx, cy), (cx + r * math.cos(a), cy + r * math.sin(a))], fill=color, width=6)
            d.ellipse([cx + r * 1.08 * math.cos(a) - 7, cy + r * 1.08 * math.sin(a) - 7, cx + r * 1.08 * math.cos(a) + 7, cy + r * 1.08 * math.sin(a) + 7], fill=color)
    return draw


def emblem_dome(color, accent):
    """ムガルのたまねぎ形のドーム。"""
    def draw(d, x, y, size, pal):
        cx = x + size / 2
        base = y + size * 0.88
        d.rectangle([x + size * 0.15, base - size * 0.28, x + size * 0.85, base], fill=accent, outline=pal["ink"], width=3)
        d.pieslice([cx - size * 0.3, base - size * 0.72, cx + size * 0.3, base - size * 0.12], 180, 360, fill=color, outline=pal["ink"], width=3)
        d.polygon([(cx - size * 0.3, base - size * 0.42), (cx, base - size * 0.95), (cx + size * 0.3, base - size * 0.42)], fill=color, outline=pal["ink"])
        for k in (-1, 1):
            mx = cx + k * size * 0.42
            d.rectangle([mx - 7, base - size * 0.62, mx + 7, base], fill=accent, outline=pal["ink"])
            d.ellipse([mx - 11, base - size * 0.7, mx + 11, base - size * 0.56], fill=color, outline=pal["ink"])
    return draw


def emblem_lotus(color, leaf):
    def draw(d, x, y, size, pal):
        cx, cy = x + size / 2, y + size * 0.62
        for k, a in enumerate((-60, -30, 0, 30, 60)):
            rad = math.radians(a - 90)
            tip = (cx + size * 0.42 * math.cos(rad), cy + size * 0.42 * math.sin(rad))
            left = (cx + size * 0.14 * math.cos(rad - 1.2), cy + size * 0.14 * math.sin(rad - 1.2))
            right = (cx + size * 0.14 * math.cos(rad + 1.2), cy + size * 0.14 * math.sin(rad + 1.2))
            d.polygon([left, tip, right, (cx, cy)], fill=color, outline=pal["ink"])
        d.ellipse([cx - size * 0.42, cy + size * 0.02, cx + size * 0.42, cy + size * 0.2], fill=leaf, outline=pal["ink"])
    return draw


def emblem_roundel(color, bg):
    """中世の円形の都市図（四つに区切られた聖都）。"""
    def draw(d, x, y, size, pal):
        cx, cy, r = x + size / 2, y + size / 2, size * 0.45
        d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=bg, outline=color, width=6)
        d.line([(cx - r, cy), (cx + r, cy)], fill=color, width=5)
        d.line([(cx, cy - r), (cx, cy + r)], fill=color, width=5)
        d.ellipse([cx - r * 0.3, cy - r * 0.3, cx + r * 0.3, cy + r * 0.3], fill=color)
    return draw


def emblem_ship(hull, sail, flag, flag2=None):
    def draw(d, x, y, size, pal):
        R.ship(d._image, x + size / 2, y + size * 0.62, size * 0.42, hull, sail, pal["ink"], flag=flag, flag2=flag2)
    return draw


def emblem_windmill(color):
    def draw(d, x, y, size, pal):
        cx, top = x + size / 2, y + size * 0.3
        d.polygon([(cx - size * 0.16, y + size * 0.95), (cx + size * 0.16, y + size * 0.95), (cx + size * 0.1, top), (cx - size * 0.1, top)], fill=color, outline=pal["ink"], width=3)
        for a in (45, 135, 225, 315):
            rad = math.radians(a)
            tip = (cx + size * 0.42 * math.cos(rad), top + size * 0.42 * math.sin(rad))
            d.line([(cx, top), tip], fill=pal["ink"], width=5)
            nx, ny = -math.sin(rad) * size * 0.07, math.cos(rad) * size * 0.07
            mid = (cx + size * 0.25 * math.cos(rad), top + size * 0.25 * math.sin(rad))
            d.polygon([mid, tip, (tip[0] + nx, tip[1] + ny), (mid[0] + nx, mid[1] + ny)], fill=(240, 232, 214), outline=pal["ink"])
        d.ellipse([cx - 8, top - 8, cx + 8, top + 8], fill=pal["ink"])
    return draw


def emblem_sunstone(color, accent):
    """アステカの太陽の石（同心円と光線）。"""
    def draw(d, x, y, size, pal):
        cx, cy = x + size / 2, y + size / 2
        for k, r in enumerate((0.48, 0.38, 0.26)):
            d.ellipse([cx - size * r, cy - size * r, cx + size * r, cy + size * r], fill=color if k != 1 else accent, outline=pal["ink"], width=3)
        for i in range(8):
            a = i * math.pi / 4
            d.polygon([(cx + size * 0.14 * math.cos(a - 0.3), cy + size * 0.14 * math.sin(a - 0.3)),
                       (cx + size * 0.36 * math.cos(a), cy + size * 0.36 * math.sin(a)),
                       (cx + size * 0.14 * math.cos(a + 0.3), cy + size * 0.14 * math.sin(a + 0.3))], fill=pal["ink"])
        d.ellipse([cx - size * 0.1, cy - size * 0.1, cx + size * 0.1, cy + size * 0.1], fill=accent, outline=pal["ink"], width=2)
    return draw


# ---------------------------------------------------------------- 都市ごとの飾り

def mountains(img, pal, rng, snow=True, top=True, count=9, height=150, color=None):
    d = ImageDraw.Draw(img)
    color = color or (150, 138, 118)
    y0 = 80 + height if top else S - 80
    x = 60
    while x < S - 60:
        w = rng.uniform(160, 300)
        h = rng.uniform(height * 0.6, height)
        peak = (x + w / 2, y0 - h if top else y0 - h)
        d.polygon([(x, y0), peak, (x + w, y0)], fill=color, outline=pal["ink"])
        d.line([peak, (x + w * 0.62, y0)], fill=(110, 100, 86), width=3)
        if snow:
            d.polygon([peak, (peak[0] - w * 0.12, peak[1] + h * 0.26), (peak[0], peak[1] + h * 0.18), (peak[0] + w * 0.12, peak[1] + h * 0.26)], fill=(250, 250, 246))
        x += w * 0.7


def palms(img, mask, pal, rng, n=500, size=26):
    d = ImageDraw.Draw(img)
    arr = np.array(mask) > 0
    for _ in range(n * 6):
        if n <= 0:
            break
        x, y = rng.integers(100, S - 100), rng.integers(100, S - 100)
        if not arr[y, x]:
            continue
        n -= 1
        d.line([(x, y), (x + 3, y - size)], fill=(95, 70, 45), width=3)
        for a in range(-150, -20, 26):
            rad = math.radians(a)
            d.line([(x + 3, y - size), (x + 3 + size * 0.7 * math.cos(rad), y - size + size * 0.5 * math.sin(rad) + size * 0.25)], fill=rgb("3f6b3a"), width=4)


def rect_wall(d, proj, s, w, n, e, color, inner, width=14, bastions=True):
    pts = [proj(n, w), proj(n, e), proj(s, e), proj(s, w), proj(n, w)]
    d.line(pts, fill=color, width=width, joint="curve")
    d.line(pts, fill=inner, width=width // 2, joint="curve")
    if bastions:
        for (a, b) in zip(pts, pts[1:]):
            length = math.hypot(b[0] - a[0], b[1] - a[1])
            for k in range(1, int(length // 90)):
                t = k * 90 / length
                x, y = a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
                d.rectangle([x - 9, y - 9, x + 9, y + 9], fill=color)


def extra_beijing(img, proj, pal, rng):
    d = ImageDraw.Draw(img)
    vermilion, yellow = rgb("b8302a"), rgb("e3b33c")
    # 清代の内城・外城の城壁（おおよその位置）と、紫禁城
    rect_wall(d, proj, 39.8990, 116.3500, 39.9490, 116.4280, rgb("6b5a4a"), rgb("9a8a74"))
    rect_wall(d, proj, 39.8660, 116.3540, 39.8990, 116.4400, rgb("6b5a4a"), rgb("9a8a74"))
    x0, y0 = proj(39.9206, 116.3864)
    x1, y1 = proj(39.9120, 116.3952)
    d.rectangle([x0, y0, x1, y1], fill=yellow, outline=vermilion, width=10)
    for k in range(1, 6):
        yy = y0 + (y1 - y0) * k / 6
        d.line([(x0 + 18, yy), (x1 - 18, yy)], fill=vermilion, width=3)
    # 天壇（円）
    tx, ty = proj(39.8822, 116.4007)
    for r in (46, 30):
        d.ellipse([tx - r, ty - r, tx + r, ty + r], outline=rgb("2f5d8a"), width=5)
    f = ImageFont.truetype(JP_FONT, 60, index=1)
    for text, lat, lon in (("内城", 39.9360, 116.3650), ("外城", 39.8750, 116.3700), ("紫禁城", 39.9215, 116.3990)):
        x, y = proj(lat, lon)
        d.text((x, y), text, font=f, fill=vermilion, stroke_width=4, stroke_fill=pal["paper"])


def extra_lhasa(img, proj, pal, rng):
    mountains(img, pal, rng, snow=True, top=True, height=170)
    d = ImageDraw.Draw(img)
    x, y = proj(29.6576, 91.1170)
    # ポタラ宮（白宮と紅宮）
    d.rectangle([x - 90, y - 30, x + 90, y + 40], fill=(245, 242, 232), outline=pal["ink"], width=3)
    d.rectangle([x - 30, y - 55, x + 30, y + 40], fill=rgb("8a2a24"), outline=pal["ink"], width=3)
    d.rectangle([x - 18, y - 70, x + 18, y - 55], fill=rgb("d9a42a"), outline=pal["ink"])


def extra_angkor(img, proj, pal, rng, green):
    palms(img, green, pal, rng, n=700)
    d = ImageDraw.Draw(img)
    # アンコール・ワットの中央祠堂（五つの塔）
    x, y = proj(13.4125, 103.8666)
    for dx, h in ((-44, 50), (-22, 64), (0, 86), (22, 64), (44, 50)):
        d.polygon([(x + dx - 14, y + 30), (x + dx, y + 30 - h), (x + dx + 14, y + 30)], fill=rgb("c9a468"), outline=pal["ink"], width=2)


def extra_london(img, proj, pal, rng):
    """テムズ川の渡し舟（ウェリー）と帆船、南岸の劇場（グローブ座・ローズ座）の小さな円形の絵。"""
    water = R.water_mask(R.load("london"), proj)
    warr = np.array(water) > 0
    spots = []
    for _ in range(6000):
        if len(spots) >= 5:
            break
        x, y = int(rng.integers(200, S - 200)), int(rng.integers(200, S - 200))
        if warr[y - 50:y + 40, x - 70:x + 70].mean() > 0.97 and all(abs(x - a) > 260 or abs(y - b) > 140 for a, b in spots):
            spots.append((x, y))
            R.ship(img, x, y, 34, rgb("5a3a22"), (242, 236, 222), pal["ink"], flag=rgb("b8302a"), flag2=(246, 246, 240))
    d = ImageDraw.Draw(img)
    for lat, lon in ((51.5081, -0.0972), (51.5074, -0.0939)):
        x, y = proj(lat, lon)
        for r, fill in ((34, (236, 222, 190)), (20, (200, 180, 140))):
            d.ellipse([x - r, y - r, x + r, y + r], fill=fill, outline=pal["ink"], width=3)
        d.polygon([(x - 8, y - 34), (x, y - 50), (x + 8, y - 34)], fill=rgb("b8302a"), outline=pal["ink"])


def extra_cusco(img, proj, pal, rng):
    mountains(img, pal, rng, snow=False, top=True, height=130, color=(158, 146, 110))


STYLES = {
    "beijing": dict(
        pal=dict(paper=(238, 229, 205), green=(148, 160, 112), ink=rgb("2a2420"), road=(244, 236, 216),
                 road_casing=rgb("7a6a58"), water=rgb("9cb5aa"), water_line=rgb("3f5f55")),
        buildings=None, road_scale=0.9, shore=(3, 7, 22),
        border=border_meander(rgb("b8302a"), (242, 232, 208)), band=46,
        title=[("京師全圖", "jp", 120, "vermilion", 12), ("PEKING · ANNO MDCCL", "Copperplate.ttc", 34, "ink", 4),
               ("北京（清代の内城・外城）", "jpr", 38, "ink", 0), ("KOMAP · ASIA", "Didot.ttc", 22, "ink", 8)],
        emblem=emblem_seal("京師全図"), accent=rgb("b8302a"), bar=(1000, "1000 m"), extra=extra_beijing,
    ),
    "xian": dict(
        pal=dict(paper=(236, 224, 196), green=(150, 156, 104), ink=rgb("2c241c"), road=(242, 232, 206),
                 road_casing=rgb("80694f"), water=rgb("9fb3a1"), water_line=rgb("45604f")),
        buildings=None, road_scale=0.9, shore=(3, 7, 22), walls=(rgb("6b5642"), rgb("a28a68")),
        border=border_meander(rgb("2f5a4a"), (236, 226, 200)), band=46,
        title=[("長安", "jp", 128, "vermilion", 30), ("SI-NGAN-FU · CHANG'AN", "Copperplate.ttc", 32, "ink", 3),
               ("西安（明の西安府城）", "jpr", 38, "ink", 0), ("KOMAP · ASIA", "Didot.ttc", 22, "ink", 8)],
        emblem=emblem_seal("長安古都"), accent=rgb("2f5a4a"), bar=(1000, "1000 m"),
    ),
    "lhasa": dict(
        pal=dict(paper=(240, 230, 204), green=(150, 162, 108), ink=rgb("2a1f1a"), road=(246, 238, 218),
                 road_casing=rgb("7d5a44"), water=rgb("8eaec2"), water_line=rgb("3a5a70")),
        buildings=[(246, 242, 232)], building_outline=rgb("8a2a24"), road_scale=1.0, shore=(4, 7, 20),
        border=border_prayer_flags(), band=48,
        title=[("ལྷ་ས", "Kailasa.ttc", 110, "maroon", 0), ("LHASA · ANNO MDCC", "Copperplate.ttc", 34, "ink", 4),
               ("ラサ（ポタラ宮と聖都）", "jpr", 38, "ink", 0), ("KOMAP · ASIA", "Didot.ttc", 22, "ink", 8)],
        emblem=emblem_wheel(rgb("c9962a")), accent=rgb("8a2a24"), bar=(500, "500 m"), extra=extra_lhasa,
    ),
    "angkor": dict(
        pal=dict(paper=(236, 228, 200), green=(120, 150, 96), ink=rgb("2a2a1e"), road=(236, 222, 190),
                 road_casing=rgb("8a6a44"), water=rgb("8fb0a0"), water_line=rgb("3c5e50")),
        buildings=[rgb("c9a468")], building_outline=rgb("6a5230"), road_scale=1.0, shore=(4, 7, 18),
        border=border_lotus(rgb("c9a468"), rgb("3f5f3a")), band=46,
        title=[("YASODHARAPURA", "Copperplate.ttc", 70, "accent", 4), ("ANGKOR · ANNO MCL", "Didot.ttc", 34, "ink", 4),
               ("アンコール（クメール王朝の都）", "jpr", 38, "ink", 0), ("KOMAP · ASIA", "Didot.ttc", 22, "ink", 8)],
        emblem=emblem_lotus(rgb("d98a8a"), rgb("5a8a4a")), accent=rgb("7a4a22"), bar=(500, "500 m"), extra="angkor",
    ),
    "delhi": dict(
        pal=dict(paper=(240, 228, 204), green=(146, 158, 100), ink=rgb("2c1f18"), road=(246, 236, 214),
                 road_casing=rgb("80583e"), water=rgb("98b4b4"), water_line=rgb("3f5c5c")),
        buildings=[rgb("b5654a"), rgb("d8b08c"), (238, 230, 214)], building_outline=rgb("6a3a28"), road_scale=1.0,
        shore=(3, 7, 18), walls=(rgb("7a3a28"), rgb("b5654a")),
        border=border_arches(rgb("a84e36"), (246, 240, 230)), band=48,
        title=[("SHAHJAHANABAD", "Copperplate.ttc", 70, "accent", 3), ("DEHLI · ANNO MDCCXXXIX", "Didot.ttc", 32, "ink", 3),
               ("デリー（ムガル帝国の都）", "jpr", 38, "ink", 0), ("KOMAP · ASIA", "Didot.ttc", 22, "ink", 8)],
        emblem=emblem_dome((246, 242, 232), rgb("b5654a")), accent=rgb("a84e36"), bar=(500, "500 m"),
    ),
    "isfahan": dict(
        pal=dict(paper=(240, 230, 206), green=(140, 160, 104), ink=rgb("232838"), road=(246, 238, 218),
                 road_casing=rgb("7d6a4e"), water=rgb("7fb3b6"), water_line=rgb("2f5e66")),
        buildings=[rgb("d8b98a"), rgb("c9a676")], building_outline=rgb("7a5f3c"), road_scale=1.0, shore=(4, 7, 18),
        border=border_stars(rgb("3aa5b0"), rgb("1f3c7a")), band=48,
        title=[("ISPAHAN", "Trattatello.ttf", 110, "cobalt", 4), ("Nesf-e Jahan · ANNO MDCLXX", "Didot.ttc", 32, "ink", 2),
               ("イスファハーン（サファヴィー朝の都）", "jpr", 36, "ink", 0), ("KOMAP · ASIA", "Didot.ttc", 22, "ink", 8)],
        emblem=emblem_star8(rgb("3aa5b0"), rgb("1f3c7a")), accent=rgb("1f3c7a"), bar=(500, "500 m"),
    ),
    "jerusalem": dict(
        pal=dict(paper=(240, 232, 212), green=(150, 160, 110), ink=rgb("2c2620"), road=(246, 240, 224),
                 road_casing=rgb("8a7658"), water=rgb("9cb3b8"), water_line=rgb("40585e")),
        buildings=[rgb("e3d3b0")], building_outline=rgb("8a7658"), road_scale=1.0, shore=(3, 7, 18),
        walls=(rgb("7a6648"), rgb("c9b58c")),
        border=border_roundels(rgb("8a6a3a"), (238, 228, 204)), band=46,
        title=[("HIEROSOLYMA", "Trattatello.ttf", 100, "accent", 2), ("Urbs Sancta · ANNO MDC", "Didot.ttc", 32, "ink", 2),
               ("エルサレム旧市街", "jpr", 38, "ink", 0), ("KOMAP · ASIA", "Didot.ttc", 22, "ink", 8)],
        emblem=emblem_roundel(rgb("8a6a3a"), (246, 238, 220)), accent=rgb("8a3a2a"), bar=(200, "200 m"),
    ),
    "boston": dict(
        pal=dict(paper=(240, 232, 210), green=(148, 160, 110), ink=rgb("262420"), road=(246, 240, 224),
                 road_casing=rgb("6e6252"), water=rgb("a3b8bd"), water_line=rgb("3f5660")),
        buildings=[rgb("a4553a"), rgb("b9a58a")], building_outline=rgb("5a3a2a"), road_scale=1.0, shore=(6, 7, 18),
        border=border_graduated(rgb("262420"), (242, 236, 220)), band=40,
        title=[("A PLAN of BOSTON", "Copperplate.ttc", 70, "accent", 3), ("in New England · MDCCLXXV", "Didot.ttc", 32, "ink", 2),
               ("ボストン（独立戦争の舞台）", "jpr", 38, "ink", 0), ("KOMAP · AMERICA", "Didot.ttc", 22, "ink", 8)],
        emblem=emblem_ship(rgb("5a3a22"), (242, 236, 222), rgb("b8302a")), accent=rgb("9c2a24"), bar=(300, "300 m"),
    ),
    "newyork": dict(
        pal=dict(paper=(238, 230, 206), green=(150, 160, 104), ink=rgb("24221e"), road=(244, 238, 220),
                 road_casing=rgb("6a5c4a"), water=rgb("9fb9b0"), water_line=rgb("3c5a52")),
        buildings=[rgb("8d5a44"), rgb("b8a488")], building_outline=rgb("4a3226"), road_scale=1.0, shore=(6, 7, 16),
        border=border_graduated(rgb("24221e"), (240, 232, 214)), band=40,
        title=[("NIEUW AMSTERDAM", "Trattatello.ttf", 88, "accent", 2), ("NEW-YORK · MDCLX – MDCCLXXVI", "Didot.ttc", 30, "ink", 2),
               ("ニューヨーク（ロウアー・マンハッタン）", "jpr", 36, "ink", 0), ("KOMAP · AMERICA", "Didot.ttc", 22, "ink", 8)],
        emblem=emblem_windmill(rgb("b89868")), accent=rgb("d9772b"), bar=(300, "300 m"),
    ),
    "mexico": dict(
        pal=dict(paper=(240, 228, 200), green=(146, 158, 96), ink=rgb("2a221c"), road=(246, 236, 212),
                 road_casing=rgb("7e5f44"), water=rgb("8fb5b0"), water_line=rgb("3a5e58")),
        buildings=[(176, 104, 84), (216, 184, 134), (234, 224, 206)], building_outline=rgb("7a5040"), road_scale=1.0,
        shore=(3, 7, 18),
        border=border_steps(rgb("2c7a6e"), rgb("d9b27a")), band=46,
        title=[("MÉXICO", "Trattatello.ttf", 104, "accent", 4), ("TENOCHTITLAN · ANNO MDCXXVIII", "Didot.ttc", 30, "ink", 2),
               ("メキシコシティ（テノチティトランの跡）", "jpr", 36, "ink", 0), ("KOMAP · AMERICA", "Didot.ttc", 22, "ink", 8)],
        emblem=emblem_sunstone(rgb("c9a468"), rgb("2c7a6e")), accent=rgb("8e3b2e"), bar=(300, "300 m"),
    ),
    "cusco": dict(
        pal=dict(paper=(238, 226, 198), green=(140, 158, 100), ink=rgb("2a221c"), road=(244, 234, 208),
                 road_casing=rgb("7a5a40"), water=rgb("8fb0b8"), water_line=rgb("3a5a64")),
        buildings=[rgb("b5563a"), rgb("c9744f")], building_outline=rgb("5a2e20"), road_scale=1.0, shore=(3, 7, 18),
        border=None, band=48, rng_border="tocapu",
        title=[("QOSQO", "Trattatello.ttf", 110, "accent", 6), ("CUZCO · ANNO MDCL", "Copperplate.ttc", 34, "ink", 4),
               ("クスコ（インカ帝国の都）", "jpr", 38, "ink", 0), ("KOMAP · AMERICA", "Didot.ttc", 22, "ink", 8)],
        emblem=emblem_sun(16, rgb("d9a42a"), wavy=False), accent=rgb("a8322a"), bar=(300, "300 m"), extra=extra_cusco,
    ),
    "paris": dict(
        pal=dict(paper=(242, 234, 214), green=(150, 168, 120), ink=rgb("33283a"), road=(248, 242, 228),
                 road_casing=rgb("a8969e"), water=rgb("a9bfc4"), water_line=rgb("4a5e66")),
        buildings=[rgb("dcc8a6"), rgb("d4b8c4"), (238, 230, 216)], building_outline=rgb("9a8a8a"), road_scale=0.85,
        shore=(3, 7, 18),
        border=border_art_nouveau(rgb("6a5a3a"), rgb("a8b88a"), (238, 228, 206)), band=48,
        title=[("MONTMARTRE", "Didot.ttc", 96, "accent", 8), ("Paris · 1900 · Les ateliers des artistes", "Didot.ttc", 30, "ink", 1),
               ("パリ・モンマルトル（芸術家の家めぐり）", "jpr", 36, "ink", 0), ("KOMAP · EUROPE", "Didot.ttc", 22, "ink", 8)],
        emblem=emblem_palette(), accent=rgb("8a4a6a"), bar=(200, "200 m"),
    ),
    "london": dict(
        pal=dict(paper=(238, 228, 200), green=(146, 158, 104), ink=rgb("2a241e"), road=(244, 234, 212),
                 road_casing=rgb("7a624a"), water=rgb("9cb2ae"), water_line=rgb("3e5650")),
        buildings=[rgb("b06a4a"), rgb("c9a878"), rgb("8a6a50")], building_outline=rgb("4a3222"), road_scale=1.0,
        shore=(6, 7, 16),
        border=border_tudor(rgb("b8302a"), (236, 226, 200)), band=48,
        title=[("LONDINUM", "Trattatello.ttf", 104, "accent", 4), ("Anno Domini MDC · the age of Shakespeare", "Didot.ttc", 30, "ink", 1),
               ("ロンドン（シェイクスピアの時代）", "jpr", 36, "ink", 0), ("KOMAP · EUROPE", "Didot.ttc", 22, "ink", 8)],
        emblem=emblem_tudor_rose(), accent=rgb("8a2a24"), bar=(300, "300 m"), extra=extra_london,
    ),
    "buenosaires": dict(
        pal=dict(paper=(240, 232, 212), green=(148, 162, 108), ink=rgb("22262e"), road=(246, 240, 226),
                 road_casing=rgb("6e6656"), water=rgb("a9bfc8"), water_line=rgb("3e5866")),
        buildings=[rgb("d9b98c"), (238, 232, 218)], building_outline=rgb("6a5a44"), road_scale=1.0, shore=(5, 7, 18),
        border=border_stripes([rgb("6cacdc"), (246, 246, 240), rgb("6cacdc")]), band=42,
        title=[("BUENOS AYRES", "Trattatello.ttf", 88, "accent", 2), ("Santísima Trinidad · MDCCLXXX", "Didot.ttc", 30, "ink", 2),
               ("ブエノスアイレス（植民地時代の港町）", "jpr", 36, "ink", 0), ("KOMAP · AMERICA", "Didot.ttc", 22, "ink", 8)],
        emblem=emblem_sun(24, rgb("e0a93a"), wavy=True), accent=rgb("3a78b0"), bar=(300, "300 m"),
    ),
}

COLOR_NAMES = {"vermilion": rgb("b8302a"), "maroon": rgb("8a2a24"), "cobalt": rgb("1f3c7a")}


def title_font(name, size):
    if name == "jp":
        return ImageFont.truetype(JP_FONT, size, index=1)
    if name == "jpr":
        return ImageFont.truetype(JP_FONT, size, index=0)
    return font(name, size)


def styled(name, elements, proj, rng):
    cfg = STYLES[name]
    pal = cfg["pal"]
    rings, spacing, hatch = cfg["shore"]
    img, water = R.base_map(elements, proj, rng, pal, building_color=cfg.get("buildings"),
                            building_outline=cfg.get("building_outline"), road_scale=cfg["road_scale"],
                            shore_rings=rings, shore_spacing=spacing, hatch_step=hatch)
    d = ImageDraw.Draw(img)

    # 建物の多い所（題名の枠を置く場所を選ぶ時に避ける）
    built = Image.new("L", (S, S), 0)
    bd = ImageDraw.Draw(built)
    if cfg.get("buildings"):
        for pts in R.polygons(elements, proj, lambda t: "building" in t):
            bd.polygon(pts, fill=255)

    green = Image.new("L", (S, S), 0)
    gd = ImageDraw.Draw(green)
    for pts in R.polygons(elements, proj, lambda t: t.get("leisure") in ("park", "garden") or t.get("landuse") in ("forest", "grass", "meadow") or t.get("natural") == "wood"):
        gd.polygon(pts, fill=255)

    # 城壁
    if cfg.get("walls"):
        outer, inner = cfg["walls"]
        for _, pts in R.lines(elements, proj, lambda t: t.get("historic") == "citywalls" or t.get("barrier") == "city_wall"):
            d.line(pts, fill=outer, width=18, joint="curve")
            d.line(pts, fill=inner, width=9, joint="curve")
            acc = 0
            for a, b in zip(pts, pts[1:]):
                acc += math.hypot(b[0] - a[0], b[1] - a[1])
                if acc > 120:
                    acc = 0
                    d.rectangle([b[0] - 11, b[1] - 11, b[0] + 11, b[1] + 11], fill=outer)

    extra = cfg.get("extra")
    if extra == "angkor":
        extra_angkor(img, proj, pal, rng, ImageChops.subtract(green, water))
    elif extra:
        extra(img, proj, pal, rng)

    # 縁取り
    band = cfg["band"]
    border = cfg["border"] or border_tocapu(rng)
    border(d, band, pal)
    d.rectangle([band, band, S - 1 - band, S - 1 - band], outline=pal["ink"], width=3)

    # 題名の枠: 陸を隠さず（水面・公園・建物の少ない所）、チェックポイントを避けて置く
    free = ImageChops.lighter(water, green)
    empty = ImageChops.invert(built.filter(ImageFilter.MaxFilter(21)))
    if np.array(free).mean() < 40:
        free = ImageChops.lighter(free, empty)
    pts = [proj(*c) for c in CHECKPOINTS[name]]
    cw, ch = 800, 380
    cx0, cy0 = R.find_spot(free, cw, ch, pts)
    paper = tuple(min(255, v + 8) for v in pal["paper"])
    accent = cfg["accent"]
    d.rectangle([cx0, cy0, cx0 + cw, cy0 + ch], fill=paper, outline=pal["ink"], width=5)
    d.rectangle([cx0 + 14, cy0 + 14, cx0 + cw - 14, cy0 + ch - 14], outline=accent, width=3)
    esize = 150
    cfg["emblem"](d, cx0 + 36, cy0 + (ch - esize) / 2, esize, pal)
    mid = cx0 + esize + 36 + (cw - esize - 36) / 2
    # 各行は枠の内側に収まるまで文字を小さくし、行の高さは実際の字面の高さで積む（はみ出し・重なり防止）
    max_w = cw - esize - 36 - 60
    lines_ = []
    for text, fname, size, color, spacing in cfg["title"]:
        while True:
            f = title_font(fname, size)
            width = sum(d.textlength(c, font=f) for c in text) + spacing * (len(text) - 1)
            if width <= max_w or size <= 18:
                break
            size -= 4
        top, bottom = d.textbbox((0, 0), text, font=f)[1::2]
        lines_.append((text, f, color, spacing, top, bottom))
    gap = 16
    total = sum(b_ - t_ for *_, t_, b_ in lines_) + gap * (len(lines_) - 1)
    y = cy0 + (ch - total) / 2
    for text, f, color, spacing, top, bottom in lines_:
        fill = accent if color == "accent" else COLOR_NAMES.get(color, pal["ink"])
        R.centered_text(d, mid, y - top, text, f, fill, spacing=spacing)
        y += bottom - top + gap
    R.rose_block(img, free, pts, [(cx0, cy0, cw, ch)], proj, pal, accent, paper, font("Copperplate.ttc", 42),
                 cfg["bar"][0], cfg["bar"][1], font("Didot.ttc", 26, index=2), radius=120, corners_only=True)
    return img


def main(names):
    out = R.HERE / "out"
    out.mkdir(exist_ok=True)
    for name in names:
        rng = np.random.default_rng(sum(map(ord, name)))
        random.seed(name)
        proj = R.Projection(*BOUNDS[name])
        img = styled(name, R.load(name), proj, rng)
        d = ImageDraw.Draw(img)
        credit = "Map data © OpenStreetMap contributors"
        f = font("Didot.ttc", 22, index=2)
        tw = d.textlength(credit, font=f)
        x, y = S - 70 - tw, S - 92
        d.rectangle([x - 8, y - 4, x + tw + 8, y + 28], fill=(240, 232, 212))
        d.text((x, y), credit, font=f, fill=(70, 60, 50))
        img.resize((R.OUT, R.OUT), Image.LANCZOS).save(out / f"{name}.png", optimize=True)
        print("wrote", name)


if __name__ == "__main__":
    main(sys.argv[1:] or list(STYLES))
