"""Fase 3 - 'haz bien los animalitos': upgraded animal piñatas (same ids/paths as fase 1/2).
Smooth face plates so eyes/mouths never get eaten by fringe teeth, glossy 2-highlight eyes with skin
eyelids + lash lines + brows, heart noses, toe-bean paws, fluffier fringe tails and ears.
CLI: blender -b --factory-startup -P animals2.py -- [name ...]   (env PREVIEW=1 -> /tmp/prev, low samples)
"""
import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
import creatures as C
from creatures import M, cone_prof, ellip_prof, lin_prof, limb, chain
from plib import *
import kawaii as K
from kawaii import V, eyes2, plate, mouth2, nose2, paw, blush2, bvh_of
from mathutils import Vector, Matrix

def build2(name, samples=96, res=(1100, 1100), out=None):
    reset(); write_palette_textures()
    parts, extra = C.CREATURES[name]()
    glow = extra.get("glow", [])
    main = [p for p in parts if p not in glow]
    body = join(main, name); objs = [body]
    if glow: objs.append(join(glow, name + "_Neon"))
    size = base_origin(objs)
    mat = material_palette()
    for o in objs:
        assign_mat(o, mat if not o.name.endswith("_Neon") else material_palette("M_Neon", emissive=1.6)); smooth(o, 50)
    info = export(objs, name, "creatures") if out is None else {o.name: tri_count(o) for o in objs}
    if out is None: bpy.ops.wm.save_as_mainfile(filepath=f"{BLEND}/{name}.blend")
    meta = {"name": name, "size_studs": [round(size.x, 2), round(size.z, 2), round(size.y, 2)], "tris": info}
    print("META", json.dumps(meta))
    bg = C.RARBG[C.RARITY.get(name, "common")]; cam = C.CAM.get(name, (28, 14))
    setup_render(res, samples); backdrop(*bg, rot_z=cam[0]); lights(scale=max(1.0, size.z / 3.2), center=(0, 0, size.z * .5))
    camera_fit(objs, az=cam[0], el=cam[1], lens=60, margin=0.86)
    render(out or f"{REND}/{name}.png")
    return meta

# ======================================================================= MICHI (uncommon)
def michi():
    """UNCOMMON - chubby sitting cat piñata waving hello (maneki vibe), smug-cute face."""
    P = []
    body = fringe_body("body", ellip_prof(.95, 2.0, p=.75), 2.0, 6, ["cat_orange", "cat_cream", "cat_orange", "fiesta_pink", "cat_orange", "cat_cream"],
                       matrix=M((0, .05, .05)), seg=30, flare=.10, tooth=.07, seed=5, sy=.92)
    P += body
    hc = V(0, -.05, 2.62)
    head = fringe_body("head", ellip_prof(1.02, 1.78, p=1.3), 1.78, 5, ["cat_orange", "cat_orange", "cat_cream", "cat_orange", "tangerine"],
                       matrix=M(hc - V(0, 0, .86)), seg=32, flare=.09, tooth=.065, seed=6, sx=1.14, sy=.96)
    P += head
    fp = plate("face", hc + V(0, 0, .02), r=(.86, .5, .66), col="cat_orange", fwd_off=.64); P.append(fp)
    mz = plate("muzzle", hc + V(0, 0, -.33), r=(.5, .26, .3), col="snow", fwd_off=1.0); P.append(mz)
    tree = bvh_of([fp, mz])
    for k, x in enumerate((-.2, 0, .2)):   # tabby forehead stripes, stuck on the plate
        P += K.decal(f"tab{k}", tree, hc + V(x, -3, .5 - abs(x) * .3), r=(.05, .15 - abs(x) * .2), col="tangerine", roll=x * 70)
    P += eyes2("e", tree, hc + V(0, 0, .12), dx=.4, dz=0, size=.31, iris="jade", lid=None, lash=True, look=(0, -.05))
    P += nose2("nose", tree, hc + V(0, -3, -.2), size=.11, col="fiesta_pink")
    P += mouth2("m", tree, hc + V(0, -3, -.37), w=.24, h=.13, smile=.6, col="ink", tongue=True)
    P += blush2("bl1", tree, hc + V(-.62, -3, -.18), size=.15); P += blush2("bl2", tree, hc + V(.62, -3, -.18), size=.15)
    for s_ in (-1, 1):
        base = hc + V(.58 * s_, .05, .62)
        P += fringe_body(f"ear{s_}", cone_prof(.4, .86), .86, 3, ["cat_orange", "tangerine", "cat_orange"], matrix=M(base, (.33 * s_, -.05, 1)), seg=16, flare=.1, tooth=.05, seed=60 + s_, sy=.5)
        d = V(.33 * s_, -.05, 1)
        P.append(K.ear_inner(f"earin{s_}", base + V(0, -.02, -.05), d, .3, .17, off=.2))
        for k in (-1, 0, 1):
            a0 = hc + V(.38 * s_, -1.12, -.3 + .07 * k)
            P.append(tube(f"wh{s_}{k}", [a0, a0 + V(.35 * s_, -.02, .05 * k), a0 + V(.68 * s_, .08, .12 * k)], radius=.014, col="ink_soft", seg=5, taper=[1, .8, .4]))
    # waving paw (beans facing camera) + resting paws
    P += limb("armR", (.72, -.3, 1.3), (1.3, -.5, 2.0), .27, .23, 3, ["cat_orange", "cat_cream", "cat_orange"], seed=70)
    P += paw("pawR", (1.36, -.58, 2.12), fwd=(0, -1, .15), s=.3, col="snow", pad="bubblegum")
    P += limb("armL", (-.62, -.4, 1.2), (-.45, -.75, .5), .25, .22, 3, ["cat_orange", "cat_cream", "cat_orange"], seed=71)
    for x in (-.42, .42):
        P += paw(f"foot{x}", (x, -.72, .22), fwd=(0, -1, .5), s=.3, col="snow", pad="bubblegum")
    # tail: fringed segments + fluffy tip
    tp = [V(.5, .6, .3), V(1.15, .85, .45), V(1.5, .75, 1.0), V(1.38, .62, 1.55)]
    P += chain("tail", tp, [.24, .22, .2, .18], 2, ["cat_orange", "tangerine", "cat_orange"], seed=72)
    P.append(sphere("tailtip", (.24, .24, .26), loc=(1.3, .6, 1.72), col="snow", seg=14, ring=8))
    P.append(torus("collar", .9, .1, loc=hc + V(0, .02, -.93), col="chili", seg=32, mseg=8))
    P.append(sphere("bell", (.17, .17, .17), loc=hc + V(0, -.92, -1.05), col="gold", seg=16, ring=10))
    P.append(torus("bellband", .17, .03, loc=hc + V(0, -.92, -1.03), rot=(0, 0, 0), col="gold_deep", seg=16, mseg=5))
    P.append(sphere("bellslot", (.05, .03, .04), loc=hc + V(0, -1.08, -1.1), col="ink", seg=8, ring=5))
    return P, {"glow": []}


# ======================================================================= BURRITO (common)
def burrito():
    """COMMON - the classic burro piñata: chubby, derpy-sleepy, big buck-tooth smile."""
    P = []
    bc = ["snow", "fiesta_pink", "snow", "turquoise", "snow", "sun_yellow", "snow", "fiesta_pink"]
    P += fringe_body("body", ellip_prof(.82, 2.5, p=.55), 2.5, 9, bc, matrix=M((1.2, 0, 1.55), (-1, 0, 0)), seg=28, flare=.10, tooth=.07, seed=4, sy=1.08)
    for i, (x, y) in enumerate([(-.65, -.38), (-.65, .38), (.7, -.38), (.7, .38)]):
        P += limb(f"leg{i}", (x, y, 1.3), (x, y, .16), .27, .26, 4, ["donkey_grey", "fiesta_pink", "donkey_grey", "turquoise"], seed=20 + i, round_end=.05, seg=14)
        P.append(cyl(f"hoof{i}", .31, .29, .22, loc=(x, y, 0), col="ink_soft", seg=16, bevel=.07))
        P.append(torus(f"cuff{i}", .27, .06, loc=(x, y, .26), col="snow", seg=16, mseg=5))
    P += limb("neck", (-1.12, 0, 1.62), (-1.25, 0, 2.55), .45, .38, 4, ["donkey_grey", "sun_yellow", "donkey_grey", "fiesta_pink"], seed=30, flare=.12)
    hd = V(-1.0, -.35, -.18).normalized(); h0 = V(-1.0, .18, 2.75)
    P += fringe_body("head", ellip_prof(.58, 1.35, p=.8), 1.35, 5, ["donkey_grey", "donkey_grey", "snow", "donkey_grey", "donkey_grey"],
                     matrix=M(h0, hd), seg=26, flare=.08, tooth=.06, seed=31, sy=1.05)
    up = V(0, 0, 1); side = hd.cross(up).normalized(); ff = (hd + up * .55).normalized()
    fc = h0 + hd * .5 + up * .16
    fp = plate("face", fc, fwd=ff, r=(.5, .3, .4), col="donkey_grey", fwd_off=.3); P.append(fp)
    snc = h0 + hd * 1.25 + up * -.05
    sn = sphere("snout", (.5, .46, .4), loc=snc, col="cream", seg=22, ring=12); P.append(sn)
    tree = bvh_of([fp, sn])
    P += eyes2("e", tree, fc + up * .08, fwd=ff, dx=.27, dz=0, size=.25, iris="chocolate", lid="donkey_grey", open_=.7, tilt=6, lash=True,
               looks=[(.25, -.1), (-.3, .05)], brow=True, brow_h=1.5, brow_tilt=8, brow_col="donkey_dark")
    for s_ in (-1, 1):
        P += K.decal(f"nos{s_}", tree, snc + hd * 3 + side * .17 * s_ + up * .12, fwd=hd, r=(.07, .05), col="brown", roll=20 * s_)
        P += blush2(f"bl{s_}", tree, fc + side * .38 * s_ + up * -.12 + ff * 3, fwd=ff, size=.1)
    P += mouth2("m", tree, snc + hd * 3 + up * -.17, fwd=hd, w=.36, h=.16, smile=.8, col="ink", tongue=True, teeth=2)
    for s_ in (-1, 1):
        base = h0 + V(.05, .28 * s_, .38)
        d = V(0.25, .55 * s_, 1)
        P += fringe_body(f"ear{s_}", cone_prof(.24, 1.05), 1.05, 3, ["donkey_grey", "fiesta_pink", "donkey_grey"], matrix=M(base, d), seg=14, flare=.12, tooth=.05, seed=40 + s_, sx=.55)
        P.append(K.ear_inner(f"earin{s_}", base + d.normalized() * .12, d, .62, .085, col="fiesta_pink", out=(hd + up * .2).normalized(), off=.1))
    P += tassels("forelock", h0 + V(-.12, 0, .5), (-.5, -.2, .3), n=4, length=.32, width=.1, colors=("fiesta_pink", "sun_yellow", "turquoise"), seed=49, spread=.25, sag=.05)
    for k in range(4):
        t = k / 3
        p0 = V(-.8, 0, 2.15).lerp(V(-1.05, .1, 3.0), t)
        P += tassels(f"mane{k}", p0, (1, 0, .4), n=3, length=.4, width=.11, colors=("fiesta_pink", "sun_yellow", "turquoise"), seed=50 + k, spread=.2, sag=.1)
    P += tassels("tail", (1.3, 0, 1.75), (1, 0, -.2), n=7, length=1.05, width=.12, colors=("fiesta_pink", "sun_yellow", "turquoise", "lime"), seed=7, spread=.28)
    P.append(sphere("tailpom", (.3, .3, .3), loc=(1.22, 0, 1.6), col="fiesta_pink", seg=12, ring=8))
    for k in range(5):
        a = 2 * math.pi * k / 5
        P.append(sphere(f"petal{k}", (.14, .14, .06), loc=(-.95 + .14 * math.cos(a), .02 + .14 * math.sin(a), 3.28), col="fiesta_pink", seg=10, ring=6))
    P.append(sphere("flower_c", (.09, .09, .07), loc=(-.95, .02, 3.31), col="sun_yellow", seg=10, ring=6))
    bpy.context.view_layer.update()
    R = Matrix.Rotation(math.radians(70), 4, 'Z')
    for o in P:
        o.data.transform(o.matrix_world); o.matrix_world = Matrix.Identity(4); o.data.transform(R)
    return P, {"glow": []}

# ======================================================================= DRAGON CHILE (epic)
def dragon():
    """EPIC - 'Dragón Chile': chili dragon, chili-stem horns, jade wings, fierce-cute brows, tiny fangs."""
    P = []; G = []
    P += fringe_body("body", ellip_prof(.95, 2.1, p=.7), 2.1, 7, ["chili", "chili", "mango", "chili", "red_dark", "chili", "chili"],
                     matrix=M((0, .15, .15), (0, .15, 1)), seg=28, flare=.1, tooth=.07, seed=9)
    bp = plate("belly", V(0, .1, 1.05), r=(.62, .3, .78), col="mango", fwd_off=.62); P.append(bp)
    bt = bvh_of([bp])
    for k in range(4):
        P += K.decal(f"bscale{k}", bt, V(0, -3, .55 + .3 * k), r=(.42 - .06 * abs(k - 1.5), .035), col="sun_yellow")
    hc = V(0, -.25, 2.75)
    P += fringe_body("head", ellip_prof(.95, 1.6, p=.85), 1.6, 5, ["chili", "chili", "red_dark", "chili", "chili"],
                     matrix=M(hc - V(0, 0, .75)), seg=28, flare=.09, tooth=.06, seed=10, sx=1.1)
    fp = plate("face", hc + V(0, 0, .1), r=(.82, .5, .58), col="chili", fwd_off=.6); P.append(fp)
    sn = plate("snout", hc + V(0, 0, -.3), r=(.6, .42, .36), col="chili", fwd_off=.85); P.append(sn)
    tree = bvh_of([fp, sn])
    P += eyes2("e", tree, hc + V(0, 0, .18), dx=.38, dz=0, size=.27, iris="mango", lid="red_dark", open_=.78, tilt=-10, lash=True,
               brow=True, brow_h=1.5, brow_tilt=-20, brow_col="red_dark", look=(0, -.05))
    for s_ in (-1, 1):
        P += K.decal(f"nost{s_}", tree, hc + V(.18 * s_, -3, -.18), r=(.07, .045), col="red_dark", roll=25 * s_)
        P += blush2(f"bl{s_}", tree, hc + V(.62 * s_, -3, -.12), size=.12, col="fiesta_pink")
    P += mouth2("m", tree, hc + V(0, -3, -.45), w=.5, h=.18, smile=.9, col="ink", tongue=True, fangs=True)
    for s_ in (-1, 1):
        b0 = hc + V(.45 * s_, .05, .62)
        P.append(tube(f"horn{s_}", [b0, b0 + V(.12 * s_, .1, .35), b0 + V(.32 * s_, .3, .6), b0 + V(.55 * s_, .55, .62)], radius=.13, taper=[1, .85, .6, .25], col="jade", seg=10))
        P.append(cyl(f"hcap{s_}", .2, .16, .12, loc=b0 + V(0, 0, -.02), col="leaf_dark", seg=12))
        base = hc + V(.88 * s_, .1, .15)
        P += fringe_body(f"ear{s_}", cone_prof(.2, .5), .5, 2, ["chili", "red_dark"], matrix=M(base, (s_, .2, .35)), seg=12, flare=.1, tooth=.04, seed=12 + s_, sy=.45)
        w2d = [(0, 0), (.35, .55), (.9, 1.05), (1.55, 1.35), (1.45, .95), (1.25, .55), (1.0, .55), (.85, .15), (.6, .1), (.45, -.25)]
        if s_ < 0: w2d = [(-x, y) for x, y in reversed(w2d)]
        mtx = Matrix.Translation((.55 * s_, .7, 1.85)) @ Matrix.Rotation(math.radians(-25 * s_), 4, 'Z') @ Matrix.Rotation(math.radians(70), 4, 'X')
        P.append(slab(f"wing{s_}", w2d, thick=.07, col="jade", bevel=.025, matrix=mtx))
        bone = [V(0, 0, .06), V(.4 * s_, .58, .06), V(.9 * s_, 1.05, .06), V(1.55 * s_, 1.35, .06)]
        P.append(tube(f"wbone{s_}", [mtx @ b for b in bone], radius=.07, taper=[1.2, 1, .8, .5], col="dark_green", seg=8))
        for (fx, fy) in ((1.25, .55), (.85, .15)):
            P.append(tube(f"wrib{s_}{fx}", [mtx @ V(.4 * s_, .58, .05), mtx @ V(fx * s_, fy, .05)], radius=.04, col="dark_green", seg=6))
        P.append(sphere(f"wclaw{s_}", (.09, .09, .09), loc=mtx @ V(1.55 * s_, 1.35, .06), col="cream", seg=8, ring=6))
        P += paw(f"foot{s_}", (.45 * s_, -.45, .22), fwd=(0, -1, .4), s=.34, col="chili", pad="mango")
        P += limb(f"arm{s_}", (.75 * s_, -.3, 1.6), (.62 * s_, -.85, 1.25), .2, .18, 2, ["chili", "mango"], seed=90 + s_)
        P += paw(f"hand{s_}", (.6 * s_, -.95, 1.2), fwd=(0, -1, .1), s=.22, col="chili", pad="mango", toes=3)
    tp = [V(0, .9, .5), V(.4, 1.6, .35), V(1.0, 1.9, .5), V(1.45, 1.75, .85)]
    P += chain("tail", tp, [.4, .3, .2, .12], 2, ["chili", "red_dark", "chili", "mango"], seed=95)
    P.append(star_prism("tailtip", 3, .32, .16, .1, loc=(1.55, 1.7, 1.0), rot=(90, 0, 30), col="jade"))
    for k in range(4):
        z = 2.1 - .42 * k
        P.append(cyl(f"spike{k}", .16, .01, .32, loc=(0, .95 - .05 * k, z), rot=(-75, 0, 0), col="jade", seg=8))
    G.append(sphere("ember", (.07, .07, .07), loc=hc + V(-.45, -1.35, -.05), col="neon_gold", seg=8, ring=5))
    G.append(sphere("ember2", (.05, .05, .05), loc=hc + V(-.62, -1.4, .12), col="neon_gold", seg=8, ring=5))
    return P + G, {"glow": G}

# ======================================================================= TORO DE ORO (legendary)
def toro():
    """LEGENDARY - 'Toro de Oro': chunky golden bull with crown, big horns, nose ring and a proud smirk."""
    P = []; G = []
    gc = ["gold", "gold_deep", "gold", "gold_pale", "gold", "gold_deep", "gold", "gold_pale"]
    P += fringe_body("body", ellip_prof(1.15, 2.6, p=.5), 2.6, 9, gc, matrix=M((0, 1.45, 1.75), (0, -1, 0)), seg=30, flare=.09, tooth=.07, seed=11, sx=1.05)
    for i, (x, y) in enumerate([(-.62, -.55), (.62, -.55), (-.62, .85), (.62, .85)]):
        P += limb(f"leg{i}", (x, y, 1.35), (x, y, .16), .34, .32, 4, ["gold_deep", "gold", "gold_pale", "gold"], seed=100 + i, round_end=.05, seg=14)
        P.append(cyl(f"hoof{i}", .37, .35, .24, loc=(x, y, 0), col="chocolate", seg=16, bevel=.08))
        P.append(box(f"hsplit{i}", (.05, .3, .2), loc=(x, y - .3, .1), col="ink_soft", bevel=.02))
    hc = V(0, -1.35, 2.45)
    P += fringe_body("head", ellip_prof(.95, 1.55, p=1.0), 1.55, 5, ["gold", "gold_deep", "gold", "gold_pale", "gold"],
                     matrix=M(hc - V(0, -.15, .75), (0, -.25, 1)), seg=28, flare=.08, tooth=.06, seed=12, sx=1.15)
    fp = plate("face", hc + V(0, 0, .12), r=(.85, .5, .55), col="gold", fwd_off=.62); P.append(fp)
    mz = plate("muzzle", hc + V(0, 0, -.42), r=(.74, .45, .44), col="gold_pale", fwd_off=.82); P.append(mz)
    tree = bvh_of([fp, mz])
    P += eyes2("e", tree, hc + V(0, 0, .2), dx=.4, dz=0, size=.25, iris="chocolate", lid="gold_deep", open_=.66, tilt=-6, lash=True,
               brow=True, brow_h=1.45, brow_tilt=-14, brow_col="chocolate", look=(-.1, 0))
    for s_ in (-1, 1):
        P += K.decal(f"nost{s_}", tree, hc + V(.28 * s_, -3, -.36), r=(.1, .07), col="gold_deep", roll=20 * s_)
        P += blush2(f"bl{s_}", tree, hc + V(.66 * s_, -3, -.05), size=.11, col="blush")
    P += mouth2("m", tree, hc + V(.08, -3, -.68), w=.42, h=.1, smile=1.3, col="ink", tongue=False, teeth=2)
    for s_ in (-1, 1):
        b0 = hc + V(.75 * s_, -.05, .5)
        P.append(tube(f"horn{s_}", [b0, b0 + V(.45 * s_, 0, .1), b0 + V(.85 * s_, -.05, .45), b0 + V(.95 * s_, -.1, .95)], radius=.2, taper=[1, .85, .6, .2], col="snow", seg=12))
        P.append(torus(f"hornband{s_}", .2, .06, loc=b0 + V(.3 * s_, 0, .05), rot=(0, 90, 0), col="gold_deep", seg=16, mseg=6))
        base = hc + V(.92 * s_, .05, .05)
        P += fringe_body(f"ear{s_}", cone_prof(.24, .55), .55, 2, ["gold_deep", "gold"], matrix=M(base, (s_, .1, -.25)), seg=12, flare=.1, tooth=.04, seed=110 + s_, sy=.45)
        P.append(K.ear_inner(f"earin{s_}", base, V(s_, .1, -.25), .42, .12, col="blush", out=(0, -1, 0), off=.1))
    P += tassels("forelock", hc + V(0, -.45, .62), (0, -.6, .5), n=4, length=.3, width=.1, colors=("gold_deep", "gold_pale", "gold"), seed=109, spread=.3, sag=.04)
    P.append(tube("medalcord", [(-.75, -1.05, 1.95), (-.4, -1.45, 1.45), (0, -1.6, 1.2), (.4, -1.45, 1.45), (.75, -1.05, 1.95)], radius=.05, col="chili", seg=6))
    P.append(cyl("medal", .38, .38, .12, loc=(0, -1.62, 1.12), rot=(90, 0, 0), col="gold_deep", seg=24, bevel=.04))
    P.append(star_prism("medalstar", 5, .28, .12, .1, loc=(0, -1.76, 1.12), rot=(90, 0, 0), col="gold_pale"))
    P.append(torus("ring", .2, .045, loc=hc + V(0, -1.3, -.62), rot=(90, 0, 0), col="silver", seg=20, mseg=6))
    cz = hc.z + .72
    P.append(cyl("crownbase", .52, .58, .3, loc=(0, hc.y + .05, cz), col="gold", seg=20, bevel=.03))
    for k in range(5):
        a = 2 * math.pi * k / 5 + math.pi / 2
        pt = V(.5 * math.cos(a), hc.y + .05 + .5 * math.sin(a), cz + .28)
        P.append(cyl(f"crownpt{k}", .14, .01, .4, loc=pt, col="gold", seg=8))
        G.append(sphere(f"gem{k}", (.07, .07, .07), loc=pt + V(0, 0, .42), col="neon_pink" if k % 2 else "neon_cyan", seg=8, ring=6))
    G.append(sphere("crowngem", (.12, .08, .12), loc=(0, hc.y - .5, cz + .15), col="neon_pink", seg=10, ring=6))
    P += tassels("tail", (0, 2.65, 1.9), (0, 1, -.3), n=6, length=1.0, width=.13, colors=("gold", "gold_deep", "gold_pale"), seed=13, spread=.25)
    P.append(sphere("tailpom", (.28, .28, .28), loc=(0, 2.62, 1.85), col="gold_deep", seg=12, ring=8))
    return P + G, {"glow": G}

# ======================================================================= RENITO (event)
def renito():
    """EVENT (Navidad) - 'Renito': chubby reindeer piñata, Santa hat, scarf, glowing nose, candy cane."""
    P = []; G = []
    P += fringe_body("body", ellip_prof(.95, 2.0, p=.8), 2.0, 6, ["brown", "cream", "xmas_red", "brown", "xmas_green", "brown"],
                     matrix=M((0, .05, .05)), seg=28, flare=.1, tooth=.07, seed=14, sy=.92)
    hc = V(0, -.1, 2.6)
    P += fringe_body("head", ellip_prof(.92, 1.65, p=1.15), 1.65, 5, ["brown", "brown", "cream", "brown", "brown"],
                     matrix=M(hc - V(0, 0, .8)), seg=28, flare=.09, tooth=.065, seed=15, sx=1.08, sy=.95)
    fp = plate("face", hc + V(0, 0, .08), r=(.8, .5, .62), col="brown", fwd_off=.6); P.append(fp)
    mz = plate("muzzle", hc + V(0, 0, -.34), r=(.48, .3, .3), col="cream", fwd_off=.95); P.append(mz)
    tree = bvh_of([fp, mz])
    P += eyes2("e", tree, hc + V(0, 0, .15), dx=.36, dz=0, size=.27, iris="chocolate", lid=None, lash=True, look=(0, .05))
    G.append(sphere("nose", (.2, .17, .17), loc=hc + V(0, -1.2, -.22), col="candy_red", seg=14, ring=8))
    P += mouth2("m", tree, hc + V(0, -3, -.46), w=.3, h=.16, smile=.7, col="ink", tongue=True)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.58 * s_, -3, -.15), size=.14)
        P += K.decal(f"freck{s_}", tree, hc + V(.32 * s_, -3, -.3), r=(.03, .03), col="chocolate")
        b0 = hc + V(.42 * s_, .05, .72)
        main = [b0, b0 + V(.2 * s_, 0, .45), b0 + V(.5 * s_, .05, .8), b0 + V(.6 * s_, .1, 1.15)]
        P.append(tube(f"ant{s_}", main, radius=.09, taper=[1.1, 1, .8, .55], col="wood_dark", seg=8))
        for (a, b) in (((.2, 0, .45), (.5, -.05, .62)), ((.5, .05, .8), (.85, 0, .9)), ((.5, .05, .8), (.35, .05, 1.15))):
            P.append(tube(f"antb{s_}{a[2]}{b[0]}", [b0 + V(a[0] * s_, a[1], a[2]), b0 + V(b[0] * s_, b[1], b[2])], radius=.065, taper=[1, .6], col="wood_dark", seg=7))
        base = hc + V(.86 * s_, .05, .2)
        P += fringe_body(f"ear{s_}", cone_prof(.24, .55), .55, 2, ["brown", "brown"], matrix=M(base, (s_, -.1, .2)), seg=12, flare=.1, tooth=.04, seed=152 + s_, sy=.45)
        P += paw(f"hoofF{s_}", (.42 * s_, -.72, .22), fwd=(0, -1, .4), s=.32, col="chocolate", pad="wood_dark", toes=2)
    hat_m = Matrix.Translation(hc + V(-.15, .05, .55)) @ Matrix.Rotation(math.radians(-18), 4, 'Y')
    hat = cyl("hat", .72, .08, 1.15, col="xmas_red", seg=22, bevel=.04); hat.data.transform(hat_m)
    for v in hat.data.vertices:
        lz = (v.co.z - (hc.z + .55))
        if lz > .4: v.co.x += -.35 * ((lz - .4) / .8) ** 2
    P.append(hat)
    P.append(torus("hatrim", .7, .16, col="snow", seg=26, mseg=8)); P[-1].data.transform(hat_m)
    P.append(sphere("hatpom", (.2, .2, .2), loc=hc + V(-.85, .05, 1.55), col="snow", seg=12, ring=8))
    P.append(torus("scarf", .9, .14, loc=hc + V(0, .02, -.85), col="xmas_green", seg=28, mseg=8))
    P.append(ribbon("scarftail", [hc + V(.45, -.8, -.9), hc + V(.55, -.95, -1.3), hc + V(.5, -.92, -1.65)], width=.3, normal=(0, -1, 0), col="xmas_green", thick=.08))
    for k in range(3):
        P.append(box(f"scarfstripe{k}", (.32, .1, .06), loc=hc + V(.52, -.97, -1.15 - .18 * k), col="xmas_red", bevel=.02))
    P += tassels("scarffr", hc + V(.5, -.92, -1.68), (0, 0, -1), n=4, length=.2, width=.07, colors=("xmas_red", "snow"), seed=158, spread=.3, sag=0)
    P += limb("arm", (.7, -.3, 1.3), (.95, -.75, 1.0), .24, .21, 2, ["brown", "cream"], seed=150)
    P.append(sphere("hand", (.24, .22, .22), loc=(1.0, -.8, 1.0), col="chocolate", seg=12, ring=8))
    cane = [(1.0, -.85, .1), (1.0, -.85, 1.0), (1.0, -.85, 1.85), (.9, -.85, 2.15), (.65, -.85, 2.2), (.48, -.85, 2.0)]
    P += striped_tube("cane", cane, .085, ["candy_red", "snow"] * 6, seg=10)
    P += limb("arm2", (-.7, -.3, 1.25), (-.55, -.68, .7), .23, .2, 2, ["brown", "cream"], seed=151)
    P.append(sphere("hand2", (.22, .2, .2), loc=(-.53, -.72, .62), col="chocolate", seg=12, ring=8))
    P.append(sphere("tailpuff", (.28, .25, .3), loc=(0, .95, .7), col="cream", seg=12, ring=8))
    return P + G, {"glow": G}

# ======================================================================= TOROGOZ CÓSMICO (mythic)
def torogoz():
    """MYTHIC - 'Torogoz Cósmico': galaxy bird inspired by El Salvador's national bird (racket tail), on a cloud."""
    P = []; G = []
    for k, (x, y, z, r) in enumerate([(0, 0, .35, .7), (.75, .1, .3, .55), (-.75, .05, .3, .55), (.35, -.45, .25, .5), (-.4, -.45, .25, .5), (0, .55, .28, .55)]):
        P.append(sphere(f"cloud{k}", (r * 1.2, r, r * .75), loc=(x, y, z), col="lavender" if k % 2 else "white", seg=16, ring=10))
    bc = ["cosmic_2", "torogoz_t", "torogoz_r", "cosmic_2", "cosmic_3", "cosmic_1"]
    P += fringe_body("body", ellip_prof(.85, 2.1, p=.8), 2.1, 6, bc, matrix=M((0, .15, .55), (0, .25, 1)), seg=28, flare=.1, tooth=.07, seed=16, sy=.95)
    hc = V(0, -.05, 2.85)
    P += fringe_body("head", ellip_prof(.8, 1.45, p=1.45), 1.45, 4, ["torogoz_t", "cosmic_2", "torogoz_t", "cosmic_2"],
                     matrix=M(hc - V(0, 0, .7)), seg=28, flare=.09, tooth=.06, seed=17)
    fp = plate("face", hc + V(0, 0, .02), r=(.72, .45, .5), col="torogoz_t", fwd_off=.5); P.append(fp)
    tree = bvh_of([fp])
    for s_ in (-1, 1):   # black bandit mask band + turquoise brow, stuck to the plate
        P += K.decal(f"mask{s_}", tree, hc + V(.42 * s_, -3, .0), r=(.3, .17), col="ink", roll=-8 * s_)
    P += eyes2("e", tree, hc + V(0, 0, .02), dx=.33, dz=0, size=.21, iris="cosmic_4", lid=None, lash=True, look=(0, .05), star=True)
    for s_ in (-1, 1):
        G.append(ribbon(f"brow{s_}", [hc + V(.16 * s_, -.78, .3), hc + V(.46 * s_, -.68, .38), hc + V(.72 * s_, -.3, .3)], width=.1, normal=(0, -1, .3), col="neon_cyan", thick=.05))
        P += blush2(f"bl{s_}", tree, hc + V(.5 * s_, -3, -.25), size=.11)
    beak = cyl("beak", .2, .01, .75, col="ink", seg=12); beak.data.transform(M(hc + V(0, -.72, -.15), (0, -1, -.15))); P.append(beak)
    P.append(torus("beakband", .17, .03, col="cosmic_1", seg=14, mseg=4)); P[-1].data.transform(M(hc + V(0, -.8, -.16), (0, -1, -.15)))
    for k in range(3):   # head crest
        P.append(cyl(f"crest{k}", .09, .01, .45 - .08 * k, col="torogoz_r", seg=8)); P[-1].data.transform(M(hc + V(0, .1 + .18 * k, .68 - .08 * k), (0, .6 + .3 * k, 1)))
    for s_ in (-1, 1):
        w2d = [(-.25, .1), (.25, .25), (.65, -.15), (.75, -.8), (.6, -1.5), (.25, -1.1), (-.1, -.55)]
        mtx = Matrix.Translation((.8 * s_, -.05, 2.5)) @ Matrix.Rotation(math.radians(-12 * s_), 4, 'Y') @ Matrix.Rotation(math.radians(90), 4, 'Z') @ Matrix.Rotation(math.radians(90), 4, 'X')
        w2d = [(x * .8, y * .8) for x, y in w2d]
        P.append(slab(f"wing{s_}", w2d, thick=.14, col="cobalt", bevel=.05, matrix=mtx))
        w2 = [(x * .7 + .05, y * .55 - .05) for x, y in w2d]
        P.append(slab(f"wing2{s_}", w2, thick=.2, col="torogoz_t", bevel=.04, matrix=mtx))
        for j in range(3):
            P.append(sphere(f"toe{s_}{j}", (.07, .2, .07), loc=(.3 * s_ + .1 * (j - 1), -.45, .74), rot=(0, 0, 15 * (j - 1)), col="tangerine", seg=8, ring=5))
    for s_ in (-1, 1):
        a = V(.1 * s_, .8, 1.4); b = V(.5 * s_, 1.5, 1.35); c = V(.95 * s_, 2.05, 1.0)
        P.append(tube(f"shaft{s_}", [a, (a + b) / 2 + V(0, 0, -.1), b, c], radius=.045, col="cosmic_1", seg=6))
        rk = slab(f"racket{s_}", [(0, -.08), (.33, .38), (.3, .9), (0, 1.08), (-.3, .9), (-.33, .38)], thick=.06, col="neon_cyan" if s_ < 0 else "neon_pink", bevel=.02,
                  matrix=Matrix.Translation(c) @ Matrix.Rotation(math.radians(-40 * s_), 4, 'Z') @ Matrix.Rotation(math.radians(70), 4, 'X') @ Matrix.Rotation(math.radians(180 + 30 * s_), 4, 'Z'))
        G.append(rk)
    for k, (x, y, z) in enumerate([(-1.05, -.2, 1.6), (1.1, -.1, 2.1), (.9, .4, 3.4)]):
        G.append(star_prism(f"spark{k}", 4, .2, .07, .06, loc=(x, y, z), rot=(90, 0, 15 * k), col="neon_gold", bevel=.02))
    return P + G, {"glow": G}


# ======================================================================= MEME 1 animals, face upgrades (same ids)
def _strip(P, prefixes):
    keep = []
    for o in P:
        if any(o.name.startswith(p) for p in prefixes):
            bpy.data.objects.remove(o, do_unlink=True)
        else:
            keep.append(o)
    return keep

def mapache_nel():
    """MYTHIC - raccoon charging broom-first yelling '¡NEL!'. v2: bandit mask decals, angry glossy eyes + brows, big yelling mouth."""
    import memes as MM
    P, extra = MM.mapache_nel(); G = extra["glow"]
    P = _strip(P, ("eye", "mask", "brow", "mouth", "tongue", "tooth", "nose", "belly"))
    lean = 14; Lm = Matrix.Rotation(math.radians(-lean), 4, 'X'); w = lambda x, y, z: Lm @ V(x, y, z)
    hc = w(0, -.2, 3.25); f = (Lm.to_3x3() @ V(0, -1, 0)).normalized(); up = (Lm.to_3x3() @ V(0, 0, 1)).normalized()
    fp = plate("face", hc + up * .05, fwd=f, r=(.95, .5, .64), col="donkey_grey", fwd_off=.62); P.append(fp)
    bp = plate("belly", w(0, .1, 1.35), fwd=f, r=(.66, .3, .8), col="snow", fwd_off=.7); P.append(bp)
    ch = plate("chin", hc + up * -.68, fwd=f, r=(.58, .36, .4), col="snow", fwd_off=.72); P.append(ch)
    tree = bvh_of([fp, ch])
    side = f.cross(V(0, 0, 1)).normalized()
    for s_ in (-1, 1):
        P += K.decal(f"mask{s_}", tree, hc + up * .14 + side * -.4 * s_ + f * 3, fwd=f, r=(.4, .26), col="ink", roll=-12 * s_, th=.035)
        P += K.decal(f"cheekw{s_}", tree, hc + up * -.28 + side * -.55 * s_ + f * 3, fwd=f, r=(.26, .16), col="snow", roll=20 * s_)
    P += eyes2("e", tree, hc + up * .14, fwd=f, dx=.4, dz=0, size=.27, iris="sun_yellow", lid="donkey_dark", open_=.82, tilt=-14, lash=True,
               brow=True, brow_h=1.5, brow_tilt=-26, brow_arch=.05, brow_col="ink", look=(0, -.05), push=.06)
    tip = hc + f * 1.42 + up * -.45
    P.append(sphere("nose", (.16, .12, .12), loc=tip, col="ink", seg=12, ring=8))
    P.append(sphere("nosehl", (.05, .03, .03), loc=tip + f * .1 + up * .06 + side * .04, col="eye_white", seg=8, ring=5))
    P += mouth2("m", tree, hc + up * -.82 + f * 3, fwd=f, w=.62, h=.42, smile=.4, col="ink", tongue=True, teeth=2, shape="D", depth=.06)
    for s_ in (-1, 1):
        base = hc + w(.62 * s_, .05, .55)
        P.append(K.ear_inner(f"earin{s_}", base, w(.4 * s_, 0, 1), .4, .14, col="ink_soft", out=f, off=.13))
        P += tassels(f"fluff{s_}", hc + up * -.3 + side * -.95 * s_, (-side * s_ + up * -.2).normalized() * -1 if False else (side * -s_), n=3, length=.28, width=.12, colors=("snow", "donkey_grey"), seed=880 + s_, spread=.35, sag=0)
    for k in range(3):
        G.append(tube(f"yell{k}", [hc + f * 1.6 + up * (-.2 + .25 * (k - 1)) + side * .9, hc + f * 1.75 + up * (-.2 + .4 * (k - 1)) + side * 1.25], radius=.04, col="neon_gold", seg=5))
    return P + G, {"glow": G}

def michi_aplausos():
    """LEGENDARY - black cat with weirdly human gloved hands slow-clapping. v2: smooth face, side-eye, uncanny human grin."""
    import memes as MM
    P, extra = MM.michi_aplausos(); G = extra["glow"]
    P = _strip(P, ("f_eye", "gum", "tooth", "nose", "earin", "gl", "arm", "cl"))
    G = []
    hc = V(0, -.05, 2.6)
    for s in (-1, 1):   # hands a bit lower so the uncanny grin reads above the clap
        sh = V(.72 * s, -.35, 1.5); wr = V(.3 * s, -1.4, 1.4)
        P += limb(f"arm{s}", sh, wr, .24, .2, 3, ["ink", "ink_soft", "ink"], seed=70 + s, seg=14)
        P += MM.glove(f"gl{s}", wr, (-.25 * s, -.35, .55), s=1.05, col="eye_white", cuff="eye_white", palm_up=(s > 0))
        for k in range(3):
            a = math.radians(60 + 30 * k)
            p0 = V(0, -2.0, 2.0) + V(s * .45 * math.cos(a), 0, .45 * math.sin(a) - .2)
            G.append(tube(f"cl{s}{k}", [p0, p0 + V(s * .28 * math.cos(a), 0, .28 * math.sin(a))], radius=.04, col="neon_gold", seg=5))
    fp = plate("face", hc + V(0, 0, .02), r=(.9, .5, .66), col="ink", fwd_off=.66); P.append(fp)
    mz = plate("muzzle", hc + V(0, 0, -.34), r=(.62, .28, .3), col="ink_soft", fwd_off=.98); P.append(mz)
    tree = bvh_of([fp, mz])
    P += eyes2("e", tree, hc + V(0, 0, .16), dx=.42, dz=0, size=.3, iris="mango", lid="ink_soft", open_=.5, tilt=4, lash=False,
               looks=[(-.55, 0), (-.55, 0)], lower="ink_soft", brow=None)
    P += nose2("nose", tree, hc + V(0, -3, -.18), size=.1, col="fiesta_pink")
    P += mouth2("m", tree, hc + V(0, -3, -.42), w=.9, h=.24, smile=.45, col="tongue", tongue=False, teeth=6, lip="ink_soft", depth=.05)
    for s_ in (-1, 1):
        base = hc + V(.58 * s_, .05, .62)
        P.append(K.ear_inner(f"earin{s_}", base + V(0, -.02, -.05), V(.35 * s_, 0, 1), .32, .17, col="bubblegum", off=.2))
    return P + G, {"glow": G}

C.CAM["burrito"] = (-35, 12)
REG = {"michi": michi, "burrito": burrito, "dragon": dragon, "toro": toro, "renito": renito, "torogoz": torogoz, "mapache_nel": mapache_nel, "michi_aplausos": michi_aplausos}
C.CREATURES.update(REG)

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    prev = os.environ.get("PREVIEW")
    names = argv or list(REG)
    metas = []
    for n in names:
        if prev:
            os.makedirs("/tmp/prev", exist_ok=True)
            metas.append(build2(n, samples=int(os.environ.get("SAMPLES", "24")), res=(700, 700), out=f"/tmp/prev/{n}.png"))
        else:
            metas.append(build2(n, samples=int(os.environ.get("SAMPLES", "96"))))
    if not prev:
        mf = f"{ROOT}/export/creatures/_meta.json"; old = json.load(open(mf))
        for m in metas: old[m["name"]] = m
        json.dump(old, open(mf, "w"), indent=1)
