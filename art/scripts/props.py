import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
from plib import *
from mathutils import Vector, Matrix
FONT = "/usr/share/fonts/truetype/sand-box/google/Luckiest Guy/LuckiestGuy-Regular.ttf"

def text_mesh(name, body, size=1.0, extrude=.12, col="sun_yellow", loc=(0,0,0), rot=(90,0,0), bevel=.02, res=2, bres=0):
    cu = bpy.data.curves.new(name, 'FONT'); cu.body = body
    cu.font = bpy.data.fonts.load(FONT, check_existing=True)
    cu.size = size; cu.extrude = extrude; cu.bevel_depth = bevel; cu.bevel_resolution = 1
    cu.align_x = 'CENTER'; cu.align_y = 'CENTER'; cu.resolution_u = res; cu.bevel_resolution = bres
    o = bpy.data.objects.new(name, cu); link(o)
    xform(o, loc, rot)
    bpy.context.view_layer.objects.active = o
    for x in bpy.context.selected_objects: x.select_set(False)
    o.select_set(True); bpy.ops.object.convert(target='MESH')
    o = bpy.context.view_layer.objects.active
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=0.001); bpy.ops.object.mode_set(mode='OBJECT')
    return paint(o, col)

# ------------------------------------------------------------------ bat
def bat(variant="wood"):
    P = []
    wood = "wood" if variant == "wood" else "gold"
    wood2 = "wood_dark" if variant == "wood" else "gold_deep"
    prof = [(0, .2), (.12, .22), (.18, .13), (1.3, .15), (2.2, .24), (3.2, .34), (3.75, .36), (3.95, .3), (4.02, .0)]
    bm = bmesh.new(); seg = 16; rings = []
    for z, r in prof:
        rings.append([bm.verts.new((r * math.cos(2 * math.pi * j / seg), r * math.sin(2 * math.pi * j / seg), z)) for j in range(seg)])
    for i in range(len(rings) - 1):
        for j in range(seg): bm.faces.new((rings[i][j], rings[i][(j + 1) % seg], rings[i + 1][(j + 1) % seg], rings[i + 1][j]))
    bm.faces.new(list(reversed(rings[0])))
    c = bm.verts.new((0, 0, 4.03))
    for j in range(seg): bm.faces.new((rings[-1][j], rings[-1][(j + 1) % seg], c))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    o = bm_to_obj(bm, "bat_body"); paint(o, wood); P.append(o)
    P.append(cyl("knob", .3, .26, .14, loc=(0, 0, -.02), col=wood2, seg=16, bevel=.04))
    # grip tape spiral
    pts = [(.165 * math.cos(t * 0.9), .165 * math.sin(t * 0.9), .2 + t * .045) for t in range(0, 24)]
    P.append(tube("tape", pts, radius=.045, col="fiesta_pink" if variant == "wood" else "ink", seg=6))
    # painted bands + confetti dots on barrel
    for z, cc in ((2.55, "fiesta_pink"), (2.75, "sun_yellow"), (2.95, "turquoise")):
        r = .24 + (z - 2.2) / 1.0 * .1
        P.append(torus(f"band{z}", r + .005, .035, loc=(0, 0, z), col=cc, seg=20, mseg=5))
    rnd = random.Random(2)
    for k in range(10):
        z = 3.15 + rnd.random() * .55; a = rnd.random() * math.tau
        r = .345 if z < 3.75 else .34
        st = star_prism(f"conf{k}", 5 if k % 2 else 4, .09, .04, .03, col=["fiesta_pink", "turquoise", "sun_yellow", "lime", "grape"][k % 5], bevel=0)
        st.location = (r * math.cos(a), r * math.sin(a), z)
        st.rotation_mode = 'QUATERNION'; st.rotation_quaternion = Vector((math.cos(a), math.sin(a), 0)).to_track_quat('Z', 'Y')
        P.append(st)
    return P, []

# ------------------------------------------------------------------ lucky box
def caja():
    P = []; G = []
    P.append(box("box", (3, 3, 2.6), loc=(0, 0, 1.3), col="fiesta_pink", bevel=.22, bseg=3))
    P.append(box("lid", (3.25, 3.25, .55), loc=(0, 0, 2.75), col="hot_magenta", bevel=.18, bseg=3))
    for rot in (0, 90):
        P.append(box(f"rib{rot}", (.5, 3.32, 2.7), loc=(0, 0, 1.36), rot=(0, 0, rot), col="sun_yellow", bevel=.08))
        P.append(box(f"ribl{rot}", (.52, 3.38, .62), loc=(0, 0, 2.75), rot=(0, 0, rot), col="sun_yellow", bevel=.08))
    # bow
    for s in (-1, 1):
        lp = torus(f"bow{s}", .42, .13, loc=(.42 * s, 0, 3.32), rot=(90, 25 * s, 0), col="sun_yellow", seg=18, mseg=8)
        lp.scale = (1, .55, 1); P.append(lp)
        P.append(ribbon(f"bowtail{s}", [(.1 * s, -.1, 3.1), (.35 * s, -.45, 3.05), (.55 * s, -.75, 2.9)], width=.3, normal=(0, 0, 1), col="sun_yellow", thick=.06))
    P.append(sphere("knot", (.22, .2, .2), loc=(0, 0, 3.15), col="mango", seg=12, ring=8))
    # question marks on 4 sides
    for k in range(4):
        a = math.radians(90 * k)
        d = Vector((math.sin(a), -math.cos(a), 0))
        for sx in (-1, 1):
            side = Vector((math.cos(a), math.sin(a), 0))
            t = text_mesh(f"q{k}{sx}", "?", size=.95, extrude=.06, col="eye_white", rot=(90, 0, math.degrees(a)))
            t.location = d * 1.56 + side * .85 * sx + Vector((0, 0, 1.25)); P.append(t)
    # little fringe skirt along the bottom
    for k in range(4):
        a = math.radians(90 * k); d = Vector((math.sin(a), -math.cos(a), 0)); side = Vector((math.cos(a), math.sin(a), 0))
        for i in range(10):
            u = -1.3 + 2.6 * i / 9
            c = ["turquoise", "sun_yellow", "lime", "grape"][(i + k) % 4]
            o = box(f"fr{k}_{i}", (.2, .05, .35), loc=d * 1.53 + side * u + Vector((0, 0, .3)), rot=(8, 0, math.degrees(a)), col=c, bevel=0)
            P.append(o)
    # rarity glow strip (Neon) on lid edge
    G.append(torus("glow", 1.0, .06, loc=(0, 0, 3.05), col="neon_cyan", seg=4, mseg=4))
    G[-1].rotation_euler = (0, 0, math.radians(45)); G[-1].scale = (1.62, 1.62, 1)
    return P, G

# ------------------------------------------------------------------ candy pile
def candy_one(name, loc, rot, col, scale=1.0):
    out = []
    b = sphere(name + "_b", (.32 * scale, .22 * scale, .22 * scale), loc=loc, rot=rot, col=col, seg=8, ring=5); out.append(b)
    for s in (-1, 1):
        w = cyl(name + f"_w{s}", .03 * scale, .2 * scale, .25 * scale, col=col, seg=6)
        w.data.transform(Matrix.Translation((s * .28 * scale, 0, 0)) @ Matrix.Rotation(math.radians(90 * s), 4, 'Y'))
        xform(w, loc, rot); out.append(w)
    return out

def candy_pile():
    P = []; rnd = random.Random(4)
    cols = ["candy_red", "candy_teal", "candy_violet", "sun_yellow", "fiesta_pink", "lime", "tangerine"]
    P.append(sphere("mound", (1.7, 1.4, .62), loc=(0, 0, 0), col="candy_violet", seg=16, ring=8))
    bm = bmesh.new(); bm.from_mesh(P[0].data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, 0), plane_no=(0, 0, -1), clear_outer=True)
    bmesh.ops.contextual_create(bm, geom=[e for e in bm.edges if e.is_boundary]); bm.to_mesh(P[0].data); bm.free()
    for i in range(30):
        a = rnd.random() * math.tau; r = math.sqrt(rnd.random())
        x, y = 1.8 * r * math.cos(a), 1.5 * r * math.sin(a)
        z = .62 * math.sqrt(max(0, 1 - r * r)) + .06 + rnd.random() * .08
        P += candy_one(f"c{i}", (x, y, z), (rnd.uniform(-30, 30), rnd.uniform(-30, 30), rnd.uniform(0, 360)), cols[i % len(cols)], scale=rnd.uniform(1.15, 1.45))
    for i in range(8):
        a = rnd.random() * math.tau; r = .3 + .9 * rnd.random()
        x, y = 1.6 * r * math.cos(a), 1.3 * r * math.sin(a); z = .7 * math.sqrt(max(0, 1 - r * r)) + .1
        P.append(cyl(f"coin{i}", .22, .22, .06, loc=(x, y, z), rot=(rnd.uniform(-40, 40), rnd.uniform(-40, 40), 0), col="gold", seg=10))
    # lollipops
    for i, (x, y, c1, c2, lean) in enumerate([(-.6, .2, "candy_red", "eye_white", -12), (.5, -.1, "candy_teal", "sun_yellow", 15), (.1, .7, "candy_violet", "fiesta_pink", 5)]):
        h = 1.6 + .3 * i
        st = cyl(f"stick{i}", .05, .05, h, loc=(x, y, .3), rot=(lean, lean * .5, 0), col="eye_white", seg=6); P.append(st)
        top = Matrix.Translation((x, y, .3)) @ Euler((math.radians(lean), math.radians(lean * .5), 0)).to_matrix().to_4x4() @ Matrix.Translation((0, 0, h))
        disc = cyl(f"pop{i}", .5, .5, .16, col=c1, seg=18, bevel=.05, bseg=1, base=False); disc.data.transform(top @ Matrix.Rotation(math.radians(90), 4, 'X')); P.append(disc)
        sw = []
        for t in range(22):
            ang = t * .82; rr = .05 + t * .019
            sw.append(top @ Matrix.Rotation(math.radians(90), 4, 'X') @ Vector((rr * math.cos(ang), rr * math.sin(ang), .085)))
        P.append(tube(f"swirl{i}", sw, radius=.045, col=c2, seg=4))
    return P, []

# ------------------------------------------------------------------ papel picado banner
def papel_picado(span=16.0, n=9, sag=1.0, pole_h=9.0):
    P = []; F = []
    P.append(cyl("poleL", .25, .22, pole_h, loc=(-span / 2, 0, 0), col="wood", seg=10, bevel=.04))
    P.append(cyl("poleR", .25, .22, pole_h, loc=(span / 2, 0, 0), col="wood", seg=10, bevel=.04))
    for x in (-span / 2, span / 2):
        P.append(sphere(f"cap{x}", (.35, .35, .35), loc=(x, 0, pole_h + .1), col="fiesta_pink", seg=12, ring=8))
    rope = []
    for i in range(21):
        t = i / 20; x = -span / 2 + span * t
        rope.append((x, 0, pole_h - .4 - sag * 4 * t * (1 - t)))
    P.append(tube("rope", rope, radius=.05, col="ink_soft", seg=6))
    fw, fh = span / n * .82, span / n * 1.6
    bm = bmesh.new(); uvs = []
    for i in range(n):
        t = (i + .5) / n; x = -span / 2 + span * t
        ztop = pole_h - .4 - sag * 4 * t * (1 - t)
        col = i % 4; u0, u1 = col / 4 + .008, (col + 1) / 4 - .008
        sway = math.sin(i * 1.7) * .12
        quad = [(x - fw / 2, sway, ztop), (x + fw / 2, sway, ztop), (x + fw / 2, sway - .15, ztop - fh), (x - fw / 2, sway - .15, ztop - fh)]
        # subdivide vertically 3 rows so it can bend a little
        rows = 4; vs = []
        for r in range(rows + 1):
            f = r / rows
            L = Vector(quad[0]).lerp(Vector(quad[3]), f); R = Vector(quad[1]).lerp(Vector(quad[2]), f)
            bow = Vector((0, -.12 * math.sin(f * math.pi), 0))
            vs.append((bm.verts.new(L + bow), bm.verts.new(R + bow), 1 - f))
        for r in range(rows):
            a, b = vs[r], vs[r + 1]
            fc = bm.faces.new((a[0], b[0], b[1], a[1])); uvs.append((fc, [(u0, a[2]), (u0, b[2]), (u1, b[2]), (u1, a[2])]))
            # back face (mirrored)
            off = Vector((0, .01, 0))
            fb = bm.faces.new((bm.verts.new(a[1].co + off), bm.verts.new(b[1].co + off), bm.verts.new(b[0].co + off), bm.verts.new(a[0].co + off)))
            uvs.append((fb, [(u1, a[2]), (u1, b[2]), (u0, b[2]), (u0, a[2])]))
    uvl = bm.loops.layers.uv.new("UVMap")
    for fc, uv in uvs:
        for l, u in zip(fc.loops, uv): l[uvl].uv = u
    me = bpy.data.meshes.new("flags"); bm.to_mesh(me); bm.free()
    fo = link(bpy.data.objects.new("papel_picado_Flags", me))
    for x in fo.data.polygons: x.use_smooth = True
    return P, [fo]

def flags_material():
    m = bpy.data.materials.new("M_PapelPicado"); m.use_nodes = True; nt = m.node_tree
    b = nt.nodes["Principled BSDF"]; t = nt.nodes.new("ShaderNodeTexImage")
    t.image = bpy.data.images.load(TEX + "/papel_picado_atlas.png")
    nt.links.new(t.outputs[0], b.inputs["Base Color"]); nt.links.new(t.outputs[1], b.inputs["Alpha"])
    b.inputs["Roughness"].default_value = .7
    b.inputs["Transmission Weight"].default_value = 0.0
    b.inputs["Subsurface Weight"].default_value = 0.0
    m.blend_method = 'HASHED'
    return m

# ------------------------------------------------------------------ generic runner
def finish(name, parts, glow, sub, cam=(30, 18), bg=("#23A6FF", "#8FD8FF"), render_it=True, lens=55, margin=.9, extra_objs=(), res=(1100, 1100), special=None, render_rot=None, keep_xy=False):
    main = join([p for p in parts], name)
    objs = [main]
    if glow: objs.append(join(glow, name + "_Neon"))
    for e in extra_objs: objs.append(e)
    size = base_origin(objs, keep_xy=keep_xy)
    for o in objs:
        if o.name.endswith("_Neon"): assign_mat(o, material_palette("M_Neon", emissive=1.6))
        elif special and o.name in special: assign_mat(o, special[o.name])
        else: assign_mat(o, material_palette())
        smooth(o, 45)
    info = export(objs, name, sub)
    bpy.ops.wm.save_as_mainfile(filepath=f"{BLEND}/{name}.blend")
    meta = {"name": name, "size_studs": [round(size.x, 2), round(size.z, 2), round(size.y, 2)], "tris": info}
    print("META", json.dumps(meta))
    if render_it:
        if render_rot:
            for o in objs:
                o.matrix_world = Matrix.Translation((0, 0, render_rot[1])) @ Matrix.Rotation(math.radians(render_rot[0]), 4, 'Y') @ o.matrix_world
        setup_render(res, 64); backdrop(*bg, rot_z=cam[0], size=max(60, size.length * 4))
        lights(scale=max(1.0, size.z / 3.0), center=(0, 0, size.z * .45))
        camera_fit(objs, az=cam[0], el=cam[1], lens=lens, margin=margin)
        render(f"{REND}/{name}.png")
    return meta

PROPS = {}
def prop(fn):
    PROPS[fn.__name__.replace("make_", "")] = fn; return fn

@prop
def make_bat():
    reset(); write_palette_textures(); P, G = bat("wood")
    for p in P: p.data.transform(Matrix.Rotation(math.radians(0), 4, 'X'))
    return finish("bat_wood", P, G, "props", cam=(20, 22), bg=("#FF7A1A", "#FFC27A"), render_rot=(-62, .5))

@prop
def make_bat_gold():
    reset(); write_palette_textures(); P, G = bat("gold")
    return finish("bat_gold", P, G, "props", cam=(20, 22), bg=("#8A3CF0", "#D2A8FF"), render_rot=(-62, .5))

@prop
def make_caja():
    reset(); write_palette_textures(); P, G = caja()
    return finish("caja_sorpresa", P, G, "props", cam=(32, 20), bg=("#23A6FF", "#8FD8FF"))

@prop
def make_candy():
    reset(); write_palette_textures(); P, G = candy_pile()
    return finish("candy_pile", P, G, "props", cam=(28, 26), bg=("#2FCB6B", "#A8F5B8"))

@prop
def make_papel():
    reset(); write_palette_textures(); P, F = papel_picado()
    fm = flags_material()
    return finish("papel_picado_banner", P, [], "props", cam=(20, 8), bg=("#23A6FF", "#8FD8FF"), extra_objs=F, special={"papel_picado_Flags": fm}, lens=40)

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(PROPS)
    metas = {}
    for n in argv:
        m = PROPS[n](); metas[m["name"]] = m
    mf = f"{EXP}/props/_meta.json"; os.makedirs(f"{EXP}/props", exist_ok=True)
    old = json.load(open(mf)) if os.path.exists(mf) else {}
    old.update(metas); json.dump(old, open(mf, "w"), indent=1)
