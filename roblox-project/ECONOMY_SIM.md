# Simulación de progresión (WP-09)

Script puro: `src/ReplicatedStorage/Shared/Gameplay/EconomySim.luau`.
Se corre con `lune run tests/economy_sim.luau` desde `roblox-project/`. No entra en el CI: imprime tiempos y marca desbalances. La semilla de este informe es `20261022`.

La Re-Fiesta 1 del GDD (§4.8, «p. ej. 500.000») caía al minuto 41. Quedó en **5.500.000** Dulces y 1 Épica: el ejemplo del GDD ×11. Los cuatro niveles siguientes usan el mismo factor (27,5M / 132M / 440M / 1.320M). Precios y Dulces/s de Rara y Épica no se tocaron. La Legendaria sigue en el payback del GDD §6.1 (Cadejo 225 s, Toro 257 s; peso de spawn 0,8). No hizo falta bajarle el peso: el jugador simulado no la compra antes de la primera Re-Fiesta, y con ese costo la primera cae el día 5.

## Cómo juega el jugador simulado

- Día 1: 45 min. D7: día 1 de 45 min y días 2–7 de 35 min. D28: días 2–7 de 40 min y días 8–28 de 30 min.
- Empieza con el Michi dorado del FTUE y 250 Dulces. Ingreso activo al 85 % (no está siempre mirando la Pasarela).
- Compra la siguiente rareza, apila copias para fusionar y deja un pedestal libre hasta conseguirla. No puede vender.
- Cuando ya tiene la rareza de la Re-Fiesta, no gasta el nido en otra piñata. Los pedestales sí se compran mientras junta: cuestan cientos, no millones, y el GDD los pone cerca del minuto 30.
- Entre días cobra offline al 50 %, tope 8 h, y también el tope de la Dulcería.
- Reclama el diario y suma el premio de dos misiones (5.000 + 2.500). La Fiesta cae cada 30 min de juego.
- El pagador tiene pase 2× y VIP desde el minuto 0 (multiplicador 2,5 contra 1).

## Tiempos (semilla 20261022)

| Hito | D1 | D7 F2P | D28 | D7 pagador |
|---|---|---|---|---|
| Rara en la Pasarela | 0,1 min | 0,5 min | 0,3 min | 0,6 min |
| Rara propia | 0,9 min | 2,7 min | 3,3 min | 0,6 min |
| Épica | 10,7 min | 22,5 min | 14,3 min | 5,4 min |
| 6 pedestales | 11,0 min | 22,7 min | 14,3 min | 5,7 min |
| Fiesta | 30,0 min | 30,0 min | 30,0 min | 30,0 min |
| Re-Fiesta | — | 150,0 min (día 5) | 125,0 min (día 4) | 80,0 min (día 3) |
| Legendaria | — | 196,3 min (día 6) | 180,9 min (día 5) | 102,4 min (día 3) |
| Set Clásicas | — | — | día 9 | día 4 |
| Fin de la ventana | 6 pedestales, 0 Re-Fiestas, 709/s | 2 Re-Fiestas; cierra en el segundo reinicio (0/s) | 8 pedestales, 2 Re-Fiestas, 16.912/s | 8 pedestales, 2 Re-Fiestas, 29.987/s |

La primera Re-Fiesta del F2P de la semana cae a las **2 h 30 min** de juego (150 min; la banda pedida es 120–180). En el D28, con sesiones un poco más largas, cae a los 125 min (2 h 5 min). El D1 (45 min) no llega: termina con 1.284.285 Dulces y la Épica del minuto 10,7.

Minuto 10 / 30 / 60 de juego quedan marcados (el 60 cae en el día 2). Rara y Épica salen en los mismos minutos que con el costo de 500.000. El primer minuto no se movió (Rara vista a los 0,1 min, Rara propia a los 0,9 en el D1).

## Banderas

| Id | Resultado | Lectura |
|---|---|---|
| d1-rare | ok | Primera Rara propia a los 0,9 min (tope 25) |
| d1-rare-seen | ok | Aparece en el primer minuto (peso 9 %) |
| d7-pedestals | ok | 6 pedestales a los 22,7 min (tope 60). El 5º y el 6º cuestan 500 y 1.100 |
| d7-epic | ok | 22,5 min, dentro de 8–120. Igual que antes del ajuste |
| d7-rebirth | ok | 150 min de juego. Dentro de la hora 2 a 3 (la banda de la simulación es 75–240) |
| d1-fiesta | ok | A los 30 min |
| d28-legendary | ok | Día 5. La ventana pedida es día 3 a 7 (la banda de la simulación llega al 14) |
| d28-classics | ok | Día 9 (tope día 14). El Toro es la pieza que falta y entra con la Legendaria |
| payer-ratio | ok | 80 min / 150 min = 0,53. La banda pide ≥ 0,35 |

## Qué se movió

`Economy.ReFiestaTiers[1].Candy` pasó de 500.000 a 5.500.000. Los niveles 2 a 5 se multiplicaron por el mismo 11. `ReFiestaCandy` (el número que lee el kiosco viejo) coincide con el nivel 1.

La Legendaria no cambió de precio ni de peso. Subir el precio se sale del payback de 225–260 s. Bajar el peso alarga la espera de un spawn que ya no es el cuello: después del reinicio el jugador tarda ~56 min de juego en poder pagarla (D28: Re-Fiesta a los 125 min, Legendaria a los 181). Con peso 0,8 el spawn esperado es de unos minutos, así que el día lo fija el costo de la Re-Fiesta, no la rareza del rollo.
