# UI → servidor

La UI no crea `RemoteEvent`. Manda intenciones con `Remotes.fireServer` y solo si la instancia ya está en `ReplicatedStorage.Remotes` (si el servidor todavía no arrancó, el clic no se queda colgado). Las specs están en `Shared/Net/Payload.luau`. `Shared/Net/UIRemotes.luau` solo lista los nombres nuevos y comprueba que el catálogo los tenga. `Remotes.init()` los crea; `AntiCheatService` escucha todos los C2S.

No registres un segundo `LogFunnelStepEvent` para el mismo paso: el cliente ya lo manda a Analytics. El servidor puede guardar la recompensa, no el embudo.

## Remotes que ya existían

| Nombre | Dirección | Args |
| --- | --- | --- |
| `RequestBuy` | C2S | slot de la Pasarela (`number`) |
| `RequestSteal` | C2S | `userId`, `pedestal` |
| `RequestSwing` | C2S | — |
| `RequestLock` | C2S | — |
| `RequestUpgrade` | C2S | `"Pedestal"` \| `"VaultCap"` \| `"ReFiesta"` (`Security.Upgrades`) |
| `RequestFuse` | C2S | `pinataId` del roster |
| `StateChanged` | S2C | parche de estado (abajo) |
| `Feedback` | S2C | `kind`, `payload` |
| `Announce` | S2C | `text`, `rarity` |

## Remotes de esta UI

| Nombre | Dirección | Args | Qué hace el servidor |
| --- | --- | --- | --- |
| `RequestCollect` | C2S | — | Nada. El cobro es el pad amarillo `Collect` de la base (`BaseService`). El botón del HUD se esconde en cuanto llega `StateChanged`. El remote queda en el catálogo para no romper los tests; un payload válido se ignora |
| `RequestSettings` | C2S | `locale`, `music`, `sfx`, `reduceMotion`, `cameraShake` | `UiIntentService` los guarda en la sesión y los devuelve en el próximo `StateChanged`. `locale` es `"auto"` `"es"` `"en"` `"pt"`. Volúmenes 0–1. No es un campo del perfil |
| `RequestFTUEStep` | C2S | un paso de `Security.FtueSteps` | Reacciona al guion real (abajo). No loguea el embudo |
| `RequestFTUEAction` | C2S | `claim` `bonk` `collect` `buy` `complete` `skip` | `bonk` saca al Ladronzuelo. `complete` y `skip` marcan `FtueCompleted`. `claim`, `collect` y `buy` no regalan nada: eso lo hacen la Pasarela y el pad |
| `OpenShop` | S2C | `kiosk`: `"dulceria"` `"bates"` `"cajas"` `"vip"` o `""` | El servidor, al entrar a un kiosco. `FireClient`, no `fireServer` |

`RequestUpgrade` (`"Pedestal"` \| `"VaultCap"` \| `"ReFiesta"`) lo registra `UiIntentService`. Cobra con `Records.trySpendDulces` al precio de `ShopCatalog` (el mismo que muestra el kiosco), sube `PedestalsOwned` hasta `Economy.MaxPedestals` y repinta los pads, o sube `VaultCapTier`, o suma una Re-Fiesta si hay una Epic en el inventario. Si falta plata manda `Feedback` `DENIED` con `poor`.

`RequestSwing` lo disparan el botón BATE y la tool `Bate` (un solo intento). `RequestLock` lo dispara el botón CANDADO. No hay un segundo HUD.

`RequestFuse` sigue sin handler: un payload válido no fusiona.

## Parche `StateChanged`

Solo se aplican estas claves. Un campo ausente no borra el valor anterior. `nil` no viaja: para soltar la piñata mandá `carrying = false` o `clearCarrying = true`.

- Números: `candy`, `candyPerSec`, `bastones`, `pedestalCount`, `pedestalCap`, `vaultTier`, `vaultStored`, `rookieShieldRemaining`, `myLockRemaining`, `myLockCooldown`, `fiestaRemaining` (`-1` = sin fiesta), `reFiestas`, `multiplier`
- `owned`: `{ uid, pinataId, mutation, pedestal? }`
- `carrying`: `{ pinataId, mutation, fromUserId, hitsLeft }`
- `nearbyLocks`: `{ userId, name, remaining, cooldown }` (el nombre se corta a 24)
- `passes`: `doubleCandy`, `vip`, `extraPedestals`, `autoCollect`, `batPack`
- `settings`: `locale` (`""` o `"auto"` = idioma del cliente), `music`, `sfx`, `reduceMotion`, `cameraShake`
- `batSkin`: string
- `ftueCompleted`: boolean

El servidor manda las dos formas de cada número para que el HUD viejo y el nuevo lean lo mismo: `candy` y `vault` / `vaultStored`, `perSec` / `candyPerSec`, `rookieLeft` / `rookieShieldRemaining`. `carrying = false` suelta la piñata; si hay carga es `{ pinataId, mutation, fromUserId, hitsLeft }`. También manda `owned`, `pedestalCount`, `vaultTier`, `reFiestas`, `multiplier`, `ftueCompleted`, `myLockRemaining`, `myLockCooldown` y, si ya se guardaron, `settings`.

El primer `StateChanged` apaga el presenter offline y esconde el botón de juntar. Antes de eso, y solo si no hay plaza, Studio predice el FTUE (Michi dorado, +250, Burrito). Esas predicciones no pisan un estado autoritativo. El cliente, por las dudas, copia `vault` → `vaultStored`, `perSec` → `candyPerSec` y `rookieLeft` → `rookieShieldRemaining` si falta la clave nueva.

## `Feedback`

`BONK`, `ROBBED`, `PURCHASE` / `PURCHASED`, `COLLECT` (`payload.amount`), `RETURNED`, `DENIED` (`payload.key` = `poor`, `shield`, … o una clave del catálogo), `ANNOUNCE` (también llega por el remote `Announce`), `TOAST` (`payload.key` o `payload.text`).

Los textos de la UI salen de `Shared/Locale/Catalog.luau` (es, en, pt) y se cargan en `LocalizationService.FiestaUI`. No uses `RichText` con nombres de jugadores.

## FTUE

Guion en `Shared/UI/FTUEScript.luau` (GDD §10.1). El cliente llama `LogFunnelStepEvent` y `LogCustomEvent("ftue_<paso>")`. El servidor no vuelve a loguear ese embudo. Saltar (solo Studio) manda `RequestFTUEAction` `"skip"` y `ftue_skip` en analytics.

Con perfil y plaza (`StateChanged` y tag `Pasarela` / `FTUEBase`) la intro no tapa el mundo:

1. Picada de la fuente (`FTUEFountain`) a tu base (`FTUEBase` con tu `OwnerUserId`).
2. Flecha a la Pasarela. Al acercarte, el servidor ofrece un Michi Golden con precio nil (el prompt dice Tomar; `BuyRules` lo trata como gratis).
3. Espera a que `owned` tenga el Michi. No hay un segundo botón TOMAR.
4. Aparece el Ladronzuelo (parte anclada, no es un jugador) caminando al pedestal 1.
5. La flecha marca el BATE del HUD. Ese clic sí manda `RequestSwing` y además `RequestFTUEAction` `"bonk"`, que despacha al bot y tira el jugo de BONK. Slow-mo 0.4 s en el cliente.
6. El texto muestra el +9/s de base del Michi. El contador muestra el `perSec` del servidor (el Golden es ×2, así que verás 18/s).
7. Flecha al pad `Collect`. El servidor deja al menos 250 en `VaultCandy`. Juntar es pisar el pad, no `RequestCollect`.
8. Flecha a la Pasarela, donde sale el Burrito a su precio real (75).

`FtueCompleted` queda en el perfil. `SkipFTUE` (atributo de `ReplicatedStorage`, o el botón Saltar) lo marca también, así un reingreso no regala otro Michi.

Sin plaza (preview o Studio sin mundo) sigue el teatro de papel, con las recompensas locales y sin remotes de intro. El preview no escribe el perfil.

## Preview

En Studio (o con el attribute `UIPreview`) aparece el botón Preview, o escribís `/ui`. Ahí se ven HUD, robo, inventario, los 4 kioscos, ajustes, toasts y la intro, en teléfono / vertical / tablet / PC. Los eventos del embudo en preview llevan `source = preview`.

## Precios provisionales

Si `Economy` no trae `VaultUpgradeCost` ni `ReFiestaCandy`, la Dulcería usa 2500 / 15000 / 80000 y 500000. El día que aparezcan en `Economy`, se leen solos. Los pases con `Id == 0` muestran «Pronto» y no abren el prompt de Robux.

## Cómo probarlo en Studio

1. `rojo serve` en `roblox-project/`.
2. Play. Si la plaza existe, no aparece el teatro: seguí la flecha, tomá el Michi de la Pasarela, pegale al Ladronzuelo con BATE, pisá el pad amarillo y comprá el Burrito. El contador, la bóveda, el escudo y el candado salen del `StateChanged`. Sin plaza, a los ~2,5 s corre el teatro de papel.
3. Output: si Analytics rechaza el evento en Studio, queda el warn y el panel Preview lista los pasos igual.
4. Preview → Teléfono (844×390, notch) y Vertical. Los botones de juego no bajan de 48 px y no se pisan con la barra de Roblox.
5. Mando: B/Esc cierra, Y inventario, Start ajustes, RT/E bate, LB/Q candado.
6. Para dejar la plaza libre: `game.ReplicatedStorage:SetAttribute("SkipFTUE", true)` antes de Play. Eso corta la intro y marca `FtueCompleted`.
