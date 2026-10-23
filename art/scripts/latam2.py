"""Colección LatAm, parte 2: Raras y Épicas (Puerto Rico, Uruguay, Nicaragua, Paraguay, Ecuador, Perú)."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from latam_lib import *

# ============================================================================= 7. COQUÍ BOCINA (rare, Puerto Rico)
def coqui_bocina():
    """RARE - a tiny coquí with a vocal sac inflated like a giant speaker, sound waves and a 'CO-QUÍ!' that fills the island.
    Joke: 'mide 5 cm y lo oyen en toda la isla'. Sits on a big leaf next to a flor de maga."""
    P = []; G = []
    # leaf seat
    leaf = [(1.9 * math.cos(a) * (1 - .25 * abs(math.sin(a))), 1.25 * math.sin(a)) for a in [2 * math.pi * k / 28 for k in range(28)]]
    P.append(slab("leaf", leaf, thick=.1, col="lime", bevel=.04, matrix=Matrix.Translation((0, .1, .06)) @ Matrix.Rotation(math.radians(8), 4, 'Z')))
    P.append(tube("leafvein", [V(-1.7, .2, .13), V(0, .1, .13), V(1.7, -.1, .13)], radius=.04, col="leaf", seg=5))
    for k in range(4):
        x = -1.1 + .7 * k
        for s_ in (-1, 1):
            P.append(tube(f"lv{k}{s_}", [V(x, .12, .13), V(x + .35, .12 + .55 * s_, .13)], radius=.025, col="leaf", seg=4))
    # flor de maga (red, 5 petals) on the side
    fc = V(1.45, .55, .5)
    for k in range(5):
        a = 2 * math.pi * k / 5
        P.append(sphere(f"pet{k}", (.32, .2, .05), loc=fc + V(.25 * math.cos(a), 0, .25 * math.sin(a)), rot=(90, -math.degrees(a), 0), col="chili", seg=12, ring=6))
    P.append(cyl("stam", .04, .03, .45, col="sun_yellow", seg=6)); P[-1].matrix_world = M(fc + V(0, -.05, 0), (.3, -1, .4))
    P.append(sphere("stamt", (.07,) * 3, loc=fc + V(.13, -.47, .18), col="sun_yellow", seg=8, ring=5))
    P.append(cyl("fstem", .04, .04, .5, loc=fc - V(0, 0, .5), col="leaf", seg=6))
    # body: squat frog (head+body one blob), tilted back a bit
    bz = .16
    body = fringe_body("body", ellip_prof(1.0, 1.85, p=.75), 1.85, 6, ["wood", "brown", "wood", "wood", "brown", "wood"], matrix=M(V(0, .15, bz), (0, .18, 1)),
                       seg=26, flare=.07, tooth=.05, seed=2701, sx=1.12, sy=.92)
    P += body
    btree = bvh_of(body)
    P += scatter("mark", btree, V(0, .15, 1.2), 12, "brown", 2702, r=(.06, .11), zr=(-.2, .9), yaw=(-3, 3), avoid=[(V(0, -.8, 1.2), .8)])
    # eye bulbs on top
    hc = V(0, -.05, 1.45)
    balls = []
    for s_ in (-1, 1):
        b = sphere(f"bulb{s_}", (.4, .36, .38), loc=hc + V(.46 * s_, -.15, .45), col="wood", seg=18, ring=10); P.append(b); balls.append(b)
    P += eyes2("e", bvh_of(balls), hc + V(0, -.15, .5), dx=.46, dz=0, size=.3, iris="tangerine", lid="wood", open_=.88, tilt=4, lash=True,
               brow=True, brow_h=1.35, brow_tilt=12, brow_col="brown", look=(.2, .25))
    # face plate + big smile line
    fp = plate("face", hc, r=(.85, .3, .42), col="cream", fwd_off=.62); P.append(fp)
    tree = bvh_of([fp])
    P += mouth2("m", tree, hc + V(0, -3, -.05), w=.75, h=.14, smile=1.8, col="ink", tongue=False, teeth=0)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.66 * s_, -3, .02), size=.1)
    # the giant vocal sac (glossy, with highlight)
    sc = hc + V(0, -.85, -.55)
    P.append(sphere("sac", (.74, .6, .6), loc=sc, col="bubblegum", seg=24, ring=14))
    P.append(sphere("sach", (.18, .08, .1), loc=sc + V(-.3, -.5, .22), rot=(0, 0, -20), col="eye_white", seg=12, ring=6))
    P.append(sphere("sach2", (.06, .04, .05), loc=sc + V(-.12, -.56, .34), col="eye_white", seg=8, ring=5))
    # sound waves + CO-QUÍ text (neon)
    for k in range(3):
        r = .45 + .32 * k
        w = torus(f"wave{k}", r, .045, col="neon_cyan", seg=20, mseg=5, arc=110)
        w.matrix_world = Matrix.Translation(sc + V(.85, -.15, .1)) @ Matrix.Rotation(math.radians(-55), 4, 'Z') @ Matrix.Rotation(math.radians(90), 4, 'X') @ Matrix.Rotation(math.radians(-55), 4, 'Z')
        G.append(w)
        w2 = torus(f"wavel{k}", r, .045, col="neon_cyan", seg=20, mseg=5, arc=110)
        w2.matrix_world = Matrix.Translation(sc + V(-.85, -.15, .1)) @ Matrix.Rotation(math.radians(55), 4, 'Z') @ Matrix.Rotation(math.radians(90), 4, 'X') @ Matrix.Rotation(math.radians(125), 4, 'Z')
        G.append(w2)
    t = text_mesh("txt", "CO-QUÍ!", size=.5, extrude=.06, col="sun_yellow", bevel=.01, res=3)
    t.matrix_world = Matrix.Translation((.15, -.7, 3.25)) @ Matrix.Rotation(math.radians(8), 4, 'Y') @ Matrix.Rotation(math.radians(90), 4, 'X'); P.append(t)
    # legs: front arms with toe pads, folded back legs
    for s_ in (-1, 1):
        a = V(.62 * s_, -.55, .85); b = V(.8 * s_, -.95, .2)
        P += limb(f"farm{s_}", a, b, .14, .11, 2, ["wood", "brown"], seed=2703 + s_, seg=12)
        for j in range(3):
            ang = math.radians(-35 + 35 * j) * s_
            tip = b + V(math.sin(ang) * .28, -math.cos(ang) * .28, -.06)
            P.append(tube(f"ft{s_}{j}", [b, tip], radius=.04, col="wood", seg=6))
            P.append(sphere(f"pad{s_}{j}", (.07, .07, .05), loc=tip, col="peach", seg=10, ring=6))
        th = V(.95 * s_, .2, .55)
        P.append(sphere(f"thigh{s_}", (.42, .62, .38), loc=th, rot=(0, 0, 15 * s_), col="wood", seg=18, ring=10))
        P += fringe_body(f"thf{s_}", ellip_prof(.38, .9, p=.8), .9, 2, ["brown", "wood"], matrix=M(th + V(0, .45, -.1), (0, -1, 0)), seg=16, flare=.08, tooth=.05, seed=2705 + s_)
        fb = V(1.1 * s_, -.35, .17)
        for j in range(3):
            ang = math.radians(-20 + 30 * j) * s_
            tip = fb + V(math.sin(ang) * .35 * s_ * s_, -math.cos(ang) * .35, -.03)
            P.append(tube(f"bt{s_}{j}", [fb, tip], radius=.045, col="wood", seg=6))
            P.append(sphere(f"bpad{s_}{j}", (.08, .08, .05), loc=tip, col="peach", seg=10, ring=6))
    P += hook("hook", hc + V(0, .2, .82), s=.9)
    return P + G, {"glow": G}

# ============================================================================= 8. MATECITO TERMERO (rare, Uruguay)
def matecito_termero():
    """RARE - an Uruguayan mate (calabaza, silver virola, bombilla, yerba) walking with the termo under his arm.
    Joke: 'termo bajo el brazo, hasta en la playa'."""
    P = []; G = []
    z0 = .55; H = 2.35
    def prof(z):
        bulb = 1.0 * math.sqrt(max(0.0, 1 - ((z - .95) / 1.0) ** 2))
        neck = .66 + .06 * max(0.0, (z - 1.9) / .45)
        return max(bulb, neck if z > 1.1 else 0.0, .12)
    body = fringe_body("gourd", prof, H, 7, ["brown", "wood_dark", "brown", "brown", "wood_dark", "brown", "brown"], matrix=M(V(0, 0, z0)), seg=28, flare=.07, tooth=.05, seed=2801)
    P += body
    top = z0 + H
    P.append(torus("virola", .74, .09, loc=(0, 0, top - .02), col="silver", seg=36, mseg=8))
    P.append(cyl("virolab", .74, .74, .22, loc=(0, 0, top - .22), col="silver", seg=36, bevel=.02))
    for k in range(18):   # engraved dots on the virola
        a = 2 * math.pi * k / 18
        P.append(sphere(f"vd{k}", (.03,) * 3, loc=(.755 * math.cos(a), .755 * math.sin(a), top - .12), col="gold", seg=6, ring=4))
    # yerba mound + foam + bombilla
    P.append(sphere("yerba", (.66, .66, .26), loc=(0, 0, top + .02), col="leaf", seg=22, ring=10))
    P.append(sphere("yerba2", (.4, .35, .2), loc=(-.18, .12, top + .14), col="leaf_dark", seg=14, ring=8))
    for k in range(9):
        a = 2 * math.pi * k / 9
        P.append(sphere(f"yb{k}", (.08, .08, .05), loc=(.4 * math.cos(a), .4 * math.sin(a), top + .2), col="lime", seg=8, ring=5))
    bd = V(.35, .15, 1).normalized(); b0 = V(.12, .05, top - .2)
    P.append(cyl("bomb", .055, .055, 1.25, col="silver", seg=10)); P[-1].matrix_world = M(b0, bd)
    btip = b0 + bd * 1.25
    P.append(tube("bombt", [btip, btip + V(.06, 0, .12), btip + V(.2, 0, .18)], radius=.06, col="gold", seg=8))
    P.append(torus("bombr", .08, .025, col="gold", seg=12, mseg=4)); P[-1].matrix_world = M(b0 + bd * .95, bd)
    for k in range(3):   # steam puffs
        P.append(sphere(f"steam{k}", (.13 + .04 * k,) * 3, loc=(-.35 + .1 * k, -.1, top + .55 + .32 * k), col="eye_white", seg=12, ring=8))
    # face on the bulb
    hc = V(0, 0, z0 + 1.0)
    fp = plate("face", hc, r=(.82, .3, .64), col="wood", fwd_off=.86); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .16), dx=.31, dz=0, size=.25, iris="sky", lid="brown", open_=.6, tilt=-4, lash=True,
               brow=True, brow_h=1.5, brow_tilt=-8, brow_col="chocolate", look=(-.15, .15))
    P += mouth2("m", tree, hc + V(0, -3, -.27), w=.36, h=.17, smile=1.5, col="ink", tongue=True, teeth=2)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.52 * s_, -3, -.1), size=.1)
    # termo under the left arm (big, leaning)
    tc = V(-1.15, .1, 1.35); td = V(.42, .25, 1).normalized()
    P.append(cyl("termo", .38, .38, 1.4, col="silver", seg=26, bevel=.05)); P[-1].matrix_world = M(tc - td * .72, td)
    P.append(cyl("termob", .39, .39, .22, col="jade", seg=26, bevel=.03)); P[-1].matrix_world = M(tc - td * .74, td)
    P.append(cyl("termoc", .39, .36, .34, col="jade", seg=26, bevel=.05)); P[-1].matrix_world = M(tc + td * .62, td)
    P.append(cyl("termosp", .1, .08, .14, col="ink", seg=12)); P[-1].matrix_world = M(tc + td * .94 + V(.12, 0, 0), td + V(.6, 0, 0))
    hb = torus("termoh", .32, .07, col="jade", seg=16, mseg=5, arc=180)
    hb.matrix_world = M(tc + td * .1 + V(-.36, 0, 0), V(0, 1, 0)) @ Matrix.Rotation(math.radians(90), 4, 'Z'); P.append(hb)
    for k in (-.35, .35):
        P.append(torus(f"termoband{k}", .385, .035, col="jade", seg=26, mseg=4)); P[-1].matrix_world = M(tc + td * k, td)
    P += limb("armL", V(-.85, -.1, 1.75), V(-1.15, -.45, 1.55), .14, .12, 2, ["wood_dark", "brown"], seed=2802, seg=12)
    P += hand("hL", V(-.95, -.5, 1.25), d=(.4, -.2, .3), s=.17, col="wood")
    # right arm: thumbs up
    P += arm("armR", V(.85, -.1, 1.6), V(1.3, -.45, 2.05), r=.14, cols=("wood_dark", "brown"), hand_col="wood", hd=(0, 0, 1), s=.17, seed=2803, fingers=1)
    G += [sparkle(f"sp{k}", loc, s=.16) for k, loc in enumerate((V(-1.75, -.4, 2.3), V(-.6, -.6, 3.75), V(1.6, -.5, 2.7)))]
    P += legs2("leg", V(-.4, -.05, .65), V(.4, -.05, .65), r=.15, cols=("wood_dark", "brown"), shoe_col="sky", sole="eye_white", s=.85, seed=2804)
    P += hook("hook", V(0, .35, top + .3), s=.9)
    return P + G, {"glow": G}


# ============================================================================= 9. GALLO PINTÓN (rare, Nicaragua)
def gallo_pinton():
    """RARE - a rooster whose plumage IS gallo pinto (white rice speckled with red beans), crowing at dawn with breakfast ready.
    Joke: 'canta a las 5 a.m. y ya trae el desayuno'."""
    P = []; G = []
    bz = .55; H = 2.4
    body = fringe_body("body", ellip_prof(1.0, H, p=.85), H, 7, ["white", "cream", "white", "white", "cream", "white", "white"], matrix=M(V(0, .05, bz), (0, .12, 1)),
                       seg=28, flare=.08, tooth=.06, seed=2901, sx=.95, sy=1.0)
    P += body
    btree = bvh_of(body)
    hc = V(0, -.05, bz + 1.7)
    fp = plate("face", hc, r=(.66, .3, .55), col="white", fwd_off=.58); P.append(fp)
    tree = bvh_of([fp])
    # beans speckles everywhere except the face
    P += scatter("bean", btree, V(0, .05, bz + 1.1), 46, "red_dark", 2902, r=(.07, .1), zr=(-.85, .95), yaw=(-3.1, 3.1), th=.04,
                 avoid=[(hc + V(0, -.65, 0), .62)])
    P += scatter("beanb", btree, V(0, .05, bz + 1.1), 14, "brown", 2903, r=(.06, .09), zr=(-.85, .95), yaw=(-3.1, 3.1), th=.04,
                 avoid=[(hc + V(0, -.65, 0), .62)])
    # crowing face: happy closed eyes, open beak
    P += eyes2("e", tree, hc + V(0, 0, .17), dx=.27, dz=0, size=.22, iris="chocolate", lid="white", open_=.3, tilt=0, lash=True,
               brow=True, brow_h=1.7, brow_tilt=14, brow_col="red_dark", look=(0, .3))
    bk = hc + V(0, -.88, -.12)
    up = cyl("beaku", .17, .01, .45, col="mango", seg=12); up.matrix_world = M(bk + V(0, 0, .04), (0, -1, .5)); P.append(up)
    lo = cyl("beakl", .14, .01, .36, col="gold_deep", seg=12); lo.matrix_world = M(bk + V(0, 0, -.06), (0, -1, -.45)); P.append(lo)
    P.append(sphere("beakin", (.12, .05, .08), loc=bk + V(0, -.08, -.01), col="tongue", seg=10, ring=6))
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.45 * s_, -3, -.05), size=.09)
    for k, s_ in enumerate((-1, 1)):   # wattles
        P.append(sphere(f"wat{k}", (.1, .08, .18), loc=bk + V(.07 * s_, .05, -.32), col="chili", seg=12, ring=8))
    # comb: 5 chunky lobes
    for k in range(5):
        x = -.36 + .18 * k; zz = .22 * math.sin(math.pi * (k + .5) / 5)
        P.append(sphere(f"comb{k}", (.13, .1, .24), loc=hc + V(x, -.05, .58 + zz), rot=(0, -20 + 10 * k, 0), col="chili", seg=12, ring=8))
    # tail: arching sickle feathers (beans + rice colours)
    tb = V(0, .9, bz + 1.15)
    cols = ["red_dark", "white", "brown", "red_dark", "white", "chili"]
    for k in range(6):
        a = math.radians(-40 + 16 * k)
        pts = [tb, tb + V(.5 * math.sin(a), .5, 1.0), tb + V(.95 * math.sin(a), .95, 1.6 - .08 * abs(k - 2.5)), tb + V(1.25 * math.sin(a), 1.45, 1.35 - .1 * abs(k - 2.5))]
        P.append(tube(f"tail{k}", pts, radius=.16, col=cols[k], seg=10, taper=[1, 1.1, .9, .35]))
    # wings: left holds a plate of gallo pinto with a fried egg, right flaps up
    wl = V(-.95, -.05, bz + 1.0)
    P += fringe_body("wingL", ellip_prof(.42, 1.1, p=.9), 1.1, 3, ["cream", "white", "cream"], matrix=M(wl, (-.55, -.6, .2)), seg=16, flare=.1, tooth=.06, seed=2904, sx=.55)
    pc = V(-1.45, -.95, bz + 1.0)
    P.append(cyl("plate", .5, .4, .08, loc=pc, rot=(10, 0, 0), col="eye_white", seg=26, bevel=.02))
    P.append(torus("platerim", .47, .03, loc=pc + V(0, 0, .07), rot=(10, 0, 0), col="sky", seg=26, mseg=4))
    rnd = random.Random(2905)
    for k in range(16):
        a = rnd.uniform(0, 2 * math.pi); r = rnd.uniform(0, .3)
        P.append(sphere(f"pin{k}", (.09, .09, .07), loc=pc + V(r * math.cos(a), r * math.sin(a), .12 + .1 * (1 - r / .3)), col="red_dark" if k % 3 == 0 else "white", seg=8, ring=5))
    P.append(sphere("egg", (.24, .2, .04), loc=pc + V(.12, -.15, .2), rot=(15, 0, 0), col="eye_white", seg=16, ring=6))
    P.append(sphere("yolk", (.09, .09, .06), loc=pc + V(.12, -.18, .24), col="sun_yellow", seg=12, ring=6))
    wr = V(.95, -.05, bz + 1.15)
    P += fringe_body("wingR", ellip_prof(.42, 1.15, p=.9), 1.15, 3, ["cream", "white", "cream"], matrix=M(wr, (.6, -.25, .75)), seg=16, flare=.1, tooth=.06, seed=2906, sx=.55)
    # little sun rising behind (5 a.m.) - neon
    G.append(torus("sun", .38, .06, loc=(1.35, .4, 3.55), rot=(90, 0, 0), col="neon_gold", seg=24, mseg=5))
    for k in range(8):
        a = 2 * math.pi * k / 8
        G.append(cyl(f"ray{k}", .04, .01, .22, col="neon_gold", seg=5)); G[-1].matrix_world = M(V(1.35, .4, 3.55) + V(.5 * math.cos(a), 0, .5 * math.sin(a)), (math.cos(a), 0, math.sin(a)))
    # legs + toes
    for s_ in (-1, 1):
        a = V(.38 * s_, 0, bz + .2); b = V(.45 * s_, -.1, .08)
        P.append(tube(f"leg{s_}", [a, b], radius=.08, col="mango", seg=8))
        for j in range(3):
            ang = math.radians(-35 + 35 * j)
            P.append(tube(f"toe{s_}{j}", [b, b + V(math.sin(ang) * .32, -math.cos(ang) * .32, -.04)], radius=.055, col="mango", seg=6, taper=[1, .7]))
        P.append(tube(f"toeb{s_}", [b, b + V(0, .2, -.04)], radius=.05, col="mango", seg=6))
    P += hook("hook", hc + V(0, .25, .98), s=.9)
    return P + G, {"glow": G}

# ============================================================================= 10. ARAÑITA ÑANDUTÍ (epic, Paraguay)
def aranita_nanduti():
    """EPIC - a sweet little spider weaving a ñandutí (Paraguayan 'spider-web' lace) on its wooden frame, needle in hand.
    Joke: 'ocho patitas, cero puntadas chuecas'."""
    P = []; G = []
    wc = V(0, .7, 2.55); WR = 1.65
    W = lambda x, z, y=0.0: wc + V(x, y, z)
    # wooden bastidor (embroidery frame) on two little feet
    fs = WR + .3
    for k, (x, z, sx, sz) in enumerate(((0, fs, 2 * fs + .3, .2), (0, -fs, 2 * fs + .3, .2), (fs, 0, .2, 2 * fs + .3), (-fs, 0, .2, 2 * fs + .3))):
        P.append(box(f"frame{k}", (sx, .2, sz), loc=W(x, z), col="wood", bevel=.05))
    for x in (-fs, fs):
        P.append(box(f"foot{x}", (.3, 1.0, .16), loc=(x, .7, .08), col="wood_dark", bevel=.05))
        P.append(box(f"post{x}", (.18, .18, wc.z - fs), loc=(x, .7, (wc.z - fs) / 2), col="wood_dark", bevel=.04))
    for k in range(4):   # threads from wheel to frame corners and sides
        a = math.pi / 4 + k * math.pi / 2
        P.append(tube(f"anch{k}", [W(WR * math.cos(a), WR * math.sin(a)), W(fs * 1.0 * (1 if math.cos(a) > 0 else -1), fs * (1 if math.sin(a) > 0 else -1))], radius=.012, col="eye_white", seg=4))
    # ñandutí wheel: rings, spokes and coloured motifs
    for r in (.25, .62, 1.02, 1.38, WR):
        t_ = torus(f"ring{r}", r, .022 if r < WR else .035, col="eye_white", seg=56, mseg=4); t_.matrix_world = M(wc, (0, -1, 0)); P.append(t_)
    NS = 24
    for k in range(NS):
        a = 2 * math.pi * k / NS
        P.append(tube(f"spoke{k}", [W(.25 * math.cos(a), .25 * math.sin(a)), W(WR * math.cos(a), WR * math.sin(a))], radius=.014, col="eye_white", seg=4))
    rain = ["fiesta_pink", "sun_yellow", "turquoise", "lime", "grape", "tangerine"]
    for k in range(12):   # inner petals (flower)
        a = 2 * math.pi * k / 12
        o = sphere(f"petal{k}", (.17, .045, .08), col=rain[k % 6], seg=10, ring=6)
        o.matrix_world = Matrix.Translation(W(.44 * math.cos(a), .44 * math.sin(a), -.01)) @ Matrix.Rotation(-a, 4, 'Y'); P.append(o)
    for k in range(NS):   # middle band: alternating wedges (lace fill)
        if k % 2: continue
        a0 = 2 * math.pi * k / NS + .03; a1 = 2 * math.pi * (k + 1) / NS - .03
        sl = slab(f"wed{k}", wedge(.68, .96, a0, a1, 4), thick=.03, col=rain[(k // 2) % 6], bevel=0)
        sl.matrix_world = Matrix.Translation(wc + V(0, -.01, 0)) @ Matrix.Rotation(math.radians(90), 4, 'X'); P.append(sl)
    for k in range(NS):   # outer band: little diamonds
        a = 2 * math.pi * (k + .5) / NS
        o = star_prism(f"dia{k}", 2, .13, .07, .03, col=rain[(k + 3) % 6], bevel=0)
        o.matrix_world = Matrix.Translation(W(1.2 * math.cos(a), 1.2 * math.sin(a), -.01)) @ Matrix.Rotation(math.radians(90), 4, 'X') @ Matrix.Rotation(a - math.pi / 2, 4, 'Z'); P.append(o)
    for k in range(NS):   # scalloped edge
        a = 2 * math.pi * (k + .5) / NS
        P.append(sphere(f"scal{k}", (.07, .03, .07), loc=W(1.52 * math.cos(a), 1.52 * math.sin(a), -.01), col=rain[k % 6], seg=8, ring=5))
    P.append(sphere("hub", (.13, .05, .13), loc=W(0, 0, -.02), col="fiesta_pink", seg=12, ring=6))
    # the spider (in front, lower half)
    sc = V(0, -.55, 1.0)
    abd = fringe_body("abd", ellip_prof(.85, 1.6, p=.9), 1.6, 5, ["grape", "lavender", "grape", "lavender", "grape"], matrix=M(sc + V(0, .55, -.65), (0, .45, 1)), seg=24, flare=.08, tooth=.06, seed=3001)
    P += abd
    head = fringe_body("head", ellip_prof(.68, 1.25, p=.85), 1.25, 3, ["lavender", "grape", "lavender"], matrix=M(sc + V(0, -.15, -.5), (0, -.25, 1)), seg=22, flare=.07, tooth=.05, seed=3002)
    P += head
    hc = sc + V(0, -.3, .15)
    fp = plate("face", hc, r=(.58, .26, .5), col="lavender", fwd_off=.42); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .12), dx=.24, dz=0, size=.22, iris="fiesta_pink", lid="grape", open_=.92, tilt=4, lash=True,
               brow=False, look=(.15, .3))
    P += mouth2("m", tree, hc + V(0, -3, -.24), w=.26, h=.13, smile=1.4, col="ink", tongue=True)
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.38 * s_, -3, -.1), size=.08)
    for k, (x, z) in enumerate(((-.3, .52), (-.12, .58), (.12, .58), (.3, .52))):   # 4 tiny extra eyes (it IS a spider)
        p, n = hit(bvh_of(head), hc + V(x, -3, z), V(0, 1, 0))
        if p is not None:
            P.append(sphere(f"xe{k}", (.065, .065, .04), loc=p + n * .03, col="ink", seg=10, ring=6))
            P.append(sphere(f"xh{k}", (.02, .02, .015), loc=p + n * .07 + V(-.015, 0, .02), col="eye_white", seg=6, ring=4))
    # 8 chubby legs with pompom feet; the front pair holds needle + thread
    legs = [((-.55, -.1, .1), (-1.25, -.35, .7), (-1.55, -.55, .05)), ((.55, -.1, .1), (1.25, -.35, .7), (1.55, -.55, .05)),
            ((-.6, .15, .05), (-1.4, .05, .55), (-1.75, .1, .03)), ((.6, .15, .05), (1.4, .05, .55), (1.75, .1, .03)),
            ((-.55, .4, 0), (-1.2, .55, .5), (-1.45, .8, .03)), ((.55, .4, 0), (1.2, .55, .5), (1.45, .8, .03))]
    for i, (a, b, c) in enumerate(legs):
        pts = [sc + V(*a) - V(0, 0, sc.z) + V(0, 0, .55), V(*b) + V(0, sc.y, 0), V(*c) + V(0, sc.y, 0)]
        P += striped_tube(f"leg{i}", pts, .11, ["grape", "lavender", "grape", "lavender"], seg=8, taper=lambda t: 1 - .3 * t)
        P.append(sphere(f"pom{i}", (.13,) * 3, loc=pts[-1] + V(0, 0, .06), col="fiesta_pink", seg=12, ring=8))
    for s_ in (-1, 1):   # front pair raised: knitting
        a = sc + V(.4 * s_, -.45, .0); b = sc + V(.75 * s_, -.85, .45); c = sc + V(.45 * s_, -1.0, .75)
        P += striped_tube(f"fleg{s_}", [a, b, c], .1, ["lavender", "grape", "lavender"], seg=8)
        P.append(sphere(f"fpom{s_}", (.12,) * 3, loc=c, col="fiesta_pink", seg=12, ring=8))
    nd0 = sc + V(.45, -1.02, .78)
    P.append(cyl("needle", .03, .005, .8, col="silver", seg=6)); P[-1].matrix_world = M(nd0 - V(-.3, 0, .5).normalized() * .1, (-.45, .15, .75))
    P.append(tube("thread", [nd0 + V(-.36, .1, .62), W(-.6, -.55, -.2), W(-.9, -.6, -.05)], radius=.02, col="fiesta_pink", seg=5))
    P.append(sphere("ball", (.22,) * 3, loc=(1.2, -1.25, .22), col="turquoise", seg=14, ring=10))
    P.append(tube("ballthread", [V(1.2, -1.25, .44), V(.9, -1.15, .55), sc + V(.45, -1.0, .75)], radius=.015, col="turquoise", seg=4))
    G += stars_ring("st", wc + V(0, -.4, 0), 2.1, n=5, s=.16, col="neon_pink", tilt=0)
    P += hook("hook", W(0, fs + .12), s=1.0)
    return P + G, {"glow": G}

# ============================================================================= 11. PIQUERO PATAZUL (epic, Ecuador)
def piquero_patazul():
    """EPIC - a Galápagos blue-footed booby mid-courtship dance: one giant blue foot up, beak to the sky, wings out.
    Joke: 'presume las patas como si fueran tenis nuevos'."""
    P = []; G = []
    bz = .75; H = 2.3
    body = fringe_body("body", ellip_prof(.88, H, p=.9), H, 6, ["white", "cream", "white", "white", "cream", "white"], matrix=M(V(0, .1, bz), (0, .15, 1)),
                       seg=26, flare=.08, tooth=.06, seed=3101, sx=.95)
    P += body
    # back + wings brown (the booby's two-tone)
    P += fringe_body("back", ellip_prof(.78, 1.9, p=.9), 1.9, 4, ["wood", "brown", "wood", "brown"], matrix=M(V(0, .55, bz + .15), (0, .5, 1)), seg=22, flare=.08, tooth=.05, seed=3102, sx=.95, sy=.7)
    for s_ in (-1, 1):
        wb = V(.75 * s_, .25, bz + 1.55)
        P += fringe_body(f"wing{s_}", ellip_prof(.4, 1.6, p=.9), 1.6, 4, ["brown", "wood", "brown", "wood"], matrix=M(wb, (.9 * s_, .45, .35)), seg=16, flare=.1, tooth=.06, seed=3103 + s_, sx=.4)
    P += fringe_body("tail", ellip_prof(.28, .8, p=1), .8, 2, ["brown", "wood"], matrix=M(V(0, .75, bz + .2), (0, .9, -.3)), seg=14, flare=.08, tooth=.05, seed=3105)
    # head on a short neck, beak pointing to the sky (sky-pointing)
    hc = V(0, -.15, bz + 2.55)
    P += fringe_body("neck", lin_prof(.45, .42, .7), .7, 2, ["cream", "white"], matrix=M(V(0, 0, bz + 1.9), (0, -.2, 1)), seg=18, flare=.06, tooth=.04, seed=3106)
    P.append(sphere("head", (.6, .58, .6), loc=hc, col="cream", seg=22, ring=12))
    htree = bvh_of([P[-1]])
    P += scatter("streak", htree, hc, 12, "wood", 3107, r=(.03, .08), zr=(-.2, 1.0), yaw=(-3, 3), avoid=[(hc + V(0, -.6, 0), .45)])
    fp = plate("face", hc, r=(.5, .2, .42), col="eye_white", fwd_off=.42); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .14), dx=.29, dz=0, size=.21, iris="sun_yellow", lid="cream", open_=.75, tilt=-6, lash=True,
               brow=True, brow_h=1.45, brow_tilt=-10, brow_col="wood", look=(0, .55))
    P.append(sphere("mask", (.2, .1, .16), loc=hc + V(-.04, -.54, -.28), rot=(-20, 0, 0), col="donkey_dark", seg=16, ring=8))
    beak = cyl("beak", .14, .025, 1.15, col="donkey_grey", seg=16); beak.matrix_world = M(hc + V(-.04, -.56, -.3), (-.55, -.8, .5)); P.append(beak)
    P.append(tube("beakline", [hc + V(-.1, -.66, -.33), hc + V(-.38, -1.05, -.08), hc + V(-.66, -1.43, .17)], radius=.018, col="ink_soft", seg=5))
    for s_ in (-1, 1):
        P += blush2(f"bl{s_}", tree, hc + V(.36 * s_, -3, -.15), size=.08)
    # legs + GIANT turquoise feet: left planted, right lifted high
    def foot(name, ank, yaw=0.0, pitch=0.0, s=1.0):
        out = []
        R_ = Matrix.Rotation(math.radians(yaw), 4, 'Z') @ Matrix.Rotation(math.radians(pitch), 4, 'X')
        web = [(0, .05), (-.42, -.6), (-.2, -.72), (0, -.68), (.2, -.72), (.42, -.6)]
        o = slab(name + "web", [(x * s, y * s) for x, y in web], thick=.09 * s, col="turquoise", bevel=.035)
        o.matrix_world = Matrix.Translation(ank) @ R_; out.append(o)
        for k, (x, y) in enumerate(((-.42, -.62), (0, -.72), (.42, -.62))):
            out.append(tube(f"{name}toe{k}", [ank + (R_ @ V(0, 0, .04)), ank + (R_ @ V(x * s, y * s, .06))], radius=.075 * s, col="turquoise", seg=8, taper=[1, .8]))
            out.append(sphere(f"{name}nail{k}", (.07 * s,) * 3, loc=ank + (R_ @ V(x * s, (y - .05) * s, .06)), col="sky", seg=8, ring=6))
        return out
    P.append(tube("legL", [V(-.35, .05, bz + .2), V(-.4, -.05, .45), V(-.45, -.1, .08)], radius=.11, col="turquoise", seg=10))
    P += foot("fL", V(-.45, -.1, .05), yaw=-12, s=1.15)
    P.append(tube("legR", [V(.35, .05, bz + .2), V(.85, -.4, .85), V(1.15, -.75, 1.2)], radius=.11, col="turquoise", seg=10))
    P += foot("fR", V(1.15, -.75, 1.2), yaw=25, pitch=-60, s=1.25)
    for k, loc in enumerate((V(1.45, -1.2, 1.35), V(.55, -1.25, 1.55), V(1.65, -.9, .7), V(-1.1, -1.1, .3))):
        G.append(star_prism(f"spark{k}", 4, .17, .05, .04, loc=loc, rot=(90, 0, 15 * k), col="neon_cyan", bevel=0))
    G += stars_ring("st", V(0, -.1, bz + 3.6), .55, n=3, s=.12, col="neon_pink")
    P += hook("hook", hc + V(0, .3, .58), s=.9)
    return P + G, {"glow": G}

# ============================================================================= 12. ALPACA ESPONJADA (epic, Perú)
def alpaca_esponjada():
    """EPIC - a Peruvian alpaca whose wool puffed up into a giant cloud after a tiny rain shower; chullo with ear flaps and pompoms.
    Joke: 'llovió un ratito y ahora es pura nube'."""
    P = []; G = []
    # cloud body: cluster of fringe puffs
    rnd = random.Random(3201)
    puffs = [(0, .2, 1.45, .95), (-.85, .3, 1.35, .78), (.85, .35, 1.35, .78), (-.45, -.25, 1.15, .75), (.45, -.2, 1.15, .75),
             (0, .55, 2.05, .75), (-.7, .55, 1.95, .62), (.7, .6, 1.95, .62), (-1.25, .35, 1.0, .55), (1.25, .4, 1.0, .55), (0, .9, 1.25, .7)]
    for i, (x, y, z, r) in enumerate(puffs):
        P += fringe_body(f"puff{i}", ellip_prof(r, 2 * r, p=.9), 2 * r, 3, ["white", "cream", "white"] if i % 2 else ["cream", "white", "cream"],
                         matrix=M(V(x, y, z - r)), seg=20, flare=.1, tooth=.07, seed=3202 + i, rings_core=6, seg_core=14)
    # neck + head
    P += fringe_body("neck", lin_prof(.42, .38, 1.1), 1.1, 3, ["cream", "white", "cream"], matrix=M(V(0, -.55, 1.7), (0, -.15, 1)), seg=18, flare=.08, tooth=.05, seed=3220)
    hc = V(0, -.75, 3.15)
    P += fringe_body("head", ellip_prof(.52, 1.1, p=.9), 1.1, 3, ["white", "cream", "white"], matrix=M(hc - V(0, 0, .5), (0, -.1, 1)), seg=20, flare=.07, tooth=.05, seed=3221, sy=.92)
    fp = plate("face", hc + V(0, 0, -.05), r=(.5, .25, .45), col="cream", fwd_off=.38); P.append(fp)
    tree = bvh_of([fp])
    P += eyes2("e", tree, hc + V(0, 0, .12), dx=.22, dz=0, size=.2, iris="chocolate", lid="cream", open_=.82, tilt=8, lash=True,
               brow=False, look=(.1, .25))
    mz = hc + V(0, -.6, -.32)
    P.append(sphere("muzzle", (.3, .22, .2), loc=mz, col="white", seg=16, ring=10))
    P.append(tube("nose", [mz + V(-.08, -.19, .06), mz + V(0, -.21, .03), mz + V(.08, -.19, .06)], radius=.025, col="ink", seg=5))
    P.append(tube("lip", [mz + V(-.13, -.17, -.06), mz + V(-.06, -.21, -.09), mz + V(0, -.2, -.05), mz + V(.06, -.21, -.09), mz + V(.13, -.17, -.06)], radius=.022, col="ink", seg=5))
    for s_ in (-1, 1):
        P.append(box(f"tooth{s_}", (.06, .03, .07), loc=mz + V(.035 * s_, -.21, -.12), col="eye_white", bevel=.012))
        P += blush2(f"bl{s_}", tree, hc + V(.36 * s_, -3, -.12), size=.08)
    # topknot puff (bangs) + chullo + ears through the holes
    P += fringe_body("topk", ellip_prof(.42, .7, p=.9), .7, 2, ["white", "cream"], matrix=M(hc + V(0, -.12, .32)), seg=18, flare=.12, tooth=.08, seed=3222)
    cz = hc + V(0, .02, .62)
    bands = ["fiesta_pink", "sun_yellow", "turquoise", "chili", "grape"]
    for k in range(5):
        r0 = .5 - .07 * k; r1 = .5 - .07 * (k + 1)
        P.append(cyl(f"chul{k}", r0, r1, .14, loc=cz + V(0, 0, .14 * k), col=bands[k], seg=22, bevel=.015))
    for k in range(10):   # knit dots on the first band
        a = 2 * math.pi * k / 10
        P.append(sphere(f"knit{k}", (.035,) * 3, loc=cz + V(.5 * math.cos(a), .5 * math.sin(a), .07), col="eye_white", seg=6, ring=4))
    P.append(sphere("pompon", (.16,) * 3, loc=cz + V(0, 0, .8), col="fiesta_pink", seg=14, ring=10))
    for s_ in (-1, 1):
        fl = slab(f"flap{s_}", [(-.17, 0), (.17, 0), (.1, -.4), (0, -.46), (-.1, -.4)], thick=.06, col="turquoise", bevel=.02)
        fl.matrix_world = Matrix.Translation(cz + V(.48 * s_, -.05, .02)) @ Matrix.Rotation(math.radians(90), 4, 'Z') @ Matrix.Rotation(math.radians(90 - 10 * s_), 4, 'X'); P.append(fl)
        tp = cz + V(.5 * s_, -.05, -.45)
        P += striped_tube(f"braid{s_}", [tp, tp + V(.05 * s_, -.05, -.35), tp + V(.02 * s_, -.08, -.6)], .04, ["sun_yellow", "fiesta_pink", "sun_yellow"], seg=6)
        P.append(sphere(f"tpom{s_}", (.11,) * 3, loc=tp + V(.02 * s_, -.08, -.68), col="sun_yellow", seg=12, ring=8))
        eb = cz + V(.25 * s_, .05, .25)
        ear = cyl(f"ear{s_}", .12, .02, .55, col="cream", seg=12); ear.matrix_world = M(eb, (.45 * s_, 0, 1)); P.append(ear)
        P.append(ear_inner(f"eari{s_}", eb + V(0, -.07, 0), (.45 * s_, 0, 1), .22, .06, col="bubblegum", off=.03))
    # legs + hooves
    for k, (x, y) in enumerate(((-.6, -.35), (.6, -.35), (-.55, .75), (.55, .75))):
        P += limb(f"leg{k}", V(x, y, .75), V(x, y - .05, .18), .14, .12, 2, ["cream", "white"], seed=3230 + k, seg=12)
        P.append(cyl(f"hoof{k}", .15, .14, .18, loc=(x, y - .05, 0), col="wood_dark", seg=14, bevel=.03))
        P.append(box(f"hoofc{k}", (.02, .16, .16), loc=(x, y - .17, .09), col="ink_soft", bevel=0))
    # the little rain cloud that caused it
    rc = V(-1.45, -.4, 4.05)
    for k, (x, z, r) in enumerate(((0, 0, .3), (.3, .05, .24), (-.28, -.02, .22), (.08, .2, .22))):
        P.append(sphere(f"rcl{k}", (r, r * .85, r * .8), loc=rc + V(x, 0, z), col="donkey_grey", seg=14, ring=8))
    for k, (x, z) in enumerate(((-.18, -.45), (.08, -.6), (.3, -.42))):
        P.append(sphere(f"drop{k}", (.06, .06, .1), loc=rc + V(x, -.05, z), col="sky", seg=10, ring=6))
    G += stars_ring("st", V(0, -.1, 1.6), 1.9, n=4, s=.15, col="neon_pink")
    P += hook("hook", cz + V(0, 0, .98), s=.85)
    return P + G, {"glow": G}

SET = {"coqui_bocina": coqui_bocina, "matecito_termero": matecito_termero, "gallo_pinton": gallo_pinton,
       "aranita_nanduti": aranita_nanduti, "piquero_patazul": piquero_patazul, "alpaca_esponjada": alpaca_esponjada}
RARITY = {"coqui_bocina": "rare", "matecito_termero": "rare", "gallo_pinton": "rare",
          "aranita_nanduti": "epic", "piquero_patazul": "epic", "alpaca_esponjada": "epic"}
CAM = {"coqui_bocina": (10, 10), "matecito_termero": (16, 10), "gallo_pinton": (30, 10), "aranita_nanduti": (14, 8),
       "piquero_patazul": (20, 9), "alpaca_esponjada": (22, 9)}
