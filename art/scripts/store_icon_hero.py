"""Icons B/C: one hero piñata close-up (real model), rarity glow, sunburst, strong double rim light.
PRESET=pulpo   -> Pulpo DJ Arcoíris (Secreta + Rainbow mutation) on a night-purple burst
PRESET=aurazoso-> Aurazoso (Secreta) with cyan Secret aura on a teal burst"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from store_lib import *

PRESETS = {
    "pulpo": dict(key="pulpo_dj", mut="rainbow", rz=22, az=18, el=12, lens=50, margin=.66, zf=.36, tx=0.0,
                  c1="#3A0F8C", c2="#5420B8", glow="#FF7BE0", vig="#12052E", ring="#3FF2FF",
                  rimA="#3FF2FF", rimB="#FF4FD8", keyE=1300, out="icon_pulpo"),
    "aurazoso": dict(key="aurazoso", mut="none", rz=14, az=14, el=8, lens=50, margin=.74, zf=.5, tx=0.0,
                  c1="#0FA9B8", c2="#22C9D6", glow="#E8FFFF", vig="#04324A", ring="#3FF2FF",
                  rimA="#3FF2FF", rimB="#FFD84D", keyE=1400, out="icon_aurazoso"),
    "aurazoso_gold": dict(key="aurazoso", mut="golden", rz=14, az=14, el=8, lens=50, margin=.74, zf=.5, tx=0.0,
                  c1="#008FA6", c2="#00B5C8", glow="#C8FFFF", vig="#012C40", ring="#FFD84D",
                  rimA="#3FF2FF", rimB="#FFE3F5", keyE=1400, out="icon_aurazoso_gold"),
}

def run():
    reset(); rnd = random.Random(5)
    C = dict(PRESETS[os.environ.get("PRESET", "pulpo")])
    for k in list(C):
        if k.upper() in os.environ: C[k] = type(C[k])(os.environ[k.upper()])
    pin = place(C["key"], (0, 0, 0), rz=C["rz"])
    if C["mut"] != "none": mutate(pin, C["mut"])
    bpy.context.view_layer.update(); mn, mx = bbox(pin); size = mx - mn
    c = (mn + mx) / 2; c.z = mn.z + size.z * C["zf"]; c.x += C["tx"]
    rad = size.length / 2
    fov = 2 * math.atan(18 / C["lens"]); dist = rad * C["margin"] / math.sin(fov / 2)
    a, e = R(C["az"]), R(C["el"])
    CAM = c + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist
    face = Vector((0, mn.y, mn.z + size.z * .62))
    camera(CAM, c, lens=C["lens"], focus=face, fstop=2.8)
    guard = FaceGuard(CAM, [(face, size.z * .32)])
    d = (c - CAM).normalized(); bgc = CAM + d * (dist + 40)
    M = Matrix.Translation(bgc) @ d.to_track_quat('-Z', 'Y').to_matrix().to_4x4() @ Matrix.Translation((0, 4, 0))
    sunburst("burst", M, 110, C["c1"], C["c2"], rays=14, glow=C["glow"], glow_r=.28, strength=1.0, twist=.01, vignette=C["vig"], vig=.6)
    world_flat("#C9B8FF", .3)
    # floor disc (pedestal glow like the in-game rarity ring) – the piñata stands on it, no floating
    ped = cyl("ped", max(size.x, size.y) * .62, max(size.x, size.y) * .66, .6, loc=(c.x, (mn.y + mx.y) / 2, mn.z - .6), col="ink", seg=64, bevel=.12)
    assign_mat(ped, palette_mat())
    rarity_fx("rar", (c.x, (mn.y + mx.y) / 2, mn.z + .01), max(size.x, size.y) * .6, C["ring"], beam=False)
    # confetti + sparkles framing the character
    confetti("conf", (c.x, c.y + 2, c.z), (size.x * .9, 2.5, size.z * .7), 140, rnd, guard=guard, zmin=mn.z + .4, size=.9)
    sp = []
    for i in range(12):
        ang = rnd.uniform(0, 2 * math.pi); r = rnd.uniform(rad * .85, rad * 1.25)
        p = c + Vector((math.cos(ang) * r, rnd.uniform(-1, 1), math.sin(ang) * r * .85))
        if guard.blocks(p) or p.z < mn.z + .5: continue
        s_ = rnd.uniform(.18, .4)
        sp.append(star_prism(f"spk{i}", 4, s_, s_ * .28, .04, loc=p, rot=(90 - C["az"] * 0, 0, rnd.uniform(-15, 15)), col="eye_white", bevel=0))
    if sp:
        j = join(sp, "sparkles"); assign_mat(j, emit_mat("E_spark", "#FFFFFF", 8)); no_shadow(j)
    # light: soft key front-left, two hard coloured rims behind (strong silhouette), top kicker
    T = c + Vector((0, 0, size.z * .1))
    area("Key", c + Vector((-rad * 1.6, -rad * 2.2, rad * 1.8)), T, C["keyE"], rad * 1.2, "#FFF1DC")
    area("RimA", c + Vector((-rad * 1.8, rad * 1.6, rad * 1.2)), T, 4500, rad * .6, C["rimA"])
    area("RimB", c + Vector((rad * 1.8, rad * 1.4, rad * 1.5)), T, 4500, rad * .6, C["rimB"])
    area("Fill", c + Vector((rad * 2, -rad * 1.5, 0)), T, 500, rad * 1.5, "#DDEBFF")
    render_setup((1024, 1024), int(os.environ.get("SAMPLES", "160")), exposure=float(os.environ.get("EXPO", "-0.15")))
    go(os.environ.get("OUT", C["out"]))
run()
