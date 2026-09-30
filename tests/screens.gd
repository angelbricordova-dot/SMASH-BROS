extends Node
## Herramienta de desarrollo: saca capturas del menú y de una pelea (necesita ventana / xvfb).
##   godot --path . res://tests/screens.tscn -- --out=/ruta/carpeta

var out := "user://capturas"


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(out + "/" + name + ".png")
	print("captura ", name)


func wait(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	# --- menú
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await wait(30)
	await shot("01_titulo")
	menu._show(1)
	await wait(20)
	await shot("02_menu")
	Game.mode = "classic"
	menu._show(2)
	await wait(20)
	await shot("03_luchadores")
	menu._show(3)
	await wait(20)
	await shot("04_escenario")
	menu.queue_free()
	await wait(2)
	# --- pelea
	Game.players = [{"char": "lamont", "cpu": true, "level": 2}, {"char": "schizov", "cpu": true, "level": 2}]
	Game.match_setup = {}
	Game.items_on = false
	var stage: Node = load(Game.stage_scene("ciudad")).instantiate()
	add_child(stage)
	await wait(260)
	await shot("05_pelea")
	var p1: Fighter = stage.fighters[0]
	var p2: Fighter = stage.fighters[1]
	p1.is_cpu = false
	p2.is_cpu = false
	p1.global_position = Vector2(-80, stage.stage_info["ground_y"] - 1)
	p2.global_position = Vector2(140, stage.stage_info["ground_y"] - 1)
	await wait(30)
	Input.action_press("p1_shield")
	await wait(20)
	p1.shield_hp = p1.max_shield() * 0.45
	await wait(3)
	await shot("06_escudo")
	Input.action_release("p1_shield")
	p1.is_cpu = true
	p2.is_cpu = true
	await wait(120)
	await shot("07_pelea2")
	for f in [p1, p2]:
		f.ult_meter = Fighter.ULT_MAX
	await wait(90)
	await shot("08_ultis")
	stage.queue_free()
	await wait(2)
	# --- todos los personajes juntos
	for pair in [["ilunna", "panadero"], ["abnielito", "iluna"]]:
		Game.players = [{"char": pair[0], "cpu": true, "level": 1}, {"char": pair[1], "cpu": true, "level": 1}]
		Game.mode = "training" if pair[1] == "iluna" else "classic"
		stage = load(Game.stage_scene("pradera")).instantiate()
		add_child(stage)
		await wait(240)
		await shot("09_%s_vs_%s" % pair)
		stage.queue_free()
		await wait(2)
	Game.mode = "classic"
	# --- golpe final
	Game.players = [{"char": "panadero", "cpu": true, "level": 1}, {"char": "ilunna", "cpu": true, "level": 1}]
	stage = load(Game.stage_scene("volcan")).instantiate()
	add_child(stage)
	await wait(220)
	p1 = stage.fighters[0]
	p2 = stage.fighters[1]
	p1.brain = CpuBrain.new()
	p1.is_cpu = false
	p2.is_cpu = false
	p1.stocks = 1
	p2.stocks = 1
	p1.global_position = Vector2(-60, stage.stage_info["ground_y"] - 1)
	p2.global_position = Vector2(0, stage.stage_info["ground_y"] - 1)
	p1.facing = 1
	p2.percent = 230.0
	await wait(3)
	p1._start_move(p1.moves["smash"])
	for i in 60:
		await wait(1)
		if stage._final_done:
			break
	await wait(8)
	await shot("10_golpe_final")
	await wait(50)
	await shot("11_golpe_final_lento")
	get_tree().quit()
