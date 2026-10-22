"""Colección Random (fase 3): 4 ORIGINAL 'random pero chidas' piñatas - unexpected combos / objects with personality,
each with ONE clear visual joke. Extra-detail pass: layered fringe, sculpted faces (kawaii.py), accessories, bevels.
CLI: blender -b --factory-startup -P randoms.py -- [name ...]   (env PREVIEW=1 -> /tmp/prev, low samples)
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
import creatures as C
from creatures import M, cone_prof, ellip_prof, lin_prof, limb, chain
from plib import *
import kawaii as K
from kawaii import V, eyes2, eye2, plate, mouth2, nose2, paw, blush2, bvh_of, decal, ear_inner, hit
from memes import glove, shoe, sign_board
from memes2 import hand, heart_pts, upright, stars_ring
from props import text_mesh
from animals2 import build2
from mathutils import Vector, Matrix

def note(name, loc, s=.3, col="neon_cyan", rz=0):
    """Music note (eighth): head + stem + flag."""
    p = Vector(loc); out = []
    h = sphere(name + "h", (s * .5, s * .22, s * .38), loc=p, rot=(0, -25, rz), col=col, seg=12, ring=6); out.append(h)
    out.append(cyl(name + "s", s * .07, s * .07, s * 1.5, loc=p + V(s * .42, 0, 0), col=col, seg=6))
    out.append(ribbon(name + "f", [p + V(s * .42, 0, s * 1.5), p + V(s * .75, 0, s * 1.15), p + V(s * .78, 0, s * .8)], width=s * .22, normal=(0, -1, 0), col=col, thick=s * .08))
    return out

# ======================================================================= 1. CARACOL TURBO (epic)
def caracol_turbo():
    """EPIC - a snail whose shell is a race car: number 7, spoiler, chrome exhausts spitting neon flames... still a snail.
    Joke: the slowest animal with the most tuned-up ride (and a slime trail with skid marks)."""
    P = []; G = []
    # foot (paper fringe chain along the ground) + neck/head
    fp_pts = [V(0, -1.05, .42), V(0, -.1, .4), V(0, 1.0, .36), V(0, 1.85, .26), V(0, 2.35, .14)]
    P += chain("foot", fp_pts, [.52, .55, .48, .3, .12], 2, ["lime", "leaf", "lime", "mint"], seed=1001, seg=18)
    hc = V(0, -1.3, 1.55)
    P += fringe_body("head", ellip_prof(.6, 1.5, p=.9), 1.5, 4, ["lime", "leaf", "lime", "lime"], matrix=M(V(0, -1.12, .45), (0, -.22, 1)), seg=24, flare=.09, tooth=.06, seed=1002)
    fp = plate("face", hc, r=(.52, .3, .45), col="lime", fwd_off=.42); P.append(fp)
    tree = bvh_of([fp])
    P += mouth2("m", tree, hc + V(.04, -3, -.2), w=.36, h=.13, smile=1.3, col="ink", tongue=False, teeth=3)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.34 * s_, -3, -.05), size=.1)
    # eye stalks with determined eyes + racing goggles pushed up on the forehead
    for s_ in (-1, 1):
        a = hc + V(.2 * s_, .05, .55); b = hc + V(.5 * s_, -.15, 1.45)
        P.append(tube(f"stalk{s_}", [a, a.lerp(b, .5) + V(.05 * s_, 0, 0), b], radius=.09, col="lime", seg=10, taper=[1.2, 1, .9]))
        ball = sphere(f"eball{s_}", (.3, .28, .3), loc=b + V(0, 0, .12), col="lime", seg=18, ring=10); P.append(ball)
        e, _, _ = eye2(f"eye{s_}", bvh_of([ball]), b + V(0, -3, .14), size=.25, iris="sky", lid="leaf", open_=.72, tilt=-12, side=-s_,
                       brow=True, brow_h=1.35, brow_tilt=-18, brow_col="leaf_dark", look=(-.15 * s_, -.05))
        P += e
    gz = hc + V(0, -.2, .45)
    for s_ in (-1, 1):
        P.append(torus(f"gog{s_}", .15, .05, loc=gz + V(.2 * s_, -.32, 0), rot=(80, 0, 0), col="ink", seg=18, mseg=6))
        P.append(cyl(f"goglens{s_}", .13, .13, .03, loc=gz + V(.2 * s_, -.33, 0), rot=(80, 0, 0), col="glass", seg=16))
    P.append(torus("gogstrap", .5, .05, loc=gz + V(0, .05, -.02), rot=(-10, 0, 0), col="candy_red", seg=26, mseg=5))
    # SHELL = race car: fringe drum around X + racing stripes, spiral, roundel #7
    sc = V(0, .55, 1.45); SH = 1.4
    shell = fringe_body("shell", lambda z: 1.2 * max(0.0, 1 - ((2 * z / SH) - 1) ** 2) ** .32, SH, 6,
                        ["candy_red", "candy_red", "red_dark", "candy_red", "candy_red", "red_dark"], matrix=M(sc - V(SH / 2, 0, 0), (1, 0, 0)), seg=30, flare=.08, tooth=.06, seed=1003)
    P += shell
    for x in (-.17, .17):
        st = torus(f"stripe{x}", 1.16, .07, col="snow", seg=40, mseg=6); st.matrix_world = Matrix.Translation(sc + V(x, 0, 0)) @ Matrix.Rotation(math.radians(90), 4, 'Y'); P.append(st)
    stree = bvh_of(shell)
    for s_ in (-1, 1):   # gold spiral painted on each side
        pts = []
        for k in range(30):
            t = k / 29; a = t * 2.3 * 2 * math.pi; r = .92 * (1 - t * .9)
            o = sc + V(3 * s_, r * math.cos(a), r * math.sin(a))
            p, n = hit(stree, o, V(-s_, 0, 0))
            if p is not None: pts.append(p + n * .05)
        if len(pts) > 3: P.append(tube(f"spiral{s_}", pts, radius=.06, col="gold", seg=6, taper=[1 - .5 * k / len(pts) for k in range(len(pts))]))
        rp, rn = hit(stree, sc + V(3 * s_, -.1, .0), V(-s_, 0, 0))
        disc = cyl(f"round{s_}", .32, .32, .04, col="eye_white", seg=24); disc.matrix_world = M(rp + rn * .06, rn); P.append(disc)
        t = text_mesh(f"num{s_}", "7", size=.42, extrude=.03, col="ink", rot=(0, 0, 0), bevel=0, res=3)
        t.matrix_world = M(rp + rn * .09, rn, roll=0 if s_ > 0 else 180); P.append(t)
    # spoiler
    for x in (-.5, .5):
        P.append(box(f"strut{x}", (.08, .12, .55), loc=sc + V(x, .95, .95), rot=(-20, 0, 0), col="ink", bevel=.02))
    P.append(box("wing", (1.8, .62, .12), loc=sc + V(0, 1.1, 1.25), rot=(-22, 0, 0), col="ink", bevel=.04))
    P.append(box("wingstripe", (1.82, .2, .13), loc=sc + V(0, 1.0, 1.29), rot=(-22, 0, 0), col="candy_red", bevel=.03))
    for x in (-.88, .88):
        P.append(box(f"endpl{x}", (.08, .75, .42), loc=sc + V(x * 1.06, 1.1, 1.2), col="candy_red", bevel=.03))
    # exhausts + neon flames
    for x in (-.35, .35):
        e0 = sc + V(x, 1.05, -.7)
        pipe = cyl(f"pipe{x}", .14, .16, .6, col="silver", seg=16, bevel=.02); pipe.matrix_world = M(e0, (0, 1, .15)); P.append(pipe)
        P.append(torus(f"piperim{x}", .14, .03, col="steel", seg=14, mseg=4)); P[-1].matrix_world = M(e0 + V(0, .6, .09), (0, 1, .15))
        fl = cyl(f"flame{x}", .14, .01, .6, col="neon_gold", seg=10); fl.matrix_world = M(e0 + V(0, .62, .09), (0, 1, .25)); G.append(fl)
        fl2 = cyl(f"flamei{x}", .09, .01, .9, col="neon_pink", seg=8); fl2.matrix_world = M(e0 + V(0, .6, .09), (0, 1, .2)); G.append(fl2)
    # slime trail with tyre skid marks + speed lines
    trail = slab("slime", [(.62 * math.cos(math.pi * k / 11), .2 + 1.25 * math.sin(math.pi * k / 11) * (1 if k <= 11 else 1)) for k in range(12)] + [(-.62, -.05), (.62, -.05)], thick=.04, col="candy_teal", bevel=.015, matrix=Matrix.Translation((0, 1.9, .02))); P.append(trail)
    for x in (-.25, .25):
        P.append(box(f"skid{x}", (.08, 1.8, .02), loc=(x, 3.05, .05), col="ink_soft", bevel=0))
    for k in range(4):
        z = .7 + .45 * k; y0 = 2.0 + .25 * (k % 2)
        G.append(tube(f"spd{k}", [V(-1.15 + .1 * k, y0, z), V(-1.15 + .1 * k, y0 + .9 + .3 * (k % 2), z)], radius=.035, col="neon_cyan", seg=5, taper=[1, .2]))
    return P + G, {"glow": G}

# ======================================================================= 2. CACTUS ABRAZOS (legendary)
def cactus_abrazos():
    """LEGENDARY - a spiky little cactus with arms wide open and a 'ABRAZOS GRATIS' sign... and a popped balloon at its feet.
    Joke: the one plant you can't hug is the one that wants a hug the most."""
    P = []; G = []
    # clay pot with painted zig-zag band
    P.append(cyl("pot", .82, 1.05, 1.05, col="terracotta", seg=28, bevel=.04))
    P.append(torus("potrim", 1.06, .13, loc=(0, 0, 1.02), col="terracotta", seg=32, mseg=8))
    P.append(cyl("soil", .98, .98, .06, loc=(0, 0, 1.0), col="chocolate", seg=24))
    for k in range(14):
        a = 2 * math.pi * k / 14; r = .93
        tri = slab(f"zig{k}", [(-.14, 0), (.14, 0), (0, .2)], thick=.04, col="sun_yellow" if k % 2 else "turquoise", bevel=.01,
                   matrix=Matrix.Translation((r * math.cos(a), r * math.sin(a), .5)) @ Matrix.Rotation(a + math.pi / 2, 4, 'Z') @ Matrix.Rotation(math.radians(90 + 8), 4, 'X'))
        P.append(tri)
    P.append(torus("potband", .91, .035, loc=(0, 0, .42), col="eye_white", seg=32, mseg=4))
    # body: tall fringe column (paper ribs) + head dome
    body = fringe_body("body", lambda z: .78 * max(0.0, 1 - (max(0.0, z - 1.9) / 1.0) ** 2) ** .5 if z > 1.9 else .78, 2.9, 7,
                       ["leaf", "leaf_dark", "leaf", "leaf", "leaf_dark", "leaf", "leaf"], matrix=M((0, 0, 1.0)), seg=30, flare=.09, tooth=.07, seed=1101)
    P += body
    hc = V(0, 0, 2.85)
    fp = plate("face", hc, r=(.66, .4, .6), col="leaf", fwd_off=.5); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .12), dx=.29, dz=0, size=.25, iris="chocolate", lid="leaf", open_=.86, tilt=14, lash=True,
               brow=True, brow_h=1.45, brow_tilt=22, brow_col="leaf_dark", look=(0, .25))
    P += mouth2("m", tree, hc + V(0, -3, -.3), w=.24, h=.1, smile=.9, col="ink", tongue=True)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.45 * s_, -3, -.16), size=.11)
    G.append(sphere("tear", (.06, .05, .09), loc=hc + V(-.48, -.62, -.08), col="neon_cyan", seg=10, ring=6))
    # spines: little cream cones all over (skip the face)
    rnd = random.Random(1102); btree = bvh_of(body)
    for k in range(46):
        a = rnd.uniform(0, 2 * math.pi); z = rnd.uniform(1.25, 3.5)
        if abs(math.atan2(math.sin(a), math.cos(a)) + math.pi / 2) < .75 and z > 2.35: continue
        d = V(math.cos(a), math.sin(a), 0)
        p, n = hit(btree, V(0, 0, z) + d * 3, -d)
        if p is None: continue
        P.append(cyl(f"sp{k}", .05, .004, .28, col="eye_white", seg=4, base=False)); P[-1].matrix_world = M(p - n * .02, (n + V(0, 0, .25)).normalized())
    # arms wide open for a hug (saguaro arms) with spine tufts + a bandage
    for s_ in (-1, 1):
        pts = [V(.6 * s_, 0, 2.0), V(1.25 * s_, -.1, 2.1), V(1.5 * s_, -.2, 2.65), V(1.55 * s_, -.25, 3.2)]
        P += chain(f"arm{s_}", pts, [.32, .3, .27, .22], 2, ["leaf", "leaf_dark"], seed=1110 + s_, seg=16)
        P.append(sphere(f"armtip{s_}", (.22, .22, .2), loc=pts[-1] + V(0, 0, .05), col="leaf", seg=14, ring=8))
        for j in range(4):
            q = pts[-1] + V(.15 * math.cos(j * 1.6), .15 * math.sin(j * 1.6), .1)
            P.append(cyl(f"asp{s_}{j}", .03, .004, .18, col="cream", seg=4, base=False)); P[-1].matrix_world = M(q, (q - pts[-1]).normalized())
    bd = V(-1.5, -.45, 2.6)
    P.append(box("bandage", (.42, .1, .18), loc=bd, rot=(0, 70, -15), col="peach", bevel=.04))
    for k in (-1, 1):
        P.append(sphere(f"bdot{k}", (.025, .015, .025), loc=bd + V(0, -.06, .07 * k), col="wood", seg=6, ring=4))
    # flower crown + sign
    fl = V(.12, -.05, 3.93)
    for k in range(6):
        a = 2 * math.pi * k / 6
        P.append(sphere(f"pt{k}", (.15, .15, .07), loc=fl + V(.15 * math.cos(a), .15 * math.sin(a), 0), rot=(0, 0, math.degrees(a)), col="hot_magenta" if k % 2 else "fiesta_pink", seg=10, ring=6))
    P.append(sphere("ptc", (.1, .1, .08), loc=fl + V(0, 0, .04), col="sun_yellow", seg=10, ring=6))
    sgn = V(0, -1.02, 1.62)
    P += sign_board("hug", [("ABRAZOS", .25, .1), ("GRATIS", .25, -.2)], 1.55, .72, sgn, rot_z=-4, board="snow", ink="candy_red", rim="wood")
    for x in (-.6, .6):
        P.append(tube(f"string{x}", [sgn + V(x, .05, .36), V(x * .55, -.72, 2.3)], radius=.02, col="wood_dark", seg=4))
    # popped balloon at the pot
    bp = V(1.05, -.85, .12)
    bal = sphere("popped", (.32, .26, .12), loc=bp, col="candy_red", seg=14, ring=8)
    for v in bal.data.vertices: v.co.z += .05 * math.sin(v.co.x * 23) * math.cos(v.co.y * 19)
    P.append(bal)
    P.append(tube("balstring", [bp + V(-.2, 0, .02), bp + V(-.45, .1, .05), bp + V(-.6, .35, .03)], radius=.015, col="eye_white", seg=4))
    for k in range(3):
        G.append(star_prism(f"pop{k}", 4, .12, .04, .03, loc=bp + V(.25 * (k - 1), -.1, .45 + .12 * k), rot=(90, 0, 20 * k), col="neon_gold", bevel=0))
    return P + G, {"glow": G}

# ======================================================================= 3. AGUACATÓN (mythic)
def aguacaton():
    """MYTHIC - gym-bro avocado: double bicep flex, sweatband, dumbbell... and the pit is a literal six-pack.
    Joke: 'bien mamado y bien maduro'."""
    P = []; G = []
    prof = lambda z: max(1.18 * max(0.0, 1 - ((z - 1.25) / 1.25) ** 2) ** .5, .8 * max(0.0, 1 - ((z - 2.55) / .95) ** 2) ** .5)
    H = 3.5
    body = fringe_body("body", prof, H, 7, ["leaf_dark", "dark_green", "leaf_dark", "leaf_dark", "dark_green", "leaf_dark", "dark_green"],
                       matrix=M((0, 0, .35)), seg=30, flare=.08, tooth=.06, seed=1201, sy=.9)
    P += body
    # cut face: flesh (lime ring + pale centre) and the PIT = six-pack
    fl = plate("flesh", V(0, 0, 1.55), r=(1.02, .36, 1.12), col="lime", fwd_off=.82); P.append(fl)
    fl2 = plate("flesh2", V(0, 0, 1.5), r=(.84, .3, .92), col="mint", fwd_off=.93); P.append(fl2)
    up = plate("fleshup", V(0, 0, 2.75), r=(.66, .3, .62), col="mint", fwd_off=.66); P.append(up)
    P.append(plate("fleshupr", V(0, 0, 2.75), r=(.74, .3, .7), col="lime", fwd_off=.6))
    pit = sphere("pit", (.62, .3, .7), loc=(0, -1.1, 1.3), col="brown", seg=22, ring=12); P.append(pit)
    for r_ in range(3):
        for c_ in (-1, 1):
            P.append(sphere(f"ab{r_}{c_}", (.21, .1, .16), loc=(.21 * c_, -1.36 + .03 * abs(r_ - 1), 1.68 - .36 * r_), col="brown", seg=12, ring=8))
    P.append(box("abline", (.035, .05, 1.0), loc=(0, -1.37, 1.32), col="chocolate", bevel=.01))
    for k in range(2):
        P.append(box(f"abh{k}", (.75, .05, .03), loc=(0, -1.35, 1.5 - .36 * k), col="chocolate", bevel=.01))
    P.append(sphere("pithl", (.12, .03, .2), loc=(-.32, -1.36, 1.7), col="wood", seg=10, ring=6))
    # face on the upper flesh: confident wink, smirk, brows, sweat drop, sweatband
    hc = V(0, 0, 2.8)
    tree = bvh_of([up])
    e, _, _ = eye2("eyeL", tree, hc + V(.3, -3, .08), size=.22, iris="chocolate", lid="leaf", open_=.82, tilt=-6, side=-1, brow=True, brow_h=1.45, brow_tilt=-14, brow_col="dark_green")
    P += e
    e, _, _ = eye2("eyeR", tree, hc + V(-.3, -3, .08), size=.22, iris="chocolate", lid="leaf", open_=.12, tilt=0, side=1, brow=True, brow_h=1.2, brow_tilt=8, brow_col="dark_green")
    P += e
    P += mouth2("m", tree, hc + V(.06, -3, -.3), w=.36, h=.12, smile=1.4, col="ink", tongue=False, teeth=3)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.42 * s_, -3, -.15), size=.09)
    G.append(sphere("sweat", (.07, .05, .1), loc=hc + V(-.62, -.55, .3), col="neon_cyan", seg=10, ring=6))
    P.append(torus("band", .82, .12, loc=(0, 0, 3.12), rot=(-6, 0, 0), col="candy_red", seg=32, mseg=8))
    P.append(torus("bandst", .85, .035, loc=(0, -.01, 3.12), rot=(-6, 0, 0), col="eye_white", seg=32, mseg=4))
    P.append(cyl("stem", .1, .07, .3, loc=(0, 0, 3.78), col="wood_dark", seg=10))
    P.append(ribbon("leaf1", [V(0, 0, 3.98), V(.25, -.05, 4.12), V(.5, 0, 4.05)], width=.18, normal=(0, -.3, 1), col="leaf", thick=.04))
    # double bicep flex
    for s_ in (-1, 1):
        sh = V(1.0 * s_, -.1, 2.1); el = V(1.65 * s_, -.25, 2.35); wr = V(1.6 * s_, -.3, 3.1)
        P += limb(f"uarm{s_}", sh, el, .24, .22, 2, ["leaf_dark", "dark_green"], seed=1210 + s_, seg=12)
        P.append(sphere(f"bicep{s_}", (.33, .3, .3), loc=sh.lerp(el, .6) + V(0, 0, .2), col="leaf_dark", seg=16, ring=10))
        P += limb(f"farm{s_}", el, wr, .22, .2, 2, ["leaf_dark", "dark_green"], seed=1212 + s_, seg=12)
        P += hand(f"hand{s_}", wr + V(0, 0, .12), d=(-.3 * s_, -.2, 1), s=.22, col="lime", fingers=3)
        G.append(star_prism(f"flex{s_}", 4, .16, .05, .04, loc=sh.lerp(el, .6) + V(.25 * s_, -.3, .55), rot=(90, 0, 15), col="neon_gold", bevel=0))
    # dumbbell resting at the feet + legs with sneakers
    db = V(1.15, -.9, .22)
    P.append(cyl("dbbar", .06, .06, 1.0, col="steel", seg=10)); P[-1].matrix_world = M(db - V(.5, 0, 0), (1, 0, 0))
    for x in (-.4, .4):
        for j in (0, 1):
            pl = cyl(f"dbpl{x}{j}", .22 - .05 * j, .22 - .05 * j, .1, col="ink" if j == 0 else "candy_red", seg=18, bevel=.02)
            pl.matrix_world = M(db + V(x + .1 * j * (1 if x > 0 else -1) - .05, 0, 0), (1, 0, 0)); P.append(pl)
    for s_ in (-1, 1):
        P += limb(f"leg{s_}", V(.45 * s_, 0, .55), V(.5 * s_, -.1, .22), .2, .18, 2, ["leaf_dark", "dark_green"], seed=1220 + s_, seg=12)
        P += shoe(f"sh{s_}", (.52 * s_, -.12, 0), col="eye_white", sole="candy_red", s=1.0)
        P.append(torus(f"sock{s_}", .17, .05, loc=(.51 * s_, -.1, .36), col="eye_white", seg=14, mseg=4))
    return P + G, {"glow": G}

# ======================================================================= 4. PULPO DJ (secret)
def pulpo_dj():
    """SECRET - an octopus DJ using all 8 arms at once: two scratching, one hyping, one on the mic, the rest dancing.
    Joke: the only DJ who can actually do everything at the same time."""
    P = []; G = []
    # DJ booth
    P.append(box("booth", (3.0, 1.0, 1.15), loc=(0, -1.25, .58), col="ink_soft", bevel=.07))
    G.append(box("led", (2.9, .04, .08), loc=(0, -1.77, .95), col="neon_pink", bevel=0))
    G.append(box("led2", (2.9, .04, .05), loc=(0, -1.77, .2), col="neon_cyan", bevel=0))
    t = text_mesh("djtxt", "DJ PULPO", size=.3, extrude=.03, col="eye_white", rot=(90, 0, 0), bevel=0, res=3); t.location = (0, -1.79, .52); P.append(t)
    P.append(box("deck", (3.1, 1.1, .12), loc=(0, -1.25, 1.2), col="ink", bevel=.04))
    for x in (-.95, .95):
        P.append(cyl(f"plat{x}", .44, .44, .06, loc=(x, -1.25, 1.26), col="silver", seg=28, bevel=.015))
        P.append(cyl(f"vinyl{x}", .4, .4, .04, loc=(x, -1.25, 1.31), col="ink", seg=28))
        for r in (.3, .22):
            P.append(torus(f"groove{x}{r}", r, .008, loc=(x, -1.25, 1.355), col="ink_soft", seg=28, mseg=3))
        G.append(cyl(f"label{x}", .12, .12, .02, loc=(x, -1.25, 1.35), col="neon_gold" if x < 0 else "neon_cyan", seg=16))
        P.append(tube(f"arm_t{x}", [V(x + .45 * (1 if x > 0 else -1), -.9, 1.3), V(x + .4 * (1 if x > 0 else -1), -1.0, 1.42), V(x + .15 * (1 if x > 0 else -1), -1.3, 1.4)], radius=.025, col="steel", seg=5))
    P.append(box("mixer", (.6, .8, .14), loc=(0, -1.25, 1.32), col="ink_soft", bevel=.03))
    for k in range(3):
        for j in range(2):
            P.append(cyl(f"knob{k}{j}", .05, .045, .07, loc=(-.18 + .18 * k, -1.45 + .2 * j, 1.39), col="snow", seg=8))
    for k in range(2):
        G.append(box(f"fader{k}", (.06, .2, .04), loc=(-.12 + .24 * k, -1.0, 1.4), col="neon_green", bevel=0))
    # mantle (head): big paper bulb
    hc = V(0, .1, 2.75)
    mant = fringe_body("mantle", ellip_prof(1.2, 2.4, p=1.15), 2.4, 6, ["fiesta_pink", "hot_magenta", "fiesta_pink", "fiesta_pink", "bubblegum", "fiesta_pink"],
                       matrix=M(V(0, .2, 1.55), (0, .12, 1)), seg=26, flare=.08, tooth=.06, seed=1301, sy=.95)
    P += mant
    fp = plate("face", hc + V(0, 0, -.1), r=(.9, .5, .62), col="fiesta_pink", fwd_off=.72); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .02), dx=.38, dz=0, size=.25, iris="grape", lid="hot_magenta", open_=.45, lower="hot_magenta", lash=True,
               brow=True, brow_h=1.4, brow_tilt=10, brow_col="velvet", look=(0, .3))
    P += mouth2("m", tree, hc + V(0, -3, -.45), w=.48, h=.24, smile=.6, col="ink", tongue=True, teeth=2)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.62 * s_, -3, -.25), size=.12)
    mt = bvh_of(mant)
    rnd = random.Random(1302)
    for k in range(9):
        a = rnd.uniform(.4, 2.7) * (1 if k % 2 else -1) + math.pi / 2; z = rnd.uniform(2.6, 3.9)
        d = V(math.cos(a), math.sin(a), .25).normalized()
        p, n = hit(mt, V(0, .2, z) + d * 3, -d)
        if p is not None:
            sp = sphere(f"spot{k}", (.12, .12, .03), col="hot_magenta", seg=10, ring=5); sp.matrix_world = M(p + n * .02, n); P.append(sp)
    # headphones
    hb = torus("hband", 1.28, .09, col="ink", seg=36, mseg=6, arc=180); hb.matrix_world = Matrix.Translation(hc + V(0, .15, .25)) @ Matrix.Rotation(math.radians(90), 4, 'X') @ Matrix.Rotation(math.radians(-5), 4, 'Y'); P.append(hb)
    for s_ in (-1, 1):
        cup = cyl(f"cup{s_}", .36, .36, .3, col="ink", seg=24, bevel=.05); cup.matrix_world = M(hc + V(1.1 * s_, .15, .25), (s_, 0, 0)); P.append(cup)
        pad = torus(f"pad{s_}", .3, .08, col="ink_soft", seg=22, mseg=6); pad.matrix_world = M(hc + V(1.08 * s_, .15, .25), (s_, 0, 0)); P.append(pad)
        rim = torus(f"cuprim{s_}", .33, .03, col="neon_cyan", seg=24, mseg=4); rim.matrix_world = M(hc + V(1.42 * s_, .15, .25), (s_, 0, 0)); G.append(rim)
    # 8 tentacles (paper-striped, suction cups)
    def tent(name, pts, r=.2, cols=("fiesta_pink", "hot_magenta")):
        out = striped_tube(name, pts, r, list(cols) * 4, seg=9, taper=lambda t: 1 - .8 * t)
        for k in range(1, len(pts) - 1):
            out.append(sphere(f"{name}c{k}", (.06, .06, .03), loc=pts[k] + V(0, -.12, -.12), col="bubblegum", seg=8, ring=5))
        return out
    base = V(0, .1, 1.62)
    T = [
        [base + V(-.55, -.4, 0), V(-.8, -.95, 1.55), V(-.95, -1.2, 1.42), V(-.75, -1.35, 1.4)],        # scratch L
        [base + V(.55, -.4, 0), V(.8, -.95, 1.55), V(.95, -1.2, 1.42), V(1.15, -1.1, 1.4)],            # scratch R
        [base + V(.85, 0, .2), V(1.75, -.1, 2.3), V(1.95, -.2, 3.2), V(1.7, -.3, 3.8)],                # hype arm up
        [base + V(-.85, 0, .2), V(-1.7, -.3, 2.0), V(-1.85, -.6, 2.55), V(-1.55, -.85, 2.75)],         # mic
        [base + V(-.6, .5, -.1), V(-1.5, .9, .9), V(-1.9, 1.2, .35), V(-2.2, .8, .15)],
        [base + V(.6, .5, -.1), V(1.5, .9, .9), V(1.9, 1.2, .35), V(2.25, .85, .15)],
        [base + V(-.25, .7, -.2), V(-.6, 1.6, .7), V(-.5, 2.1, .25), V(-.1, 2.3, .15)],
        [base + V(.25, .7, -.2), V(.6, 1.6, .7), V(.55, 2.15, .3), V(.95, 2.25, .15)],
    ]
    for i, pts in enumerate(T):
        P += tent(f"t{i}", pts, r=.22 if i < 4 else .24)
    # mic in tentacle 3
    mp = V(-1.5, -.95, 2.8)
    P.append(cyl("mic", .07, .1, .5, col="ink", seg=12)); P[-1].matrix_world = M(mp - V(0, 0, .3), (.2, -.3, 1))
    P.append(sphere("mich", (.15, .15, .15), loc=mp + V(.06, -.1, .22), col="steel", seg=14, ring=8))
    # glow stick in the hype arm + notes + disco ball
    G.append(cyl("glowstick", .05, .05, .55, loc=(1.7, -.3, 3.8), rot=(0, 25, 0), col="neon_green", seg=8))
    for k, (x, y, z, c) in enumerate(((-2.2, -.6, 3.6, "neon_cyan"), (2.35, -.4, 2.6, "neon_pink"), (-.9, -.8, 4.6, "neon_gold"), (1.0, -.6, 4.7, "neon_cyan"))):
        G += note(f"n{k}", (x, y, z), s=.3, col=c, rz=10 * k)
    P.append(cyl("discostring", .015, .015, .6, loc=(0, -.4, 5.15), col="silver", seg=4))
    db = sphere("disco", (.3, .3, .3), loc=(0, -.4, 5.0), col="silver", seg=12, ring=8); P.append(db)
    return P + G, {"glow": G}

RANDOMS = {"caracol_turbo": caracol_turbo, "cactus_abrazos": cactus_abrazos, "aguacaton": aguacaton, "pulpo_dj": pulpo_dj}
RANDOM_RARITY = {"caracol_turbo": "epic", "cactus_abrazos": "legendary", "aguacaton": "mythic", "pulpo_dj": "secret"}
RANDOM_CAM = {"caracol_turbo": (38, 10), "cactus_abrazos": (14, 9), "aguacaton": (16, 9), "pulpo_dj": (14, 11)}
C.CREATURES.update(RANDOMS); C.RARITY.update(RANDOM_RARITY); C.CAM.update(RANDOM_CAM)

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    prev = os.environ.get("PREVIEW")
    metas = []
    for n in (argv or list(RANDOMS)):
        if prev:
            os.makedirs("/tmp/prev", exist_ok=True)
            metas.append(build2(n, samples=int(os.environ.get("SAMPLES", "24")), res=(700, 700), out=f"/tmp/prev/{n}.png"))
        else:
            metas.append(build2(n, samples=int(os.environ.get("SAMPLES", "96"))))
    if not prev:
        mf = f"{ROOT}/export/creatures/_meta.json"; old = json.load(open(mf))
        for m in metas: old[m["name"]] = m
        json.dump(old, open(mf, "w"), indent=1)
