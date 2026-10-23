"""Temporada Meme 1: 6 ORIGINAL piñatas that riff on Oct-2026 trends (see plan/TRENDS_MEMES.md).
Same pipeline/look as creatures.py (crepe-paper fringe, palette atlas, faces face -Y).
CLI: blender -b --factory-startup -P memes.py -- [name ...]   (no args = all)
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
import creatures as C
from creatures import M, cone_prof, ellip_prof, lin_prof, limb, face
from plib import *
from props import text_mesh
from mathutils import Vector, Matrix, Euler

def V(*a): return Vector(a)

# ------------------------------------------------------------------ shared bits
def glove(name, wrist, direction, s=1.0, col="eye_white", palm_up=False, spread=1.0, cuff=None, curl=()):
    """Cartoon 4-finger glove. direction = from wrist towards fingertips."""
    d = Vector(direction).normalized()
    side = d.cross(V(0, 0, 1)); side = side.normalized() if side.length > 1e-3 else V(1, 0, 0)
    up = side.cross(d).normalized()
    if palm_up: up = -up; side = -side
    w = Vector(wrist); P = []
    palm = w + d * .38 * s
    o = sphere(name + "palm", (.36 * s, .3 * s, .17 * s), col=col, seg=14, ring=8)
    o.matrix_world = Matrix.Translation(palm) @ Matrix((side, d, up)).transposed().to_4x4(); P.append(o)
    for k in range(4):
        u = (k - 1.5) * .17 * s * spread
        base = palm + side * u + d * .22 * s
        tip = base + d * (.34 - .05 * abs(k - 1.5)) * s + side * u * .3
        if k in curl: tip = base + d * .08 * s - up * .14 * s
        P.append(tube(name + f"fg{k}", [base, base.lerp(tip, .5) + up * .03 * s, tip], radius=.085 * s, col=col, seg=8, taper=[1, 1, .9]))
        P.append(sphere(name + f"ft{k}", (.085 * s,) * 3, loc=tip, col=col, seg=8, ring=6))
    tb = palm + side * .3 * s + up * .05 * s
    P.append(tube(name + "th", [tb, tb + side * .18 * s + d * .12 * s + up * .1 * s], radius=.09 * s, col=col, seg=8))
    P.append(sphere(name + "tht", (.09 * s,) * 3, loc=tb + side * .18 * s + d * .12 * s + up * .1 * s, col=col, seg=8, ring=6))
    if cuff:
        t_ = torus(name + "cuff", .2 * s, .08 * s, col=cuff, seg=14, mseg=6); t_.matrix_world = M(w + d * .05 * s, d); P.append(t_)
    return P

def gold_chain(name, pts, link=.13, col="gold"):
    """Chunky cuban-style chain along a polyline."""
    P = []; pts = [Vector(p) for p in pts]
    L = [0.0]
    for i in range(1, len(pts)): L.append(L[-1] + (pts[i] - pts[i - 1]).length)
    n = int(L[-1] / (link * 1.55))
    for k in range(n + 1):
        t = L[-1] * k / max(n, 1); i = max(1, min(len(pts) - 1, next((j for j in range(1, len(pts)) if L[j] >= t), len(pts) - 1)))
        u = (t - L[i - 1]) / max(L[i] - L[i - 1], 1e-6); p = pts[i - 1].lerp(pts[i], u); d = (pts[i] - pts[i - 1]).normalized()
        o = torus(name + f"{k}", link, link * .38, col=col, seg=10, mseg=4)
        o.matrix_world = M(p, d.cross(V(0, 0, 1)) if k % 2 else d.cross(d.cross(V(0, 0, 1))), roll=0) @ Matrix.Diagonal((1, .62, 1, 1))
        P.append(o)
    return P

def bake(o):
    return bake_xform(o)

def stripe_paint(o, cols, band=.32, axis=2, cut=True):
    """Cut a mesh into horizontal bands and paint them alternately (crepe-paper stripes)."""
    bake(o)
    if cut:
        bm = bmesh.new(); bm.from_mesh(o.data)
        zs = [v.co[axis] for v in bm.verts]; z = min(zs) + band
        while z < max(zs):
            no = [0, 0, 0]; no[axis] = 1; co = [0, 0, 0]; co[axis] = z
            bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=co, plane_no=no)
            z += band
        bm.to_mesh(o.data); bm.free()
    me = o.data
    if not me.uv_layers: me.uv_layers.new(name="UVMap")
    uv = me.uv_layers[0].data
    ca = me.color_attributes.get("Col") or me.color_attributes.new("Col", 'BYTE_COLOR', 'CORNER')
    z0 = min(v.co[axis] for v in me.vertices)
    for p in me.polygons:
        c = cols[int((p.center[axis] - z0) / band) % len(cols)]
        u = cell_uv(c); lin = hex2lin(PALETTE[PIDX[c]][1])
        for li in p.loop_indices: uv[li].uv = u; ca.data[li].color = (*lin, 1)
    return o

def sign_board(name, lines, w, h, loc, rot_z=0, board="ink", ink="eye_white", rim="gold", th=.12):
    """Small placard with text lines [(text, size, dz)], facing -Y; returns parts."""
    P = []
    Mw = Matrix.Translation(loc) @ Matrix.Rotation(math.radians(rot_z), 4, 'Z')
    b = box(name + "b", (w, th, h), col=board, bevel=.04); b.matrix_world = Mw; P.append(b)
    r = box(name + "r", (w + .12, th * .8, h + .12), col=rim, bevel=.04); r.matrix_world = Mw @ Matrix.Translation((0, th * .3, 0)); P.append(r)
    for i, (txt, size, dz) in enumerate(lines):
        t = text_mesh(f"{name}t{i}", txt, size=size, extrude=.025, col=ink, rot=(90, 0, 0), bevel=0, res=4)
        t.matrix_world = Mw @ Matrix.Translation((0, -th / 2 - .03, dz)) @ Matrix.Rotation(math.radians(90), 4, 'X'); P.append(t)
    return P

def shoe(name, loc, col="eye_white", sole="fiesta_pink", s=1.0, yaw=0):
    x, y, z = loc
    return [sphere(name, (.3 * s, .42 * s, .2 * s), loc=(x, y - .06 * s, z + .16 * s), rot=(0, 0, yaw), col=col, seg=14, ring=8),
            cyl(name + "s", .3 * s, .31 * s, .08 * s, loc=(x, y - .06 * s, z), col=sole, seg=14)]

# ======================================================================= 1. LOS GEMELOS PUPUSA (secret)
def pupusa_twin(cx, tilt, cap_col, cap_side, shoe_col, seed, arm_over):
    P = []; R = 1.15; T = .78; cz = 1.95
    Mb = Matrix.Translation((cx, 0, 0)) @ Matrix.Rotation(math.radians(tilt), 4, 'Y')
    body = fringe_body(f"pup{seed}", lin_prof(R, R, T, round_end=.35), T, 3, ["mango", "wood", "mango"],
                       matrix=Mb @ M((0, T / 2, cz), (0, -1, 0)), seg=28, flare=.09, tooth=.06, seed=seed, core_col="cream")
    P += body
    w = lambda x, y, z: Mb @ V(x, y, z)
    rnd = random.Random(seed)
    for k in range(9):   # toasted comal spots on the front, away from the face
        a = rnd.uniform(0, 6.28); r = rnd.uniform(.72, .98)
        if -.5 < math.sin(a) < .9 and abs(math.cos(a)) < .5: continue
        P.append(sphere(f"spot{seed}{k}", (.13 * rnd.uniform(.7, 1.3), .03, .1), loc=w(r * math.cos(a), -T / 2 - .01, cz + r * math.sin(a)), col="wood_dark", seg=8, ring=5))
    for k in range(4):   # melted cheese oozing at the rim
        a = math.radians(-60 - 20 * k + rnd.uniform(-5, 5))
        P.append(sphere(f"ch{seed}{k}", (.18, .18, .3), loc=w(R * 1.02 * math.cos(a), -.05, cz + R * 1.02 * math.sin(a) - .12), col="white", seg=10, ring=6))
    # flat-brim cap worn sideways
    ctop = w(0, 0, cz + R - .05)
    dome = sphere(f"cap{seed}", (.66, .6, .42), loc=ctop, col=cap_col, seg=18, ring=10)
    bm = bmesh.new(); bm.from_mesh(dome.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, 0), plane_no=(0, 0, -1), clear_outer=True)
    bmesh.ops.contextual_create(bm, geom=[e for e in bm.edges if e.is_boundary]); bm.to_mesh(dome.data); bm.free(); paint(dome, cap_col)
    dome.rotation_euler = (0, math.radians(tilt), 0); P.append(dome)
    P.append(cyl(f"brim{seed}", .5, .5, .07, loc=w(cap_side * .7, -.15, cz + R - .02), rot=(0, tilt, 0), col=cap_col, seg=20))
    P.append(sphere(f"btn{seed}", (.08,) * 3, loc=w(0, 0, cz + R + .38), col="eye_white", seg=8, ring=5))
    # face: confident smug eyes, thick brows, open grin with GOLD GRILLZ, tiny mustache
    fc = w(0, 0, cz + .12)
    P += face(body, f"pf{seed}", fc, size=.24, eye_dx=.38, eye_dz=.2, style="smug", mouth="open", mouth_dz=-.36, mw=.56,
              blush_dx=.68, blush_dz=-.12, lid="wood_dark")
    hit = surface_hit(body, fc + V(0, -8, -.27), (0, 1, 0))
    mp = hit[0] + V(0, -.07, 0)
    for k in range(6):
        u = -.2 + .08 * k
        P.append(box(f"grill{seed}{k}", (.07, .04, .09), loc=mp + V(u, 0, -.02 - .03 * (1 - (u / .25) ** 2)), col="gold", bevel=.012))
    P.append(tube(f"must{seed}", [mp + V(-.2, -.01, .14), mp + V(0, -.03, .1), mp + V(.2, -.01, .14)], radius=.04, col="wood_dark", seg=6))
    for s in (-1, 1):
        P.append(box(f"brow{seed}{s}", (.3, .05, .07), loc=hit[0] + V(s * .38, -.06, .78), rot=(0, s * -8, 0), col="wood_dark", bevel=.02))
    # chunky gold chain + big medallion
    ch = [w(-.95, -T / 2 - .12, cz - .1), w(-.6, -T / 2 - .16, cz - .72), w(0, -T / 2 - .18, cz - .98), w(.6, -T / 2 - .16, cz - .72), w(.95, -T / 2 - .12, cz - .1)]
    P += gold_chain(f"chn{seed}", ch, link=.1)
    P.append(cyl(f"med{seed}", .26, .26, .08, loc=w(0, -T / 2 - .25, cz - 1.22), rot=(90, 0, 0), col="gold", seg=20, bevel=.02))
    P.append(text_mesh(f"medt{seed}", "$", size=.32, extrude=.03, col="gold_deep", loc=w(0, -T / 2 - .31, cz - 1.24), rot=(90, 0, 0), bevel=0, res=3))
    # legs + sneakers
    for s in (-1, 1):
        a = w(s * .42, 0, cz - R + .15); b = w(s * .5, -.05, .35)
        P += limb(f"leg{seed}{s}", a, b, .18, .16, 2, ["wood", "mango"], seed=seed + 3 + s, seg=12)
        P += shoe(f"sh{seed}{s}", (b.x, b.y, 0), col="eye_white", sole=shoe_col, s=1.0)
    # outer arm: peace sign up high; inner arm over the twin's shoulder
    sh_out = w(-cap_side * 1.0, -.1, cz + .2); hand_out = w(-cap_side * 1.75, -.35, cz + 1.1)
    P += limb(f"armo{seed}", sh_out, hand_out, .17, .15, 2, ["mango", "wood"], seed=seed + 7, seg=12)
    dd = (hand_out - sh_out).normalized()
    P += glove(f"go{seed}", hand_out - dd * .42, dd, s=.95, col="eye_white", spread=1.5, cuff="eye_white", curl=(0, 1))
    sh_in = w(cap_side * 1.0, -.05 + arm_over * .25, cz + .45); hand_in = w(cap_side * 1.95, -.15 + arm_over * .5, cz + 1.0)
    P += limb(f"armi{seed}", sh_in, hand_in, .17, .15, 2, ["mango", "wood"], seed=seed + 9, seg=12)
    P.append(sphere(f"gi{seed}", (.27, .27, .22), loc=hand_in, col="eye_white", seg=12, ring=8))
    return P

def gemelos_pupusa():
    """SECRET - two pupusa twins in campy rapper fits (sideways caps, gold chains, grillz) bouncing arm-in-arm.
    Riff on the 'Thank You Baby / Thank You Babeh' LIVE trend (Sep-Oct 2026) + the duo-unit format."""
    P = []
    P += pupusa_twin(-1.3, -7, "fiesta_pink", 1, "fiesta_pink", 31, arm_over=-1)
    P += pupusa_twin(1.3, 7, "turquoise", -1, "turquoise", 47, arm_over=1)
    G = [star_prism(f"spark{i}", 4, .22, .07, .05, loc=loc, rot=(90, 0, 0), col="neon_gold", bevel=0)
         for i, loc in enumerate(((-2.9, -.4, 3.9), (2.8, -.4, 4.1), (0, -.6, 4.3)))]
    return P + G, {"glow": G}

# ======================================================================= 2. FICHADITO (secret)
def fichadito():
    """SECRET - the cutest baby piñata in the game posing for its police mugshot with a hardened-criminal stare.
    Riff on 'How Kids See Us' (teens posting mugshots captioned 'how first graders see us', Sep-Oct 2026)."""
    P = []; G = []
    # height-chart wall behind (instantly reads as 'mugshot')
    P.append(box("wall", (4.4, .14, 4.9), loc=(0, 1.15, 2.45), col="stone", bevel=.05))
    for k in range(10):
        z = .45 + k * .45; wide = k % 2 == 0
        P.append(box(f"ln{k}", (4.0 if wide else 1.0, .04, .05), loc=(0 if wide else -1.5, 1.07, z), col="ink_soft", bevel=0))
    for k, z in enumerate((1.35, 2.25, 3.15, 4.05)):
        t = text_mesh(f"hn{k}", ("3'", "4'", "5'", "6'")[k], size=.28, extrude=.02, col="ink_soft", rot=(90, 0, 0), bevel=0, res=3)
        t.location = (1.85, 1.05, z + .12); P.append(t)
    # chubby baby body + big head
    body = fringe_body("body", ellip_prof(.78, 1.45, p=.8), 1.45, 4, ["sky", "snow", "sky", "snow"], matrix=M((0, 0, .32)), seg=28, flare=.1, tooth=.06, seed=3, sy=.92)
    P += body
    P.append(sphere("diaper", (.8, .74, .42), loc=(0, 0, .55), col="eye_white", seg=20, ring=10))
    P.append(sphere("pin", (.1, .04, .06), loc=(.25, -.72, .72), col="sky", seg=8, ring=5))
    hc = V(0, -.05, 2.55)
    head = fringe_body("head", ellip_prof(1.05, 1.95, p=1.15), 1.95, 5, ["peach", "peach", "bubblegum", "peach", "peach"],
                       matrix=M(hc - V(0, 0, .95)), seg=32, flare=.08, tooth=.06, seed=4, sx=1.1, sy=.98)
    P += head
    # bonnet with frill
    bon = sphere("bonnet", (1.18, 1.05, 1.1), loc=hc + V(0, .22, .12), col="bubblegum", seg=24, ring=12)
    bm = bmesh.new(); bm.from_mesh(bon.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, -.25, 0), plane_no=(0, -1, -.35), clear_outer=True)
    bm.to_mesh(bon.data); bm.free(); paint(bon, "bubblegum"); P.append(bon)
    fr = torus("frill", 1.0, .13, loc=hc + V(0, -.42, .1), rot=(68, 0, 0), col="eye_white", seg=36, mseg=6); P.append(fr)
    P.append(sphere("bow", (.32, .16, .2), loc=hc + V(0, -.05, 1.12), col="fiesta_pink", seg=12, ring=6))
    P.append(tube("curl", [hc + V(0, -.85, .9), hc + V(.12, -.95, 1.08), hc + V(-.05, -1.0, 1.15), hc + V(-.12, -.92, 1.02)], radius=.05, col="wood_dark", seg=6))
    # hardened-criminal face: fierce lids, thick straight brows, pacifier, band-aid
    P += face(head, "f", hc + V(0, 0, .02), size=.27, eye_dx=.42, eye_dz=.12, style="fierce", mouth=None, blush_dx=.7, blush_dz=-.2, lid="peach")
    for s in (-1, 1):
        P.append(box(f"brow{s}", (.48, .08, .12), loc=hc + V(s * .43, -1.0, .52), rot=(0, s * 14, 0), col="wood_dark", bevel=.03))
    mp = surface_hit(head, hc + V(0, -8, -.42), (0, 1, 0))[0]
    P.append(cyl("paci_shield", .34, .34, .1, loc=mp + V(0, -.05, 0), rot=(90, 0, 0), col="turquoise", seg=20, bevel=.03))
    P.append(torus("paci_ring", .22, .055, loc=mp + V(0, -.2, -.02), rot=(90, 0, 0), col="sun_yellow", seg=18, mseg=6))
    bp = surface_hit(head, hc + V(.62, -8, -.08), (0, 1, 0))[0]
    P.append(box("bandaid", (.38, .05, .14), loc=bp + V(0, -.03, 0), rot=(0, 25, 0), col="cream", bevel=.02))
    for s in (-1, 1):
        P.append(box(f"bx{s}", (.12, .06, .02), loc=bp + V(0, -.05, 0), rot=(0, 25 + s * 45, 0), col="wood", bevel=0))
    # mugshot placard held at the chest
    P += sign_board("plac", [("FICHADO", .34, .14), ("No. 000001", .17, -.2)], 2.2, .82, (0, -.95, 1.32), board="ink", ink="eye_white", rim="stone_dark")
    for s in (-1, 1):
        sh = V(s * .62, -.35, 1.45); hd = V(s * 1.05, -.98, 1.32)
        P += limb(f"arm{s}", sh, hd, .2, .17, 2, ["sky", "snow"], seed=10 + s, seg=12)
        P.append(sphere(f"hand{s}", (.2, .17, .2), loc=hd + V(0, -.1, 0), col="peach", seg=12, ring=8))
        P += limb(f"leg{s}", V(s * .38, 0, .5), V(s * .48, -.15, .12), .2, .19, 2, ["sky", "snow"], seed=20 + s, seg=12)
        P.append(sphere(f"foot{s}", (.24, .32, .16), loc=(s * .5, -.25, .12), col="peach", seg=12, ring=8))
    # camera flash going off (neon)
    G.append(star_prism("flash", 8, .55, .2, .06, loc=(-1.55, 1.0, 4.3), rot=(90, 0, 0), col="neon_gold", bevel=0))
    G.append(sphere("flashc", (.2, .06, .2), loc=(-1.55, .95, 4.3), col="neon_gold", seg=10, ring=5))
    return P + G, {"glow": G}

# ======================================================================= 3. MICHI APLAUSOS (legendary)
def michi_aplausos():
    """LEGENDARY - black cat piñata with weirdly human white-gloved hands and a too-human grin, slow-clapping.
    Riff on 'Black Cat Clapping' (AI cat green-screen reaction, Sep 2026)."""
    P = []
    cols = ["ink", "ink_soft", "ink", "ink", "ink_soft", "ink"]
    body = fringe_body("body", ellip_prof(.95, 2.0, p=.75), 2.0, 6, cols, matrix=M((0, .05, .05)), seg=30, flare=.1, tooth=.07, seed=55, sy=.92)
    P += body
    hc = V(0, -.05, 2.6)
    head = fringe_body("head", ellip_prof(1.05, 1.8, p=1.25), 1.8, 5, ["ink", "ink_soft", "ink", "ink", "ink_soft"],
                       matrix=M(hc - V(0, 0, .88)), seg=32, flare=.09, tooth=.065, seed=56, sx=1.14, sy=.95)
    P += head
    for s in (-1, 1):
        base = hc + V(.58 * s, .05, .62)
        P += fringe_body(f"ear{s}", cone_prof(.38, .85), .85, 3, ["ink", "ink_soft", "ink"], matrix=M(base, (.35 * s, 0, 1)), seg=14, flare=.1, tooth=.05, seed=60 + s, sy=.45)
        P.append(sphere(f"earin{s}", (.15, .05, .28), loc=base + V(.1 * s, -.16, .25), rot=(0, 20 * s, 0), col="bubblegum", seg=10, ring=6))
        for k in (-1, 0, 1):
            a0 = hc + V(.42 * s, -1.0, -.3 + .06 * k)
            P.append(tube(f"wh{s}{k}", [a0, a0 + V(.35 * s, -.02, .04 * k), a0 + V(.7 * s, .06, .1 * k)], radius=.018, col="snow", seg=5))
    # half-lidded unimpressed eyes, golden iris
    P += face(head, "f", hc + V(0, 0, .12), size=.29, eye_dx=.44, eye_dz=.12, style="smug", mouth=None, iris="mango", blush_dx=0, lid="ink_soft")
    # the unsettling human grin: wide white teeth band with gaps + pink gums
    mp = surface_hit(head, hc + V(0, -8, -.36), (0, 1, 0))[0]
    gum = sphere("gum", (.62, .08, .2), loc=mp + V(0, -.03, -.02), col="tongue", seg=20, ring=8); P.append(gum)
    for k in range(10):
        u = -.5 + k * (1.0 / 9)
        P.append(box(f"tooth{k}", (.085, .08, .16 - .05 * abs(u) * 2), loc=mp + V(u * 1.0, -.1 + .12 * u * u, -.01 + .1 * u * u), col="eye_white", bevel=.02))
    P.append(sphere("nose", (.11, .07, .07), loc=mp + V(0, -.05, .3), col="fiesta_pink", seg=10, ring=6))
    # arms forward to the HUMAN hands, mid-clap in front of the chest
    for s in (-1, 1):
        sh = V(.72 * s, -.35, 1.55); wr = V(.32 * s, -1.35, 1.75)
        P += limb(f"arm{s}", sh, wr, .24, .2, 3, ["ink", "ink_soft", "ink"], seed=70 + s, seg=14)
        P += glove(f"gl{s}", wr, (-.25 * s, -.35, .55), s=1.05, col="eye_white", cuff="eye_white", palm_up=(s > 0))
        P.append(sphere(f"paw{s}", (.32, .32, .22), loc=(.42 * s, -.72, .2), col="ink_soft", seg=14, ring=8))
    tp = [(.5, .6, .3), (1.15, .85, .4), (1.5, .75, .95), (1.4, .6, 1.5), (1.05, .55, 1.72), (.9, .55, 1.5)]
    P += striped_tube("tail", tp, .2, ["ink", "ink_soft", "ink", "ink_soft", "ink", "grape"], seg=12, taper=lambda t: 1 - .35 * t)
    P.append(torus("collar", .9, .09, loc=hc + V(0, .02, -.95), col="gold", seg=28, mseg=8))
    P.append(sphere("bell", (.15, .15, .15), loc=hc + V(0, -.9, -1.03), col="gold", seg=12, ring=8))
    G = []
    for s in (-1, 1):   # little 'clap' impact lines
        for k in range(3):
            a = math.radians(60 + 30 * k)
            p0 = V(0, -1.95, 2.35) + V(s * .45 * math.cos(a), 0, .45 * math.sin(a) - .2)
            G.append(tube(f"cl{s}{k}", [p0, p0 + V(s * .28 * math.cos(a), 0, .28 * math.sin(a))], radius=.04, col="neon_gold", seg=5))
    return P + G, {"glow": G}

# ======================================================================= 4. MAPACHE NEL (mythic)
def mapache_nel():
    """MYTHIC - raccoon piñata charging broom-first, yelling '¡NEL!'. Your base's only security guard.
    Riff on the 'Hell Nah Cuh' raccoon-with-broom mashup (viral since Sep 23 2026)."""
    P = []; G = []; lean = 14
    Lm = Matrix.Rotation(math.radians(-lean), 4, 'X')   # lean forward (towards -Y)
    w = lambda x, y, z: Lm @ V(x, y, z)
    body = fringe_body("body", ellip_prof(1.0, 2.2, p=.8), 2.2, 6, ["donkey_grey", "donkey_dark", "donkey_grey", "donkey_grey", "donkey_dark", "donkey_grey"],
                       matrix=Lm @ M((0, .1, .35)), seg=30, flare=.1, tooth=.07, seed=81, sy=.9)
    P += body
    P.append(sphere("belly", (.66, .3, .8), loc=w(0, -.72, 1.35), rot=(-lean, 0, 0), col="snow", seg=16, ring=10))
    hc = w(0, -.2, 3.25)
    head = fringe_body("head", ellip_prof(1.0, 1.7, p=1.2), 1.7, 5, ["donkey_grey", "donkey_grey", "snow", "donkey_grey", "donkey_dark"],
                       matrix=Lm @ M(V(0, -.2, 3.25) - V(0, 0, .85)), seg=32, flare=.09, tooth=.06, seed=82, sx=1.2, sy=.95)
    P += head
    # snout + bandit mask
    P += fringe_body("snout", cone_prof(.42, .75), .75, 2, ["snow", "snow"], matrix=M(hc + w(0, -.7, -.38), Lm.to_3x3() @ V(0, -1, -.1)), seg=16, flare=.08, tooth=.04, seed=83)
    P.append(sphere("nose", (.14, .1, .1), loc=hc + w(0, -1.42, -.45), col="ink", seg=10, ring=6))
    for s in (-1, 1):
        mk = surface_hit(head, hc + w(s * .42, -8, .12), Lm.to_3x3() @ V(0, 1, 0))
        o = sphere(f"mask{s}", (.42, .5, .1), col="ink", seg=16, ring=8); o.location = mk[0] + mk[1] * .01; orient_to(o, mk[1]); P.append(o)
        base = hc + w(.62 * s, .05, .55)
        P += fringe_body(f"ear{s}", cone_prof(.32, .62), .62, 2, ["donkey_dark", "snow"], matrix=M(base, w(.4 * s, 0, 1)), seg=12, flare=.1, tooth=.05, seed=84 + s, sy=.5)
    # yelling: fierce eyes on the mask, wide-open mouth with tongue + 2 buck teeth
    eyes = []
    for s in (-1, 1):
        e, _, _ = cute_eye(f"eye{s}", head, hc + w(s * .42, -12, .12), Lm.to_3x3() @ V(0, 1, 0), size=.28, style="fierce", iris="sun_yellow", lid="donkey_dark", push=.07)
        eyes += e
    P += eyes
    mp = hc + w(0, -1.12, -.78)
    mo = sphere("mouth", (.42, .2, .34), loc=mp, rot=(-lean - 20, 0, 0), col="ink", seg=16, ring=8); P.append(mo)
    P.append(sphere("tongue", (.26, .14, .14), loc=mp + w(0, -.08, -.14), col="tongue", seg=12, ring=6))
    for s in (-1, 1):
        P.append(box(f"tooth{s}", (.12, .06, .14), loc=mp + w(s * .08, -.12, .22), rot=(-lean, 0, 0), col="eye_white", bevel=.02))
    for s in (-1, 1):
        P.append(box(f"brow{s}", (.42, .07, .1), loc=hc + w(s * .4, -1.02, .55), rot=(-lean, s * 22, 0), col="ink", bevel=.03))
    # broom held like a lance
    a = V(.9, .9, 3.0); b = V(-.25, -2.6, .75)
    P.append(tube("stick", [a, b], radius=.09, col="wood", seg=8))
    d = (b - a).normalized()
    P.append(torus("tie", .26, .07, col="candy_red", seg=14, mseg=5)); P[-1].matrix_world = M(b + d * .05, d)
    P += fringe_body("bristles", lambda z: .24 + .32 * (z / 1.1) ** .8, 1.1, 3, ["mango", "wood", "mango"], matrix=M(b, d), seg=18, flare=.18, tooth=.12, seed=85)
    for s, t in ((-1, .38), (1, .62)):
        hp = a.lerp(b, t); sh = w(.75 * s, -.25, 2.25)
        P += limb(f"arm{s}", sh, hp, .22, .19, 2, ["donkey_grey", "donkey_dark"], seed=86 + s, seg=12)
        P.append(sphere(f"hand{s}", (.24, .24, .24), loc=hp, col="ink", seg=12, ring=8))
    # legs mid-stride + striped bushy tail
    P += limb("legL", w(-.45, 0, .55), V(-.55, -.85, .2), .26, .22, 2, ["donkey_grey", "donkey_dark"], seed=88, seg=12)
    P += limb("legR", w(.45, 0, .55), V(.55, .75, .25), .26, .22, 2, ["donkey_grey", "donkey_dark"], seed=89, seg=12)
    P.append(sphere("footL", (.3, .42, .18), loc=(-.55, -1.0, .16), col="ink", seg=12, ring=8))
    P.append(sphere("footR", (.3, .42, .18), loc=(.55, .85, .2), rot=(30, 0, 0), col="ink", seg=12, ring=8))
    tp = [w(0, .8, .9), (0, 1.7, 1.1), (.2, 2.4, 1.7), (.1, 2.7, 2.5), (-.15, 2.6, 3.0)]
    P += striped_tube("tail", tp, .42, ["donkey_grey", "ink", "donkey_grey", "ink", "donkey_grey", "ink"], seg=14, taper=lambda t: 1 - .3 * t + .2 * math.sin(math.pi * t))
    # speech bubble '¡NEL!' with neon rim
    bc = V(1.75, -.6, 5.0)
    Mb = Matrix.Translation(bc) @ Matrix.Rotation(math.radians(90), 4, 'X') @ Matrix.Rotation(math.radians(-6), 4, 'Z')
    from lobby import rrect
    pts = rrect(2.5, 1.25, .6)
    bub = slab("bubble", pts, thick=.18, col="eye_white", bevel=.05, matrix=Mb); P.append(bub)
    P.append(slab("btail", [(-.55, -.55), (-.1, -.55), (-.85, -1.15)], thick=.18, col="eye_white", bevel=.03, matrix=Mb))
    G.append(tube("brim", [Mb @ V(x, y, .14) for x, y in pts + [pts[0]]], radius=.05, col="neon_pink", seg=6))
    t = text_mesh("btxt", "¡NEL!", size=.72, extrude=.06, col="candy_red", rot=(0, 0, 0), bevel=.01, res=4)
    t.matrix_world = Mb @ Matrix.Translation((0, -.04, .12)); P.append(t)
    return P + G, {"glow": G}

# ======================================================================= 5. SEIS-SIETE (legendary)
def digit(name, ch, x, cols, size=4.6):
    t = text_mesh(name, ch, size=size, extrude=.4, col=cols[0], rot=(90, 0, 0), bevel=.07, res=6, bres=1)
    bake(t); t.data.transform(Matrix.Translation((x, 0, 0)))
    zmin = min(v.co.z for v in t.data.vertices); t.data.transform(Matrix.Translation((0, 0, .55 - zmin)))
    return stripe_paint(t, cols, band=.34)

def seis_siete():
    """LEGENDARY - a '6' and a '7' piñata doing the palms-up 'six seven' hand-weighing bit.
    Riff on '6 7', still the #1 classroom meme in 2026. Gameplay joke: 67,000 candy/s, costs 6,767,676."""
    P = []; G = []
    six = digit("six", "6", -1.15, ["fiesta_pink", "sun_yellow", "turquoise", "sun_yellow"])
    sev = digit("seven", "7", 1.15, ["lime", "sun_yellow", "grape", "sun_yellow"])
    P += [six, sev]
    def top_of(o, x, z0):
        h = surface_hit([o], (x, -8, z0), (0, 1, 0)); return h
    # faces (eyes + mouths raycast onto the glyphs)
    for o, cx, ez, mz, mx, style in ((six, -1.15, 2.5, 1.9, 0, "round"), (sev, 1.15, 2.7, 2.0, .31, "smug")):
        for s in (-1, 1):
            e, _, _ = cute_eye(f"{o.name}e{s}", [o], (cx + s * .33, -8, ez), (0, 1, 0), size=.25, style=style, push=.02)
            P += e
        P += smile(f"{o.name}m", [o], (cx + mx, -8, mz), (0, 1, 0), width=.42, height=.12, open_mouth=True)
        if o is six:
            P += blush(f"{o.name}b1", [o], (cx - .58, -8, mz + .15), (0, 1, 0), size=.11)
            P += blush(f"{o.name}b2", [o], (cx + .58, -8, mz + .15), (0, 1, 0), size=.11)
    # the gesture: both palms up, one high one low (weighing 6 vs 7)
    for nm, sh, hd, col in (("six", V(-2.05, 0, 1.9), V(-2.85, -.55, 2.9), "fiesta_pink"), ("sev", V(2.0, 0, 2.55), V(2.9, -.55, 1.85), "lime")):
        P += limb(nm + "arm", sh, hd, .17, .15, 2, [col, "sun_yellow"], seed=hash(nm) % 50, seg=12)
        P += glove(nm + "g", hd, (hd - sh) * .3 + V(0, -1, 0) * .7, s=.95, col="eye_white", palm_up=True, cuff="sun_yellow")
        P += [s_ for s_ in [None] if s_]
    for nm, sh, hd, col in (("sixL", V(-.25, 0, 1.55), V(.05, -.8, 1.3), "fiesta_pink"), ("sevL", V(.4, 0, 2.5), V(.12, -.8, 2.8), "lime")):
        P += limb(nm + "arm", sh, hd, .15, .13, 2, [col, "sun_yellow"], seed=hash(nm) % 50 + 3, seg=12)
        P += glove(nm + "g", hd, V(0, -1, .35), s=.8, col="eye_white", palm_up=True, cuff="sun_yellow")
    # motion arcs (up/down) next to each raised palm
    for x, z0, up in ((-2.85, 2.9, 1), (2.9, 1.85, -1)):
        for k in range(2):
            pts = [V(x + (k * .25 - .5) * (1 if x > 0 else -1), -.6, z0 + up * (.35 + .25 * t)) for t in (0, 1)]
            G.append(tube(f"mv{x}{k}", pts, radius=.045, col="neon_gold", seg=5))
    # stubby legs + sneakers
    for x, col in ((-1.55, "fiesta_pink"), (-.75, "fiesta_pink"), (.65, "lime"), (1.2, "lime")):
        P += limb(f"leg{x}", V(x, 0, .8), V(x, -.05, .25), .17, .16, 2, [col, "sun_yellow"], seed=int(x * 10) % 40, seg=10)
        P += shoe(f"shoe{x}", (x, -.05, 0), col="eye_white", sole=col, s=.85)
    return P + G, {"glow": G}

# ======================================================================= 6. MANZANIN IQ (mythic)
def manzanin_iq():
    """MYTHIC - cross-eyed apple piñata with mini apples orbiting its head and a tiny 'IQ: 3' sign.
    Riff on the 'spinning apples IQ test' format."""
    P = []; G = []; R = 1.2; cz = .4
    body = fringe_body("body", lambda z: R * max(0.0, 1 - ((2 * z / 2.3) - 1) ** 2) ** .45 * (1 - .12 * math.exp(-((z - 2.3) / .25) ** 2)), 2.3, 6,
                       ["candy_red", "chili", "candy_red", "candy_red", "chili", "candy_red"], matrix=M((0, 0, cz)), seg=34, flare=.1, tooth=.07, seed=91, sx=1.1)
    P += body
    top = V(0, 0, cz + 2.3)
    P.append(tube("stem", [top - V(0, 0, .2), top + V(.08, 0, .35), top + V(.25, 0, .55)], radius=.08, col="wood_dark", seg=8))
    P.append(slab("leaf", [(0, 0), (.35, .18), (.75, .12), (1.0, 0), (.75, -.12), (.35, -.18)], thick=.06, col="lime", bevel=.02,
                  matrix=Matrix.Translation(top + V(.15, 0, .35)) @ Matrix.Rotation(math.radians(25), 4, 'Y') @ Matrix.Rotation(math.radians(-20), 4, 'Z')))
    fc = V(0, 0, cz + 1.25)
    for s, look in ((-1, (.38, -.05)), (1, (-.38, -.05))):   # cross-eyed
        e, _, _ = cute_eye(f"eye{s}", body, fc + V(s * .45, -12, .25), (0, 1, 0), size=.34, iris="lime", look=look, push=.03)
        P += e
    mp = surface_hit(body, fc + V(0, -8, -.42), (0, 1, 0))[0]
    P += smile("m", body, fc + V(0, -12, -.42), (0, 1, 0), width=.6, height=.16, open_mouth=True)
    tg = sphere("tongue_out", (.16, .1, .26), loc=mp + V(.14, -.12, -.3), rot=(20, 0, -15), col="tongue", seg=12, ring=6); P.append(tg)
    P += blush("b1", body, fc + V(-.72, -12, -.15), (0, 1, 0), size=.13)
    P += blush("b2", body, fc + V(.72, -12, -.15), (0, 1, 0), size=.13)
    # orbit: tilted neon ring + 4 mini apples
    tilt = Matrix.Translation((0, 0, cz + 2.55)) @ Matrix.Rotation(math.radians(16), 4, 'X') @ Matrix.Rotation(math.radians(-8), 4, 'Y')
    ring = torus("orbit", 1.85, .035, col="neon_cyan", seg=48, mseg=5); ring.matrix_world = tilt; G.append(ring)
    for k in range(4):
        a = 2 * math.pi * k / 4 + .4; p = tilt @ V(1.85 * math.cos(a), 1.85 * math.sin(a), 0)
        P.append(sphere(f"ma{k}", (.3, .3, .27), loc=p, col=("candy_red", "lime", "candy_red", "sun_yellow")[k], seg=14, ring=8))
        P.append(cyl(f"mas{k}", .03, .03, .2, loc=p + V(0, 0, .22), col="wood_dark", seg=5))
        P.append(sphere(f"mal{k}", (.1, .05, .05), loc=p + V(.08, 0, .36), col="lime", seg=8, ring=4))
    # arms: one scratching head, one holding the IQ sign; legs
    P += limb("armL", V(-1.15, -.2, 1.45), V(-1.25, -.55, 2.75), .17, .15, 2, ["candy_red", "chili"], seed=93, seg=12)
    P += glove("gL", V(-1.25, -.55, 2.75), (.5, .1, .6), s=.85, col="eye_white", cuff="lime")
    P += limb("armR", V(1.15, -.2, 1.3), V(1.6, -.75, 1.0), .17, .15, 2, ["candy_red", "chili"], seed=94, seg=12)
    P += sign_board("iq", [("IQ: 3", .34, -.02)], 1.15, .62, (1.75, -.95, 1.55), rot_z=-12, board="snow", ink="ink", rim="wood")
    P.append(cyl("iqstick", .05, .05, 1.0, loc=(1.7, -.85, .55), col="wood", seg=6))
    P.append(sphere("handR", (.2, .2, .2), loc=(1.68, -.85, 1.02), col="eye_white", seg=12, ring=8))
    for s in (-1, 1):
        P += limb(f"leg{s}", V(s * .45, 0, .6), V(s * .55, -.05, .22), .18, .16, 2, ["chili", "candy_red"], seed=95 + s, seg=10)
        P += shoe(f"sh{s}", (s * .55, -.05, 0), col="lime", sole="eye_white", s=.95)
    return P + G, {"glow": G}

MEMES = {"gemelos_pupusa": gemelos_pupusa, "fichadito": fichadito, "michi_aplausos": michi_aplausos,
         "mapache_nel": mapache_nel, "seis_siete": seis_siete, "manzanin_iq": manzanin_iq}
MEME_RARITY = {"gemelos_pupusa": "secret", "fichadito": "secret", "michi_aplausos": "legendary",
               "mapache_nel": "mythic", "seis_siete": "legendary", "manzanin_iq": "mythic"}
MEME_CAM = {"gemelos_pupusa": (12, 10), "fichadito": (18, 10), "michi_aplausos": (22, 10), "mapache_nel": (35, 12),
            "seis_siete": (12, 8), "manzanin_iq": (20, 10)}
C.CREATURES.update(MEMES); C.RARITY.update(MEME_RARITY); C.CAM.update(MEME_CAM)

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    metas = [C.build(n, samples=int(os.environ.get("SAMPLES", "96")), res=(1100, 1100)) for n in (argv or list(MEMES))]
    mf = f"{ROOT}/export/creatures/_meta.json"
    old = json.load(open(mf)) if os.path.exists(mf) else {}
    for m in metas: old[m["name"]] = m
    json.dump(old, open(mf, "w"), indent=1)
