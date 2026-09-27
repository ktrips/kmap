"""Europe（旧Komap Global）の古地図を、OpenStreetMap のデータから各国の古地図の様式で描く。

    python3 render.py [city ...]

出力: out/<city>.png（1024x1024）。画像の範囲はアプリの古地図の範囲（southWest〜northEast）と
同じで、メルカトル図法で位置を合わせている（Google Maps の地上オーバーレイと同じ）。
チェックポイントの番号はアプリが画像の上に重ねて描くため、画像には描き込まない。
"""
import json
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

S = 2048  # 描画は2倍で行い、最後に1024へ縮小して線をなめらかにする
OUT = 1024
HERE = Path(__file__).parent
FONT_DIR = Path("/System/Library/Fonts/Supplemental")
JP_FONT = "/System/Library/Fonts/ヒラギノ明朝 ProN.ttc"


def font(name, size, index=0):
    path = FONT_DIR / name
    if not path.exists():
        path = Path("/System/Library/Fonts") / name
    return ImageFont.truetype(str(path), size, index=index)


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


# ---------------------------------------------------------------- 投影

class Projection:
    def __init__(self, s, w, n, e):
        self.s, self.w, self.n, self.e = s, w, n, e
        self.y_n = self._merc(n)
        self.y_s = self._merc(s)

    @staticmethod
    def _merc(lat):
        return math.log(math.tan(math.pi / 4 + math.radians(lat) / 2))

    def __call__(self, lat, lon):
        x = (lon - self.w) / (self.e - self.w) * S
        y = (self.y_n - self._merc(lat)) / (self.y_n - self.y_s) * S
        return (x, y)

    def meters_per_px(self):
        lat = (self.s + self.n) / 2
        width_m = (self.e - self.w) * 111_320 * math.cos(math.radians(lat))
        return width_m / S


# ---------------------------------------------------------------- データ

def load(city):
    return json.load(open(HERE / f"{city}.json"))["elements"]


def way_points(el, proj):
    return [proj(p["lat"], p["lon"]) for p in el.get("geometry", []) if p]


def assemble_rings(segments):
    """マルチポリゴンのメンバー（端点でつながる線の列）を閉じたリングにまとめる。"""
    segs = [list(s) for s in segments if len(s) >= 2]
    rings = []
    while segs:
        ring = segs.pop()
        changed = True
        while changed and ring[0] != ring[-1]:
            changed = False
            for i, s in enumerate(segs):
                if s[0] == ring[-1]:
                    ring += s[1:]
                elif s[-1] == ring[-1]:
                    ring += s[::-1][1:]
                elif s[-1] == ring[0]:
                    ring = s[:-1] + ring
                elif s[0] == ring[0]:
                    ring = s[::-1][:-1] + ring
                else:
                    continue
                segs.pop(i)
                changed = True
                break
        if len(ring) >= 3:
            rings.append(ring)
    return rings


def _water_rings(elements, proj):
    """水面（湖・川・運河）のポリゴン。(外側リング, 内側リング) のリストを返す。"""
    outers, inners = [], []
    for el in elements:
        tags = el.get("tags", {})
        if not (tags.get("natural") == "water" or tags.get("waterway") == "riverbank"):
            continue
        if el["type"] == "way":
            g = el.get("geometry", [])
            if len(g) >= 4 and g[0] == g[-1]:
                outers.append(way_points(el, proj))
        elif el["type"] == "relation":
            o, i = [], []
            for m in el.get("members", []):
                if m.get("type") != "way" or "geometry" not in m:
                    continue
                pts = [proj(p["lat"], p["lon"]) for p in m["geometry"] if p]
                (i if m.get("role") == "inner" else o).append(pts)
            outers += [r for r in assemble_rings(o) if r[0] == r[-1]]
            inners += [r for r in assemble_rings(i) if r[0] == r[-1]]
    return outers, inners


def water_mask(elements, proj):
    """海・湖・運河の水面を255で表すマスク。"""
    outers, inners = _water_rings(elements, proj)
    mask = Image.new("L", (S, S), 0)

    # 海岸線: OSMでは進行方向の右側が海。海岸線（と、河口で海岸線が途切れる所を閉じるため
    # 水面ポリゴンの輪郭）で画面を区切り、区切られた領域ごとに「右側（海）」と「左側（陸）」の
    # どちらの目印が多いかの多数決で海かどうかを決める（1か所の途切れで全体が崩れないように）。
    coast = [way_points(el, proj) for el in elements
             if el["type"] == "way" and el.get("tags", {}).get("natural") == "coastline"]
    if coast:
        work = Image.new("I", (S, S), 0)
        wd = ImageDraw.Draw(work)
        for pts in coast:
            if len(pts) >= 2:
                wd.line(pts, fill=1, width=3)
        for ring in outers + inners:
            wd.line(ring, fill=1, width=3)
        votes = {}
        next_label = 2
        for pts in coast:
            for a, b in zip(pts, pts[1:]):
                dx, dy = b[0] - a[0], b[1] - a[1]
                length = math.hypot(dx, dy)
                if length < 4:
                    continue
                nx, ny = -dy / length, dx / length
                for side, sign in ((1, 1), (-1, -1)):
                    mx = int((a[0] + b[0]) / 2 + nx * 6 * sign)
                    my = int((a[1] + b[1]) / 2 + ny * 6 * sign)
                    if not (0 <= mx < S and 0 <= my < S):
                        continue
                    label = work.getpixel((mx, my))
                    if label == 1:
                        continue
                    if label == 0:
                        ImageDraw.floodfill(work, (mx, my), next_label)
                        label = next_label
                        next_label += 1
                    votes[label] = votes.get(label, 0) + side
        arr = np.array(work)
        water_labels = [label for label, v in votes.items() if v > 0]
        sea = np.isin(arr, water_labels)
        mask = Image.fromarray((sea * 255).astype("uint8")).filter(ImageFilter.MaxFilter(5))

    draw = ImageDraw.Draw(mask)
    for ring in outers:
        draw.polygon(ring, fill=255)
    for ring in inners:
        draw.polygon(ring, fill=0)
    return mask


# ---------------------------------------------------------------- 描画の部品

def paper(base, rng, grain=10, stain=True):
    arr = np.full((S, S, 3), base, dtype=np.float32)
    noise = rng.normal(0, grain, (S // 4, S // 4))
    noise = np.array(Image.fromarray(noise.astype(np.float32)).resize((S, S), Image.BILINEAR))
    arr += noise[..., None]
    if stain:
        yy, xx = np.mgrid[0:S, 0:S]
        d = np.hypot(xx - S / 2, yy - S / 2) / (S / 2)
        arr *= (1 - 0.16 * np.clip(d - 0.55, 0, 1))[..., None]
        for _ in range(5):
            cx, cy, r = rng.uniform(0, S), rng.uniform(0, S), rng.uniform(S * 0.08, S * 0.22)
            blot = np.exp(-(((xx - cx) ** 2 + (yy - cy) ** 2) / (2 * r * r)))
            arr -= (blot * rng.uniform(6, 14))[..., None]
    return Image.fromarray(np.clip(arr, 0, 255).astype("uint8"))


def fill_mask(img, mask, color, alpha=255):
    layer = Image.new("RGB", img.size, color)
    m = mask if alpha == 255 else mask.point(lambda v: v * alpha // 255)
    img.paste(layer, (0, 0), m)


def erode(mask, px):
    out = mask
    while px > 0:
        step = min(px, 4)
        out = out.filter(ImageFilter.MinFilter(step * 2 + 1))
        px -= step
    return out


def engraved_shore(img, water, color, rings, spacing, width=2):
    """海岸線に沿って、水側へ等間隔に何本も引く銅版画風の線（古地図によくある表現）。"""
    for k in range(1, rings + 1):
        inner = erode(water, spacing * k)
        edge = ImageChops.subtract(inner, erode(inner, width))
        fill_mask(img, edge, color, alpha=int(200 * (1 - k / (rings + 1.5))))


def wave_hatch(img, water, color, step, amp, rng, alpha=110):
    layer = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(layer)
    y = step / 2
    while y < S:
        phase = rng.uniform(0, math.tau)
        pts = [(x, y + amp * math.sin(x / 38 + phase)) for x in range(0, S + 20, 12)]
        d.line(pts, fill=255, width=2)
        y += step
    fill_mask(img, ImageChops.multiply(layer, water), color, alpha)


def polygons(elements, proj, pred):
    for el in elements:
        if el["type"] != "way":
            continue
        tags = el.get("tags", {})
        if not pred(tags):
            continue
        g = el.get("geometry", [])
        if len(g) >= 4 and g[0] == g[-1]:
            yield way_points(el, proj)


def lines(elements, proj, pred):
    for el in elements:
        if el["type"] != "way":
            continue
        if pred(el.get("tags", {})):
            pts = way_points(el, proj)
            if len(pts) >= 2:
                yield el.get("tags", {}), pts


ROAD_WIDTH = {
    "motorway": 9, "trunk": 9, "primary": 8, "secondary": 7, "tertiary": 6,
    "residential": 4, "unclassified": 4, "pedestrian": 4, "living_street": 4,
    "service": 2, "footway": 2, "steps": 2,
}


def draw_roads(img, elements, proj, casing, fill, scale=1.0, classes=None):
    d = ImageDraw.Draw(img)
    items = [(t, p) for t, p in lines(elements, proj, lambda t: t.get("highway") in ROAD_WIDTH)
             if classes is None or t["highway"] in classes]
    for t, pts in items:
        w = ROAD_WIDTH[t["highway"]] * scale
        d.line(pts, fill=casing, width=int(w + 3), joint="curve")
    for t, pts in items:
        w = ROAD_WIDTH[t["highway"]] * scale
        if w >= 3:
            d.line(pts, fill=fill, width=int(w - 1), joint="curve")


def star_path(cx, cy, r_out, r_in, points, rotation=-math.pi / 2):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = rotation + i * math.pi / points
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def compass_rose(img, cx, cy, r, ink, accent, paper_color, label_font):
    d = ImageDraw.Draw(img)
    d.ellipse([cx - r * 1.05, cy - r * 1.05, cx + r * 1.05, cy + r * 1.05], outline=ink, width=3)
    d.ellipse([cx - r * 0.95, cy - r * 0.95, cx + r * 0.95, cy + r * 0.95], outline=ink, width=1)
    for i in range(32):
        a = i * math.tau / 32
        r0 = r * (0.86 if i % 4 else 0.78)
        d.line([(cx + r0 * math.cos(a), cy + r0 * math.sin(a)), (cx + r * 0.95 * math.cos(a), cy + r * 0.95 * math.sin(a))], fill=ink, width=2)
    # 8方位の星: 主方位は長く、左右半分を塗り分ける
    for i in range(8):
        a = -math.pi / 2 + i * math.pi / 4
        length = r * (0.92 if i % 2 == 0 else 0.55)
        half = r * (0.13 if i % 2 == 0 else 0.1)
        tip = (cx + length * math.cos(a), cy + length * math.sin(a))
        left = (cx + half * math.cos(a - math.pi / 2), cy + half * math.sin(a - math.pi / 2))
        right = (cx + half * math.cos(a + math.pi / 2), cy + half * math.sin(a + math.pi / 2))
        d.polygon([(cx, cy), left, tip], fill=accent if i % 2 == 0 else ink, outline=ink)
        d.polygon([(cx, cy), tip, right], fill=paper_color, outline=ink)
    d.ellipse([cx - r * 0.08, cy - r * 0.08, cx + r * 0.08, cy + r * 0.08], fill=accent, outline=ink, width=2)
    tw = d.textlength("N", font=label_font)
    d.text((cx - tw / 2, cy - r * 1.05 - label_font.size * 1.25), "N", font=label_font, fill=ink)


def scale_bar(img, x, y, proj, ink, paper_color, meters, label, label_font):
    d = ImageDraw.Draw(img)
    length = meters / proj.meters_per_px()
    seg = length / 4
    for i in range(4):
        d.rectangle([x + i * seg, y, x + (i + 1) * seg, y + 12], fill=ink if i % 2 == 0 else paper_color, outline=ink, width=2)
    tw = d.textlength(label, font=label_font)
    d.text((x + length / 2 - tw / 2, y + 20), label, font=label_font, fill=ink)
    return length


def centered_text(d, cx, y, text, f, fill, spacing=0):
    if spacing:
        widths = [d.textlength(c, font=f) for c in text]
        total = sum(widths) + spacing * (len(text) - 1)
        x = cx - total / 2
        for c, w in zip(text, widths):
            d.text((x, y), c, font=f, fill=fill)
            x += w + spacing
        return
    tw = d.textlength(text, font=f)
    d.text((cx - tw / 2, y), text, font=f, fill=fill)


def curved_label(img, text, cx, cy, f, fill, angle=0, halo=None, spacing=6):
    """水面などに置く斜めの地名（halo指定時は文字の周りを紙の色でふちどる）。"""
    d0 = ImageDraw.Draw(img)
    widths = [d0.textlength(c, font=f) for c in text]
    total = sum(widths) + spacing * (len(text) - 1)
    pad = f.size
    layer = Image.new("RGBA", (int(total + pad * 2), int(f.size * 2 + pad)), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    x = pad
    for c, w in zip(text, widths):
        if halo:
            ld.text((x, pad / 2), c, font=f, fill=halo, stroke_width=4, stroke_fill=halo)
        ld.text((x, pad / 2), c, font=f, fill=fill)
        x += w + spacing
    rot = layer.rotate(angle, resample=Image.BICUBIC, expand=True)
    img.paste(rot, (int(cx - rot.width / 2), int(cy - rot.height / 2)), rot)


def best_corner(water, w, h, margin, candidates=("sw", "se", "nw", "ne")):
    """カルトゥーシュ（題名枠）を置くのに、なるべく水面（陸を隠さない場所）が多い隅を選ぶ。"""
    arr = np.array(water) > 0
    best, best_score = None, -1
    for c in candidates:
        x = margin if "w" in c else S - margin - w
        y = margin if "n" in c else S - margin - h
        score = arr[int(y):int(y + h), int(x):int(x + w)].mean()
        if score > best_score:
            best, best_score = (c, x, y), score
    return best


CHECKPOINTS = {
    "helsinki": [(60.1699, 24.9522), (60.1454, 24.9880), (60.1677, 24.9535), (60.1699, 24.9563), (60.2197, 24.9646),
                 (60.1715, 24.9406), (60.1730, 24.9252), (60.1820, 24.9134)],
    "stockholm": [(59.3258, 18.0717), (59.3251, 18.0672), (59.3268, 18.0717), (59.3258, 18.0847), (59.3197, 18.0717),
                  (59.3250, 18.0708), (59.3259, 18.0658), (59.3231, 18.0728)],
    "amsterdam": [(52.3731, 4.8926), (52.3724, 4.9010), (52.3699, 4.8907), (52.3713, 4.9037), (52.3735, 4.9127),
                  (52.3745, 4.8840), (52.3671, 4.8932), (52.3744, 4.8981)],
    "tallinn": [(59.4370, 24.7454), (59.4370, 24.7402), (59.4376, 24.7484), (59.4393, 24.7439), (59.4425, 24.7456),
                (59.4370, 24.7392), (59.4378, 24.7480), (59.4377, 24.7422)],
}


def find_spot(free, w, h, points, avoid=(), margin=90, prefer_edges=True, corners_only=False):
    """題名枠・方位記号を置く場所。陸（free=0）とチェックポイントを隠さず、ほかの飾りとも
    重ならない位置のうち、なるべく「空いている」（free=255）所を選ぶ。"""
    arr = (np.array(free) > 0).astype(np.float64)
    integral = np.pad(arr.cumsum(0).cumsum(1), ((1, 0), (1, 0)))

    def area(x, y):
        x, y = int(x), int(y)
        return (integral[y + h, x + w] - integral[y, x + w] - integral[y + h, x] + integral[y, x]) / (w * h)

    best, best_score = (margin, margin), -1e9
    xs = [margin, S - margin - w] if corners_only else range(margin, S - margin - w + 1, 24)
    ys = [margin, S - margin - h] if corners_only else range(margin, S - margin - h + 1, 24)
    for y in ys:
        for x in xs:
            score = area(x, y)
            for px, py in points:
                if x - 60 <= px <= x + w + 60 and y - 60 <= py <= y + h + 60:
                    score -= 5
            for ax, ay, aw, ah in avoid:
                if x < ax + aw + 30 and ax < x + w + 30 and y < ay + ah + 30 and ay < y + h + 30:
                    score -= 10
            if prefer_edges:
                edge = min(x - margin, y - margin, S - margin - (x + w), S - margin - (y + h))
                score -= 0.0004 * edge
            if score > best_score:
                best, best_score = (x, y), score
    return best


def rose_block(img, free, points, avoid, proj, pal, accent, paper_color, n_font, bar_meters, bar_label, bar_font, radius=140, corners_only=False):
    """方位記号と縮尺をひとまとめに置く（縮尺は方位記号の下）。"""
    w, h = int(radius * 2.6), int(radius * 3.3)
    x, y = find_spot(free, w, h, points, avoid, corners_only=corners_only)
    cx, cy = x + w / 2, y + radius * 1.5
    compass_rose(img, cx, cy, radius, pal["ink"], accent, paper_color, n_font)
    length = bar_meters / proj.meters_per_px()
    scale_bar(img, cx - length / 2, cy + radius * 1.25, proj, pal["ink"], paper_color, bar_meters, bar_label, bar_font)
    return (x, y, w, h)


def ship(img, cx, cy, size, hull, sail, ink, flag=None, flag2=None):
    """帆船（オランダのフライト船・ハンザのコグ船を簡略化したもの）。"""
    d = ImageDraw.Draw(img)
    s = size
    d.polygon([(cx - s, cy), (cx + s, cy), (cx + s * 0.7, cy + s * 0.35), (cx - s * 0.75, cy + s * 0.35)], fill=hull, outline=ink)
    d.line([(cx - s * 1.05, cy - s * 0.05), (cx - s * 0.6, cy - s * 0.2)], fill=ink, width=2)
    for mx, h in ((cx - s * 0.35, 1.25), (cx + s * 0.25, 1.5)):
        d.line([(mx, cy), (mx, cy - s * h)], fill=ink, width=3)
        for k in range(2):
            top = cy - s * h + s * 0.15 + k * s * 0.55
            d.polygon([(mx - s * 0.32, top), (mx + s * 0.32, top), (mx + s * 0.38, top + s * 0.45), (mx - s * 0.38, top + s * 0.45)], fill=sail, outline=ink)
        if flag:
            d.polygon([(mx, cy - s * h), (mx + s * 0.35, cy - s * h + s * 0.08), (mx, cy - s * h + s * 0.16)], fill=flag, outline=None)
            if flag2:
                d.polygon([(mx, cy - s * h + s * 0.08), (mx + s * 0.35, cy - s * h + s * 0.08), (mx, cy - s * h + s * 0.16)], fill=flag2)
    for i in range(4):
        wx = cx - s + i * s * 0.6
        d.arc([wx, cy + s * 0.3, wx + s * 0.5, cy + s * 0.55], 200, 340, fill=ink, width=2)


def crown(d, cx, cy, w, fill, ink):
    """スウェーデンの三つの王冠（トレ・クローノル）に使う王冠。"""
    h = w * 0.62
    base_y = cy + h / 2
    pts = [(cx - w / 2, base_y), (cx - w / 2, cy - h * 0.1), (cx - w * 0.3, cy + h * 0.1), (cx - w * 0.15, cy - h / 2),
           (cx, cy + h * 0.05), (cx + w * 0.15, cy - h / 2), (cx + w * 0.3, cy + h * 0.1), (cx + w / 2, cy - h * 0.1), (cx + w / 2, base_y)]
    d.polygon(pts, fill=fill, outline=ink)
    d.rectangle([cx - w / 2, base_y - h * 0.18, cx + w / 2, base_y], fill=fill, outline=ink)
    for px in (cx - w * 0.15, cx + w * 0.15, cx):
        d.ellipse([px - w * 0.05, cy - h / 2 - w * 0.05 if px != cx else cy - w * 0.02, px + w * 0.05, cy - h / 2 + w * 0.05 if px != cx else cy + w * 0.08], fill=fill, outline=ink)


def pine(d, x, y, h, fill, ink):
    """フィンランドの森を表す小さな松（木版画風の三角形の重ね）。"""
    for k in range(3):
        top = y - h + k * h * 0.28
        w = h * (0.28 + k * 0.1)
        d.polygon([(x, top), (x - w, top + h * 0.42), (x + w, top + h * 0.42)], fill=fill, outline=ink)
    d.line([(x, y - h * 0.1), (x, y + h * 0.1)], fill=ink, width=3)


# ---------------------------------------------------------------- 都市ごとの設定

CITIES = {}


def city(name):
    def register(fn):
        CITIES[name] = fn
        return fn
    return register


def base_map(elements, proj, rng, pal, building_color=None, building_outline=None, road_scale=1.0,
             shore_rings=4, shore_spacing=7, hatch_step=22, green_filter=None):
    img = paper(pal["paper"], rng)
    water = water_mask(elements, proj)

    # 公園・森
    green = Image.new("L", (S, S), 0)
    gd = ImageDraw.Draw(green)
    greens = green_filter or (lambda t: t.get("leisure") in ("park", "garden") or t.get("landuse") in ("forest", "grass", "meadow", "cemetery") or t.get("natural") == "wood")
    for pts in polygons(elements, proj, greens):
        gd.polygon(pts, fill=255)
    green = ImageChops.subtract(green, water)
    fill_mask(img, green, pal["green"], alpha=150)

    # 建物（街区）
    if building_color:
        bd = ImageDraw.Draw(img)
        colors = building_color if isinstance(building_color, list) else [building_color]
        for pts in polygons(elements, proj, lambda t: "building" in t):
            bd.polygon(pts, fill=colors[int(rng.integers(0, len(colors)))], outline=building_outline)

    # 鉄道（ハッチ線）
    d = ImageDraw.Draw(img)
    for _, pts in lines(elements, proj, lambda t: t.get("railway") == "rail"):
        d.line(pts, fill=pal["ink"], width=5)
        d.line(pts, fill=pal["paper"], width=2)

    draw_roads(img, elements, proj, pal["road_casing"], pal["road"], scale=road_scale)

    # 水面（道路・建物の上から塗って、橋以外を隠す）
    fill_mask(img, water, pal["water"])
    engraved_shore(img, water, pal["water_line"], shore_rings, shore_spacing)
    wave_hatch(img, water, pal["water_line"], hatch_step, 3, rng, alpha=70)
    # 岸の輪郭
    edge = ImageChops.subtract(water.filter(ImageFilter.MaxFilter(5)), water)
    fill_mask(img, edge, pal["ink"])

    # 運河・川の中心線（細い水路）
    for _, pts in lines(elements, proj, lambda t: t.get("waterway") in ("canal", "river", "stream")):
        d.line(pts, fill=pal["water_line"], width=2)
    return img, water


def ornament_border(img, pal, band, pattern, rng):
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, S - 1, S - 1], outline=pal["ink"], width=band)
    inner = band
    d.rectangle([inner, inner, S - 1 - inner, S - 1 - inner], outline=pal["ink"], width=3)
    pattern(d, band)
    d.rectangle([band + 10, band + 10, S - 1 - band - 10, S - 1 - band - 10], outline=pal["ink"], width=2)


# ---- ヘルシンキ: フィンランドのナショナル・ロマンティシズム（1900年前後のユーゲント様式）

@city("helsinki")
def helsinki(elements, proj, rng):
    pal = dict(paper=(239, 232, 212), green=(126, 146, 104), ink=rgb("2b3a4a"), road=(246, 240, 224),
               road_casing=rgb("6b5d4b"), water=rgb("8fa9bf"), water_line=rgb("3d5a78"))
    blue, birch = rgb("1f4e8c"), (246, 243, 232)
    img, water = base_map(elements, proj, rng, pal, building_color=(214, 196, 164), building_outline=None,
                          road_scale=0.9, shore_rings=5, shore_spacing=9, hatch_step=26)
    d = ImageDraw.Draw(img)

    # 森（公園・森の中に松を散らす）
    greens = Image.new("L", (S, S), 0)
    gd = ImageDraw.Draw(greens)
    for pts in polygons(elements, proj, lambda t: t.get("natural") == "wood" or t.get("landuse") == "forest" or t.get("leisure") == "park"):
        gd.polygon(pts, fill=255)
    garr = np.array(greens) > 0
    warr = np.array(water) > 0
    for _ in range(900):
        x, y = rng.integers(90, S - 90), rng.integers(90, S - 90)
        if garr[y, x] and not warr[y, x]:
            pine(d, x, y, 22, rgb("4d6b45"), pal["ink"])

    # 地名（水面）
    ital = font("Didot.ttc", 34, index=2)
    for text, lat, lon, ang in [("SUOMENLAHTI · FINSKA VIKEN", 60.1462, 24.935, 0), ("Eteläsatama", 60.1602, 24.9590, 0),
                                ("Kruunuvuorenselkä", 60.1660, 25.004, -12), ("Seurasaarenselkä", 60.1790, 24.8995, 78)]:
        x, y = proj(lat, lon)
        curved_label(img, text, x, y, ital, pal["water_line"], angle=ang, spacing=8)

    def pattern(d, band):
        # 縁取り: カレリア刺繍風の菱形と三角の連続文様（青と白樺色）
        d.rectangle([6, 6, S - 7, S - 7], outline=blue, width=band - 12)
        step = 44
        for i in range(0, S, step):
            for (x, y, horiz) in ((i, band / 2, True), (i, S - band / 2, True), (band / 2, i, False), (S - band / 2, i, False)):
                if horiz:
                    d.polygon([(x, y), (x + step / 2, y - 12), (x + step, y), (x + step / 2, y + 12)], fill=birch, outline=blue)
                else:
                    d.polygon([(x, y), (x - 12, y + step / 2), (x, y + step), (x + 12, y + step / 2)], fill=birch, outline=blue)
    ornament_border(img, pal, 44, pattern, rng)

    # 題名の枠: ユーゲント様式の角を落とした枠と、松の飾り
    cw, ch = 760, 330
    pts = [proj(*c) for c in CHECKPOINTS["helsinki"]]
    cx0, cy0 = find_spot(water, cw, ch, pts)
    d.rounded_rectangle([cx0, cy0, cx0 + cw, cy0 + ch], radius=40, fill=birch, outline=blue, width=6)
    d.rounded_rectangle([cx0 + 14, cy0 + 14, cx0 + cw - 14, cy0 + ch - 14], radius=30, outline=pal["ink"], width=2)
    for k in range(5):
        pine(d, cx0 + 70 + k * 20, cy0 + ch - 40, 34 - abs(k - 2) * 6, rgb("4d6b45"), pal["ink"])
        pine(d, cx0 + cw - 150 + k * 20, cy0 + ch - 40, 34 - abs(k - 2) * 6, rgb("4d6b45"), pal["ink"])
    mid = cx0 + cw / 2
    centered_text(d, mid, cy0 + 42, "HELSINGFORS", font("Copperplate.ttc", 92, index=1), blue, spacing=6)
    centered_text(d, mid, cy0 + 150, "· HELSINKI · ANNO MDCCCXL ·", font("Didot.ttc", 34, index=2), pal["ink"])
    centered_text(d, mid, cy0 + 205, "ヘルシンキ旧市街（帝政期）", ImageFont.truetype(JP_FONT, 40, index=0), pal["ink"])
    d.line([(mid - 150, cy0 + 268), (mid + 150, cy0 + 268)], fill=blue, width=3)
    centered_text(d, mid, cy0 + 280, "KOMAP · EUROPE", font("Didot.ttc", 22), pal["ink"], spacing=8)

    rose_block(img, water, pts, [(cx0, cy0, cw, ch)], proj, pal, blue, birch, font("Copperplate.ttc", 44),
               1000, "1000 m", font("Didot.ttc", 28))
    return img


# ---- ストックホルム: スウェーデンのバロック（カロリン朝の都市図）

@city("stockholm")
def stockholm(elements, proj, rng):
    pal = dict(paper=(240, 230, 205), green=(140, 150, 104), ink=rgb("2c2a33"), road=(244, 236, 214),
               road_casing=rgb("75654f"), water=rgb("a7bcbf"), water_line=rgb("4a6468"))
    blue, gold, falu, ochre = rgb("1d4f91"), rgb("d4a52c"), rgb("9c3b2b"), rgb("d9a45a")
    img, water = base_map(elements, proj, rng, pal, building_color=None, road_scale=1.3, shore_rings=6, shore_spacing=8, hatch_step=20)
    d = ImageDraw.Draw(img)
    # 建物: ファールン赤と黄土色の漆喰を交互に（ガムラスタンの家並み）
    for pts in polygons(elements, proj, lambda t: "building" in t):
        d.polygon(pts, fill=falu if rng.random() < 0.45 else ochre, outline=pal["ink"])

    ital = font("Didot.ttc", 44, index=2)
    for text, lat, lon, ang in [("SALTSJÖN", 59.3232, 18.0835, 8), ("RIDDARFJÄRDEN", 59.3229, 18.0663, 62)]:
        x, y = proj(lat, lon)
        curved_label(img, text, x, y, ital, pal["water_line"], angle=ang, spacing=10)

    def pattern(d, band):
        d.rectangle([6, 6, S - 7, S - 7], outline=blue, width=band - 12)
        d.rectangle([band - 12, band - 12, S - band + 11, S - band + 11], outline=gold, width=4)
        for (x, y) in ((band / 2, band / 2), (S - band / 2, band / 2), (band / 2, S - band / 2), (S - band / 2, S - band / 2)):
            crown(d, x, y, 36, gold, pal["ink"])
        for i in range(150, S - 100, 180):
            for (x, y) in ((i, band / 2), (i, S - band / 2), (band / 2, i), (S - band / 2, i)):
                d.ellipse([x - 6, y - 6, x + 6, y + 6], fill=gold, outline=pal["ink"])
    ornament_border(img, pal, 48, pattern, rng)

    # 題名: バロックの巻物飾りの枠と、三つの王冠
    cw, ch = 740, 380
    pts = [proj(*c) for c in CHECKPOINTS["stockholm"]]
    cx0, cy0 = find_spot(water, cw, ch, pts)
    d.rounded_rectangle([cx0, cy0, cx0 + cw, cy0 + ch], radius=24, fill=(246, 238, 216), outline=pal["ink"], width=4)
    for sx in (cx0, cx0 + cw):
        for sy in (cy0 + 60, cy0 + ch - 60):
            d.ellipse([sx - 34, sy - 34, sx + 34, sy + 34], fill=(246, 238, 216), outline=pal["ink"], width=4)
            d.ellipse([sx - 16, sy - 16, sx + 16, sy + 16], outline=pal["ink"], width=3)
    mid = cx0 + cw / 2
    for k, off in enumerate((-70, 0, 70)):
        crown(d, mid + off, cy0 + 62 + (0 if k != 1 else -14), 54, gold, pal["ink"])
    centered_text(d, mid, cy0 + 100, "STOCKHOLMIA", font("Trattatello.ttf", 96), blue)
    centered_text(d, mid, cy0 + 236, "HOLMIA · ANNO MDCC", font("Copperplate.ttc", 32), pal["ink"], spacing=3)
    centered_text(d, mid, cy0 + 284, "ストックホルム旧市街（ガムラスタン）", ImageFont.truetype(JP_FONT, 36), pal["ink"])
    centered_text(d, mid, cy0 + 336, "KOMAP · EUROPE", font("Didot.ttc", 22), pal["ink"], spacing=8)

    rose_block(img, water, pts, [(cx0, cy0, cw, ch)], proj, pal, blue, (246, 238, 216), font("Copperplate.ttc", 44),
               119, "200 alnar ≈ 120 m", font("Didot.ttc", 26, index=2), radius=130)
    return img


# ---- アムステルダム: オランダ黄金時代（ブラウ／ヨアン・ブラウの都市図風の手彩色銅版画）

@city("amsterdam")
def amsterdam(elements, proj, rng):
    pal = dict(paper=(238, 226, 196), green=(150, 160, 100), ink=rgb("33261a"), road=(241, 231, 204),
               road_casing=rgb("6a5236"), water=rgb("9fbfa9"), water_line=rgb("3e5f4d"))
    orange, red = rgb("d9772b"), rgb("a52a2a")
    img, water = base_map(elements, proj, rng, pal, building_color=rgb("c79f72"), building_outline=rgb("6a4a30"),
                          road_scale=1.0, shore_rings=3, shore_spacing=6, hatch_step=14)
    d = ImageDraw.Draw(img)

    ital = font("Didot.ttc", 40, index=2)
    for text, lat, lon, ang in [("AMSTEL", 52.3625, 4.9025, 60), ("Het IJ", 52.3795, 4.9075, 0),
                                ("Herengracht", 52.3700, 4.8878, 72), ("Singel", 52.3737, 4.8903, 80)]:
        x, y = proj(lat, lon)
        curved_label(img, text, x, y, ital, pal["water_line"], angle=ang, halo=(238, 226, 196), spacing=6)

    def pattern(d, band):
        # 縁取り: ブラウの地図によくある、目盛りのような白黒の市松の帯
        d.rectangle([6, 6, S - 7, S - 7], outline=pal["ink"], width=4)
        step = 64
        for i in range(0, S, step):
            f = pal["ink"] if (i // step) % 2 == 0 else (240, 232, 210)
            d.rectangle([i, 10, i + step, band - 8], fill=f)
            d.rectangle([i, S - band + 8, i + step, S - 10], fill=f)
            d.rectangle([10, i, band - 8, i + step], fill=f)
            d.rectangle([S - band + 8, i, S - 10, i + step], fill=f)
    ornament_border(img, pal, 40, pattern, rng)

    cw, ch = 780, 350
    pts = [proj(*c) for c in CHECKPOINTS["amsterdam"]]
    cx0, cy0 = find_spot(water, cw, ch, pts)
    # IJ（北側）の水面に帆船
    warr = np.array(water) > 0
    placed = 0
    ship_spots = []
    for _ in range(4000):
        if placed >= 4:
            break
        x, y = rng.integers(200, S - 200), rng.integers(90, 520)
        in_title = cx0 - 90 < x < cx0 + cw + 90 and cy0 - 120 < y < cy0 + ch + 60
        too_close = any(abs(x - sx) < 200 and abs(y - sy) < 160 for sx, sy in ship_spots)
        if not in_title and not too_close and warr[max(0, y - 80):y + 40, max(0, x - 80):x + 80].mean() > 0.97:
            ship_spots.append((x, y))
            ship(img, x, y, 46, rgb("6b4226"), (243, 236, 220), pal["ink"], flag=red, flag2=(245, 245, 245))
            placed += 1

    d.rectangle([cx0, cy0, cx0 + cw, cy0 + ch], fill=(244, 235, 212), outline=pal["ink"], width=5)
    # 巻物の端
    for sx, dirx in ((cx0, -1), (cx0 + cw, 1)):
        d.pieslice([sx - 40, cy0, sx + 40, cy0 + 80], 90 if dirx < 0 else 270, 270 if dirx < 0 else 450, fill=orange, outline=pal["ink"], width=3)
        d.pieslice([sx - 40, cy0 + ch - 80, sx + 40, cy0 + ch], 90 if dirx < 0 else 270, 270 if dirx < 0 else 450, fill=orange, outline=pal["ink"], width=3)
    d.rectangle([cx0 + 18, cy0 + 18, cx0 + cw - 18, cy0 + ch - 18], outline=orange, width=3)
    mid = cx0 + cw / 2
    # アムステルダム市章の三つのX（聖アンデレ十字）
    for off in (-60, 0, 60):
        x0, y0 = mid + off, cy0 + 60
        d.line([(x0 - 16, y0 - 16), (x0 + 16, y0 + 16)], fill=red, width=9)
        d.line([(x0 - 16, y0 + 16), (x0 + 16, y0 - 16)], fill=red, width=9)
    centered_text(d, mid, cy0 + 92, "AMSTELODAMUM", font("Trattatello.ttf", 92), pal["ink"])
    centered_text(d, mid, cy0 + 200, "Nova et accurata descriptio · MDCL", font("Didot.ttc", 30, index=2), pal["ink"])
    centered_text(d, mid, cy0 + 245, "アムステルダム旧市街（黄金時代）", ImageFont.truetype(JP_FONT, 36), pal["ink"])
    centered_text(d, mid, cy0 + 300, "KOMAP · EUROPE", font("Didot.ttc", 20), pal["ink"], spacing=8)

    rose_block(img, water, pts, [(cx0, cy0, cw, ch)], proj, pal, orange, (244, 235, 212), font("Copperplate.ttc", 42),
               300, "300 m", font("Didot.ttc", 26, index=2), radius=120, corners_only=True)
    return img


# ---- タリン: ハンザ同盟時代のレヴァル（赤い屋根と城壁の中世都市図）

@city("tallinn")
def tallinn(elements, proj, rng):
    pal = dict(paper=(239, 228, 200), green=(150, 158, 110), ink=rgb("2a2622"), road=(236, 224, 196),
               road_casing=rgb("7b6a55"), water=rgb("93a9b3"), water_line=rgb("40545e"))
    roof, blue = rgb("b14e36"), rgb("2f5d8a")
    img, water = base_map(elements, proj, rng, pal, building_color=None, road_scale=1.4, shore_rings=5, shore_spacing=8, hatch_step=20)
    d = ImageDraw.Draw(img)
    # トームペアの丘（等高線風の陰影）
    hx, hy = proj(59.4370, 24.7392)
    for k in range(6, 0, -1):
        r = 60 + k * 45
        d.ellipse([hx - r * 1.3, hy - r, hx + r * 1.3, hy + r], outline=(180, 160, 120), width=2)
    # 旧市街（城壁で囲まれた下町と、トームペアの丘）の範囲: 城壁の点の凸包を少し広げたもの
    walls = list(lines(elements, proj, lambda t: t.get("historic") == "citywalls" or t.get("barrier") == "city_wall"))
    wall_pts = sorted({(round(x), round(y)) for _, pts in walls for x, y in pts} | {(round(hx), round(hy))})

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p_ in wall_pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p_) <= 0:
            lower.pop()
        lower.append(p_)
    for p_ in reversed(wall_pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p_) <= 0:
            upper.pop()
        upper.append(p_)
    old_town = Image.new("L", (S, S), 0)
    ImageDraw.Draw(old_town).polygon(lower[:-1] + upper[:-1], fill=255)
    old_town = old_town.filter(ImageFilter.MaxFilter(41))
    old_arr = np.array(old_town) > 0
    # 旧市街の外は、中世の都市図の「郊外」らしく淡い色で描いて、城壁の内側を引き立てる
    outside = Image.fromarray(((~old_arr) * 255).astype("uint8"))
    fill_mask(img, outside, pal["paper"], alpha=110)
    # 建物: 城壁の内側は赤い瓦屋根、外側は淡い黄土色
    for pts in polygons(elements, proj, lambda t: "building" in t):
        cx_, cy_ = sum(p_[0] for p_ in pts) / len(pts), sum(p_[1] for p_ in pts) / len(pts)
        inside = 0 <= int(cx_) < S and 0 <= int(cy_) < S and old_arr[int(cy_), int(cx_)]
        if inside:
            d.polygon(pts, fill=roof, outline=pal["ink"])
        else:
            d.polygon(pts, fill=(222, 206, 172), outline=(170, 150, 118))
    free = outside
    # 城壁と塔
    for _, pts in walls:
        d.line(pts, fill=rgb("5d5046"), width=16, joint="curve")
        d.line(pts, fill=rgb("8a7a66"), width=8, joint="curve")
    for _, pts in walls:
        acc = 0
        for a, b in zip(pts, pts[1:]):
            acc += math.hypot(b[0] - a[0], b[1] - a[1])
            if acc > 110:
                acc = 0
                d.ellipse([b[0] - 16, b[1] - 16, b[0] + 16, b[1] + 16], fill=rgb("8a7a66"), outline=pal["ink"], width=3)
                d.pieslice([b[0] - 16, b[1] - 30, b[0] + 16, b[1] + 2], 200, 340, fill=roof, outline=pal["ink"])

    ital = font("Didot.ttc", 44, index=2)
    for text, lat, lon, ang in [("TOOMPEA", 59.4366, 24.7386, 0), ("ALL-LINN", 59.4400, 24.7462, 0)]:
        x, y = proj(lat, lon)
        curved_label(img, text, x, y, font("Luminari.ttf", 50), pal["ink"], angle=ang, halo=(239, 228, 200), spacing=10)
    warr = np.array(water) > 0
    if warr.mean() > 0.02:
        ys, xs = np.nonzero(warr[:900])
        if len(xs):
            i = len(xs) // 2
            ship(img, int(xs[i]), int(ys[i]), 50, rgb("5a3a22"), (240, 232, 214), pal["ink"], flag=blue, flag2=(245, 245, 245))

    def pattern(d, band):
        # 縁取り: 青・黒・白の三本線（エストニアの色）
        d.rectangle([4, 4, S - 5, S - 5], outline=blue, width=14)
        d.rectangle([18, 18, S - 19, S - 19], outline=pal["ink"], width=12)
        d.rectangle([30, 30, S - 31, S - 31], outline=(246, 242, 232), width=10)
    ornament_border(img, pal, 46, pattern, rng)

    cw, ch = 760, 340
    pts = [proj(*c) for c in CHECKPOINTS["tallinn"]]
    cx0, cy0 = find_spot(free, cw, ch, pts)
    d.rectangle([cx0, cy0, cx0 + cw, cy0 + ch], fill=(245, 236, 214), outline=pal["ink"], width=5)
    # 盾（タリン小紋章: 青地に白十字）
    sx, sy = cx0 + 90, cy0 + ch / 2
    d.polygon([(sx - 50, sy - 70), (sx + 50, sy - 70), (sx + 50, sy + 10), (sx, sy + 75), (sx - 50, sy + 10)], fill=blue, outline=pal["ink"], width=4)
    d.rectangle([sx - 8, sy - 70, sx + 8, sy + 60], fill=(246, 242, 232))
    d.rectangle([sx - 50, sy - 22, sx + 50, sy - 6], fill=(246, 242, 232))
    mid = cx0 + cw / 2 + 60
    centered_text(d, mid, cy0 + 50, "REVALIA", font("Luminari.ttf", 104), roof)
    centered_text(d, mid, cy0 + 175, "Civitas Hanseatica · MDC", font("Didot.ttc", 32, index=2), pal["ink"])
    centered_text(d, mid, cy0 + 222, "タリン旧市街（ハンザ同盟）", ImageFont.truetype(JP_FONT, 38), pal["ink"])
    centered_text(d, mid, cy0 + 285, "KOMAP · EUROPE", font("Didot.ttc", 22), pal["ink"], spacing=8)

    rose_block(img, free, pts, [(cx0, cy0, cw, ch)], proj, pal, roof, (245, 236, 214), font("Luminari.ttf", 44),
               100, "100 m", font("Didot.ttc", 26, index=2), radius=120)
    return img


BOUNDS = {
    "helsinki": (60.141, 24.886, 60.224, 25.053),
    "stockholm": (59.317, 18.063, 59.329, 18.089),
    "amsterdam": (52.360, 4.883, 52.380, 4.916),
    "tallinn": (59.436, 24.736, 59.444, 24.752),
}


def main(names):
    out = HERE / "out"
    out.mkdir(exist_ok=True)
    for name in names:
        rng = np.random.default_rng(sum(map(ord, name)))
        random.seed(name)
        proj = Projection(*BOUNDS[name])
        img = CITIES[name](load(name), proj, rng)
        # 地図データの出典（ODbL）
        d = ImageDraw.Draw(img)
        credit = "Map data © OpenStreetMap contributors"
        f = font("Didot.ttc", 22, index=2)
        tw = d.textlength(credit, font=f)
        x, y = S - 70 - tw, S - 92
        d.rectangle([x - 8, y - 4, x + tw + 8, y + 28], fill=(240, 232, 212))
        d.text((x, y), credit, font=f, fill=(70, 60, 50))
        img = img.resize((OUT, OUT), Image.LANCZOS)
        img.save(out / f"{name}.png", optimize=True)
        print("wrote", out / f"{name}.png")


if __name__ == "__main__":
    main(sys.argv[1:] or list(CITIES))
