class_name CharacterData
extends RefCounted
## ============================================================
##  DATOS DE LOS PERSONAJES  (¡aquí cambias cómo se siente cada uno!)
## ============================================================
## Cada personaje tiene además su propio script en scripts/characters/<id>.gd
## con sus habilidades únicas (especiales y ulti).
##
## Movimiento:
##  walk_speed / speed / air_speed   caminar / correr / en el aire
##  accel / friction / air_accel     qué tan rápido acelera y frena
##  jump_vel / double_jump_vel       fuerza del salto y del doble salto
##  gravity / fall_speed / fast_fall_speed   caída
##  weight       peso: más peso = sale volando menos
##  power        multiplica el daño de todos sus golpes normales
##  tempo        multiplica la duración de sus golpes (menos = más rápido)
##
## Los golpes normales salen de una plantilla (FISTS o WEAPON, más abajo) y cada
## personaje puede cambiar lo que quiera en "moves". Campos de un golpe:
##  dmg / base_kb / kb_scale / angle   daño, empuje base, empuje por %, ángulo (90 = arriba, -70 = hacia abajo)
##  startup / active / recovery        tiempos (segundos)
##  box_pos / box_size                 zona de golpe (respecto a los pies; y negativo = arriba)
##  next        siguiente golpe del combo (jab1 -> jab2 -> jab3)
##  hits        golpes múltiples dentro del mismo ataque
##  lunge       impulso hacia delante      boost: impulso vertical
##  landing_lag retraso al aterrizar (aéreos)
##  arc         estela visual [ángulo inicial, ángulo final, radio]
##  fx          efecto especial: "fire", "elec", "ice", "shadow", "magic", "rock"

const FISTS := {
	"jab1": {"dmg": 2.5, "base_kb": 70.0, "kb_scale": 1.0, "angle": 75.0, "startup": 0.04, "active": 0.05,
		"recovery": 0.13, "box_pos": Vector2(34, -48), "box_size": Vector2(46, 34), "next": "jab2",
		"arc": [-20.0, 20.0, 34.0], "sfx": "swing"},
	"jab2": {"dmg": 2.5, "base_kb": 70.0, "kb_scale": 1.0, "angle": 75.0, "startup": 0.04, "active": 0.05,
		"recovery": 0.13, "box_pos": Vector2(36, -46), "box_size": Vector2(48, 34), "next": "jab3",
		"arc": [15.0, -25.0, 36.0], "sfx": "swing"},
	"jab3": {"dmg": 5.0, "base_kb": 290.0, "kb_scale": 6.0, "angle": 40.0, "startup": 0.07, "active": 0.08,
		"recovery": 0.22, "box_pos": Vector2(42, -40), "box_size": Vector2(62, 40), "arc": [-60.0, 30.0, 46.0],
		"sfx": "swing_heavy"},
	"ftilt": {"dmg": 9.0, "base_kb": 290.0, "kb_scale": 8.0, "angle": 35.0, "startup": 0.1, "active": 0.08,
		"recovery": 0.2, "box_pos": Vector2(46, -36), "box_size": Vector2(72, 36), "arc": [-30.0, 20.0, 54.0],
		"sfx": "swing_heavy"},
	"utilt": {"dmg": 7.0, "base_kb": 280.0, "kb_scale": 8.0, "angle": 88.0, "startup": 0.08, "active": 0.1,
		"recovery": 0.18, "box_pos": Vector2(12, -82), "box_size": Vector2(62, 58), "arc": [30.0, -160.0, 48.0],
		"sfx": "swing"},
	"dtilt": {"dmg": 6.0, "base_kb": 230.0, "kb_scale": 6.0, "angle": 25.0, "startup": 0.07, "active": 0.08,
		"recovery": 0.16, "box_pos": Vector2(46, -10), "box_size": Vector2(74, 26), "arc": [60.0, 10.0, 50.0],
		"sfx": "swing"},
	"dash": {"dmg": 9.0, "base_kb": 300.0, "kb_scale": 7.0, "angle": 45.0, "startup": 0.08, "active": 0.15,
		"recovery": 0.25, "lunge": 380.0, "box_pos": Vector2(38, -40), "box_size": Vector2(64, 48),
		"arc": [-10.0, 10.0, 50.0], "sfx": "swing_heavy"},
	"smash": {"dmg": 14.0, "base_kb": 360.0, "kb_scale": 13.0, "angle": 38.0, "startup": 0.14, "active": 0.1,
		"recovery": 0.32, "box_pos": Vector2(50, -42), "box_size": Vector2(84, 52), "arc": [-70.0, 40.0, 62.0],
		"charge_bonus": 0.5, "sfx": "swing_heavy"},
	"nair": {"dmg": 8.0, "base_kb": 260.0, "kb_scale": 7.0, "angle": 45.0, "startup": 0.06, "active": 0.2,
		"recovery": 0.14, "box_pos": Vector2(0, -42), "box_size": Vector2(96, 86), "landing_lag": 0.08,
		"arc": [0.0, 360.0, 50.0], "sfx": "swing"},
	"fair": {"dmg": 10.0, "base_kb": 290.0, "kb_scale": 8.5, "angle": 40.0, "startup": 0.1, "active": 0.08,
		"recovery": 0.2, "box_pos": Vector2(42, -44), "box_size": Vector2(62, 58), "landing_lag": 0.12,
		"arc": [-90.0, 60.0, 50.0], "sfx": "swing_heavy"},
	"bair": {"dmg": 12.0, "base_kb": 300.0, "kb_scale": 9.5, "angle": 35.0, "startup": 0.09, "active": 0.08,
		"recovery": 0.2, "box_pos": Vector2(-44, -40), "box_size": Vector2(62, 48), "back": true,
		"landing_lag": 0.12, "arc": [200.0, 160.0, 52.0], "sfx": "swing_heavy"},
	"uair": {"dmg": 8.0, "base_kb": 290.0, "kb_scale": 8.0, "angle": 88.0, "startup": 0.06, "active": 0.1,
		"recovery": 0.16, "box_pos": Vector2(6, -92), "box_size": Vector2(72, 50), "landing_lag": 0.08,
		"arc": [20.0, -200.0, 50.0], "sfx": "swing"},
	"dair": {"dmg": 12.0, "base_kb": 240.0, "kb_scale": 8.0, "angle": -70.0, "startup": 0.14, "active": 0.1,
		"recovery": 0.22, "box_pos": Vector2(4, 6), "box_size": Vector2(50, 42), "landing_lag": 0.18,
		"arc": [60.0, 120.0, 44.0], "sfx": "swing_heavy"},
}

## Plantilla con arma: más alcance, un poco más lenta.
const WEAPON_REACH := 22.0

const DATA := {
	"ilunna": {
		"name": "ILUNNA", "script": "res://scripts/characters/ilunna.gd",
		"desc": "Rápido y ligero. Combos de patadas veloces. En su ulti se quita la chaqueta y se vuelve imparable.",
		"color": Color(0.42, 0.85, 1.0), "fx_color": Color(0.75, 0.95, 1.0),
		"abilities": ["Patada de viento", "Patada tornado", "Hachazo", "Puño de impacto", "Sin Chaqueta"],
		"walk_speed": 235.0, "speed": 465.0, "air_speed": 370.0, "accel": 3500.0, "friction": 3000.0,
		"air_accel": 2200.0, "jump_vel": 800.0, "double_jump_vel": 740.0, "gravity": 2100.0, "fall_speed": 780.0,
		"fast_fall_speed": 1300.0, "weight": 82.0, "power": 0.85, "tempo": 0.8, "special_cooldown": 0.45,
		"style": "fists", "tag": "RÁPIDO",
		"moves": {"jab3": {"hits": 3, "dmg": 2.6, "active": 0.14}, "nair": {"hits": 3, "dmg": 3.0},
			"uair": {"hits": 2, "dmg": 4.5}, "dair": {"angle": -75.0}},
	},
	"lamont": {
		"name": "LAMONT", "script": "res://scripts/characters/lamont.gd",
		"desc": "Equilibrado y con pistola. Carga balas y dispara ráfagas de tres. Su ulti le pide 'prestada' vida al rival.",
		"color": Color(1.0, 0.78, 0.25), "fx_color": Color(1.0, 0.88, 0.45),
		"abilities": ["Disparo", "Uppercut de puerta", "Freno de mano", "Ráfaga triple", "Préstamo"],
		"walk_speed": 205.0, "speed": 365.0, "air_speed": 320.0, "accel": 2800.0, "friction": 2600.0,
		"air_accel": 1700.0, "jump_vel": 760.0, "double_jump_vel": 700.0, "gravity": 2000.0, "fall_speed": 780.0,
		"fast_fall_speed": 1250.0, "weight": 98.0, "power": 1.0, "tempo": 1.0, "special_cooldown": 0.3,
		"style": "fists", "prop": "pistol", "tag": "ESTÁNDAR",
		"moves": {"smash": {"dmg": 15.0, "fx": "fire"}, "ftilt": {"dmg": 9.5}},
	},
	"abnielito": {
		"name": "ABNIELITO", "script": "res://scripts/characters/abnielito.gd",
		"desc": "De Tenerife, pelea con su micrófono. Sus mentiras confunden al rival: ¡se le invierten los controles!",
		"color": Color(0.3, 0.62, 1.0), "fx_color": Color(1.0, 0.86, 0.3),
		"abilities": ["Onda de micro", "¡Guagua!", "Mic drop", "Freestyle", "Mentiras"],
		"walk_speed": 215.0, "speed": 400.0, "air_speed": 340.0, "accel": 3000.0, "friction": 2700.0,
		"air_accel": 1900.0, "jump_vel": 780.0, "double_jump_vel": 720.0, "gravity": 2050.0, "fall_speed": 780.0,
		"fast_fall_speed": 1250.0, "weight": 92.0, "power": 0.95, "tempo": 0.9, "special_cooldown": 0.5,
		"style": "fists", "prop": "mic", "tag": "TÉCNICO",
		"moves": {"jab1": {"sfx_hit": "mic"}, "ftilt": {"box_size": Vector2(80, 40), "box_pos": Vector2(50, -40)},
			"smash": {"dmg": 15.0, "kb_scale": 13.5}},
	},
	"panadero": {
		"name": "PANADERO", "script": "res://scripts/characters/panadero.gd",
		"desc": "Tanque lento pero durísimo. Lanza harina y, en su ulti, se convierte en un panadero de verdad.",
		"color": Color(1.0, 0.68, 0.32), "fx_color": Color(1.0, 0.97, 0.9),
		"abilities": ["Harina", "Explosión de harina", "Masa pegajosa / Panzazo", "Baguette gigante",
			"Panadero Real"],
		"walk_speed": 150.0, "speed": 275.0, "air_speed": 255.0, "accel": 2000.0, "friction": 2400.0,
		"air_accel": 1200.0, "jump_vel": 700.0, "double_jump_vel": 640.0, "gravity": 2250.0, "fall_speed": 860.0,
		"fast_fall_speed": 1350.0, "weight": 138.0, "power": 1.3, "tempo": 1.25, "special_cooldown": 0.8,
		"style": "fists", "tag": "TANQUE",
		"moves": {"smash": {"armor": true, "kb_scale": 14.0, "dmg": 18.0}, "jab3": {"fx": "fire", "dmg": 7.0},
			"dair": {"angle": -80.0, "dmg": 14.0}},
	},
	"schizov": {
		"name": "SCHIZOV", "script": "res://scripts/characters/schizov.gd",
		"desc": "Tanque que pelea con un pez en la mano. Lanza revistas y, si se enfada, reparte cachetadas.",
		"color": Color(1.0, 0.45, 0.6), "fx_color": Color(0.65, 0.88, 1.0),
		"abilities": ["Revistas", "Birrete volador", "Plano deslizante / Pez en picada", "Montón de revistas",
			"¡Ya me cansé!"],
		"walk_speed": 165.0, "speed": 295.0, "air_speed": 270.0, "accel": 2200.0, "friction": 2400.0,
		"air_accel": 1350.0, "jump_vel": 720.0, "double_jump_vel": 660.0, "gravity": 2150.0, "fall_speed": 820.0,
		"fast_fall_speed": 1300.0, "weight": 126.0, "power": 1.2, "tempo": 1.15, "special_cooldown": 0.6,
		"style": "fists", "prop": "fish", "tag": "TANQUE",
		"moves": {"jab1": {"sfx_hit": "slap"}, "jab2": {"sfx_hit": "slap"}, "ftilt": {"box_size": Vector2(84, 40),
			"box_pos": Vector2(52, -40), "sfx_hit": "slap"}, "smash": {"armor": true}},
	},
	## Muñeco de prueba del modo Entrenamiento (usa los dibujos de Ilunna)
	"iluna": {
		"name": "ILUNA", "script": "res://scripts/characters/dummy.gd", "sprite": "ilunna",
		"desc": "Muñeco de prueba.", "color": Color(1.0, 0.55, 0.3), "fx_color": Color(1.0, 0.8, 0.5),
		"abilities": [], "walk_speed": 180.0, "speed": 300.0, "air_speed": 300.0, "accel": 2500.0,
		"friction": 2600.0, "air_accel": 1500.0, "jump_vel": 740.0, "double_jump_vel": 690.0, "gravity": 2000.0,
		"fall_speed": 780.0, "fast_fall_speed": 1250.0, "weight": 100.0, "power": 1.0, "tempo": 1.0,
		"special_cooldown": 1.0, "style": "fists", "moves": {},
	},
}

const ORDER := ["ilunna", "lamont", "abnielito", "panadero", "schizov"]

## Golpe con el bate (objeto). Mantén ATAQUE para cargarlo.
const BAT_MOVE := {"dmg": 15.0, "base_kb": 420.0, "kb_scale": 12.0, "angle": 38.0,
	"startup": 0.16, "active": 0.10, "recovery": 0.28, "box_pos": Vector2(56, -44), "box_size": Vector2(90, 60),
	"bat": true, "anim": "smash", "arc": [-100.0, 40.0, 80.0], "charge_bonus": 0.9, "max_charge": 1.2,
	"sfx": "swing_heavy"}
## Espada de energía (objeto): combo de 2 golpes
const SWORD_MOVES := {
	"sword1": {"dmg": 11.0, "base_kb": 300.0, "kb_scale": 8.0, "angle": 40.0, "startup": 0.08, "active": 0.09,
		"recovery": 0.18, "box_pos": Vector2(60, -44), "box_size": Vector2(96, 50), "next": "sword2", "anim": "ftilt",
		"arc": [-80.0, 30.0, 84.0], "sword": true, "sfx": "slash"},
	"sword2": {"dmg": 13.0, "base_kb": 360.0, "kb_scale": 10.0, "angle": 50.0, "startup": 0.09, "active": 0.1,
		"recovery": 0.24, "box_pos": Vector2(56, -56), "box_size": Vector2(96, 70), "anim": "utilt",
		"arc": [40.0, -130.0, 84.0], "sword": true, "sfx": "slash"},
}

static var _moves_cache := {}


static func get_data(id: String) -> Dictionary:
	return DATA.get(id, DATA["lamont"])


## Todos los golpes normales de un personaje (plantilla + sus cambios).
static func moves_for(id: String) -> Dictionary:
	if _moves_cache.has(id):
		return _moves_cache[id]
	var d := get_data(id)
	var out := {}
	var weapon: bool = d.get("style", "fists") == "weapon"
	for k in FISTS:
		var m: Dictionary = FISTS[k].duplicate()
		if weapon:
			m["box_pos"] = m["box_pos"] + Vector2(WEAPON_REACH * 0.5 * (-1.0 if m.get("back", false) else 1.0), 0)
			m["box_size"] = m["box_size"] + Vector2(WEAPON_REACH, 10)
			m["arc"] = [m["arc"][0], m["arc"][1], m["arc"][2] + WEAPON_REACH + 10.0]
			m["startup"] = m["startup"] * 1.1
			m["sfx"] = "slash" if d.get("blade", false) else "swing_heavy"
			m["weapon"] = true
		m["dmg"] = m["dmg"] * d.get("power", 1.0)
		for t in ["startup", "active", "recovery"]:
			m[t] = m[t] * d.get("tempo", 1.0)
		if d.has("all_fx"):
			m["fx"] = d["all_fx"]
		var mods: Dictionary = d.get("moves", {}).get(k, {})
		for f in mods:
			m[f] = mods[f]
		m["name"] = k
		out[k] = m
	_moves_cache[id] = out
	return out
