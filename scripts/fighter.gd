class_name Fighter
extends CharacterBody2D
## El luchador: se mueve, salta, ataca, se defiende y sale volando.
## Los números de cada personaje están en character_data.gd.

signal died(fighter)
signal hit_landed(strength)   # se emite cuando ALGUIEN recibe un golpe (para sacudir la cámara)

enum State { NORMAL, ATTACK, HITSTUN, SHIELD, SHIELD_BREAK, DEAD }

# --- Hoja de sprites: DEBE coincidir con tools/make_sprites.py ---
const FRAME := 64          # tamaño de cada cuadro (píxeles)
const FEET_Y := 61         # fila del cuadro donde están los pies
const SPRITE_SCALE := 2.0
const ANIMS := [           # [nombre, cuadros, velocidad(fps), repetir]
	["idle", 4, 5.0, true],
	["run", 6, 14.0, true],
	["jump", 1, 1.0, false],
	["fall", 1, 1.0, false],
	["attack", 5, 1.0, false],
	["special", 4, 1.0, false],
	["hurt", 1, 1.0, false],
	["shield", 1, 1.0, false],
]

const HURT_SIZE := Vector2(28, 72)
const MAX_SHIELD := 60.0

# --- Configuración (la pone el escenario antes de añadirlo) ---
var player_id := 1
var char_id := "rojo"
var is_cpu := false
var stage_info := {"half_width": 450.0, "ground_y": 200.0}

# --- Estado ---
var data: Dictionary
var brain: CpuBrain
var state := State.NORMAL
var facing := 1
var percent := 0.0
var stocks := 3
var air_jumps_left := 1
var fast_falling := false
var can_jump_cut := false
var coyote := 0.0
var drop_timer := 0.0
var floor_collider: Object = null

var invincible_time := 0.0
var hover_time := 0.0          # flotando al reaparecer
var hitlag := 0.0
var pending_velocity := Vector2.ZERO
var hitstun := 0.0
var spin := 0.0
var shield_hp := MAX_SHIELD
var shield_break_time := 0.0

var attack_time := 0.0
var attack_total := 0.0
var current_move: Dictionary = {}
var is_special := false
var special_fired := false
var special_cooldown := 0.0
var hit_list: Array = []

# --- Entradas (las llena el teclado/control o el CPU) ---
var in_move := 0.0
var in_up := false
var in_down := false
var in_down_pressed := false
var in_jump_pressed := false
var in_jump_held := false
var in_attack_pressed := false
var in_special_pressed := false
var in_shield := false
var attack_buffer := 0.0
var special_buffer := 0.0

var sprite: AnimatedSprite2D
var overlay: Node2D


func _ready() -> void:
	add_to_group("fighters")
	data = CharacterData.get_data(char_id)
	collision_layer = 4
	collision_mask = 3
	floor_snap_length = 8.0
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = _build_frames()
	sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	sprite.position = Vector2(0, (FRAME / 2.0 - FEET_Y) * SPRITE_SCALE)
	add_child(sprite)
	sprite.play("idle")
	overlay = Node2D.new()
	overlay.set_script(preload("res://scripts/fighter_overlay.gd"))
	overlay.fighter = self
	overlay.z_index = 2
	add_child(overlay)
	if is_cpu:
		brain = CpuBrain.new()


func _build_frames() -> SpriteFrames:
	var tex: Texture2D = load(data["sheet"])
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for row in ANIMS.size():
		var a: Array = ANIMS[row]
		sf.add_animation(a[0])
		sf.set_animation_speed(a[0], a[2])
		sf.set_animation_loop(a[0], a[3])
		for col in a[1]:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(col * FRAME, row * FRAME, FRAME, FRAME)
			sf.add_frame(a[0], at)
	return sf


# ------------------------------------------------------------------
#  Utilidades
# ------------------------------------------------------------------
func hurtbox() -> Rect2:
	return Rect2(global_position + Vector2(-HURT_SIZE.x / 2.0, -HURT_SIZE.y), HURT_SIZE)


func is_alive() -> bool:
	return state != State.DEAD


func find_target() -> Fighter:
	var best: Fighter = null
	var best_d := INF
	for f in get_tree().get_nodes_in_group("fighters"):
		if f != self and f.is_alive():
			var d := global_position.distance_to(f.global_position)
			if d < best_d:
				best_d = d
				best = f
	return best


func respawn(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	percent = 0.0
	state = State.NORMAL
	hitstun = 0.0
	hitlag = 0.0
	spin = 0.0
	sprite.rotation = 0.0
	shield_hp = MAX_SHIELD
	air_jumps_left = 1
	invincible_time = 2.5
	hover_time = 2.5
	visible = true
	facing = 1 if pos.x < 0 else -1


func kill() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	visible = false
	stocks -= 1
	velocity = Vector2.ZERO
	Game.play_sfx("ko")
	died.emit(self)


# ------------------------------------------------------------------
#  Bucle principal
# ------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_poll_input(delta)

	if hitlag > 0.0:
		hitlag -= delta
		sprite.pause()
		if hitlag <= 0.0:
			velocity = pending_velocity
			sprite.play()
		overlay.queue_redraw()
		return

	# temporizadores
	invincible_time = maxf(0.0, invincible_time - delta)
	special_cooldown = maxf(0.0, special_cooldown - delta)
	coyote = maxf(0.0, coyote - delta)
	drop_timer = maxf(0.0, drop_timer - delta)
	if state != State.SHIELD and state != State.SHIELD_BREAK:
		shield_hp = minf(MAX_SHIELD, shield_hp + 10.0 * delta)
	collision_mask = 1 if drop_timer > 0.0 else 3

	if hover_time > 0.0:
		_hover(delta)
	else:
		match state:
			State.NORMAL: _state_normal(delta)
			State.ATTACK: _state_attack(delta)
			State.HITSTUN: _state_hitstun(delta)
			State.SHIELD: _state_shield(delta)
			State.SHIELD_BREAK: _state_shield_break(delta)
		move_and_slide()
		_after_move()

	_update_visuals(delta)
	overlay.queue_redraw()


func _poll_input(delta: float) -> void:
	in_up = false
	in_down_pressed = false
	in_jump_pressed = false
	in_attack_pressed = false
	in_special_pressed = false
	if is_cpu:
		brain.think(self, delta)
	else:
		var p := "p%d_" % player_id
		in_move = Input.get_axis(p + "left", p + "right")
		in_up = Input.is_action_pressed(p + "up")
		in_down = Input.is_action_pressed(p + "down")
		in_down_pressed = Input.is_action_just_pressed(p + "down")
		in_jump_pressed = Input.is_action_just_pressed(p + "jump")
		in_jump_held = Input.is_action_pressed(p + "jump")
		in_attack_pressed = Input.is_action_just_pressed(p + "attack")
		in_special_pressed = Input.is_action_just_pressed(p + "special")
		in_shield = Input.is_action_pressed(p + "shield")
	attack_buffer = 0.12 if in_attack_pressed else maxf(0.0, attack_buffer - delta)
	special_buffer = 0.12 if in_special_pressed else maxf(0.0, special_buffer - delta)


func _hover(delta: float) -> void:
	# Al reaparecer flotas un momento. Se acaba si te mueves, saltas o atacas.
	velocity = Vector2.ZERO
	hover_time -= delta
	invincible_time = maxf(invincible_time, 0.1)
	if in_jump_pressed or in_attack_pressed or in_special_pressed or absf(in_move) > 0.5:
		hover_time = 0.0
		invincible_time = 1.2


# ------------------------------------------------------------------
#  Estados
# ------------------------------------------------------------------
func _apply_gravity(delta: float, factor := 1.0) -> void:
	var max_fall: float = data["fast_fall_speed"] if fast_falling else data["fall_speed"]
	if velocity.y < max_fall:
		velocity.y = minf(velocity.y + data["gravity"] * factor * delta, max_fall)


func _ground_move(delta: float) -> void:
	var target: float = in_move * data["speed"]
	var rate: float = data["accel"] if absf(in_move) > 0.1 else data["friction"]
	velocity.x = move_toward(velocity.x, target, rate * delta)


func _air_move(delta: float) -> void:
	var target: float = in_move * data["speed"]
	if absf(in_move) > 0.1:
		# solo acelera si no va ya más rápido que su velocidad máxima en esa dirección
		if absf(velocity.x) <= data["speed"] or signf(velocity.x) != signf(in_move):
			velocity.x = move_toward(velocity.x, target, data["air_accel"] * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 700.0 * delta)


func _do_jump() -> void:
	if is_on_floor() or coyote > 0.0:
		velocity.y = -data["jump_vel"]
		can_jump_cut = true
		coyote = 0.0
		floor_snap_length = 0.0
	else:
		air_jumps_left -= 1
		velocity.y = -data["double_jump_vel"]
		can_jump_cut = false
		fast_falling = false
		Effects.dust(get_parent(), global_position)
	Game.play_sfx("jump", -6.0, randf_range(0.95, 1.1))


func _can_jump() -> bool:
	return is_on_floor() or coyote > 0.0 or air_jumps_left > 0


func _state_normal(delta: float) -> void:
	var on_floor := is_on_floor()
	if absf(in_move) > 0.1:
		facing = 1 if in_move > 0.0 else -1

	# escudo
	if in_shield and on_floor and shield_hp > 8.0:
		state = State.SHIELD
		return

	# ataques
	if special_buffer > 0.0 and special_cooldown <= 0.0:
		_start_special()
		return
	if attack_buffer > 0.0:
		_start_attack("up" if in_up else ("down" if in_down else "neutral"))
		return

	# saltar
	if in_jump_pressed and _can_jump():
		_do_jump()
		on_floor = false
	if can_jump_cut and not in_jump_held and velocity.y < -300.0:
		velocity.y *= 0.5
		can_jump_cut = false

	# atravesar plataformas
	if on_floor and in_down_pressed and floor_collider and floor_collider.is_in_group("oneway"):
		drop_timer = 0.25
		position.y += 2.0
		on_floor = false

	if on_floor:
		_ground_move(delta)
		velocity.y = 0.0
	else:
		_air_move(delta)
		if in_down_pressed and velocity.y > -50.0:
			fast_falling = true
		_apply_gravity(delta)


func _start_attack(key: String) -> void:
	current_move = data["moves"][key]
	is_special = false
	state = State.ATTACK
	attack_time = 0.0
	attack_total = current_move["startup"] + current_move["active"] + current_move["recovery"]
	attack_buffer = 0.0
	hit_list.clear()
	sprite.play("attack")
	sprite.pause()
	if is_on_floor():
		velocity.x *= 0.4


func _start_special() -> void:
	var sp: Dictionary = data["special"]
	current_move = sp
	is_special = true
	special_fired = false
	state = State.ATTACK
	attack_time = 0.0
	attack_total = sp["startup"] + sp["recovery"] + 0.1
	special_buffer = 0.0
	special_cooldown = sp["cooldown"]
	sprite.play("special")
	sprite.pause()
	if is_on_floor():
		velocity.x *= 0.4


func _state_attack(delta: float) -> void:
	attack_time += delta
	var m := current_move
	var on_floor := is_on_floor()

	if is_special:
		if not special_fired and attack_time >= m["startup"]:
			special_fired = true
			_fire_projectile()
		var f := 0
		if attack_time >= m["startup"] + 0.1:
			f = 3
		elif attack_time >= m["startup"]:
			f = 2
		elif attack_time >= m["startup"] * 0.5:
			f = 1
		sprite.frame = f
	else:
		var t: float = attack_time
		if t >= m["startup"] and t < m["startup"] + m["active"]:
			_check_melee_hits(m)
		var f := 0
		if t >= m["startup"] + m["active"]:
			f = 4
		elif t >= m["startup"]:
			f = 1 + clampi(int((t - m["startup"]) / m["active"] * 3.0), 0, 2)
		sprite.frame = f

	if on_floor:
		velocity.x = move_toward(velocity.x, 0.0, data["friction"] * delta)
		velocity.y = 0.0
	else:
		_air_move(delta * 0.5)
		_apply_gravity(delta)

	# se puede saltar al aire si ya estás en el aire y gastas el doble salto al final
	if attack_time >= attack_total:
		state = State.NORMAL


func _check_melee_hits(m: Dictionary) -> void:
	var center := global_position + Vector2(m["box_pos"].x * facing, m["box_pos"].y)
	var box := Rect2(center - m["box_size"] / 2.0, m["box_size"])
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == self or not f.is_alive() or hit_list.has(f):
			continue
		if box.intersects(f.hurtbox()):
			hit_list.append(f)
			var angle: float = m["angle"]
			if not is_on_floor() and m.has("air_angle"):
				angle = m["air_angle"]
			var info := {
				"dmg": m["dmg"], "base_kb": m["base_kb"], "kb_scale": m["kb_scale"],
				"angle": angle, "dir": facing, "pos": box.get_center().lerp(f.hurtbox().get_center(), 0.5),
			}
			if f.apply_hit(self, info):
				hitlag = f.hitlag  # el atacante también se congela un instante


func _fire_projectile() -> void:
	var sp: Dictionary = data["special"]
	var proj := Projectile.new()
	proj.owner_fighter = self
	proj.dir = facing
	proj.speed = sp["speed"]
	proj.radius = sp["size"]
	proj.lifetime = sp["lifetime"]
	proj.texture = load(data["proj"])
	proj.info = {"dmg": sp["dmg"], "base_kb": sp["base_kb"], "kb_scale": sp["kb_scale"], "angle": sp["angle"]}
	proj.global_position = global_position + Vector2(facing * 38, -44)
	get_parent().add_child(proj)
	Game.play_sfx("shoot", -4.0)


func _state_hitstun(delta: float) -> void:
	hitstun -= delta
	if is_on_floor() and velocity.y >= 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 1400.0 * delta)
		velocity.y = 0.0
		if absf(velocity.x) < 30.0 and hitstun < 0.35:
			spin = 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 420.0 * delta)
		_apply_gravity(delta, 0.8)
	if hitstun <= 0.0:
		state = State.NORMAL
		spin = 0.0
		sprite.rotation = 0.0


func _state_shield(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, data["friction"] * delta)
	velocity.y = 0.0
	shield_hp -= 12.0 * delta
	if in_jump_pressed and _can_jump():
		state = State.NORMAL
		_do_jump()
		return
	if shield_hp <= 0.0:
		_break_shield()
	elif not in_shield or not is_on_floor():
		state = State.NORMAL


func _break_shield() -> void:
	state = State.SHIELD_BREAK
	shield_break_time = 2.2
	velocity = Vector2(0, -520)
	Game.play_sfx("hit_strong")
	hit_landed.emit(30.0)


func _state_shield_break(delta: float) -> void:
	shield_break_time -= delta
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	_apply_gravity(delta)
	if is_on_floor():
		velocity.y = 0.0
	if shield_break_time <= 0.0:
		shield_hp = MAX_SHIELD * 0.5
		state = State.NORMAL


func _after_move() -> void:
	floor_collider = null
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < -0.7:
			floor_collider = c.get_collider()
	if is_on_floor():
		air_jumps_left = 1
		fast_falling = false
		can_jump_cut = false
		coyote = 0.08
		floor_snap_length = 8.0
	elif state == State.NORMAL and floor_snap_length == 0.0 and velocity.y > 0.0:
		floor_snap_length = 8.0


# ------------------------------------------------------------------
#  Recibir golpes
# ------------------------------------------------------------------
## Devuelve true si el golpe conectó. `attacker` puede ser null.
func apply_hit(attacker: Fighter, info: Dictionary) -> bool:
	if state == State.DEAD or invincible_time > 0.0:
		return false

	var dir: int = info["dir"]

	# --- Escudo: bloquea todo el daño ---
	if state == State.SHIELD:
		shield_hp -= info["dmg"] * 1.6
		velocity.x = dir * 140.0
		hitlag = 0.06
		pending_velocity = velocity
		Game.play_sfx("shield")
		Effects.spark(get_parent(), info["pos"], 0.3, Color(0.6, 0.85, 1.0))
		if attacker:
			attacker.velocity.x = -dir * 180.0
		if shield_hp <= 0.0:
			_break_shield()
		return true

	# --- Daño y empuje estilo Smash ---
	percent += info["dmg"]
	var kb: float = (info["base_kb"] + info["kb_scale"] * percent) * (100.0 / data["weight"])
	var angle := deg_to_rad(info["angle"])
	var launch := Vector2(cos(angle) * dir, -sin(angle)) * kb

	state = State.HITSTUN
	hitstun = clampf(0.12 + kb * 0.00035, 0.12, 1.1)
	pending_velocity = launch
	hitlag = clampf(0.035 + info["dmg"] * 0.0045, 0.04, 0.14)
	facing = -dir
	fast_falling = false
	can_jump_cut = false
	floor_snap_length = 0.0 if launch.y < 0.0 else 8.0
	hover_time = 0.0
	spin = 1.0 if kb > 700.0 else 0.0
	sprite.play("hurt")

	var strength := kb / 100.0
	Game.play_sfx("hit_strong" if kb > 700.0 else "hit", -2.0, randf_range(0.92, 1.08))
	Effects.spark(get_parent(), info["pos"], clampf(strength / 8.0, 0.4, 1.6), Color(1.0, 0.95, 0.6))
	hit_landed.emit(strength)
	return true


# ------------------------------------------------------------------
#  Visual
# ------------------------------------------------------------------
func _update_visuals(delta: float) -> void:
	sprite.flip_h = facing < 0
	sprite.position.x = -8.0 * facing
	if invincible_time > 0.0:
		sprite.modulate.a = 0.45 + 0.4 * sin(Time.get_ticks_msec() * 0.03)
	else:
		sprite.modulate.a = 1.0

	if hitlag > 0.0:
		return
	var anim := ""
	match state:
		State.NORMAL:
			if is_on_floor():
				anim = "run" if absf(velocity.x) > 40.0 and absf(in_move) > 0.1 else "idle"
			else:
				anim = "jump" if velocity.y < 0.0 else "fall"
		State.HITSTUN, State.SHIELD_BREAK, State.DEAD:
			anim = "hurt"
		State.SHIELD:
			anim = "shield"
		State.ATTACK:
			anim = ""
	if anim != "" and sprite.animation != anim:
		sprite.play(anim)
	if state == State.NORMAL and sprite.animation == "run":
		sprite.speed_scale = clampf(absf(velocity.x) / data["speed"], 0.6, 1.3)
	else:
		sprite.speed_scale = 1.0

	if state == State.HITSTUN and spin > 0.0:
		sprite.rotation += (1.0 if velocity.x >= 0.0 else -1.0) * 14.0 * delta
	elif sprite.rotation != 0.0:
		sprite.rotation = 0.0


## Dibujos extra encima del personaje (escudo, etiqueta, plataforma de reaparición).
func draw_overlay(ci: CanvasItem) -> void:
	var col: Color = data["color"]
	if hover_time > 0.0:
		ci.draw_rect(Rect2(-40, 4, 80, 8), Color(0.75, 0.9, 1.0, 0.9))
		ci.draw_rect(Rect2(-40, 4, 80, 3), Color(1, 1, 1, 0.9))
	if state == State.SHIELD:
		var r := 30.0 + 26.0 * (shield_hp / MAX_SHIELD)
		ci.draw_circle(Vector2(0, -38), r, Color(col.r, col.g, col.b, 0.35))
		ci.draw_arc(Vector2(0, -38), r, 0, TAU, 32, Color(1, 1, 1, 0.7), 2.0)
	if state == State.SHIELD_BREAK:
		for i in 3:
			var a := Time.get_ticks_msec() * 0.008 + i * TAU / 3.0
			ci.draw_circle(Vector2(cos(a) * 22, -92 + sin(a) * 6), 4, Color(1, 0.9, 0.3))
	# Etiqueta "P1" / "CPU" sobre la cabeza
	var font := ThemeDB.fallback_font
	var label := "CPU" if is_cpu else "P%d" % player_id
	ci.draw_string(font, Vector2(-20, -102), label, HORIZONTAL_ALIGNMENT_CENTER, 40, 16,
		Color(0, 0, 0, 0.8))
	ci.draw_string(font, Vector2(-21, -103), label, HORIZONTAL_ALIGNMENT_CENTER, 40, 16, col)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-5, -97), Vector2(5, -97), Vector2(0, -91)]), col)
