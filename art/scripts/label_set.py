"""python3 label_set.py memes2|random  -> labels + title on the lineup raw render, crops, saves art/renders/<out>.png"""
import os
import sys, json
from PIL import Image, ImageDraw, ImageFont
R = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "renders") + "/"
CFG = {
    "memes2": ("lineup_memes_2", "TEMPORADA MEME 2", {
        "garrobita_terenga": "bien terenga, bota el atol", "fantasmita_bu": "¡BÚ! (bizco)", "cochinito_quincena": "rico 2 días al mes",
        "lic_dos_peces": "defiende lo indefendible", "pinovela": "¡¿cómo pudiste?!", "chancla_teledirigida": "nunca falla",
        "aurazoso": "+1000 aura sin hacer nada", "abuelita_en_vivo": "factura en vivo"}),
    "random": ("lineup_random", "COLECCIÓN RANDOM", {
        "caracol_turbo": "lento pero tuneado", "cactus_abrazos": "abrazos gratis (no)", "aguacaton": "la semilla es six-pack",
        "pulpo_dj": "8 brazos, cero descanso"}),
}
out, title, JOKE = CFG[sys.argv[1] if len(sys.argv) > 1 else "memes2"]
im = Image.open(R + out + "_raw.png").convert("RGB"); W, H = im.size
d = ImageDraw.Draw(im)
F = "/usr/share/fonts/truetype/sand-box/google/Luckiest Guy/LuckiestGuy-Regular.ttf"
fn = ImageFont.truetype(F, 38); fr = ImageFont.truetype(F, 28); ft = ImageFont.truetype(F, 92); fj = ImageFont.truetype(F, 23)
RC = {"COMÚN": "#E6EEF9", "POCO COMÚN": "#8BE530", "RARO": "#3DA5FF", "ÉPICO": "#C59BFF", "LEGENDARIO": "#FFC22E", "EVENTO NAVIDAD": "#FF5A6E", "MÍTICO": "#FF4FD8", "SECRETO": "#3FF2FF"}
def txt(x, y, s, f, fill, stroke=6):
    w = d.textlength(s, font=f); d.text((x - w / 2, y), s, font=f, fill=fill, stroke_width=stroke, stroke_fill="#1B1430")
A = json.load(open(f"/tmp/{out}_anchors.json"))
for a in A:
    x = a["u"] * W; y = (1 - a["v"]) * H
    txt(x, y + 6, a["name"].upper(), fn, "white")
    txt(x, y + 54, a["rarity"], fr, RC[a["rarity"]], 5)
    txt(x, y + 92, JOKE[a["key"]], fj, "white", 4)
TOP = 200
txt(W / 2, TOP + 24, title, ft, "#FFE14D", 9)
ymax = max((1 - a["v"]) * H for a in A) + 140
im = im.crop((0, TOP, W, min(H, int(ymax)))); im.save(R + out + ".png"); print("ok", out)
