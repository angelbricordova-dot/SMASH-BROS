class_name Cards
extends RefCounted
## ============================================================
##  MODO CAOS DE CARTAS: la baraja de mejoras
## ============================================================
## Al empezar, cada jugador elige 1 de 3 cartas. Cada vez que saca a un rival (KO),
## gana un punto y elige OTRA carta. Para agregar una carta: copia una línea de DECK
## y programa su efecto en apply().
## rareza: 0 común (azul), 1 rara (morado), 2 épica (dorado)

const DECK := [
	{"id": "double_dmg", "name": "Doble Golpe", "icon": "x2", "rarity": 2,
		"desc": "Todos tus ataques hacen el DOBLE de daño."},
	{"id": "instant_ult", "name": "Ulti Instantánea", "icon": "U", "rarity": 2,
		"desc": "Tu barra de ulti se llena AHORA y se carga 50% más rápido."},
	{"id": "triple_jump", "name": "Triple Salto", "icon": "^^^", "rarity": 1,
		"desc": "Ganas un salto extra en el aire (¡tres saltos!)."},
	{"id": "swift", "name": "Pies Veloces", "icon": ">>", "rarity": 0,
		"desc": "Te mueves 25% más rápido en el suelo y en el aire."},
	{"id": "heavy", "name": "Peso Pesado", "icon": "KG", "rarity": 0,
		"desc": "Eres 35% más pesado: cuesta mucho más mandarte a volar."},
	{"id": "giant", "name": "Gigante", "icon": "+", "rarity": 1,
		"desc": "Creces 30%: +25% daño y +25% peso, pero eres un blanco más grande."},
	{"id": "mini", "name": "Mini", "icon": "-", "rarity": 0,
		"desc": "Te encoges: blanco pequeño y +15% velocidad (pero -10% peso)."},
	{"id": "vampire", "name": "Vampiro", "icon": "V", "rarity": 1,
		"desc": "Te curas 30% del daño que haces."},
	{"id": "regen", "name": "Regeneración", "icon": "+%", "rarity": 0,
		"desc": "Tu daño baja 1.5% cada segundo."},
	{"id": "power_arm", "name": "Brazo de Hierro", "icon": "KB", "rarity": 1,
		"desc": "Tus golpes empujan 35% más lejos."},
	{"id": "armor", "name": "Súper Armadura", "icon": "A", "rarity": 1,
		"desc": "Los golpes de menos de 10% no te hacen salir volando."},
	{"id": "parry_master", "name": "Maestro del Parry", "icon": "P", "rarity": 0,
		"desc": "La ventana del parry es el doble de grande y cada parry te cura 5%."},
	{"id": "thorns", "name": "Espinas", "icon": "*", "rarity": 0,
		"desc": "Quien te golpee cuerpo a cuerpo recibe 35% del daño."},
	{"id": "spell_power", "name": "Poder Arcano", "icon": "S", "rarity": 1,
		"desc": "Especiales con 40% más daño y la mitad de espera."},
	{"id": "feather", "name": "Pluma", "icon": "~", "rarity": 0,
		"desc": "Caes 25% más lento y saltas 10% más alto."},
	{"id": "extra_life", "name": "Segunda Vida", "icon": "1UP", "rarity": 2,
		"desc": "Ganas una vida extra."},
	{"id": "crit", "name": "Golpe Crítico", "icon": "!", "rarity": 1,
		"desc": "20% de probabilidad de hacer 2.5 veces el daño."},
	{"id": "arsenal", "name": "Arsenal", "icon": "[]", "rarity": 0,
		"desc": "Recibes un objeto al azar ahora mismo (bate, espada, arco...)."},
	{"id": "titan_shield", "name": "Escudo de Titanio", "icon": "O", "rarity": 0,
		"desc": "Tu escudo es el doble de fuerte y se recupera el doble de rápido."},
	{"id": "star_power", "name": "Poder Estelar", "icon": "★", "rarity": 2,
		"desc": "Eres invencible durante 12 segundos."},
]

const RARITY_COLORS := [Color(0.35, 0.65, 1.0), Color(0.75, 0.45, 1.0), Color(1.0, 0.8, 0.25)]
const RARITY_NAMES := ["COMÚN", "RARA", "ÉPICA"]


static func get_card(id: String) -> Dictionary:
	for c in DECK:
		if c["id"] == id:
			return c
	return DECK[0]


## Tres cartas al azar (las épicas salen menos).
static func draw_three(owned: Array) -> Array:
	var pool := []
	for c in DECK:
		if owned.has(c["id"]) and c["id"] in ["triple_jump", "extra_life", "double_dmg", "giant", "mini"]:
			continue
		var weight: int = [6, 3, 1][c["rarity"]]
		for i in weight:
			pool.append(c)
	pool.shuffle()
	var out := []
	for c in pool:
		if not out.has(c):
			out.append(c)
		if out.size() == 3:
			break
	return out


static func apply(f: Fighter, id: String) -> void:
	f.cards.append(id)
	var m := f.mods
	match id:
		"double_dmg": m["dmg"] *= 2.0
		"instant_ult":
			f.add_meter(Fighter.ULT_MAX)
			m["meter"] *= 1.5
		"triple_jump": m["extra_jumps"] += 1
		"swift": m["speed"] *= 1.25
		"heavy": m["weight"] *= 1.35
		"giant":
			m["size"] *= 1.3
			m["dmg"] *= 1.25
			m["weight"] *= 1.25
		"mini":
			m["size"] *= 0.72
			m["speed"] *= 1.15
			m["weight"] *= 0.9
		"vampire": m["lifesteal"] += 0.3
		"regen": m["regen"] += 1.5
		"power_arm": m["kb"] *= 1.35
		"armor": m["armor"] = maxf(m["armor"], 10.0)
		"parry_master": m["parry"] *= 2.0
		"thorns": m["thorns"] += 0.35
		"spell_power":
			m["special_dmg"] *= 1.4
			m["special_cd"] *= 0.5
		"feather":
			m["gravity"] *= 0.75
			m["jump"] *= 1.1
		"extra_life": f.stocks += 1
		"crit": m["crit"] = minf(0.6, m["crit"] + 0.2)
		"arsenal":
			f.held_item = ["bat", "sword", "bow", "bomb", "boomerang"].pick_random()
			f.item_ammo = {"bow": 3, "sword": 12}.get(f.held_item, 0)
		"titan_shield":
			m["shield"] *= 2.0
			f.shield_hp = f.max_shield()
		"star_power": f.star_time = 12.0
	f.air_jumps_left = f.max_air_jumps()
