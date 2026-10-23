"""Colección LatAm, parte 3: Legendarias, Míticas y Secretas (Costa Rica, Panamá, Argentina, Guatemala, Colombia, Brasil, México)."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from latam_lib import *

def wheel_mandala(name, c, axis, R=1.0, base="chili", cols=("sun_yellow", "eye_white", "cobalt", "lime")):
    """Painted Costa Rican carreta wheel: wooden rim + steel band + concentric star/petal pattern on the outer face."""
    ax = Vector(axis).normalized(); c = Vector(c); P = []
    d = cyl(name + "d", R * .92, R * .92, .2, col=base, seg=40, bevel=.03); d.matrix_world = M(c - ax * .1, ax); P.append(d)
    P.append(torus(name + "rim", R * .95, .1, col="wood_dark", seg=40, mseg=8)); P[-1].matrix_world = M(c, ax)
    P.append(torus(name + "band", R * 1.0, .06, col="steel", seg=40, mseg=6)); P[-1].matrix_world = M(c, ax)
    face = c + ax * .11
    fm = M(face, ax)
    sp = star_prism(name + "star", 12, R * .82, R * .5, .04, col=cols[0], bevel=0); sp.matrix_world = fm; P.append(sp)
    ring = torus(name + "r2", R * .5, .035, col=cols[1], seg=32, mseg=4); ring.matrix_world = M(face + ax * .02, ax); P.append(ring)
    s2 = star_prism(name + "star2", 8, R * .42, R * .2, .05, col=cols[2], bevel=0); s2.matrix_world = M(face + ax * .015, ax); P.append(s2)
    for k in range(12):
        a = 2 * math.pi * (k + .5) / 12
        q = (fm @ V(R * .7 * math.cos(a), R * .7 * math.sin(a), .03))
        P.append(sphere(f"{name}dot{k}", (R * .06,) * 3, loc=q, col=cols[3], seg=8, ring=5))
    hub = cyl(name + "hub", R * .16, R * .14, .4, col="wood_dark", seg=16, bevel=.03); hub.matrix_world = M(c - ax * .1, ax); P.append(hub)
    P.append(sphere(name + "hubc", (R * .1,) * 3, loc=c + ax * .3, col="gold", seg=10, ring=6))
    return P

# ============================================================================= 13. CARRETICA PURA VIDA (legendary, Costa Rica)
def carretica_pura_vida():
    """LEGENDARY - the painted Costa Rican oxcart IS the character: face on the front board, mandala wheels, coffee sacks + flowers on board.
    Joke: 'no tiene prisa: todo es pura vida'."""
    P = []; G = []
    bw, bl, bz, bh = 1.7, 2.3, 1.15, 1.05   # bed width (x), length (y), bottom z, height
    # bed: floor + 4 painted boards
    P.append(box("floor", (bw, bl, .14), loc=(0, 0, bz), col="wood_dark", bevel=.04))
    P.append(box("front", (bw, .14, bh), loc=(0, -bl / 2, bz + bh / 2), col="chili", bevel=.05))
    P.append(box("back", (bw, .14, bh), loc=(0, bl / 2, bz + bh / 2), col="chili", bevel=.05))
    for s_ in (-1, 1):
        P.append(box(f"side{s_}", (.14, bl, bh), loc=(s_ * bw / 2, 0, bz + bh / 2), col="chili", bevel=.05))
        # painted geometric band on the side: triangles + trim
        for k in range(9):
            y = -bl / 2 + .2 + (bl - .4) * k / 8
            tri = slab(f"stri{s_}{k}", [(-.14, 0), (.14, 0), (0, .24 if k % 2 == 0 else -.24)], thick=.03, col="sun_yellow" if k % 2 == 0 else "cobalt", bevel=0)
            tri.matrix_world = Matrix.Translation((s_ * (bw / 2 + .075), y, bz + .3 + (0 if k % 2 == 0 else .24))) @ Matrix.Rotation(math.radians(90 * s_), 4, 'Z') @ Matrix.Rotation(math.radians(90), 4, 'X')
            P.append(tri)
        P.append(box(f"strim{s_}", (.03, bl - .1, .06), loc=(s_ * (bw / 2 + .075), 0, bz + .82), col="eye_white", bevel=0))
    # rails on top of the boards
    for s_ in (-1, 1):
        P.append(box(f"rail{s_}", (.18, bl + .1, .12), loc=(s_ * bw / 2, 0, bz + bh + .04), col="sun_yellow", bevel=.04))
    for s_ in (-1, 1):
        P.append(box(f"railf{s_}", (bw + .1, .18, .12), loc=(0, s_ * bl / 2, bz + bh + .04), col="sun_yellow", bevel=.04))
    # PURA VIDA on the right side board
    sgz = bz + bh + 1.0
    for x in (-.75, .75):
        P.append(cyl(f"sgp{x}", .04, .04, 1.0, loc=(x, .95, bz + bh), col="wood_dark", seg=8))
    P.append(box("sgn", (1.75, .08, .42), loc=(0, .95, sgz), col="sun_yellow", bevel=.05))
    P.append(box("sgnb", (1.85, .06, .5), loc=(0, .99, sgz), col="chili", bevel=.04))
    t = text_mesh("txt", "PURA VIDA", size=.3, extrude=.03, col="chili", bevel=0, res=3)
    t.matrix_world = Matrix.Translation((0, .9, sgz)) @ Matrix.Rotation(math.radians(90), 4, 'X'); P.append(t)
    # paper fringe garlands along the top rails (piñata DNA)
    for s_ in (-1, 1):
        P.append(fringe_strip(f"frs{s_}a", (s_ * (bw / 2 + .1), -bl / 2, bz + bh - .02), (s_ * (bw / 2 + .1), bl / 2, bz + bh - .02), h=.22, col="sun_yellow" if s_ > 0 else "fiesta_pink"))
    P.append(fringe_strip("frf", (-bw / 2, -bl / 2 - .09, bz + bh - .02), (bw / 2, -bl / 2 - .09, bz + bh - .02), h=.2, col="sun_yellow"))
    # face on the front board
    ft = bvh_of([P[1]])
    hc = V(0, -bl / 2, bz + bh / 2 + .05)
    P += eyes2("e", ft, hc + V(0, 0, .12), dx=.38, dz=0, size=.25, iris="chocolate", lid="red_dark", open_=.5, tilt=4, lash=True,
               brow=True, brow_h=1.5, brow_tilt=10, brow_col="ink", look=(.2, .1))
    P += mouth2("m", ft, hc + V(0, -3, -.28), w=.46, h=.16, smile=1.6, col="ink", tongue=True)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", ft, hc + V(.62 * s_, -3, -.12), size=.1)
    # wheels (big, painted)
    for s_ in (-1, 1):
        P += wheel_mandala(f"wh{s_}", V(s_ * (bw / 2 + .32), .1, 1.0), V(s_, 0, 0), R=1.0,
                           cols=("sun_yellow", "eye_white", "cobalt", "lime") if s_ > 0 else ("sun_yellow", "eye_white", "jade", "fiesta_pink"))
    P.append(cyl("axle", .1, .1, bw + .5, col="wood_dark", seg=12)); P[-1].matrix_world = M(V(-(bw + .5) / 2, .1, 1.0), (1, 0, 0))
    # tongue (pole) to the front resting on a stone, little yoke
    pa = V(0, -bl / 2 + .3, bz - .02); pb_ = V(0, -bl / 2 - 1.05, .3)
    P.append(cyl("pole", .09, .08, (pb_ - pa).length + .05, col="wood", seg=10, bevel=.02)); P[-1].matrix_world = M(pa, pb_ - pa)
    P.append(sphere("stone", (.28, .24, .16), loc=pb_ + V(0, 0, -.22), col="stone_dark", seg=12, ring=8))
    yk = box("yoke", (1.1, .16, .18), loc=pb_ + V(0, 0, .08), col="wood", bevel=.06); P.append(yk)
    for s_ in (-1, 1):
        P.append(sphere(f"yokeb{s_}", (.1,) * 3, loc=pb_ + V(s_ * .57, 0, .08), col="chili", seg=10, ring=6))
    # load: coffee sacks + bouquet of flowers
    for k, (x, y, rz) in enumerate(((-.38, .25, 15), (.38, .35, -10), (0, .6, 5))):
        P.append(sphere(f"sack{k}", (.42, .36, .4), loc=(x, y, bz + bh + .25 + (.25 if k == 2 else 0)), rot=(0, 0, rz), col="cream", seg=16, ring=10))
        P.append(torus(f"sackt{k}", .14, .04, loc=(x, y, bz + bh + .6 + (.25 if k == 2 else 0)), col="wood", seg=12, mseg=4))
        P.append(sphere(f"bean{k}", (.06, .045, .04), loc=(x - .12, y - .36, bz + bh + .3 + (.25 if k == 2 else 0)), rot=(90, 0, 0), col="chocolate", seg=8, ring=5))
    fl = [("fiesta_pink", -.55, -.45), ("sun_yellow", -.2, -.6), ("tangerine", .2, -.55), ("eye_white", .55, -.4), ("grape", 0, -.3)]
    for k, (c, x, y) in enumerate(fl):
        fc = V(x, y, bz + bh + .55 + .12 * (k % 2))
        P.append(tube(f"fst{k}", [V(x * .6, y * .6, bz + bh), fc], radius=.03, col="leaf", seg=5))
        for j in range(5):
            a = 2 * math.pi * j / 5
            P.append(sphere(f"fp{k}{j}", (.11, .11, .05), loc=fc + V(.1 * math.cos(a), .1 * math.sin(a), 0), col=c, seg=8, ring=5))
        P.append(sphere(f"fcen{k}", (.06,) * 3, loc=fc + V(0, 0, .03), col="sun_yellow" if c != "sun_yellow" else "tangerine", seg=8, ring=5))
    G += [sparkle(f"sp{k}", loc, s=.2) for k, loc in enumerate((V(-1.6, -1.3, 2.9), V(1.8, -1.0, 3.2), V(-1.9, -.8, 1.4)))]
    P += hook("hook", V(0, .95, bz + bh + 1.3))
    return P + G, {"glow": G}

# ============================================================================= 14. HARPÍA DESPEINADA (legendary, Panamá)
def harpia_despeinada():
    """LEGENDARY - Panama's harpy eagle: huge, double crest sticking up like bed-head, giant yellow talons... and a zipper on the belly.
    Joke: 'tan grandota y despeinada que parece un señor disfrazado'."""
    P = []; G = []
    bz = .75; H = 2.5
    body = fringe_body("body", ellip_prof(1.08, H, p=.8), H, 6, ["ink_soft", "ink_soft", "white", "white", "white", "white"], matrix=M(V(0, .05, bz)), seg=28, flare=.08, tooth=.06, seed=3401)
    P += body
    btree = bvh_of(body)
    # zipper running down the belly (the costume gag)
    zp = []
    for k in range(9):
        z = bz + 1.5 - .14 * k
        p, n = hit(btree, V(.32, -3, z), V(0, 1, 0))
        if p is not None: zp.append((p, n))
    if len(zp) > 3:
        P.append(tube("zip", [p + n * .06 for p, n in zp], radius=.035, col="steel", seg=6))
        for k, (p, n) in enumerate(zp):
            for s_ in (-1, 1):
                P.append(box(f"zt{k}{s_}", (.07, .03, .05), loc=p + n * .07 + V(.05 * s_, 0, .035 * s_), col="silver", bevel=.01))
        p, n = zp[2]
        P.append(box("zpull", (.09, .04, .2), loc=p + n * .12 + V(0, 0, -.12), col="silver", bevel=.02))
        P.append(torus("zpullr", .05, .015, loc=p + n * .12 + V(0, 0, -.25), rot=(90, 0, 0), col="silver", seg=10, mseg=4))
    # head
    hc = V(0, -.1, bz + H + .45)
    head = fringe_body("head", ellip_prof(.82, 1.5, p=.85), 1.5, 3, ["donkey_grey", "stone", "donkey_grey"], matrix=M(hc - V(0, 0, .72)), seg=24, flare=.08, tooth=.06, seed=3402)
    P += head
    fp = plate("face", hc, r=(.66, .26, .55), col="stone", fwd_off=.62); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .14), dx=.28, dz=0, size=.25, iris="ink_soft", lid="donkey_dark", open_=.62, tilt=-10, lash=True,
               brow=True, brow_h=1.35, brow_tilt=-22, brow_col="ink", look=(0, .05), looks=[(0, .05), (.15, .25)])
    for s_ in (-1, 1):   # dark mask under the eyes
        P += decal(f"msk{s_}", tree, hc + V(.28 * s_, -3, -.12), r=(.16, .08), col="donkey_dark", roll=15 * s_)
        P += blush2(f"bl{s_}", tree, hc + V(.45 * s_, -3, -.2), size=.08)
    # hooked beak
    bk = hc + V(0, -.85, -.12)
    P.append(sphere("cere", (.2, .18, .14), loc=bk + V(0, .05, .06), col="donkey_dark", seg=14, ring=8))
    P.append(tube("beak", [bk + V(0, 0, .05), bk + V(0, -.2, .02), bk + V(0, -.28, -.12), bk + V(0, -.2, -.28)], radius=.15, col="ink", seg=12, taper=[1, .95, .6, .15]))
    # the double crest: two messy fans sticking up (bed-head)
    rnd = random.Random(3403)
    for s_ in (-1, 1):
        base = hc + V(.25 * s_, .1, .62)
        for k in range(6):
            a = math.radians(10 + 14 * k + rnd.uniform(-6, 6)) * s_
            L = .75 + rnd.uniform(-.1, .2)
            d = V(math.sin(a), rnd.uniform(-.1, .25), math.cos(a))
            tip = base + d * L
            P.append(tube(f"cr{s_}{k}", [base, base + d * L * .5 + V(.05 * s_, 0, .04), tip], radius=.09, col="ink_soft" if k % 2 else "donkey_dark", seg=8, taper=[1, .8, .25]))
    for k in range(3):   # a few loose feathers on the head
        a = rnd.uniform(-.4, .4)
        P.append(tube(f"loose{k}", [hc + V(a, 0, .7), hc + V(a * 1.4, -.25, 1.0), hc + V(a * 1.8, -.2, 1.15)], radius=.05, col="stone", seg=6, taper=[1, .7, .2]))
    # wings: left scratches the head, right on the hip
    P += fringe_body("wingL", ellip_prof(.42, 1.45, p=.85), 1.45, 4, ["donkey_dark", "ink_soft", "donkey_dark", "ink_soft"], matrix=M(V(-.95, 0, bz + 1.95), (-.35, -.25, 1)), seg=16, flare=.1, tooth=.06, seed=3404, sx=.55)
    P += fringe_body("wingR", ellip_prof(.42, 1.35, p=.85), 1.35, 4, ["donkey_dark", "ink_soft", "donkey_dark", "ink_soft"], matrix=M(V(1.0, -.05, bz + 1.9), (.45, -.35, -.8)), seg=16, flare=.1, tooth=.06, seed=3405, sx=.55)
    # feathered "pants" + giant talons
    for s_ in (-1, 1):
        P += fringe_body(f"pant{s_}", lin_prof(.36, .3, .75), .75, 3, ["white", "stone", "white"], matrix=M(V(.45 * s_, -.05, bz + .2), (0, 0, -1)), seg=16, flare=.12, tooth=.07, seed=3406 + s_)
        an = V(.48 * s_, -.1, .2)
        P.append(cyl(f"shin{s_}", .1, .1, .3, loc=an, col="mango", seg=10))
        for j in range(3):
            a = math.radians(-30 + 30 * j)
            tip = an + V(math.sin(a) * .5, -math.cos(a) * .5, -.1)
            P.append(tube(f"toe{s_}{j}", [an, an.lerp(tip, .6) + V(0, 0, .04), tip], radius=.08, col="mango", seg=8))
            P.append(tube(f"claw{s_}{j}", [tip, tip + V(math.sin(a) * .1, -math.cos(a) * .1, -.08)], radius=.05, col="ink", seg=6, taper=[1, .2]))
        P.append(tube(f"toeb{s_}", [an, an + V(0, .35, -.12)], radius=.07, col="mango", seg=6))
    G += [sparkle(f"sp{k}", loc, s=.2) for k, loc in enumerate((V(-1.5, -.9, 4.3), V(1.6, -.8, 4.0), V(1.7, -.9, 1.3)))]
    P += hook("hook", hc + V(0, .45, .82))
    return P + G, {"glow": G}

# ============================================================================= 15. CARPINCHO TRANQUI (legendary, Argentina)
def carpincho_tranqui():
    """LEGENDARY - an Argentine carpincho in total zen mode: floating in a pool ring, a mandarina on his head and a bird on top of that.
    Joke: 'se metió al barrio cheto y ni se inmutó' (the Nordelta carpinchos)."""
    P = []; G = []
    # water + ripples
    P.append(cyl("water", 2.1, 2.1, .06, loc=(0, 0, 0), col="water", seg=40))
    for k, r in enumerate((1.75, 2.0)):
        P.append(torus(f"rip{k}", r, .03, loc=(0, 0, .07), col="eye_white", seg=40, mseg=4))
    # pool ring (striped)
    rz = .42; RR = 1.25; rr = .38
    for k in range(8):
        P.append(torus(f"ring{k}", RR, rr, loc=(0, 0, rz), rot=(0, 0, 45 * k), col="turquoise" if k % 2 else "eye_white", seg=6, mseg=12, arc=45))
    # body sitting in the ring
    bz = .2
    body = fringe_body("body", ellip_prof(1.0, 2.1, p=.85), 2.1, 6, ["wood", "brown", "wood", "wood", "brown", "wood"], matrix=M(V(0, .1, bz), (0, .05, 1)), seg=26, flare=.08, tooth=.06, seed=3501, sx=1.05)
    P += body
    # blocky head
    hc = V(0, -.15, 2.55)
    # capybara head: a big long rounded block (blunt snout), tiny ears at the back, eyes up high
    P += fringe_body("nape", ellip_prof(.66, .9, p=.7), .9, 2, ["brown", "wood"], matrix=M(hc + V(0, .35, -.45)), seg=20, flare=.07, tooth=.05, seed=3502)
    head = box("head", (1.15, 1.4, .95), loc=hc + V(0, -.2, 0), col="wood", bevel=.44, bseg=5); P.append(head)
    mz = hc + V(0, -.86, -.08)
    P.append(box("nose", (.9, .2, .64), loc=mz + V(0, .02, 0), col="brown", bevel=.2, bseg=3))
    st = bvh_of([head])
    P += eyes2("e", st, hc + V(0, -.2, .3), dx=.3, dz=0, size=.17, iris="chocolate", lid="brown", open_=.25, tilt=0, lash=True,
               brow=False, look=(0, 0))
    for s_ in (-1, 1):
        P.append(sphere(f"nos{s_}", (.08, .04, .05), loc=mz + V(.17 * s_, -.1, .14), col="chocolate", seg=10, ring=6))
        P.append(sphere(f"ear{s_}", (.11, .08, .12), loc=hc + V(.42 * s_, .3, .5), col="brown", seg=12, ring=8))
        P += blush2(f"bl{s_}", st, hc + V(.44 * s_, -3, -.12), size=.08)
    P.append(tube("smile", [mz + V(-.15, -.11, -.13), mz + V(0, -.13, -.2), mz + V(.15, -.11, -.13)], radius=.025, col="ink", seg=6))
    # mandarina on the head + a little bienteveo on top of it
    mc = hc + V(0, -.05, .78)
    P.append(sphere("mand", (.34, .34, .3), loc=mc, col="tangerine", seg=20, ring=12))
    mt = bvh_of([P[-1]])
    P += scatter("mdot", mt, mc, 10, "mango", 3503, r=(.025, .035), zr=(-.3, .8), yaw=(-3, 3), th=.015)
    P.append(cyl("mstem", .03, .03, .08, loc=mc + V(0, 0, .28), col="wood_dark", seg=6))
    P.append(ribbon("mleaf", [mc + V(0, 0, .34), mc + V(.15, -.05, .42), mc + V(.3, 0, .38)], width=.12, normal=(0, -.3, 1), col="leaf", thick=.03))
    bc = mc + V(.28, -.06, .4)
    P.append(sphere("bird", (.2, .17, .17), loc=bc, col="sun_yellow", seg=14, ring=8))
    P.append(sphere("birdb", (.16, .16, .12), loc=bc + V(0, .07, .1), col="brown", seg=12, ring=8))
    P.append(sphere("birdh", (.13,) * 3, loc=bc + V(-.12, -.05, .2), col="ink", seg=12, ring=8))
    P.append(torus("birdst", .1, .02, loc=bc + V(-.12, -.05, .22), rot=(0, 90, 20), col="eye_white", seg=14, mseg=4))
    P.append(cyl("birdbk", .04, .005, .12, col="ink", seg=6)); P[-1].matrix_world = M(bc + V(-.22, -.1, .19), (-.7, -.6, -.1))
    P.append(sphere("birde", (.025,) * 3, loc=bc + V(-.17, -.15, .24), col="eye_white", seg=6, ring=4))
    P.append(cyl("birdt", .07, .02, .22, col="brown", seg=6)); P[-1].matrix_world = M(bc + V(.12, .08, .05), (.7, .4, .1))
    # arms resting on the ring, totally relaxed
    for s_ in (-1, 1):
        a = V(.85 * s_, -.25, 1.35); b = V(1.3 * s_, -.55, .8)
        P += limb(f"arm{s_}", a, b, .17, .15, 2, ["brown", "wood"], seed=3504 + s_, seg=12)
        P += paw(f"paw{s_}", b + V(.05 * s_, -.1, -.02), fwd=(0, -1, 0), s=.2, col="wood", pad="brown", toes=3)
    G += [sparkle(f"sp{k}", loc, s=.18) for k, loc in enumerate((V(-1.35, -.6, 3.3), V(1.35, -.5, 3.6), V(1.5, -.8, 2.2)))]
    t = text_mesh("zz", "Z", size=.32, extrude=.03, col="neon_gold", bevel=0, res=3); t.matrix_world = Matrix.Translation((.95, -.55, 3.95)) @ Matrix.Rotation(math.radians(90), 4, 'X') @ Matrix.Rotation(math.radians(-12), 4, 'Z'); G.append(t)
    t2 = text_mesh("zz2", "z", size=.24, extrude=.03, col="neon_gold", bevel=0, res=3); t2.matrix_world = Matrix.Translation((.7, -.55, 3.6)) @ Matrix.Rotation(math.radians(90), 4, 'X'); G.append(t2)
    P += hook("hook", mc + V(-.22, .12, .28), s=.85)
    return P + G, {"glow": G}

# ============================================================================= 16. QUETZALETE (mythic, Guatemala)
def quetzalete():
    """MYTHIC - a resplendent quetzal (national bird + the currency) flying a giant Sumpango barrilete with a 'Q' in the middle.
    Joke: 'vale un quetzal... pero vuela como mil'."""
    P = []; G = []
    # the barrilete (behind, upper left)
    kc = V(-.7, 1.1, 3.0); KR = 1.55
    km = Matrix.Translation(kc) @ Matrix.Rotation(math.radians(-8), 4, 'Y') @ Matrix.Rotation(math.radians(90), 4, 'X')
    rain = ["fiesta_pink", "sun_yellow", "turquoise", "tangerine", "grape", "lime", "chili", "sky"]
    N = 16
    for k in range(N):
        a0 = 2 * math.pi * k / N; a1 = 2 * math.pi * (k + 1) / N
        sl = slab(f"kw{k}", wedge(.45, KR, a0, a1, 4), thick=.04, col=rain[k % 8], bevel=0); sl.matrix_world = km; P.append(sl)
        sl2 = slab(f"kw2{k}", wedge(.95, 1.15, a0 + .05, a1 - .05, 3), thick=.05, col=rain[(k + 4) % 8], bevel=0); sl2.matrix_world = km @ Matrix.Translation((0, 0, -.02)); P.append(sl2)
    cen = cyl("kcen", .47, .47, .06, col="eye_white", seg=28); cen.matrix_world = km @ Matrix.Translation((0, 0, -.03)); P.append(cen)
    q = text_mesh("kq", "Q", size=.62, extrude=.04, col="jade", bevel=0, res=3); q.matrix_world = km @ Matrix.Translation((0, 0, -.06)) @ Matrix.Rotation(math.radians(180), 4, 'X') @ Matrix.Rotation(math.radians(180), 4, 'Z')
    P.append(q)
    for k in range(8):   # bamboo spokes (back)
        a = math.pi * k / 8
        p0 = km @ V(-KR * math.cos(a), -KR * math.sin(a), .05); p1 = km @ V(KR * math.cos(a), KR * math.sin(a), .05)
        P.append(tube(f"bam{k}", [p0, p1], radius=.025, col="wood", seg=5))
    rim = torus("krim", KR, .045, col="neon_pink", seg=48, mseg=5); rim.matrix_world = km; G.append(rim)
    for k in range(32):   # fleco: paper fringe tassels all around
        a = 2 * math.pi * k / 32
        p = km @ V((KR + .02) * math.cos(a), (KR + .02) * math.sin(a), 0)
        d = (p - kc).normalized()
        P.append(ribbon(f"fl{k}", [p, p + d * .2 + V(0, 0, -.04), p + d * .36 + V(0, 0, -.1)], width=.14, normal=(0, -1, 0), col=rain[(k + 2) % 8], thick=.02))
    # kite tail
    kt = km @ V(0, -KR, 0)
    tl = [kt + V(.1 * math.sin(k * 1.3), 0, -.35 * k) + V(.1 * k, 0, 0) for k in range(6)]
    P.append(tube("ktail", tl, radius=.025, col="eye_white", seg=4))
    for k in range(1, 6):
        P.append(slab(f"kbow{k}", [(-.14, 0), (.14, .08), (.14, -.08)], thick=.02, col=rain[k], bevel=0, matrix=Matrix.Translation(tl[k]) @ Matrix.Rotation(math.radians(90), 4, 'X')))
        P.append(slab(f"kbow2{k}", [(.14, 0), (-.14, .08), (-.14, -.08)], thick=.02, col=rain[k], bevel=0, matrix=Matrix.Translation(tl[k]) @ Matrix.Rotation(math.radians(90), 4, 'X')))
    # the quetzal
    bz = .55; H = 2.1
    body = fringe_body("body", ellip_prof(.85, H, p=.85), H, 6, ["jade", "dark_green", "jade", "jade", "chili", "chili"], matrix=M(V(.35, -.2, bz), (0, .1, 1)), seg=26, flare=.08, tooth=.06, seed=3601)
    P += body
    hc = V(.35, -.35, bz + H + .25)
    head = fringe_body("head", ellip_prof(.62, 1.15, p=.85), 1.15, 3, ["jade", "torogoz_t", "jade"], matrix=M(hc - V(0, 0, .55)), seg=22, flare=.08, tooth=.05, seed=3602)
    P += head
    P += fringe_body("crest", ellip_prof(.38, .75, p=.8), .75, 2, ["jade", "torogoz_t"], matrix=M(hc + V(0, .1, .42), (0, -.5, 1)), seg=18, flare=.14, tooth=.08, seed=3603, sx=.55)
    fp = plate("face", hc, r=(.48, .22, .42), col="jade", fwd_off=.45); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .1), dx=.22, dz=0, size=.21, iris="ink_soft", lid="dark_green", open_=.8, tilt=-4, lash=True,
               brow=True, brow_h=1.45, brow_tilt=-6, brow_col="dark_green", look=(-.3, .35))
    P.append(cyl("beak", .12, .02, .32, col="sun_yellow", seg=12)); P[-1].matrix_world = M(hc + V(0, -.55, -.14), (0, -1, -.25))
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.36 * s_, -3, -.15), size=.08)
    # wings: right one up holding the string, left on the chest
    P += fringe_body("wingR", ellip_prof(.38, 1.2, p=.9), 1.2, 3, ["dark_green", "jade", "dark_green"], matrix=M(V(1.05, -.25, bz + 1.5), (.2, -.3, 1)), seg=16, flare=.1, tooth=.06, seed=3604, sx=.5)
    P += fringe_body("wingL", ellip_prof(.38, 1.2, p=.9), 1.2, 3, ["dark_green", "jade", "dark_green"], matrix=M(V(-.4, -.25, bz + 1.6), (-.5, -.4, -.7)), seg=16, flare=.1, tooth=.06, seed=3605, sx=.5)
    hand_p = V(1.15, -.55, bz + 2.65)
    P.append(tube("string", [hand_p, hand_p.lerp(kc, .5) + V(0, 0, .25), km @ V(0, 0, .06)], radius=.015, col="eye_white", seg=4))
    # the famous long tail streamers
    tb = V(.35, .45, bz + .45)
    for s_, c in ((-1, "jade"), (1, "torogoz_t")):
        pts = [tb, tb + V(.25 * s_, .6, -.25), tb + V(.5 * s_, 1.1, -.4), tb + V(.85 * s_, 1.5, -.42), tb + V(1.25 * s_, 1.7, -.2), tb + V(1.5 * s_, 1.65, .15)]
        P.append(ribbon(f"tail{s_}", pts, width=.3, normal=(0, 0, 1), col=c, thick=.05))
        P.append(tube(f"tailr{s_}", pts, radius=.03, col="dark_green", seg=5))
    for s_ in (-1, 1):
        an = V(.35 + .3 * s_, -.3, .25)
        P.append(tube(f"leg{s_}", [an + V(0, 0, .35), an], radius=.06, col="donkey_dark", seg=6))
        for j in range(3):
            a = math.radians(-30 + 30 * j)
            P.append(tube(f"toe{s_}{j}", [an, an + V(math.sin(a) * .22, -math.cos(a) * .22, -.2)], radius=.04, col="donkey_dark", seg=5))
    # a golden Q coin on a little cord (the currency joke) + neon stars
    cc = hc + V(0, -.62, -.85)
    G.append(cyl("coin", .2, .2, .05, col="neon_gold", seg=24)); G[-1].matrix_world = M(cc, (0, -1, .15))
    cq = text_mesh("cq", "Q", size=.24, extrude=.02, col="gold_deep", bevel=0, res=3); place_text(cq, cc, V(0, -1, .15), push=.04); P.append(cq)
    P.append(tube("cord", [cc + V(-.18, .05, .15), hc + V(0, -.35, -.5), cc + V(.18, .05, .15)], radius=.015, col="gold", seg=4))
    G += stars_ring("st", V(.35, -.3, 2.4), 1.7, n=4, s=.16, col="neon_gold")
    P += hook("hook", hc + V(0, .2, .82), s=.9)
    return P + G, {"glow": G}

# ============================================================================= 17. CHIVITA RUMBERA (mythic, Colombia)
def chivita_rumbera():
    """MYTHIC - a Colombian chiva (hand-painted ladder bus) turned party bus: face on the cab, loaded roof, neon lights, speaker.
    Joke: 'siempre cabe uno más'."""
    P = []; G = []
    W_, L_, z0, Hb = 2.1, 3.3, .55, 1.65
    # body (wooden box) + painted stripes
    P.append(box("body", (W_, L_, Hb), loc=(0, .3, z0 + Hb / 2), col="sun_yellow", bevel=.12))
    for k, (z, c) in enumerate(((z0 + .25, "chili"), (z0 + .45, "cobalt"), (z0 + Hb - .18, "lime"))):
        P.append(box(f"band{k}", (W_ + .04, L_ + .04, .14), loc=(0, .3, z), col=c, bevel=.04))
    # windows (open, no glass) on both sides + front
    for s_ in (-1, 1):
        for k in range(4):
            y = -.8 + .75 * k
            P.append(box(f"win{s_}{k}", (.06, .55, .55), loc=(s_ * W_ / 2, y + .3, z0 + 1.05), col="ink_soft", bevel=.06))
            P.append(box(f"winf{s_}{k}", (.07, .63, .07), loc=(s_ * (W_ / 2 + .01), y + .3, z0 + 1.36), col="chili", bevel=.02))
            # tiny paper confetti blowing out of the windows
    t = text_mesh("txt", "LA RUMBERA", size=.24, extrude=.03, col="chili", bevel=0, res=3)
    t.matrix_world = Matrix.Translation((W_ / 2 + .04, .3, z0 + .66)) @ Matrix.Rotation(math.radians(90), 4, 'Z') @ Matrix.Rotation(math.radians(90), 4, 'X'); P.append(t)
    # cab + hood at the front (-Y)
    cab = box("cab", (W_ - .1, .9, Hb - .1), loc=(0, -1.55, z0 + (Hb - .1) / 2), col="sun_yellow", bevel=.14); P.append(cab)
    hood = box("hood", (W_ - .35, .75, .8), loc=(0, -2.15, z0 + .4), col="chili", bevel=.18, bseg=3); P.append(hood)
    P.append(box("windsh", (W_ - .45, .05, .55), loc=(0, -2.01, z0 + 1.22), col="sky", bevel=.06))
    ft = bvh_of([cab])
    hc = V(0, -2.0, z0 + 1.15)
    P += eyes2("e", bvh_of([P[-1]]), hc + V(0, 0, .02), dx=.42, dz=0, size=.24, iris="cobalt", lid="sky", open_=.85, tilt=-4, lash=True,
               brow=True, brow_h=1.45, brow_tilt=-6, brow_col="ink", look=(.15, .1))
    # grille smile on the hood
    ht = bvh_of([hood])
    P += mouth2("m", ht, V(0, -3, z0 + .42), w=.85, h=.32, smile=1.4, col="ink", tongue=True, teeth=4)
    for s_ in (-1, 1):
        P.append(cyl(f"hl{s_}", .14, .14, .06, col="sun_yellow", seg=16)); P[-1].matrix_world = M(V(.58 * s_, -2.53, z0 + .58), (0, -1, 0))
        P.append(torus(f"hlr{s_}", .14, .03, col="silver", seg=16, mseg=4)); P[-1].matrix_world = M(V(.58 * s_, -2.55, z0 + .58), (0, -1, 0))
        P += blush2(f"bl{s_}", ht, V(.62 * s_, -3, z0 + .3), size=.08)
    P.append(box("bumper", (W_ - .2, .14, .14), loc=(0, -2.55, z0 + .05), col="silver", bevel=.05))
    # wheels
    for s_ in (-1, 1):
        for y in (-1.9, .9):
            tr = cyl(f"tire{s_}{y}", .5, .5, .34, col="rubber", seg=24, bevel=.08); tr.matrix_world = M(V(s_ * (W_ / 2 - .12), y, .5), (s_, 0, 0)); P.append(tr)
            hb = cyl(f"hub{s_}{y}", .24, .24, .36, col="chili", seg=16, bevel=.03); hb.matrix_world = M(V(s_ * (W_ / 2 - .12), y, .5), (s_, 0, 0)); P.append(hb)
    # paper fringe skirt along the sides (piñata DNA)
    for s_ in (-1, 1):
        P.append(fringe_strip(f"skirt{s_}", (s_ * (W_ / 2 + .05), -1.2, z0 + .14), (s_ * (W_ / 2 + .05), 1.9, z0 + .14), h=.2, col="fiesta_pink" if s_ > 0 else "turquoise"))
    # roof rack + load + ladder
    rz = z0 + Hb + .05
    for s_ in (-1, 1):
        P.append(box(f"rail{s_}", (.08, L_ + .6, .08), loc=(s_ * (W_ / 2 - .05), .0, rz + .3), col="ink_soft", bevel=.02))
        for k in range(6):
            P.append(box(f"post{s_}{k}", (.06, .06, .3), loc=(s_ * (W_ / 2 - .05), -1.8 + .75 * k, rz + .15), col="ink_soft", bevel=0))
    load = [((-.5, -.9), (.6, .5, .45), "cobalt"), ((.35, -.7), (.55, .55, .55), "chili"), ((-.3, .1), (.7, .6, .5), "grape"), ((.45, .35), (.5, .45, .4), "lime"),
            ((0, 1.0), (.8, .6, .55), "tangerine")]
    for k, ((x, y), sz, c) in enumerate(load):
        P.append(box(f"bag{k}", sz, loc=(x, y, rz + sz[2] / 2), col=c, bevel=.1))
        P.append(box(f"strap{k}", (sz[0] + .02, .07, sz[2] + .02), loc=(x, y, rz + sz[2] / 2), col="wood_dark", bevel=.02))
    # bunch of plátanos + a speaker on the roof
    pb = V(.1, -.1, rz + .7)
    for k in range(5):
        a = math.radians(-50 + 25 * k)
        P.append(tube(f"bnn{k}", [pb, pb + V(.35 * math.sin(a), -.05, .1), pb + V(.55 * math.sin(a), -.1, -.05)], radius=.08, col="lime", seg=8, taper=[.8, 1, .6]))
    spk = box("speaker", (.5, .4, .65), loc=(-.55, .75, rz + .78), col="ink", bevel=.06); P.append(spk)
    for z in (.62, .95):
        P.append(cyl(f"cone{z}", .15, .1, .05, col="ink_soft", seg=16)); P[-1].matrix_world = M(V(-.55, .54, rz + z), (0, -1, 0))
        G.append(torus(f"conr{z}", .15, .025, col="neon_cyan", seg=16, mseg=4)); G[-1].matrix_world = M(V(-.55, .53, rz + z), (0, -1, 0))
    for k in range(5):
        P.append(box(f"lad{k}", (.9, .06, .06), loc=(0, L_ / 2 + .35, z0 + .3 + .33 * k), col="wood", bevel=.02))
    for s_ in (-1, 1):
        P.append(box(f"ladr{s_}", (.07, .07, Hb + .3), loc=(.45 * s_, L_ / 2 + .35, z0 + (Hb + .3) / 2), col="wood", bevel=.02))
    # neon string lights around the roof edge
    bulbs = []
    for k in range(14):
        y = -1.95 + 3.9 * k / 13
        for s_ in (-1, 1):
            bulbs.append(V(s_ * (W_ / 2 + .02), y, rz - .05 - .08 * math.sin(math.pi * ((k * 2) % 4) / 4)))
    cols = ["neon_pink", "neon_cyan", "neon_gold", "neon_green"]
    for k, b in enumerate(bulbs):
        G.append(sphere(f"bulb{k}", (.06, .06, .08), loc=b, col=cols[k % 4], seg=8, ring=6))
    for s_ in (-1, 1):
        P.append(tube(f"wire{s_}", [V(s_ * (W_ / 2 + .02), -1.95 + 3.9 * k / 13, rz - .02) for k in range(14)], radius=.012, col="ink", seg=4))
    for k, (x, y, z, c) in enumerate(((-1.6, -1.5, 3.4, "neon_pink"), (1.55, -1.2, 3.6, "neon_cyan"), (1.6, .5, 3.1, "neon_gold"))):
        G += note(f"n{k}", (x, y, z), s=.3, col=c, rz=10 * k)
    P += hook("hook", V(0, .3, rz + 1.25))
    return P + G, {"glow": G}

# ============================================================================= 18. BOTO BAILÃO (secret, Brasil)
def boto_bailao():
    """SECRET - the Amazon's pink river dolphin (boto cor-de-rosa) of the legend: comes out of the river at night in a white hat to dance at the festa junina.
    Joke: 'sale del río de noche solo para bailar'."""
    P = []; G = []
    # river base + ripples + splash
    P.append(cyl("river", 1.9, 1.9, .07, col="water", seg=40))
    for k, r in enumerate((1.45, 1.75)):
        P.append(torus(f"rip{k}", r, .03, loc=(0, 0, .08), col="eye_white", seg=40, mseg=4))
    for k in range(7):
        a = 2 * math.pi * k / 7
        P.append(sphere(f"spl{k}", (.12, .12, .2), loc=(.75 * math.cos(a), .75 * math.sin(a), .22), rot=(25 * math.cos(a), 25 * math.sin(a), 0), col="turquoise", seg=10, ring=6))
    # body standing on the tail, a little S-curve (dancing)
    z0 = .25; H = 3.0
    prof = lambda z: .2 + .78 * math.sin(math.pi * min(max(z / H * .92 + .05, 0), 1)) ** .8 * (1 if z / H < .7 else (1 - (z / H - .7) * .55))
    body = fringe_body("body", prof, H, 8, ["bubblegum", "fiesta_pink", "bubblegum", "bubblegum", "fiesta_pink", "bubblegum", "bubblegum", "fiesta_pink"], matrix=M(V(0, 0, z0)),
                       seg=26, flare=.07, tooth=.05, seed=3801, sy=.95)
    bend(body, 6.0, 1.2, axis_x=0.0); P += body
    # tail flukes on the water
    for s_ in (-1, 1):
        fl = slab(f"fluke{s_}", [(0, 0), (.75, .25), (.85, -.05), (.55, -.2)], thick=.1, col="fiesta_pink", bevel=.04)
        fl.matrix_world = Matrix.Translation((0, .1, .2)) @ Matrix.Rotation(math.radians(90 + 90 * s_), 4, 'Z') @ Matrix.Rotation(math.radians(-10), 4, 'Y'); P.append(fl)
    # head: bulbous melon + long snout
    hc = V(.35, -.15, 2.9)
    P.append(sphere("melon", (.7, .66, .62), loc=hc, col="bubblegum", seg=24, ring=14))
    sn = tube("snout", [hc + V(-.1, -.45, -.18), hc + V(-.45, -.85, -.26), hc + V(-.8, -1.1, -.3)], radius=.19, col="bubblegum", seg=14, taper=[1.35, 1, .75])
    P.append(sn); P.append(sphere("snt", (.15, .15, .14), loc=hc + V(-.8, -1.1, -.3), col="bubblegum", seg=12, ring=8))
    tree = bvh_of([P[-3]])
    P += eyes2("e", tree, hc + V(0, -.1, .08), dx=.33, dz=0, size=.2, iris="cobalt", lid="fiesta_pink", open_=.5, tilt=-4, lash=True,
               brow=True, brow_h=1.5, brow_tilt=-10, brow_col="hot_magenta", look=(.25, .15))
    P.append(tube("smile", [hc + V(.12, -.55, -.33), hc + V(-.2, -.75, -.43), hc + V(-.55, -.97, -.45)], radius=.025, col="ink", seg=5))
    P.append(tube("smile2", [hc + V(.18, -.48, -.28), hc + V(.12, -.55, -.33)], radius=.02, col="ink", seg=4))
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.42 * s_, -3, -.15), size=.09)
    # white hat (the legend's giveaway) tilted, red band
    hm = Matrix.Translation(hc + V(.05, .05, .5)) @ Matrix.Rotation(math.radians(-14), 4, 'Y') @ Matrix.Rotation(math.radians(6), 4, 'X')
    brim = cyl("brim", .72, .72, .06, col="eye_white", seg=32, bevel=.02); brim.matrix_world = hm; P.append(brim)
    crown = cyl("hatc", .42, .36, .42, col="eye_white", seg=24, bevel=.06); crown.matrix_world = hm @ Matrix.Translation((0, 0, .05)); P.append(crown)
    band = cyl("hatb", .43, .42, .1, col="chili", seg=24); band.matrix_world = hm @ Matrix.Translation((0, 0, .07)); P.append(band)
    # flippers: one up (dance), one on the hip
    P += fringe_body("finR", ellip_prof(.24, .9, p=.9), .9, 2, ["fiesta_pink", "bubblegum"], matrix=M(V(.85, -.1, 2.15), (.6, -.2, .8)), seg=14, flare=.08, tooth=.05, seed=3802, sx=.45)
    P += fringe_body("finL", ellip_prof(.24, .85, p=.9), .85, 2, ["fiesta_pink", "bubblegum"], matrix=M(V(-.5, -.1, 1.85), (-.6, -.3, -.55)), seg=14, flare=.08, tooth=.05, seed=3803, sx=.45)
    # festa junina bandeirinhas behind + poles
    for x in (-1.75, 1.75):
        P.append(cyl(f"pole{x}", .05, .05, 3.7, loc=(x, .9, 0), col="wood", seg=8))
    P += pennants("band", V(-1.75, .9, 3.6), V(1.75, .9, 3.6), n=11, sag=.6, s=.3)
    # neon moon + stars (night) - secret
    mo = V(-1.25, .6, 4.25)
    G.append(sphere("moon", (.36, .1, .36), loc=mo, col="neon_gold", seg=20, ring=10))
    P.append(sphere("moonc", (.32, .1, .33), loc=mo + V(.17, -.05, .08), col="ink_soft", seg=18, ring=10))
    G += [sparkle(f"sp{k}", loc, s=.17, col="neon_cyan") for k, loc in enumerate((V(1.35, -.4, 4.2), V(1.6, -.6, 2.3), V(-1.5, -.6, 2.6), V(-.4, -.6, 4.5)))]
    P += hook("hook", hc + V(.0, .05, 1.05), s=.9)
    return P + G, {"glow": G}

# ============================================================================= 19. AJOLOTE TRAJINERO (secret, México)
def ajolote_trajinero():
    """SECRET - a Xochimilco axolotl (always smiling, regenerates) poling its own trajinera with a flower arch; neon gills.
    Joke: 'se le cae el ánimo y le vuelve a crecer'."""
    P = []; G = []
    # canal water + floating petals
    P.append(slab("canal", [(2.5 * math.cos(a), 1.45 * math.sin(a)) for a in [2 * math.pi * k / 32 for k in range(32)]], thick=.06, col="water", bevel=.02, matrix=Matrix.Translation((0, 0, .03))))
    rnd = random.Random(3901)
    for k in range(8):
        P.append(sphere(f"pet{k}", (.08, .06, .02), loc=(rnd.uniform(-2.2, 2.2), rnd.uniform(-1.2, -.7), .07), rot=(0, 0, rnd.uniform(0, 180)), col="tangerine" if k % 2 else "fiesta_pink", seg=8, ring=4))
    # trajinera hull (long along X), painted stripes
    hz = .12; Lh = 4.0; Wh = 1.3
    hull = [(-Lh / 2 + .25, -Wh / 2), (Lh / 2 - .25, -Wh / 2), (Lh / 2, -Wh / 4), (Lh / 2, Wh / 4), (Lh / 2 - .25, Wh / 2), (-Lh / 2 + .25, Wh / 2), (-Lh / 2, Wh / 4), (-Lh / 2, -Wh / 4)]
    P.append(slab("hull", hull, thick=.5, col="cobalt", bevel=.08, matrix=Matrix.Translation((0, 0, hz + .25))))
    P.append(slab("hulls", [(x * 1.01, y * 1.01) for x, y in hull], thick=.12, col="sun_yellow", bevel=.03, matrix=Matrix.Translation((0, 0, hz + .38))))
    P.append(slab("hullb", [(x * 1.005, y * 1.005) for x, y in hull], thick=.1, col="chili", bevel=.03, matrix=Matrix.Translation((0, 0, hz + .17))))
    P.append(slab("deck", [(x * .93, y * .86) for x, y in hull], thick=.06, col="wood", bevel=.02, matrix=Matrix.Translation((0, 0, hz + .52))))
    for k in range(7):   # painted flowers on the hull side
        x = -1.6 + 3.2 * k / 6
        for j in range(5):
            a = 2 * math.pi * j / 5
            P.append(sphere(f"hf{k}{j}", (.07, .02, .07), loc=(x + .08 * math.cos(a), -Wh / 2 - .03, hz + .26 + .08 * math.sin(a)), col="fiesta_pink" if k % 2 else "eye_white", seg=8, ring=4))
        P.append(sphere(f"hfc{k}", (.045, .02, .045), loc=(x, -Wh / 2 - .05, hz + .26), col="sun_yellow", seg=6, ring=4))
    # the arch with the name, facing the camera (behind the axolotl)
    ay = .35; az = hz + .55
    for x in (-1.35, 1.35):
        P.append(box(f"apost{x}", (.12, .12, 3.0), loc=(x, ay, az + 1.5), col="wood_dark", bevel=.03))
    arch = [(1.6 * math.cos(a), .35 * math.sin(a) + .0) for a in [math.pi * k / 16 for k in range(17)]] + [(-1.6, -.42), (1.6, -.42)]
    arch = [(1.6 * math.cos(math.pi * k / 16), .4 * math.sin(math.pi * k / 16)) for k in range(17)] + [(-1.6, -.45 + 0 * k) for k in range(1)] + [(1.6, -.45)]
    arch = arch[:17] + [(-1.6, -.45), (1.6, -.45)][::-1][::-1]
    pts = [(1.6 * math.cos(math.pi * k / 16), .4 * math.sin(math.pi * k / 16)) for k in range(17)] + [(-1.6, -.45), (1.6, -.45)]
    pts = pts[:17] + [(-1.6, -.45), (1.6, -.45)]
    poly = [(1.6, -.45)] + [(1.6 * math.cos(math.pi * k / 16), .4 * math.sin(math.pi * k / 16)) for k in range(17)] + [(-1.6, -.45)]
    sign = upright("sign", poly, .1, "fiesta_pink", V(0, ay - .05, az + 2.95), bevel=.03); P.append(sign)
    t = text_mesh("txt", "AJOLOTITA", size=.32, extrude=.03, col="sun_yellow", bevel=0, res=3)
    t.matrix_world = Matrix.Translation((0, ay - .12, az + 2.87)) @ Matrix.Rotation(math.radians(90), 4, 'X'); P.append(t)
    flo = ["tangerine", "fiesta_pink", "sun_yellow", "chili", "eye_white", "grape"]
    for k in range(15):   # flower garland along the arch top
        a = math.pi * k / 14
        fc = V(1.65 * math.cos(a), ay - .12, az + 2.95 + .45 * math.sin(a) + .05)
        P.append(sphere(f"af{k}", (.15, .1, .15), loc=fc, col=flo[k % 6], seg=10, ring=6))
        P.append(sphere(f"afc{k}", (.05, .04, .05), loc=fc + V(0, -.09, 0), col="sun_yellow" if flo[k % 6] != "sun_yellow" else "tangerine", seg=6, ring=4))
    for x in (-1.35, 1.35):   # flowers climbing the posts
        for k in range(4):
            P.append(sphere(f"pf{x}{k}", (.12, .08, .12), loc=(x, ay - .1, az + .5 + .5 * k), col=flo[(k + 2) % 6], seg=10, ring=6))
    P += pennants("pp", V(-1.35, ay + .05, az + 2.35), V(1.35, ay + .05, az + 2.35), n=9, sag=.3, s=.24)
    # the axolotl sitting in the boat
    bz = az + .02
    body = fringe_body("body", ellip_prof(.78, 1.7, p=.85), 1.7, 5, ["bubblegum", "blush", "bubblegum", "bubblegum", "blush"], matrix=M(V(0, -.1, bz)), seg=24, flare=.08, tooth=.05, seed=3902)
    P += body
    hc = V(0, -.25, bz + 1.95)
    head = sphere("head", (.95, .72, .66), loc=hc, col="bubblegum", seg=26, ring=14); P.append(head)
    tree = bvh_of([head])
    P += eyes2("e", tree, hc + V(0, 0, .18), dx=.48, dz=0, size=.18, iris="ink", lid=None, open_=1.0, lash=False, brow=False, look=(0, 0))
    P += mouth2("m", tree, hc + V(0, -3, -.2), w=.85, h=.2, smile=2.2, col="ink", tongue=True, shape="D")
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.62 * s_, -3, -.08), size=.11)
    # 3 pairs of feathery gills (fringe fronds) with neon tips
    for s_ in (-1, 1):
        for k in range(3):
            a = math.radians(-35 + 35 * k)
            base = hc + V(.82 * s_, .1, .15 + .22 * (1 - k))
            d = V(math.cos(a) * s_, .15, math.sin(a) + .55).normalized()
            tip = base + d * .75
            P += fringe_body(f"gill{s_}{k}", lin_prof(.13, .06, .75), .75, 3, ["hot_magenta", "fiesta_pink", "hot_magenta"], matrix=M(base, d), seg=12, flare=.35, tooth=.08, seed=3903 + k + (3 if s_ > 0 else 0))
            G.append(sphere(f"gt{s_}{k}", (.08,) * 3, loc=tip, col="neon_pink", seg=8, ring=6))
    # arms holding the pole (garrocha)
    pole0 = V(1.0, -.55, .1); pole1 = V(.55, -.75, 4.1)
    P.append(cyl("pole", .05, .05, (pole1 - pole0).length, col="wood", seg=8)); P[-1].matrix_world = M(pole0, pole1 - pole0)
    for s_, z in ((-1, 1.75), (1, 1.15)):
        hp = pole0.lerp(pole1, (bz + z - pole0.z) / (pole1.z - pole0.z))
        P += limb(f"arm{s_}", V(.6 * s_, -.3, bz + 1.1), hp + V(-.1, .05, 0), .14, .12, 2, ["blush", "bubblegum"], seed=3910 + s_, seg=12)
        P += hand(f"h{s_}", hp + V(-.04, -.02, 0), d=(.2, 0, 1), s=.14, col="bubblegum", fingers=4)
    # tail curling over the deck
    P.append(tube("tail", [V(0, .45, bz + .2), V(-.55, .7, bz + .2), V(-1.05, .55, bz + .25), V(-1.25, .2, bz + .3)], radius=.2, col="bubblegum", seg=12, taper=[1, .8, .5, .15]))
    P.append(ribbon("tailfin", [V(0, .45, bz + .42), V(-.55, .7, bz + .4), V(-1.05, .55, bz + .4), V(-1.28, .2, bz + .36)], width=.14, normal=(0, 0, 1), col="blush", thick=.04))
    G += [sparkle(f"sp{k}", loc, s=.17, col="neon_cyan") for k, loc in enumerate((V(-2.0, -.8, 1.6), V(2.05, -.7, 2.2), V(-1.9, -.6, 3.4)))]
    P += hook("hook", V(0, ay - .05, az + 3.55))
    return P + G, {"glow": G}

SET = {"carretica_pura_vida": carretica_pura_vida, "harpia_despeinada": harpia_despeinada, "carpincho_tranqui": carpincho_tranqui,
       "quetzalete": quetzalete, "chivita_rumbera": chivita_rumbera, "boto_bailao": boto_bailao, "ajolote_trajinero": ajolote_trajinero}
RARITY = {"carretica_pura_vida": "legendary", "harpia_despeinada": "legendary", "carpincho_tranqui": "legendary",
          "quetzalete": "mythic", "chivita_rumbera": "mythic", "boto_bailao": "secret", "ajolote_trajinero": "secret"}
CAM = {"carretica_pura_vida": (30, 12), "harpia_despeinada": (18, 9), "carpincho_tranqui": (28, 11), "quetzalete": (14, 8),
       "chivita_rumbera": (36, 13), "boto_bailao": (24, 9), "ajolote_trajinero": (16, 11)}
