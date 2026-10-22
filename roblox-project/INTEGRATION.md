# Integración con S1 (WP-02 datos y WP-10a anti-cheat)

El gameplay de WP-04 a WP-08 **no escribe** `DataService.luau` ni `Services/AntiCheat/*`. Esos archivos los está implementando otro agente. Este código habla con dos módulos chicos. Cuando S1 esté listo, se reemplaza el adaptador o se conecta el puerto: los servicios de juego no cambian.

## Datos — `Server/Adapters/ProfileAdapter.luau`

Todo el dulce, las piñatas y el escudo salen de acá.

```lua
ProfileAdapter.bind(dataService) -- BaseService.init ya lo llama con services.DataService
ProfileAdapter.load(player) --> ProfileData
ProfileAdapter.get(player) --> ProfileData?
ProfileAdapter.getByUserId(userId) --> ProfileData?
ProfileAdapter.release(player) -- sella lastLogoutUnix y, si hay puerto, commit + releaseProfile
```

Si `DataService` expone estas funciones, el adaptador las usa. Si no (el stub de hoy), la sesión vive en memoria y **sobrevive a salir y volver en el mismo server**. No persiste si se cierra el server: eso es ProfileStore.

| Método en DataService | Cuándo se llama | Contrato |
|---|---|---|
| `loadProfile(player) -> table?` | La primera vez que vemos ese UserId | Tabla del esquema v1, o `nil` si es jugador nuevo. Si tira error, se avisa y se sigue en memoria. |
| `commit(player, data)` | Cada 30 s y al salir | Guardar la tabla. Tiene que ser idempotente. |
| `releaseProfile(player)` | Al salir, después de `commit` | Soltar el session lock. |

En un reingreso **al mismo server** se reutiliza la tabla que ya está en memoria (el robo en curso vive ahí). `loadProfile` no se vuelve a llamar para no pisar esa sesión con un snapshot viejo. Si el modelo de sesión de S1 necesita un lock por cada join, lo correcto es reemplazar este archivo, no parchar los servicios.

### Esquema v1 (`Shared/Types/Profile.luau`)

`Profile.hydrate` completa lo que falte y tira campos de tipo raro, así un perfil a medias no tumba el server.

| Campo | Tipo | Uso |
|---|---|---|
| `schemaVersion` | number | Siempre `1` |
| `candy`, `bastones` | number | Billetera |
| `reFiestas`, `has2x`, `hasVip`, `setsDone` | number / bool | Entran a `Economy.totalMultiplier` |
| `pedestalCount` | number | Arranca en `Economy.StartPedestals` (4) |
| `vaultTier` | number | Índice 1..4 de `Economy.VaultCapSeconds` |
| `vaultCandy` | number | Lo que hay en la Dulcería, sin reclamar |
| `pinatas` | `{ uid, pinataId, mutation?, pedestal?, inTransit? }` | Inventario. `inTransit` = alguien la está cargando |
| `totalPlaySeconds` | number | Escudo de novato (15 min) |
| `lastLogoutUnix` | number? | Para la ganancia offline (50 %, tope 8 h) |
| `robbedAt` | `{ number }` | Unix de cada robo sufrido (máximo 2 / 5 min) |
| `lockCooldownUntil` | number | Unix. El láser en sí no se persiste: al salir la base se vacía |
| `lastStealUnix`, `stealTimes` | | Reservados; el cooldown de 1.5 s es de sesión |

`inTransit = true` y un crash: al cargar en frío el adaptador lo limpia, así la piñata **vuelve al dueño**. No se duplica y no se pierde. Entregar en la base propia sí mueve el registro de un perfil al otro (`Shared/Gameplay/Inventory.luau`).

Los Dulces de práctica (`Tuning.PlaytestCandy`, 2500) solo se suman en Studio y solo si el perfil llega vacío. Un server publicado no los regala.

## Anti-cheat — `Server/Adapters/Validation.luau`

Único archivo de este PR que hace `require` de `Services/AntiCheat/`.

| Función | Delega en |
|---|---|
| `allow(player, key)` | `RateLimiter` (capacidad 5, fuga 2/s) |
| `root`, `inRange`, `inFront` | `Validators` (incluye el slack de ping) |
| `isFinite` | `Validators.isFiniteNumber` |
| `distance` | magnitud en el servidor, para el log |
| `flag(player, reason, data)` | `Logger.flag` |

Las reglas de juego (robo, bate, compra, candado, pesos, offline) están en `Shared/Gameplay/*` y se testean sin el motor. El server arma el input con lo que mide `Validation`, así que si S1 cambia la fórmula de ping, el gameplay la hereda sin copiarla.

Un remote a ≥ 200 studs se rechaza (`StealRules` / `BatRules`) **y** se manda a `Logger` con `RequestSteal.far` o `RequestSwing.range`. Un swing que no llega por poco no se loguea: es un whiff.

## Qué no hay que mover

- `init.server.luau` ya prende los servicios en orden. No hizo falta tocarlo.
- Los remotes usados ya estaban en `Shared/Net/Remotes.luau`: `RequestBuy`, `RequestSteal`, `RequestSwing`, `RequestLock`, `StateChanged`, `Feedback`, `Announce`.
- `Economy.luau` ganó tres bloques (`Buy`, `Return`, `StealPromptHoldSec`, `Steal.WindowSec`, `Conveyor.AnnounceLeadSec`). El resto de los números de diseño sigue ahí. La física está en `Shared/Config/Tuning.luau`, no en Economy.

## Ganchos que S1 / los WP de después pueden llamar

| Función | Para qué |
|---|---|
| `ConveyorService.setServerLuck(seconds)` | Suerte de Server (WP-11). Duplica el peso de Rara para arriba. |
| `LockService.grant(plotIndex, seconds, ownerUserId)` | Candado de emergencia o el de 20 s post-robo. No gasta el cooldown manual. |
| `LockService.tryActivate(player)` | Candado del dueño. Sí gasta el cooldown. |
| `BaseService.hasRoom` / `acceptPurchase` / `pushState` | Comprar sin pasar por la Pasarela (FTUE, fiesta). |
| `ProfileAdapter.isRookie(player)` | El escudo. Los primeros 15 min de `totalPlaySeconds` no se roba ni te roban. |
| `Movement.setMode(player, "normal" \| "carry" \| "stun")` | Dueño de `WalkSpeed`. No lo pise otro sistema. |
