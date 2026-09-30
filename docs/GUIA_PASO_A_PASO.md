# BOULEVARD SMASH — Guía paso a paso (para empezar desde cero)

No necesitas saber programar para seguir esta guía. Lo que sí vas a hacer es **cambiar números y reemplazar imágenes**,
y eso ya te permite cambiar muchísimo del juego. Cuando quieras algo más grande (un ataque nuevo, un personaje con
habilidades raras), me lo pides y lo hacemos juntos.

---

## 1. Conseguir el proyecto en tu computadora

1. Entra a: <https://github.com/angelbricordova-dot/SMASH-BROS/tree/claude/peaceful-bohr-t7f3xv>
2. Botón verde **Code** → **Download ZIP**.
3. Descomprime el ZIP en una carpeta que encuentres fácil (por ejemplo `Documentos/boulevard-smash`).
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
| Saltar · **doble salto** | `Espacio` **o `W`** | `Enter` / `Num 0` **o `↑`** | `A` |
| **Agacharse** (mantener) / caer rápido | `S` | `↓` | abajo |
| **Ataque** (tócalo varias veces = **combo**) | `F` | `,` / `Num 1` | `X` |
| Ataque + dirección (lado / arriba / abajo) | `A/D/W/S` + `F` | flechas + `,` | stick + `X` |
| **Smash cargado** (mantener) | mantener `F` | mantener `,` | mantener `X` |
| **Especial** | `G` | `.` / `Num 2` | `B` |
| Especial + arriba / + abajo / mantener | `W`+`G` · `S`+`G` · mantener `G` | `↑`+`.` · `↓`+`.` · mantener `.` | stick + `B` |
| **Entrenamiento**: reiniciar · qué hace ILUNA · ulti infinita | `T` · `Y` · `U` | | |
| Escudo | `Q` | `-` / `Num 3` | `LB` / gatillos |
| Rodar · esquivar en el sitio | `Q` + `A`/`D` · `Q` + `S` | `-` + `←`/`→` · `-` + `↓` | escudo + stick |
| Esquiva en el aire | `Q` en el aire | `-` en el aire | escudo en el aire |
| **Lanzar objeto** (+ arriba/abajo) | `C` | `J` / `Num 6` | `RB` |
| **Ulti** (barra llena) | `E` | `L` / `Num 4` | `Y` |
| Provocar (emote) | `R` | `K` / `Num 5` | `Select` |
| Pausa | `Esc` | `Esc` | `Start` |

En el menú del juego hay una pantalla de **CONTROLES** con todo esto.

> **Saltar con W / flecha arriba:** si presionas `W` y **justo** después (o a la vez) `F` o `G`, NO salta: sale el
> ataque hacia arriba o la recuperación. Si no te gusta saltar con `W`, lo puedes apagar en **Ajustes**.

### Los ataques (cada personaje tiene su propio set)

- **Combo**: toca ataque varias veces → golpe 1, golpe 2 y remate (cada personaje los hace distinto: ILUNNA remata
  con una ráfaga de patadas, SCHIZOV con cachetadas y su pez, etc.).
- **Ataque + dirección** en el suelo: lado = golpe fuerte hacia delante, arriba = golpe hacia arriba, abajo = barrida.
- **Corriendo + ataque** = ataque en carrera.
- **Mantén el ataque** = **smash cargado**: mientras más lo cargues, más daño y más lejos manda al rival.
- **En el aire**: ataque solo, hacia delante, **hacia atrás**, arriba o abajo. **Los ataques aéreos tienen sus propias
  animaciones** (distintas a las del suelo). ¡El de abajo puede mandar al rival hacia abajo!
- **Especiales** (G): tocar G, **arriba + G** (recuperación para volver al escenario), **abajo + G** y
  **mantener G** (versión cargada). **Abajo + G también funciona en el aire** y cada personaje tiene una versión
  aérea distinta (casi siempre cae en picada). Mira la tabla de luchadores más abajo.

### Las mecánicas

- **Daño en %**: cada golpe suma % al rival. Con más %, sale volando más lejos. Si sale de la pantalla pierde una vida.
- **Recuperación**: fuera del escenario usa el doble salto y luego **arriba + especial**. Después caes **indefenso**
  (oscurecido) hasta tocar suelo o agarrarte de un borde.
- **Bordes**: al caer cerca de la orilla te **cuelgas**. Salto = saltar, arriba = subir, abajo = soltarte.
- **Escudo**: una burbuja redonda del color de tu jugador. Bloquea, pero **se encoge, se agrieta** y se rompe. Escudo + dirección = **rodar**; escudo + abajo = **esquivar**.
  En el aire: **esquiva aérea** en cualquier dirección.
- **PARRY** (como Street Fighter III): justo cuando te van a pegar, **toca la dirección HACIA el atacante**.
  Si lo logras: no recibes daño, el rival queda congelado un instante y ganas un poco de **barra de ulti**.
- **Barra de ulti**: se llena con parries (unos 8 parries = barra llena) y al hacer daño. Llena → tecla de ulti.
  Las ultis no se pueden interrumpir.
- **Buffer y DI**: si presionas algo un poquito antes de poder moverte, sale en cuanto se puede. Mientras sales
  volando, mantener una dirección cambia un poco el ángulo (úsalo para sobrevivir).
- **Impacto**: cada golpe tiene destello, onda, líneas de choque y el **número de daño** saltando; el que recibe el
  golpe **tiembla** un instante (más cuanto más fuerte) y al salir volando deja una **estela de humo** del color del atacante.
- **EL GOLPE FINAL**: cuando un golpe va a quitarle la **última vida** al rival y decide la partida, el juego se
  **congela**, la cámara se acerca, aparecen **franjas de cine y líneas de velocidad**, y el rival sale volando en
  **cámara lenta**. ¡El KO que termina la partida explota el doble!

### Los luchadores

| | G | Arriba + G | Abajo + G (suelo / aire) | Mantener G | Ulti |
|---|---|---|---|---|---|
| **ILUNNA** (rápido, patadas) | Patada de viento (media luna de aire) | Patada tornado | Hachazo / cae en picada (meteoro) | Puño de impacto (embestida explosiva) | **Sin Chaqueta**: se quita la chaqueta y 10 s es más rápido, más fuerte y con un salto extra |
| **LAMONT** (estándar, pistola) | Disparo | Uppercut de puerta | Freno de mano (derrape) / patada en diagonal | **Ráfaga triple: carga balas y dispara 3 (¡ta-ta-ta!)** | **Préstamo**: le pide "vida prestada" a un rival: el rival **suma 40%** y Lamont **se cura 40%** |
| **ABNIELITO** (Tenerife, micrófono) | Onda de micro | **¡Guagua!** (una guagua lo lanza y atropella) | Mic drop / cae con el micro | Freestyle (onda gigante que aturde) | **Mentiras**: los rivales se confunden 7 s y **se les invierten los controles** (izquierda↔derecha, arriba↔abajo) |
| **PANADERO** (tanque, lento y fuerte) | **Harina** (nube que golpea varias veces) | Explosión de harina | Masa pegajosa (trampa) / **Panzazo** | Baguette gigante | **Panadero Real**: se transforma (gorro y filipina) y 7 s lanza **panes a diestra y siniestra**, con súper armadura |
| **SCHIZOV** (tanque, pez en la mano) | **Revistas** | Birrete volador | Plano deslizante / Pez en picada | Montón de revistas (abanico) | **¡Ya me cansé!**: se enfada y le da una lluvia de **cachetadas** + un pescadazo |

Los tanques (Panadero y Schizov) son más lentos pero pesan más (cuesta sacarlos) y pegan más fuerte. Ilunna es el más
rápido pero el más ligero.

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
- **Entrenamiento**: practica combos contra **ILUNA, el muñeco de prueba** (pintado de naranja y con una diana). Vidas
  infinitas. El panel de arriba a la izquierda muestra el **combo** actual (golpes y daño), el último y el mejor.
  Teclas: `T` reinicia posiciones y daño, `Y` cambia lo que hace ILUNA (quieto, agachado, saltando, caminando, con
  escudo o peleando como la CPU), `U` ulti infinita.
- **Caos de Cartas** (estilo ARAM Chaos): al empezar cada jugador elige **1 de 3 cartas** de mejora
  (doble daño, triple salto, ulti instantánea, vampiro, gigante…). Cada vez que sacas a un rival (**KO**) ganas un punto
  y eliges **otra carta**. El juego se pausa mientras eliges para que leas con calma. El CPU elige solo.

### Menú
**Título → Menú principal** (Clásico / Caos de Cartas / Entrenamiento / Controles / Ajustes) **→ Luchadores → Escenario**.
En luchadores: izquierda/derecha elige (el `?` es aleatorio), **ATAQUE** = listo, **ESPECIAL** = Humano/CPU,
arriba/abajo = dificultad del CPU (Fácil / Normal / Difícil). En escenario: elige mapa (o aleatorio), **escudo** cambia
las vidas, **especial** los objetos y **ulti** (`E` / `L`) **la música** (se escucha al cambiarla; `R` va hacia atrás).
En **Ajustes** subes o bajas el volumen de la música y de los efectos, activas la pantalla completa y eliges si
**W / flecha arriba** también salta (todo se guarda).

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
| `assets/sprites/` | Personajes (`char_<id>.png` + `.json`), objetos (`prop_*`) y proyectiles (`proj_*`) |
| `art/referencias/` | **Tus dibujos originales** de cada personaje (de ahí salen los sprites) |
| `assets/stages/` | Fondos (en capas) y texturas de los mapas |
| `assets/sounds/`, `assets/music/` | Efectos (76) y música (7 canciones) |
| `tools/` | Programas que generan dibujos, mapas, sonidos y música |
| `tests/` | Pruebas automáticas |

---

## 5. Primeros cambios (¡pruébalos!)

### 5.1 Hacer que un personaje corra más rápido
En `scripts/character_data.gd`, busca `"lamont"` y cambia `"speed": 365.0` por `"speed": 450.0`
(`speed` = corriendo, `walk_speed` = caminando, `air_speed` = en el aire). **Ctrl+S** y **F5**.

Otros números: `jump_vel` (salto), `gravity` (qué tan pesado cae), `weight` (peso), `power` (daño de todos sus
golpes), `tempo` (velocidad de sus golpes: menos = más rápido).

### 5.2 Cambiar un golpe
En el mismo archivo, arriba está la plantilla `FISTS` con todos los golpes (`jab1`, `ftilt`, `smash`, `nair`…).
Cada personaje puede cambiar lo que quiera en su sección `"moves"`. Por ejemplo, para que el smash de LAMONT pegue
más: `"smash": {"dmg": 20.0}`. Las ultis y especiales están en `scripts/characters/<id>.gd` (por ejemplo, en
`lamont.gd` la constante `LOAN := 40.0` es cuánto % "presta" la ulti; en `abnielito.gd`, `CONFUSE_TIME` es cuánto
dura la confusión).

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

### 6.1 Personajes (a partir de TUS dibujos)
Los luchadores salen de las hojas que me pasaste, guardadas en `art/referencias/<id>` (una imagen con el retrato y
muchas poses sueltas sobre un fondo de cuadritos). Dos programas de `tools/` las convierten en sprites del juego:

1. `tools/cut_sheets.py` quita el fondo de cuadritos y guarda una **máscara** en `art/mascaras/<id>.png`
   (blanco = personaje). Para Lamont (fondo casi negro) usa una IA de recorte; para los demás basta con detectar
   los cuadritos.
2. `tools/import_sheets.py` recorta cada **pose** (un rectángulo de la hoja), las escala todas al mismo tamaño,
   les pone un contorno oscuro y arma las **31 animaciones** combinando poses con pequeños giros, saltitos y
   estiramientos. También calcula dónde está la **mano** en cada cuadro (para dibujar el pez, el micrófono y la
   pistola) y crea la versión de la ulti (Ilunna sin chaqueta, Panadero con gorro y filipina).

Para cambiar una animación: abre `tools/import_sheets.py`, busca el personaje (`CHARACTERS["lamont"]`…) y cambia
qué pose usa cada animación. Con `python3 tools/import_sheets.py lamont --debug` se guarda `art/debug_lamont.png`
para revisar todas las animaciones (punto rojo = mano, verde = cabeza).

La hoja final es `assets/sprites/char_<id>.png` de **1280 × 4464 píxeles**: cuadros de **160 × 144** (8 columnas ×
31 filas; cada **fila** es una animación):
`idle, walk, run, jump, fall, crouch, shield, dodge, hurt, ledge, taunt, win, jab1, jab2, jab3, ftilt, utilt, dtilt,
dash, smash, nair, fair, bair, uair, dair, special, upspecial, downspecial, charge, throw, ult`.
El personaje **mira a la derecha**, con los **pies** en la fila 138 del cuadro y la cadera en la columna 70.

**¿Quieres un personaje nuevo o mejorar uno?** Lo más fácil: pásame otra hoja de poses (como las que hiciste) y la
importo. Si en la hoja hay más poses (por ejemplo "agarre" o "lanzamiento"), mejor.

### 6.2 Mapas
Cada mapa usa capas en `assets/stages/<mapa>/`: `sky.png` (cielo, quieto), `clouds.png` (se mueve sola), `far.png`
y `mid.png` (se mueven con la cámara para dar profundidad; 2560 px de ancho y se repiten). Las texturas del suelo
están en `assets/stages/tiles/`.

### 6.3 Regenerar los dibujos automáticos
Necesitas Python (`pip install pillow numpy`):
`python3 tools/import_sheets.py` (luchadores) · `python3 tools/make_props.py` (pez, micro, pistola, panes, revistas…)
· `python3 tools/make_sprites.py` (objetos del escenario) · `python3 tools/make_stages.py` (mapas).
Para las miniaturas del menú abre `tools/make_thumbnails.tscn` y presiona **F6**. ¡Ojo: sobrescriben los PNG!

---

## 7. Sonidos y música
- Efectos en `assets/sounds/` (`.wav`). Reemplázalos por los tuyos con el mismo nombre.
  Sonidos gratis: freesound.org, kenney.nl, opengameart.org (revisa la licencia).
- **Música** en `assets/music/` (`.ogg`). Son canciones completas (intro, estrofa, estribillo, puente, solo y final)
  de 1:30 a 1:50 minutos, para que no se sienta un bucle corto:

| Archivo | Canción | Estilo | Dónde suena |
|---|---|---|---|
| `boulevard` | Rock del Boulevard | punk-rock | Pradera |
| `asfalto` | Asfalto | hard rock | Azotea, Cumbre Nevada |
| `fuego` | Fuego Cruzado | metal | Volcán |
| `neon` | Noches de Neón | synth-rock | Destino Cósmico, Bosque Nocturno |
| `chaos` | Caos Total | punk rápido | modo Caos de Cartas |
| `training` | Calentando | funk | Entrenamiento |
| `menu` | Boulevard de Noche | lo-fi | menús |

- **Elegir la música**: en la pantalla de escenario, `E` / `L` cambia la canción ("Automática" = la del mapa).
- Qué música suena por defecto en cada mapa: `scripts/game.gd`, lista `STAGES`, campo `"music"`.
- Para poner **tu propia canción**: guárdala como `.ogg` en `assets/music/` (por ejemplo `mi_cancion.ogg`) y
  agrega una línea a la lista `TRACKS` de `scripts/game.gd`: `{"id": "mi_cancion", "name": "Mi canción"}`.
- Regenerar: `pip install numpy scipy soundfile`, luego `python3 tools/make_audio.py` (efectos) y
  `python3 tools/make_music.py` (música).

---

## 8. Agregar un personaje nuevo
1. Guarda su hoja de poses en `art/referencias/<id>.png` y ejecuta `python3 tools/cut_sheets.py <id>`.
2. En `tools/import_sheets.py` copia el bloque de otro personaje, cambia los rectángulos de las poses y ejecuta
   `python3 tools/import_sheets.py <id> --debug`.
3. En `scripts/character_data.gd`: copia un bloque completo (por ejemplo `"lamont": {...}`), cambia nombre, textos,
   colores, números y `"script": "res://scripts/characters/<id>.gd"`. Agrega el id a `ORDER`.
4. Copia `scripts/characters/lamont.gd` como `<id>.gd` (ahí van sus habilidades).
5. **F5**: aparece en la selección de personaje.

> Las habilidades totalmente nuevas requieren programar. Pídemelas y las hacemos juntos (o pásame la hoja y lo
> hago yo entero).

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
