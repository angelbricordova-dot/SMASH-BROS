class_name CharacterData
extends RefCounted
## ============================================================
##  DATOS DE LOS PERSONAJES  (¡aquí cambias cómo se siente cada uno!)
## ============================================================
## Para agregar un personaje nuevo: copia un bloque (por ejemplo "rojo"),
## cámbiale el nombre y los números, y pon su hoja de sprites en
## assets/sprites/char_<id>.png  (mira docs/GUIA_PASO_A_PASO.md).
##
## Significado de los números:
##  speed        velocidad al correr (píxeles por segundo)
##  accel        qué tan rápido acelera en el suelo
##  friction     qué tan rápido frena en el suelo
##  air_accel    control en el aire
##  jump_vel     fuerza del salto
##  double_jump_vel  fuerza del segundo salto
##  gravity      qué tan rápido cae
##  fall_speed   velocidad máxima de caída
##  fast_fall_speed  velocidad de caída rápida (presionando abajo)
##  weight       peso: más peso = sale volando menos
##
##  Ataques ("moves"):
##  dmg        daño en %
##  base_kb    fuerza base con la que empuja
##  kb_scale   cuánto más empuja por cada % de daño que ya tenga el rival
##  angle      ángulo de salida en grados (0 = horizontal, 90 = hacia arriba, -90 = hacia abajo)
##  startup    segundos antes de que el golpe "salga"
##  active     segundos que el golpe está activo
##  recovery   segundos de recuperación (no puedes hacer nada)
##  box_pos    centro de la zona de golpe respecto a los pies (x hacia delante, y hacia arriba es negativo)
##  box_size   tamaño de la zona de golpe

const DATA := {
	"rojo": {
		"name": "RYU-KO",
		"desc": "Equilibrado. Buen daño y buen alcance.",
		"sheet": "res://assets/sprites/char_rojo.png",
		"proj": "res://assets/sprites/proj_rojo.png",
		"color": Color(1.0, 0.35, 0.25),
		"speed": 320.0, "accel": 2400.0, "friction": 2800.0, "air_accel": 1300.0,
		"jump_vel": 720.0, "double_jump_vel": 660.0,
		"gravity": 1900.0, "fall_speed": 760.0, "fast_fall_speed": 1150.0,
		"weight": 100.0,
		"moves": {
			"neutral": {"dmg": 7.0, "base_kb": 300.0, "kb_scale": 7.0, "angle": 40.0,
				"startup": 0.10, "active": 0.12, "recovery": 0.16,
				"box_pos": Vector2(40, -42), "box_size": Vector2(56, 40)},
			"up": {"dmg": 9.0, "base_kb": 340.0, "kb_scale": 9.0, "angle": 88.0,
				"startup": 0.12, "active": 0.14, "recovery": 0.20,
				"box_pos": Vector2(14, -82), "box_size": Vector2(56, 50)},
			"down": {"dmg": 8.0, "base_kb": 300.0, "kb_scale": 7.0, "angle": 30.0, "air_angle": -70.0,
				"startup": 0.12, "active": 0.12, "recovery": 0.20,
				"box_pos": Vector2(34, -16), "box_size": Vector2(64, 34)},
		},
		"special": {"dmg": 6.0, "base_kb": 260.0, "kb_scale": 6.0, "angle": 30.0,
			"speed": 620.0, "size": 18.0, "lifetime": 1.2, "startup": 0.22, "recovery": 0.22, "cooldown": 0.8},
	},
	"azul": {
		"name": "KORI",
		"desc": "Rápida y ligera. Sale volando fácil.",
		"sheet": "res://assets/sprites/char_azul.png",
		"proj": "res://assets/sprites/proj_azul.png",
		"color": Color(0.35, 0.75, 1.0),
		"speed": 390.0, "accel": 3000.0, "friction": 3200.0, "air_accel": 1700.0,
		"jump_vel": 760.0, "double_jump_vel": 700.0,
		"gravity": 1900.0, "fall_speed": 720.0, "fast_fall_speed": 1150.0,
		"weight": 84.0,
		"moves": {
			"neutral": {"dmg": 5.0, "base_kb": 260.0, "kb_scale": 6.0, "angle": 45.0,
				"startup": 0.06, "active": 0.10, "recovery": 0.12,
				"box_pos": Vector2(38, -42), "box_size": Vector2(52, 38)},
			"up": {"dmg": 7.0, "base_kb": 320.0, "kb_scale": 8.0, "angle": 88.0,
				"startup": 0.08, "active": 0.12, "recovery": 0.16,
				"box_pos": Vector2(12, -82), "box_size": Vector2(52, 50)},
			"down": {"dmg": 6.0, "base_kb": 280.0, "kb_scale": 6.0, "angle": 30.0, "air_angle": -70.0,
				"startup": 0.08, "active": 0.10, "recovery": 0.16,
				"box_pos": Vector2(32, -16), "box_size": Vector2(60, 32)},
		},
		"special": {"dmg": 5.0, "base_kb": 240.0, "kb_scale": 5.0, "angle": 25.0,
			"speed": 820.0, "size": 14.0, "lifetime": 1.0, "startup": 0.18, "recovery": 0.16, "cooldown": 0.55},
	},
	"verde": {
		"name": "GRUNK",
		"desc": "Lento y pesado. Golpes devastadores.",
		"sheet": "res://assets/sprites/char_verde.png",
		"proj": "res://assets/sprites/proj_verde.png",
		"color": Color(0.5, 0.9, 0.3),
		"speed": 250.0, "accel": 1800.0, "friction": 2400.0, "air_accel": 1000.0,
		"jump_vel": 660.0, "double_jump_vel": 600.0,
		"gravity": 2100.0, "fall_speed": 820.0, "fast_fall_speed": 1250.0,
		"weight": 130.0,
		"moves": {
			"neutral": {"dmg": 11.0, "base_kb": 340.0, "kb_scale": 9.5, "angle": 38.0,
				"startup": 0.18, "active": 0.14, "recovery": 0.26,
				"box_pos": Vector2(44, -42), "box_size": Vector2(64, 46)},
			"up": {"dmg": 13.0, "base_kb": 380.0, "kb_scale": 11.0, "angle": 86.0,
				"startup": 0.20, "active": 0.16, "recovery": 0.30,
				"box_pos": Vector2(16, -86), "box_size": Vector2(66, 56)},
			"down": {"dmg": 12.0, "base_kb": 340.0, "kb_scale": 9.5, "angle": 30.0, "air_angle": -70.0,
				"startup": 0.20, "active": 0.14, "recovery": 0.28,
				"box_pos": Vector2(38, -16), "box_size": Vector2(72, 38)},
		},
		"special": {"dmg": 9.0, "base_kb": 300.0, "kb_scale": 8.0, "angle": 35.0,
			"speed": 420.0, "size": 26.0, "lifetime": 1.6, "startup": 0.30, "recovery": 0.30, "cooldown": 1.2},
	},
}

const ORDER := ["rojo", "azul", "verde"]


static func get_data(id: String) -> Dictionary:
	return DATA.get(id, DATA["rojo"])
