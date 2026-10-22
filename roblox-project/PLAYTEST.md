# Probar WP-04 a WP-08 en Studio

No hace falta subir los mesh. Al dar Play, `PlaceBuilder` arma la plaza, la Pasarela y 6 bases con Parts. Si más adelante hay modelos en `ServerStorage/Pinatas/<id>`, se usan solos; si no, cada piñata es una esfera con aro de neón.

## Una vez

1. En Studio, conectá el plugin de Rojo a `rojo serve` desde `roblox-project/` (ver `README.md`).
2. `Workspace → Server Authority → AuthorityMode = Server` (prende StreamingEnabled y la simulación del servidor). Sin eso el juego corre igual, pero un cliente puede pelearse con el knockback: el servidor igual intenta `SetNetworkOwner(nil)` durante el batazo.
3. Play. En la consola tiene que aparecer `[SelfCheck] N pruebas ok` y `[Piñata] TuNombre → base 1`.

En Studio el perfil vacío arranca con **2500 Dulces** (`Tuning.PlaytestCandy`) para poder comprar. Un server publicado no los da.

## WP-04 — Bases

- Entrá: te asigna una base libre (hay 6) y aparecés adentro, con el bate equipado.
- En el piso hay 8 pedestales; los primeros 4 están claros y el resto oscuros (todavía no se compran: eso es WP-09).
- Comprá algo en la Pasarela (abajo). Camina solo al pedestal. El letrero de la Dulcería sube `+N/s` cada segundo.
- Pisá la plataforma amarilla de la Dulcería estando dentro de tu base: los Dulces pasan a tu contador (arriba, y en la leaderboard `Dulces`).
- El tope es 5 min de producción (`Economy.VaultCapSeconds`). Cuando se llena, el número deja de crecer hasta que juntás.
- Salí (o en un server de 2 jugadores, andate). La base queda `LIBRE` y **no queda ninguna piñata en el mundo**. Volvé a entrar en el mismo server: están otra vez, y si pasó tiempo se suma la ganancia offline al 50 % con tope de 8 h.
- La prueba de "8 jugadores, bases distintas, y al salir se libera" está en `AssignPlots` (el mapa de esta fase tiene 6, como el GDD §12; el algoritmo está probado con 8).

## WP-05 — Pasarela

- La alfombra magenta está en Z = −52. Sale una piñata cada 4 s desde el arco **FÁBRICA** y cruza en 40 s hacia **SALIDA**.
- Prompt **Comprar** (o **¡Tomar!** si es Secreta, que no tiene precio en Dulces). También existe el remote `RequestBuy(slotId)`.
- Sin Dulces, una de precio fijo se rechaza y se queda en la alfombra. Sin pedestal libre, también.
- Legendaria o mejor: cartel arriba ~5 s antes de que aparezca.
- Los pesos (200 000 spawns, ±0.5 puntos) los corre el SelfCheck al arrancar y `lune run tests/run.luau`.

## WP-06 — Robo

Hacen falta 2 jugadores: Test → Start Server and Players → 2.

- El escudo de novato dura 15 min de juego total. Con el perfil de práctica **ya estás protegido**: para probar el robo, en la consola del servidor podés subir el tiempo jugado o bajar `Economy.RookieShieldSec` en una sesión local. El HUD dice `protegido Ns` mientras dure.
- Prompt **Robar** (hold 0.6 s) en una piñata ajena, a ≤ 8 studs, base sin candado, sin cargar otra, con un pedestal libre.
- Queda soldada **sobre la cabeza**, WalkSpeed 11, aro rosa y confeti detrás.
- Al entrar a tu propia base, pasa a ser tuya y camina a un pedestal (confeti).
- Un remote disparado a 200 studs se rechaza y la consola muestra `[AC] ... RequestSteal.far`.
- Si te noquean los golpes que pide la rareza (1, o 2 si es Legendaria o mejor), la piñata vuelve caminando a su dueño y 3 s no se puede agarrar. Después sí, con el mismo prompt.
- Máximo 2 robos por víctima cada 5 min. Después de un robo, la base víctima recibe 20 s de láser gratis (el ladrón tiene 4 s para salir, si no el láser lo encierra).
- Si el ladrón se desconecta o se muere, la piñata vuelve. Si el dueño no está, queda en su perfil: al reconectar aparece. No se duplica.

## WP-07 — Bate

- Click / botón **BATE** (84 px, abajo a la derecha) dispara `RequestSwing`.
- El servidor exige cooldown 0.8 s, ≤ 9 studs y ≤ 70° al frente, medido con la posición del servidor.
- Hit válido: aturdimiento 1.5 s, impulso, highlight, cartel **¡BONK!**, flash y un shake chico en quien lo ve.
- El primer golpe a una Legendaria+ la tambalea pero no la suelta. El segundo, sí.
- Un swing al vacío gasta cooldown y no se loguea. Uno a alguien que está al doble de rango o más, sí (`RequestSwing.range`).

## WP-08 — Candado

- Prompt **Candado** en el candado de tu puerta, o el botón **CANDADO**.
- 30 s de láser (VIP +10, Re-Fiesta +5 cada una, tope 60) y después 60 s de cooldown. El anillo sobre la puerta muestra los segundos y solo se lee de cerca (`MaxDistance` 140).
- Con el láser prendido, otro jugador no cruza (grupo de colisión; el dueño sí sale) y `RequestSteal` responde `locked`.
- Al irte, el láser se apaga. El cooldown queda en el perfil.

## Pruebas sin Studio

Desde `roblox-project/`, con [Lune](https://github.com/lune-org/lune):

```bash
lune run tests/run.luau
```

Cubre asignación, Dulces/s a 10 min (±1 %) y tope, offline, pesos de la Pasarela, compra sin Dulces, reglas de robo y de bate, duración del candado, y el ápice del salto. `selene src` y `stylua --check src` tienen que pasar; este PR no toca la CI ni `rokit.toml` (los está armando S1).
