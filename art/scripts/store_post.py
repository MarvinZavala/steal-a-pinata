"""store_post: grade + brand text for the store set.  python3 store_post.py [all|icons|thumbs|sheet]
Reads raw Cycles renders from /tmp/store_raw, writes art/renders/store/{icons,thumbnails,thumbnails_en}/ +
previews. Text style = the game logo (logo_gen.py): Luckiest Guy, per-letter fiesta colours, thick ink outline."""
import os, sys, math
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageEnhance, ImageChops

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, "..")
RAW = "/tmp/store_raw"
OUT = os.path.join(ART, "renders", "store")
TX = os.path.join(ART, "textures")
FONT = "/usr/share/fonts/truetype/sand-box/google/Luckiest Guy/LuckiestGuy-Regular.ttf"
INK = "#2B1B4A"                                    # logo outline colour (logo_gen.py)
COLS = ["#FF3EA5", "#FFD23F", "#2EC4F1", "#7BE35A", "#A35BFF", "#FF8A1F"]   # logo letter colours
GOLD = ["#FFE14D", "#FFC22E", "#FFB400"]

# ------------------------------------------------------------------ grade
def grade(im, sat=1.1, con=1.05, bloom=.35, thr=200, rad=None, vig=.18):
    im = im.convert("RGB")
    rad = rad or max(im.size) / 90
    a = np.asarray(im).astype(np.float32)
    lum = a @ np.array([.299, .587, .114], np.float32)
    mask = np.clip((lum - thr) / (255 - thr), 0, 1)[..., None]
    bright = Image.fromarray((a * mask).astype(np.uint8)).filter(ImageFilter.GaussianBlur(rad))
    b = np.asarray(bright).astype(np.float32) * bloom
    a = 255 - (255 - a) * (255 - b) / 255                # screen blend
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    im = ImageEnhance.Color(im).enhance(sat); im = ImageEnhance.Contrast(im).enhance(con)
    if vig:
        w, h = im.size
        v = Image.new("L", (w, h), 0); d = ImageDraw.Draw(v)
        d.ellipse((-w * .2, -h * .3, w * 1.2, h * 1.3), fill=255); v = v.filter(ImageFilter.GaussianBlur(max(w, h) / 9))
        dark = ImageEnhance.Brightness(im).enhance(1 - vig)
        im = Image.composite(im, dark, v)
    return im

# ------------------------------------------------------------------ brand text
def _fill_for(style, i, ch):
    if style == "rainbow": return COLS[i % len(COLS)]
    if style == "gold": return GOLD[i % len(GOLD)]
    if style == "white": return "#FFFFFF"
    return style

def text_layer(lines, gap=.18, track=.03, stroke=.11, align="center"):
    """lines: [(text, size_px, style)] -> RGBA layer (tight), logo look: ink stroke + soft drop shadow."""
    fonts = [ImageFont.truetype(FONT, s) for _, s, _ in lines]
    tmp = ImageDraw.Draw(Image.new("RGBA", (10, 10)))
    widths = []
    for (t, s, _), f in zip(lines, fonts):
        widths.append(sum(tmp.textlength(c, font=f) for c in t) + (len(t) - 1) * s * track)
    maxs = max(s for _, s, _ in lines)
    W = int(max(widths) + maxs * .6); H = int(sum(s * (1 + gap) for _, s, _ in lines) + maxs * .6)
    lay = Image.new("RGBA", (W, H), (0, 0, 0, 0)); sh = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(lay); ds = ImageDraw.Draw(sh)
    y = maxs * .3; ci = 0
    for (t, s, style), f, w in zip(lines, fonts, widths):
        sw = max(3, int(s * stroke))
        x = (W - w) / 2 if align == "center" else (maxs * .3 if align == "left" else W - w - maxs * .3)
        for c in t:
            fill = _fill_for(style, ci, c)
            ds.text((x + s * .05, y + s * .08), c, font=f, fill=INK, stroke_width=sw + 1, stroke_fill=INK)
            d.text((x, y), c, font=f, fill=fill, stroke_width=sw, stroke_fill=INK)
            if c != " ": ci += 1
            x += tmp.textlength(c, font=f) + s * track
        y += s * (1 + gap)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    out.alpha_composite(sh.filter(ImageFilter.GaussianBlur(max(2, maxs / 60))))
    out.alpha_composite(lay)
    # subtle top highlight on letters (glossy toy look)
    bb = out.getbbox(); out = out.crop(bb)
    return out

def put(im, layer, cx, cy, rot=0.0, max_w=None):
    if max_w and layer.width > max_w:
        layer = layer.resize((int(max_w), int(layer.height * max_w / layer.width)), Image.LANCZOS)
    if rot: layer = layer.rotate(rot, resample=Image.BICUBIC, expand=True)
    im = im.convert("RGBA"); im.alpha_composite(layer, (int(cx - layer.width / 2), int(cy - layer.height / 2)))
    return im

def arrow(im, x0, y0, x1, y1, width, fill="#FFFFFF"):
    """Chunky sticker arrow with ink outline (used for 3 -> 1)."""
    lay = Image.new("RGBA", im.size, (0, 0, 0, 0)); d = ImageDraw.Draw(lay)
    ang = math.atan2(y1 - y0, x1 - x0); L = math.hypot(x1 - x0, y1 - y0); hw = width / 2; hl = width * 1.5
    def P(u, v): return (x0 + u * math.cos(ang) - v * math.sin(ang), y0 + u * math.sin(ang) + v * math.cos(ang))
    poly = [P(0, -hw), P(L - hl, -hw), P(L - hl, -hw * 2.1), P(L, 0), P(L - hl, hw * 2.1), P(L - hl, hw), P(0, hw)]
    sh = [(x + width * .12, y + width * .16) for x, y in poly]
    d.polygon(sh, fill=INK); lay = lay.filter(ImageFilter.GaussianBlur(2)); d = ImageDraw.Draw(lay)
    d.polygon(poly, fill=fill, outline=INK, width=max(4, int(width * .22)))
    im = im.convert("RGBA"); im.alpha_composite(lay); return im

def logo(w):
    lg = Image.open(os.path.join(TX, "logo_steal_a_pinata.png")).convert("RGBA")
    return lg.resize((int(w), int(lg.height * w / lg.width)), Image.LANCZOS)

def save_png(im, path, max_mb=2.9):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im = im.convert("RGB"); im.save(path, optimize=True)
    if os.path.getsize(path) > max_mb * 1e6:     # Roblox thumbnail upload limit is 3 MB -> quantize if needed
        im.quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG).save(path, optimize=True)
    print(f"{path}  {os.path.getsize(path) / 1e6:.2f} MB")

# ------------------------------------------------------------------ thumbnails
TEXT = {  # key: (es, en)
    "robo": ([("¡ROBA", 150, "white"), ("PIÑATAS!", 215, "rainbow")], [("STEAL", 150, "white"), ("PIÑATAS!", 215, "rainbow")]),
    "coleccion": ([("¡COLECCIÓNALAS TODAS!", 128, "rainbow")], [("COLLECT THEM ALL!", 140, "rainbow")]),
    "fusion": ([("¡FUSIÓN!", 210, "rainbow")], [("FUSE!", 220, "rainbow")]),
    "fusion_tags": ((("DORADA", "x2"), ("ARCOÍRIS", "x5")), (("GOLDEN", "x2"), ("RAINBOW", "x5"))),
    "memes": ([("¡NUEVAS", 130, "white"), ("PIÑATAS!", 200, "rainbow")], [("NEW", 130, "white"), ("PIÑATAS!", 200, "rainbow")]),
    "fiesta": ([("¡FIESTA!", 230, "rainbow"), ("¡LLUEVEN PIÑATAS!", 92, "white")], [("PARTY!", 230, "rainbow"), ("IT'S RAINING PIÑATAS!", 84, "white")]),
}

def thumb(name, lang):
    i = 0 if lang == "es" else 1
    raw = Image.open(f"{RAW}/thumb_{name}.png")
    im = grade(raw)
    W, H = im.size
    if name == "robo":
        im = put(im, text_layer(TEXT["robo"][i], gap=.02), W * .73, H * .2, rot=4, max_w=W * .46)
    elif name == "coleccion":
        im = put(im, text_layer(TEXT["coleccion"][i]), W * .5, H * .1, rot=0, max_w=W * .9)
    elif name == "fusion":
        im = put(im, text_layer(TEXT["fusion"][i]), W * .2, H * .15, rot=-5, max_w=W * .36)
        tg = TEXT["fusion_tags"][i]
        im = put(im, text_layer([("3", 170, "white")]), W * .085, H * .37, rot=-6)
        im = arrow(im, W * .14, H * .37, W * .405, H * .37, 46)
        im = put(im, text_layer([("1", 150, "gold")]), W * .455, H * .33, rot=6)
        im = put(im, text_layer([(tg[0][0], 70, "gold"), (tg[0][1], 120, "gold")], gap=.0), W * .68, H * .2, rot=6)
        im = put(im, text_layer([(tg[1][0], 62, "rainbow"), (tg[1][1], 110, "rainbow")], gap=.0), W * .87, H * .33, rot=-5)
    elif name == "memes":
        im = put(im, text_layer(TEXT["memes"][i], gap=.02), W * .5, H * .17, rot=-3, max_w=W * .5)
    elif name == "fiesta":
        im = put(im, text_layer(TEXT["fiesta"][i], gap=.04), W * .22, H * .19, rot=-5, max_w=W * .4)
    return im

THUMBS = [("robo", "01_robo"), ("coleccion", "02_coleccion"), ("fusion", "03_fusion"), ("memes", "04_memes_random"), ("fiesta", "05_fiesta")]
EN = {"01_robo": "01_steal", "02_coleccion": "02_collection", "03_fusion": "03_fuse", "04_memes_random": "04_meme_random", "05_fiesta": "05_party"}

# ------------------------------------------------------------------ icons
ICONS = [("icon_ladron", "icon_A_ladron", None), ("icon_pulpo", "icon_B_pulpo_arcoiris", "logo"), ("icon_aurazoso_gold", "icon_C_aurazoso_dorado", "pinata")]

def icon(raw_name, badge):
    im = grade(Image.open(f"{RAW}/{raw_name}.png"), sat=1.12, con=1.06, bloom=.3, vig=.22)
    im = im.resize((512, 512), Image.LANCZOS)
    if badge == "logo":
        lg = logo(330); im = im.convert("RGBA"); im.alpha_composite(lg, ((512 - lg.width) // 2, 512 - lg.height - 6))
    elif badge == "pinata":
        im = put(im, text_layer([("¡PIÑATA!", 120, "rainbow")]), 256, 452, rot=-4, max_w=440)
    return im.convert("RGB")

def sheet():
    """contact_sheet.png: all icons (512 + 100px) + all thumbnails ES/EN at a glance."""
    ic = [Image.open(os.path.join(OUT, "icons", f"{n}.png")) for _, n, _ in ICONS]
    th = [Image.open(os.path.join(OUT, "thumbnails", f"{n}.png")) for _, n in THUMBS]
    te = [Image.open(os.path.join(OUT, "thumbnails_en", f"{EN[n]}.png")) for _, n in THUMBS]
    tw, thh = 640, 360; pad = 24
    Wd = pad + 2 * (tw + pad) + 0
    Wd = max(Wd, pad + 3 * (300 + pad) + 3 * (100 + pad))
    Hd = 110 + 300 + pad + 100 + 5 * (thh + pad) + 40
    S = Image.new("RGB", (Wd, Hd), "#1B1430"); d = ImageDraw.Draw(S)
    f = ImageFont.truetype(FONT, 44); fs = ImageFont.truetype(FONT, 26)
    d.text((pad, 30), "STEAL A PIÑATA! - STORE ART SET", font=f, fill="#FFE14D")
    x = pad; y = 110
    for (_, n, _), im in zip(ICONS, ic):
        S.paste(im.resize((300, 300), Image.LANCZOS), (x, y)); d.text((x, y + 304), n, font=fs, fill="white"); x += 300 + pad
    for im in ic:
        S.paste(im.resize((100, 100), Image.LANCZOS), (x, y + 100)); x += 100 + pad
    d.text((x - 3 * (100 + pad), y + 210), "@100px", font=fs, fill="#8BE530")
    y += 300 + pad + 90
    d.text((pad, y - 40), "THUMBNAILS  ES (primary)", font=fs, fill="#16D3E8"); d.text((pad * 2 + tw, y - 40), "EN (localized alternates)", font=fs, fill="#16D3E8")
    for a, b in zip(th, te):
        S.paste(a.resize((tw, thh), Image.LANCZOS), (pad, y)); S.paste(b.resize((tw, thh), Image.LANCZOS), (pad * 2 + tw, y)); y += thh + pad
    S = S.crop((0, 0, max(pad * 3 + 2 * tw, x), y + 10))
    save_png(S, os.path.join(OUT, "contact_sheet.png"), max_mb=4.8)
    # icon readability sheet @100 px and @150 px on Roblox-like light and dark backgrounds
    P = Image.new("RGB", (pad + 3 * (150 + pad) + 3 * (100 + pad), 2 * (150 + pad) + pad + 40), "#F2F4F5"); dp = ImageDraw.Draw(P)
    P.paste(Image.new("RGB", (P.width, P.height // 2), "#191B1D"), (0, P.height // 2))
    for row in range(2):
        x = pad; y = pad + row * (P.height // 2)
        for im in ic:
            P.paste(im.resize((150, 150), Image.LANCZOS), (x, y)); x += 150 + pad
        for im in ic:
            P.paste(im.resize((100, 100), Image.LANCZOS), (x, y + 25)); x += 100 + pad
    save_png(P, os.path.join(OUT, "icons", "icons_preview_100px.png"))

if __name__ == "__main__":
    what = sys.argv[1] if len(sys.argv) > 1 else "all"
    if what in ("all", "icons"):
        for raw, n, badge in ICONS:
            if os.path.exists(f"{RAW}/{raw}.png"): save_png(icon(raw, badge), os.path.join(OUT, "icons", f"{n}.png"))
    if what in ("all", "thumbs"):
        for key, n in THUMBS:
            if not os.path.exists(f"{RAW}/thumb_{key}.png"): continue
            save_png(thumb(key, "es"), os.path.join(OUT, "thumbnails", f"{n}.png"))
            save_png(thumb(key, "en"), os.path.join(OUT, "thumbnails_en", f"{EN[n]}.png"))
    if what in ("all", "sheet"): sheet()
