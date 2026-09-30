class_name Effects
extends RefCounted
## Efectos visuales sencillos (chispas al golpear, polvo al saltar).


static func spark(parent: Node, pos: Vector2, size: float, color: Color) -> void:
	var s := _FxNode.new()
	s.kind = "spark"
	s.size = size
	s.color = color
	s.life = 0.22
	s.global_position = pos
	parent.add_child(s)


static func dust(parent: Node, pos: Vector2) -> void:
	var s := _FxNode.new()
	s.kind = "dust"
	s.size = 1.0
	s.color = Color(1, 1, 1, 0.8)
	s.life = 0.3
	s.global_position = pos
	parent.add_child(s)


class _FxNode extends Node2D:
	var kind := "spark"
	var size := 1.0
	var color := Color.WHITE
	var life := 0.2
	var _t := 0.0

	func _ready() -> void:
		z_index = 10
		rotation = randf() * TAU

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := _t / life
		if kind == "spark":
			var r := (16.0 + 44.0 * k) * size
			var pts := PackedVector2Array()
			for i in 16:
				var rr := r if i % 2 == 0 else r * 0.35
				var a := i * TAU / 16.0
				pts.append(Vector2(cos(a), sin(a)) * rr)
			var c := color
			c.a = 1.0 - k
			draw_colored_polygon(pts, c)
			draw_circle(Vector2.ZERO, r * 0.3, Color(1, 1, 1, 1.0 - k))
		else:
			var c := color
			c.a = 0.8 * (1.0 - k)
			for i in 2:
				var sgn := -1.0 if i == 0 else 1.0
				draw_circle(Vector2(sgn * (6 + 18 * k), -4 - 6 * k), 7 * (1.0 - k * 0.5), c)
