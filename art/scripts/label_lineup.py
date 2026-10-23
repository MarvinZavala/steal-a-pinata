import os
from PIL import Image, ImageDraw, ImageFont
import json
R = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "renders") + "/"
im = Image.open(R + "lineup_raw.png").convert("RGB"); W, H = im.size
d = ImageDraw.Draw(im)
F = "/usr/share/fonts/truetype/sand-box/google/Luckiest Guy/LuckiestGuy-Regular.ttf"
fn = ImageFont.truetype(F, 42); fr = ImageFont.truetype(F, 30); ft = ImageFont.truetype(F, 92)
RC = {"COMÚN": "#E6EEF9", "POCO COMÚN": "#8BE530", "RARO": "#3DA5FF", "ÉPICO": "#C59BFF", "LEGENDARIO": "#FFC22E", "EVENTO NAVIDAD": "#FF5A6E", "MÍTICO": "#FF4FD8", "SECRETO": "#3FF2FF"}
def txt(x, y, s, f, fill, stroke=6):
    w = d.textlength(s, font=f); d.text((x - w / 2, y), s, font=f, fill=fill, stroke_width=stroke, stroke_fill="#1B1430")
for a in json.load(open("/tmp/lineup_anchors.json")):
    x = a["u"] * W; y = (1 - a["v"]) * H
    txt(x, y + 6, a["name"].upper(), fn, "white")
    txt(x, y + 58, a["rarity"], fr, RC[a["rarity"]], 5)
txt(W / 2, 34, "STEAL A PIÑATA!  —  PIÑATITOS", ft, "#FFE14D", 9)
im = im.crop((0, 0, W, int(H * .80))); im.save(R + "lineup.png"); print("ok")
