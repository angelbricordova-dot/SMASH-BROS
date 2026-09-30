extends Node
## Prueba automática (sin ventana): simula peleas para comprobar que todo funciona.
## Correr:  godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn
## (opcional: -- --only=cpu   para correr solo una parte)

class ScriptBrain extends CpuBrain:
	var script_fn: Callable
	func think(f: Fighter, _delta: float) -> void:
		f.in_move = 0.0
		f.in_up = false
		f.in_down = false
		f.in_jump_held = false
		f.in_shield = false
		f.in_attack_held = false
		f.in_special_held = false
		if script_fn.is_valid():
			script_fn.call(f)

var stage: Node
var p1: Fighter
var p2: Fighter
var fails := 0
var only := ""


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func check(name: String, ok: bool, extra := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + name + "  " + extra)
	if not ok:
		fails += 1


func setup_stage(c1 := "lamont", c2 := "ilunna", stage_id := "pradera", items := false, mode := "classic") -> void:
	if stage:
		stage.queue_free()
		await frames(2)
	Engine.time_scale = 1.0
	get_tree().paused = false
	Game.players = [{"char": c1, "cpu": true, "level": 1}, {"char": c2, "cpu": true, "level": 1}]
	Game.match_setup = {}
	Game.items_on = items
	Game.mode = mode
	Game.stocks = 3
	stage = load(Game.stage_scene(stage_id)).instantiate()
	add_child(stage)
	await frames(1)
	p1 = stage.fighters[0]
	p2 = stage.fighters[1]
	for f in [p1, p2]:
		f.brain = ScriptBrain.new()
	await frames(200)


func press(f: Fighter, fn: Callable) -> void:
	f.brain.script_fn = fn
	await frames(1)
	f.brain.script_fn = Callable()


func hold(f: Fighter, fn: Callable, n: int) -> void:
	f.brain.script_fn = fn
	await frames(n)
	f.brain.script_fn = Callable()


func place(a: Fighter, pos: Vector2, b: Fighter, pos_b: Vector2) -> void:
	a.global_position = pos
	b.global_position = pos_b
	a.velocity = Vector2.ZERO
	b.velocity = Vector2.ZERO
	for f in [a, b]:
		f.state = Fighter.State.NORMAL
		f.invincible_time = 0.0
		f.hover_time = 0.0
		f.visible = true


func recover(f: Fighter) -> void:
	var pos := f.global_position
	if absf(pos.x) > 420.0 or pos.y > 190.0 and not f.is_on_floor():
		f.in_move = -signf(pos.x) if absf(pos.x) > 380.0 else 0.0
		if f.state == Fighter.State.NORMAL and f.air_jumps_left > 0 and f.velocity.y > 0.0 and pos.y > 120.0:
			f.in_jump_pressed = true
			f.in_jump_held = true
		f.in_jump_held = f.velocity.y < 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	var tests := [["move", test_movement], ["combo", test_combos], ["smash", test_smash], ["defense", test_defense],
		["ledge", test_ledge], ["specials", test_specials], ["items", test_items], ["cards", test_cards],
		["ko", test_ko], ["human", test_human_input], ["menu", test_menu], ["training", test_training],
		["final", test_final_blow], ["cpu", test_cpu_matches]]
	for t in tests:
		if only == "" or only == t[0]:
			await t[1].call()
	print("=== RESULTADO: %s ===" % ("TODO BIEN" if fails == 0 else "%d FALLOS" % fails))
	get_tree().quit(fails)


func test_movement() -> void:
	await setup_stage()
	check("p1 en el suelo", p1.is_on_floor(), "y=%.1f" % p1.global_position.y)
	var x0 := p1.global_position.x
	await hold(p1, func(f): f.in_move = 1.0, 30)
	var walk := p1.global_position.x - x0
	await frames(30)
	x0 = p1.global_position.x
	await press(p1, func(f): f.in_right_pressed = true)
	await frames(3)
	await press(p1, func(f):
		f.in_move = 1.0
		f.in_right_pressed = true)
	await hold(p1, func(f): f.in_move = 1.0, 29)
	var run := p1.global_position.x - x0
	check("correr (doble toque) más rápido que caminar", run > walk * 1.4, "caminar=%.0f correr=%.0f" % [walk, run])
	await frames(40)
	await press(p1, func(f):
		f.in_jump_pressed = true
		f.in_jump_held = true)
	await hold(p1, func(f): f.in_jump_held = true, 20)
	await press(p1, func(f):
		f.in_jump_pressed = true
		f.in_jump_held = true)
	check("doble salto", p1.air_jumps_left == 0 and p1.velocity.y < 0.0)
	await frames(90)
	check("aterriza", p1.is_on_floor())


func _attack_name(f: Fighter) -> String:
	return f.move.get("name", "") if f.state == Fighter.State.ATTACK else ""


func test_combos() -> void:
	await setup_stage()
	place(p1, Vector2(0, 199), p2, Vector2(50, 199))
	p1.facing = 1
	await frames(5)
	var seen := []
	for i in 30:
		p1.brain.script_fn = (func(f): f.in_attack_pressed = true) if i % 5 == 0 else Callable()
		await frames(1)
		var n := _attack_name(p1)
		if n != "" and not seen.has(n):
			seen.append(n)
	p1.brain.script_fn = Callable()
	check("combo jab1 -> jab2 -> jab3", seen.slice(0, 3) == ["jab1", "jab2", "jab3"], str(seen))
	check("el combo hace daño", p2.percent > 6.0, "%.1f%%" % p2.percent)
	await frames(60)
	var cases := [["utilt", func(f):
			f.in_up = true
			f.in_attack_pressed = true],
		["dtilt", func(f):
			f.in_down = true
			f.in_attack_pressed = true]]
	for c in cases:
		place(p1, Vector2(0, 199), p2, Vector2(300, 199))
		await frames(10)
		await press(p1, c[1])
		await frames(2)
		check("ataque %s" % c[0], _attack_name(p1) == c[0], _attack_name(p1))
		await frames(40)
	# lado + ataque (se decide al soltar)
	place(p1, Vector2(0, 199), p2, Vector2(300, 199))
	await frames(10)
	await press(p1, func(f):
		f.in_move = 1.0
		f.in_attack_pressed = true
		f.in_attack_held = true)
	await press(p1, func(f): f.in_move = 1.0)
	await frames(1)
	check("ataque ftilt (lado + F)", _attack_name(p1) == "ftilt", _attack_name(p1))
	await frames(40)
	# aéreos
	for c in [["nair", 0.0, false, false], ["fair", 1.0, false, false], ["bair", -1.0, false, false],
			["uair", 0.0, true, false], ["dair", 0.0, false, true]]:
		place(p1, Vector2(0, -100), p2, Vector2(300, 199))
		p1.facing = 1
		await frames(3)
		var mv: float = c[1]
		var up: bool = c[2]
		var dn: bool = c[3]
		await press(p1, func(f):
			f.in_move = mv
			f.in_up = up
			f.in_down = dn
			f.in_attack_pressed = true)
		await frames(2)
		check("aéreo %s" % c[0], _attack_name(p1) == c[0], _attack_name(p1))
		await frames(60)


func test_smash() -> void:
	await setup_stage()
	place(p1, Vector2(0, 199), p2, Vector2(60, 199))
	p1.facing = 1
	await frames(5)
	await press(p1, func(f):
		f.in_attack_pressed = true
		f.in_attack_held = true)
	await hold(p1, func(f): f.in_attack_held = true, 45)
	check("mantener F carga el smash", p1.charging and _attack_name(p1) == "smash", _attack_name(p1))
	await frames(40)
	check("smash cargado hace mucho daño", p2.percent >= 17.0, "%.1f%%" % p2.percent)


func test_defense() -> void:
	await setup_stage()
	place(p1, Vector2(0, 199), p2, Vector2(50, 199))
	await frames(10)
	p1.facing = 1
	# escudo
	var pc := p2.percent
	p2.brain.script_fn = func(f): f.in_shield = true
	await frames(10)
	var hp := p2.shield_hp
	await press(p1, func(f): f.in_attack_pressed = true)
	await frames(30)
	check("escudo bloquea y se agrieta", is_equal_approx(p2.percent, pc) and p2.shield_hp < hp - 3.0,
		"hp %.0f -> %.0f" % [hp, p2.shield_hp])
	# rodar
	p2.brain.script_fn = func(f):
		f.in_shield = true
		f.in_right_pressed = true
	await frames(1)
	p2.brain.script_fn = Callable()
	await frames(4)
	check("escudo + lado = rodar", p2.action == "roll", p2.action)
	await frames(60)
	# parry (barra nerfeada)
	place(p1, Vector2(-100, 199), p2, Vector2(-50, 199))
	p2.ult_meter = 0.0
	await frames(10)
	pc = p2.percent
	p1.facing = 1
	var startup: float = p1.moves["jab1"]["startup"]
	p1.brain.script_fn = func(f):
		f.in_attack_pressed = true
	await frames(1)
	p1.brain.script_fn = Callable()
	await frames(maxi(0, int(startup * 60.0) - 2))
	await press(p2, func(f): f.in_left_pressed = true)
	await frames(20)
	check("PARRY evita el daño", is_equal_approx(p2.percent, pc), "%.1f%%" % p2.percent)
	check("PARRY llena poco la barra (nerf)", p2.ult_meter > 0.0 and p2.ult_meter <= Fighter.PARRY_METER + 1.0,
		"%.0f" % p2.ult_meter)
	await frames(60)
	# esquiva en el aire
	place(p1, Vector2(300, -60), p2, Vector2(-300, 199))
	await frames(2)
	await press(p1, func(f):
		f.in_shield = true
		f.in_shield_pressed = true)
	await frames(3)
	check("esquiva aérea (intangible)", p1.action == "airdodge" and p1.intangible_time > 0.0)
	await frames(60)


func test_ledge() -> void:
	await setup_stage()
	p1.global_position = Vector2(470, 240)
	p1.velocity = Vector2(0, 50)
	var grabbed := false
	for i in 40:
		await frames(1)
		if p1.state == Fighter.State.LEDGE:
			grabbed = true
			break
	check("se cuelga del borde", grabbed, "pos=%s" % p1.global_position)
	await frames(15)
	await press(p1, func(f): f.in_up = true)
	await frames(10)
	check("sube desde el borde", p1.is_on_floor() and p1.global_position.x < 450.0, "pos=%s" % p1.global_position)


func test_specials() -> void:
	for cid in CharacterData.ORDER:
		await setup_stage(cid, "lamont")
		# neutral
		place(p1, Vector2(-300, 199), p2, Vector2(-130, 199))
		p1.facing = 1
		await frames(5)
		await press(p1, func(f):
			f.in_special_pressed = true
			f.in_special_held = true)
		await frames(90)
		check("%s: especial golpea" % cid, p2.percent > 0.0, "%.0f%%" % p2.percent)
		await frames(40)
		# cargado (cada uno tiene su alcance)
		var dist: float = {"ilunna": 120.0}.get(cid, 170.0)
		place(p1, Vector2(-300, 199), p2, Vector2(-300 + dist, 199))
		p2.percent = 0.0
		p1.facing = 1
		p1.special_cooldown = 0.0
		await frames(5)
		await press(p1, func(f):
			f.in_special_pressed = true
			f.in_special_held = true)
		await hold(p1, func(f): f.in_special_held = true, 50)
		var charging := (p1.state == Fighter.State.ACTION and p1.act.has("charge")) or p1.special_hold_t >= 0.0
		await frames(150)
		check("%s: especial cargado" % cid, charging and p2.percent > 0.0, "%.0f%% accion=%s" % [p2.percent, p1.action])
		await frames(30)
		# abajo + especial
		place(p1, Vector2(-100, 199), p2, Vector2(-40, 199))
		p1.facing = 1
		await frames(5)
		await press(p1, func(f):
			f.in_down = true
			f.in_special_pressed = true)
		await frames(3)
		var started := p1.state == Fighter.State.ACTION
		await frames(120)
		check("%s: abajo + especial" % cid, started and p1.state != Fighter.State.ACTION, p1.action)
		await frames(60)
		# abajo + especial EN EL AIRE (antes no hacía nada)
		place(p1, Vector2(-40, 20), p2, Vector2(-20, 199))
		p1.facing = 1
		p2.percent = 0.0
		await frames(2)
		await press(p1, func(f):
			f.in_down = true
			f.in_special_pressed = true)
		await frames(2)
		var air_act := p1.action
		await frames(120)
		check("%s: abajo + especial en el aire (%s)" % [cid, air_act], air_act != "" and p1.state != Fighter.State.ACTION)
		await frames(40)
		# recuperación
		place(p1, Vector2(-100, 100), p2, Vector2(300, 199))
		p1.air_jumps_left = 0
		await frames(2)
		var y0 := p1.global_position.y
		await press(p1, func(f):
			f.in_up = true
			f.in_special_pressed = true)
		var min_y := y0
		for i in 50:
			await frames(1)
			min_y = minf(min_y, p1.global_position.y)
		check("%s: recuperación sube" % cid, min_y < y0 - 120.0, "sube %.0f" % (y0 - min_y))
		await frames(120)
		# ulti
		place(p1, Vector2(-150, 199), p2, Vector2(-40, 199))
		p1.facing = 1
		p2.percent = 0.0
		p2.invincible_time = 0.0
		p1.ult_meter = Fighter.ULT_MAX
		await frames(3)
		await press(p1, func(f): f.in_ult_pressed = true)
		await frames(200)
		match cid:
			"ilunna", "panadero":
				check("%s: ULTI transforma" % cid, p1.form == "ult", "forma=%s" % p1.form)
			"abnielito":
				check("abnielito: ULTI confunde al rival", p2.confused_time > 0.0, "%.1f s" % p2.confused_time)
			"lamont":
				check("lamont: ULTI (préstamo) suma 40%% al rival", p2.percent >= 40.0, "p2=%.0f%%" % p2.percent)
			_:
				check("%s: ULTI golpea (>= 20%%)" % cid, p2.percent >= 20.0 or p2.stocks < 3, "p2=%.0f%%" % p2.percent)
		await frames(60 * 8)


func test_items() -> void:
	await setup_stage()
	place(p1, Vector2(-200, 199), p2, Vector2(200, 199))
	var bat: Item = stage.spawn_item("bat")
	bat.global_position = Vector2(-190, 150)
	await frames(40)
	await press(p1, func(f): f.in_attack_pressed = true)
	await frames(2)
	check("recoger bate", p1.held_item == "bat")
	place(p1, Vector2(0, 199), p2, Vector2(60, 199))
	p2.percent = 60.0
	p1.facing = 1
	await frames(3)
	await press(p1, func(f):
		f.in_attack_pressed = true
		f.in_attack_held = true)
	await hold(p1, func(f): f.in_attack_held = true, 60)
	await frames(200)
	check("batazo CARGADO a 60% = home run", p2.stocks < 3, "p2=%s" % p2.global_position)
	await frames(100)
	# lanzar el bate
	place(p1, Vector2(-200, 199), p2, Vector2(0, 199))
	p2.percent = 0.0
	p1.facing = 1
	await frames(3)
	await press(p1, func(f): f.in_throw_pressed = true)
	await frames(40)
	check("lanzar el bate (tecla C) y hace daño", p1.held_item == "" and p2.percent > 5.0, "%.0f%%" % p2.percent)
	await frames(60)
	check("el bate queda en el suelo para recogerlo", get_tree().get_nodes_in_group("items").size() >= 1)
	# bomba
	for it in get_tree().get_nodes_in_group("items"):
		it.queue_free()
	place(p1, Vector2(-200, 199), p2, Vector2(50, 199))
	p2.percent = 0.0
	p1.held_item = "bomb"
	p1.facing = 1
	await frames(3)
	await press(p1, func(f): f.in_attack_pressed = true)
	await frames(60)
	check("bomba lanzada explota", p2.percent >= 15.0, "%.0f%%" % p2.percent)
	await frames(60)
	# bumerán
	place(p1, Vector2(-200, 199), p2, Vector2(100, 199))
	p2.percent = 0.0
	p1.held_item = "boomerang"
	p1.facing = 1
	await frames(3)
	await press(p1, func(f): f.in_throw_pressed = true)
	await frames(120)
	check("bumerán golpea y vuelve", p2.percent > 0.0 and p1.held_item == "boomerang", "%.0f%% item=%s" % [p2.percent, p1.held_item])
	# espada
	place(p1, Vector2(0, 199), p2, Vector2(80, 199))
	p2.percent = 0.0
	p1.held_item = "sword"
	p1.item_ammo = 12
	p1.facing = 1
	await frames(3)
	await press(p1, func(f): f.in_attack_pressed = true)
	await frames(40)
	check("espada de energía golpea de lejos", p2.percent >= 10.0, "%.0f%%" % p2.percent)
	# corazón y estrella
	await frames(60)
	p1.held_item = ""
	p1.percent = 80.0
	var heart: Item = stage.spawn_item("heart")
	heart.global_position = p1.global_position + Vector2(0, -20)
	await frames(30)
	await press(p1, func(f): f.in_attack_pressed = true)
	await frames(2)
	check("corazón cura", p1.percent <= 41.0, "%.0f%%" % p1.percent)
	var star: Item = stage.spawn_item("star")
	star.global_position = p1.global_position + Vector2(0, -20)
	await frames(30)
	await press(p1, func(f): f.in_attack_pressed = true)
	await frames(2)
	check("estrella = invencible", p1.star_time > 0.0)


func test_cards() -> void:
	await setup_stage()
	place(p1, Vector2(0, 199), p2, Vector2(50, 199))
	p1.facing = 1
	await frames(5)
	await press(p1, func(f): f.in_attack_pressed = true)
	await frames(30)
	var normal := p2.percent
	await frames(60)
	Cards.apply(p1, "double_dmg")
	place(p1, Vector2(0, 199), p2, Vector2(50, 199))
	p2.percent = 0.0
	await frames(5)
	await press(p1, func(f): f.in_attack_pressed = true)
	await frames(30)
	check("carta Doble Golpe duplica el daño", is_equal_approx(p2.percent, normal * 2.0), "%.1f vs %.1f" % [p2.percent, normal])
	Cards.apply(p1, "triple_jump")
	check("carta Triple Salto", p1.max_air_jumps() == 2)
	Cards.apply(p1, "instant_ult")
	check("carta Ulti Instantánea", p1.ult_meter >= Fighter.ULT_MAX)
	# modo completo con CPUs: eligen cartas al inicio y tras cada KO
	if stage:
		stage.queue_free()
		await frames(2)
	Game.players = [{"char": "ilunna", "cpu": true, "level": 2}, {"char": "lamont", "cpu": true, "level": 2}]
	Game.match_setup = {}
	Game.mode = "cards"
	Game.stocks = 2
	stage = load(Game.stage_scene("bosque")).instantiate()
	add_child(stage)
	var n := 0
	while not stage.over and n < 60 * 200:
		await get_tree().process_frame
		n += 1
	var f1: Fighter = stage.fighters[0]
	var f2: Fighter = stage.fighters[1]
	print("   cartas: ilunna=%s  lamont=%s" % [f1.cards, f2.cards])
	check("modo Caos de Cartas: todos eligen al inicio y hay cartas extra por KO",
		f1.cards.size() >= 1 and f2.cards.size() >= 1 and f1.cards.size() + f2.cards.size() >= 3)
	check("modo Caos de Cartas termina", stage.over)
	get_tree().paused = false
	Game.mode = "classic"


func ko_test(move_fn: Callable, victim_pos: Vector2, start_pct: float, target_id: String) -> bool:
	await setup_stage("lamont", target_id)
	place(p1, victim_pos + Vector2(-50, 0), p2, victim_pos)
	p1.facing = 1
	p2.percent = start_pct
	await frames(3)
	p2.brain.script_fn = recover
	await press(p1, move_fn)
	await frames(240)
	return p2.stocks < 3


func test_ko() -> void:
	for target in ["ilunna", "panadero"]:
		var found := -1
		for pct in range(40, 300, 20):
			if await ko_test(func(f):
					f.in_move = 1.0
					f.in_attack_pressed = true, Vector2(0, 199), float(pct), target):
				found = pct
				break
		print("   KO con ataque lateral (ftilt) de lamont contra %s -> %d%%" % [target, found])


func test_human_input() -> void:
	if stage:
		stage.queue_free()
		await frames(2)
	Engine.time_scale = 1.0
	Game.players = [{"char": "schizov", "cpu": false, "level": 1}, {"char": "ilunna", "cpu": true, "level": 1}]
	Game.match_setup = {}
	Game.mode = "classic"
	stage = load(Game.stage_scene("pradera")).instantiate()
	add_child(stage)
	await frames(200)
	var f: Fighter = stage.fighters[0]
	stage.fighters[1].brain = ScriptBrain.new()
	Input.action_press("p1_right")
	await frames(2)
	Input.action_release("p1_right")
	await frames(3)
	Input.action_press("p1_right")
	await frames(5)
	check("P1 humano corre con doble toque", f.running, "vx=%.0f" % f.velocity.x)
	await frames(20)
	Input.action_release("p1_right")
	await frames(20)
	Input.action_press("p1_attack")
	await frames(2)
	Input.action_release("p1_attack")
	await frames(3)
	check("P1 humano: tocar F = jab", _attack_name(f) == "jab1", _attack_name(f))
	await frames(40)
	Input.action_press("p1_attack")
	await frames(30)
	check("P1 humano: mantener F = smash cargando", f.charging, _attack_name(f))
	Input.action_release("p1_attack")
	await frames(60)
	# saltar con W (arriba)
	f.global_position = Vector2(-100, 199)
	f.velocity = Vector2.ZERO
	await frames(20)
	Input.action_press("p1_up")
	await frames(8)
	check("P1 humano: W también salta", f.velocity.y < -200.0 or f.global_position.y < 190.0, "vy=%.0f" % f.velocity.y)
	Input.action_release("p1_up")
	await frames(60)
	# W + F a la vez = ataque hacia arriba (no salta)
	Input.action_press("p1_up")
	Input.action_press("p1_attack")
	await frames(3)
	check("P1 humano: W+F = ataque arriba sin saltar", _attack_name(f) == "utilt" and f.is_on_floor(), _attack_name(f))
	Input.action_release("p1_up")
	Input.action_release("p1_attack")
	await frames(60)


func test_menu() -> void:
	if stage:
		stage.queue_free()
		stage = null
		await frames(2)
	Game.players[0]["char"] = "ilunna"
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await frames(5)
	var ev := InputEventAction.new()
	ev.action = "ui_start"
	ev.pressed = true
	menu._unhandled_input(ev)
	check("menú: título -> principal", menu._screen == 1)
	var down := InputEventAction.new()
	down.action = "p1_down"
	down.pressed = true
	menu._unhandled_input(down)
	menu._unhandled_input(ev)
	check("menú: Caos de Cartas -> luchadores", menu._screen == 2 and Game.mode == "cards")
	var right := InputEventAction.new()
	right.action = "p1_right"
	right.pressed = true
	menu._unhandled_input(right)
	check("menú: P1 cambia de personaje", Game.players[0]["char"] == CharacterData.ORDER[1])
	menu._unhandled_input(ev)
	check("menú: luchadores -> escenario", menu._screen == 3)
	Game.mode = "classic"
	menu.queue_free()
	await frames(2)


func test_cpu_matches() -> void:
	var combos := [["lamont", "panadero", "pradera", 0], ["schizov", "ilunna", "cosmos", 1],
		["abnielito", "lamont", "ciudad", 2], ["panadero", "schizov", "volcan", 1], ["ilunna", "abnielito", "bosque", 2],
		["schizov", "lamont", "nieve", 1]]
	for c in combos:
		if stage:
			stage.queue_free()
			await frames(2)
		Game.players = [{"char": c[0], "cpu": true, "level": c[3]}, {"char": c[1], "cpu": true, "level": c[3]}]
		Game.match_setup = {}
		Game.mode = "classic"
		Game.stocks = 2
		Game.items_on = true
		stage = load(Game.stage_scene(c[2])).instantiate()
		add_child(stage)
		await frames(1)
		var n := 0
		while not stage.over and n < 60 * 240:
			await frames(60)
			n += 60
		var f1: Fighter = stage.fighters[0]
		var f2: Fighter = stage.fighters[1]
		print("   CPU %s vs %s en %s (nivel %d): terminó=%s en %ds · parries %d/%d" % [
			c[0], c[1], c[2], c[3], stage.over, n / 60, f1.parries, f2.parries])
		check("partida CPU en %s termina" % c[2], stage.over)
		await frames(240)
		check("resultados (%s)" % c[2], stage.has_node("ResultsScreen"))


func test_training() -> void:
	if stage:
		stage.queue_free()
		await frames(2)
	Engine.time_scale = 1.0
	Game.players = [{"char": "ilunna", "cpu": true, "level": 1}, {"char": "iluna", "cpu": true, "level": 1}]
	Game.match_setup = {}
	Game.mode = "training"
	stage = load(Game.stage_scene("pradera")).instantiate()
	add_child(stage)
	await frames(200)
	p1 = stage.fighters[0]
	p2 = stage.fighters[1]
	p1.brain = ScriptBrain.new()
	check("entrenamiento: ILUNA es el muñeco", p2.char_id == "iluna" and p2.get("behavior") == "quieto")
	check("entrenamiento: panel de combos", stage._training != null)
	place(p1, Vector2(-120, 199), p2, Vector2(-70, 199))
	p1.facing = 1
	await frames(5)
	for i in 3:
		await press(p1, func(f): f.in_attack_pressed = true)
		await frames(7)
	await frames(30)
	check("entrenamiento: cuenta el combo", stage._training.best[0] >= 2 or stage._training.hits >= 2,
		"golpes=%d mejor=%s" % [stage._training.hits, stage._training.best])
	p2.global_position = Vector2(0, 2000)
	await frames(120)
	check("entrenamiento: vidas infinitas (reaparece)", p2.stocks > 90 and p2.is_alive() and not stage.over)
	Game.mode = "classic"


func test_final_blow() -> void:
	await setup_stage("panadero", "ilunna")
	p1.stocks = 1
	p2.stocks = 1
	place(p1, Vector2(-100, 199), p2, Vector2(-40, 199))
	p1.facing = 1
	p2.percent = 220.0
	await frames(3)
	p1._start_move(p1.moves["smash"])
	var slow := false
	for i in 120:
		await frames(1)
		if Engine.time_scale < 0.5:
			slow = true
	check("golpe final: cámara lenta épica", stage._final_done and slow)
	await frames(400)
	check("golpe final: la partida termina", stage.over)
