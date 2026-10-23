"""Fase 4 - las 14 piñatas del roster de fase 1 que faltaban modelar (izalco, pixelin, tamalito, jengibrin).
Mítica, secreta y las dos de Navidad. Mismo pipeline que animals2.py / randoms.py: fringe_body + kawaii (plate, eyes2, mouth2...),
build2() exporta a export/creatures/<id>.fbx|.obj, guarda blend/<id>.blend y renders/<id>.png.
Solo colores de PALETTE (plib.py): la paleta ya está subida a Roblox y no se puede cambiar.
CLI: blender -b --factory-startup -P roster_c.py -- [name ...]
     PREVIEW=1 [PREVIEW_DIR=/ruta] [SAMPLES=16] -> png chico sin exportar ni tocar la paleta.
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
import creatures as C
from creatures import M, cone_prof, ellip_prof, lin_prof, limb, chain
from plib import *
import kawaii as K
from kawaii import V, eyes2, eye2, plate, mouth2, nose2, paw, blush2, bvh_of, decal, ear_inner, hit
import animals2, bmesh
from animals2 import build2
from mathutils import Vector, Matrix
from memes2 import hand


# ======================================================================= helpers
def on_cone(prof, a_deg, z, out=1.0):
    """Point on a revolved profile at angle a (deg, -90 = front/-Y) and height z."""
    a = math.radians(a_deg); r = prof(max(z, 0.0)) * out
    return V(r * math.cos(a), r * math.sin(a), z)


def drip_band(name, prof, z_top, drips, base=.22, out=1.12, n=160, rows=7, col="neon_pink", th=.05, lip=(), wob=.03):
    """Overflowing goo collar (lava / icing) hugging a revolved profile: scalloped bottom edge with rounded drips.
    drips: (angle_deg, length, half_width_deg). lip: extra (r, z) rows above z_top (goo curling over a rim)."""
    def L(a):
        v = base + wob * math.sin(math.radians(a) * 7)
        for ad, ln, wd in drips:
            d = (a - ad + 180) % 360 - 180
            if abs(d) < wd: v = max(v, base + (ln - base) * math.sqrt(1 - (d / wd) ** 2))
        return v
    bm = bmesh.new(); cols = []
    for j in range(n):
        a = 360 * j / n; ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a)); l = L(a)
        cv = [bm.verts.new((rr * ca, rr * sa, zz)) for rr, zz in lip]
        for i in range(rows + 1):
            z = z_top - l * i / rows; r = prof(max(z, 0.0)) * out
            cv.append(bm.verts.new((r * ca, r * sa, z)))
        cols.append(cv)
    for j in range(n):
        a_, b_ = cols[j], cols[(j + 1) % n]
        for i in range(len(a_) - 1): bm.faces.new((a_[i], b_[i], b_[i + 1], a_[i + 1]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    o = bm_to_obj(bm, name)
    m = o.modifiers.new("s", 'SOLIDIFY'); m.thickness = th; m.offset = 0; apply_mods(o)
    return paint(o, col), L


def sq_loop(hw, hd, n, ex=8.0, phase=0.0):
    """n points evenly spaced (by arc length) around a superellipse |x/hw|^ex + |y/hd|^ex = 1 (rounded square)."""
    raw = []
    for k in range(720):
        a = 2 * math.pi * k / 720; c, s_ = math.cos(a), math.sin(a)
        raw.append(V(hw * math.copysign(abs(c) ** (2 / ex), c), hd * math.copysign(abs(s_) ** (2 / ex), s_), 0))
    cum = [0.0]
    for k in range(1, 721): cum.append(cum[-1] + (raw[k % 720] - raw[k - 1]).length)
    tot = cum[-1]; out = []; j = 0
    for i in range(n):
        d = (i / n + phase) % 1.0 * tot
        while cum[j + 1] < d: j += 1
        t = (d - cum[j]) / max(cum[j + 1] - cum[j], 1e-9)
        out.append(raw[j % 720].lerp(raw[(j + 1) % 720], t))
    return out

def sq_band(name, hw, hd, zt, zb, col, flare=.1, tooth=.07, seed=0, ex=8.0, spacing=.11, split=None, mtx=Matrix.Identity(4), s_top=1.0, s_bot=1.0):
    """One crepe-paper fringe band around a rounded-square prism (top row tucked in, toothed bottom row flared out).
    split: optional list of (u0, u1, col) perimeter ranges (0..1, start at +X going CCW) painted in other colours."""
    rnd = random.Random(seed)
    n = max(16, int(round(4 * (hw + hd) / spacing / 2)) * 2)
    top = sq_loop(hw * .97 * s_top, hd * .97 * s_top, n, ex); bot = sq_loop(hw * (1 + flare) * s_bot, hd * (1 + flare) * s_bot, n, ex)
    rows = []
    for i in range(n):
        if i % 2 == 0: z2 = zb - tooth * (1 + rnd.uniform(-.25, .25)); sc = 1 + rnd.uniform(0, .04)
        else: z2 = zb + tooth * .35; sc = 1.0
        rows.append((V(top[i].x, top[i].y, zt), V(bot[i].x * sc, bot[i].y * sc, z2)))
    def owner(i):
        u = (i + .5) / n; c = col
        for u0, u1, cc in (split or []):
            if u0 <= u < u1: c = cc
        return c
    groups = {}
    for i in range(n): groups.setdefault(owner(i), []).append(i)
    out = []
    for c, idx in groups.items():
        bm = bmesh.new(); vm = {}
        def gv(k, r):
            if (k, r) not in vm: vm[(k, r)] = bm.verts.new(rows[k % n][r])
            return vm[(k, r)]
        for i in idx:
            bm.faces.new((gv(i, 1), gv(i + 1, 1), gv(i + 1, 0), gv(i, 0)))
        o = bm_to_obj(bm, f"{name}_{c}")
        me = o.data; f0 = me.polygons[0]
        if (f0.center - Vector((0, 0, f0.center.z))).dot(f0.normal) < 0: me.flip_normals()
        me.transform(mtx); paint(o, c); out.append(o)
    return out

def sq_core(name, hw, hd, z0, z1, col, ex=4.0, n=48, bev=.14, loc=(0, 0), prof=None):
    """Watertight rounded-square prism (superellipse section) with softly rounded top/bottom edges.
    prof: optional scale(t), t = 0..1 along the height (pillow / barrel shapes)."""
    bm = bmesh.new(); rings = []
    if prof: prof = [(prof(i / 12), z0 + (z1 - z0) * i / 12) for i in range(13)]
    else: prof = [(.8, z0), (.95, z0 + bev * .3), (1, z0 + bev), (1, z1 - bev), (.95, z1 - bev * .3), (.8, z1)]
    for sc, z in prof:
        rings.append([bm.verts.new((loc[0] + p.x, loc[1] + p.y, z)) for p in sq_loop(hw * sc, hd * sc, n, ex)])
    for i in range(len(rings) - 1):
        a, b = rings[i], rings[i + 1]
        for j in range(n): bm.faces.new((a[j], a[(j + 1) % n], b[(j + 1) % n], b[j]))
    bm.faces.new(list(reversed(rings[0]))); bm.faces.new(rings[-1])
    bmesh.ops.triangulate(bm, faces=[f for f in bm.faces if len(f.verts) > 4])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return paint(bm_to_obj(bm, name), col)

def fringe_cube(name, w, d, h, loc, colors, bands=2, flare=.1, tooth=.07, seed=0, bevel=.12, split=None, core=None, ex=8.0, prof=None):
    """Chunky block wrapped in square fringe bands (bands top->bottom, colours cycle). ex>=7: bevelled box core ('pixel');
    lower ex: rounder superellipse pillow core. split: {band_index: [(u0, u1, col), ...]} for glitchy mismatched chunks."""
    x, y, z = loc
    if ex >= 7: P = [box(f"{name}_core", (w * .96, d * .96, h), loc=(x, y, z + h / 2), col=core or colors[0], bevel=bevel)]
    else: P = [sq_core(f"{name}_core", w * .48, d * .48, z, z + h, core or colors[0], ex=ex, bev=bevel, loc=(x, y), prof=prof)]
    pf = prof or (lambda t: 1.0)
    span = h / bands; mt = Matrix.Translation((x, y, 0))
    for b in range(bands):
        zt = z + h - b * span - (.02 if b == 0 else -span * .3); zb = z + h - (b + 1) * span
        P += sq_band(f"{name}_b{b}", w / 2, d / 2, zt, zb, colors[b % len(colors)], flare=flare, tooth=tooth, seed=seed + b,
                     split=(split or {}).get(b), mtx=mt, ex=ex, s_top=pf(min(1, (zt - z) / h)), s_bot=pf(max(0, (zb - z) / h)))
    return P


# ======================================================================= VOLCÁN IZALCO (mythic)
def izalco():
    """MYTHIC - 'Volcán Izalco', el Faro del Pacífico: chubby fringe volcano cheering with both arms up, a crater of
    bubbling magic lava overflowing in a collar of rounded drips (all the lava is _Neon -> mythic pink in Roblox),
    a green foothill skirt and a cotton-candy smoke cloud."""
    P = []; G = []
    H = 2.85; rb, rt = 1.5, .74
    prof = lambda z: rt + (rb - rt) * max(0.0, 1 - z / H) ** 1.55
    body = fringe_body("cone", prof, H, 6, ["chocolate", "brown", "brown", "terracotta", "brown", "leaf"],
                       seg=34, flare=.1, tooth=.08, seed=1701, z_from=.12, core_col="brown")
    P += body
    # crater: glowing lava dome + bubbles, overflowing into a dripping collar of neon lava (rounded drips)
    G.append(sphere("pool", (rt * .9, rt * .9, .26), loc=(0, 0, H + .04), col="neon_pink", seg=24, ring=10))
    for k, (x, y, z, r) in enumerate([(.28, -.2, .28, .16), (-.3, -.05, .3, .13), (.0, .12, .36, .11), (-.12, -.3, .42, .08), (.36, .1, .5, .07)]):
        G.append(sphere(f"bub{k}", (r, r, r), loc=(x, y, H + z), col="neon_pink", seg=12, ring=7))
    drips = [(-90, .45, 9), (-64, .62, 9), (-117, .55, 9), (-28, 1.15, 11), (-152, 1.0, 11), (8, .7, 9), (36, 1.3, 11),
             (70, .8, 10), (108, 1.1, 11), (145, .75, 9), (180, .95, 10)]
    collar, _ = drip_band("lava", prof, H + .02, drips, base=.22, out=1.12, n=128, rows=5, lip=((rt * .74, H + .2), (rt * 1.0, H + .14)))
    G.append(collar)
    # face on the front slope
    f = V(0, -1, .26).normalized(); hc = V(0, 0, 1.32)
    fp = plate("face", hc, fwd=f, r=(.9, .42, .72), col="brown", fwd_off=.86); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .2), fwd=f, dx=.37, dz=0, size=.3, iris="tangerine", lid=None, lash=True, look=(0, .08),
               brow=True, brow_h=1.45, brow_tilt=12, brow_arch=.25, brow_col="ink_soft")
    P += mouth2("m", tree, hc + V(0, 0, -.3) + f * 3, fwd=f, w=.5, h=.27, smile=.6, col="ink", tongue=True)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.6 * s_, 0, -.12) + f * 3, fwd=f, size=.14)
    # little arms up ("¡erupción!") + stubby feet
    for s_ in (-1, 1):
        sh = V(1.0 * s_, -.15, 1.25); wr = V(1.5 * s_, -.35, 1.9)
        P += limb(f"arm{s_}", sh, wr, .22, .19, 2, ["brown", "terracotta"], seed=1710 + s_, seg=12)
        P += hand(f"hand{s_}", wr + V(.04 * s_, -.02, .12), d=(.35 * s_, -.2, 1), s=.2, col="chocolate", fingers=3)
        P += paw(f"foot{s_}", (.55 * s_, -1.45, .2), fwd=(0, -1, .45), s=.3, col="chocolate", pad="terracotta")
    # cotton-candy smoke cloud rising from the crater (behind the lip)
    puffs = [(.1, .3, .62, .22, "white"), (-.15, .4, .9, .3, "bubblegum"), (.32, .45, 1.08, .32, "mint"),
             (-.45, .5, 1.28, .33, "white"), (.1, .6, 1.42, .4, "bubblegum"), (.58, .6, 1.5, .27, "lavender")]
    for k, (x, y, z, r, c) in enumerate(puffs):
        P.append(sphere(f"puff{k}", (r * 1.15, r, r * .95), loc=(x, y, H + z), col=c, seg=16, ring=10))
    for k, (x, y, z) in enumerate([(-1.25, -.4, 3.1), (1.3, -.2, 3.4)]):
        G.append(star_prism(f"spark{k}", 4, .2, .07, .06, loc=(x, y, z), rot=(90, 0, 15 * k), col="neon_pink", bevel=.02))
    return P + G, {"glow": G}


# ======================================================================= PIXELÍN (secret)
def pixelin():
    """SECRET - 'Pixelín': a glitched piñata made of fringe-wrapped pixel blocks. A band slips sideways, chunks flicker
    into the wrong colour, a head corner dissolves into loose pixels and its face is a little screen (cyan glow bezel)
    with glowing pixel eyes and a pixel smile. Waves with a stepped pixel arm."""
    P = []; G = []
    # pixel-sprite silhouette: feet -> body block -> big head block -> ear blocks
    for s_ in (-1, 1):
        P += fringe_cube(f"foot{s_}", .62, .62, .42, (.52 * s_, -.3, 0), ["grape"], bands=1, seed=1800 + s_, bevel=.08)
    P += fringe_cube("body", 1.85, 1.55, 1.15, (0, 0, .38), ["grape", "fiesta_pink"], bands=2, seed=1803, bevel=.12,
                     split={0: [(.3, .4, "turquoise")], 1: [(.52, .6, "sun_yellow")]})
    hz = 1.45; hh = 1.6
    head = fringe_cube("head", 2.4, 1.9, hh, (0, 0, hz), ["fiesta_pink", "grape", "fiesta_pink"], bands=3, seed=1806, bevel=.14,
                       split={0: [(.55, .66, "turquoise")], 2: [(.05, .16, "turquoise"), (.86, .93, "sun_yellow")]})
    for o in head:   # glitch: the middle band slipped sideways
        if "_b1_" in o.name: o.data.transform(Matrix.Translation((.13, 0, 0)))
    P += head
    for s_, c in ((-1, "turquoise"), (1, "fiesta_pink")):
        P += fringe_cube(f"ear{s_}", .55, .5, .55, (.82 * s_, .1, hz + hh - .02), [c], bands=1, seed=1810 + s_, bevel=.07,
                         core="grape" if c == "turquoise" else "hot_magenta")
    # face = little screen with glowing pixel eyes + pixel smile (on a plate, so the fringe never eats it)
    fc = V(0, -1.02, hz + hh * .52)
    P.append(box("screen", (1.72, .3, 1.08), loc=fc, col="ink_soft", bevel=.12))
    G.append(box("screenrim", (1.86, .22, 1.22), loc=fc + V(0, .05, 0), col="neon_cyan", bevel=.1))
    yf = fc.y - .16
    for s_ in (-1, 1):
        G.append(box(f"eye{s_}", (.27, .12, .38), loc=(.38 * s_, yf - .02, fc.z + .1), col="neon_cyan", bevel=.025))
        P.append(box(f"eyehl{s_}", (.1, .06, .1), loc=(.38 * s_ - .07, yf - .09, fc.z + .21), col="eye_white", bevel=.015))
        P.append(box(f"blush{s_}", (.22, .05, .1), loc=(.66 * s_, yf, fc.z - .18), col="fiesta_pink", bevel=.015))
    u = .1
    for k, (gx, gz) in enumerate([(-2, 1), (-1, 0), (0, 0), (1, 0), (2, 1)]):
        G.append(box(f"mouth{k}", (u * .95, .1, u * .95), loc=(gx * u, yf - .01, fc.z - .24 + gz * u), col="neon_cyan", bevel=.01))
    # arms: one block arm resting, one stepped pixel arm waving hi
    P += fringe_cube("armL", .46, .46, .46, (-1.08, -.42, .75), ["grape"], bands=1, seed=1820, bevel=.07)
    P += fringe_cube("armL1", .4, .4, .4, (-1.38, -.5, .5), ["turquoise"], bands=1, seed=1823, bevel=.07)
    for k, (x, z, sz, c) in enumerate([(1.1, .8, .46, "grape"), (1.48, 1.12, .42, "grape"), (1.74, 1.5, .4, "grape"), (1.86, 1.92, .42, "turquoise")]):
        P += fringe_cube(f"armR{k}", sz, sz, sz, (x, -.45, z), [c], bands=1, seed=1821 + k, bevel=.07)
    # pixel heart on the belly
    q = .075
    heart = [(-3.5, .5), (-3.5, 2.5), (-2.5, 2.5), (-2.5, 3.5), (-.5, 3.5), (-.5, 2.5), (.5, 2.5), (.5, 3.5), (2.5, 3.5), (2.5, 2.5), (3.5, 2.5),
             (3.5, .5), (2.5, .5), (2.5, -.5), (1.5, -.5), (1.5, -1.5), (.5, -1.5), (.5, -2.5), (-.5, -2.5), (-.5, -1.5), (-1.5, -1.5),
             (-1.5, -.5), (-2.5, -.5), (-2.5, .5)]
    P.append(slab("pxheart", [(x * q, y * q) for x, y in heart], thick=.08, col="hot_magenta", bevel=.012,
                  matrix=Matrix.Translation((-.45, -.93, 1.02)) @ Matrix.Rotation(math.radians(90), 4, 'X')))
    # glitch FX: the head's top corner dissolving into loose pixels (cyan glow + body colours), a few strays
    cx, cy, cz = 1.15, -.9, hz + hh
    for k, (dx, dy, dz, sz, c) in enumerate([(.08, -.05, -.05, .28, "neon_cyan"), (.36, -.12, .2, .2, "fiesta_pink"), (.6, -.08, .48, .15, "neon_cyan"),
                                               (.82, -.15, .78, .1, "neon_cyan"), (.3, -.3, .55, .1, "sun_yellow")]):
        (G if c.startswith("neon") else P).append(box(f"dis{k}", (sz, sz, sz), loc=(cx + dx, cy + dy, cz + dz), col=c, bevel=.015))
    for k, (x, y, z, sz) in enumerate([(-1.7, -.5, 3.15, .16), (-1.95, -.3, 3.5, .1), (-1.65, -.8, .35, .14), (-1.95, -.7, .7, .09)]):
        G.append(box(f"px{k}", (sz, sz, sz), loc=(x, y, z), col="neon_cyan", bevel=.012))
    return P + G, {"glow": G}


# ======================================================================= TAMALITO (event, Navidad)
def tamalito():
    """EVENT (Navidad) - 'Tamalito': a chubby tamal wrapped in banana leaf, tied with a red Christmas bow (with holly),
    the leaf folded open on the front to show its masa face with puffy masa cheeks. Holds a mug of hot chocolate."""
    P = []
    W, D, Hb, z0 = 2.2, 1.6, 2.5, .32
    pillow = lambda t: max(.64, (1 - abs(2 * t - 1) ** 4) ** .25)
    wrap = fringe_cube("wrap", W, D, Hb, (0, 0, z0), ["leaf", "xmas_green", "leaf", "xmas_green", "leaf"], bands=5, seed=1901,
                       bevel=.4, ex=3.0, flare=.09, tooth=.07, core="xmas_green", prof=pillow)
    P += wrap
    zt = z0 + Hb
    wt = bvh_of(wrap)
    # masa face peeking out of the opened leaf (leaf-edge rim around it) + puffy masa cheeks
    hc = V(0, 0, z0 + Hb * .55)
    fp = plate("masa", hc, r=(.8, .36, .8), col="cream", fwd_off=.66); P.append(fp)
    bt = bvh_of([fp] + wrap)
    rim = []
    for k in range(29):
        th = 2 * math.pi * k / 28
        q, n = hit(bt, hc + V(.76 * math.cos(th), -3, .76 * math.sin(th)), V(0, 1, 0))
        if q is not None: rim.append(q + n * .02)
    P.append(tube("leafrim", rim, radius=.085, col="leaf_dark", seg=8))
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .2), dx=.31, dz=0, size=.25, iris="chocolate", lid=None, lash=True, look=(0, .05))
    P += mouth2("m", tree, hc + V(0, -3, -.25), w=.28, h=.15, smile=.7, col="ink", tongue=True)
    for s_ in (-1, 1):
        ck = sphere(f"cheek{s_}", (.21, .13, .17), loc=hc + V(.46 * s_, -.98, -.17), col="cream", seg=14, ring=8); P.append(ck)
        P += blush2(f"bl{s_}", bvh_of([ck]), hc + V(.46 * s_, -3, -.17), size=.12)
    # red string tied over the top + Christmas bow with a holly sprig
    sp = []
    for k in range(17):   # string hugging the wrap: up the left side, over the top, down the right side
        th = math.pi * (1 - k / 16) * 1.25 - math.pi * .125
        d = V(math.cos(th), 0, math.sin(th) * 1.25).normalized()
        q, n = hit(wt, V(0, -.05, z0 + Hb * .62) + d * 4, -d)
        if q is not None: sp.append(q + n * .04)
    P.append(tube("string", sp, radius=.06, col="xmas_red", seg=8))
    for s_ in (-1, 1):
        lp = torus(f"loop{s_}", .26, .07, col="xmas_red", seg=20, mseg=8)
        lp.matrix_world = Matrix.Translation((.3 * s_, -.05, zt + .38)) @ Matrix.Rotation(math.radians(-28 * s_), 4, 'Y') @ Matrix.Diagonal((1.25, 1, 1, 1)) @ Matrix.Rotation(math.radians(90), 4, 'X') @ Matrix.Diagonal((1, 1, 2.2, 1))
        P.append(lp)
        P.append(ribbon(f"tail{s_}", [V(.06 * s_, -.12, zt + .28), V(.25 * s_, -.22, zt + .14), V(.4 * s_, -.26, zt - .02)], width=.17, normal=(0, -1, .3), col="xmas_red", thick=.05))
    P.append(sphere("knot", (.15, .14, .15), loc=(0, -.07, zt + .3), col="red_dark", seg=14, ring=8))
    for k, rz in enumerate((200, 330)):
        P.append(slab(f"holly{k}", [(0, 0), (.1, .07), (.2, .03), (.3, .09), (.44, 0), (.3, -.09), (.2, -.03), (.1, -.07)], thick=.04, col="pine", bevel=.012,
                      matrix=Matrix.Translation((.05, -.2, zt + .44)) @ Matrix.Rotation(math.radians(rz), 4, 'Z') @ Matrix.Rotation(math.radians(-35), 4, 'X')))
    for k, (x, y, z) in enumerate([(-.02, -.3, .5), (.1, -.28, .56), (.03, -.2, .62)]):
        P.append(sphere(f"berry{k}", (.065, .065, .065), loc=(x, y, zt + z), col="candy_red", seg=10, ring=6))
    # little leaf arms: one waving, one holding a mug of chocolate; stubby feet
    P += limb("armL", (-1.05, -.2, 1.4), (-1.55, -.35, 1.95), .2, .17, 2, ["leaf", "xmas_green"], seed=1910, seg=12)
    P += hand("handL", V(-1.6, -.38, 2.08), d=(-.3, -.2, 1), s=.18, col="cream", fingers=3)
    P += limb("armR", (1.05, -.2, 1.35), (1.3, -.7, 1.05), .2, .17, 2, ["leaf", "xmas_green"], seed=1911, seg=12)
    P.append(sphere("handR", (.18, .17, .17), loc=(1.3, -.78, 1.0), col="cream", seg=12, ring=8))
    mg = V(1.3, -1.0, .78)
    P.append(cyl("mug", .2, .21, .42, loc=mg, col="snow", seg=18, bevel=.02))
    P.append(torus("mugband", .21, .03, loc=mg + V(0, 0, .14), col="xmas_red", seg=18, mseg=4))
    P.append(cyl("choco", .17, .17, .02, loc=mg + V(0, 0, .41), col="chocolate", seg=16))
    P.append(torus("mughandle", .11, .035, loc=mg + V(.22, 0, .22), rot=(90, 0, 0), col="snow", seg=12, mseg=5))
    for k in (-1, 1):
        P.append(tube(f"steam{k}", [mg + V(.05 * k, 0, .48), mg + V(.12 * k, -.02, .62), mg + V(.02 * k, 0, .76), mg + V(.1 * k, .02, .9)], radius=.03, col="snow", seg=6, taper=[1, 1, .8, .4]))
    for s_ in (-1, 1):
        P += paw(f"foot{s_}", (.48 * s_, -.5, .19), fwd=(0, -1, .45), s=.25, col="leaf_dark", pad="cream", toes=2)
    return P, {"glow": []}


# ======================================================================= JENGIBRÍN (event, Navidad)
def icing_zigzag(name, tree, center, fwd, side, width, amp=.07, n=9, r=.045, push=.03):
    """Wavy line of white icing piped across a surface (projected with rays along -fwd)."""
    f = Vector(fwd).normalized(); sd = Vector(side).normalized(); up = sd.cross(f).normalized() * -1
    pts = []
    for k in range(n):
        u = -1 + 2 * k / (n - 1)
        o = Vector(center) + sd * u * width / 2 + up * (amp if k % 2 else -amp) + f * 3
        q, nn = hit(tree, o, -f)
        if q is not None: pts.append(q + nn * push)
    return [tube(name, pts, radius=r, col="snow", seg=6)] if len(pts) > 2 else []

def jengibrin():
    """EVENT (Navidad) - 'Jengibrín': a chubby gingerbread-cookie piñata in cinnamon fringe, white icing piping
    (scalloped face outline, zig-zag cuffs), gumdrop candy buttons and a red icing bow tie. Waving hello."""
    P = []
    # legs + round cookie feet with icing zig-zags
    for s_ in (-1, 1):
        P += limb(f"leg{s_}", (.42 * s_, 0, 1.25), (.62 * s_, -.05, .32), .36, .34, 2, ["wood", "brown"], seed=2000 + s_, sy=.78, seg=16)
        ft = sphere(f"foot{s_}", (.4, .34, .32), loc=(.66 * s_, -.08, .32), col="wood", seg=18, ring=10); P.append(ft)
        P += icing_zigzag(f"fzz{s_}", bvh_of([ft]), (.66 * s_, -.1, .36), (0, -1, 0), (1, 0, 0), .6, amp=.06)
    body = fringe_body("body", ellip_prof(.95, 1.95, p=.55), 1.95, 5, ["wood", "brown", "wood", "wood", "brown"], matrix=M((0, 0, .72)), seg=30,
                       flare=.08, tooth=.07, seed=2003, sy=.74)
    P += body
    hc = V(0, -.02, 3.22)
    head = fringe_body("head", ellip_prof(1.02, 1.68, p=1.1), 1.68, 4, ["wood", "wood", "brown", "wood"], matrix=M(hc - V(0, 0, .82)), seg=32,
                       flare=.09, tooth=.065, seed=2004, sx=1.04, sy=.76)
    P += head
    # face plate + kawaii face + scalloped icing outline
    fp = plate("face", hc + V(0, 0, -.02), r=(.86, .4, .72), col="wood", fwd_off=.5); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .14), dx=.34, dz=0, size=.27, iris="chocolate", lid=None, lash=True, look=(0, .05))
    P += mouth2("m", tree, hc + V(0, -3, -.3), w=.4, h=.2, smile=.7, col="ink", tongue=True)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.58 * s_, -3, -.16), size=.13)
    ring = []
    ht = bvh_of([fp] + head)
    for k in range(41):
        th = 2 * math.pi * k / 40; rr = .84 + .05 * math.cos(th * 12)
        q, n = hit(ht, hc + V(rr * math.cos(th), -3, rr * .86 * math.sin(th) - .02), V(0, 1, 0))
        if q is not None: ring.append(q + n * .03)
    P.append(tube("icing_face", ring, radius=.055, col="snow", seg=6))
    # gumdrop buttons + bow tie
    bt = bvh_of(body)
    for k, (z, c) in enumerate([(2.08, "candy_red"), (1.62, "xmas_green"), (1.16, "candy_red")]):
        q, n = hit(bt, V(0, -3, z), V(0, 1, 0))
        g = cyl(f"gum{k}", .17, .12, .16, col=c, seg=14, bevel=.05); g.matrix_world = M(q - n * .02, n); P.append(g)
        P.append(sphere(f"gumtop{k}", (.12, .12, .07), loc=q + n * .14, col=c, seg=12, ring=6))
        P.append(sphere(f"gumhl{k}", (.04, .04, .02), loc=q + n * .18 + V(-.05, 0, .04), col="eye_white", seg=8, ring=4))
    bz = 2.52
    for s_ in (-1, 1):
        P.append(slab(f"bow{s_}", [(0, 0), (.3 * s_, .17), (.36 * s_, 0), (.3 * s_, -.17)], thick=.12, col="xmas_red", bevel=.04,
                      matrix=Matrix.Translation((0, -.8, bz)) @ Matrix.Rotation(math.radians(90), 4, 'X')))
    P.append(sphere("bowknot", (.1, .08, .1), loc=(0, -.86, bz), col="red_dark", seg=12, ring=6))
    # arms: right waving up, left relaxed; round cookie hands with icing cuffs
    for s_, end in ((1, V(1.6, -.12, 2.95)), (-1, V(-1.55, -.12, 1.7))):
        sh = V(.78 * s_, 0, 2.18)
        P += limb(f"arm{s_}", sh, end, .32, .28, 2, ["wood", "brown"], seed=2010 + s_, sy=.78, seg=14)
        hd = sphere(f"hand{s_}", (.3, .26, .3), loc=end + (end - sh).normalized() * .12, col="wood", seg=16, ring=10); P.append(hd)
        P += icing_zigzag(f"hzz{s_}", bvh_of([hd]), end + (end - sh).normalized() * .12, (0, -1, 0), (end - sh).normalized().cross(V(0, -1, 0)), .45, amp=.05, n=7)
    # peppermint lollipop in the left hand
    lp = V(-1.82, -.42, 2.62)
    P.append(tube("stick", [V(-1.68, -.38, 1.55), lp - V(0, 0, .3)], radius=.05, col="snow", seg=8))
    disc = cyl("pep", .4, .4, .14, col="snow", seg=28, bevel=.04); disc.matrix_world = M(lp - V(0, -.07, 0), (0, -1, 0)); P.append(disc)
    sw = [lp + V(.36 * (t / 22) * math.cos(t * .62), -.085, .36 * (t / 22) * math.sin(t * .62)) for t in range(1, 23)]
    P.append(tube("pepswirl", sw, radius=.05, col="candy_red", seg=6))
    P.append(torus("peprim", .4, .045, loc=lp, rot=(90, 0, 0), col="candy_red", seg=28, mseg=5))
    return P, {"glow": []}


REG = {"izalco": izalco, "pixelin": pixelin, "tamalito": tamalito, "jengibrin": jengibrin}
REG_RARITY = {"izalco": "mythic", "pixelin": "secret", "tamalito": "event", "jengibrin": "event"}
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
