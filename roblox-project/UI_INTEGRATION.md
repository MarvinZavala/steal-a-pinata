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

| Nombre | Dirección | Args | Quién lo dispara |
| --- | --- | --- | --- |
| `RequestCollect` | C2S | — | Botón de la Dulcería cuando hay dulces en el frasco |
| `RequestSettings` | C2S | `locale`, `music`, `sfx`, `reduceMotion`, `cameraShake` | Ajustes. `locale` es `"auto"` `"es"` `"en"` `"pt"`. Volúmenes 0–1. Los dos últimos son boolean |
| `RequestFTUEStep` | C2S | un paso de `Security.FtueSteps` | Cada paso del embudo, después de que el jugador lo cumple |
| `RequestFTUEAction` | C2S | `claim` `bonk` `collect` `buy` `complete` | La recompensa de ese paso |
| `OpenShop` | S2C | `kiosk`: `"dulceria"` `"bates"` `"cajas"` `"vip"` o `""` | El servidor, al entrar a un kiosco. `FireClient`, no `fireServer` |

Hasta que gameplay registre el handler con `AntiCheatService.register`, un payload válido se acepta y no cambia datos (igual que el resto de intenciones en la semana 1).

`RequestUpgrade` no lleva el índice. El servidor sube el siguiente pedestal, el siguiente tope de bóveda o hace la Re-Fiesta. La UI muestra el precio del siguiente (`Economy` + costos provisionales de bóveda).

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

El primer `StateChanged` apaga el presenter offline. Antes de eso, Studio predice el FTUE (Michi dorado, +250, Burrito) para poder ver la UI sin el gameplay. Esas predicciones no pisan un estado autoritativo.

## `Feedback`

`BONK`, `ROBBED`, `PURCHASE` / `PURCHASED`, `COLLECT` (`payload.amount`), `RETURNED`, `DENIED` (`payload.key` = `poor`, `shield`, … o una clave del catálogo), `ANNOUNCE` (también llega por el remote `Announce`), `TOAST` (`payload.key` o `payload.text`).

Los textos de la UI salen de `Shared/Locale/Catalog.luau` (es, en, pt) y se cargan en `LocalizationService.FiestaUI`. No uses `RichText` con nombres de jugadores.

## FTUE

Guion en `Shared/UI/FTUEScript.luau` (GDD §10.1): Michi Golden, +9/s de base (no el ×2 de la mutación), slow-mo 0.4 s, +250, Burrito a 75, Dragón Chile asomado, fiesta en 4:59. Embudo `ftue_first_60`, pasos `1_spawn` … `8_first_purchase`. El cliente llama `LogFunnelStepEvent` y `LogCustomEvent("ftue_<paso>")`. Saltar (solo Studio) manda `ftue_skip`.

`ReplicatedStorage:SetAttribute("SkipFTUE", true)` corta la intro para no tapar al agente de gameplay. En Studio también está el botón Saltar.

Tags opcionales de mundo: `FTUEFountain`, `FTUEBase`, `FTUEDulceria`, `FTUEConveyor`. Si no están, el teatro de papel igual corre.

## Preview

En Studio (o con el attribute `UIPreview`) aparece el botón Preview, o escribís `/ui`. Ahí se ven HUD, robo, inventario, los 4 kioscos, ajustes, toasts y la intro, en teléfono / vertical / tablet / PC. Los eventos del embudo en preview llevan `source = preview`.

## Precios provisionales

Si `Economy` no trae `VaultUpgradeCost` ni `ReFiestaCandy`, la Dulcería usa 2500 / 15000 / 80000 y 500000. El día que aparezcan en `Economy`, se leen solos. Los pases con `Id == 0` muestran «Pronto» y no abren el prompt de Robux.

## Cómo probarlo en Studio

1. `rojo serve` en `roblox-project/`.
2. Play. Tiene que verse el HUD y, a los ~0,5 s, el teatro del primer minuto. Tocá los botones grandes (seguir, tomar, bate, cobrar, comprar). En menos de 70 s termina.
3. Output: si Analytics rechaza el evento en Studio, queda el warn y el panel Preview lista los pasos igual.
4. Preview → Teléfono (844×390, notch) y Vertical. Los botones de juego no bajan de 48 px y no se pisan con la barra de Roblox.
5. Mando: B/Esc cierra, Y inventario, Start ajustes, RT/E bate, LB/Q candado.
6. Para dejar la plaza libre: `game.ReplicatedStorage:SetAttribute("SkipFTUE", true)` antes de Play.
