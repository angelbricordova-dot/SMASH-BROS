class_name Effects
extends RefCounted
## Efectos visuales: chispas de golpe, partículas, estelas de ataques, rayos, explosiones,
## textos flotantes... Todos son nodos que se dibujan solos y desaparecen.


static func _add(parent: Node, fx: Node2D, pos: Vector2) -> Node2D:
	fx.position = pos
	if parent and parent.is_inside_tree():
		parent.add_child(fx)
	return fx


static func _fx(kind: String, color: Color, life: float, size := 1.0) -> FxNode:
	var s := FxNode.new()
	s.kind = kind
	s.color = color
	s.life = life
	s.size = size
	return s


## Chispa de golpe completa: estrella + anillo + partículas + líneas de impacto.
static func hit(parent: Node, pos: Vector2, strength: float, color: Color, dir := 1) -> void:
	spark(parent, pos, strength, color)
	ring(parent, pos, Color(1, 1, 1, 0.9), 30.0 + 40.0 * strength)
	burst(parent, pos, {"count": int(6 + 10 * strength), "color": color, "speed": 220.0 + 180.0 * strength,
		"life": 0.35, "size": 3.0 + strength, "angle": 0.0 if dir > 0 else 180.0, "spread": 70.0, "streak": true})
	if strength > 1.1:
		var s := _fx("impact", Color(1, 1, 1), 0.16, strength)
		s.extra = Vector2(dir, 0)
		_add(parent, s, pos)


static func spark(parent: Node, pos: Vector2, size: float, color: Color) -> void:
	var s := _fx("spark", color, 0.22, size)
	s.rotation = randf() * TAU
	_add(parent, s, pos)


static func dust(parent: Node, pos: Vector2) -> void:
	burst(parent, pos, {"count": 6, "color": Color(0.95, 0.92, 0.88, 0.7), "speed": 90.0, "life": 0.4,
		"size": 6.0, "angle": -90.0, "spread": 160.0, "gravity": -60.0, "grow": true})


static func ring(parent: Node, pos: Vector2, color: Color, radius := 40.0) -> void:
	_add(parent, _fx("ring", color, 0.3, radius), pos)


static func smoke(parent: Node, pos: Vector2, color := Color(0.25, 0.12, 0.4)) -> void:
	_add(parent, _fx("smoke", color, 0.6), pos)
	burst(parent, pos + Vector2(0, -40), {"count": 14, "color": Color(color.r, color.g, color.b, 0.8),
		"speed": 120.0, "life": 0.6, "size": 9.0, "gravity": -60.0, "grow": true})


static func shatter(parent: Node, pos: Vector2, color: Color) -> void:
	_add(parent, _fx("shatter", color, 0.8), pos)
	ring(parent, pos, Color(1, 1, 1), 90.0)


static func shockwave(parent: Node, pos: Vector2, color: Color, width := 900.0) -> void:
	_add(parent, _fx("shockwave", color, 0.7, width), pos)
	burst(parent, pos, {"count": 30, "color": Color(0.55, 0.45, 0.35), "speed": 420.0, "life": 0.8, "size": 6.0,
		"angle": -90.0, "spread": 80.0, "gravity": 900.0})


static func explosion(parent: Node, pos: Vector2, radius := 90.0, color := Color(1, 0.6, 0.2)) -> void:
	_add(parent, _fx("explosion", color, 0.5, radius), pos)
	ring(parent, pos, Color(1, 0.9, 0.6), radius * 1.4)
	burst(parent, pos, {"count": 26, "color": color, "speed": 380.0, "life": 0.5, "size": 6.0, "gravity": 300.0})
	burst(parent, pos, {"count": 10, "color": Color(0.3, 0.3, 0.32, 0.8), "speed": 120.0, "life": 0.9,
		"size": 14.0, "gravity": -80.0, "grow": true})


static func beam(parent: Node, pos: Vector2, dir: int, length: float, height: float, color: Color, life: float) -> void:
	var s := _fx("beam", color, life, length)
	s.extra = Vector2(dir, height)
	_add(parent, s, pos)


static func vbeam(parent: Node, pos: Vector2, width: float, color: Color, life: float) -> void:
	var s := _fx("vbeam", color, life, width)
	_add(parent, s, pos)


static func lightning(parent: Node, from: Vector2, to: Vector2, color := Color(1, 0.95, 0.4), life := 0.18) -> void:
	var s := _fx("bolt", color, life)
	s.extra = to - from
	_add(parent, s, from)


static func snow(parent: Node, pos: Vector2, life: float) -> void:
	_add(parent, _fx("snow", Color(0.85, 0.95, 1.0), life), pos)


static func rune_circle(parent: Node, pos: Vector2, radius: float, color: Color, life: float) -> FxNode:
	return _add(parent, _fx("runes", color, life, radius), pos)


static func afterimage(parent: Node, fighter: Fighter, color: Color) -> void:
	var tex := fighter.sprite.sprite_frames.get_frame_texture(fighter.sprite.animation, fighter.sprite.frame)
	var s := Sprite2D.new()
	s.texture = tex
	s.flip_h = fighter.sprite.flip_h
	s.scale = fighter.sprite.scale
	s.modulate = color
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.global_position = fighter.sprite.global_position
	s.rotation = fighter.sprite.rotation
	parent.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.3)
	tw.tween_callback(s.queue_free)


static func popup(parent: Node, pos: Vector2, text: String, color: Color, scale := 1.0) -> void:
	var s := _fx("text", color, 0.9, scale)
	s.text = text
	_add(parent, s, pos)


## Estela de un ataque: un arco que sigue al luchador.
static func swoosh(fighter: Node2D, a0: float, a1: float, radius: float, color: Color, life: float, width := 8.0,
		offset := Vector2(0, -40)) -> void:
	var s := _fx("swoosh", color, life, radius)
	s.extra = Vector2(a0, a1)
	s.width = width
	s.facing = fighter.get("facing") if fighter.get("facing") != null else 1
	s.position = offset
	fighter.add_child(s)


## Explosión de partículas. opts: count, color, speed, life, size, angle (grados), spread (grados),
## gravity, grow, streak (líneas en vez de círculos), star, radius (nacen en un círculo y van al centro si speed<0)
static func burst(parent: Node, pos: Vector2, opts: Dictionary) -> void:
	var p := Particles.new()
	p.opts = opts
	_add(parent, p, pos)


class Particles extends Node2D:
	var opts := {}
	var parts := []
	var _t := 0.0
	var life := 0.4

	func _ready() -> void:
		z_index = 11
		life = opts.get("life", 0.4)
		var n: int = opts.get("count", 8)
		var speed: float = opts.get("speed", 150.0)
		var ang: float = deg_to_rad(opts.get("angle", 0.0))
		var spread: float = deg_to_rad(opts.get("spread", 180.0))
		var radius: float = opts.get("radius", 0.0)
		for i in n:
			var a := ang + randf_range(-spread, spread)
			var v := Vector2(cos(a), sin(a)) * speed * randf_range(0.5, 1.1)
			var p0 := Vector2.ZERO
			if radius > 0.0:
				p0 = Vector2(cos(a), sin(a)) * radius
			parts.append({"p": p0, "v": v, "s": opts.get("size", 4.0) * randf_range(0.6, 1.2),
				"l": life * randf_range(0.6, 1.0)})

	func _process(delta: float) -> void:
		_t += delta
		var g: float = opts.get("gravity", 0.0)
		for p in parts:
			p["v"].y += g * delta
			p["v"] *= 0.97
			p["p"] += p["v"] * delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var col: Color = opts.get("color", Color.WHITE)
		for p in parts:
			var k: float = clampf(_t / p["l"], 0.0, 1.0)
			if k >= 1.0:
				continue
			var c := Color(col.r, col.g, col.b, col.a * (1.0 - k))
			var s: float = p["s"] * ((1.0 + k * 1.5) if opts.get("grow", false) else (1.0 - k * 0.6))
			if opts.get("streak", false):
				draw_line(p["p"], p["p"] - p["v"] * 0.05, c, maxf(1.5, s * 0.6))
			elif opts.get("star", false):
				draw_line(p["p"] - Vector2(s, 0), p["p"] + Vector2(s, 0), c, 1.5)
				draw_line(p["p"] - Vector2(0, s), p["p"] + Vector2(0, s), c, 1.5)
			else:
				draw_circle(p["p"], s, c)


class FxNode extends Node2D:
	var kind := "spark"
	var size := 1.0
	var color := Color.WHITE
	var life := 0.2
	var text := ""
	var extra := Vector2.ZERO
	var width := 8.0
	var facing := 1
	var _t := 0.0
	var _seed := 0

	func _ready() -> void:
		z_index = 20 if kind == "text" else (-1 if kind == "runes" else 10)
		_seed = randi()

	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(_t / life, 0.0, 1.0)
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed
		match kind:
			"spark":
				var r := (18.0 + 50.0 * k) * size
				var pts := PackedVector2Array()
				for i in 16:
					var rr := r if i % 2 == 0 else r * 0.32
					var a := i * TAU / 16.0
					pts.append(Vector2(cos(a), sin(a)) * rr)
				draw_colored_polygon(pts, Color(color.r, color.g, color.b, 1.0 - k))
				draw_circle(Vector2.ZERO, r * 0.3, Color(1, 1, 1, 1.0 - k))
			"impact":
				var a := 1.0 - k
				for i in 10:
					var ang := rng.randf() * TAU
					var r0 := 20.0 + 30.0 * k
					var r1 := r0 + rng.randf_range(40, 110) * size
					draw_line(Vector2(cos(ang), sin(ang)) * r0, Vector2(cos(ang), sin(ang)) * r1, Color(1, 1, 1, a), 3.0)
			"ring":
				draw_arc(Vector2.ZERO, size * (0.35 + k), 0, TAU, 40, Color(color.r, color.g, color.b, 1.0 - k),
					5.0 * (1.0 - k) + 1.0)
			"smoke":
				for i in 7:
					var a := rng.randf() * TAU
					var d := rng.randf_range(4, 30) * (0.5 + k)
					draw_circle(Vector2(cos(a) * d, sin(a) * d - 40 - 20 * k), rng.randf_range(12, 22) * (1.0 - k * 0.4),
						Color(color.r, color.g, color.b, 0.75 * (1.0 - k)))
			"shatter":
				for i in 16:
					var a := i * TAU / 16.0 + rng.randf() * 0.3
					var d := 20.0 + 170.0 * k * rng.randf_range(0.6, 1.2)
					var p := Vector2(cos(a), sin(a)) * d + Vector2(0, 220 * k * k)
					var s := rng.randf_range(6, 12) * (1.0 - k * 0.5)
					draw_colored_polygon(PackedVector2Array([p + Vector2(-s, 0), p + Vector2(0, -s * 0.6),
						p + Vector2(s, s * 0.4)]), Color(color.r, color.g, color.b, 1.0 - k).lerp(Color(1, 1, 1, 1.0 - k), 0.5))
			"shockwave":
				var w := size * minf(1.0, k * 2.5)
				var a := 1.0 - k
				draw_rect(Rect2(-w / 2, -28 * a, w, 28 * a + 4), Color(color.r, color.g, color.b, 0.45 * a))
				draw_rect(Rect2(-w / 2, -6, w, 6), Color(1, 1, 1, 0.6 * a))
			"explosion":
				var r := size * (0.4 + 0.8 * minf(1.0, k * 3.0))
				var a := 1.0 - k
				draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.6 * a))
				draw_circle(Vector2.ZERO, r * 0.65, Color(1, 0.9, 0.5, 0.8 * a))
				draw_circle(Vector2.ZERO, r * 0.3, Color(1, 1, 1, a))
			"beam":
				var dir := extra.x
				var h := extra.y * (1.0 if k < 0.8 else (1.0 - k) * 5.0)
				var blen := size * minf(1.0, k * 8.0)
				var x0 := 0.0 if dir > 0 else -blen
				var wob := sin(_t * 60.0) * 6.0
				draw_rect(Rect2(x0, -h / 2 - wob - 10, blen, h + wob * 2 + 20), Color(color.r, color.g, color.b, 0.25))
				draw_rect(Rect2(x0, -h / 2 - wob, blen, h + wob * 2), Color(color.r, color.g, color.b, 0.6))
				draw_rect(Rect2(x0, -h * 0.3, blen, h * 0.6), Color(color.r, color.g, color.b, 0.9).lerp(Color.WHITE, 0.3))
				draw_rect(Rect2(x0, -h * 0.12, blen, h * 0.24), Color(1, 1, 0.95, 0.95))
				draw_circle(Vector2.ZERO, h * 0.7, Color(1, 1, 0.9, 0.9))
			"vbeam":
				var w := size * (1.0 if k < 0.85 else (1.0 - k) * 6.6) * (0.9 + 0.1 * sin(_t * 50.0))
				draw_rect(Rect2(-w, -2000, w * 2, 2000), Color(color.r, color.g, color.b, 0.35))
				draw_rect(Rect2(-w * 0.6, -2000, w * 1.2, 2000), Color(color.r, color.g, color.b, 0.75))
				draw_rect(Rect2(-w * 0.25, -2000, w * 0.5, 2000), Color(1, 1, 1, 0.95))
				draw_circle(Vector2.ZERO, w * 1.4, Color(color.r, color.g, color.b, 0.5))
			"bolt":
				var pts := PackedVector2Array([Vector2.ZERO])
				var n := 8
				var perp := Vector2(-extra.y, extra.x).normalized()
				for i in range(1, n):
					pts.append(extra * (float(i) / n) + perp * rng.randf_range(-18, 18))
				pts.append(extra)
				var a := 1.0 - k
				draw_polyline(pts, Color(color.r, color.g, color.b, 0.5 * a), 9.0)
				draw_polyline(pts, Color(color.r, color.g, color.b, a), 4.0)
				draw_polyline(pts, Color(1, 1, 1, a), 1.5)
			"snow":
				for i in 120:
					var x := fposmod(rng.randf_range(-1000, 1000) + _t * rng.randf_range(-400, -150), 2000.0) - 1000.0
					var y := fposmod(rng.randf_range(-700, 700) + _t * rng.randf_range(200, 500), 1400.0) - 700.0
					draw_circle(Vector2(x, y), rng.randf_range(2, 5),
						Color(color.r, color.g, color.b, 0.9 * minf(1.0, (1.0 - k) * 4.0)))
			"runes":
				var a := minf(1.0, (1.0 - k) * 5.0) * minf(1.0, k * 8.0)
				var r := size
				draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.3))
				draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.18 * a))
				draw_arc(Vector2.ZERO, r, 0, TAU, 48, Color(color.r, color.g, color.b, 0.9 * a), 4.0)
				draw_arc(Vector2.ZERO, r * 0.7, _t * 2.0, _t * 2.0 + TAU, 48, Color(1, 1, 1, 0.6 * a), 2.0)
				for i in 6:
					var ang := _t * 1.5 + i * TAU / 6.0
					draw_circle(Vector2(cos(ang), sin(ang)) * r * 0.85, 6.0, Color(color.r, color.g, color.b, a))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"swoosh":
				var a0 := deg_to_rad(extra.x)
				var a1 := deg_to_rad(extra.y)
				var grow := minf(1.0, k * 3.0)
				var fade := 1.0 - maxf(0.0, (k - 0.3) / 0.7)
				var steps := 18
				var cur := lerpf(a0, a1, grow)
				var prev := Vector2.ZERO
				for i in steps + 1:
					var t := float(i) / steps
					var ang := lerpf(a0, cur, t)
					var p := Vector2(cos(ang) * facing, sin(ang)) * size
					if i > 0:
						var wv := width * t * fade
						draw_line(prev, p, Color(color.r, color.g, color.b, 0.35 * fade), wv + 6.0)
						draw_line(prev, p, Color(1, 1, 1, 0.9 * fade * t), wv)
					prev = p
			"text":
				var font: Font = Game.font_title
				var fs := int(38 * size * (1.0 + 0.4 * maxf(0.0, 0.15 - _t) / 0.15))
				var y := -40.0 * k
				var a := 1.0 if k < 0.7 else (1.0 - k) / 0.3
				draw_string_outline(font, Vector2(-220, y), text, HORIZONTAL_ALIGNMENT_CENTER, 440, fs, 10, Color(0, 0, 0, a))
				draw_string(font, Vector2(-220, y), text, HORIZONTAL_ALIGNMENT_CENTER, 440, fs, Color(color.r, color.g, color.b, a))
