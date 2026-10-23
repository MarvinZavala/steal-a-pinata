"""Thumbnail 2 '¡COLECCIÓNALAS TODAS!': rarity pyramid of real piñatas on rarity-coloured pedestals.
Común/Poco común/Rara in front -> Épica/Legendaria -> Míticas (pink neon) -> Secretas on top (cyan beams)."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from store_lib import *

RC = {"C": ("donkey_grey", "#E6EEF9"), "U": ("lime", "#8BE530"), "R": ("sky", "#3DA5FF"), "E": ("grape", "#C59BFF"),
      "L": ("gold", "#FFC22E"), "M": ("fiesta_pink", "#FF4FD8"), "S": ("ink", "#3FF2FF")}
TIERS = [  # (y, z, scale, [(key, rarity, rz)])
    (0.0, 0.0, 1.0, [("estrellita", "C", 15), ("burrito", "C", 25), ("michi", "U", -5), ("cohetin", "R", -20)]),
    (7.0, 2.7, 1.08, [("dragon", "E", 25), ("garrobita_terenga", "E", 15), ("cochinito_quincena", "L", 30), ("toro", "L", -40), ("michi_aplausos", "L", -10), ("cactus_abrazos", "L", -20)]),
    (14.0, 5.4, 1.28, [("torogoz", "M", 20), ("aguacaton", "M", 10), ("pinovela", "M", 0), ("chancla_teledirigida", "M", -10), ("mapache_nel", "M", -25)]),
    (21.0, 8.1, 1.85, [("aurazoso", "S", 18), ("pulpo_dj", "S", 0), ("sombra", "S", -18)]),
]

def run():
    reset(); rnd = random.Random(3)
    pal = palette_mat(); guard_faces = []
    widths = [20, 30, 32, 30]
    for ti, (y, z, s, items) in enumerate(TIERS):
        W = widths[ti]
        # stage step (rounded, cream top with pink trim)
        step = box(f"step{ti}", (W + 6, 7.0, z + 1.0), loc=(0, y, (z + 1.0) / 2 - 1.0), col=["fiesta_pink", "grape", "hot_magenta", "ink_soft"][ti], bevel=.35, bseg=3)
        assign_mat(step, pal)
        trim = box(f"trim{ti}", (W + 6.2, .25, .25), loc=(0, y - 3.5, z - .05), col="sun_yellow", bevel=.1); assign_mat(trim, pal)
        n = len(items)
        for i, (k, r, rz) in enumerate(items):
            x = -W / 2 + W * (i + .5) / n
            if ti == 3: x = [-10.5, 0, 10.5][i]
            pc, glow = RC[r]
            pr = 2.0 * s
            ped = cyl(f"ped_{k}", pr, pr + .15, .7, loc=(x, y, z), col=pc, seg=40, bevel=.12); assign_mat(ped, pal)
            ring = torus(f"ring_{k}", pr + .05, .08, loc=(x, y, z + .7), col="eye_white", seg=40, mseg=6)
            assign_mat(ring, emit_mat(f"E_ring_{r}", glow, 7)); no_shadow(ring)
            ss = s * (1.25 if k == "pulpo_dj" else 1.0)
            objs = place(k, (x, y, z + .7), rz=rz, s=ss)
            bpy.context.view_layer.update(); mn, mx = bbox(objs)
            # keep big models inside their pedestal footprint
            ext = max(mx.x - mn.x, mx.y - mn.y)
            if ext > pr * 2.3:
                f = pr * 2.3 / ext
                for o in objs: o.matrix_world = Matrix.Translation((x, y, z + .7)) @ Matrix.Scale(f, 4) @ Matrix.Translation((-x, -y, -(z + .7))) @ o.matrix_world
                bpy.context.view_layer.update(); mn, mx = bbox(objs)
            guard_faces.append((Vector(((mn.x + mx.x) / 2, mn.y, mn.z + (mx.z - mn.z) * .6)), (mx.z - mn.z) * .35))
            if r in ("M", "S"):
                rarity_fx(f"fx_{k}", (x, y, z + .72), pr * .95, glow, beam_h=(14 if r == "S" else 9), ring=False, light=True, strength=(.9 if r == "S" else .6))
    # backdrop + world
    bd = backdrop("#1A0840", "#4A1C8C", size=140); bd.location = (0, 28, -1.0)
    world_flat("#3B1A7A", .5)
    CAM = Vector((0, -36, 9.0)); TGT = Vector((0, 8, float(os.environ.get("TZ", "8.6"))))
    camera(CAM, TGT, lens=float(os.environ.get("LENS", "32")), focus=Vector((0, 13, 6)), fstop=6.0, shift=(0, float(os.environ.get("SHIFT", "0.045"))))
    guard = FaceGuard(CAM, guard_faces)
    confetti("conf", (0, 6, 12), (20, 8, 5), 380, rnd, guard=guard, zmin=1.5, size=1.1)
    candies("cand", (0, 4, 13), (18, 6, 4), 26, rnd, guard=guard, zmin=3, scale=1.5)
    # spotlights: warm key, magenta/cyan rims, top light
    area("Key", (-14, -24, 22), (0, 8, 4), 9000, 14, "#FFF1DC")
    area("Fill", (16, -22, 10), (0, 8, 4), 3500, 14, "#DDEBFF")
    area("RimC", (-22, 30, 18), (0, 12, 6), 16000, 8, "#3FF2FF")
    area("RimM", (22, 30, 18), (0, 12, 6), 16000, 8, "#FF4FD8")
    area("Top", (0, 14, 30), (0, 14, 6), 8000, 10, "#FFFFFF")
    render_setup((1920, 1080), int(os.environ.get("SAMPLES", "128")), exposure=float(os.environ.get("EXPO", "-0.2")))
    go(os.environ.get("OUT", "thumb_coleccion"))
run()
