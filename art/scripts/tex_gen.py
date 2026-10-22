"""Generates papel picado atlas (RGBA, cut-outs in alpha) - 4 designs x 1 row, 1024x512."""
from PIL import Image, ImageDraw
import math
OUT = "/workspace/roblox/steal-a-pinata/art/textures/papel_picado_atlas.png"
W, H = 1024, 512; FW = W // 4
cols = ["#FF3E9A", "#FFE14D", "#16D3E8", "#8BE530"]
img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
S = 2  # supersample
big = Image.new("RGBA", (W * S, H * S), (0, 0, 0, 0))
d = ImageDraw.Draw(big)
def star(cx, cy, ro, ri, n=5, rot=-math.pi / 2):
    pts = []
    for i in range(n * 2):
        a = rot + math.pi * i / n; r = ro if i % 2 == 0 else ri
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts
for k, c in enumerate(cols):
    x0 = k * FW * S; m = 10 * S; fw = FW * S; fh = H * S
    # flag body
    d.rectangle([x0 + m, 0, x0 + fw - m, fh - 40 * S], fill=c)
    # scalloped bottom edge
    n = 7; sw = (fw - 2 * m) / n
    for i in range(n):
        cx = x0 + m + sw * (i + .5)
        d.pieslice([cx - sw / 2, fh - 40 * S - sw / 2, cx + sw / 2, fh - 40 * S + sw / 2], 0, 180, fill=c)
    T = (0, 0, 0, 0)
    # hem holes row under the top fold
    for i in range(9):
        cx = x0 + m + (fw - 2 * m) * (i + .5) / 9
        d.ellipse([cx - 6 * S, 34 * S, cx + 6 * S, 46 * S], fill=T)
    # inner border of small diamonds
    for side in range(2):
        for j in range(7):
            cy = 80 * S + j * 40 * S
            cx = x0 + (m + 22 * S if side == 0 else fw - m - 22 * S)
            d.polygon([(cx, cy - 10 * S), (cx + 8 * S, cy), (cx, cy + 10 * S), (cx - 8 * S, cy)], fill=T)
    cx = x0 + fw / 2; cy = 230 * S
    if k == 0:   # big star (piñata!) with inner star kept
        d.polygon(star(cx, cy, 88 * S, 40 * S), fill=T)
        d.polygon(star(cx, cy, 40 * S, 18 * S), fill=c)
    elif k == 1:  # flower
        for i in range(8):
            a = 2 * math.pi * i / 8
            px, py = cx + 55 * S * math.cos(a), cy + 55 * S * math.sin(a)
            d.ellipse([px - 26 * S, py - 26 * S, px + 26 * S, py + 26 * S], fill=T)
        d.ellipse([cx - 30 * S, cy - 30 * S, cx + 30 * S, cy + 30 * S], fill=c)
        d.ellipse([cx - 12 * S, cy - 12 * S, cx + 12 * S, cy + 12 * S], fill=T)
    elif k == 2:  # wrapped candy
        d.ellipse([cx - 45 * S, cy - 32 * S, cx + 45 * S, cy + 32 * S], fill=T)
        d.polygon([(cx - 40 * S, cy), (cx - 95 * S, cy - 38 * S), (cx - 95 * S, cy + 38 * S)], fill=T)
        d.polygon([(cx + 40 * S, cy), (cx + 95 * S, cy - 38 * S), (cx + 95 * S, cy + 38 * S)], fill=T)
        for i in range(3):
            xx = cx - 25 * S + i * 25 * S
            d.line([(xx - 8 * S, cy - 26 * S), (xx + 8 * S, cy + 26 * S)], fill=c, width=7 * S)
    else:  # heart
        r = 36 * S
        d.ellipse([cx - 2 * r + 4 * S, cy - r - 20 * S, cx + 4 * S, cy + r - 20 * S], fill=T)
        d.ellipse([cx - 4 * S, cy - r - 20 * S, cx + 2 * r - 4 * S, cy + r - 20 * S], fill=T)
        d.polygon([(cx - 2 * r + 6 * S, cy - 4 * S), (cx + 2 * r - 6 * S, cy - 4 * S), (cx, cy + 80 * S)], fill=T)
    # lower lattice: small stars row
    for i in range(4):
        px = x0 + m + (fw - 2 * m) * (i + .5) / 4
        d.polygon(star(px, 375 * S, 16 * S, 7 * S), fill=T)
    for i in range(3):
        px = x0 + m + (fw - 2 * m) * (i + 1) / 4
        d.ellipse([px - 7 * S, 405 * S - 7 * S, px + 7 * S, 405 * S + 7 * S], fill=T)
img = big.resize((W, H), Image.LANCZOS)
img.save(OUT)
print("saved", OUT)
