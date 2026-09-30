extends Node2D
## Escenario (sirve para todos los mapas): crea a los luchadores, vigila la zona de KO,
## maneja vidas, reaparición, objetos, el modo Caos de Cartas y la pantalla de victoria.
## Cada mapa es una escena en scenes/stages/ con este script.

@export var stage_id := "pradera"
## Si un luchador sale de este rectángulo, pierde una vida.
@export var blast_zone := Rect2(-1050, -900, 2100, 1800)
## Tiempo entre objetos (segundos, mínimo y máximo)
@export var item_interval := Vector2(8, 13)

var fighters: Array[Fighter] = []
var over := false
var winner: Fighter = null
var stage_info := {}

var _banner: Label
var _flash: ColorRect
var _dim: ColorRect
var _item_timer := 6.0
var _started := false
var _picking := false
var _pick_queue := []


func _ready() -> void:
	stage_info = _build_stage_info()
	if Game.preview_mode:
		return
	var sd := Game.get_stage(stage_id)
	Game.play_music("chaos" if Game.mode == "cards" else sd["music"])
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
	for f in fighters:
		f.set_physics_process(false)
	if Game.mode == "cards":
		await get_tree().create_timer(0.4).timeout
		for f in fighters:
			_pick_queue.append([f, "inicio"])
		await _run_picks()
	_intro()


## Info del escenario que usan los luchadores y el CPU (centro, suelo, bordes para colgarse).
func _build_stage_info() -> Dictionary:
	var ground: Node2D = $Platforms/MainGround
	var ledges := []
	for p in $Platforms.get_children():
		if p is Platform and p.ground and not p.one_way:
			ledges.append({"pos": p.position, "side": -1})
			ledges.append({"pos": p.position + Vector2(p.size.x, 0), "side": 1})
	return {"half_width": ground.size.x / 2.0, "ground_y": ground.position.y, "ledges": ledges,
		"center_x": ground.position.x + ground.size.x / 2.0}


func _make_overlays() -> void:
	var back := CanvasLayer.new()
	back.layer = -5
	add_child(back)
	_dim = ColorRect.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.color = Color(0.02, 0.0, 0.06, 0.0)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(_dim)
	var layer := CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	_flash = ColorRect.new()
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)
	_banner = UI.label("", 130, Color.WHITE, true, 24)
	_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.pivot_offset = Vector2(640, 360)
	layer.add_child(_banner)


func _show_banner(text: String, color := Color.WHITE) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner.scale = Vector2(1.8, 1.8)
	_banner.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_banner, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _intro() -> void:
	for f in fighters:
		f.set_physics_process(false)
	for text in ["3", "2", "1"]:
		_show_banner(text)
		Game.play_sfx("countdown")
		await get_tree().create_timer(0.6).timeout
	_show_banner("¡YA!", UI.ACCENT)
	Game.play_sfx("go")
	flash(Color(1, 1, 1, 0.25), 0.3)
	for f in fighters:
		f.set_physics_process(true)
	_started = true
	await get_tree().create_timer(0.7).timeout
	if not over and not _picking:
		create_tween().tween_property(_banner, "modulate:a", 0.0, 0.25)


# ------------------------------------------------------------------
#  Efectos de pantalla (los usan las ultis)
# ------------------------------------------------------------------
func add_shake(amount: float) -> void:
	$GameCamera.add_shake(amount)


func flash(color: Color, duration := 0.4) -> void:
	_flash.color = color
	create_tween().tween_property(_flash, "color:a", 0.0, duration)


## Oscurece el fondo durante `duration` segundos.
func dim(duration: float, amount := 0.6) -> void:
	var tw := create_tween()
	tw.tween_property(_dim, "color:a", amount, 0.25)
	tw.tween_interval(maxf(0.0, duration - 0.5))
	tw.tween_property(_dim, "color:a", 0.0, 0.25)


func slowmo(duration: float, scale := 0.35) -> void:
	Engine.time_scale = scale
	get_tree().create_timer(duration, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


# ------------------------------------------------------------------
#  Bucle
# ------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if over or not _started or Game.preview_mode:
		return
	for f in fighters:
		if f.is_alive() and f.state != Fighter.State.VICTORY and not blast_zone.has_point(f.global_position):
			_ko_effect(f)
			f.kill()
	if Game.items_on:
		_item_timer -= delta
		if _item_timer <= 0.0:
			_item_timer = randf_range(item_interval.x, item_interval.y)
			if get_tree().get_nodes_in_group("items").size() < 3:
				spawn_item()


func spawn_item(kind := "") -> Item:
	var it := Item.new()
	it.kind = kind if kind != "" else Item.random_kind()
	var hw: float = stage_info["half_width"]
	var cx: float = stage_info.get("center_x", 0.0)
	it.position = Vector2(cx + randf_range(-hw + 80.0, hw - 80.0), -420.0)
	add_child(it)
	Game.play_sfx("item_spawn", -4.0)
	Effects.burst(self, it.position + Vector2(0, 200), {"count": 12, "color": Color(1, 0.95, 0.6), "speed": 120.0,
		"life": 0.6, "size": 3.0, "star": true})
	return it


func _ko_effect(f: Fighter) -> void:
	var p := f.global_position
	p.x = clampf(p.x, blast_zone.position.x + 40.0, blast_zone.end.x - 40.0)
	p.y = clampf(p.y, blast_zone.position.y + 40.0, blast_zone.end.y - 40.0)
	var col: Color = f.data["color"]
	var inward := (Vector2(0, 100) - p).normalized()
	Effects.beam(self, p, 1 if inward.x >= 0.0 else -1, 900.0, 160.0, col, 0.8)
	Effects.explosion(self, p, 160.0, col)
	Effects.burst(self, p, {"count": 40, "color": col, "speed": 700.0, "life": 0.8, "size": 5.0, "streak": true,
		"angle": rad_to_deg(inward.angle()), "spread": 60.0})
	Game.play_sfx("ko")
	Game.play_sfx("explosion", -4.0)
	$GameCamera.add_shake(34.0)
	flash(Color(col.r, col.g, col.b, 0.35), 0.5)
	slowmo(0.4, 0.3)
	if f.last_hit_by and is_instance_valid(f.last_hit_by) and f.last_hit_by != f:
		f.last_hit_by.kos += 1
		if Game.mode == "cards" and f.last_hit_by.stocks > 0:
			_pick_queue.append([f.last_hit_by, "ko"])
			_run_picks_later()


func _run_picks_later() -> void:
	await get_tree().create_timer(0.9, true, false, true).timeout
	if not over:
		_run_picks()


## Muestra las pantallas de cartas pendientes, una por una, con el juego en pausa.
func _run_picks() -> void:
	if _picking:
		return
	_picking = true
	while not _pick_queue.is_empty() and not over:
		var entry: Array = _pick_queue.pop_front()
		var f: Fighter = entry[0]
		if not is_instance_valid(f):
			continue
		get_tree().paused = true
		Engine.time_scale = 1.0
		var picker := CardPicker.new()
		picker.fighter = f
		picker.reason = entry[1]
		picker.name = "CardPicker"
		add_child(picker)
		await picker.picked
		await get_tree().process_frame
	get_tree().paused = false
	_picking = false


func _on_hit_landed(strength: float) -> void:
	$GameCamera.add_shake(clampf(strength * 0.6, 1.0, 36.0))
	if strength > 9.0:
		flash(Color(1, 1, 1, clampf(strength / 60.0, 0.08, 0.3)), 0.2)


func _on_ult_used(f: Fighter) -> void:
	flash(Color(f.data["color"].r, f.data["color"].g, f.data["color"].b, 0.5), 0.6)
	$GameCamera.add_shake(14.0)
	$GameCamera.punch(0.25)
	dim(1.0, 0.45)


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
	_pick_queue.clear()
	winner = alive[0] if alive.size() == 1 else null
	_show_banner("¡JUEGO!", Color.WHITE)
	Game.play_sfx("hit_strong")
	Engine.time_scale = 0.3
	await get_tree().create_timer(1.1, true, false, true).timeout
	Engine.time_scale = 1.0
	get_tree().paused = false
	if has_node("CardPicker"):
		$CardPicker.queue_free()
	create_tween().tween_property(_banner, "modulate:a", 0.0, 0.3)
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
	Game.play_music("menu")


func _unhandled_input(event: InputEvent) -> void:
	if not over or not has_node("ResultsScreen"):
		return
	if event.is_action_pressed("ui_start"):
		Game.rematch()
	elif event.is_action_pressed("ui_back"):
		Game.goto_menu()


func _exit_tree() -> void:
	Engine.time_scale = 1.0
