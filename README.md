# BOULEVARD SMASH

Juego de peleas de plataformas al estilo **Super Smash Bros.**, hecho con **Godot 4**.
**5 luchadores** hechos a partir de dibujos propios (Ilunna, Lamont, Abnielito, Panadero y Schizov), 6 mapas,
modos **Clásico**, **Caos de Cartas** y **Entrenamiento** (con el muñeco **ILUNA**), CPU con 3 dificultades, combos,
smash cargados, parry, ultis, **golpe final en cámara lenta**, objetos y **música rock** que eliges antes de pelear.

## Empezar rápido
1. Instala [Godot 4.3+](https://godotengine.org/download) (versión *Standard*, no .NET).
2. Abre Godot → **Importar** → elige `project.godot` de esta carpeta → **Importar y editar**.
3. Presiona **F5** para jugar.

👉 Guía completa para principiantes (controles, luchadores, mecánicas y cómo modificar el juego): [`docs/GUIA_PASO_A_PASO.md`](docs/GUIA_PASO_A_PASO.md)
👉 Qué sigue: [`docs/HOJA_DE_RUTA.md`](docs/HOJA_DE_RUTA.md)

## Controles rápidos
| | P1 | P2 |
|---|---|---|
| Mover (doble toque = correr) | A D | ← → |
| Saltar | Espacio **o W** | Enter **o ↑** |
| Agacharse | S | ↓ |
| Ataque (varias veces = combo · mantener = smash · + dirección · en el aire = aéreos) | F | , |
| Especial (+ arriba · + abajo, también en el aire · mantener) | G | . |
| Escudo (+ lado = rodar · en el aire = esquiva) | Q | - |
| Lanzar objeto | C | J |
| Ulti | E | L |
| Provocar | R | K |
| **Parry** | toca la dirección hacia el atacante justo cuando te golpea | |
| Entrenamiento: reiniciar · qué hace ILUNA · ulti infinita | T · Y · U | |

También funciona con gamepad (1.º control = P1, 2.º = P2). El P2 también puede usar el teclado numérico (0–6).

## Los luchadores
| | Estilo | Especial | Ulti |
|---|---|---|---|
| **Ilunna** | rápido, patadas | Patada de viento | Sin Chaqueta (más rápido y fuerte 10 s) |
| **Lamont** | estándar, pistola | Disparo · mantener = ráfaga de 3 (¡ta-ta-ta!) | Préstamo (le quita 40% de "vida" a un rival y se cura) |
| **Abnielito** | micrófono, de Tenerife | Onda de micro · ¡Guagua! | Mentiras (el rival tiene los controles al revés) |
| **Panadero** | tanque lento | Harina · Baguette gigante | Panadero Real (lanza panes por todos lados) |
| **Schizov** | tanque con un pez | Revistas | ¡Ya me cansé! (lluvia de cachetadas) |

## Pruebas automáticas (opcional)
```
godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn
```

## Créditos
Personajes: dibujos de referencia del autor (`art/referencias/`), convertidos en sprites con `tools/cut_sheets.py` y
`tools/import_sheets.py`. Fuentes: [Lilita One](https://fonts.google.com/specimen/Lilita+One),
[Nunito](https://fonts.google.com/specimen/Nunito), [Bungee](https://fonts.google.com/specimen/Bungee) (SIL Open Font
License) y [Permanent Marker](https://fonts.google.com/specimen/Permanent+Marker) (Apache 2.0); licencias en
`assets/fonts/`. Mapas, objetos, sonidos y música generados con los scripts de `tools/`.
