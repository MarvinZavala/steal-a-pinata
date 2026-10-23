"""Icon A 'El Ladrón': masked thief sprinting toward camera with a GOLDEN Cochinito Quincena over his head
(in-game the stolen piñata is welded above the thief's head). Pink sunburst, gold + cyan rims."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from store_lib import *

def run():
    reset(); rnd = random.Random(11)
    KEY = os.environ.get("PINATA", "cochinito_quincena"); MUT = os.environ.get("MUT", "golden")
    OUT = os.environ.get("OUT", "icon_ladron")
    rootM = Matrix.Translation((0, 0, 0)) @ eul(0, 0, float(os.environ.get("TROT", "-16")))
    P, hands = avatar("thief", "cosmic_2", "ink_soft", pose="carry_run", face="grin", mask=True, M=rootM)
    bpy.context.view_layer.update()
    hR = hands["R"].to_translation(); hL = hands["L"].to_translation(); mid = (hR + hL) / 2
    pin = place(KEY, (0, 0, 0), rz=float(os.environ.get("TROT", "-16")) + float(os.environ.get("PROT", "35")), s=float(os.environ.get("PSCALE", "1.25")), rx=-8)
    bpy.context.view_layer.update(); mn, mx = bbox(pin)
    c = (mn + mx) / 2
    for o in pin: o.matrix_world = Matrix.Translation((mid.x - c.x, mid.y - c.y + .2, mid.z + .05 - mn.z)) @ o.matrix_world
    if MUT != "none": mutate(pin, MUT)
    bpy.context.view_layer.update(); mn, mx = bbox(pin); pc = (mn + mx) / 2
    head = bpy.data.objects["thief_head"].matrix_world @ Vector((0, -.3, .6))
    # camera: low 3/4 front, slightly wide for punch
    CAM = Vector((float(os.environ.get("CX", "2.5")), float(os.environ.get("CY", "-11")), float(os.environ.get("CZ", "5.0")))); TGT = Vector((pc.x * .5 + float(os.environ.get("TX", "0.4")), 0, (head.z * .6 + mx.z * .4) + float(os.environ.get("TZ", "-0.55"))))
    cam = camera(CAM, TGT, lens=float(os.environ.get("LENS", "35")), focus=head, fstop=3.2)
    guard = FaceGuard(CAM, [(head, 1.3), (pc + Vector((0, -1.2, .3)), 1.9)])
    # background: sunburst far behind, facing the camera
    d = (TGT - CAM).normalized(); bgc = CAM + d * 60
    M = Matrix.Translation(bgc) @ d.to_track_quat('-Z', 'Y').to_matrix().to_4x4() @ Matrix.Translation((0, 6, 0))
    sunburst("burst", M, 120, os.environ.get("C1", "#FF1A86"), os.environ.get("C2", "#FF4AAE"), rays=16, glow=os.environ.get("GLOW", "#FFD6EC"), glow_r=.3, strength=1.0, twist=0.0, vignette="#7A0A4A", vig=.55)
    world_flat("#FFC0E0", .35)
    # sparkles around the gold piñata + confetti + speed lines behind the runner
    sp = []
    for i in range(10):
        a = rnd.uniform(0, 2 * math.pi); r = rnd.uniform(3.4, 4.8)
        p = pc + Vector((math.cos(a) * r, rnd.uniform(-.5, 1.5), math.sin(a) * r * .9))
        if guard.blocks(p): continue
        s_ = rnd.uniform(.25, .55)
        sp.append(star_prism(f"spk{i}", 4, s_, s_ * .28, .05, loc=p, rot=(90, 0, rnd.uniform(-15, 15)), col="neon_gold", bevel=0))
    if sp:
        j = join(sp, "sparkles"); assign_mat(j, emit_mat("E_spark", "#FFF3B0", 9)); no_shadow(j)
    confetti("conf", (pc.x, 2.0, pc.z - 1.0), (6, 3, 4), 170, rnd, guard=guard, zmin=-50, size=1.1)
    sl = speed_lines("speed", (pc.x + 1.5, 4.0, 5.0), (1, 2.2, .05), 16, rnd, length=(4, 8), spread=(2.2, 3.2))
    # lights: warm key front-left, strong cyan rim back-left, pink-white rim back-right, gold kicker on piñata
    area("Key", (-7, -10, 10), pc, 2600, 6, "#FFF1DC")
    area("RimC", (-8, 9, 9), (pc + head) / 2, 9000, 4, "#3FF2FF")
    area("RimW", (8, 8, 11), (pc + head) / 2, 9000, 4, "#FFE3F5")
    area("Fill", (8, -9, 2), head, 900, 6, "#DDEBFF")
    area("Top", (0, 2, 18), pc, 2500, 5, "#FFE9A0")
    render_setup((1024, 1024), int(os.environ.get("SAMPLES", "160")), exposure=float(os.environ.get("EXPO", "-0.4")))
    go(OUT)
run()
