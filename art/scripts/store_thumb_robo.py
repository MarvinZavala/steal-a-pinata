"""Thumbnail 1 'EL ROBO': inside a player's base, a masked thief sprints toward camera with a glowing
Legendary Cochinito Quincena over his head (in-game: welded above the head + rarity sparkle trail),
while the angry owner chases him with the wooden bat. Pedestals with piñatas, papel picado, Dulcería behind."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from store_lib import *

BASE_PARTS = ["base_floor", "base_generator", "base_generator_Glass",
              "papel_picado_banner", "papel_picado_banner.001", "papel_picado_Flags", "papel_picado_Flags.001", "candy_pile", "candy_pile.001"] + \
             [f"base_fence.{i:03d}" for i in range(1, 19)] + ["base_fence"] + \
             ["base_pedestal"] + [f"base_pedestal.{i:03d}" for i in range(1, 8)] + ["base_pedestal_Neon"] + [f"base_pedestal_Neon.{i:03d}" for i in range(1, 8)]

def run():
    reset(); rnd = random.Random(21)
    base = append_asset("base_plot_assembled", BASE_PARTS)
    # new-generation piñatas on the pedestals (pedestal top = 1.65)
    PEDS = {(-13.5, -16): ("michi_aplausos", 20), (13.5, -16): ("dragon", -25), (-13.5, -6): ("mapache_nel", 25), (13.5, -6): ("torogoz", -30),
            (-13.5, 4): ("aguacaton", 20), (13.5, 4): ("caracol_turbo", -40), (-13.5, 14): ("burrito", 20), (13.5, 14): ("michi", -30)}
    for (x, y), (k, rz) in PEDS.items():
        place(k, (x, y, 1.65), rz=rz, s=1.15)
    # --- thief (left, near camera) carrying the Legendary piñata
    TM = Matrix.Translation((-3.2, -19.5, 0)) @ eul(0, 0, -22)
    P, hands = avatar("thief", "cosmic_2", "ink_soft", pose="carry_run", face="grin", mask=True, M=TM)
    bpy.context.view_layer.update()
    mid = (hands["R"].to_translation() + hands["L"].to_translation()) / 2
    pin = place("cochinito_quincena", (0, 0, 0), rz=8, s=1.2, rx=-6)
    bpy.context.view_layer.update(); mn, mx = bbox(pin); c = (mn + mx) / 2
    for o in pin: o.matrix_world = Matrix.Translation((mid.x - c.x, mid.y - c.y + .2, mid.z + .05 - mn.z)) @ o.matrix_world
    bpy.context.view_layer.update(); mn, mx = bbox(pin); pc = (mn + mx) / 2
    # --- owner (right, behind) chasing with the bat raised
    OM = Matrix.Translation((3.6, -12.5, 0)) @ eul(0, 0, 18)
    O, oh = avatar("owner", "fiesta_pink", "cobalt", pose="chase_bat", face="angry", cap="turquoise", M=OM)
    bat = hold("bat_wood", oh["R"], length_dir=(0, -.35, -1), s=1.15, grip=.35)
    for b in bat: assign_mat(b, palette_mat())
    bpy.context.view_layer.update()
    th = bpy.data.objects["thief_head"].matrix_world @ Vector((0, -.3, .6)); oh_ = bpy.data.objects["owner_head"].matrix_world @ Vector((0, -.3, .6))
    CAM = Vector((float(os.environ.get("CX", "3.0")), float(os.environ.get("CY", "-35")), float(os.environ.get("CZ", "3.6"))))
    TGT = Vector((float(os.environ.get("TX", "1.5")), -18, float(os.environ.get("TZ", "6.2"))))
    camera(CAM, TGT, lens=float(os.environ.get("LENS", "30")), focus=th, fstop=float(os.environ.get("FSTOP", "3.5")))
    guard = FaceGuard(CAM, [(th, 1.4), (oh_, 1.4), (pc + Vector((0, -1.5, .4)), 2.2)])
    # --- Legendary FX: gold glow, sparkle trail behind the piñata, gold coins
    lg = bpy.data.lights.new("leg", 'POINT'); lg.energy = 2500; lg.color = hex2srgb("#FFC22E"); lg.shadow_soft_size = 2
    lo = bpy.data.objects.new("leg", lg); link(lo); lo.location = pc + Vector((0, -2.5, .5))
    glow_ball("aura", pc + (pc - CAM).normalized() * 9.0, 5.6, "#FFC22E", strength=float(os.environ.get("AURA", "1.05")), power=2.0)
    trail = []
    for i in range(40):
        t = i / 40
        p = pc + Vector((t * 7 + rnd.gauss(0, .5), 4 + t * 9 + rnd.gauss(0, .6), -t * 1.5 + rnd.gauss(0, .7)))
        if guard.blocks(p): continue
        s_ = rnd.uniform(.15, .38) * (1 - t * .5)
        trail.append(star_prism(f"tr{i}", 4, s_, s_ * .3, .04, loc=p, rot=(90, 0, rnd.uniform(0, 40)), col="neon_gold", bevel=0))
    if trail:
        j = join(trail, "trail"); assign_mat(j, emit_mat("E_trail", "#FFE27A", 10)); no_shadow(j)
    coins = []
    for i in range(10):
        a = rnd.uniform(0, 2 * math.pi); r = rnd.uniform(3.0, 4.6)
        p = pc + Vector((math.cos(a) * r, rnd.uniform(0, 2), math.sin(a) * r * .8))
        if guard.blocks(p, .4): continue
        coins.append(cyl(f"coin{i}", .42, .42, .12, loc=p, rot=(rnd.uniform(40, 100), rnd.uniform(-30, 30), rnd.uniform(0, 180)), col="gold", seg=20, base=False, bevel=.03))
    if coins:
        j = join(coins, "coins"); assign_mat(j, golden_material())
    # --- party atmosphere: confetti in the air, ground confetti, speed lines, dust puffs at the feet
    confetti("conf", (0, -12, 7), (10, 6, 3.5), 260, rnd, guard=guard, zmin=.5, size=1.0)
    ground_confetti("gconf", (-14, 14, -30, 10), 200, rnd)
    speed_lines("speed", th + Vector((2.0, 4, -1.0)), (1.2, 3.5, .1), 14, rnd, length=(3, 6), spread=(1.6, 2.4))
    puffs = []
    for i in range(7):
        p = Vector((-1.8 + rnd.uniform(-.8, 1.6), -17.0 + rnd.uniform(0, 2.5), .35))
        puffs.append(sphere(f"puff{i}", (rnd.uniform(.4, .7),) * 3, loc=p, col="eye_white", seg=12, ring=8))
    j = join(puffs, "puffs"); assign_mat(j, emit_mat("E_puff", "#FFFFFF", 1.2, alpha=.5)); no_shadow(j)
    # --- sky, sun, rim lights
    floor_plane("grass", 600, "#5BD65C", .9, z=-1.2)
    world_sky("#0A6BFF", "#9CDFFF", 1.0, split=(.0, .3))
    for k, (x, y, z, s) in enumerate([(-40, 80, 30, 7), (-10, 95, 38, 6), (30, 90, 34, 8), (55, 100, 24, 6)]):
        cl = [sphere(f"cloud{k}{j}", (s * (1 - .15 * j), s * .7, s * .6), loc=(x + j * s * .9 - s, y, z + (j % 2) * s * .3), col="white", seg=16, ring=10) for j in range(4)]
        cj = join(cl, f"cloud{k}"); assign_mat(cj, emit_mat("E_cloud", "#FFFFFF", 1.15)); no_shadow(cj)
    sun("Sun", (52, 8, -35), 3.6)
    area("RimGold", pc + Vector((-3, 6, 3)), pc, 5000, 3, "#FFC22E")
    area("RimL", (-10, -2, 12), th, 9000, 5, "#FFE6F4")
    area("RimR", (12, -4, 12), oh_, 7000, 5, "#C9F7FF")
    area("Fill", (6, -34, 6), th, 1600, 10, "#E3EEFF")
    render_setup((1920, 1080), int(os.environ.get("SAMPLES", "128")), exposure=float(os.environ.get("EXPO", "-0.3")))
    json_out = {"thief": project(th), "owner": project(oh_), "pinata": project(pc)}
    print("ANCHORS", json_out)
    go(os.environ.get("OUT", "thumb_robo"))
run()
