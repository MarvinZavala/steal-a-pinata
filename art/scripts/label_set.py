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
RC = {"COMÚN": "#E6EEF9", "POCO COMÚN": "#8BE530", "RARO": "#3DA5FF", "ÉPICO": "#C59BFF", "LEGENDARIO": "#FFC22E", "EVENTO NAVIDAD": "#FF5A6E", "MÍTICO": "#FF4FD8", "SECRETO": "#3FF2FF"}
def txt(x, y, s, f, fill, stroke=6):
    w = d.textlength(s, font=f); d.text((x - w / 2, y), s, font=f, fill=fill, stroke_width=stroke, stroke_fill="#1B1430")
LATAM_JOKE = {
    "saltena_jugosa": "si se chorrea, perdiste", "cucurucho_mani": "más ritmo que tú", "arepa_reina": "rellena de cariño",
    "completito_italiano": "se cree italiano", "platanito_merenguero": "no lo majes: baila", "baleada_con_todo": "pidió sencilla",
    "coqui_bocina": "5 cm, se oye en toda la isla", "matecito_termero": "termo hasta en la playa", "gallo_pinton": "trae el desayuno",
    "aranita_nanduti": "cero puntadas chuecas", "piquero_patazul": "patas de tenis nuevos", "alpaca_esponjada": "llovió: pura nube",
    "carretica_pura_vida": "todo es pura vida", "harpia_despeinada": "¿señor disfrazado?", "carpincho_tranqui": "ni se inmutó",
    "quetzalete": "vale un quetzal", "chivita_rumbera": "siempre cabe uno más", "boto_bailao": "sale del río a bailar",
    "ajolote_trajinero": "el ánimo le vuelve a crecer"}
# country tag = small pill with simplified flag colors (stripes, no emblems) + country name
COUNTRY = {
    "saltena_jugosa": ("BOLIVIA", "h", ["#D52B1E", "#F9E300", "#007934"]),
    "cucurucho_mani": ("CUBA", "h", ["#002A8F", "#FFFFFF", "#002A8F", "#FFFFFF", "#002A8F"], "#CF142B"),
    "arepa_reina": ("VENEZUELA", "h", ["#FFCC00", "#00247D", "#CF142B"]),
    "completito_italiano": ("CHILE", "h", ["#FFFFFF", "#D52B1E"], "#0039A6"),
    "platanito_merenguero": ("REP. DOMINICANA", "h", ["#002D62", "#FFFFFF", "#CE1126"]),
    "baleada_con_todo": ("HONDURAS", "h", ["#0073CF", "#FFFFFF", "#0073CF"]),
    "coqui_bocina": ("PUERTO RICO", "h", ["#ED0000", "#FFFFFF", "#ED0000", "#FFFFFF", "#ED0000"], "#0050F0"),
    "matecito_termero": ("URUGUAY", "h", ["#FFFFFF", "#0038A8", "#FFFFFF", "#0038A8", "#FFFFFF"], "#FCD116"),
    "gallo_pinton": ("NICARAGUA", "h", ["#0067C6", "#FFFFFF", "#0067C6"]),
    "aranita_nanduti": ("PARAGUAY", "h", ["#D52B1E", "#FFFFFF", "#0038A8"]),
    "piquero_patazul": ("ECUADOR", "h", ["#FFD100", "#FFD100", "#034EA2", "#ED1C24"]),
    "alpaca_esponjada": ("PERÚ", "v", ["#D91023", "#FFFFFF", "#D91023"]),
    "carretica_pura_vida": ("COSTA RICA", "h", ["#002B7F", "#FFFFFF", "#CE1126", "#CE1126", "#FFFFFF", "#002B7F"]),
    "harpia_despeinada": ("PANAMÁ", "q", ["#FFFFFF", "#DA121A", "#072357", "#FFFFFF"]),
    "carpincho_tranqui": ("ARGENTINA", "h", ["#74ACDF", "#FFFFFF", "#74ACDF"]),
    "quetzalete": ("GUATEMALA", "v", ["#4997D0", "#FFFFFF", "#4997D0"]),
    "chivita_rumbera": ("COLOMBIA", "h", ["#FCD116", "#FCD116", "#003893", "#CE1126"]),
    "boto_bailao": ("BRASIL", "h", ["#009C3B", "#FFDF00", "#002776"]),
    "ajolote_trajinero": ("MÉXICO", "v", ["#006847", "#FFFFFF", "#CE1126"]),
}

def flag_pill(d, x0, y0, w, h, spec):
    _, mode, cols = spec[:3]; canton = spec[3] if len(spec) > 3 else None
    from PIL import Image as _I
    tile = _I.new("RGB", (w, h)); td = ImageDraw.Draw(tile)
    if mode == "q":
        for i, c in enumerate(cols):
            td.rectangle(((i % 2) * w // 2, (i // 2) * h // 2, (i % 2 + 1) * w // 2, (i // 2 + 1) * h // 2), fill=c)
    else:
        n = len(cols)
        for i, c in enumerate(cols):
            if mode == "h": td.rectangle((0, i * h / n, w, (i + 1) * h / n), fill=c)
            else: td.rectangle((i * w / n, 0, (i + 1) * w / n, h), fill=c)
    if canton:
        td.polygon([(0, 0), (int(h * .9), h // 2), (0, h)], fill=canton)
    mask = _I.new("L", (w, h), 0); ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=h // 3, fill=255)
    return tile, mask

def latam():
    global d
    rows = []
    F = "/usr/share/fonts/truetype/sand-box/google/Luckiest Guy/LuckiestGuy-Regular.ttf"
    fn = ImageFont.truetype(F, 40); fr = ImageFont.truetype(F, 28); ft = ImageFont.truetype(F, 104); fj = ImageFont.truetype(F, 24); fc = ImageFont.truetype(F, 24)
    for part in ("a", "b"):
        out = f"lineup_latam_{part}"
        im = Image.open(R + out + "_raw.png").convert("RGB"); W, H = im.size; d = ImageDraw.Draw(im)
        A = json.load(open(f"/tmp/{out}_anchors.json"))
        for a in A:
            x = a["u"] * W; y = (1 - a["v"]) * H
            txt(x, y + 4, a["name"].upper(), fn, "white")
            txt(x, y + 52, a["rarity"], fr, RC[a["rarity"]], 5)
            cn = COUNTRY[a["key"]]; pw, ph = 46, 28
            tw = d.textlength(cn[0], font=fc); x0 = int(x - (pw + 10 + tw) / 2); y0 = int(y + 90)
            d.rounded_rectangle((x0 - 3, y0 - 3, x0 + pw + 3, y0 + ph + 3), radius=ph // 3 + 2, fill="#1B1430")
            tile, mask = flag_pill(d, x0, y0, pw, ph, cn); im.paste(tile, (x0, y0), mask)
            d.text((x0 + pw + 10, y0 + 1), cn[0], font=fc, fill="white", stroke_width=4, stroke_fill="#1B1430")
            txt(x, y + 128, LATAM_JOKE[a["key"]], fj, "white", 4)
        top = 170 if part == "a" else 250
        ymax = max((1 - a["v"]) * H for a in A) + 172
        rows.append(im.crop((0, top, W, min(H, int(ymax)))))
    W = rows[0].width; TH = 170
    canvas = Image.new("RGB", (W, TH + sum(r.height for r in rows)))
    # title band: same gradient start colour as the backdrop top
    g = rows[0].crop((0, 0, W, 1)).resize((W, TH)); canvas.paste(g, (0, 0))
    y = TH
    for r in rows: canvas.paste(r, (0, y)); y += r.height
    d = ImageDraw.Draw(canvas)
    txt(W / 2, 40, "COLECCIÓN LATAM", ft, "#FFE14D", 10)
    canvas.save(R + "lineup_latam.png"); print("ok lineup_latam", canvas.size)

if len(sys.argv) > 1 and sys.argv[1] == "latam":
    latam(); sys.exit(0)
out, title, JOKE = CFG[sys.argv[1] if len(sys.argv) > 1 else "memes2"]
im = Image.open(R + out + "_raw.png").convert("RGB"); W, H = im.size
d = ImageDraw.Draw(im)
F = "/usr/share/fonts/truetype/sand-box/google/Luckiest Guy/LuckiestGuy-Regular.ttf"
fn = ImageFont.truetype(F, 38); fr = ImageFont.truetype(F, 28); ft = ImageFont.truetype(F, 92); fj = ImageFont.truetype(F, 23)
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
