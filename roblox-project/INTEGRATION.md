# Integración con S1 (WP-02 y WP-10a)

Esta rama incluye `main` en `58d18c5` (PR #1). Donde el loop y S1 tocaban el mismo archivo, se quedó la implementación de S1 (ProfileStore, migraciones, `AntiCheatService`, registro) y el gameplay solo suma llamadas encima.

El loop de WP-04 a WP-08 ya no tiene un perfil en memoria ni un rate limiter propio. Usa lo que quedó en `main`.

## Datos

`DataService` es el dueño de la sesión de ProfileStore. `Server/Data/Records.luau` no copia esa tabla: `Records.get(player)` devuelve `DataService.profile(player)`, que es `profile.Data`.

| Qué | Dónde |
|---|---|
| Dulces | `DataService.trySpend` / `grant` (`Wallet`) |
| Alta de piñata | `DataService.grantPinata` → `(ok, instanceId)`. `Wallet.grantPinata` sigue devolviendo boolean. |
| Pasar una piñata de un jugador a otro | `DataService.movePinata` → `Wallet.movePinata`. El `InstanceId` no cambia. |
| Pedestal | `Wallet.place` / `unplace` sobre `Placed` (`"1"` … slot) |
| Dulcería sin reclamar | `VaultCandy` en el perfil (entero). Se suma 1 vez por segundo y al volver (`LastLeaveUnix`, 50 %, tope 8 h). |
| Candado | `LockReadyUnix` |
| Ventana de 2 robos / 5 min | `RobbedUnix` (máximo 8 timestamps) |
| Escudo | `RookieSeconds`, +1 por segundo en el server |
| Contadores | `Stats.Steals`, `Stats.TimesRobbed`, `Stats.Bonks`, `Stats.Buys`, `Stats.Collects`, `Stats.FiestaCandy` |
| Pases | `Passes.DoubleCandy`, `Vip`, `ExtraPedestals`, `AutoCollect`, `BatPack` |
| Recibos | `ProcessedPurchases[PurchaseId]`. `DataService.persist` espera a ver ese id en `LastSavedData` |

`Migrations` está en v3. Un perfil v1 o v2 recibe los campos nuevos en false / 0 / `{}` y no se rechaza. El autosave y `EndSession` los persiste ProfileStore.

El multiplicador es `Economy.totalMultiplier`: Re-Fiestas, el pase 2× **o** el boost del video (el mismo +1, no se apilan), VIP +0.5 y +0.05 por set completo del Dex. El candado suma `VipBonusSec` si `Passes.Vip`.

Una piñata cargada sigue en el `Inventory` del dueño y sale de `Placed`. `World/Transit.luau` es un set de sesión (no se guarda). Si el server se cae, el set nace vacío y la piñata vuelve al pedestal. Entregarla mueve el ítem con `movePinata`.

En Studio, un perfil vacío recibe `Tuning.PlaytestCandy` (2500) una vez por `UserId` en ese server. Un server publicado no.

## Anti-cheat

Los remotes de cliente los escucha `AntiCheatService` (payload, leaky bucket, honeypot, posición). El gameplay se anota con `AntiCheatService.register` y no abre otro `OnServerEvent`.

La distancia y el ángulo salen de `AntiCheatService.authorize(player, action, posicionDelServidor)`:

| Acción | Tope |
|---|---|
| `RequestBuy`, `RequestLock`, `RequestUpgrade`, `RequestFuse` | `Economy.Buy.MaxDistance` |
| `RequestSteal` | `Economy.Steal.MaxDistance` |
| `RequestSwing` | `Economy.Bat.MaxDistance` y `MaxAngleDeg` |

El slack de ping es el de `Validators.pingSlack`. Un intento a ≥ 200 studs se manda a `Logger` (`RequestBuy.far`, `RequestSteal.far`, `RequestSwing.range`). El cliente dispara con `Remotes.fireServer`.

## Qué se sacó

- `Adapters/ProfileAdapter.luau` (perfil en memoria y el puerto `loadProfile`)
- `Adapters/Validation.luau` (el leaky bucket paralelo)
- `Shared/Types/Profile.luau` (esquema v1 paralelo)

`Adapters/Lifecycle.luau` se queda: ordena el drop del robo antes de liberar la base. El `EndSession` lo hace `DataService` en `PlayerRemoving`, que corre después.

## WP-10b y WP-16

El movimiento, la custodia del robo, el puntaje y las ligas están en `FAIRPLAY.md`. El cliente no recibe el puntaje. El parche `StateChanged` suma `league`, `leaguePower`, `serverLeague`, `carryLocked` y `carryLockLeft` (la UI puede ignorarlos). El escudo sigue siendo `RookieSeconds` en el perfil; el server lo refleja en `rookieShieldRemaining`.
