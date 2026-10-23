"""Thumbnail 6 '¡DEFENDÉ TU BASE!': the base lock (candado láser, LockService.luau / WP-08) is ON.
Matches the game: magenta neon laser (#FF4FD8, Neon, Transparency .15) between the gate posts (base_gate_Neon),
the padlock on the gate switched from gold Metal to neon pink, the lock ring over the gate counting the seconds
left with a turquoise stroke. A masked thief who ran into it is bounced back (LaserBlock collides with everyone
but the owner) while the owner, safe inside (LockOwner group), laughs at him between his pedestals full of
glowing piñatas, incl. two of the LatAm collection (Ajolote Trajinero, Chivita Rumbera)."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from store_lib import *
from props import text_mesh

GATE_Y = -27.5          # base_plot_assembled: gate at -L/2 + 1.5, opening faces -Y
NEON = "#FF4FD8"        # LockService NEON (laser + padlock when locked)
TURQ = "#16D3E8"        # lock ring stroke when on

BASE_PARTS = ["base_floor", "base_generator", "base_generator_Glass", "base_gate", "base_gate_Neon", "base_padlock",
              "papel_picado_banner", "papel_picado_banner.001", "papel_picado_Flags", "papel_picado_Flags.001", "candy_pile", "candy_pile.001"] + \
             [f"base_fence.{i:03d}" for i in range(1, 19)] + ["base_fence"] + \
             ["base_pedestal"] + [f"base_pedestal.{i:03d}" for i in range(1, 8)] + ["base_pedestal_Neon"] + [f"base_pedestal_Neon.{i:03d}" for i in range(1, 8)]

E = lambda k, d: float(os.environ.get(k, d))

def billboard(objs, center, cam):
    """Turn flat objs (built facing +Z around the origin) to face the camera at center."""
    q = (cam - center).normalized().to_track_quat('Z', 'Y').to_matrix().to_4x4()
    for o in objs: o.matrix_world = Matrix.Translation(center) @ q @ o.matrix_world

def run():
    reset(); rnd = random.Random(66); pal = palette_mat()
    base = append_asset("base_plot_assembled", BASE_PARTS)
    byname = {o.name: o for o in base}
    CAM = Vector((E("CX", "1.5"), E("CY", "-43"), E("CZ", "3.6")))
    TGT = Vector((E("TX", "0.1"), GATE_Y, E("TZ", "8.8")))
    # --- piñatas on the pedestals (pedestal top = 1.65). The front pair is pulled in next to the gate (staging)
    # so the two LatAm stars flank the laser; the rest stay in their real slots.
    PEDS = {"": ((-13.5, -16), (E("PLX", "-12.4"), E("PLY", "-24.6")), "ajolote_trajinero", 12, 1.35, "#FFC22E"),
            ".001": ((13.5, -16), (E("PRX", "12.6"), E("PRY", "-24.6")), "chivita_rumbera", -28, 1.35, "#3FF2FF"),
            ".002": ((-13.5, -6), None, "boto_bailao", 20, 1.2, "#C59BFF"), ".003": ((13.5, -6), None, "cochinito_quincena", -25, 1.2, "#FF4FD8"),
            ".004": ((-13.5, 4), None, "quetzalete", 20, 1.15, None), ".005": ((13.5, 4), None, "dragon", -30, 1.15, None),
            ".006": ((-13.5, 14), None, "carpincho_tranqui", 20, 1.15, None), ".007": ((13.5, 14), None, "michi", -30, 1.15, None)}
    faces = []
    for suf, ((x0, y0), to, k, rz, s, glow) in PEDS.items():
        x, y = to or (x0, y0)
        for nm in ("base_pedestal" + suf, "base_pedestal_Neon" + suf):
            byname[nm].matrix_world = Matrix.Translation((x - x0, y - y0, 0)) @ byname[nm].matrix_world
        o = place(k, (x, y, 1.65), rz=rz, s=s)
        if glow:
            rarity_fx(f"fx_{k}", (x, y, 1.68), 2.7, glow, beam_h=8, ring=True, light=True, strength=E("BEAM", ".55"))
        if to:
            bpy.context.view_layer.update(); mn, mx = bbox(o); faces.append((Vector(((mn.x + mx.x) / 2, mn.y, mn.z + (mx.z - mn.z) * .6)), 1.6))
    # --- the lock is ON: neon bars (base_gate_Neon) + faint laser sheet (Laser part) + magenta spill
    gn = byname["base_gate_Neon"]; assign_mat(gn, emit_mat("E_laser", NEON, E("BARS", "3.5"))); no_shadow(gn)
    bpy.context.view_layer.update(); lmn, lmx = bbox([gn])
    sheet = box("laser_sheet", (lmx.x - lmn.x, .06, lmx.z - lmn.z + .6), loc=(0, GATE_Y, (lmn.z + lmx.z) / 2), col="eye_white", bevel=0)
    assign_mat(sheet, emit_mat("E_sheet", NEON, E("SHEET", "0.7"), alpha=E("SHEETA", "0.16"))); no_shadow(sheet)
    sheet.visible_diffuse = False
    for nm, x, y, en in (("lzL", -4.5, GATE_Y - .8, 160), ("lzR", 4.5, GATE_Y - .8, 160), ("lzI", 0, GATE_Y + 1.5, 600)):
        ld = bpy.data.lights.new(nm, 'POINT'); ld.energy = en; ld.color = hex2srgb(NEON); ld.shadow_soft_size = 2.5
        lo = bpy.data.objects.new(nm, ld); link(lo); lo.location = (x, y, 4.8)
    pl = byname["base_padlock"]   # Material Neon + Color NEON while locked: pink glossy body that glows
    pm = bpy.data.materials.new("M_padlock_on"); pm.use_nodes = True; b = pm.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*hex2lin(NEON), 1); b.inputs["Roughness"].default_value = .25
    b.inputs["Emission Color"].default_value = (*hex2lin(NEON), 1); b.inputs["Emission Strength"].default_value = E("PADE", "1.2")
    assign_mat(pl, pm)
    bpy.context.view_layer.update(); pmn, pmx = bbox([pl]); pc = (pmn + pmx) / 2
    glow_ball("padglow", pc + Vector((0, 1.5, 0)), 2.2, NEON, strength=.8, power=2.2)
    # --- lock ring over the gate (BillboardGui on Gate, always faces the viewer): ink disc, turquoise stroke, "30s"
    ring_c = Vector((0, GATE_Y - .5, E("RINGZ", "15.2")))
    disc = cyl("ring_disc", 1.6, 1.6, .2, loc=(0, 0, -.1), col="ink", seg=48, base=True); assign_mat(disc, emit_mat("E_disc", "#2A1F45", .9))
    st = torus("ring_stroke", 1.6, .18, loc=(0, 0, .05), col="eye_white", seg=48, mseg=8); assign_mat(st, emit_mat("E_stroke", TURQ, 7)); no_shadow(st)
    t = text_mesh("ring_txt", "30s", size=1.2, extrude=.08, col="eye_white", rot=(0, 0, 0)); t.location = (0, -.05, .12)
    assign_mat(t, emit_mat("E_ringtxt", "#FFFFFF", 3))
    billboard([disc, st, t], ring_c, CAM)
    # --- thief: ran at the gate, the laser bounced him back -> airborne toward camera, flailing, shocked
    flail = {"torso": (-22, 0, 4), "head": (-10, 0, 8), "armR": (-150, 0, 55), "armL": (-165, 0, -40), "legR": (-70, 0, 12), "legL": (-20, 0, -14)}
    TM = Matrix.Translation((E("THX", "-2.6"), GATE_Y - E("THD", "4.4"), E("THZ", "1.9"))) @ eul(0, 0, E("THR", "10")) @ eul(0, E("THROLL", "-14"), 0)
    P, th_hands = avatar("thief", "cosmic_2", "ink_soft", pose=flail, face="shock", mask=True, M=TM, grounded=False)
    # --- owner: safe inside, right behind the laser, celebrating with a victory hop, laughing at the thief
    taunt = {"torso": (-6, 0, -6), "head": (-10, 0, E("OHR", "10")), "armR": (-160, 0, 30), "armL": (-155, 0, -34), "legR": (24, 0, -6), "legL": (-30, 0, 6)}
    OM = Matrix.Translation((E("OWX", "2.6"), GATE_Y + E("OWD", "1.6"), E("OWZ", "1.3"))) @ eul(0, 0, E("OWR", "-12"))
    O, oh = avatar("owner", "fiesta_pink", "cobalt", pose=taunt, face="grin", cap="turquoise", M=OM, grounded=False)   # little victory hop
    bpy.context.view_layer.update()
    th = bpy.data.objects["thief_head"].matrix_world @ Vector((0, -.3, .6)); ow = bpy.data.objects["owner_head"].matrix_world @ Vector((0, -.3, .6))
    print("FACE_Z thief %.2f owner %.2f" % (th.z, ow.z))
    camera(CAM, TGT, lens=E("LENS", "22"), focus=th, fstop=E("FSTOP", "5.6"))
    guard = FaceGuard(CAM, [(th, 1.6), (ow, 1.5), (ring_c, 2.4)] + faces)
    # --- impact on the laser where he hit: burst + zap bolts in the laser plane, arcs tracing his bounce
    hit = Vector((E("HITX", "-0.8"), GATE_Y - .1, E("HITZ", "6.6")))
    zap = []
    sp = star_prism("zap", 10, E("ZAP", "1.15"), .75, .06, col="eye_white", bevel=0); zap.append(sp)
    sp2 = star_prism("zap2", 10, E("ZAP", "1.15") * .55, .4, .08, loc=(0, 0, .05), rot=(0, 0, 18), col="eye_white", bevel=0)
    billboard([sp], hit, CAM); billboard([sp2], hit + Vector((0, -.05, 0)), CAM)
    assign_mat(sp, emit_mat("E_zap", "#FF7BE6", 7)); assign_mat(sp2, emit_mat("E_zap2", "#FFFFFF", 9)); no_shadow(sp); no_shadow(sp2)
    bolts = []
    for i in range(8):
        a = i / 11 * 2 * math.pi + rnd.uniform(-.2, .2); L = rnd.uniform(1.2, 2.4)
        pts = [hit + Vector((math.cos(a) * 1.1, -.05, math.sin(a) * 1.1))]
        for j in range(3):
            pts.append(pts[-1] + Vector((math.cos(a) * L / 3 + rnd.uniform(-.35, .35), 0, math.sin(a) * L / 3 + rnd.uniform(-.35, .35))))
        if any(guard.blocks(p, .2) for p in pts): continue
        bolts.append(tube(f"bolt{i}", pts, radius=.065, col="eye_white", seg=5, taper=[1, .8, .5, .1]))
    if bolts:
        bj = join(bolts, "bolts"); assign_mat(bj, emit_mat("E_bolt", "#FFC6F4", 8)); no_shadow(bj)
    ld = bpy.data.lights.new("hit", 'POINT'); ld.energy = 400; ld.color = hex2srgb("#FF6FE0"); ld.shadow_soft_size = 1.0
    lo = bpy.data.objects.new("hit", ld); link(lo); lo.location = hit + Vector((0, 1.4, 0))   # behind the laser: magenta rim on the thief, not a pink face
    # bounce arcs: 3 curved white streaks from the impact to his back
    arcs = []
    tb = bpy.data.objects["thief_torso"].matrix_world @ Vector((0, .6, 1.2))
    for i, off in enumerate((-1.1, 0, 1.1)):
        a0 = hit + Vector((off * .6, -.6, off * .5)); a2 = tb + Vector((off * .7, .9, off * .6 + .3))
        mid = (a0 + a2) / 2 + Vector((0, 0, 1.4))
        pts = [a0.lerp(mid, u) .lerp(mid.lerp(a2, u), u) for u in (0, .2, .4, .6, .8, 1)]
        arcs.append(tube(f"arc{i}", pts, radius=.09, col="eye_white", seg=6, taper=[.1, .5, .9, 1, .8, .2]))
    aj = join(arcs, "arcs"); assign_mat(aj, emit_mat("E_arc", "#FFFFFF", 2.6, alpha=.7)); no_shadow(aj)
    # dizzy stars around his head
    dz = []
    for i in range(4):
        a = i / 4 * 2 * math.pi + .4
        p = th + Vector((math.cos(a) * 1.35, math.sin(a) * .9 + .4, .95 + math.sin(a) * .25))
        dz.append(star_prism(f"dz{i}", 5, .32, .14, .1, loc=p, rot=(90, 0, rnd.uniform(-20, 20)), col="sun_yellow", bevel=.02))
    dj = join(dz, "dizzy"); assign_mat(dj, emit_mat("E_dizzy", "#FFE14D", 3.5)); no_shadow(dj)
    sparks = []
    for i in range(34):
        d = Vector((rnd.uniform(-1, 1), rnd.uniform(-1.6, -.1), rnd.uniform(-.5, 1))).normalized() * rnd.uniform(2.2, 5.0)
        p = hit + d
        if guard.blocks(p, .35) or p.z < .5: continue
        s_ = rnd.uniform(.12, .3)
        sparks.append(star_prism(f"spk{i}", 4, s_, s_ * .3, .04, loc=p, rot=(90, 0, rnd.uniform(0, 45)), col="eye_white", bevel=0))
    if sparks:
        j = join(sparks, "sparks"); assign_mat(j, emit_mat("E_spk", "#FFE0FA", 9)); no_shadow(j)
    # --- party atmosphere (kept light so the laser reads)
    confetti("conf", (0, -26, 10), (13, 7, 3.5), 200, rnd, guard=guard, zmin=2.5, size=1.1)
    ground_confetti("gconf", (-16, 16, -46, -28.6), 160, rnd)
    tiles = []
    for jy in range(6):
        for ix in range(3):
            c = ["plaza_tile", "cream", "terracotta"][(ix + jy) % 3]
            tiles.append(box(f"otile{ix}_{jy}", (2.7, 2.7, .3), loc=(-3 + ix * 3, GATE_Y - 3.0 - jy * 3.6, -.05), col=c, bevel=.15, bseg=1))
    tj = join(tiles, "out_tiles"); assign_mat(tj, pal)
    floor_plane("grass", 600, "#5BD65C", .9, z=-.12)
    world_sky("#0A6BFF", "#9CDFFF", 1.0, split=(.0, .3))
    for k, (x, y, z, s) in enumerate([(-60, 90, 30, 7), (-26, 100, 42, 6), (28, 95, 36, 8), (62, 100, 26, 6)]):
        cl = [sphere(f"cloud{k}{j}", (s * (1 - .15 * j), s * .7, s * .6), loc=(x + j * s * .9 - s, y, z + (j % 2) * s * .3), col="white", seg=16, ring=10) for j in range(4)]
        cj = join(cl, f"cloud{k}"); assign_mat(cj, emit_mat("E_cloud", "#FFFFFF", 1.15)); no_shadow(cj)
    sun("Sun", (E("SUNX", "50"), 8, E("SUNZ", "-30")), 3.4)
    area("KeyT", (-12, -44, 10), th, E("KEYT", "2600"), 6, "#FFE6CC")
    area("RimT", (-10, -26, 9), th, 3500, 4, "#C9F7FF")
    area("KeyO", (10, -38, 12), ow, 4000, 5, "#FFF4E6")
    area("Fill", (2, -52, 5), th, E("FILL", "800"), 10, "#E3EEFF")
    render_setup((1920, 1080), int(os.environ.get("SAMPLES", "128")), exposure=E("EXPO", "-0.3"))
    print("ANCHORS", {"thief": project(th), "owner": project(ow), "hit": project(hit), "ring": project(ring_c)})
    go(os.environ.get("OUT", "thumb_defensa"))
run()
