import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
from plib import *
from props import text_mesh, finish, papel_picado, flags_material, candy_pile, bat
from mathutils import Vector, Matrix

def append_asset(blendname, names=None):
    path = f"{BLEND}/{blendname}.blend"
    with bpy.data.libraries.load(path) as (src, dst):
        dst.objects = [n for n in src.objects if (names is None or n in names)]
    out = []
    for o in dst.objects:
        if o is None or o.type != 'MESH': continue
        link(o); out.append(o)
    return out

# ------------------------------------------------------------------ modules
def pedestal():
    P = []; G = []
    P.append(cyl("ped_base", 3.1, 3.3, .6, col="stone_dark", seg=28, bevel=.12))
    P.append(cyl("ped_mid", 2.8, 2.9, .7, loc=(0, 0, .6), col="fiesta_pink", seg=28, bevel=.12))
    P.append(cyl("ped_top", 2.95, 2.95, .35, loc=(0, 0, 1.3), col="cream", seg=28, bevel=.1))
    # scalloped trim (little spheres)
    for k in range(20):
        a = 2 * math.pi * k / 20
        P.append(sphere(f"bead{k}", (.18, .18, .18), loc=(2.9 * math.cos(a), 2.9 * math.sin(a), .95), col=["sun_yellow", "turquoise"][k % 2], seg=8, ring=5))
    # collect pad in front (neon ring = "touch to collect")
    P.append(cyl("collect", 1.0, 1.05, .25, loc=(0, -4.3, 0), col="stone_dark", seg=20, bevel=.06))
    G.append(torus("collect_ring", .78, .1, loc=(0, -4.3, .27), col="neon_green", seg=20, mseg=6))
    return P, G

def gate():
    P = []; G = []
    W = 14
    for s in (-1, 1):
        x = s * W / 2
        P.append(cyl(f"pillar_base{s}", 1.8, 1.9, 1.0, loc=(x, 0, 0), col="stone_dark", seg=16, bevel=.12))
        for k in range(8):
            P.append(cyl(f"pil{s}{k}", 1.35, 1.35, 1.3, loc=(x, 0, 1.0 + k * 1.3), col=["fiesta_pink", "snow"][k % 2], seg=16, bevel=.08))
        P.append(sphere(f"pil_top{s}", (1.6, 1.6, 1.0), loc=(x, 0, 11.6), col="sun_yellow", seg=16, ring=8))
        P.append(star_prism(f"pil_star{s}", 5, 1.0, .45, .45, loc=(x, 0, 13.4), rot=(90, 0, 0), col="mango", bevel=.1))
    P.append(box("beam", (W + 1.5, 1.6, 1.8), loc=(0, 0, 10.6), col="turquoise", bevel=.3, bseg=3))
    P.append(box("sign", (8.5, .7, 3.0), loc=(0, -.9, 12.4), col="snow", bevel=.3, bseg=3))
    P.append(box("signrim", (9.1, .5, 3.6), loc=(0, -.6, 12.4), col="fiesta_pink", bevel=.3, bseg=3))
    t = text_mesh("signtxt", "BASE", size=2.2, extrude=.15, col="ink_soft", rot=(90, 0, 0)); t.location = (0, -1.35, 12.35); P.append(t)
    # laser barrier: stack of neon bars (server toggles when locked)
    for k in range(5):
        G.append(cyl(f"laser{k}", .12, .12, W - 2.2, loc=(-(W - 2.2) / 2, 0, 1.8 + k * 1.7), rot=(0, 90, 0), col="neon_pink", seg=8))
    return P, G

def padlock():
    P = []
    P.append(box("lock_body", (2.2, 1.0, 1.9), loc=(0, 0, .95), col="gold", bevel=.25, bseg=3))
    P.append(torus("shackle", .72, .2, loc=(0, 0, 1.9), rot=(90, 0, 0), col="silver", seg=20, mseg=8, arc=180))
    P.append(cyl("keyhole", .2, .2, .2, loc=(0, -.42, 1.15), rot=(90, 0, 0), col="ink", seg=12))
    P.append(box("keyslot", (.14, .2, .5), loc=(0, -.52, .85), col="ink", bevel=0))
    P.append(star_prism("lockstar", 5, .25, .11, .08, loc=(0, -.52, 1.55), rot=(90, 0, 0), col="fiesta_pink", bevel=.02))
    return P, []

def generator():
    """Gumball-style 'Dulcería' candy generator. Glass dome exported as separate mesh."""
    P = []; GL = []
    P.append(cyl("g_foot", 2.8, 3.0, .6, col="stone_dark", seg=24, bevel=.12))
    P.append(cyl("g_base", 2.3, 2.7, 3.6, loc=(0, 0, .6), col="candy_red", seg=24, bevel=.25))
    P.append(torus("g_trim", 2.35, .14, loc=(0, 0, 4.15), col="gold", seg=28, mseg=6))
    P.append(torus("g_trim2", 2.65, .14, loc=(0, 0, .75), col="gold", seg=28, mseg=6))
    P.append(cyl("g_collar", 2.0, 2.2, .5, loc=(0, 0, 4.2), col="gold", seg=24, bevel=.1))
    # chute + tray
    P.append(box("chute", (1.5, 1.0, 1.4), loc=(0, -2.35, 2.0), col="gold", bevel=.2, bseg=2))
    P.append(box("chute_hole", (1.0, .3, .8), loc=(0, -2.85, 1.9), col="ink", bevel=.1))
    P.append(box("tray", (2.0, 1.4, .3), loc=(0, -2.9, 1.15), col="gold", bevel=.12))
    P.append(cyl("crank", .55, .55, .3, loc=(0, -2.45, 3.25), rot=(90, 0, 0), col="silver", seg=16, bevel=.06))
    P.append(box("crank_arm", (1.3, .2, .25), loc=(.5, -2.65, 3.25), rot=(0, 30, 0), col="silver", bevel=.05))
    P.append(sphere("crank_knob", (.25, .25, .25), loc=(1.05, -2.7, 3.55), col="fiesta_pink", seg=10, ring=6))
    # candy balls inside dome
    rnd = random.Random(9); cols = ["candy_red", "candy_teal", "candy_violet", "sun_yellow", "fiesta_pink", "lime", "tangerine", "eye_white"]
    cz = 7.0; R = 2.75
    n = 0
    for i in range(400):
        p = Vector((rnd.uniform(-R, R), rnd.uniform(-R, R), rnd.uniform(-R, .6)))
        if p.length < R - .5 and n < 70:
            P.append(sphere(f"ball{n}", (.48, .48, .48), loc=(p.x, p.y, cz + p.z), col=cols[n % len(cols)], seg=10, ring=6)); n += 1
    GL.append(sphere("dome", (R, R, R), loc=(0, 0, cz), col="glass", seg=28, ring=16))
    P.append(cyl("cap", 1.0, .7, .7, loc=(0, 0, cz + R - .3), col="candy_red", seg=18, bevel=.15))
    P.append(sphere("cap_ball", (.45, .45, .45), loc=(0, 0, cz + R + .55), col="sun_yellow", seg=12, ring=8))
    return P, GL

def fence(length=8.0, n=6):
    P = []
    for i in range(n):
        x = -length / 2 + length * (i + .5) / n
        h = 3.0 + (.3 if i % 2 else 0)
        c = ["fiesta_pink", "turquoise", "sun_yellow", "lime", "grape", "tangerine"][i % 6]
        P.append(box(f"picket{i}", (1.0, .35, h), loc=(x, 0, h / 2), col=c, bevel=.12, bseg=2))
        P.append(cyl(f"picktop{i}", .5, .02, .55, loc=(x, 0, h - .05), col=c, seg=4, rot=(0, 0, 45)))
    for z in (.9, 2.2):
        P.append(box(f"rail{z}", (length, .25, .35), loc=(0, .3, z), col="white", bevel=.08))
    return P, []

def floor_pad(W=46, L=58):
    P = []
    P.append(box("pad", (W, L, 1.2), loc=(0, 0, -.6), col="grass", bevel=.5, bseg=3))
    P.append(box("rim", (W + 1.6, L + 1.6, .9), loc=(0, 0, -.75), col="stone_dark", bevel=.4, bseg=2))
    # tiled path from gate to generator
    rnd = random.Random(1)
    for j in range(13):
        for i in range(3):
            c = ["plaza_tile", "cream", "terracotta"][(i + j) % 3]
            P.append(box(f"tile{i}_{j}", (2.7, 2.7, .3), loc=(-3 + i * 3, -L / 2 + 3 + j * 3.6, .1), col=c, bevel=.15, bseg=1))
    return P, []

def sign_post():
    P = []
    P.append(cyl("post", .3, .3, 5, col="wood", seg=10, bevel=.05))
    P.append(box("board", (6, .5, 2.6), loc=(0, -.2, 5.2), col="wood", bevel=.25))
    P.append(box("board_face", (5.4, .2, 2.0), loc=(0, -.5, 5.2), col="cream", bevel=.12))
    P.append(star_prism("board_star", 5, .5, .22, .2, loc=(-2.0, -.65, 5.2), rot=(90, 0, 0), col="fiesta_pink"))
    return P, []

MODULES = {"base_pedestal": pedestal, "base_gate": gate, "base_padlock": padlock, "base_generator": generator,
           "base_fence": fence, "base_floor": floor_pad, "base_signpost": sign_post}

def build_module(name):
    reset(); write_palette_textures()
    P, G = MODULES[name]()
    if name == "base_generator":
        # glass as its own mesh/material
        glass = join(G, name + "_Glass"); G = []
        gm = bpy.data.materials.new("M_Glass"); gm.use_nodes = True
        b = gm.node_tree.nodes["Principled BSDF"]; b.inputs["Base Color"].default_value = (*hex2lin("#BFF4FF"), 1)
        b.inputs["Transmission Weight"].default_value = 1.0; b.inputs["Roughness"].default_value = 0.05; b.inputs["IOR"].default_value = 1.2
        return finish(name, P, G, "base", cam=(30, 16), extra_objs=[glass], special={name + "_Glass": gm}, margin=.9, keep_xy=True)
    cams = {"base_floor": (25, 45), "base_gate": (25, 10), "base_fence": (25, 12)}
    return finish(name, P, G, "base", cam=cams.get(name, (30, 18)), margin=.92 if name != "base_floor" else .8, keep_xy=True)

# ------------------------------------------------------------------ assembled plot scene
def assembled(render_name="base_plot_assembled", res=(1600, 1000), samples=96, cam=None):
    reset(); write_palette_textures()
    objs = []
    for n in MODULES: pass
    def place(blend, loc, rotz=0, scale=1.0):
        got = append_asset(blend)
        for o in got:
            o.matrix_world = Matrix.Translation(loc) @ Matrix.Rotation(math.radians(rotz), 4, 'Z') @ Matrix.Scale(scale, 4) @ o.matrix_world
        objs.extend(got); return got
    W, L = 46, 58
    place("base_floor", (0, 0, 0))
    place("base_gate", (0, -L / 2 + 1.5, 0))
    place("base_padlock", (7.0, -L / 2 - .1, 4.5), scale=1.0)
    place("base_generator", (0, L / 2 - 7, 0))
    # fences on 3 sides + front corners
    for i in range(6):
        place("base_fence", (-W / 2 + .5, -L / 2 + 6 + i * 8.2, 0), rotz=90)
        place("base_fence", (W / 2 - .5, -L / 2 + 6 + i * 8.2, 0), rotz=90)
    for i in range(5):
        place("base_fence", (-W / 2 + 6 + i * 8.6, L / 2 - .5, 0))
    for s in (-1, 1):
        place("base_fence", (s * 15.5, -L / 2 + .5, 0))
    creatures = ["estrellita", "burrito", "michi", "cohetin", "dragon", "toro", "renito", "torogoz"]
    scl = {"toro": 1.25, "torogoz": 1.3, "dragon": 1.15, "renito": 1.1}
    k = 0
    for row in range(4):
        for s in (-1, 1):
            x = s * 13.5; y = -16 + row * 10
            place("base_pedestal", (x, y, 0), rotz=90 * s)  # collect pad faces the path
            c = creatures[k]; k += 1
            place(c, (x, y, 1.65), rotz=(50 if s < 0 else -50), scale=1.5 * scl.get(c, 1.0))
    place("papel_picado_banner", (0, -6, 0), scale=1.25)
    place("papel_picado_banner", (0, 10, 0), scale=1.25)
    place("candy_pile", (6, L / 2 - 8, 0), scale=1.2)
    place("candy_pile", (-6.5, L / 2 - 9, 0), rotz=60, scale=1.0)
    place("caja_sorpresa", (-5, -L / 2 + 8, 0), rotz=20, scale=.9)
    place("base_signpost", (-11, -L / 2 + 3, 0), rotz=-10)
    # ground around
    bpy.ops.mesh.primitive_plane_add(size=4000, location=(0, 0, -1.2)); g = bpy.context.object
    gm = bpy.data.materials.new("Ground"); gm.use_nodes = True; gm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*hex2lin("#FFD9A0"), 1)
    gm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .95
    g.data.materials.append(gm)
    setup_render(res, samples)
    s = bpy.context.scene
    w = bpy.data.worlds.new("Sky"); s.world = w; w.use_nodes = True
    nt = w.node_tree; bg = nt.nodes["Background"]
    bg.inputs[0].default_value = (*hex2lin("#7CC8FF"), 1); bg.inputs[1].default_value = .9
    sun = bpy.data.lights.new("Sun", 'SUN'); sun.energy = 3.6; sun.angle = math.radians(6); sun.color = hex2srgb("#FFF0D8")
    so = bpy.data.objects.new("Sun", sun); link(so); so.rotation_euler = (math.radians(48), math.radians(-12), math.radians(-35))
    cd = bpy.data.cameras.new("Cam"); cd.lens = 28; camo = bpy.data.objects.new("Cam", cd); link(camo); s.camera = camo
    camo.location = cam[0] if cam else (30, -50, 27); tgt = Vector(cam[1] if cam else (0, -1, 1))
    camo.rotation_euler = (tgt - camo.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.ops.wm.save_as_mainfile(filepath=f"{BLEND}/{render_name}.blend")
    render(f"{REND}/{render_name}.png")

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(MODULES) + ["assembled"]
    metas = {}
    for n in argv:
        if n == "assembled": assembled(); continue
        m = build_module(n); metas[m["name"]] = m
    if metas:
        mf = f"{EXP}/base/_meta.json"; os.makedirs(f"{EXP}/base", exist_ok=True)
        old = json.load(open(mf)) if os.path.exists(mf) else {}
        old.update(metas); json.dump(old, open(mf, "w"), indent=1)
