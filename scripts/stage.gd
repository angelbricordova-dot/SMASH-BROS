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
var _final_done := false
var _dim_target := -1.0
var _flash_rate := 0.0
var _training: TrainingPanel = null


func _ready() -> void:
	stage_info = _build_stage_info()
	if Game.preview_mode:
		return
	var sd := Game.get_stage(stage_id)
	Game.play_music(Game.battle_track(sd["id"]))
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
		f.stocks = 99 if Game.mode == "training" else Game.stocks
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
	if Game.mode == "training":
		_training = TrainingPanel.new()
		_training.stage = self
		var tl := CanvasLayer.new()
		tl.layer = 20
		add_child(tl)
		tl.add_child(_training)
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
	_flash_rate = color.a / maxf(duration, 0.01)


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
	if _training:
		_training.tick(delta)
	if Game.items_on and Game.mode != "training":
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
	if _final_done:
		# el KO que termina la partida: explosión el doble de grande
		Effects.explosion(self, p, 300.0, Color(1, 0.85, 0.4))
		Effects.beam(self, p, 1 if inward.x >= 0.0 else -1, 1600.0, 300.0, Color(1, 1, 1), 1.0)
		Game.play_sfx("final_hit", 0.0, 0.8)
		$GameCamera.add_shake(60.0)
	else:
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
	$GameCamera.add_shake(clampf(strength * 0.7, 1.5, 40.0))
	if strength > 6.0:
		$GameCamera.punch(clampf(strength / 90.0, 0.03, 0.14))
	if strength > 9.0:
		flash(Color(1, 1, 1, clampf(strength / 60.0, 0.08, 0.3)), 0.2)


## EL GOLPE FINAL: cuando un golpe va a quitarle la última vida al rival (y decide la partida),
## todo se congela, la cámara se acerca, el fondo se oscurece con líneas de velocidad y luego
## el rival sale volando en cámara lenta.
func final_blow(victim: Fighter, attacker: Fighter, pos: Vector2) -> void:
	if _final_done or over:
		return
	_final_done = true
	var col: Color = attacker.data["color"] if attacker else Color(1, 0.8, 0.3)
	var cam: Node = $GameCamera
	Engine.time_scale = 0.02
	Game.play_sfx("final_hit")
	Game.play_sfx("hit_strong", 2.0, 0.7)
	cam.focus_pos = pos
	cam.focus_zoom = 2.2
	cam.focus_speed = 3.0
	cam.add_shake(20.0)
	var fx := FinalBlowFx.new()
	fx.color = col
	fx.world_pos = pos
	fx.cam = cam
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	layer.add_child(fx)
	flash(Color(1, 1, 1, 0.8), 0.25)
	_dim_target = 0.88
	# los dos luchadores se dibujan por encima de los efectos (que se vea el golpe)
	for f in [victim, attacker]:
		if f and is_instance_valid(f):
			f.z_index = 16
	await get_tree().create_timer(0.6, true, false, true).timeout
	# cámara lenta siguiendo al que sale volando
	Engine.time_scale = 0.22
	cam.focus_pos = null
	cam.focus = victim
	cam.focus_zoom = 1.45
	cam.focus_speed = 1.4
	fx.release()
	await get_tree().create_timer(1.25, true, false, true).timeout
	_dim_target = 0.0
	if cam.focus == victim:
		cam.focus = null
	cam.focus_zoom = 1.7
	cam.focus_speed = 1.0
	if not over:
		Engine.time_scale = 1.0
	for f in [victim, attacker]:
		if f and is_instance_valid(f):
			f.z_index = 0
	await get_tree().create_timer(0.6, true, false, true).timeout
	layer.queue_free()
	_dim_target = -1.0


## Oscurecer el fondo en tiempo real (aunque el juego esté en cámara lenta).
func _process(delta: float) -> void:
	# (en tiempo real: funciona igual aunque el juego esté en cámara lenta)
	var real := delta / maxf(Engine.time_scale, 0.01)
	if _dim_target >= 0.0 and _dim:
		_dim.color.a = move_toward(_dim.color.a, _dim_target, real * 5.0)
	if _flash and _flash.color.a > 0.0:
		_flash.color.a = maxf(0.0, _flash.color.a - _flash_rate * real)


## Líneas de velocidad y bordes negros del golpe final (estilo anime).
class FinalBlowFx extends Control:
	var color := Color.WHITE
	var world_pos := Vector2.ZERO
	var cam: Node = null
	var _t := 0.0
	var _fade := 1.0
	var _released := false

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func release() -> void:
		_released = true

	func _process(delta: float) -> void:
		var real := delta / maxf(Engine.time_scale, 0.01)
		_t += real
		if _released:
			_fade = maxf(0.0, _fade - real * 1.1)
		queue_redraw()

	func _draw() -> void:
		var size := get_viewport_rect().size
		var center := size / 2.0
		if is_instance_valid(cam) and cam.is_inside_tree():
			center = (cam.get_viewport().get_canvas_transform() * world_pos)
		var rng := RandomNumberGenerator.new()
		rng.seed = int(_t * 30.0)
		var a := _fade
		# bandas negras de cine
		var bar := 70.0 * minf(1.0, _t * 6.0) * a
		draw_rect(Rect2(0, 0, size.x, bar), Color(0, 0, 0, 0.95))
		draw_rect(Rect2(0, size.y - bar, size.x, bar), Color(0, 0, 0, 0.95))
		# líneas de velocidad que apuntan al golpe
		for i in 70:
			var ang := rng.randf() * TAU
			var dir := Vector2(cos(ang), sin(ang))
			var r0 := rng.randf_range(160.0, 300.0)
			var r1 := r0 + rng.randf_range(250.0, 900.0)
			var w := rng.randf_range(1.5, 6.0)
			var c := Color(1, 1, 1, 0.75 * a) if i % 3 else Color(color.r, color.g, color.b, 0.8 * a)
			draw_line(center + dir * r0, center + dir * r1, c, w)
		# destello en el punto del golpe
		var k := minf(1.0, _t * 4.0)
		draw_circle(center, 60.0 + 40.0 * k, Color(1, 1, 1, 0.25 * a))
		draw_arc(center, 90.0 + 260.0 * k, 0, TAU, 64, Color(color.r, color.g, color.b, 0.7 * a * (1.0 - k * 0.5)), 6.0)


func _on_ult_used(f: Fighter) -> void:
	flash(Color(f.data["color"].r, f.data["color"].g, f.data["color"].b, 0.5), 0.6)
	$GameCamera.add_shake(14.0)
	$GameCamera.punch(0.25)
	dim(1.0, 0.45)


func _on_fighter_died(f: Fighter) -> void:
	if over:
		return
	if f.stocks > 0:
		await get_tree().create_timer(0.8 if Game.mode == "training" else 1.4).timeout
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


## Vuelve a poner a todos en su sitio con 0% (modo Entrenamiento).
func training_reset() -> void:
	var spawns := [$Spawn1.position, $Spawn2.position]
	for i in fighters.size():
		var f := fighters[i]
		if not f.is_alive():
			continue
		f.global_position = spawns[mini(i, 1)]
		f.velocity = Vector2.ZERO
		f.percent = 0.0
		f.state = Fighter.State.NORMAL
		f.hitstun = 0.0
		f.hitlag = 0.0
		f.confused_time = 0.0
		f.facing = 1 if f.global_position.x < 0 else -1
		Effects.smoke(self, f.global_position, Color(1, 1, 1))


## Panel del modo Entrenamiento: contador de combos, daño y lo que hace el muñeco ILUNA.
class TrainingPanel extends Control:
	const GRACE := 0.2        # margen entre golpes para que siga contando como combo (segundos)
	const BEHAVIORS := ["quieto", "agachado", "saltar", "caminar", "escudo", "cpu"]
	const NAMES := {"quieto": "Quieto", "agachado": "Agachado", "saltar": "Saltando", "caminar": "Caminando",
		"escudo": "Con escudo", "cpu": "Pelea (CPU)"}
	var stage: Node
	var hits := 0
	var dmg := 0.0
	var last := [0, 0.0]
	var best := [0, 0.0]
	var inf_ult := false
	var _prev := 0.0
	var _idle := 0.0
	var _pop := 0.0
	var _dummy: Fighter
	var _player: Fighter

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for f in stage.fighters:
			if f.char_id == "iluna":
				_dummy = f
			elif _player == null:
				_player = f

	func tick(delta: float) -> void:
		if _dummy == null:
			return
		if Input.is_action_just_pressed("train_reset"):
			stage.training_reset()
			hits = 0
			dmg = 0.0
			_prev = 0.0
			Game.play_sfx("menu_confirm")
		if Input.is_action_just_pressed("train_mode"):
			var i := BEHAVIORS.find(_dummy.behavior)
			_dummy.behavior = BEHAVIORS[(i + 1) % BEHAVIORS.size()]
			Game.play_sfx("select")
		if Input.is_action_just_pressed("train_ult"):
			inf_ult = not inf_ult
			Game.play_sfx("select")
		if inf_ult and _player and _player.ult_meter < Fighter.ULT_MAX:
			_player.ult_meter = Fighter.ULT_MAX
		# contador de combos: los golpes cuentan mientras ILUNA no se haya recuperado
		var in_combo := _dummy.state == Fighter.State.HITSTUN or _dummy.hitlag > 0.0 \
			or _dummy.state == Fighter.State.FROZEN
		var dp := _dummy.percent - _prev
		_prev = _dummy.percent
		if dp > 0.05:
			if _idle > GRACE:
				hits = 0
				dmg = 0.0
			hits += 1
			dmg += dp
			_idle = 0.0
			_pop = 0.3
			if hits >= 2:
				Effects.popup(stage, _dummy.global_position + Vector2(0, -150), "%d GOLPES" % hits,
					Color(1, 0.85, 0.3), 0.8 + minf(hits, 10) * 0.04)
		elif not in_combo:
			if _idle <= GRACE and _idle + delta > GRACE and hits > 0:
				last = [hits, dmg]
				if hits > best[0] or (hits == best[0] and dmg > best[1]):
					best = [hits, dmg]
			_idle += delta
		_pop = maxf(0.0, _pop - delta)
		queue_redraw()

	func _golpes(n: int) -> String:
		return "%d golpe" % n if n == 1 else "%d golpes" % n

	func _draw() -> void:
		var ft: Font = Game.font_title
		var fb: Font = Game.font_body
		var r := Rect2(20, 20, 330, 228)
		draw_style_box(UI.style(Color(0.05, 0.05, 0.12, 0.8), 16, Color(1, 0.6, 0.3, 0.8), 2), r)
		draw_string(ft, Vector2(36, 54), "ENTRENAMIENTO", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.65, 0.35))
		var combo_txt := _golpes(hits) + " · %d%%" % int(dmg) if _idle <= GRACE and hits > 0 else "—"
		var fs := int(24 * (1.0 + _pop))
		draw_string(fb, Vector2(36, 86), "Combo:", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UI.MUTED)
		draw_string_outline(ft, Vector2(100, 88), combo_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.8))
		draw_string(ft, Vector2(100, 88), combo_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.ACCENT)
		draw_string(fb, Vector2(36, 116), "Último: %s · %d%%" % [_golpes(last[0]), int(last[1])], HORIZONTAL_ALIGNMENT_LEFT,
			-1, 16, UI.TEXT)
		draw_string(fb, Vector2(36, 140), "Mejor:  %s · %d%%" % [_golpes(best[0]), int(best[1])], HORIZONTAL_ALIGNMENT_LEFT,
			-1, 16, UI.GOOD)
		var beh: String = NAMES.get(_dummy.behavior, "") if _dummy else ""
		draw_string(fb, Vector2(36, 170), "ILUNA: %s" % beh, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.7, 0.45))
		draw_string(fb, Vector2(36, 196), "T reiniciar · Y qué hace ILUNA", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.MUTED)
		draw_string(fb, Vector2(36, 218), "U ulti infinita: %s" % ("SÍ" if inf_ult else "NO"), HORIZONTAL_ALIGNMENT_LEFT,
			-1, 14, UI.MUTED)
