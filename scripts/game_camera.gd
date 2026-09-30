extends Camera2D
## Cámara que sigue a los luchadores: se acerca y se aleja para que todos se vean.

@export var min_zoom := 0.55
@export var max_zoom := 1.05
@export var margin := Vector2(380, 260)
@export var smooth := 6.0

var focus: Node2D = null   # si se asigna, la cámara se acerca a ese nodo (victoria)
var _shake := 0.0
var _punch := 0.0
var _base_zoom := Vector2.ONE


func _ready() -> void:
	make_current()


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


## Pequeño "zoom de impacto".
func punch(amount: float) -> void:
	_punch = maxf(_punch, amount)


func _process(delta: float) -> void:
	var target := global_position
	var z := _base_zoom.x
	if focus and is_instance_valid(focus):
		target = focus.global_position + Vector2(0, -60)
		z = 1.7
	else:
		var pts: Array[Vector2] = []
		for f in get_tree().get_nodes_in_group("fighters"):
			if f.is_alive():
				pts.append(f.global_position + Vector2(0, -40))
		if not pts.is_empty():
			var lo := pts[0]
			var hi := pts[0]
			for p in pts:
				lo = lo.min(p)
				hi = hi.max(p)
			lo -= margin
			hi += margin
			var view := get_viewport_rect().size
			z = clampf(minf(view.x / (hi.x - lo.x), view.y / (hi.y - lo.y)), min_zoom, max_zoom)
			target = (lo + hi) / 2.0 + Vector2(0, 30)
	var k := 1.0 - exp(-smooth * delta)
	global_position = global_position.lerp(target, k)
	_base_zoom = _base_zoom.lerp(Vector2(z, z), k)
	zoom = _base_zoom * (1.0 + _punch * 0.3)
	_punch = move_toward(_punch, 0.0, 1.5 * delta)
	_shake = move_toward(_shake, 0.0, 60.0 * delta)
	offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake
