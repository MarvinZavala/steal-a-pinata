"""Lobby / hub block-out: 'La Plaza' — fountain, Pasarela (piñata conveyor carpet), 4 shop kiosks,
palms, lamps, papel picado ring, 6 player plots. Reusable modules exported to art/export/lobby/."""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
from plib import *
from props import text_mesh, finish
from base import append_asset
from mathutils import Vector, Matrix

# ------------------------------------------------------------------ modules
def kiosk(accent="candy_red", accent2="sun_yellow", wall="cream", stripe2="snow"):
    """Market stall. Front faces -Y. Sign board left blank: put text as SurfaceGui (localizable)."""
    P = []
    P.append(box("k_plinth", (12, 10, .6), loc=(0, 0, .3), col="stone_dark", bevel=.15))
    P.append(box("k_body", (10, 8, 6), loc=(0, 0, 3.6), col=wall, bevel=.25, bseg=2))
    P.append(box("k_window", (8.4, .3, 2.6), loc=(0, -3.95, 4.6), col="ink_soft", bevel=.08))
    P.append(box("k_counter", (10.6, 1.6, 2.6), loc=(0, -4.6, 1.9), col=accent, bevel=.2))
    P.append(box("k_counter_top", (11.0, 2.0, .35), loc=(0, -4.6, 3.3), col="wood", bevel=.08))
    for s in (-1, 1):
        P.append(box(f"k_post{s}", (.6, .6, 6.4), loc=(s * 5.1, -4.4, 3.6), col=accent2, bevel=.1))
    n = 7; w = 11.2 / n
    for i in range(n):
        x = -5.6 + w * (i + .5)
        P.append(box(f"k_awn{i}", (w + .02, 3.6, .22), loc=(x, -5.6, 6.2), rot=(20, 0, 0), col=accent if i % 2 == 0 else stripe2, bevel=.04))
        P.append(sphere(f"k_scal{i}", (w / 2, .2, .45), loc=(x, -7.25, 5.55), col=accent if i % 2 == 0 else stripe2, seg=10, ring=6))
    P.append(box("k_roof", (11, 9, .7), loc=(0, .2, 7.0), col=accent2, bevel=.2))
    P.append(box("k_signrim", (10.2, .6, 3.4), loc=(0, -2.6, 9.0), col=accent, bevel=.25, bseg=2))
    P.append(box("k_sign", (9.4, .7, 2.6), loc=(0, -2.85, 9.0), col="snow", bevel=.2, bseg=2))
    for s in (-1, 1):
        P.append(star_prism(f"k_star{s}", 5, .9, .42, .4, loc=(s * 5.3, -2.7, 10.4), rot=(90, 0, 0), col="mango", bevel=.06))
    return P, []

def fountain():
    P = []; G = []
    P.append(cyl("f_step", 12.5, 12.8, .6, col="stone_dark", seg=40, bevel=.15))
    P.append(cyl("f_wall", 11, 11, 2.2, loc=(0, 0, .6), col="fiesta_pink", seg=40, bevel=.3))
    P.append(torus("f_lip", 11, .45, loc=(0, 0, 2.8), col="snow", seg=40, mseg=8))
    P.append(cyl("f_water", 10.6, 10.6, .1, loc=(0, 0, 2.3), col="turquoise", seg=40))
    for k in range(4):
        P.append(cyl(f"f_col{k}", 2.0 - k * .1, 2.0 - (k + 1) * .1, 1.3, loc=(0, 0, 2.4 + k * 1.3), col=["sun_yellow", "turquoise"][k % 2], seg=20, bevel=.06))
    P.append(cyl("f_bowl", 1.6, 5, 1.4, loc=(0, 0, 7.6), col="mango", seg=32, bevel=.2))
    P.append(torus("f_bowl_lip", 5, .3, loc=(0, 0, 9.0), col="snow", seg=32, mseg=6))
    P.append(cyl("f_water2", 4.8, 4.8, .1, loc=(0, 0, 8.85), col="turquoise", seg=32))
    P.append(cyl("f_plinth", 1.8, 1.6, 1.2, loc=(0, 0, 8.9), col="fiesta_pink", seg=20, bevel=.12))
    for i in range(8):   # water arcs: bowl lip -> basin
        a = 2 * math.pi * i / 8
        pts = []
        for j in range(9):
            t = j / 8; r = 5.0 + 4.6 * t; z = 9.1 + 1.6 * math.sin(math.pi * t * .6) - 6.8 * t * t
            pts.append((r * math.cos(a), r * math.sin(a), z))
        G.append(tube(f"f_jet{i}", pts, radius=.28, col="neon_cyan", seg=6, taper=[1, 1, .95, .9, .85, .8, .75, .7, .6]))
    return P, G

def palm():
    P = []
    pts = [(0, 0, 0), (.4, 0, 3), (1.2, 0, 6), (2.4, 0, 8.6)]
    P += striped_tube("p_trunk", pts, .7, ["wood", "wood_dark", "wood", "wood_dark", "wood", "wood_dark"], seg=10, taper=lambda t: 1 - .35 * t)
    top = Vector((2.4, 0, 8.7))
    leaf = [(0, 0)] + [(4.8 * t, .9 * math.sin(math.pi * t) + .05) for t in (.15, .35, .55, .75, .9)] + [(5.2, 0)] + \
           [(4.8 * t, -.9 * math.sin(math.pi * t) - .05) for t in (.9, .75, .55, .35, .15)]
    for i in range(7):
        a = 2 * math.pi * i / 7
        M = Matrix.Translation(top) @ Matrix.Rotation(a, 4, 'Z') @ Matrix.Rotation(math.radians(28), 4, 'Y')
        P.append(slab(f"p_leaf{i}", leaf, thick=.18, col=["lime", "jade"][i % 2], bevel=.04, matrix=M))
    for i in range(3):
        a = 2 * math.pi * i / 3 + .4
        P.append(sphere(f"p_coco{i}", (.45, .45, .45), loc=top + Vector((.6 * math.cos(a), .6 * math.sin(a), -.5)), col="brown", seg=10, ring=6))
    return P, []

def lamp():
    P = []; G = []
    P.append(cyl("l_foot", .8, .9, .5, col="ink_soft", seg=12, bevel=.08))
    P.append(cyl("l_pole", .22, .22, 8, loc=(0, 0, .5), col="ink_soft", seg=10))
    P.append(torus("l_ring", .5, .1, loc=(0, 0, 3), col="mango", seg=16, mseg=6))
    P.append(cyl("l_cap", .9, .2, .6, loc=(0, 0, 9.6), col="fiesta_pink", seg=14, bevel=.05))
    P.append(cyl("l_hold", .5, .7, .3, loc=(0, 0, 8.4), col="ink_soft", seg=14))
    G.append(sphere("l_bulb", (.75, .75, .7), loc=(0, 0, 9.05), col="neon_gold", seg=14, ring=8))
    return P, G

MODULES = {"lobby_kiosk": kiosk, "lobby_fountain": fountain, "lobby_palm": palm, "lobby_lamp": lamp}
CAMS = {"lobby_kiosk": (30, 14), "lobby_fountain": (30, 22), "lobby_palm": (30, 12), "lobby_lamp": (30, 10)}

def build_module(name):
    reset(); write_palette_textures()
    P, G = MODULES[name]()
    return finish(name, P, G, "lobby", cam=CAMS[name], bg=("#C04BFF", "#F1A8FF"), margin=.92)

# ------------------------------------------------------------------ scene
def scene(res=(1920, 1080), samples=80, preview=False):
    reset(); write_palette_textures()
    pal = material_palette(); neon = material_palette("M_Neon", emissive=1.6)
    def put(parts, glow, M_, name):
        objs = []
        if parts:
            o = join(parts, name); assign_mat(o, pal); smooth(o, 45); o.matrix_world = M_ @ o.matrix_world; objs.append(o)
        if glow:
            g = join(glow, name + "_Neon"); assign_mat(g, neon); g.matrix_world = M_ @ g.matrix_world; objs.append(g)
        return objs
    def asset(name, M_):
        objs = append_asset(name)
        for o in objs: o.matrix_world = M_ @ o.matrix_world
        return objs
    def T(x, y, z=0, rz=0, s=1.0):
        return Matrix.Translation((x, y, z)) @ Matrix.Rotation(math.radians(rz), 4, 'Z') @ Matrix.Scale(s, 4)
    def face_center(x, y): return math.degrees(math.atan2(-x, y))  # rotation so -Y faces origin
    # --- ground + plaza rings
    PR = 46
    G = []
    G.append(cyl("pl_outer", PR + 2, PR + 2, .5, loc=(0, 0, -.1), col="terracotta", seg=64))
    G.append(cyl("pl_main", PR, PR, .52, loc=(0, 0, -.1), col="plaza_tile", seg=64))
    G.append(cyl("pl_ring", 24, 24, .54, loc=(0, 0, -.1), col="terracotta", seg=56))
    G.append(cyl("pl_inner", 22.5, 22.5, .56, loc=(0, 0, -.1), col="cream", seg=56))
    for i in range(16):   # sun-ray tile wedges
        a = 2 * math.pi * i / 16
        G.append(box(f"pl_ray{i}", (1.2, 14, .05), loc=(math.cos(a) * 34, math.sin(a) * 34, .44), rot=(0, 0, math.degrees(a) - 90),
                     col=["fiesta_pink", "turquoise", "sun_yellow", "lime"][i % 4], bevel=0))
    G.append(star_prism("pl_star", 8, 20, 14, .05, loc=(0, 0, .47), col="bubblegum", bevel=0))
    # paths to the plots
    for s in (-1, 1):
        G.append(box(f"path{s}", (24, 12, .5), loc=(s * (PR + 8), 18, .0), col="plaza_tile", bevel=.1))
    put(G, [], Matrix.Identity(4), "Plaza")
    # --- Pasarela: piñata conveyor carpet across the front of the plaza
    PY = -52; PL = 156
    C = [box("carpet", (PL, 10, .3), loc=(0, PY, .55), col="hot_magenta", bevel=.05)]
    for s in (-1, 1):
        C.append(box(f"carpet_edge{s}", (PL, .8, .5), loc=(0, PY + s * 5.2, .55), col="gold", bevel=.1))
    for i in range(30):
        C.append(box(f"chev{i}", (1.6, 4, .05), loc=(-PL / 2 + 3 + i * 5, PY, .72), rot=(0, 0, 0), col="fiesta_pink", bevel=0))
    for k, x in enumerate(range(-72, 74, 12)):   # velvet-rope stanchions
        for s in (-1, 1):
            C.append(cyl(f"stan{k}{s}", .25, .25, 2.6, loc=(x, PY + s * 6.6, .5), col="gold", seg=8))
            C.append(sphere(f"stanb{k}{s}", (.4, .4, .4), loc=(x, PY + s * 6.6, 3.2), col="gold", seg=10, ring=6))
            if x + 12 < 74:
                pts = [(x + t * 12, PY + s * 6.6, 2.7 - .8 * math.sin(math.pi * t)) for t in [j / 6 for j in range(7)]]
                C.append(tube(f"rope{k}{s}", pts, radius=.14, col="red_dark", seg=6))
    C.append(box("plaza_link", (16, 8, .5), loc=(0, -PR - 1, 0), col="plaza_tile", bevel=.1))
    put(C, [], Matrix.Identity(4), "Pasarela")
    # Fábrica arch (spawn end) — reuse the base gate, strip 'BASE', add text plaque
    gM = T(-77, PY, 0, 90, 1.15)
    import bmesh as _bm
    for o in append_asset("base_gate"):
        bm = _bm.new(); bm.from_mesh(o.data)
        _bm.ops.delete(bm, geom=[v for v in bm.verts if v.co.z > 11.55 and abs(v.co.x) < 5.2], context='VERTS'); bm.to_mesh(o.data); bm.free()
        o.matrix_world = gM @ o.matrix_world
    pl = [box("fab_rim", (12.4, .7, 4.4), loc=(0, -.2, 13.4), col="turquoise", bevel=.3, bseg=2),
          box("fab_card", (11.6, .7, 3.6), loc=(0, -.4, 13.4), col="snow", bevel=.2, bseg=2)]
    put(pl, [], gM, "FabricaPlaque")
    t = text_mesh("fab_txt", "FÁBRICA", size=2.4, extrude=.2, col="fiesta_pink", rot=(90, 0, 0), bevel=0); t.location = (0, -.85, 13.3)
    put([t], [], gM, "FabricaText")
    # piñatas walking the carpet (+X), with rarity rings
    walkers = [("estrellita", -54, "neon_green"), ("burrito", -36, "neon_green"), ("michi", -18, "neon_cyan"),
               ("cohetin", 4, "neon_cyan"), ("dragon", 26, "neon_pink"), ("renito", 48, "neon_gold")]
    for nm, x, rc in walkers:
        asset(nm, T(x, PY, .7, 55, 1.25))
        put([], [torus(f"rr_{nm}", 2.6, .18, loc=(0, 0, 0), col=rc, seg=28, mseg=6)], T(x, PY, .9), f"Ring_{nm}")
    # --- fountain centrepiece with estrellita statue
    P_, G_ = fountain(); put(P_, G_, Matrix.Identity(4), "Fountain")
    asset("estrellita", T(0, 0, 10.1, 0, 2.3))
    # --- shop kiosks on the back arc
    shops = [("DULCERÍA", 155, ("candy_red", "sun_yellow", "cream", "snow"), ("candy_pile", 1.5, 0)),
             ("BATES", 115, ("cobalt", "mango", "sky", "snow"), ("bat_wood", 2.4, 1)),
             ("CAJAS", 65, ("grape", "fiesta_pink", "lavender", "snow"), ("caja_sorpresa", 1.7, 0)),
             ("VIP", 25, ("gold", "ink_soft", "ink_soft", "gold_pale"), ("toro", 1.2, 0))]
    R = 33
    for label, ang, cols, (prop, ps, tilt) in shops:
        x, y = R * math.cos(math.radians(ang)), R * math.sin(math.radians(ang)); rz = face_center(x, y)
        M_ = T(x, y, .45, rz, 1.35)
        P_, G_ = kiosk(*cols); put(P_, G_, M_, f"Kiosk_{label}")
        tx = text_mesh(f"t_{label}", label, size=1.9 if len(label) > 5 else 2.2, extrude=.18, col=cols[0] if cols[0] != "gold" else "ink_soft", rot=(90, 0, 0), bevel=0)
        tx.location = (0, -3.25, 8.95); put([tx], [], M_, f"Sign_{label}")
        if tilt:
            asset(prop, M_ @ Matrix.Translation((3.2, 1.5, 7.3)) @ Matrix.Rotation(math.radians(-25), 4, 'Y') @ Matrix.Scale(ps, 4))
        else:
            asset(prop, M_ @ Matrix.Translation((0, 1.8, 7.3)) @ Matrix.Scale(ps, 4))
    # --- papel picado ring + lamps + palms
    for i in range(6):
        a = math.radians(30 + 60 * i)
        x, y = 21 * math.cos(a), 21 * math.sin(a)
        asset("papel_picado_banner", T(x, y, .45, math.degrees(a) + 90, 1.05))
    for i in range(12):
        a = math.radians(15 + 30 * i)
        x, y = (PR - 3) * math.cos(a), (PR - 3) * math.sin(a)
        if abs(y - PY) < 9: continue
        P_, G_ = lamp(); put(P_, G_, T(x, y, .45), f"Lamp{i}")
    rnd = random.Random(3)
    for i in range(14):
        a = math.radians(8 + i * 360 / 14 + rnd.uniform(-5, 5))
        x, y = (PR + 7) * math.cos(a), (PR + 7) * math.sin(a)
        if abs(y - 18) < 9: continue
        P_, G_ = palm(); put(P_, G_, T(x, y, 0, rnd.uniform(0, 360), rnd.uniform(.9, 1.2)), f"Palm{i}")
    # --- player plots (6) flanking the plaza, gates facing the hub
    plot_creatures = ["toro", "torogoz", "michi", "sombra", "dragon", "burrito"]
    k = 0
    for s in (-1, 1):
        for y in (-12, 42, 96):
            x = s * (PR + 44); rz = 90 if s < 0 else -90
            M_ = T(x, y, 0, rz)
            asset("base_floor", M_)
            asset("base_gate", M_ @ Matrix.Translation((0, -28, 0)))
            asset("base_generator", M_ @ Matrix.Translation((0, 22, 0)))
            for px in (-13.5, 13.5):
                asset("base_pedestal", M_ @ Matrix.Translation((px, -6, 0)) @ Matrix.Rotation(math.radians(90 if px > 0 else -90), 4, 'Z'))
            asset(plot_creatures[k], M_ @ Matrix.Translation((13.5 if k % 2 else -13.5, -6, 1.65)) @ Matrix.Scale(1.5, 4)); k += 1
    # distant hills ring
    H = []
    for i in range(22):
        a = 2 * math.pi * i / 22 + rnd.uniform(-.1, .1); r = rnd.uniform(260, 320)
        H.append(sphere(f"hill{i}", (rnd.uniform(50, 80), rnd.uniform(40, 60), rnd.uniform(18, 34)), loc=(r * math.cos(a), r * math.sin(a), -6),
                        col=["grass_dark", "jade", "grass"][i % 3], seg=14, ring=8))
    put(H, [], Matrix.Identity(4), "Hills")
    # grass
    bpy.ops.mesh.primitive_plane_add(size=2000, location=(0, 0, -.2)); g = bpy.context.object
    gm = bpy.data.materials.new("Grass"); gm.use_nodes = True; gb = gm.node_tree.nodes["Principled BSDF"]
    gb.inputs["Base Color"].default_value = (*hex2lin("#58D15A"), 1); gb.inputs["Roughness"].default_value = .9; g.data.materials.append(gm)
    # --- render setup
    s = setup_render((960, 540) if preview else res, 20 if preview else samples)
    w = bpy.data.worlds.new("Sky"); s.world = w; w.use_nodes = True
    nt = w.node_tree; bg = nt.nodes["Background"]; tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0]); ramp = nt.nodes.new("ShaderNodeValToRGB"); nt.links.new(sep.outputs[2], ramp.inputs[0])
    ramp.color_ramp.elements[0].position = .5; ramp.color_ramp.elements[0].color = (*hex2lin("#CFF0FF"), 1)
    ramp.color_ramp.elements[1].position = .62; ramp.color_ramp.elements[1].color = (*hex2lin("#3D9BFF"), 1)
    nt.links.new(ramp.outputs[0], bg.inputs[0]); bg.inputs[1].default_value = 1.0
    sun = bpy.data.lights.new("Sun", 'SUN'); sun.energy = 3.6; sun.angle = math.radians(6); sun.color = hex2srgb("#FFF0D8")
    so = bpy.data.objects.new("Sun", sun); link(so); so.rotation_euler = (math.radians(45), math.radians(-10), math.radians(-35))
    cd = bpy.data.cameras.new("Cam"); cd.lens = 26; cam = bpy.data.objects.new("Cam", cd); link(cam); s.camera = cam
    cam.location = (22, -132, 52); tgt = Vector((-10, -4, 6))
    cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
    if preview:
        render("/tmp/lobby_preview.png"); return
    bpy.ops.wm.save_as_mainfile(filepath=f"{BLEND}/lobby_hub.blend")
    render(f"{REND}/lobby_hub.png")
    # top-down layout map (orthographic) for the GDD
    cd.type = 'ORTHO'; cd.ortho_scale = 290; cam.location = (0, 10, 300); cam.rotation_euler = (0, 0, 0)
    s.render.resolution_x, s.render.resolution_y = 1600, 1200; s.cycles.samples = 32
    render(f"{REND}/lobby_hub_topdown.png")

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(MODULES) + ["scene"]
    metas = {}
    for n in argv:
        if n == "scene": scene(); continue
        if n == "preview": scene(preview=True); continue
        m = build_module(n); metas[m["name"]] = m
    if metas:
        mf = f"{EXP}/lobby/_meta.json"; os.makedirs(f"{EXP}/lobby", exist_ok=True)
        old = json.load(open(mf)) if os.path.exists(mf) else {}
        old.update(metas); json.dump(old, open(mf, "w"), indent=1)
