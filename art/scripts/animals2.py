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

REG = {"michi": michi}
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
