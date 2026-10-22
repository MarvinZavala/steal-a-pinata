"""Generates the game logo PNG (used on the gate plaque in key art + UI/thumbnail overlay)."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os, sys
FONT = "/usr/share/fonts/truetype/sand-box/google/Luckiest Guy/LuckiestGuy-Regular.ttf"
OUT = os.path.join(os.path.dirname(__file__), "..", "textures")
COLS = ["#FF3EA5", "#FFD23F", "#2EC4F1", "#7BE35A", "#A35BFF", "#FF8A1F"]

def logo(w=1400, h=760, bg=None, path=None):
    im = Image.new("RGBA", (w, h), bg or (0, 0, 0, 0))
    lines = [("¡STEAL A", 150), ("PIÑATA!", 250)]
    y = 70
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0)); d = ImageDraw.Draw(layer)
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0)); ds = ImageDraw.Draw(shadow)
    ci = 0
    for text, size in lines:
        f = ImageFont.truetype(FONT, size)
        tw = sum(d.textlength(c, font=f) for c in text) + (len(text) - 1) * 4
        x = (w - tw) / 2
        for c in text:
            col = "#FFFFFF" if c in " " else (COLS[ci % len(COLS)] if size > 200 else "#FFFFFF")
            ds.text((x + 10, y + 14), c, font=f, fill="#2B1B4A", stroke_width=18, stroke_fill="#2B1B4A")
            d.text((x, y), c, font=f, fill=col, stroke_width=16, stroke_fill="#2B1B4A")
            if c != " ": ci += 1
            x += d.textlength(c, font=f) + 4
        y += size + 70
    im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(3)))
    im.alpha_composite(layer)
    a = im.split()[3] if not bg else Image.eval(layer.split()[3], lambda v: v)
    bb = (layer.split()[3]).getbbox()
    m = 40
    im = im.crop((max(0, bb[0] - m), max(0, bb[1] - m), min(w, bb[2] + m), min(h, bb[3] + m)))
    if path: im.save(path)
    return im

if __name__ == "__main__":
    logo(path=os.path.join(OUT, "logo_steal_a_pinata.png"))
    # plaque version: opaque white card for the gate sign
    logo(bg=(255, 231, 245, 255), path=os.path.join(OUT, "logo_plaque.png"))
