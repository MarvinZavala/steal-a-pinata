# Steal a Piñata! — Fase 1

![thumbnail](art/renders/thumbnail_1920x1080.png)

| Qué | Dónde |
|---|---|
| Diseño completo (GDD, español) | `plan/GDD.md` |
| Dirección de arte | `art/ART_DIRECTION.md` |
| Cómo importar a Roblox Studio | `art/IMPORT_GUIDE.md` |
| Triángulos por malla (verificados ≤ 20K) | `art/export/TRIANGLES.md` |
| Assets para Roblox (.fbx + .obj) | `art/export/{creatures,base,props,lobby}/` |
| Texturas (paleta, papel picado, logo) | `art/textures/` |
| Fuentes Blender (.blend) | `art/blend/` |
| Scripts que generan TODO el arte | `art/scripts/` (`plib.py` = librería; `creatures.py`, `props.py`, `base.py`, `lobby.py`, `hero.py`, `lineup.py`) |
| Renders | `art/renders/` |
| Proyecto Roblox (Rojo) | `roblox-project/` |

Regenerar un asset: `cd art/scripts && blender -b --factory-startup -P creatures.py -- toro` (Blender 4.2).
