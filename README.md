# SUPER BRAWL (nombre temporal)

Juego de peleas de plataformas al estilo **Super Smash Bros.**, hecho con **Godot 4**.

## Empezar rápido
1. Instala [Godot 4.3+](https://godotengine.org/download) (versión *Standard*, no .NET).
2. Abre Godot → **Importar** → elige `project.godot` de esta carpeta → **Importar y editar**.
3. Presiona **F5** para jugar.

👉 Guía completa para principiantes: [`docs/GUIA_PASO_A_PASO.md`](docs/GUIA_PASO_A_PASO.md)
👉 Qué sigue: [`docs/HOJA_DE_RUTA.md`](docs/HOJA_DE_RUTA.md)

## Controles rápidos
| | P1 | P2 |
|---|---|---|
| Mover | A D | ← → |
| Saltar | Espacio | Enter |
| Atacar (+ W/S = arriba/abajo) | F | , |
| Especial | G | . |
| Escudo | Q | - |

También funciona con gamepad (1.º control = P1, 2.º = P2). En el menú puedes poner a cualquier jugador como CPU.

## Pruebas automáticas (opcional)
```
godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn
```
