"""Thumbnail 5 '¡FIESTA!': the 30-min Fiesta event in the plaza - wild piñatas rain down (GDD §4.6), a player
bats one and it bursts into Dulces + confetti while a friend cheers. Real plaza (lobby_hub) behind, defocused."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from store_lib import *

GZ = 0.6   # plaza tile top

def run():
    reset(); rnd = random.Random(30); pal = palette_mat()
    hub = append_asset("lobby_hub")
    # drop objects that would sit between camera and action (+ the gold fountain statue, which read as a 2nd falling piñata)
    for o in list(hub):
        if (o.location.y < -24 and abs(o.location.x) < 30 and o.name not in ("plaza", "Plane", "Hills")) or o.name == "estrellita.001":
            bpy.data.objects.remove(o, do_unlink=True)
    # --- batter (left) + the bursting Estrellita (centre)
    AM = Matrix.Translation((-6.4, -19.0, GZ)) @ eul(0, 0, float(os.environ.get("AROT", "30")))
    A, ah = avatar("hero", "fiesta_pink", "cobalt", pose="swing", face="grin", cap="turquoise", M=AM)
    hit = Vector((-0.6, -21.8, 6.4))
    hp = ah["R"].to_translation()
    hold_world("bat_wood", hp, (hit + Vector((0, 0, .6))) - hp, s=1.15, grip=.35)
    est = place("estrellita", (0, 0, 0), rz=-20, s=1.5)
    bpy.context.view_layer.update(); mn, mx = bbox(est); c = (mn + mx) / 2
    for o in est: o.matrix_world = Matrix.Translation(hit + Vector((1.9, 0.3, -.4)) - c) @ eul(0, 14, -8) @ Matrix.Translation(-(hit + Vector((1.9, .3, -.4)))) @ Matrix.Translation(hit + Vector((1.9, .3, -.4))) @ o.matrix_world
    bpy.context.view_layer.update(); emn, emx = bbox(est); ec = (emn + emx) / 2
    # friend cheering (right)
    BM = Matrix.Translation((7.6, -16.5, GZ)) @ eul(0, 0, 22)
    B, bh = avatar("friend", "lime", "grape", pose="cheer", face="happy", cap="sun_yellow", cap2="fiesta_pink", M=BM)
    # string the piñata hangs from (wild ones float in on a string? no: they fall) -> impact star instead
    st = star_prism("bonk", 8, 1.1, .6, .12, loc=hit + Vector((.4, -.8, .2)), rot=(80, 0, -10), col="sun_yellow", bevel=.02); assign_mat(st, emit_mat("E_bonk", "#FFE14D", 5)); no_shadow(st)
    st2 = star_prism("bonk2", 8, .7, .38, .14, loc=hit + Vector((.4, -.9, .2)), rot=(80, 0, -10), col="eye_white", bevel=.02); assign_mat(st2, emit_mat("E_bonk2", "#FFFFFF", 6)); no_shadow(st2)
    bpy.context.view_layer.update()
    ah_ = bpy.data.objects["hero_head"].matrix_world @ Vector((0, -.3, .6)); bh_ = bpy.data.objects["friend_head"].matrix_world @ Vector((0, -.3, .6))
    CAM = Vector((float(os.environ.get("CX", "1.0")), float(os.environ.get("CY", "-40")), float(os.environ.get("CZ", "4.2"))))
    TGT = Vector((1.0, -14, float(os.environ.get("TZ", "7.4"))))
    camera(CAM, TGT, lens=float(os.environ.get("LENS", "32")), focus=ec, fstop=float(os.environ.get("FSTOP", "3.2")))
    guard = FaceGuard(CAM, [(ah_, 1.4), (bh_, 1.4), (Vector((ec.x, emn.y, ec.z + .5)), 2.0)])
    # --- candy explosion from the hit
    candies("burst", ec + Vector((0, .5, .8)), (4.5, 2.5, 3.2), 34, rnd, guard=guard, zmin=GZ + 1.0, scale=1.15)
    confetti("conf", ec + Vector((0, 2, 2)), (9, 4, 5), 320, rnd, guard=guard, zmin=GZ + .3, size=1.15)
    for i in range(5):
        a = rnd.uniform(0, 2 * math.pi); p = ec + Vector((math.cos(a) * rnd.uniform(3, 5), rnd.uniform(-1, 1), math.sin(a) * rnd.uniform(2.5, 4)))
        if not guard.blocks(p, .8): lollipop(f"lol{i}", p, (rnd.uniform(0, 360), rnd.uniform(-40, 40), rnd.uniform(0, 360)), s=1.0, cols=[("fiesta_pink", "eye_white"), ("turquoise", "eye_white"), ("sun_yellow", "fiesta_pink")][i % 3])
    # Dulces already on the floor
    gc = []
    for i in range(46):
        p = Vector((rnd.uniform(-14, 16), rnd.uniform(-24, -8), GZ + .22))
        gc += candy_one(f"gcand{i}", p, (0, rnd.uniform(-10, 10), rnd.uniform(0, 360)), ["candy_red", "candy_teal", "candy_violet", "sun_yellow", "fiesta_pink", "lime"][i % 6], scale=1.3)
    j = join(gc, "ground_candy"); assign_mat(j, pal)
    ground_confetti("gconf", (-18, 20, -26, -4), 260, rnd, z=GZ + .02)
    place("candy_pile", (-13.5, -11, GZ), rz=30, s=1.2)
    place("candy_pile", (15.5, -9, GZ), rz=-20, s=1.0)
    # --- piñatas raining from the sky (falling, with motion streaks above them)
    rain = [("michi", 9, 0, 15, -25, 1.2), ("burrito", 19, 8, 19, -30, 1.2), ("cohetin", 2, 16, 21, 15, 1.1), ("torogoz", 28, 18, 14, -20, 1.2), ("dragon", -9, 26, 26, 30, 1.1), ("caracol_turbo", 13, 26, 26, -10, 1.1)]
    for k, x, y, z, rz, s in rain:
        o = place(k, (x, y, z), rz=rz, s=s, rx=rnd.uniform(-15, 15), ry=rnd.uniform(-20, 20), pivot_z=2)
        bpy.context.view_layer.update(); mn, mx = bbox(o)
        top = Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mx.z + .3))
        lines = []
        for i in range(5):
            o0 = top + Vector((rnd.uniform(-1.4, 1.4), rnd.uniform(-.5, .5), rnd.uniform(0, .8)))
            L = rnd.uniform(3, 6)
            lines.append(tube(f"fall_{k}{i}", [o0, o0 + Vector((0, 0, L * .5)), o0 + Vector((0, 0, L))], radius=rnd.uniform(.06, .11), col="eye_white", seg=5, taper=[1, .6, .05]))
        jj = join(lines, f"fall_{k}"); assign_mat(jj, emit_mat("E_fall", "#FFFFFF", 2.2, alpha=.6)); no_shadow(jj)
    # --- light: warm afternoon sun + rims
    world_sky("#0A6BFF", "#9CDFFF", 1.0, split=(.0, .3))
    sun("Sun", (50, 6, -30), 3.4)
    area("RimL", (-14, -8, 14), ah_, 7000, 5, "#FFE6F4")
    area("RimR", (16, -6, 14), bh_, 7000, 5, "#C9F7FF")
    area("Fill", (2, -36, 7), ec, 2000, 10, "#E3EEFF")
    area("Pop", ec + Vector((0, -5, 2)), ec, 1500, 3, "#FFE9A0")
    render_setup((1920, 1080), int(os.environ.get("SAMPLES", "128")), exposure=float(os.environ.get("EXPO", "-0.3")))
    go(os.environ.get("OUT", "thumb_fiesta"))
run()
