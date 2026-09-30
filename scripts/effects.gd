class_name Effects
extends RefCounted
## Efectos visuales (chispas, polvo, textos flotantes, rayos, humo...).
## Todos son nodos que se dibujan solos y desaparecen.


static func _add(parent: Node, fx: Node2D, pos: Vector2) -> Node2D:
	fx.position = pos
	if parent:
		parent.add_child(fx)
	return fx


static func spark(parent: Node, pos: Vector2, size: float, color: Color) -> void:
	var s := FxNode.new()
	s.kind = "spark"
	s.size = size
	s.color = color
	s.life = 0.22
	_add(parent, s, pos)


static func dust(parent: Node, pos: Vector2) -> void:
	var s := FxNode.new()
	s.kind = "dust"
	s.color = Color(1, 1, 1, 0.8)
	s.life = 0.3
	_add(parent, s, pos)


static func ring(parent: Node, pos: Vector2, color: Color, radius := 40.0) -> void:
	var s := FxNode.new()
	s.kind = "ring"
	s.color = color
	s.size = radius
	s.life = 0.3
	_add(parent, s, pos)


static func smoke(parent: Node, pos: Vector2, color := Color(0.25, 0.12, 0.4)) -> void:
	var s := FxNode.new()
	s.kind = "smoke"
	s.color = color
	s.life = 0.6
	_add(parent, s, pos)


static func shatter(parent: Node, pos: Vector2, color: Color) -> void:
	var s := FxNode.new()
	s.kind = "shatter"
	s.color = color
	s.life = 0.7
	_add(parent, s, pos)


static func shockwave(parent: Node, pos: Vector2, color: Color, width := 900.0) -> void:
	var s := FxNode.new()
	s.kind = "shockwave"
	s.color = color
	s.size = width
	s.life = 0.6
	_add(parent, s, pos)


static func beam(parent: Node, pos: Vector2, dir: int, length: float, height: float, color: Color, life: float) -> void:
	var s := FxNode.new()
	s.kind = "beam"
	s.color = color
	s.size = length
	s.extra = Vector2(dir, height)
	s.life = life
	_add(parent, s, pos)


static func snow(parent: Node, pos: Vector2, life: float) -> void:
	var s := FxNode.new()
	s.kind = "snow"
	s.color = Color(0.85, 0.95, 1.0)
	s.life = life
	_add(parent, s, pos)


static func afterimage(parent: Node, fighter: Fighter, color: Color) -> void:
	var tex := fighter.sprite.sprite_frames.get_frame_texture(fighter.sprite.animation, fighter.sprite.frame)
	var s := Sprite2D.new()
	s.texture = tex
	s.flip_h = fighter.sprite.flip_h
	s.scale = fighter.sprite.scale
	s.modulate = color
	s.global_position = fighter.sprite.global_position
	s.rotation = fighter.sprite.rotation
	parent.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.3)
	tw.tween_callback(s.queue_free)


static func popup(parent: Node, pos: Vector2, text: String, color: Color, scale := 1.0) -> void:
	var s := FxNode.new()
	s.kind = "text"
	s.text = text
	s.color = color
	s.size = scale
	s.life = 0.9
	_add(parent, s, pos)


class FxNode extends Node2D:
	var kind := "spark"
	var size := 1.0
	var color := Color.WHITE
	var life := 0.2
	var text := ""
	var extra := Vector2.ZERO
	var _t := 0.0
	var _seed := 0

	func _ready() -> void:
		z_index = 20 if kind == "text" else 10
		_seed = randi()
		if kind == "spark" or kind == "shatter":
			rotation = randf() * TAU

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := _t / life
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed
		match kind:
			"spark":
				var r := (16.0 + 44.0 * k) * size
				var pts := PackedVector2Array()
				for i in 16:
					var rr := r if i % 2 == 0 else r * 0.35
					var a := i * TAU / 16.0
					pts.append(Vector2(cos(a), sin(a)) * rr)
				draw_colored_polygon(pts, Color(color.r, color.g, color.b, 1.0 - k))
				draw_circle(Vector2.ZERO, r * 0.3, Color(1, 1, 1, 1.0 - k))
			"dust":
				for i in 2:
					var sgn := -1.0 if i == 0 else 1.0
					draw_circle(Vector2(sgn * (6 + 18 * k), -4 - 6 * k), 7 * (1.0 - k * 0.5),
						Color(color.r, color.g, color.b, 0.8 * (1.0 - k)))
			"ring":
				draw_arc(Vector2.ZERO, size * (0.4 + k), 0, TAU, 32, Color(color.r, color.g, color.b, 1.0 - k), 4.0 * (1.0 - k) + 1.0)
			"smoke":
				for i in 7:
					var a := rng.randf() * TAU
					var d := rng.randf_range(4, 30) * (0.5 + k)
					draw_circle(Vector2(cos(a) * d, sin(a) * d - 40 - 20 * k), rng.randf_range(10, 20) * (1.0 - k * 0.4),
						Color(color.r, color.g, color.b, 0.75 * (1.0 - k)))
			"shatter":
				for i in 12:
					var a := i * TAU / 12.0 + rng.randf() * 0.3
					var d := 20.0 + 140.0 * k * rng.randf_range(0.6, 1.2)
					var p := Vector2(cos(a), sin(a)) * d + Vector2(0, 200 * k * k)
					var s := rng.randf_range(5, 10) * (1.0 - k * 0.5)
					draw_colored_polygon(PackedVector2Array([p + Vector2(-s, 0), p + Vector2(0, -s * 0.6), p + Vector2(s, s * 0.4)]),
						Color(color.r, color.g, color.b, 1.0 - k).lerp(Color(1, 1, 1, 1.0 - k), 0.4))
			"shockwave":
				var w := size * minf(1.0, k * 2.5)
				var a := 1.0 - k
				draw_rect(Rect2(-w / 2, -24 * (1.0 - k), w, 24 * (1.0 - k) + 4), Color(color.r, color.g, color.b, 0.5 * a))
				for i in 14:
					var x := rng.randf_range(-w / 2, w / 2)
					draw_rect(Rect2(x, -rng.randf_range(10, 50) * a, 8, 8), Color(0.55, 0.4, 0.3, a))
			"beam":
				var dir := extra.x
				var h := extra.y * (1.0 if k < 0.8 else (1.0 - k) * 5.0)
				var grow := minf(1.0, k * 8.0)
				var blen := size * grow
				var x0 := 0.0 if dir > 0 else -blen
				var wob := sin(_t * 60.0) * 6.0
				draw_rect(Rect2(x0, -h / 2 - wob, blen, h + wob * 2), Color(color.r, color.g, color.b, 0.55))
				draw_rect(Rect2(x0, -h * 0.3, blen, h * 0.6), Color(color.r, color.g, color.b, 0.85).lerp(Color.WHITE, 0.3))
				draw_rect(Rect2(x0, -h * 0.12, blen, h * 0.24), Color(1, 1, 0.9, 0.95))
				draw_circle(Vector2.ZERO, h * 0.7, Color(1, 1, 0.9, 0.9))
			"snow":
				for i in 90:
					var x := fposmod(rng.randf_range(-900, 900) + _t * rng.randf_range(-400, -150), 1800.0) - 900.0
					var y := fposmod(rng.randf_range(-600, 600) + _t * rng.randf_range(200, 500), 1200.0) - 600.0
					draw_circle(Vector2(x, y), rng.randf_range(2, 5), Color(color.r, color.g, color.b, 0.9 * minf(1.0, (1.0 - k) * 4.0)))
			"text":
				var font: Font = Game.font_title
				var fs := int(38 * size * (1.0 + 0.4 * maxf(0.0, 0.15 - _t) / 0.15))
				var y := -40.0 * k
				var a := 1.0 if k < 0.7 else (1.0 - k) / 0.3
				draw_string_outline(font, Vector2(-200, y), text, HORIZONTAL_ALIGNMENT_CENTER, 400, fs, 10, Color(0, 0, 0, a))
				draw_string(font, Vector2(-200, y), text, HORIZONTAL_ALIGNMENT_CENTER, 400, fs, Color(color.r, color.g, color.b, a))
