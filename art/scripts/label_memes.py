from PIL import Image, ImageDraw, ImageFont
import json
R = "/workspace/roblox/steal-a-pinata/art/renders/"
im = Image.open(R + "lineup_memes_raw.png").convert("RGB"); W, H = im.size
d = ImageDraw.Draw(im)
F = "/usr/share/fonts/truetype/sand-box/google/Luckiest Guy/LuckiestGuy-Regular.ttf"
fn = ImageFont.truetype(F, 42); fr = ImageFont.truetype(F, 30); ft = ImageFont.truetype(F, 92); fj = ImageFont.truetype(F, 24)
JOKE = {"michi_aplausos": "aplaude cuando fallas un robo", "seis_siete": "6,767 dulces/s", "manzanin_iq": "¿cuántas manzanas ves?", "mapache_nel": "seguridad de tu base", "fichadito": "así nos ven los de 1er grado", "gemelos_pupusa": "¡gracias bebé!"}
RC = {"COMÚN": "#E6EEF9", "POCO COMÚN": "#8BE530", "RARO": "#3DA5FF", "ÉPICO": "#C59BFF", "LEGENDARIO": "#FFC22E", "EVENTO NAVIDAD": "#FF5A6E", "MÍTICO": "#FF4FD8", "SECRETO": "#3FF2FF"}
def txt(x, y, s, f, fill, stroke=6):
    w = d.textlength(s, font=f); d.text((x - w / 2, y), s, font=f, fill=fill, stroke_width=stroke, stroke_fill="#1B1430")
for a in json.load(open("/tmp/lineup_memes_anchors.json")):
    x = a["u"] * W; y = (1 - a["v"]) * H
    txt(x, y + 6, a["name"].upper(), fn, "white")
    txt(x, y + 58, a["rarity"], fr, RC[a["rarity"]], 5)
    txt(x, y + 100, JOKE[a["key"]], fj, "white", 4)
TOP = 200
txt(W / 2, TOP + 24, "TEMPORADA MEME 1", ft, "#FFE14D", 9)
ymax = max((1 - a["v"]) * H for a in json.load(open("/tmp/lineup_memes_anchors.json"))) + 150
im = im.crop((0, TOP, W, min(H, int(ymax)))); im.save(R + "lineup_memes.png"); print("ok")
