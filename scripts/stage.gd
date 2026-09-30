extends Node2D
## Escenario (sirve para todos los mapas): crea a los luchadores, vigila la zona de KO,
## maneja vidas, reaparición, objetos que caen del cielo y la pantalla de victoria.
## Cada mapa es una escena en scenes/stages/ con este script.

## Si un luchador sale de este rectángulo, pierde una vida.
@export var blast_zone := Rect2(-1050, -900, 2100, 1800)
## Tiempo entre objetos (segundos, mínimo y máximo)
@export var item_interval := Vector2(9, 15)

var fighters: Array[Fighter] = []
var over := false
var winner: Fighter = null
var stage_info := {}

var _banner: Label
var _flash: ColorRect
var _item_timer := 7.0
var _started := false


func _ready() -> void:
	stage_info = _build_stage_info()
	if Game.preview_mode:
		return
	var spawns := [$Spawn1.position, $Spawn2.position, $Spawn3.position, $Spawn4.position]
	var setup_chars: Array = Game.match_setup.get("chars", [])
	for i in Game.players.size():
		var cfg: Dictionary = Game.players[i]
		var cid: String = cfg["char"]
		if cid == "random":
			cid = setup_chars[i] if i < setup_chars.size() else CharacterData.ORDER.pick_random()
		var script: Script = load(CharacterData.get_data(cid)["script"])
		var f: Fighter = script.new()
		f.player_id = i + 1
		f.char_id = cid
		f.is_cpu = cfg["cpu"]
		f.cpu_level = cfg.get("level", 1)
		f.stocks = Game.stocks
		f.stage_info = stage_info
		f.position = spawns[i]
		add_child(f)
		f.facing = 1 if spawns[i].x < 0 else -1
		f.died.connect(_on_fighter_died)
		f.hit_landed.connect(_on_hit_landed)
		f.ult_used.connect(_on_ult_used)
		fighters.append(f)

	$HUD.setup(fighters)
	_make_overlays()
	_intro()


## Info del escenario que usan los luchadores y el CPU (centro, suelo, bordes para colgarse).
func _build_stage_info() -> Dictionary:
	var ground: Node2D = $Platforms/MainGround
	var ledges := []
	for p in $Platforms.get_children():
		if p is Platform and p.ground and not p.one_way:
			ledges.append({"pos": p.position, "side": -1})
			ledges.append({"pos": p.position + Vector2(p.size.x, 0), "side": 1})
	return {"half_width": ground.size.x / 2.0, "ground_y": ground.position.y, "ledges": ledges}


func _make_overlays() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)
	_banner = UI.label("", 120, Color.WHITE, true, 22)
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.pivot_offset = Vector2(640, 360)
	layer.add_child(_banner)


func _show_banner(text: String, color := Color.WHITE) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.scale = Vector2(1.6, 1.6)
	_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _intro() -> void:
	for f in fighters:
		f.set_physics_process(false)
	for text in ["3", "2", "1"]:
		_show_banner(text)
		Game.play_sfx("select")
		await get_tree().create_timer(0.6).timeout
	_show_banner("¡YA!", UI.ACCENT)
	Game.play_sfx("go")
	for f in fighters:
		f.set_physics_process(true)
	_started = true
	await get_tree().create_timer(0.7).timeout
	if not over:
		var tw := create_tween()
		tw.tween_property(_banner, "modulate:a", 0.0, 0.25)


func _physics_process(delta: float) -> void:
	if over or not _started or Game.preview_mode:
		return
	for f in fighters:
		if f.is_alive() and f.state != Fighter.State.VICTORY and not blast_zone.has_point(f.global_position):
			_ko_effect(f)
			if f.last_hit_by and is_instance_valid(f.last_hit_by):
				f.last_hit_by.kos += 1
			f.kill()
	if Game.items_on:
		_item_timer -= delta
		if _item_timer <= 0.0:
			_item_timer = randf_range(item_interval.x, item_interval.y)
			if get_tree().get_nodes_in_group("items").size() < 2:
				spawn_item()


func spawn_item(kind := "") -> Item:
	var it := Item.new()
	it.kind = kind if kind != "" else ["bat", "bow"].pick_random()
	var hw: float = stage_info["half_width"]
	it.position = Vector2(randf_range(-hw + 80.0, hw - 80.0), -420.0)
	add_child(it)
	Game.play_sfx("item_spawn", -4.0)
	return it


func _ko_effect(f: Fighter) -> void:
	var p := f.global_position
	p.x = clampf(p.x, blast_zone.position.x, blast_zone.end.x)
	p.y = clampf(p.y, blast_zone.position.y, blast_zone.end.y)
	Effects.spark(self, p, 3.0, f.data["color"])
	Effects.ring(self, p, f.data["color"], 200.0)
	$GameCamera.add_shake(28.0)
	Engine.time_scale = 0.35
	get_tree().create_timer(0.35, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func _on_hit_landed(strength: float) -> void:
	$GameCamera.add_shake(clampf(strength * 0.6, 1.0, 30.0))


func _on_ult_used(f: Fighter) -> void:
	_flash.color = Color(f.data["color"].r, f.data["color"].g, f.data["color"].b, 0.45)
	var tw := create_tween()
	tw.tween_property(_flash, "color:a", 0.0, 0.5)
	$GameCamera.add_shake(12.0)


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
	_show_banner("¡JUEGO!", Color.WHITE)
	Game.play_sfx("hit_strong")
	Engine.time_scale = 0.3
	await get_tree().create_timer(1.1, true, false, true).timeout
	Engine.time_scale = 1.0
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 0.0, 0.3)
	for it in get_tree().get_nodes_in_group("items"):
		it.queue_free()
	if winner:
		winner.celebrate()
		$GameCamera.focus = winner
		Game.play_sfx("cheer", -4.0)
	await get_tree().create_timer(1.6).timeout
	$HUD.visible = false
	var results := ResultsScreen.new()
	results.fighters = fighters
	results.winner = winner
	results.name = "ResultsScreen"
	add_child(results)
	Game.play_sfx("fanfare")


func _unhandled_input(event: InputEvent) -> void:
	if not over or not has_node("ResultsScreen"):
		return
	if event.is_action_pressed("ui_start"):
		Game.rematch()
	elif event.is_action_pressed("ui_back"):
		Game.goto_menu()
