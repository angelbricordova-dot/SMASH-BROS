class_name Projectile
extends Node2D
## Proyectil genérico: bolas de energía, rocas, flechas, objetos lanzados...
## Se configura con propiedades (ver Fighter.spawn_projectile).

var owner_fighter: Fighter
var velocity := Vector2(600, 0)
var gravity := 0.0
var radius := 16.0
var lifetime := 1.2
var texture: Texture2D
var hframes := 4
var sprite_scale := 0.0          # 0 = automático según el radio
var spin := 0.0                  # vueltas por segundo (para objetos lanzados)
var rotate_to_velocity := false  # flechas
var pierce := false              # atraviesa y golpea a varios
var solid := false               # se destruye al chocar con el suelo
var hit_sfx := ""
var info := {}
var on_hit: Callable             # función extra al golpear (recibe al Fighter)

var _sprite: Sprite2D
var _age := 0.0
var _hit := []


func _ready() -> void:
	add_to_group("projectiles")
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.hframes = hframes
	var sc := sprite_scale if sprite_scale > 0.0 else radius / 8.0 * 1.2
	var dir := -1.0 if velocity.x < 0.0 and not rotate_to_velocity else 1.0
	_sprite.scale = Vector2(sc * dir, sc)
	add_child(_sprite)
	z_index = 1


func _physics_process(delta: float) -> void:
	_age += delta
	velocity.y += gravity * delta
	position += velocity * delta
	if hframes > 1 and spin == 0.0:
		_sprite.frame = int(_age * 16.0) % hframes
	if spin != 0.0:
		_sprite.rotation += spin * delta * signf(velocity.x)
	elif rotate_to_velocity:
		_sprite.rotation = velocity.angle()
	if _age >= lifetime:
		queue_free()
		return
	if solid and _touches_ground():
		Effects.dust(get_parent(), global_position + Vector2(0, radius))
		queue_free()
		return
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == owner_fighter or not f.is_alive() or _hit.has(f):
			continue
		if _circle_hits_rect(global_position, radius, f.hurtbox()):
			_hit.append(f)
			var hit_info := info.duplicate()
			hit_info["dir"] = 1 if velocity.x >= 0.0 else -1
			hit_info["pos"] = global_position
			hit_info["projectile"] = true
			if hit_sfx != "":
				hit_info["sfx"] = hit_sfx
			if f.apply_hit(owner_fighter, hit_info):
				if on_hit.is_valid() and f.state == Fighter.State.HITSTUN:
					on_hit.call(f)
				if not pierce:
					queue_free()
					return


func _touches_ground() -> bool:
	var q := PhysicsPointQueryParameters2D.new()
	q.position = global_position + Vector2(0, radius * 0.6)
	q.collision_mask = 1
	return not get_world_2d().direct_space_state.intersect_point(q, 1).is_empty()


static func _circle_hits_rect(c: Vector2, r: float, rect: Rect2) -> bool:
	var nearest := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
	return nearest.distance_to(c) <= r
