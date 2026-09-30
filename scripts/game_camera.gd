extends Camera2D
## Cámara que sigue a los luchadores: se acerca y se aleja para que todos se vean.

@export var min_zoom := 0.55
@export var max_zoom := 1.05
@export var margin := Vector2(380, 260)
@export var smooth := 6.0

var _shake := 0.0


func _ready() -> void:
	make_current()


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	var pts: Array[Vector2] = []
	for f in get_tree().get_nodes_in_group("fighters"):
		if f.is_alive():
			pts.append(f.global_position + Vector2(0, -40))
	if pts.is_empty():
		return
	var lo := pts[0]
	var hi := pts[0]
	for p in pts:
		lo = lo.min(p)
		hi = hi.max(p)
	lo -= margin
	hi += margin
	var view := get_viewport_rect().size
	var z := clampf(minf(view.x / (hi.x - lo.x), view.y / (hi.y - lo.y)), min_zoom, max_zoom)
	var target := (lo + hi) / 2.0 + Vector2(0, 30)
	var k := 1.0 - exp(-smooth * delta)
	global_position = global_position.lerp(target, k)
	zoom = zoom.lerp(Vector2(z, z), k)
	_shake = move_toward(_shake, 0.0, 60.0 * delta)
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
