import sys, math, random, json, os
sys.path.insert(0, os.path.dirname(__file__))
import importlib, plib; importlib.reload(plib)
from plib import *
from mathutils import Vector, Matrix

def M(loc=(0,0,0), direction=(0,0,1), roll=0, scale=1.0):
    d = Vector(direction).normalized()
    q = d.to_track_quat('Z', 'Y')
    return Matrix.Translation(loc) @ q.to_matrix().to_4x4() @ Matrix.Rotation(math.radians(roll), 4, 'Z') @ Matrix.Scale(scale, 4)

def cone_prof(R, H, tipround=0.15):
    return lambda z: R * max(0.0, (1 - z / H)) ** 0.9 + (0 if z < H * 0.98 else 0)

def ellip_prof(R, H, p=1.0):
    return lambda z: R * max(0.0, 1 - ((2 * z / H) - 1) ** 2) ** (0.5 * p)

def face(objs, name, center, fwd=(0, -1, 0), eye_dx=.42, eye_dz=.15, size=.32, style="round", mouth="smile",
         mouth_dz=-.32, mw=.34, iris=None, blush_dx=.68, blush_dz=-.18, look=(0, 0), lid=None, mouth_col="ink", lid_roll=0):
    """center = point inside the head; rays cast along fwd from behind."""
    c = Vector(center); f = Vector(fwd).normalized()
    side = f.cross(Vector((0, 0, 1))).normalized()
    out = []
    for s in (-1, 1):
        o = c + side * eye_dx * s + Vector((0, 0, eye_dz)) + f * 12
        e, p, n = cute_eye(f"{name}_eye{'L' if s < 0 else 'R'}", objs, o, -f, size=size, style=style, look=look, iris=iris, lid=lid, lid_roll=lid_roll * s)
        out += e
        if blush_dx:
            out += blush(f"{name}_blush{s}", objs, c + side * blush_dx * s + Vector((0, 0, blush_dz)) + f * 12, -f, size=size * .45)
    if mouth:
        out += smile(f"{name}_mouth", objs, c + Vector((0, 0, mouth_dz)) + f * 12, -f, width=mw, height=mw * .35, r=.035,
                     open_mouth=(mouth == "open"), col=mouth_col)
    return out

# ======================================================================= creatures
def estrellita():
    """COMMON - classic 7-point-style star piñata turned into a creature: round fringe belly,
    big fringed cones (top, arms, legs) with streamers; legs end in pompom feet."""
    parts = []; R = .9; cz = 1.75
    body = fringe_body("body", ellip_prof(R, 2 * R), 2 * R, 8,
                       ["fiesta_pink", "sun_yellow", "turquoise", "tangerine", "fiesta_pink", "lime", "turquoise", "sun_yellow"],
                       matrix=M((0, 0, cz - R)), seg=32, flare=.10, tooth=.075, seed=2, sx=1.05)
    parts += body
    cols = [["sun_yellow", "fiesta_pink", "turquoise"], ["turquoise", "sun_yellow", "fiesta_pink"], ["lime", "fiesta_pink", "sun_yellow"],
            ["tangerine", "grape", "sun_yellow"], ["grape", "tangerine", "lime"]]
    dirs = [(0, 0, 1), (-1, -.05, .42), (1, -.05, .42), (-.42, -.05, -1), (.42, -.05, -1)]
    tcols = [("fiesta_pink", "turquoise", "sun_yellow", "grape", "lime"), ("sun_yellow", "fiesta_pink", "lime", "grape"),
             ("lime", "sun_yellow", "fiesta_pink", "turquoise")]
    for i, d in enumerate(dirs):
        dv = Vector(d).normalized(); base = Vector((0, 0, cz)) + dv * R * .45
        H = 1.55 if i == 0 else (1.35 if i < 3 else 1.05)
        Rc = .55 if i < 3 else .45
        parts += fringe_body(f"cone{i}", cone_prof(Rc, H), H, 5, cols[i], matrix=M(base, dv, roll=i * 17),
                             seg=18, flare=.14, tooth=.07, seed=10 + i)
        tip = base + dv * (H - .03)
        if i < 3:
            parts += tassels(f"t{i}", tip, dv, n=5 if i == 0 else 4, length=.85 if i == 0 else .75, width=.12, colors=tcols[i], seed=i, spread=.45)
            parts.append(sphere(f"tipball{i}", (.12, .12, .12), loc=tip, col="sun_yellow", seg=12, ring=8))
        else:
            parts.append(sphere(f"pom{i}", (.26, .3, .2), loc=tip + Vector((0, -.06, .03)), col="hot_magenta", seg=14, ring=8))
    parts += face(body, "f", (0, 0, cz + .05), size=.26, eye_dx=.34, eye_dz=.12, mouth="open", mouth_dz=-.25, mw=.42,
                  blush_dx=.6, blush_dz=-.14)
    return parts, {"glow": []}


def lin_prof(r0, r1, H, round_end=0.25):
    def f(z):
        t = z / H; r = r0 + (r1 - r0) * t
        # round both ends a little
        e = min(t, 1 - t) / max(round_end, 1e-3)
        return r * (min(1.0, e) ** 0.35 if e < 1 else 1.0)
    return f

def limb(name, a, b, r0, r1, bands, colors, seg=16, flare=.14, tooth=.06, seed=0, sx=1, sy=1, round_end=.18, roll=0):
    a, b = Vector(a), Vector(b); d = b - a
    return fringe_body(name, lin_prof(r0, r1, d.length, round_end), d.length, bands, colors, matrix=M(a, d, roll=roll),
                       seg=seg, flare=flare, tooth=tooth, seed=seed, sx=sx, sy=sy)

def burrito():
    """COMMON - the classic burro piñata, chubby and derpy-sleepy."""
    P = []
    bc = ["snow", "fiesta_pink", "snow", "turquoise", "snow", "sun_yellow", "snow", "fiesta_pink"]
    body = fringe_body("body", ellip_prof(.82, 2.5, p=.55), 2.5, 9, bc, matrix=M((1.2, 0, 1.55), (-1, 0, 0)),
                       seg=30, flare=.10, tooth=.07, seed=4, sy=1.08)
    P += body
    # legs
    for i, (x, y) in enumerate([(-.65, -.38), (-.65, .38), (.7, -.38), (.7, .38)]):
        P += limb(f"leg{i}", (x, y, 1.3), (x, y, .12), .27, .26, 4, ["donkey_grey", "fiesta_pink", "donkey_grey", "turquoise"], seed=20 + i, round_end=.05)
        P.append(cyl(f"hoof{i}", .3, .28, .2, loc=(x, y, 0), col="ink_soft", seg=14, bevel=.06))
    # neck + head
    P += limb("neck", (-1.12, 0, 1.62), (-1.25, 0, 2.55), .45, .38, 4, ["donkey_grey", "sun_yellow", "donkey_grey", "fiesta_pink"], seed=30, flare=.12)
    hd = Vector((-1.0, -.35, -.18)).normalized()
    head = fringe_body("head", ellip_prof(.55, 1.35, p=.8), 1.35, 5, ["donkey_grey", "donkey_grey", "snow", "donkey_grey", "donkey_grey"],
                       matrix=M((-1.0, .18, 2.75), hd), seg=26, flare=.08, tooth=.06, seed=31, sy=1.05)
    P += head
    snout_c = Vector((-1.0, .18, 2.75)) + hd * 1.22
    sn = sphere("snout", (.42, .38, .34), loc=snout_c + Vector((0, 0, -.06)), col="cream", seg=18, ring=10); P.append(sn)
    for s_ in (-1, 1):
        side = hd.cross(Vector((0, 0, 1))).normalized()
        nos = sphere(f"nostril{s_}", (.07, .05, .05), loc=snout_c + hd * .4 + side * .14 * s_ + Vector((0, 0, .02)), col="brown", seg=8, ring=5); P.append(nos)
    # ears
    for s_, ang in ((-1, -20), (1, 20)):
        base = Vector((-.95, .18 + .28 * s_, 3.12))
        P += fringe_body(f"ear{s_}", cone_prof(.22, 1.0), 1.0, 3, ["donkey_grey", "fiesta_pink", "donkey_grey"],
                         matrix=M(base, (0.25, .55 * s_, 1)), seg=14, flare=.12, tooth=.05, seed=40 + s_, sx=.55)
    # mane: tassel tufts along the neck
    for k in range(4):
        t = k / 3
        p0 = Vector((-.8, 0, 2.15)).lerp(Vector((-1.05, .1, 3.15)), t)
        P += tassels(f"mane{k}", p0, (1, 0, .4), n=3, length=.38, width=.11, colors=("fiesta_pink", "sun_yellow", "turquoise"), seed=50 + k, spread=.2, sag=.1)
    # tail
    P += tassels("tail", (1.3, 0, 1.75), (1, 0, -.2), n=6, length=1.0, width=.12, colors=("fiesta_pink", "sun_yellow", "turquoise", "lime"), seed=7, spread=.25)
    # saddle blanket (striped serape-ish band)
    P.append(sphere("tailpom", (.3, .3, .3), loc=(1.22, 0, 1.6), col="fiesta_pink", seg=12, ring=8))
    # flower on the head (between the ears)
    for k in range(5):
        a = 2 * math.pi * k / 5
        P.append(sphere(f"petal{k}", (.13, .13, .06), loc=(-1.12 + .13 * math.cos(a), .02 + .13 * math.sin(a), 3.2), col="fiesta_pink", seg=10, ring=6))
    P.append(sphere("flower_c", (.09, .09, .07), loc=(-1.12, .02, 3.23), col="sun_yellow", seg=10, ring=6))
    # face on the head
    side = hd.cross(Vector((0, 0, 1))).normalized()
    fc = Vector((-1.0, .18, 2.75)) + hd * .55
    P += face(head, "f", fc + Vector((0, 0, .02)), fwd=(hd + Vector((0, 0, .15))).normalized(), size=.2, eye_dx=.27, eye_dz=.18,
              style="sleepy", mouth=None, blush_dx=.36, blush_dz=-.12)
    P += smile("f_mouth", [sn], snout_c + Vector((0, 0, -.14)) + hd * 6, -hd, width=.34, height=.09, r=.03)
    # standardise: every creature faces -Y (Roblox front after export = -Z... see IMPORT_GUIDE)
    bpy.context.view_layer.update()
    R = Matrix.Rotation(math.radians(70), 4, 'Z')
    for o in P:
        bake_xform(o); o.data.transform(R)
    return P, {"glow": []}

def chain(name, pts, radii, bands_per, colors, seed=0, seg=14, flare=.14, tooth=.05):
    out = []
    for i in range(len(pts) - 1):
        out += limb(f"{name}{i}", pts[i], pts[i+1], radii[i], radii[i+1], bands_per, colors[i % len(colors):] + colors[:i % len(colors)],
                    seg=seg, flare=flare, tooth=tooth, seed=seed + i, round_end=.08)
    return out

def michi():
    """UNCOMMON - chubby sitting cat piñata, smug face, one paw waving, curly tail."""
    P = []
    body = fringe_body("body", ellip_prof(.95, 2.0, p=.75), 2.0, 6, ["cat_orange", "cat_cream", "cat_orange", "fiesta_pink", "cat_orange", "cat_cream"],
                       matrix=M((0, .05, .05)), seg=30, flare=.10, tooth=.07, seed=5, sy=.92)
    P += body
    hc = Vector((0, -.05, 2.55))
    head = fringe_body("head", ellip_prof(1.0, 1.75, p=1.25), 1.75, 5, ["cat_orange", "cat_orange", "cat_cream", "cat_orange", "cat_orange"],
                       matrix=M(hc - Vector((0, 0, .85))), seg=32, flare=.09, tooth=.065, seed=6, sx=1.12, sy=.95)
    P += head
    # muzzle patch
    mz = sphere("muzzle", (.46, .3, .3), loc=hc + Vector((0, -.86, -.32)), col="cat_cream", seg=16, ring=10); P.append(mz)
    P.append(sphere("nose", (.1, .07, .07), loc=hc + Vector((0, -1.13, -.2)), col="fiesta_pink", seg=10, ring=6))
    # ears
    for s_ in (-1, 1):
        base = hc + Vector((.55 * s_, .05, .62))
        P += fringe_body(f"ear{s_}", cone_prof(.36, .8), .8, 3, ["cat_orange", "fiesta_pink", "cat_orange"],
                         matrix=M(base, (.35 * s_, 0, 1), roll=0), seg=14, flare=.1, tooth=.05, seed=60 + s_, sx=1.0, sy=.45)
        P.append(sphere(f"earin{s_}", (.15, .05, .28), loc=base + Vector((.1 * s_, -.16, .25)), rot=(0, 20 * s_, 0), col="bubblegum", seg=10, ring=6))
        # whiskers
        for k in (-1, 0, 1):
            a0 = hc + Vector((.32 * s_, -1.0, -.28 + .06 * k))
            P.append(tube(f"wh{s_}{k}", [a0, a0 + Vector((.35 * s_, -.02, .04 * k)), a0 + Vector((.7 * s_, .06, .1 * k))], radius=.018, col="ink", seg=5))
    # paws
    P.append(sphere("pawL", (.3, .3, .22), loc=(-.42, -.72, .2), col="cat_cream", seg=14, ring=8))
    P += limb("armR", (.7, -.3, 1.25), (1.32, -.42, 1.95), .26, .22, 3, ["cat_orange", "cat_cream", "cat_orange"], seed=70)
    P.append(sphere("pawR", (.27, .22, .27), loc=(1.38, -.45, 2.05), col="cat_cream", seg=14, ring=8))
    P.append(sphere("pawLb", (.3, .3, .22), loc=(.42, -.72, .2), col="cat_cream", seg=14, ring=8))
    P += limb("armL", (-.62, -.4, 1.2), (-.48, -.72, .45), .25, .22, 3, ["cat_orange", "cat_cream", "cat_orange"], seed=71)
    # curly tail
    tp = [(.5, .6, .3), (1.15, .85, .4), (1.5, .75, .95), (1.4, .6, 1.5), (1.05, .55, 1.72), (.9, .55, 1.5)]
    P += striped_tube("tail", tp, .2, ["cat_orange", "cat_cream", "cat_orange", "cat_cream", "cat_orange", "fiesta_pink"], seg=12, taper=lambda t: 1 - .35 * t)
    # collar + bell
    P.append(torus("collar", 0.86, .09, loc=hc + Vector((0, .02, -.92)), col="chili", seg=28, mseg=8))
    P.append(sphere("bell", (.15, .15, .15), loc=hc + Vector((0, -.86, -1.0)), col="gold", seg=12, ring=8))
    P += face(head, "f", hc + Vector((0, 0, .05)), size=.27, eye_dx=.42, eye_dz=.12, style="smug", mouth=None,
              blush_dx=.72, blush_dz=-.15, look=(0, 0))
    # "w" mouth
    base = hc + Vector((0, -1.12, -.38))
    for s_ in (-1, 1):
        pts = [base + Vector((0, 0, .02)), base + Vector((.08 * s_, -.01, -.06)), base + Vector((.17 * s_, 0, -.01))]
        P.append(tube(f"wm{s_}", pts, radius=.03, col="ink", seg=6))
    return P, {"glow": []}

def cohetin():
    """RARE - rocket piñata with a porthole face, swept fins it stands on, nose cone and a neon flame."""
    P = []; G = []
    H = 2.55; z0 = .55
    prof = lambda z: .8 * (max(0.0, 1 - ((z - .9) / 1.75) ** 2) ** .5 if z > .9 else (.86 + .14 * min(1, z / .9)))
    body = fringe_body("body", prof, H, 8, ["snow", "chili", "snow", "sky", "snow", "chili", "snow", "sun_yellow"],
                       matrix=M((0, 0, z0)), seg=30, flare=.09, tooth=.06, seed=8, z_to=H * .93)
    P += body
    # smooth nose cone + tip
    P.append(cyl("nose", .62, .05, 1.05, loc=(0, 0, z0 + H * .78), col="chili", seg=24, bevel=.04))
    P.append(torus("noseband", .6, .07, loc=(0, 0, z0 + H * .8), col="sun_yellow", seg=28, mseg=6))
    P.append(sphere("nosetip", (.15, .15, .15), loc=(0, 0, z0 + H * .78 + 1.05), col="sun_yellow", seg=12, ring=8))
    # swept fins (it stands on them)
    fin2d = [(.45, 1.8), (.6, 1.75), (1.35, .55), (1.45, .05), (1.1, 0.0), (.55, .45)]
    for k in range(3):
        a = math.radians(90 + 120 * k + 30)
        mtx = Matrix.Rotation(a, 4, 'Z') @ Matrix.Rotation(math.radians(90), 4, 'X')
        P.append(slab(f"fin{k}", fin2d, thick=.2, col="rocket_fin", bevel=.07, bseg=3, matrix=mtx))
        d = Vector((math.cos(a), math.sin(a), 0))
        P.append(sphere(f"finball{k}", (.17, .17, .17), loc=d * 1.32 + Vector((0, 0, .14)), col="sun_yellow", seg=12, ring=8))
    pc = Vector((0, -.84, 2.05))
    P.append(torus("port", .52, .1, loc=pc + Vector((0, -.04, 0)), rot=(90, 0, 0), col="silver", seg=28, mseg=8))
    win = sphere("window", (.5, .16, .5), loc=pc + Vector((0, .02, 0)), col="glass", seg=20, ring=10); P.append(win)
    for k in range(6):
        a = 2 * math.pi * k / 6
        P.append(sphere(f"bolt{k}", (.05, .05, .05), loc=pc + Vector((.52 * math.cos(a), -.15, .52 * math.sin(a))), col="steel", seg=8, ring=5))
    P += face([win], "f", pc, size=.17, eye_dx=.19, eye_dz=.08, style="round", mouth="open", mouth_dz=-.18, mw=.22, blush_dx=0, look=(0, .1))
    P.append(cyl("nozzle", .4, .55, .35, loc=(0, 0, .3), col="steel", seg=18, bevel=.04))
    G.append(sphere("flame1", (.36, .36, .5), loc=(0, 0, .2), col="neon_gold", seg=14, ring=8))
    G.append(sphere("flame2", (.22, .22, .32), loc=(0, 0, .1), col="tangerine", seg=12, ring=6))
    for k, (a, z) in enumerate([(205, 1.25), (320, 2.75), (140, 2.6)]):
        r = prof(z - z0) * 1.03; aa = math.radians(a)
        st = star_prism(f"star{k}", 5, .2, .09, .06, loc=(r * math.cos(aa), r * math.sin(aa), z), col="sun_yellow")
        st.rotation_mode = 'QUATERNION'; st.rotation_quaternion = Vector((math.cos(aa), math.sin(aa), 0)).to_track_quat('Z', 'Y')
        P.append(st)
    return P + G, {"glow": G}

def dragon():
    """EPIC - 'Dragón Chile': chili-red dragon, jade wings, fierce-cute eyes, little fangs."""
    P = []; G = []
    body = fringe_body("body", ellip_prof(.95, 2.1, p=.7), 2.1, 7, ["chili", "chili", "mango", "chili", "red_dark", "chili", "chili"],
                       matrix=M((0, .15, .15), (0, .15, 1)), seg=30, flare=.1, tooth=.07, seed=9)
    P += body
    belly = sphere("belly", (.62, .3, .78), loc=(0, -.68, 1.05), col="mango", seg=16, ring=10); P.append(belly)
    hc = Vector((0, -.25, 2.75))
    head = fringe_body("head", ellip_prof(.95, 1.6, p=.85), 1.6, 5, ["chili", "chili", "red_dark", "chili", "chili"],
                       matrix=M(hc - Vector((0, 0, .75))), seg=30, flare=.09, tooth=.06, seed=10, sx=1.1)
    P += head
    sn = sphere("snout", (.6, .5, .38), loc=hc + Vector((0, -.78, -.28)), col="chili", seg=18, ring=10); P.append(sn)
    for s_ in (-1, 1):
        P.append(sphere(f"nost{s_}", (.07, .05, .05), loc=hc + Vector((.2 * s_, -1.26, -.18)), col="red_dark", seg=8, ring=5))
        # horns = chili stems (green, curved)
        b0 = hc + Vector((.45 * s_, .05, .62))
        P.append(tube(f"horn{s_}", [b0, b0 + Vector((.12 * s_, .1, .35)), b0 + Vector((.32 * s_, .3, .6)), b0 + Vector((.55 * s_, .55, .62))],
                      radius=.13, taper=[1, .85, .6, .25], col="jade", seg=10))
        # fangs
        P.append(cyl(f"fang{s_}", .055, .005, -.16, loc=hc + Vector((.2 * s_, -1.12, -.5)), col="eye_white", seg=8))
        # wings: arm bones + membrane fan of ribbons
        # wing membrane: scalloped fan in a plane tilted back
        w2d = [(0, 0), (.35, .55), (.9, 1.05), (1.55, 1.35), (1.45, .95), (1.25, .55), (1.0, .55), (.85, .15), (.6, .1), (.45, -.25)]
        if s_ < 0: w2d = [(-x, y) for x, y in reversed(w2d)]
        mtx = Matrix.Translation((.55 * s_, .7, 1.85)) @ Matrix.Rotation(math.radians(-25 * s_), 4, 'Z') @ Matrix.Rotation(math.radians(70), 4, 'X')
        P.append(slab(f"wing{s_}", w2d, thick=.07, col="jade", bevel=.025, matrix=mtx))
        bone = [Vector((0, 0, .06)), Vector((.4 * s_, .58, .06)), Vector((.9 * s_, 1.05, .06)), Vector((1.55 * s_, 1.35, .06))]
        P.append(tube(f"wbone{s_}", [mtx @ b for b in bone], radius=.07, taper=[1.2, 1, .8, .5], col="dark_green", seg=8))
        for (fx, fy) in ((1.25, .55), (.85, .15)):
            P.append(tube(f"wrib{s_}{fx}", [mtx @ Vector((.4 * s_, .58, .05)), mtx @ Vector((fx * s_, fy, .05))], radius=.04, col="dark_green", seg=6))
        P.append(sphere(f"wclaw{s_}", (.09, .09, .09), loc=mtx @ Vector((1.55 * s_, 1.35, .06)), col="cream", seg=8, ring=6))
        # feet
        P.append(sphere(f"foot{s_}", (.33, .42, .2), loc=(.45 * s_, -.3, .18), col="chili", seg=14, ring=8))
        for c in (-1, 0, 1):
            P.append(cyl(f"claw{s_}{c}", .06, .005, .14, loc=(.45 * s_ + .13 * c, -.7, .12), rot=(-80, 0, 0), col="cream", seg=6))
        # arms
        P += limb(f"arm{s_}", (.75 * s_, -.3, 1.6), (.7 * s_, -.85, 1.25), .2, .18, 2, ["chili", "mango"], seed=90 + s_)
    # tail with spikes
    tp = [(0, .9, .5), (.4, 1.6, .35), (1.0, 1.9, .5), (1.45, 1.75, .85)]
    P += chain("tail", tp, [.4, .3, .2, .12], 2, ["chili", "red_dark", "chili", "mango"], seed=95)
    P.append(star_prism("tailtip", 3, .32, .16, .1, loc=(1.55, 1.7, 1.0), rot=(90, 0, 30), col="jade"))
    # back spikes
    for k in range(4):
        z = 2.1 - .42 * k
        P.append(cyl(f"spike{k}", .16, .01, .32, loc=(0, .95 - .05 * k, z), rot=(-75, 0, 0), col="jade", seg=8))
    P += face(head, "f", hc + Vector((0, 0, .12)), size=.27, eye_dx=.42, eye_dz=.12, style="fierce", iris="mango", mouth=None,
              blush_dx=0, look=(0, 0), lid="red_dark", lid_roll=-22)
    P += smile("f_mouth", [sn], hc + Vector((0, -6, -.42)), (0, 1, 0), width=.55, height=.1, r=.035)
    return P + G, {"glow": G}

def toro():
    """LEGENDARY - 'Toro de Oro': chunky golden bull with crown, big horns and nose ring."""
    P = []; G = []
    gc = ["gold", "gold_deep", "gold", "gold_pale", "gold", "gold_deep", "gold", "gold_pale"]
    body = fringe_body("body", ellip_prof(1.15, 2.6, p=.5), 2.6, 9, gc, matrix=M((0, 1.45, 1.75), (0, -1, 0)),
                       seg=32, flare=.09, tooth=.07, seed=11, sx=1.05, sy=1.0)
    P += body
    for i, (x, y) in enumerate([(-.62, -.55), (.62, -.55), (-.62, .85), (.62, .85)]):
        P += limb(f"leg{i}", (x, y, 1.35), (x, y, .12), .34, .32, 4, ["gold_deep", "gold", "gold_pale", "gold"], seed=100 + i, round_end=.05)
        P.append(cyl(f"hoof{i}", .36, .34, .22, loc=(x, y, 0), col="chocolate", seg=14, bevel=.07))
    hc = Vector((0, -1.35, 2.45))
    head = fringe_body("head", ellip_prof(.95, 1.55, p=1.0), 1.55, 5, ["gold", "gold_deep", "gold", "gold_pale", "gold"],
                       matrix=M(hc - Vector((0, -.15, .75)), (0, -.25, 1)), seg=30, flare=.08, tooth=.06, seed=12, sx=1.15)
    P += head
    mz = sphere("muzzle", (.72, .45, .45), loc=hc + Vector((0, -.78, -.45)), col="gold_pale", seg=18, ring=10); P.append(mz)
    for s_ in (-1, 1):
        P.append(sphere(f"nost{s_}", (.1, .06, .08), loc=hc + Vector((.28 * s_, -1.2, -.4)), col="gold_deep", seg=8, ring=5))
        b0 = hc + Vector((.75 * s_, -.05, .5))
        P.append(tube(f"horn{s_}", [b0, b0 + Vector((.45 * s_, 0, .1)), b0 + Vector((.85 * s_, -.05, .45)), b0 + Vector((.95 * s_, -.1, .95))],
                      radius=.2, taper=[1, .85, .6, .2], col="snow", seg=12))
        P.append(torus(f"hornband{s_}", .2, .06, loc=b0 + Vector((.3 * s_, 0, .05)), rot=(0, 90, 0), col="gold_deep", seg=16, mseg=6))
        # ears
        P.append(sphere(f"ear{s_}", (.32, .1, .18), loc=hc + Vector((1.0 * s_, .05, .1)), rot=(0, -25 * s_, 0), col="gold_deep", seg=12, ring=6))
    # chest medallion (hides the fringe pole + legendary bling)
    P.append(tube("medalcord", [(-.75, -1.05, 1.95), (-.4, -1.45, 1.45), (0, -1.6, 1.2), (.4, -1.45, 1.45), (.75, -1.05, 1.95)], radius=.05, col="chili", seg=6))
    P.append(cyl("medal", .38, .38, .12, loc=(0, -1.62, 1.12), rot=(90, 0, 0), col="gold_deep", seg=24, bevel=.04))
    P.append(star_prism("medalstar", 5, .28, .12, .1, loc=(0, -1.76, 1.12), rot=(90, 0, 0), col="gold_pale"))
    P.append(torus("ring", .2, .045, loc=hc + Vector((0, -1.28, -.58)), rot=(90, 0, 0), col="silver", seg=20, mseg=6))
    # crown
    cz = hc.z + .72
    P.append(cyl("crownbase", .52, .58, .3, loc=(0, hc.y + .05, cz), col="gold", seg=20, bevel=.03))
    for k in range(5):
        a = 2 * math.pi * k / 5 + math.pi / 2
        pt = Vector((.5 * math.cos(a), hc.y + .05 + .5 * math.sin(a), cz + .28))
        P.append(cyl(f"crownpt{k}", .14, .01, .4, loc=pt, col="gold", seg=8))
        G.append(sphere(f"gem{k}", (.07, .07, .07), loc=pt + Vector((0, 0, .42)), col="neon_pink" if k % 2 else "neon_cyan", seg=8, ring=6))
    G.append(sphere("crowngem", (.12, .08, .12), loc=(0, hc.y - .5, cz + .15), col="neon_pink", seg=10, ring=6))
    # tail
    P += tassels("tail", (0, 2.65, 1.9), (0, 1, -.3), n=5, length=.95, width=.13, colors=("gold", "gold_deep", "gold_pale"), seed=13, spread=.25)
    P.append(sphere("tailpom", (.28, .28, .28), loc=(0, 2.62, 1.85), col="gold_deep", seg=12, ring=8))
    P += face(head, "f", hc + Vector((0, 0, .15)), size=.26, eye_dx=.42, eye_dz=.1, style="fierce", mouth=None,
              blush_dx=0, lid="gold_deep", lid_roll=-14)
    P += smile("f_mouth", [mz], hc + Vector((.0, -6, -.66)), (0, 1, 0), width=.5, height=.1, r=.035)
    return P + G, {"glow": G}

def renito():
    """EVENT (Navidad) - 'Renito': chubby reindeer piñata with Santa hat, scarf, glowing nose and a candy cane."""
    P = []; G = []
    body = fringe_body("body", ellip_prof(.95, 2.0, p=.8), 2.0, 6, ["brown", "cream", "xmas_red", "brown", "xmas_green", "brown"],
                       matrix=M((0, .05, .05)), seg=30, flare=.1, tooth=.07, seed=14, sy=.92)
    P += body
    hc = Vector((0, -.1, 2.6))
    head = fringe_body("head", ellip_prof(.92, 1.65, p=1.15), 1.65, 5, ["brown", "brown", "cream", "brown", "brown"],
                       matrix=M(hc - Vector((0, 0, .8))), seg=30, flare=.09, tooth=.065, seed=15, sx=1.08, sy=.95)
    P += head
    mz = sphere("muzzle", (.45, .32, .3), loc=hc + Vector((0, -.8, -.35)), col="cream", seg=16, ring=10); P.append(mz)
    G.append(sphere("nose", (.2, .17, .17), loc=hc + Vector((0, -1.1, -.22)), col="candy_red", seg=14, ring=8))
    for s_ in (-1, 1):
        # antlers
        b0 = hc + Vector((.42 * s_, .05, .72))
        main = [b0, b0 + Vector((.2 * s_, 0, .45)), b0 + Vector((.5 * s_, .05, .8)), b0 + Vector((.6 * s_, .1, 1.15))]
        P.append(tube(f"ant{s_}", main, radius=.09, taper=[1.1, 1, .8, .55], col="wood_dark", seg=8))
        for (a, b) in (((.2, 0, .45), (.5, -.05, .62)), ((.5, .05, .8), (.85, 0, .9)), ((.5, .05, .8), (.35, .05, 1.15))):
            P.append(tube(f"antb{s_}{a[2]}{b[0]}", [b0 + Vector((a[0] * s_, a[1], a[2])), b0 + Vector((b[0] * s_, b[1], b[2]))], radius=.065, taper=[1, .6], col="wood_dark", seg=7))
        P.append(sphere(f"ear{s_}", (.3, .09, .16), loc=hc + Vector((.92 * s_, .05, .15)), rot=(0, -30 * s_, 0), col="brown", seg=12, ring=6))
        P.append(sphere(f"hoofF{s_}", (.3, .32, .22), loc=(.42 * s_, -.7, .2), col="chocolate", seg=14, ring=8))
    # santa hat (tilted)
    hat_m = Matrix.Translation(hc + Vector((-.15, .05, .55))) @ Matrix.Rotation(math.radians(-18), 4, 'Y')
    hat = cyl("hat", .72, .08, 1.15, col="xmas_red", seg=22, bevel=.04); hat.data.transform(hat_m)
    # bend the hat tip sideways
    for v in hat.data.vertices:
        lz = (v.co.z - (hc.z + .55)); 
        if lz > .4: v.co.x += -.35 * ((lz - .4) / .8) ** 2
    P.append(hat)
    P.append(torus("hatrim", .7, .16, col="snow", seg=26, mseg=8)); P[-1].data.transform(hat_m)
    P.append(sphere("hatpom", (.2, .2, .2), loc=hc + Vector((-.85, .05, 1.55)), col="snow", seg=12, ring=8))
    # scarf
    P.append(torus("scarf", .9, .14, loc=hc + Vector((0, .02, -.85)), col="xmas_green", seg=28, mseg=8))
    P.append(ribbon("scarftail", [hc + Vector((.45, -.8, -.9)), hc + Vector((.55, -.95, -1.3)), hc + Vector((.5, -.92, -1.65))], width=.3, normal=(0, -1, 0), col="xmas_green", thick=.08))
    for k in range(3):
        P.append(box(f"scarfstripe{k}", (.32, .1, .06), loc=hc + Vector((.52, -.97, -1.15 - .18 * k)), col="xmas_red", bevel=.02))
    # arm holding candy cane
    P += limb("arm", (.7, -.3, 1.3), (.95, -.75, 1.0), .24, .21, 2, ["brown", "cream"], seed=150)
    P.append(sphere("hand", (.24, .22, .22), loc=(1.0, -.8, 1.0), col="chocolate", seg=12, ring=8))
    cane = [(1.0, -.85, .1), (1.0, -.85, 1.0), (1.0, -.85, 1.85), (.9, -.85, 2.15), (.65, -.85, 2.2), (.48, -.85, 2.0)]
    P += striped_tube("cane", cane, .085, ["candy_red", "snow"] * 6, seg=10)
    P += limb("arm2", (-.7, -.3, 1.25), (-.55, -.68, .7), .23, .2, 2, ["brown", "cream"], seed=151)
    P.append(sphere("hand2", (.22, .2, .2), loc=(-.53, -.72, .62), col="chocolate", seg=12, ring=8))
    P += face(head, "f", hc + Vector((0, 0, .1)), size=.25, eye_dx=.38, eye_dz=.12, style="round", mouth=None,
              blush_dx=.66, blush_dz=-.15)
    P += smile("f_mouth", [mz], hc + Vector((0, -6, -.5)), (0, 1, 0), width=.34, height=.09, r=.03, open_mouth=True)
    return P + G, {"glow": G}

def torogoz():
    """MYTHIC - 'Torogoz Cósmico': galaxy bird inspired by El Salvador's national bird (racket tail), on a cloud."""
    P = []; G = []
    # cloud pedestal
    for k, (x, y, z, r) in enumerate([(0, 0, .35, .7), (.75, .1, .3, .55), (-.75, .05, .3, .55), (.35, -.45, .25, .5), (-.4, -.45, .25, .5), (0, .55, .28, .55)]):
        P.append(sphere(f"cloud{k}", (r * 1.2, r, r * .75), loc=(x, y, z), col="lavender" if k % 2 else "white", seg=16, ring=10))
    bc = ["cosmic_2", "torogoz_t", "torogoz_r", "cosmic_2", "cosmic_3", "cosmic_1"]
    body = fringe_body("body", ellip_prof(.85, 2.1, p=.8), 2.1, 6, bc, matrix=M((0, .15, .55), (0, .25, 1)),
                       seg=30, flare=.1, tooth=.07, seed=16, sy=.95)
    P += body
    hc = Vector((0, -.05, 2.85))
    head = fringe_body("head", ellip_prof(.8, 1.45, p=1.45), 1.45, 4, ["torogoz_t", "cosmic_2", "torogoz_t", "cosmic_2"],
                       matrix=M(hc - Vector((0, 0, .7))), seg=28, flare=.09, tooth=.06, seed=17, sx=1.0, sy=1.0)
    P += head
    # beak
    beak = cyl("beak", .2, .01, .75, col="ink", seg=12); beak.data.transform(M(hc + Vector((0, -.65, -.12)), (0, -1, -.15))); P.append(beak)
    # black mask + glowing turquoise brow
    for s_ in (-1, 1):
        P.append(ribbon(f"mask{s_}", [hc + Vector((.15 * s_, -.72, 0)), hc + Vector((.5 * s_, -.55, .02)), hc + Vector((.75 * s_, -.1, .0))], width=.22, normal=(0, -1, .1), col="ink", thick=.06))
        G.append(ribbon(f"brow{s_}", [hc + Vector((.18 * s_, -.72, .3)), hc + Vector((.5 * s_, -.6, .38)), hc + Vector((.78 * s_, -.15, .3))], width=.1, normal=(0, -1, .3), col="neon_cyan", thick=.05))
        # folded wings
        w2d = [(-.25, .1), (.25, .25), (.65, -.15), (.75, -.8), (.6, -1.5), (.25, -1.1), (-.1, -.55)]
        mtx = Matrix.Translation((.8 * s_, -.05, 2.5)) @ Matrix.Rotation(math.radians(-12 * s_), 4, 'Y') @ Matrix.Rotation(math.radians(90), 4, 'Z') @ Matrix.Rotation(math.radians(90), 4, 'X')
        w2d = [(x * .8, y * .8) for x, y in w2d]
        P.append(slab(f"wing{s_}", w2d, thick=.14, col="cobalt", bevel=.05, matrix=mtx))
        w2 = [(x * .7 + .05, y * .55 - .05) for x, y in w2d]
        P.append(slab(f"wing2{s_}", w2, thick=.2, col="torogoz_t", bevel=.04, matrix=mtx))
        P.append(sphere(f"foot{s_}", (.18, .25, .1), loc=(.3 * s_, -.35, .72), col="tangerine", seg=10, ring=6))
    # racket tail: two long shafts + glowing racket tips
    for s_ in (-1, 1):
        a = Vector((.1 * s_, .8, 1.4)); b = Vector((.5 * s_, 1.5, 1.35)); c = Vector((.95 * s_, 2.05, 1.0))
        P.append(tube(f"shaft{s_}", [a, (a + b) / 2 + Vector((0, 0, -.1)), b, c], radius=.045, col="cosmic_1", seg=6))
        rk = slab(f"racket{s_}", [(0, -.08), (.33, .38), (.3, .9), (0, 1.08), (-.3, .9), (-.33, .38)], thick=.06, col="neon_cyan" if s_ < 0 else "neon_pink", bevel=.02,
                  matrix=Matrix.Translation(c) @ Matrix.Rotation(math.radians(-40 * s_), 4, 'Z') @ Matrix.Rotation(math.radians(70), 4, 'X') @ Matrix.Rotation(math.radians(180 + 30 * s_), 4, 'Z'))
        G.append(rk)
    # floating stars attached to cloud by thin "sparkle" stems
    for k, (x, y, z) in enumerate([(-1.05, -.2, 1.6), (1.1, -.1, 2.1), (.9, .4, 3.4)]):
        G.append(star_prism(f"spark{k}", 4, .2, .07, .06, loc=(x, y, z), rot=(90, 0, 15 * k), col="neon_gold", bevel=.02))
    P += face(head, "f", hc + Vector((0, 0, .1)), size=.22, eye_dx=.33, eye_dz=.05, style="round", iris="cosmic_4", mouth=None,
              blush_dx=.55, blush_dz=-.2)
    return P + G, {"glow": G}

def sombra():
    """SECRET - 'Sombra': shadow urchin-star piñata, one giant eye, neon tips."""
    P = []; G = []; R = .95; cz = 1.75
    body = fringe_body("body", ellip_prof(R, 2 * R), 2 * R, 7, ["cosmic_1", "ink_soft", "cosmic_1", "ink", "cosmic_1", "ink_soft", "cosmic_1"],
                       matrix=M((0, 0, cz - R)), seg=32, flare=.12, tooth=.08, seed=18)
    P += body
    import random as _r
    rnd = _r.Random(5)
    dirs = []
    # fibonacci sphere spikes, skip the face area
    N = 16
    for i in range(N):
        y = 1 - 2 * (i + .5) / N; r = math.sqrt(1 - y * y); th = math.pi * (3 - math.sqrt(5)) * i
        d = Vector((r * math.cos(th), r * math.sin(th), y))
        if d.y < -.55 and abs(d.z) < .6: continue
        dirs.append(d)
    for i, d in enumerate(dirs):
        H = .95 if d.z > -.6 else .75
        base = Vector((0, 0, cz)) + d * R * .55
        P += fringe_body(f"sp{i}", cone_prof(.32, H), H, 3, ["cosmic_1", "cosmic_2", "ink_soft"], matrix=M(base, d, roll=i * 23), seg=14, flare=.14, tooth=.06, seed=200 + i)
        G.append(sphere(f"tip{i}", (.09, .09, .09), loc=base + d * (H - .02), col="neon_pink" if i % 2 else "neon_cyan", seg=8, ring=6))
    # cyclops eye
    hit = surface_hit(body, (0, -8, cz + .18), (0, 1, 0))
    p, n = hit[0], Vector((0, -1, .1)).normalized()
    w = sphere("eyewhite", (.62, .62, .3), col="eye_white", seg=20, ring=10); w.location = p + n * .05; orient_to(w, n); P.append(w)
    ir = sphere("iris", (.38, .38, .2), col="neon_pink", seg=16, ring=8); ir.location = p + n * .2; orient_to(ir, n); G.append(ir)
    pu = sphere("pupil", (.12, .3, .12), col="ink", seg=12, ring=6); pu.location = p + n * .3; orient_to(pu, n); P.append(pu)
    hl = sphere("hl", (.1, .1, .05), col="eye_white", seg=8, ring=5); hl.location = p + n * .34 + Vector((-.12, 0, .14)); orient_to(hl, n); P.append(hl)
    # toothy grin
    gp = surface_hit(body, (0, -8, cz - .5), (0, 1, 0))[0]
    mouth = []
    for k in range(9):
        u = -1 + 2 * k / 8
        mouth.append(gp + Vector((u * .55, -.05, -(1 - u * u) * .2 + .12)))
    P.append(tube("grin", mouth, radius=.05, col="neon_pink", seg=6)); G.append(P.pop())
    for k in range(4):
        u = -.6 + .4 * k
        t = cyl(f"tooth{k}", .07, .01, -.14, loc=gp + Vector((u * .55, -.08, -(1 - u * u) * .2 + .12)), col="eye_white", seg=6); P.append(t)
    return P + G, {"glow": G}

CREATURES = {"estrellita": estrellita, "burrito": burrito, "michi": michi, "cohetin": cohetin, "dragon": dragon, "toro": toro, "renito": renito, "torogoz": torogoz, "sombra": sombra}

RARBG = {"common": ("#23A6FF", "#8FD8FF"), "uncommon": ("#2FCB6B", "#A8F5B8"), "rare": ("#2A6BFF", "#7FB2FF"),
         "epic": ("#8A3CF0", "#D2A8FF"), "legendary": ("#B8320B", "#FF8A3D"), "mythic": ("#C2187A", "#FF8FD8"),
         "secret": ("#1B1430", "#5B3F8F"), "event": ("#D7192F", "#FF9AA6")}
RARITY = {"estrellita": "common", "burrito": "common", "michi": "uncommon", "cohetin": "rare", "dragon": "epic", "toro": "legendary", "renito": "event", "torogoz": "mythic", "sombra": "secret"}
CAM = {"burrito": (-5, 12), "toro": (-35, 13), "torogoz": (32, 12)}

def build(name, out_render=True, samples=64, res=(1100, 1100), bg=("#23A6FF", "#8FD8FF")):
    reset(); write_palette_textures()
    parts, extra = CREATURES[name]()
    glow = extra.get("glow", [])
    main = [p for p in parts if p not in glow]
    body = join(main, name)
    objs = [body]
    if glow:
        g = join(glow, name + "_Neon"); objs.append(g)
    size = base_origin(objs)
    mat = material_palette(); 
    for o in objs:
        assign_mat(o, mat if not o.name.endswith("_Neon") else material_palette("M_Neon", emissive=1.6)); smooth(o, 50)
    info = export(objs, name, "creatures")
    bpy.ops.wm.save_as_mainfile(filepath=f"{BLEND}/{name}.blend")
    meta = {"name": name, "size_studs": [round(size.x, 2), round(size.z, 2), round(size.y, 2)], "tris": info}
    print("META", json.dumps(meta))
    if out_render:
        bg = RARBG[RARITY.get(name, "common")]
        setup_render(res, samples); backdrop(*bg, rot_z=CAM.get(name,(28,14))[0]); lights(scale=max(1.0, size.z / 3.2), center=(0, 0, size.z * .5))
        camera_fit(objs, az=CAM.get(name,(28,14))[0], el=CAM.get(name,(28,14))[1], lens=60, margin=0.86)
        render(f"{REND}/{name}.png")
    return meta

if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    metas = []
    for n in (argv or list(CREATURES)):
        metas.append(build(n))
    os.makedirs(f"{ROOT}/export/creatures", exist_ok=True)
    mf = f"{ROOT}/export/creatures/_meta.json"
    old = json.load(open(mf)) if os.path.exists(mf) else {}
    for m in metas: old[m["name"]] = m
    json.dump(old, open(mf, "w"), indent=1)
