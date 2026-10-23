"""Shared helpers for the Colección LatAm piñatas (latam.py, latam2.py, latam3.py)."""
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


# ----------------------------------------------------------------------------- shared helpers
def hook(name, top, s=1.0, knot="fiesta_pink", ring="gold"):
    """Hanging point like a real piñata: paper knot + twisted string + gold ring (faces the camera 3/4)."""
    top = Vector(top)
    P = [cyl(name + "k", .13 * s, .07 * s, .18 * s, loc=top - V(0, 0, .06 * s), col=knot, seg=12, bevel=.02)]
    P.append(tube(name + "s", [top + V(0, 0, .1 * s), top + V(.02, 0, .2 * s), top + V(0, 0, .3 * s)], radius=.035 * s, col="eye_white", seg=6))
    P.append(torus(name + "r", .17 * s, .045 * s, loc=top + V(0, 0, .3 * s + .16 * s), rot=(90, 0, 25), col=ring, seg=22, mseg=6))
    return P

def scatter(name, tree, center, n, col, seed, r=(.06, .1), zr=(-1, 1), yaw=(-1.4, 1.4), th=.025, avoid=None):
    """Little decals (spots/beans/toast marks) sprayed on a surface by rays aimed at `center`."""
    rnd = random.Random(seed); out = []
    c = Vector(center)
    for k in range(n * 3):
        if len(out) >= n: break
        a = rnd.uniform(*yaw) - math.pi / 2; e = rnd.uniform(*zr) * .9
        d = V(math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e))
        p, nn = hit(tree, c + d * 6, -d)
        if p is None: continue
        if avoid and any((p - Vector(q)).length < rr for q, rr in avoid): continue
        t1, t2, n3 = basis(nn)
        o = sphere(f"{name}{k}", (rnd.uniform(*r), rnd.uniform(*r) * .6, th), col=col, seg=10, ring=5)
        place(o, p + nn * th * .2, t1, t2, n3, roll=rnd.uniform(0, 180)); out.append(o)
    return out

def legs2(name, hip_l, hip_r, foot_z=0.0, r=.17, cols=("brown", "wood"), shoe_col="eye_white", sole="fiesta_pink", s=.85, seed=0, spread=.05):
    P = []
    for s_, hp in ((-1, hip_l), (1, hip_r)):
        hp = Vector(hp); ft = V(hp.x + spread * s_, hp.y - .05, foot_z + .2 * s)
        P += limb(f"{name}{s_}", hp, ft, r, r * .9, 2, list(cols), seed=seed + (1 if s_ > 0 else 0), seg=12)
        P += shoe(f"{name}sh{s_}", (ft.x, ft.y, foot_z), col=shoe_col, sole=sole, s=s)
    return P

def arm(name, a, b, r=.15, cols=("mango", "tangerine"), hand_col="mango", hd=None, s=.2, seed=0, fingers=3):
    a, b = Vector(a), Vector(b)
    P = limb(name, a, b, r, r * .85, 2, list(cols), seed=seed, seg=12)
    P += hand(name + "h", b + (b - a).normalized() * s * .6, d=hd or (b - a), s=s, col=hand_col, fingers=fingers)
    return P

def maraca(name, grip, d, s=1.0, cols=("chili", "sun_yellow", "lime")):
    d = Vector(d).normalized(); g = Vector(grip)
    P = [cyl(name + "h", .05 * s, .06 * s, .55 * s, col="wood", seg=8)]; P[-1].matrix_world = M(g - d * .2 * s, d)
    hc = g + d * .52 * s
    P += striped_tube(name + "b", [hc - d * .26 * s, hc - d * .1 * s, hc + d * .1 * s, hc + d * .24 * s], .26 * s, list(cols), seg=14,
                      taper=lambda t: max(.25, math.sin(math.pi * min(max(t, .04), .96)) ** .6))
    for k in range(6):
        a = 2 * math.pi * k / 6
        side = d.cross(V(0, 0, 1)).normalized() if abs(d.z) < .95 else V(1, 0, 0); up = side.cross(d)
        P.append(sphere(f"{name}dot{k}", (.045 * s,) * 3, loc=hc + (side * math.cos(a) + up * math.sin(a)) * .245 * s, col="eye_white", seg=8, ring=5))
    return P

def note(name, loc, s=.3, col="neon_cyan", rz=0):
    p = Vector(loc); out = []
    out.append(sphere(name + "h", (s * .5, s * .22, s * .38), loc=p, rot=(0, -25, rz), col=col, seg=12, ring=6))
    out.append(cyl(name + "s", s * .07, s * .07, s * 1.5, loc=p + V(s * .42, 0, 0), col=col, seg=6))
    out.append(ribbon(name + "f", [p + V(s * .42, 0, s * 1.5), p + V(s * .75, 0, s * 1.15), p + V(s * .78, 0, s * .8)], width=s * .22, normal=(0, -1, 0), col=col, thick=s * .08))
    return out

def face_std(name, tree, hc, dx=.3, dz=.1, size=.26, iris="chocolate", lid=None, open_=.9, tilt=0, brow_col="ink", brow_tilt=0,
             look=(0, 0), mouth_dz=-.32, mw=.32, mh=.16, smile=1.0, tongue=True, teeth=0, blush_dx=.5, blush_dz=-.15, shape="D", lash=True, brow=True, lower=None):
    P = eyes2(name + "e", tree, hc + V(0, 0, dz), dx=dx, dz=0, size=size, iris=iris, lid=lid, open_=open_, tilt=tilt, lash=lash,
              brow=brow, brow_h=1.45, brow_tilt=brow_tilt, brow_col=brow_col, look=look, lower=lower)
    P += mouth2(name + "m", tree, hc + V(0, -3, mouth_dz), w=mw, h=mh, smile=smile, col="ink", tongue=tongue, teeth=teeth, shape=shape)
    for s_ in (-1, 1):
        P += blush2(f"{name}bl{s_}", tree, hc + V(blush_dx * s_, -3, blush_dz), size=.1)
    return P

def place_text(o, p, n, push=.0):
    """Place a text mesh (local XY, facing +Z) on a surface point with normal n, reading left->right from the front."""
    t1, t2, n3 = basis(n); right = t2.cross(n3).normalized()
    place(o, Vector(p) + n3 * push, right, t2, n3); return o

def bend(objs, Rb, z0=0.0, axis_x=0.0):
    """Bend meshes (already in world coords) built along +Z towards +X: arc of radius Rb starting at height z0."""
    for o in objs:
        me = o.data
        for v in me.vertices:
            x, y, z = v.co
            if z <= z0: continue
            th = (z - z0) / Rb; d = Rb - (x - axis_x)
            v.co = Vector((axis_x + Rb - d * math.cos(th), y, z0 + d * math.sin(th)))
        me.update()
    return objs

def wedge(r0, r1, a0, a1, n=6):
    """2D annular wedge polygon."""
    pts = [(r1 * math.cos(a0 + (a1 - a0) * k / n), r1 * math.sin(a0 + (a1 - a0) * k / n)) for k in range(n + 1)]
    pts += [(r0 * math.cos(a1 - (a1 - a0) * k / n), r0 * math.sin(a1 - (a1 - a0) * k / n)) for k in range(n + 1)]
    return pts


def fringe_strip(name, p0, p1, h=.25, n=None, col="fiesta_pink", thick=.03, drop=0.0):
    """Flat paper-fringe garland (zig-zag teeth hanging down) from p0 to p1, standing vertical."""
    p0, p1 = Vector(p0), Vector(p1); d = p1 - p0; L = d.length; X = d.normalized()
    Y = V(0, 0, 1); Z = X.cross(Y).normalized(); Y = Z.cross(X).normalized()
    n = n or max(4, int(L / .12) * 2)
    pts = [(0, 0), (L, 0)]
    for i in range(n, -1, -1):
        pts.append((L * i / n, -h if i % 2 == 0 else -h * .4))
    pts = pts[:2] + pts[3:-1]
    mtx = Matrix.Translation(p0 - Y * drop) @ Matrix((X, Y, Z)).transposed().to_4x4()
    return slab(name, pts, thick=thick, col=col, bevel=0, matrix=mtx)

def sparkle(name, loc, s=.2, col="neon_gold"):
    return star_prism(name, 4, s, s * .3, s * .25, loc=loc, rot=(90, 0, 0), col=col, bevel=0)

def pennants(name, p0, p1, n=9, sag=.4, s=.28, cols=("fiesta_pink", "sun_yellow", "turquoise", "lime", "grape", "tangerine")):
    """String of triangular bandeirinhas / banderitas between two points (sagging)."""
    p0, p1 = Vector(p0), Vector(p1); out = []
    pts = [p0.lerp(p1, k / 16) - V(0, 0, sag * math.sin(math.pi * k / 16)) for k in range(17)]
    out.append(tube(name + "str", pts, radius=.018, col="eye_white", seg=4))
    X = (p1 - p0).normalized(); Z = X.cross(V(0, 0, 1)).normalized()
    for k in range(n):
        t = (k + .5) / n; c = p0.lerp(p1, t) - V(0, 0, sag * math.sin(math.pi * t))
        tri = [(-s / 2, 0), (s / 2, 0), (0, -s * 1.2)]
        mtx = Matrix.Translation(c) @ Matrix((X, Z.cross(X).normalized(), Z)).transposed().to_4x4()
        out.append(slab(f"{name}{k}", tri, thick=.02, col=cols[k % len(cols)], bevel=0, matrix=mtx))
    return out
