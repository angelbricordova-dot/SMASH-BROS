class_name CpuBrain
extends RefCounted
## Cerebro sencillo para jugadores controlados por la computadora.
## Cada frame rellena las "entradas" del Fighter, como si fuera un control.

var _attack_cd := 0.5
var _jump_cd := 0.0
var _special_cd := 2.0
var _shield_time := 0.0
var reaction := 0.25  # más alto = más lento reaccionando


func think(f: Fighter, delta: float) -> void:
	f.in_move = 0.0
	f.in_up = false
	f.in_down = false
	f.in_jump_held = false
	f.in_shield = false
	_attack_cd -= delta
	_jump_cd -= delta
	_special_cd -= delta
	_shield_time -= delta

	var half_w: float = f.stage_info["half_width"]
	var ground_y: float = f.stage_info["ground_y"]
	var pos := f.global_position

	# --- Recuperación: si está fuera del escenario, volver al centro ---
	var off_x := absf(pos.x) > half_w - 10.0
	var below := pos.y > ground_y + 10.0
	if off_x or below:
		f.in_move = -signf(pos.x)
		if pos.y > ground_y - 60.0 and f.velocity.y > -80.0 and _jump_cd <= 0.0 and f.air_jumps_left > 0:
			f.in_jump_pressed = true
			f.in_jump_held = true
			_jump_cd = 0.5
		f.in_jump_held = f.velocity.y < 0.0
		return

	var t := f.find_target()
	if t == null:
		return
	var d := t.global_position - pos
	var dist := absf(d.x)

	# no caminar fuera del borde
	var edge_guard := func(dirx: float) -> float:
		if absf(pos.x + dirx * 40.0) > half_w - 20.0:
			return 0.0
		return dirx

	# --- Defensa ---
	if t.state == Fighter.State.ATTACK and dist < 110.0 and absf(d.y) < 70.0 and _shield_time <= 0.0 \
			and randf() < 0.02 and f.is_on_floor():
		_shield_time = randf_range(0.3, 0.7)
	if _shield_time > 0.0:
		f.in_shield = true
		return

	# --- Acercarse ---
	if dist > 60.0:
		f.in_move = edge_guard.call(signf(d.x))
	else:
		f.facing = 1 if d.x > 0.0 else -1

	# --- Saltar hacia plataformas / oponente alto ---
	if d.y < -90.0 and dist < 260.0 and _jump_cd <= 0.0 and f._can_jump():
		f.in_jump_pressed = true
		f.in_jump_held = true
		_jump_cd = randf_range(0.5, 1.0)
	if f.velocity.y < 0.0 and d.y < -40.0:
		f.in_jump_held = true

	# --- Bajar de la plataforma si el rival está más abajo ---
	if d.y > 90.0 and dist < 140.0 and f.is_on_floor() and f.floor_collider \
			and f.floor_collider.is_in_group("oneway"):
		f.in_down = true
		f.in_down_pressed = true

	# --- Atacar ---
	if _attack_cd <= 0.0 and dist < 85.0 and absf(d.y) < 90.0:
		if d.y < -70.0:
			f.in_up = true
		f.facing = 1 if d.x > 0.0 else -1
		f.in_attack_pressed = true
		_attack_cd = randf_range(0.35, 0.9) + reaction
	elif _special_cd <= 0.0 and dist > 220.0 and absf(d.y) < 70.0:
		f.facing = 1 if d.x > 0.0 else -1
		f.in_special_pressed = true
		_special_cd = randf_range(1.5, 3.0)
