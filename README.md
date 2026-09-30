# SUPER BRAWL (nombre temporal)

Juego de peleas de plataformas al estilo **Super Smash Bros.**, hecho con **Godot 4**.
8 luchadores con sets de movimientos únicos, 6 mapas, modo **Caos de Cartas**, CPU con 3 dificultades,
combos, smash cargados, parry, ultis y 7 objetos.

## Empezar rápido
1. Instala [Godot 4.3+](https://godotengine.org/download) (versión *Standard*, no .NET).
2. Abre Godot → **Importar** → elige `project.godot` de esta carpeta → **Importar y editar**.
3. Presiona **F5** para jugar.

👉 Guía completa para principiantes (controles, mecánicas y cómo modificar el juego): [`docs/GUIA_PASO_A_PASO.md`](docs/GUIA_PASO_A_PASO.md)
👉 Qué sigue: [`docs/HOJA_DE_RUTA.md`](docs/HOJA_DE_RUTA.md)

## Controles rápidos
| | P1 | P2 |
|---|---|---|
| Mover (doble toque = correr) | A D | ← → |
| Saltar | Espacio | Enter |
| Agacharse | S | ↓ |
| Ataque (varias veces = combo · mantener = smash · + dirección) | F | , |
| Especial (+ arriba · + abajo · mantener) | G | . |
| Escudo (+ lado = rodar · en el aire = esquiva) | Q | - |
| Lanzar objeto | C | J |
| Ulti | E | L |
| Provocar | R | K |
| **Parry** | toca la dirección hacia el atacante justo cuando te golpea | |

También funciona con gamepad (1.º control = P1, 2.º = P2). El P2 también puede usar el teclado numérico (0–6).

## Pruebas automáticas (opcional)
```
godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn
```

## Créditos
Fuentes: [Lilita One](https://fonts.google.com/specimen/Lilita+One) y [Nunito](https://fonts.google.com/specimen/Nunito)
(licencia SIL Open Font License, ver `assets/fonts/`). Sprites, mapas, sonidos y música generados con los scripts de `tools/`.
