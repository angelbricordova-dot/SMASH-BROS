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
	at.atlas = load("res://assets/sprites/idle_%s.png" % char_id)
	at.region = Rect2(col * Fighter.FRAME_W, 0, Fighter.FRAME_W, Fighter.FRAME_H)
	return at


## Un cuadro cualquiera de la hoja completa (fila = animación).
static func sheet_tex(char_id: String, row: int, col: int) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/sprites/char_%s.png" % char_id)
	at.region = Rect2(col * Fighter.FRAME_W, row * Fighter.FRAME_H, Fighter.FRAME_W, Fighter.FRAME_H)
	return at


## Retrato (la cabeza) de un personaje.
static func head_tex(char_id: String) -> Texture2D:
	return load("res://assets/sprites/portrait_%s.png" % char_id)


static func pixel_rect(tex: Texture2D, min_size: Vector2) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.custom_minimum_size = min_size
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return tr


## Fondo animado con degradado para los menús.
class MenuBackground extends Control:
	var _t := 0.0

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
			var c := Color(0.07, 0.06, 0.2).lerp(Color(0.2, 0.08, 0.3), k)
			draw_rect(Rect2(0, s.y * k, s.x, s.y / steps + 1), c)
		# franjas diagonales que se mueven
		for i in 14:
			var x := fposmod(i * 160.0 + _t * 40.0, s.x + 400.0) - 200.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 60, 0),
				Vector2(x - 240, s.y), Vector2(x - 300, s.y)]), Color(1, 1, 1, 0.03))
		# partículas
		for i in 40:
			var px := fposmod(i * 97.0 + _t * (10 + i % 5 * 6), s.x)
			var py := fposmod(i * 53.0 - _t * (20 + i % 7 * 5), s.y)
			draw_circle(Vector2(px, py), 1.5 + (i % 3), Color(1, 1, 1, 0.12))
