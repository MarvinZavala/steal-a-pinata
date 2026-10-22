"""Generic set lineup (fase 3): blender -b --factory-startup -P lineup_set.py -- memes2|random
Writes art/renders/lineup_<set>_raw.png + /tmp/lineup_<set>_anchors.json; then run label_set.py <set>."""
import sys, os, math, json
sys.path.insert(0, os.path.dirname(__file__))
from plib import *
from base import append_asset
from mathutils import Vector, Matrix
SETS = {
    "memes2": dict(out="lineup_memes_2", res=(3300, 1150), bg=("#5B1F9E", "#D9479F"), order=[
        ("garrobita_terenga", "Garrobita Terenga", "ÉPICO"), ("fantasmita_bu", "Fantasmita Bú", "ÉPICO"),
        ("cochinito_quincena", "Cochinito Quincena", "LEGENDARIO"), ("lic_dos_peces", "Lic. Dos Peces", "LEGENDARIO"),
        ("pinovela", "Piñovela", "MÍTICO"), ("chancla_teledirigida", "La Chancla Teledirigida", "MÍTICO"),
        ("aurazoso", "Aurazoso", "SECRETO"), ("abuelita_en_vivo", "Abuelita en Vivo", "SECRETO")],
        rot={"cochinito_quincena": -35, "chancla_teledirigida": 10, "lic_dos_peces": 0}),
    "random": dict(out="lineup_random", res=(2600, 1150), bg=("#0F6E8C", "#43D9B8"), order=[
        ("caracol_turbo", "Caracol Turbo", "ÉPICO"), ("cactus_abrazos", "Cactus Abrazos", "LEGENDARIO"),
        ("aguacaton", "Aguacatón", "MÍTICO"), ("pulpo_dj", "Pulpo DJ", "SECRETO")],
        rot={"caracol_turbo": -38}),
}
PEDCOL = {"COMÚN": "donkey_grey", "POCO COMÚN": "lime", "RARO": "sky", "ÉPICO": "grape", "LEGENDARIO": "gold", "EVENTO NAVIDAD": "xmas_red", "MÍTICO": "fiesta_pink", "SECRETO": "ink"}
GLOW = {"ÉPICO": "neon_pink", "LEGENDARIO": "neon_gold", "EVENTO NAVIDAD": "neon_green", "MÍTICO": "neon_pink", "SECRETO": "neon_cyan"}

def run(setname):
    cfg = SETS[setname]
    reset(); write_palette_textures()
    x = 0; placed = []; gap = 1.0
    for key, nm, rar in cfg["order"]:
        objs = append_asset(key)
        for o in objs: o.matrix_world = Matrix.Rotation(math.radians(cfg["rot"].get(key, 0)), 4, 'Z') @ o.matrix_world
        bpy.context.view_layer.update()
        mn = min((o.matrix_world @ v.co).x for o in objs for v in o.data.vertices)
        mxx = max((o.matrix_world @ v.co).x for o in objs for v in o.data.vertices)
        pr = max((mxx - mn) / 2 + .3, 1.6); cx = x + pr
        for o in objs: o.matrix_world = Matrix.Translation((cx - (mn + mxx) / 2, 0, .9)) @ o.matrix_world
        ped = cyl(f"ped_{key}", pr, pr + .15, .9, loc=(cx, 0, 0), col=PEDCOL[rar], seg=40, bevel=.12); assign_mat(ped, material_palette())
        if rar in GLOW:
            g = torus(f"glow_{key}", pr + .05, .07, loc=(cx, 0, .9), col=GLOW[rar], seg=40, mseg=6); assign_mat(g, material_palette("M_Neon", emissive=4))
        placed.append((key, nm, rar, cx)); x = cx + pr + gap
    total = x - gap
    for o in bpy.context.scene.objects:
        if o.type == 'MESH': o.location.x -= total / 2
    placed = [(k, n, r, cx - total / 2) for k, n, r, cx in placed]
    setup_render(cfg["res"], int(os.environ.get("SAMPLES", "128")))
    bpy.context.scene.view_settings.view_transform = "AgX"; bpy.context.scene.view_settings.look = "AgX - Punchy"
    backdrop(*cfg["bg"], size=200); lights(scale=3.2, center=(0, 0, 2.5))
    cd = bpy.data.cameras.new("Cam"); cd.lens = 50; cam = bpy.data.objects.new("Cam", cd); link(cam); bpy.context.scene.camera = cam
    fov_h = 2 * math.atan(36 / 2 / 50)
    dist = (total / 2 + 2.2) / math.tan(fov_h / 2)
    cam.location = (0, -dist, 4.4); tgt = Vector((0, 0, 3.4))
    cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.ops.wm.save_as_mainfile(filepath=f"{BLEND}/{cfg['out']}.blend")
    render(f"{REND}/{cfg['out']}_raw.png")
    from bpy_extras.object_utils import world_to_camera_view
    s = bpy.context.scene; anchors = []
    for k, n, r, cx in placed:
        co = world_to_camera_view(s, cam, Vector((cx, -1.5, 0)))
        anchors.append({"key": k, "name": n, "rarity": r, "u": co.x, "v": co.y})
    json.dump(anchors, open(f"/tmp/{cfg['out']}_anchors.json", "w"))

run(sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "memes2")
