# Guía de importación a Roblox Studio — Steal a Piñata!

> Para: Marvin (o cualquier agente que monte los assets en Studio).
> Todos los assets están en `art/export/<carpeta>/` en **.fbx** (recomendado) y **.obj** (respaldo). Las texturas están en `art/textures/`.
> ⚠️ Honestidad: estos archivos se generaron y verificaron en Blender, pero **no se probaron dentro de Studio** desde mi computadora (no tengo Studio). Hacé primero la importación de prueba (paso 1) y revisá escala y orientación antes de importar todo.

---

## 0. Qué hay
| Carpeta | Contenido |
|---|---|
| `export/creatures/` | 9 piñatas: estrellita, burrito, michi, cohetin, dragon, toro, renito, torogoz, sombra |
| `export/base/` | base_floor, base_gate, base_padlock, base_generator, base_pedestal, base_fence, base_signpost |
| `export/props/` | bat_wood, bat_gold, caja_sorpresa, candy_pile, papel_picado_banner |
| `export/lobby/` | lobby_kiosk, lobby_fountain, lobby_palm, lobby_lamp |
| `textures/` | `palette_color.png` (color), `palette_roughness.png`, `palette_metalness.png`, `papel_picado_atlas.png` (con alpha), logos |

**Convenciones:**
- **1 unidad = 1 stud.** El origen está en el **centro de la base** de cada asset y el eje Y queda arriba.
- Un archivo puede traer **varias mallas**. Cada una se vuelve un MeshPart:
  - `<nombre>`: la malla principal (textura de paleta).
  - `<nombre>_Neon`: partes que brillan → **Material = Neon**.
  - `<nombre>_Glass`: cúpula de vidrio de la Dulcería → **Material = Glass**.
  - `papel_picado_Flags`: banderines con alpha.
- **Una sola textura de color** (la paleta) sirve para TODO. Se sube una vez y se reutiliza el mismo asset ID.

---

## 1. Importación de prueba (5 min)
1. Abrí Studio. En el menú **File**, elegí **Import** y seleccioná `export/creatures/estrellita.fbx` [Importer docs].
2. En la ventana del Importer revisá **File Geometry → Scale Unit = Studs** (es el default). Dejá **Merge Meshes = desactivado** para que `_Neon` quede separado.
3. Dale a **Import**. Va a aparecer un `Model` con el MeshPart `estrellita` adentro.
4. **Revisá la escala:** la Estrellita debe medir unos **3.5 studs de alto** (unos 4.4 de ancho). Al lado de un avatar R15 (unos 5 studs) se ve como una mascota grande.
   - Si sale 100 veces más grande o más chica, cambiá **Scale Unit** (p. ej. a Centimeters o Meters) y reimportá. Anotá cuál funcionó.
5. **Orientación:** la cara debe mirar hacia **−Z del modelo** (el "frente" de Roblox con `CFrame.LookVector`). Si mira para otro lado, rotá el modelo 180° en Y y anotalo. Todas las piñatas comparten la misma convención, así que el ajuste aplica igual para todas.

## 2. Subir las texturas (una vez)
1. **File → Import** de `palette_color.png`, `palette_roughness.png`, `palette_metalness.png` y `papel_picado_atlas.png` (también sirve el Asset Manager → Bulk Import).
2. Copiá cada asset ID (clic derecho → Copy asset ID) y pegalos en `roblox-project/src/ReplicatedStorage/Shared/Config/Assets.luau`.

## 3. Aplicar el color
**Opción A (recomendada): SurfaceAppearance (PBR).** Dentro de cada MeshPart principal:
```
SurfaceAppearance
  ColorMap      = rbxassetid://<palette_color>
  RoughnessMap  = rbxassetid://<palette_roughness>
  MetalnessMap  = rbxassetid://<palette_metalness>
  AlphaMode     = Opaque          (Enum.AlphaMode: Overlay / Transparency / TintMask / Opaque)
```
Así el Toro de Oro se ve metálico y los dulces brillantes.

**Opción B (más barata): `MeshPart.TextureID = rbxassetid://<palette_color>`.** Sin PBR, pero funciona en todo y pesa menos. Va bien para las piñatas de la Pasarela en móviles bajos.

> Las UV de cada cara caen **en el centro** de su celda de color de 16×16 px, así que el filtrado bilineal de Roblox no mezcla colores vecinos. Además, cada vértice lleva vertex color con el mismo color de respaldo.

**Partes especiales:**
| MeshPart | Propiedades |
|---|---|
| `*_Neon` | `Material = Neon`, `Color` = el neón de la rareza (p. ej. `#3FF2FF` para Sombra, `#FF4FD8` para el láser), `CastShadow = false` |
| `base_generator_Glass` | `Material = Glass`, `Transparency = 0.45`, `Color = #BFF4FF` |
| `papel_picado_Flags` | SurfaceAppearance con `ColorMap = papel_picado_atlas`, **`AlphaMode = Transparency`**, `DoubleSided = true` en el MeshPart |
| Letreros (gate, kioscos) | El texto "BASE" del arco viene modelado. Para los kioscos, el letrero viene **en blanco**: poné un `SurfaceGui` + `TextLabel` (fuente Luckiest Guy o similar) para que se pueda traducir (DULCERÍA / CANDY SHOP / DOCERIA) |

## 4. Montar cada piñata como Model jugable
```
Pinata_<id> (Model)            PrimaryPart = Body
 ├─ Body   (MeshPart principal)   Anchored = false, CanCollide = false, CollisionFidelity = Box
 ├─ Neon   (MeshPart _Neon, si existe) WeldConstraint → Body
 ├─ Root   (Part invisible 2×1×2 en la base) ← para pedestal / soldar a la espalda
 └─ Attributes: PinataId="toro", Rarity="Legendary", CandyPerSec=3500
```
- **CollisionFidelity = Box** en piñatas y props: es mucho más barato y nadie se va a parar encima.
- **RenderFidelity = Automatic** (LOD automático de Roblox).
- Guardá las piñatas en `ServerStorage/Pinatas/` (el servidor las clona). Los nombres tienen que coincidir con `Shared/Config/Pinatas.luau`.
- **Escala sobre pedestal:** las bases asumen la piñata a 1.5× sobre `base_pedestal`. Usá `Model:ScaleTo(1.5)` y no edites la malla.

## 5. Base y lobby
- `base_floor` (47.6 × 59.6 studs) es el piso de una base. Posiciones de referencia en `art/scripts/base.py → assembled()`: puerta en `z = −28`, Dulcería en `z = +22` y pedestales en `x = ±13.5` (4 filas cada 10 studs).
- `base_gate_Neon` = **láser del candado**. El servidor alterna su `Transparency` y `CanCollide` y le pone un `Part` invisible de colisión (no uses la malla neón para colisión).
- Módulos del lobby: `lobby_kiosk` (12 × 12 × 11 studs), `lobby_fountain` (radio de unos 12.7), `lobby_palm` y `lobby_lamp`. El layout está en `renders/lobby_hub_topdown.png` y en `art/scripts/lobby.py`.
- El **piso de la plaza, la Pasarela, los caminos y las colinas** NO se exportan: construilos con Parts y Terrain de Roblox (son más baratos y fáciles de ajustar). Medidas en `lobby.py`: plaza de radio 46 y alfombra de 156 × 10 studs.

## 6. Rendimiento (móvil primero)
- Activá **StreamingEnabled** en Workspace.
- Las piñatas que esperan en la Pasarela usan **Opción B** (TextureID) y sin sombras (`CastShadow = false` en las pequeñas).
- Reutilizá MeshParts: Roblox cachea por MeshId, así que 6 bases con la misma `base_gate` cuestan casi lo mismo que una.
- Revisá con **MicroProfiler** y la pestaña **Memory** del Developer Console en un celular de gama baja (WP-20 del GDD).

## 7. Reimportar después de cambios
Los assets se generan **con código** (`art/scripts/*.py`). Para cambiar algo:
```bash
cd art/scripts
blender -b --factory-startup -P creatures.py -- michi     # reconstruye, exporta y renderiza solo michi
blender -b --factory-startup -P props.py -- caja_sorpresa
blender -b --factory-startup -P base.py -- base_gate
blender -b --factory-startup -P lobby.py -- lobby_kiosk
python3 tri_report.py                                       # actualiza export/TRIANGLES.md
```
En Studio: clic derecho en el MeshPart → **Update** / reimportar con el mismo nombre, o usá el 3D Import Queue para varios a la vez.

## 8. Problemas comunes
| Síntoma | Causa probable | Solución |
|---|---|---|
| Sale todo gris o blanco | No hay textura asignada | Paso 3: SurfaceAppearance o TextureID |
| Colores corridos o mezclados | Una textura de paleta distinta, o con compresión agresiva | Usá exactamente `palette_color.png` (256×256 PNG) |
| Tamaño ×100 | Scale Unit | Paso 1.4 |
| Mira hacia atrás | Convención de ejes | Rotar el Model 180° en Y (una vez, igual para todas) |
| "Mesh resolution higher than max" | Más de 20K tris en una malla | No debería pasar (máximo actual 12,618). Revisá TRIANGLES.md |
| Banderines opacos con fondo negro | Falta el AlphaMode | `AlphaMode = Transparency` |

---

## 9. Conteo de triángulos (verificado)
Límite de Roblox: **20,000 triángulos por malla** [Specs]. Tabla generada por `scripts/tri_report.py`, que cuenta directo de los .obj exportados:

| Folder | File | MeshPart | Triangles | OK |
|---|---|---|---:|:-:|
| base | base_fence | base_fence | 936 | ✅ |
| base | base_floor | base_floor | 2,012 | ✅ |
| base | base_gate | base_gate | 6,808 | ✅ |
| base | base_gate | base_gate_Neon | 140 | ✅ |
| base | base_generator | base_generator | 9,624 | ✅ |
| base | base_generator | base_generator_Glass | 840 | ✅ |
| base | base_padlock | base_padlock | 852 | ✅ |
| base | base_pedestal | base_pedestal | 2,512 | ✅ |
| base | base_pedestal | base_pedestal_Neon | 240 | ✅ |
| base | base_signpost | base_signpost | 608 | ✅ |
| creatures | burrito | burrito | 9,848 | ✅ |
| creatures | cohetin | cohetin | 6,220 | ✅ |
| creatures | cohetin | cohetin_Neon | 316 | ✅ |
| creatures | dragon | dragon | 8,108 | ✅ |
| creatures | estrellita | estrellita | 7,280 | ✅ |
| creatures | michi | michi | 7,696 | ✅ |
| creatures | renito | renito | 7,632 | ✅ |
| creatures | renito | renito_Neon | 196 | ✅ |
| creatures | sombra | sombra | 8,632 | ✅ |
| creatures | sombra | sombra_Neon | 1,448 | ✅ |
| creatures | toro | toro | 9,260 | ✅ |
| creatures | toro | toro_Neon | 500 | ✅ |
| creatures | torogoz | torogoz | 5,892 | ✅ |
| creatures | torogoz | torogoz_Neon | 964 | ✅ |
| lobby | lobby_fountain | lobby_fountain | 3,688 | ✅ |
| lobby | lobby_fountain | lobby_fountain_Neon | 832 | ✅ |
| lobby | lobby_kiosk | lobby_kiosk | 3,088 | ✅ |
| lobby | lobby_lamp | lobby_lamp | 584 | ✅ |
| lobby | lobby_lamp | lobby_lamp_Neon | 196 | ✅ |
| lobby | lobby_palm | lobby_palm | 2,080 | ✅ |
| props | bat_gold | bat_gold | 1,646 | ✅ |
| props | bat_wood | bat_wood | 1,646 | ✅ |
| props | caja_sorpresa | caja_sorpresa | 7,768 | ✅ |
| props | caja_sorpresa | caja_sorpresa_Neon | 32 | ✅ |
| props | candy_pile | candy_pile | 12,618 | ✅ |
| props | papel_picado_banner | papel_picado_banner | 816 | ✅ |
| props | papel_picado_banner | papel_picado_Flags | 144 | ✅ |

**37 MeshParts, max 12,618 tris, 0 over the limit.**

---
**Referencias:** [Importer docs] https://create.roblox.com/docs/en-us/studio/importer.md · [Specs] https://create.roblox.com/docs/art/modeling/specifications · AlphaMode: https://create.roblox.com/docs/reference/engine/enums/AlphaMode · 3D Import Queue: https://devforum.roblox.com/t/full-release-3d-import-queue/3784554
