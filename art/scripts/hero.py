import sys, os, math, random, json
sys.path.insert(0, os.path.dirname(__file__))
from plib import *
from base import append_asset
from props import candy_one
from mathutils import Vector, Matrix, Euler

from hero_lib import blocky

def run():
    reset(); write_palette_textures()
    rnd = random.Random(7)
    pal = material_palette(); neon = material_palette("M_Neon", emissive=3)
    def asset(name, M_):
        objs = append_asset(name)
        for o in objs: o.matrix_world = M_ @ o.matrix_world
        return objs
    # --- background base (behind)
    gateM = Matrix.Translation((-13.5, 34, 0)) @ Matrix.Rotation(math.radians(14), 4, 'Z') @ Matrix.Scale(1.3, 4)
    gobjs = append_asset("base_gate")
    import bmesh as _bm
    for o in gobjs:   # strip the generic 'BASE' sign -> replaced by the game-logo plaque
        bm = _bm.new(); bm.from_mesh(o.data)
        kill = [v for v in bm.verts if v.co.z > 11.55 and abs(v.co.x) < 5.2]
        _bm.ops.delete(bm, geom=kill, context='VERTS'); bm.to_mesh(o.data); bm.free()
        o.matrix_world = gateM @ o.matrix_world
    rim_ = box("plaque_rim", (11.2, .7, 5.8), loc=(0, -.2, 13.9), col="fiesta_pink", bevel=.35, bseg=3)
    card = box("plaque_card", (10.4, .7, 5.0), loc=(0, -.35, 13.9), col="snow", bevel=.25, bseg=3)
    for o in (rim_, card): assign_mat(o, pal); o.matrix_world = gateM @ o.matrix_world
    bpy.ops.mesh.primitive_plane_add(size=1); lp = bpy.context.object; lp.name = "plaque_logo"
    lp.data.transform(Matrix.Rotation(math.radians(90), 4, 'X') @ Matrix.Diagonal((9.6, 4.8, 1, 1)))
    lp.matrix_world = gateM @ Matrix.Translation((0, -.72, 13.9))
    lm = bpy.data.materials.new("Logo"); lm.use_nodes = True; lnt = lm.node_tree; lb = lnt.nodes["Principled BSDF"]
    li = lnt.nodes.new("ShaderNodeTexImage"); li.image = bpy.data.images.load(os.path.join(TEX, "logo_plaque.png"))
    lnt.links.new(li.outputs["Color"], lb.inputs["Base Color"]); lnt.links.new(li.outputs["Color"], lb.inputs["Emission Color"])
    lb.inputs["Emission Strength"].default_value = .35; lb.inputs["Roughness"].default_value = .5
    lp.data.materials.append(lm)
    asset("base_generator", Matrix.Translation((14, 44, 0)) @ Matrix.Scale(1.2, 4))
    asset("papel_picado_banner", Matrix.Translation((-1, 16, 0)) @ Matrix.Scale(1.15, 4))
    for i in range(4): asset("base_fence", Matrix.Translation((-28 + i * 8.3, 31, 0)))
    for i in range(4): asset("base_fence", Matrix.Translation((6 + i * 8.3, 31, 0)))
    asset("candy_pile", Matrix.Translation((10, 26, 0)) @ Matrix.Scale(1.3, 4))
    # --- hero swinging the bat (left)
    P, hand = blocky("hero", "fiesta_pink", "cobalt", pose="swing", cap="turquoise")
    for o in P: assign_mat(o, pal)
    heroM = Matrix.Translation((-4.2, 0, 0)) @ Matrix.Rotation(math.radians(-35), 4, 'Z')
    for o in P: o.matrix_basis = heroM @ o.matrix_basis
    hp = (heroM @ hand).to_translation()
    bdir = (Vector((1.4, -2.2, 6.9)) - hp).normalized()
    bat = asset("bat_wood", Matrix.Translation(hp) @ bdir.to_track_quat('Z', 'Y').to_matrix().to_4x4() @ Matrix.Translation((0, 0, -.5)))
    # swoosh arc (motion trail)
    arc = []
    for i in range(14):
        a = math.radians(-70 + i * 9)
        arc.append(Vector((-4.2 + 4.3 * math.cos(a) * .9, -1.0 + 4.3 * math.sin(a) * .5, 5.2 + 1.2 * math.sin(a))))
    sw = ribbon("swoosh", arc, width=1.3, normal=(0, -.3, 1), col="eye_white", thick=.02)
    swm = bpy.data.materials.new("Swoosh"); swm.use_nodes = True; nt = swm.node_tree
    b = nt.nodes["Principled BSDF"]; b.inputs["Base Color"].default_value = (1, 1, 1, 1); b.inputs["Emission Color"].default_value = (1, 1, 1, 1)
    b.inputs["Emission Strength"].default_value = 1.5; b.inputs["Alpha"].default_value = .55; swm.blend_method = 'BLEND'
    sw.data.materials.append(swm)
    # --- thief carrying the golden toro (right), getting bonked
    T, _ = blocky("thief", "cosmic_1", "ink_soft", pose="carry", mask=True)
    for o in T: assign_mat(o, pal)
    thiefM = Matrix.Translation((3.3, -1.0, 0)) @ Matrix.Rotation(math.radians(-25), 4, 'Z') @ Matrix.Rotation(math.radians(-8), 4, 'Y')
    for o in T: o.matrix_basis = thiefM @ o.matrix_basis
    toro = asset("toro", thiefM @ Matrix.Translation((0, .3, 6.9)) @ Matrix.Rotation(math.radians(-15), 4, 'Z') @ Matrix.Rotation(math.radians(15), 4, 'X') @ Matrix.Scale(1.25, 4))
    # impact burst star + dizzy stars
    st = star_prism("bonk", 8, 1.5, .8, .1, loc=(1.6, -2.2, 6.6), rot=(80, 0, -20), col="sun_yellow", bevel=.02); assign_mat(st, neon)
    st2 = star_prism("bonk2", 8, 1.0, .55, .12, loc=(1.6, -2.3, 6.6), rot=(80, 0, -20), col="eye_white", bevel=.02); assign_mat(st2, neon)
    st2.location.y -= .05
    # --- spectators: estrellita + michi cheering bottom
    asset("estrellita", Matrix.Translation((-9.5, -4.5, 0)) @ Matrix.Rotation(math.radians(25), 4, 'Z') @ Matrix.Scale(1.1, 4))
    asset("michi", Matrix.Translation((9.8, -3.8, 0)) @ Matrix.Rotation(math.radians(-30), 4, 'Z') @ Matrix.Scale(1.1, 4))
    asset("cohetin", Matrix.Translation((-13, 6, 0)) @ Matrix.Rotation(math.radians(20), 4, 'Z') @ Matrix.Scale(1.2, 4))
    asset("dragon", Matrix.Translation((14.5, 7, 0)) @ Matrix.Rotation(math.radians(-35), 4, 'Z') @ Matrix.Scale(1.2, 4))
    # keep faces clean: nothing flying between the camera and a face
    bpy.context.view_layer.update()
    CAMP = Vector((0, -24, 3.2))
    def center(o): return o.matrix_world @ (sum((Vector(c) for c in o.bound_box), Vector()) / 8)
    faces = [center(bpy.data.objects["hero_head"]), center(bpy.data.objects["thief_head"]),
             center(toro[0]) + Vector((0, -1.5, .5)), center(lp)]
    def blocks_face(p, r):
        for f in faces:
            d = f - CAMP; t = max(0, min(1, (p - CAMP).dot(d) / d.length_squared))
            if (CAMP + d * t - p).length < r and t > .55: return True
        return False
    # --- confetti + candy explosion around impact
    ccols = ["fiesta_pink", "sun_yellow", "turquoise", "lime", "grape", "tangerine", "eye_white"]
    conf = []
    for i in range(260):
        d = Vector((rnd.gauss(0, 1), rnd.gauss(0, .6) - .3, rnd.gauss(0, .8) + .3)).normalized()
        r = rnd.uniform(1.5, 11)
        p = Vector((1.5, -2.0, 6.4)) + d * r
        if p.z < .3 or blocks_face(p, 1.3): continue
        if i % 5 == 0:
            o = star_prism(f"cst{i}", 5, .22, .1, .04, loc=p, rot=(rnd.uniform(0, 360), rnd.uniform(0, 360), 0), col=ccols[i % 7], bevel=0)
        else:
            o = box(f"cf{i}", (.32, .16, .02), loc=p, rot=(rnd.uniform(0, 360), rnd.uniform(0, 360), rnd.uniform(0, 360)), col=ccols[i % 7], bevel=0)
        conf.append(o)
    for i in range(16):
        d = Vector((rnd.gauss(0, 1), rnd.gauss(0, .5) - .4, rnd.gauss(0, .7) + .2)).normalized()
        p = Vector((1.5, -2.0, 6.0)) + d * rnd.uniform(2, 7)
        if p.z < .5 or blocks_face(p, 2.4): continue
        conf += candy_one(f"cd{i}", p, (rnd.uniform(0, 360), rnd.uniform(0, 360), 0), ["candy_red", "candy_teal", "candy_violet", "sun_yellow"][i % 4], scale=1.6)
    for o in conf: assign_mat(o, pal)
    # ground confetti
    for i in range(160):
        p = Vector((rnd.uniform(-16, 16), rnd.uniform(-8, 14), .02))
        o = box(f"gc{i}", (.3, .15, .02), loc=p, rot=(0, 0, rnd.uniform(0, 360)), col=ccols[i % 7], bevel=0); assign_mat(o, pal)
    # --- environment: grass ground, sky, clouds
    bpy.ops.mesh.primitive_plane_add(size=600, location=(0, 0, 0)); g = bpy.context.object
    gm = bpy.data.materials.new("Grass"); gm.use_nodes = True; gb = gm.node_tree.nodes["Principled BSDF"]
    gb.inputs["Base Color"].default_value = (*hex2lin("#58D15A"), 1); gb.inputs["Roughness"].default_value = .9; g.data.materials.append(gm)
    for k, (x, y, z, s) in enumerate([(-30, 80, 26, 6), (-12, 90, 34, 5), (26, 85, 30, 7), (45, 95, 20, 5)]):
        for j in range(4):
            c = sphere(f"cloud{k}{j}", (s * (1 - .15 * j), s * .7, s * .6), loc=(x + j * s * .9 - s, y, z + (j % 2) * s * .3), col="white", seg=16, ring=10)
            cm = bpy.data.materials.get("Cloud") or bpy.data.materials.new("Cloud")
            cm.use_nodes = True; cb = cm.node_tree.nodes["Principled BSDF"]; cb.inputs["Base Color"].default_value = (1, 1, 1, 1)
            cb.inputs["Emission Color"].default_value = (1, 1, 1, 1); cb.inputs["Emission Strength"].default_value = .6
            c.data.materials.append(cm)
    RES = (960, 540) if os.environ.get("PREVIEW") else (1920, 1080)
    s = setup_render(RES, 24 if os.environ.get("PREVIEW") else 96)
    w = bpy.data.worlds.new("Sky"); s.world = w; w.use_nodes = True; nt = w.node_tree
    bg = nt.nodes["Background"]; grad = nt.nodes.new("ShaderNodeTexGradient"); tc = nt.nodes.new("ShaderNodeTexCoord")
    sep = nt.nodes.new("ShaderNodeSeparateXYZ"); nt.links.new(tc.outputs["Generated"], sep.inputs[0])
    ramp = nt.nodes.new("ShaderNodeValToRGB"); nt.links.new(sep.outputs[2], ramp.inputs[0])
    ramp.color_ramp.elements[0].position = .5; ramp.color_ramp.elements[0].color = (*hex2lin("#BDEBFF"), 1)
    ramp.color_ramp.elements[1].position = .75; ramp.color_ramp.elements[1].color = (*hex2lin("#1E8CFF"), 1)
    nt.links.new(ramp.outputs[0], bg.inputs[0]); bg.inputs[1].default_value = 1.0
    sun = bpy.data.lights.new("Sun", 'SUN'); sun.energy = 3.4; sun.angle = math.radians(8); sun.color = hex2srgb("#FFF2DD")
    so = bpy.data.objects.new("Sun", sun); link(so); so.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
    rim = bpy.data.lights.new("Rim", 'AREA'); rim.energy = 6000; rim.size = 12; rim.color = hex2srgb("#FFE0F4")
    ro = bpy.data.objects.new("Rim", rim); link(ro); ro.location = (6, 18, 14); ro.rotation_euler = (Vector((0, 0, 4)) - ro.location).to_track_quat('-Z', 'Y').to_euler()
    fill = bpy.data.lights.new("Fill", 'AREA'); fill.energy = 2500; fill.size = 14
    fo = bpy.data.objects.new("Fill", fill); link(fo); fo.location = (-8, -20, 10); fo.rotation_euler = (Vector((0, 0, 4)) - fo.location).to_track_quat('-Z', 'Y').to_euler()
    cd = bpy.data.cameras.new("Cam"); cd.lens = 30; cam = bpy.data.objects.new("Cam", cd); link(cam); s.camera = cam
    cam.location = (0, -24, 3.2); tgt = Vector((0, 4, 5.4))
    cam.rotation_euler = (tgt - cam.location).to_track_quat('-Z', 'Y').to_euler()
    cd.dof.use_dof = True; cd.dof.focus_distance = 23; cd.dof.aperture_fstop = 2.8
    if os.environ.get("PREVIEW"):
        render("/tmp/hero_preview.png")
    else:
        bpy.ops.wm.save_as_mainfile(filepath=f"{BLEND}/hero_key_art.blend")
        render(f"{REND}/hero_key_art_raw.png")
run()
