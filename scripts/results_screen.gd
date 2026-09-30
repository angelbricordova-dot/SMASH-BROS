class_name ResultsScreen
extends CanvasLayer
## Pantalla de resultados: el ganador celebrando, confeti y estadísticas de la partida.

var fighters: Array = []
var winner: Fighter = null

var _win_tex: AtlasTexture
var _t := 0.0
var _root: Control


func _ready() -> void:
	layer = 60
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.1, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.78, 0.4)

	var confetti := Confetti.new()
	_root.add_child(confetti)

	var col: Color = winner.data["color"] if winner else UI.MUTED
	# --- Ganador (a la izquierda) ---
	var glow := GlowCircle.new()
	glow.color = col
	glow.position = Vector2(300, 330)
	_root.add_child(glow)
	if winner:
		_win_tex = UI.frame_tex(winner.char_id, 10, 0)
		var pic := UI.pixel_rect(_win_tex, Vector2(384, 384))
		pic.position = Vector2(108, 110)
		pic.size = Vector2(384, 384)
		_root.add_child(pic)
	var who := ""
	if winner:
		who = "CPU" if winner.is_cpu else "JUGADOR %d" % winner.player_id
	var title := UI.label("¡GANA %s!" % (winner.data["name"] if winner else "NADIE"), 64, col, true, 14)
	title.position = Vector2(560, 90)
	_root.add_child(title)
	var sub := UI.label(who if winner else "Empate", 26, UI.TEXT, false, 6)
	sub.position = Vector2(564, 170)
	_root.add_child(sub)

	# --- Tabla de estadísticas ---
	var table := UI.panel(UI.CARD, 18)
	table.position = Vector2(560, 220)
	table.custom_minimum_size = Vector2(640, 0)
	_root.add_child(table)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 12)
	table.add_child(grid)
	for h in ["", "Luchador", "KOs", "Caídas", "Daño", "Parries"]:
		grid.add_child(UI.label(h, 16, UI.MUTED))
	var ranked := fighters.duplicate()
	ranked.sort_custom(func(a, b): return a.stocks > b.stocks or (a.stocks == b.stocks and a.kos > b.kos))
	for f in ranked:
		var fc: Color = f.data["color"]
		grid.add_child(UI.pixel_rect(UI.head_tex(f.char_id), Vector2(40, 40)))
		grid.add_child(UI.label(("CPU " if f.is_cpu else "P%d " % f.player_id) + f.data["name"], 20, fc))
		grid.add_child(UI.label(str(f.kos), 22, UI.TEXT, true))
		grid.add_child(UI.label(str(f.falls), 22, UI.TEXT, true))
		grid.add_child(UI.label("%d%%" % int(f.damage_dealt), 22, UI.TEXT, true))
		grid.add_child(UI.label(str(f.parries), 22, UI.TEXT, true))

	var hint := UI.label("ENTER  Revancha          ESC  Menú", 24, UI.ACCENT, true, 6)
	hint.position = Vector2(560, 610)
	_root.add_child(hint)

	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.35)


func _process(delta: float) -> void:
	_t += delta
	if _win_tex:
		_win_tex.region.position.x = (int(_t * 7.0) % 6) * Fighter.FRAME


class GlowCircle extends Node2D:
	var color := Color.WHITE
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		for i in 6:
			var r := 110.0 + i * 22.0 + sin(_t * 2.0 + i) * 6.0
			draw_circle(Vector2.ZERO, r, Color(color.r, color.g, color.b, 0.07))
		for i in 12:
			var a := _t * 0.4 + i * TAU / 12.0
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, Vector2(cos(a - 0.08), sin(a - 0.08)) * 260,
				Vector2(cos(a + 0.08), sin(a + 0.08)) * 260]), Color(color.r, color.g, color.b, 0.08))


class Confetti extends Control:
	var _pieces := []
	var _t := 0.0

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cols := [Color(1, 0.35, 0.35), Color(0.35, 0.75, 1), Color(1, 0.85, 0.3), Color(0.5, 0.95, 0.4), Color(0.8, 0.5, 1)]
		for i in 120:
			_pieces.append({"x": randf() * 1280.0, "y": randf_range(-800, 0), "vy": randf_range(80, 200),
				"vx": randf_range(-40, 40), "r": randf() * TAU, "vr": randf_range(-6, 6), "c": cols.pick_random()})

	func _process(delta: float) -> void:
		_t += delta
		for p in _pieces:
			p["y"] += p["vy"] * delta
			p["x"] += p["vx"] * delta + sin(_t * 3.0 + p["r"]) * 30.0 * delta
			p["r"] += p["vr"] * delta
			if p["y"] > 740.0:
				p["y"] = -20.0
		queue_redraw()

	func _draw() -> void:
		for p in _pieces:
			draw_set_transform(Vector2(p["x"], p["y"]), p["r"], Vector2(1, absf(sin(p["r"] * 2.0)) + 0.2))
			draw_rect(Rect2(-5, -3, 10, 6), p["c"])
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
