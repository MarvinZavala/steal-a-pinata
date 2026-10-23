"""Thumbnail 4 '¡NUEVAS PIÑATAS!': party stage. Pulpo DJ spinning on a raised stage, Meme 2 + Random piñatas
dancing in front (tilted 'dance' poses, every one still standing on the floor). Disco lights + confetti."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from store_lib import *

FRONT = [  # key, x, y, rz, tilt_y (lean sideways), tilt_x (lean fwd/back), scale
    ("caracol_turbo", -14.2, -0.5, 38, 0, 0, 1.25),
    ("garrobita_terenga", -10.4, -3.6, 24, 9, 0, 1.3),
    ("abuelita_en_vivo", -5.0, -5.6, 14, -6, 0, 1.3),
    ("aguacaton", 5.0, -5.6, -14, 7, 0, 1.3),
    ("fantasmita_bu", 10.4, -3.6, -24, -9, 0, 1.3),
    ("cactus_abrazos", 14.2, -0.5, -34, 6, 0, 1.25),
]

def run():
    reset(); rnd = random.Random(14); pal = palette_mat(); faces = []
    # raised round DJ stage with neon edge
    st = cyl("stage", 7.5, 7.8, 2.2, loc=(0, 6.5, 0), col="ink_soft", seg=64, bevel=.2); assign_mat(st, pal)
    for k, (r, z, colr) in enumerate([(7.82, 2.0, "#3FF2FF"), (7.95, 1.2, "#FF4FD8"), (8.08, .4, "#FFD84D")]):
        t = torus(f"stg{k}", r, .1, loc=(0, 6.5, z), col="eye_white", seg=64, mseg=6); assign_mat(t, emit_mat(f"E_stg{k}", colr, 7)); no_shadow(t)
    dj = place("pulpo_dj", (0, 6.5, 2.2), rz=0, s=2.05)
    bpy.context.view_layer.update(); mn, mx = bbox(dj)
    faces.append((Vector((0, mn.y, mn.z + (mx.z - mn.z) * .6)), 2.4))
    for key, x, y, rz, ty, tx, s in FRONT:
        o = place(key, (x, y, 0), rz=rz, s=s, ry=ty, rx=tx)
        ground(o, 0.0)
        bpy.context.view_layer.update(); mn, mx = bbox(o)
        faces.append((Vector(((mn.x + mx.x) / 2, mn.y, mn.z + (mx.z - mn.z) * .62)), (mx.z - mn.z) * .3))
    # dance floor: glossy tiles in 4 colours
    cols = ["fiesta_pink", "turquoise", "grape", "sun_yellow"]
    tiles = []
    for i in range(-8, 9):
        for j in range(-5, 5):
            c = cols[(i + j) % 4]
            tiles.append(box(f"tile{i}_{j}", (3.9, 3.9, .2), loc=(i * 4, j * 4 + 2, -.1), col=c, bevel=.06))
    tj = join(tiles, "floor_tiles")
    fm = bpy.data.materials.new("M_floor"); fm.use_nodes = True; nt = fm.node_tree; b = nt.nodes["Principled BSDF"]
    vc = nt.nodes.new("ShaderNodeVertexColor"); vc.layer_name = "Col"
    dim = nt.nodes.new("ShaderNodeMix"); dim.data_type = 'RGBA'; dim.inputs[0].default_value = .68
    nt.links.new(vc.outputs[0], dim.inputs[6]); dim.inputs[7].default_value = (*hex2lin("#1B1430"), 1)
    nt.links.new(dim.outputs[2], b.inputs["Base Color"]); b.inputs["Roughness"].default_value = .12; b.inputs["Coat Weight"].default_value = .6
    nt.links.new(vc.outputs[0], b.inputs["Emission Color"]); b.inputs["Emission Strength"].default_value = .07
    tj.data.materials.clear(); tj.data.materials.append(fm)
    floor_plane("dark", 500, "#120A26", .4, z=-.21)
    CAM = Vector((0, -31, 6.4)); TGT = Vector((0, 2, float(os.environ.get("TZ", "6.6"))))
    camera(CAM, TGT, lens=float(os.environ.get("LENS", "31")), focus=Vector((0, -4, 3)), fstop=5.6, shift=(0, float(os.environ.get("SHIFT", "0.0"))))
    guard = FaceGuard(CAM, faces)
    # background: dark violet burst + spot beams
    d = (TGT - CAM).normalized(); bc = TGT + d * 80
    M = Matrix.Translation(bc) @ d.to_track_quat('-Z', 'Y').to_matrix().to_4x4() @ Matrix.Translation((0, 10, 0))
    sunburst("burst", M, 260, "#2A0E6E", "#3C1690", rays=22, glow="#FF4FD8", glow_r=.18, strength=1.0, twist=.003, vignette="#0A0420", vig=.75)
    world_flat("#2A1458", .35)
    for k, (x, colr) in enumerate([(-20, "#3FF2FF"), (-8, "#FF4FD8"), (8, "#FFD84D"), (20, "#5CFF8A")]):
        bm_ = cyl(f"spot{k}", .6, 5.5, 34, loc=(x, 22, 30), rot=(180 + (8 if x < 0 else -8), (x / 20) * 18, 0), col="eye_white", seg=32)
        assign_mat(bm_, beam_mat(f"B_spot{k}", colr, .45, power=.8)); no_shadow(bm_)
    confetti("conf", (0, -2, 9), (17, 6, 4.5), 420, rnd, guard=guard, zmin=1.0, size=1.1)
    ground_confetti("gconf", (-26, 26, -12, 10), 200, rnd, z=.02)
    # music notes floating near the DJ (same note language as the Pulpo DJ model)
    # lights
    area("Key", (-10, -26, 18), (0, 0, 4), 9000, 12, "#FFF1DC")
    area("Fill", (14, -24, 6), (0, 0, 4), 3000, 12, "#DDEBFF")
    area("RimC", (-22, 14, 12), (0, 0, 4), 14000, 7, "#3FF2FF")
    area("RimM", (22, 14, 12), (0, 0, 4), 14000, 7, "#FF4FD8")
    area("DJ", (0, -6, 16), (0, 6.5, 6), 5000, 6, "#FFFFFF")
    render_setup((1920, 1080), int(os.environ.get("SAMPLES", "128")), exposure=float(os.environ.get("EXPO", "-0.2")))
    go(os.environ.get("OUT", "thumb_memes"))
run()
