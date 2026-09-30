class_name CharacterData
extends RefCounted
## ============================================================
##  DATOS DE LOS PERSONAJES  (¡aquí cambias cómo se siente cada uno!)
## ============================================================
## Cada personaje tiene además su propio script en scripts/characters/<id>.gd
## con sus habilidades únicas (especial, recuperación y ulti).
##
## Movimiento:
##  walk_speed   velocidad caminando
##  speed        velocidad corriendo (doble toque de dirección)
##  air_speed    velocidad máxima en el aire
##  accel / friction / air_accel   qué tan rápido acelera y frena
##  jump_vel / double_jump_vel     fuerza del salto y del doble salto
##  gravity / fall_speed / fast_fall_speed   caída
##  weight       peso: más peso = sale volando menos
##
## Ataques ("moves"):
##  dmg        daño en %
##  base_kb    fuerza base con la que empuja
##  kb_scale   cuánto más empuja por cada % de daño que ya tenga el rival
##  angle      ángulo de salida en grados (0 = horizontal, 90 = arriba, -90 = abajo)
##  startup / active / recovery   segundos antes del golpe / golpe activo / recuperación
##  box_pos / box_size   zona de golpe (respecto a los pies; y negativo = arriba)

const DATA := {
	"rojo": {
		"name": "RYU-KO",
		"desc": "Artista marcial equilibrado. Buen daño y buen alcance.",
		"script": "res://scripts/characters/rojo.gd",
		"sheet": "res://assets/sprites/char_rojo.png",
		"proj": "res://assets/sprites/proj_rojo.png",
		"color": Color(1.0, 0.38, 0.27),
		"abilities": ["Bola de fuego", "Puño del Dragón", "Rayo Dragón"],
		"walk_speed": 190.0, "speed": 340.0, "air_speed": 300.0,
		"accel": 2600.0, "friction": 2600.0, "air_accel": 1600.0,
		"jump_vel": 740.0, "double_jump_vel": 680.0,
		"gravity": 2000.0, "fall_speed": 780.0, "fast_fall_speed": 1200.0,
		"weight": 100.0,
		"special_cooldown": 0.7,
		"moves": {
			"neutral": {"dmg": 7.0, "base_kb": 300.0, "kb_scale": 7.0, "angle": 40.0,
				"startup": 0.08, "active": 0.10, "recovery": 0.14,
				"box_pos": Vector2(40, -42), "box_size": Vector2(56, 40)},
			"up": {"dmg": 9.0, "base_kb": 340.0, "kb_scale": 9.0, "angle": 88.0,
				"startup": 0.10, "active": 0.12, "recovery": 0.18,
				"box_pos": Vector2(14, -82), "box_size": Vector2(56, 50)},
			"down": {"dmg": 8.0, "base_kb": 300.0, "kb_scale": 7.0, "angle": 30.0, "air_angle": -70.0,
				"startup": 0.10, "active": 0.10, "recovery": 0.18,
				"box_pos": Vector2(34, -16), "box_size": Vector2(64, 34)},
			"dash": {"dmg": 10.0, "base_kb": 330.0, "kb_scale": 7.5, "angle": 45.0,
				"startup": 0.08, "active": 0.14, "recovery": 0.22, "lunge": 380.0,
				"box_pos": Vector2(36, -40), "box_size": Vector2(60, 46)},
		},
	},
	"azul": {
		"name": "KORI",
		"desc": "Ninja del hielo. Rapidísima y ligera: sale volando fácil.",
		"script": "res://scripts/characters/azul.gd",
		"sheet": "res://assets/sprites/char_azul.png",
		"proj": "res://assets/sprites/proj_azul.png",
		"color": Color(0.36, 0.76, 1.0),
		"abilities": ["Shurikens de hielo", "Ráfaga (8 direcciones)", "Ventisca Eterna"],
		"walk_speed": 220.0, "speed": 420.0, "air_speed": 350.0,
		"accel": 3200.0, "friction": 3000.0, "air_accel": 2000.0,
		"jump_vel": 780.0, "double_jump_vel": 720.0,
		"gravity": 2000.0, "fall_speed": 740.0, "fast_fall_speed": 1200.0,
		"weight": 84.0,
		"special_cooldown": 0.55,
		"moves": {
			"neutral": {"dmg": 5.0, "base_kb": 260.0, "kb_scale": 6.0, "angle": 45.0,
				"startup": 0.05, "active": 0.09, "recovery": 0.10,
				"box_pos": Vector2(38, -42), "box_size": Vector2(52, 38)},
			"up": {"dmg": 7.0, "base_kb": 320.0, "kb_scale": 8.0, "angle": 88.0,
				"startup": 0.07, "active": 0.10, "recovery": 0.14,
				"box_pos": Vector2(12, -82), "box_size": Vector2(52, 50)},
			"down": {"dmg": 6.0, "base_kb": 280.0, "kb_scale": 6.0, "angle": 30.0, "air_angle": -70.0,
				"startup": 0.07, "active": 0.09, "recovery": 0.14,
				"box_pos": Vector2(32, -16), "box_size": Vector2(60, 32)},
			"dash": {"dmg": 7.0, "base_kb": 300.0, "kb_scale": 6.5, "angle": 40.0,
				"startup": 0.06, "active": 0.12, "recovery": 0.18, "lunge": 460.0,
				"box_pos": Vector2(34, -40), "box_size": Vector2(56, 44)},
		},
	},
	"verde": {
		"name": "GRUNK",
		"desc": "Bruto de las montañas. Lento y pesado, golpes devastadores.",
		"script": "res://scripts/characters/verde.gd",
		"sheet": "res://assets/sprites/char_verde.png",
		"proj": "res://assets/sprites/proj_verde.png",
		"color": Color(0.52, 0.9, 0.32),
		"abilities": ["Lanzar roca", "Supersalto", "Terremoto"],
		"walk_speed": 150.0, "speed": 270.0, "air_speed": 250.0,
		"accel": 2000.0, "friction": 2400.0, "air_accel": 1200.0,
		"jump_vel": 700.0, "double_jump_vel": 640.0,
		"gravity": 2200.0, "fall_speed": 840.0, "fast_fall_speed": 1300.0,
		"weight": 130.0,
		"special_cooldown": 1.1,
		"moves": {
			"neutral": {"dmg": 11.0, "base_kb": 340.0, "kb_scale": 9.5, "angle": 38.0,
				"startup": 0.15, "active": 0.12, "recovery": 0.22,
				"box_pos": Vector2(44, -42), "box_size": Vector2(64, 46)},
			"up": {"dmg": 13.0, "base_kb": 380.0, "kb_scale": 11.0, "angle": 86.0,
				"startup": 0.17, "active": 0.14, "recovery": 0.26,
				"box_pos": Vector2(16, -86), "box_size": Vector2(66, 56)},
			"down": {"dmg": 12.0, "base_kb": 340.0, "kb_scale": 9.5, "angle": 30.0, "air_angle": -70.0,
				"startup": 0.17, "active": 0.12, "recovery": 0.24,
				"box_pos": Vector2(38, -16), "box_size": Vector2(72, 38)},
			"dash": {"dmg": 13.0, "base_kb": 360.0, "kb_scale": 9.0, "angle": 42.0,
				"startup": 0.12, "active": 0.14, "recovery": 0.3, "lunge": 300.0,
				"box_pos": Vector2(40, -42), "box_size": Vector2(64, 50)},
		},
	},
	"morado": {
		"name": "UMBRA",
		"desc": "Espectro de las sombras. Se teletransporta y ataca por la espalda.",
		"script": "res://scripts/characters/morado.gd",
		"sheet": "res://assets/sprites/char_morado.png",
		"proj": "res://assets/sprites/proj_morado.png",
		"color": Color(0.74, 0.5, 1.0),
		"abilities": ["Paranoia (atraviesa)", "Paso sombrío (teletransporte)", "Desde las Sombras"],
		"walk_speed": 180.0, "speed": 330.0, "air_speed": 310.0,
		"accel": 2400.0, "friction": 2400.0, "air_accel": 1700.0,
		"jump_vel": 720.0, "double_jump_vel": 680.0,
		"gravity": 1750.0, "fall_speed": 680.0, "fast_fall_speed": 1100.0,
		"weight": 92.0,
		"special_cooldown": 0.9,
		"moves": {
			"neutral": {"dmg": 8.0, "base_kb": 300.0, "kb_scale": 7.0, "angle": 42.0,
				"startup": 0.09, "active": 0.10, "recovery": 0.15,
				"box_pos": Vector2(40, -42), "box_size": Vector2(58, 42)},
			"up": {"dmg": 8.0, "base_kb": 330.0, "kb_scale": 8.5, "angle": 88.0,
				"startup": 0.10, "active": 0.12, "recovery": 0.18,
				"box_pos": Vector2(14, -82), "box_size": Vector2(56, 50)},
			"down": {"dmg": 8.0, "base_kb": 300.0, "kb_scale": 7.0, "angle": 30.0, "air_angle": -70.0,
				"startup": 0.10, "active": 0.10, "recovery": 0.18,
				"box_pos": Vector2(34, -16), "box_size": Vector2(64, 34)},
			"dash": {"dmg": 9.0, "base_kb": 320.0, "kb_scale": 7.0, "angle": 40.0,
				"startup": 0.08, "active": 0.14, "recovery": 0.2, "lunge": 400.0,
				"box_pos": Vector2(36, -40), "box_size": Vector2(60, 46)},
		},
	},
}

const ORDER := ["rojo", "azul", "verde", "morado"]

## Golpe con el bate (objeto)
const BAT_MOVE := {"dmg": 15.0, "base_kb": 420.0, "kb_scale": 12.0, "angle": 38.0,
	"startup": 0.16, "active": 0.10, "recovery": 0.28,
	"box_pos": Vector2(52, -44), "box_size": Vector2(80, 56), "bat": true}


static func get_data(id: String) -> Dictionary:
	return DATA.get(id, DATA["rojo"])
