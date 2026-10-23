"""Thumbnail 3 '¡FUSIÓN!': 3 identical Dragón Chile (left) break into energy streams that fuse into one big
Dragón Chile DORADA (x2) - with the rarer ARCOÍRIS (x5) result shown beside it. (GDD §4.7: 3 same -> 1 same species
with a guaranteed mutation, Golden or Rainbow.)"""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from store_lib import *

KEY = os.environ.get("PINATA", "dragon")

def bez(p0, p1, p2, p3, n=24):
    out = []
    for i in range(n + 1):
        t = i / n; a = (1 - t) ** 3; b = 3 * (1 - t) ** 2 * t; c = 3 * (1 - t) * t * t; d = t ** 3
        out.append(p0 * a + p1 * b + p2 * c + p3 * d)
    return out

def run():
    reset(); rnd = random.Random(8); pal = palette_mat()
    faces = []
    # three normal ones, left, on small pink pedestals
    smalls = [(-11.2, 5.2, 14), (-11.6, -1.2, 26), (-5.9, -1.6, 18)]
    tips = []
    for i, (x, y, rz) in enumerate(smalls):
        ped = cyl(f"sp{i}", 2.3, 2.45, .7, loc=(x, y, 0), col="fiesta_pink", seg=40, bevel=.12); assign_mat(ped, pal)
        ring = torus(f"sr{i}", 2.35, .07, loc=(x, y, .7), col="eye_white", seg=40, mseg=6); assign_mat(ring, emit_mat("E_epic", "#C59BFF", 7)); no_shadow(ring)
        o = place(KEY, (x, y, .7), rz=rz, s=.85)
        bpy.context.view_layer.update(); mn, mx = bbox(o)
        tips.append(Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mx.z * .7 + mn.z * .3)))
        faces.append((Vector(((mn.x + mx.x) / 2, mn.y, mn.z + (mx.z - mn.z) * .6)), 1.6))
    # result: big Golden (centre-right) + Rainbow (right, a bit behind)
    gx, gy = 2.2, 2.0
    gp = cyl("gped", 4.6, 4.8, 1.0, loc=(gx, gy, 0), col="gold", seg=64, bevel=.15); assign_mat(gp, golden_material())
    gold = place(KEY, (gx, gy, 1.0), rz=-14, s=2.0); mutate(gold, "golden")
    rarity_fx("gfx", (gx, gy, 1.02), 4.5, "#FFC22E", beam_h=16, strength=.9)
    rx_, ry_ = 12.0, 6.5
    rp = cyl("rped", 3.6, 3.8, .9, loc=(rx_, ry_, 0), col="ink_soft", seg=64, bevel=.15); assign_mat(rp, pal)
    rain = place(KEY, (rx_, ry_, .9), rz=-32, s=1.3); mutate(rain, "rainbow")
    rring = torus("rring", 3.65, .1, loc=(rx_, ry_, .9), col="eye_white", seg=48, mseg=6); assign_mat(rring, emit_mat("E_rain", "#FF4FD8", 7)); no_shadow(rring)
    bpy.context.view_layer.update()
    gmn, gmx = bbox(gold); gc = (gmn + gmx) / 2
    rmn, rmx = bbox(rain)
    faces += [(Vector((gc.x, gmn.y, gmn.z + (gmx.z - gmn.z) * .62)), 3.0), (Vector(((rmn.x + rmx.x) / 2, rmn.y, rmn.z + (rmx.z - rmn.z) * .6)), 2.2)]
    # energy streams from each small one into the golden one
    for i, t in enumerate(tips):
        end = gc + Vector((-2.5, -1.0, .8 - i * .6))
        pts = bez(t, t + Vector((3, -2, 5 + i)), end + Vector((-5, -3, 4 - i)), end)
        tb = tube(f"stream{i}", pts, radius=.22, col="eye_white", seg=10, taper=[.25 + .75 * math.sin(math.pi * k / (len(pts) - 1)) for k in range(len(pts))])
        assign_mat(tb, emit_mat("E_stream", "#FFE27A", 6)); no_shadow(tb)
        tb2 = tube(f"streamg{i}", pts, radius=.55, col="eye_white", seg=10, taper=[.2 + .8 * math.sin(math.pi * k / (len(pts) - 1)) for k in range(len(pts))])
        assign_mat(tb2, emit_mat("E_streamglow", "#FFB000", 2.5, alpha=.35)); no_shadow(tb2)
        sp = []
        for k, p in enumerate(pts[2:-2]):
            for _ in range(2):
                q = p + Vector((rnd.gauss(0, .6), rnd.gauss(0, .6), rnd.gauss(0, .6)))
                s_ = rnd.uniform(.12, .3)
                sp.append(star_prism(f"ss{i}_{k}_{_}", 4, s_, s_ * .3, .03, loc=q, rot=(90, 0, rnd.uniform(0, 45)), col="neon_gold", bevel=0))
        j = join(sp, f"sparks{i}"); assign_mat(j, emit_mat("E_spark", "#FFFFFF", 9)); no_shadow(j)
    CAM = Vector((float(os.environ.get("CX", "-0.5")), -27, 5.8)); TGT = Vector((0.3, 0, float(os.environ.get("TZ", "5.9"))))
    camera(CAM, TGT, lens=float(os.environ.get("LENS", "33")), focus=gc, fstop=5.0, shift=(0, float(os.environ.get("SHIFT", "0.02"))))
    guard = FaceGuard(CAM, faces)
    # burst of sparkles + coins + confetti around the golden result
    confetti("conf", (gc.x, gc.y + 3, gc.z + 2), (12, 5, 5), 300, rnd, guard=guard, zmin=1.5, size=1.1)
    sp = []
    for i in range(40):
        a = rnd.uniform(0, 2 * math.pi); r = rnd.uniform(5.5, 9)
        p = gc + Vector((math.cos(a) * r, rnd.uniform(-1, 3), math.sin(a) * r * .75))
        if guard.blocks(p) or p.z < 1: continue
        s_ = rnd.uniform(.25, .6)
        sp.append(star_prism(f"gs{i}", 4, s_, s_ * .28, .05, loc=p, rot=(90, 0, rnd.uniform(-20, 20)), col="neon_gold", bevel=0))
    j = join(sp, "gsparks"); assign_mat(j, emit_mat("E_spark", "#FFFFFF", 9)); no_shadow(j)
    # backdrop: violet sunburst centred behind the golden result
    d = (gc - CAM).normalized(); bc = gc + d * 70
    M = Matrix.Translation(bc) @ d.to_track_quat('-Z', 'Y').to_matrix().to_4x4()
    sunburst("burst", M, 240, "#5A1FC0", "#7A35E0", rays=20, glow="#FFC2F0", glow_r=.22, strength=1.0, twist=.004, vignette="#1C0748", vig=.7)
    floor_plane("floor", 400, "#4A1C8C", .5)
    world_flat("#5A2AA0", .4)
    area("Key", (-12, -26, 20), gc, 9000, 12, "#FFF1DC")
    area("Fill", (18, -24, 8), gc, 3000, 12, "#DDEBFF")
    area("RimC", (-20, 18, 14), gc, 14000, 6, "#3FF2FF")
    area("RimM", (24, 20, 14), gc, 14000, 6, "#FF4FD8")
    area("RimS", (-16, 10, 10), tips[0], 5000, 5, "#FFE3F5")
    render_setup((1920, 1080), int(os.environ.get("SAMPLES", "128")), exposure=float(os.environ.get("EXPO", "-0.25")))
    print("ANCHORS", {"gold": project(Vector((gc.x, gc.y, gmn.z))), "rain": project(Vector(((rmn.x + rmx.x) / 2, rmn.y, rmn.z))), "smalls": project(sum(tips, Vector()) / 3)})
    go(os.environ.get("OUT", "thumb_fusion"))
run()
