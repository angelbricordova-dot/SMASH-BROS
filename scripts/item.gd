class_name Item
extends CharacterBody2D
## Objeto que cae del cielo. Acércate y presiona ATAQUE para recogerlo.
## Tecla LANZAR (C / J) para tirarlo: ¡le hace daño al rival!
##  - bat:       bate. ATAQUE = batazo; MANTÉN ATAQUE para cargar un home run.
##  - bow:       arco (estilo Minecraft) con 3 flechas. Mantén ATAQUE para tensar.
##  - sword:     espada de energía: combo de 2 cortes de gran alcance (se rompe tras 12 golpes).
##  - bomb:      bomba: al lanzarla explota al tocar algo.
##  - boomerang: bumerán: va y vuelve a tu mano.
##  - heart:     corazón: cura 40% al recogerlo.
##  - star:      estrella: invencible y más rápido durante 8 segundos.

const LIFETIME := 20.0
const KINDS := {"bat": 3, "bow": 2, "sword": 2, "bomb": 3, "boomerang": 2, "heart": 1, "star": 1}
const THROW_DMG := {"bat": 12.0, "bow": 8.0, "sword": 13.0, "bomb": 20.0, "boomerang": 9.0}
const TEX := {
	"bat": preload("res://assets/sprites/item_bat.png"), "bow": preload("res://assets/sprites/item_bow.png"),
	"sword": preload("res://assets/sprites/item_sword.png"), "bomb": preload("res://assets/sprites/item_bomb.png"),
	"boomerang": preload("res://assets/sprites/item_boomerang.png"), "heart": preload("res://assets/sprites/item_heart.png"),
	"star": preload("res://assets/sprites/item_star.png"),
}

var kind := "bat"
var ammo := -1
var thrown_by: Fighter = null
var thrown := false
var _age := 0.0
var _spin := 0.0
var _return_t := 0.0
var _hit := []


static func random_kind() -> String:
	var total := 0
	for k in KINDS:
		total += KINDS[k]
	var r := randi() % total
	for k in KINDS:
		r -= KINDS[k]
		if r < 0:
			return k
	return "bat"


func _ready() -> void:
	add_to_group("items")
	collision_layer = 0
	collision_mask = 3
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(30, 16)
	shape.shape = r
	shape.position = Vector2(0, -8)
	add_child(shape)
	z_index = 1
	if ammo < 0:
		ammo = {"bow": 3, "sword": 12}.get(kind, 0)


func can_pickup() -> bool:
	return _age > 0.3 and not thrown


func picked_by(f: Fighter) -> void:
	match kind:
		"heart":
			f.heal(40.0)
			Game.play_sfx("heal")
			Effects.popup(f.get_parent(), f.global_position + Vector2(0, -110), "+40% SALUD", Color(1, 0.5, 0.6), 1.0)
			Effects.burst(f.get_parent(), f.global_position + Vector2(0, -40), {"count": 16, "color": Color(1, 0.5, 0.6),
				"speed": 150.0, "life": 0.7, "size": 4.0, "gravity": -150.0})
		"star":
			f.star_time = 8.0
			Game.play_sfx("star")
			Effects.popup(f.get_parent(), f.global_position + Vector2(0, -110), "¡INVENCIBLE!", Color(1, 0.9, 0.3), 1.1)
		_:
			f.held_item = kind
			f.item_ammo = ammo
			Game.play_sfx("pickup")
			var names := {"bat": "¡BATE!", "bow": "ARCO x%d" % ammo, "sword": "¡ESPADA!", "bomb": "¡BOMBA!",
				"boomerang": "¡BUMERÁN!"}
			Effects.popup(f.get_parent(), f.global_position + Vector2(0, -110), names.get(kind, kind), Color(1, 0.95, 0.6), 0.8)
	queue_free()


## Lanzado por un luchador: vuela, golpea y luego queda en el suelo para recogerlo otra vez.
func throw(by: Fighter, vel: Vector2) -> void:
	thrown_by = by
	thrown = vel.length() > 10.0
	collision_mask = 1 if thrown else 3   # volando atraviesa las plataformas flotantes
	velocity = vel
	_age = 0.0
	_return_t = 0.0
	_hit.clear()


func _physics_process(delta: float) -> void:
	_age += delta
	if thrown:
		_physics_thrown(delta)
	else:
		velocity.y = minf(velocity.y + 1400.0 * delta, 900.0)
		velocity.x = move_toward(velocity.x, 0.0, 500.0 * delta)
		move_and_slide()
		if is_on_floor():
			velocity.y = 0.0
		_spin = move_toward(_spin, 0.0, 10.0 * delta)
	if _age > LIFETIME or global_position.y > 1300.0 or absf(global_position.x) > 2000.0:
		queue_free()
	queue_redraw()


func _physics_thrown(delta: float) -> void:
	_spin += delta * 18.0
	if kind == "boomerang":
		_return_t += delta
		if _return_t > 0.45 and thrown_by and is_instance_valid(thrown_by) and thrown_by.is_alive():
			var to := thrown_by.global_position + Vector2(0, -50) - global_position
			velocity = velocity.lerp(to.normalized() * 950.0, 6.0 * delta)
			if to.length() < 40.0 and _return_t > 0.6:
				if thrown_by.held_item == "":
					thrown_by.held_item = "boomerang"
					Game.play_sfx("pickup", -6.0)
				queue_free()
				return
			if _return_t > 0.5 and Engine.get_physics_frames() % 6 == 0:
				_hit.clear()
		if Engine.get_physics_frames() % 6 == 0:
			Game.play_sfx("boomerang", -16.0)
	else:
		velocity.y += 1300.0 * delta
	var col := move_and_collide(velocity * delta)
	if col and kind != "boomerang":
		if kind == "bomb":
			_explode()
			return
		velocity = velocity.bounce(col.get_normal()) * 0.3
		thrown = false
		collision_mask = 3
		Effects.dust(get_parent(), global_position)
		Game.play_sfx("land", -6.0)
	# golpear luchadores
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == thrown_by or not f.is_alive() or _hit.has(f):
			continue
		if Projectile.circle_hits_rect(global_position + Vector2(0, -8), 26.0, f.hurtbox()):
			_hit.append(f)
			if kind == "bomb":
				_explode()
				return
			var dmg: float = THROW_DMG.get(kind, 8.0)
			var info := {"dmg": dmg, "base_kb": 300.0 + dmg * 8.0, "kb_scale": 5.0 + dmg * 0.3, "angle": 40.0,
				"dir": 1 if velocity.x >= 0.0 else -1, "pos": global_position, "projectile": true,
				"sfx": "hit_strong" if dmg > 10.0 else "hit"}
			if f.apply_hit(thrown_by, info) and kind != "boomerang":
				velocity = Vector2(-velocity.x * 0.25, -350)
				thrown = false
				collision_mask = 3


func _explode() -> void:
	Effects.explosion(get_parent(), global_position + Vector2(0, -10), 110.0)
	Game.play_sfx("explosion")
	for f in get_tree().get_nodes_in_group("fighters"):
		if not f.is_alive():
			continue
		if Projectile.circle_hits_rect(global_position, 110.0, f.hurtbox()):
			f.apply_hit(thrown_by if f != thrown_by else null, {"dmg": 20.0, "base_kb": 420.0, "kb_scale": 9.0,
				"angle": 60.0, "dir": 1 if f.global_position.x >= global_position.x else -1,
				"pos": f.hurtbox().get_center(), "projectile": true, "sfx": "hit_strong"})
	var stage := get_parent()
	if stage and stage.has_method("add_shake"):
		stage.add_shake(24.0)
	queue_free()


func _draw() -> void:
	if not thrown and _age > LIFETIME - 3.0 and fmod(_age, 0.2) < 0.1:
		return
	var tex: Texture2D = TEX[kind]
	var bob := 0.0 if thrown else sin(_age * 3.0) * 3.0
	if not thrown:
		var pulse := 0.5 + 0.5 * sin(_age * 6.0)
		draw_circle(Vector2(0, -18), 28.0 + pulse * 4.0, Color(1, 0.95, 0.5, 0.15 + pulse * 0.1))
		draw_arc(Vector2(0, -18), 28.0 + pulse * 4.0, 0, TAU, 32, Color(1, 1, 0.7, 0.55), 2.0)
	var rot := _spin if thrown else -0.3
	draw_set_transform(Vector2(0, -18 + bob), rot, Vector2.ONE)
	match kind:
		"bow":
			draw_texture_rect_region(tex, Rect2(-20, -28, 40, 56), Rect2(0, 0, 40, 56))
		"bomb":
			draw_texture_rect_region(tex, Rect2(-20, -20, 40, 40), Rect2(40 * (int(_age * 6.0) % 2), 0, 40, 40))
		_:
			draw_texture(tex, -tex.get_size() / 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
