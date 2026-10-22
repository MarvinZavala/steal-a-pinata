# Steal a Piñata! — proyecto Roblox (Rojo)

Esqueleto de código para la fase 1. El diseño completo está en `../plan/GDD.md` y la guía para montar el arte en `../art/IMPORT_GUIDE.md`.

## Requisitos
- Roblox Studio + el plugin de **Rojo** (desde el Creator Store o con `rojo plugin install`).
- [Rokit](https://github.com/rojo-rbx/rokit) para instalar la toolchain fijada en `rokit.toml` (rojo, wally, selene, stylua).
- VS Code con las extensiones **Luau Language Server** y **Rojo**.

```bash
cd roblox-project
rokit install          # instala rojo / wally / selene / stylua / lune (rokit.toml)
wally install          # Packages/ (gitignore). Hoy no hay dependencias de Wally.
bash scripts/ensure-packages.sh   # Rojo exige Packages/ aunque Wally no lo cree
selene src tests
stylua --check src tests
lune run tests/run     # migraciones, wallet, rate limit, validadores, fuzz de remotes
rojo serve             # luego en Studio: plugin Rojo -> Connect
```

Si `rokit install` no puede bajar los binarios, `bash scripts/install-toolchain.sh` los instala en `~/.local/bin` con los mismos tags. El CI está en `../.github/workflows/ci.yml`. Cómo verificar cada WP en Studio: [TESTING.md](TESTING.md).

Para generar un place desde cero: `rojo build -o StealAPinata.rbxlx` (está en .gitignore).

## Configuración obligatoria en Studio (una vez)
1. **Workspace → Server Authority → AuthorityMode = Server.** Esto activa solo StreamingEnabled, SignalBehavior = Deferred, NextGenerationReplication, UseFixedSimulation y PlayerScriptsUseInputActionSystem ([anuncio oficial](https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993)).
   - Ojo: con Server Authority hay un límite de **64 Attributes por instancia** y los RemoteEvents no van sincronizados con la timeline de simulación. Por eso guardamos el estado pesado en el servidor y no en Attributes.
2. **Game Settings → Security:** activá *Enable Studio Access to API Services* para probar DataStores (ProfileStore tiene un modo Mock para no tocar datos reales).
3. Importá los modelos según `../art/IMPORT_GUIDE.md` y guardalos en `ServerStorage/Pinatas` y `ServerStorage/Templates`. Rojo no los borra porque esas carpetas no están mapeadas a archivos `.luau`.

## Estructura
```
src/
├─ ReplicatedStorage/Shared/        (→ ReplicatedStorage.Shared)
│   ├─ Config/  Pinatas · Rarities · Economy · Monetization · Events · Assets   ← TODOS los números de diseño
│   ├─ Net/Remotes.luau             ← lista única de remotes (cliente = intenciones)
│   └─ Util/Format.luau
├─ ServerScriptService/Server/      (→ ServerScriptService.Server)
│   ├─ init.server.luau             ← bootstrap: init() en orden, luego start()
│   ├─ Services/*Service.luau       ← un servicio por Work Package (WP-xx del GDD)
│   ├─ Services/AntiCheat/          ← RateLimiter (leaky bucket, listo), Validators (listo), Logger
│   └─ Vendor/                      ← ProfileStore (copiar a mano, revisado)
├─ ServerStorage/                   ← modelos importados (Pinatas/, Templates/)
├─ StarterPlayer/StarterPlayerScripts/Client/
│   ├─ init.client.luau
│   └─ Controllers/ HUD · Shop · FTUE · VFX · Camera
└─ StarterGui/
```

## Reglas del código (para humanos y agentes)
1. **El servidor manda.** El cliente nunca cambia Dulces, propiedad ni posiciones de piñatas. Solo llama `Remotes.get("RequestX"):FireServer(...)`.
2. Todo remote nuevo se declara en `Shared/Net/Remotes.luau` y se valida en el servidor (tipo, rango, distancia, cooldown y `RateLimiter`).
3. Ningún número mágico: todo va en `Shared/Config/*`.
4. `--!strict` en todos los archivos; `selene src` y `stylua --check src` tienen que pasar.
5. Cada PR dice qué **WP** implementa y cómo cumple sus criterios de aceptación (GDD §13.2).
6. No metás free models con scripts; los módulos de terceros van en `Vendor/` revisados.

## Estado
| Pieza | Estado |
|---|---|
| Tooling (Rojo 7, Wally, Selene, StyLua, Lune, CI) | ✅ WP-01 |
| DataService + ProfileStore (esquema v2, migraciones, mock, autosave, EndSession) | ✅ WP-02. El dupe de 2 servers se prueba en Studio con API Services ([TESTING.md](TESTING.md)) |
| Registro de 23 piñatas, mesh ids placeholder y modelos en ServerStorage | ✅ WP-03. Los FBX se importan aparte; `rbxassetid://0` hasta subirlos |
| Anti-cheat (payload, leaky bucket, honeypots, `authorize`) | ✅ WP-10a. Robo, bate, compra y candado lo usan |
| WP-04 a WP-08 (bases, Pasarela, robo, bate, candado) + gravedad | ✅ ver `PLAYTEST.md` |
| Config de rarezas, economía, monetización y eventos | ✅ datos de diseño (balancear) |
| Servicios de economía, tienda, FTUE, fiesta, diarios, ligas | ⏳ stubs con TODO(WP-xx) |
| IDs de pases, productos, texturas y mallas | ⏳ en 0 hasta crearlos en el Creator Dashboard |

Cómo probar el loop en Studio: `PLAYTEST.md`. El perfil y el anti-cheat que usa el loop: `INTEGRATION.md`. Por qué la gravedad y el salto están así: `PHYSICS.md`. Semana 1: `TESTING.md`.
