extends Node
## Prueba automática (sin ventana): simula peleas para comprobar que todo funciona.
## Correr:  godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn

class ScriptBrain extends CpuBrain:
	var script_fn: Callable
	func think(f: Fighter, _delta: float) -> void:
		f.in_move = 0.0
		f.in_up = false
		f.in_down = false
		f.in_jump_held = false
		f.in_shield = false
		f.in_attack_held = false
		if script_fn.is_valid():
			script_fn.call(f)

var stage: Node
var p1: Fighter
var p2: Fighter
var fails := 0


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func check(name: String, ok: bool, extra := "") -> void:
	print(("PASS  " if ok else "FAIL  ") + name + "  " + extra)
	if not ok:
		fails += 1


func setup_stage(c1 := "rojo", c2 := "azul", stage_id := "pradera", items := false) -> void:
	if stage:
		stage.queue_free()
		await frames(2)
	Engine.time_scale = 1.0
	Game.players = [{"char": c1, "cpu": true, "level": 1}, {"char": c2, "cpu": true, "level": 1}]
	Game.match_setup = {}
	Game.items_on = items
	Game.stocks = 3
	stage = load(Game.get_stage(stage_id)["scene"]).instantiate()
	add_child(stage)
	await frames(1)
	p1 = stage.fighters[0]
	p2 = stage.fighters[1]
	for f in [p1, p2]:
		f.brain = ScriptBrain.new()
	await frames(200)  # cuenta regresiva + caer al suelo


func press(f: Fighter, fn: Callable) -> void:
	f.brain.script_fn = fn
	await frames(1)
	f.brain.script_fn = Callable()


func place(a: Fighter, pos: Vector2, b: Fighter, pos_b: Vector2) -> void:
	a.global_position = pos
	b.global_position = pos_b
	a.velocity = Vector2.ZERO
	b.velocity = Vector2.ZERO


func recover(f: Fighter) -> void:
	# el rival intenta volver al escenario (como haría una persona)
	var pos := f.global_position
	if absf(pos.x) > 420.0 or pos.y > 190.0 and not f.is_on_floor():
		f.in_move = -signf(pos.x) if absf(pos.x) > 380.0 else 0.0
		if f.state == Fighter.State.NORMAL and f.air_jumps_left > 0 and f.velocity.y > 0.0 and pos.y > 120.0:
			f.in_jump_pressed = true
			f.in_jump_held = true
		f.in_jump_held = f.velocity.y < 0.0


func _ready() -> void:
	await test_movement()
	await test_combat_shield_parry()
	await test_crouch_taunt()
	await test_ledge()
	await test_specials_and_ults()
	await test_items()
	await test_ko_thresholds()
	await test_human_input()
	await test_menu()
	await test_cpu_matches()
	print("=== RESULTADO: %s ===" % ("TODO BIEN" if fails == 0 else "%d FALLOS" % fails))
	get_tree().quit(fails)


func test_movement() -> void:
	await setup_stage()
	check("p1 en el suelo", p1.is_on_floor(), "y=%.1f" % p1.global_position.y)
	# caminar
	var x0 := p1.global_position.x
	p1.brain.script_fn = func(f): f.in_move = 1.0
	await frames(30)
	var walk := p1.global_position.x - x0
	p1.brain.script_fn = Callable()
	await frames(30)
	# correr (doble toque)
	x0 = p1.global_position.x
	await press(p1, func(f): f.in_right_pressed = true)
	await frames(3)
	p1.brain.script_fn = func(f):
		f.in_move = 1.0
	await press(p1, func(f):
		f.in_move = 1.0
		f.in_right_pressed = true)
	p1.brain.script_fn = func(f): f.in_move = 1.0
	await frames(29)
	var run := p1.global_position.x - x0
	p1.brain.script_fn = Callable()
	check("correr es más rápido que caminar", run > walk * 1.4, "caminar=%.0f correr=%.0f" % [walk, run])
	await frames(40)
	# salto + doble salto
	await press(p1, func(f):
		f.in_jump_pressed = true
		f.in_jump_held = true)
	p1.brain.script_fn = func(f): f.in_jump_held = true
	await frames(20)
	var jumps_before := p1.air_jumps_left
	await press(p1, func(f):
		f.in_jump_pressed = true
		f.in_jump_held = true)
	check("doble salto", jumps_before == 1 and p1.air_jumps_left == 0 and p1.velocity.y < 0.0)
	p1.brain.script_fn = Callable()
	await frames(90)
	check("aterriza", p1.is_on_floor())


func test_combat_shield_parry() -> void:
	await setup_stage()
	place(p1, Vector2(0, 199), p2, Vector2(50, 199))
	await frames(10)
	p1.facing = 1
	await press(p1, func(f): f.in_attack_pressed = true)
	await frames(30)
	check("ataque conecta", p2.percent > 0.0, "p2=%.1f%%" % p2.percent)
	check("atacante gana barra de ulti", p1.ult_meter > 0.0, "%.1f" % p1.ult_meter)
	await frames(120)
	# escudo
	place(p1, Vector2(-100, 199), p2, Vector2(-50, 199))
	await frames(10)
	var pc := p2.percent
	p2.brain.script_fn = func(f): f.in_shield = true
	await frames(10)
	check("p2 en escudo", p2.state == Fighter.State.SHIELD)
	var hp := p2.shield_hp
	p1.facing = 1
	await press(p1, func(f): f.in_attack_pressed = true)
	await frames(30)
	check("escudo bloquea daño y se agrieta", is_equal_approx(p2.percent, pc) and p2.shield_hp < hp - 5.0,
		"hp %.0f -> %.0f" % [hp, p2.shield_hp])
	p2.brain.script_fn = Callable()
	await frames(60)
	# parry: p1 ataca de izquierda a derecha -> p2 presiona IZQUIERDA (hacia p1) justo antes del golpe
	place(p1, Vector2(-100, 199), p2, Vector2(-50, 199))
	p2.ult_meter = 0.0
	await frames(10)
	pc = p2.percent
	p1.facing = 1
	var startup: float = p1.data["moves"]["neutral"]["startup"]
	await press(p1, func(f): f.in_attack_pressed = true)
	await frames(int(startup * 60.0) - 3)
	await press(p2, func(f): f.in_left_pressed = true)
	await frames(20)
	check("PARRY evita el daño", is_equal_approx(p2.percent, pc), "%.1f%%" % p2.percent)
	check("PARRY llena la barra", p2.ult_meter >= Fighter.PARRY_METER - 0.1, "%.0f" % p2.ult_meter)
	check("PARRY cuenta", p2.parries == 1)
	await frames(60)
	# parry con la dirección equivocada no funciona
	place(p1, Vector2(-100, 199), p2, Vector2(-50, 199))
	await frames(40)
	pc = p2.percent
	await press(p1, func(f): f.in_attack_pressed = true)
	await frames(int(startup * 60.0) - 3)
	await press(p2, func(f): f.in_right_pressed = true)
	await frames(20)
	check("dirección equivocada NO hace parry", p2.percent > pc)


func test_crouch_taunt() -> void:
	await setup_stage()
	p1.brain.script_fn = func(f): f.in_down = true
	await frames(10)
	check("agacharse", p1.crouching and p1.hurtbox().size.y < Fighter.HURT_SIZE.y)
	p1.brain.script_fn = Callable()
	await frames(5)
	await press(p1, func(f): f.in_taunt_pressed = true)
	await frames(5)
	check("provocar (taunt)", p1.state == Fighter.State.ACTION and p1.action == "taunt")
	await frames(70)
	check("taunt termina", p1.state == Fighter.State.NORMAL)


func test_ledge() -> void:
	await setup_stage()
	# soltar a p1 justo afuera del borde derecho
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


func test_specials_and_ults() -> void:
	for cid in CharacterData.ORDER:
		await setup_stage(cid, "rojo")
		# especial normal
		place(p1, Vector2(-300, 199), p2, Vector2(-120, 199))
		p1.facing = 1
		await frames(5)
		await press(p1, func(f): f.in_special_pressed = true)
		await frames(90)
		check("%s: especial golpea" % cid, p2.percent > 0.0, "%.0f%%" % p2.percent)
		await frames(60)
		# recuperación (arriba + especial) en el aire
		place(p1, Vector2(-100, 100), p2, Vector2(300, 199))
		p1.air_jumps_left = 0
		await frames(2)
		var y0 := p1.global_position.y
		await press(p1, func(f):
			f.in_up = true
			f.in_special_pressed = true)
		var min_y := y0
		for i in 40:
			await frames(1)
			min_y = minf(min_y, p1.global_position.y)
		check("%s: recuperación sube" % cid, min_y < y0 - 120.0, "sube %.0f" % (y0 - min_y))
		await frames(10)
		check("%s: queda indefenso tras recuperación" % cid, p1.helpless or p1.is_on_floor())
		await frames(90)
		# ulti
		place(p1, Vector2(-150, 199), p2, Vector2(-40, 199))
		p1.facing = 1
		p2.percent = 0.0
		p1.ult_meter = Fighter.ULT_MAX
		await frames(3)
		await press(p1, func(f): f.in_ult_pressed = true)
		await frames(170)
		check("%s: ULTI golpea" % cid, p2.percent >= 20.0, "p2=%.0f%%" % p2.percent)
		check("%s: ULTI gasta la barra" % cid, p1.ult_meter < 20.0, "%.0f" % p1.ult_meter)


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
	p2.percent = 80.0
	p1.facing = 1
	await frames(3)
	await press(p1, func(f): f.in_attack_pressed = true)
	await frames(200)
	check("batazo a 80% saca del escenario (home run)", p2.stocks < 3, "p2 pos=%s" % p2.global_position)
	await frames(120)
	# arco
	await setup_stage()
	place(p1, Vector2(-300, 199), p2, Vector2(100, 199))
	var bow: Item = stage.spawn_item("bow")
	bow.global_position = Vector2(-300, 150)
	await frames(40)
	await press(p1, func(f): f.in_attack_pressed = true)
	await frames(2)
	check("recoger arco", p1.held_item == "bow" and p1.item_ammo == 3)
	p1.facing = 1
	await frames(5)
	var pc := p2.percent
	p1.brain.script_fn = func(f):
		f.in_attack_pressed = true
		f.in_attack_held = true
	await frames(1)
	p1.brain.script_fn = func(f): f.in_attack_held = true
	await frames(50)
	p1.brain.script_fn = Callable()
	await frames(60)
	check("flecha cargada golpea", p2.percent > pc + 8.0, "p2=%.0f%%" % p2.percent)
	check("gasta una flecha", p1.item_ammo == 2)
	# lanzar objeto: escudo + ataque
	p1.brain.script_fn = func(f): f.in_shield = true
	await frames(5)
	p1.brain.script_fn = func(f):
		f.in_shield = true
		f.in_attack_pressed = true
	await frames(1)
	p1.brain.script_fn = Callable()
	await frames(2)
	check("lanzar objeto con escudo+ataque", p1.held_item == "")


func ko_test(move: String, victim_pos: Vector2, start_pct: float, target_id: String) -> bool:
	await setup_stage("rojo", target_id)
	place(p1, victim_pos + Vector2(-50, 0), p2, victim_pos)
	p1.facing = 1
	p2.percent = start_pct
	await frames(3)
	p2.brain.script_fn = recover
	var up := move == "up"
	await press(p1, func(f):
		f.in_attack_pressed = true
		f.in_up = up)
	await frames(240)
	return p2.stocks < 3


func test_ko_thresholds() -> void:
	for target in ["azul", "verde"]:
		var res := {}
		for spec in [["neutral", Vector2(0, 199)], ["up", Vector2(0, 199)]]:
			var found := -1
			for pct in range(60, 300, 20):
				if await ko_test(spec[0], spec[1], float(pct), target):
					found = pct
					break
			res[spec[0]] = found
		print("   KO de rojo contra %s -> %s" % [target, res])


func test_human_input() -> void:
	if stage:
		stage.queue_free()
		await frames(2)
	Game.players = [{"char": "rojo", "cpu": false, "level": 1}, {"char": "azul", "cpu": true, "level": 1}]
	Game.match_setup = {}
	stage = load(Game.get_stage("pradera")["scene"]).instantiate()
	add_child(stage)
	await frames(200)
	var f: Fighter = stage.fighters[0]
	stage.fighters[1].brain = ScriptBrain.new()
	# doble toque real con teclado -> correr
	Input.action_press("p1_right")
	await frames(2)
	Input.action_release("p1_right")
	await frames(3)
	Input.action_press("p1_right")
	await frames(5)
	check("P1 humano corre con doble toque", f.running, "vx=%.0f" % f.velocity.x)
	await frames(20)
	Input.action_release("p1_right")
	Input.action_press("p1_jump")
	await frames(3)
	check("P1 humano salta", f.velocity.y < 0.0 or not f.is_on_floor())
	Input.action_release("p1_jump")
	await frames(60)


func test_menu() -> void:
	if stage:
		stage.queue_free()
		stage = null
		await frames(2)
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await frames(5)
	var ev := InputEventAction.new()
	ev.action = "ui_start"
	ev.pressed = true
	menu._unhandled_input(ev)
	await frames(2)
	check("menú: título -> personajes", menu._screen == 1)
	var right := InputEventAction.new()
	right.action = "p1_right"
	right.pressed = true
	menu._unhandled_input(right)
	check("menú: P1 cambia de personaje", Game.players[0]["char"] == CharacterData.ORDER[1])
	menu._unhandled_input(ev)
	await frames(2)
	check("menú: personajes -> escenario", menu._screen == 2)
	menu.queue_free()
	await frames(2)


func test_cpu_matches() -> void:
	var combos := [["rojo", "verde", "pradera", 0], ["azul", "morado", "cosmos", 1], ["morado", "rojo", "ciudad", 2]]
	for c in combos:
		if stage:
			stage.queue_free()
			await frames(2)
		Game.players = [{"char": c[0], "cpu": true, "level": c[3]}, {"char": c[1], "cpu": true, "level": c[3]}]
		Game.match_setup = {}
		Game.stocks = 2
		Game.items_on = true
		stage = load(Game.get_stage(c[2])["scene"]).instantiate()
		add_child(stage)
		await frames(1)
		var n := 0
		while not stage.over and n < 60 * 240:
			await frames(60)
			n += 60
		var f1: Fighter = stage.fighters[0]
		var f2: Fighter = stage.fighters[1]
		print("   CPU %s vs %s en %s (nivel %d): terminó=%s en %ds · parries %d/%d · ultis usadas: %s" % [
			c[0], c[1], c[2], c[3], stage.over, n / 60, f1.parries, f2.parries, f1.ult_meter])
		check("partida CPU %s termina" % c[2], stage.over)
		await frames(240)
		check("pantalla de resultados aparece (%s)" % c[2], stage.has_node("ResultsScreen"))
