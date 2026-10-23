"""Re-exporta SOLO las mallas (FBX/OBJ en export/creatures) de piñatas ya hechas, sin .blend ni render.
Sirve cuando cambia el pipeline (p. ej. plib.join/torus) y la geometría se ve igual en los renders.
Cada id se arma con el script que lo define hoy (las rehechas de fase 3 viven en animals2.py).
CLI: blender -b --factory-startup -P reexport_meshes.py -- [id ...]      (sin ids: todas las de OWNERS)
Al final compara size_studs y tris con export/creatures/_meta.json y lo actualiza.
"""
import sys, os, json
sys.path.insert(0, os.path.dirname(__file__))
import creatures as C
from plib import *

# Copias de los registros de cada módulo: importar un módulo pisa C.CREATURES con su versión.
OWNERS = {}
_fase1 = dict(C.CREATURES)
for n in ("estrellita", "cohetin", "sombra"):
    OWNERS[n] = _fase1[n]
import memes
for n in ("seis_siete", "manzanin_iq", "fichadito", "gemelos_pupusa"):
    OWNERS[n] = memes.MEMES[n]
import animals2
OWNERS.update(animals2.REG)
import memes2
OWNERS.update({n: C.CREATURES[n] for n in ("garrobita_terenga", "fantasmita_bu", "cochinito_quincena", "lic_dos_peces",
                                             "pinovela", "chancla_teledirigida", "aurazoso", "abuelita_en_vivo")})
import randoms
OWNERS.update(randoms.RANDOMS)
import latam, latam2, latam3
OWNERS.update(latam.LATAM); OWNERS.update(latam2.SET); OWNERS.update(latam3.SET)
import roster_a, roster_b, roster_c
OWNERS.update(roster_a.REG); OWNERS.update(roster_b.REG); OWNERS.update(roster_c.REG)


def export_only(name):
    reset()
    parts, extra = OWNERS[name]()
    glow = extra.get("glow", [])
    main = [p for p in parts if p not in glow]
    objs = [join(main, name)]
    if glow:
        objs.append(join(glow, name + "_Neon"))
    size = base_origin(objs)
    mat = material_palette()
    for o in objs:
        assign_mat(o, mat if not o.name.endswith("_Neon") else material_palette("M_Neon", emissive=1.6)); smooth(o, 50)
    info = export(objs, name, "creatures")
    return {"name": name, "size_studs": [round(size.x, 2), round(size.z, 2), round(size.y, 2)], "tris": info}


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    mf = f"{ROOT}/export/creatures/_meta.json"
    old = json.load(open(mf))
    for n in (argv or list(OWNERS)):
        m = export_only(n)
        prev = old.get(n)
        same = prev is not None and prev.get("size_studs") == m["size_studs"] and prev.get("tris") == m["tris"]
        print("REEXPORT", n, "igual" if same else f"CAMBIO {prev and prev.get('size_studs')} {prev and prev.get('tris')} -> {m['size_studs']} {m['tris']}")
        old[n] = m
        json.dump(old, open(mf, "w"), indent=1)
