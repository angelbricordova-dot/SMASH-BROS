class_name CpuBrain
extends RefCounted
## Cerebro de los jugadores controlados por la computadora (CPU).
## Cada frame rellena las "entradas" del Fighter, como si fuera un control.
## Dificultad: 0 = Fácil, 1 = Normal, 2 = Difícil (ver set_level).

var level := 1
var reaction := 0.25
var aggression := 0.65
var shield_chance := 0.015
var parry_chance := 0.12
var dodge_chance := 0.1
var recovery_skill := 0.85
var item_interest := 0.5
var di_skill := 0.4
var combo_skill := 0.5

var _attack_cd := 0.6
var _jump_cd := 0.0
var _special_cd := 1.5
var _shield_time := 0.0
var _hold_attack := 0.0
var _hold_special := 0.0
var _ledge_wait := 0.4
var _dash_cd := 0.0
var _taunt_cd := 3.0
var _last_seen_attack_t := 99.0
var _parry_tried := false
var _combo_left := 0


func set_level(l: int) -> void:
	level = clampi(l, 0, 2)
	match level:
		0:
			reaction = 0.65; aggression = 0.35; shield_chance = 0.004; parry_chance = 0.0; dodge_chance = 0.0
			recovery_skill = 0.55; item_interest = 0.2; di_skill = 0.0; combo_skill = 0.1
		1:
			reaction = 0.28; aggression = 0.65; shield_chance = 0.015; parry_chance = 0.1; dodge_chance = 0.12
			recovery_skill = 0.85; item_interest = 0.5; di_skill = 0.4; combo_skill = 0.5
		2:
			reaction = 0.06; aggression = 0.95; shield_chance = 0.03; parry_chance = 0.35; dodge_chance = 0.3
			recovery_skill = 1.0; item_interest = 0.8; di_skill = 0.9; combo_skill = 0.9


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
	_dash_cd -= delta
	_taunt_cd -= delta
	f.in_attack_held = _hold_attack > 0.0
	f.in_special_held = _hold_special > 0.0
	_hold_attack = maxf(0.0, _hold_attack - delta)
	_hold_special = maxf(0.0, _hold_special - delta)

	var half_w: float = f.stage_info["half_width"]
	var cx: float = f.stage_info.get("center_x", 0.0)
	var ground_y: float = f.stage_info["ground_y"]
	var pos := f.global_position
	var rel_x := pos.x - cx

	if f.state == Fighter.State.LEDGE:
		_ledge_wait -= delta
		if _ledge_wait <= 0.0:
			_ledge_wait = randf_range(0.2, 0.7) + reaction
			if randf() < 0.6:
				f.in_move = f.facing
			else:
				f.in_jump_pressed = true
		return

	if f.state == Fighter.State.HITSTUN:
		if randf() < di_skill:
			f.in_move = -signf(rel_x)
			f.in_up = true
		return

	# --- Recuperación ---
	var offstage := (absf(rel_x) > half_w - 5.0 or pos.y > ground_y + 10.0) and not f.is_on_floor()
	if offstage:
		f.in_move = -signf(rel_x)
		if f.helpless or f.state != Fighter.State.NORMAL:
			return
		var low := pos.y > ground_y - 40.0
		if f.air_jumps_left > 0 and f.velocity.y > -50.0 and low and _jump_cd <= 0.0:
			f.in_jump_pressed = true
			_jump_cd = 0.35
		elif f.air_jumps_left == 0 and not f.up_special_used and f.velocity.y > 0.0 \
				and (pos.y > ground_y - 10.0 or absf(rel_x) > half_w + 160.0) and randf() < recovery_skill:
			f.in_up = true
			f.in_special_pressed = true
		f.in_jump_held = f.velocity.y < 0.0
		return

	var t := f.find_target()
	if t == null:
		return
	var d := t.global_position - pos
	var dist := absf(d.x)
	var face_target := func() -> void:
		f.facing = 1 if d.x > 0.0 else -1

	# --- Provocar si el rival acaba de perder una vida ---
	if not t.is_alive() or t.hover_time > 0.0:
		if _taunt_cd <= 0.0 and f.is_on_floor() and randf() < 0.5:
			f.in_taunt_pressed = true
			_taunt_cd = 6.0
		return

	# --- Objetos en la mano ---
	if f.held_item in ["bomb", "boomerang"] and dist < 420.0 and absf(d.y) < 80.0 and _attack_cd <= 0.0:
		face_target.call()
		f.in_throw_pressed = true
		_attack_cd = 0.8
		return
	if f.held_item == "bow":
		if _hold_attack > 0.0:
			return
		if _attack_cd <= 0.0 and dist > 140.0 and absf(d.y) < 60.0:
			face_target.call()
			f.in_attack_pressed = true
			f.in_attack_held = true
			_hold_attack = randf_range(0.3, 0.95)
			_attack_cd = 0.6 + reaction
			return
	if f.held_item in ["bat", "sword"] and randf() < 0.002:
		face_target.call()
		f.in_throw_pressed = true
		return

	# --- Ulti ---
	if f.ult_meter >= Fighter.ULT_MAX and randf() < 0.04 + level * 0.05:
		var ok := true
		match f.char_id:
			"schizov": ok = dist < 500.0
			"lamont": ok = t.percent < 120.0 or f.percent > 40.0
		if ok:
			face_target.call()
			f.in_ult_pressed = true
			return

	# --- Recoger objetos ---
	if f.held_item == "" and item_interest > 0.0 and f.is_on_floor():
		var best: Node2D = null
		var best_d := 380.0 * item_interest
		for it in f.get_tree().get_nodes_in_group("items"):
			if not it.can_pickup():
				continue
			var dd: float = it.global_position.distance_to(pos)
			if dd < best_d and absf(it.global_position.y - pos.y) < 40.0:
				best_d = dd
				best = it
		if best:
			var dx := best.global_position.x - pos.x
			if absf(dx) < 40.0:
				f.in_attack_pressed = true
			else:
				f.in_move = signf(dx)
			return

	# --- Parry ---
	if t.state == Fighter.State.ATTACK and not t.charging:
		if t.attack_time < _last_seen_attack_t:
			_parry_tried = false
		_last_seen_attack_t = t.attack_time
		var until_active: float = t.move.get("startup", 0.1) - t.attack_time
		if not _parry_tried and dist < 150.0 and absf(d.y) < 90.0 and until_active > 0.0 and until_active < 0.08:
			_parry_tried = true
			var r := randf()
			if r < parry_chance:
				if d.x > 0.0:
					f.in_right_pressed = true
				else:
					f.in_left_pressed = true
				return
			elif r < parry_chance + dodge_chance and f.is_on_floor():
				f.in_shield = true
				f.in_down_pressed = true
				return
	else:
		_last_seen_attack_t = 99.0

	var edge_guard := func(dirx: float) -> float:
		if absf(rel_x + dirx * 40.0) > half_w - 20.0:
			return 0.0
		return dirx

	# --- Escudo ---
	if t.state == Fighter.State.ATTACK and dist < 110.0 and absf(d.y) < 70.0 and _shield_time <= 0.0 \
			and randf() < shield_chance * 3.0 and f.is_on_floor():
		_shield_time = randf_range(0.25, 0.6)
	if _shield_time > 0.0:
		f.in_shield = true
		return

	# --- Acercarse (y correr si está lejos) ---
	if dist > 60.0:
		f.in_move = edge_guard.call(signf(d.x))
		if dist > 230.0 and f.is_on_floor() and not f.running and _dash_cd <= 0.0 and f.in_move != 0.0:
			f.dash_request = 0.1
			f.dash_dir = int(signf(d.x))
			_dash_cd = 1.0
	else:
		face_target.call()

	if d.y < -90.0 and dist < 260.0 and _jump_cd <= 0.0 and f._can_jump():
		f.in_jump_pressed = true
		f.in_jump_held = true
		_jump_cd = randf_range(0.5, 1.0) + reaction
	if f.velocity.y < 0.0 and d.y < -40.0:
		f.in_jump_held = true
	if d.y > 90.0 and dist < 140.0 and f.is_on_floor() and f._on_oneway():
		f.in_down = true
		f.in_down_pressed = true

	# --- Combos: seguir presionando ataque ---
	if _combo_left > 0 and f.state == Fighter.State.ATTACK and dist < 100.0:
		if f.move.has("next"):
			f.in_attack_pressed = true
			_combo_left -= 1
		return

	# --- Atacar ---
	if _attack_cd <= 0.0 and dist < 95.0 and absf(d.y) < 100.0:
		face_target.call()
		var r := randf()
		if not f.is_on_floor():
			if d.y < -60.0:
				f.in_up = true
			elif d.y > 50.0:
				f.in_down = true
			elif r < 0.5:
				f.in_move = float(f.facing)
			f.in_attack_pressed = true
		elif d.y < -70.0:
			f.in_up = true
			f.in_attack_pressed = true
		elif t.percent > 90.0 and r < 0.35 + 0.2 * level:
			f.in_attack_pressed = true
			f.in_attack_held = true
			_hold_attack = randf_range(0.2, 0.7)   # smash cargado para rematar
		elif r < 0.25:
			f.in_down = true
			f.in_attack_pressed = true
		elif r < 0.5:
			f.in_move = float(f.facing)
			f.in_attack_pressed = true
		else:
			f.in_attack_pressed = true
			_combo_left = 2 if randf() < combo_skill else 0
		_attack_cd = randf_range(0.25, 0.7) / aggression + reaction
	elif _special_cd <= 0.0 and absf(d.y) < 70.0:
		face_target.call()
		if dist > 200.0:
			f.in_special_pressed = true
			if randf() < 0.3 + 0.15 * level:
				f.in_special_held = true
				_hold_special = randf_range(0.3, 1.0)
			_special_cd = randf_range(1.5, 3.0) + reaction * 2.0
		elif dist < 120.0 and randf() < 0.3:
			f.in_down = true
			f.in_special_pressed = true
			_special_cd = randf_range(2.0, 4.0) + reaction * 2.0
