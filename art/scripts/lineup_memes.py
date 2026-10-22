import sys, os, math, json
sys.path.insert(0, os.path.dirname(__file__))
from plib import *
from base import append_asset
from mathutils import Vector, Matrix
ORDER = [("michi_aplausos", "Michi Aplausos", "LEGENDARIO"), ("seis_siete", "Seis-Siete", "LEGENDARIO"), ("manzanin_iq", "Manzanín IQ", "MÍTICO"),
         ("mapache_nel", "Mapache Nel", "MÍTICO"), ("fichadito", "Fichadito", "SECRETO"), ("gemelos_pupusa", "Los Gemelos Pupusa", "SECRETO")]
SCALE = {"LEGENDARIO": 1.0, "MÍTICO": 1.0, "SECRETO": 1.0}
PEDCOL = {"COMÚN": "donkey_grey", "POCO COMÚN": "lime", "RARO": "sky", "ÉPICO": "grape", "LEGENDARIO": "gold", "EVENTO NAVIDAD": "xmas_red", "MÍTICO": "fiesta_pink", "SECRETO": "ink"}
GLOW = {"LEGENDARIO": "neon_gold", "EVENTO NAVIDAD": "neon_green", "MÍTICO": "neon_pink", "SECRETO": "neon_cyan"}
ROT = {"mapache_nel": 18, "michi_aplausos": -8}

def run():
    reset(); write_palette_textures()
    x = 0; placed = []; gap = 1.2
    for key, nm, rar in ORDER:
        objs = append_asset(key)
        sc = SCALE[rar]
        for o in objs: o.matrix_world = Matrix.Rotation(math.radians(ROT.get(key, 0)), 4, 'Z') @ Matrix.Scale(sc, 4) @ o.matrix_world
        bpy.context.view_layer.update()
        mn = min((o.matrix_world @ v.co).x for o in objs for v in o.data.vertices)
        mxx = max((o.matrix_world @ v.co).x for o in objs for v in o.data.vertices)
        w = mxx - mn
        pr = max(w / 2 + .3, 1.6)
        cx = x + pr
        for o in objs: o.matrix_world = Matrix.Translation((cx - (mn + mxx) / 2, 0, .9)) @ o.matrix_world
        ped = cyl(f"ped_{key}", pr, pr + .15, .9, loc=(cx, 0, 0), col=PEDCOL[rar], seg=40, bevel=.12)
        assign_mat(ped, material_palette())
        if rar in GLOW:
            g = torus(f"glow_{key}", pr + .05, .07, loc=(cx, 0, .9), col=GLOW[rar], seg=40, mseg=6)
            assign_mat(g, material_palette("M_Neon", emissive=4))
        placed.append((key, nm, rar, cx))
        x = cx + pr + gap
    total = x - gap
    for o in bpy.context.scene.objects:
        if o.type == 'MESH': o.location.x -= total / 2
    placed = [(k, n, r, cx - total / 2) for k, n, r, cx in placed]
    setup_render((2600, 1150), 128)
    bpy.context.scene.view_settings.view_transform = "AgX"; bpy.context.scene.view_settings.look = "AgX - Punchy"
    bd = backdrop("#5B1F9E", "#D9479F", size=200)
    lights(scale=3.2, center=(0, 0, 2.5))
    cd = bpy.data.cameras.new("Cam"); cd.lens = 50; cam = bpy.data.objects.new("Cam", cd); link(cam); bpy.context.scene.camera = cam
    fov_h = 2 * math.atan(36 / 2 / 50)
    dist = (total / 2 + 2.2) / math.tan(fov_h / 2)
    cam.location = (0, -dist, 4.4); tgt = Vector((0, 0, 3.4))
    cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.ops.wm.save_as_mainfile(filepath=f"{BLEND}/lineup_memes.blend")
    render(f"{REND}/lineup_memes_raw.png")
    # project label anchor (pedestal base) to pixels
    from bpy_extras.object_utils import world_to_camera_view
    s = bpy.context.scene; anchors = []
    for k, n, r, cx in placed:
        co = world_to_camera_view(s, cam, Vector((cx, -1.5, 0)))
        anchors.append({"key": k, "name": n, "rarity": r, "u": co.x, "v": co.y})
    json.dump(anchors, open("/tmp/lineup_memes_anchors.json", "w"))
run()
