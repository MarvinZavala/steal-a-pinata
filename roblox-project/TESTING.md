# Cómo probar la semana 1 (WP-01, WP-02, WP-03, WP-10a)

Desde la raíz del repo. Hace falta Roblox Studio y el plugin de Rojo.

## Toolchain

```bash
cd roblox-project
rokit install
wally install
bash scripts/ensure-packages.sh   # Rojo exige Packages/; Wally no lo crea sin dependencias
selene src tests
stylua --check src tests
lune run tests/run
rojo build -o /tmp/StealAPinata.rbxlx
```

Si `rokit install` recibe un 403 de GitHub: `bash scripts/install-toolchain.sh` y agregá `~/.local/bin` al PATH. Las versiones salen de `rokit.toml`.

El CI (`.github/workflows/ci.yml`) corre selene, StyLua, los tests y `rojo build`.

## Sincronizar con Studio

1. `rojo serve` dentro de `roblox-project/`.
2. En Studio, plugin Rojo → Connect (puerto por defecto).
3. Una vez: **Workspace → Server Authority → AuthorityMode = Server** (prende StreamingEnabled).
4. **Game Settings → Security → Enable Studio Access to API Services** solo cuando quieras persistencia real. Con el attribute apagado, Studio usa el mock y no escribe DataStores de producción.

Play (F5). En el output del servidor tienen que aparecer, sin errores rojos:

- `[WP-03] registro: 23 piñatas`
- `[WP-03] smoke ok: 9 piñatas instanciadas`
- `[WP-02] ProfileStore.Mock`
- `[WP-10a] anti-cheat escuchando`
- `[Steal a Piñata] server listo`

En el Explorer, **ServerStorage → Pinatas**: 23 Models. Cada uno tiene `PrimaryPart` = `Root` (en la base), attributes `PinataId`, `Rarity` y `CandyPerSec`. Las que llevan neón (`cohetin`, `toro`, `torogoz`, `sombra`, `renito`, `izalco`, `pixelin`) tienen una parte `*_Neon` con Material Neon. Mientras el mesh siga en `rbxassetid://0` (`Shared/Config/Assets.luau`), el cuerpo es un Part con attribute `MeshPlaceholder`. Cuando subas el FBX, reemplazá ese id y Rojo + Play vuelven a armar un MeshPart. Si ya importaste el modelo con el nombre del id (`toro`, etc.), el registry lo reutiliza y solo completa attributes, Root y el material Neon.

## WP-01

`selene`, `stylua --check` y `lune run tests/run` en verde, y el place sincronizado con `rojo serve`. Eso es el criterio.

## WP-02 — datos

En Play, con la vista **Server** y la command bar:

```lua
local DS = require(game.ServerScriptService.Server.Services.DataService)
local p = game.Players:GetPlayers()[1]
print(DS.isLoaded(p), DS.usingMock(), DS.getDulces(p))
print(DS.grant(p, "Dulces", 100), DS.getDulces(p))
print(DS.trySpend(p, "Dulces", 40), DS.getDulces(p))
print(DS.grantPinata(p, "michi", "Golden"), DS.inventoryCount(p))
```

Tiene que imprimir `true`, el mock, `0`, luego `true 100`, `true 60` y un inventario de 1. `DS.grant(p, "Dulces", -5)` y `DS.trySpend` de más de lo que hay devuelven `false` y no cambian el saldo.

**Autosave:** esperá un poco más de `AutoSaveSec / 2` (30 s con el valor de 60 en `Shared/Config/Data.luau`). `p:GetAttribute("LastProfileSave")` pasa a ser un timestamp **sin** salir del juego. Al parar Play se llama `EndSession`.

**Persistencia y dos servidores (no está cubierto por CI):** en Edit, antes de Play, `workspace:SetAttribute("UseLiveProfiles", true)` con API Services activo, y el place publicado para que los dos servidores compartan el DataStore.

1. Servidor A: grant de 100 Dulces, esperá el autosave o salí para forzar `EndSession`.
2. Volvé a entrar: `getDulces` sigue en 100.
3. Con la sesión abierta en A, entrá el mismo usuario en un servidor B. A tiene que kickear ("sesión se abrió en otro servidor") y B tiene que cargar **100**, no 0 ni 200.
4. En B grant de 50. Reentrando solo a un servidor, el saldo es 150.

El mock se olvida al cerrar el servidor: no sirve para este paso. Nadie llama `Steal = true`.

Si la migración rechaza el perfil, el jugador es kickeado y **no** se reemplazan los datos por un perfil vacío.

## WP-03 — registro

El smoke del output instancia las 9 modeladas (estrellita, burrito, michi, cohetin, dragon, toro, torogoz, sombra, renito) y revisa PrimaryPart, `PinataId`, `Rarity` y `_Neon`. Los tests de `lune` fijan las 23 entradas contra `Pinatas.luau` y que cada una tenga un mesh id en `Assets.luau`.

## WP-10a — anti-cheat

Los tests cubren el leaky bucket (100 req en el mismo instante → solo entra la capacidad, el resto throttled), distancia (un robo a 200 studs no pasa; 8 sí), ángulo del bate, y un fuzz de payloads que no tira.

En Studio, vista **Client**, command bar:

```lua
local swing = game.ReplicatedStorage.Remotes.RequestSwing
for _ = 1, 100 do
	swing:FireServer()
end
game.ReplicatedStorage.Remotes.RequestSteal:FireServer("no", {}, 0/0)
game.ReplicatedStorage.Remotes.RequestGrantCurrency:FireServer(10 ^ 9)
```

En el output del **servidor** tienen que verse warns `[AC]` de `rate:`, `payload:` y `honeypot:`. No tiene que haber `Script error` ni un error rojo del server. Los Dulces no se mueven: no hay handler que los toque, y un payload con `Dulces` se rechaza.

A los 15 flags de la sesión el jugador queda restringido (se ignoran sus intenciones). No hay ban. Al salir, el conteo se borra. La posición imposible se loguea; la distancia al objetivo la van a usar Robo y Bate (`AntiCheatService.authorize(player, action, posicionDelServidor)`) cuando existan esos sistemas.

## WP-10b y WP-16

El guion de Studio, la vista de admin y el checklist están en [FAIRPLAY.md](FAIRPLAY.md). Desde `roblox-project/`:

```bash
lune run tests/run
```

`fairplay.spec` cubre velocidad, knockback, noclip, carga, autoclick, puntaje, ligas, escudo y offline.
