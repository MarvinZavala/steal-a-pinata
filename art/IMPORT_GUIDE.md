# Guía de importación a Roblox Studio — Steal a Piñata!

> Para: Marvin (o cualquier agente que monte los assets en Studio).
> Todos los assets están en `art/export/<carpeta>/` en **.fbx** (recomendado) y **.obj** (respaldo). Las texturas están en `art/textures/`.
> ⚠️ Honestidad: estos archivos se generaron y verificaron en Blender, pero **no se probaron dentro de Studio** desde mi computadora (no tengo Studio). Hacé primero la importación de prueba (paso 1) y revisá escala y orientación antes de importar todo.

---

## 0. Qué hay
| Carpeta | Contenido |
|---|---|
| `export/creatures/` | 46 piñatas. Fase 1: estrellita, burrito, michi, cohetin, dragon, toro, renito, torogoz, sombra (burrito, michi, dragon, toro, renito y torogoz rehechas en fase 3, mismos ids). **Temporada Meme 1:** michi_aplausos, seis_siete, manzanin_iq, mapache_nel, fichadito, gemelos_pupusa. **Temporada Meme 2:** garrobita_terenga, fantasmita_bu, cochinito_quincena, lic_dos_peces, pinovela, chancla_teledirigida, aurazoso, abuelita_en_vivo. **Colección Random:** caracol_turbo, cactus_abrazos, aguacaton, pulpo_dj. **Colección LatAm (19, una por país; las 13 de Rara para arriba traen `_Neon`):** saltena_jugosa, cucurucho_mani, arepa_reina, completito_italiano, platanito_merenguero, baleada_con_todo, coqui_bocina, matecito_termero, gallo_pinton, aranita_nanduti, piquero_patazul, alpaca_esponjada, carretica_pura_vida, harpia_despeinada, carpincho_tranqui, quetzalete, chivita_rumbera, boto_bailao, ajolote_trajinero. Dragón ahora trae `_Neon` (chispitas) |
| `export/base/` | base_floor, base_gate, base_padlock, base_generator, base_pedestal, base_fence, base_signpost |
| `export/props/` | bat_wood, bat_gold, caja_sorpresa, candy_pile, papel_picado_banner |
| `export/lobby/` | Plaza v2 (15 módulos exportados): lobby_shop_dulceria / _bates / _cajas / _vip, lobby_fountain, lobby_fabrica_gate, lobby_bench, lobby_planter, lobby_lamp, lobby_light_pole, lobby_string_lights, lobby_papel_garland, lobby_palm, lobby_flamboyan, lobby_candy_cart. `lobby_pasarela_seg` está en `scripts/lobby.py` pero **no hay FBX/OBJ** en esta carpeta |
| `textures/` | `palette_color.png` (color, 1024×1024), `palette_roughness.png`, `palette_metalness.png`, `papel_picado_atlas.png` (con alpha), logos |
| `textures/plaza/` | Pisos de la plaza para **MaterialVariant**: `plaza_tiles_*` (baldosa de barro biselada), `plaza_cobble_*` (adoquín), `plaza_mosaic_*` (mosaico del sol, con alpha). Ver §5.1 |

**Convenciones:**
- **1 unidad = 1 stud.** El origen está en el **centro de la base** de cada asset y el eje Y queda arriba.
- Un archivo puede traer **varias mallas**. Cada una se vuelve un MeshPart:
  - `<nombre>`: la malla principal (textura de paleta).
  - `<nombre>_Neon`: partes que brillan → **Material = Neon**.
  - `<nombre>_Glass`: cúpula de vidrio de la Dulcería → **Material = Glass**.
  - `<nombre>_Sign`: letrero con texto modelado (tiendas y FÁBRICA). Va aparte para poder reemplazarlo por un `SurfaceGui` traducible.
  - `<nombre>_Water`: agua de la fuente → `Material = Glass`, `Transparency = 0.35`, `Color = #25C7E0`.
  - `<nombre>_Flags`: banderines de papel picado (atlas con alpha).
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

> Las UV de cada cara caen **en el centro** de su celda de color de 64×64 px (la paleta pasó de 256 a 1024 px para que no se vea pixeleada; la cuadrícula de 16×16 celdas no cambió, así que las UV viejas siguen sirviendo), así que el filtrado bilineal de Roblox no mezcla colores vecinos. Además, cada vértice lleva vertex color con el mismo color de respaldo.

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

### 5.1 Plaza v2 (lobby)
El layout de referencia es `renders/lobby_hub_topdown.png` y las posiciones exactas están en `art/scripts/lobby.py → scene()` (constantes `PLAZA_X`, `SHOP_X`, `PLOTS_Y`, `PY`).
- **Tiendas** (`lobby_shop_*`, unos 23 × 14 × 25 studs, escaladas ×1.15 en la escena): cada una trae la malla principal, `_Neon` (focos del toldo y del mostrador) y `_Sign` (letrero DULCERÍA / BATES / CAJAS / VIP). Las de los extremos van giradas 12° hacia la fuente. Dejá `CanCollide` solo en una `Part` de caja invisible por tienda; la puerta en arco tiene 5 studs de fondo para el ProximityPrompt.
- **Fuente** (`lobby_fountain`): principal + `_Water` (cortinas de agua, Glass) + `_Neon` (luces bajo el agua). Encima va la estatua dorada de la Estrellita: usá `estrellita` con `Material = Foil`/`Metal`, `Color = #FFC93C`.
- **FÁBRICA** (`lobby_fabrica_gate`): arco del Gacha/Fábrica de piñatas, al inicio de la Pasarela. Trae `_Sign` y `_Neon`. La cortina de tiras de colores es parte de la malla principal; poné un `Part` invisible `CanCollide=false` como trigger.
- **Guirnaldas** (`lobby_string_lights`, `lobby_papel_garland`): vienen modeladas de 0 a 24 studs de largo. Escalalas en X para otros tramos (hasta ±25% se ve bien). `_Flags` usa el atlas de papel picado con `AlphaMode = Transparency`.
- **Pisos de la plaza (NO exportados como malla):** construí la plaza, los bulevares y el disco central con Parts de Roblox y **MaterialVariant**:
  | MaterialVariant | BaseMaterial | ColorMap / NormalMap / RoughnessMap | StudsPerTile |
  |---|---|---|---|
  | `PlazaTiles` | Brick | `plaza_tiles_color/normal/roughness.png` | 16 (8×8 baldosas de 2 studs) |
  | `PlazaCobble` | Cobblestone | `plaza_cobble_color/normal/roughness.png` | 16 |
  Para el **mosaico del sol** (disco de radio 25.2 en el centro), usá un `Decal` con `plaza_mosaic_color.png` (tiene alpha) sobre un cilindro plano, o una `SurfaceAppearance` con `AlphaMode = Overlay`. Medidas: plaza de 116 × 90 studs (X ±58, Y −42…48), bulevares de 11 studs a cada lado que llegan a las 6 bases.
- La **Pasarela** se arma con 4 segmentos de 24 studs (`pasarela_seg` en `lobby.py`). El módulo `lobby_pasarela_seg` **no está exportado** en `export/lobby/`: generá el FBX con `blender -b --factory-startup -P lobby.py -- lobby_pasarela_seg` antes de importarlo. Colinas, volcán y nubes del render son decorado: hacelos con Terrain.

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
blender -b --factory-startup -P lobby.py -- lobby_shop_bates   # un módulo
blender -b --factory-startup -P lobby.py -- final              # escena completa + renders (unos 20 min)
blender -b --factory-startup -P memes.py -- seis_siete
python3 tri_report.py                                       # actualiza export/TRIANGLES.md
```
En Studio: clic derecho en el MeshPart → **Update** / reimportar con el mismo nombre, o usá el 3D Import Queue para varios a la vez.

## 8. Problemas comunes
| Síntoma | Causa probable | Solución |
|---|---|---|
| Sale todo gris o blanco | No hay textura asignada | Paso 3: SurfaceAppearance o TextureID |
| Colores corridos o mezclados | Una textura de paleta distinta, o con compresión agresiva | Usá exactamente `palette_color.png` (1024×1024 PNG) |
| Tamaño ×100 | Scale Unit | Paso 1.4 |
| Mira hacia atrás | Convención de ejes | Rotar el Model 180° en Y (una vez, igual para todas) |
| "Mesh resolution higher than max" | Más de 20K tris en una malla | Revisá `export/TRIANGLES.md`. Ninguna malla de la fase 2 pasa de 20K (`lobby_shop_cajas` quedó en 18,956; `candy_pile` en 4,562) |
| Banderines opacos con fondo negro | Falta el AlphaMode | `AlphaMode = Transparency` |

---

## 9. Conteo de triángulos (verificado)
Límite de Roblox: **20,000 triángulos por malla** [Specs]. La tabla viva la genera `scripts/tri_report.py` desde los .obj y queda en `export/TRIANGLES.md` (no se duplica acá, para que no se quede en el kiosco v1).

Al integrar la fase 2 el reporte dice **73 MeshParts, máximo 19,620, 0 sobre el límite**. `lobby_shop_cajas` quedó en **18,956** (disuelto planar a 5° solo en el "?" del ícono). `candy_pile` quedó en **4,562**.

---
**Referencias:** [Importer docs] https://create.roblox.com/docs/en-us/studio/importer.md · [Specs] https://create.roblox.com/docs/art/modeling/specifications · AlphaMode: https://create.roblox.com/docs/reference/engine/enums/AlphaMode · 3D Import Queue: https://devforum.roblox.com/t/full-release-3d-import-queue/3784554
