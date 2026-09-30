# SUPER BRAWL (nombre temporal)

Juego de peleas de plataformas al estilo **Super Smash Bros.**, hecho con **Godot 4**.
4 luchadores con habilidades únicas, 3 mapas, CPU con 3 dificultades, parry, ultis y objetos.

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
| Atacar (+ W/S = arriba/abajo) | F | , |
| Especial (+ W = recuperación) | G | . |
| Escudo | Q | - |
| Ulti | E | L |
| Provocar | R | K |
| **Parry** | toca la dirección hacia el atacante justo cuando te golpea | |

También funciona con gamepad (1.º control = P1, 2.º = P2). El P2 también puede usar el teclado numérico (0–5).

## Pruebas automáticas (opcional)
```
godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn
```

## Créditos
Fuentes: [Lilita One](https://fonts.google.com/specimen/Lilita+One) y [Nunito](https://fonts.google.com/specimen/Nunito)
(licencia SIL Open Font License, ver `assets/fonts/`). Sprites y sonidos generados con los scripts de `tools/`.
