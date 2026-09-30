extends Node
## Prueba automática (sin ventana): simula peleas para comprobar que todo funciona.
## Correr:  godot --headless --fixed-fps 60 --path . res://tests/sim_test.tscn

class ScriptBrain extends CpuBrain:
	var script_fn: Callable
	func think(f: Fighter, delta: float) -> void:
		f.in_move = 0.0
		f.in_up = false
		f.in_down = false
		f.in_jump_held = false
		f.in_shield = false
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


func setup_stage(c1 := "rojo", c2 := "azul") -> void:
	if stage:
		stage.queue_free()
		await frames(2)
	Game.players = [{"char": c1, "cpu": true}, {"char": c2, "cpu": true}]
	stage = load("res://scenes/stage.tscn").instantiate()
	add_child(stage)
	await frames(1)
	p1 = stage.fighters[0]
	p2 = stage.fighters[1]
	for f in [p1, p2]:
		f.brain = ScriptBrain.new()
	await frames(200)  # cuenta regresiva + caer al suelo


func press_attack(f: Fighter, up := false, down := false) -> void:
	f.brain.script_fn = func(ff):
		ff.in_attack_pressed = true
		ff.in_up = up
		ff.in_down = down
	await frames(1)
	f.brain.script_fn = Callable()


func _ready() -> void:
	await test_basic()
	await test_combat()
	await test_ko_thresholds()
	await test_special()
	await test_platform_and_jump()
	await test_human_input()
	await test_cpu_match()
	print("=== RESULTADO: %s ===" % ("TODO BIEN" if fails == 0 else "%d FALLOS" % fails))
	get_tree().quit(fails)


func test_basic() -> void:
	await setup_stage()
	check("p1 en el suelo", p1.is_on_floor(), "y=%.1f" % p1.global_position.y)
	check("p2 en el suelo", p2.is_on_floor(), "y=%.1f" % p2.global_position.y)
	# correr a la derecha
	var x0 := p1.global_position.x
	p1.brain.script_fn = func(f): f.in_move = 1.0
	await frames(30)
	check("p1 corre", p1.global_position.x > x0 + 80.0, "dx=%.1f" % (p1.global_position.x - x0))
	p1.brain.script_fn = Callable()
	await frames(30)
	# salto
	p1.brain.script_fn = func(f):
		f.in_jump_pressed = true
		f.in_jump_held = true
	await frames(1)
	p1.brain.script_fn = func(f): f.in_jump_held = true
	var min_y := 1e9
	for i in 50:
		await frames(1)
		min_y = minf(min_y, p1.global_position.y)
	print("   altura salto completo: %.1f" % (199.0 - min_y))
	check("p1 salta", min_y < 199.0 - 100.0)
	p1.brain.script_fn = Callable()
	await frames(90)
	check("p1 aterriza", p1.is_on_floor())


func recover(f: Fighter) -> void:
	# el rival intenta volver al escenario (como haría una persona)
	var pos := f.global_position
	if absf(pos.x) > 420.0 or pos.y > 190.0 and not f.is_on_floor():
		f.in_move = -signf(pos.x) if absf(pos.x) > 380.0 else 0.0
		if f.state == Fighter.State.NORMAL and f.air_jumps_left > 0 and f.velocity.y > 0.0 and pos.y > 120.0:
			f.in_jump_pressed = true
			f.in_jump_held = true
		f.in_jump_held = f.velocity.y < 0.0


func place(a: Fighter, pos: Vector2, b: Fighter, pos_b: Vector2) -> void:
	a.global_position = pos
	b.global_position = pos_b
	a.velocity = Vector2.ZERO
	b.velocity = Vector2.ZERO


func test_combat() -> void:
	await setup_stage()
	place(p1, Vector2(0, 199), p2, Vector2(50, 199))
	await frames(10)
	p1.facing = 1
	var before := p2.percent
	press_attack(p1)
	await frames(30)
	check("ataque conecta", p2.percent > before, "p2=%.1f%%" % p2.percent)
	check("p2 en hitstun o volando", p2.state == Fighter.State.HITSTUN or p2.velocity.length() > 10.0)
	await frames(120)
	# escudo
	place(p1, Vector2(-100, 199), p2, Vector2(-50, 199))
	await frames(10)
	var pc := p2.percent
	p2.brain.script_fn = func(f): f.in_shield = true
	await frames(10)
	check("p2 en escudo", p2.state == Fighter.State.SHIELD)
	p1.facing = 1
	press_attack(p1)
	await frames(30)
	check("escudo bloquea daño", is_equal_approx(p2.percent, pc), "%.1f" % p2.percent)
	p2.brain.script_fn = Callable()


func ko_test(attacker_id: String, move: String, victim_pos: Vector2, start_pct: float, target_id := "azul") -> bool:
	# devuelve true si el golpe saca al rival del escenario
	await setup_stage(attacker_id, target_id)
	var up := move == "up"
	var down := move == "down"
	var apos := victim_pos + Vector2(-50, 0)
	place(p1, apos, p2, victim_pos)
	p1.facing = 1
	p2.percent = start_pct
	await frames(3)
	var killed := false
	p2.died.connect(func(_f): killed = true)
	p2.brain.script_fn = recover
	press_attack(p1, up, down)
	await frames(240)
	return killed or p2.stocks < 3


func test_ko_thresholds() -> void:
	# medir a qué % muere cada personaje con golpes horizontales y hacia arriba
	for target in ["rojo", "azul", "verde"]:
		var res := {}
		for spec in [["neutral", Vector2(0, 199)], ["neutral", Vector2(380, 199)], ["up", Vector2(0, 199)]]:
			var found := -1
			for pct in range(0, 400, 10):
				if await ko_test("rojo", spec[0], spec[1], float(pct), target):
					found = pct
					break
			res["%s@x%d" % [spec[0], spec[1].x]] = found
		print("   KO de rojo contra %s -> %s" % [target, res])


func test_special() -> void:
	await setup_stage()
	place(p1, Vector2(-300, 199), p2, Vector2(250, 199))
	await frames(10)
	p1.facing = 1
	var pc := p2.percent
	p1.brain.script_fn = func(f): f.in_special_pressed = true
	await frames(1)
	p1.brain.script_fn = Callable()
	await frames(120)
	check("proyectil conecta", p2.percent > pc, "p2=%.1f%%" % p2.percent)


func test_platform_and_jump() -> void:
	await setup_stage()
	# subir a la plataforma izquierda (x -330..-130, y 68) con salto
	place(p1, Vector2(-230, 199), p2, Vector2(300, 199))
	await frames(10)
	p1.brain.script_fn = func(f):
		f.in_jump_pressed = true
		f.in_jump_held = true
	await frames(1)
	p1.brain.script_fn = func(f): f.in_jump_held = true
	await frames(40)
	p1.brain.script_fn = func(f):
		f.in_jump_pressed = f.air_jumps_left > 0 and f.velocity.y > 0.0
		f.in_jump_held = true
	await frames(60)
	p1.brain.script_fn = Callable()
	await frames(30)
	print("   p1 y tras doble salto: %.1f floor=%s" % [p1.global_position.y, p1.is_on_floor()])
	check("sube a la plataforma", p1.global_position.y < 100.0 and p1.is_on_floor())
	# bajar con abajo
	p1.brain.script_fn = func(f):
		f.in_down = true
		f.in_down_pressed = true
	await frames(1)
	p1.brain.script_fn = func(f): f.in_down = true
	await frames(40)
	p1.brain.script_fn = Callable()
	await frames(20)
	check("atraviesa plataforma hacia abajo", p1.global_position.y > 150.0, "y=%.1f" % p1.global_position.y)


func test_cpu_match() -> void:
	# dos CPUs reales peleando: debe terminar con un ganador
	if stage:
		stage.queue_free()
		await frames(2)
	Game.players = [{"char": "rojo", "cpu": true}, {"char": "verde", "cpu": true}]
	Game.stocks = 2
	stage = load("res://scenes/stage.tscn").instantiate()
	add_child(stage)
	await frames(1)
	var n := 0
	while not stage.over and n < 60 * 240:
		await frames(60)
		n += 60
	var f1: Fighter = stage.fighters[0]
	var f2: Fighter = stage.fighters[1]
	print("   CPU vs CPU: terminó=%s tiempo=%ds  rojo(vidas %d, %d%%)  verde(vidas %d, %d%%)" % [
		stage.over, n / 60, f1.stocks, f1.percent, f2.stocks, f2.percent])
	check("la partida CPU vs CPU termina", stage.over)


func test_human_input() -> void:
	# P1 humano: simula pulsar teclas reales (acciones de Input)
	if stage:
		stage.queue_free()
		await frames(2)
	Game.players = [{"char": "rojo", "cpu": false}, {"char": "azul", "cpu": true}]
	stage = load("res://scenes/stage.tscn").instantiate()
	add_child(stage)
	await frames(200)
	var f: Fighter = stage.fighters[0]
	stage.fighters[1].brain = ScriptBrain.new()
	var x0 := f.global_position.x
	Input.action_press("p1_right")
	await frames(30)
	Input.action_release("p1_right")
	check("P1 humano se mueve con teclado", f.global_position.x > x0 + 50.0)
	Input.action_press("p1_jump")
	await frames(3)
	check("P1 humano salta", f.velocity.y < 0.0 or not f.is_on_floor())
	Input.action_release("p1_jump")
