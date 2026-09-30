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
   Si ya tenías una versión anterior, **reemplaza la carpeta completa** por la nueva.

## 2. Abrir el proyecto en Godot

> Usa **Godot 4.3 o más nuevo** (versión *Standard*; **no** la que dice ".NET" / "C#").

1. Abre Godot. Te aparece el **Administrador de proyectos** (Project Manager).
2. Clic en **Importar** (Import) → **Examinar** → elige el archivo `project.godot` → **Abrir** → **Importar y editar**.
3. La primera vez tarda unos segundos: Godot "importa" los dibujos, sonidos y música. Es normal.
4. Para **jugar**: presiona **F5** (o el botón ▶ arriba a la derecha).

> **Pantalla completa (F11):** en Godot 4.4 o más nuevo, el juego se abre *dentro* del editor (pestaña **Game**) y ahí
> la pantalla completa no funciona. Para jugar en su propia ventana: en la pestaña **Game** desactiva
> **"Embed Game on Next Play"** (o en *Editor → Configuración del editor → Run → Window Placement*) y vuelve a presionar F5.
> También puedes activarla desde **Ajustes** en el menú del juego.

---

## 3. Cómo se juega

### Controles

| Acción | Jugador 1 | Jugador 2 | Control (gamepad) |
|---|---|---|---|
| Caminar | `A` `D` | `←` `→` | Stick / cruceta |
| **Correr** (doble toque) | `A A` / `D D` | `← ←` / `→ →` | doble toque |
| Saltar · **doble salto** | `Espacio` | `Enter` / `Num 0` | `A` |
| **Agacharse** (mantener) / caer rápido | `S` | `↓` | abajo |
| **Ataque** (tócalo varias veces = **combo**) | `F` | `,` / `Num 1` | `X` |
| Ataque + dirección (lado / arriba / abajo) | `A/D/W/S` + `F` | flechas + `,` | stick + `X` |
| **Smash cargado** (mantener) | mantener `F` | mantener `,` | mantener `X` |
| **Especial** | `G` | `.` / `Num 2` | `B` |
| Especial + arriba / + abajo / mantener | `W`+`G` · `S`+`G` · mantener `G` | `↑`+`.` · `↓`+`.` · mantener `.` | stick + `B` |
| Escudo | `Q` | `-` / `Num 3` | `LB` / gatillos |
| Rodar · esquivar en el sitio | `Q` + `A`/`D` · `Q` + `S` | `-` + `←`/`→` · `-` + `↓` | escudo + stick |
| Esquiva en el aire | `Q` en el aire | `-` en el aire | escudo en el aire |
| **Lanzar objeto** (+ arriba/abajo) | `C` | `J` / `Num 6` | `RB` |
| **Ulti** (barra llena) | `E` | `L` / `Num 4` | `Y` |
| Provocar (emote) | `R` | `K` / `Num 5` | `Select` |
| Pausa | `Esc` | `Esc` | `Start` |

En el menú del juego hay una pantalla de **CONTROLES** con todo esto.

### Los ataques (cada personaje tiene su propio set)

- **Combo**: toca ataque varias veces → golpe 1, golpe 2 y remate (cada personaje los hace distinto: KORI remata
  con una ráfaga de patadas, KAEDE con cortes de katana, etc.).
- **Ataque + dirección** en el suelo: lado = golpe fuerte hacia delante, arriba = golpe hacia arriba, abajo = barrida.
- **Corriendo + ataque** = ataque en carrera.
- **Mantén el ataque** = **smash cargado**: mientras más lo cargues, más daño y más lejos manda al rival.
- **En el aire**: ataque solo, hacia delante, **hacia atrás**, arriba o abajo (¡el de abajo puede mandar al rival hacia abajo!).
- **Especiales** (G): tocar G, **arriba + G** (recuperación para volver al escenario), **abajo + G** y
  **mantener G** (versión cargada). Mira la tabla de luchadores más abajo.

### Las mecánicas

- **Daño en %**: cada golpe suma % al rival. Con más %, sale volando más lejos. Si sale de la pantalla pierde una vida.
- **Recuperación**: fuera del escenario usa el doble salto y luego **arriba + especial**. Después caes **indefenso**
  (oscurecido) hasta tocar suelo o agarrarte de un borde.
- **Bordes**: al caer cerca de la orilla te **cuelgas**. Salto = saltar, arriba = subir, abajo = soltarte.
- **Escudo**: bloquea, pero **se agrieta** y se rompe. Escudo + dirección = **rodar**; escudo + abajo = **esquivar**.
  En el aire: **esquiva aérea** en cualquier dirección.
- **PARRY** (como Street Fighter III): justo cuando te van a pegar, **toca la dirección HACIA el atacante**.
  Si lo logras: no recibes daño, el rival queda congelado un instante y ganas un poco de **barra de ulti**.
- **Barra de ulti**: se llena con parries (unos 8 parries = barra llena) y al hacer daño. Llena → tecla de ulti.
  Las ultis no se pueden interrumpir.
- **Buffer y DI**: si presionas algo un poquito antes de poder moverte, sale en cuanto se puede. Mientras sales
  volando, mantener una dirección cambia un poco el ángulo (úsalo para sobrevivir).

### Los luchadores

| | G | Arriba + G | Abajo + G | Mantener G | Ulti |
|---|---|---|---|---|---|
| **RYU-KO** (equilibrado, fuego) | Bola de fuego | Puño del Dragón | Pisotón llameante | Gran bola de fuego | Rayo Dragón |
| **KORI** (rápida, hielo) | Shurikens | Ráfaga (8 direcciones) | Patada en picada | Tormenta de shurikens | Ventisca Eterna (congela) |
| **GRUNK** (pesado, garrote) | Roca | Supersalto | Golpe sísmico | Carga de toro (armadura) | Terremoto |
| **UMBRA** (sombras, como Omen) | Paranoia | Paso sombrío (teletransporte) | Trampa de sombra | Paranoia doble | Desde las Sombras (6 cortes + remate) |
| **KAEDE** (samurái, katana) | Corte al viento | Iai ascendente | **Contraataque** | Estocada | Mil Cortes |
| **VOLTA** (eléctrico, veloz) | Chispa | Relámpago (zigzag) | Trueno | Sobrecarga | Tormenta Eléctrica |
| **NOVA** (robot, distancia) | Blaster | Jetpack | Mina | Cañón de plasma | Láser Orbital |
| **BRUMA** (bruja, magia) | Estrella que persigue | Escoba voladora | Círculo de runas | Meteorito | Lluvia de Meteoros |

### Objetos (caen del cielo)

Acércate y presiona **ATAQUE** para recogerlos. **LANZAR** (`C` / `J`) los tira: ¡le hacen daño al rival! Luego quedan
en el suelo y se pueden volver a recoger.

| Objeto | Qué hace |
|---|---|
| **Bate** | Batazo fuerte. **Mantén ATAQUE para cargar** un home run. |
| **Arco** (Minecraft) | 3 flechas. Mantén ATAQUE para tensar (caminas lento), suelta para disparar. |
| **Espada de energía** | Combo de 2 cortes de gran alcance. Se rompe tras 12 golpes. |
| **Bomba** | ATAQUE o LANZAR: explota al tocar algo. |
| **Bumerán** | Va, golpea y vuelve a tu mano. |
| **Corazón** | Te cura 40% al recogerlo. |
| **Estrella** | Invencible y más rápido 8 segundos. |

### Modos de juego

- **Clásico**: a vidas; el último en pie gana.
- **Caos de Cartas** (estilo ARAM Chaos): al empezar cada jugador elige **1 de 3 cartas** de mejora
  (doble daño, triple salto, ulti instantánea, vampiro, gigante…). Cada vez que sacas a un rival (**KO**) ganas un punto
  y eliges **otra carta**. El juego se pausa mientras eliges para que leas con calma. El CPU elige solo.

### Menú
**Título → Menú principal** (Clásico / Caos de Cartas / Controles / Ajustes) **→ Luchadores → Escenario**.
En luchadores: izquierda/derecha elige (el `?` es aleatorio), **ATAQUE** = listo, **ESPECIAL** = Humano/CPU,
arriba/abajo = dificultad del CPU (Fácil / Normal / Difícil). En escenario: elige mapa (o aleatorio), **escudo** cambia
las vidas y **especial** los objetos. En **Ajustes** subes o bajas el volumen de la música y de los efectos
(se guarda) y activas la pantalla completa.

---

## 4. Un mini-tour por Godot (solo lo necesario)

- **Sistema de archivos (FileSystem)**, abajo a la izquierda: todas las carpetas. **Doble clic** abre el archivo.
- Arriba al centro: **2D** (ver/mover cosas), **Script** (código).
- **Escena (Scene)**: la lista de "cosas" (nodos) de lo que tienes abierto. **Inspector**: sus propiedades.
- **F5** = jugar todo. **F6** = jugar solo la escena abierta. **Ctrl+S** = guardar.

### Las carpetas del proyecto

| Carpeta / archivo | Qué hay |
|---|---|
| `scenes/menu.tscn` | Todo el menú |
| `scenes/stages/` | Los 6 mapas: `pradera`, `cosmos`, `ciudad`, `volcan`, `bosque`, `nieve` |
| `scripts/character_data.gd` | **Los números de cada personaje** y sus golpes normales |
| `scripts/characters/` | **Las habilidades únicas** de cada personaje (un archivo por personaje) |
| `scripts/fighter.gd` | Lo común: movimiento, combos, escudo, parry, esquivas, bordes, objetos… |
| `scripts/cards.gd` | Las cartas del modo Caos |
| `scripts/item.gd` | Los objetos |
| `scripts/game.gd` | Controles, lista de mapas, música, ajustes |
| `scripts/stage.gd`, `stage_background.gd` | Reglas de la partida · fondo con profundidad y partículas |
| `scripts/cpu_brain.gd` | La "inteligencia" del CPU y sus dificultades |
| `assets/sprites/` | Personajes, objetos y proyectiles |
| `assets/stages/` | Fondos (en capas) y texturas de los mapas |
| `assets/sounds/`, `assets/music/` | Efectos (61) y música (4 pistas) |
| `tools/` | Programas que generan dibujos, mapas, sonidos y música |
| `tests/` | Pruebas automáticas |

---

## 5. Primeros cambios (¡pruébalos!)

### 5.1 Hacer que un personaje corra más rápido
En `scripts/character_data.gd`, busca `"rojo"` y cambia `"speed": 350.0` por `"speed": 450.0`
(`speed` = corriendo, `walk_speed` = caminando, `air_speed` = en el aire). **Ctrl+S** y **F5**.

Otros números: `jump_vel` (salto), `gravity` (qué tan pesado cae), `weight` (peso), `power` (daño de todos sus
golpes), `tempo` (velocidad de sus golpes: menos = más rápido).

### 5.2 Cambiar un golpe
En el mismo archivo, arriba está la plantilla `FISTS` con todos los golpes (`jab1`, `ftilt`, `smash`, `nair`…).
Cada personaje puede cambiar lo que quiera en su sección `"moves"`. Por ejemplo, para que el smash de RYU-KO pegue
más: `"smash": {"dmg": 20.0}`.

### 5.3 Parry y barra de ulti
En `scripts/fighter.gd`, arriba: `PARRY_WINDOW` (qué tan justo es el parry), `PARRY_METER` (cuánta barra da cada
parry) y `HIT_METER` (cuánta barra da cada % de daño que haces).

### 5.4 Cambiar las teclas
En `scripts/game.gd`, sección `_register_controls`. Por ejemplo `"throw": [KEY_C]` → `"throw": [KEY_V]`.

### 5.5 Modificar un mapa
Abre `scenes/stages/pradera.tscn`. En **Escena** → `Platforms`, selecciona una plataforma y muévela o cambia `Size`
en el **Inspector**. `One Way` = se atraviesa desde abajo. `Ground` = suelo principal (con bordes para colgarse).
`Style` = textura. Las plataformas móviles tienen `Travel` (cuánto se mueven) y `Period` (en cuántos segundos).

### 5.6 Agregar un mapa nuevo
1. Duplica `scenes/stages/pradera.tscn` como `scenes/stages/playa.tscn` y cambia sus plataformas.
2. En su nodo raíz pon `Stage Id = playa` y en el nodo `Background` también `Stage Id = playa`.
3. Pon los fondos en `assets/stages/playa/` (`sky.png`, `far.png`, `mid.png`, `clouds.png`), o copia la carpeta de otro mapa.
4. En `scripts/game.gd`, dentro de `STAGES`, copia una línea y cambia `"id": "playa"`, nombre y descripción.

### 5.7 Agregar una carta al modo Caos
En `scripts/cards.gd`: copia una línea de `DECK` (nombre, ícono, rareza, descripción) y agrega su efecto en `apply()`.

---

## 6. Los dibujos

### 6.1 Personajes
Cada personaje es una hoja de sprites `assets/sprites/char_<id>.png` de **1280 × 4464 píxeles**: cuadros de
**160 × 144** (8 columnas × 31 filas). Cada **fila** es una animación, en este orden:

`idle, walk, run, jump, fall, crouch, shield, dodge, hurt, ledge, taunt, win, jab1, jab2, jab3, ftilt, utilt, dtilt,
dash, smash, nair, fair, bair, uair, dair, special, upspecial, downspecial, charge, throw, ult`

(la cantidad de cuadros de cada una está en `scripts/fighter.gd`, lista `ANIMS`). Reglas: el personaje **mira a la
derecha**, los **pies** en la fila 138 del cuadro y la cadera en la columna 70, con fondo transparente.
Además hay `idle_<id>.png` (para los menús) y `portrait_<id>.png` (el retrato).

Programas gratis para pixel art: **Piskel** (en el navegador), **LibreSprite**, **Pixelorama**. También puedes
pedirme que cambie la apariencia de cualquier personaje.

### 6.2 Mapas
Cada mapa usa capas en `assets/stages/<mapa>/`: `sky.png` (cielo, quieto), `clouds.png` (se mueve sola), `far.png`
y `mid.png` (se mueven con la cámara para dar profundidad; 2560 px de ancho y se repiten). Las texturas del suelo
están en `assets/stages/tiles/`.

### 6.3 Regenerar los dibujos automáticos
Necesitas Python (`pip install pillow numpy`):
`python3 tools/make_sprites.py` (personajes y objetos) · `python3 tools/make_stages.py` (mapas).
Para las miniaturas del menú abre `tools/make_thumbnails.tscn` y presiona **F6**. ¡Ojo: sobrescriben los PNG!

---

## 7. Sonidos y música
- Efectos en `assets/sounds/` (`.wav`) y música en `assets/music/` (`.ogg`: `menu`, `battle1`, `battle2`, `chaos`).
  Reemplázalos por los tuyos con el mismo nombre. Sonidos gratis: freesound.org, kenney.nl, opengameart.org (revisa la licencia).
- Regenerarlos: `pip install numpy scipy soundfile` y `python3 tools/make_audio.py`.
- Qué música suena en cada mapa: `scripts/game.gd`, lista `STAGES`, campo `"music"`.

---

## 8. Agregar un personaje nuevo
1. Sprites: agrega su bloque en `tools/make_sprites.py` (`CHARACTERS`) y ejecútalo, o dibuja tu hoja (sección 6.1).
2. En `scripts/character_data.gd`: copia un bloque completo (por ejemplo `"rojo": {...}`), cambia nombre, textos,
   colores, números y `"script": "res://scripts/characters/<id>.gd"`. Agrega el id a `ORDER`.
3. Copia `scripts/characters/rojo.gd` como `<id>.gd` (ahí van sus habilidades).
4. **F5**: aparece en la selección de personaje.

> Las habilidades totalmente nuevas requieren programar. Pídemelas y las hacemos juntos.

---

## 9. Exportar el juego para compartirlo
`Proyecto → Exportar…` → **Añadir…** → *Windows Desktop* → (si lo pide, **Administrar plantillas → Descargar e
instalar**) → **Exportar proyecto**. Te genera un `.exe` para compartir. En el juego exportado F11 funciona siempre.

---

## 10. Si algo sale mal

| Problema | Solución |
|---|---|
| Sale un error rojo al abrir | Usa Godot **4.3 o más nuevo** (Standard, no .NET). |
| Los personajes o fondos no se ven | Espera a que termine "importando", o `Proyecto → Recargar proyecto actual`. |
| F11 no hace nada | Mira la nota de la sección 2 (juego dentro del editor). |
| No suena la música | Revisa **Ajustes** en el menú (volumen de música). |
| Cambié un número y nada cambió | ¿Guardaste (**Ctrl+S**)? Ejecuta otra vez con **F5**. |
| "Parse Error" | Casi siempre falta una coma o un `:`. Mira la línea que indica el mensaje. |
| El gamepad no responde | Conéctalo **antes** de abrir el juego. |

Regla de oro: **cambia una cosa a la vez y prueba** (F5).

Sigue con [`HOJA_DE_RUTA.md`](HOJA_DE_RUTA.md) para ver ideas de lo que podemos agregar después.
