"""Colección LatAm (fase 4): 19 piñatas, una por país (plan/LATAM_COLLECTION.md).
Same pipeline as randoms.py (palette UVs, fringe bands, kawaii faces, _Neon mesh) + a hanging hook (paper knot + gold ring).
CLI: blender -b --factory-startup -P latam.py -- [name ...]   (env PREVIEW=1 -> /tmp/prev, low samples)
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
import creatures as C
from creatures import M, cone_prof, ellip_prof, lin_prof, limb, chain
from plib import *
import kawaii as K
from kawaii import V, eyes2, eye2, plate, mouth2, nose2, paw, blush2, bvh_of, decal, ear_inner, hit, basis, place
from memes import glove, shoe, sign_board
from memes2 import hand, heart_pts, upright, stars_ring, ellipse_pts
from props import text_mesh
from animals2 import build2
from mathutils import Vector, Matrix

from latam_lib import *

# ============================================================================= 1. SALTEÑA JUGOSA (common, Bolivia)
def saltena_jugosa():
    """COMMON - a juicy Bolivian salteña with its braided repulgue as a crest, a napkin bib and a drip she's trying not to lose.
    Joke: 'si se te chorrea, perdiste'."""
    P = []; G = []
    L = 3.0; R = 1.02; cz = 1.25
    prof = ellip_prof(R, L, p=1.25)
    body = fringe_body("body", prof, L, 7, ["mango", "tangerine", "mango", "mango", "mango", "tangerine", "mango"], matrix=M(V(-L / 2, 0, cz), (1, 0, 0)),
                       seg=28, flare=.07, tooth=.05, seed=2001, sx=.62, sy=1.0)
    P += body
    tree_b = bvh_of(body)
    # repulgue: big braided crest along the top seam (twisted lobes) = the salteña signature
    N = 17
    for k in range(N):
        t = k / (N - 1); x = -L / 2 * .8 + L * .8 * t
        z = cz + prof(x + L / 2) * .96 + .02
        lob = sphere(f"rep{k}", (.2, .14, .25), loc=(x, 0, z), rot=(0, 40 if k % 2 else -40, 0), col="wood" if k % 2 else "brown", seg=12, ring=8)
        P.append(lob)
    hc = V(.0, 0, cz + .02)
    fp = plate("face", hc, r=(.8, .26, .62), col="mango", fwd_off=.42); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .14), dx=.3, dz=0, size=.25, iris="chocolate", lid="tangerine", open_=.95, tilt=10, lash=True,
               brow=True, brow_h=1.45, brow_tilt=22, brow_col="brown", look=(.3, -.5))
    P += mouth2("m", tree, hc + V(.0, -3, -.25), w=.24, h=.16, smile=-.3, col="ink", tongue=False, shape="O")
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.5 * s_, -3, -.1), size=.1)
    # the drip: one fat drop of caldo hanging from the mouth corner + a sweat drop
    mp, mn = hit(tree, hc + V(.11, -3, -.33), V(0, 1, 0))
    if mp is not None:
        P.append(tube("drip", [mp + mn * .03, mp + mn * .06 + V(.02, 0, -.1)], radius=.045, col="tangerine", seg=8, taper=[.7, 1]))
        P.append(sphere("drop", (.08, .07, .1), loc=mp + mn * .06 + V(.03, 0, -.19), col="tangerine", seg=12, ring=8))
        P.append(sphere("droph", (.025, .015, .03), loc=mp + mn * .13 + V(0, 0, -.16), col="eye_white", seg=6, ring=4))
    P.append(sphere("sweat", (.07, .05, .11), loc=hc + V(-.64, -.5, .42), col="sky", seg=10, ring=6))
    # napkin bib under the chin
    bib = [(-.45, 0), (.45, 0), (.14, -.42), (0, -.5), (-.14, -.42)]
    bp, bn = hit(tree_b, hc + V(0, -3, -.62), V(0, 1, 0))
    if bp is not None:
        t1, t2, n3 = basis(bn)
        o = slab("bib", bib, thick=.04, col="eye_white", bevel=.015); place(o, bp + bn * .06 + t2 * .04, t1, t2, n3); P.append(o)
        P.append(tube("bibtrim", [bp + bn * .09 + t1 * x + t2 * .05 for x in (-.42, -.14, .14, .42)], radius=.03, col="chili", seg=6))
    P += scatter("toast", tree_b, V(0, 0, cz), 18, "wood", 2002, r=(.05, .09), zr=(-.6, .9), avoid=[(hc + V(0, -.6, 0), .75)])
    # a little puddle already on the floor (too late...)
    P.append(sphere("puddle", (.32, .22, .02), loc=(.35, -.75, .02), col="tangerine", seg=16, ring=6))
    # panicking hands on the cheeks
    for s_ in (-1, 1):
        P += arm(f"arm{s_}", V(1.05 * s_, -.25, cz - .2), V(.95 * s_, -.75, cz + .05), r=.14, cols=("mango", "tangerine"), hand_col="mango",
                 hd=(-.4 * s_, -.3, .6), s=.17, seed=2003 + s_, fingers=4)
    P += legs2("leg", V(-.45, -.05, cz - .85), V(.45, -.05, cz - .85), r=.15, cols=("tangerine", "mango"), shoe_col="eye_white", sole="chili", s=.8, seed=2005)
    P += hook("hook", V(0, 0, cz + R + .3))
    return P + G, {"glow": G}

# ============================================================================= 2. CUCURUCHO MANÍ (common, Cuba)
def cucurucho_mani():
    """COMMON - a toasted peanut popping out of its paper cucurucho, shaking two maracas (the manisero's pregón).
    Joke: 'chiquito, tostadito y con más ritmo que tú'."""
    P = []; G = []
    z0 = .62; H = 2.0
    cone = fringe_body("cone", lambda z: .2 + .78 * (z / H) ** .9, H, 5, ["eye_white", "cream", "eye_white", "turquoise", "eye_white"], matrix=M(V(0, 0, z0)),
                       seg=26, flare=.06, tooth=.05, seed=2101)
    P += cone
    P.append(cyl("tip", .02, .2, .2, loc=(0, 0, z0 - .18), col="cream", seg=14))
    P.append(torus("rim", .98, .07, loc=(0, 0, z0 + H), col="eye_white", seg=34, mseg=6))
    ct = bvh_of(cone)
    tp, tn = hit(ct, V(0, -3, z0 + 1.15), V(0, 1, 0))
    t = text_mesh("txt", "MANÍ", size=.36, extrude=.04, col="chili", bevel=0, res=3)
    place_text(t, tp, tn, push=.07); P.append(t)
    # peanut (two-lobed fringe shell)
    pz = z0 + H - .55; PH = 2.0
    def pprof(z):
        a = .66 * math.sqrt(max(0, 1 - ((z - .62) / .66) ** 2)); b = .6 * math.sqrt(max(0, 1 - ((z - 1.42) / .6) ** 2))
        return max(a, b, .5 if .55 < z < 1.5 else 0)
    nut = fringe_body("nut", pprof, PH, 5, ["wood", "plaza_tile", "wood", "plaza_tile", "wood"], matrix=M(V(0, 0, pz)), seg=24, flare=.07, tooth=.05, seed=2102, sy=.9)
    P += nut
    hc = V(0, 0, pz + 1.38)
    fp = plate("face", hc, r=(.56, .26, .5), col="plaza_tile", fwd_off=.35); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .1), dx=.24, dz=0, size=.21, iris="brown", lid="wood", open_=.62, tilt=-4, lash=True,
               brow=True, brow_h=1.5, brow_tilt=-10, brow_col="wood_dark", look=(.2, .1))
    P += mouth2("m", tree, hc + V(0, -3, -.24), w=.32, h=.17, smile=1.2, col="ink", tongue=True, teeth=2)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.38 * s_, -3, -.1), size=.08)
    nt = bvh_of(nut)
    P += scatter("dimp", nt, V(0, 0, pz + .9), 22, "wood_dark", 2103, r=(.03, .05), zr=(-.8, .8), avoid=[(hc + V(0, -.5, 0), .55)])
    # arms with maracas up
    for s_ in (-1, 1):
        a = V(.5 * s_, -.1, pz + .75); b = V(1.05 * s_, -.3, pz + 1.3)
        P += limb(f"arm{s_}", a, b, .13, .11, 2, ["wood", "plaza_tile"], seed=2104 + s_, seg=12)
        P += hand(f"h{s_}", b + V(.06 * s_, -.04, .08), d=(.3 * s_, 0, 1), s=.15, col="plaza_tile")
        P += maraca(f"mar{s_}", b + V(.06 * s_, -.06, .12), (.45 * s_, -.15, 1), s=.9, cols=("chili", "sun_yellow", "cobalt") if s_ < 0 else ("cobalt", "sun_yellow", "chili"))
    # little feet poking out under the cone tip
    for s_ in (-1, 1):
        P += limb(f"leg{s_}", V(.08 * s_, 0, .55), V(.32 * s_, -.08, .18), .09, .08, 1, ["wood"], seed=2110 + s_, seg=10)
        P += shoe(f"sh{s_}", (.34 * s_, -.1, 0), col="eye_white", sole="cobalt", s=.7)
    # loose peanuts on the floor
    for k, (x, y, rz) in enumerate(((.95, -.55, 30), (-.9, -.35, -50), (.6, -.95, 100))):
        for j in (-1, 1):
            d = V(math.cos(math.radians(rz)), math.sin(math.radians(rz)), 0) * .1 * j
            P.append(sphere(f"loose{k}{j}", (.13, .11, .1), loc=V(x, y, .1) + d, rot=(0, 0, rz), col="wood", seg=10, ring=6))
    P += hook("hook", V(0, 0, pz + PH - .02))
    return P + G, {"glow": G}

# ============================================================================= 3. AREPA REINA (common, Venezuela)
def arepa_reina():
    """COMMON - a Venezuelan arepa standing like a coin, stuffed with reina pepiada (the filling bursts out like hair) and a tiny crown.
    Joke: 'rellena de cariño... y de aguacate'."""
    P = []; G = []
    R = 1.22; T = .72; cz = 1.55
    prof = lambda z: R * (.8 + .2 * math.sqrt(max(0.0, 1 - ((2 * z / T) - 1) ** 2)))
    disc = fringe_body("disc", prof, T, 2, ["wood", "plaza_tile"], matrix=M(V(0, T / 2, cz), (0, -1, 0)), seg=34, flare=.07, tooth=.06, seed=2201)
    P += disc
    hc = V(0, 0, cz - .05)
    fp = plate("face", hc, r=(1.06, .14, 1.0), col="cream", fwd_off=.3); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .15), dx=.36, dz=0, size=.27, iris="jade", lid="plaza_tile", open_=.85, tilt=0, lash=True,
               brow=True, brow_h=1.5, brow_tilt=8, brow_col="wood_dark", look=(-.15, .25))
    P += mouth2("m", tree, hc + V(0, -3, -.32), w=.42, h=.22, smile=1.2, col="ink", tongue=True)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.62 * s_, -3, -.15), size=.12)
    P += scatter("toast", tree, hc, 14, "wood", 2202, r=(.07, .13), zr=(-1.0, 1.0), yaw=(-.55, .55), th=.02,
                 avoid=[(hc + V(-.36, -.4, .15), .42), (hc + V(.36, -.4, .15), .42), (hc + V(-.36, -.4, .6), .3), (hc + V(.36, -.4, .6), .3), (hc + V(0, -.4, -.32), .36)])
    # reina pepiada filling bursting out of the top slit = her hairdo
    rnd = random.Random(2203)
    for k in range(17):
        a = math.radians(40 + 100 * k / 16); r = R * .97
        p = V(r * math.cos(a), rnd.uniform(-.12, .12), cz + r * math.sin(a) + .04)
        col = "lime" if k % 3 else "leaf"
        P.append(sphere(f"fill{k}", (.25, .2, .21), loc=p, rot=(0, rnd.uniform(0, 90), 0), col=col, seg=12, ring=8))
        if k % 4 == 1:
            P.append(box(f"chick{k}", (.17, .14, .13), loc=p + V(0, -.13, .12), rot=(rnd.uniform(-30, 30), 20, rnd.uniform(0, 90)), col="white", bevel=.04))
    for s_ in (-1, 1):   # avocado slices poking out
        P.append(sphere(f"avo{s_}", (.34, .08, .15), loc=(.55 * s_, -.06, cz + 1.2), rot=(0, -35 * s_, 0), col="lime", seg=14, ring=8))
        P.append(sphere(f"avos{s_}", (.35, .07, .06), loc=(.6 * s_, -.06, cz + 1.31), rot=(0, -35 * s_, 0), col="dark_green", seg=14, ring=6))
    cc = V(.1, 0, cz + R + .26)
    P.append(cyl("crown", .3, .34, .2, loc=cc, col="gold", seg=24, bevel=.02))
    for k in range(5):
        a = 2 * math.pi * k / 5 - math.pi / 2
        b = cc + V(.3 * math.cos(a), .3 * math.sin(a), .18)
        P.append(cyl(f"cp{k}", .09, .01, .26, loc=b, col="gold", seg=8)); P.append(sphere(f"cpb{k}", (.05,) * 3, loc=b + V(0, 0, .27), col="gold_pale", seg=8, ring=5))
    for k, col in enumerate(("candy_red", "candy_teal", "candy_red")):
        a = -math.pi / 2 + (k - 1) * .7
        P.append(sphere(f"gem{k}", (.05, .03, .06), loc=cc + V(.33 * math.cos(a), .33 * math.sin(a), .1), col=col, seg=8, ring=5))
    P += arm("armR", V(1.0, -.1, cz - .1), V(1.45, -.25, cz + .55), r=.13, cols=("plaza_tile", "cream"), hand_col="cream", hd=(.2, 0, 1), s=.17, seed=2204, fingers=4)
    P += arm("armL", V(-1.0, -.1, cz - .25), V(-1.3, -.3, cz - .65), r=.13, cols=("plaza_tile", "cream"), hand_col="cream", hd=(.3, -.2, -.3), s=.16, seed=2205)
    P += legs2("leg", V(-.38, 0, cz - 1.05), V(.38, 0, cz - 1.05), r=.14, cols=("plaza_tile", "cream"), shoe_col="fiesta_pink", sole="hot_magenta", s=.8, seed=2206)
    P += hook("hook", cc + V(0, 0, .3), s=.9)
    return P + G, {"glow": G}

# ============================================================================= 4. COMPLETITO ITALIANO (uncommon, Chile)
def completito_italiano():
    """UNCOMMON - a Chilean completo italiano: bun body, vienesa, tomato + palta + mayo (Italian flag colours) and shades.
    Joke: 'palta, tomate y mayo: se cree italiano'."""
    P = []; G = []
    L = 3.4; cz = 1.05
    bun = fringe_body("bun", ellip_prof(.78, L, p=.55), L, 7, ["wood", "plaza_tile", "wood", "wood", "plaza_tile", "wood", "wood"], matrix=M(V(-L / 2, 0, cz), (1, 0, 0)),
                      seg=26, flare=.07, tooth=.05, seed=2301, sx=.88, sy=.72)
    P += bun
    # vienesa on top, poking out at both ends
    vz = cz + .5
    P.append(tube("vien", [V(-1.95, 0, vz - .05), V(-1, 0, vz + .02), V(0, 0, vz + .04), V(1, 0, vz + .02), V(1.95, 0, vz - .05)], radius=.27, col="terracotta", seg=16,
                  taper=[.75, 1, 1, 1, .75]))
    for s_ in (-1, 1):
        P.append(sphere(f"vend{s_}", (.21, .21, .21), loc=(1.97 * s_, 0, vz - .05), col="terracotta", seg=14, ring=8))
    rnd = random.Random(2302)
    for k in range(14):   # tomato cubes
        x = -1.45 + 2.9 * k / 13
        P.append(box(f"tom{k}", (.2, .2, .18), loc=(x + rnd.uniform(-.06, .06), rnd.uniform(-.2, .2), vz + .28), rot=(rnd.uniform(-20, 20), rnd.uniform(-20, 20), rnd.uniform(0, 90)), col="chili", bevel=.04))
    for k in range(13):   # palta mash
        x = -1.4 + 2.8 * k / 12
        P.append(sphere(f"palta{k}", (.27, .3, .17), loc=(x, rnd.uniform(-.06, .06), vz + .45), rot=(0, 0, rnd.uniform(0, 90)), col="lime" if k % 3 else "leaf", seg=14, ring=8))
    mp = []
    for k in range(25):   # mayo zig-zag
        x = -1.35 + 2.7 * k / 24
        mp.append(V(x, .18 * (1 if k % 2 else -1), vz + .66))
    P.append(tube("mayo", mp, radius=.075, col="white", seg=8))
    # face on the bun front
    hc = V(.1, 0, cz + .02)
    fp = plate("face", hc, r=(.86, .22, .5), col="plaza_tile", fwd_off=.6); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .2), dx=.33, dz=0, size=.2, iris="cobalt", lid="wood", open_=.55, tilt=-6, lash=True,
               brow=True, brow_h=1.55, brow_tilt=-14, brow_col="wood_dark", look=(-.2, 0))
    P += mouth2("m", tree, hc + V(.02, -3, -.25), w=.42, h=.17, smile=1.3, col="ink", tongue=True, teeth=2, push=.03)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.55 * s_, -3, -.08), size=.09)
    # sunglasses pushed up on the palta "hair"
    gz = V(.15, -.32, vz + .55)
    for s_ in (-1, 1):
        P.append(cyl(f"lens{s_}", .17, .17, .05, col="ink", seg=18)); P[-1].matrix_world = M(gz + V(.22 * s_, 0, 0), (0, -1, .5))
        P.append(torus(f"frame{s_}", .17, .025, col="sun_yellow", seg=18, mseg=4)); P[-1].matrix_world = M(gz + V(.22 * s_, -.03, 0), (0, -1, .5))
    P.append(tube("bridge", [gz + V(-.06, -.03, 0), gz + V(0, -.05, .03), gz + V(.06, -.03, 0)], radius=.025, col="sun_yellow", seg=5))
    # arms: hand on hip + thumbs up
    P += arm("armL", V(-.9, -.35, cz - .05), V(-1.25, -.55, cz - .45), r=.13, cols=("wood", "plaza_tile"), hand_col="plaza_tile", hd=(.4, -.2, -.2), s=.15, seed=2303)
    P += arm("armR", V(.9, -.35, cz - .05), V(1.3, -.6, cz + .3), r=.13, cols=("wood", "plaza_tile"), hand_col="plaza_tile", hd=(0, 0, 1), s=.16, seed=2304, fingers=1)
    P += legs2("leg", V(-.55, -.05, cz - .4), V(.55, -.05, cz - .4), r=.13, cols=("wood", "plaza_tile"), shoe_col="eye_white", sole="chili", s=.8, seed=2305)
    P += hook("hook", V(0, 0, vz + .78), s=.9)
    return P + G, {"glow": G}

# ============================================================================= 5. PLATANITO MERENGUERO (uncommon, Dominican Republic)
def platanito_merenguero():
    """UNCOMMON - a green plantain dancing merengue: güira + scraper in hand, tambora at his feet, hips out.
    Joke: 'no lo majes: está bailando'."""
    P = []; G = []
    z0 = .45; H = 3.5; Rb = 3.4; zb = 1.2
    prof = lambda z: max(.16, .68 * math.sin(math.pi * min(max(z / H, 0), 1)) ** .5)
    body = fringe_body("pl", prof, H, 12, ["lime", "lime", "leaf"] * 4, matrix=M(V(0, 0, z0)), seg=18, flare=.035, tooth=.03, seed=2401, sx=.92, sy=.86, seg_core=14)
    # longitudinal ridges (the plantain's edges) - built straight, bent with the body
    rid = []
    for k, a in enumerate((-2.2, -1.25, 1.25, 2.2, math.pi)):
        pts = [V(prof(z) * 1.06 * .92 * math.cos(a + math.pi / 2) * 1.0, prof(z) * 1.06 * .86 * math.sin(a + math.pi / 2) * -1.0, z0 + z) for z in [H * (.08 + .84 * i / 14) for i in range(15)]]
        rid.append(tube(f"ridge{k}", pts, radius=.035, col="leaf_dark", seg=5))
    bend(body + rid, Rb, zb); P += body + rid
    def bp(z, x=0.0, y=0.0):
        if z <= zb: return V(x, y, z)
        th = (z - zb) / Rb; d = Rb - x
        return V(Rb - d * math.cos(th), y, zb + d * math.sin(th))
    tipb = bp(z0); tipt = bp(z0 + H)
    P.append(sphere("tipb", (.18, .18, .15), loc=tipb + V(0, 0, .02), col="dark_green", seg=12, ring=8))
    th = (z0 + H - zb) / Rb
    P.append(cyl("stem", .11, .08, .38, col="wood_dark", seg=10)); P[-1].matrix_world = M(tipt - V(math.sin(th), 0, math.cos(th)) * .08, (math.sin(th), 0, math.cos(th)))
    hc = bp(2.45)
    fp = plate("face", hc, r=(.6, .3, .62), col="lime", fwd_off=.42); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .14), dx=.25, dz=0, size=.23, iris="chocolate", lid="leaf", open_=.5, tilt=-2, lash=True,
               brow=True, brow_h=1.55, brow_tilt=-6, brow_col="dark_green", look=(.3, .2))
    P += mouth2("m", tree, hc + V(.03, -3, -.27), w=.34, h=.18, smile=1.5, col="ink", tongue=True, teeth=2)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.4 * s_, -3, -.1), size=.09)
    sh = bp(1.95)
    # güira (left) and scraper (right)
    gc = sh + V(-1.05, -.55, .05); gd = V(.35, -.15, 1).normalized()
    g = cyl("guira", .17, .17, .95, col="silver", seg=18, bevel=.02); g.matrix_world = M(gc - gd * .45, gd); P.append(g)
    P.append(torus("guirah", .16, .035, col="steel", seg=14, mseg=4)); P[-1].matrix_world = M(gc + gd * .52, gd) @ Matrix.Rotation(math.radians(90), 4, 'X')
    side = gd.cross(V(0, 1, 0)).normalized(); up2 = gd.cross(side)
    for i in range(6):
        for j in range(7):
            a = -1.4 + 2.8 * j / 6
            p = gc + gd * (-.35 + .14 * i) + (side * math.cos(a) - up2 * math.sin(a)) * .172
            if (p - gc).dot(V(0, -1, 0)) < -.05: continue
            P.append(sphere(f"gh{i}{j}", (.02, .02, .02), loc=p, col="ink_soft", seg=6, ring=4))
    P += arm("armL", sh + V(-.5, -.2, .1), gc + V(.1, 0, 0), r=.14, cols=("leaf", "lime"), hand_col="lime", hd=(-.2, -.3, 1), s=.17, seed=2402)
    sc = sh + V(1.0, -.65, 0)
    P.append(cyl("scrh", .06, .07, .38, col="wood", seg=8)); P[-1].matrix_world = M(sc, (-.8, -.2, .25))
    tip = sc + V(-.8, -.2, .25).normalized() * .36
    for k in range(5):
        P.append(cyl(f"tine{k}", .012, .012, .38, col="steel", seg=4)); P[-1].matrix_world = M(tip + V(0, 0, (k - 2) * .035), (-.9, -.2, .1))
    P += arm("armR", sh + V(.55, -.2, .05), sc + V(.05, .05, -.05), r=.14, cols=("leaf", "lime"), hand_col="lime", hd=(-.4, -.2, .3), s=.17, seed=2403)
    P += limb("legL", V(-.25, -.05, .8), V(-.55, -.15, .22), .16, .14, 2, ["leaf", "lime"], seed=2404, seg=12)
    P += shoe("shL", (-.6, -.17, 0), col="eye_white", sole="cobalt", s=.85)
    P += limb("legR", V(.25, -.05, .8), V(.5, -.25, .5), .16, .14, 2, ["leaf", "lime"], seed=2405, seg=12)
    P += shoe("shR", (.55, -.3, .3), col="eye_white", sole="cobalt", s=.85)
    tb = V(1.35, .45, .38)
    P.append(cyl("tamb", .36, .36, .8, col="wood_dark", seg=22, bevel=.03)); P[-1].matrix_world = M(tb - V(.4, 0, 0), (1, 0, 0))
    for s_ in (-1, 1):
        P.append(cyl(f"tambh{s_}", .38, .38, .05, col="cream", seg=22)); P[-1].matrix_world = M(tb + V(.4 * s_ - .025, 0, 0), (1, 0, 0))
        P.append(torus(f"tambr{s_}", .38, .04, col="chili", seg=22, mseg=4)); P[-1].matrix_world = M(tb + V(.38 * s_, 0, 0), (1, 0, 0))
    zz = []
    for k in range(13):
        a = 2 * math.pi * k / 12; x = .34 if k % 2 else -.34
        zz.append(tb + V(x, .37 * math.cos(a), .37 * math.sin(a)))
    P.append(tube("tambz", zz, radius=.02, col="eye_white", seg=4))
    for k, (x, z, c) in enumerate(((-1.6, 3.05, "fiesta_pink"), (1.9, 2.6, "cobalt"), (-1.1, 3.65, "chili"))):
        P += note(f"n{k}", (x, -.5, z), s=.28, col=c, rz=10 * k)
    P += hook("hook", tipt + V(math.sin(th), 0, math.cos(th)) * .32, s=.85)
    return P + G, {"glow": G}

# ============================================================================= 6. BALEADA CON TODO (uncommon, Honduras)
def baleada_con_todo():
    """UNCOMMON - a Honduran baleada (folded flour tortilla) overflowing with everything: beans, egg, avocado, plátano, cheese.
    Joke: 'pidió sencilla y le pusieron de todo'."""
    P = []; G = []
    R = 1.42; cz = 2.4
    L = 2 * R
    shells = []
    for s_, col in ((-1, "plaza_tile"), (1, "cream")):
        semi = [(R * math.cos(a), R * math.sin(a)) for a in [math.pi + math.pi * k / 28 for k in range(29)]]
        o = upright(f"shell{s_}", semi, .14, col, V(0, .3 * s_, cz), bevel=.05); P.append(o); shells.append(o)
    # the folded edge: a fat rolled tortilla along the round bottom
    arc = [V((R - .12) * math.cos(a), 0, cz + (R - .12) * math.sin(a)) for a in [math.pi * (1.03 + .94 * k / 20) for k in range(21)]]
    P.append(tube("fold", arc, radius=.36, col="cream", seg=14, taper=[.75] + [1] * 19 + [.75]))
    # crepe-paper fringe teeth around the rim (two layered rows, piñata style)
    for row, (rr, col, y) in enumerate(((R + .02, "wood", -.41), (R - .16, "cream", -.43))):
        n = 40 - 6 * row
        for k in range(n):
            a0 = math.pi * (1 + k / n); a1 = math.pi * (1 + (k + 1) / n); am = (a0 + a1) / 2
            tri = [(rr * .93 * math.cos(a0), rr * .93 * math.sin(a0)), (rr * .93 * math.cos(a1), rr * .93 * math.sin(a1)),
                   ((rr + .09) * math.cos(am), (rr + .09) * math.sin(am))]
            P.append(upright(f"tooth{row}_{k}", tri, .04, col, V(0, y, cz), bevel=0))
    tree_s = bvh_of([shells[0]])
    hc = V(0, 0, cz - .72)
    P += face_std("f", tree_s, hc, dx=.36, dz=.12, size=.26, iris="chocolate", lid="wood", open_=.98, tilt=12, brow_col="wood_dark", brow_tilt=24,
                  look=(0, .5), mouth_dz=-.36, mw=.3, mh=.2, smile=.2, tongue=False, shape="O", blush_dx=.6, blush_dz=-.2)
    P += scatter("toast", tree_s, V(0, 0, cz - .55), 36, "wood", 2502, r=(.07, .13), zr=(-.95, .35), yaw=(-.85, .85), th=.02,
                 avoid=[(hc + V(-.36, -.5, .12), .36), (hc + V(.36, -.5, .12), .36), (hc + V(0, -.5, -.36), .3), (hc + V(0, -.5, .12), .3)])
    rnd = random.Random(2503)
    for k in range(18):   # refried beans (thick layer you can see from the front)
        x = -1.2 + 2.4 * k / 17
        P.append(sphere(f"bean{k}", (.24, .2, .17), loc=(x, rnd.uniform(-.16, .1), cz - .02 + rnd.uniform(0, .08)), rot=(0, 0, rnd.uniform(0, 90)), col="red_dark" if k % 2 else "brown", seg=10, ring=6))
    eg = V(-.5, -.12, cz + .5)   # fried egg facing the camera
    P.append(sphere("eggw", (.5, .4, .07), loc=eg, rot=(62, -8, 6), col="eye_white", seg=20, ring=8))
    P.append(sphere("eggy", (.18, .18, .12), loc=eg + V(.04, -.1, .05), col="sun_yellow", seg=14, ring=8))
    for k in range(3):    # avocado slices fanned up
        a = math.radians(-30 + 25 * k)
        c0 = V(.55 + .16 * k, .02, cz + .55)
        P.append(sphere(f"avo{k}", (.13, .1, .46), loc=c0, rot=(8, math.degrees(a), 0), col="lime", seg=14, ring=8))
        P.append(sphere(f"avs{k}", (.06, .1, .47), loc=c0 + V(.09, .02, .02), rot=(8, math.degrees(a), 0), col="dark_green", seg=10, ring=8))
    for k in range(3):    # fried plátano slices standing up
        p = V(-1.05 + .1 * k, -.02 - .05 * k, cz + .28 + .1 * k)
        P.append(cyl(f"plat{k}", .22, .22, .08, loc=p, rot=(75, 15 * k - 10, 0), col="mango", seg=16, bevel=.02))
        P.append(cyl(f"platc{k}", .14, .14, .09, loc=p, rot=(75, 15 * k - 10, 0), col="sun_yellow", seg=14))
    for k in range(3):    # chorizo rounds
        P.append(cyl(f"chor{k}", .15, .15, .08, loc=(.0 + .25 * k, -.15, cz + .25 + .05 * k), rot=(70, -20 + 20 * k, 0), col="terracotta", seg=14, bevel=.02))
    for k in range(14):   # cheese crumbs
        P.append(box(f"ch{k}", (.09, .09, .07), loc=(rnd.uniform(-1.1, 1.1), rnd.uniform(-.25, .15), cz + .2 + rnd.uniform(0, .25)), rot=(rnd.uniform(0, 90),) * 3, col="white", bevel=.02))
    for k in range(4):    # pickled onion rings (encurtido)
        P.append(torus(f"oni{k}", .1, .025, loc=(rnd.uniform(-.9, .9), -.2, cz + .35 + rnd.uniform(0, .2)), rot=(70, rnd.uniform(-30, 30), 0), col="lavender", seg=14, mseg=4))
    sp, sn = hit(bvh_of([shells[0]]), V(.8, -3, cz - .05), V(0, 1, 0))
    if sp is not None:
        P.append(tube("crema", [sp + sn * .04, sp + sn * .07 + V(0, 0, -.15), sp + sn * .07 + V(.02, 0, -.32)], radius=.065, col="white", seg=8, taper=[1, .9, 1.15]))
        P.append(sphere("cremad", (.085, .07, .1), loc=sp + sn * .07 + V(.02, 0, -.38), col="white", seg=10, ring=6))
    for s_ in (-1, 1):
        P += arm(f"arm{s_}", V(1.2 * s_, 0, cz - .65), V(1.75 * s_, -.3, cz - .3), r=.14, cols=("cream", "plaza_tile"), hand_col="cream", hd=(.5 * s_, -.2, .6), s=.17, seed=2504 + s_, fingers=4)
    P += legs2("leg", V(-.42, 0, cz - R + .12), V(.42, 0, cz - R + .12), r=.15, cols=("cream", "plaza_tile"), shoe_col="cobalt", sole="eye_white", s=.85, seed=2506)
    P.append(sphere("fallen", (.15, .13, .11), loc=(1.0, -.7, .09), col="red_dark", seg=10, ring=6))
    P.append(cyl("fallenp", .2, .2, .07, loc=(-1.05, -.6, .04), rot=(8, 0, 0), col="mango", seg=16, bevel=.02))
    P += hook("hook", V(-.05, .2, cz + .55), s=.9)
    return P + G, {"glow": G}

LATAM = {"saltena_jugosa": saltena_jugosa, "cucurucho_mani": cucurucho_mani, "arepa_reina": arepa_reina,
         "completito_italiano": completito_italiano, "platanito_merenguero": platanito_merenguero, "baleada_con_todo": baleada_con_todo}
LATAM_RARITY = {"saltena_jugosa": "common", "cucurucho_mani": "common", "arepa_reina": "common",
                "completito_italiano": "uncommon", "platanito_merenguero": "uncommon", "baleada_con_todo": "uncommon"}
LATAM_CAM = {"saltena_jugosa": (12, 12), "cucurucho_mani": (20, 10), "arepa_reina": (12, 10), "completito_italiano": (22, 7),
             "platanito_merenguero": (18, 10), "baleada_con_todo": (22, 10)}

import importlib
for _mod in ("latam2", "latam3"):
    try:
        _m = importlib.import_module(_mod)
    except ModuleNotFoundError:
        continue
    LATAM.update(_m.SET); LATAM_RARITY.update(_m.RARITY); LATAM_CAM.update(_m.CAM)
C.CREATURES.update(LATAM); C.RARITY.update(LATAM_RARITY); C.CAM.update(LATAM_CAM)

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    prev = os.environ.get("PREVIEW")
    metas = []
    for n in (argv or list(LATAM)):
        if prev:
            os.makedirs("/tmp/prev", exist_ok=True)
            metas.append(build2(n, samples=int(os.environ.get("SAMPLES", "24")), res=(700, 700), out=f"/tmp/prev/{n}.png"))
        else:
            metas.append(build2(n, samples=int(os.environ.get("SAMPLES", "96"))))
    if not prev:
        mf = f"{ROOT}/export/creatures/_meta.json"; old = json.load(open(mf))
        for m in metas: old[m["name"]] = m
        json.dump(old, open(mf, "w"), indent=1)
