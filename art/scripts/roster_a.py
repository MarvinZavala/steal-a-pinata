"""Fase 4 - las 14 piñatas del roster de fase 1 que faltaban modelar (pollito, sandia, elotito, ranita, pupusita).
Comunes y poco comunes: las que más salen en la Pasarela. Mismo pipeline que animals2.py / randoms.py: fringe_body + kawaii (plate, eyes2, mouth2...),
build2() exporta a export/creatures/<id>.fbx|.obj, guarda blend/<id>.blend y renders/<id>.png.
Solo colores de PALETTE (plib.py): la paleta ya está subida a Roblox y no se puede cambiar.
CLI: blender -b --factory-startup -P roster_a.py -- [name ...]
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
def MB(loc, zdir, yhint=(0, 0, 1)):
    """Frame matrix: local +Z -> zdir, local +Y -> yhint (orthogonalised). Lets fringe_body sx/sy flatten on a known axis."""
    z = Vector(zdir).normalized(); y = Vector(yhint)
    y = (y - z * y.dot(z))
    if y.length < 1e-4: y = Vector((0, 1, 0)) - z * z.y
    y.normalize(); x = y.cross(z).normalized()
    m = Matrix((x, y, z)).transposed().to_4x4(); m.translation = Vector(loc)
    return m

def pompom(name, loc, r, cols, seed=0, bands=3, seg=14, squash=1.0):
    """Little fringe ball (pom-pom foot / tuft)."""
    H = 2 * r * squash
    return fringe_body(name, ellip_prof(r, H, p=.9), H, bands, cols, matrix=M(Vector(loc) - V(0, 0, H / 2)), seg=seg, flare=.16, tooth=.05, seed=seed, rings_core=6, seg_core=14)

def smooth_pts(pts, n=10):
    """Catmull-Rom resample so tubes curve smoothly."""
    P = [Vector(p) for p in pts]; out = []
    for i in range(n + 1):
        t = i / n; k = len(P) - 1; j = min(int(t * k), k - 1); u = t * k - j
        p0 = P[max(j - 1, 0)]; p1 = P[j]; p2 = P[j + 1]; p3 = P[min(j + 2, k)]
        out.append(.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u * u + (-p0 + 3 * p1 - 3 * p2 + p3) * u * u * u))
    return out

def taper_list(n, prof):
    return [prof(i / (n - 1)) for i in range(n)]

def _sq(a, w, d, n):
    """Superellipse point + outward normal (half-width w along x, half-depth d along y)."""
    c, s = math.cos(a), math.sin(a)
    x = w * math.copysign(abs(c) ** (2 / n), c); y = d * math.copysign(abs(s) ** (2 / n), s)
    gx = (abs(x / w) ** (n - 1)) * math.copysign(1, x) / w if w > 1e-6 else 0
    gy = (abs(y / d) ** (n - 1)) * math.copysign(1, y) / d if d > 1e-6 else 0
    g = Vector((gx, gy, 0)); g = g.normalized() if g.length > 1e-9 else Vector((c, s, 0))
    return Vector((x, y, 0)), g

def fringe_sq(name, wfun, dfun, H, bands, colors, matrix=Matrix.Identity(4), seg=30, flare=.09, tooth=.07, n=4.0,
              seed=1, overlap=.35, rings_core=14, seg_core=28, core_col=None, jitter=.25):
    """fringe_body with a squircle cross-section (flat-ish front/back faces): half-width wfun(z), half-depth dfun(z).
    flare is absolute (studs) so the teeth lift evenly off the flat faces."""
    rnd = random.Random(seed); objs = []
    bm = bmesh.new(); rings = []
    zs = [H * i / rings_core for i in range(rings_core + 1)]
    for z in zs:
        w, d = max(wfun(z), 1e-4), max(dfun(z), 1e-4)
        ring = []
        for j in range(seg_core):
            p, g = _sq(2 * math.pi * j / seg_core, w, d, n)
            q = p - g * min(.05, w * .3, d * .3); q.z = z; ring.append(bm.verts.new(q))
        rings.append(ring)
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for j in range(seg_core): bm.faces.new((a[j], a[(j + 1) % seg_core], b[(j + 1) % seg_core], b[j]))
    bot = bm.verts.new((0, 0, 0)); topv = bm.verts.new((0, 0, H))
    for j in range(seg_core):
        bm.faces.new((rings[0][(j + 1) % seg_core], rings[0][j], bot)); bm.faces.new((rings[-1][j], rings[-1][(j + 1) % seg_core], topv))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5); bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    core = bm_to_obj(bm, name + "_core"); paint(core, core_col or colors[0]); objs.append(core)
    span = H / bands; n2 = seg * 2
    for b in range(bands):
        zt = H - b * span + span * overlap * (0 if b == 0 else 1); zb = H - (b + 1) * span
        bm = bmesh.new(); rows = []
        phase = rnd.random() * math.pi * 2 / n2
        for ri, z in enumerate((min(zt, H), zb)):
            w, d = max(wfun(max(z, 0)), 1e-4), max(dfun(max(z, 0)), 1e-4)
            row = []
            for j in range(n2):
                p, g = _sq(2 * math.pi * j / n2 + phase, w, d, n)
                zz = z
                if ri == 0: q = p - g * .01
                else:
                    q = p + g * flare
                    if j % 2 == 0: zz = z - tooth * (1 + rnd.uniform(-jitter, jitter)); q += g * rnd.uniform(0, .03)
                    else: zz = z + tooth * .35
                q.z = zz; row.append(bm.verts.new(q))
            rows.append(row)
        a_, b_ = rows
        for j in range(n2): bm.faces.new((b_[j], b_[(j + 1) % n2], a_[(j + 1) % n2], a_[j]))
        o = bm_to_obj(bm, f"{name}_band{b}"); me = o.data
        f0 = me.polygons[0]
        if (f0.center - Vector((0, 0, f0.center.z))).dot(f0.normal) < 0: me.flip_normals()
        paint(o, colors[b % len(colors)]); objs.append(o)
    for o in objs: o.data.transform(matrix)
    return objs

def teardrop(name, r=(.1, .15, .05), col="ink", point=.65, seg=16, ring=10):
    """Ellipsoid pinched toward +Y (watermelon seed / drop). Local: x width, y height, z depth."""
    o = sphere(name, r, col=col, seg=seg, ring=ring)
    for v in o.data.vertices:
        t = max(0.0, v.co.y / r[1]); v.co.x *= 1 - point * t ** 1.4; v.co.z *= 1 - point * .6 * t ** 1.4
    return o

def stick(o, tree, origin, fwd=(0, -1, 0), push=.02, roll=0.0):
    """Raycast-place a local-XY-facing object onto a surface (kawaii.place convention: local z = surface normal)."""
    f = Vector(fwd).normalized(); p, n = hit(tree, origin, -f)
    if p is None: return None
    n = (n * .5 + f * .5).normalized(); t1, t2, n = K.basis(n)
    K.place(o, p + n * push, t1, t2, n, roll=roll); return p, n


# ======================================================================= POLLITO PÍO (common)
def pollito():
    """COMMON - 'Pollito Pío': yellow fringe ball chick, orange open beak ('¡pío!'), 3 head feathers, pom-pom feet."""
    P = []
    H = 2.6; R = 1.28; z0 = .32
    P += fringe_body("body", ellip_prof(R, H, p=.78), H, 7, ["sun_yellow", "mango", "sun_yellow", "mango", "sun_yellow", "mango", "sun_yellow"],
                     matrix=M((0, 0, z0)), seg=32, flare=.1, tooth=.07, seed=201, sy=.96, z_to=H * .87, rings_core=14, seg_core=28)
    hc = V(0, 0, 1.78)
    fp = plate("face", hc, r=(1.02, .5, .8), col="sun_yellow", fwd_off=.84); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .22), dx=.42, dz=0, size=.31, iris="sky", lid=None, lash=True, look=(0, -.05))
    # open beak ('¡pío!'): upper + lower beak halves, mouth cavity + tongue peeking between them
    bp, bn = hit(tree, hc + V(0, -3, -.16), V(0, 1, 0))
    up = cyl("beakU", .3, .03, .44, col="tangerine", seg=16); up.data.transform(Matrix.Diagonal((1, .58, 1, 1)))
    up.matrix_world = MB(bp + V(0, .1, .06), (0, -1, .08), (0, 0, 1)); P.append(up)
    lo = cyl("beakL", .25, .03, .3, col="tangerine", seg=16); lo.data.transform(Matrix.Diagonal((1, .5, 1, 1)))
    lo.matrix_world = MB(bp + V(0, .1, -.2), (0, -1, -.32), (0, 0, 1)); P.append(lo)
    P += mouth2("m", tree, hc + V(0, -3, -.27), w=.3, h=.2, smile=.2, col="ink", tongue=True, shape="O", depth=.05, push=.03)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.58 * s_, -3, -.1), size=.13)
    # 3 head feathers (curl forward) out of the smooth crown
    top = V(0, .02, z0 + H - .1)
    for k, (s_, h, col) in enumerate(((-1, .5, "mango"), (0, .72, "tangerine"), (1, .5, "mango"))):
        a = top + V(.13 * s_, 0, 0)
        pts = smooth_pts([a, a + V(.1 * s_, -.02, h * .45), a + V(.22 * s_, -.1, h * .85), a + V(.24 * s_, -.32, h * .98)], 9)
        P.append(tube(f"feather{k}", pts, radius=.12, col=col, seg=10, taper=taper_list(10, lambda t: 1.05 - .1 * t if t < .75 else 1.0 - 2.4 * (t - .75))))
    # little wings (flattened fringe cones) out to the sides like tiny hands
    WL = 1.15
    wprof = lambda z: .5 * max(0.0, 1 - (max(z - .3, 0) / (WL - .3)) ** 2) ** .5
    for s_, d in ((-1, (-1, -.12, -.5)), (1, (1, .05, .6))):   # left wing resting, right wing waving hello
        base = V(.72 * s_, -.2, 1.5)
        P += fringe_body(f"wing{s_}", wprof, WL, 4, ["tangerine", "mango", "mango", "sun_yellow"], matrix=MB(base, d, (0, -1, 0)),
                         seg=14, flare=.14, tooth=.06, seed=210 + s_, sy=.42)
    # pom-pom feet with three toes
    for s_ in (-1, 1):
        fpt = V(.48 * s_, -.25, .3)
        P += pompom(f"foot{s_}", fpt, .32, ["tangerine", "mango", "tangerine"], seed=220 + s_)
        for j in (-1, 0, 1):
            d = V(.35 * j, -1, 0).normalized()
            P.append(sphere(f"toe{s_}{j}", (.09, .09, .08), loc=fpt + d * .34 + V(0, 0, -.22), col="tangerine", seg=10, ring=6))
    # perky tail: short flattened fringe cone pointing back-up
    P += fringe_body("tail", cone_prof(.42, 1.0), 1.0, 3, ["tangerine", "mango", "sun_yellow"], matrix=MB(V(0, .78, 1.15), (0, 1, .75), (1, 0, 0)),
                     seg=14, flare=.14, tooth=.06, seed=230, sy=.45)
    return P, {"glow": []}


# ======================================================================= SANDÍA SONRIENTE (common)
def bend_arc(objs, C, Rr, a0, L):
    """Bend objects built along local +Z (0..L; local x -> world Y depth, local y -> radial) onto an arc in the XZ plane:
    centre C, radius Rr, starting at angle a0 (0 = straight down) and sweeping toward +X."""
    C = Vector(C)
    for o in objs:
        for v in o.data.vertices:
            x, y, z = v.co
            a = a0 + z / Rr; u = Vector((math.sin(a), 0, -math.cos(a)))
            v.co = C + u * (Rr + y) + Vector((0, x, 0))
        # (x, y, z) -> (Y, radial, tangent) mirrors handedness: reverse winding so normals point outward again
        bm = bmesh.new(); bm.from_mesh(o.data); bmesh.ops.reverse_faces(bm, faces=bm.faces[:]); bm.to_mesh(o.data); bm.free()
    return objs

def seed_eye(name, tree, origin, size=.3, fwd=(0, -1, 0), roll=0.0):
    """'Semilla-ojo': glossy black watermelon seed (point up) with 2 highlights, stuck on the face plate."""
    e = teardrop(name, (size * .72, size, size * .3), col="ink", point=.6, seg=20, ring=12)
    p, n = stick(e, tree, origin, fwd=fwd, push=size * .08, roll=roll)
    t1, t2, n = K.basis(n)
    P = [e]
    h1 = sphere(name + "_hl1", (size * .22, size * .26, size * .1), col="eye_white", seg=10, ring=6)
    K.place(h1, p + n * size * .32 + t1 * -size * .22 + t2 * -size * .05, t1, t2, n); P.append(h1)
    h2 = sphere(name + "_hl2", (size * .1, size * .1, size * .06), col="eye_white", seg=8, ring=5)
    K.place(h2, p + n * size * .3 + t1 * size * .2 + t2 * -size * .42, t1, t2, n); P.append(h2)
    return P

def sandia():
    """COMMON - 'Sandía Sonriente': upright watermelon wedge, striped green fringe rind, seeds for eyes and a huge smile."""
    P = []
    Rs, th = 3.0, math.radians(35); rr = .38
    dc = rr / math.sin(th); dt = dc * math.cos(th) ** 2; d0 = dc - rr
    H = Rs - d0; zb = .78; D0 = .55
    def wf(z):
        d = Rs - z
        if d <= d0: return 0.0
        if d < dt: return math.sqrt(max(rr * rr - (dc - d) ** 2, 0))
        return min(d * math.tan(th), math.sqrt(max(Rs * Rs - d * d, 0)))
    df = lambda z: min(D0, wf(z) * .85 + .02)
    flesh = fringe_sq("flesh", wf, df, H, 7, ["candy_red", "chili", "candy_red", "chili", "candy_red", "chili", "candy_red"],
                      matrix=Matrix.Translation((0, 0, zb)), seg=34, flare=.09, tooth=.08, seed=301, n=5.0)
    P += flesh
    apex = V(0, 0, zb + Rs)
    # rind: white inner strip + striped dark/leaf fringe rind bent along the arc
    Ri = Rs - .3; a0 = -th + .02; L_in = Ri * 2 * (th - .02)
    inner = fringe_sq("rindw", lambda z: D0 + .1, lambda z: .13, L_in, 1, ["white"], seg=10, flare=.0, tooth=.0, n=5, rings_core=24, seg_core=16)
    P += bend_arc(inner[:1], apex, Ri, a0, L_in)
    for o in inner[1:]: bpy.data.objects.remove(o, do_unlink=True)
    Rr = Rs - .02; a0 = -th; L = Rr * 2 * th
    cap = lambda z: (min(z, L - z) / .2) ** .5 if min(z, L - z) < .2 else 1.0
    rind = fringe_sq("rind", lambda z: (D0 + .1) * max(cap(z), .7), lambda z: .22 * max(cap(z), .3), L, 11,
                     ["dark_green", "leaf"], seg=14, flare=.07, tooth=.07, seed=302, n=4.5, rings_core=30, seg_core=18)
    P += bend_arc(rind, apex, Rr, a0, L)
    for s_ in (-1, 1):   # smooth rounded rind ends at the corners
        a = th * s_ - .035 * s_
        P.append(sphere(f"rindcap{s_}", (.13, D0 + .08, .23), loc=apex + Rr * V(math.sin(a), 0, -math.cos(a)), rot=(0, -math.degrees(a), 0),
                        col="dark_green", seg=18, ring=10))
    # face
    hc = V(0, 0, zb + 1.3)
    fp = plate("face", hc, r=(.92, .2, .72), col="candy_red", fwd_off=D0 - .02); P.append(fp)
    tree = bvh_of([fp])
    for s_ in (-1, 1):
        P += seed_eye(f"eye{s_}", tree, hc + V(.38 * s_, -3, .26), size=.3, roll=12 * s_)
        P += blush2(f"bl{s_}", tree, hc + V(.64 * s_, -3, -.06), size=.13)
    P += mouth2("m", tree, hc + V(0, -3, -.22), w=.92, h=.34, smile=1.1, col="ink", tongue=True, depth=.05)
    # little arms from the straight edges: one waving
    for s_, tip in ((-1, V(-2.05, -.3, 1.75)), (1, V(1.85, -.25, 2.6))):
        sh = V(.95 * s_, 0, zb + 1.35)
        P.append(tube(f"arm{s_}", smooth_pts([sh, sh.lerp(tip, .5) + V(0, -.05, .05 if s_ < 0 else -.1), tip], 6), radius=.13, col="dark_green", seg=10))
        P += pompom(f"hand{s_}", tip, .19, ["leaf", "leaf"], seed=320 + s_, bands=2, seg=12)
    # loose seeds on the flesh (front + back)
    ftree = bvh_of(flesh)
    for k, (x, z) in enumerate(((0, 2.55), (-.32, 2.05), (.34, 2.1), (-.95, 1.25), (.98, 1.3), (-1.35, .72), (1.38, .78), (0, .45))):
        for side in (-1, 1):
            sd = teardrop(f"seed{k}{side}", (.07, .12, .04), col="ink", point=.6, seg=10, ring=6)
            if stick(sd, ftree, V(x, 3 * side, zb + z), fwd=(0, side, 0), push=.0, roll=0) is None:
                bpy.data.objects.remove(sd, do_unlink=True); continue
            P.append(sd)
    # short legs + pom-pom feet under the rind
    for s_ in (-1, 1):
        P.append(tube(f"leg{s_}", [V(.55 * s_, 0, .75), V(.6 * s_, -.1, .4)], radius=.12, col="dark_green", seg=10))
        P += pompom(f"foot{s_}", V(.62 * s_, -.16, .27), .27, ["leaf", "leaf", "dark_green"], seed=310 + s_)
    return P, {"glow": []}


# ======================================================================= ELOTITO (uncommon)
def bend_yz(objs, Rb):
    """Bend objects built along local +Z so they curl toward local +Y (radius Rb). Orientation preserving."""
    for o in objs:
        for v in o.data.vertices:
            x, y, z = v.co; a = z / Rb
            v.co = Vector((x, Rb - (Rb - y) * math.cos(a), (Rb - y) * math.sin(a)))
    return objs

def place_all(objs, mtx):
    for o in objs: o.data.transform(mtx)
    return objs

def husk(name, L, W, curl, mtx, cols, seed=0, flat=.26, bands=5):
    """Corn husk leaf of crepe paper: flattened fringe blade (wide low, pointed tip), curled toward local +Y."""
    prof = lambda z: W * min(1.0, (z / (L * .18)) ** .5 if z < L * .18 else 1.0) * max(0.0, 1 - (z / L) ** 1.6) ** .8
    o = fringe_body(name, prof, L, bands, cols, seg=14, flare=.12, tooth=.07, seed=seed, sy=flat, rings_core=10, seg_core=14)
    bend_yz(o, curl)
    return place_all(o, mtx)

def elotito():
    """UNCOMMON - 'Elotito': proud standing corn cob, yellow fringe kernels, peeled green husks as a cape, corn-silk mustache."""
    P = []
    H = 3.05; R = .9; z0 = .55
    prof = lambda z: R * (1 - .2 * z / H) * max(0.0, 1 - ((2 * z / H) - 1) ** 2) ** .2
    cob = fringe_body("cob", prof, H, 10, ["sun_yellow", "mango"], matrix=M((0, 0, z0)), seg=30, flare=.1, tooth=.065, seed=401, sy=.92,
                      rings_core=12, seg_core=26)
    P += cob
    # husk cape: 5 crepe leaves peeled back around the sides/back, curling outward
    for k, (az, L, curl) in enumerate(((96, 2.7, 3.2), (-96, 2.7, 3.2), (136, 3.0, 3.5), (-136, 3.0, 3.5), (180, 3.2, 3.9))):
        a = math.radians(az); out = V(math.sin(a), -math.cos(a), 0)   # az measured from the front (-Y)
        base = V(0, 0, z0 + .25) + out * .66
        d = (V(0, 0, 1) - out * .04).normalized()
        cols = ["leaf", "lime", "leaf", "leaf", "lime"] if k % 2 else ["lime", "leaf", "lime", "leaf", "leaf"]
        P += husk(f"husk{k}", L, .7, curl, MB(base, d, out), cols, seed=410 + k)
    P.append(sphere("stem", (.36, .36, .26), loc=(0, .05, z0 + .1), col="leaf_dark", seg=16, ring=8))
    # face
    hc = V(0, 0, z0 + 2.05)
    fp = plate("face", hc, r=(.72, .4, .78), col="sun_yellow", fwd_off=.58); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .3), dx=.32, dz=0, size=.26, iris="jade", lid=None, lash=True, look=(0, -.05),
               brow=True, brow_h=1.55, brow_tilt=-6, brow_arch=.25, brow_col="brown")
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.52 * s_, -3, -.05), size=.11)
    P += mouth2("m", tree, hc + V(0, -3, -.43), w=.5, h=.2, smile=1.3, col="ink", tongue=True)
    # corn-silk mustache (curls up at the ends)
    mp, mn = hit(tree, hc + V(0, -3, -.2), V(0, 1, 0))
    for s_ in (-1, 1):
        pts = [mp + V(0, -.06, 0), mp + V(.16 * s_, -.08, -.03), mp + V(.31 * s_, -.06, -.02), mp + V(.42 * s_, -.02, .07), mp + V(.4 * s_, -.02, .17), mp + V(.33 * s_, -.04, .19)]
        P.append(tube(f"must{s_}", smooth_pts(pts, 10), radius=.075, col="brown", seg=10, taper=taper_list(11, lambda t: 1.15 - .35 * t if t < .8 else .87 - 2.2 * (t - .8))))
    P.append(sphere("mustc", (.09, .07, .07), loc=mp + V(0, -.07, -.01), col="brown", seg=10, ring=6))
    # corn-silk tuft on top (messy hair)
    top = V(0, .02, z0 + H - .1); rnd = random.Random(420)
    for k in range(11):
        a = 2 * math.pi * k / 11 + rnd.uniform(-.2, .2); dr = V(math.cos(a), math.sin(a) * .9, 0)
        hgt = rnd.uniform(.35, .5); reach = rnd.uniform(.45, .65)
        pts = [top + dr * .05, top + dr * .15 + V(0, 0, hgt * .8), top + dr * reach * .6 + V(0, 0, hgt), top + dr * reach + V(0, 0, hgt * .55), top + dr * reach * 1.1 + V(0, 0, hgt * .05)]
        P.append(tube(f"silk{k}", smooth_pts(pts, 9), radius=.05, col=("wood", "gold_pale", "mango")[k % 3], seg=7,
                      taper=taper_list(10, lambda t: 1.2 - .6 * t)))
    # arms (one on the hip, one thumbs-up) + pom-pom feet
    for s_, tip in ((-1, V(-1.15, -.45, 1.35)), (1, V(1.35, -.35, 2.45))):
        sh = V(.72 * s_, -.15, z0 + 1.45)
        P += limb(f"arm{s_}", sh, tip, .17, .15, 2, ["mango", "sun_yellow"], seed=430 + s_, seg=12)
        P.append(sphere(f"hand{s_}", (.18, .16, .18), loc=tip, col="leaf", seg=12, ring=8))
    for s_ in (-1, 1):
        P.append(tube(f"leg{s_}", [V(.32 * s_, 0, .6), V(.38 * s_, -.08, .3)], radius=.11, col="leaf_dark", seg=10))
        P += pompom(f"foot{s_}", V(.4 * s_, -.14, .26), .26, ["leaf", "lime", "leaf"], seed=440 + s_)
    return P, {"glow": []}


# ======================================================================= RANITA FIESTERA (uncommon)
def ranita():
    """UNCOMMON - 'Ranita Fiestera': chubby lime frog, party hat, huge eyes, tongue = party blower unrolling into a curl."""
    P = []
    H = 2.3; z0 = .28
    body = fringe_body("body", ellip_prof(1.25, H, p=.62), H, 6, ["lime", "jade", "lime", "lime", "jade", "lime"],
                       matrix=M((0, .05, z0)), seg=32, flare=.1, tooth=.07, seed=501, sx=1.15, sy=.92, z_to=H * .88, rings_core=12, seg_core=28)
    P += body
    bp = plate("belly", V(0, .05, z0 + .85), r=(.82, .3, .62), col="sun_yellow", fwd_off=.82); P.append(bp)
    hc = V(0, 0, z0 + 1.62)
    fp = plate("face", hc, r=(1.08, .42, .58), col="lime", fwd_off=.74); P.append(fp)
    # huge eyes on bulging domes
    for s_ in (-1, 1):
        ec = V(.56 * s_, -.32, z0 + 2.3)
        dome = sphere(f"edome{s_}", (.52, .48, .5), loc=ec, col="lime", seg=22, ring=12); P.append(dome)
        P.append(torus(f"elid{s_}", .47, .07, loc=ec + V(0, .02, .02), rot=(78, 0, 0), col="jade", seg=24, mseg=6))
        e, _, _ = eye2(f"eye{s_}", bvh_of([dome]), ec + V(.04 * s_, -3, .02), size=.42, iris="grape", lid=None, side=s_, lash=True,
                       look=(-.12 * s_, -.08))
        P += e
    tree = bvh_of([fp])
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.72 * s_, -3, -.05), size=.15)
        P += K.decal(f"nost{s_}", tree, hc + V(.12 * s_, -3, .18), r=(.04, .03), col="jade")
    # wide frog grin with a little round 'blowing' mouth in the middle
    mp, mn = hit(tree, hc + V(0, -3, -.12), V(0, 1, 0))
    gr = []
    for k in range(9):
        u = -1 + 2 * k / 8
        q, qn = hit(tree, hc + V(u * .72, -3, -.04 + .14 * u * u), V(0, 1, 0))
        gr.append(q + qn * .03)
    P.append(tube("grin", gr, radius=.035, col="ink", seg=6, taper=[.5, .9, 1, 1, 1, 1, 1, .9, .5]))
    P += mouth2("m", tree, hc + V(0, -3, -.14), w=.26, h=.22, smile=.0, col="ink", tongue=False, shape="O", depth=.05, push=.03)
    # party-blower tongue: straight out, then curls up and back into a spiral (striped paper)
    p0 = mp + V(0, -.05, -.02)
    fw = V(-.55, -.84, 0).normalized()             # aimed so the curl faces the 3/4 camera
    pts = [p0, p0 + fw * .45 + V(0, 0, -.08), p0 + fw * .9 + V(0, 0, -.14)]
    c = p0 + fw * 1.22 + V(0, 0, .24); turns = 1.4
    for k in range(1, 26):
        t = k / 25; th = -math.pi / 2 + t * turns * 2 * math.pi; r = .38 * (1 - .66 * t)
        pts.append(c + fw * (r * math.cos(th)) + V(0, 0, r * math.sin(th)))
    P += striped_tube("blower", pts, .1, ["tongue", "fiesta_pink", "sun_yellow", "fiesta_pink", "sun_yellow", "fiesta_pink", "sun_yellow", "fiesta_pink", "sun_yellow"],
                      seg=10, taper=lambda t: 1.1 - .45 * t, samples=54)
    # party hat: striped fringe cone + pom-pom, tilted, sitting between/behind the eyes
    hb = V(.1, .3, z0 + H - .12)
    hd = V(.22, .12, 1).normalized()
    P += fringe_body("hat", cone_prof(.58, 1.45), 1.45, 5, ["fiesta_pink", "sun_yellow", "fiesta_pink", "sun_yellow", "fiesta_pink"],
                     matrix=M(hb, hd), seg=22, flare=.12, tooth=.06, seed=510)
    P += pompom("hatpom", hb + hd * 1.47, .2, ["sun_yellow", "fiesta_pink"], seed=511, bands=2, seg=12)
    P.append(torus("hatrim", .57, .07, col="sun_yellow", seg=26, mseg=6)); P[-1].matrix_world = M(hb + hd * .05, hd)
    # back legs folded at the sides + webbed feet; front arms with toe-pad hands
    def frog_foot(name, loc, d, s=1.0):
        d = Vector(d).normalized(); side = d.cross(V(0, 0, 1)).normalized(); out = []
        out.append(sphere(name, (.26 * s, .3 * s, .1 * s), loc=loc, rot=(0, 0, math.degrees(math.atan2(d.x, -d.y))), col="lime", seg=16, ring=8))
        for j in (-1, 0, 1):
            td = (d + side * .55 * j).normalized()
            a = Vector(loc) + td * .14 * s; b = Vector(loc) + td * .44 * s + V(0, 0, .02)
            out.append(tube(f"{name}_t{j}", [a, b], radius=.06 * s, col="lime", seg=8))
            out.append(sphere(f"{name}_p{j}", (.09 * s, .09 * s, .07 * s), loc=b + td * .02, col="jade", seg=10, ring=6))
        return out
    for s_ in (-1, 1):
        P += fringe_body(f"thigh{s_}", ellip_prof(.52, 1.3, p=.8), 1.3, 3, ["lime", "jade", "lime"], matrix=MB(V(.98 * s_, .6, .55), (0, -1, .1), (s_, 0, 0)),
                         seg=18, flare=.12, tooth=.06, seed=520 + s_, sy=.75)
        P += frog_foot(f"foot{s_}", V(1.08 * s_, -.62, .1), (.45 * s_, -1, 0), s=1.15)
        P += limb(f"arm{s_}", (.62 * s_, -.55, 1.15), (.52 * s_, -.98, .28), .18, .16, 2, ["lime", "jade"], seed=530 + s_, seg=12)
        P += frog_foot(f"hand{s_}", V(.52 * s_, -1.05, .1), (.2 * s_, -1, 0), s=.9)
    return P, {"glow": []}


# ======================================================================= PUPUSITA (uncommon)
def pupusita():
    """UNCOMMON - 'Pupusita': puffy cream pupusa disc (concentric crepe rings on the face side), messy curtido hair
    (cabbage + carrot shreds), toasted comal freckles and a big happy face."""
    P = []
    R = 1.4; T = 1.2; zc = 1.88
    disc = fringe_body("disc", ellip_prof(R, T, p=.9), T, 7, ["cream", "plaza_tile", "cream", "plaza_tile", "cream", "plaza_tile", "wood"],
                       matrix=MB(V(0, T / 2, zc), (0, -1, 0), (0, 0, 1)), seg=34, flare=.11, tooth=.08, seed=601, z_to=T * .93, rings_core=12, seg_core=30)
    P += disc
    hc = V(0, 0, zc - .08)
    fp = plate("face", hc, r=(.84, .24, .72), col="cream", fwd_off=.39); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .22), dx=.34, dz=0, size=.26, iris="chocolate", lid=None, lash=True, look=(0, .12),
               brow=True, brow_h=1.55, brow_tilt=-4, brow_arch=.4, brow_col="wood_dark")
    P += mouth2("m", tree, hc + V(0, -3, -.3), w=.64, h=.28, smile=1.3, col="ink", tongue=True, depth=.05)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.56 * s_, -3, -.1), size=.13)
    # toasted comal freckles on the outer rings
    dtree = bvh_of(disc); rnd = random.Random(602)
    for k, (a, rr) in enumerate(((-.5, 1.12), (.45, 1.18), (2.5, 1.1), (3.5, 1.16), (4.2, 1.02), (5.5, 1.18), (1.4, 1.22))):
        o = V(rr * math.cos(a), -3, zc + rr * math.sin(a))
        sp = sphere(f"toast{k}", (.11 * rnd.uniform(.8, 1.2), .08, .03), col="wood" if k % 2 else "wood_dark", seg=10, ring=5)
        if stick(sp, dtree, o, push=.02, roll=rnd.uniform(0, 180)) is None: bpy.data.objects.remove(sp, do_unlink=True)
        else: P.append(sp)
    # curtido hair: cluster of shredded-crepe tufts (cabbage + carrot) on the top rim, wavy bangs, carrot curls
    rnd = random.Random(603)
    tufts = [(a_, y_, r_) for a_, y_, r_ in ((28, -.12, .36), (52, -.2, .42), (76, -.22, .46), (102, -.22, .46), (128, -.2, .42), (152, -.12, .36),
                                              (62, .3, .42), (90, .32, .46), (118, .3, .42))]
    for k, (ad, y_, r_) in enumerate(tufts):
        a_ = math.radians(ad); q = V((R - .12) * math.cos(a_), y_, zc + (R - .12) * math.sin(a_))
        cols = ["lime", "leaf", "lime"] if k % 3 else ["leaf", "lime", "tangerine"]
        P += pompom(f"tuft{k}", q, r_, cols, seed=630 + k, bands=3, seg=12, squash=.9)
    for k in range(8):   # wavy bangs over the forehead
        u = -1 + 2 * k / 7
        root = V(u * .7, -.48, zc + R - .1 - .38 * u * u)
        L = rnd.uniform(.38, .52) * (1 - .2 * abs(u))
        pts = [root, root + V(u * .05, -.14, .02), root + V(u * .1 + .04, -.2, -L * .45), root + V(u * .12 - .03, -.22, -L * .8), root + V(u * .14, -.2, -L)]
        col = ("lime", "tangerine", "leaf", "lime")[k % 4]
        P.append(tube(f"bang{k}", smooth_pts(pts, 8), radius=.075 if col != "tangerine" else .06, col=col, seg=7, taper=taper_list(9, lambda t: 1.1 - .55 * t)))
    for k in range(6):   # curly carrot + cabbage shreds poking out of the mop
        a_ = math.radians(35 + 22 * k); d = V(math.cos(a_), .15 * (k % 2) - .1, math.sin(a_)).normalized()
        b0 = V(0, 0, zc) + d * (R + .22)
        side = V(0, 1, 0).cross(d).normalized()
        pts = [b0, b0 + d * .18 + side * .08, b0 + d * .3 - side * .04, b0 + d * .36 + side * .1]
        P.append(tube(f"shred{k}", smooth_pts(pts, 7), radius=.05, col="tangerine" if k % 2 == 0 else "lime", seg=6, taper=taper_list(8, lambda t: 1.1 - .5 * t)))
    # arms (one waving) + pom-pom feet
    for s_, tip in ((-1, V(-1.75, -.3, 1.25)), (1, V(1.75, -.35, 2.75))):
        sh = V(1.15 * s_, 0, zc - .2)
        P += limb(f"arm{s_}", sh, tip, .17, .15, 2, ["cream", "plaza_tile"], seed=610 + s_, seg=12)
        P.append(sphere(f"hand{s_}", (.18, .16, .18), loc=tip, col="cream", seg=12, ring=8))
    for s_ in (-1, 1):
        P.append(tube(f"leg{s_}", [V(.42 * s_, 0, .65), V(.48 * s_, -.08, .32)], radius=.12, col="plaza_tile", seg=10))
        P += pompom(f"foot{s_}", V(.5 * s_, -.14, .27), .27, ["tangerine", "mango", "tangerine"], seed=620 + s_)
    return P, {"glow": []}


REG = {"pollito": pollito, "sandia": sandia, "elotito": elotito, "ranita": ranita, "pupusita": pupusita}
REG_RARITY = {"pollito": "common", "sandia": "common", "elotito": "uncommon", "ranita": "uncommon", "pupusita": "uncommon"}
REG_CAM = {}
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
