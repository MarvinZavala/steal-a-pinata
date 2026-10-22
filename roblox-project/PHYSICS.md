# La gravedad — por qué se siente así

Todos los números están en `src/ReplicatedStorage/Shared/Config/Tuning.luau`. El servidor los aplica en `Server/World/Movement.luau` (`Workspace.Gravity`, `StarterPlayer`, y de nuevo en cada `Humanoid` por si el cliente los toca).

## Qué usa el motor

| Parámetro | Default de Roblox | Acá | Efecto |
|---|---:|---:|---|
| `Workspace.Gravity` | 196.2 | **210** | El aire dura menos. El aterrizaje llega antes. |
| `Humanoid.JumpHeight` | 7.2 | **6.2** | Un salto claro, que no pasa la cerca de 10 studs. |
| `Humanoid.UseJumpPower` | — | **false** | La altura queda fija aunque se retoche la gravedad. |
| `WalkSpeed` | 16 | **16** | Igual que `Economy.Walk.Normal` y que el GDD. |
| `WalkSpeed` cargando | — | **11** | Igual que `Economy.Walk.Carrying`. |
| Impulso horizontal / vertical | — | **62 / 32** studs/s | Un empujón que se lee. No es un cohete. |
| Elasticidad del personaje | — | **0** (peso 100) | No rebota al caer. |

Con gravedad 210 y salto de 6.2 studs, la velocidad inicial es `sqrt(2 · g · h)` y el ápice vuelve a ser exactamente 6.2. El tiempo en el aire sale cerca de **0.49 s** (lo afirma `MoveMath` en las pruebas). El default con JumpPower 50 y g = 196.2 sube unos 6.37 studs y se queda un poco más flotando.

## Por qué estos números y no otros

El mapa está medido para caminar a 16 studs/s: de una base a la Pasarela hay unos 60 a 90 studs, o sea 4 a 6 s, y cargando a 11 son 6 a 8 s (GDD §12 y §4.3). Subir el WalkSpeed "porque se siente más moderno" rompe ese tiempo de persecución. Lo que hace que se sienta seco es el arco del salto y el golpe, no correr más rápido.

Los juegos grandes de 2025-2026 de este género se apoyan en el humanoide de siempre (16 studs/s, salto corto, pulgar de móvil). No hay un número público de "Steal a Brainrot usa gravedad X", y no invento uno. La recomendación que sí está escrita es otra: si vas a cambiar la gravedad, no uses `JumpPower`, porque la altura pasa a depender de `g`.

## Citas

1. **WalkSpeed 16, JumpPower 50, JumpHeight 7.2.** El default de `WalkSpeed` sale de `StarterPlayer.CharacterWalkSpeed`. `JumpPower` es la velocidad hacia arriba y la gravedad la afecta. `JumpHeight` es la altura en studs y se usa cuando `UseJumpPower` es false.  
   https://create.roblox.com/docs/reference/engine/classes/Humanoid

2. **Altura = v² / (2g).** Con JumpPower 50 y gravedad 196.2 el personaje sube ~6.37 studs. Es la misma cuenta que usa `MoveMath.apex`.  
   https://devforum.roblox.com/t/strange-physics-when-scaling-the-character/178757

3. **Para cambiar cómo se siente el salto, tocá la gravedad — y no trates JumpPower como si fuera una altura.** En ese hilo se mide que la velocidad real no es el número que uno cree, y la sugerencia es ajustar `Workspace.Gravity`. Por eso acá la altura vive en `JumpHeight` y la gravedad está un ~7 % arriba del default (210 vs 196.2): el arco se acorta y, si mañana se mueve la gravedad, el salto sigue midiendo 6.2.  
   https://devforum.roblox.com/t/what-exactly-is-jumppower/3029994

4. **El impulso es Δv · masa.** `BasePart:ApplyImpulse` espera un momento lineal. `Movement.knock` usa `AssemblyMass` y los Δv de `Tuning`. Durante el aturdimiento (1.5 s, GDD §4.4) el humanoide pasa a `PlatformStand` + estado Physics, se apaga `GettingUp` para que no se levante al instante, y se intenta `SetNetworkOwner(nil)` por si el place todavía no tiene `AuthorityMode = Server` (con Server Authority el servidor ya simula al personaje; el `pcall` cubre los dos modos).  
   https://create.roblox.com/docs/reference/engine/classes/BasePart#ApplyImpulse  
   https://create.roblox.com/docs/physics/network-ownership  
   https://devforum.roblox.com/t/full-release-ship-fair-and-competitive-games-with-server-authority/4727993

5. **El confeti no es un emisor infinito.** Se usa `Emit` con tope de 40 partículas (dirección de arte) en vez de un `Rate` alto. El cliente solo agrega un flash y un shake de ~0.16 studs / 0.2 s.  
   https://devforum.roblox.com/t/performance-considerations-improvements-and-optimizations-when-making-a-game/817499

La cerca de la base mide 10 studs a propósito: el salto de 6.2 no la salta, así el robo entra por la puerta y el candado importa.
