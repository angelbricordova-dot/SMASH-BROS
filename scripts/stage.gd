extends Node2D
## El escenario: crea a los luchadores, vigila los límites (zona de KO),
## maneja las vidas, la reaparición y quién gana.

const FIGHTER_SCENE := preload("res://scenes/fighter.tscn")

## Si un luchador sale de este rectángulo, pierde una vida.
@export var blast_zone := Rect2(-1000, -850, 2000, 1750)

var fighters: Array[Fighter] = []
var over := false
var winner: Fighter = null

var _banner: Label
var _sub_banner: Label


func _ready() -> void:
	var spawns := [$Spawn1.position, $Spawn2.position, $Spawn3.position, $Spawn4.position]
	var ground: Node = $Platforms/MainGround
	var info := {"half_width": ground.size.x / 2.0, "ground_y": ground.position.y}

	for i in Game.players.size():
		var cfg: Dictionary = Game.players[i]
		var f: Fighter = FIGHTER_SCENE.instantiate()
		f.player_id = i + 1
		f.char_id = cfg["char"]
		f.is_cpu = cfg["cpu"]
		f.stocks = Game.stocks
		f.stage_info = info
		f.position = spawns[i]
		add_child(f)
		f.facing = 1 if spawns[i].x < 0 else -1
		f.died.connect(_on_fighter_died)
		f.hit_landed.connect(_on_hit_landed)
		fighters.append(f)

	$HUD.setup(fighters)
	_make_banner()
	_intro()


func _make_banner() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 96)
	_banner.add_theme_constant_override("outline_size", 16)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_banner)
	_sub_banner = Label.new()
	_sub_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sub_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sub_banner.position = Vector2(0, 110)
	_sub_banner.add_theme_font_size_override("font_size", 28)
	_sub_banner.add_theme_constant_override("outline_size", 8)
	_sub_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	layer.add_child(_sub_banner)


func _intro() -> void:
	for f in fighters:
		f.set_physics_process(false)
	for text in ["3", "2", "1"]:
		_banner.text = text
		Game.play_sfx("select")
		await get_tree().create_timer(0.6).timeout
	_banner.text = "¡YA!"
	Game.play_sfx("start")
	for f in fighters:
		f.set_physics_process(true)
	await get_tree().create_timer(0.7).timeout
	if not over:
		_banner.text = ""


func _physics_process(_delta: float) -> void:
	if over:
		return
	for f in fighters:
		if f.is_alive() and not blast_zone.has_point(f.global_position):
			_ko_effect(f)
			f.kill()


func _ko_effect(f: Fighter) -> void:
	# Destello en el borde por donde salió volando
	var p := f.global_position
	p.x = clampf(p.x, blast_zone.position.x, blast_zone.end.x)
	p.y = clampf(p.y, blast_zone.position.y, blast_zone.end.y)
	Effects.spark(self, p, 3.0, f.data["color"])
	$GameCamera.add_shake(28.0)
	Engine.time_scale = 0.35
	get_tree().create_timer(0.35, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func _on_hit_landed(strength: float) -> void:
	$GameCamera.add_shake(clampf(strength * 0.6, 1.0, 14.0))


func _on_fighter_died(f: Fighter) -> void:
	if over:
		return
	if f.stocks > 0:
		await get_tree().create_timer(1.4).timeout
		if not over:
			f.respawn($RespawnPoint.position)
	else:
		_check_game_over()


func _check_game_over() -> void:
	var alive: Array[Fighter] = []
	for f in fighters:
		if f.stocks > 0:
			alive.append(f)
	if alive.size() > 1:
		return
	over = true
	winner = alive[0] if alive.size() == 1 else null
	await get_tree().create_timer(0.8).timeout
	Engine.time_scale = 1.0
	if winner:
		var who := "CPU" if winner.is_cpu else "P%d" % winner.player_id
		_banner.text = "¡GANA %s!" % who
		_banner.add_theme_color_override("font_color", winner.data["color"])
		winner.state = Fighter.State.NORMAL
		winner.sprite.play("idle")
	else:
		_banner.text = "¡EMPATE!"
	_sub_banner.text = "Enter: revancha     Esc: menú"
	Game.play_sfx("start")


func _unhandled_input(event: InputEvent) -> void:
	if not over:
		return
	if event.is_action_pressed("ui_start"):
		Game.goto_stage()
	elif event.is_action_pressed("pause"):
		Game.goto_menu()
