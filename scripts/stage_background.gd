extends CanvasLayer
## Fondo de un escenario, en capas con profundidad (paralaje):
##   cielo (quieto)  ·  nubes (se mueven solas)  ·  capa lejana  ·  capa media
## más partículas de ambiente (polen, estrellas, brasas, luciérnagas, nieve...).
## Las imágenes están en assets/stages/<stage_id>/ (las genera tools/make_stages.py).

@export var stage_id := "pradera"
@export var ambience := "pollen"
@export var far_factor := 0.06
@export var mid_factor := 0.16

var _layers := []


func _ready() -> void:
	layer = -10
	var base := "res://assets/stages/%s/" % stage_id
	var sky := TextureRect.new()
	sky.texture = load(base + "sky.png")
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	sky.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(sky)
	for spec in [["clouds", 0.02, 12.0, -20.0], ["far", far_factor, 0.0, 0.0], ["mid", mid_factor, 0.0, 0.0]]:
		var path: String = base + spec[0] + ".png"
		if not ResourceLoader.exists(path):
			continue
		var l := ScrollLayer.new()
		l.texture = load(path)
		l.factor = spec[1]
		l.drift = spec[2]
		l.y_offset = spec[3]
		add_child(l)
		_layers.append(l)
	var amb := Ambience.new()
	amb.kind = ambience
	add_child(amb)


## Una capa que se repite horizontalmente y se mueve con la cámara.
class ScrollLayer extends Node2D:
	var texture: Texture2D
	var factor := 0.1
	var drift := 0.0
	var y_offset := 0.0
	var _t := 0.0

	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if texture == null or texture.get_width() < 16:
			return
		var cam := get_viewport().get_camera_2d()
		var c := cam.get_screen_center_position() if cam else Vector2.ZERO
		var w := float(texture.get_width())
		var x := fposmod(-(c.x * factor) - _t * drift, w)
		var y := y_offset - (c.y - 40.0) * factor * 0.6
		draw_texture(texture, Vector2(x - w, y))
		draw_texture(texture, Vector2(x, y))
		if x + w < 1280.0:
			draw_texture(texture, Vector2(x + w, y))


## Partículas de ambiente (en la pantalla, detrás de los luchadores).
class Ambience extends Node2D:
	var kind := "pollen"
	var parts := []
	var _t := 0.0

	func _ready() -> void:
		var n: int = {"pollen": 40, "stars": 60, "lights": 26, "embers": 60, "fireflies": 36, "snow": 110}.get(kind, 30)
		for i in n:
			parts.append(_new_part(true))

	func _new_part(anywhere: bool) -> Dictionary:
		var p := {"x": randf() * 1280.0, "y": randf() * 720.0 if anywhere else 0.0, "s": randf_range(1.5, 4.0),
			"ph": randf() * TAU, "sp": randf_range(0.5, 1.5)}
		match kind:
			"embers":
				p["y"] = randf() * 720.0 if anywhere else 740.0
			"snow":
				p["y"] = randf() * 720.0 if anywhere else -10.0
		return p

	func _process(delta: float) -> void:
		_t += delta
		for p in parts:
			match kind:
				"pollen":
					p["x"] += (14.0 + 10.0 * sin(_t + p["ph"])) * delta * p["sp"]
					p["y"] += sin(_t * 1.3 + p["ph"]) * 10.0 * delta
				"embers":
					p["y"] -= 60.0 * p["sp"] * delta
					p["x"] += sin(_t * 2.0 + p["ph"]) * 20.0 * delta
					if p["y"] < -10.0:
						p.merge(_new_part(false), true)
				"snow":
					p["y"] += 50.0 * p["sp"] * delta
					p["x"] += (sin(_t + p["ph"]) * 20.0 - 15.0) * delta
					if p["y"] > 730.0:
						p.merge(_new_part(false), true)
				"fireflies", "lights":
					p["x"] += cos(_t * 0.7 * p["sp"] + p["ph"]) * 18.0 * delta
					p["y"] += sin(_t * 0.9 * p["sp"] + p["ph"]) * 14.0 * delta
			p["x"] = fposmod(p["x"], 1280.0)
		queue_redraw()

	func _draw() -> void:
		for p in parts:
			var tw := 0.5 + 0.5 * sin(_t * 3.0 * p["sp"] + p["ph"])
			var pos := Vector2(p["x"], p["y"])
			match kind:
				"pollen":
					draw_circle(pos, p["s"] * 0.8, Color(1, 1, 0.8, 0.45))
				"stars":
					draw_circle(pos, p["s"] * 0.5 * (0.5 + tw), Color(1, 1, 1, 0.3 + 0.6 * tw))
				"lights":
					draw_circle(pos, p["s"] * 4.0, Color(1, 0.8, 0.5, 0.06 + 0.06 * tw))
					draw_circle(pos, p["s"] * 1.5, Color(1, 0.85, 0.6, 0.2 + 0.2 * tw))
				"embers":
					draw_circle(pos, p["s"] * 0.7, Color(1, 0.5 + 0.3 * tw, 0.2, 0.8))
					draw_circle(pos, p["s"] * 2.0, Color(1, 0.4, 0.1, 0.15))
				"fireflies":
					draw_circle(pos, p["s"] * 3.0, Color(0.8, 1, 0.4, 0.1 * tw))
					draw_circle(pos, p["s"] * 0.9, Color(0.9, 1, 0.5, 0.3 + 0.6 * tw))
				"snow":
					draw_circle(pos, p["s"] * 0.8, Color(1, 1, 1, 0.8))
		if kind == "stars" and fmod(_t, 4.0) < 0.6:  # estrella fugaz
			var k := fmod(_t, 4.0) / 0.6
			var sx := 200.0 + fmod(floor(_t / 4.0) * 377.0, 900.0)
			var a := Vector2(sx + k * 300.0, 60.0 + k * 150.0)
			draw_line(a, a - Vector2(80, 40), Color(1, 1, 1, 0.7 * (1.0 - k)), 2.0)
