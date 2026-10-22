# Steal a Piñata! — Dirección de Arte

> **Una frase:** "Fiesta de cumpleaños en 3D". Son piñatas de papel crepé convertidas en criaturas gorditas con caras kawaii, colores saturados de dulce y confeti por todos lados. Tienen que leerse a 30 m y en un thumbnail de 150 px.

![key art](renders/hero_key_art.png)

---

## 1. Pilares visuales
1. **Chunky y suave.** Volúmenes grandes y redondeados con biseles en todo. Nada filoso ni realista.
2. **Flecos = identidad.** Cada piñata lleva **bandas de flecos de papel** (anillos dentados apilados con flare hacia afuera). Es el rasgo que nos separa de cualquier otro "Steal a ___".
3. **Cara siempre visible.** Ojos ovalados negros con 2 brillos blancos, boca curva y chapitas. La cara mira a la cámara 3/4. Sin cara, no hay personaje.
4. **Saturado pero ordenado.** Cada objeto usa máximo 3 o 4 colores de la paleta, con 1 dominante, 1 secundario y 1 acento. El confeti es donde se permite el arcoíris completo.
5. **Leer primero la silueta.** Común = redondo y simple. Épica en adelante = alas, cuernos y tentáculos. Mítica y Secreta = partes neón.

## 2. Paleta (oficial, `textures/palette.json` → `palette_color.png` 256×256, celdas 16×16)

| Grupo | Nombre | Hex | Uso |
|---|---|---|---|
| Fiesta | fiesta_pink | `#FF3E9A` | Color de marca, alfombra, puerta |
| | hot_magenta | `#E0187A` | Sombras de rosa y la Pasarela |
| | sun_yellow | `#FFE14D` | Dulces, estrellas, logo |
| | mango | `#FFB400` | Estrellas y acentos cálidos |
| | tangerine | `#FF7A1A` | Michi y llamas |
| | turquoise | `#16D3E8` | Contraste frío, agua, viga de la puerta |
| | lime | `#8BE530` | Hojas y flecos |
| | grape | `#8A3CF0` | Épico y Cajas |
| Neutros | white `#FFF7EC` · snow `#F4FBFF` · cream `#FFE6B8` | | Paneles, letreros y nieve |
| Tinta | ink `#1B1430` · ink_soft `#3A2A55` | | Ojos, contornos de UI y texto (**nunca negro puro**) |
| Metal | gold `#FFC22E` (metal .8) · gold_deep `#E08A00` · silver `#D9E2F2` | | Toro de Oro, candado, bordes de la Pasarela |
| Cósmico | cosmic_1..4 `#2B0F6B → #3FF2FF` | | Torogoz Cósmico y Sombra |
| Neón | neon_pink `#FF4FD8` · neon_cyan `#3FF2FF` · neon_gold `#FFD84D` · neon_green `#5CFF8A` | | Láser, auras y llamas (MeshPart `_Neon` → Material Neon) |

Hay 64 entradas en total (ver `scripts/plib.py`). **Regla:** no se agregan colores sueltos. Si hace falta uno nuevo, se agrega a la paleta y se regeneran las texturas.

## 3. Estilo de modelado (cómo se ve "bien" y no genérico)
- **Proporciones:** cabeza o cuerpo enorme (60 a 70% de la altura) y patitas cortas tipo pompón. Altura de 2.7 a 4.5 studs (avatar ≈ 5).
- **Biseles** en todo borde visible (0.08 a 0.3 studs). Atrapan luz y hacen que se vea "juguete premium".
- **Flecos:** 2 filas por banda, dientes con flare de 0.13 y colores alternos por banda. Las piñatas clásicas (Estrellita) usan arcoíris y las de especie (Michi, Burrito) usan 2 tonos de su color.
- **Ojos** proyectados sobre la superficie (raycast) para que nunca floten. Los párpados ("lid") dan actitud: dormido (Burrito), presumido (Michi) o fiero (Dragón).
- **Presupuesto:** creaturas de 5K a 10K tris (máximo real de Roblox: 20K por malla [Creator Hub]), props de 0.5K a 8K, y módulos de base de hasta 10K. Ver `export/TRIANGLES.md`.
- **Origen** en el centro de la base, a escala real en studs, eje Y arriba en la exportación.

## 4. Materiales
| Material | Cómo | Dónde |
|---|---|---|
| **Papel crepé / plástico mate** | Palette texture, roughness 0.45 a 0.6 | Cuerpos y flecos |
| **Dulce brillante** | Roughness 0.25 | Caramelos, ojos y paletas |
| **Oro** | Metalness 0.8, roughness 0.28 | Toro, candado y bordes |
| **Neón** | MeshPart separado `*_Neon`, Material Neon + Color | Láser, llamas, puntas de Sombra y nariz de Renito |
| **Vidrio** | MeshPart `*_Glass`, Material Glass, Transparency 0.4 | Cúpula de la Dulcería |
| **Papel picado** | Textura con alpha (`papel_picado_atlas.png`), SurfaceAppearance AlphaMode Transparency | Banderines |

En Roblox se usa **una sola textura de paleta** compartida por todos los MeshParts: 1 descarga, caché y memoria mínima en móvil.

## 5. Lenguaje VFX por rareza
| Rareza | Color de aro / aura | Partículas | Sonido al aparecer |
|---|---|---|---|
| Común | Blanco-celeste `#E6EEF9` | Ninguna, solo aro | "pop" suave |
| Poco común | Lima `#8BE530` | 4 confetis lentos | "pop" + campanita |
| Rara | Azul `#3DA5FF` | Chispas que suben | Arpa corta |
| Épica | Morado `#C59BFF` | Confeti en espiral + brillo de contorno | Fanfarria corta |
| Legendaria | Oro `#FFC22E` | Rayos de luz (beams) + monedas | Fanfarria + "¡OOOH!" del público, con anuncio global |
| Mítica | Rosa neón `#FF4FD8` | Estrellas fugaces y anillo pulsante | Coro + bajo |
| Secreta | Cian `#3FF2FF` sobre negro | Glitch y destellos invertidos | Silencio de 0.3 s → golpe grave |
| Evento | Rojo navideño `#FF5A6E` | Nieve y destellos | Cascabeles |

Las **mutaciones** se superponen: Dorada (shimmer dorado), Arcoíris (hue-shift animado del aura) y Navideña (gorro + nieve).
**Tope en móvil:** ≤ 40 partículas por emisor y `ParticleEmitter.Rate` escalado según la calidad gráfica del cliente.

## 6. UI
- **Tipografía:** *Luckiest Guy* (títulos, números grandes, contorno ink de 3 a 4 px) + *Fredoka* o *Nunito* bold para textos (todas son fuentes de Google; revisar disponibilidad en `Enum.Font`/`FontFace` de Roblox).
- **Forma:** paneles de esquinas muy redondeadas (UICorner 16 a 24 px), con borde blanco de 4 px + sombra ink al 25% desplazada 4 px hacia abajo (estilo "sticker").
- **Colores:** botón primario **fiesta_pink**, compra con Robux **verde lima con ícono R$**, peligro/robo **rojo chili** y candado **turquesa** pulsante.
- **Números** grandes y redondeados con abreviación (1.2K, 3.4M). Los Dulces/s saltan con tween de escala 1.0 → 1.25 → 1.0.
- **Móvil primero:** botones ≥ 44 px y las acciones principales (Batear, Candado) abajo a la derecha. Nada de texto largo; usar íconos + 1 palabra.
- **Rarezas en UI:** siempre se muestran con color + nombre + forma (marco liso, doble, con estrellas...). Así también funciona para daltónicos.

## 7. Thumbnails e ícono
**Ya listos:**
- `renders/thumbnail_1920x1080.png`: bate contra el ladrón con el Toro de Oro en el aire, confeti y logo arriba a la derecha.
- `renders/icon_512.png`: Toro de Oro + logo.
- `renders/hero_key_art.png`: la versión sin logo superpuesto (el logo está dentro de la escena, en el arco).
- Logo suelto: `textures/logo_steal_a_pinata.png` (PNG transparente).

**Conceptos para A/B (semana 1 en vivo):**
1. **"¡PÉGALE!"**: primer plano del bate a punto de pegarle al ladrón que huye con una Mítica, y texto "NO HACKERS" en una banda.
2. **"¿CUÁL ROBARÍAS?"**: 3 piñatas (Común, Legendaria, Secreta oculta con "?") sobre la Pasarela con flechas.
3. **"NAVIDAD"**: Renito con nieve y logo con gorro de Santa (diciembre).
4. **Cara gigante**: Sombra (ojo único) mirando a la cámara sobre negro y neón. Es el thumbnail "misterio".

Reglas: 1 idea por thumbnail, máximo 3 personajes, el personaje más importante ocupa ≥ 35% del alto y hay que verlo en 150 px antes de aprobarlo.

## 8. Renders de referencia
| Asset | Render |
|---|---|
| Lineup de 9 piñatas | `renders/lineup.png` |
| Base armada | `renders/base_plot_assembled.png` |
| Plaza / hub | `renders/lobby_hub.png`, `renders/lobby_hub_topdown.png` |
| Cada piñata, prop y módulo | `renders/<nombre>.png` |

## 9. Lo que evitamos
- Estereotipos (sombreros de charro, bigotes falsos y "acentos"). Lo latino entra por la comida, la fauna, el folklore y la fiesta.
- Texturas realistas, ruido o grunge; negro puro; colores apagados.
- Cualquier parecido con personajes o assets de otros juegos (riesgo legal; ver GDD [F13]).
