# Juego limpio (WP-10b) y ligas (WP-16)

El servidor decide. El cliente no manda posiciones ni un puntaje. Un flag no es un ban: el puntaje vive en la sesión y se borra al salir.

Los números están en `Shared/Config/FairPlay.luau`, `Tuning.luau` y `Security.luau`. La lógica pura (`MovementSanity`, `PlotSolids`, `CarryIntegrity`, `BatSpam`, `Suspicion`, `LeagueRules`) la corre `lune run tests/run`.

## Qué hace el server

| Check | Si falla | Respuesta |
| --- | --- | --- |
| Velocidad / teleport / vuelo | Contra `Tuning` (16 y 11), con slack de ping y una ventana de knockback (`KnockbackGraceSec`) | Log. El teleport, el noclip y el vuelo se corrigen al instante. La velocidad solo vuelve atrás cuando el puntaje pide rubber-band |
| Noclip | Entrar o salir de una base atravesando la cerca. La puerta no cuenta. Rozar la cerca por afuera tampoco | Rubber-band a la última posición buena |
| Soltar por la pared / entregar lejos | La piñata no puede cruzar la cerca ni quedar a más de `MaxCarrySeparation` studs | No se entrega. Suma puntaje |
| Dupe de rejoin o crash a mitad del robo | El ítem sigue en el inventario de la víctima hasta `deliver`. El ledger es memoria de este server. Un rejoin aborta el tránsito y no copia el ítem | La segunda entrega se rechaza |
| Autoclick del bate | Ráfaga bajo 0.2 s, o más intentos que el cooldown de 0.8 s en la ventana | El swing no pega. El puntaje sube como máximo cada 2 s |
| Liga más alta contra una más baja | Fuego no le roba a Confeti. Serpentina tampoco | `RequestSteal` responde `tier` |
| Escudo de novato | 15 min de `RookieSeconds` (`Economy.RookieShieldSec`) | Nadie roba ni es robado. Al cumplirse el tiempo, `rookieShieldRemaining` queda en 0 |

Escalera del puntaje (`FairPlay.Weights`): log → rubber-band (6) → candado de carga 25 s (12) → kick (18). El kick cierra la sesión y deja volver a entrar. No escribe un ban en el perfil. Con el puntaje en 18, si `KickEnabled` está en false, se queda en el candado de carga.

El offline de WP-16 ya está en `OfflineEarnings`: 50 % y tope de 8 h. No se reimplementa acá.

## Ligas y servers

Poder = Dulces/s de la base.

| Liga | Poder |
| --- | --- |
| Confeti | 0 a 2 000 |
| Serpentina | 2 000 a 100 000 |
| Fuego | 100 000 en adelante |

`OpenLeagues` arranca en Confeti y Serpentina. Fuego, mientras no esté en esa lista, va a Serpentina (un escalón) y **nunca** a un server Confeti. Si la única liga abierta queda por debajo de más de un escalón, el destino es Mixto. Para abrir la tercera liga, agregá `"Fuego"` a `OpenLeagues`.

En un server publicado:

1. El jugador entra. Si el server público todavía no tiene liga, se queda con la de él (`claim`).
2. Si la liga del server no es la suya, `LeagueService` busca un server reservado en MemoryStore (`StealAPinata_Leagues_v1`).
3. Si esa liga no tiene nadie, y `PreferMixedWhenEmpty`, usa un server Mixto.
4. Si no hay ninguno, `TeleportService:ReserveServer` y `TeleportAsync` con `TeleportOptions` (`league` + `accessCode` en el TeleportData).
5. El server reservado publica su código para que el siguiente jugador de la misma liga entre ahí.

Un server privado (dueño distinto de 0) no redirige y no se publica. El escudo y la regla de ligas siguen activos: un amigo de Fuego no le vacía la base a uno de Confeti.

En Studio, y si `workspace:SetAttribute("SkipLeagueTeleport", true)` antes de Play, no hay teleport. El atributo `League` igual se calcula y el robo entre ligas se frena.

## Qué puede leer la UI

No está en el HUD de hoy (`UIState.patch` ignora claves que no conoce). El server las manda igual, en el `StateChanged` de siempre:

- `league`, `leaguePower`, `serverLeague`
- `carryLocked`, `carryLockLeft`
- `rookieShieldRemaining` / `rookieLeft` (ya los pinta el escudo)

Atributos del jugador, por si el HUD los lee directo: `League`, `LeaguePower`, `ServerLeague`, `RookieLeft`.

El puntaje, el último motivo y la lista de flags **no** se replican.

## Vista de admin

Solo en el servidor, `ServerStorage.FairPlayDebug`:

- `Report` (StringValue): liga, poder, puntaje, respuesta y el último motivo. Sin inventario ni posiciones.
- `KickEnabled` (BoolValue): en false el kick no saca al jugador (útil para un playtest). El rubber-band y el candado de carga siguen.

Command bar, vista **Server**:

```lua
local AC = require(game.ServerScriptService.Server.Services.AntiCheatService)
print(AC.report())
```

## Cómo probarlo en Studio

1. `rojo serve` en `roblox-project/` y Play con AuthorityMode = Server (ver `PLAYTEST.md`).
2. Output: `[WP-10b] movimiento, carga y puntaje` y `[WP-16] ligas abiertas: Confeti, Serpentina`.
3. Escudo: el HUD dice protegido. En la command bar del **server**:

```lua
local DS = require(game.ServerScriptService.Server.Services.DataService)
local data = DS.profile(game.Players:GetPlayers()[1])
data.RookieSeconds = 15 * 60 - 5
```

A los ~5 s `rookieShieldRemaining` llega a 0. Con dos jugadores, antes de eso `RequestSteal` no roba. Después sí, si la liga lo permite.

4. Liga: un jugador nuevo queda en `Confeti` (atributo `League` y el parche `StateChanged`). Para ver la regla de ligas con dos jugadores, vencé el escudo de los dos y dale una Sombra al primero (75 000/s, Liga Serpentina):

```lua
local DS = require(game.ServerScriptService.Server.Services.DataService)
DS.grantPinata(game.Players:GetPlayers()[1], "sombra", "None")
```

Al tick siguiente su `League` pasa a `Serpentina`. Ese jugador no puede robarle al de Confeti. El de Confeti sí puede intentar robarle a él. Fuego (100 000/s o más) usa la misma regla: no entra a un server Confeti y no roba hacia abajo. Ese corte está en `lune` (`destination` y `canSteal`). En Studio no hay teleport.

5. Admin: abrí `ServerStorage.FairPlayDebug.Report` mientras Play. Mové al personaje con un plugin muy lejos: tiene que aparecer `teleport` o `speed` y, si el puntaje llega a 6, volver a la última posición buena. No tiene que haber ban en el perfil.
6. Bate: un click normal pega. Un macro por debajo de 0.2 s no pega y suma `bat_spam` como máximo cada 2 s.
7. Carga: robá (escudo vencido, misma liga) y desconectá al ladrón. La piñata vuelve al dueño. No aparece en el inventario del ladrón al reconectar.

En un server publicado, un jugador de Fuego que cae en un server Confeti es teletransportado. Si MemoryStore o Teleport fallan, se queda y el robo entre ligas igual no pasa. El output dice `[WP-16] sin server` o `[WP-16] teleport`.

## Checklist de aceptación

- [ ] Un novato (menos de 15 min) no puede ser robado ni robar. Al cumplirse el tiempo, el escudo se apaga.
- [ ] Un jugador de Liga Fuego no entra a un server Confeti (en Studio no se teletransporta; la regla de destino está en `lune` y el robo entre ligas sí se puede ver).
- [ ] Las ganancias offline siguen en 50 % con tope de 8 h.
- [ ] Speed, teleport y noclip flaggean. Un knockback dentro de la ventana no flaggea. No hay ban al primer flag.
- [ ] No se entrega una piñata desde lejos ni a través de la cerca.
- [ ] Un rejoin o un crash a mitad del robo no duplica la piñata.
- [ ] Una ráfaga de bate no pega y sube el puntaje con techo.
- [ ] El puntaje pasa por log, rubber-band, candado de carga y kick. El kick deja volver a entrar.
- [ ] `ServerStorage.FairPlayDebug` se lee en el server y no le llega al cliente.
- [ ] Un server privado no redirige, y un ladrón de liga más alta igual no roba a uno de liga más baja.
