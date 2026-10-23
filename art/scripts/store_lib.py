"""store_lib: shared helpers for the Roblox store art set (icons + thumbnails).
Everything is built from the real game models in art/blend (append_asset). Only staging, light,
FX (confetti / candy / rarity glow) and the key-art avatars are generated here.
Raw renders go to /tmp/store_raw; store_post.py adds text/grade and writes art/renders/store/."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from plib import *
from base import append_asset
from props import candy_one
from mathutils import Vector, Matrix, Euler

RAW = "/tmp/store_raw"
PREVIEW = bool(os.environ.get("PREVIEW"))
os.makedirs(RAW, exist_ok=True)

def R(a): return math.radians(a)
def eul(rx=0, ry=0, rz=0): return Euler((R(rx), R(ry), R(rz))).to_matrix().to_4x4()

# ------------------------------------------------------------------ assets
def place(name, loc=(0, 0, 0), rz=0, s=1.0, rx=0, ry=0, pivot_z=0.0):
    """Append a game model (origin = base centre) and pose it. rx/ry tilt around a pivot at height pivot_z*s."""
    objs = append_asset(name)
    M = Matrix.Translation(loc) @ Matrix.Translation((0, 0, pivot_z * s)) @ eul(rx, ry, rz) @ Matrix.Translation((0, 0, -pivot_z * s)) @ Matrix.Scale(s, 4)
    for o in objs:
        o.matrix_world = M @ o.matrix_world
        o["asset"] = name
    return objs

def bbox(objs):
    mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
    for o in objs:
        if o.type != 'MESH': continue
        mw = o.matrix_world
        for v in o.data.vertices:
            w = mw @ v.co; mn = Vector(map(min, mn, w)); mx = Vector(map(max, mx, w))
    return mn, mx

def ground(objs, z=0.0):
    """Drop objs so their lowest vertex touches z (no floating, no sinking)."""
    bpy.context.view_layer.update()
    mn, _ = bbox(objs); d = z - mn.z
    for o in objs: o.matrix_world = Matrix.Translation((0, 0, d)) @ o.matrix_world
    return objs

def mains(objs): return [o for o in objs if not o.name.endswith("_Neon")]
def neons(objs): return [o for o in objs if o.name.endswith("_Neon")]

def _pal_tex(nt, name):
    im = bpy.data.images.get(name) or bpy.data.images.load(f"{TEX}/{name}.png")
    im.name = name; n = nt.nodes.new("ShaderNodeTexImage"); n.image = im; n.interpolation = 'Closest'
    return n

def _keep_mask(nt, col_out):
    """1 where the palette colour is ink (eyes/mouth) or pure white (eye shine): keep those untouched."""
    hsv = nt.nodes.new("ShaderNodeSeparateColor"); hsv.mode = 'HSV'; nt.links.new(col_out, hsv.inputs[0])
    dark = nt.nodes.new("ShaderNodeMath"); dark.operation = 'LESS_THAN'; dark.inputs[1].default_value = .12
    nt.links.new(hsv.outputs[2], dark.inputs[0])
    lows = nt.nodes.new("ShaderNodeMath"); lows.operation = 'LESS_THAN'; lows.inputs[1].default_value = .02
    nt.links.new(hsv.outputs[1], lows.inputs[0])
    hiv = nt.nodes.new("ShaderNodeMath"); hiv.operation = 'GREATER_THAN'; hiv.inputs[1].default_value = .98
    nt.links.new(hsv.outputs[2], hiv.inputs[0])
    wh = nt.nodes.new("ShaderNodeMath"); wh.operation = 'MULTIPLY'; nt.links.new(lows.outputs[0], wh.inputs[0]); nt.links.new(hiv.outputs[0], wh.inputs[1])
    mx = nt.nodes.new("ShaderNodeMath"); mx.operation = 'MAXIMUM'; nt.links.new(dark.outputs[0], mx.inputs[0]); nt.links.new(wh.outputs[0], mx.inputs[1])
    return mx.outputs[0], hsv

def golden_material():
    """'Dorada' mutation look (ART_DIRECTION §5: golden shimmer): palette luminance -> gold ramp, metallic."""
    m = bpy.data.materials.get("M_Golden")
    if m: return m
    m = bpy.data.materials.new("M_Golden"); m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    c = _pal_tex(nt, "palette_color")
    keep, hsv = _keep_mask(nt, c.outputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB"); nt.links.new(hsv.outputs[2], ramp.inputs[0])
    E = ramp.color_ramp.elements
    E[0].position = .04; E[0].color = (*hex2lin("#7A3300"), 1)
    E[1].position = 1.0; E[1].color = (*hex2lin("#FFE680"), 1)
    mid = E.new(.42); mid.color = (*hex2lin("#FFAE00"), 1)
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = 'RGBA'
    nt.links.new(keep, mix.inputs[0]); nt.links.new(ramp.outputs[0], mix.inputs[6]); nt.links.new(c.outputs[0], mix.inputs[7])
    nt.links.new(mix.outputs[2], b.inputs["Base Color"])
    met = nt.nodes.new("ShaderNodeMath"); met.operation = 'SUBTRACT'; met.inputs[0].default_value = .92
    k2 = nt.nodes.new("ShaderNodeMath"); k2.operation = 'MULTIPLY'; k2.inputs[1].default_value = .92; nt.links.new(keep, k2.inputs[0])
    nt.links.new(k2.outputs[0], met.inputs[1]); nt.links.new(met.outputs[0], b.inputs["Metallic"])
    b.inputs["Roughness"].default_value = .24; b.inputs["Coat Weight"].default_value = .3
    nt.links.new(ramp.outputs[0], b.inputs["Emission Color"]); b.inputs["Emission Strength"].default_value = .05
    return m

def rainbow_material():
    """'Arcoíris' mutation look (ART_DIRECTION §5: hue-shift): hue bands along height, value from palette."""
    m = bpy.data.materials.get("M_Rainbow")
    if m: return m
    m = bpy.data.materials.new("M_Rainbow"); m.use_nodes = True; nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    c = _pal_tex(nt, "palette_color")
    keep, hsv = _keep_mask(nt, c.outputs[0])
    tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tc.outputs["Object"], sep.inputs[0])
    hz = nt.nodes.new("ShaderNodeMath"); hz.operation = 'MULTIPLY_ADD'; hz.inputs[1].default_value = .32; hz.inputs[2].default_value = .0
    nt.links.new(sep.outputs[2], hz.inputs[0])
    hx = nt.nodes.new("ShaderNodeMath"); hx.operation = 'MULTIPLY_ADD'; hx.inputs[1].default_value = .06
    nt.links.new(sep.outputs[0], hx.inputs[0]); nt.links.new(hz.outputs[0], hx.inputs[2])
    fr = nt.nodes.new("ShaderNodeMath"); fr.operation = 'FRACT'; nt.links.new(hx.outputs[0], fr.inputs[0])
    val = nt.nodes.new("ShaderNodeMapRange"); val.inputs[3].default_value = .5; val.inputs[4].default_value = 1.0
    nt.links.new(hsv.outputs[2], val.inputs[0])
    comb = nt.nodes.new("ShaderNodeCombineColor"); comb.mode = 'HSV'
    nt.links.new(fr.outputs[0], comb.inputs[0]); comb.inputs[1].default_value = .95; nt.links.new(val.outputs[0], comb.inputs[2])
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = 'RGBA'
    nt.links.new(keep, mix.inputs[0]); nt.links.new(comb.outputs[0], mix.inputs[6]); nt.links.new(c.outputs[0], mix.inputs[7])
    nt.links.new(mix.outputs[2], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = .32; b.inputs["Coat Weight"].default_value = .5; b.inputs["Coat Roughness"].default_value = .1
    b.inputs["Sheen Weight"].default_value = .3
    nt.links.new(comb.outputs[0], b.inputs["Emission Color"]); b.inputs["Emission Strength"].default_value = .04
    return m

def mutate(objs, kind):
    m = golden_material() if kind == "golden" else rainbow_material()
    for o in mains(objs): assign_mat(o, m)
    return objs

def palette_mat(): return material_palette()
def neon_mat(strength=4): return material_palette(f"M_NeonS{strength}", emissive=strength)

def emit_mat(name, hexcol, strength=4.0, alpha=None):
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial"); em = nt.nodes.new("ShaderNodeEmission")
    em.inputs[0].default_value = (*hex2lin(hexcol), 1); em.inputs[1].default_value = strength
    if alpha is None:
        nt.links.new(em.outputs[0], out.inputs[0])
    else:
        tr = nt.nodes.new("ShaderNodeBsdfTransparent"); mx = nt.nodes.new("ShaderNodeMixShader")
        mx.inputs[0].default_value = alpha; nt.links.new(tr.outputs[0], mx.inputs[1]); nt.links.new(em.outputs[0], mx.inputs[2])
        nt.links.new(mx.outputs[0], out.inputs[0]); m.blend_method = 'BLEND'
    return m

def beam_mat(name, hexcol, strength=3.0, power=1.6):
    """Additive vertical light beam: emission fading with object-space height (0..1) and toward the rim."""
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial"); em = nt.nodes.new("ShaderNodeEmission"); tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    add = nt.nodes.new("ShaderNodeAddShader")
    em.inputs[0].default_value = (*hex2lin(hexcol), 1)
    tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    inv = nt.nodes.new("ShaderNodeMath"); inv.operation = 'SUBTRACT'; inv.inputs[0].default_value = 1; nt.links.new(sep.outputs[2], inv.inputs[1])
    pw = nt.nodes.new("ShaderNodeMath"); pw.operation = 'POWER'; pw.inputs[1].default_value = power; nt.links.new(inv.outputs[0], pw.inputs[0])
    lw = nt.nodes.new("ShaderNodeLayerWeight"); lw.inputs[0].default_value = .35
    f = nt.nodes.new("ShaderNodeMath"); f.operation = 'SUBTRACT'; f.inputs[0].default_value = 1; nt.links.new(lw.outputs["Facing"], f.inputs[1])
    mul = nt.nodes.new("ShaderNodeMath"); mul.operation = 'MULTIPLY'; nt.links.new(pw.outputs[0], mul.inputs[0]); nt.links.new(f.outputs[0], mul.inputs[1])
    mul2 = nt.nodes.new("ShaderNodeMath"); mul2.operation = 'MULTIPLY'; mul2.inputs[1].default_value = strength; nt.links.new(mul.outputs[0], mul2.inputs[0])
    nt.links.new(mul2.outputs[0], em.inputs[1])
    nt.links.new(tr.outputs[0], add.inputs[0]); nt.links.new(em.outputs[0], add.inputs[1]); nt.links.new(add.outputs[0], out.inputs[0])
    m.blend_method = 'BLEND'
    return m

def no_shadow(o):
    o.visible_shadow = False
    return o

def rarity_fx(name, center, radius, hexcol, beam_h=9.0, ring=True, beam=True, light=True, strength=2.4, back_only=True):
    """In-game rarity VFX language (ART_DIRECTION §5): neon ring on the floor + light beam + coloured light."""
    out = []
    if ring:
        t = torus(f"{name}_ring", radius, .09, loc=center, col="eye_white", seg=48, mseg=8)
        assign_mat(t, emit_mat(f"E_{name}_ring", hexcol, 8)); out.append(no_shadow(t))
        t2 = torus(f"{name}_ring2", radius * .78, .05, loc=Vector(center) + Vector((0, 0, .02)), col="eye_white", seg=48, mseg=6)
        assign_mat(t2, emit_mat(f"E_{name}_ring", hexcol, 8)); out.append(no_shadow(t2))
    if beam:
        b = cyl(f"{name}_beam", radius * 1.02, radius * 1.25, beam_h, loc=center, col="eye_white", seg=40, base=True)
        bm_ = bmesh.new(); bm_.from_mesh(b.data)
        kill = [f for f in bm_.faces if abs(f.normal.z) > .9 or (back_only and f.calc_center_median().y < 0)]
        bmesh.ops.delete(bm_, geom=kill, context='FACES'); bm_.to_mesh(b.data); bm_.free()
        assign_mat(b, beam_mat(f"B_{name}", hexcol, strength)); out.append(no_shadow(b))
    if light:
        ld = bpy.data.lights.new(f"{name}_pt", 'POINT'); ld.energy = 220 * radius; ld.color = hex2srgb(hexcol); ld.shadow_soft_size = radius
        lo = bpy.data.objects.new(f"{name}_pt", ld); link(lo); lo.location = Vector(center) + Vector((0, -radius * .8, radius * .6)); out.append(lo)
    return out

# ------------------------------------------------------------------ avatars (key-art only; same build as hero_lib.blocky)
POSES = {
    # torso/head/limbs as XYZ euler degrees. -X on an arm = raise forward; +X on a leg = swing back.
    "carry_run": dict(torso=(14, 0, 0), head=(-24, 0, 14), armR=(-172, 0, -8), armL=(-172, 0, 8), legR=(-52, 0, 0), legL=(44, 0, 0)),
    "chase_bat": dict(torso=(14, 0, -10), head=(-12, 0, 8), armR=(-150, 0, 35), armL=(-70, 0, -15), legR=(40, 0, 0), legL=(-50, 0, 0)),
    "swing": dict(torso=(0, 0, -20), head=(0, 0, 25), armR=(-100, 0, 65), armL=(-95, 0, 45), legR=(20, 0, 0), legL=(-25, 0, 0)),
    "cheer": dict(torso=(-4, 0, 0), head=(-10, 0, 0), armR=(-160, 0, 25), armL=(-160, 0, -25), legR=(6, 0, -6), legL=(-6, 0, 6)),
    "bat_up": dict(torso=(-6, 0, 12), head=(-8, 0, -10), armR=(-165, 0, 20), armL=(-120, 0, -30), legR=(-15, 0, -8), legL=(18, 0, 8)),
    "point": dict(torso=(0, 0, 8), head=(-6, 0, -8), armR=(-95, 0, -10), armL=(-20, 0, -10), legR=(0, 0, 0), legL=(0, 0, 0)),
}

def avatar(name, shirt, pants, pose="cheer", skin="peach", face="grin", mask=False, cap=None, cap2=None, M=Matrix.Identity(4), grounded=True):
    """Generic blocky avatar (our own simple build, R6-like proportions). Returns parts and hand matrices."""
    p = POSES[pose] if isinstance(pose, str) else pose
    P = []
    base = M @ Matrix.Translation((0, 0, 2.0))
    T = base @ eul(*p["torso"])
    def mk(nm, size, col, bevel, offset, Mw):
        o = box(f"{name}_{nm}", size, col=col, bevel=bevel, bseg=2)
        o.data.transform(Matrix.Translation(offset)); o.matrix_world = Mw; P.append(o); return o
    mk("torso", (2, 1, 2), shirt, .12, (0, 0, 1), T)
    H = T @ Matrix.Translation((0, 0, 2.0)) @ eul(*p["head"])
    mk("head", (1.25, 1.2, 1.2), skin, .3, (0, 0, .62), H)
    hands = {}
    for s, k in ((1, "R"), (-1, "L")):
        A = T @ Matrix.Translation((1.5 * s, 0, 1.75)) @ eul(*p["arm" + k])
        mk("arm" + k, (1, 1, 2), shirt, .12, (0, 0, -.8), A)
        mk("hand" + k, (.9, .9, .5), skin, .2, (0, 0, -1.95), A)
        hands[k] = A @ Matrix.Translation((0, 0, -1.95))
        Lg = base @ Matrix.Translation((.5 * s, 0, 0)) @ eul(*p["leg" + k])
        mk("leg" + k, (1, 1, 2), pants, .12, (0, 0, -1), Lg)
        mk("shoe" + k, (1.05, 1.25, .45), "white", .15, (0, -.1, -1.85), Lg)
    def hp(o): o.matrix_basis = H @ o.matrix_basis; P.append(o); return o
    brow = {"grin": -14, "angry": 26, "shock": -28, "smug": 14, "happy": -18}[face]
    for s in (-1, 1):
        if not mask:
            hp(sphere(f"{name}_eye{s}", (.15, .05, .21), loc=(.28 * s, -.62, .72), col="ink", seg=12, ring=8))
            hp(sphere(f"{name}_ehl{s}", (.05, .02, .05), loc=(.23 * s, -.665, .8), col="eye_white", seg=8, ring=5))
        hp(box(f"{name}_brow{s}", (.36, .07, .09), loc=(.28 * s, -.63, 1.0 + (.04 if face == "shock" else 0)), rot=(0, -brow * s, 0), col="ink", bevel=0))
    if face in ("grin", "angry", "shock", "happy"):
        # open mouth: dark oval + tongue + teeth strip, sitting on the head surface
        w, h = {"grin": (.36, .2), "angry": (.3, .2), "shock": (.2, .24), "happy": (.34, .22)}[face]
        hp(sphere(f"{name}_mouth", (w, .06, h), loc=(0, -.6, .34 if face != "angry" else .32), col="ink", seg=16, ring=10))
        hp(sphere(f"{name}_tongue", (w * .55, .04, h * .45), loc=(0, -.645, .26), col="tongue", seg=12, ring=8))
        if face in ("grin", "angry", "happy"):
            hp(box(f"{name}_teeth", (w * 1.3, .05, .07), loc=(0, -.655, .34 + h * .55), col="eye_white", bevel=.02))
    else:  # smug closed smile
        pts = [Vector((-.32, -.63, .44)), Vector((-.15, -.665, .32)), Vector((0, -.67, .3)), Vector((.18, -.665, .36)), Vector((.33, -.63, .5))]
        hp(tube(f"{name}_mouth", pts, radius=.055, col="ink", seg=6))
    hp(sphere(f"{name}_blushL", (.12, .03, .07), loc=(-.45, -.6, .5), col="blush", seg=8, ring=5))
    hp(sphere(f"{name}_blushR", (.12, .03, .07), loc=(.45, -.6, .5), col="blush", seg=8, ring=5))
    if mask:
        hp(box(f"{name}_mask", (1.34, 1.29, .36), loc=(0, 0, .76), col="ink", bevel=.07))
        for s in (-1, 1):
            hp(sphere(f"{name}_meye{s}", (.15, .05, .12), loc=(.27 * s, -.67, .76), col="eye_white", seg=12, ring=8))
            hp(sphere(f"{name}_mpup{s}", (.075, .03, .08), loc=(.27 * s - .02, -.705, .75), col="ink", seg=8, ring=6))
            hp(sphere(f"{name}_mhl{s}", (.03, .015, .03), loc=(.27 * s - .05, -.725, .79), col="eye_white", seg=6, ring=4))
    if cap:
        hp(box(f"{name}_cap", (1.37, 1.32, .5), loc=(0, .02, 1.3), col=cap, bevel=.22))
        hp(box(f"{name}_brim", (1.05, .85, .12), loc=(0, (.85 if not cap2 else -.85), 1.12), col=cap2 or cap, bevel=.05))
    pal = palette_mat()
    for o in P: assign_mat(o, pal)
    if grounded:   # lowest shoe touches the floor of M (running poses would otherwise hover)
        bpy.context.view_layer.update()
        mn, _ = bbox(P); dz = M.to_translation().z - mn.z
        D = Matrix.Translation((0, 0, dz))
        for o in P: o.matrix_world = D @ o.matrix_world
        hands = {k: D @ v for k, v in hands.items()}
    return P, hands

def hold(asset, hand, length_dir=(0, 0, -1), s=1.0, roll=0.0, grip=0.5):
    """Attach a long asset (bat) to a hand matrix: asset local +Z goes along length_dir in hand space."""
    objs = append_asset(asset)
    q = Vector(length_dir).normalized().to_track_quat('Z', 'Y').to_matrix().to_4x4()
    M = hand @ q @ eul(0, 0, roll) @ Matrix.Translation((0, 0, -grip)) @ Matrix.Scale(s, 4)
    for o in objs: o.matrix_world = M @ o.matrix_world
    return objs

# ------------------------------------------------------------------ FX
CCOLS = ["fiesta_pink", "sun_yellow", "turquoise", "lime", "grape", "tangerine", "eye_white", "sky"]

class FaceGuard:
    """Keeps particles out of the line of sight between camera and important faces."""
    def __init__(self, cam_loc, faces=()):
        self.c = Vector(cam_loc); self.f = [(Vector(p), r) for p, r in faces]
    def blocks(self, p, pad=0.0):
        for f, r in self.f:
            d = f - self.c; t = (p - self.c).dot(d) / d.length_squared
            if 0.05 < t < 1.15 and (self.c + d * t - p).length < r + pad: return True
        return False

def confetti(name, center, spread, n, rnd, guard=None, zmin=.2, size=1.0, stars=.2, glossy=False):
    objs = []
    cx, cy, cz = center; sx, sy, sz = spread
    for i in range(n):
        p = Vector((cx + rnd.gauss(0, sx), cy + rnd.gauss(0, sy), cz + rnd.gauss(0, sz)))
        if p.z < zmin or (guard and guard.blocks(p)): continue
        col = CCOLS[i % len(CCOLS)]
        r = (rnd.uniform(0, 360), rnd.uniform(0, 360), rnd.uniform(0, 360))
        if rnd.random() < stars:
            o = star_prism(f"{name}s{i}", 5, .2 * size, .09 * size, .04 * size, loc=p, rot=r, col=col, bevel=0)
        elif rnd.random() < .25:
            pts = [p + Vector((0, 0, 0)), p + Vector((.15, .05, .12)) * size, p + Vector((.3, -.02, .05)) * size, p + Vector((.45, .03, .18)) * size]
            o = ribbon(f"{name}r{i}", pts, width=.09 * size, normal=(rnd.uniform(-1, 1), rnd.uniform(-1, 1), 1), col=col, thick=.015)
        else:
            o = box(f"{name}c{i}", (.3 * size, .16 * size, .02), loc=p, rot=r, col=col, bevel=0)
        objs.append(o)
    if not objs: return None
    j = join(objs, name); assign_mat(j, palette_mat()); no_shadow(j)
    return j

def candies(name, center, spread, n, rnd, guard=None, zmin=.4, scale=1.4):
    objs = []
    cols = ["candy_red", "candy_teal", "candy_violet", "sun_yellow", "fiesta_pink", "lime"]
    for i in range(n):
        p = Vector(center) + Vector((rnd.gauss(0, spread[0]), rnd.gauss(0, spread[1]), rnd.gauss(0, spread[2])))
        if p.z < zmin or (guard and guard.blocks(p, .5 * scale)): continue
        objs += candy_one(f"{name}{i}", p, (rnd.uniform(0, 360), rnd.uniform(0, 360), rnd.uniform(0, 360)), cols[i % len(cols)], scale=scale * rnd.uniform(.8, 1.2))
    if not objs: return None
    j = join(objs, name); assign_mat(j, palette_mat()); smooth(j, 50)
    return j

def lollipop(name, loc, rot, s=1.0, cols=("fiesta_pink", "eye_white")):
    P = [cyl(f"{name}_st", .07 * s, .07 * s, 1.6 * s, col="eye_white", seg=8)]
    P.append(cyl(f"{name}_dk", .55 * s, .55 * s, .22 * s, loc=(0, 0, 1.6 * s), rot=(90, 0, 0), col=cols[0], seg=24, base=False, bevel=.06 * s))
    sw = [Vector((math.cos(a) * .045 * a * s, -.12 * s, 1.6 * s + math.sin(a) * .045 * a * s)) for a in [x * .25 for x in range(4, 44)]]
    P.append(tube(f"{name}_sw", sw, radius=.05 * s, col=cols[1], seg=6))
    j = join(P, name); j.matrix_world = Matrix.Translation(loc) @ eul(*rot); assign_mat(j, palette_mat()); return j

def ground_confetti(name, rect, n, rnd, z=.02):
    x0, x1, y0, y1 = rect; objs = []
    for i in range(n):
        p = Vector((rnd.uniform(x0, x1), rnd.uniform(y0, y1), z))
        objs.append(box(f"{name}{i}", (.3, .15, .02), loc=p, rot=(0, 0, rnd.uniform(0, 360)), col=CCOLS[i % len(CCOLS)], bevel=0))
    j = join(objs, name); assign_mat(j, palette_mat()); return j

def speed_lines(name, origin, direction, n, rnd, length=(3, 7), spread=(1.5, 2.5)):
    d = Vector(direction).normalized(); side = d.cross(Vector((0, 0, 1))).normalized(); up = side.cross(d).normalized()
    objs = []
    for i in range(n):
        o = Vector(origin) + side * rnd.uniform(-spread[0], spread[0]) + up * rnd.uniform(-spread[1], spread[1])
        L = rnd.uniform(*length)
        objs.append(tube(f"{name}{i}", [o, o + d * L * .5, o + d * L], radius=rnd.uniform(.035, .07), col="eye_white", seg=5, taper=[1, .7, .05]))
    j = join(objs, name); assign_mat(j, emit_mat("E_speed", "#FFFFFF", 2.5, alpha=.65)); no_shadow(j)
    return j

# ------------------------------------------------------------------ environment / backdrops
def world_sky(top="#1E8CFF", bottom="#BDEBFF", strength=1.0, split=(.5, .75)):
    w = bpy.data.worlds.new("Sky"); bpy.context.scene.world = w; w.use_nodes = True; nt = w.node_tree
    bg = nt.nodes["Background"]; tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ")
    nt.links.new(tc.outputs["Generated"], sep.inputs[0]); ramp = nt.nodes.new("ShaderNodeValToRGB"); nt.links.new(sep.outputs[2], ramp.inputs[0])
    ramp.color_ramp.elements[0].position = split[0]; ramp.color_ramp.elements[0].color = (*hex2lin(bottom), 1)
    ramp.color_ramp.elements[1].position = split[1]; ramp.color_ramp.elements[1].color = (*hex2lin(top), 1)
    nt.links.new(ramp.outputs[0], bg.inputs[0]); bg.inputs[1].default_value = strength
    return w

def world_flat(col="#BFE6FF", strength=.5):
    w = bpy.data.worlds.new("W"); bpy.context.scene.world = w; w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (*hex2lin(col), 1); w.node_tree.nodes["Background"].inputs[1].default_value = strength
    return w

def sunburst(name, M, size, c1, c2, rays=18, glow="#FFFFFF", glow_r=.35, strength=1.0, twist=0.0, vignette="#000000", vig=.0):
    """Big emissive plane behind the subject: radial rays (classic toy-box thumbnail) + soft centre glow."""
    bpy.ops.mesh.primitive_plane_add(size=1); p = bpy.context.object; p.name = name
    p.data.transform(Matrix.Diagonal((size, size, 1, 1))); p.matrix_world = M
    m = bpy.data.materials.new(f"M_{name}"); m.use_nodes = True; nt = m.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial"); em = nt.nodes.new("ShaderNodeEmission")
    tc = nt.nodes.new("ShaderNodeTexCoord"); sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tc.outputs["Object"], sep.inputs[0])
    at = nt.nodes.new("ShaderNodeMath"); at.operation = 'ARCTAN2'; nt.links.new(sep.outputs[1], at.inputs[0]); nt.links.new(sep.outputs[0], at.inputs[1])
    ln = nt.nodes.new("ShaderNodeVectorMath"); ln.operation = 'LENGTH'
    cxy = nt.nodes.new("ShaderNodeCombineXYZ"); nt.links.new(sep.outputs[0], cxy.inputs[0]); nt.links.new(sep.outputs[1], cxy.inputs[1]); nt.links.new(cxy.outputs[0], ln.inputs[0])
    tw = nt.nodes.new("ShaderNodeMath"); tw.operation = 'MULTIPLY_ADD'; tw.inputs[1].default_value = twist
    nt.links.new(ln.outputs["Value"], tw.inputs[0]); nt.links.new(at.outputs[0], tw.inputs[2])
    k = nt.nodes.new("ShaderNodeMath"); k.operation = 'MULTIPLY'; k.inputs[1].default_value = rays / (2 * math.pi) * 2 * math.pi
    nt.links.new(tw.outputs[0], k.inputs[0])
    sn = nt.nodes.new("ShaderNodeMath"); sn.operation = 'SINE'; nt.links.new(k.outputs[0], sn.inputs[0])
    st = nt.nodes.new("ShaderNodeMapRange"); st.inputs[1].default_value = -.08; st.inputs[2].default_value = .08; nt.links.new(sn.outputs[0], st.inputs[0])
    mix = nt.nodes.new("ShaderNodeMix"); mix.data_type = 'RGBA'; nt.links.new(st.outputs[0], mix.inputs[0])
    mix.inputs[6].default_value = (*hex2lin(c1), 1); mix.inputs[7].default_value = (*hex2lin(c2), 1)
    # centre glow
    g = nt.nodes.new("ShaderNodeMapRange"); g.inputs[1].default_value = 0; g.inputs[2].default_value = size * glow_r
    g.inputs[3].default_value = 1; g.inputs[4].default_value = 0; nt.links.new(ln.outputs["Value"], g.inputs[0])
    gp = nt.nodes.new("ShaderNodeMath"); gp.operation = 'POWER'; gp.inputs[1].default_value = 1.6; nt.links.new(g.outputs[0], gp.inputs[0])
    mix2 = nt.nodes.new("ShaderNodeMix"); mix2.data_type = 'RGBA'; nt.links.new(gp.outputs[0], mix2.inputs[0])
    nt.links.new(mix.outputs[2], mix2.inputs[6]); mix2.inputs[7].default_value = (*hex2lin(glow), 1)
    # vignette toward edges
    v = nt.nodes.new("ShaderNodeMapRange"); v.inputs[1].default_value = size * .2; v.inputs[2].default_value = size * .55
    v.inputs[3].default_value = 0; v.inputs[4].default_value = vig; nt.links.new(ln.outputs["Value"], v.inputs[0])
    mix3 = nt.nodes.new("ShaderNodeMix"); mix3.data_type = 'RGBA'; nt.links.new(v.outputs[0], mix3.inputs[0])
    nt.links.new(mix2.outputs[2], mix3.inputs[6]); mix3.inputs[7].default_value = (*hex2lin(vignette), 1)
    nt.links.new(mix3.outputs[2], em.inputs[0]); em.inputs[1].default_value = strength
    nt.links.new(em.outputs[0], out.inputs[0])
    p.data.materials.append(m); p.visible_shadow = False
    p.visible_diffuse = False; p.visible_glossy = True
    return p

def floor_plane(name, size, hexcol, rough=.6, z=0.0):
    bpy.ops.mesh.primitive_plane_add(size=size, location=(0, 0, z)); g = bpy.context.object; g.name = name
    m = bpy.data.materials.new(f"M_{name}"); m.use_nodes = True; b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*hex2lin(hexcol), 1); b.inputs["Roughness"].default_value = rough
    g.data.materials.append(m); return g

def area(name, loc, target, energy, size, col="#FFFFFF", shape='DISK'):
    ld = bpy.data.lights.new(name, 'AREA'); ld.energy = energy; ld.size = size; ld.color = hex2srgb(col); ld.shape = shape
    o = bpy.data.objects.new(name, ld); link(o); o.location = loc
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler(); return o

def sun(name, rot, energy, col="#FFF2DD", angle=6):
    ld = bpy.data.lights.new(name, 'SUN'); ld.energy = energy; ld.angle = R(angle); ld.color = hex2srgb(col)
    o = bpy.data.objects.new(name, ld); link(o); o.rotation_euler = tuple(R(a) for a in rot); return o

def camera(loc, target, lens=35, focus=None, fstop=4.0, shift=(0, 0)):
    cd = bpy.data.cameras.new("Cam"); cd.lens = lens; cam = bpy.data.objects.new("Cam", cd); link(cam)
    cam.location = loc; cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    cd.shift_x, cd.shift_y = shift
    if focus is not None:
        cd.dof.use_dof = True; cd.dof.aperture_fstop = fstop
        cd.dof.focus_distance = (Vector(focus) - Vector(loc)).length if not isinstance(focus, (int, float)) else focus
    bpy.context.scene.camera = cam; return cam

def render_setup(res, samples, look="AgX - Punchy", exposure=0.0):
    s = setup_render(res, 12 if PREVIEW else samples)
    if PREVIEW: s.render.resolution_percentage = 40
    vt = os.environ.get("VT", "Standard")
    s.view_settings.view_transform = vt; s.view_settings.look = look if vt == "AgX" else "None"; s.view_settings.exposure = exposure
    s.cycles.use_adaptive_sampling = True; s.cycles.adaptive_threshold = .02
    s.cycles.max_bounces = 5; s.cycles.transparent_max_bounces = 16
    s.render.film_transparent = False
    return s

def go(name):
    """Save the .blend snapshot to /tmp (not committed: scenes are fully reproducible from the script) and render."""
    path = f"{RAW}/{name}{'_prev' if PREVIEW else ''}.png"
    if not PREVIEW: bpy.ops.wm.save_as_mainfile(filepath=f"{RAW}/{name}.blend")
    render(path); print("RENDERED", path)
    return path

def project(p):
    from bpy_extras.object_utils import world_to_camera_view
    s = bpy.context.scene; co = world_to_camera_view(s, s.camera, Vector(p)); return co.x, 1 - co.y

def hold_world(asset, hand_pos, direction, s=1.0, grip=.5, up=(0, 0, 1)):
    """Bat etc. gripped at hand_pos, pointing along a world direction (asset local +Z = length)."""
    objs = append_asset(asset)
    q = Vector(direction).normalized().to_track_quat('Z', 'Y').to_matrix().to_4x4()
    M = Matrix.Translation(hand_pos) @ q @ Matrix.Translation((0, 0, -grip * s)) @ Matrix.Scale(s, 4)
    for o in objs: o.matrix_world = M @ o.matrix_world; assign_mat(o, palette_mat())
    return objs

def glow_mat(name, hexcol, strength=2.0, power=3.0):
    """Soft additive glow ball: bright in the centre of the silhouette, fading to nothing at the rim."""
    m = bpy.data.materials.get(name)
    if m: return m
    m = bpy.data.materials.new(name); m.use_nodes = True; nt = m.node_tree
    for n in list(nt.nodes): nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial"); em = nt.nodes.new("ShaderNodeEmission"); tr = nt.nodes.new("ShaderNodeBsdfTransparent")
    add = nt.nodes.new("ShaderNodeAddShader"); em.inputs[0].default_value = (*hex2lin(hexcol), 1)
    lw = nt.nodes.new("ShaderNodeLayerWeight"); lw.inputs[0].default_value = .5
    inv = nt.nodes.new("ShaderNodeMath"); inv.operation = 'SUBTRACT'; inv.inputs[0].default_value = 1; nt.links.new(lw.outputs["Facing"], inv.inputs[1])
    pw = nt.nodes.new("ShaderNodeMath"); pw.operation = 'POWER'; pw.inputs[1].default_value = power; nt.links.new(inv.outputs[0], pw.inputs[0])
    mul = nt.nodes.new("ShaderNodeMath"); mul.operation = 'MULTIPLY'; mul.inputs[1].default_value = strength; nt.links.new(pw.outputs[0], mul.inputs[0])
    nt.links.new(mul.outputs[0], em.inputs[1])
    nt.links.new(tr.outputs[0], add.inputs[0]); nt.links.new(em.outputs[0], add.inputs[1]); nt.links.new(add.outputs[0], out.inputs[0])
    m.blend_method = 'BLEND'
    return m

def glow_ball(name, center, r, hexcol, strength=1.5, power=3.0):
    g = sphere(name, (r, r, r), loc=center, col="eye_white", seg=32, ring=16)
    for p in g.data.polygons: p.use_smooth = True
    assign_mat(g, glow_mat(f"G_{name}", hexcol, strength, power)); no_shadow(g)
    g.visible_diffuse = False; g.visible_glossy = False
    return g
