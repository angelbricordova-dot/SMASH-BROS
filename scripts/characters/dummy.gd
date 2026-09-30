extends Fighter
## ILUNA — el muñeco de prueba del modo Entrenamiento (usa los dibujos de Ilunna, pintado de naranja
## y con una diana en el pecho). No ataca: solo hace lo que elijas en el menú de entrenamiento.
##   "quieto", "agachado", "saltar", "caminar", "escudo" o "cpu" (pelea como la CPU normal).

var behavior := "quieto"
var _jump_t := 0.0
var _walk_dir := 1.0
var _walk_t := 0.0


func _ready() -> void:
	super._ready()
	tint = Color(1.0, 0.72, 0.5)


func _poll_input(delta: float) -> void:
	if behavior == "cpu":
		super._poll_input(delta)
		return
	in_move = 0.0
	in_up = false
	in_down = false
	in_down_pressed = false
	in_left_pressed = false
	in_right_pressed = false
	in_jump_pressed = false
	in_jump_held = false
	in_attack_pressed = false
	in_attack_held = false
	in_special_pressed = false
	in_special_held = false
	in_shield = false
	in_shield_pressed = false
	in_ult_pressed = false
	in_taunt_pressed = false
	in_throw_pressed = false
	attack_buffer = 0.0
	special_buffer = 0.0
	ult_buffer = 0.0
	jump_buffer = maxf(0.0, jump_buffer - delta)
	match behavior:
		"agachado":
			in_down = is_on_floor()
		"saltar":
			_jump_t -= delta
			if is_on_floor() and _jump_t <= 0.0:
				_jump_t = 0.9
				jump_buffer = BUFFER_TIME
			in_jump_held = true
		"caminar":
			_walk_t -= delta
			if _walk_t <= 0.0:
				_walk_t = 1.4
				_walk_dir = -_walk_dir
			var hw: float = stage_info.get("half_width", 400.0) - 120.0
			var rel: float = global_position.x - stage_info.get("center_x", 0.0)
			if absf(rel) > hw:
				_walk_dir = -signf(rel)
			in_move = _walk_dir * 0.6
		"escudo":
			in_shield = is_on_floor()
	# que vuelva al escenario si sale volando (recuperación sencilla)
	if state == State.NORMAL and not is_on_floor():
		var rel2: float = global_position.x - stage_info.get("center_x", 0.0)
		if absf(rel2) > stage_info.get("half_width", 400.0) - 20.0:
			in_move = -signf(rel2)
			if velocity.y > 0.0 and air_jumps_left > 0:
				jump_buffer = BUFFER_TIME


func do_special() -> void:
	end_action()


func do_ultimate() -> void:
	end_action()


func draw_overlay(ci: CanvasItem) -> void:
	super.draw_overlay(ci)
	if vanished or state == State.DEAD:
		return
	# diana en el pecho
	var p := Vector2(0, -52) * size_k()
	for i in 3:
		ci.draw_circle(p, 12.0 - i * 4.0, Color(1, 0.25, 0.2, 0.55) if i % 2 == 0 else Color(1, 1, 1, 0.55))
