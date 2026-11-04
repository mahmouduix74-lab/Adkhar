# -*- coding: utf-8 -*-
"""Draws the Samt app icon and writes every iOS size.

The mark is the day's arc — mirrored against the one in the home header so
the icon and the app read as a pair, not a repeat — thin where the day
began, thick where it is now, with a lit point riding the leading edge. It
sits on a faint bed of eight-point stars over the app's night sky.

Run:  python3 tool/make_icon.py
"""
import json, math, os
from PIL import Image, ImageDraw, ImageFilter

S = 4096
GOLD = (194, 145, 58)
GOLD_HI = (232, 196, 122)
SKY_TOP = (11, 16, 38)      # #0B1026, the app's night sky
SKY_BOT = (36, 44, 100)

CX, CY, R = S // 2, int(S * 0.53), int(S * 0.42)
# Mirrored: the header arc runs 190deg -> 350deg; this one runs the other
# way, 350 -> 190, so the two curve opposite each other.
A0, A1 = 345.0, 195.0
W0, W1 = int(S * 0.010), int(S * 0.052)   # thin start, thick end


def background():
    img = Image.new("RGB", (S, S))
    d = ImageDraw.Draw(img)
    for y in range(S):
        t = y / (S - 1)
        t = t * t * (3 - 2 * t)
        d.line([(0, y), (S, y)],
               fill=tuple(round(a + (b - a) * t) for a, b in zip(SKY_TOP, SKY_BOT)))
    return img


def star(d, cx, cy, r, fill):
    pts = []
    for i in range(16):
        rr = r if i % 2 == 0 else r * 0.42
        a = i * math.pi / 8
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    d.polygon(pts, outline=fill)


def pattern(img):
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    step = S * 0.11
    y = -step
    while y < S + step:
        x = -step
        while x < S + step:
            # fade the stars in toward the bottom so they carry the empty
            # lower half without crowding the arc up top
            depth = min(1.0, max(0.0, (y / S - 0.15) / 0.85))
            alpha = int(10 + 46 * depth)
            star(d, x + (step / 2 if int(y / step) % 2 else 0), y,
                 step * 0.30, (255, 255, 255, alpha))
            x += step
        y += step
    img.paste(Image.new("RGB", (S, S), (255, 255, 255)), (0, 0),
              layer.split()[3])


def tapered_arc(steps=480):
    outer, inner = [], []
    for i in range(steps + 1):
        t = i / steps
        ang = math.radians(A0 + (A1 - A0) * t)
        half = W0 + (W1 - W0) * t
        c, s = math.cos(ang), math.sin(ang)
        outer.append((CX + (R + half) * c, CY + (R + half) * s))
        inner.append((CX + (R - half) * c, CY + (R - half) * s))
    return outer + inner[::-1]


def draw():
    img = background()
    pattern(img)

    arc = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ImageDraw.Draw(arc).polygon(tapered_arc(), fill=GOLD + (255,))
    bloom = arc.filter(ImageFilter.GaussianBlur(70))
    img.paste(Image.new("RGB", (S, S), GOLD), (0, 0),
              bloom.split()[3].point(lambda a: int(a * 0.28)))
    img.paste(Image.new("RGB", (S, S), GOLD), (0, 0), arc.split()[3])

    dd = ImageDraw.Draw(img)
    # rounded thin cap (trailing end)
    a0 = math.radians(A0)
    c0 = (CX + R * math.cos(a0), CY + R * math.sin(a0))
    dd.ellipse([c0[0] - W0, c0[1] - W0, c0[0] + W0, c0[1] + W0], fill=GOLD)
    # rounded thick cap (leading end, under the light)
    a1c = math.radians(A1)
    c1 = (CX + R * math.cos(a1c), CY + R * math.sin(a1c))
    dd.ellipse([c1[0] - W1 / 2, c1[1] - W1 / 2,
                c1[0] + W1 / 2, c1[1] + W1 / 2], fill=GOLD)

    # the light on the leading (thick) end
    a1 = math.radians(A1)
    px, py = CX + R * math.cos(a1), CY + R * math.sin(a1)
    halo = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    hd = ImageDraw.Draw(halo)
    for rad, alpha in ((260, 90), (170, 135), (105, 195)):
        hd.ellipse([px - rad, py - rad, px + rad, py + rad], fill=GOLD_HI + (alpha,))
    halo = halo.filter(ImageFilter.GaussianBlur(75))
    img.paste(Image.new("RGB", (S, S), GOLD_HI), (0, 0), halo.split()[3])
    d = ImageDraw.Draw(img)
    d.ellipse([px - 132, py - 132, px + 132, py + 132], fill=GOLD_HI)
    d.ellipse([px - 92, py - 92, px + 92, py + 92], fill=(255, 250, 240))
    return img


def main():
    master = draw().resize((1024, 1024), Image.LANCZOS)
    here = os.path.dirname(os.path.abspath(__file__))
    master.save(os.path.join(here, "icon-1024.png"))

    root = os.path.join(here, os.pardir,
                        "ios/Runner/Assets.xcassets/AppIcon.appiconset")
    contents = json.load(open(os.path.join(root, "Contents.json")))
    wanted = {}
    for e in contents["images"]:
        if "filename" not in e:
            continue
        wanted[e["filename"]] = round(
            float(e["size"].split("x")[0]) * float(e["scale"].rstrip("x")))
    for name, px in sorted(wanted.items(), key=lambda kv: kv[1]):
        master.resize((px, px), Image.LANCZOS).convert("RGB").save(
            os.path.join(root, name))
    print(f"wrote {len(wanted)} iOS icons: {sorted(set(wanted.values()))}")

    # Android. `ic_launcher` is the square icon older launchers show as-is;
    # `ic_launcher_foreground` is the adaptive layer, which every launcher
    # masks to its own shape and may rotate — so the mark is inset to the
    # safe circle (66% of the canvas) to keep it clear of any crop.
    android = os.path.join(here, os.pardir, "android/app/src/main/res")
    buckets = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144,
               "xxxhdpi": 192}
    for bucket, px in buckets.items():
        folder = os.path.join(android, f"mipmap-{bucket}")
        os.makedirs(folder, exist_ok=True)
        master.resize((px, px), Image.LANCZOS).convert("RGB").save(
            os.path.join(folder, "ic_launcher.png"))

        inner = round(px * 0.66)
        layer = Image.new("RGBA", (px, px), (0, 0, 0, 0))
        layer.paste(master.resize((inner, inner), Image.LANCZOS),
                    ((px - inner) // 2, (px - inner) // 2))
        layer.save(os.path.join(folder, "ic_launcher_foreground.png"))
    print(f"wrote {len(buckets) * 2} Android icons")


main()
