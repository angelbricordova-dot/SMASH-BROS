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
| Caminar | `A` `D` | `←` `→` | Stick / cruceta |
| **Correr** (doble toque) | `A A` / `D D` | `← ←` / `→ →` | doble toque |
| Saltar · **doble salto** (otra vez en el aire) | `Espacio` | `Enter` o `Num 0` | `A` |
| **Agacharse** (mantener) | `S` | `↓` | abajo |
| Atacar (+ arriba/abajo = otro ataque) | `F` | `,` o `Num 1` | `X` |
| Ataque corriendo | `F` mientras corres | `,` mientras corres | `X` |
| Especial | `G` | `.` o `Num 2` | `B` |
| **Recuperación** (arriba + especial) | `W` + `G` | `↑` + `.` | arriba + `B` |
| Escudo (mantener) | `Q` | `-` o `Num 3` | `LB` / `RB` / gatillos |
| Lanzar objeto | `Q` + `F` | `-` + `,` | escudo + `X` |
| **Ulti** (con la barra llena) | `E` | `L` o `Num 4` | `Y` |
| **Provocar** (emote) | `R` | `K` o `Num 5` | `Back` / `Select` |
| Caída rápida (en el aire) | `S` | `↓` | abajo |
| Atravesar plataforma | tocar `S` | tocar `↓` | abajo |
| Pausa | `Esc` | `Esc` | `Start` |

- El control 1 (gamepad) maneja al Jugador 1 y el control 2 al Jugador 2.
- `F11` = pantalla completa.

### El menú
1. **Título** → `Enter`.
2. **Elige tu luchador**: izquierda/derecha para elegir (el `?` es **aleatorio**), **ATAQUE** = ¡listo!,
   **ESPECIAL** = cambiar entre Humano y CPU, **arriba/abajo** = dificultad del CPU (Fácil / Normal / Difícil).
   `Enter` para continuar.
3. **Elige el escenario**: Pradera, Destino Cósmico, Azotea o **aleatorio**. Arriba/abajo cambia las vidas,
   ESPECIAL activa/desactiva los objetos. `Enter` = ¡a pelear!

### Las mecánicas (cómo se juega)
- **Daño en %**: cada golpe suma % al rival. Con más %, sale volando más lejos. Si sale de la pantalla, pierde una vida.
  Los pesados (GRUNK) aguantan más; los ligeros (KORI) salen volando antes.
- **Correr**: toca dos veces rápido la dirección. Si atacas mientras corres haces un **ataque corriendo**.
- **Doble salto**: salta otra vez en el aire (da una voltereta). Si sueltas el salto rápido haces un **salto corto**.
- **Recuperación**: si te sacan del escenario, usa el doble salto y luego **arriba + especial**. Cada personaje tiene
  una distinta. Después de usarla caes **indefenso** (oscurecido) hasta tocar el suelo o agarrarte de un borde.
- **Bordes**: si caes cerca de la orilla del escenario te **cuelgas** automáticamente. Desde ahí: salto = saltar,
  arriba/hacia el escenario = subir, abajo/hacia afuera = soltarte.
- **Agacharse**: mantén abajo. Tu cuerpo se hace más pequeño y sales volando un poco menos.
- **Escudo**: bloquea el daño, pero **se agrieta** con cada golpe y se va encogiendo. Si se rompe, quedas mareado.
- **PARRY** (como en Street Fighter III): justo cuando te van a pegar, **toca la dirección HACIA el atacante**.
  Ejemplo: si el rival te ataca desde la derecha (su golpe va de derecha a izquierda), toca **derecha** en el
  momento exacto. Si lo logras: no recibes daño, el rival queda congelado un momento (¡contraataca!) y se llena
  **1/3 de tu barra de ulti**. Si aprietas izquierda-derecha como loco no funciona: tiene que ser a tiempo.
- **Barra de ulti**: se llena sobre todo con parries (3 parries = barra llena) y un poquito al golpear. Cuando
  está llena, tu tarjeta brilla y dice ¡ULTI!: presiona la tecla de ulti.
- **Influir tu salida (DI)**: mientras sales volando, mantener una dirección cambia un poco el ángulo. Úsalo para sobrevivir.
- **Buffer**: si presionas saltar/atacar un poquito antes de poder moverte (por ejemplo, al final de un golpe
  recibido), la acción sale en cuanto se puede. Además, cuando te golpean recuperas tu doble salto y tu recuperación.
- **Objetos** (caen del cielo): acércate y presiona **ATAQUE** para recogerlo.
  - **Bate**: tu ataque se vuelve un batazo que manda a volar lejísimos (¡home run!).
  - **Arco** (estilo Minecraft) con **3 flechas**: mantén ATAQUE para tensar (caminas lento) y suelta para disparar.
    Más tensado = flecha más rápida y fuerte.
  - **Escudo + ATAQUE** lanza el objeto que tengas.

### Los luchadores

| | Especial | Arriba + Especial (recuperación) | Ulti |
|---|---|---|---|
| **RYU-KO** (equilibrado) | Bola de fuego | Puño del Dragón: gancho que sube y golpea | Rayo Dragón: rayo gigante que cruza la pantalla |
| **KORI** (rápida, ligera) | 3 shurikens de hielo | Ráfaga: se lanza en cualquiera de 8 direcciones | Ventisca Eterna: congela a todos, los daña y los hace estallar |
| **GRUNK** (lento, pesado) | Roca en arco | Supersalto con cabezazo | Terremoto: golpe al suelo que lanza a todos los que estén en el piso (¡salta para esquivarlo!) |
| **UMBRA** (sombras) | Paranoia: orbe que atraviesa a todos | Paso sombrío: se desvanece y reaparece donde apuntes (como Omen) | Desde las Sombras: desaparece y aparece a la espalda del rival para golpearlo |

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
| `scenes/menu.tscn` | Título, elección de luchadores y de escenario |
| `scenes/stages/` | Los 3 mapas: `pradera.tscn`, `cosmos.tscn`, `ciudad.tscn` |
| `scripts/character_data.gd` | **Aquí están los números de cada personaje** (velocidad, salto, daño, peso…) |
| `scripts/characters/` | **Las habilidades únicas** de cada personaje (un archivo por personaje) |
| `scripts/game.gd` | Controles (teclas), lista de mapas, sonidos y configuración general |
| `scripts/fighter.gd` | Lo que comparten todos: movimiento, ataques, escudo, parry, bordes, objetos… |
| `scripts/stage.gd` | Reglas de la partida (KO, vidas, objetos, ganador) |
| `scripts/cpu_brain.gd` | La "inteligencia" del CPU y sus 3 dificultades |
| `scripts/menu.gd`, `hud.gd`, `results_screen.gd` | La interfaz |
| `scripts/item.gd` | Los objetos (bate y arco) |
| `assets/sprites/` | Dibujos (personajes, escenario, fondo) |
| `assets/sounds/` | Sonidos |
| `tools/` | Programitas para regenerar dibujos y sonidos |
| `tests/` | Pruebas automáticas (puedes ignorarlas) |

---

## 4. Primeros cambios (¡pruébalos!)

### 4.1 Hacer que un personaje corra más rápido
1. En FileSystem abre `scripts/character_data.gd` (doble clic).
2. Busca `"rojo"` y en su línea de movimiento cambia `"speed": 340.0` por `"speed": 450.0`
   (`speed` = corriendo, `walk_speed` = caminando, `air_speed` = en el aire).
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

### 4.5 Modificar un escenario
1. Abre `scenes/stages/pradera.tscn` (o `cosmos.tscn`, `ciudad.tscn`).
2. En **Escena**, abre `Platforms` y haz clic en una plataforma (por ejemplo `PlatformLeft`).
3. Arrástrala en la vista, o en el **Inspector** cambia `Position` y `Size` (ancho y alto).
4. `One Way` activado = se puede atravesar desde abajo (plataforma flotante). `Ground` = suelo principal
   (tiene bordes para colgarse). `Style` = textura (Pradera / Cósmico / Ciudad).
5. Para agregar otra: selecciona una plataforma → **Ctrl+D** (duplicar) → muévela.
6. El tamaño de la zona de KO está en el nodo raíz → propiedad `Blast Zone`.

### 4.6 Agregar un mapa nuevo
1. En FileSystem, clic derecho sobre `scenes/stages/pradera.tscn` → **Duplicar** → ponle `volcan.tscn`.
2. Ábrelo y mueve/cambia las plataformas. Cambia el fondo en `Background > Sky > Texture`.
3. En `scripts/game.gd`, dentro de `STAGES`, copia una línea y cámbiala: `"id": "volcan"`, nombre, descripción
   y `"scene": "res://scenes/stages/volcan.tscn"`.
4. (Opcional) Para su miniatura en el menú corre `tools/make_thumbnails.tscn` (ábrelo y presiona F6).

### 4.7 Cambiar cómo funciona el parry o la ulti
En `scripts/fighter.gd`, arriba del todo: `PARRY_WINDOW` (qué tan justo hay que presionar; más grande = más fácil)
y `PARRY_METER` (cuánto llena cada parry).

---

## 5. Sprites (los dibujos)

### 5.1 Cómo están hechos los personajes
Cada personaje es **una sola imagen PNG** (una "hoja de sprites") de **384 × 832 píxeles**, dividida en una cuadrícula
de cuadros de **64 × 64** (6 columnas × 13 filas). Cada **fila** es una animación:

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
| 9 | `crouch` | 2 | agachado |
| 10 | `taunt` | 4 | provocar |
| 11 | `win` | 6 | celebración de victoria |
| 12 | `ledge` | 1 | colgado del borde |
| 13 | `upspecial` | 2 | recuperación (arriba + especial) |

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
- `bg_pradera.png`, `bg_cosmos.png`, `bg_ciudad.png`: fondos (640×360, se estiran a la pantalla).
- `tile_*.png`: texturas de suelos y plataformas (se repiten en mosaico).
- `item_bat.png`, `item_bow.png` (3 cuadros: normal, medio tenso, tenso), `item_arrow.png`: objetos.

### 5.4 Regenerar los dibujos automáticos
Los dibujos que vienen en el proyecto los genera `tools/make_sprites.py` (necesitas Python y `pip install pillow`).
No es necesario usarlo; si lo vuelves a correr **sobrescribe** los PNG de `assets/sprites/`.

---

## 6. Agregar un personaje nuevo

1. Crea su hoja de sprites y guárdala como `assets/sprites/char_luna.png` (y su proyectil `proj_luna.png`).
2. Abre `scripts/character_data.gd`. **Copia** un bloque completo (por ejemplo el de `"rojo": { ... },`), pégalo debajo
   y cámbiale el nombre a `"luna"`, el `name`, `desc`, `abilities`, las rutas de `sheet`/`proj`, el `color` y los números.
   En `"script"` pon `"res://scripts/characters/luna.gd"`.
3. Copia `scripts/characters/rojo.gd` como `luna.gd` (ahí están sus habilidades; para empezar puede quedarse igual).
4. En la línea `const ORDER := [...]` agrega `"luna"`.
5. **F5**: aparece en la selección de personaje.

> Las habilidades nuevas (un especial distinto, otra ulti…) sí requieren programar. Pídemelas y las hacemos juntos.

## 7. Sonidos
Los efectos están en `assets/sounds/` (archivos `.wav`). Puedes **reemplazarlos** por los tuyos con el mismo nombre
(`hit.wav`, `jump.wav`, `parry.wav`, `ult.wav`, `homerun.wav`…; son 41 en total, la lista está en `scripts/game.gd`). Sitios con sonidos gratis: freesound.org, kenney.nl, opengameart.org.
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
