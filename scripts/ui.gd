class_name UI
extends RefCounted
## Kit de estilos de la interfaz: colores, etiquetas, paneles y retratos.

const BG := Color(0.055, 0.07, 0.15)
const CARD := Color(0.1, 0.12, 0.24, 0.92)
const CARD_HI := Color(0.16, 0.19, 0.36, 0.95)
const TEXT := Color(0.96, 0.97, 1.0)
const MUTED := Color(0.66, 0.71, 0.86)
const ACCENT := Color(1.0, 0.82, 0.25)
const GOOD := Color(0.35, 0.9, 0.55)
const P_COLORS := [Color(1.0, 0.33, 0.33), Color(0.3, 0.6, 1.0)]


static func label(text: String, size := 18, color := TEXT, title := false, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if title:
		l.add_theme_font_override("font", Game.font_title)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	return l


static func style(bg: Color, radius := 16, border := Color(0, 0, 0, 0), border_w := 0, shadow := true) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.35)
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0, 4)
	sb.set_content_margin_all(12)
	return sb


static func panel(bg := CARD, radius := 16, border := Color(0, 0, 0, 0), border_w := 0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(bg, radius, border, border_w))
	return p


## Un cuadro de la animación "idle" de un personaje (para menús).
static func frame_tex(char_id: String, col := 0) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/sprites/idle_%s.png" % sprite_of(char_id))
	at.region = Rect2(col * Fighter.FRAME_W, 0, Fighter.FRAME_W, Fighter.FRAME_H)
	return at


## Un cuadro cualquiera de la hoja completa (fila = animación).
static func sheet_tex(char_id: String, row: int, col: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/sprites/char_%s.png" % sprite_of(char_id))
	at.region = Rect2(col * Fighter.FRAME_W, row * Fighter.FRAME_H, Fighter.FRAME_W, Fighter.FRAME_H)
	return at


## Retrato (la cabeza) de un personaje.
static func head_tex(char_id: String) -> Texture2D:
	return load("res://assets/sprites/portrait_%s.png" % sprite_of(char_id))


## Id de los dibujos de un personaje (el muñeco ILUNA usa los de Ilunna).
static func sprite_of(char_id: String) -> String:
	return CharacterData.get_data(char_id).get("sprite", char_id)


static func pixel_rect(tex: Texture2D, min_size: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = min_size
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return tr


## Logo de BOULEVARD SMASH: letras de cartel, contorno grueso, sombra y un letrero de calle.
class Logo extends Control:
	var small := false
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var k := 0.5 if small else 1.0
		var w := size.x
		var fl: Font = Game.font_logo if Game.font_logo else ThemeDB.fallback_font
		var ft: Font = Game.font_tag if Game.font_tag else ThemeDB.fallback_font
		draw_set_transform(Vector2(w * (0.0 if small else 0.5), 0), -0.04, Vector2.ONE)
		var ox := 0.0 if small else -w * 0.5
		# letrero de calle verde detrás
		var street_sign := Rect2(ox + 40 * k, 8 * k, 560 * k, 70 * k)
		draw_rect(street_sign.grow(6 * k), Color(0.95, 0.95, 0.95))
		draw_rect(street_sign, Color(0.08, 0.45, 0.28))
		draw_string(ft, Vector2(ox + 60 * k, 60 * k), "Av. del Boulevard", HORIZONTAL_ALIGNMENT_LEFT, -1,
			int(40 * k), Color(1, 1, 1))
		# BOULEVARD
		var y1 := 150.0 * k
		var fs1 := int(96 * k)
		draw_string_outline(fl, Vector2(ox + 8 * k, y1 + 8 * k), "BOULEVARD", HORIZONTAL_ALIGNMENT_LEFT, -1, fs1,
			int(26 * k), Color(0.05, 0.02, 0.1))
		draw_string_outline(fl, Vector2(ox, y1), "BOULEVARD", HORIZONTAL_ALIGNMENT_LEFT, -1, fs1, int(16 * k),
			Color(0.1, 0.05, 0.2))
		draw_string(fl, Vector2(ox, y1), "BOULEVARD", HORIZONTAL_ALIGNMENT_LEFT, -1, fs1, Color(0.97, 0.97, 1.0))
		# SMASH (con brillo que late, como un neón)
		var y2 := 240.0 * k
		var fs2 := int(118 * k)
		var glow := 0.6 + 0.4 * sin(_t * 3.0)
		var sx := ox + 330 * k
		draw_string_outline(fl, Vector2(sx + 10 * k, y2 + 10 * k), "SMASH", HORIZONTAL_ALIGNMENT_LEFT, -1, fs2,
			int(30 * k), Color(0.05, 0.02, 0.1))
		draw_string_outline(fl, Vector2(sx, y2), "SMASH", HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, int(34 * k),
			Color(1.0, 0.25, 0.45, 0.25 * glow))
		draw_string_outline(fl, Vector2(sx, y2), "SMASH", HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, int(16 * k),
			Color(0.55, 0.05, 0.2))
		draw_string(fl, Vector2(sx, y2), "SMASH", HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, ACCENT)
		# subrayado de spray
		draw_line(Vector2(ox + 20 * k, y2 + 16 * k), Vector2(sx - 20 * k, y2 + 8 * k), Color(1.0, 0.3, 0.5, 0.9),
			8.0 * k)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Fondo de los menús: el boulevard de noche (edificios, farolas, neones y luces de coches).
class MenuBackground extends Control:
	var _t := 0.0
	var _rng_seed := 7

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var s := get_viewport_rect().size
		var steps := 24
		for i in steps:
			var k := float(i) / steps
			var c := Color(0.05, 0.04, 0.16).lerp(Color(0.32, 0.1, 0.36), pow(k, 1.6))
			draw_rect(Rect2(0, s.y * k, s.x, s.y / steps + 1), c)
		var rng := RandomNumberGenerator.new()
		rng.seed = _rng_seed
		# estrellas
		for i in 50:
			var p := Vector2(rng.randf() * s.x, rng.randf() * s.y * 0.45)
			draw_circle(p, rng.randf_range(0.8, 1.8), Color(1, 1, 1, 0.25 + 0.2 * sin(_t * 2.0 + i)))
		# edificios lejanos y cercanos (con ventanas encendidas)
		for layer in 2:
			var base_y := s.y * (0.62 if layer == 0 else 0.72)
			var col := Color(0.1, 0.07, 0.22) if layer == 0 else Color(0.06, 0.04, 0.13)
			var x := -40.0 - layer * 50.0
			while x < s.x + 140.0:
				var bw := rng.randf_range(70, 140)
				var bh := rng.randf_range(120, 300) * (0.8 if layer == 0 else 1.0)
				draw_rect(Rect2(x, base_y - bh, bw, s.y), col)
				for wy in range(int(base_y - bh + 14), int(base_y - 10), 22):
					for wx in range(int(x + 10), int(x + bw - 12), 18):
						if rng.randf() < 0.35:
							var lit := Color(1.0, 0.8, 0.45, 0.35 if layer == 0 else 0.55)
							draw_rect(Rect2(wx, wy, 8, 11), lit)
				x += bw + rng.randf_range(4, 18)
		# neones
		var neon := [["BAR", Color(1, 0.3, 0.5)], ["24H", Color(0.3, 0.9, 1.0)], ["PAN", Color(1, 0.8, 0.3)]]
		var ft: Font = Game.font_tag if Game.font_tag else ThemeDB.fallback_font
		for i in neon.size():
			var flick := 1.0 if fmod(_t * (1.3 + i * 0.4), 5.0) > 0.12 else 0.3
			var c: Color = neon[i][1]
			var p := Vector2(120 + i * 430, s.y * 0.52 + (i % 2) * 30)
			draw_string(ft, p, neon[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(c.r, c.g, c.b, 0.35 * flick))
			draw_string(ft, p + Vector2(1, 1), neon[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 42, Color(c.r, c.g, c.b, 0.8 * flick))
		# calle, farolas y luces de coches
		draw_rect(Rect2(0, s.y * 0.86, s.x, s.y), Color(0.05, 0.04, 0.08))
		for i in 8:
			var lx := fposmod(i * 190.0 - _t * 30.0, s.x + 190.0) - 95.0
			draw_line(Vector2(lx, s.y * 0.86), Vector2(lx, s.y * 0.62), Color(0.15, 0.13, 0.2), 4.0)
			draw_circle(Vector2(lx, s.y * 0.62), 7.0, Color(1, 0.85, 0.55, 0.9))
			draw_circle(Vector2(lx, s.y * 0.62), 26.0, Color(1, 0.8, 0.5, 0.08))
		for i in 6:
			var cx := fposmod(i * 260.0 + _t * (160.0 + i * 25.0), s.x + 300.0) - 150.0
			var cy := s.y * (0.9 + (i % 2) * 0.04)
			draw_line(Vector2(cx - 60, cy), Vector2(cx, cy), Color(1.0, 0.2, 0.25, 0.5), 3.0)
			draw_circle(Vector2(cx, cy), 3.0, Color(1, 0.3, 0.3, 0.9))
		for i in 8:
			var lx2 := fposmod(i * 170.0, s.x)
			draw_line(Vector2(lx2, s.y * 0.93), Vector2(lx2 + 70, s.y * 0.93), Color(1, 1, 1, 0.12), 3.0)
