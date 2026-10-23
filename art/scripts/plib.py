"""plib: shared Blender helpers for Steal a Piñata! assets.
Units: 1 Blender unit = 1 Roblox stud (scene unit scale 0.01 so FBX lands 1:1 in studs).
Colour: every face gets a palette cell (UV) + vertex colour, so ONE shared 256px
palette texture (art/textures/palette_color.png) colours every asset in Roblox.
"""
import bpy, bmesh, math, random, os, json
from mathutils import Vector, Matrix, Euler
from mathutils.bvhtree import BVHTree

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo/art (works in any worktree)
TEX = ROOT + "/textures"
EXP = ROOT + "/export"
BLEND = ROOT + "/blend"
REND = ROOT + "/renders"

# ---------------------------------------------------------------- palette
# name: (hex, roughness, metallic)
PALETTE = [
 ("white",      "#FFF7EC", .45, 0), ("ink",        "#1B1430", .30, 0),
 ("ink_soft",   "#3A2A55", .40, 0), ("eye_white",  "#FFFFFF", .15, 0),
 ("blush",      "#FF7FA8", .55, 0), ("tongue",     "#FF4D6D", .45, 0),
 ("fiesta_pink","#FF3E9A", .55, 0), ("hot_magenta","#E0187A", .55, 0),
 ("mango",      "#FFB400", .50, 0), ("sun_yellow", "#FFE14D", .50, 0),
 ("tangerine",  "#FF7A1A", .50, 0), ("chili",      "#E8262E", .50, 0),
 ("lime",       "#8BE530", .55, 0), ("jade",       "#18C98A", .50, 0),
 ("turquoise",  "#16D3E8", .45, 0), ("sky",        "#3DA5FF", .50, 0),
 ("cobalt",     "#2A55E0", .50, 0), ("grape",      "#8A3CF0", .50, 0),
 ("lavender",   "#C59BFF", .55, 0), ("mint",       "#9FF5D6", .55, 0),
 ("bubblegum",  "#FFB3D9", .55, 0), ("cream",      "#FFE6B8", .60, 0),
 ("donkey_grey","#A9B4C9", .60, 0), ("donkey_dark","#6C7894", .60, 0),
 ("brown",      "#8A4B2A", .65, 0), ("wood",       "#C98A4B", .70, 0),
 ("wood_dark",  "#7A4A26", .75, 0), ("gold",       "#FFC22E", .28, .8),
 ("gold_deep",  "#E08A00", .32, .8), ("gold_pale",  "#FFE9A0", .25, .7),
 ("silver",     "#D9E2F2", .25, 1), ("steel",      "#7D8AA6", .35, 1),
 ("xmas_red",   "#D7192F", .50, 0), ("xmas_green", "#11A35A", .55, 0),
 ("snow",       "#F4FBFF", .60, 0), ("pine",       "#0B6E45", .60, 0),
 ("cosmic_1",   "#2B0F6B", .35, 0), ("cosmic_2",   "#5B2BE0", .35, 0),
 ("cosmic_3",   "#FF4FD8", .35, 0), ("cosmic_4",   "#3FF2FF", .30, 0),
 ("torogoz_t",  "#1FC7C1", .45, 0), ("torogoz_r",  "#D9572B", .50, 0),
 ("grass",      "#5FD35A", .80, 0), ("grass_dark", "#3FAE45", .85, 0),
 ("stone",      "#E9E1F2", .70, 0), ("stone_dark", "#B9AECB", .75, 0),
 ("plaza_tile", "#FFD9A8", .75, 0), ("terracotta", "#E07A4F", .75, 0),
 ("glass",      "#BFF4FF", .05, 0), ("rubber",     "#2D2440", .85, 0),
 ("neon_pink",  "#FF4FD8", .30, 0), ("neon_cyan",  "#3FF2FF", .30, 0),
 ("neon_gold",  "#FFD84D", .30, 0), ("neon_green", "#5CFF8A", .30, 0),
 ("red_dark",   "#9E1420", .55, 0), ("rocket_fin", "#2A55E0", .45, 0),
 ("cat_orange", "#FF9A3D", .55, 0), ("cat_cream",  "#FFE2C2", .60, 0),
 ("peach",      "#FFC9A8", .60, 0), ("candy_red",  "#FF2D55", .25, 0),
 ("candy_teal", "#00C2B8", .25, 0), ("candy_violet","#9B4DFF", .25, 0),
 ("chocolate",  "#5A2E1A", .45, 0), ("dark_green", "#0E5C3A", .60, 0),
 # --- phase 2 (plaza architecture) — appended, existing UV cells unchanged
 ("wall_rose",  "#F79BBE", .80, 0), ("wall_ochre", "#F9C34E", .80, 0),
 ("wall_aqua",  "#5AD2CB", .80, 0), ("wall_lilac", "#A88AF2", .80, 0),
 ("iron",       "#2B2238", .40, .6), ("tile_blue",  "#1F4FC9", .20, 0),
 ("leaf",       "#3DBB4C", .70, 0), ("leaf_dark",  "#23893A", .75, 0),
 ("bark",       "#6B4128", .85, 0), ("flame",      "#FF5A1F", .65, 0),
 ("water",      "#25C7E0", .05, 0), ("trim",       "#FFF4E0", .65, 0),
 ("roof_tile",  "#C9562E", .70, 0), ("velvet",     "#B0124F", .80, 0),
]
CELL = 64; GRID = 16; TEXSIZE = CELL * GRID
PIDX = {n: i for i, (n, *_r) in enumerate(PALETTE)}

def hex2lin(h):
    h = h.lstrip('#'); c = [int(h[i:i+2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x / 12.92) if x <= 0.04045 else ((x + .055) / 1.055) ** 2.4) for x in c)

def hex2srgb(h):
    h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) / 255 for i in (0, 2, 4))

def cell_uv(name):
    i = PIDX[name]; cx, cy = i % GRID, i // GRID
    return ((cx + .5) / GRID, 1 - (cy + .5) / GRID)

def write_palette_textures():
    """Writes palette_color/roughness/metalness PNGs + palette.json (Roblox SurfaceAppearance ready)."""
    import numpy as np
    os.makedirs(TEX, exist_ok=True)
    col = np.zeros((TEXSIZE, TEXSIZE, 4), np.float32); col[..., 3] = 1
    rough = np.ones_like(col); metal = np.zeros_like(col); metal[..., 3] = 1
    for i, (n, hx, r, m) in enumerate(PALETTE):
        cx, cy = i % GRID, i // GRID
        y0 = TEXSIZE - (cy + 1) * CELL  # numpy rows bottom-up in blender images
        sl = (slice(y0, y0 + CELL), slice(cx * CELL, cx * CELL + CELL))
        col[sl[0], sl[1], :3] = hex2srgb(hx)
        rough[sl[0], sl[1], :3] = r
        metal[sl[0], sl[1], :3] = m
    for nm, arr in (("palette_color", col), ("palette_roughness", rough), ("palette_metalness", metal)):
        img = bpy.data.images.get(nm) or bpy.data.images.new(nm, TEXSIZE, TEXSIZE, alpha=False)
        img.pixels.foreach_set(arr.ravel()); img.filepath_raw = f"{TEX}/{nm}.png"
        img.file_format = 'PNG'; img.save()
    json.dump({n: {"hex": h, "roughness": r, "metalness": m, "uv": cell_uv(n)} for n, h, r, m in PALETTE},
              open(f"{TEX}/palette.json", "w"), indent=1)

# ---------------------------------------------------------------- scene
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    s = bpy.context.scene
    s.unit_settings.system = 'METRIC'; s.unit_settings.scale_length = 0.01
    s.unit_settings.length_unit = 'CENTIMETERS'
    return s

def link(obj, coll=None):
    (coll or bpy.context.scene.collection).objects.link(obj); return obj

def bm_to_obj(bm, name, coll=None):
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    return link(bpy.data.objects.new(name, me), coll)

def paint(obj, cname):
    """Assign palette colour (UV cell + vertex colour) to all faces of obj."""
    me = obj.data
    if not me.uv_layers: me.uv_layers.new(name="UVMap")
    uv = me.uv_layers[0].data; u = cell_uv(cname)
    for l in uv: l.uv = u
    ca = me.color_attributes.get("Col") or me.color_attributes.new("Col", 'BYTE_COLOR', 'CORNER')
    c = hex2srgb(PALETTE[PIDX[cname]][1])
    lin = hex2lin(PALETTE[PIDX[cname]][1])
    for d in ca.data: d.color = (*lin, 1)
    obj["pal"] = cname
    return obj

def apply_mods(obj):
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.selected_objects: o.select_set(False)
    obj.select_set(True)
    for m in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)
    return obj

def xform(obj, loc=(0,0,0), rot=(0,0,0), scl=(1,1,1)):
    obj.location = loc; obj.rotation_euler = Euler([math.radians(a) for a in rot]); obj.scale = scl
    return obj

def bake_xform(obj):
    me = obj.data; me.transform(obj.matrix_world); obj.matrix_world = Matrix.Identity(4)
    if obj.matrix_world.determinant() < 0: pass
    return obj

# ---------------------------------------------------------------- primitives
def sphere(name, r=(1,1,1), loc=(0,0,0), rot=(0,0,0), col="white", seg=16, ring=10):
    bm = bmesh.new(); bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=ring, radius=1)
    bmesh.ops.scale(bm, vec=r, verts=bm.verts)
    o = bm_to_obj(bm, name); xform(o, loc, rot); return paint(o, col)

def cyl(name, r1=1, r2=1, h=1, loc=(0,0,0), rot=(0,0,0), col="white", seg=16, bevel=0.0, bseg=2, base=True):
    """Cylinder/cone standing on z=0 (base) up to z=h."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r1, radius2=max(r2, 1e-4), depth=h)
    if base: bmesh.ops.translate(bm, vec=(0, 0, h / 2), verts=bm.verts)
    o = bm_to_obj(bm, name); xform(o, loc, rot)
    if bevel > 0:
        m = o.modifiers.new("b", 'BEVEL'); m.width = bevel; m.segments = bseg; m.limit_method = 'ANGLE'
        m.angle_limit = math.radians(40); apply_mods(o)
    return paint(o, col)

def box(name, size=(1,1,1), loc=(0,0,0), rot=(0,0,0), col="white", bevel=0.08, bseg=2):
    bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    o = bm_to_obj(bm, name); xform(o, loc, rot)
    if bevel > 0:
        m = o.modifiers.new("b", 'BEVEL'); m.width = bevel; m.segments = bseg; m.limit_method = 'ANGLE'
        apply_mods(o)
    return paint(o, col)

def torus(name, R=1, r=.2, loc=(0,0,0), rot=(0,0,0), col="white", seg=24, mseg=8, arc=360):
    bm = bmesh.new(); verts = []
    n = seg if arc >= 360 else seg + 1
    for i in range(n):
        a = math.radians(arc) * i / seg
        ring = []
        for j in range(mseg):
            b = 2 * math.pi * j / mseg
            p = Vector(((R + r * math.cos(b)) * math.cos(a), (R + r * math.cos(b)) * math.sin(a), r * math.sin(b)))
            ring.append(bm.verts.new(p))
        verts.append(ring)
    rng = range(seg) if arc >= 360 else range(seg)
    for i in rng:
        a, b2 = verts[i], verts[(i + 1) % n]
        for j in range(mseg):
            bm.faces.new((a[j], a[(j+1) % mseg], b2[(j+1) % mseg], b2[j]))
    if arc < 360:
        bm.faces.new(list(reversed(verts[0]))); bm.faces.new(verts[-1])
    o = bm_to_obj(bm, name); xform(o, loc, rot); return paint(o, col)

def tube(name, pts, radius=.1, col="white", seg=8, taper=None, closed=False):
    """Sweep a circle along points (list of xyz). taper: list of radius multipliers."""
    bm = bmesh.new(); rings = []
    P = [Vector(p) for p in pts]; n = len(P)
    prev_side = None
    for i, p in enumerate(P):
        t = (P[min(i+1, n-1)] - P[max(i-1, 0)]).normalized()
        up = Vector((0, 0, 1)) if abs(t.z) < .95 else Vector((1, 0, 0))
        side = t.cross(up).normalized()
        if prev_side is not None and side.dot(prev_side) < 0: side = -side
        prev_side = side
        nrm = side.cross(t).normalized()
        rr = radius * (taper[i] if taper else 1)
        ring = [bm.verts.new(p + rr * (math.cos(2*math.pi*j/seg) * side + math.sin(2*math.pi*j/seg) * nrm)) for j in range(seg)]
        rings.append(ring)
    for i in range(n - 1):
        a, b = rings[i], rings[i+1]
        for j in range(seg):
            bm.faces.new((a[j], a[(j+1) % seg], b[(j+1) % seg], b[j]))
    bm.faces.new(list(reversed(rings[0]))); bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = bm_to_obj(bm, name); return paint(o, col)

def ribbon(name, pts, width=.15, normal=(0,0,1), col="white", thick=0.02):
    """Flat strip (with small thickness) along pts."""
    bm = bmesh.new(); P = [Vector(p) for p in pts]; n = len(P); N = Vector(normal).normalized()
    L, R = [], []
    for i, p in enumerate(P):
        t = (P[min(i+1, n-1)] - P[max(i-1, 0)]).normalized()
        s = t.cross(N).normalized() * width / 2
        L.append(p - s); R.append(p + s)
    top = [bm.verts.new(v + N * thick / 2) for v in L + R]
    bot = [bm.verts.new(v - N * thick / 2) for v in L + R]
    for i in range(n - 1):
        a0, a1, b0, b1 = i, i+1, n+i, n+i+1
        bm.faces.new((top[a0], top[b0], top[b1], top[a1]))
        bm.faces.new((bot[a0], bot[a1], bot[b1], bot[b0]))
        bm.faces.new((top[a0], top[a1], bot[a1], bot[a0]))
        bm.faces.new((top[b0], bot[b0], bot[b1], top[b1]))
    bm.faces.new((top[0], bot[0], bot[n], top[n])); bm.faces.new((top[n-1], top[2*n-1], bot[2*n-1], bot[n-1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return paint(bm_to_obj(bm, name), col)

def star_prism(name, points=5, r_out=1, r_in=.5, depth=.3, loc=(0,0,0), rot=(0,0,0), col="sun_yellow", bevel=.05):
    bm = bmesh.new(); top, bot = [], []
    for i in range(points * 2):
        a = math.pi / 2 + math.pi * i / points; r = r_out if i % 2 == 0 else r_in
        top.append(bm.verts.new((r * math.cos(a), r * math.sin(a), depth / 2)))
        bot.append(bm.verts.new((r * math.cos(a), r * math.sin(a), -depth / 2)))
    bm.faces.new(top); bm.faces.new(list(reversed(bot)))
    m = len(top)
    for i in range(m):
        bm.faces.new((bot[i], bot[(i+1) % m], top[(i+1) % m], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    o = bm_to_obj(bm, name); xform(o, loc, rot)
    if bevel:
        mm = o.modifiers.new("b", 'BEVEL'); mm.width = bevel; mm.segments = 2; apply_mods(o)
    return paint(o, col)

def slab(name, pts2d, thick=.15, col="white", bevel=.04, bseg=2, matrix=Matrix.Identity(4)):
    """Extrude a 2D polygon (x,y) along z by thick (centered), bevel, then transform."""
    bm = bmesh.new()
    top = [bm.verts.new((x, y, thick / 2)) for x, y in pts2d]
    bot = [bm.verts.new((x, y, -thick / 2)) for x, y in pts2d]
    bm.faces.new(top); bm.faces.new(list(reversed(bot)))
    n = len(top)
    for i in range(n): bm.faces.new((bot[i], bot[(i+1) % n], top[(i+1) % n], top[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4], quad_method='BEAUTY', ngon_method='EAR_CLIP')
    o = bm_to_obj(bm, name)
    if bevel:
        m = o.modifiers.new("b", 'BEVEL'); m.width = bevel; m.segments = bseg; m.limit_method = 'ANGLE'; m.angle_limit = math.radians(50); apply_mods(o)
    o.data.transform(matrix)
    return paint(o, col)

def striped_tube(name, pts, radius, colors, seg=10, taper=None, samples=24):
    """Smooth Catmull-Rom tube split in coloured segments (candy-cane / tail stripes)."""
    P = [Vector(p) for p in pts]
    def cr(t):
        n = len(P) - 1; i = min(int(t * n), n - 1); u = t * n - i
        p0 = P[max(i - 1, 0)]; p1 = P[i]; p2 = P[i + 1]; p3 = P[min(i + 2, n)]
        return .5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u)
    pts_s = [cr(i / samples) for i in range(samples + 1)]
    tp = [(taper(i / samples) if taper else 1) for i in range(samples + 1)]
    out = []; nseg = len(colors); per = samples // nseg
    for k in range(nseg):
        a = k * per; b = samples if k == nseg - 1 else (k + 1) * per
        out.append(tube(f"{name}{k}", pts_s[a:b + 1], radius=radius, taper=tp[a:b + 1], col=colors[k], seg=seg))
    return out

# ---------------------------------------------------------------- piñata fringe
def egg_profile(R, H, p=0.9, bottom_flat=0.0, top_scale=1.0):
    """r(z) for z in [0,H]; egg/blob with tunable roundness."""
    def f(z):
        t = (z / H) * 2 - 1  # -1..1
        k = top_scale if t > 0 else 1.0
        v = max(0.0, 1 - abs(t) ** 2)
        return R * (v ** (p * 0.5)) * (k if t > 0 else 1) * (1 if t > -1 + bottom_flat else 0.6)
    return f

def fringe_body(name, prof, H, bands, colors, matrix=Matrix.Identity(4), seg=28, flare=0.13,
                tooth=0.10, sx=1.0, sy=1.0, core_col=None, z_from=0.0, z_to=None, jitter=0.25,
                seed=1, overlap=0.35, rings_core=8, open_top=False, seg_core=20):
    """Stacked crepe-paper fringe bands around a revolved core along local +Z.
    Returns list of objects (already transformed to world by `matrix`).
    bands go from top (index 0) to bottom; colors cycles."""
    rnd = random.Random(seed)
    z_to = H if z_to is None else z_to
    objs = []
    # core (watertight, slightly inset)
    bm = bmesh.new(); rings = []
    zs = [z_from + (z_to - z_from) * i / rings_core for i in range(rings_core + 1)]
    zs = [0.0] + zs + [H] if z_from > 0 or z_to < H else zs
    zs = sorted(set([0.0] + [H * i / rings_core for i in range(rings_core + 1)]))
    sc = seg_core
    for z in zs:
        r = max(prof(z) * 0.94, 0.0)
        rings.append([bm.verts.new((r * sx * math.cos(2*math.pi*j/sc), r * sy * math.sin(2*math.pi*j/sc), z)) for j in range(sc)])
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i+1]
        for j in range(sc): bm.faces.new((a[j], a[(j+1) % sc], b[(j+1) % sc], b[j]))
    bot = bm.verts.new((0, 0, 0)); topv = bm.verts.new((0, 0, H))
    for j in range(sc):
        bm.faces.new((rings[0][(j+1) % sc], rings[0][j], bot)); bm.faces.new((rings[-1][j], rings[-1][(j+1) % sc], topv))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    core = bm_to_obj(bm, name + "_core"); paint(core, core_col or colors[0]); objs.append(core)
    # bands
    span = (z_to - z_from) / bands
    n2 = seg * 2
    for b in range(bands):
        zt = z_to - b * span + span * overlap * (0 if b == 0 else 1)
        zb = z_to - (b + 1) * span
        zm = (zt + zb) / 2
        bm = bmesh.new(); rows = []
        phase = rnd.random() * math.pi * 2 / n2
        for ri, (z, fl) in enumerate(((zt, 0.97), (zb, 1 + flare))):
            row = []
            for j in range(n2):
                a = 2 * math.pi * j / n2 + phase
                zz = z; rr = prof(max(min(z, H), 0)) * fl
                if ri == 1:
                    if j % 2 == 0:
                        zz = z - tooth * (1 + rnd.uniform(-jitter, jitter))
                        rr *= 1 + rnd.uniform(0, 0.05)
                    else:
                        zz = z + tooth * 0.35
                row.append(bm.verts.new((rr * sx * math.cos(a), rr * sy * math.sin(a), zz)))
            rows.append(row)
        for i in range(1):
            a_, b_ = rows[i], rows[i+1]
            for j in range(n2): bm.faces.new((b_[j], b_[(j+1) % n2], a_[(j+1) % n2], a_[j]))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        # make normals point outward
        o = bm_to_obj(bm, f"{name}_band{b}")
        me = o.data
        c = Vector((0, 0, zm))
        f0 = me.polygons[0]
        if (f0.center - Vector((0, 0, f0.center.z))).dot(f0.normal) < 0: me.flip_normals()
        paint(o, colors[b % len(colors)]); objs.append(o)
    for o in objs:
        o.data.transform(matrix)
    return objs

def tassels(name, origin, direction, n=5, length=1.2, width=.12, colors=("fiesta_pink",), spread=0.5, seed=3, sag=0.4):
    """Hanging paper streamers from a point (piñata tips)."""
    rnd = random.Random(seed); out = []
    o = Vector(origin); d = Vector(direction).normalized()
    for i in range(n):
        ang = 2 * math.pi * i / n + rnd.random() * .5
        side = Vector((math.cos(ang), math.sin(ang), 0)) * spread
        pts = []
        for k in range(6):
            t = k / 5
            p = o + d * length * t * 0.6 + side * t * 0.5 + Vector((0, 0, -sag * t * t * length - length * 0.5 * t))
            p += Vector((math.sin(t * 6 + i) * 0.05, math.cos(t * 5 + i) * 0.05, 0))
            pts.append(p)
        nrm = side.cross(Vector((0, 0, 1))) if side.length > 1e-4 else Vector((1, 0, 0))
        out.append(ribbon(f"{name}_tas{i}", pts, width=width, normal=nrm.normalized(), col=colors[i % len(colors)]))
    return out

# ---------------------------------------------------------------- face features
def surface_hit(objs, origin, direction):
    bpy.context.view_layer.update()
    best = None
    for o in objs:
        bm = bmesh.new(); bm.from_mesh(o.data); bm.transform(o.matrix_world)
        tree = BVHTree.FromBMesh(bm); bm.free()
        hit = tree.ray_cast(Vector(origin), Vector(direction).normalized())
        if hit[0] is not None and (best is None or hit[3] < best[3]): best = hit
    return best

def orient_to(obj, normal, up=(0, 0, 1)):
    n = Vector(normal).normalized()
    q = n.to_track_quat('Z', 'Y')
    obj.rotation_mode = 'QUATERNION'; obj.rotation_quaternion = q

def cute_eye(name, objs, origin, direction, size=.35, style="round", look=(0, 0), push=0.02, iris=None, lid=None, lid_roll=0):
    """Big glossy cartoon eye stuck on the surface hit by a ray. Returns objects."""
    hit = surface_hit(objs, origin, direction)
    if hit is None: raise RuntimeError("eye ray missed " + name)
    p, nrm = hit[0], hit[1]
    if nrm.dot(Vector(direction)) > 0: nrm = -nrm
    nrm = (nrm * 0.5 + (-Vector(direction).normalized()) * 0.5).normalized()
    out = []
    def place(o, off, local=(0, 0)):
        # local offset in the tangent plane
        t1 = nrm.cross(Vector((0, 0, 1))).normalized(); t2 = t1.cross(nrm).normalized()
        o.location = p + nrm * off + t1 * local[0] * size + t2 * local[1] * size
        orient_to(o, nrm)
    if style in ("round", "fierce", "sleepy", "smug"):
        if iris:
            w = sphere(name + "_white", (size * .95, size * 1.1, size * .35), col="eye_white", seg=16, ring=8); place(w, push)
            ir = sphere(name + "_iris", (size * .62, size * .72, size * .25), col=iris, seg=14, ring=7); place(ir, push + size * .18, (look[0] * .25, look[1] * .25))
            pu = sphere(name + "_pupil", (size * .36, size * .44, size * .2), col="ink", seg=12, ring=6); place(pu, push + size * .26, (look[0] * .3, look[1] * .3))
            out += [w, ir, pu]
        else:
            pu = sphere(name + "_pupil", (size * .78, size * .95, size * .32), col="ink", seg=16, ring=8); place(pu, push, look)
            out.append(pu)
        h1 = sphere(name + "_hl1", (size * .28, size * .28, size * .12), col="eye_white", seg=10, ring=6); place(h1, push + size * .3, (look[0] - .28, look[1] + .33))
        h2 = sphere(name + "_hl2", (size * .13, size * .13, size * .08), col="eye_white", seg=8, ring=5); place(h2, push + size * .3, (look[0] + .25, look[1] - .3))
        out += [h1, h2]
        if style in ("sleepy", "smug", "fierce") or lid:
            lc = lid or "ink"
            # eyelid: half-disc cap over top of the eye
            ld = sphere(name + "_lid", (size * 1.02, size * 1.15, size * .4), col=lc, seg=16, ring=8)
            bm = bmesh.new(); bm.from_mesh(ld.data)
            cut = .15 if style == "sleepy" else (.45 if style == "smug" else .55)
            bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, size * 1.15 * cut, 0), plane_no=(0, -1, 0), clear_outer=True)
            bmesh.ops.contextual_create(bm, geom=[e for e in bm.edges if e.is_boundary])
            bm.to_mesh(ld.data); bm.free(); paint(ld, lc)
            place(ld, push + size * .05)
            if lid_roll:
                from mathutils import Quaternion
                ld.rotation_quaternion = ld.rotation_quaternion @ Quaternion((0, 0, 1), math.radians(lid_roll))
            out.append(ld)
    return out, p, nrm

def smile(name, objs, origin, direction, width=.35, height=.12, r=.045, col="ink", push=0.03, open_mouth=False):
    hit = surface_hit(objs, origin, direction)
    p, nrm = hit[0], hit[1]
    if nrm.dot(Vector(direction)) > 0: nrm = -nrm
    t1 = nrm.cross(Vector((0, 0, 1))).normalized(); t2 = t1.cross(nrm).normalized()
    pts = []
    for i in range(9):
        u = -1 + 2 * i / 8
        hh = height * (1.7 if open_mouth else 1)
        pts.append(p + nrm * push + t1 * u * width / 2 + t2 * (-(1 - u * u) * hh + hh * .3))
    out = []
    if open_mouth:
        # filled D-shaped mouth
        bm = bmesh.new()
        vs = [bm.verts.new(pt + nrm * 0.0) for pt in pts]
        bm.faces.new(vs)
        o = bm_to_obj(bm, name + "_mouth")
        m = o.modifiers.new("s", 'SOLIDIFY'); m.thickness = .04; m.offset = 1; apply_mods(o)
        paint(o, col); out.append(o)
        tg = sphere(name + "_tongue", (width * .22, width * .16, .03), col="tongue", seg=10, ring=6)
        tg.location = p + nrm * (push + .035) + t2 * (-height * 1.0); orient_to(tg, nrm); out.append(tg)
    else:
        out.append(tube(name + "_smile", pts, radius=r, col=col, seg=6))
    return out

def blush(name, objs, origin, direction, size=.12, push=.02):
    hit = surface_hit(objs, origin, direction)
    if not hit[0]: return []
    p, nrm = hit[0], hit[1]
    if nrm.dot(Vector(direction)) > 0: nrm = -nrm
    o = sphere(name, (size * 1.3, size * .8, size * .25), col="blush", seg=10, ring=6)
    o.location = p + nrm * push; orient_to(o, nrm); return [o]

# ---------------------------------------------------------------- finalize / export
def join(objs, name):
    objs = [o for o in objs if o is not None]
    for o in bpy.context.selected_objects: o.select_set(False)
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.view_layer.objects.active; o.name = name; o.data.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return o

def smooth(o, angle=40):
    for p in o.data.polygons: p.use_smooth = True
    bpy.context.view_layer.objects.active = o
    for x in bpy.context.selected_objects: x.select_set(False)
    o.select_set(True)
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))
    except Exception:
        o.data.use_auto_smooth = True; o.data.auto_smooth_angle = math.radians(angle)
    return o

def base_origin(objs, keep_xy=False):
    """Move all objs so combined bbox base-center sits at world origin; set origins there."""
    mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
    for o in objs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co
            mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
    off = Vector((0, 0, mn.z)) if keep_xy else Vector(((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, mn.z))
    for o in objs:
        o.data.transform(o.matrix_world); o.matrix_world = Matrix.Identity(4)
        o.data.transform(Matrix.Translation(-off))
    return mx - mn

def tri_count(o):
    return sum(len(p.vertices) - 2 for p in o.data.polygons)

def material_palette(name="M_Palette", emissive=None):
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; bsdf = nt.nodes["Principled BSDF"]
    def img(nm, cs):
        im = bpy.data.images.get(nm)
        if im is None:
            im = bpy.data.images.load(f"{TEX}/{nm}.png"); im.name = nm
        im.colorspace_settings.name = cs
        n = nt.nodes.new("ShaderNodeTexImage"); n.image = im; n.interpolation = 'Closest'; return n
    c = img("palette_color", "sRGB"); r = img("palette_roughness", "Non-Color"); me = img("palette_metalness", "Non-Color")
    nt.links.new(c.outputs[0], bsdf.inputs["Base Color"])
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(r.outputs[0], bsdf.inputs["Roughness"]); nt.links.new(me.outputs[0], bsdf.inputs["Metallic"])
    bsdf.inputs["Specular IOR Level"].default_value = 0.55
    bsdf.inputs["Coat Weight"].default_value = 0.15; bsdf.inputs["Coat Roughness"].default_value = 0.25
    # fase 3: crepe-paper fuzz (render only; Roblox uses the palette maps)
    bsdf.inputs["Sheen Weight"].default_value = 0.35; bsdf.inputs["Sheen Roughness"].default_value = 0.45
    if emissive:
        nt.links.new(c.outputs[0], bsdf.inputs["Emission Color"]); bsdf.inputs["Emission Strength"].default_value = emissive
    return m

def assign_mat(o, m):
    o.data.materials.clear(); o.data.materials.append(m); return o

def export(objs, name, sub=""):
    d = os.path.join(EXP, sub); os.makedirs(d, exist_ok=True)
    for x in bpy.context.selected_objects: x.select_set(False)
    for o in objs: o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.fbx(filepath=f"{d}/{name}.fbx", use_selection=True, object_types={'MESH'},
        apply_unit_scale=False, apply_scale_options='FBX_SCALE_ALL', global_scale=1.0,
        axis_forward='-Z', axis_up='Y', use_mesh_modifiers=True, mesh_smooth_type='FACE',
        colors_type='SRGB', path_mode='RELATIVE', embed_textures=False, add_leaf_bones=False, bake_anim=False)
    bpy.ops.wm.obj_export(filepath=f"{d}/{name}.obj", export_selected_objects=True, forward_axis='NEGATIVE_Z',
        up_axis='Y', global_scale=1.0, export_materials=True, export_colors=True, path_mode='RELATIVE',
        export_uv=True, export_normals=True)
    info = {o.name: tri_count(o) for o in objs}
    return info

# ---------------------------------------------------------------- render
def setup_render(res=(1200, 1200), samples=64):
    s = bpy.context.scene
    s.render.engine = 'CYCLES'; s.cycles.device = 'CPU'; s.cycles.samples = samples
    s.cycles.use_denoising = True
    try: s.cycles.denoiser = 'OPENIMAGEDENOISE'
    except Exception: pass
    s.cycles.max_bounces = 6; s.cycles.diffuse_bounces = 3; s.cycles.glossy_bounces = 3; s.cycles.transmission_bounces = 4
    s.render.resolution_x, s.render.resolution_y = res; s.render.resolution_percentage = 100
    s.render.film_transparent = False
    s.view_settings.view_transform = 'Standard'
    s.view_settings.look = 'None'; s.view_settings.exposure = 0.0
    s.render.image_settings.file_format = 'PNG'
    s.render.threads_mode = 'FIXED'; s.render.threads = 8
    return s

def backdrop(color_top="#5BC8FF", color_floor="#8FDCFF", size=60, light_center=(0, 0), rot_z=0.0):
    """Seamless sweep backdrop with a radial gradient shader (thumbnail look)."""
    bpy.ops.mesh.primitive_plane_add(size=1)
    p = bpy.context.object; p.name = "Backdrop"
    bm = bmesh.new(); W = size; rows = []
    # profile: floor from y=-W..0 at z=0, then curve up to wall
    prof = []
    for i in range(12): prof.append((-W + (W) * i / 11 * 0.999, 0))
    R = W * 0.25
    for i in range(1, 12):
        a = math.pi / 2 * i / 11
        prof.append((R * math.sin(a), R * (1 - math.cos(a))))
    for i in range(1, 6): prof.append((R, R + W * 0.5 * i / 5))
    for (y, z) in prof:
        rows.append([bm.verts.new((x, y, z)) for x in (-W, -W/2, 0, W/2, W)])
    for i in range(len(rows) - 1):
        for j in range(4): bm.faces.new((rows[i][j], rows[i][j+1], rows[i+1][j+1], rows[i+1][j]))
    bm.to_mesh(p.data); bm.free()
    for f in p.data.polygons: f.use_smooth = True
    m = bpy.data.materials.new("M_Backdrop"); m.use_nodes = True; nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]; bsdf.inputs["Roughness"].default_value = 0.9
    tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Object"], sep.inputs[0])
    mr = nt.nodes.new("ShaderNodeMapRange"); mr.inputs[1].default_value = 0; mr.inputs[2].default_value = R * 1.6
    nt.links.new(sep.outputs[2], mr.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*hex2lin(color_floor), 1); ramp.color_ramp.elements[1].color = (*hex2lin(color_top), 1)
    nt.links.new(mr.outputs[0], ramp.inputs[0]); nt.links.new(ramp.outputs[0], bsdf.inputs["Base Color"])
    p.data.materials.append(m)
    p.is_shadow_catcher = False
    p.rotation_euler.z = math.radians(rot_z)
    return p

def lights(key=1300, rim=900, fill=160, key_col="#FFF1DC", rim_col="#FFFFFF", scale=1.0, center=(0, 0, 1.5)):
    out = []
    def area(name, loc, energy, size, col):
        ld = bpy.data.lights.new(name, 'AREA'); ld.energy = energy * scale * scale; ld.size = size * scale; ld.color = hex2srgb(col)
        o = bpy.data.objects.new(name, ld); link(o); o.location = Vector(loc) * scale
        d = Vector(center) - o.location; o.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler(); out.append(o)
    area("Key", (-5, -6, 7), key, 4, key_col)
    area("Rim", (6, 5, 6), rim, 3, rim_col)
    area("Fill", (6, -5, 2.5), fill, 6, "#DDEBFF")
    w = bpy.data.worlds.new("W"); bpy.context.scene.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (*hex2lin("#BFE6FF"), 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    return out

def camera_fit(objs, az=35, el=16, lens=55, margin=1.12, target_z_frac=0.48, aspect=1.0):
    mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
    for o in objs:
        for v in o.data.vertices:
            w = o.matrix_world @ v.co; mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
    c = (mn + mx) / 2; c.z = mn.z + (mx.z - mn.z) * target_z_frac
    rad = (mx - mn).length / 2
    cd = bpy.data.cameras.new("Cam"); cd.lens = lens; cam = bpy.data.objects.new("Cam", cd); link(cam)
    fov = 2 * math.atan(36 / 2 / lens) if aspect >= 1 else 2 * math.atan(36 * aspect / 2 / lens)
    dist = rad * margin / math.sin(fov / 2)
    a, e = math.radians(az), math.radians(el)
    # camera looks from -Y side (front of creature faces -Y)
    cam.location = c + Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e))) * dist
    cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = cam
    return cam, c, rad

def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
