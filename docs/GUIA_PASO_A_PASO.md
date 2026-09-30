# Guía paso a paso (para empezar desde cero)

No necesitas saber programar para seguir esta guía. Lo que sí vas a hacer es **cambiar números y reemplazar imágenes**,
y eso ya te permite cambiar muchísimo del juego. Cuando quieras algo más grande (un ataque nuevo, un personaje con
habilidades raras), me lo pides y lo hacemos juntos.

---

## 1. Conseguir el proyecto en tu computadora

1. Entra a: <https://github.com/angelbricordova-dot/SMASH-BROS/tree/claude/peaceful-bohr-t7f3xv>
2. Botón verde **Code** → **Download ZIP**.
3. Descomprime el ZIP en una carpeta que encuentres fácil (por ejemplo `Documentos/super-brawl`).
   Dentro debe verse el archivo **`project.godot`**. Esa es la carpeta del juego.

## 2. Abrir el proyecto en Godot

> Usa **Godot 4.3 o más nuevo** (versión *Standard*; **no** la que dice ".NET" / "C#").

1. Abre Godot. Te aparece el **Administrador de proyectos** (Project Manager).
2. Clic en **Importar** (Import) → **Examinar** → elige el archivo `project.godot` → **Abrir** → **Importar y editar**.
3. La primera vez tarda unos segundos: Godot "importa" los dibujos y sonidos. Es normal.
   Si te sale un aviso sobre la versión del proyecto, acepta (es solo una conversión automática).
4. Para **jugar**: presiona **F5** (o el botón ▶ arriba a la derecha). Se abre el menú del juego.

### Controles

| Acción | Jugador 1 | Jugador 2 | Control (gamepad) |
|---|---|---|---|
| Moverse | `A` `D` | `←` `→` | Stick izquierdo / cruceta |
| Saltar (presiónalo otra vez en el aire = doble salto) | `Espacio` | `Enter` | `A` o `Y` |
| Atacar | `F` | `,` (coma) | `X` |
| Ataque hacia arriba | `W` + `F` | `↑` + `,` | Stick arriba + `X` |
| Ataque hacia abajo | `S` + `F` | `↓` + `,` | Stick abajo + `X` |
| Especial (bola de energía) | `G` | `.` (punto) | `B` |
| Escudo (mantener) | `Q` | `-` (guion) | `LB` / `RB` / gatillos |
| Caída rápida (en el aire) | `S` | `↓` | Stick abajo |
| Atravesar plataforma | `S` (tocar) | `↓` (tocar) | Stick abajo |
| Pausa | `Esc` | `Esc` | `Start` |

- El control 1 (gamepad) maneja al Jugador 1 y el control 2 al Jugador 2.
- En el menú: cambia personaje, alterna **Humano/CPU** con el botón de especial (`G` o `.`), cambia las vidas con
  arriba/abajo y empieza con **Enter**.
- `F11` = pantalla completa.

### Cómo funciona el daño (igual que Smash)
Cada golpe suma **% de daño** al rival. Mientras más % tenga, **más lejos sale volando**. Si sale de la pantalla
(zona de KO) pierde una vida. Los personajes pesados salen volando menos; los ligeros, más.

---

## 3. Un mini-tour por Godot (solo lo necesario)

Cuando abres el proyecto ves esto:

```
┌────────────┬──────────────────────────┬────────────┐
│ Escena     │                          │ Inspector  │
│ (Scene)    │      Vista principal     │ (propie-   │
│            │  (aquí ves el escenario) │  dades)    │
├────────────┤                          │            │
│ Sistema de │                          │            │
│ archivos   │                          │            │
│(FileSystem)│                          │            │
└────────────┴──────────────────────────┴────────────┘
```

- **Sistema de archivos (FileSystem)**, abajo a la izquierda: todas las carpetas del proyecto. **Doble clic** abre el archivo.
- Arriba al centro hay 4 pestañas: **2D** (ver/mover cosas), **Script** (código), **Game**, **AssetLib**.
- **Escena (Scene)**: la lista de "cosas" (nodos) que forman lo que tienes abierto.
- **Inspector**: cuando seleccionas un nodo, aquí cambias sus propiedades (tamaño, posición, etc.).
- Botón ▶ (F5) = jugar todo. **F6** = jugar solo la escena que tienes abierta.
- **Ctrl+S** = guardar. Guarda seguido.

### Las carpetas del proyecto

| Carpeta / archivo | Qué hay |
|---|---|
| `scenes/menu.tscn` | Pantalla de inicio y elección de personajes |
| `scenes/stage.tscn` | El escenario de pelea (plataformas, cámara, fondo) |
| `scenes/fighter.tscn` | El luchador (se usa para todos los personajes) |
| `scripts/character_data.gd` | **Aquí están los números de cada personaje** (velocidad, salto, daño, peso…) |
| `scripts/game.gd` | Controles (teclas), sonidos y configuración general |
| `scripts/fighter.gd` | La lógica del luchador (movimiento, ataques, escudo…) |
| `scripts/stage.gd` | Reglas de la partida (KO, vidas, ganador) |
| `scripts/cpu_brain.gd` | La "inteligencia" del CPU |
| `assets/sprites/` | Dibujos (personajes, escenario, fondo) |
| `assets/sounds/` | Sonidos |
| `tools/` | Programitas para regenerar dibujos y sonidos |
| `tests/` | Pruebas automáticas (puedes ignorarlas) |

---

## 4. Primeros cambios (¡pruébalos!)

### 4.1 Hacer que un personaje corra más rápido
1. En FileSystem abre `scripts/character_data.gd` (doble clic).
2. Busca `"rojo"` y la línea `"speed": 320.0`. Cámbiala a `450.0`.
3. **Ctrl+S** y **F5**. ¡Ya corre más rápido!

Todos los números tienen su explicación en comentarios al principio del mismo archivo. Los más divertidos:

- `jump_vel` → qué tan alto salta.
- `gravity` → qué tan "flotante" o pesado se siente.
- `weight` → peso (más peso = cuesta más mandarlo a volar).
- En `moves`: `dmg` (daño), `base_kb` (empuje base), `kb_scale` (cuánto crece el empuje con el daño), `angle` (hacia dónde sale volando el rival).
- `startup / active / recovery` → velocidad del golpe (más chico = más rápido).

### 4.2 Cambiar las vidas por defecto
En `scripts/game.gd`: `var stocks := 3` → pon el número que quieras (también se cambia desde el menú).

### 4.3 Cambiar las teclas
En `scripts/game.gd`, sección `_register_controls`. Por ejemplo `"attack": KEY_F` → `"attack": KEY_J`.

### 4.4 Cambiar el nombre del juego
`Proyecto → Configuración del proyecto → Application → Config → Name`. Y el título grande del menú está en `scripts/menu.gd` (busca `"SUPER BRAWL"`).

### 4.5 Modificar el escenario
1. Abre `scenes/stage.tscn`.
2. En **Escena**, abre `Platforms` y haz clic en una plataforma (por ejemplo `PlatformLeft`).
3. Arrástrala en la vista, o en el **Inspector** cambia `Position` y `Size` (ancho y alto).
4. `One Way` activado = se puede atravesar desde abajo (plataforma flotante).
5. Para agregar otra: selecciona una plataforma → **Ctrl+D** (duplicar) → muévela.
6. El tamaño de la zona de KO está en el nodo raíz `Stage` → propiedad `Blast Zone`.

---

## 5. Sprites (los dibujos)

### 5.1 Cómo están hechos los personajes
Cada personaje es **una sola imagen PNG** (una "hoja de sprites") de **384 × 512 píxeles**, dividida en una cuadrícula
de cuadros de **64 × 64** (6 columnas × 8 filas). Cada **fila** es una animación:

| Fila | Animación | Cuadros | Cuándo se usa |
|---|---|---|---|
| 1 | `idle` | 4 | quieto |
| 2 | `run` | 6 | corriendo |
| 3 | `jump` | 1 | subiendo en un salto |
| 4 | `fall` | 1 | cayendo |
| 5 | `attack` | 5 | ataque normal (1 = preparar · 2‑4 = golpe activo · 5 = recuperar) |
| 6 | `special` | 4 | ataque especial (el cuadro 3 es cuando sale la bola) |
| 7 | `hurt` | 1 | recibiendo golpe |
| 8 | `shield` | 1 | escudo |

Reglas para que funcione sin tocar código:
- El personaje **mira a la derecha** (el juego lo voltea solo).
- Los **pies** deben quedar cerca de la **fila 61** del cuadro de 64 (abajo, con un poquito de margen).
- El cuerpo centrado horizontalmente más o menos en la **columna 36** del cuadro.
- Fondo **transparente** (PNG).

### 5.2 Hacer tus propios dibujos
Programas gratis para pixel art: **Piskel** (en el navegador, piskelapp.com), **LibreSprite**, **Pixelorama** (hecho en Godot),
o Aseprite (de pago). Pasos:
1. Crea un lienzo de cuadros de 64×64.
2. Dibuja las animaciones según la tabla de arriba.
3. Exporta como **PNG spritesheet** de 6 columnas.
4. Guarda el PNG con el nombre `assets/sprites/char_<id>.png` (por ejemplo reemplazando `char_rojo.png`).
5. Regresa a Godot: se reimporta solo. ¡Ya aparece tu personaje!

> Consejo: empieza **editando** los sprites que ya existen (ábrelos en Piskel, cámbiales colores y detalles) antes de
> dibujar todo desde cero. También puedes **pedirme** que te genere personajes nuevos con otra apariencia.

### 5.3 Otros dibujos
- `proj_<id>.png`: la bola del ataque especial (4 cuadros de 16×16 en una fila).
- `background.png`: el fondo (640×360, se estira a la pantalla).
- `tile_grass.png`, `tile_dirt.png`, `tile_platform.png`: texturas del suelo (se repiten en mosaico).

### 5.4 Regenerar los dibujos automáticos
Los dibujos que vienen en el proyecto los genera `tools/make_sprites.py` (necesitas Python y `pip install pillow`).
No es necesario usarlo; si lo vuelves a correr **sobrescribe** los PNG de `assets/sprites/`.

---

## 6. Agregar un personaje nuevo

1. Crea su hoja de sprites y guárdala como `assets/sprites/char_luna.png` (y una bolita `proj_luna.png`).
2. Abre `scripts/character_data.gd`. **Copia** un bloque completo (por ejemplo el de `"rojo": { ... },`), pégalo debajo
   y cámbiale el nombre a `"luna"`, el `name`, `desc`, las rutas de `sheet` y `proj`, el `color` y los números.
3. En la línea `const ORDER := ["rojo", "azul", "verde"]` agrega `"luna"`.
4. **F5**: aparece en la selección de personaje.

---

## 7. Sonidos
Los efectos están en `assets/sounds/` (archivos `.wav`). Puedes **reemplazarlos** por los tuyos con el mismo nombre
(`hit.wav`, `jump.wav`, `ko.wav`…). Sitios con sonidos gratis: freesound.org, kenney.nl, opengameart.org.
Revisa siempre la licencia.

---

## 8. Exportar el juego para compartirlo
1. `Proyecto → Exportar…` → **Añadir…** → elige *Windows Desktop* (o tu sistema).
2. Si te pide **plantillas de exportación**, clic en **Administrar plantillas** → **Descargar e instalar**.
3. **Exportar proyecto**. Te genera un `.exe` que puedes pasarle a tus amigos.

---

## 9. Si algo sale mal

| Problema | Solución |
|---|---|
| Sale un error rojo al abrir | Usa Godot **4.3 o más nuevo** (Standard, no .NET). |
| Los personajes no se ven | Espera a que termine la barra de "importando" abajo a la derecha, o `Proyecto → Recargar proyecto actual`. |
| Cambié un número y nada cambió | ¿Guardaste (**Ctrl+S**)? Ejecuta otra vez con **F5**. |
| Rompí algo en un script | `Ctrl+Z` para deshacer. Y recuerda: mientras tengas el ZIP original, siempre puedes volver a empezar. |
| El gamepad no responde | Conéctalo **antes** de abrir el juego. El primero es P1, el segundo P2. |
| Mensaje "Parse Error" | Casi siempre es un error al escribir (falta una coma, un `:`…). Fíjate en la línea que indica el mensaje. |

Regla de oro: **cambia una cosa a la vez y prueba** (F5). Así sabes qué causó cada cosa.

---

Sigue con [`HOJA_DE_RUTA.md`](HOJA_DE_RUTA.md) para ver ideas de lo que podemos agregar después.
