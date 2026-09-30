class_name Fighter
extends CharacterBody2D
## El luchador BASE: movimiento, combos, ataques, escudo, esquivas, parry, objetos, bordes...
## Las habilidades únicas de cada personaje están en scripts/characters/<id>.gd
## (esos scripts "heredan" de este y reemplazan do_special, do_up_special, do_down_special,
##  do_charge_special y do_ultimate). Los números están en character_data.gd.

signal died(fighter)
signal hit_landed(strength)
signal ult_used(fighter)

enum State { NORMAL, ATTACK, ACTION, HITSTUN, SHIELD, SHIELD_BREAK, LEDGE, FROZEN, VICTORY, DEAD }

# --- Hoja de sprites: DEBE coincidir con tools/make_sprites.py ---
const FRAME_W := 160
const FRAME_H := 144
const HIP_X := 70
const FEET_Y := 138
const ANIMS := [   # [nombre, cuadros, velocidad(fps), repetir]
	["idle", 6, 8.0, true], ["walk", 8, 11.0, true], ["run", 8, 16.0, true], ["jump", 2, 8.0, false],
	["fall", 2, 6.0, true], ["crouch", 2, 3.0, true], ["shield", 1, 1.0, false], ["dodge", 3, 12.0, true],
	["hurt", 2, 8.0, true], ["ledge", 2, 3.0, true], ["taunt", 6, 7.0, false], ["win", 8, 8.0, true],
	["jab1", 3, 1.0, false], ["jab2", 3, 1.0, false], ["jab3", 4, 1.0, false], ["ftilt", 4, 1.0, false],
	["utilt", 4, 1.0, false], ["dtilt", 4, 1.0, false], ["dash", 4, 1.0, false], ["smash", 5, 1.0, false],
	["nair", 4, 1.0, false], ["fair", 4, 1.0, false], ["bair", 4, 1.0, false], ["uair", 4, 1.0, false],
	["dair", 4, 1.0, false], ["special", 4, 1.0, false], ["upspecial", 3, 10.0, false],
	["downspecial", 4, 1.0, false], ["charge", 4, 1.0, false], ["throw", 3, 1.0, false], ["ult", 4, 1.0, false],
]

const HURT_SIZE := Vector2(30, 76)
const CROUCH_SIZE := Vector2(36, 46)
const BASE_SHIELD := 60.0
const PARRY_WINDOW := 0.15    # qué tan justo hay que presionar para el parry (segundos)
const ULT_MAX := 100.0
const PARRY_METER := 12.0     # cada parry llena esto de la barra de ulti (antes 34: estaba roto)
const HIT_METER := 0.22       # por cada % de daño que haces
const DASH_TAP_TIME := 0.25
const BUFFER_TIME := 0.15
const HOLD_TIME := 0.14       # mantener ATAQUE/ESPECIAL más que esto = versión cargada
const ITEM_TEX := {
	"bat": preload("res://assets/sprites/item_bat.png"), "bow": preload("res://assets/sprites/item_bow.png"),
	"bomb": preload("res://assets/sprites/item_bomb.png"), "sword": preload("res://assets/sprites/item_sword.png"),
	"boomerang": preload("res://assets/sprites/item_boomerang.png"),
}
const ARROW_TEX := preload("res://assets/sprites/item_arrow.png")

# --- Configuración (la pone el escenario antes de añadirlo) ---
var player_id := 1
var char_id := "rojo"
var is_cpu := false
var cpu_level := 1
var stage_info := {"half_width": 450.0, "ground_y": 200.0, "ledges": []}

# --- Estado ---
var data: Dictionary
var moves: Dictionary
var brain: CpuBrain
var state := State.NORMAL
var facing := 1
var percent := 0.0
var stocks := 3
var ult_meter := 0.0
var air_jumps_left := 1
var up_special_used := false
var air_dodge_used := false
var helpless := false
var fast_falling := false
var can_jump_cut := false
var running := false
var crouching := false
var coyote := 0.0
var drop_timer := 0.0
var landing_lag := 0.0
var floor_collider: Object = null
var vanished := false

var invincible_time := 0.0
var intangible_time := 0.0
var armor_time := 0.0         # súper armadura temporal (no sales volando)
var hover_time := 0.0
var hitlag := 0.0
var pending_velocity := Vector2.ZERO
var hitstun := 0.0
var hitstun_total := 0.0
var spin := 0.0
var flip_t := 0.0
var parry_flash := 0.0
var hit_flash := 0.0
var frozen_time := 0.0
var shield_hp := BASE_SHIELD
var shield_flash := 0.0
var shield_break_time := 0.0
var shield_cracks: Array = []
var squash := Vector2.ONE
var star_time := 0.0

var ledge: Dictionary = {}
var ledge_time := 0.0
var ledge_cooldown := 0.0

# ataques
var move: Dictionary = {}
var attack_time := 0.0
var attack_total := 0.0
var attack_in_air := false
var charging := false
var charge_t := 0.0
var charge_mult := 1.0
var hit_idx := -1
var fx_done := false
var combo_next := ""
var combo_window := 0.0
var attack_hold_t := -1.0
var attack_hold_kind := ""
var attack_hold_side := false
var special_hold_t := -1.0
var special_cooldown := 0.0
var hit_list: Array = []

var action := ""
var action_t := 0.0
var act := {}

var held_item := ""
var item_ammo := 0

# modificadores (modo Caos de Cartas)
var mods := {"dmg": 1.0, "kb": 1.0, "speed": 1.0, "jump": 1.0, "weight": 1.0, "gravity": 1.0, "extra_jumps": 0,
	"meter": 1.0, "lifesteal": 0.0, "regen": 0.0, "size": 1.0, "shield": 1.0, "parry": 1.0, "armor": 0.0,
	"thorns": 0.0, "crit": 0.0, "special_cd": 1.0, "special_dmg": 1.0}
var cards: Array = []

# estadísticas
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
var in_special_held := false
var in_shield := false
var in_shield_pressed := false
var in_ult_pressed := false
var in_taunt_pressed := false
var in_throw_pressed := false

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
var _run_dust_t := 0.0


func _ready() -> void:
	add_to_group("fighters")
	data = CharacterData.get_data(char_id)
	moves = CharacterData.moves_for(char_id)
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
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
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
	var rng := RandomNumberGenerator.new()
	rng.seed = player_id * 97
	for i in 12:
		var a := rng.randf() * TAU
		var pts := PackedVector2Array([Vector2(cos(a), sin(a)) * 0.12])
		var r := 0.12
		while r < 1.0:
			r += rng.randf_range(0.16, 0.28)
			a += rng.randf_range(-0.5, 0.5)
			pts.append(Vector2(cos(a), sin(a)) * minf(r, 1.0))
		shield_cracks.append(pts)
	shield_hp = max_shield()


static var _frames_cache := {}


func _build_frames() -> SpriteFrames:
	if _frames_cache.has(char_id):
		return _frames_cache[char_id]
	var tex: Texture2D = load("res://assets/sprites/char_%s.png" % char_id)
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
			at.region = Rect2(col * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H)
			sf.add_frame(a[0], at)
	_frames_cache[char_id] = sf
	return sf


static func anim_frames(anim_name: String) -> int:
	for a in ANIMS:
		if a[0] == anim_name:
			return a[1]
	return 1


# ------------------------------------------------------------------
#  Utilidades (también las usan los scripts de cada personaje)
# ------------------------------------------------------------------
func stat(key: String) -> float:
	var v: float = data[key]
	match key:
		"speed", "walk_speed", "air_speed", "accel", "air_accel":
			v *= mods["speed"]
		"jump_vel", "double_jump_vel":
			v *= mods["jump"]
		"gravity", "fall_speed", "fast_fall_speed":
			v *= mods["gravity"]
		"weight":
			v *= mods["weight"]
	return v


func max_shield() -> float:
	return BASE_SHIELD * mods["shield"]


func size_k() -> float:
	return mods["size"]


func hurtbox() -> Rect2:
	var s := (CROUCH_SIZE if crouching else HURT_SIZE) * size_k()
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
	var k := size_k()
	var center := global_position + Vector2(offset.x * facing, offset.y) * k
	return Rect2(center - size * k / 2.0, size * k)


func make_info(m: Dictionary, dir: int, pos: Vector2) -> Dictionary:
	var angle: float = m.get("angle", 40.0)
	if not is_on_floor() and m.has("air_angle"):
		angle = m["air_angle"]
	var dmg: float = m.get("dmg", 5.0) * mods["dmg"] * charge_mult
	if m.get("special", false):
		dmg *= mods["special_dmg"]
	var crit := false
	if mods["crit"] > 0.0 and randf() < mods["crit"]:
		dmg *= 2.5
		crit = true
	return {"dmg": dmg, "base_kb": m.get("base_kb", 250.0) * mods["kb"] * lerpf(1.0, charge_mult, 0.6),
		"kb_scale": m.get("kb_scale", 5.0) * mods["kb"], "angle": angle, "dir": dir, "pos": pos,
		"sfx": m.get("sfx_hit", ""), "fx": m.get("fx", ""), "crit": crit}


## Golpea a los enemigos dentro de `rect` (cada uno una vez por golpe). Devuelve cuántos.
func hit_rect(rect: Rect2, m: Dictionary, dir := 0) -> int:
	var n := 0
	for f in enemies():
		if hit_list.has(f) or not rect.intersects(f.hurtbox()):
			continue
		hit_list.append(f)
		var d := dir if dir != 0 else facing
		var info := make_info(m, d, rect.get_center().lerp(f.hurtbox().get_center(), 0.5))
		if f.apply_hit(self, info):
			n += 1
	return n


## Golpe en círculo (para explosiones, ondas, etc.)
func hit_circle(center: Vector2, radius: float, m: Dictionary) -> int:
	var n := 0
	for f in enemies():
		if hit_list.has(f):
			continue
		if Projectile.circle_hits_rect(center, radius, f.hurtbox()):
			hit_list.append(f)
			var d := 1 if f.global_position.x >= center.x else -1
			var info := make_info(m, d, f.hurtbox().get_center())
			info["projectile"] = true
			if f.apply_hit(self, info):
				n += 1
	return n


func spawn_projectile(p: Dictionary) -> Projectile:
	var proj := Projectile.new()
	proj.owner_fighter = self
	for k in p:
		proj.set(k, p[k])
	if not p.has("texture"):
		proj.texture = load("res://assets/sprites/proj_%s.png" % char_id)
	if proj.info.has("dmg"):
		proj.info["dmg"] = proj.info["dmg"] * mods["dmg"] * mods["special_dmg"]
	get_parent().add_child(proj)
	return proj


func anim_frame(anim_name: String, frame: int) -> void:
	if sprite.animation != anim_name:
		sprite.play(anim_name)
	sprite.pause()
	sprite.frame = clampi(frame, 0, anim_frames(anim_name) - 1)


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
	charge_mult = 1.0


func end_action(helpless_after := false) -> void:
	if action.begins_with("ult_"):
		invincible_time = minf(invincible_time, 0.25)
	state = State.NORMAL
	action = ""
	vanished = false
	sprite.rotation = 0.0
	if helpless_after and not is_on_floor():
		helpless = true
		Game.play_sfx("helpless", -12.0)


func add_meter(amount: float) -> void:
	var was_full := ult_meter >= ULT_MAX
	ult_meter = minf(ULT_MAX, ult_meter + amount * mods["meter"])
	if not was_full and ult_meter >= ULT_MAX:
		Game.play_sfx("ult_ready")
		Effects.popup(get_parent(), global_position + Vector2(0, -130), "¡ULTI LISTA!", data["color"])


func heal(amount: float) -> void:
	percent = maxf(0.0, percent - amount)


func respawn(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	percent = 0.0
	state = State.NORMAL
	hitstun = 0.0
	hitlag = 0.0
	spin = 0.0
	sprite.rotation = 0.0
	shield_hp = max_shield()
	air_jumps_left = max_air_jumps()
	up_special_used = false
	air_dodge_used = false
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
	star_time = 0.0
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
	if state == State.DEAD or invincible_time > 0.0 or intangible_time > 0.0:
		return
	state = State.FROZEN
	frozen_time = duration
	velocity.x = 0.0
	action = ""
	vanished = false


func max_air_jumps() -> int:
	return 1 + int(mods["extra_jumps"])


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
	intangible_time = maxf(0.0, intangible_time - delta)
	armor_time = maxf(0.0, armor_time - delta)
	special_cooldown = maxf(0.0, special_cooldown - delta)
	coyote = maxf(0.0, coyote - delta)
	drop_timer = maxf(0.0, drop_timer - delta)
	landing_lag = maxf(0.0, landing_lag - delta)
	ledge_cooldown = maxf(0.0, ledge_cooldown - delta)
	parry_flash = maxf(0.0, parry_flash - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	shield_flash = maxf(0.0, shield_flash - delta)
	flip_t = maxf(0.0, flip_t - delta)
	combo_window = maxf(0.0, combo_window - delta)
	if star_time > 0.0:
		star_time -= delta
		invincible_time = maxf(invincible_time, 0.05)
	if mods["regen"] > 0.0:
		percent = maxf(0.0, percent - mods["regen"] * delta)
	if state != State.SHIELD and state != State.SHIELD_BREAK:
		shield_hp = minf(max_shield(), shield_hp + 9.0 * mods["shield"] * delta)
	collision_mask = 1 if drop_timer > 0.0 else 3
	squash = squash.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))


func _poll_input(delta: float) -> void:
	in_up = false
	in_down_pressed = false
	in_left_pressed = false
	in_right_pressed = false
	in_jump_pressed = false
	in_attack_pressed = false
	in_special_pressed = false
	in_shield_pressed = false
	in_ult_pressed = false
	in_taunt_pressed = false
	in_throw_pressed = false
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
		in_special_held = Input.is_action_pressed(p + "special")
		in_shield = Input.is_action_pressed(p + "shield")
		in_shield_pressed = Input.is_action_just_pressed(p + "shield")
		in_ult_pressed = Input.is_action_just_pressed(p + "ult")
		in_taunt_pressed = Input.is_action_just_pressed(p + "taunt")
		in_throw_pressed = Input.is_action_just_pressed(p + "throw")

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
	attack_buffer = BUFFER_TIME if in_attack_pressed else maxf(0.0, attack_buffer - delta)
	special_buffer = BUFFER_TIME if in_special_pressed else maxf(0.0, special_buffer - delta)
	jump_buffer = BUFFER_TIME if in_jump_pressed else maxf(0.0, jump_buffer - delta)
	ult_buffer = BUFFER_TIME if in_ult_pressed else maxf(0.0, ult_buffer - delta)


func _hover(delta: float) -> void:
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
	var max_fall: float = stat("fast_fall_speed") if fast_falling else stat("fall_speed")
	if velocity.y < max_fall:
		velocity.y = minf(velocity.y + stat("gravity") * factor * delta, max_fall)


func ground_friction(delta: float, factor := 1.0) -> void:
	velocity.x = move_toward(velocity.x, 0.0, data["friction"] * factor * delta)


func _ground_move(delta: float) -> void:
	var top: float = stat("speed") if running else stat("walk_speed")
	if absf(in_move) > 0.1:
		var target: float = in_move * top
		var rate: float = stat("accel")
		if signf(velocity.x) != signf(in_move) and absf(velocity.x) > 60.0:
			rate *= 1.8   # dar la vuelta rápido
		velocity.x = move_toward(velocity.x, target, rate * delta)
	else:
		ground_friction(delta)


func air_drift(delta: float, factor := 1.0) -> void:
	var max_s: float = stat("air_speed")
	if absf(in_move) > 0.1:
		var target: float = in_move * max_s
		if absf(velocity.x) <= max_s or signf(velocity.x) != signf(in_move):
			velocity.x = move_toward(velocity.x, target, stat("air_accel") * factor * delta)
		else:
			velocity.x = move_toward(velocity.x, target, 300.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 650.0 * factor * delta)


func _do_jump() -> void:
	if is_on_floor() or coyote > 0.0:
		velocity.y = -stat("jump_vel")
		var air_max: float = stat("air_speed") * 1.15
		velocity.x = clampf(velocity.x, -air_max, air_max)
		can_jump_cut = true
		coyote = 0.0
		floor_snap_length = 0.0
		squash = Vector2(0.82, 1.2)
		Game.play_sfx("jump", -6.0, randf_range(0.95, 1.1))
		Effects.dust(get_parent(), global_position)
	else:
		air_jumps_left -= 1
		velocity.y = -stat("double_jump_vel")
		velocity.x = in_move * stat("air_speed")
		if absf(in_move) > 0.3:
			facing = 1 if in_move > 0.0 else -1
		can_jump_cut = false
		fast_falling = false
		flip_t = 0.35
		squash = Vector2(0.85, 1.15)
		Game.play_sfx("double_jump", -4.0)
		Effects.ring(get_parent(), global_position + Vector2(0, -8), Color(1, 1, 1, 0.8), 38.0)
		Effects.burst(get_parent(), global_position, {"count": 8, "color": Color(1, 1, 1, 0.8), "speed": 120.0,
			"life": 0.35, "size": 3.0, "angle": 90.0, "spread": 70.0})
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

	# --- decidir entre golpe normal y golpe cargado (mantener ATAQUE) ---
	if attack_hold_t >= 0.0:
		attack_hold_t += delta
		ground_friction(delta)
		velocity.y = 0.0
		if not in_attack_held:
			attack_hold_t = -1.0
			if attack_hold_kind == "bat":
				_start_move(CharacterData.BAT_MOVE)
			elif attack_hold_side or absf(in_move) > 0.5:
				if absf(in_move) > 0.3:
					facing = 1 if in_move > 0.0 else -1
				_start_move(moves["ftilt"])
			else:
				_start_move(moves[combo_next if combo_window > 0.0 and combo_next != "" else "jab1"])
		elif attack_hold_t >= HOLD_TIME:
			attack_hold_t = -1.0
			if absf(in_move) > 0.3:
				facing = 1 if in_move > 0.0 else -1
			_start_move(CharacterData.BAT_MOVE if attack_hold_kind == "bat" else moves["smash"], true)
		return
	if special_hold_t >= 0.0:
		special_hold_t += delta
		_action_physics(delta)
		if not in_special_held:
			special_hold_t = -1.0
			special_cooldown = data["special_cooldown"] * mods["special_cd"]
			do_special()
		elif special_hold_t >= HOLD_TIME:
			special_hold_t = -1.0
			special_cooldown = data["special_cooldown"] * mods["special_cd"]
			do_charge_special()
		return

	# ulti
	if ult_buffer > 0.0 and ult_meter >= ULT_MAX:
		ult_buffer = 0.0
		_start_ult()
		return
	# provocar
	if in_taunt_pressed and on_floor:
		begin_action("taunt")
		Game.play_sfx("taunt", -2.0, 0.85 + 0.05 * CharacterData.ORDER.find(char_id))
		return
	# lanzar objeto
	if in_throw_pressed and held_item != "":
		throw_item()
		return
	# escudo / esquivas
	if in_shield:
		if on_floor and shield_hp > 8.0:
			state = State.SHIELD
			running = false
			Game.play_sfx("shield_up", -10.0)
			return
		if not on_floor and in_shield_pressed and not air_dodge_used:
			begin_action("airdodge")
			return
	# especiales
	if special_buffer > 0.0:
		if in_up and not up_special_used:
			special_buffer = 0.0
			up_special_used = true
			do_up_special()
			return
		elif in_down:
			special_buffer = 0.0
			do_down_special()
			return
		elif special_cooldown <= 0.0:
			special_buffer = 0.0
			if absf(in_move) > 0.3:
				facing = 1 if in_move > 0.0 else -1
			special_hold_t = 0.0
			return
	# ataques / objetos
	if attack_buffer > 0.0:
		attack_buffer = 0.0
		if held_item == "" and on_floor and _try_pickup():
			return
		if _item_attack(on_floor):
			return
		if on_floor:
			if running and absf(velocity.x) > stat("walk_speed"):
				_start_move(moves["dash"])
			elif in_up:
				_start_move(moves["utilt"])
			elif in_down:
				_start_move(moves["dtilt"])
			else:
				attack_hold_t = 0.0
				attack_hold_kind = ""
				attack_hold_side = absf(in_move) > 0.5
				if attack_hold_side:
					facing = 1 if in_move > 0.0 else -1
				running = false
		else:
			var side := in_move * facing
			if in_up:
				_start_move(moves["uair"])
			elif in_down:
				_start_move(moves["dair"])
			elif side > 0.3:
				_start_move(moves["fair"])
			elif side < -0.3:
				_start_move(moves["bair"])
			else:
				_start_move(moves["nair"])
		return

	# saltar
	if jump_buffer > 0.0 and _can_jump():
		jump_buffer = 0.0
		_do_jump()
		on_floor = false
	if can_jump_cut and not in_jump_held and velocity.y < -300.0:
		velocity.y *= 0.5
		can_jump_cut = false

	# atravesar plataformas
	if on_floor and in_down_pressed and _on_oneway():
		drop_timer = 0.25
		position.y += 2.0
		on_floor = false

	if on_floor:
		if dash_request > 0.0:
			dash_request = 0.0
			running = true
			facing = dash_dir
			var burst: float = stat("speed") * 1.1
			if absf(velocity.x) < burst or signf(velocity.x) != dash_dir:
				velocity.x = dash_dir * burst
			Game.play_sfx("dash", -6.0)
			Effects.dust(get_parent(), global_position)
			squash = Vector2(1.15, 0.9)
		if running and (absf(in_move) < 0.1 or signf(in_move) != facing):
			running = false
			if absf(velocity.x) > stat("walk_speed"):
				Effects.dust(get_parent(), global_position + Vector2(facing * 10, 0))
		crouching = in_down and absf(in_move) < 0.3
		if crouching:
			ground_friction(delta, 1.5)
			if not was_crouching:
				Game.play_sfx("crouch", -14.0)
				squash = Vector2(1.1, 0.9)
		else:
			_ground_move(delta)
			if absf(in_move) > 0.1:
				facing = 1 if in_move > 0.0 else -1
		velocity.y = 0.0
		if running:
			_run_dust_t -= delta
			if _run_dust_t <= 0.0:
				_run_dust_t = 0.12
				Effects.burst(get_parent(), global_position, {"count": 2, "color": Color(1, 1, 1, 0.5),
					"speed": 60.0, "life": 0.3, "size": 4.0, "angle": 90.0 - facing * 60.0, "spread": 30.0,
					"gravity": -80.0})
	else:
		running = false
		air_drift(delta)
		if in_down_pressed and velocity.y > -80.0 and not fast_falling:
			fast_falling = true
			Effects.ring(get_parent(), global_position + Vector2(0, -40), Color(1, 1, 1, 0.6), 16.0)
		apply_gravity(delta)
		_check_ledge_grab()


# ------------------------------------------------------------------
#  Ataques normales
# ------------------------------------------------------------------
func _start_move(m: Dictionary, charge := false) -> void:
	move = m
	state = State.ATTACK
	attack_time = 0.0
	attack_total = m["startup"] + m["active"] + m["recovery"]
	attack_in_air = not is_on_floor()
	hit_list.clear()
	hit_idx = -1
	fx_done = false
	crouching = false
	charging = charge
	charge_t = 0.0
	charge_mult = 1.0
	combo_window = 0.0
	combo_next = ""
	anim_frame(m.get("anim", m.get("name", "jab1")), 0)
	if m.has("lunge"):
		velocity.x = facing * m["lunge"]
		running = false
	elif not attack_in_air:
		velocity.x *= 0.35
	if charging:
		Game.play_sfx("charge", -8.0)


func _state_attack(delta: float) -> void:
	var m := move
	var anim: String = m.get("anim", m.get("name", "jab1"))
	if charging:
		# cargando el golpe (mantener ATAQUE)
		charge_t += delta
		anim_frame(anim, 0)
		ground_friction(delta)
		velocity.y = 0.0 if is_on_floor() else velocity.y
		if not is_on_floor():
			apply_gravity(delta)
		if Engine.get_physics_frames() % 5 == 0:
			Effects.burst(get_parent(), global_position + Vector2(0, -40), {"count": 2, "color": data["fx_color"],
				"speed": -90.0, "life": 0.3, "size": 3.0, "spread": 180.0, "radius": 50.0})
		if not in_attack_held or charge_t >= m.get("max_charge", 1.0):
			charging = false
			charge_mult = 1.0 + minf(charge_t, m.get("max_charge", 1.0)) * m.get("charge_bonus", 0.5)
			attack_time = 0.0
		return

	attack_time += delta
	var t := attack_time
	var su: float = m["startup"]
	var ac: float = m["active"]
	if t >= su and not fx_done:
		fx_done = true
		_attack_fx(m)
		if m.has("boost"):
			velocity.y = m["boost"]
		if m.get("proj", false):
			_move_projectile(m)
		if m.get("sword", false):
			item_ammo -= 1
	if t >= su and t < su + ac:
		var n: int = m.get("hits", 1)
		var idx := int((t - su) / ac * n)
		if idx != hit_idx:
			hit_idx = idx
			hit_list.clear()
		var hm := m
		if n > 1 and idx < n - 1:
			hm = m.duplicate()
			hm["base_kb"] = 60.0
			hm["kb_scale"] = 0.5
			hm["angle"] = 80.0
		var dir := -facing if m.get("back", false) else facing
		hit_rect(box(m["box_pos"], m["box_size"]), hm, dir)
	var nf := anim_frames(anim)
	var f := 0
	if t >= su + ac:
		f = nf - 1
	elif t >= su:
		f = 1 + clampi(int((t - su) / ac * (nf - 2)), 0, nf - 3) if nf > 2 else 1
	anim_frame(anim, f)
	# el combo: presionar ATAQUE otra vez encadena el siguiente golpe
	if m.has("next") and attack_buffer > 0.0 and t >= su + ac * 0.5:
		attack_buffer = 0.0
		var nxt: String = m["next"]
		_start_move(CharacterData.SWORD_MOVES[nxt] if m.get("sword", false) else moves[nxt])
		return
	if is_on_floor():
		if attack_in_air:
			state = State.NORMAL
			landing_lag = m.get("landing_lag", 0.08)
			squash = Vector2(1.2, 0.82)
			Effects.dust(get_parent(), global_position)
			return
		ground_friction(delta, 0.6 if m.has("lunge") else 1.0)
		velocity.y = 0.0
	else:
		air_drift(delta, 0.7)
		apply_gravity(delta)
	if attack_time >= attack_total:
		state = State.NORMAL
		charge_mult = 1.0
		if m.has("next"):
			combo_next = m["next"]
			combo_window = 0.25
		if m.get("sword", false) and item_ammo <= 0 and held_item == "sword":
			held_item = ""
			Effects.popup(get_parent(), global_position + Vector2(0, -110), "¡Espada rota!", Color(0.7, 1, 0.8), 0.8)


func _attack_fx(m: Dictionary) -> void:
	var col: Color = data["fx_color"]
	if m.get("bat", false):
		col = Color(1, 0.95, 0.7)
	elif m.get("sword", false):
		col = Color(0.5, 1.0, 0.7)
	if m.has("arc"):
		var a: Array = m["arc"]
		var width := 10.0 if m.get("weapon", false) or m.get("sword", false) or m.get("bat", false) else 7.0
		Effects.swoosh(self, a[0], a[1], a[2] * size_k(), col, m["active"] + 0.1, width * charge_mult,
			Vector2(0, -40 if a[2] < 60 else -44))
	Game.play_sfx(m.get("sfx", "swing"), -6.0, randf_range(0.9, 1.1) / sqrt(charge_mult))
	match m.get("fx", ""):
		"fire":
			Effects.burst(get_parent(), box(m["box_pos"], m["box_size"]).get_center(), {"count": 10,
				"color": Color(1, 0.5, 0.1), "speed": 160.0, "life": 0.4, "size": 5.0, "gravity": -200.0})
		"elec":
			Effects.lightning(get_parent(), global_position + Vector2(0, -40), box(m["box_pos"], m["box_size"]).get_center(),
				Color(1, 0.95, 0.4))
			Game.play_sfx("zap", -12.0, randf_range(1.0, 1.3))
		"ice":
			Effects.burst(get_parent(), box(m["box_pos"], m["box_size"]).get_center(), {"count": 8,
				"color": Color(0.75, 0.95, 1.0), "speed": 140.0, "life": 0.4, "size": 3.0})
		"shadow":
			Effects.burst(get_parent(), box(m["box_pos"], m["box_size"]).get_center(), {"count": 8,
				"color": Color(0.4, 0.15, 0.6, 0.9), "speed": 90.0, "life": 0.5, "size": 6.0, "gravity": -60.0})
		"magic":
			Effects.burst(get_parent(), box(m["box_pos"], m["box_size"]).get_center(), {"count": 8,
				"color": Color(0.6, 1.0, 0.85), "speed": 110.0, "life": 0.5, "size": 3.0, "star": true})
		"rock":
			Effects.burst(get_parent(), box(m["box_pos"], m["box_size"]).get_center(), {"count": 8,
				"color": Color(0.55, 0.45, 0.35), "speed": 200.0, "life": 0.5, "size": 5.0, "gravity": 700.0})


func _move_projectile(m: Dictionary) -> void:
	spawn_projectile({"velocity": Vector2(facing * 900.0, 0), "radius": 8.0, "lifetime": 0.35,
		"global_position": global_position + Vector2(facing * 40, -48), "sprite_scale": 0.8,
		"info": {"dmg": 3.0, "base_kb": 120.0, "kb_scale": 2.0, "angle": 20.0}})
	Game.play_sfx("laser", -8.0)


# ------------------------------------------------------------------
#  Acciones (especiales, ulti, provocar, esquivas, arco...)
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
		"airdodge":
			_action_airdodge(delta)
		"roll":
			_action_roll(delta)
		"spotdodge":
			anim_frame("dodge", 0)
			ground_friction(delta, 2.0)
			velocity.y = 0.0
			if action_t < 0.28:
				intangible_time = maxf(intangible_time, 0.02)
			if action_t >= 0.34:
				end_action()
		"throw":
			anim_frame("throw", mini(int(action_t / 0.08), 2))
			_action_physics(delta)
			if action_t >= 0.25:
				end_action()
		_:
			char_action(action, action_t, delta)


func _action_airdodge(delta: float) -> void:
	if action_t < delta * 1.5:
		air_dodge_used = true
		var d := input_dir(Vector2.ZERO)
		velocity = d * 620.0 if d != Vector2.ZERO else velocity * 0.2
		Game.play_sfx("roll", -6.0)
		fast_falling = false
	anim_frame("dodge", 0)
	if action_t < 0.3:
		intangible_time = maxf(intangible_time, 0.02)
		velocity = velocity.move_toward(Vector2.ZERO, 1400.0 * delta)
		if Engine.get_physics_frames() % 3 == 0:
			Effects.afterimage(get_parent(), self, Color(1, 1, 1, 0.4))
	else:
		apply_gravity(delta)
		air_drift(delta, 0.5)
	if is_on_floor() and action_t > 0.05:
		end_action()
		landing_lag = 0.06
		return
	if action_t >= 0.45:
		end_action()


func _action_roll(delta: float) -> void:
	var dir: int = act.get("dir", facing)
	var k := action_t / 0.36
	anim_frame("dodge", mini(int(k * 3.0), 2))
	sprite.rotation = 0.0
	velocity.x = dir * 460.0 * (1.0 - k)
	velocity.y = 0.0
	if action_t > 0.04 and action_t < 0.3:
		intangible_time = maxf(intangible_time, 0.02)
		if Engine.get_physics_frames() % 3 == 0:
			Effects.afterimage(get_parent(), self, Color(1, 1, 1, 0.35))
	if action_t >= 0.36 or not is_on_floor():
		end_action()


## Especial neutral (tocar ESPECIAL). Los personajes lo reemplazan.
func do_special() -> void:
	begin_action("fireball")


## Especial cargado (mantener ESPECIAL). Por defecto = especial normal.
func do_charge_special() -> void:
	do_special()


## Recuperación (arriba + especial).
func do_up_special() -> void:
	begin_action("recover")


## Abajo + especial.
func do_down_special() -> void:
	do_special()


## Ulti.
func do_ultimate() -> void:
	begin_action("recover")


## Para especiales cargados: devuelve true MIENTRAS se sigue cargando (mantener ESPECIAL).
## Al soltar (o al llegar al máximo) guarda la carga final (0..1) en act["charge"].
func hold_charge(t: float, max_t := 1.0) -> bool:
	if act.has("released"):
		return false
	act["charge"] = clampf(t / max_t, 0.0, 1.0)
	if in_special_held and t < max_t:
		anim_frame("charge", int(t * 8.0) % 2)
		if Engine.get_physics_frames() % 5 == 0:
			Effects.burst(get_parent(), global_position + Vector2(facing * 20, -44), {"count": 2,
				"color": data["fx_color"], "speed": -80.0, "life": 0.3, "size": 3.0, "radius": 50.0})
		return true
	act["released"] = t
	return false


## Contraataque (lo usa KAEDE). Devuelve true si el golpe fue contrarrestado.
func try_counter(_attacker: Fighter, _info: Dictionary) -> bool:
	return false


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
	invincible_time = maxf(invincible_time, 4.0)   # la ulti no se puede interrumpir
	Game.play_sfx("ult")
	Effects.popup(get_parent(), global_position + Vector2(0, -130), "¡ULTI!", data["color"], 1.6)
	ult_used.emit(self)
	do_ultimate()


# ------------------------------------------------------------------
#  Objetos
# ------------------------------------------------------------------
func _try_pickup() -> bool:
	for it in get_tree().get_nodes_in_group("items"):
		if it.can_pickup() and it.global_position.distance_to(global_position + Vector2(0, -10)) < 64.0:
			it.picked_by(self)
			return true
	return false


## Devuelve true si el ataque se usó con un objeto.
func _item_attack(on_floor: bool) -> bool:
	match held_item:
		"bat":
			if on_floor:
				attack_hold_t = 0.0
				attack_hold_kind = "bat"
				running = false
			else:
				_start_move(CharacterData.BAT_MOVE)
			return true
		"sword":
			_start_move(CharacterData.SWORD_MOVES["sword1"])
			return true
		"bow":
			begin_action("bow")
			Game.play_sfx("bow_draw", -4.0)
			return true
		"bomb", "boomerang":
			throw_item()
			return true
	return false


## Lanza el objeto que tienes en la mano (tecla LANZAR, o ATAQUE con bomba/bumerán).
func throw_item() -> void:
	if held_item == "":
		return
	var lift := -0.03 if held_item == "boomerang" else -0.2
	var dir := Vector2(facing, lift)
	if in_up:
		dir = Vector2(0.15 * facing, -1.0)
	elif in_down:
		dir = Vector2(0.1 * facing, 1.0)
	elif absf(in_move) > 0.3:
		facing = 1 if in_move > 0.0 else -1
		dir = Vector2(facing, lift)
	var it := Item.new()
	it.kind = held_item
	it.ammo = item_ammo
	it.global_position = global_position + Vector2(facing * 24, -50)
	get_parent().add_child(it)
	var speed := 1050.0 if not (in_down and is_on_floor()) else 0.0
	it.throw(self, dir.normalized() * speed)
	held_item = ""
	begin_action("throw")
	Game.play_sfx("throw")


func bow_charge() -> float:
	return clampf(action_t / 0.9, 0.0, 1.0) if action == "bow" and not act.has("fired") else 0.0


func _action_bow(delta: float) -> void:
	anim_frame("special", 1 if not act.has("fired") else 3)
	_action_physics(delta, 0.4)
	if absf(in_move) > 0.1 and is_on_floor():
		velocity.x = in_move * 60.0
	if not act.has("fired"):
		if action_t > 0.12 and (not in_attack_held or action_t > 2.5):
			var c := clampf(action_t / 0.9, 0.0, 1.0)
			act["fired"] = action_t
			item_ammo -= 1
			spawn_projectile({"velocity": Vector2(facing * (560.0 + 950.0 * c), -40.0 * (1.0 - c)),
				"gravity": 900.0 * (1.0 - c * 0.6), "texture": ARROW_TEX, "hframes": 1, "rotate_to_velocity": true,
				"radius": 10.0, "lifetime": 2.0, "solid": true, "sprite_scale": 1.0, "trail": Color(1, 1, 1, 0.5),
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
			velocity.x += in_move * 320.0 * delta
		apply_gravity(delta, 0.8)
		if spin > 0.0 and velocity.length() > 500.0 and Engine.get_physics_frames() % 2 == 0:
			Effects.burst(get_parent(), global_position + Vector2(0, -38), {"count": 1, "color": Color(1, 1, 1, 0.6),
				"speed": 10.0, "life": 0.4, "size": 7.0})
	var early := hitstun < hitstun_total * 0.3 and (jump_buffer > 0.0 or special_buffer > 0.0 or attack_buffer > 0.0)
	if hitstun <= 0.0 or early:
		state = State.NORMAL
		spin = 0.0
		sprite.rotation = 0.0


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
	return since_tap[toward] <= PARRY_WINDOW * mods["parry"] and mash_heat < 3.5


func _do_parry(attacker: Fighter, info: Dictionary) -> void:
	parries += 1
	since_tap[-1] = 99.0
	since_tap[1] = 99.0
	pending_velocity = velocity
	hitlag = 0.1
	invincible_time = 0.25
	parry_flash = 0.3
	if attacker and not info.get("projectile", false):
		attacker.hitlag = maxf(attacker.hitlag, 0.4)
		attacker.pending_velocity = attacker.velocity
	add_meter(PARRY_METER)
	if mods["parry"] > 1.0:
		heal(5.0)
	Game.play_sfx("parry")
	Effects.popup(get_parent(), global_position + Vector2(0, -110), "¡PARRY!", Color(0.45, 0.85, 1.0), 1.2)
	Effects.ring(get_parent(), global_position + Vector2(0, -38), Color(0.6, 0.9, 1.0), 80.0)
	Effects.burst(get_parent(), global_position + Vector2(0, -38), {"count": 16, "color": Color(0.7, 0.95, 1.0),
		"speed": 260.0, "life": 0.4, "size": 3.0, "star": true})


## Devuelve true si el golpe "conectó" (incluye escudo y parry). `attacker` puede ser null.
func apply_hit(attacker: Fighter, info: Dictionary) -> bool:
	if state == State.DEAD or state == State.VICTORY or invincible_time > 0.0 or intangible_time > 0.0:
		return false
	var dir: int = info["dir"]
	var melee: bool = not info.get("projectile", false)

	if _can_parry(dir):
		_do_parry(attacker, info)
		return true
	if try_counter(attacker, info):
		return true

	if state == State.SHIELD:
		shield_hp -= info["dmg"] * 1.5 + 2.0
		shield_flash = 0.15
		velocity.x = dir * 150.0
		hitlag = 0.06
		pending_velocity = velocity
		Game.play_sfx("shield_crack" if shield_hp < max_shield() * 0.5 else "shield")
		Effects.spark(get_parent(), info["pos"], 0.35, Color(0.6, 0.85, 1.0))
		Effects.burst(get_parent(), info["pos"], {"count": 5, "color": Color(0.8, 0.95, 1.0), "speed": 150.0,
			"life": 0.3, "size": 3.0})
		if attacker and melee:
			attacker.velocity.x = -dir * 180.0
		if shield_hp <= 0.0:
			_break_shield()
		return true

	var dmg: float = info["dmg"]
	percent = minf(999.0, percent + dmg)
	hit_flash = 0.12
	if attacker:
		last_hit_by = attacker
		attacker.damage_dealt += dmg
		attacker.add_meter(dmg * HIT_METER)
		if attacker.mods["lifesteal"] > 0.0:
			attacker.heal(dmg * attacker.mods["lifesteal"])
		if mods["thorns"] > 0.0 and melee:
			attacker.percent += dmg * mods["thorns"]
	if info.get("crit", false):
		Effects.popup(get_parent(), global_position + Vector2(0, -120), "¡CRÍTICO!", Color(1, 0.3, 0.2), 1.0)

	# súper armadura: aguanta golpes débiles sin salir volando
	var armored: bool = (mods["armor"] > 0.0 and dmg < mods["armor"]) or (armor_time > 0.0 and dmg < 20.0)
	if state == State.ATTACK and move.get("armor", false) and attack_time < move["startup"] + move["active"]:
		armored = armored or dmg < 16.0
	if armored:
		hitlag = 0.06
		pending_velocity = velocity
		Game.play_sfx("hit", -4.0, 0.8)
		Effects.spark(get_parent(), info["pos"], 0.5, Color(1, 0.7, 0.3))
		return true

	var kb: float = (info["base_kb"] + info["kb_scale"] * percent) * (100.0 / stat("weight"))
	if crouching:
		kb *= 0.85
	var angle := deg_to_rad(info["angle"])
	var launch := Vector2(cos(angle) * dir, -sin(angle)) * kb

	if state == State.ACTION:
		action = ""
		vanished = false
	attack_hold_t = -1.0
	special_hold_t = -1.0
	charging = false
	state = State.HITSTUN
	hitstun = clampf(0.1 + kb * 0.00032, 0.1, 0.95)
	hitstun_total = hitstun
	pending_velocity = launch
	hitlag = clampf(0.035 + dmg * 0.0045, 0.04, 0.18)
	if info.get("fx", "") == "elec":
		hitlag += 0.05
	if attacker and melee:
		attacker.hitlag = maxf(attacker.hitlag, hitlag)
		attacker.pending_velocity = attacker.velocity
	facing = -dir
	fast_falling = false
	can_jump_cut = false
	running = false
	crouching = false
	helpless = false
	air_jumps_left = maxi(air_jumps_left, 1)
	up_special_used = false
	air_dodge_used = false
	floor_snap_length = 0.0 if launch.y < 0.0 else 8.0
	hover_time = 0.0
	spin = 1.0 if kb > 700.0 else 0.0
	sprite.play("hurt")
	squash = Vector2(0.8, 1.2)

	var strength := kb / 100.0
	var sfx: String = info.get("sfx", "")
	if sfx == "homerun" and kb < 900.0:
		sfx = "hit_strong"
	if sfx == "":
		sfx = "hit_strong" if kb > 650.0 else "hit"
	Game.play_sfx(sfx, -2.0, randf_range(0.92, 1.08))
	var col := Color(1.0, 0.95, 0.6)
	match info.get("fx", ""):
		"fire": col = Color(1, 0.55, 0.2)
		"elec": col = Color(1, 1, 0.5)
		"ice": col = Color(0.7, 0.95, 1)
		"shadow": col = Color(0.75, 0.4, 1)
		"magic": col = Color(0.5, 1, 0.85)
	Effects.hit(get_parent(), info["pos"], clampf(strength / 8.0, 0.4, 2.0), col, dir)
	hit_landed.emit(strength)
	return true


## Daño sin empuje (por ejemplo, mientras está congelado).
func take_damage(dmg: float, attacker: Fighter = null) -> void:
	percent = minf(999.0, percent + dmg)
	hit_flash = 0.1
	if attacker:
		attacker.damage_dealt += dmg
		last_hit_by = attacker
	Effects.spark(get_parent(), global_position + Vector2(0, -40), 0.4, Color(0.8, 0.9, 1.0))


func _state_shield(delta: float) -> void:
	ground_friction(delta)
	velocity.y = 0.0
	shield_hp -= 11.0 * delta
	if jump_buffer > 0.0 and _can_jump():
		jump_buffer = 0.0
		state = State.NORMAL
		_do_jump()
		return
	# esquivas: escudo + izquierda/derecha = rodar, escudo + abajo = esquiva en el sitio
	if in_left_pressed or in_right_pressed:
		begin_action("roll")
		act["dir"] = -1 if in_left_pressed else 1
		Game.play_sfx("roll", -6.0)
		return
	if in_down_pressed:
		begin_action("spotdodge")
		Game.play_sfx("roll", -8.0, 1.3)
		return
	if (attack_buffer > 0.0 or in_throw_pressed) and held_item != "":
		attack_buffer = 0.0
		state = State.NORMAL
		throw_item()
		return
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
		shield_hp = max_shield() * 0.5
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
		if fmod(Time.get_ticks_msec() / 1000.0, 1.4) < delta * 1.5:
			velocity.y = -420.0
			floor_snap_length = 0.0
			squash = Vector2(0.85, 1.15)
	if sprite.animation != "win":
		sprite.play("win")


# ------------------------------------------------------------------
#  Bordes del escenario
# ------------------------------------------------------------------
func _hang_pos(l: Dictionary) -> Vector2:
	var p: Vector2 = l["pos"]
	return Vector2(p.x + l["side"] * 15.0, p.y + 70.0)


func _check_ledge_grab() -> void:
	if ledge_cooldown > 0.0 or velocity.y < 0.0:
		return
	for l in stage_info.get("ledges", []):
		var hp := _hang_pos(l)
		if absf(global_position.x - hp.x) < 30.0 and absf(global_position.y - hp.y) < 44.0:
			_grab_ledge(l)
			return


func _grab_ledge(l: Dictionary) -> void:
	state = State.LEDGE
	ledge = l
	ledge_time = 0.0
	global_position = _hang_pos(l)
	velocity = Vector2.ZERO
	facing = -int(l["side"])
	air_jumps_left = max_air_jumps()
	up_special_used = false
	air_dodge_used = false
	helpless = false
	fast_falling = false
	invincible_time = maxf(invincible_time, 0.5)
	sprite.play("ledge")
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
		velocity = Vector2(facing * 150.0, -stat("jump_vel"))
		ledge_cooldown = 0.4
		floor_snap_length = 0.0
		Game.play_sfx("jump", -6.0)
	elif in_up or in_move * facing > 0.5 or attack_buffer > 0.0:
		attack_buffer = 0.0
		state = State.NORMAL
		global_position = Vector2(p.x - side * 28.0, p.y - 1.0)
		velocity = Vector2.ZERO
		invincible_time = maxf(invincible_time, 0.2)
		squash = Vector2(1.1, 0.9)
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
			squash = Vector2(1.18, 0.84)
			Effects.dust(get_parent(), global_position)
			if helpless:
				landing_lag = 0.12
		air_jumps_left = max_air_jumps()
		up_special_used = false
		air_dodge_used = false
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
	var k := size_k()
	sprite.flip_h = facing < 0
	sprite.scale = Vector2(squash.x, squash.y) * k
	sprite.position = Vector2((HIP_X - FRAME_W / 2.0) * -1.0 * facing * k * squash.x,
		(FRAME_H / 2.0 - FEET_Y) * k * squash.y)
	sprite.visible = not vanished

	var col := Color.WHITE
	if hit_flash > 0.0:
		col = Color(2.2, 2.2, 2.2)
	elif parry_flash > 0.0:
		col = Color(0.7, 1.0, 1.8)
	elif state == State.FROZEN:
		col = Color(0.6, 0.9, 1.4)
	elif star_time > 0.0:
		col = Color.from_hsv(fmod(Time.get_ticks_msec() / 400.0, 1.0), 0.5, 1.6)
	elif charging or attack_hold_t > HOLD_TIME * 0.5:
		col = Color(1.3, 1.25, 1.1) if Engine.get_physics_frames() % 6 < 3 else Color.WHITE
	elif helpless and not is_on_floor():
		col = Color(0.55, 0.55, 0.75)
	if (invincible_time > 0.0 and star_time <= 0.0 and state != State.VICTORY) or intangible_time > 0.0:
		col.a = 0.45 + 0.4 * sin(Time.get_ticks_msec() * 0.03)
	sprite.modulate = col

	if hitlag > 0.0:
		return
	var anim := ""
	var speed := 1.0
	match state:
		State.NORMAL:
			if attack_hold_t >= 0.0:
				anim_frame("smash" if attack_hold_kind != "bat" else "smash", 0)
			elif special_hold_t >= 0.0:
				anim_frame("charge", 0)
			elif is_on_floor():
				if landing_lag > 0.0 or crouching:
					anim = "crouch"
				elif absf(velocity.x) > 30.0 and absf(in_move) > 0.1:
					if running or absf(velocity.x) > stat("walk_speed") * 1.1:
						anim = "run"
						speed = clampf(absf(velocity.x) / stat("speed"), 0.6, 1.3)
					else:
						anim = "walk"
						speed = clampf(absf(velocity.x) / stat("walk_speed"), 0.5, 1.3)
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
		ci.draw_rect(Rect2(-44, 4, 88, 8), Color(0.75, 0.9, 1.0, 0.9))
		ci.draw_rect(Rect2(-44, 4, 88, 3), Color(1, 1, 1, 0.9))
	if held_item != "" and not vanished and state != State.DEAD:
		_draw_held_item(ci)
	if state == State.SHIELD:
		var k := clampf(shield_hp / max_shield(), 0.0, 1.0)
		var r := (30.0 + 30.0 * k) * size_k()
		var c := col.lerp(Color(1, 0.25, 0.2), 1.0 - k)
		var alpha := 0.35 if k > 0.25 or fmod(t, 0.2) < 0.1 else 0.15
		if shield_flash > 0.0:
			c = c.lerp(Color.WHITE, 0.6)
			alpha = 0.6
		var center := Vector2(0, -40)
		ci.draw_circle(center, r, Color(c.r, c.g, c.b, alpha))
		ci.draw_arc(center, r, 0, TAU, 48, Color(1, 1, 1, 0.8), 2.0)
		ci.draw_arc(center, r * 0.72, -2.4, -1.4, 12, Color(1, 1, 1, 0.4), 3.0)
		var cracks := int((1.0 - k) * shield_cracks.size() * 1.1)
		for i in mini(cracks, shield_cracks.size()):
			var pts: PackedVector2Array = shield_cracks[i]
			var scaled := PackedVector2Array()
			for p in pts:
				scaled.append(center + p * r)
			ci.draw_polyline(scaled, Color(1, 1, 1, 0.9), 1.6)
	if state == State.SHIELD_BREAK:
		for i in 3:
			var a := t * 8.0 + i * TAU / 3.0
			ci.draw_circle(Vector2(cos(a) * 22, -98 + sin(a) * 6), 4, Color(1, 0.9, 0.3))
	if state == State.FROZEN:
		ci.draw_rect(Rect2(-28, -88, 56, 90), Color(0.7, 0.92, 1.0, 0.45))
		ci.draw_rect(Rect2(-28, -88, 56, 90), Color(1, 1, 1, 0.8), false, 2.0)
		ci.draw_line(Vector2(-18, -78), Vector2(-6, -60), Color(1, 1, 1, 0.7), 2.0)
	# carga (smash / especial / arco)
	var charge := -1.0
	if charging:
		charge = clampf(charge_t / move.get("max_charge", 1.0), 0.0, 1.0)
	elif attack_hold_t >= 0.0:
		charge = 0.0
	elif bow_charge() > 0.0:
		charge = bow_charge()
	elif action.begins_with("charge") and act.has("charge"):
		charge = act["charge"]
	if charge >= 0.0:
		var cc: Color = data["fx_color"] if charge < 1.0 else Color.WHITE
		ci.draw_arc(Vector2(0, -40), 48, -PI / 2, -PI / 2 + TAU * maxf(charge, 0.02), 32, cc, 4.0)
		if charge >= 1.0:
			ci.draw_arc(Vector2(0, -40), 52 + sin(t * 20.0) * 3.0, 0, TAU, 32, Color(1, 1, 1, 0.5), 2.0)
	if ult_meter >= ULT_MAX and not vanished and state != State.DEAD:
		for i in 5:
			var a := t * 2.5 + i * TAU / 5.0
			ci.draw_circle(Vector2(cos(a) * 32, -42 + sin(a * 2.0) * 36), 2.5, Color(col.r, col.g, col.b, 0.9))
	if star_time > 0.0:
		for i in 6:
			var a := t * 5.0 + i * TAU / 6.0
			ci.draw_circle(Vector2(cos(a) * 36, -42 + sin(a) * 40), 3.0, Color.from_hsv(fmod(t + i * 0.15, 1.0), 0.6, 1.0))
	if vanished:
		return
	var font := Game.font_title if Game.font_title else ThemeDB.fallback_font
	var label := "CPU" if is_cpu else "P%d" % player_id
	var y := -112.0 * size_k()
	ci.draw_string_outline(font, Vector2(-30, y), label, HORIZONTAL_ALIGNMENT_CENTER, 60, 18, 5, Color(0, 0, 0, 0.8))
	ci.draw_string(font, Vector2(-30, y), label, HORIZONTAL_ALIGNMENT_CENTER, 60, 18, col)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-6, y + 6), Vector2(6, y + 6), Vector2(0, y + 13)]), col)


func _draw_held_item(ci: CanvasItem) -> void:
	var hand := Vector2(facing * 16, -52)
	match held_item:
		"bat", "sword":
			var tex: Texture2D = ITEM_TEX[held_item]
			var rot := -1.1
			if state == State.ATTACK and (move.get("bat", false) or move.get("sword", false)):
				if charging:
					rot = -2.5
				else:
					var k := clampf((attack_time - move["startup"] * 0.5) / (move["startup"] * 0.5 + move["active"]), 0.0, 1.0)
					rot = lerpf(-2.4, 0.3, k)
				hand = Vector2(facing * 22, -48)
			elif attack_hold_t >= 0.0:
				rot = -2.5
			ci.draw_set_transform(hand, rot * facing, Vector2(facing, 1.0))
			ci.draw_texture(tex, Vector2(-8, -12))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"bow":
			var tex: Texture2D = ITEM_TEX["bow"]
			var frame := 0
			var c := bow_charge()
			if c > 0.0:
				frame = 1 if c < 0.6 else 2
			ci.draw_set_transform(Vector2(facing * 22, -52), 0.0, Vector2(facing, 1.0))
			ci.draw_texture_rect_region(tex, Rect2(-10, -28, 40, 56), Rect2(frame * 40, 0, 40, 56))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for i in item_ammo:
				ci.draw_rect(Rect2(-14 + i * 10, -134, 6, 6), Color(0.9, 0.8, 0.5))
		"bomb", "boomerang":
			var tex: Texture2D = ITEM_TEX[held_item]
			ci.draw_set_transform(hand + Vector2(0, -6), 0.0, Vector2(facing, 1.0))
			if held_item == "bomb":
				ci.draw_texture_rect_region(tex, Rect2(-20, -20, 40, 40), Rect2(40 * (int(Time.get_ticks_msec() / 150) % 2), 0, 40, 40))
			else:
				ci.draw_texture(tex, Vector2(-18, -18))
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
