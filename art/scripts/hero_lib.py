import math
from plib import *
from mathutils import Vector, Matrix, Euler

def blocky(name, hoodie, pants, skin="peach", pose="swing", mask=False, cap=None):
    """Generic blocky avatar (R6-like proportions, our own simple build) - only for key art."""
    P = []
    def part(nm, size, pivot, offset, rot, col, bevel=.12):
        o = box(f"{name}_{nm}", size, col=col, bevel=bevel, bseg=2)
        o.data.transform(Matrix.Translation(offset))
        o.matrix_world = Matrix.Translation(pivot) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
        P.append(o); return o
    poses = {
        "swing": dict(torso=(0, 0, -20), head=(0, 0, 25), armR=(-100, 0, 65), armL=(-95, 0, 45), legR=(20, 0, 0), legL=(-25, 0, 0)),
        "carry": dict(torso=(10, 0, 10), head=(-5, 0, -10), armR=(-175, 0, -10), armL=(-175, 0, 10), legR=(-40, 0, 0), legL=(35, 0, 0)),
        "cheer": dict(torso=(0, 0, 0), head=(0, 0, 0), armR=(-160, 0, 20), armL=(-160, 0, -20), legR=(0, 0, 0), legL=(0, 0, 0)),
    }[pose]
    T = Euler([math.radians(a) for a in poses["torso"]]).to_matrix().to_4x4()
    base = Matrix.Translation((0, 0, 2.0))
    torso = part("torso", (2, 1, 2), (0, 0, 0), (0, 0, 1), (0, 0, 0), hoodie)
    torso.matrix_world = base @ T
    def attach(nm, size, joint_local, offset, rot, col, bevel=.12):
        o = box(f"{name}_{nm}", size, col=col, bevel=bevel, bseg=2)
        o.data.transform(Matrix.Translation(offset))
        o.matrix_world = base @ T @ Matrix.Translation(joint_local) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4()
        P.append(o); return o
    attach("head", (1.25, 1.2, 1.2), (0, 0, 2.0), (0, 0, .62), poses["head"], skin, bevel=.3)
    attach("armR", (1, 1, 2), (1.5, 0, 1.75), (0, 0, -.8), poses["armR"], hoodie)
    attach("armL", (1, 1, 2), (-1.5, 0, 1.75), (0, 0, -.8), poses["armL"], hoodie)
    attach("handR", (.9, .9, .5), (1.5, 0, 1.75), (0, 0, -1.95), poses["armR"], skin, bevel=.2)
    attach("handL", (.9, .9, .5), (-1.5, 0, 1.75), (0, 0, -1.95), poses["armL"], skin, bevel=.2)
    T2 = Matrix.Identity(4)
    legR = box(f"{name}_legR", (1, 1, 2), col=pants, bevel=.12); legR.data.transform(Matrix.Translation((0, 0, -1)))
    legR.matrix_world = base @ Matrix.Translation((.5, 0, 0)) @ Euler([math.radians(a) for a in poses["legR"]]).to_matrix().to_4x4(); P.append(legR)
    legL = box(f"{name}_legL", (1, 1, 2), col=pants, bevel=.12); legL.data.transform(Matrix.Translation((0, 0, -1)))
    legL.matrix_world = base @ Matrix.Translation((-.5, 0, 0)) @ Euler([math.radians(a) for a in poses["legL"]]).to_matrix().to_4x4(); P.append(legL)
    for nm, lg, sx in (("shoeR", poses["legR"], .5), ("shoeL", poses["legL"], -.5)):
        o = box(f"{name}_{nm}", (1.05, 1.25, .45), col="white", bevel=.15); o.data.transform(Matrix.Translation((0, -.1, -1.85)))
        o.matrix_world = base @ Matrix.Translation((sx, 0, 0)) @ Euler([math.radians(a) for a in lg]).to_matrix().to_4x4(); P.append(o)
    # face (on head front, in head-local space)
    H = base @ T @ Matrix.Translation((0, 0, 2.0)) @ Euler([math.radians(a) for a in poses["head"]]).to_matrix().to_4x4()
    def hpart(o): o.matrix_basis = H @ o.matrix_basis; P.append(o)
    for s in (-1, 1):
        e = sphere(f"{name}_eye{s}", (.12, .05, .17), loc=(.27 * s, -.62, .72), col="ink", seg=10, ring=6); hpart(e)
        hl = sphere(f"{name}_ehl{s}", (.045, .02, .045), loc=(.24 * s, -.66, .78), col="eye_white", seg=6, ring=4); hpart(hl)
        br = box(f"{name}_brow{s}", (.32, .06, .08), loc=(.28 * s, -.62, .98), rot=(0, (-18 if not mask else 12) * s, 0), col="ink", bevel=0); hpart(br)
    mouth = [Vector((-.3, -.63, .42)), Vector((-.15, -.66, .3)), Vector((0, -.67, .27)), Vector((.15, -.66, .3)), Vector((.3, -.63, .44))]
    hpart(tube(f"{name}_mouth", mouth, radius=.05, col="ink", seg=6))
    if mask:
        hpart(box(f"{name}_mask", (1.32, 1.27, .32), loc=(0, 0, .74), col="ink", bevel=.06))
        for s in (-1, 1):
            hpart(sphere(f"{name}_meye{s}", (.12, .05, .1), loc=(.27 * s, -.66, .74), col="eye_white", seg=10, ring=6))
            hpart(sphere(f"{name}_mpup{s}", (.06, .03, .06), loc=(.3 * s, -.69, .73), col="ink", seg=8, ring=5))
    if cap:
        hpart(box(f"{name}_cap", (1.35, 1.3, .45), loc=(0, .02, 1.28), col=cap, bevel=.2))
        hpart(box(f"{name}_brim", (1.0, .8, .12), loc=(0, .85, 1.1), col=cap, bevel=.05))
    return P, (base @ T @ Matrix.Translation((1.5, 0, 1.75)) @ Euler([math.radians(a) for a in poses["armR"]]).to_matrix().to_4x4() @ Matrix.Translation((0, 0, -1.95)))

