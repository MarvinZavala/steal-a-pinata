"""kawaii: upgraded face + body helpers for fase 3 (Temporada Meme 2 + animal polish).
Same palette/UV pipeline as plib (paint() per part). Everything faces -Y by default.
- eye2():  sclera + big iris + pupil + 2 highlights + skin eyelid (cut + tilt) + lash line + brow
- plate(): smooth face/muzzle patch that pokes through the fringe so features never get eaten by teeth
- mouth2(): open cartoon mouth (dark cavity + lip rim + tongue + optional teeth)
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix, Quaternion
from mathutils.bvhtree import BVHTree
from plib import sphere, tube, paint, bm_to_obj, cyl, torus, box, PALETTE, PIDX

def V(*a): return Vector(a)

_bvh = {}
def bvh_of(objs):
    key = tuple(id(o) for o in objs)
    bpy.context.view_layer.update()
    bm = bmesh.new()
    for o in objs:
        t = bmesh.new(); t.from_mesh(o.data); t.transform(o.matrix_world)
        me = bpy.data.meshes.new("_tmp"); t.to_mesh(me); t.free(); bm.from_mesh(me); bpy.data.meshes.remove(me)
    tree = BVHTree.FromBMesh(bm); bm.free()
    return tree

def hit(tree, origin, direction):
    d = Vector(direction).normalized()
    r = tree.ray_cast(Vector(origin), d)
    if r[0] is None: return None, None
    n = r[1]
    if n.dot(d) > 0: n = -n
    return r[0], n

def basis(n, up_hint=(0, 0, 1)):
    n = Vector(n).normalized(); up = Vector(up_hint)
    t1 = n.cross(up)
    if t1.length < 1e-4: t1 = n.cross(V(0, 1, 0))
    t1.normalize(); t2 = t1.cross(n).normalized()
    return t1, t2, n           # side(+x screen-right when looking along -n), up, out

def place(o, p, t1, t2, n, roll=0.0):
    R = Matrix((t1, t2, n)).transposed()
    if roll: R = R @ Matrix.Rotation(math.radians(roll), 3, 'Z')
    o.matrix_world = Matrix.Translation(p) @ R.to_4x4()
    return o

def cut_cap(o, plane_y, keep_above=True, tilt=0.0, col="ink"):
    """Keep the part of a local mesh above (or below) a tilted local plane y = plane_y; cap the hole."""
    bm = bmesh.new(); bm.from_mesh(o.data)
    a = math.radians(tilt); no = V(-math.sin(a), math.cos(a), 0)
    if keep_above: no = -no
    bmesh.ops.bisect_plane(bm, geom=bm.verts[:] + bm.edges[:] + bm.faces[:], plane_co=(0, plane_y, 0), plane_no=no, clear_outer=True)
    edges = [e for e in bm.edges if e.is_boundary]
    if edges: bmesh.ops.contextual_create(bm, geom=edges)
    bm.to_mesh(o.data); bm.free(); paint(o, col)
    return o

def eye2(name, tree, origin, fwd=(0, -1, 0), size=.3, iris="sky", look=(0, 0), lid=None, open_=.78, tilt=0.0,
         lower=None, lash=True, brow=None, brow_h=1.55, brow_tilt=0.0, brow_arch=.18, brow_col="ink", push=.03,
         pupil="ink", side=1, squash=1.0, hl=True, star=False, lash_col="ink"):
    """origin: point in front of the face (ray is cast along -fwd). side: -1 left, +1 right (mirrors tilt).
    open_: 1 = fully open, .5 = half lid (smug), .2 = sleepy. tilt (deg): + = outer corner down (sad), - = angry.
    Returns (parts, p, n)."""
    f = Vector(fwd).normalized()
    p, n = hit(tree, origin, -f)
    if p is None: raise RuntimeError("eye2 ray missed " + name)
    n = (n * .45 + f * .55).normalized()
    t1, t2, n = basis(n)
    s = size; P = []
    sx, sy = s * .92, s * 1.08 * squash
    c = p + n * push
    w = sphere(name + "_scl", (sx, sy, s * .45), col="eye_white", seg=20, ring=10); place(w, c, t1, t2, n); P.append(w)
    lk = t1 * look[0] * s * .34 + t2 * look[1] * s * .32
    ir = sphere(name + "_iris", (s * .66, s * .74 * squash, s * .2), col=iris, seg=16, ring=8); place(ir, c + n * s * .3 + lk, t1, t2, n); P.append(ir)
    pu = sphere(name + "_pup", (s * .36, s * .42 * squash, s * .12), col=pupil, seg=12, ring=6); place(pu, c + n * s * .4 + lk * 1.1, t1, t2, n); P.append(pu)
    if hl:
        h1 = sphere(name + "_hl1", (s * .2, s * .2, s * .08), col="eye_white", seg=10, ring=6); place(h1, c + n * s * .48 + lk + t1 * (-s * .22) + t2 * s * .26, t1, t2, n); P.append(h1)
        h2 = sphere(name + "_hl2", (s * .09, s * .09, s * .05), col="eye_white", seg=8, ring=5); place(h2, c + n * s * .47 + lk + t1 * s * .2 + t2 * (-s * .22), t1, t2, n); P.append(h2)
    tl = tilt * side
    if lid and open_ < .98:
        ld = sphere(name + "_lid", (sx * 1.07, sy * 1.07, s * .5), col=lid, seg=20, ring=10)
        y = sy * (1 - 2 * (1 - open_)) * 1.07
        cut_cap(ld, y, keep_above=True, tilt=tl, col=lid); place(ld, c, t1, t2, n); P.append(ld)
        if lash:
            pts = []
            for k in range(9):
                u = -1 + 2 * k / 8; xx = u * sx * 1.02
                yy = y + math.tan(math.radians(tl)) * xx
                rr = (sx * 1.07) ** 2 * (1 - (yy / (sy * 1.07)) ** 2)
                if rr < xx * xx: xx = math.copysign(math.sqrt(max(rr, 0)), xx)
                zz = s * .5 * math.sqrt(max(0, 1 - (xx / (sx * 1.07)) ** 2 - (yy / (sy * 1.07)) ** 2)) + s * .02
                pts.append(c + t1 * xx + t2 * yy + n * zz)
            P.append(tube(name + "_lash", pts, radius=s * .065, col=lash_col, seg=6, taper=[.5, .8, 1, 1, 1, 1, 1, 1.1, 1.2] if side > 0 else [1.2, 1.1, 1, 1, 1, 1, 1, .8, .5]))
    elif lash:
        pts = []
        for k in range(9):
            a = math.radians(160 - 140 * k / 8)
            pts.append(c + t1 * math.cos(a) * sx * 1.04 + t2 * math.sin(a) * sy * 1.04 + n * s * .06)
        P.append(tube(name + "_lash", pts, radius=s * .06, col=lash_col, seg=6))
    if lower:
        lo = sphere(name + "_low", (sx * 1.07, sy * 1.07, s * .5), col=lower, seg=20, ring=10)
        cut_cap(lo, -sy * .55, keep_above=False, tilt=0, col=lower); place(lo, c, t1, t2, n); P.append(lo)
    if brow:
        pts = []
        bt = brow_tilt * side
        for k in range(7):
            u = -1 + 2 * k / 6
            xx = u * s * .95
            yy = s * brow_h + math.tan(math.radians(bt)) * xx + brow_arch * s * (1 - u * u)
            q = c + t1 * xx + t2 * yy
            hp, hn = hit(tree, q + f * 3, -f)
            pts.append((hp + hn * s * .07) if hp is not None else q + n * s * .2)
        P.append(tube(name + "_brow", pts, radius=s * .1, col=brow_col, seg=7, taper=[.55, .9, 1, 1, 1, .85, .5]))
    return P, p, n

def eyes2(name, objs_or_tree, center, fwd=(0, -1, 0), dx=.42, dz=.12, **kw):
    tree = objs_or_tree if isinstance(objs_or_tree, BVHTree) else bvh_of(objs_or_tree)
    f = Vector(fwd).normalized(); side = f.cross(V(0, 0, 1)).normalized()
    out = []
    looks = kw.pop("looks", None)
    for i, s_ in enumerate((-1, 1)):
        o = Vector(center) + side * dx * s_ * -1 + V(0, 0, dz) + f * 6   # s_=-1 -> screen-left
        k2 = dict(kw)
        if looks: k2["look"] = looks[i]
        e, _, _ = eye2(f"{name}{'L' if s_ < 0 else 'R'}", tree, o, fwd=f, side=s_, **k2)
        out += e
    return out

def plate(name, center, fwd=(0, -1, 0), r=(.8, .55, .65), col="cream", fwd_off=.5, seg=24, ring=12, tilt=0.0):
    """Smooth ellipsoid face patch. center = head centre; sits fwd_off along fwd."""
    f = Vector(fwd).normalized(); t1, t2, n = basis(f)
    o = sphere(name, (r[0], r[2], r[1]), col=col, seg=seg, ring=ring)
    place(o, Vector(center) + f * fwd_off, t1, t2, n, roll=tilt)
    return o

def blush2(name, tree, origin, fwd=(0, -1, 0), size=.15, col="blush"):
    f = Vector(fwd).normalized(); p, n = hit(tree, origin, -f)
    if p is None: return []
    t1, t2, n = basis(n)
    o = sphere(name, (size * 1.35, size * .8, size * .22), col=col, seg=14, ring=7); place(o, p + n * .01, t1, t2, n); return [o]

def mouth2(name, tree, origin, fwd=(0, -1, 0), w=.5, h=.3, smile=.35, col="ink", lip=None, tongue=True, teeth=0,
           fangs=0, push=.015, depth=.05, shape="D"):
    """Open mouth: filled shape (D = flat top/curved bottom, O = oval) + optional lip rim, tongue, top teeth, fangs."""
    f = Vector(fwd).normalized(); p, n = hit(tree, origin, -f)
    if p is None: raise RuntimeError("mouth ray missed " + name)
    n = (n * .5 + f * .5).normalized(); t1, t2, n = basis(n)
    pts2 = []
    N = 18
    if shape == "O":
        for k in range(N): a = 2 * math.pi * k / N; pts2.append((w / 2 * math.cos(a), h / 2 * math.sin(a)))
    else:
        for k in range(N + 1):   # bottom curve, left->right
            u = -1 + 2 * k / N; pts2.append((u * w / 2, -h * math.sqrt(max(0, 1 - u ** 4)) * .9))
        for k in range(1, 6):    # top edge, smiling up at corners
            u = 1 - 2 * k / 6; pts2.append((u * w / 2, smile * h * (u * u) * .6))
    bm = bmesh.new(); vs = [bm.verts.new((x, y, 0)) for x, y in pts2]; bm.faces.new(vs)
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    o = bm_to_obj(bm, name + "_cav")
    m = o.modifiers.new("s", 'SOLIDIFY'); m.thickness = depth; m.offset = 0
    bpy.context.view_layer.objects.active = o
    for x in bpy.context.selected_objects: x.select_set(False)
    o.select_set(True); bpy.ops.object.modifier_apply(modifier="s")
    paint(o, col); place(o, p + n * push, t1, t2, n)
    P = [o]
    W = lambda x, y, z=0: p + n * (push + z) + t1 * x + t2 * y
    if lip:
        ring = [W(x, y, depth * .5) for x, y in pts2] + [W(*pts2[0], depth * .5)]
        P.append(tube(name + "_lip", ring, radius=min(w, h) * .07, col=lip, seg=6))
    if tongue:
        tg = sphere(name + "_tg", (w * .28, h * .26, depth * .9), col="tongue", seg=14, ring=7)
        place(tg, W(0, -h * .58 if shape != "O" else -h * .22, depth * .45), t1, t2, n); P.append(tg)
    if teeth:
        for k in range(teeth):
            u = (k - (teeth - 1) / 2) * (w * .16)
            yy = smile * h * ((u / (w / 2)) ** 2) * .6 - h * .1
            P.append(box(f"{name}_t{k}", (w * .14, h * .2, depth * .8), col="eye_white", bevel=.012))
            place(P[-1], W(u, yy, depth * .5), t1, t2, n)
    for s_ in ((-1, 1) if fangs else ()):
        fg = cyl(f"{name}_fg{s_}", w * .06, .004, -h * .32, col="eye_white", seg=8)
        place(fg, W(s_ * w * .3, smile * h * .3 * .6 - .01, depth * .55), t1, t2, n); P.append(fg)
    return P

def nose2(name, tree, origin, fwd=(0, -1, 0), size=.12, col="fiesta_pink", shape="heart"):
    f = Vector(fwd).normalized(); p, n = hit(tree, origin, -f)
    t1, t2, n = basis(n)
    if shape == "heart":
        P = []
        for s_ in (-1, 1):
            o = sphere(f"{name}{s_}", (size * .62, size * .5, size * .45), col=col, seg=12, ring=8)
            place(o, p + n * size * .2 + t1 * s_ * size * .32 + t2 * size * .1, t1, t2, n, roll=s_ * -25); P.append(o)
        o = sphere(name + "c", (size * .5, size * .55, size * .4), col=col, seg=12, ring=8); place(o, p + n * size * .2 - t2 * size * .25, t1, t2, n); P.append(o)
        h = sphere(name + "h", (size * .22, size * .14, size * .08), col="eye_white", seg=8, ring=5); place(h, p + n * size * .55 + t1 * -size * .25 + t2 * size * .2, t1, t2, n); P.append(h)
        return P
    o = sphere(name, (size, size * .75, size * .6), col=col, seg=14, ring=8); place(o, p + n * size * .25, t1, t2, n)
    h = sphere(name + "h", (size * .3, size * .2, size * .1), col="eye_white", seg=8, ring=5); place(h, p + n * size * .75 + t1 * -size * .35 + t2 * size * .3, t1, t2, n)
    return [o, h]

def paw(name, loc, fwd=(0, -1, 0), s=.3, col="cream", pad="bubblegum", toes=3, up=(0, 0, 1)):
    """Rounded paw with toe beans on the front."""
    f = Vector(fwd).normalized(); t1, t2, n = basis(f, up)
    P = []
    b = sphere(name, (s, s * .85, s * .95), col=col, seg=16, ring=10); place(b, Vector(loc), t1, t2, n); P.append(b)
    if pad:
        for k in range(toes):
            u = (k - (toes - 1) / 2) * s * .5
            o = sphere(f"{name}_b{k}", (s * .17, s * .17, s * .08), col=pad, seg=8, ring=5)
            place(o, Vector(loc) + n * s * .8 + t1 * u + t2 * s * .25 * (1 - abs(u) / s), t1, t2, n); P.append(o)
        o = sphere(f"{name}_pd", (s * .34, s * .26, s * .1), col=pad, seg=10, ring=6); place(o, Vector(loc) + n * s * .82 - t2 * s * .2, t1, t2, n); P.append(o)
    return P

def sparkle(name, loc, s=.2, col="neon_gold", rot=(90, 0, 0)):
    from plib import star_prism
    return star_prism(name, 4, s, s * .3, s * .25, loc=loc, rot=rot, col=col, bevel=0)

def decal(name, tree, origin, fwd=(0, -1, 0), r=(.1, .2), col="tangerine", roll=0.0, th=.03):
    """Flat ellipse stuck on a surface (stripes, spots, masks)."""
    f = Vector(fwd).normalized(); p, n = hit(tree, origin, -f)
    if p is None: return []
    t1, t2, n = basis(n)
    o = sphere(name, (r[0], r[1], th), col=col, seg=14, ring=7); place(o, p + n * th * .3, t1, t2, n, roll=roll); return [o]

def ear_inner(name, base, d, length, width, col="bubblegum", out=(0, -1, 0), off=.15, th=.04):
    d = Vector(d).normalized(); o_ = Vector(out).normalized()
    t1 = d.cross(o_).normalized(); n = t1.cross(d).normalized()
    o = sphere(name, (width, length, th), col=col, seg=12, ring=8)
    place(o, Vector(base) + d * length * .9 + n * off, t1, d, n); return o
