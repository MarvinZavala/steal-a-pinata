"""La Plaza (phase 2) - production lobby hub for Steal a Pinata!.
Modular, Roblox-ready pieces (each mesh <= 20K tris) exported to art/export/lobby/:
  shops (4 themed two-storey Latin facades), fountain (+ _Water), bench, planter, lamp, light pole,
  palm, flamboyan tree, candy cart, Fabrica gate (+ _Sign), pasarela segment, papel picado garland,
  string lights. Every module returns a dict of mesh groups: ""(palette), "Neon", "Sign", "Water", "Flags".
CLI: blender -b --factory-startup -P lobby.py -- [module ...] | preview | topprev | scene
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
from plib import *
from props import text_mesh, flags_material
from base import append_asset
from mathutils import Vector, Matrix, Euler

def R(deg, ax='Z'): return Matrix.Rotation(math.radians(deg), 4, ax)
def Tr(x, y=0, z=0): return Matrix.Translation((x, y, z))
XZ = R(90, 'X')                                   # slab 2D (x, y) -> world (x, z); thickness along -y
YZ = Matrix(((0, 0, 1, 0), (1, 0, 0, 0), (0, 1, 0, 0), (0, 0, 0, 1)))  # slab 2D (a, b) -> world (y=a, z=b), thick along x

def xz_slab(name, poly, front_y, thick, col, bevel=.06, x=0):
    """Vertical slab in the XZ plane whose FRONT face is at y=front_y (front = -Y)."""
    return slab(name, poly, thick=thick, col=col, bevel=bevel, matrix=Tr(x, front_y + thick / 2, 0) @ XZ)

def lathe(name, prof, seg=32, col="white", loc=(0, 0, 0), rmod=None, closed=False):
    """Revolve [(r, z), ...] (ordered bottom->top on the outside for outward normals)."""
    bm = bmesh.new(); rings = []
    for r, z in prof:
        ring = []
        for j in range(seg):
            a = 2 * math.pi * j / seg; rr = r * (rmod(a) if rmod else 1)
            ring.append(bm.verts.new((rr * math.cos(a), rr * math.sin(a), z)))
        rings.append(ring)
    n = len(rings)
    for i in range(n - 1 + (1 if closed else 0)):
        A, B = rings[i], rings[(i + 1) % n]
        for j in range(seg): bm.faces.new((A[j], A[(j + 1) % seg], B[(j + 1) % seg], B[j]))
    o = bm_to_obj(bm, name); o.location = loc; return paint(o, col)

def sheet(name, rows, thick=.12, col="white"):
    """Quad grid through rows of points, solidified."""
    bm = bmesh.new(); V = [[bm.verts.new(p) for p in r] for r in rows]
    for i in range(len(V) - 1):
        for j in range(len(V[0]) - 1): bm.faces.new((V[i][j], V[i][j + 1], V[i + 1][j + 1], V[i + 1][j]))
    o = bm_to_obj(bm, name)
    m = o.modifiers.new("s", 'SOLIDIFY'); m.thickness = thick; m.offset = 0; apply_mods(o)
    return paint(o, col)

def catenary(p0, p1, sag, n=24):
    p0, p1 = Vector(p0), Vector(p1)
    return [p0.lerp(p1, i / n) - Vector((0, 0, sag * 4 * (i / n) * (1 - i / n))) for i in range(n + 1)]

def rrect(w, h, r, n=5):
    """Rounded rectangle polygon centred at origin."""
    pts = []
    for cx, cy, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)):
        for k in range(n + 1):
            a = math.radians(a0 + 90 * k / n); pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts

def arch_pts(hw, spring, n=14, y0=0.0):
    """Outline of an arched opening: left jamb bottom -> up -> semicircle -> right jamb bottom."""
    pts = [(-hw, y0)]
    for k in range(n + 1):
        a = math.pi - math.pi * k / n; pts.append((hw * math.cos(a), spring + hw * math.sin(a)))
    pts.append((hw, y0)); return pts

def lump(name, r, loc, col, seed=0, sub=2, amp=.18, squash=1.0):
    bm = bmesh.new(); bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1)
    rnd = random.Random(seed); ph = [rnd.uniform(0, 6.28) for _ in range(6)]
    for v in bm.verts:
        p = v.co; d = 1 + amp * (math.sin(3.1 * p.x + ph[0]) * math.sin(2.7 * p.y + ph[1]) + .6 * math.sin(4.3 * p.z + ph[2]) * math.sin(3.7 * p.x + ph[3]))
        v.co = Vector((p.x * r * d, p.y * r * d, p.z * r * d * squash))
    o = bm_to_obj(bm, name); o.location = loc; return paint(o, col)

def flower(name, loc, col, s=1.0, center="sun_yellow"):
    out = [star_prism(name + "p", 5, .42 * s, .26 * s, .1 * s, loc=loc, col=col, bevel=0)]
    out.append(sphere(name + "c", (.15 * s, .15 * s, .1 * s), loc=Vector(loc) + Vector((0, 0, .06 * s)), col=center, seg=8, ring=4))
    return out

def jar(name, loc, col, h=.8, r=.34):
    x, y, z = loc
    return [cyl(name + "g", r, r, h, loc=(x, y, z), col=col, seg=8),
            cyl(name + "l", r * .8, r * .8, .16, loc=(x, y, z + h), col="gold", seg=8)]

def potted_bush(name, loc, s=1.0, cols=("fiesta_pink", "sun_yellow")):
    x, y, z = loc; P = []
    P.append(lathe(name + "pot", [(.55 * s, 0), (.75 * s, .2 * s), (.85 * s, 1.1 * s), (.95 * s, 1.25 * s), (.95 * s, 1.4 * s), (.75 * s, 1.4 * s)], 12, "terracotta", loc=(x, y, z)))
    P.append(lump(name + "b", .95 * s, (x, y, z + 1.95 * s), "leaf", seed=len(name), sub=2, amp=.16))
    rnd = random.Random(len(name))
    for k in range(6):
        a = rnd.uniform(0, 6.28); e = rnd.uniform(.2, 1.1)
        p = Vector((x, y, z + 1.95 * s)) + .95 * s * Vector((math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)))
        P.append(sphere(name + f"f{k}", (.2 * s,) * 3, loc=p, col=cols[k % len(cols)], seg=6, ring=4))
    return P

# ======================================================================= SHOPS
SHOPS = {
    "dulceria": dict(text="DULCERÍA", wall="wall_rose", trim="trim", zoc="hot_magenta", aw=("candy_red", "snow"), shut="turquoise",
                     accent="candy_red", board="snow", ink="candy_red", icon="lollipop", goods=("candy_red", "sun_yellow", "candy_teal", "fiesta_pink", "lime")),
    "bates": dict(text="BATES", wall="wall_ochre", trim="trim", zoc="terracotta", aw=("cobalt", "snow"), shut="cobalt",
                  accent="cobalt", board="snow", ink="cobalt", icon="bats", goods=("wood", "gold", "wood_dark", "wood", "silver")),
    "cajas": dict(text="CAJAS", wall="wall_aqua", trim="trim", zoc="cobalt", aw=("grape", "sun_yellow"), shut="fiesta_pink",
                  accent="grape", board="snow", ink="grape", icon="caja", goods=("grape", "fiesta_pink", "sun_yellow", "turquoise", "lime")),
    "vip": dict(text="VIP", wall="wall_lilac", trim="gold_pale", zoc="ink_soft", aw=("ink_soft", "gold"), shut="gold_deep",
                accent="gold", board="ink_soft", ink="gold", icon="crown", goods=("gold", "neon_pink", "gold_deep", "cosmic_3", "gold")),
}
SW, SD, H1, SH = 23.0, 14.0, 11.0, 19.0          # shop width, depth, ground floor height, cornice height
DW, SPR = 4.4, 5.0                                 # door half width, arch spring

def sbox(*a, **k):
    """Shop boxes: single-segment chamfer (reads the same at plaza distance, ~60% fewer tris)."""
    k.setdefault("bseg", 1); return box(*a, **k)

def shop_icon(kind, z):
    P = []; G = []
    if kind == "lollipop":
        P.append(cyl("ic_base", 1.0, .7, .6, loc=(0, -.2, z - .6), col="trim", seg=14, bevel=.1))
        P.append(cyl("ic_stick", .38, .38, 2.6, loc=(0, -.2, z - .2), col="snow", seg=10))
        z -= 1.6
        M = Tr(0, -.2, z + 5.6) @ R(90, 'X')
        d = cyl("ic_disc", 2.4, 2.4, .8, col="candy_red", seg=40, bevel=.25, bseg=3, base=False); d.data.transform(M); P.append(d)
        for side in (1, -1):
            sw = [M @ Vector(((.2 + t * .07) * math.cos(t * .7), (.2 + t * .07) * math.sin(t * .7), .42 * side)) for t in range(32)]
            P.append(tube(f"ic_swirl{side}", sw, radius=.2, col="snow", seg=6))
        P.append(torus("ic_bow", .5, .22, loc=(0, -.2, z + 3.4), rot=(90, 0, 0), col="sun_yellow", seg=14, mseg=6))
    elif kind == "bats":
        for s in (-1, 1):
            M = Tr(0, -.3, z + 3.2) @ R(s * 32, 'Y')
            b = lathe(f"ic_bat{s}", [(.001, -3.4), (.42, -3.35), (.48, -3.1), (.3, -2.9), (.3, -1.0), (.62, 1.0), (.82, 2.6), (.8, 3.1), (.5, 3.4), (.001, 3.45)], 14, "wood" if s < 0 else "gold")
            b.data.transform(M); P.append(b)
            for zz in (-2.3, -1.9):
                t_ = torus(f"ic_tape{s}{zz}", .34, .07, col="candy_red", seg=14, mseg=4); t_.data.transform(M @ Tr(0, 0, zz)); P.append(t_)
        P.append(star_prism("ic_star", 5, 1.2, .55, .5, loc=(0, -.9, z + 3.0), rot=(90, 0, 0), col="sun_yellow", bevel=.1))
    elif kind == "caja":
        P.append(sbox("ic_box", (4.2, 4.2, 3.6), loc=(0, .2, z + 1.8), rot=(0, 0, 12), col="grape", bevel=.25, bseg=2))
        P.append(sbox("ic_lid", (4.7, 4.7, 1.0), loc=(0, .2, z + 3.9), rot=(0, 0, 12), col="fiesta_pink", bevel=.25, bseg=2))
        for a in (12, 102):
            P.append(sbox(f"ic_rib{a}", (4.8, .7, 4.9), loc=(0, .2, z + 2.2), rot=(0, 0, a), col="sun_yellow", bevel=.1))
        for s in (-1, 1):
            t_ = torus(f"ic_loop{s}", .9, .3, col="sun_yellow", seg=16, mseg=6)
            t_.data.transform(Tr(0, .2, z + 4.9) @ R(12) @ Tr(s * .9, 0, .3) @ R(90, 'X')); P.append(t_)
        P.append(sphere("ic_knot", (.55, .55, .5), loc=(0, .2, z + 4.7), col="sun_yellow", seg=12, ring=6))
        P.append(text_mesh("ic_q", "?", 2.4, .3, "snow", loc=(0, -1.95, z + 1.8), rot=(90, 0, 12), bevel=0, res=3, bres=0))
    elif kind == "crown":
        P.append(lathe("ic_band", [(2.2, 0), (2.4, .2), (2.4, 1.4), (2.2, 1.6), (2.0, 1.4), (2.0, .2)], 36, "gold", loc=(0, .5, z), closed=True))
        for k in range(6):
            a = 2 * math.pi * k / 6 + math.pi / 2
            p = Vector((2.2 * math.cos(a), .5 + 2.2 * math.sin(a), z + 1.4))
            P.append(cyl(f"ic_pt{k}", .55, .05, 2.2, loc=p, col="gold", seg=8))
            P.append(sphere(f"ic_ball{k}", (.32,) * 3, loc=p + Vector((0, 0, 2.25)), col="gold_pale", seg=10, ring=6))
            gp = Vector((2.45 * math.cos(a), .5 + 2.45 * math.sin(a), z + .8))
            G.append(sphere(f"ic_gem{k}", (.36, .2, .36), loc=gp, rot=(0, 0, math.degrees(a) + 90), col=["neon_pink", "neon_cyan"][k % 2], seg=10, ring=6))
        P.append(sphere("ic_vel", (1.9, 1.9, 1.3), loc=(0, .5, z + 1.0), col="velvet", seg=20, ring=10))
    return P, G

def shop(key):
    c = SHOPS[key]; P = []; G = []; S = []
    FY = -SD / 2; W = SW; H = SH
    # --- masses: front block with an arched, 5-deep doorway + body behind
    poly = [(-W / 2, 0)] + arch_pts(DW, SPR) + [(W / 2, 0), (W / 2, H), (-W / 2, H)]
    P.append(xz_slab("front", poly, FY, 5.0, c["wall"], bevel=.08))
    P.append(sbox("body", (W, SD - 5, H), loc=(0, (FY + 5 + SD / 2) / 2, H / 2), col=c["wall"], bevel=.1))
    # zocalo (base band), broken by the door
    for s in (-1, 1):
        x0, x1 = s * DW, s * (W / 2 + .2)
        P.append(sbox(f"zoc{s}", (abs(x1 - x0), .5, 1.5), loc=((x0 + x1) / 2, FY - .1, .75), col=c["zoc"], bevel=.08))
        P.append(sbox(f"zocS{s}", (.5, SD + .4, 1.5), loc=(s * (W / 2 + .05), 0, .75), col=c["zoc"], bevel=.08))
    P.append(sbox("zocB", (W + .4, .5, 1.5), loc=(0, SD / 2 + .05, .75), col=c["zoc"], bevel=.08))
    # pilasters + capitals + bases; corner pilasters upstairs; band + cornice
    for x in (-W / 2 + .7, -DW - 1.0, DW + 1.0, W / 2 - .7):
        P.append(sbox(f"pil{x}", (1.4, .6, H1 - 1.5), loc=(x, FY - .3, 1.5 + (H1 - 1.5) / 2), col=c["trim"], bevel=.08))
        P.append(sbox(f"cap{x}", (1.9, .9, .45), loc=(x, FY - .4, H1 - .3), col=c["trim"], bevel=.1))
        P.append(sbox(f"pb{x}", (1.8, .8, .5), loc=(x, FY - .35, 1.75), col=c["trim"], bevel=.1))
    for x in (-W / 2 + .7, W / 2 - .7):
        P.append(sbox(f"upil{x}", (1.3, .5, H - H1 - 1), loc=(x, FY - .25, H1 + .6 + (H - H1 - 1) / 2), col=c["trim"], bevel=.08))
    P.append(sbox("band", (W + .7, 1.1, .9), loc=(0, FY - .35, H1 + .25), col=c["trim"], bevel=.12))
    P.append(sbox("corn1", (W + 1.0, 1.3, .55), loc=(0, FY - .4, H - .2), col=c["trim"], bevel=.12))
    P.append(sbox("corn2", (W + 1.8, 1.9, .45), loc=(0, FY - .55, H + .25), col=c["trim"], bevel=.12))
    P.append(tube("archivolt", [(x, FY - .25, z) for x, z in arch_pts(DW + .35, SPR, n=18)], radius=.38, col=c["trim"], seg=8))
    P.append(sbox("key", (1.1, .9, 1.5), loc=(0, FY - .35, SPR + DW + .5), col=c["accent"], bevel=.12))
    # --- interior visible through the arch: shelves of jars, counter, hanging lamp
    BY = FY + 5
    P.append(sbox("in_floor", (2 * DW, 5, .12), loc=(0, FY + 2.5, .06), col="plaza_tile", bevel=0))
    for k, z in enumerate((2.2, 4.1, 6.0)):
        P.append(sbox(f"shelf{k}", (2 * DW - .4, 1.1, .2), loc=(0, BY - .55, z), col="wood", bevel=.04))
        for j in range(6):
            x = -DW + .9 + j * (2 * DW - 1.8) / 5
            P += jar(f"sj{k}{j}", (x, BY - .55, z + .1), c["goods"][(j + k) % 5], h=.9, r=.32)
    P.append(sbox("counter", (6.8, 1.4, 2.6), loc=(0, FY + 2.4, 1.3), col=c["accent"], bevel=.12))
    P.append(sbox("counter_top", (7.2, 1.8, .3), loc=(0, FY + 2.4, 2.75), col="wood", bevel=.06))
    for j, x in enumerate((-2.4, 0, 2.4)):
        P += jar(f"cj{j}", (x, FY + 2.3, 2.9), c["goods"][j + 1], h=1.3, r=.55)
    P.append(cyl("lampcord", .05, .05, 1.2, loc=(0, FY + 2.5, 7.4), col="ink", seg=6))
    G.append(sphere("lampbulb", (.5, .5, .5), loc=(0, FY + 2.5, 7.3), col="neon_gold", seg=12, ring=8))
    # --- ground-floor arched shop windows with display sills
    for s in (-1, 1):
        x = s * 8.25; hw = 1.55; sp = 6.0
        P.append(xz_slab(f"gw{s}", arch_pts(hw, sp, n=12, y0=2.4), FY - .05, .12, "ink_soft", bevel=0, x=x))
        P.append(tube(f"gwf{s}", [(x + px, FY - .12, pz) for px, pz in arch_pts(hw + .15, sp, n=14, y0=2.25)], radius=.2, col=c["trim"], seg=6))
        P.append(sbox(f"gwm{s}", (.15, .2, 3.6), loc=(x, FY - .12, 4.2), col=c["trim"], bevel=0))
        P.append(sbox(f"gwt{s}", (3.1, .2, .15), loc=(x, FY - .12, 4.6), col=c["trim"], bevel=0))
        P.append(sbox(f"gws{s}", (3.8, 1.2, .3), loc=(x, FY - .5, 2.25), col=c["trim"], bevel=.08))
        for j in range(3):
            P += jar(f"wj{s}{j}", (x - 1.1 + j * 1.1, FY - .55, 2.4), c["goods"][(j + 2 + s) % 5], h=.75, r=.3)
    # --- upper floor: 3 windows with open shutters; flower boxes; central iron balcony
    for k, x in enumerate((-7.2, 0, 7.2)):
        z0, z1, hw = H1 + 2.0, H1 + 6.4, 1.35
        P.append(sbox(f"uw{k}", (2 * hw, .2, z1 - z0), loc=(x, FY - .05, (z0 + z1) / 2), col="ink_soft", bevel=0))
        fr = [(x - hw - .15, FY - .15, z0 - .15), (x - hw - .15, FY - .15, z1 + .15), (x + hw + .15, FY - .15, z1 + .15), (x + hw + .15, FY - .15, z0 - .15)]
        P.append(tube(f"uwf{k}", fr + [fr[0]], radius=.18, col=c["trim"], seg=6))
        P.append(sbox(f"uwm{k}", (.14, .2, z1 - z0), loc=(x, FY - .15, (z0 + z1) / 2), col=c["trim"], bevel=0))
        P.append(sbox(f"uwl{k}", (2 * hw + 1.2, .8, .5), loc=(x, FY - .35, z1 + .55), col=c["trim"], bevel=.08))
        for s in (-1, 1):
            sx = x + s * (hw + .85)
            P.append(sbox(f"sh{k}{s}", (1.45, .25, z1 - z0 + .2), loc=(sx, FY - .3, (z0 + z1) / 2), rot=(0, 0, -s * 12), col=c["shut"], bevel=.05))
            for j in range(5):
                P.append(sbox(f"sl{k}{s}{j}", (1.15, .12, .14), loc=(sx - s * .04, FY - .47, z0 + .5 + j * .85), rot=(0, 0, -s * 12), col="snow", bevel=0))
        if k == 1:
            P.append(sbox("balc", (5.4, 2.0, .4), loc=(x, FY - 1.0, z0 - .25), col=c["trim"], bevel=.1))
            for s in (-1, 1):
                P.append(sbox(f"corb{s}", (.5, 1.5, .9), loc=(x + s * 2.1, FY - .75, z0 - .9), col=c["trim"], bevel=.1))
            rail = [(x - 2.55, FY - .1, z0 + 1.6), (x - 2.55, FY - 1.85, z0 + 1.6), (x + 2.55, FY - 1.85, z0 + 1.6), (x + 2.55, FY - .1, z0 + 1.6)]
            P.append(tube("rail", rail, radius=.1, col="iron", seg=6))
            for j in range(11):
                bx = x - 2.5 + j * .5; P.append(cyl(f"bal{j}", .05, .05, 1.65, loc=(bx, FY - 1.85, z0 - .05), col="iron", seg=5))
                if j % 2 == 0 and j < 10: P.append(torus(f"balr{j}", .22, .05, loc=(bx + .25, FY - 1.85, z0 + .75), rot=(90, 0, 0), col="iron", seg=10, mseg=4))
            for j in range(3):
                for s in (-1, 1):
                    P.append(cyl(f"bals{j}{s}", .05, .05, 1.65, loc=(x + s * 2.55, FY - .35 - j * .55, z0 - .05), col="iron", seg=5))
        else:
            P.append(sbox(f"fb{k}", (3.4, 1.0, .8), loc=(x, FY - .55, z0 - .45), col="wood", bevel=.08))
            for j in range(5):
                P.append(lump(f"fbl{k}{j}", .45, (x - 1.3 + j * .65, FY - .6, z0 + .05), "leaf", seed=j + k * 7, sub=1, amp=.15))
                P.append(sphere(f"fbf{k}{j}", (.24,) * 3, loc=(x - 1.3 + j * .65, FY - .95, z0 + .3 + .1 * (j % 2)), col=("fiesta_pink", "sun_yellow", "snow", "tangerine")[(j + k) % 4], seg=6, ring=4))
    for s in (-1, 1):   # side windows (upper)
        P.append(sbox(f"swin{s}", (.2, 2.6, 4.0), loc=(s * (W / 2 + .02), 0, H1 + 4.2), col="ink_soft", bevel=0))
        for dy in (-1.55, 1.55):
            P.append(sbox(f"sws{s}{dy}", (.3, 1.3, 4.2), loc=(s * (W / 2 + .1), dy, H1 + 4.2), col=c["shut"], bevel=.05))
        P.append(sbox(f"swl{s}", (.7, 3.4, .45), loc=(s * (W / 2 + .2), 0, H1 + 6.5), col=c["trim"], bevel=.08))
    # --- pitched terracotta (barrel) tile roof, ridge along X
    y_f, y_b, zr = FY + 1.2, SD / 2 + .9, H + 4.6
    def roof_rows(y0, z0, y1, z1):
        return [[(x, y0 + (y1 - y0) * i, z0 + (z1 - z0) * i + .22 * abs(math.sin(math.pi * x / 1.15)))
                 for x in [(-W / 2 - .9) + (W + 1.8) * j / 88 for j in range(89)]] for i in range(2)]
    ym = (y_f + y_b) / 2
    P.append(sheet("roofF", roof_rows(y_f - .6, H + .3, ym, zr), .2, "roof_tile"))
    P.append(sheet("roofB", roof_rows(ym, zr, y_b, H + .3), .2, "roof_tile"))
    P.append(cyl("ridge", .45, .45, W + 2.0, loc=(-W / 2 - 1.0, ym, zr + .2), rot=(0, 90, 0), col="roof_tile", seg=10))
    for s in (-1, 1):
        P.append(slab(f"gable{s}", [(y_f - .2, H), (y_b - .9, H), (ym, zr - .1)], thick=.6, col=c["wall"], bevel=.05, matrix=Tr(s * (W / 2 - .3), 0, 0) @ YZ))
    # --- espadana (curvy colonial parapet) carrying the sign + themed icon
    EW = 9.6
    top = lambda x: 3.2 + 5.2 * max(0.0, math.cos(math.pi * x / (2 * EW))) ** 1.25
    xs = [-EW + 2 * EW * i / 40 for i in range(41)]
    P.append(slab("espadana", [(-EW, -.5)] + [(x, top(x)) for x in xs] + [(EW, -.5)], thick=1.1, col=c["wall"], bevel=.1, matrix=Tr(0, FY + .3, H) @ XZ))
    P.append(tube("esp_trim", [(x, FY - .35, H + top(x) + .05) for x in xs], radius=.32, col=c["trim"], seg=8))
    for s in (-1, 1):
        P.append(tube(f"esp_side{s}", [(s * EW, FY - .35, H + .3), (s * EW, FY - .35, H + top(s * EW) + .05)], radius=.32, col=c["trim"], seg=8))
        P.append(cyl(f"esp_ped{s}", .5, .5, .5, loc=(s * EW, FY - .35, H + 3.2), col=c["trim"], seg=10))
        P.append(sphere(f"esp_ball{s}", (.55,) * 3, loc=(s * EW, FY - .35, H + 3.95), col=c["trim"], seg=12, ring=8))
    IP, IG = shop_icon(c["icon"], H + top(0) + .3); P += IP; G += IG
    # sign: rim + board + text  -> separate mesh "<name>_Sign" (swap / localize)
    sz = H + 3.6
    S.append(slab("sign_rim", rrect(14.2, 4.3, 1.0), thick=.5, col=c["accent"], bevel=.12, matrix=Tr(0, FY - .55, sz) @ XZ))
    S.append(slab("sign_board", rrect(13.2, 3.4, .7), thick=.5, col=c["board"], bevel=.1, matrix=Tr(0, FY - .75, sz) @ XZ))
    t = text_mesh("sign_txt", c["text"], size=2.55 if len(c["text"]) > 5 else 2.8, extrude=.18, col=c["ink"], rot=(90, 0, 0), bevel=.05, res=5, bres=1)
    t.location = (0, FY - 1.1, sz - .05); S.append(t)
    for s in (-1, 1):
        S.append(star_prism(f"sign_star{s}", 5, .9, .42, .4, loc=(s * 7.4, FY - .9, sz + 1.6), rot=(90, 0, 0), col="sun_yellow", bevel=.08))
    # --- striped scalloped awning over the door + bulbs
    AW = 2 * DW + 2.8; n = 8; wst = AW / n
    prof = [(FY - .1 - 4.0 * t, H1 - .55 - 2.5 * t ** 1.7) for t in [i / 8 for i in range(9)]]
    ye, ze = prof[-1]
    for i in range(n):
        x0 = -AW / 2 + i * wst; x1 = x0 + wst; col = c["aw"][i % 2]
        P.append(sheet(f"aw{i}", [[(x0 + (x1 - x0) * j / 2, y, z) for j in range(3)] for y, z in prof], .14, col))
        sc = [(-math.cos(math.pi * k / 10) * wst / 2, -math.sin(math.pi * k / 10) * .75) for k in range(11)]
        P.append(slab(f"sc{i}", [(-wst / 2, .25)] + sc + [(wst / 2, .25)], thick=.12, col=col, bevel=0, matrix=Tr((x0 + x1) / 2, ye - .02, ze - .15) @ XZ))
    P.append(cyl("aw_rod", .14, .14, AW + .6, loc=(-AW / 2 - .3, ye + .08, ze + .1), rot=(0, 90, 0), col="gold", seg=8))
    for s in (-1, 1):
        P.append(sphere(f"aw_end{s}", (.28,) * 3, loc=(s * (AW / 2 + .35), ye + .08, ze + .1), col="gold", seg=10, ring=6))
        P.append(tube(f"aw_br{s}", [(s * (AW / 2 - .4), FY - .1, H1 - 3.6), (s * (AW / 2 - .4), FY - 2.2, H1 - 2.6), (s * (AW / 2 - .4), ye + .2, ze - .05)], radius=.09, col="iron", seg=6))
    for k in range(9):
        x = -AW / 2 + .7 + k * (AW - 1.4) / 8
        G.append(sphere(f"awb{k}", (.18, .18, .22), loc=(x, ye + .4, ze - .55), col="neon_gold", seg=8, ring=5))
    for s in (-1, 1):
        P += potted_bush(f"pot{s}", (s * 5.9, FY - 1.3, 0), s=1.0, cols=(c["aw"][0], "sun_yellow", "snow"))
    return {"": P, "Neon": G, "Sign": S}

# ======================================================================= FOUNTAIN
def fountain():
    P = []; Wt = []; G = []
    P.append(cyl("st1", 17.2, 17.2, .5, col="stone_dark", seg=8, rot=(0, 0, 22.5), bevel=.15))
    P.append(cyl("st2", 15.9, 15.9, .5, loc=(0, 0, .5), col="stone", seg=8, rot=(0, 0, 22.5), bevel=.15))
    P.append(cyl("basin", 14.0, 14.0, 2.3, loc=(0, 0, 1.0), col="snow", seg=8, rot=(0, 0, 22.5), bevel=.12))
    ap = 14.0 * math.cos(math.radians(22.5))
    for k in range(8):
        phi = math.radians(45 * k); n_ = Vector((math.cos(phi), math.sin(phi), 0)); t_ = Vector((-math.sin(phi), math.cos(phi), 0))
        def on_face(name, size, u, z, col, rot45=False, out=.05):
            b = box(name, size, col=col, bevel=0)
            b.data.transform(Tr(*(n_ * (ap + out) + t_ * u + Vector((0, 0, z)))) @ Matrix.Rotation(phi + math.pi / 2, 4, 'Z') @ (R(45, 'Y') if rot45 else Matrix.Identity(4)))
            return b
        P.append(on_face(f"bandT{k}", (10.6, .12, .32), 0, 3.0, "tile_blue"))
        P.append(on_face(f"bandB{k}", (10.6, .12, .25), 0, 1.25, "tile_blue"))
        for j in range(4):
            u = -3.3 + j * 2.2
            P.append(on_face(f"dia{k}{j}", (1.05, .12, 1.05), u, 2.1, "tile_blue", True))
            P.append(on_face(f"dot{k}{j}", (.42, .14, .42), u, 2.1, "sun_yellow", True, .07))
            if j < 3: P.append(on_face(f"sq{k}{j}", (.36, .12, .36), u + 1.1, 2.1, "turquoise", True))
        P.append(on_face(f"cop{k}", (11.5, 1.9, .55), 0, 3.55, "stone", False, -1.0))
        cp = Vector((math.cos(phi + math.pi / 8), math.sin(phi + math.pi / 8), 0)) * (ap - .4) / math.cos(math.pi / 8)
        P.append(box(f"post{k}", (2.1, 2.1, 1.3), loc=cp + Vector((0, 0, 3.75)), rot=(0, 0, 45 * k + 22.5), col="stone", bevel=.15))
        P.append(sphere(f"postb{k}", (.62,) * 3, loc=cp + Vector((0, 0, 4.85)), col="trim", seg=12, ring=8))
        inward = -cp.normalized()
        sp = cp + inward * 1.0 + Vector((0, 0, 4.0))
        P.append(tube(f"spout{k}", [sp - inward * .3, sp + inward * .5 + Vector((0, 0, .1))], radius=.22, col="gold", seg=8))
        tgt = cp.normalized() * 9.4; s0 = sp + inward * .5
        pts = [s0.lerp(Vector((tgt.x, tgt.y, 3.3)), u) + Vector((0, 0, 2.4 * math.sin(math.pi * u) * (1 - .3 * u))) for u in [i / 10 for i in range(11)]]
        Wt.append(tube(f"jet{k}", pts, radius=.16, col="water", seg=6))
        P.append(torus(f"spl{k}", .55, .1, loc=(tgt.x, tgt.y, 3.32), col="snow", seg=14, mseg=4))
    Wt.append(cyl("w_basin", 13.0, 13.0, .12, loc=(0, 0, 3.2), col="water", seg=8, rot=(0, 0, 22.5)))
    P.append(lathe("ped", [(3.4, 3.1), (3.4, 3.6), (2.7, 3.9), (2.0, 4.3), (1.6, 5.2), (1.7, 5.9), (.01, 5.95)], 24, "trim"))
    scal = lambda a: 1 + .05 * math.cos(12 * a)
    P.append(lathe("bowl1", [(.01, 5.6), (2.0, 5.65), (4.4, 6.2), (6.2, 7.0), (7.0, 7.6), (7.2, 7.95), (6.85, 8.1), (6.5, 7.85), (.01, 7.85)], 48, "trim", rmod=scal))
    Wt.append(lathe("w_bowl1", [(.01, 7.75), (6.45, 7.75), (6.45, 7.8), (.01, 7.8)], 48, "water", rmod=scal))
    P.append(lathe("bal", [(1.5, 7.8), (1.5, 8.2), (1.0, 8.5), (1.35, 9.4), (.8, 10.6), (1.1, 11.0), (.01, 11.05)], 20, "turquoise"))
    for k in range(6):
        a = 2 * math.pi * k / 6
        P.append(sphere(f"fish{k}", (.55, .35, .35), loc=(1.3 * math.cos(a), 1.3 * math.sin(a), 9.3), rot=(0, 25, math.degrees(a)), col="fiesta_pink", seg=10, ring=6))
    P.append(lathe("bowl2", [(.01, 10.9), (1.4, 10.95), (2.8, 11.5), (3.75, 12.2), (3.95, 12.5), (3.65, 12.65), (3.4, 12.4), (.01, 12.4)], 36, "trim", rmod=scal))
    Wt.append(lathe("w_bowl2", [(.01, 12.3), (3.35, 12.3), (3.35, 12.35), (.01, 12.35)], 36, "water", rmod=scal))
    P.append(lathe("plinth", [(1.4, 12.3), (1.4, 12.8), (1.0, 13.0), (1.0, 14.0), (1.35, 14.2), (1.35, 14.6), (.01, 14.62)], 20, "fiesta_pink"))
    for k in range(10):
        a = 2 * math.pi * k / 10
        P.append(sphere(f"pb{k}", (.18,) * 3, loc=(1.38 * math.cos(a), 1.38 * math.sin(a), 14.4), col="gold", seg=8, ring=5))
    Wt.append(lathe("curtain1", [(8.4, 3.3), (8.25, 4.8), (8.0, 6.3), (7.6, 7.5), (7.25, 7.9)], 48, "water", rmod=scal))
    Wt.append(lathe("curtain2", [(5.1, 7.8), (5.0, 8.9), (4.75, 10.6), (4.35, 12.0), (4.0, 12.45)], 36, "water", rmod=scal))
    P.append(torus("foam1", 8.4, .28, loc=(0, 0, 3.3), col="snow", seg=56, mseg=6))
    P.append(torus("foam2", 5.1, .22, loc=(0, 0, 7.85), col="snow", seg=40, mseg=6))
    for k in range(8):
        a = 2 * math.pi * (k + .5) / 8
        G.append(sphere(f"ul{k}", (.35, .35, .15), loc=(11.0 * math.cos(a), 11.0 * math.sin(a), 3.2), col="neon_cyan", seg=10, ring=5))
    return {"": P, "Water": Wt, "Neon": G}

# ======================================================================= SMALL FURNITURE
def bench():
    P = []
    side = [(-1.15, 0), (-.85, 0), (-.7, 1.25), (.65, 1.25), (.85, 0), (1.15, 0), (1.0, 1.45), (1.55, 3.7), (1.28, 3.75), (.78, 1.72), (-1.0, 1.72), (-1.25, 1.55)]
    for x in (-2.9, 0, 2.9):
        P.append(slab(f"side{x}", side, thick=.28, col="iron", bevel=.05, matrix=Tr(x, 0, 0) @ YZ))
    for x in (-2.9, 2.9):
        P.append(tube(f"arm{x}", [(x, -1.15, 1.75), (x, -1.2, 2.5), (x, -.4, 2.75), (x, .7, 2.6)], radius=.1, col="iron", seg=6))
        P.append(sphere(f"armk{x}", (.17,) * 3, loc=(x, -1.2, 2.55), col="iron", seg=8, ring=5))
    for j in range(4):
        P.append(box(f"seat{j}", (6.6, .48, .16), loc=(0, -.95 + j * .56, 1.82), col="wood", bevel=.05))
    for j in range(3):
        z = 2.3 + j * .55; y = .85 + (z - 1.72) * .55 / 2.0
        P.append(box(f"back{j}", (6.6, .14, .45), loc=(0, y + .05, z), rot=(-15, 0, 0), col="wood", bevel=.05))
    return {"": P}

def planter():
    P = []
    P.append(lathe("ring", [(3.3, .9), (3.25, 0), (4.05, 0), (4.2, .85), (4.05, 1.2), (3.4, 1.2)], 32, "stone", closed=True))
    P.append(cyl("soil", 3.35, 3.35, 1.0, col="chocolate", seg=32))
    P.append(lump("bushC", 1.6, (0, 0, 2.0), "leaf_dark", seed=2, sub=2, amp=.14, squash=1.1))
    rnd = random.Random(5)
    for k in range(7):
        a = 2 * math.pi * k / 7
        P.append(lump(f"bush{k}", rnd.uniform(.75, .95), (2.35 * math.cos(a), 2.35 * math.sin(a), 1.3), ["leaf", "leaf_dark"][k % 2], seed=k, sub=1, amp=.15, squash=.85))
    cols = ["fiesta_pink", "sun_yellow", "snow", "tangerine", "grape"]
    for k in range(22):
        a = rnd.uniform(0, 6.28); r = rnd.uniform(1.4, 3.0)
        z = 1.25 + rnd.uniform(.35, .95) + (2.2 - r) * .35
        P += flower(f"fl{k}", (r * math.cos(a), r * math.sin(a), z), cols[k % 5], s=rnd.uniform(.8, 1.1))
    for k in range(6):
        a = 2 * math.pi * k / 6 + .3
        P.append(lump(f"mg{k}", .35, (1.2 * math.cos(a), 1.2 * math.sin(a), 3.2 + .2 * (k % 2)), "tangerine", seed=k + 20, sub=1, amp=.25))
    return {"": P}

def lamp():
    P = []; G = []
    P.append(lathe("lbase", [(1.0, 0), (1.0, .4), (.7, .7), (.55, 1.4), (.65, 1.6), (.35, 1.8)], 12, "iron"))
    P.append(cyl("lpole", .26, .2, 8.4, loc=(0, 0, 1.7), col="iron", seg=8))
    P.append(torus("lcol", .3, .1, loc=(0, 0, 4.5), col="gold", seg=12, mseg=4))
    P.append(lathe("ltop", [(.35, 10.0), (.5, 10.2), (.3, 10.5)], 10, "iron"))
    for s in (-1, 1):
        P.append(tube(f"larm{s}", [(0, 0, 9.0), (s * .9, 0, 9.9), (s * 1.9, 0, 10.0), (s * 2.3, 0, 9.6)], radius=.1, col="iron", seg=6))
        P.append(tube(f"lcurl{s}", [(s * .3, 0, 8.6), (s * 1.1, 0, 8.7), (s * 1.4, 0, 9.2), (s * 1.1, 0, 9.55)], radius=.07, col="iron", seg=5))
        lx = s * 2.3
        P.append(cyl(f"lcap{s}", .85, .12, .7, loc=(lx, 0, 9.0), col="iron", seg=6))
        P.append(cyl(f"lbot{s}", .3, .62, .35, loc=(lx, 0, 7.4), col="iron", seg=6))
        G.append(cyl(f"lglass{s}", .6, .66, 1.3, loc=(lx, 0, 7.72), col="neon_gold", seg=6))
        for k in range(6):
            a = 2 * math.pi * k / 6
            P.append(cyl(f"lbar{s}{k}", .045, .045, 1.35, loc=(lx + .64 * math.cos(a), .64 * math.sin(a), 7.7), col="iron", seg=4))
        P.append(sphere(f"lfin{s}", (.16,) * 3, loc=(lx, 0, 9.75), col="gold", seg=8, ring=5))
    G.append(sphere("ltopglow", (.42, .42, .55), loc=(0, 0, 10.9), col="neon_gold", seg=10, ring=6))
    P.append(cyl("ltopcap", .55, .08, .5, loc=(0, 0, 11.4), col="iron", seg=8))
    return {"": P, "Neon": G}

def light_pole(h=12.0):
    P = []
    P.append(cyl("pfoot", .7, .8, .5, col="stone_dark", seg=10, bevel=.08))
    P.append(cyl("ppole", .28, .22, h, loc=(0, 0, .5), col="wood_dark", seg=8))
    P.append(box("pcross", (2.4, .3, .3), loc=(0, 0, h - .2), col="wood_dark", bevel=.05))
    P.append(sphere("ptop", (.4,) * 3, loc=(0, 0, h + .6), col="fiesta_pink", seg=10, ring=6))
    for s in (-1, 1):
        P.append(torus(f"phook{s}", .22, .06, loc=(s * 1.1, 0, h - .55), rot=(90, 0, 0), col="iron", seg=10, mseg=4))
    return {"": P}

def string_lights(p0=(-12, 0, 11), p1=(12, 0, 11), sag=1.8, name="sl"):
    P = []; G = []
    P.append(tube(name + "wire", catenary(p0, p1, sag, 30), radius=.05, col="ink", seg=5))
    L = (Vector(p1) - Vector(p0)).length; nb = max(3, int(L / 2.0))
    cols = ["neon_gold", "neon_gold", "neon_pink", "neon_gold", "neon_cyan"]
    for k in range(nb):
        t = (k + .5) / nb; p = Vector(p0).lerp(Vector(p1), t) - Vector((0, 0, sag * 4 * t * (1 - t)))
        P.append(cyl(name + f"so{k}", .09, .09, .3, loc=p - Vector((0, 0, .3)), col="ink", seg=6))
        G.append(sphere(name + f"b{k}", (.2, .2, .27), loc=p - Vector((0, 0, .5)), col=cols[k % 5], seg=8, ring=5))
    return {"": P, "Neon": G}

def papel_garland(p0=(-12, 0, 11), p1=(12, 0, 11), sag=1.6, name="pg"):
    """Rope + papel picado flags (flags use papel_picado_atlas.png, 4 designs, alpha cut-outs)."""
    P = [tube(name + "rope", catenary(p0, p1, sag, 30), radius=.06, col="ink_soft", seg=5)]
    p0, p1 = Vector(p0), Vector(p1); L = (p1 - p0).length; d = (p1 - p0).normalized()
    side = Vector((-d.y, d.x, 0)).normalized()
    n = max(3, int(L / 2.1)); fw, fh = L / n * .78, 2.3
    bm = bmesh.new(); uvl = bm.loops.layers.uv.new("UVMap"); rnd = random.Random(int(L * 10))
    for i in range(n):
        t = (i + .5) / n; c = p0.lerp(p1, t) - Vector((0, 0, sag * 4 * t * (1 - t)))
        k = rnd.randrange(4); u0, u1 = k / 4 + .008, (k + 1) / 4 - .008
        sw = side * rnd.uniform(-.15, .15); rows = []
        for r in range(5):
            f = r / 4; bow = side * (-.18 * math.sin(f * math.pi)) + sw * f
            rows.append((c - d * fw / 2 - Vector((0, 0, fh * f)) + bow, c + d * fw / 2 - Vector((0, 0, fh * f)) + bow, 1 - f))
        for r in range(4):
            a, b = rows[r], rows[r + 1]
            for flip in (0, 1):
                off = side * (.01 if flip else 0)
                vs = [bm.verts.new(a[0] + off), bm.verts.new(b[0] + off), bm.verts.new(b[1] + off), bm.verts.new(a[1] + off)]
                uv = [(u0, a[2]), (u0, b[2]), (u1, b[2]), (u1, a[2])]
                if flip: vs.reverse(); uv.reverse()
                fc = bm.faces.new(vs)
                for l, u in zip(fc.loops, uv): l[uvl].uv = u
    me = bpy.data.meshes.new(name + "flags"); bm.to_mesh(me); bm.free()
    return {"": P, "Flags": [link(bpy.data.objects.new(name + "flags", me))]}

def palm():
    P = []
    spine = [Vector((0, 0, 0)), Vector((.3, 0, 3.5)), Vector((1.0, 0, 7)), Vector((2.0, 0, 10.2))]
    def sp(t):
        n = len(spine) - 1; i = min(int(t * n), n - 1); u = t * n - i; return spine[i].lerp(spine[i + 1], u)
    for k in range(12):
        t0, t1 = k / 12, (k + 1) / 12; a, b = sp(t0), sp(t1); r0 = .75 - .3 * t0
        o = cyl(f"tr{k}", r0 * 1.12, r0 * .86, (b - a).length + .05, col=["wood", "wood_dark"][k % 2], seg=10)
        o.data.transform(Tr(*a) @ (b - a).to_track_quat('Z', 'Y').to_matrix().to_4x4()); o.location = (0, 0, 0); P.append(o)
    top = sp(1.0) + Vector((0, 0, .2))
    P.append(lump("crown", .85, top, "leaf_dark", seed=3, sub=1, amp=.1))
    rnd = random.Random(11)
    for f in range(9):
        az = 2 * math.pi * f / 9 + rnd.uniform(-.15, .15); L = rnd.uniform(6.2, 7.4); lift = rnd.uniform(.9, 1.6)
        dirv = Vector((math.cos(az), math.sin(az), 0))
        pts = [top + dirv * (L * t) + Vector((0, 0, lift * 2.2 * t - 4.2 * t * t)) for t in [i / 10 for i in range(11)]]
        P.append(tube(f"rach{f}", pts, radius=.09, col="leaf_dark", seg=5, taper=[1 - .7 * i / 10 for i in range(11)]))
        bm = bmesh.new()
        for j in range(1, 10):
            t = j / 10; p = pts[j]; tang = (pts[j + 1] - pts[j - 1]).normalized()
            side = tang.cross(Vector((0, 0, 1))).normalized(); ll = 1.9 * math.sin(math.pi * (t * .85 + .1)) + .3
            for s in (-1, 1):
                tip = p + side * s * ll + tang * ll * .35 - Vector((0, 0, ll * .55))
                mid = p.lerp(tip, .5); wv = tang * .22
                vs = [bm.verts.new(v) for v in (p - wv * .3, mid - wv, tip, mid + wv, p + wv * .3)]; bm.faces.new(vs)
        o = bm_to_obj(bm, f"lf{f}"); m = o.modifiers.new("s", 'SOLIDIFY'); m.thickness = .05; apply_mods(o)
        P.append(paint(o, ["leaf", "lime", "leaf"][f % 3]))
    for k in range(4):
        a = 2 * math.pi * k / 4 + .3
        P.append(sphere(f"coco{k}", (.45,) * 3, loc=top + Vector((.65 * math.cos(a), .65 * math.sin(a), -.6)), col="brown", seg=10, ring=6))
    return {"": P}

def flamboyan():
    """Flame tree (Delonix regia): iconic Central American plaza tree, wide umbrella canopy."""
    P = []
    P.append(tube("trunk", [(0, 0, 0), (.2, .1, 2.5), (.1, .3, 5.0), (.0, .2, 6.2)], radius=.85, col="bark", seg=10, taper=[1.3, .95, .8, .7]))
    rnd = random.Random(8)
    for k in range(5):
        a = 2 * math.pi * k / 5 + rnd.uniform(-.2, .2); L = rnd.uniform(5.5, 7.0)
        tip = (L * math.cos(a), L * math.sin(a), 9.0 + rnd.uniform(-.5, .8))
        P.append(tube(f"br{k}", [(0, .2, 5.6), (L * .35 * math.cos(a), L * .35 * math.sin(a), 7.6), tip], radius=.42, col="bark", seg=8, taper=[1, .7, .4]))
    cols = ["flame", "flame", "candy_red", "tangerine", "flame"]
    for i in range(16):
        a = 2 * math.pi * i / 16 + rnd.uniform(-.1, .1); r = rnd.uniform(3.5, 7.5) if i % 3 else rnd.uniform(.5, 3)
        p = Vector((r * math.cos(a), r * math.sin(a), 10.3 + rnd.uniform(-.4, 1.2) - r * .12))
        P.append(lump(f"can{i}", rnd.uniform(2.3, 3.0), p, cols[i % 5], seed=i, sub=2, amp=.2, squash=.62))
    for i in range(6):
        a = 2 * math.pi * i / 6 + .4
        P.append(lump(f"leafy{i}", 2.0, Vector((5.0 * math.cos(a), 5.0 * math.sin(a), 8.9)), "leaf", seed=40 + i, sub=1, amp=.2, squash=.5))
    return {"": P}

def candy_cart():
    P = []
    P.append(box("cbody", (6.0, 3.4, 2.6), loc=(0, 0, 2.6), col="turquoise", bevel=.2))
    P.append(box("cband", (6.2, 3.6, .5), loc=(0, 0, 3.6), col="sun_yellow", bevel=.12))
    P.append(box("ctop", (6.4, 3.8, .3), loc=(0, 0, 4.0), col="wood", bevel=.08))
    for x in (-1.9, 0, 1.9):
        P.append(star_prism(f"cst{x}", 5, .5, .24, .15, loc=(x, -1.75, 2.5), rot=(90, 0, 0), col="fiesta_pink", bevel=.03))
    for s in (-1, 1):
        for yy in (-1.95, 1.95):
            P.append(torus(f"wheel{s}{yy}", 1.25, .22, loc=(s * 1.9, yy, 1.3), rot=(90, 0, 0), col="candy_red", seg=24, mseg=6))
            for k in range(3):
                P.append(box(f"spk{s}{k}{yy}", (2.4, .1, .1), loc=(s * 1.9, yy, 1.3), rot=(0, 60 * k, 0), col="snow", bevel=0))
    P.append(tube("handle", [(3.0, 0, 3.2), (4.4, 0, 3.9), (4.8, 0, 3.95)], radius=.12, col="wood_dark", seg=6))
    P.append(cyl("hbar", .14, .14, 3.0, loc=(4.8, -1.5, 3.95), rot=(-90, 0, 0), col="wood_dark", seg=8))
    P.append(cyl("upole", .1, .1, 6.6, loc=(-2.2, .8, 4.1), col="snow", seg=6))
    for k in range(10):
        a0, a1 = 2 * math.pi * k / 10, 2 * math.pi * (k + 1) / 10
        rows = [[(-2.2 + (4.0 * i / 4) * math.cos(a0 + (a1 - a0) * j / 3), .8 + (4.0 * i / 4) * math.sin(a0 + (a1 - a0) * j / 3), 10.6 - 1.6 * (i / 4) ** 1.4) for j in range(4)] for i in range(5)]
        P.append(sheet(f"umb{k}", rows, .1, ["fiesta_pink", "snow"][k % 2]))
    P.append(sphere("utop", (.3,) * 3, loc=(-2.2, .8, 10.7), col="sun_yellow", seg=8, ring=5))
    for j, (x, col) in enumerate(((-1.8, "candy_red"), (-.6, "sun_yellow"), (.6, "candy_teal"), (1.8, "candy_violet"))):
        P += jar(f"cjr{j}", (x, -.6, 4.15), col, h=1.1, r=.45)
    for j, x in enumerate((-.9, .9)):
        P.append(cyl(f"ccs{j}", .07, .07, 1.6, loc=(x, .9, 4.15), col="snow", seg=5))
        P.append(lump(f"cc{j}", .65, (x, .9, 6.1), ["bubblegum", "lavender"][j], seed=j, sub=2, amp=.12))
    P.append(cyl("bbox", .9, .9, 1.4, loc=(2.1, .7, 4.15), col="fiesta_pink", seg=12))
    for k in range(5):
        px, py = 2.1 + .4 * math.cos(k * 1.3), .7 + .4 * math.sin(k * 1.3)
        P.append(cyl(f"pops{k}", .04, .04, 1.4, loc=(px, py, 5.2), col="snow", seg=4))
        P.append(cyl(f"popd{k}", .38, .38, .12, loc=(px, py, 6.6), rot=(90, 0, k * 70), col=["candy_red", "lime", "sun_yellow", "candy_teal", "grape"][k], seg=14, base=False))
    return {"": P}

# ======================================================================= FABRICA GATE + PASARELA
def gear(name, r, teeth, th, loc, rot, col):
    pts = []
    for i in range(teeth * 4):
        a = 2 * math.pi * i / (teeth * 4); rr = r if (i % 4) in (0, 1) else r * .8
        pts.append((rr * math.cos(a), rr * math.sin(a)))
    g = slab(name, pts, thick=th, col=col, bevel=.06); xform(g, loc, rot); return g

def fabrica():
    """Spawn gate where new pinatas roll out onto the pasarela. Passage along local Y (front = -Y)."""
    P = []; G = []; S = []
    TX = 10.2
    for s in (-1, 1):
        x = s * TX
        P.append(box(f"tbase{s}", (6.6, 7.6, 1.6), loc=(x, 0, .8), col="ink_soft", bevel=.2))
        for k in range(7):
            P.append(box(f"tow{s}{k}", (5.8, 6.8, 2.3), loc=(x, 0, 2.75 + k * 2.3), col=["fiesta_pink", "snow"][k % 2], bevel=.18))
        P.append(box(f"tcap{s}", (6.8, 7.8, .9), loc=(x, 0, 18.55), col="sun_yellow", bevel=.2))
        P.append(lathe(f"chim{s}", [(1.4, 18.9), (1.2, 22.5), (1.55, 22.8), (1.55, 23.6), (1.0, 23.6)], 16, "ink_soft", loc=(x + s * 1.2, 2.4, 0)))
        for j, (dz, rr, col) in enumerate(((25.0, 1.3, "bubblegum"), (26.9, 1.6, "lavender"), (29.0, 1.9, "mint"))):
            P.append(lump(f"puff{s}{j}", rr, (x + s * (2.6 + j * 1.5), 3.0 + j * 1.6, dz - 1.0), col, seed=j + (s + 1) * 5, sub=2, amp=.12))
        P.append(gear(f"gear{s}", 2.3, 10, .6, (x, -3.55, 10.5), (90, 0, 0), "gold"))
        P.append(cyl(f"gearh{s}", .8, .8, .7, loc=(x, -3.6, 10.5), rot=(90, 0, 0), col="ink_soft", seg=12, bevel=.1))
        P.append(star_prism(f"tstar{s}", 5, 1.2, .55, .5, loc=(x, -3.6, 15.7), rot=(90, 0, 0), col="sun_yellow", bevel=.1))
        for k in range(4):
            G.append(sphere(f"tb{s}{k}", (.3,) * 3, loc=(x + (k - 1.5) * 1.3, -3.95, 5.0), col="neon_gold", seg=8, ring=5))
        P.append(cyl(f"flagp{s}", .12, .12, 4.0, loc=(x - s * 2.2, -2.5, 19.0), col="ink", seg=6))
        P.append(slab(f"flag{s}", [(0, 0), (2.6, -.7), (0, -1.4)], thick=.1, col="turquoise", bevel=0, matrix=Tr(x - s * 2.2, -2.5, 22.9) @ XZ))
    ar = [(7.2 * math.cos(math.pi * k / 24), -2.0, 13.2 + 5.2 * math.sin(math.pi * k / 24)) for k in range(25)]
    P.append(tube("arch", ar, radius=1.15, col="sun_yellow", seg=12))
    for k in range(1, 24, 2):
        x, y, z = ar[k]; G.append(sphere(f"ab{k}", (.32,) * 3, loc=(x, -3.25, z), col="neon_gold" if k % 4 == 1 else "neon_pink", seg=8, ring=5))
    P.append(box("tunnel", (14.0, 1.0, 13.0), loc=(0, 3.4, 6.5), col="ink", bevel=.1))
    P.append(box("lintel", (15.0, 7.0, 1.6), loc=(0, 0, 13.0), col="ink_soft", bevel=.2))
    for k in range(13):
        P.append(box(f"strip{k}", (.85, .12, 9.2), loc=(-6.0 + k * 1.0, 1.2, 7.6), col=["fiesta_pink", "sun_yellow", "turquoise", "lime"][k % 4], bevel=.03))
    P.append(box("belt", (11.0, 8.0, .6), loc=(0, -1.0, .3), col="rubber", bevel=.1))
    for k in range(7):
        P.append(cyl(f"roll{k}", .3, .3, 11.2, loc=(-5.6, -4.4 + k * 1.15, .45), rot=(0, 90, 0), col="steel", seg=8))
    S.append(slab("fs_rim", rrect(24.0, 7.2, 1.6), thick=.8, col="turquoise", bevel=.2, matrix=Tr(0, -3.6, 22.4) @ XZ))
    S.append(slab("fs_board", rrect(22.6, 5.9, 1.2), thick=.6, col="snow", bevel=.15, matrix=Tr(0, -3.95, 22.4) @ XZ))
    t1 = text_mesh("fs_t1", "FÁBRICA", size=3.3, extrude=.25, col="fiesta_pink", rot=(90, 0, 0), bevel=.06, res=5, bres=1); t1.location = (0, -4.4, 23.3); S.append(t1)
    t2 = text_mesh("fs_t2", "DE PIÑATAS", size=1.55, extrude=.2, col="cobalt", rot=(90, 0, 0), bevel=.04, res=5, bres=1); t2.location = (0, -4.35, 20.75); S.append(t2)
    for s in (-1, 1):
        S.append(star_prism(f"fs_st{s}", 5, 1.3, .6, .5, loc=(s * 11.6, -4.0, 25.6), rot=(90, 0, 0), col="sun_yellow", bevel=.1))
    P.append(box("signpost", (1.0, 1.0, 4.0), loc=(0, -3.2, 17.5), col="ink_soft", bevel=.1))
    return {"": P, "Neon": G, "Sign": S}

def pasarela_seg(L=24.0):
    P = []
    P.append(box("carpet", (L, 10, .3), loc=(0, 0, .15), col="hot_magenta", bevel=.05))
    for s in (-1, 1):
        P.append(box(f"edge{s}", (L, .7, .45), loc=(0, s * 5.15, .22), col="gold", bevel=.1))
    for k in range(int(L / 6)):
        P.append(slab(f"chev{k}", [(-1.2, 2.2), (.4, 2.2), (2.0, 0), (.4, -2.2), (-1.2, -2.2), (.4, 0)][::-1], thick=.06, col="fiesta_pink", bevel=0, matrix=Tr(-L / 2 + 3 + k * 6, 0, .33)))
    for s in (-1, 1):
        for x in (-L / 2 + 1, L / 2 - 1):
            P.append(lathe(f"stan{s}{x}", [(.55, 0), (.55, .25), (.18, .35), (.15, 2.6), (.25, 2.8), (.01, 2.82)], 10, "gold", loc=(x, s * 6.4, 0)))
            P.append(sphere(f"stanb{s}{x}", (.35,) * 3, loc=(x, s * 6.4, 3.05), col="gold", seg=10, ring=6))
        P.append(tube(f"rope{s}", catenary((-L / 2 + 1, s * 6.4, 2.6), (L / 2 - 1, s * 6.4, 2.6), 1.0, 16), radius=.15, col="velvet", seg=6))
    return {"": P}

# ======================================================================= MODULE REGISTRY / EXPORT
MODULES = {
    "lobby_shop_dulceria": lambda: shop("dulceria"), "lobby_shop_bates": lambda: shop("bates"),
    "lobby_shop_cajas": lambda: shop("cajas"), "lobby_shop_vip": lambda: shop("vip"),
    "lobby_fountain": fountain, "lobby_bench": bench, "lobby_planter": planter, "lobby_lamp": lamp,
    "lobby_light_pole": light_pole, "lobby_string_lights": string_lights, "lobby_papel_garland": papel_garland,
    "lobby_palm": palm, "lobby_flamboyan": flamboyan, "lobby_candy_cart": candy_cart,
    "lobby_fabrica_gate": fabrica, "lobby_pasarela_seg": pasarela_seg,
}
CAMS = {"lobby_fountain": (28, 24, .78), "lobby_bench": (30, 14), "lobby_planter": (30, 24), "lobby_lamp": (25, 6),
        "lobby_light_pole": (25, 6), "lobby_string_lights": (8, 8, .72), "lobby_papel_garland": (8, 8, .72), "lobby_palm": (30, 10, .82),
        "lobby_flamboyan": (30, 12, .86), "lobby_candy_cart": (32, 14), "lobby_fabrica_gate": (24, 10), "lobby_pasarela_seg": (30, 28)}

def water_material():
    m = bpy.data.materials.get("M_Water")
    if m: return m
    m = bpy.data.materials.new("M_Water"); m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*hex2lin("#2FD6EA"), 1); b.inputs["Roughness"].default_value = .03
    b.inputs["Transmission Weight"].default_value = .8; b.inputs["IOR"].default_value = 1.33
    nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 3.0; nz.inputs["Detail"].default_value = 4
    bp = nt.nodes.new("ShaderNodeBump"); bp.inputs["Strength"].default_value = .25
    nt.links.new(nz.outputs[0], bp.inputs["Height"]); nt.links.new(bp.outputs[0], b.inputs["Normal"])
    return m

def materialize(groups, name, M_=Matrix.Identity(4), export_mode=False):
    """Join groups -> objects name, name_Neon, name_Sign, name_Water, name_Flags; assign materials; place with M_."""
    pal = material_palette(); neon = material_palette("M_Neon", emissive=2.2)
    out = []
    for key, parts in groups.items():
        parts = [p for p in parts if p is not None]
        if not parts: continue
        nm = name if key == "" else f"{name}_{key}"
        o = join(parts, nm)
        if key == "Neon": assign_mat(o, neon)
        elif key == "Water": assign_mat(o, pal if export_mode else water_material())
        elif key == "Flags": assign_mat(o, bpy.data.materials.get("M_PapelPicado") or flags_material())
        else: assign_mat(o, pal)
        if key != "Flags": smooth(o, 40)
        o.matrix_world = M_ @ o.matrix_world
        out.append(o)
    return out

def build_module(name, render_it=True):
    reset(); write_palette_textures()
    objs = materialize(MODULES[name](), name, export_mode=True)
    size = base_origin(objs, keep_xy=name.startswith("lobby_shop") or name == "lobby_fabrica_gate")
    info = export(objs, name, "lobby")
    bpy.ops.wm.save_as_mainfile(filepath=f"{BLEND}/{name}.blend")
    meta = {"name": name, "size_studs": [round(size.x, 2), round(size.z, 2), round(size.y, 2)], "tris": info}
    print("META", json.dumps(meta))
    if render_it:
        for o in objs:
            if o.name.endswith("_Water"): assign_mat(o, water_material())
        render_module(objs, name, size)
    return meta

def render_module(objs, name, size):
    """Studio render: deeper saturated backdrop + AgX so pastel/white pieces don't wash out; full framing."""
    az, el, *mg = CAMS.get(name, (28, 14)); mg = mg[0] if mg else 1.08
    s = setup_render((1400, 1400), 160)
    s.view_settings.view_transform = 'AgX'; s.view_settings.look = 'AgX - Punchy'
    backdrop("#5B33C9", "#A58BF5", rot_z=az, size=max(60, size.length * 4))
    lights(key=1000, rim=700, fill=140, scale=max(1.0, size.z / 3.0), center=(0, 0, size.z * .45))
    bpy.context.scene.world.node_tree.nodes["Background"].inputs[1].default_value = .35
    camera_fit(objs, az=az, el=el, lens=50, margin=mg)
    render(f"{REND}/{name}.png")

# ======================================================================= SCENE
PLOTS_Y = (-12, 42, 96)
PLAZA_X, PLAZA_Y0, PLAZA_Y1 = 58.0, -42.0, 48.0
BLVD_X0, BLVD_X1 = 58.0, 69.0
PY = -50.0                      # pasarela centreline
SHOP_Y = PLAZA_Y1 + SD / 2      # shop centre (front face on the plaza edge)
SHOP_S = 1.15
SHOP_X = (-43.4, -14.7, 14.7, 43.4)
SHOP_RZ = (12, 0, 0, -12)
SHOP_DY = (-1.8, 0, 0, -1.8)
HERO_CAM = [[12, -128, 46], [-10, 8, 7], 23]

def tex_material(name, base, scale_studs=16.0, normal_strength=1.0, rough=None):
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord"); mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (1 / scale_studs, 1 / scale_studs, 1)
    nt.links.new(tc.outputs["Object"], mp.inputs[0])
    def img(fn, cs):
        n = nt.nodes.new("ShaderNodeTexImage"); n.image = bpy.data.images.load(f"{TEX}/plaza/{fn}.png"); n.image.colorspace_settings.name = cs
        n.interpolation = 'Cubic'; nt.links.new(mp.outputs[0], n.inputs[0]); return n
    c = img(base + "_color", "sRGB"); nt.links.new(c.outputs[0], b.inputs["Base Color"])
    nm = img(base + "_normal", "Non-Color"); nmap = nt.nodes.new("ShaderNodeNormalMap"); nmap.inputs["Strength"].default_value = normal_strength
    nt.links.new(nm.outputs[0], nmap.inputs["Color"]); nt.links.new(nmap.outputs[0], b.inputs["Normal"])
    if rough: r = img(rough, "Non-Color"); nt.links.new(r.outputs[0], b.inputs["Roughness"])
    else: b.inputs["Roughness"].default_value = .7
    return m

def mosaic_material():
    m = bpy.data.materials.new("M_Mosaic"); m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    c = nt.nodes.new("ShaderNodeTexImage"); c.image = bpy.data.images.load(f"{TEX}/plaza/plaza_mosaic_color.png"); c.interpolation = 'Cubic'
    n = nt.nodes.new("ShaderNodeTexImage"); n.image = bpy.data.images.load(f"{TEX}/plaza/plaza_mosaic_normal.png"); n.image.colorspace_settings.name = "Non-Color"
    for t in (c, n): nt.links.new(tc.outputs["UV"], t.inputs[0])
    nmap = nt.nodes.new("ShaderNodeNormalMap"); nt.links.new(n.outputs[0], nmap.inputs["Color"]); nt.links.new(nmap.outputs[0], b.inputs["Normal"])
    nt.links.new(c.outputs[0], b.inputs["Base Color"]); nt.links.new(c.outputs[1], b.inputs["Alpha"])
    b.inputs["Roughness"].default_value = .35; m.blend_method = 'HASHED'
    return m

def grass_material():
    m = bpy.data.materials.new("M_Grass"); m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    tc = nt.nodes.new("ShaderNodeTexCoord")
    nz = nt.nodes.new("ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = .02; nz.inputs["Detail"].default_value = 6
    nt.links.new(tc.outputs["Object"], nz.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = .35; ramp.color_ramp.elements[0].color = (*hex2lin("#4DBE4A"), 1)
    ramp.color_ramp.elements[1].position = .7; ramp.color_ramp.elements[1].color = (*hex2lin("#86DE5A"), 1)
    nt.links.new(nz.outputs[0], ramp.inputs[0]); nt.links.new(ramp.outputs[0], b.inputs["Base Color"])
    n2 = nt.nodes.new("ShaderNodeTexNoise"); n2.inputs["Scale"].default_value = 1.5; nt.links.new(tc.outputs["Object"], n2.inputs[0])
    bp = nt.nodes.new("ShaderNodeBump"); bp.inputs["Strength"].default_value = .12
    nt.links.new(n2.outputs[0], bp.inputs["Height"]); nt.links.new(bp.outputs[0], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = .95
    return m

def flat_obj(name, poly, z0, z1, mat, bevel=.12, loc=(0, 0, 0)):
    o = slab(name, poly, thick=z1 - z0, col=mat if isinstance(mat, str) else "white", bevel=bevel, matrix=Tr(loc[0], loc[1], (z0 + z1) / 2))
    assign_mat(o, material_palette() if isinstance(mat, str) else mat); smooth(o, 30)
    return o

def rect(x0, y0, x1, y1): return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]

def scene(mode="final"):
    reset(); write_palette_textures()
    def place(name, groups, M_): return materialize(groups, name, M_)
    def T(x, y, z=0, rz=0, s=1.0): return Tr(x, y, z) @ R(rz) @ Matrix.Scale(s, 4)
    def asset(name, M_):
        objs = append_asset(name)
        for o in objs: o.matrix_world = M_ @ o.matrix_world
        return objs
    tiles = tex_material("M_Tiles", "plaza_tiles", 16, 1.0, "plaza_tiles_roughness")
    cob = tex_material("M_Cobble", "plaza_cobble", 14, 1.2, "plaza_cobble_roughness")
    # ---------------- ground: grass, plaza tiles + curb, mosaic medallion, boulevards + spurs to EVERY base
    bpy.ops.mesh.primitive_plane_add(size=3000, location=(0, 0, 0)); g = bpy.context.object; g.data.materials.append(grass_material())
    X, Y0, Y1 = PLAZA_X, PLAZA_Y0, PLAZA_Y1; cy = (Y0 + Y1) / 2
    flat_obj("curb", rrect(2 * X + 2.4, (Y1 - Y0) + 2.4, 6), 0, .45, "stone_dark", .2, loc=(0, cy))
    flat_obj("plaza", rrect(2 * X, Y1 - Y0, 5), .3, .6, tiles, .1, loc=(0, cy))
    md = cyl("mosaic", 25.2, 25.2, .02, loc=(0, 0, .6), seg=96)
    bm = bmesh.new(); bm.from_mesh(md.data); uvl = bm.loops.layers.uv.verify()
    for f in bm.faces:
        for l in f.loops: l[uvl].uv = (l.vert.co.x / 25.2 * .5 + .5, l.vert.co.y / 25.2 * .5 + .5)
    bm.to_mesh(md.data); bm.free(); assign_mat(md, mosaic_material())
    for s in (-1, 1):
        x0, x1 = sorted((s * BLVD_X0, s * BLVD_X1))
        flat_obj(f"blvd_curb{s}", rect(x0 - .6, -38.6, x1 + .6, 126.6), 0, .35, "stone_dark", .15)
        flat_obj(f"blvd{s}", rect(x0, -38, x1, 126), .2, .45, cob, .1)
        for y in PLOTS_Y:
            xa, xb = sorted((s * (BLVD_X1 - .5), s * (BLVD_X1 + 2.5)))
            flat_obj(f"spur{s}{y}", rect(xa, y - 6, xb, y + 6), .2, .45, cob, .08)
    flat_obj("shopwalk", rect(-X + 1, Y1 - 6.5, X - 1, Y1 + .2), .3, .62, cob, .1)
    flat_obj("plink", rect(-44, PY + 5.5, 48, Y0 + .8), .2, .5, cob, .1)
    # ---------------- pasarela + fabrica gate
    for k in range(4):
        place(f"Pas{k}", pasarela_seg(24.0), T(-36 + 24 * k, PY, .45))
    place("PasCap", {"": [box("pcap", (2.5, 11.2, .7), loc=(49.3, PY, .5), col="gold", bevel=.2)]}, Matrix.Identity(4))
    flat_obj("fab_pad", rect(-62, PY - 11, -47, PY + 11), 0, .45, "stone_dark", .15)
    place("Fabrica", fabrica(), T(-53.0, PY, .45, 90))
    walkers = [("estrellita", -38, "neon_green"), ("burrito", -22, "neon_green"), ("michi", -6, "neon_cyan"),
               ("cohetin", 10, "neon_cyan"), ("dragon", 25, "neon_pink"), ("renito", 40, "neon_gold")]
    for nm, x, rc in walkers:
        asset(nm, T(x, PY, .78, 20, 1.25))
        place(f"Ring_{nm}", {"Neon": [torus(f"rr_{nm}", 2.6, .16, col=rc, seg=32, mseg=6)]}, T(x, PY, .8))
    # ---------------- fountain + golden estrellita statue
    place("Fountain", fountain(), T(0, 0, .6))
    st = asset("estrellita", T(0, 0, 15.2, 0, 2.4))
    goldm = bpy.data.materials.new("M_Gold"); goldm.use_nodes = True; gb = goldm.node_tree.nodes["Principled BSDF"]
    gb.inputs["Base Color"].default_value = (*hex2lin("#FFC83D"), 1); gb.inputs["Metallic"].default_value = 1; gb.inputs["Roughness"].default_value = .22
    for o in st: o.data.materials.clear(); o.data.materials.append(goldm)
    # ---------------- shops along the back edge
    for key, x, rz, dy in zip(("dulceria", "bates", "cajas", "vip"), SHOP_X, SHOP_RZ, SHOP_DY):
        place(f"Shop_{key}", shop(key), T(x, SHOP_Y * 1.0 + SD * (SHOP_S - 1) / 2 + dy, .6, rz, SHOP_S))
    for x in (-29.0, 0, 29.0):
        place(f"AlleyLamp{x}", lamp(), T(x, Y1 - 3.5, .6))
    # ---------------- plaza furniture
    for i in range(8):
        a = math.radians(22.5 + 45 * i); r = 31.5
        x, y = r * math.cos(a), r * math.sin(a)
        if y < -20: continue
        place(f"Planter{i}", planter(), T(x, y, .6))
    for i, a in enumerate((0, 180, 90)):
        a = math.radians(a); r = 21.0
        place(f"Bench{i}", bench(), T(r * math.cos(a), r * math.sin(a), .6, math.degrees(a) + 90))
    for x, y in ((-53, -37), (53, -37), (-53, 6), (53, 6), (-24, -37), (24, -37)):
        place(f"Lamp{x}{y}", lamp(), T(x, y, .6))
    place("CartA", candy_cart(), T(-33, -26, .6, 25))
    place("CartB", candy_cart(), T(35, -24, .6, -160))
    for x, y in ((-55, -39), (55, -39)):
        place(f"PalmF{x}", palm(), T(x, y, .6, 40 if x < 0 else 200, 1.05))
    for x, y in ((-49, 26), (49, 26), (-49, -14), (49, -14)):
        place(f"Flam{x}{y}", flamboyan(), T(x, y, .6, x * 3 + y, 1.0))
    for i, (x, y, rz) in enumerate(((-40, -2, -90), (40, -2, 90), (-14, -33, 0), (14, -33, 0))):
        place(f"BenchO{i}", bench(), T(x, y, .6, rz))
    for i, (x, y) in enumerate(((-47, -28), (47, -28))):
        place(f"PlanterF{i}", planter(), T(x, y, .6, 0, .9))
    # string lights around, papel picado fanning from shop balconies over the plaza
    poles = [(-40, -38.5), (-12, -38.5), (12, -38.5), (40, -38.5), (-55, -12), (55, -12), (-55, 36), (55, 36)]
    for k, (x, y) in enumerate(poles):
        place(f"Pole{k}", light_pole(12.0), T(x, y, .6))
    top = lambda p: (p[0], p[1], 12.9)
    for a_, b_ in ((0, 1), (1, 2), (2, 3), (0, 4), (3, 5), (4, 6), (5, 7)):
        place(f"SL{a_}{b_}", string_lights(top(poles[a_]), top(poles[b_]), 2.0, name=f"sl{a_}{b_}"), Matrix.Identity(4))
    for k, x in enumerate(SHOP_X):
        place(f"PG{k}", papel_garland((x, Y1 - .9, 21.0), top(poles[k]), 4.5, name=f"pg{k}"), Matrix.Identity(4))
    rnd = random.Random(3)
    # flower hedges framing the pasarela + bushes scattered on the lawn
    F = []
    for k in range(10):
        x = -44 + k * 10.2
        F.append(lump(f"hedge{k}", 1, (0, 0, 0), "leaf_dark" if k % 2 else "leaf", seed=k, sub=2, amp=.1))
        F[-1].data.transform(Tr(x, PY - 9.6, .9) @ Matrix.Diagonal((5.0, 1.6, 1.5, 1))); F[-1].location = (0, 0, 0)
        for j in range(7):
            F += flower(f"hf{k}{j}", (x - 3.6 + j * 1.2, PY - 10.6 + (j % 2) * .6, 1.6 + (j % 3) * .25), ("fiesta_pink", "sun_yellow", "snow", "tangerine", "grape")[(j + k) % 5], s=1.1)
    for i in range(40):
        x, y = rnd.choice((-1, 1)) * rnd.uniform(75, 130), rnd.uniform(-110, -50)
        F.append(lump(f"lb{i}", rnd.uniform(1.2, 2.4), (x, y, .5), ["leaf", "leaf_dark", "lime"][i % 3], seed=i + 99, sub=2, amp=.15, squash=.75))
        for j in range(3):
            F += flower(f"lf{i}{j}", (x + rnd.uniform(-1.5, 1.5), y + rnd.uniform(-1.5, 1.5), 1.6), ("fiesta_pink", "sun_yellow", "snow")[j], s=1.0)
    place("Flowers", {"": F}, Matrix.Identity(4))
    # ---------------- 6 player plots, gates open onto the boulevards
    plot_creatures = ["toro", "torogoz", "michi", "sombra", "dragon", "burrito"]
    k = 0
    for s in (-1, 1):
        for y in PLOTS_Y:
            M_ = T(s * (BLVD_X1 + 2.5 + 29), y, 0, 90 if s < 0 else -90)
            asset("base_floor", M_ @ Tr(0, 0, .5))
            asset("base_gate", M_ @ Tr(0, -27.5, .5))
            asset("base_generator", M_ @ Tr(0, 22, .5))
            for i in range(6):
                for sx in (-1, 1): asset("base_fence", M_ @ Tr(sx * 22.5, -23 + i * 8.2, .5) @ R(90))
            for px in (-13.5, 13.5):
                asset("base_pedestal", M_ @ Tr(px, -6, .5) @ R(90 if px > 0 else -90))
            asset(plot_creatures[k], M_ @ Tr(13.5 if k % 2 else -13.5, -6, 2.15) @ Matrix.Scale(1.5, 4)); k += 1
    # ---------------- surroundings
    rnd = random.Random(3)
    for i in range(30):
        a = rnd.uniform(0, 2 * math.pi); r = rnd.uniform(150, 220)
        x, y = r * math.cos(a), r * math.sin(a)
        if y < -70: continue
        if i % 3: place(f"PalmO{i}", palm(), T(x, y, 0, rnd.uniform(0, 360), rnd.uniform(1.2, 1.6)))
        else: place(f"FlamO{i}", flamboyan(), T(x, y, 0, rnd.uniform(0, 360), rnd.uniform(1.1, 1.4)))
    for i in range(14):     # grove behind the shops (peeks above the roofs, fills the top-down)
        x = -52 + i * 8 + rnd.uniform(-2, 2); y = rnd.uniform(78, 120)
        if i % 2: place(f"PalmB{i}", palm(), T(x, y, 0, rnd.uniform(0, 360), rnd.uniform(1.3, 1.7)))
        else: place(f"FlamB{i}", flamboyan(), T(x, y, 0, rnd.uniform(0, 360), rnd.uniform(1.0, 1.3)))
    Hh = []
    for i in range(24):
        a = 2 * math.pi * i / 24 + rnd.uniform(-.1, .1); r = rnd.uniform(330, 420)
        h = lump(f"hill{i}", 1, (0, 0, 0), ["leaf", "leaf_dark", "jade"][i % 3], seed=i, sub=3, amp=.06)
        h.data.transform(Tr(r * math.cos(a), r * math.sin(a), -10) @ Matrix.Diagonal((rnd.uniform(60, 95), rnd.uniform(45, 70), rnd.uniform(28, 48), 1)))
        h.location = (0, 0, 0); Hh.append(h)
    # Izalco-style volcano (the 'Faro del Pacifico') on the horizon behind the shops + puffy clouds
    vol = lathe("volcano", [(1, 0), (.82, .18), (.55, .5), (.3, .82), (.16, .97), (.12, 1.0), (.08, .96), (.001, .94)], 48, "jade")
    vol.data.transform(Tr(-520, 980, -8) @ Matrix.Diagonal((300, 300, 190, 1)))
    cap = lathe("volcap", [(.3, .82), (.16, .97), (.12, 1.0), (.08, .96), (.001, .94)], 48, "stone_dark")
    cap.data.transform(Tr(-520, 980, -7.5) @ Matrix.Diagonal((301, 301, 190.6, 1)))
    Hh += [vol, cap]
    for i in range(9):
        a = math.radians(-35 + i * 70 / 8 + rnd.uniform(-3, 3)); r = rnd.uniform(560, 700)
        zc = rnd.uniform(60, 95)
        for j in range(4):
            Hh.append(lump(f"cl{i}{j}", rnd.uniform(14, 22), (r * math.sin(a) + j * 20 - 30, r * math.cos(a) + 300, zc + (7 if j in (1, 2) else 0)), "snow", seed=i * 7 + j, sub=2, amp=.12, squash=.6))
    place("Hills", {"": Hh}, Matrix.Identity(4))
    return finalize_scene(mode)

def finalize_scene(mode):
    s = setup_render((960, 540) if mode == "preview" else (1920, 1080), 40 if mode == "preview" else 384)
    s.view_settings.view_transform = 'AgX'; s.view_settings.look = 'AgX - Punchy'
    s.cycles.use_adaptive_sampling = True; s.cycles.adaptive_threshold = .008
    s.render.filter_size = 1.2
    s.cycles.max_bounces = 8; s.cycles.transparent_max_bounces = 16
    w = bpy.data.worlds.new("Sky"); s.world = w; w.use_nodes = True; nt = w.node_tree
    sky = nt.nodes.new("ShaderNodeTexSky"); sky.sky_type = 'NISHITA'; sky.sun_disc = False
    sky.sun_elevation = math.radians(40); sky.sun_rotation = math.radians(200); sky.altitude = 200; sky.air_density = 1.0; sky.dust_density = 1.2
    bgl = nt.nodes["Background"]; bgl.inputs[1].default_value = .3
    nt.links.new(sky.outputs[0], bgl.inputs[0])
    # what the camera sees: a clean stylised blue gradient (Nishita still lights the scene)
    lp = nt.nodes.new("ShaderNodeLightPath"); bgc = nt.nodes.new("ShaderNodeBackground"); mix = nt.nodes.new("ShaderNodeMixShader")
    tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB"); nt.links.new(sep.outputs[2], ramp.inputs[0])
    ramp.color_ramp.elements[0].position = .0; ramp.color_ramp.elements[0].color = (*hex2lin("#86D0FF"), 1)
    ramp.color_ramp.elements[1].position = .2; ramp.color_ramp.elements[1].color = (*hex2lin("#2A7CF5"), 1)
    nt.links.new(ramp.outputs[0], bgc.inputs[0]); bgc.inputs[1].default_value = .95
    out = nt.nodes["World Output"]
    nt.links.new(lp.outputs["Is Camera Ray"], mix.inputs[0]); nt.links.new(bgl.outputs[0], mix.inputs[1]); nt.links.new(bgc.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    sun = bpy.data.lights.new("Sun", 'SUN'); sun.energy = 4.0; sun.angle = math.radians(3.5); sun.color = hex2srgb("#FFE8C8")
    so = bpy.data.objects.new("Sun", sun); link(so); so.rotation_euler = (math.radians(50), 0, math.radians(-28))
    s.use_nodes = True; ct = s.node_tree
    for n in list(ct.nodes): ct.nodes.remove(n)
    rl = ct.nodes.new("CompositorNodeRLayers"); gl = ct.nodes.new("CompositorNodeGlare")
    gl.glare_type = 'FOG_GLOW'; gl.quality = 'HIGH'; gl.mix = -.85; gl.threshold = .95; gl.size = 7
    comp = ct.nodes.new("CompositorNodeComposite")
    ct.links.new(rl.outputs["Image"], gl.inputs["Image"]); ct.links.new(gl.outputs["Image"], comp.inputs["Image"])
    cd = bpy.data.cameras.new("Cam"); cam = bpy.data.objects.new("Cam", cd); link(cam); s.camera = cam
    cam.location = Vector(HERO_CAM[0]); cd.lens = HERO_CAM[2]
    cam.rotation_euler = (Vector(HERO_CAM[1]) - cam.location).to_track_quat('-Z', 'Y').to_euler()
    if mode == "preview":
        render("/tmp/plaza_preview.png"); return
    if mode == "topprev":
        topdown(s, cam, cd, preview=True); return
    bpy.ops.wm.save_as_mainfile(filepath=f"{BLEND}/lobby_hub.blend")
    if mode in ("final", "hero"): render(f"{REND}/lobby_hub.png")
    if mode in ("final", "street", "streetprev"):
        cam.location = Vector((-31, 8, 8.5)); cd.lens = 23
        cam.rotation_euler = (Vector((-15, 50, 15.5)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
        if mode == "streetprev":
            s.render.resolution_x, s.render.resolution_y = 960, 540; s.cycles.samples = 40; render("/tmp/plaza_street_preview.png"); return
        s.cycles.samples = 256; render(f"{REND}/lobby_hub_street.png")
    if mode in ("final", "top"): topdown(s, cam, cd)

def topdown(s, cam, cd, preview=False):
    cd.type = 'ORTHO'; cd.ortho_scale = 250; cam.location = (0, 42, 400); cam.rotation_euler = (0, 0, 0)
    s.render.resolution_x, s.render.resolution_y = (900, 1000) if preview else (1800, 2000)
    s.cycles.samples = 24 if preview else 128
    render("/tmp/plaza_top_preview.png" if preview else f"{REND}/lobby_hub_topdown.png")

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(MODULES) + ["scene"]
    if os.environ.get("HERO_CAM"): HERO_CAM[:] = json.loads(os.environ["HERO_CAM"])
    metas = {}
    for n in argv:
        if n in ("scene", "final"): scene("final"); continue
        if n in ("preview", "topprev", "hero", "street", "streetprev", "top"): scene(n); continue
        m = build_module(n.split(":")[1], False) if n.startswith("norender:") else build_module(n)
        metas[m["name"]] = m
    if metas:
        mf = f"{EXP}/lobby/_meta.json"; os.makedirs(f"{EXP}/lobby", exist_ok=True)
        old = json.load(open(mf)) if os.path.exists(mf) else {}
        old.update(metas); json.dump(old, open(mf, "w"), indent=1)
