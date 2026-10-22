"""Temporada Meme 2: 8 ORIGINAL piñatas riffing on Oct-2026 Latino + global trends (plan/TRENDS_MEMES_2.md).
Same pipeline/look as creatures.py / memes.py + fase-3 kawaii faces (kawaii.py).
CLI: blender -b --factory-startup -P memes2.py -- [name ...]   (env PREVIEW=1 -> /tmp/prev, low samples)
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
import creatures as C
from creatures import M, cone_prof, ellip_prof, lin_prof, limb, chain
from plib import *
import kawaii as K
from kawaii import V, eyes2, eye2, plate, mouth2, nose2, paw, blush2, bvh_of, decal, ear_inner
from memes import glove, shoe, sign_board, bake, gold_chain
from props import text_mesh
from animals2 import build2
from mathutils import Vector, Matrix

def upright(name, pts2d, thick, col, loc, rz=0.0, rx=90.0, bevel=.04):
    """2D shape (x, y) standing in the XZ plane (faces -Y), rotated rz about Z."""
    mtx = Matrix.Translation(loc) @ Matrix.Rotation(math.radians(rz), 4, 'Z') @ Matrix.Rotation(math.radians(rx), 4, 'X')
    return slab(name, pts2d, thick=thick, col=col, bevel=bevel, matrix=mtx)

def heart_pts(s=1.0, n=20):
    pts = []
    for k in range(n):
        t = 2 * math.pi * k / n
        x = 16 * math.sin(t) ** 3; y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x / 17 * s, y / 17 * s))
    return pts

def ellipse_pts(a, b, n=20, y0=0.0):
    return [(a * math.cos(2 * math.pi * k / n), y0 + b * math.sin(2 * math.pi * k / n)) for k in range(n)]

def hand(name, loc, d=(0, 0, 1), s=.22, col="lime", fingers=3, spread=40):
    """Chubby mitten hand: ball + finger nubs fanned around direction d."""
    d = Vector(d).normalized(); P = [sphere(name, (s, s, s * 1.05), loc=loc, col=col, seg=14, ring=8)]
    side = d.cross(V(0, -1, 0)); side = side.normalized() if side.length > 1e-3 else V(1, 0, 0)
    for k in range(fingers):
        a = math.radians((k - (fingers - 1) / 2) * spread)
        fd = (d * math.cos(a) + side * math.sin(a)).normalized()
        P.append(sphere(f"{name}f{k}", (s * .38,) * 3, loc=Vector(loc) + fd * s * .95, col=col, seg=10, ring=6))
    return P

def stars_ring(name, center, R, n=4, s=.16, col="neon_gold", tilt=12):
    G = []
    for k in range(n):
        a = 2 * math.pi * k / n + .3
        p = Vector(center) + V(R * math.cos(a), R * math.sin(a) * .6, R * .25 * math.sin(a + 1.2))
        G.append(star_prism(f"{name}{k}", 5, s, s * .45, s * .35, loc=p, rot=(90, 0, k * 20), col=col, bevel=0))
    return G

# ======================================================================= 1. GARROBITA TERENGA (epic)
def garrobita_terenga():
    """EPIC - Salvadoran garrobo (spiny-tailed iguana) cipota, hands up, eyes wandering, spilling her atol shuco.
    Riff on 'Bicha terenga' (SV, Oct 2026): 'yo soy una bicha terenga que levanta las manos'."""
    P = []; G = []
    body = fringe_body("body", ellip_prof(.88, 1.85, p=.8), 1.85, 5, ["lime", "jade", "lime", "lime", "jade"],
                       matrix=M((0, .05, .3)), seg=30, flare=.1, tooth=.07, seed=301, sy=.9)
    P += body
    P.append(plate("belly", (0, .05, 1.15), r=(.55, .3, .68), col="sun_yellow", fwd_off=.6))
    for k in range(3):   # belly scale stripes
        P.append(sphere(f"bs{k}", (.42 - .08 * abs(k - 1), .05, .035), loc=(0, -.86, .85 + .3 * k), col="mango", seg=12, ring=5))
    hc = V(0, -.05, 2.75)
    head = fringe_body("head", ellip_prof(1.0, 1.65, p=1.2), 1.65, 4, ["lime", "lime", "jade", "lime"],
                       matrix=M(hc - V(0, 0, .8)), seg=32, flare=.09, tooth=.06, seed=302, sx=1.12, sy=.98)
    P += head
    fp = plate("face", hc + V(0, 0, .05), r=(.84, .48, .62), col="lime", fwd_off=.66); P.append(fp)
    sn = plate("snout", hc + V(0, 0, -.32), r=(.6, .42, .34), col="lime", fwd_off=.95); P.append(sn)
    tree = bvh_of([fp, sn])
    # terenga eyes: one looks up-left, the other down-right
    P += eyes2("e", tree, hc + V(0, 0, .2), dx=.4, dz=0, size=.31, iris="sun_yellow", lid=None, lash=True,
               looks=[(.7, .6), (.6, -.7)], brow=True, brow_h=1.5, brow_tilt=-6, brow_arch=.25, brow_col="dark_green")
    P += mouth2("m", tree, hc + V(0, -3, -.42), w=.62, h=.26, smile=.7, col="ink", tongue=True, teeth=0)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.62 * s_, -3, -.15), size=.15)
        P += decal(f"nos{s_}", tree, hc + V(.13 * s_, -3, -.18), r=(.04, .03), col="dark_green")
    P.append(sphere("dewlap", (.3, .2, .22), loc=hc + V(0, -.8, -.78), col="sun_yellow", seg=14, ring=8))
    # dorsal crest: soft spikes from forehead down the back
    crest = [hc + V(0, -.35, 1.0), hc + V(0, .05, 1.05), hc + V(0, .45, .9), hc + V(0, .8, .55), V(0, .85, 2.0), V(0, .9, 1.55), V(0, .92, 1.1)]
    for k, p in enumerate(crest):
        d = (p - V(0, 0, p.z - .4 if k > 3 else hc.z)).normalized()
        P.append(cyl(f"cr{k}", .13 - .01 * k, .015, .32 - .02 * k, col="jade" if k % 2 else "sun_yellow", seg=8).copy() if False else
                 cyl(f"cr{k}", .13 - .008 * k, .015, .32 - .015 * k, col="jade" if k % 2 else "sun_yellow", seg=8))
        P[-1].matrix_world = M(p - d * .05, d)
    # hair bow
    bw = hc + V(.45, -.2, .85)
    for s_ in (-1, 1):
        P.append(sphere(f"bow{s_}", (.26, .12, .18), loc=bw + V(.22 * s_, 0, 0), rot=(0, 15 * s_, 0), col="fiesta_pink", seg=12, ring=8))
    P.append(sphere("bowc", (.1, .1, .1), loc=bw, col="hot_magenta", seg=10, ring=6))
    # arms UP ('que levanta las manos')
    for s_ in (-1, 1):
        sh = V(.72 * s_, -.15, 1.85); hd = V(1.25 * s_, -.3, 3.55)
        P += limb(f"arm{s_}", sh, hd, .2, .16, 3, ["lime", "jade", "lime"], seed=310 + s_, seg=12)
        P += hand(f"h{s_}", hd + (hd - sh).normalized() * .12, d=(hd - sh), s=.19, col="lime", fingers=3)
    # huacal (morro gourd bowl) of atol shuco tipping from the right hand, spilling
    hb = V(1.2, -.55, 3.95)
    bowl = sphere("huacal", (.5, .5, .36), loc=(0, 0, 0), col="wood_dark", seg=20, ring=10)
    bm = bmesh.new(); bm.from_mesh(bowl.data)
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, 0, .05), plane_no=(0, 0, 1), clear_outer=True)
    bm.to_mesh(bowl.data); bm.free(); paint(bowl, "wood_dark")
    tiltm = Matrix.Translation(hb) @ Matrix.Rotation(math.radians(48), 4, 'X') @ Matrix.Rotation(math.radians(-25), 4, 'Y')
    bowl.matrix_world = tiltm; P.append(bowl)
    P.append(torus("huacalrim", .47, .045, col="wood", seg=22, mseg=5)); P[-1].matrix_world = tiltm @ Matrix.Translation((0, 0, .04))
    atol = cyl("atol", .44, .44, .04, col="chocolate", seg=20); atol.matrix_world = tiltm @ Matrix.Translation((0, 0, -.01)); P.append(atol)
    lip = tiltm @ V(0, -.48, .04)
    P.append(tube("spill", [lip, lip + V(-.05, -.12, -.3), lip + V(-.08, -.14, -.7)], radius=.075, col="chocolate", seg=8, taper=[1.1, .8, .55]))
    for k, dz in enumerate((-.95, -1.25, -1.5)):
        P.append(sphere(f"drop{k}", (.08 - .015 * k,) * 2 + (.1 - .015 * k,), loc=lip + V(-.09, -.15, dz), col="chocolate", seg=8, ring=6))
    # legs + one loose chancla
    for s_ in (-1, 1):
        P += limb(f"leg{s_}", V(.42 * s_, 0, .6), V(.5 * s_, -.1, .2), .22, .2, 2, ["lime", "jade"], seed=320 + s_, seg=12)
        P += paw(f"ft{s_}", (.52 * s_, -.3, .16), fwd=(0, -1, .6), s=.24, col="lime", pad=None)
        for k in (-1, 0, 1):
            P.append(sphere(f"toe{s_}{k}", (.08, .08, .07), loc=(.52 * s_ + .1 * k, -.52, .08), col="lime", seg=8, ring=5))
    so = upright("sole", ellipse_pts(.22, .42, 18), .07, "fiesta_pink", (-.55, -.32, .02), rx=0, bevel=.02); P.append(so)
    P.append(tube("strap", [V(-.75, -.4, .05), V(-.55, -.5, .32), V(-.35, -.4, .05)], radius=.05, col="turquoise", seg=6))
    # ringed spiny tail curling behind
    tp = [(.2, .75, .5), (.8, 1.25, .35), (1.45, 1.35, .45), (1.85, 1.0, .75), (1.8, .55, 1.15)]
    P += striped_tube("tail", tp, .3, ["lime", "dark_green", "lime", "dark_green", "lime", "dark_green", "lime"], seg=12, taper=lambda t: 1 - .82 * t)
    # dizzy stars (terenga)
    G += stars_ring("dz", hc + V(0, 0, 1.25), .75, n=4, s=.15)
    return P + G, {"glow": G}

# ======================================================================= 2. FANTASMITA BU (epic)
def fantasmita_bu():
    """EPIC - sheet-ghost piñata lunging at you cross-eyed with puffed cheeks: '¡BÚ!'. Cempasúchil crown (Día de Muertos).
    Riff on the TikTok 'Boo Trend' (Sep-Oct 2026)."""
    P = []; G = []; lean = 12
    Lm = Matrix.Rotation(math.radians(-lean), 4, 'X')
    H = 3.1
    prof = lambda z: (1.12 + .2 * (1 - z / 1.2) ** 2) if z < 1.2 else 1.12 * max(0.0, 1 - ((z - 1.2) / (H - 1.2)) ** 2) ** .42
    cols = ["snow", "white", "snow", "white", "snow", "white", "lavender"]
    body = fringe_body("ghost", prof, H, 7, cols, matrix=Lm @ M((0, 0, .25)), seg=34, flare=.12, tooth=.09, seed=401)
    P += body
    # papel-picado coloured hem tassels
    hem = ["fiesta_pink", "mango", "turquoise", "lime", "grape", "sun_yellow"]
    for k in range(12):
        a = 2 * math.pi * k / 12; r = 1.38
        p0 = Lm @ V(r * math.cos(a), r * math.sin(a), .42)
        P.append(cyl(f"hem{k}", .14, .02, .38, col=hem[k % 6], seg=8))
        P[-1].matrix_world = M(p0, V(math.cos(a) * .4, math.sin(a) * .4, -1))
    hc = Lm @ V(0, 0, 2.15)
    f = (Lm.to_3x3() @ V(0, -1, 0)).normalized()
    fp = plate("face", hc, fwd=f, r=(.92, .5, .78), col="snow", fwd_off=.66); P.append(fp)
    # puffed cheeks
    for s_ in (-1, 1):
        P.append(sphere(f"cheek{s_}", (.3, .26, .26), loc=hc + f * 1.0 + V(.56 * s_, 0, -.34), col="snow", seg=14, ring=8))
    tree = bvh_of([fp] + P[-2:])
    P += eyes2("e", tree, hc + V(0, 0, .2), fwd=f, dx=.36, dz=0, size=.33, iris="grape", lid=None, lash=True,
               looks=[(-1.25, -.15), (1.25, -.15)], brow=True, brow_h=1.45, brow_tilt=12, brow_arch=.3, brow_col="ink_soft")
    P += mouth2("m", tree, hc + V(0, 0, -.48) + f * 3, fwd=f, w=.42, h=.5, shape="O", col="ink", tongue=True, lip="hot_magenta", depth=.08)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.55 * s_, 0, -.25) + f * 3, fwd=f, size=.17)
    # stubby arms thrown up
    for s_ in (-1, 1):
        a = Lm @ V(.95 * s_, -.1, 1.75); b = Lm @ V(1.55 * s_, -.55, 2.6)
        P += limb(f"arm{s_}", a, b, .26, .2, 2, ["snow", "white"], seed=410 + s_, seg=12)
        P.append(sphere(f"hand{s_}", (.24, .22, .24), loc=b + (b - a).normalized() * .1, col="snow", seg=14, ring=8))
    # cempasuchil crown
    top = Lm @ V(0, .05, H + .1)
    for k in range(7):
        a = math.pi * (k / 6) * 1.0 + math.pi * .0
        p = Lm @ V(.78 * math.cos(math.pi - a), .3 * math.sin(math.pi - a) - .15, H - .22 + .12 * math.sin(a))
        P.append(sphere(f"fl{k}", (.2, .2, .17), loc=p, col="mango" if k % 2 else "tangerine", seg=12, ring=8))
        for j in range(5):
            b = 2 * math.pi * j / 5
            P.append(sphere(f"fp{k}{j}", (.1, .1, .07), loc=p + V(.15 * math.cos(b), -.06, .15 * math.sin(b)), col="tangerine" if k % 2 else "mango", seg=8, ring=5))
    for k in range(3):
        P.append(slab(f"lf{k}", [(0, 0), (.15, .06), (.32, 0), (.15, -.06)], thick=.04, col="leaf", bevel=.01,
                      matrix=Matrix.Translation(Lm @ V(-.6 + .6 * k, .05, H - .15)) @ Matrix.Rotation(math.radians(60 + 30 * k), 4, 'Y')))
    # speech burst '¡BÚ!' (neon)
    t = text_mesh("bu", "¡BÚ!", size=.62, extrude=.06, col="neon_pink", rot=(90, 0, -8), bevel=.01, res=4)
    t.location = (1.55, -.9, 3.65); G.append(t)
    G += [star_prism(f"bs{k}", 4, .14, .04, .04, loc=loc, rot=(90, 0, 0), col="neon_gold", bevel=0) for k, loc in enumerate(((.75, -.9, 3.85), (2.45, -.9, 3.3)))]
    return P + G, {"glow": G}

# ======================================================================= 3. COCHINITO QUINCENA (legendary)
def cochinito_quincena():
    """LEGENDARY - piggy-bank piñata on payday: '$' eyes, coins bursting out of the slot, calendar on 15.
    Riff on #vivalaquincena (MX TikTok, Oct 2026): rich for two days, then broke."""
    P = []; G = []
    cols = ["bubblegum", "fiesta_pink", "bubblegum", "blush", "bubblegum", "fiesta_pink", "bubblegum", "blush"]
    body = fringe_body("body", ellip_prof(1.2, 2.7, p=.55), 2.7, 8, cols, matrix=M((0, 1.35, 1.55), (0, -1, 0)),
                       seg=28, flare=.09, tooth=.07, seed=501, sx=1.05)
    P += body
    for i, (x, y) in enumerate([(-.62, -.6), (.62, -.6), (-.62, .7), (.62, .7)]):
        P += limb(f"leg{i}", (x, y, .9), (x, y, .12), .28, .27, 2, ["bubblegum", "fiesta_pink"], seed=510 + i, round_end=.05)
        P.append(cyl(f"hoof{i}", .3, .28, .18, loc=(x, y, 0), col="hot_magenta", seg=16, bevel=.06))
    hc = V(0, -1.25, 1.75)
    fp = plate("face", hc, r=(1.0, .45, .88), col="bubblegum", fwd_off=.15); P.append(fp)
    sn = cyl("snout", .42, .4, .3, col="blush", seg=24, bevel=.08); sn.matrix_world = M(hc + V(0, -.48, -.35), (0, -1, 0)); P.append(sn)
    for s_ in (-1, 1):
        P.append(sphere(f"nost{s_}", (.08, .04, .12), loc=hc + V(.14 * s_, -.8, -.35), col="hot_magenta", seg=10, ring=6))
    tree = bvh_of([fp])
    # $ eyes
    for s_ in (-1, 1):
        e, p, n = eye2(f"e{s_}", tree, hc + V(.42 * s_, -4, .3), side=s_, size=.33, iris="gold", lid=None, lash=True, hl=True,
                       brow=True, brow_h=1.5, brow_tilt=-10, brow_arch=.3, brow_col="hot_magenta")
        P += e
        t1, t2, nn = K.basis(n)
        d = text_mesh(f"dol{s_}", "$", size=.42, extrude=.03, col="gold_deep", rot=(0, 0, 0), bevel=0, res=3)
        bake(d); K.place(d, p + n * .25, -t1, t2, nn); d.data.transform(Matrix.Identity(4)); P.append(d)
    P += mouth2("m", tree, hc + V(0, -4, -.75), w=.6, h=.24, smile=.8, col="ink", tongue=True, teeth=2)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.72 * s_, -4, -.3), size=.17)
        base = V(.62 * s_, -.85, 2.75)
        P += fringe_body(f"ear{s_}", cone_prof(.36, .7), .7, 2, ["bubblegum", "fiesta_pink"], matrix=M(base, (.45 * s_, -.5, .8)), seg=14, flare=.1, tooth=.05, seed=520 + s_, sy=.45)
    # coin slot + coins bursting
    P.append(box("slot", (.9, .16, .1), loc=(0, .35, 2.78), col="ink", bevel=.03))
    P.append(box("slotrim", (1.05, .3, .07), loc=(0, .35, 2.74), col="gold", bevel=.03))
    rnd = random.Random(7)
    for k in range(6):
        t = k / 5
        p = V(-.9 + 1.8 * t, .35 - .1 * math.sin(t * 6), 3.0 + 1.0 * math.sin(math.pi * t) + .1 * (k % 2))
        c = cyl(f"coin{k}", .23, .23, .07, col="gold", seg=16, bevel=.015)
        c.matrix_world = Matrix.Translation(p) @ Matrix.Rotation(math.radians(70 + rnd.uniform(-30, 30)), 4, 'X') @ Matrix.Rotation(math.radians(-50 + 100 * t), 4, 'Y')
        P.append(c)
        d = text_mesh(f"cd{k}", "$", size=.26, extrude=.02, col="gold_deep", rot=(0, 0, 0), bevel=0, res=2)
        d.matrix_world = c.matrix_world @ Matrix.Translation((0, 0, .075)); P.append(d)
    G += [star_prism(f"cs{k}", 4, .14, .04, .04, loc=loc, rot=(90, 0, 0), col="neon_gold", bevel=0) for k, loc in enumerate(((-.8, .1, 3.7), (.85, .1, 3.9), (.1, .1, 4.25)))]
    # curly tail
    tl = [V(.0 + .12 * math.cos(t * 4.5), 2.72 + .1 * t, 1.75 + .12 * math.sin(t * 4.5) + .25 * t) for t in [i / 10 for i in range(11)]]
    P.append(tube("tail", tl, radius=.07, col="fiesta_pink", seg=8))
    # tear-off calendar '15' (quincena)
    cx = V(1.75, -.6, 0)
    P.append(cyl("calpole", .05, .05, 1.7, loc=cx, col="wood", seg=8))
    P.append(cyl("calbase", .32, .36, .1, loc=cx, col="wood_dark", seg=16, bevel=.03))
    P += sign_board("cal", [("15", .62, -.12)], .95, .95, cx + V(0, -.02, 2.05), board="snow", ink="candy_red", rim="candy_red")
    P.append(box("calhead", (1.07, .16, .25), loc=cx + V(0, -.04, 2.6), col="candy_red", bevel=.04))
    t = text_mesh("calt", "QUINCENA", size=.13, extrude=.02, col="eye_white", rot=(90, 0, 0), bevel=0, res=3); t.location = cx + V(0, -.14, 2.6); P.append(t)
    return P + G, {"glow": G}

# ======================================================================= 4. LIC. DOS PECES (legendary)
def fish(tag, cx, cols, fin_col, flip=1, seed=0):
    P = []
    body = fringe_body(f"fb{tag}", ellip_prof(.85, 2.3, p=.85), 2.3, 5, cols, matrix=M((cx, 0, .55)), seg=26, flare=.1, tooth=.07, seed=seed, sy=.78)
    P += body
    # tail fin = feet
    tf = [(0, 0), (.55, -.35), (.75, -.05), (.4, .25), (0, .35), (-.4, .25), (-.75, -.05), (-.55, -.35)]
    P.append(upright(f"tail{tag}", tf, .14, fin_col, (cx, .05, .2), bevel=.05))
    # dorsal fin on top
    df = [(-.35, 0), (.0, .55), (.35, .35), (.4, 0)]
    P.append(slab(f"dfin{tag}", df, thick=.1, col=fin_col, bevel=.03, matrix=Matrix.Translation((cx, .1, 2.65)) @ Matrix.Rotation(math.radians(90), 4, 'Z') @ Matrix.Rotation(math.radians(90), 4, 'X')))
    hc = V(cx, 0, 1.95)
    fp = plate(f"face{tag}", hc, r=(.66, .4, .58), col=cols[0], fwd_off=.42); P.append(fp)
    belly = plate(f"bel{tag}", V(cx, 0, 1.0), r=(.5, .3, .45), col="snow", fwd_off=.48); P.append(belly)
    for k in range(3):   # scales
        for j in (-1, 1):
            P.append(sphere(f"sc{tag}{k}{j}", (.12, .04, .1), loc=(cx + j * (.35 + .1 * (k % 2)), -.66 + .03 * k, .95 + .3 * k), col=cols[1], seg=8, ring=5))
    return P, hc, fp

def lic_dos_peces():
    """LEGENDARY - two fish lawyers (tie, glasses, briefcase) defending the indefensible with a straight face.
    Riff on 'Two Fishes / Dos peces' (Love Island USA audio, #1 TikTok trend Oct 2026)."""
    P = []; G = []
    A, ha, fa = fish("a", -1.35, ["tangerine", "mango", "tangerine", "sun_yellow", "tangerine"], "chili", seed=601)
    B, hb, fb = fish("b", 1.35, ["sky", "turquoise", "sky", "snow", "sky"], "cobalt", flip=-1, seed=602)
    P += A + B
    for tag, hc, fp, iris, brow in (("a", ha, fa, "chocolate", "red_dark"), ("b", hb, fb, "cobalt", "ink")):
        tree = bvh_of([fp])
        P += eyes2(f"e{tag}", tree, hc + V(0, 0, .12), dx=.3, dz=0, size=.25, iris=iris, lid=("tangerine" if tag == "a" else "sky"), open_=.6, tilt=0,
                   brow=True, brow_h=1.35, brow_tilt=-14, brow_arch=.05, brow_col=brow, lash_col="ink")
        P += mouth2(f"m{tag}", tree, hc + V(0, -3, -.38), w=.2, h=.2, shape="O", col="ink", tongue=False, lip="candy_red")
        # side fins = hands
        for s_ in (-1, 1):
            p0 = V(hc.x + .78 * s_, -.2, 1.35)
            P.append(slab(f"pf{tag}{s_}", [(0, 0), (.45, .2), (.55, -.05), (.3, -.25)], thick=.08, col=("chili" if tag == "a" else "cobalt"), bevel=.03,
                          matrix=Matrix.Translation(p0) @ Matrix.Rotation(math.radians(90), 4, 'X') @ Matrix.Rotation(math.radians(0 if s_ > 0 else 180), 4, 'Y')))
    # fish A: glasses + tie + pointer stick to the board
    gc = ha + V(0, -.86, .14)
    for s_ in (-1, 1):
        r = torus(f"gl{s_}", .2, .03, loc=gc + V(.3 * s_, 0, 0), rot=(90, 0, 0), col="ink", seg=18, mseg=5); P.append(r)
    P.append(tube("glbr", [gc + V(-.1, 0, .02), gc + V(0, -.02, .05), gc + V(.1, 0, .02)], radius=.025, col="ink", seg=5))
    for x0 in (-1.35, 1.35):
        tie = [(0, 0), (.12, -.08), (.08, -.6), (0, -.72), (-.08, -.6), (-.12, -.08)]
        col = "candy_red" if x0 < 0 else "grape"
        P.append(upright(f"tie{x0}", tie, .06, col, (x0, -.82, 1.5), bevel=.02))
        P.append(sphere(f"knot{x0}", (.1, .07, .09), loc=(x0, -.84, 1.5), col=col, seg=10, ring=6))
        P.append(torus(f"collar{x0}", .55, .05, loc=(x0, -.05, 1.55), rot=(8, 0, 0), col="eye_white", seg=24, mseg=5))
    P.append(tube("stick", [V(-.6, -.45, 1.35), V(-.1, -.4, 2.2), V(.3, .35, 3.0)], radius=.035, col="wood", seg=6))
    # fish B: briefcase
    P.append(box("case", (.75, .22, .55), loc=(2.3, -.35, .95), col="brown", bevel=.05))
    P.append(torus("handle", .15, .035, loc=(2.3, -.35, 1.3), rot=(90, 0, 0), col="chocolate", seg=12, mseg=4, arc=180))
    P.append(box("clasp", (.12, .05, .08), loc=(2.3, -.47, 1.12), col="gold", bevel=.01))
    # whiteboard on an easel behind: fish + fish = check
    bc = V(0, .7, 3.05)
    P.append(box("board", (2.0, .08, 1.15), loc=bc, col="snow", bevel=.04))
    P.append(box("boardrim", (2.12, .06, 1.27), loc=bc + V(0, .03, 0), col="wood_dark", bevel=.03))
    for s_ in (-1, 1):
        P.append(tube(f"easel{s_}", [bc + V(.85 * s_, .05, .5), V(.95 * s_, .75, 0)], radius=.05, col="wood_dark", seg=6))
    fishicon = [(-.22, 0), (-.05, .12), (.12, .08), (.2, 0), (.12, -.08), (-.05, -.12), (-.22, 0), (-.32, .1), (-.32, -.1)]
    fishicon = ellipse_pts(.18, .1, 14)
    for k, (x, col) in enumerate(((-.7, "tangerine"), (-.05, "sky"))):
        P.append(upright(f"ic{k}", fishicon, .03, col, bc + V(x, -.05, .05), bevel=0))
        P.append(upright(f"ict{k}", [(0, 0), (.14, .1), (.14, -.1)], .03, col, bc + V(x + .14, -.05, .05), bevel=0))
    for k, (txt, x) in enumerate((("+", -.38), ("=", .3))):
        t = text_mesh(f"bt{k}", txt, size=.34, extrude=.02, col="ink", rot=(90, 0, 0), bevel=0, res=3); t.location = bc + V(x, -.06, .04); P.append(t)
    G.append(slab("check", [(-.1, 0), (0, -.1), (.22, .16), (.16, .21), (0, .04), (-.05, .08)], thick=.04, col="neon_green", bevel=0,
                  matrix=Matrix.Translation(bc + V(.65, -.07, .0)) @ Matrix.Rotation(math.radians(90), 4, 'X') @ Matrix.Scale(1.4, 4)))
    t = text_mesh("bth", "DOS PECES", size=.27, extrude=.02, col="ink_soft", rot=(90, 0, 0), bevel=0, res=3); t.location = bc + V(0, -.06, .38); P.append(t)
    return P + G, {"glow": G}

# ======================================================================= 5. PINOVELA (mythic)
def pinovela():
    """MYTHIC - the most dramatic pineapple in the telenovela: back of hand on forehead, glittering tears, a rose.
    Riff on 'Frutinovelas' (AI fruit soap operas, top LatAm TikTok 2026). Piña + piñata pun."""
    P = []; G = []
    cols = ["mango", "sun_yellow", "mango", "sun_yellow", "mango", "sun_yellow", "mango"]
    body = fringe_body("body", ellip_prof(1.05, 2.9, p=.75), 2.9, 7, cols, matrix=M((0, 0, .5)), seg=32, flare=.1, tooth=.08, seed=701, sy=.95)
    P += body
    # pineapple diamond eyes (little brown crosses) on the sides/back
    for k in range(14):
        a = math.radians(40 + 280 * k / 13); z = 1.0 + .45 * (k % 4)
        r = ellip_prof(1.05, 2.9, p=.75)(z - .5) * 1.06
        if abs(math.degrees(a) - 270) < 55: continue
        P.append(sphere(f"pe{k}", (.07, .07, .07), loc=(r * math.cos(a), r * .95 * math.sin(a), z), col="wood", seg=8, ring=5))
    hc = V(0, 0, 2.15)
    fp = plate("face", hc, r=(.85, .45, .78), col="sun_yellow", fwd_off=.62); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .22), dx=.38, dz=0, size=.33, iris="grape", lid="mango", open_=.72, tilt=14, lash=True,
               brow=True, brow_h=1.55, brow_tilt=22, brow_arch=.15, brow_col="chocolate", look=(0, .35))
    for s_ in (-1, 1):   # extra-long diva lashes
        for k in range(3):
            base = hc + V(.38 * s_ + (.18 + .08 * k) * s_, -1.0, .3 + .08 * k - .05)
            P.append(tube(f"lsh{s_}{k}", [base, base + V(.12 * s_, -.05, .1)], radius=.022, col="ink", seg=5, taper=[1, .3]))
    P += mouth2("m", tree, hc + V(0, -3, -.42), w=.32, h=.34, shape="O", col="ink", tongue=True, lip="candy_red")
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.6 * s_, -3, -.22), size=.16)
        # running mascara + glittering tears (neon)
        p0 = hc + V(.42 * s_, -1.08, -.15)
        P.append(tube(f"masc{s_}", [p0, p0 + V(.02 * s_, -.02, -.22), p0 + V(-.02 * s_, -.02, -.42)], radius=.025, col="ink_soft", seg=5, taper=[1, .8, .4]))
        G.append(sphere(f"tear{s_}", (.07, .06, .1), loc=hc + V(.58 * s_, -1.0, -.4), col="neon_cyan", seg=10, ring=6))
        G.append(sphere(f"tear2{s_}", (.05, .045, .07), loc=hc + V(.66 * s_, -.95, -.75), col="neon_cyan", seg=8, ring=5))
    # pearl necklace
    for k in range(13):
        a = math.radians(200 + 140 * k / 12)
        P.append(sphere(f"pearl{k}", (.07,) * 3, loc=(.9 * math.cos(a), .82 * math.sin(a) - .05, 1.42 + .25 * abs(math.cos(a)) * 0), col="eye_white", seg=8, ring=6))
    # crown of spiky leaves (diva hairdo)
    leaf = [(0, 0), (.16, .25), (.12, 1.0), (0, 1.25), (-.12, 1.0), (-.16, .25)]
    for k in range(11):
        a = 2 * math.pi * k / 11; tilt = 25 + 18 * (k % 2)
        h = 1.0 + .35 * ((k + 1) % 3) / 2
        m = Matrix.Translation((.15 * math.cos(a), .15 * math.sin(a), 3.25)) @ Matrix.Rotation(a + math.pi / 2, 4, 'Z') @ Matrix.Rotation(math.radians(-tilt), 4, 'X') @ Matrix.Diagonal((1, h, 1, 1))
        P.append(slab(f"leaf{k}", leaf, thick=.08, col="leaf" if k % 2 else "leaf_dark", bevel=.03, matrix=m @ Matrix.Rotation(math.radians(90), 4, 'X')))
    P.append(sphere("leafcore", (.32, .32, .25), loc=(0, 0, 3.3), col="leaf_dark", seg=14, ring=8))
    # dramatic arm: back of the hand on the forehead
    P += limb("armR", V(.9, -.2, 1.75), V(.45, -.85, 2.75), .19, .16, 2, ["mango", "sun_yellow"], seed=710, seg=12)
    P += glove("gR", V(.45, -.85, 2.75), (-.6, -.2, .35), s=.72, col="eye_white", cuff="candy_red", palm_up=True)
    # other arm offers a rose
    P += limb("armL", V(-.95, -.2, 1.55), V(-1.6, -.75, 1.65), .19, .16, 2, ["mango", "sun_yellow"], seed=711, seg=12)
    P += glove("gL", V(-1.6, -.75, 1.65), (-.3, -.6, .45), s=.72, col="eye_white", cuff="candy_red", curl=(0, 1, 2, 3))
    rp = V(-1.95, -1.2, 2.25)
    P.append(tube("stem", [V(-1.75, -.95, 1.6), V(-1.85, -1.1, 1.95), rp], radius=.035, col="leaf_dark", seg=6))
    for k in range(6):
        a = 2 * math.pi * k / 6
        P.append(sphere(f"pet{k}", (.14, .1, .12), loc=rp + V(.1 * math.cos(a), .1 * math.sin(a) * .6, .05 + .02 * (k % 2)), col="candy_red", seg=10, ring=6))
    P.append(sphere("petc", (.1, .1, .14), loc=rp + V(0, 0, .12), col="red_dark", seg=10, ring=6))
    # legs + heels
    for s_ in (-1, 1):
        P += limb(f"leg{s_}", V(.42 * s_, 0, .75), V(.48 * s_, -.1, .3), .18, .15, 2, ["mango", "sun_yellow"], seed=720 + s_, seg=10)
        P += shoe(f"heel{s_}", (.48 * s_, -.12, .08), col="fiesta_pink", sole="hot_magenta", s=.75)
        P.append(cyl(f"spike{s_}", .05, .04, .1, loc=(.48 * s_, .15, 0), col="hot_magenta", seg=8))
    # telenovela sparkle burst
    G += [star_prism(f"sp{k}", 4, .18, .05, .04, loc=loc, rot=(90, 0, 0), col="neon_pink", bevel=0) for k, loc in enumerate(((1.4, -.6, 3.6), (-1.35, -.6, 3.85), (1.75, -.6, 2.6)))]
    return P + G, {"glow": G}

# ======================================================================= 6. LA CHANCLA TELEDIRIGIDA (mythic)
def foot_pts(L=1.0, W=.5, n=32):
    """Flip-flop outline in XY (heel at -y, toe at +y): squarish, wide toe, pinched arch."""
    pts = []
    for k in range(n):
        t = 2 * math.pi * k / n; c, sn = math.cos(t), math.sin(t)
        y = L * .5 * math.copysign(abs(sn) ** .8, sn); u = y / L + .5
        w = W * .5 * (.64 + .46 * u ** 1.3) * (1 - .2 * math.exp(-((u - .42) / .15) ** 2))
        pts.append((w * math.copysign(abs(c) ** .75, c), y))
    return pts

def chancla_teledirigida():
    """MYTHIC - a flip-flop piñata with a 'you know what you did' face, neon sniper reticle and speed trail; a knocked cup.
    Riff on the chancla / 'Confío en mi latina' challenge (still viral in 2026: abuela chanclazos, mamá vs abuela)."""
    P = []; G = []
    tilt = 18
    Mc = Matrix.Translation((0, 0, 2.55)) @ Matrix.Rotation(math.radians(12), 4, 'Z') @ Matrix.Rotation(math.radians(-tilt), 4, 'Y') @ Matrix.Rotation(math.radians(-30), 4, 'X')
    pts = foot_pts(3.4, 2.05)
    layers = [("sky", .3, 0.0), ("eye_white", .18, .26), ("fiesta_pink", .24, .46)]   # foam sole layers (back->front)
    for k, (col, th, y) in enumerate(layers):
        P.append(slab(f"sole{k}", pts, thick=th, col=col, bevel=.06, bseg=2, matrix=Mc @ Matrix.Translation((0, -y, 0)) @ Matrix.Rotation(math.radians(90), 4, 'X')))
    front = -.6
    W = lambda x, z: Mc @ V(x, front, z)
    fpt = W(0, .15)
    sole_front = [o for o in P if o.name == "sole2"]
    tree = bvh_of(sole_front)
    f = (Mc.to_3x3() @ V(0, -1, 0)).normalized()
    # straps (Y) from the toe post
    post = W(0, .95)
    P.append(sphere("post", (.16, .16, .16), loc=post + f * .08, col="turquoise", seg=12, ring=8))
    for s_ in (-1, 1):
        P.append(tube(f"strap{s_}", [post + f * .1, W(.42 * s_, .45) + f * .5, W(.78 * s_, -.35) + f * .42, W(.92 * s_, -.95) + f * .05], radius=.15, col="turquoise", seg=12, taper=[.8, 1.15, 1.15, 1.0]))
        P.append(sphere(f"rivet{s_}", (.1, .1, .1), loc=W(.92 * s_, -.95) + f * .05, col="candy_teal", seg=10, ring=6))
    # face (lower half): fierce knowing eyes + smirk
    P += eyes2("e", tree, fpt + f * 3 + V(0, 0, 0), fwd=f, dx=.28, dz=-.42, size=.25, iris="chili", lid="fiesta_pink", open_=.62, tilt=-16,
               brow=True, brow_h=1.45, brow_tilt=-22, brow_arch=.05, brow_col="ink")
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, Mc @ V(.5 * s_, 0, -.78) + f * 3, fwd=f, size=.13)
    P += mouth2("m", tree, Mc @ V(.05, 0, -1.0) + f * 3, fwd=f, w=.42, h=.12, smile=1.5, col="ink", tongue=False, teeth=3)
    # neon sniper reticle in front + speed trail behind
    rc = V(-1.55, -1.1, 3.1)
    r = torus("ret", .42, .04, col="neon_pink", seg=32, mseg=5); r.matrix_world = Matrix.Translation(rc) @ Matrix.Rotation(math.radians(90), 4, 'X'); G.append(r)
    for a in (0, 90, 180, 270):
        d = V(math.cos(math.radians(a)), 0, math.sin(math.radians(a)))
        G.append(tube(f"rl{a}", [rc + d * .25, rc + d * .62], radius=.035, col="neon_pink", seg=5))
    G.append(sphere("retdot", (.06, .04, .06), loc=rc, col="neon_pink", seg=8, ring=5))
    for k in range(3):
        o = V(0, 0, .35 * (k - 1))
        pts3 = [Mc @ V(1.1, .4, 1.0) + o, V(1.9 + .1 * k, .7, 3.2) + o, V(2.6 + .1 * k, .9, 2.9) + o, V(3.1, 1.0, 2.2) + o]
        G.append(tube(f"trail{k}", pts3, radius=.09 - .015 * k, col="neon_cyan", seg=6, taper=[1, .8, .5, .1]))
    # pedestal: puff cloud + knocked-over cup trophy
    for k, (x, y, z, rr) in enumerate([(0, 0, .25, .7), (.65, .1, .2, .5), (-.65, .05, .2, .5), (.25, -.45, .18, .45)]):
        P.append(sphere(f"puff{k}", (rr * 1.2, rr, rr * .7), loc=(x, y, z), col="white" if k % 2 else "snow", seg=14, ring=8))
    cup = cyl("cup", .24, .3, .7, col="candy_teal", seg=18, bevel=.03); cup.matrix_world = Matrix.Translation((1.35, -.55, .3)) @ Matrix.Rotation(math.radians(90), 4, 'Y') @ Matrix.Rotation(math.radians(20), 4, 'X'); P.append(cup)
    P.append(torus("cuprim", .3, .04, col="eye_white", seg=18, mseg=5)); P[-1].matrix_world = Matrix.Translation((2.05, -.55, .3)) @ Matrix.Rotation(math.radians(90), 4, 'Y')
    G.append(star_prism("hit", 6, .3, .12, .04, loc=(2.25, -.6, .75), rot=(90, 0, 0), col="neon_gold", bevel=0))
    P.append(cyl("stem", .18, .22, 1.1, loc=(0, .1, .2), col="snow", seg=12))
    return P + G, {"glow": G}

# ======================================================================= 7. AURAZOSO (secret)
def aurazoso():
    """SECRET - a sloth chilling on a log in shades, scarf in the wind, neon aura ring: '+1000 AURA'.
    Riff on 'aura / farmear aura' (#4 classroom slang 2026)."""
    P = []; G = []
    # log seat
    P.append(cyl("log", .55, .55, 3.0, col="wood", seg=20, bevel=.06)); P[-1].matrix_world = M((-1.5, .15, .55), (1, 0, 0))
    for x in (-1.5, 1.5):
        P.append(cyl(f"logend{x}", .47, .47, .05, col="cream", seg=20)); P[-1].matrix_world = M((x + (.0 if x < 0 else -.04), .15, .55), (math.copysign(1, x), 0, 0))
        P.append(torus(f"ring{x}", .25, .02, col="wood", seg=16, mseg=4)); P[-1].matrix_world = M((x + (-.02 if x < 0 else .03), .15, .55), (1, 0, 0))
    for k in range(4):
        P.append(torus(f"bark{k}", .56, .035, col="bark", seg=24, mseg=4)); P[-1].matrix_world = M((-1.0 + .65 * k, .15, .55), (1, 0, 0))
    lean = 10
    Lm = Matrix.Translation((0, 0, 1.0)) @ Matrix.Rotation(math.radians(lean), 4, 'X')   # leaning back
    body = fringe_body("body", ellip_prof(.95, 2.0, p=.8), 2.0, 5, ["wood", "brown", "wood", "wood", "brown"], matrix=Lm, seg=30, flare=.11, tooth=.08, seed=801, sy=.9)
    P += body
    hc = Lm @ V(0, -.05, 2.55)
    head = fringe_body("head", ellip_prof(.92, 1.55, p=1.2), 1.55, 4, ["wood", "brown", "wood", "brown"], matrix=Lm @ M(V(0, -.05, 1.8)), seg=30, flare=.09, tooth=.06, seed=802, sx=1.12)
    P += head
    f = (Lm.to_3x3() @ V(0, -1, 0)).normalized()
    fp = plate("face", hc, fwd=f, r=(.8, .45, .62), col="cream", fwd_off=.6); P.append(fp)
    tree = bvh_of([fp])
    # sloth eye patches -> shades on top
    for s_ in (-1, 1):
        P += decal(f"patch{s_}", tree, hc + V(.34 * s_, 0, .02) + f * 3, fwd=f, r=(.28, .16), col="chocolate", roll=-18 * s_)
    gl_c = hc + f * 1.08 + V(0, 0, .1)
    for s_ in (-1, 1):
        lens = sphere(f"lens{s_}", (.3, .2, .08), col="ink", seg=16, ring=8)
        t1, t2, n = K.basis(f); K.place(lens, gl_c + t1 * -.34 * s_, t1, t2, n, roll=-8 * s_); P.append(lens)
        G.append(tube(f"glint{s_}", [gl_c + t1 * (-.34 * s_ + .12) + t2 * .1 + n * .07, gl_c + t1 * (-.34 * s_ - .02) + t2 * -.02 + n * .08], radius=.02, col="neon_cyan", seg=4))
        P.append(tube(f"arm_g{s_}", [gl_c + t1 * -.62 * s_, hc + V(.82 * s_, .25, .2)], radius=.03, col="ink", seg=5))
    P.append(tube("bridge", [gl_c + V(-.06, 0, .02), gl_c + V(.06, 0, .02)], radius=.035, col="ink", seg=5))
    P += nose2("nose", tree, hc + V(0, 0, -.16) + f * 3, fwd=f, size=.12, col="chocolate", shape="round")
    # smirk
    sp = [hc + f * 1.03 + V(-.18, 0, -.38), hc + f * 1.06 + V(.02, 0, -.42), hc + f * 1.02 + V(.22, 0, -.33)]
    P.append(tube("smirk", sp, radius=.03, col="ink", seg=6))
    # arm behind head + other arm resting with long claws
    P += limb("armR", Lm @ V(.8, .1, 1.55), Lm @ V(.95, .55, 2.85), .22, .18, 2, ["wood", "brown"], seed=810, seg=12)
    P += limb("armL", Lm @ V(-.8, -.1, 1.4), V(-1.25, -.55, 1.25), .22, .18, 2, ["wood", "brown"], seed=811, seg=12)
    for k in (-1, 0, 1):
        b = V(-1.32, -.68, 1.2) + V(.08 * k, 0, 0)
        P.append(tube(f"claw{k}", [b, b + V(.03 * k, -.12, -.15), b + V(.05 * k, -.05, -.32)], radius=.04, col="cream", seg=6, taper=[1, .7, .2]))
    P.append(sphere("handL", (.2, .2, .2), loc=(-1.3, -.6, 1.28), col="brown", seg=12, ring=8))
    # legs dangling
    for s_ in (-1, 1):
        P += limb(f"leg{s_}", V(.45 * s_, -.4, 1.2), V(.55 * s_, -.85, .45), .22, .19, 2, ["wood", "brown"], seed=820 + s_, seg=12)
        P.append(sphere(f"foot{s_}", (.22, .26, .2), loc=(.56 * s_, -.95, .38), col="brown", seg=12, ring=8))
    # scarf flowing in the wind
    nk = hc + V(0, 0, -.95)
    P.append(torus("scarf", .8, .14, col="fiesta_pink", seg=28, mseg=8)); P[-1].matrix_world = Matrix.Translation(nk) @ Lm.to_3x3().to_4x4() @ Matrix.Diagonal((1, 1, .65, 1))
    for k in range(6):
        a = math.radians(200 + 28 * k)
        st = box(f"scs{k}", (.08, .3, .2), loc=nk + Lm.to_3x3() @ V(.82 * math.cos(a), .82 * math.sin(a), 0), rot=(0, 0, math.degrees(a)), col="eye_white", bevel=.02); P.append(st)
    P.append(ribbon("scarftail", [nk + V(.5, -.6, 0), nk + V(1.1, -.5, .25), nk + V(1.7, -.2, .45), nk + V(2.2, .1, .4)], width=.32, normal=(0, -.3, 1), col="fiesta_pink", thick=.07))
    for k in range(3):
        P.append(box(f"sst{k}", (.08, .34, .1), loc=nk + V(1.0 + .45 * k, -.45 + .2 * k, .3 + .06 * k), rot=(0, 0, 20 * k), col="eye_white", bevel=.02))
    # aura: tilted neon ring + rising flames
    # aura: flame wisps rising behind the body (like a power-up silhouette)
    for k in range(9):
        a = math.radians(-70 + 140 * k / 8)
        r = 1.35 + .1 * (k % 2)
        p = V(r * math.sin(a), .55 + .35 * math.cos(a), 1.3 + .4 * math.cos(a))
        h = 1.4 + 1.0 * math.cos(a) + .3 * (k % 2)
        fl = cone_prof(.2, h)
        wisp = tube(f"fl{k}", [p, p + V(.15 * math.sin(a), .05, h * .5), p + V(.3 * math.sin(a) - .1 * (k % 3 - 1), .1, h)], radius=.17, col="neon_cyan" if k % 3 else "neon_pink", seg=8, taper=[1, .7, .05])
        G.append(wisp)
    P.append(torus("aurafloor", 1.6, .035, col="neon_cyan", seg=40, mseg=4)); G.append(P.pop()); G[-1].location = (0, .1, .06)
    t = text_mesh("auratxt", "+1000 AURA", size=.5, extrude=.06, col="neon_cyan", rot=(90, 0, 6), bevel=.0, res=2); t.location = (0, -.4, 4.55); G.append(t)
    return P + G, {"glow": G}

# ======================================================================= 8. ABUELITA EN VIVO (secret)
def abuelita_en_vivo():
    """SECRET - turtle abuelita in a crochet shawl going LIVE on a selfie stick; hearts and roses rain on her.
    Riff on abuelas 'facturando' on TikTok LIVE battles (Oct 2026)."""
    P = []; G = []
    # shell (dome) with scutes + rim, on her back
    sc = V(0, .55, 1.55)
    shell = sphere("shell", (1.25, .85, 1.45), loc=sc, col="wood", seg=28, ring=16); P.append(shell)
    P.append(torus("shellrim", 1.22, .12, col="mango", seg=36, mseg=6)); P[-1].matrix_world = Matrix.Translation(sc + V(0, -.25, 0)) @ Matrix.Rotation(math.radians(90), 4, 'X') @ Matrix.Diagonal((1, 1.17, 1, 1))
    stree = bvh_of([shell])
    for k, (x, z) in enumerate([(0, .55), (0, -.25), (-.62, .15), (.62, .15), (-.55, -.65), (.55, -.65), (0, 1.05), (-.75, .8), (.75, .8)]):
        P += decal(f"scute{k}", stree, sc + V(x, 3, z), fwd=(0, 1, 0), r=(.24, .24), col="brown", th=.05)
    # body (front belly) - fringe in jade with a cream plastron
    body = fringe_body("body", ellip_prof(.95, 2.1, p=.8), 2.1, 5, ["jade", "leaf", "jade", "jade", "leaf"], matrix=M((0, .05, .25)), seg=30, flare=.1, tooth=.07, seed=901, sy=.82)
    P += body
    P.append(plate("plastron", (0, .05, 1.15), r=(.62, .3, .72), col="cream", fwd_off=.55))
    # crochet shawl (rebozo) with tassels
    P += fringe_body("shawl", lambda z: 1.02 + .18 * (1 - z / .55), .55, 2, ["grape", "lavender"], matrix=M((0, -.02, 1.6)) @ Matrix.Rotation(math.radians(-8), 4, 'X'), seg=28, flare=.14, tooth=.09, seed=905, sy=.86)
    for k in range(9):
        a = math.radians(200 + 140 * k / 8)
        p = V(1.08 * math.cos(a), 1.0 * math.sin(a) - .1, 1.92)
        P.append(cyl(f"tas{k}", .05, .03, .32, col="lavender" if k % 2 else "fiesta_pink", seg=6)); P[-1].matrix_world = M(p, (0, 0, -1))
    hc = V(0, -.15, 3.05)
    head = fringe_body("head", ellip_prof(.88, 1.45, p=1.25), 1.45, 4, ["jade", "jade", "leaf", "jade"], matrix=M(hc - V(0, 0, .7)), seg=30, flare=.08, tooth=.06, seed=902, sx=1.1)
    P += head
    fp = plate("face", hc, r=(.78, .45, .6), col="jade", fwd_off=.55); P.append(fp)
    tree = bvh_of([fp])
    # happy squint eyes (lower lid) behind round glasses on the tip of the beak
    P += eyes2("e", tree, hc + V(0, 0, .12), dx=.32, dz=0, size=.24, iris="chocolate", lid=None, lower="jade", lash=True, look=(0, .2))
    gc = hc + V(0, -1.08, -.02)
    for s_ in (-1, 1):
        P.append(torus(f"gl{s_}", .22, .03, loc=gc + V(.32 * s_, 0, 0), rot=(90, 0, 0), col="gold", seg=20, mseg=5))
    P.append(tube("glbr", [gc + V(-.1, 0, .03), gc + V(0, -.03, .06), gc + V(.1, 0, .03)], radius=.025, col="gold", seg=5))
    P.append(tube("glchain", [gc + V(-.54, .05, 0), V(-.6, -.75, 2.3), gc + V(.54, .05, 0)], radius=.015, col="gold", seg=4))
    P += mouth2("m", tree, hc + V(0, -3, -.35), w=.48, h=.2, smile=1.0, col="ink", tongue=True)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.55 * s_, -3, -.2), size=.15)
        # wrinkle smile lines
        P += decal(f"wr{s_}", tree, hc + V(.64 * s_, -3, .12), r=(.06, .015), col="leaf_dark", roll=30 * s_)
    # silver bun (chongo) + flower
    P.append(sphere("bun", (.38, .36, .32), loc=hc + V(0, .15, .78), col="silver", seg=16, ring=10))
    P.append(torus("bunband", .3, .05, loc=hc + V(0, .15, .66), col="grape", seg=18, mseg=5))
    fl = hc + V(.32, -.1, .9)
    for k in range(5):
        a = 2 * math.pi * k / 5
        P.append(sphere(f"pt{k}", (.11, .06, .11), loc=fl + V(.11 * math.cos(a), -.02, .11 * math.sin(a)), col="fiesta_pink", seg=10, ring=6))
    P.append(sphere("ptc", (.07, .05, .07), loc=fl + V(0, -.05, 0), col="sun_yellow", seg=8, ring=5))
    # selfie stick + phone (screen glows) + EN VIVO badge
    P += limb("armR", V(.85, -.2, 1.85), V(1.45, -.65, 2.35), .2, .17, 2, ["jade", "leaf"], seed=910, seg=12)
    P.append(sphere("handR", (.2, .2, .2), loc=(1.5, -.7, 2.38), col="jade", seg=12, ring=8))
    P.append(tube("stick", [V(1.5, -.7, 2.38), V(1.7, -1.25, 3.45)], radius=.04, col="steel", seg=6))
    ph = V(1.75, -1.32, 3.75)
    phone = box("phone", (.52, .1, .92), loc=ph, rot=(-20, 0, 0), col="fiesta_pink", bevel=.06); P.append(phone)
    G.append(box("screen", (.42, .02, .8), loc=ph + V(0, .06, -.02), rot=(-20, 0, 0), col="neon_cyan", bevel=0))
    for j, (dx, dz) in enumerate(((-.12, .3), (-.12, .14))):
        P.append(cyl(f"lens{j}", .06, .06, .04, col="ink", seg=10)); P[-1].matrix_world = Matrix.Translation(ph + V(dx, -.06, dz)) @ Matrix.Rotation(math.radians(-20), 4, 'X') @ Matrix.Rotation(math.radians(90), 4, 'X')
    G.append(upright("caseheart", heart_pts(.14), .03, "neon_pink", ph + V(.08, -.07, -.15), rx=70, bevel=0))
    bd = V(-1.55, -.75, 4.25)
    P.append(box("badge", (1.2, .1, .4), loc=bd, rot=(0, 6, 0), col="candy_red", bevel=.06))
    t = text_mesh("vivo", "EN VIVO", size=.24, extrude=.02, col="eye_white", rot=(90, 0, 0), bevel=0, res=3); t.location = bd + V(.08, -.07, -.01); t.rotation_euler = (math.radians(90), math.radians(-6), 0); P.append(t)
    G.append(sphere("livedot", (.07, .04, .07), loc=bd + V(-.45, -.07, .0), col="neon_pink", seg=8, ring=5))
    # waving hand
    P += limb("armL", V(-.85, -.2, 1.9), V(-1.4, -.5, 2.75), .2, .17, 2, ["jade", "leaf"], seed=911, seg=12)
    P += hand("handL", V(-1.47, -.55, 2.9), d=(-.4, -.2, 1), s=.2, col="jade", fingers=3)
    # hearts + roses floating (neon hearts)
    for k, (loc, s) in enumerate((((.55, -.9, 4.35), .32), ((-.45, -.95, 4.75), .24), ((1.05, -1.0, 4.85), .2), ((-2.15, -.8, 3.4), .22))):
        G.append(upright(f"heart{k}", heart_pts(s), .07, "neon_pink", loc, rz=10 * k, bevel=.02))
    # stubby legs
    for s_ in (-1, 1):
        P += limb(f"leg{s_}", V(.45 * s_, -.1, .55), V(.52 * s_, -.25, .2), .26, .24, 2, ["jade", "leaf"], seed=920 + s_, seg=12)
        P.append(sphere(f"ft{s_}", (.3, .36, .2), loc=(.55 * s_, -.4, .16), col="jade", seg=14, ring=8))
    return P + G, {"glow": G}

MEMES2 = {"garrobita_terenga": garrobita_terenga, "fantasmita_bu": fantasmita_bu, "cochinito_quincena": cochinito_quincena,
          "lic_dos_peces": lic_dos_peces, "pinovela": pinovela, "chancla_teledirigida": chancla_teledirigida,
          "aurazoso": aurazoso, "abuelita_en_vivo": abuelita_en_vivo}
MEME2_RARITY = {"garrobita_terenga": "epic", "fantasmita_bu": "epic", "cochinito_quincena": "legendary", "lic_dos_peces": "legendary",
                "pinovela": "mythic", "chancla_teledirigida": "mythic", "aurazoso": "secret", "abuelita_en_vivo": "secret"}
MEME2_CAM = {"garrobita_terenga": (20, 10), "fantasmita_bu": (18, 10), "cochinito_quincena": (-30, 12), "lic_dos_peces": (10, 8),
             "pinovela": (18, 10), "chancla_teledirigida": (12, 10), "aurazoso": (20, 10), "abuelita_en_vivo": (16, 10)}
C.CREATURES.update(MEMES2); C.RARITY.update(MEME2_RARITY); C.CAM.update(MEME2_CAM)

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    prev = os.environ.get("PREVIEW")
    metas = []
    for n in (argv or list(MEMES2)):
        if prev:
            os.makedirs("/tmp/prev", exist_ok=True)
            metas.append(build2(n, samples=int(os.environ.get("SAMPLES", "24")), res=(700, 700), out=f"/tmp/prev/{n}.png"))
        else:
            metas.append(build2(n, samples=int(os.environ.get("SAMPLES", "96"))))
    if not prev:
        mf = f"{ROOT}/export/creatures/_meta.json"; old = json.load(open(mf))
        for m in metas: old[m["name"]] = m
        json.dump(old, open(mf, "w"), indent=1)
