"""Post: hero_key_art.png (graded), thumbnail_1920x1080.png (with big logo), icon_512.png."""
from PIL import Image, ImageEnhance, ImageFilter, ImageDraw
import os
R = os.path.join(os.path.dirname(__file__), "..", "renders"); TX = os.path.join(os.path.dirname(__file__), "..", "textures")
raw = Image.open(f"{R}/hero_key_art_raw.png").convert("RGB")
im = ImageEnhance.Color(raw).enhance(1.12); im = ImageEnhance.Contrast(im).enhance(1.05)
w, h = im.size
vig = Image.new("L", (w, h), 0); d = ImageDraw.Draw(vig)
d.ellipse((-w * .15, -h * .25, w * 1.15, h * 1.25), fill=255); vig = vig.filter(ImageFilter.GaussianBlur(160))
dark = ImageEnhance.Brightness(im).enhance(.78)
im = Image.composite(im, dark, vig); im.save(f"{R}/hero_key_art.png")
# thumbnail with big logo bottom-centre
logo = Image.open(f"{TX}/logo_steal_a_pinata.png")
lw = int(w * .34); logo = logo.resize((lw, int(logo.height * lw / logo.width)), Image.LANCZOS)
th = im.copy().convert("RGBA"); th.alpha_composite(logo, (w - lw - int(w * .015), int(h * .03)))
th.convert("RGB").save(f"{R}/thumbnail_1920x1080.png")
# icon: square crop around the golden toro + small logo
cx, cy = int(w * .565), int(h * .29); s = int(h * .52)
ic = im.crop((cx - s // 2, max(0, cy - s // 2), cx + s // 2, max(0, cy - s // 2) + s)).resize((512, 512), Image.LANCZOS).convert("RGBA")
lg = Image.open(f"{TX}/logo_steal_a_pinata.png"); lw2 = 470; lg = lg.resize((lw2, int(lg.height * lw2 / lg.width)), Image.LANCZOS)
ic.alpha_composite(lg, ((512 - lw2) // 2, 512 - lg.height - 10)); ic.convert("RGB").save(f"{R}/icon_512.png")
print("ok", im.size)
