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
	"rojo": {
		"name": "RYU-KO", "script": "res://scripts/characters/rojo.gd",
		"desc": "Artista marcial del fuego. Equilibrado, con golpes rápidos y patadas.",
		"color": Color(1.0, 0.38, 0.27), "fx_color": Color(1.0, 0.55, 0.15),
		"abilities": ["Bola de fuego", "Puño del Dragón", "Pisotón llameante", "Gran bola de fuego", "Rayo Dragón"],
		"walk_speed": 200.0, "speed": 350.0, "air_speed": 310.0, "accel": 2800.0, "friction": 2600.0,
		"air_accel": 1700.0, "jump_vel": 750.0, "double_jump_vel": 690.0, "gravity": 2050.0, "fall_speed": 790.0,
		"fast_fall_speed": 1250.0, "weight": 100.0, "power": 1.0, "tempo": 1.0, "special_cooldown": 0.6,
		"style": "fists",
		"moves": {"smash": {"fx": "fire", "dmg": 15.0}, "dash": {"fx": "fire"}, "fair": {"fx": "fire"}},
	},
	"azul": {
		"name": "KORI", "script": "res://scripts/characters/azul.gd",
		"desc": "Ninja del hielo. Rapidísima y ligera; combos de patadas veloces.",
		"color": Color(0.36, 0.76, 1.0), "fx_color": Color(0.6, 0.9, 1.0),
		"abilities": ["Shurikens de hielo", "Ráfaga (8 direcciones)", "Patada en picada", "Tormenta de shurikens",
			"Ventisca Eterna"],
		"walk_speed": 230.0, "speed": 430.0, "air_speed": 360.0, "accel": 3400.0, "friction": 3000.0,
		"air_accel": 2100.0, "jump_vel": 790.0, "double_jump_vel": 730.0, "gravity": 2050.0, "fall_speed": 750.0,
		"fast_fall_speed": 1250.0, "weight": 84.0, "power": 0.82, "tempo": 0.8, "special_cooldown": 0.5,
		"style": "fists",
		"moves": {"jab3": {"hits": 4, "dmg": 2.2, "active": 0.2, "fx": "ice"}, "nair": {"hits": 3, "fx": "ice"},
			"uair": {"hits": 2}, "dtilt": {"angle": 70.0, "base_kb": 180.0, "kb_scale": 4.0}},
	},
	"verde": {
		"name": "GRUNK", "script": "res://scripts/characters/verde.gd",
		"desc": "Bruto de las montañas con su garrote. Lento y pesado; golpes devastadores.",
		"color": Color(0.52, 0.9, 0.32), "fx_color": Color(0.85, 0.75, 0.5),
		"abilities": ["Lanzar roca", "Supersalto", "Golpe sísmico", "Carga de toro", "Terremoto"],
		"walk_speed": 160.0, "speed": 280.0, "air_speed": 260.0, "accel": 2100.0, "friction": 2400.0,
		"air_accel": 1250.0, "jump_vel": 710.0, "double_jump_vel": 650.0, "gravity": 2250.0, "fall_speed": 850.0,
		"fast_fall_speed": 1350.0, "weight": 130.0, "power": 1.3, "tempo": 1.25, "special_cooldown": 1.0,
		"style": "weapon",
		"moves": {"smash": {"armor": true, "fx": "rock", "kb_scale": 14.0}, "dair": {"fx": "rock"},
			"dtilt": {"fx": "rock"}},
	},
	"morado": {
		"name": "UMBRA", "script": "res://scripts/characters/morado.gd",
		"desc": "Espectro de las sombras (como Omen). Garras oscuras, se teletransporta y ataca por la espalda.",
		"color": Color(0.74, 0.5, 1.0), "fx_color": Color(0.7, 0.35, 1.0),
		"abilities": ["Paranoia (atraviesa)", "Paso sombrío (teletransporte)", "Trampa de sombra",
			"Paranoia doble", "Desde las Sombras"],
		"walk_speed": 190.0, "speed": 340.0, "air_speed": 320.0, "accel": 2500.0, "friction": 2400.0,
		"air_accel": 1800.0, "jump_vel": 730.0, "double_jump_vel": 690.0, "gravity": 1800.0, "fall_speed": 700.0,
		"fast_fall_speed": 1150.0, "weight": 92.0, "power": 1.0, "tempo": 0.95, "special_cooldown": 0.8,
		"style": "fists",
		"moves": {"jab1": {"fx": "shadow"}, "jab2": {"fx": "shadow"}, "jab3": {"fx": "shadow", "hits": 2},
			"ftilt": {"fx": "shadow", "box_size": Vector2(86, 40), "box_pos": Vector2(52, -38)},
			"smash": {"fx": "shadow"}, "bair": {"fx": "shadow"}},
	},
	"kaede": {
		"name": "KAEDE", "script": "res://scripts/characters/kaede.gd",
		"desc": "Samurái de la flor de cerezo. Katana de gran alcance y contraataque.",
		"color": Color(1.0, 0.5, 0.72), "fx_color": Color(1.0, 0.85, 0.95),
		"abilities": ["Corte al viento", "Iai ascendente", "Contraataque", "Estocada", "Mil Cortes"],
		"walk_speed": 200.0, "speed": 360.0, "air_speed": 320.0, "accel": 2700.0, "friction": 2600.0,
		"air_accel": 1700.0, "jump_vel": 760.0, "double_jump_vel": 700.0, "gravity": 2000.0, "fall_speed": 780.0,
		"fast_fall_speed": 1250.0, "weight": 95.0, "power": 1.05, "tempo": 1.0, "special_cooldown": 0.7,
		"style": "weapon", "blade": true,
		"moves": {"fair": {"angle": 45.0}, "smash": {"dmg": 16.0}},
	},
	"volta": {
		"name": "VOLTA", "script": "res://scripts/characters/volta.gd",
		"desc": "Velocista eléctrico. Todo lo que toca da calambre.",
		"color": Color(1.0, 0.86, 0.2), "fx_color": Color(1.0, 0.95, 0.45),
		"abilities": ["Chispa", "Relámpago", "Trueno", "Sobrecarga", "Tormenta Eléctrica"],
		"walk_speed": 220.0, "speed": 450.0, "air_speed": 350.0, "accel": 3300.0, "friction": 2800.0,
		"air_accel": 2000.0, "jump_vel": 770.0, "double_jump_vel": 700.0, "gravity": 2150.0, "fall_speed": 800.0,
		"fast_fall_speed": 1300.0, "weight": 88.0, "power": 0.92, "tempo": 0.85, "special_cooldown": 0.45,
		"style": "fists", "all_fx": "elec",
		"moves": {"nair": {"hits": 4, "dmg": 2.5}, "dash": {"hits": 3, "dmg": 3.5, "lunge": 520.0}},
	},
	"nova": {
		"name": "NOVA", "script": "res://scripts/characters/nova.gd",
		"desc": "Robot explorador con cañón de plasma y jetpack. Pelea a distancia.",
		"color": Color(1.0, 0.6, 0.25), "fx_color": Color(0.4, 0.95, 1.0),
		"abilities": ["Blaster", "Jetpack", "Mina", "Cañón de plasma", "Láser Orbital"],
		"walk_speed": 180.0, "speed": 320.0, "air_speed": 300.0, "accel": 2400.0, "friction": 2500.0,
		"air_accel": 1500.0, "jump_vel": 720.0, "double_jump_vel": 700.0, "gravity": 2000.0, "fall_speed": 780.0,
		"fast_fall_speed": 1250.0, "weight": 110.0, "power": 1.0, "tempo": 1.05, "special_cooldown": 0.35,
		"style": "fists",
		"moves": {"ftilt": {"proj": true, "dmg": 6.0}, "fair": {"proj": true}, "smash": {"fx": "elec"}},
	},
	"bruma": {
		"name": "BRUMA", "script": "res://scripts/characters/bruma.gd",
		"desc": "Bruja de la niebla. Magia de largo alcance con su báculo; flota al caer.",
		"color": Color(0.3, 0.9, 0.8), "fx_color": Color(0.55, 1.0, 0.85),
		"abilities": ["Estrella mágica", "Escoba voladora", "Círculo de runas", "Meteorito", "Lluvia de Meteoros"],
		"walk_speed": 180.0, "speed": 320.0, "air_speed": 330.0, "accel": 2400.0, "friction": 2300.0,
		"air_accel": 1900.0, "jump_vel": 720.0, "double_jump_vel": 700.0, "gravity": 1650.0, "fall_speed": 640.0,
		"fast_fall_speed": 1100.0, "weight": 86.0, "power": 0.95, "tempo": 1.0, "special_cooldown": 0.8,
		"style": "weapon", "all_fx": "magic",
		"moves": {"nair": {"box_size": Vector2(130, 110)}, "uair": {"hits": 3, "dmg": 3.5}},
	},
}

const ORDER := ["rojo", "azul", "verde", "morado", "kaede", "volta", "nova", "bruma"]

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
	return DATA.get(id, DATA["rojo"])


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
