class_name Fighter
extends CharacterBody2D
## El luchador BASE: movimiento, ataques normales, escudo, parry, objetos, bordes...
## Las habilidades únicas de cada personaje están en scripts/characters/<id>.gd
## (esos scripts "heredan" de este y reemplazan do_special / do_up_special / do_ultimate).
## Los números de cada personaje están en character_data.gd.

signal died(fighter)
signal hit_landed(strength)   # alguien recibió un golpe (para sacudir la cámara)
signal ult_used(fighter)

enum State { NORMAL, ATTACK, ACTION, HITSTUN, SHIELD, SHIELD_BREAK, LEDGE, FROZEN, VICTORY, DEAD }

# --- Hoja de sprites: DEBE coincidir con tools/make_sprites.py ---
const FRAME := 64
const FEET_Y := 61
const SPRITE_SCALE := 2.0
const ANIMS := [   # [nombre, cuadros, velocidad(fps), repetir]
	["idle", 4, 5.0, true],
	["run", 6, 14.0, true],
	["jump", 1, 1.0, false],
	["fall", 1, 1.0, false],
	["attack", 5, 1.0, false],
	["special", 4, 1.0, false],
	["hurt", 1, 1.0, false],
	["shield", 1, 1.0, false],
	["crouch", 2, 2.0, true],
	["taunt", 4, 5.0, false],
	["win", 6, 7.0, true],
	["ledge", 1, 1.0, false],
	["upspecial", 2, 10.0, false],
]

const HURT_SIZE := Vector2(28, 72)
const CROUCH_SIZE := Vector2(34, 44)
const MAX_SHIELD := 60.0
const PARRY_WINDOW := 0.15   # segundos: qué tan justo hay que presionar para el parry
const ULT_MAX := 100.0
const PARRY_METER := 34.0    # cada parry llena esto de la barra de ulti
const DASH_TAP_TIME := 0.25  # tiempo máximo entre los dos toques para correr
const BUFFER_TIME := 0.15    # las teclas se "recuerdan" este tiempo
const BAT_TEX := preload("res://assets/sprites/item_bat.png")
const BOW_TEX := preload("res://assets/sprites/item_bow.png")
const ARROW_TEX := preload("res://assets/sprites/item_arrow.png")

# --- Configuración (la pone el escenario antes de añadirlo) ---
var player_id := 1
var char_id := "rojo"
var is_cpu := false
var cpu_level := 1
var stage_info := {"half_width": 450.0, "ground_y": 200.0, "ledges": []}

# --- Estado ---
var data: Dictionary
var brain: CpuBrain
var state := State.NORMAL
var facing := 1
var percent := 0.0
var stocks := 3
var ult_meter := 0.0
var air_jumps_left := 1
var up_special_used := false
var helpless := false         # caída indefensa tras la recuperación
var fast_falling := false
var can_jump_cut := false
var running := false
var crouching := false
var coyote := 0.0
var drop_timer := 0.0
var landing_lag := 0.0
var floor_collider: Object = null
var vanished := false           # invisible (teletransporte)

var invincible_time := 0.0
var hover_time := 0.0
var hitlag := 0.0
var pending_velocity := Vector2.ZERO
var hitstun := 0.0
var hitstun_total := 0.0
var spin := 0.0
var flip_t := 0.0
var parry_flash := 0.0
var frozen_time := 0.0
var shield_hp := MAX_SHIELD
var shield_flash := 0.0
var shield_break_time := 0.0
var shield_cracks: Array = []

var ledge: Dictionary = {}
var ledge_time := 0.0
var ledge_cooldown := 0.0

var attack_time := 0.0
var attack_total := 0.0
var attack_in_air := false
var current_move: Dictionary = {}
var special_cooldown := 0.0
var hit_list: Array = []

var action := ""
var action_t := 0.0
var act := {}                 # datos temporales de la acción actual

var held_item := ""           # "", "bat" o "bow"
var item_ammo := 0

# estadísticas de la partida
var damage_dealt := 0.0
var kos := 0
var falls := 0
var parries := 0
var last_hit_by: Fighter = null

# --- Entradas (las llena el teclado/control o el CPU) ---
var in_move := 0.0
var in_up := false
var in_down := false
var in_down_pressed := false
var in_left_pressed := false
var in_right_pressed := false
var in_jump_pressed := false
var in_jump_held := false
var in_attack_pressed := false
var in_attack_held := false
var in_special_pressed := false
var in_shield := false
var in_ult_pressed := false
var in_taunt_pressed := false

var attack_buffer := 0.0
var special_buffer := 0.0
var jump_buffer := 0.0
var ult_buffer := 0.0
var since_tap := {-1: 99.0, 1: 99.0}
var mash_heat := 0.0
var dash_request := 0.0
var dash_dir := 1

var sprite: AnimatedSprite2D
var overlay: Node2D
var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group("fighters")
	data = CharacterData.get_data(char_id)
	collision_layer = 4
	collision_mask = 3
	floor_snap_length = 8.0
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = HURT_SIZE
	_shape.shape = rect
	_shape.position = Vector2(0, -HURT_SIZE.y / 2.0)
	add_child(_shape)

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
		brain.set_level(cpu_level)
	# grietas del escudo (se muestran según el daño)
	var rng := RandomNumberGenerator.new()
	rng.seed = player_id * 97
	for i in 10:
		var a := rng.randf() * TAU
		var pts := PackedVector2Array([Vector2(cos(a), sin(a)) * 0.15])
		var r := 0.15
		while r < 1.0:
			r += rng.randf_range(0.18, 0.3)
			a += rng.randf_range(-0.5, 0.5)
			pts.append(Vector2(cos(a), sin(a)) * minf(r, 1.0))
		shield_cracks.append(pts)


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
#  Utilidades (también las usan los scripts de cada personaje)
# ------------------------------------------------------------------
func hurtbox() -> Rect2:
	var s := CROUCH_SIZE if crouching else HURT_SIZE
	return Rect2(global_position + Vector2(-s.x / 2.0, -s.y), s)


func is_alive() -> bool:
	return state != State.DEAD


func enemies() -> Array:
	var out := []
	for f in get_tree().get_nodes_in_group("fighters"):
		if f != self and f.is_alive():
			out.append(f)
	return out


func find_target() -> Fighter:
	var best: Fighter = null
	var best_d := INF
	for f in enemies():
		var d := global_position.distance_to(f.global_position)
		if d < best_d:
			best_d = d
			best = f
	return best


## Rectángulo de golpe a partir de un desplazamiento (x hacia donde mira).
func box(offset: Vector2, size: Vector2) -> Rect2:
	var center := global_position + Vector2(offset.x * facing, offset.y)
	return Rect2(center - size / 2.0, size)


func make_info(move: Dictionary, dir: int, pos: Vector2) -> Dictionary:
	var angle: float = move.get("angle", 40.0)
	if not is_on_floor() and move.has("air_angle"):
		angle = move["air_angle"]
	return {"dmg": move.get("dmg", 5.0), "base_kb": move.get("base_kb", 250.0),
		"kb_scale": move.get("kb_scale", 5.0), "angle": angle, "dir": dir, "pos": pos,
		"sfx": move.get("sfx", "")}


## Golpea a los enemigos dentro de `rect` (cada uno solo una vez por acción). Devuelve cuántos.
func hit_rect(rect: Rect2, move: Dictionary, dir := 0) -> int:
	var n := 0
	for f in enemies():
		if hit_list.has(f) or not rect.intersects(f.hurtbox()):
			continue
		hit_list.append(f)
		var d := dir if dir != 0 else facing
		var info := make_info(move, d, rect.get_center().lerp(f.hurtbox().get_center(), 0.5))
		if f.apply_hit(self, info):
			n += 1
	return n


func spawn_projectile(p: Dictionary) -> Projectile:
	var proj := Projectile.new()
	proj.owner_fighter = self
	for k in p:
		proj.set(k, p[k])
	if not p.has("texture"):
		proj.texture = load(data["proj"])
	get_parent().add_child(proj)
	return proj


func anim_frame(anim_name: String, frame: int) -> void:
	if sprite.animation != anim_name:
		sprite.play(anim_name)
	sprite.pause()
	sprite.frame = frame


## Dirección que se está presionando (por defecto: arriba). Útil para recuperaciones.
func input_dir(default := Vector2.UP) -> Vector2:
	var v := Vector2(in_move, (-1.0 if in_up else 0.0) + (1.0 if in_down else 0.0))
	return v.normalized() if v.length() > 0.2 else default


func begin_action(action_name: String) -> void:
	state = State.ACTION
	action = action_name
	action_t = 0.0
	act = {}
	hit_list.clear()
	running = false
	crouching = false


func end_action(helpless_after := false) -> void:
	state = State.NORMAL
	action = ""
	vanished = false
	sprite.rotation = 0.0
	if helpless_after and not is_on_floor():
		helpless = true
		Game.play_sfx("helpless", -10.0)


func add_meter(amount: float) -> void:
	var was_full := ult_meter >= ULT_MAX
	ult_meter = minf(ULT_MAX, ult_meter + amount)
	if not was_full and ult_meter >= ULT_MAX:
		Game.play_sfx("ult_ready")
		Effects.popup(get_parent(), global_position + Vector2(0, -120), "¡ULTI LISTA!", data["color"])


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
	up_special_used = false
	helpless = false
	vanished = false
	invincible_time = 2.5
	hover_time = 2.5
	last_hit_by = null
	visible = true
	facing = 1 if pos.x < 0 else -1


func kill() -> void:
	if state == State.DEAD or state == State.VICTORY:
		return
	state = State.DEAD
	visible = false
	stocks -= 1
	falls += 1
	velocity = Vector2.ZERO
	held_item = ""
	action = ""
	Game.play_sfx("ko")
	died.emit(self)


func celebrate() -> void:
	state = State.VICTORY
	invincible_time = 999.0
	vanished = false
	visible = true
	sprite.rotation = 0.0
	sprite.modulate = Color.WHITE
	sprite.play("win")


func freeze(duration: float) -> void:
	if state == State.DEAD or invincible_time > 0.0:
		return
	state = State.FROZEN
	frozen_time = duration
	velocity.x = 0.0
	action = ""
	vanished = false


# ------------------------------------------------------------------
#  Bucle principal
# ------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_poll_input(delta)
	_tick(delta)

	if hitlag > 0.0:
		hitlag -= delta
		sprite.pause()
		if hitlag <= 0.0:
			velocity = _apply_di(pending_velocity) if state == State.HITSTUN else pending_velocity
			sprite.play()
		overlay.queue_redraw()
		return

	if hover_time > 0.0:
		_hover(delta)
	else:
		var was_on_floor := is_on_floor()
		match state:
			State.NORMAL: _state_normal(delta)
			State.ATTACK: _state_attack(delta)
			State.ACTION: _state_action(delta)
			State.HITSTUN: _state_hitstun(delta)
			State.SHIELD: _state_shield(delta)
			State.SHIELD_BREAK: _state_shield_break(delta)
			State.LEDGE: _state_ledge(delta)
			State.FROZEN: _state_frozen(delta)
			State.VICTORY: _state_victory(delta)
		if state != State.LEDGE and state != State.DEAD:
			move_and_slide()
			_after_move(was_on_floor)

	_update_visuals(delta)
	overlay.queue_redraw()


func _tick(delta: float) -> void:
	invincible_time = maxf(0.0, invincible_time - delta)
	special_cooldown = maxf(0.0, special_cooldown - delta)
	coyote = maxf(0.0, coyote - delta)
	drop_timer = maxf(0.0, drop_timer - delta)
	landing_lag = maxf(0.0, landing_lag - delta)
	ledge_cooldown = maxf(0.0, ledge_cooldown - delta)
	parry_flash = maxf(0.0, parry_flash - delta)
	shield_flash = maxf(0.0, shield_flash - delta)
	flip_t = maxf(0.0, flip_t - delta)
	if state != State.SHIELD and state != State.SHIELD_BREAK:
		shield_hp = minf(MAX_SHIELD, shield_hp + 9.0 * delta)
	collision_mask = 1 if drop_timer > 0.0 else 3


func _poll_input(delta: float) -> void:
	in_up = false
	in_down_pressed = false
	in_left_pressed = false
	in_right_pressed = false
	in_jump_pressed = false
	in_attack_pressed = false
	in_special_pressed = false
	in_ult_pressed = false
	in_taunt_pressed = false
	if is_cpu:
		brain.think(self, delta)
	else:
		var p := "p%d_" % player_id
		in_move = Input.get_axis(p + "left", p + "right")
		in_up = Input.is_action_pressed(p + "up")
		in_down = Input.is_action_pressed(p + "down")
		in_down_pressed = Input.is_action_just_pressed(p + "down")
		in_left_pressed = Input.is_action_just_pressed(p + "left")
		in_right_pressed = Input.is_action_just_pressed(p + "right")
		in_jump_pressed = Input.is_action_just_pressed(p + "jump")
		in_jump_held = Input.is_action_pressed(p + "jump")
		in_attack_pressed = Input.is_action_just_pressed(p + "attack")
		in_attack_held = Input.is_action_pressed(p + "attack")
		in_special_pressed = Input.is_action_just_pressed(p + "special")
		in_shield = Input.is_action_pressed(p + "shield")
		in_ult_pressed = Input.is_action_just_pressed(p + "ult")
		in_taunt_pressed = Input.is_action_just_pressed(p + "taunt")

	# toques de dirección: sirven para correr (doble toque) y para el parry
	since_tap[-1] += delta
	since_tap[1] += delta
	mash_heat = maxf(0.0, mash_heat - delta * 2.5)
	dash_request = maxf(0.0, dash_request - delta)
	for d in [-1, 1]:
		if (d == -1 and in_left_pressed) or (d == 1 and in_right_pressed):
			if since_tap[d] < DASH_TAP_TIME:
				dash_request = 0.1
				dash_dir = d
			since_tap[d] = 0.0
			mash_heat += 1.0

	# "buffer": una tecla presionada un poco antes se ejecuta en cuanto se pueda
	attack_buffer = BUFFER_TIME if in_attack_pressed else maxf(0.0, attack_buffer - delta)
	special_buffer = BUFFER_TIME if in_special_pressed else maxf(0.0, special_buffer - delta)
	jump_buffer = BUFFER_TIME if in_jump_pressed else maxf(0.0, jump_buffer - delta)
	ult_buffer = BUFFER_TIME if in_ult_pressed else maxf(0.0, ult_buffer - delta)


func _hover(delta: float) -> void:
	# Al reaparecer flotas un momento. Se acaba si te mueves, saltas o atacas.
	velocity = Vector2.ZERO
	hover_time -= delta
	invincible_time = maxf(invincible_time, 0.1)
	if in_jump_pressed or in_attack_pressed or in_special_pressed or absf(in_move) > 0.5 or in_down:
		hover_time = 0.0
		invincible_time = 1.2
		jump_buffer = 0.0
		attack_buffer = 0.0


# ------------------------------------------------------------------
#  Movimiento
# ------------------------------------------------------------------
func apply_gravity(delta: float, factor := 1.0) -> void:
	var max_fall: float = data["fast_fall_speed"] if fast_falling else data["fall_speed"]
	if velocity.y < max_fall:
		velocity.y = minf(velocity.y + data["gravity"] * factor * delta, max_fall)


func ground_friction(delta: float, factor := 1.0) -> void:
	velocity.x = move_toward(velocity.x, 0.0, data["friction"] * factor * delta)


func _ground_move(delta: float) -> void:
	var top: float = data["speed"] if running else data["walk_speed"]
	var target: float = in_move * top
	if absf(in_move) > 0.1:
		velocity.x = move_toward(velocity.x, target, data["accel"] * delta)
	else:
		ground_friction(delta)


func air_drift(delta: float, factor := 1.0) -> void:
	var max_s: float = data["air_speed"]
	if absf(in_move) > 0.1:
		var target: float = in_move * max_s
		if absf(velocity.x) <= max_s or signf(velocity.x) != signf(in_move):
			velocity.x = move_toward(velocity.x, target, data["air_accel"] * factor * delta)
		else:
			velocity.x = move_toward(velocity.x, target, 300.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 700.0 * factor * delta)


func _do_jump() -> void:
	if is_on_floor() or coyote > 0.0:
		velocity.y = -data["jump_vel"]
		var air_max: float = data["air_speed"] * 1.15
		velocity.x = clampf(velocity.x, -air_max, air_max)
		can_jump_cut = true
		coyote = 0.0
		floor_snap_length = 0.0
		Game.play_sfx("jump", -6.0, randf_range(0.95, 1.1))
		Effects.dust(get_parent(), global_position)
	else:
		air_jumps_left -= 1
		velocity.y = -data["double_jump_vel"]
		velocity.x = in_move * data["air_speed"]  # el doble salto cambia de dirección al instante
		can_jump_cut = false
		fast_falling = false
		flip_t = 0.35
		Game.play_sfx("double_jump", -4.0)
		Effects.ring(get_parent(), global_position + Vector2(0, -8), Color(1, 1, 1, 0.8), 34.0)
	running = false


func _can_jump() -> bool:
	return is_on_floor() or coyote > 0.0 or air_jumps_left > 0


func _on_oneway() -> bool:
	return floor_collider != null and is_instance_valid(floor_collider) and floor_collider.is_in_group("oneway")


func _state_normal(delta: float) -> void:
	var on_floor := is_on_floor()
	var was_crouching := crouching
	crouching = false

	if landing_lag > 0.0 and on_floor:
		ground_friction(delta)
		velocity.y = 0.0
		return

	if helpless and not on_floor:
		air_drift(delta, 0.6)
		apply_gravity(delta)
		_check_ledge_grab()
		return

	# ulti
	if ult_buffer > 0.0 and ult_meter >= ULT_MAX:
		ult_buffer = 0.0
		_start_ult()
		return
	# provocar
	if in_taunt_pressed and on_floor:
		begin_action("taunt")
		Game.play_sfx("taunt", -2.0, 0.85 + 0.1 * CharacterData.ORDER.find(char_id))
		return
	# escudo
	if in_shield and on_floor and shield_hp > 8.0:
		state = State.SHIELD
		running = false
		return
	# especiales: arriba + especial = recuperación
	if special_buffer > 0.0:
		if in_up and not up_special_used:
			special_buffer = 0.0
			up_special_used = true
			do_up_special()
			return
		elif not in_up and special_cooldown <= 0.0:
			special_buffer = 0.0
			special_cooldown = data["special_cooldown"]
			do_special()
			return
	# ataques / objetos
	if attack_buffer > 0.0:
		attack_buffer = 0.0
		if held_item == "" and on_floor and _try_pickup():
			return
		if held_item == "bat":
			_start_attack_move(CharacterData.BAT_MOVE)
			return
		if held_item == "bow":
			begin_action("bow")
			Game.play_sfx("bow_draw", -4.0)
			return
		var key := "neutral"
		if on_floor and running and absf(velocity.x) > data["walk_speed"]:
			key = "dash"
		elif in_up:
			key = "up"
		elif in_down:
			key = "down"
		_start_attack(key)
		return

	# saltar
	if jump_buffer > 0.0 and _can_jump():
		jump_buffer = 0.0
		_do_jump()
		on_floor = false
	if can_jump_cut and not in_jump_held and velocity.y < -300.0:
		velocity.y *= 0.5   # salto corto si sueltas rápido
		can_jump_cut = false

	# atravesar plataformas
	if on_floor and in_down_pressed and _on_oneway():
		drop_timer = 0.25
		position.y += 2.0
		on_floor = false

	if on_floor:
		# correr con doble toque
		if dash_request > 0.0:
			dash_request = 0.0
			running = true
			facing = dash_dir
			var burst: float = data["speed"] * 1.1
			if absf(velocity.x) < burst or signf(velocity.x) != dash_dir:
				velocity.x = dash_dir * burst
			Game.play_sfx("dash", -6.0)
			Effects.dust(get_parent(), global_position)
		if running and (absf(in_move) < 0.1 or signf(in_move) != facing):
			running = false
		crouching = in_down and absf(in_move) < 0.3
		if crouching:
			ground_friction(delta, 1.5)
			if not was_crouching:
				Game.play_sfx("crouch", -12.0)
		else:
			_ground_move(delta)
			if absf(in_move) > 0.1:
				facing = 1 if in_move > 0.0 else -1
		velocity.y = 0.0
	else:
		running = false
		if absf(in_move) > 0.1:
			facing = 1 if in_move > 0.0 else -1
		air_drift(delta)
		if in_down_pressed and velocity.y > -80.0:
			fast_falling = true
		apply_gravity(delta)
		_check_ledge_grab()


# ------------------------------------------------------------------
#  Ataques normales
# ------------------------------------------------------------------
func _start_attack(key: String) -> void:
	_start_attack_move(data["moves"][key])


func _start_attack_move(m: Dictionary) -> void:
	current_move = m
	state = State.ATTACK
	attack_time = 0.0
	attack_total = m["startup"] + m["active"] + m["recovery"]
	attack_in_air = not is_on_floor()
	hit_list.clear()
	crouching = false
	anim_frame("attack", 0)
	if m.has("lunge"):
		velocity.x = facing * m["lunge"]
		running = false
	elif not attack_in_air:
		velocity.x *= 0.4
	if m.get("bat", false):
		Game.play_sfx("swing", -2.0, 0.8)
	else:
		Game.play_sfx("swing", -10.0, randf_range(1.2, 1.5))


func _state_attack(delta: float) -> void:
	attack_time += delta
	var m := current_move
	var t := attack_time
	if t >= m["startup"] and t < m["startup"] + m["active"]:
		var move := m.duplicate()
		if m.get("bat", false):
			move["sfx"] = "homerun"
		hit_rect(box(m["box_pos"], m["box_size"]), move)
	var f := 0
	if t >= m["startup"] + m["active"]:
		f = 4
	elif t >= m["startup"]:
		f = 1 + clampi(int((t - m["startup"]) / m["active"] * 3.0), 0, 2)
	anim_frame("attack", f)

	if is_on_floor():
		if attack_in_air:
			# aterrizar cancela el ataque aéreo (con muy poco retraso)
			state = State.NORMAL
			landing_lag = 0.06
			return
		ground_friction(delta, 0.6 if m.has("lunge") else 1.0)
		velocity.y = 0.0
	else:
		air_drift(delta, 0.6)
		apply_gravity(delta)
	if attack_time >= attack_total:
		state = State.NORMAL


# ------------------------------------------------------------------
#  Acciones (especiales, ulti, provocar, arco...). Los personajes agregan las suyas.
# ------------------------------------------------------------------
func _state_action(delta: float) -> void:
	action_t += delta
	match action:
		"taunt":
			if sprite.animation != "taunt":
				sprite.play("taunt")
			ground_friction(delta)
			apply_gravity(delta)
			if action_t >= 0.9:
				end_action()
		"bow":
			_action_bow(delta)
		_:
			char_action(action, action_t, delta)


## Especial normal por defecto: bola de energía. Los personajes lo reemplazan.
func do_special() -> void:
	begin_action("fireball")


## Recuperación (arriba + especial) por defecto: un salto fuerte.
func do_up_special() -> void:
	begin_action("recover")


## Ulti por defecto.
func do_ultimate() -> void:
	begin_action("recover")


## Lo reemplazan los personajes para programar sus acciones.
func char_action(action_name: String, t: float, delta: float) -> void:
	match action_name:
		"fireball":
			anim_frame("special", mini(int(t / 0.1), 3))
			if not act.has("fired") and t >= 0.2:
				act["fired"] = true
				spawn_projectile({"velocity": Vector2(facing * 600, 0),
					"global_position": global_position + Vector2(facing * 38, -44),
					"info": {"dmg": 6.0, "base_kb": 260.0, "kb_scale": 6.0, "angle": 30.0}})
			_action_physics(delta)
			if t >= 0.45:
				end_action()
		"recover":
			if t < 0.02:
				velocity.y = -900.0
			anim_frame("upspecial", 0)
			air_drift(delta)
			apply_gravity(delta)
			if t >= 0.4:
				end_action(true)
		_:
			end_action()


## Física genérica durante una acción: frena en el suelo, cae en el aire.
func _action_physics(delta: float, air_factor := 0.5) -> void:
	if is_on_floor():
		ground_friction(delta)
		velocity.y = 0.0
	else:
		air_drift(delta, air_factor)
		apply_gravity(delta)


func _start_ult() -> void:
	ult_meter = 0.0
	invincible_time = maxf(invincible_time, 0.5)
	Game.play_sfx("ult")
	Effects.popup(get_parent(), global_position + Vector2(0, -130), "¡ULTI!", data["color"], 1.6)
	ult_used.emit(self)
	do_ultimate()


# ------------------------------------------------------------------
#  Objetos
# ------------------------------------------------------------------
func _try_pickup() -> bool:
	for it in get_tree().get_nodes_in_group("items"):
		if it.can_pickup() and it.global_position.distance_to(global_position + Vector2(0, -10)) < 60.0:
			held_item = it.kind
			item_ammo = 3 if it.kind == "bow" else 0
			it.queue_free()
			Game.play_sfx("pickup")
			Effects.popup(get_parent(), global_position + Vector2(0, -110),
				"¡BATE!" if held_item == "bat" else "ARCO x3", Color(1, 0.95, 0.6), 0.8)
			return true
	return false


func throw_item() -> void:
	if held_item == "":
		return
	var tex: Texture2D = BAT_TEX if held_item == "bat" else BOW_TEX
	spawn_projectile({"velocity": Vector2(facing * 900, -150), "gravity": 700.0, "texture": tex,
		"hframes": 1 if held_item == "bat" else 3, "spin": 18.0, "radius": 18.0, "lifetime": 1.2,
		"global_position": global_position + Vector2(facing * 20, -50), "solid": true,
		"info": {"dmg": 9.0, "base_kb": 300.0, "kb_scale": 6.0, "angle": 35.0}})
	held_item = ""
	Game.play_sfx("throw")


func bow_charge() -> float:
	return clampf(action_t / 0.9, 0.0, 1.0) if action == "bow" and not act.has("fired") else 0.0


func _action_bow(delta: float) -> void:
	anim_frame("special", 1 if not act.has("fired") else 3)
	_action_physics(delta, 0.4)
	if absf(in_move) > 0.1 and is_on_floor():
		velocity.x = in_move * 60.0   # como en Minecraft: caminas lento mientras tensas
	if not act.has("fired"):
		if action_t > 0.12 and (not in_attack_held or action_t > 2.5):
			var c := clampf(action_t / 0.9, 0.0, 1.0)
			act["fired"] = action_t
			item_ammo -= 1
			spawn_projectile({"velocity": Vector2(facing * (520.0 + 900.0 * c), -40.0 * (1.0 - c)),
				"gravity": 900.0 * (1.0 - c * 0.6), "texture": ARROW_TEX,
				"hframes": 1, "rotate_to_velocity": true, "radius": 10.0, "lifetime": 2.0, "solid": true,
				"global_position": global_position + Vector2(facing * 30, -48), "hit_sfx": "arrow_hit",
				"info": {"dmg": 4.0 + 10.0 * c, "base_kb": 180.0 + 240.0 * c, "kb_scale": 3.0 + 5.0 * c, "angle": 30.0}})
			Game.play_sfx("bow_shoot")
	elif action_t - float(act["fired"]) >= 0.2:
		if item_ammo <= 0:
			held_item = ""
			Effects.popup(get_parent(), global_position + Vector2(0, -110), "Sin flechas", Color(0.9, 0.9, 0.9), 0.8)
		end_action()


# ------------------------------------------------------------------
#  Golpes recibidos, escudo y parry
# ------------------------------------------------------------------
func _state_hitstun(delta: float) -> void:
	hitstun -= delta
	if is_on_floor() and velocity.y >= 0.0:
		ground_friction(delta, 0.6)
		velocity.y = 0.0
		if absf(velocity.x) < 30.0 and hitstun < 0.35:
			spin = 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, 420.0 * delta)
		if absf(in_move) > 0.1:
			velocity.x += in_move * 320.0 * delta   # un poco de control mientras vuelas
		apply_gravity(delta, 0.8)
	# salir antes del aturdimiento si ya casi termina y presionas algo (más fluido)
	var early := hitstun < hitstun_total * 0.3 and (jump_buffer > 0.0 or special_buffer > 0.0 or attack_buffer > 0.0)
	if hitstun <= 0.0 or early:
		state = State.NORMAL
		spin = 0.0
		sprite.rotation = 0.0


## DI: mantener una dirección al ser golpeado cambia un poco el ángulo de salida (como en Smash).
func _apply_di(v: Vector2) -> Vector2:
	var inp := Vector2(in_move, (-1.0 if in_up else 0.0) + (1.0 if in_down else 0.0))
	if inp.length() < 0.2 or v.length() < 1.0:
		return v
	var cross := v.normalized().cross(inp.normalized())
	return v.rotated(cross * 0.26)


func _can_parry(dir: int) -> bool:
	if helpless or not (state == State.NORMAL or state == State.SHIELD or state == State.LEDGE):
		return false
	var toward := -dir
	return since_tap[toward] <= PARRY_WINDOW and mash_heat < 3.5


func _do_parry(attacker: Fighter, info: Dictionary) -> void:
	parries += 1
	since_tap[-1] = 99.0
	since_tap[1] = 99.0
	pending_velocity = velocity
	hitlag = 0.1
	invincible_time = 0.25
	parry_flash = 0.3
	if attacker and not info.get("projectile", false):
		attacker.hitlag = maxf(attacker.hitlag, 0.4)   # el atacante queda congelado: ¡contraataca!
		attacker.pending_velocity = attacker.velocity
	add_meter(PARRY_METER)
	Game.play_sfx("parry")
	Effects.popup(get_parent(), global_position + Vector2(0, -110), "¡PARRY!", Color(0.45, 0.85, 1.0), 1.2)
	Effects.ring(get_parent(), global_position + Vector2(0, -38), Color(0.6, 0.9, 1.0), 70.0)


## Devuelve true si el golpe "conectó" (incluye escudo y parry). `attacker` puede ser null.
func apply_hit(attacker: Fighter, info: Dictionary) -> bool:
	if state == State.DEAD or state == State.VICTORY or invincible_time > 0.0:
		return false
	var dir: int = info["dir"]
	var melee: bool = not info.get("projectile", false)

	# --- PARRY: presionar hacia el atacante justo cuando llega el golpe ---
	if _can_parry(dir):
		_do_parry(attacker, info)
		return true

	# --- Escudo: bloquea el daño, pero se agrieta ---
	if state == State.SHIELD:
		shield_hp -= info["dmg"] * 1.5 + 2.0
		shield_flash = 0.15
		velocity.x = dir * 150.0
		hitlag = 0.06
		pending_velocity = velocity
		Game.play_sfx("shield_crack" if shield_hp < MAX_SHIELD * 0.5 else "shield")
		Effects.spark(get_parent(), info["pos"], 0.35, Color(0.6, 0.85, 1.0))
		if attacker and melee:
			attacker.velocity.x = -dir * 180.0
		if shield_hp <= 0.0:
			_break_shield()
		return true

	# --- Daño y empuje estilo Smash ---
	var dmg: float = info["dmg"]
	percent = minf(999.0, percent + dmg)
	if attacker:
		last_hit_by = attacker
		attacker.damage_dealt += dmg
		attacker.add_meter(dmg * 0.35)
	var kb: float = (info["base_kb"] + info["kb_scale"] * percent) * (100.0 / data["weight"])
	if crouching:
		kb *= 0.85
	var angle := deg_to_rad(info["angle"])
	var launch := Vector2(cos(angle) * dir, -sin(angle)) * kb

	if state == State.ACTION:
		action = ""
		vanished = false
	state = State.HITSTUN
	hitstun = clampf(0.1 + kb * 0.00032, 0.1, 0.95)
	hitstun_total = hitstun
	pending_velocity = launch
	hitlag = clampf(0.035 + dmg * 0.0045, 0.04, 0.16)
	if attacker and melee:
		attacker.hitlag = maxf(attacker.hitlag, hitlag)
		attacker.pending_velocity = attacker.velocity
	facing = -dir
	fast_falling = false
	can_jump_cut = false
	running = false
	crouching = false
	helpless = false
	# ser golpeado te devuelve el doble salto y la recuperación (no desperdicias movilidad)
	air_jumps_left = maxi(air_jumps_left, 1)
	up_special_used = false
	floor_snap_length = 0.0 if launch.y < 0.0 else 8.0
	hover_time = 0.0
	spin = 1.0 if kb > 700.0 else 0.0
	sprite.play("hurt")

	var strength := kb / 100.0
	var sfx: String = info.get("sfx", "")
	if sfx == "homerun" and kb < 900.0:
		sfx = "hit_strong"
	if sfx == "":
		sfx = "hit_strong" if kb > 700.0 else "hit"
	Game.play_sfx(sfx, -2.0, randf_range(0.92, 1.08))
	Effects.spark(get_parent(), info["pos"], clampf(strength / 8.0, 0.4, 1.8), Color(1.0, 0.95, 0.6))
	hit_landed.emit(strength)
	return true


## Daño sin empuje (por ejemplo, mientras está congelado).
func take_damage(dmg: float, attacker: Fighter = null) -> void:
	percent = minf(999.0, percent + dmg)
	if attacker:
		attacker.damage_dealt += dmg
	Effects.spark(get_parent(), global_position + Vector2(0, -40), 0.4, Color(0.7, 0.9, 1.0))


func _state_shield(delta: float) -> void:
	ground_friction(delta)
	velocity.y = 0.0
	shield_hp -= 11.0 * delta
	if jump_buffer > 0.0 and _can_jump():
		jump_buffer = 0.0
		state = State.NORMAL
		_do_jump()
		return
	if attack_buffer > 0.0 and held_item != "":
		attack_buffer = 0.0
		throw_item()   # escudo + ataque = lanzar el objeto
	if shield_hp <= 0.0:
		_break_shield()
	elif not in_shield or not is_on_floor():
		state = State.NORMAL


func _break_shield() -> void:
	state = State.SHIELD_BREAK
	shield_break_time = 2.2
	velocity = Vector2(0, -520)
	Game.play_sfx("shield_break")
	Effects.shatter(get_parent(), global_position + Vector2(0, -38), data["color"])
	hit_landed.emit(30.0)


func _state_shield_break(delta: float) -> void:
	shield_break_time -= delta
	velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
	apply_gravity(delta)
	if is_on_floor():
		velocity.y = 0.0
	if shield_break_time <= 0.0:
		shield_hp = MAX_SHIELD * 0.5
		state = State.NORMAL


func _state_frozen(delta: float) -> void:
	frozen_time -= delta
	velocity.x = move_toward(velocity.x, 0.0, 800.0 * delta)
	apply_gravity(delta)
	if is_on_floor():
		velocity.y = 0.0
	if frozen_time <= 0.0:
		state = State.NORMAL


func _state_victory(delta: float) -> void:
	apply_gravity(delta)
	ground_friction(delta)
	if is_on_floor():
		velocity.y = 0.0
		# pequeños saltos de emoción
		if fmod(Time.get_ticks_msec() / 1000.0, 1.4) < delta * 1.5:
			velocity.y = -420.0
			floor_snap_length = 0.0
	if sprite.animation != "win":
		sprite.play("win")


# ------------------------------------------------------------------
#  Bordes del escenario
# ------------------------------------------------------------------
func _hang_pos(l: Dictionary) -> Vector2:
	var p: Vector2 = l["pos"]
	return Vector2(p.x + l["side"] * 14.0, p.y + 66.0)


func _check_ledge_grab() -> void:
	if ledge_cooldown > 0.0 or velocity.y < 0.0:
		return
	for l in stage_info.get("ledges", []):
		var hp := _hang_pos(l)
		if absf(global_position.x - hp.x) < 30.0 and absf(global_position.y - hp.y) < 42.0:
			_grab_ledge(l)
			return


func _grab_ledge(l: Dictionary) -> void:
	state = State.LEDGE
	ledge = l
	ledge_time = 0.0
	global_position = _hang_pos(l)
	velocity = Vector2.ZERO
	facing = -int(l["side"])
	air_jumps_left = 1
	up_special_used = false
	helpless = false
	fast_falling = false
	invincible_time = maxf(invincible_time, 0.5)
	anim_frame("ledge", 0)
	Game.play_sfx("land", -4.0)


func _state_ledge(delta: float) -> void:
	ledge_time += delta
	velocity = Vector2.ZERO
	if ledge_time < 0.12:
		return
	var p: Vector2 = ledge["pos"]
	var side: float = ledge["side"]
	if jump_buffer > 0.0:
		jump_buffer = 0.0
		state = State.NORMAL
		global_position.y = p.y + 30.0
		velocity = Vector2(facing * 150.0, -data["jump_vel"])
		ledge_cooldown = 0.4
		floor_snap_length = 0.0
		Game.play_sfx("jump", -6.0)
	elif in_up or in_move * facing > 0.5 or attack_buffer > 0.0:
		attack_buffer = 0.0
		state = State.NORMAL
		global_position = Vector2(p.x - side * 26.0, p.y - 1.0)
		velocity = Vector2.ZERO
		invincible_time = maxf(invincible_time, 0.2)
	elif in_down or in_move * facing < -0.5 or ledge_time > 4.0:
		state = State.NORMAL
		ledge_cooldown = 0.5
		global_position.x += side * 6.0


func _after_move(was_on_floor: bool) -> void:
	floor_collider = null
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < -0.7:
			floor_collider = c.get_collider()
	if is_on_floor():
		if not was_on_floor and state != State.DEAD:
			Game.play_sfx("land", -14.0)
			if helpless:
				landing_lag = 0.12
		air_jumps_left = 1
		up_special_used = false
		helpless = false
		fast_falling = false
		can_jump_cut = false
		coyote = 0.08
		floor_snap_length = 8.0
	elif state == State.NORMAL and floor_snap_length == 0.0 and velocity.y > 0.0:
		floor_snap_length = 8.0


# ------------------------------------------------------------------
#  Visual
# ------------------------------------------------------------------
func _update_visuals(delta: float) -> void:
	sprite.flip_h = facing < 0
	sprite.position.x = -8.0 * facing
	sprite.visible = not vanished

	var col := Color.WHITE
	if parry_flash > 0.0:
		col = Color(0.7, 1.0, 1.8)
	elif state == State.FROZEN:
		col = Color(0.6, 0.9, 1.4)
	elif helpless and not is_on_floor():
		col = Color(0.55, 0.55, 0.75)
	if invincible_time > 0.0 and state != State.VICTORY:
		col.a = 0.45 + 0.4 * sin(Time.get_ticks_msec() * 0.03)
	sprite.modulate = col

	if hitlag > 0.0:
		return
	var anim := ""
	var speed := 1.0
	match state:
		State.NORMAL:
			if is_on_floor():
				if landing_lag > 0.0 or crouching:
					anim = "crouch"
				elif absf(velocity.x) > 30.0 and absf(in_move) > 0.1:
					anim = "run"
					speed = clampf(absf(velocity.x) / data["speed"], 0.45, 1.3)
				else:
					anim = "idle"
			else:
				anim = "jump" if velocity.y < 0.0 else "fall"
		State.HITSTUN, State.SHIELD_BREAK, State.FROZEN:
			anim = "hurt"
		State.SHIELD:
			anim = "shield"
		State.LEDGE:
			anim = "ledge"
		State.VICTORY:
			anim = "win"
	if anim != "" and sprite.animation != anim:
		sprite.play(anim)
	elif anim != "" and not sprite.is_playing():
		sprite.play(anim)
	if state == State.NORMAL or state == State.VICTORY:
		sprite.speed_scale = speed

	if state == State.HITSTUN and spin > 0.0:
		sprite.rotation += (1.0 if velocity.x >= 0.0 else -1.0) * 14.0 * delta
	elif flip_t > 0.0:
		sprite.rotation = facing * TAU * (1.0 - flip_t / 0.35)
	elif state != State.ACTION and sprite.rotation != 0.0:
		sprite.rotation = 0.0


## Dibujos extra encima del personaje (escudo, objetos, etiqueta...).
func draw_overlay(ci: CanvasItem) -> void:
	var col: Color = data["color"]
	var t := Time.get_ticks_msec() / 1000.0
	if hover_time > 0.0:
		ci.draw_rect(Rect2(-40, 4, 80, 8), Color(0.75, 0.9, 1.0, 0.9))
		ci.draw_rect(Rect2(-40, 4, 80, 3), Color(1, 1, 1, 0.9))

	# objeto en la mano
	if held_item != "" and not vanished and state != State.DEAD:
		_draw_held_item(ci)

	# escudo que se va rompiendo
	if state == State.SHIELD:
		var k := clampf(shield_hp / MAX_SHIELD, 0.0, 1.0)
		var r := 28.0 + 28.0 * k
		var c := col.lerp(Color(1, 0.25, 0.2), 1.0 - k)
		var alpha := 0.35 if k > 0.25 or fmod(t, 0.2) < 0.1 else 0.15
		if shield_flash > 0.0:
			c = c.lerp(Color.WHITE, 0.6)
			alpha = 0.6
		var center := Vector2(0, -38)
		ci.draw_circle(center, r, Color(c.r, c.g, c.b, alpha))
		ci.draw_arc(center, r, 0, TAU, 40, Color(1, 1, 1, 0.75), 2.0)
		ci.draw_arc(center, r * 0.7, -2.4, -1.4, 10, Color(1, 1, 1, 0.35), 3.0)  # brillo
		var cracks := int((1.0 - k) * shield_cracks.size() * 1.1)
		for i in mini(cracks, shield_cracks.size()):
			var pts: PackedVector2Array = shield_cracks[i]
			var scaled := PackedVector2Array()
			for p in pts:
				scaled.append(center + p * r)
			ci.draw_polyline(scaled, Color(1, 1, 1, 0.85), 1.5)
	if state == State.SHIELD_BREAK:
		for i in 3:
			var a := t * 8.0 + i * TAU / 3.0
			ci.draw_circle(Vector2(cos(a) * 22, -92 + sin(a) * 6), 4, Color(1, 0.9, 0.3))
	if state == State.FROZEN:
		ci.draw_rect(Rect2(-26, -84, 52, 86), Color(0.7, 0.92, 1.0, 0.45))
		ci.draw_rect(Rect2(-26, -84, 52, 86), Color(1, 1, 1, 0.8), false, 2.0)
		ci.draw_line(Vector2(-18, -76), Vector2(-6, -60), Color(1, 1, 1, 0.7), 2.0)
	# carga del arco
	var c2 := bow_charge()
	if c2 > 0.0:
		ci.draw_arc(Vector2(0, -38), 44, -PI / 2, -PI / 2 + TAU * c2, 24,
			Color(1, 0.9, 0.4) if c2 < 1.0 else Color(1, 1, 1), 3.0)
	# ulti lista: chispas
	if ult_meter >= ULT_MAX and not vanished and state != State.DEAD:
		for i in 4:
			var a := t * 2.5 + i * TAU / 4.0
			ci.draw_circle(Vector2(cos(a) * 30, -40 + sin(a * 2.0) * 34), 2.5, Color(col.r, col.g, col.b, 0.9))
	if vanished:
		return
	# Etiqueta "P1" / "CPU" sobre la cabeza
	var font := Game.font_title if Game.font_title else ThemeDB.fallback_font
	var label := "CPU" if is_cpu else "P%d" % player_id
	ci.draw_string_outline(font, Vector2(-30, -104), label, HORIZONTAL_ALIGNMENT_CENTER, 60, 18, 5, Color(0, 0, 0, 0.8))
	ci.draw_string(font, Vector2(-30, -104), label, HORIZONTAL_ALIGNMENT_CENTER, 60, 18, col)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-6, -98), Vector2(6, -98), Vector2(0, -91)]), col)


func _draw_held_item(ci: CanvasItem) -> void:
	var hand := Vector2(facing * 14, -48)
	if held_item == "bat":
		var tex: Texture2D = BAT_TEX
		var rot := -1.1
		if state == State.ATTACK and current_move.get("bat", false):
			var m := current_move
			var k := clampf((attack_time - m["startup"] * 0.5) / (m["startup"] * 0.5 + m["active"]), 0.0, 1.0)
			rot = lerpf(-2.4, 0.3, k)
			hand = Vector2(facing * 20, -44)
		ci.draw_set_transform(hand, rot * facing, Vector2(facing * 2.0, 2.0))
		ci.draw_texture(tex, Vector2(-4, -6))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif held_item == "bow":
		var tex: Texture2D = BOW_TEX
		var frame := 0
		var c := bow_charge()
		if c > 0.0:
			frame = 1 if c < 0.6 else 2
		ci.draw_set_transform(Vector2(facing * 22, -48), 0.0, Vector2(facing * 2.0, 2.0))
		ci.draw_texture_rect_region(tex, Rect2(-6, -14, 20, 28), Rect2(frame * 20, 0, 20, 28))
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		for i in item_ammo:
			ci.draw_rect(Rect2(-14 + i * 10, -126, 6, 6), Color(0.9, 0.8, 0.5))
