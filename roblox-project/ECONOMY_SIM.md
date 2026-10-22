# Simulación de progresión (WP-09)

Script puro: `src/ReplicatedStorage/Shared/Gameplay/EconomySim.luau`.
Se corre con `lune run tests/economy_sim.luau` desde `roblox-project/`. No entra en el CI: imprime tiempos y marca desbalances. La semilla de este informe es `20261022`.

Los precios, Dulces/s y la Re-Fiesta 1 (1 Épica y 500.000 Dulces) son los del GDD §4.8 y §5. No se movió el 500.000 para apagar una bandera.

## Cómo juega el jugador simulado

- Día 1: 45 min. D7: día 1 de 45 min y días 2–7 de 35 min. D28: días 2–7 de 40 min y días 8–28 de 30 min.
- Empieza con el Michi dorado del FTUE y 250 Dulces. Ingreso activo al 85 % (no está siempre mirando la Pasarela).
- Compra la siguiente rareza, apila copias para fusionar y deja un pedestal libre hasta conseguirla. No puede vender.
- Cuando ya tiene la rareza de la Re-Fiesta, guarda esos Dulces y no los gasta en otra piñata.
- Entre días cobra offline al 50 %, tope 8 h, y también el tope de la Dulcería.
- Reclama el diario y suma el premio de dos misiones (5.000 + 2.500). La Fiesta cae cada 30 min de juego.
- El pagador tiene pase 2× y VIP desde el minuto 0 (multiplicador 2,5 contra 1).

## Tiempos (semilla 20261022)

| Hito | D1 | D7 F2P | D28 | D7 pagador |
|---|---|---|---|---|
| Rara en la Pasarela | 0,1 min | 0,5 min | 0,3 min | 0,6 min |
| Rara propia | 0,9 min | 2,7 min | 3,3 min | 0,6 min |
| Épica | 10,7 min | 22,5 min | 14,3 min | 5,4 min |
| 6 pedestales | 42,7 min | 55,3 min (día 2) | 51,7 min (día 2) | 43,3 min |
| Fiesta | 30,0 min | 30,0 min | 30,0 min | 30,0 min |
| Re-Fiesta | 24,2 min | 41,2 min | 30,0 min | 14,8 min |
| Legendaria | — | 73,7 min (día 2) | 65,7 min (día 2) | 55,5 min (día 2) |
| Set Clásicas | — | día 2 | día 3 | día 2 |
| Fin de la ventana | 7 pedestales, 1 Re-Fiesta, 648/s | 8 pedestales, 2 Re-Fiestas, 9.969/s | 8 pedestales, 2 Re-Fiestas, 10.207/s | 8 pedestales, 2 Re-Fiestas, 28.574/s |

Minuto 10 / 30 / 60 de juego quedan marcados (el 60 cae en el día 2). El Dulces/s de esa marca no se guarda aparte: al terminar el D1 el jugador ya hizo una Re-Fiesta y produce 648/s.

## Banderas

| Id | Resultado | Lectura |
|---|---|---|
| d1-rare | ok | Primera Rara propia antes de los 25 min |
| d1-rare-seen | ok | Aparece en el primer minuto (peso 9 %) |
| d7-pedestals | ok | 6 pedestales antes de los 60 min. El GDD los imagina cerca del minuto 30; la curva ×2,2 desde 500 los deja baratos al lado de una Épica (40.000) |
| d7-epic | ok | 22,5 min, dentro de 8–120 |
| d7-rebirth | **FLAG** | 41 min de juego. El objetivo del GDD §6.3 es la hora 2 a 3 (la banda de la simulación es 75–240) |
| d1-fiesta | ok | A los 30 min |
| d28-legendary | **FLAG** | Día 2. El GDD la ubica entre el día 3 y el 7 |
| d28-classics | ok | Día 3 (tope día 14) |
| payer-ratio | ok, justo | 15 min / 41 min = 0,36. La banda pide ≥ 0,35. El 2× y el VIP, sumados, adelantan mucho la primera Re-Fiesta |

## Qué no se cambió

La Re-Fiesta 1 sigue en **500.000** porque el GDD lo escribe como ejemplo. Con una Épica de 300–700 Dulces/s, ese número se junta en unos 15–25 min de juego activo. Para caer en la hora 2–3 sin tocar el resto de la curva, el knob es `Economy.ReFiestaTiers[1].Candy` (del orden de 2,5M a 4M si el ingreso post-Épica se queda cerca de 600/s). La Legendaria del día 2 sale del mismo efecto: después de la Re-Fiesta el multiplicador ya es 1,5 y 450.000 no alcanzan a llenar la sesión del día 3.

El pagador no rompe la banda de 0,35, pero está en el borde. Si se sube el costo de la Re-Fiesta, hay que volver a medir este ratio: el pase no debería dejar al F2P afuera de la semana ni entregar la Re-Fiesta en el primer cuarto de hora.
