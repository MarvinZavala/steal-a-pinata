"""Fase 4 - las 14 piñatas del roster de fase 1 que faltaban modelar (paleton, tortuga, pulpo, robo, cadejo).
Raras, épicas y la legendaria. Mismo pipeline que animals2.py / randoms.py: fringe_body + kawaii (plate, eyes2, mouth2...),
build2() exporta a export/creatures/<id>.fbx|.obj, guarda blend/<id>.blend y renders/<id>.png.
Solo colores de PALETTE (plib.py): la paleta ya está subida a Roblox y no se puede cambiar.
CLI: blender -b --factory-startup -P roster_b.py -- [name ...]
     PREVIEW=1 [PREVIEW_DIR=/ruta] [SAMPLES=16] -> png chico sin exportar ni tocar la paleta.
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
import creatures as C
from creatures import M, cone_prof, ellip_prof, lin_prof, limb, chain
from plib import *
import kawaii as K
from kawaii import V, eyes2, eye2, plate, mouth2, nose2, paw, blush2, bvh_of, decal, ear_inner, hit
import animals2
from animals2 import build2
from mathutils import Vector, Matrix


# ----------------------------------------------------------------------- helpers
def crom(pts, n):
    """Catmull-Rom resample of a polyline into n+1 smooth points."""
    P = [Vector(p) for p in pts]
    def cr(t):
        m = len(P) - 1; i = min(int(t * m), m - 1); u = t * m - i
        p0 = P[max(i - 1, 0)]; p1 = P[i]; p2 = P[i + 1]; p3 = P[min(i + 2, m)]
        return .5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u)
    return [cr(i / n) for i in range(n + 1)]

def oval_tube(name, pts, a, b, side, col="white", seg=10, taper=None):
    """Sweep an ellipse (a = half-width along `side`, b = half-thickness) along pts: flat paper streamer / tentacle.
    side: constant world vector (re-orthogonalised per point) or a list of vectors per point."""
    bm = bmesh.new(); rings = []; n = len(pts); P = [Vector(p) for p in pts]
    for i, p in enumerate(P):
        t = (P[min(i + 1, n - 1)] - P[max(i - 1, 0)]).normalized()
        s = Vector(side[i] if isinstance(side, list) else side)
        s = (s - t * s.dot(t)).normalized(); nn = t.cross(s).normalized()
        k = taper[i] if taper else 1
        rings.append([bm.verts.new(p + s * a * k * math.cos(2 * math.pi * j / seg) + nn * b * max(k, .5) * math.sin(2 * math.pi * j / seg)) for j in range(seg)])
    for i in range(n - 1):
        for j in range(seg):
            bm.faces.new((rings[i][j], rings[i][(j + 1) % seg], rings[i + 1][(j + 1) % seg], rings[i + 1][j]))
    bm.faces.new(list(reversed(rings[0]))); bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return paint(bm_to_obj(bm, name), col)

def twist_ribbon(name, pts, a, b, side, cols, half_turns=2, n_twist=None, taper=None, seg=5, t0=0.0):
    """Flat paper streamer swept along pts, two-tone (top face cols[0], bottom cols[1]), twisted `half_turns` x 180 deg
    over the first n_twist points (then untwisted, so a curl at the end keeps its face toward the curl centre)."""
    P = [Vector(p) for p in pts]; n = len(P); n_twist = n_twist or n
    L = [0.0]
    for i in range(1, n): L.append(L[-1] + (P[i] - P[i - 1]).length)
    Lt = L[min(n_twist, n) - 1]; L0 = Lt * t0
    halves = [bmesh.new(), bmesh.new()]; rings = [[], []]
    for i, p in enumerate(P):
        t = (P[min(i + 1, n - 1)] - P[max(i - 1, 0)]).normalized()
        sv = Vector(side[i] if isinstance(side, list) else side); sv = (sv - t * sv.dot(t)).normalized(); nv = t.cross(sv).normalized()
        u = min(max((L[i] - L0) / max(Lt - L0, 1e-6), 0.0), 1.0); u = u * u * (3 - 2 * u)
        ph = math.pi * half_turns * u
        s2 = sv * math.cos(ph) + nv * math.sin(ph); n2 = -sv * math.sin(ph) + nv * math.cos(ph)
        k = taper[i] if taper else 1
        for h in (0, 1):
            ring = []
            for j in range(seg + 1):
                th = math.pi * h + math.pi * j / seg
                ring.append(halves[h].verts.new(p + s2 * a * k * math.cos(th) + n2 * b * max(k, .6) * math.sin(th)))
            rings[h].append(ring)
    out = []
    for h in (0, 1):
        bm = halves[h]; R = rings[h]; m = seg + 1
        for i in range(n - 1):
            for j in range(m):
                bm.faces.new((R[i][j], R[i][(j + 1) % m], R[i + 1][(j + 1) % m], R[i + 1][j]))
        bm.faces.new(list(reversed(R[0]))); bm.faces.new(R[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        out.append(paint(bm_to_obj(bm, f"{name}_{h}"), cols[h]))
    return out

def squircle(n_pts, ex=4.5):
    """Unit superellipse |x|^ex + |y|^ex = 1, resampled to n_pts points evenly spaced by arc length."""
    dense = []
    for k in range(1440):
        t = 2 * math.pi * k / 1440; c, s = math.cos(t), math.sin(t)
        dense.append(Vector((math.copysign(abs(c) ** (2 / ex), c), math.copysign(abs(s) ** (2 / ex), s), 0)))
    L = [0.0]
    for i in range(1, len(dense) + 1): L.append(L[-1] + (dense[i % len(dense)] - dense[i - 1]).length)
    out = []; j = 0
    for k in range(n_pts):
        tgt = L[-1] * k / n_pts
        while L[j + 1] < tgt: j += 1
        u = (tgt - L[j]) / max(L[j + 1] - L[j], 1e-9)
        out.append(dense[j].lerp(dense[(j + 1) % len(dense)], u))
    return out

def sq_fringe(name, a, b, H, bands, colors, matrix=Matrix.Identity(4), ex=4.5, seg=40, flare=.1, tooth=.07, seed=1,
              overlap=.35, jitter=.25, core_col=None, bevel=.18):
    """Boxy crepe-paper fringe: like fringe_body but each band is a rounded-square ring (cube piñatas)."""
    rnd = random.Random(seed); objs = []
    core = box(name + "_core", (2 * a * .96, 2 * b * .96, H), loc=(0, 0, H / 2), col=core_col or colors[0], bevel=bevel, bseg=3)
    core.data.transform(core.matrix_world); core.matrix_world = Matrix.Identity(4); objs.append(core)
    n2 = seg * 2; ring = squircle(n2, ex); span = H / bands
    for bi in range(bands):
        zt = H - bi * span + span * overlap * (0 if bi == 0 else 1) - (.02 if bi == 0 else 0)
        zb = H - (bi + 1) * span
        bm = bmesh.new(); rows = []
        for ri, (z, fl) in enumerate(((zt, .995), (zb, 1 + flare))):
            row = []
            for j, u in enumerate(ring):
                zz = z; ff = fl
                if ri == 1:
                    if j % 2 == 0: zz = z - tooth * (1 + rnd.uniform(-jitter, jitter)); ff *= 1 + rnd.uniform(0, .04)
                    else: zz = z + tooth * .35
                row.append(bm.verts.new((u.x * a * ff, u.y * b * ff, zz)))
            rows.append(row)
        for j in range(n2):
            bm.faces.new((rows[1][j], rows[1][(j + 1) % n2], rows[0][(j + 1) % n2], rows[0][j]))
        o = bm_to_obj(bm, f"{name}_band{bi}"); me = o.data
        f0 = me.polygons[0]
        if (f0.center - Vector((0, 0, f0.center.z))).dot(f0.normal) < 0: me.flip_normals()
        paint(o, colors[bi % len(colors)]); objs.append(o)
    for o in objs: o.data.transform(matrix)
    return objs

def wrapped_candy(name, loc, d=(1, 0, 0), s=.25, col="fiesta_pink", wrap="bubblegum", stripe="eye_white"):
    """Bonbon: striped ellipsoid + two pleated wrapper ends along d."""
    d = Vector(d).normalized(); c = Vector(loc); P = []
    o = sphere(name, (s * 1.25, s, s), col=col, seg=18, ring=10); o.matrix_world = M(c, d) @ Matrix.Rotation(math.radians(90), 4, 'Y'); P.append(o)
    for k in (-1, 0, 1):
        t_ = torus(f"{name}st{k}", s * (.98 - .25 * abs(k)), s * .07, col=stripe, seg=18, mseg=5); t_.matrix_world = M(c + d * k * s * .55, d); P.append(t_)
    for s_ in (-1, 1):
        w = cyl(f"{name}w{s_}", s * .25, s * .85, s * .75, col=wrap, seg=10, bevel=0); w.matrix_world = M(c + d * s_ * s * 1.05, d * s_); P.append(w)
        P.append(torus(f"{name}k{s_}", s * .22, s * .08, col=col, seg=10, mseg=5)); P[-1].matrix_world = M(c + d * s_ * s * 1.12, d)
    return P

def paper_link(name, loc, axis, along, R=.13, w=.08, th=.025, col="sky", seg=14, ovl=1.35):
    """One paper-chain loop: a flat strip bent into an oval ring. axis = ring axis, along = chain direction (long side)."""
    ax = Vector(axis).normalized(); al = Vector(along); al = (al - ax * al.dot(ax)).normalized(); sd = ax.cross(al)
    bm = bmesh.new(); rows = []
    for (rr, hh) in ((R + th, -w / 2), (R + th, w / 2), (R, w / 2), (R, -w / 2)):
        rows.append([bm.verts.new(Vector(loc) + al * rr * ovl * math.cos(2 * math.pi * j / seg) + sd * rr * math.sin(2 * math.pi * j / seg) + ax * hh) for j in range(seg)])
    for i in range(4):
        a_, b_ = rows[i], rows[(i + 1) % 4]
        for j in range(seg): bm.faces.new((a_[j], a_[(j + 1) % seg], b_[(j + 1) % seg], b_[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return paint(bm_to_obj(bm, name), col)

def drop(name):
    o = bpy.data.objects.get(name)
    if o: bpy.data.objects.remove(o, do_unlink=True)

# ======================================================================= PALETÓN (rare)
def paleton():
    """RARE - 'Paletón': a giant pink & turquoise swirl lollipop whose paper-wrapped stick is its body.
    Fringe ruffle around the candy, fringe arms, winking with its tongue out (😜)."""
    P = []; G = []
    C0 = V(0, 0, 2.62); R = 1.22; T = .6
    # candy disc: fringe ruffle rim (axis +Y so the teeth point forward and frame the swirl)
    rim_prof = lambda z: R * (1 - .06 * (2 * z / T - 1) ** 2)
    P += fringe_body("rim", rim_prof, T, 3, ["hot_magenta", "turquoise", "fiesta_pink"], matrix=M(C0 + V(0, -T / 2, 0), (0, 1, 0)),
                     seg=34, flare=.1, tooth=.08, seed=2001, core_col="fiesta_pink")
    dc = C0 + V(0, -T / 2 + .03, 0); Rd = R * .95; Dy = .3
    P.append(sphere("dome", (Rd, Dy, Rd), loc=dc, col="snow", seg=36, ring=18))
    # swirl: two interleaved candy ropes lying on the dome
    tr = .105; bb = 2 * tr * .9 / math.pi
    def on_dome(r, a, lift):
        x = r * math.cos(a); z = r * math.sin(a)
        y = -Dy * math.sqrt(max(0.0, 1 - (r / Rd) ** 2))
        n = V(x / Rd ** 2, y / Dy ** 2, z / Rd ** 2).normalized()
        return dc + V(x, y, z) + n * lift
    for arm, col in ((0, "fiesta_pink"), (1, "turquoise")):
        pts = []; th = 0.0
        while True:
            r = .03 + bb * th
            if r > Rd * .9: break
            pts.append(on_dome(r, -(th + arm * math.pi), tr * .3))
            th += min(.45, .07 / max(r, .08))
        n = len(pts)
        tp = [min(1.0, .35 + 2.5 * k / n) * min(1.0, .4 + 6 * (n - 1 - k) / n) for k in range(n)]
        P.append(tube(f"swirl{arm}", pts, radius=tr, col=col, seg=8, taper=tp))
    P.append(sphere("swirlc", (.12, .08, .12), loc=on_dome(0, 0, .04), col="fiesta_pink", seg=12, ring=8))
    # back: concentric candy rings
    for k, rr in enumerate((.35, .7, 1.0)):
        P.append(torus(f"back{k}", rr, .07, loc=C0 + V(0, T / 2 + .02, 0), rot=(90, 0, 0), col="turquoise" if k % 2 else "fiesta_pink", seg=28, mseg=6))
    # face on a proxy surface at the rope-top level (so features sit on the swirl, never inside it)
    prox = sphere("_prox", (Rd + .02, Dy + tr * 1.25, Rd + .02), loc=dc, col="snow", seg=36, ring=18)
    tree = bvh_of([prox]); drop("_prox")
    hc = C0 + V(0, 0, .12)
    e, _, _ = eye2("eyeL", tree, hc + V(-.44, -3, .12), size=.36, iris="sky", lid=None, lash=True, side=-1, look=(.12, .08),
                   brow=True, brow_h=1.4, brow_tilt=-6, brow_col="ink")
    P += e
    # winking eye: happy closed arc + brow
    pts = []
    for k in range(9):
        u = -1 + 2 * k / 8
        p, n = hit(tree, hc + V(.44 + u * .3, -3, .08 + .18 * (1 - u * u)), V(0, 1, 0))
        pts.append(p + n * .05)
    P.append(tube("wink", pts, radius=.06, col="ink", seg=8, taper=[.6, .9, 1, 1, 1, 1, 1, .9, .6]))
    p, n = hit(tree, hc + V(.44, -3, .58), V(0, 1, 0))
    P.append(tube("winkbrow", [p + n * .05 + V(-.24, 0, -.03), p + n * .07 + V(0, 0, .05), p + n * .05 + V(.24, 0, .0)], radius=.05, col="ink", seg=6, taper=[.5, 1, .5]))
    # mouth + tongue sticking out
    P += mouth2("m", tree, hc + V(0, -3, -.44), w=.6, h=.27, smile=.45, col="ink", tongue=False, push=.07, depth=.08, lip="hot_magenta")
    p, n = hit(tree, hc + V(.07, -3, -.64), V(0, 1, 0))
    tg = sphere("tongue", (.19, .1, .26), col="tongue", seg=16, ring=10)
    tg.matrix_world = Matrix.Translation(p + n * .12 + V(0, 0, -.08)) @ Matrix.Rotation(math.radians(-25), 4, 'X') @ Matrix.Rotation(math.radians(-10), 4, 'Y'); P.append(tg)
    P.append(tube("tgline", [p + n * .2 + V(.03, 0, -.02), p + n * .22 + V(.06, -.03, -.2)], radius=.018, col="hot_magenta", seg=5))
    # stick body (paper-wrapped, fringe) + bow where it meets the candy
    st0 = V(0, .02, .3); st1 = V(0, .02, C0.z - R + .15)
    P += limb("stick", st0, st1, .3, .26, 4, ["snow", "white", "snow", "white"], seed=2002, seg=18, flare=.1, tooth=.05)
    bw = V(0, -.32, C0.z - R + .02)
    P.append(sphere("bowknot", (.14, .12, .12), loc=bw, col="turquoise", seg=12, ring=8))
    for s_ in (-1, 1):
        lobe = sphere(f"bowlobe{s_}", (.32, .12, .2), col="turquoise", seg=16, ring=8)
        lobe.matrix_world = Matrix.Translation(bw + V(.3 * s_, .02, .06)) @ Matrix.Rotation(math.radians(-18 * s_), 4, 'Y'); P.append(lobe)
        P.append(ribbon(f"bowtail{s_}", [bw + V(.05 * s_, 0, -.05), bw + V(.18 * s_, -.04, -.3), bw + V(.26 * s_, -.02, -.5)], width=.13, normal=(0, -1, 0), col="turquoise", thick=.04))
    # fringe arms: one waving out past the candy, one on the hip
    P += chain("armR", [V(.22, 0, 1.15), V(.85, -.12, 1.25), V(1.42, -.25, 1.72)], [.17, .16, .15], 2, ["fiesta_pink", "turquoise"], seed=2003, seg=12, flare=.14, tooth=.05)
    P += K.paw("handR", V(1.5, -.3, 1.88), fwd=(0, -1, .1), s=.22, col="snow", pad=None)
    P += limb("armL", V(-.22, 0, 1.15), V(-.78, -.1, .9), .17, .15, 3, ["fiesta_pink", "turquoise", "fiesta_pink"], seed=2004, seg=12, flare=.14, tooth=.05)
    P += K.paw("handL", V(-.86, -.12, .85), fwd=(0, -1, .2), s=.21, col="snow", pad=None)
    # little candy shoes tucked under the stick
    for s_ in (-1, 1):
        P.append(sphere(f"foot{s_}", (.25, .34, .2), loc=(.2 * s_, -.14, .17), rot=(0, 0, -10 * s_), col="turquoise", seg=16, ring=8))
        P.append(cyl(f"sole{s_}", .24, .26, .07, loc=(.2 * s_, -.14, 0), col="fiesta_pink", seg=16))
        P.append(sphere(f"toe{s_}", (.1, .06, .07), loc=(.21 * s_, -.46, .2), col="snow", seg=8, ring=5))
    return P + G, {"glow": G}


# ======================================================================= TORTUGA TAMBOR (rare)
def tortuga():
    """RARE - 'Tortuga Tambor': chubby turtle whose shell is a toy drum (gold hoops, zig-zag cords, drumhead painted
    with turtle scutes), two drumsticks strapped crossed on its back, jade crepe fringe skin."""
    P = []; G = []
    dc = V(0, .35, .98); DR = 1.2; DH = .9
    # body under the shell + 4 stubby legs
    P += fringe_body("belly", ellip_prof(1.0, 1.0, p=.6), 1.0, 2, ["jade", "lime"], matrix=M(V(0, .3, .42)), seg=22, flare=.12, tooth=.07, seed=2100, sy=1.05)
    for i, (x, y) in enumerate([(-.78, -.45), (.78, -.45), (-.78, 1.05), (.78, 1.05)]):
        P += limb(f"leg{i}", (x, y, .95), (x * 1.05, y - .05, .22), .3, .28, 3, ["jade", "lime", "jade"], seed=2110 + i, seg=12, round_end=.05)
        P += K.paw(f"foot{i}", (x * 1.05, y - .1, .2), fwd=(x * .3, -1, .35), s=.3, col="jade", pad="cream", toes=3)
    # DRUM shell: red fringe bands, gold hoops, cream zig-zag cords with gold tacks
    drum_prof = lambda z: DR * (1 - .04 * (2 * z / DH - 1) ** 2)
    P += fringe_body("drum", drum_prof, DH, 3, ["candy_red", "chili", "candy_red"], matrix=M(dc), seg=30, flare=.06, tooth=.07, seed=2101, seg_core=24)
    for k, z in enumerate((0.0, DH)):
        P.append(torus(f"hoop{k}", DR * 1.05, .1, loc=dc + V(0, 0, z), col="gold", seg=32, mseg=6))
    P.append(sphere("drumhead", (DR * 1.0, DR * 1.0, .13), loc=dc + V(0, 0, DH), col="cream", seg=30, ring=10))
    NZ = 8; zz = []
    for k in range(NZ * 2 + 1):
        a = 2 * math.pi * k / (NZ * 2) + .2
        zz.append(dc + V(DR * 1.11 * math.cos(a), DR * 1.11 * math.sin(a), DH - .1 if k % 2 == 0 else .1))
    P.append(tube("cords", zz, radius=.04, col="cream", seg=6))
    for k, q in enumerate(zz[:-1]):
        P.append(sphere(f"tack{k}", (.07, .07, .07), loc=q, col="gold_deep", seg=8, ring=5))
    # turtle scutes painted on the drumhead
    top = dc.z + DH
    def on_head(x, y): return top + .13 * math.sqrt(max(0.0, 1 - (x * x + y * y) / DR ** 2)) - .015
    hexp = [(.27 * math.cos(math.pi / 6 + k * math.pi / 3), .27 * math.sin(math.pi / 6 + k * math.pi / 3)) for k in range(6)]
    for k, (ox, oy) in enumerate([(0, 0)] + [(.54 * math.cos(k * math.pi / 3), .54 * math.sin(k * math.pi / 3)) for k in range(6)]):
        P.append(slab(f"scute{k}", hexp, thick=.04, col="jade" if k == 0 else "mint", bevel=.012, bseg=1, matrix=Matrix.Translation((dc.x + ox, dc.y + oy, on_head(ox, oy)))))
    # neck + big head
    P += limb("neck", V(0, -.5, 1.0), V(0, -1.05, 1.8), .44, .4, 2, ["jade", "lime"], seed=2120, seg=14)
    hc = V(0, -1.32, 2.32)
    P += fringe_body("head", ellip_prof(.92, 1.6, p=1.15), 1.6, 4, ["jade", "jade", "lime", "jade"], matrix=M(hc - V(0, -.05, .78), (0, -.12, 1)),
                     seg=28, flare=.09, tooth=.065, seed=2121, sx=1.1)
    fp = plate("face", hc + V(0, 0, .06), r=(.82, .5, .62), col="jade", fwd_off=.56); P.append(fp)
    mz = plate("muzzle", hc + V(0, 0, -.33), r=(.58, .34, .32), col="mint", fwd_off=.82); P.append(mz)
    tree = bvh_of([fp, mz])
    P += eyes2("e", tree, hc + V(0, 0, .16), dx=.38, dz=0, size=.3, iris="chocolate", lid=None, lash=True, look=(0, .08))
    P += mouth2("m", tree, hc + V(0, -3, -.3), w=.4, h=.17, smile=1.1, col="ink", tongue=True, push=.03)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.6 * s_, -3, -.14), size=.13)
    # drumsticks strapped crossed on its back
    bk = dc + V(0, DR * 1.1, DH * .55)
    for s_ in (-1, 1):
        a = bk + V(-.62 * s_, .02, -.35); b = bk + V(.72 * s_, .3, 1.75)
        P.append(cyl(f"stick{s_}", .065, .05, (b - a).length, col="wood", seg=10)); P[-1].matrix_world = M(a, b - a)
        P.append(sphere(f"stickball{s_}", (.14, .14, .14), loc=b + (b - a).normalized() * .06, col="candy_red", seg=12, ring=8))
    P.append(torus("strap", DR * 1.17, .06, loc=(dc.x, dc.y, bk.z + .08), rot=(0, 0, 90 - 34), col="sun_yellow", seg=14, mseg=6, arc=68))
    P.append(box("buckle", (.24, .1, .24), loc=(dc.x, dc.y + DR * 1.17 + .04, bk.z + .08), col="gold", bevel=.03))
    P.append(cyl("tail", .2, .02, .5, col="jade", seg=10)); P[-1].matrix_world = M(V(0, 1.45, .62), (0, 1, -.25))
    return P + G, {"glow": G}

# ======================================================================= PULPO CONFETI (epic)
def pulpo():
    """EPIC - 'Pulpo Confeti': purple paper octopus whose 8 tentacles are twisted two-tone streamers (serpentinas) ending in curls;
    in a party hat, one tentacle fires a party popper and another tosses a handful of neon confetti."""
    P = []; G = []
    rnd = random.Random(2201)
    mb = V(0, .15, .92)
    P += fringe_body("mantle", ellip_prof(1.2, 2.45, p=1.1), 2.45, 6, ["grape", "lavender", "grape", "candy_violet", "grape", "lavender"],
                     matrix=M(mb, (0, .12, 1)), seg=28, flare=.09, tooth=.07, seed=2201, sy=.95)
    hc = V(0, -.05, 2.02)
    fp = plate("face", hc, r=(.94, .5, .68), col="grape", fwd_off=.74); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .12), dx=.41, dz=0, size=.3, iris="turquoise", lid=None, lash=True,
               brow=True, brow_h=1.55, brow_tilt=8, brow_arch=.3, brow_col="cosmic_1", look=(.05, .3))
    P += mouth2("m", tree, hc + V(0, -3, -.4), w=.54, h=.32, smile=.6, col="ink", tongue=True)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.66 * s_, -3, -.2), size=.13, col="fiesta_pink")
    mt = bvh_of([o for o in P if o.name.startswith("mantle")])
    for k in range(8):   # paper spots on the mantle
        a = rnd.uniform(.5, 2.6) * (1 if k % 2 else -1) + math.pi / 2; z = rnd.uniform(2.45, 3.15)
        d = V(math.cos(a), math.sin(a), .3).normalized()
        p, n = hit(mt, V(0, .2, z) + d * 3, -d)
        if p is not None:
            sp = sphere(f"spot{k}", (.11, .11, .03), col="lavender", seg=8, ring=4); sp.matrix_world = M(p + n * .02, n); P.append(sp)
    # party hat
    hb = V(.2, .22, 3.2); hd = V(.25, .05, 1).normalized()
    hat = cyl("hat", .5, .03, 1.05, col="fiesta_pink", seg=20, bevel=.02); hat.matrix_world = M(hb, hd); P.append(hat)
    sp = []
    for k in range(34):
        t = k / 33; a = t * 3 * 2 * math.pi; r = .5 * (1 - t) + .035
        sp.append(M(hb, hd) @ V(r * math.cos(a), r * math.sin(a), t * 1.05))
    P.append(tube("hatstripe", sp, radius=.06, col="sun_yellow", seg=6, taper=[1 - .6 * k / 33 for k in range(34)]))
    P.append(sphere("hatpom", (.17, .17, .17), loc=hb + hd * 1.1, col="sun_yellow", seg=12, ring=8))
    P += fringe_body("hatfr", lambda z: .58, .16, 1, ["turquoise"], matrix=M(hb - hd * .02, hd), seg=20, flare=.18, tooth=.07, seed=2202)
    # 6 ground tentacles: twisted streamers splayed on the floor, each ending in a curl
    base = V(0, .18, 1.0)
    def tentacle(name, ang, reach, cols, curl_r=.36, turns=1.2, half_turns=3):
        d = V(math.cos(ang), math.sin(ang), 0); s = d.cross(V(0, 0, 1))
        ctrl = [base + d * .55 + V(0, 0, .0), base + d * (.55 + reach * .3) + V(0, 0, -.58),
                base + d * (.55 + reach * .65) + V(0, 0, -.86), base + d * (.55 + reach) + V(0, 0, -.9)]
        pts = crom(ctrl, 12); nt = len(pts)
        tip = pts[-1]; tdir = (pts[-1] - pts[-2]).normalized(); up = s.cross(tdir).normalized()
        if up.z < 0: up = -up
        cc = tip + up * curl_r
        for k in range(1, 19):
            ph = -math.pi / 2 + 2 * math.pi * turns * k / 18; r = curl_r * (1 - .68 * k / 18)
            pts.append(cc + tdir * r * math.cos(ph) + up * r * math.sin(ph))
        n = len(pts); tp = [1.0 - .55 * (k / (n - 1)) for k in range(n)]
        return twist_ribbon(name, pts, .3, .09, s, cols, half_turns=half_turns, n_twist=nt, taper=tp, t0=.35, seg=6)
    ground = [(-2.45, 1.15), (-1.95, 1.3), (-1.35, 1.35), (-.75, 1.25), (-.2, 1.1), (.9, 1.0)]
    for i, (a, rch) in enumerate(ground):
        P += tentacle(f"t{i}", a, rch, ["lavender", "grape"] if i % 2 == 0 else ["lavender", "candy_violet"], half_turns=0)
    # 2 raised tentacles: left tosses confetti, right fires a party popper
    def raised(name, sx):
        ctrl = [base + V(.75 * sx, -.1, .15), base + V(1.3 * sx, -.25, .45), base + V(1.62 * sx, -.3, 1.3), base + V(1.55 * sx, -.35, 2.15)]
        pts = crom(ctrl, 12); nt = len(pts)
        tip = pts[-1]; cc = tip + V(-sx * .24, 0, 0)
        for k in range(1, 14):
            ph = math.pi * (0 if sx > 0 else 1) + (1 if sx > 0 else -1) * 1.45 * math.pi * k / 13
            r = .24 * (1 - .4 * k / 13)
            pts.append(cc + V(r * math.cos(ph), 0, r * math.sin(ph)))
        n = len(pts); tp = [1.0 - .5 * (k / (n - 1)) for k in range(n)]
        return twist_ribbon(name, pts, .23, .13, V(0, 1, 0), ["grape", "lavender"], half_turns=0, n_twist=nt, taper=tp, seg=6), pts
    o, lp = raised("tL", -1); P += o
    o, rp = raised("tR", 1); P += o
    # party popper held in the right curl
    pp = rp[-6] + V(.02, -.05, .1); pd = V(.3, -.3, 1).normalized()
    pop = cyl("popper", .08, .28, .62, col="sun_yellow", seg=16, bevel=.02); pop.matrix_world = M(pp - pd * .2, pd); P.append(pop)
    for k, (t, rr) in enumerate(((.25, .15), (.48, .22))):
        P.append(torus(f"popst{k}", rr + .01, .03, col="fiesta_pink", seg=16, mseg=4)); P[-1].matrix_world = M(pp - pd * .2 + pd * t, pd)
    mouth_ = pp - pd * .2 + pd * .64
    # streamers shooting out of the popper (main mesh, party colours)
    side = pd.cross(V(0, -1, 0)).normalized()
    for k, col in enumerate(("fiesta_pink", "turquoise", "lime", "sun_yellow")):
        a0 = math.radians(-50 + 33 * k)
        dirk = (pd * math.cos(a0 * .6) + side * math.sin(a0 * .6)).normalized()
        sp = []
        for j in range(22):
            t = j / 21
            c = mouth_ + dirk * (.08 + .95 * t) + V(0, 0, -.3 * t * t)
            sp.append(c + side * .08 * math.cos(t * 13 + k) + V(0, 0, .08 * math.sin(t * 13 + k)))
        P.append(oval_tube(f"serp{k}", sp, .055, .015, side.cross(dirk), col=col, seg=6))
    # neon confetti (glow): burst from the popper + handful tossed by the left tentacle + a few on the floor
    def confetto(name, p, kind, sc=1.0):
        rot = (rnd.uniform(0, 180), rnd.uniform(0, 180), rnd.uniform(0, 180))
        if kind == 0: return box(name, (.15 * sc, .07 * sc, .02), loc=p, rot=rot, col="lavender", bevel=0)
        if kind == 1: return cyl(name, .065 * sc, .065 * sc, .02, loc=p, rot=rot, col="lavender", seg=8)
        return star_prism(name, 5, .1 * sc, .045 * sc, .025, loc=p, rot=rot, col="lavender", bevel=0)
    for k in range(20):
        t = rnd.uniform(.15, 1.0); spread = .6 * t
        p = mouth_ + pd * (1.25 * t) + side * rnd.uniform(-spread, spread) + V(0, rnd.uniform(-spread, spread) * .5, rnd.uniform(-spread, spread) * .6)
        G.append(confetto(f"cfR{k}", p, k % 3))
    lt = lp[-4]
    for k in range(18):
        a = rnd.uniform(0, 2 * math.pi); r = rnd.uniform(.2, .8)
        p = lt + V(r * math.cos(a) * .9 - .15, rnd.uniform(-.35, .2), .35 + abs(r * math.sin(a)) * 1.1)
        G.append(confetto(f"cfL{k}", p, k % 3))
    for k in range(10):
        a = rnd.uniform(-math.pi, 0); r = rnd.uniform(1.0, 2.1)
        G.append(confetto(f"cfG{k}", V(r * math.cos(a), r * math.sin(a) * .9 - .1, .02), k % 3))
    return P + G, {"glow": G}

# ======================================================================= ROBO-PIÑATA (epic)
LED_EYE = [".##.", "####", "####", "####", "####", ".##."]
LED_MOUTH = ["#....#", ".####."]

def led(name, rows, center, pitch, size, y, col):
    out = []; h = len(rows); w = len(rows[0])
    for r, line in enumerate(rows):
        for c, ch in enumerate(line):
            if ch != "#": continue
            x = center.x + (c - (w - 1) / 2) * pitch; z = center.z + ((h - 1) / 2 - r) * pitch
            out.append(box(f"{name}{r}_{c}", (size, .05, size), loc=(x, y, z), col=col, bevel=.012, bseg=1))
    return out

def robo():
    """EPIC - 'Robo-Piñata': boxy robot made of silver crepe fringe, a wrapped candy on its spring antenna,
    a TV-screen face with LED pixel eyes (neon) and a porthole belly full of candy."""
    P = []; G = []
    # feet + accordion legs
    for s_ in (-1, 1):
        x = .4 * s_
        P.append(box(f"foot{s_}", (.5, .72, .3), loc=(x, -.1, .15), col="fiesta_pink", bevel=.12, bseg=3))
        P.append(cyl(f"leg{s_}", .13, .13, .4, loc=(x, 0, .25), col="steel", seg=12))
        for k in range(2): P.append(torus(f"legr{s_}{k}", .15, .05, loc=(x, 0, .38 + .13 * k), col="silver", seg=14, mseg=6))
    bz = .58; ba, bb, bh = .74, .6, 1.08
    P += sq_fringe("body", ba, bb, bh, 3, ["silver", "steel", "silver"], matrix=Matrix.Translation((0, .02, bz)), seg=36, flare=.08, tooth=.07, seed=2301, core_col="steel")
    # candy porthole on the belly
    wc = V(0, -bb * 1.09 - .02, bz + .52)
    P.append(torus("port", .3, .07, col="fiesta_pink", seg=24, mseg=8)); P[-1].matrix_world = M(wc, (0, -1, 0))
    P.append(cyl("portbg", .3, .3, .05, col="ink_soft", seg=20)); P[-1].matrix_world = M(wc + V(0, .03, 0), (0, -1, 0))
    for k, (x, z, col) in enumerate(((-.1, -.1, "sun_yellow"), (.1, -.12, "turquoise"), (0, .08, "lime"), (-.14, .1, "fiesta_pink"), (.14, .08, "candy_red"), (0, -.2, "mango"))):
        P.append(sphere(f"gum{k}", (.1, .1, .1), loc=wc + V(x, -.02, z), col=col, seg=10, ring=6))
    P.append(sphere("portglint", (.06, .02, .1), loc=wc + V(-.17, -.1, .14), rot=(0, -30, 0), col="eye_white", seg=8, ring=5))
    # wind-up key on the back (toy robot)
    kc = V(0, bb * 1.08 + .02, bz + .6)
    P.append(cyl("keyshaft", .07, .07, .32, col="steel", seg=10)); P[-1].matrix_world = M(kc, (0, 1, 0))
    hub = kc + V(0, .4, 0)
    P.append(sphere("keyhub", (.12, .13, .12), loc=hub, col="fiesta_pink", seg=12, ring=8))
    KM = Matrix.Translation(hub + V(0, .08, 0)) @ Matrix.Rotation(math.radians(20), 4, 'Y') @ Matrix.Rotation(math.radians(90), 4, 'Y')
    for s_ in (-1, 1):
        P.append(torus(f"keylobe{s_}", .18, .07, col="fiesta_pink", seg=16, mseg=6)); P[-1].matrix_world = KM @ Matrix.Translation((.26 * s_, 0, 0))
    P.append(cyl("neck", .26, .26, .3, loc=(0, .02, bz + bh - .05), col="steel", seg=14))
    P.append(torus("neckr", .27, .05, loc=(0, .02, bz + bh + .14), col="silver", seg=16, mseg=6))
    # head: big boxy fringe
    hz = bz + bh + .2; ha, hb, hh = 1.1, .86, 1.5
    P += sq_fringe("head", ha, hb, hh, 4, ["silver", "steel", "silver", "steel"], matrix=Matrix.Translation((0, 0, hz)), seg=44, flare=.07, tooth=.07, seed=2302, core_col="steel")
    sc = V(0, 0, hz + hh * .5 - .02); fy = -hb * 1.08
    P.append(box("bezel", (1.78, .14, 1.16), loc=(sc.x, fy - .03, sc.z), col="fiesta_pink", bevel=.16, bseg=3))
    P.append(box("screen", (1.56, .12, .96), loc=(sc.x, fy - .09, sc.z), col="ink", bevel=.12, bseg=3))
    sy = fy - .16
    for s_ in (-1, 1):
        G += led(f"eye{s_}", LED_EYE, sc + V(.36 * s_, 0, .1), .09, .076, sy, "lavender")
        P.append(box(f"eyehl{s_}", (.07, .05, .07), loc=(.36 * s_ - .09, sy - .03, sc.z + .1 + .16), col="eye_white", bevel=.012, bseg=1))
        P += led(f"cheek{s_}", ["##"], sc + V(.64 * s_, 0, -.22), .088, .074, sy, "fiesta_pink")
    G += led("mouth", LED_MOUTH, sc + V(0, 0, -.27), .075, .064, sy, "lavender")
    for k, (w, x, z) in enumerate(((.18, .62, .37), (.08, .7, .27))):
        P.append(box(f"glint{k}", (w, .03, .04), loc=(sc.x + x, sy - .005, sc.z + z), rot=(0, -40, 0), col="eye_white", bevel=0))
    for k, (x, z) in enumerate(((-.8, .49), (.8, .49), (-.8, -.49), (.8, -.49))):
        sw = cyl(f"screw{k}", .045, .045, .04, col="silver", seg=8); sw.matrix_world = M(V(sc.x + x, fy - .1, sc.z + z), (0, -1, 0)); P.append(sw)
    # ears (side bolts)
    for s_ in (-1, 1):
        e = cyl(f"ear{s_}", .27, .27, .22, col="fiesta_pink", seg=20, bevel=.05); e.matrix_world = M(V(ha * 1.02 * s_, 0, sc.z + .05), (s_, 0, 0)); P.append(e)
        b_ = cyl(f"earb{s_}", .12, .1, .16, col="silver", seg=14, bevel=.03); b_.matrix_world = M(V((ha * 1.02 + .2) * s_, 0, sc.z + .05), (s_, 0, 0)); P.append(b_)
    # antenna with a spring and a wrapped candy on top
    tz = hz + hh
    P.append(cyl("antb", .17, .14, .14, loc=(0, 0, tz - .02), col="silver", seg=14, bevel=.03))
    hel = [V(.09 * math.cos(t * 2 * math.pi * 4), .09 * math.sin(t * 2 * math.pi * 4), tz + .12 + .42 * t) for t in [k / 48 for k in range(49)]]
    P.append(tube("spring", hel, radius=.028, col="steel", seg=6))
    P.append(cyl("rod", .03, .03, .3, loc=(0, 0, tz + .5), col="silver", seg=8))
    P += wrapped_candy("candy", V(0, 0, tz + .98), d=(1, 0, .12), s=.22, col="fiesta_pink", wrap="bubblegum", stripe="eye_white")
    # slinky arms: left waves hello, right hangs down
    def slinky(name, pts, n=11):
        pts = crom(pts, n * 3); out = []
        for k in range(n):
            i = int(k * (len(pts) - 1) / (n - 1)); i0, i1 = max(i - 1, 0), min(i + 1, len(pts) - 1)
            t_ = (pts[i1] - pts[i0]).normalized()
            out.append(torus(f"{name}{k}", .14, .055, col="silver" if k % 2 else "steel", seg=14, mseg=6)); out[-1].matrix_world = M(pts[i], t_)
        return out
    P += slinky("armR", [V(.74, .02, bz + .82), V(1.2, -.1, bz + 1.0), V(1.62, -.3, bz + 1.5), V(1.72, -.4, bz + 2.0)])
    P += K.paw("handR", V(1.74, -.44, bz + 2.2), fwd=(0, -1, .15), s=.24, col="fiesta_pink", pad=None)
    P += slinky("armL", [V(-.74, .02, bz + .82), V(-1.08, -.08, bz + .55), V(-1.15, -.2, bz + .05)], n=8)
    P += K.paw("handL", V(-1.15, -.24, bz - .12), fwd=(0, -1, .25), s=.22, col="fiesta_pink", pad=None)
    return P + G, {"glow": G}

# ======================================================================= CADEJO (legendary)
def wisp(name, base, d, L, col, r=.16, curl=1.0, side=(1, 0, 0), n=12):
    """Soft ghost-flame lick: thick tapered tube that bends and curls over at the end (blunt round tip)."""
    d = Vector(d).normalized(); sd = Vector(side); sd = (sd - d * sd.dot(d)).normalized(); pts = []
    for j in range(n + 1):
        t = j / n; ang = curl * 2.2 * t * t
        dirv = d * math.cos(ang) + sd * math.sin(ang)
        pts.append((pts[-1] + dirv * L / n) if pts else Vector(base))
    tp = [max(.22, 1 - .78 * (j / n) ** 1.4) for j in range(n + 1)]
    o = tube(name, pts, radius=r, col=col, seg=10, taper=tp)
    return [o, sphere(name + "e", (r * .24,) * 3, loc=pts[-1], col=col, seg=8, ring=6)]

def cadejo():
    """LEGENDARY - 'Cadejo': the good white spirit-dog of Central American folklore, guardian of night walkers.
    Floppy ears, light-blue eyes, ghost-flame forelock + plume tail, paper-chain collar with a little gold moon."""
    P = []; G = []
    body = fringe_body("body", ellip_prof(.95, 2.0, p=.75), 2.0, 6, ["snow", "white", "snow", "lavender", "snow", "white"],
                       matrix=M((0, .1, .05)), seg=26, flare=.11, tooth=.08, seed=2401, sy=.92)
    P += body
    hc = V(0, -.08, 2.68)
    P += fringe_body("head", ellip_prof(1.0, 1.72, p=.95), 1.72, 5, ["snow", "snow", "white", "snow", "lavender"],
                     matrix=M(hc - V(0, 0, .84)), seg=28, flare=.1, tooth=.07, seed=2402, sx=1.12, sy=.96)
    fp = plate("face", hc + V(0, 0, .04), r=(.86, .5, .64), col="snow", fwd_off=.62); P.append(fp)
    mz = plate("muzzle", hc + V(0, 0, -.33), r=(.48, .36, .3), col="white", fwd_off=1.0); P.append(mz)
    tree = bvh_of([fp, mz])
    P += eyes2("e", tree, hc + V(0, 0, .12), dx=.4, dz=0, size=.31, iris="neon_cyan", lid=None, lash=True, look=(0, .08))
    for s_ in (-1, 1):   # shiba-style eyebrow dots
        P += K.decal(f"maro{s_}", tree, hc + V(.36 * s_, -3, .56), r=(.1, .07), col="lavender", roll=-15 * s_)
        P += blush2(f"bl{s_}", tree, hc + V(.62 * s_, -3, -.2), size=.13)
    p, n = hit(tree, hc + V(0, -3, .58), V(0, 1, 0))
    st = star_prism("mark", 4, .13, .045, .04, col="sky", bevel=.01); st.matrix_world = M(p + n * .03, n); P.append(st)
    P += nose2("nose", tree, hc + V(0, -3, -.18), size=.13, col="ink", shape="round")
    P += mouth2("m", tree, hc + V(0, -3, -.42), w=.34, h=.2, smile=.9, col="ink", tongue=True)
    # floppy ears hanging outside the head (rounded leaf profile, flattened)
    ear_prof = lambda z: .4 * max(0.0, 1 - ((z / 1.05) - .55) ** 2 / .3025) ** .5 + .03
    for s_ in (-1, 1):
        base = hc + V(.8 * s_, .05, .72); d = V(.95 * s_, -.12, -.75)
        P += fringe_body(f"ear{s_}", ear_prof, 1.05, 3, ["lavender", "white", "snow"], matrix=M(base, d, roll=90), seg=14, flare=.1, tooth=.05, seed=2410 + s_, sy=.42)
        P.append(K.ear_inner(f"earin{s_}", base + d.normalized() * .05, d, .42, .17, col="lavender", out=(s_ * .25, -1, 0), off=.13))
    # legs: front legs + paws, chubby haunches
    for s_ in (-1, 1):
        P += limb(f"arm{s_}", (.45 * s_, -.45, 1.25), (.42 * s_, -.7, .38), .26, .23, 3, ["snow", "white", "snow"], seed=2420 + s_, seg=12)
        P += paw(f"paw{s_}", (.42 * s_, -.76, .22), fwd=(0, -1, .5), s=.3, col="snow", pad="lavender")
        P.append(sphere(f"haunch{s_}", (.42, .55, .42), loc=(.72 * s_, .2, .45), col="snow", seg=14, ring=8))
        P += paw(f"bpaw{s_}", (.8 * s_, -.32, .17), fwd=(0, -1, .3), s=.26, col="snow", pad=None)
    # big fluffy plume tail curling up behind (camera side), fading into a ghost-flame tip
    tb = V(.45, .85, .35); td = V(.6, .4, 1).normalized()
    P += fringe_body("tail", ellip_prof(.42, 1.55, p=.8), 1.55, 4, ["snow", "white", "snow", "lavender"], matrix=M(tb, td), seg=18, flare=.14, tooth=.08, seed=2430)
    tt = tb + td * 1.5
    P.append(sphere("tailtip", (.2, .2, .22), loc=tt, col="lavender", seg=12, ring=8))
    P += wisp("tw0", tt + V(0, 0, .1), (.1, -.3, 1), .6, "sky", r=.21, curl=1.1, side=(-1, 0, 0))
    P += wisp("tw1", tt + V(.1, .05, .05), (.6, .2, 1), .42, "lavender", r=.15, curl=1.0, side=(1, 0, 0))
    # paper chain collar + dangling moon charm
    cz = hc.z - .9; CR = .9; NL = 18
    cols = ["sky", "lavender", "mint"]
    for k in range(NL):
        a = 2 * math.pi * k / NL; rd = V(math.cos(a), math.sin(a), 0); tg = V(-math.sin(a), math.cos(a), 0)
        P.append(paper_link(f"lk{k}", V(0, 0, cz) + rd * CR, rd if k % 2 else V(0, 0, 1), tg, R=.12, w=.09, col=cols[k % 3], seg=8))
    ch0 = V(0, -CR, cz)
    for j in range(3):
        P.append(paper_link(f"dl{j}", ch0 + V(0, -.04, -.26 * (j + 1)), V(0, -1, 0) if j % 2 == 0 else V(1, 0, 0), V(0, 0, 1), R=.1, w=.08, col=cols[(j + 1) % 3], seg=8))
    mc = ch0 + V(0, -.08, -1.18)
    moon = [(.24 * math.cos(math.radians(a)), .24 * math.sin(math.radians(a))) for a in range(60, 301, 20)]
    moon += [(.1 + .19 * math.cos(math.radians(a)), .19 * math.sin(math.radians(a))) for a in range(280, 79, -20)]
    P.append(slab("moon", moon, thick=.08, col="gold", bevel=.025, matrix=Matrix.Translation(mc) @ Matrix.Rotation(math.radians(90), 4, 'X') @ Matrix.Rotation(math.radians(-20), 4, 'Z')))
    # floating spirit sparkles
    for k, (p, col, s_) in enumerate(((V(-1.45, -.3, 3.55), "sky", .2), (V(1.6, -.4, 3.5), "neon_cyan", .15), (V(-1.35, -.5, 2.0), "lavender", .13))):
        P.append(star_prism(f"spark{k}", 4, s_, s_ * .3, s_ * .25, loc=p, rot=(90, 0, 10 * k), col=col, bevel=0))
    return P + G, {"glow": []}

REG = {"paleton": paleton, "tortuga": tortuga, "pulpo": pulpo, "robo": robo, "cadejo": cadejo}
REG_RARITY = {"paleton": "rare", "tortuga": "rare", "pulpo": "epic", "robo": "epic", "cadejo": "legendary"}
REG_CAM = {"tortuga": (30, 20)}
C.CREATURES.update(REG); C.RARITY.update(REG_RARITY); C.CAM.update(REG_CAM)

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    prev = os.environ.get("PREVIEW")
    metas = []
    for n in (argv or list(REG)):
        if prev:
            out = os.environ.get("PREVIEW_DIR", "/tmp/prev")
            os.makedirs(out, exist_ok=True)
            animals2.write_palette_textures = lambda: None   # la paleta ya está en art/textures; no reescribirla
            metas.append(build2(n, samples=int(os.environ.get("SAMPLES", "16")), res=(700, 700), out=f"{out}/{n}.png"))
        else:
            metas.append(build2(n, samples=int(os.environ.get("SAMPLES", "96"))))
    if not prev:
        mf = f"{ROOT}/export/creatures/_meta.json"; old = json.load(open(mf))
        for m in metas: old[m["name"]] = m
        json.dump(old, open(mf, "w"), indent=1)
