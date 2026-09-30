class_name Projectile
extends Node2D
## Proyectil del ataque especial (la bola de energía).

var owner_fighter: Fighter
var dir := 1
var speed := 600.0
var radius := 16.0
var lifetime := 1.2
var texture: Texture2D
var info := {}

var _sprite: Sprite2D
var _age := 0.0


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.hframes = 4
	_sprite.scale = Vector2(radius / 8.0 * 1.2 * dir, radius / 8.0 * 1.2)
	add_child(_sprite)
	z_index = 1


func _physics_process(delta: float) -> void:
	_age += delta
	position.x += dir * speed * delta
	_sprite.frame = int(_age * 16.0) % 4
	if _age >= lifetime:
		queue_free()
		return
	for f in get_tree().get_nodes_in_group("fighters"):
		if f == owner_fighter or not f.is_alive():
			continue
		if _circle_hits_rect(global_position, radius, f.hurtbox()):
			var hit_info := info.duplicate()
			hit_info["dir"] = dir
			hit_info["pos"] = global_position
			if f.apply_hit(owner_fighter, hit_info):
				queue_free()
				return


static func _circle_hits_rect(c: Vector2, r: float, rect: Rect2) -> bool:
	var nearest := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
	return nearest.distance_to(c) <= r
