class_name Projectile
extends Node2D
## Proyectil genérico: bolas de energía, rocas, flechas, láseres, meteoritos...
## Se configura con propiedades (ver Fighter.spawn_projectile).

var owner_fighter: Fighter
var velocity := Vector2(600, 0)
var gravity := 0.0
var radius := 16.0
var lifetime := 1.2
var texture: Texture2D
var hframes := 4
var sprite_scale := 0.0          # 0 = automático según el radio
var spin := 0.0                  # vueltas por segundo
var rotate_to_velocity := false
var pierce := false              # atraviesa y golpea a varios
var solid := false               # se destruye al chocar con el suelo
var homing := 0.0                # qué tanto persigue al rival (0 = nada)
var explode_radius := 0.0        # si > 0, explota al chocar
var trail := Color(0, 0, 0, 0)   # estela (alfa 0 = sin estela)
var hit_sfx := ""
var info := {}
var on_hit: Callable

var _sprite: Sprite2D
var _age := 0.0
var _hit := []
var _trail_pts: Array[Vector2] = []


func _ready() -> void:
	add_to_group("projectiles")
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.hframes = hframes
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sc := sprite_scale if sprite_scale > 0.0 else radius / 16.0 * 1.2
	var dir := -1.0 if velocity.x < 0.0 and not rotate_to_velocity else 1.0
	_sprite.scale = Vector2(sc * dir, sc)
	add_child(_sprite)
	z_index = 1
	if trail.a == 0.0 and owner_fighter:
		trail = Color(owner_fighter.data["fx_color"], 0.45)


func _physics_process(delta: float) -> void:
	_age += delta
	if homing > 0.0 and owner_fighter:
		var t := owner_fighter.find_target()
		if t:
			var want := (t.hurtbox().get_center() - global_position).normalized() * velocity.length()
			velocity = velocity.lerp(want, clampf(homing * delta, 0.0, 1.0))
	velocity.y += gravity * delta
	position += velocity * delta
	_trail_pts.push_front(global_position)
	if _trail_pts.size() > 10:
		_trail_pts.pop_back()
	queue_redraw()
	if hframes > 1 and spin == 0.0:
		_sprite.frame = int(_age * 16.0) % hframes
	if spin != 0.0:
		_sprite.rotation += spin * delta * signf(velocity.x)
	elif rotate_to_velocity:
		_sprite.rotation = velocity.angle()
	if _age >= lifetime:
		_end()
		return
	if solid and _touches_ground():
		_end()
		return
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == owner_fighter or not f.is_alive() or _hit.has(f):
			continue
		if circle_hits_rect(global_position, radius, f.hurtbox()):
			_hit.append(f)
			if explode_radius > 0.0:
				_end()
				return
			var hit_info := info.duplicate()
			hit_info["dir"] = 1 if velocity.x >= 0.0 else -1
			hit_info["pos"] = global_position
			hit_info["projectile"] = true
			if hit_sfx != "":
				hit_info["sfx"] = hit_sfx
			if f.apply_hit(owner_fighter, hit_info):
				if on_hit.is_valid():
					on_hit.call(f)
				if not pierce:
					queue_free()
					return


func _end() -> void:
	if explode_radius > 0.0 and is_inside_tree():
		Effects.explosion(get_parent(), global_position, explode_radius, trail if trail.a > 0 else Color(1, 0.6, 0.2))
		Game.play_sfx("explosion", -4.0)
		for f in get_tree().get_nodes_in_group("fighters"):
			if f == owner_fighter or not f.is_alive():
				continue
			if circle_hits_rect(global_position, explode_radius, f.hurtbox()):
				var hit_info := info.duplicate()
				hit_info["dir"] = 1 if f.global_position.x >= global_position.x else -1
				hit_info["pos"] = f.hurtbox().get_center()
				hit_info["projectile"] = true
				f.apply_hit(owner_fighter, hit_info)
	elif solid:
		Effects.dust(get_parent(), global_position + Vector2(0, radius))
	queue_free()


func _draw() -> void:
	if trail.a <= 0.0 or _trail_pts.size() < 2:
		return
	for i in range(1, _trail_pts.size()):
		var k := 1.0 - float(i) / _trail_pts.size()
		draw_line(to_local(_trail_pts[i - 1]), to_local(_trail_pts[i]), Color(trail.r, trail.g, trail.b, trail.a * k),
			radius * 1.2 * k + 1.0)


func _touches_ground() -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = global_position + Vector2(0, radius * 0.6)
	q.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()


static func circle_hits_rect(c: Vector2, r: float, rect: Rect2) -> bool:
	var nearest := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
	return nearest.distance_to(c) <= r
