class_name CardPicker
extends CanvasLayer
## Pantalla para elegir 1 de 3 cartas (modo Caos de Cartas). El juego queda en pausa
## para que haya tiempo de leer. El CPU elige solo (se ve lo que elige).

signal picked(fighter, card_id)

var fighter: Fighter
var reason := ""               # "inicio" o "ko"
var _cards := []
var _sel := 1
var _nodes: Array[Control] = []
var _t := 0.0
var _done := false
var _cpu_timer := 1.6
var _root: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 70
	_cards = Cards.draw_three(fighter.cards)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.08, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var col: Color = fighter.data["color"]
	var who := "CPU" if fighter.is_cpu else "JUGADOR %d" % fighter.player_id
	var title := UI.label("%s  ·  %s" % [who, fighter.data["name"]], 26, col, true, 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(0, 40)
	title.size = Vector2(1280, 36)
	_root.add_child(title)
	var head := UI.label("¡ELIGE UNA CARTA!" if reason == "inicio" else "¡KO! GANASTE UNA CARTA", 54, UI.ACCENT, true, 12)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.position = Vector2(0, 78)
	head.size = Vector2(1280, 70)
	_root.add_child(head)
	for i in _cards.size():
		var card := CardView.new()
		card.card = _cards[i]
		card.position = Vector2(170 + i * 330, 180)
		card.size = Vector2(290, 400)
		card.pivot_offset = card.size / 2.0
		card.scale = Vector2(0.2, 0.2)
		card.modulate.a = 0.0
		_root.add_child(card)
		_nodes.append(card)
		var tw := card.create_tween()
		tw.tween_interval(0.08 * i)
		tw.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(card, "modulate:a", 1.0, 0.2)
	var hint := "CPU eligiendo..." if fighter.is_cpu else "← →  elegir        ATAQUE / SALTO / ENTER  tomar carta"
	var h := UI.label(hint, 20, UI.MUTED, false, 4)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.position = Vector2(0, 610)
	h.size = Vector2(1280, 30)
	_root.add_child(h)
	if not fighter.cards.is_empty():
		var owned := []
		for id in fighter.cards:
			owned.append(Cards.get_card(id)["name"])
		var o := UI.label("Tus cartas: " + ", ".join(owned), 16, UI.TEXT)
		o.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		o.position = Vector2(0, 648)
		o.size = Vector2(1280, 24)
		o.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_root.add_child(o)
	Game.play_sfx("card_show")
	if fighter.is_cpu:
		_sel = randi() % _cards.size()
	_refresh()


func _refresh() -> void:
	for i in _nodes.size():
		var c: CardView = _nodes[i]
		c.selected = i == _sel


func _process(delta: float) -> void:
	_t += delta
	if _done:
		return
	if fighter.is_cpu:
		_cpu_timer -= delta
		if _cpu_timer <= 0.0:
			_choose()
		return
	var p := "p%d_" % fighter.player_id
	if Input.is_action_just_pressed(p + "left"):
		_sel = (_sel + _cards.size() - 1) % _cards.size()
		Game.play_sfx("menu_move")
		_refresh()
	elif Input.is_action_just_pressed(p + "right"):
		_sel = (_sel + 1) % _cards.size()
		Game.play_sfx("menu_move")
		_refresh()
	elif _t > 0.5 and (Input.is_action_just_pressed(p + "attack") or Input.is_action_just_pressed(p + "jump")
			or Input.is_action_just_pressed("ui_start")):
		_choose()


## Elige la carta seleccionada (también lo usan las pruebas automáticas).
func _choose() -> void:
	if _done:
		return
	_done = true
	var card: Dictionary = _cards[_sel]
	Cards.apply(fighter, card["id"])
	Game.play_sfx("card_pick")
	var chosen: CardView = _nodes[_sel]
	var tw := create_tween()
	tw.tween_property(chosen, "scale", Vector2(1.15, 1.15), 0.15)
	for i in _nodes.size():
		if i != _sel:
			tw.parallel().tween_property(_nodes[i], "modulate:a", 0.0, 0.2)
	tw.tween_interval(0.35)
	tw.tween_property(_root, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func():
		picked.emit(fighter, card["id"])
		queue_free())


## Dibujo de una carta.
class CardView extends Control:
	var card := {}
	var selected := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		var target := -18.0 if selected else 0.0
		position.y = lerpf(position.y, 180.0 + target, 1.0 - exp(-12.0 * delta))
		queue_redraw()

	func _draw() -> void:
		var r: int = card["rarity"]
		var col: Color = Cards.RARITY_COLORS[r]
		var w := size.x
		var h := size.y
		if selected:
			for i in 4:
				draw_style_box(UI.style(Color(col.r, col.g, col.b, 0.12), 26, Color(0, 0, 0, 0), 0, false),
					Rect2(-8 - i * 5, -8 - i * 5, w + 16 + i * 10, h + 16 + i * 10))
		draw_style_box(UI.style(Color(0.08, 0.09, 0.2), 22, col if selected else col.darkened(0.4), 4), Rect2(0, 0, w, h))
		# brillo de fondo
		draw_style_box(UI.style(Color(col.r, col.g, col.b, 0.18), 18, Color(0, 0, 0, 0), 0, false), Rect2(12, 12, w - 24, 170))
		var c := Vector2(w / 2.0, 100)
		var pulse := 1.0 + (0.05 * sin(_t * 4.0) if selected else 0.0)
		draw_circle(c, 62 * pulse, Color(col.r, col.g, col.b, 0.35))
		draw_circle(c, 52 * pulse, Color(0.1, 0.11, 0.24))
		draw_arc(c, 54 * pulse, 0, TAU, 48, col, 4.0)
		var ft: Font = Game.font_title
		var icon: String = card["icon"]
		var fs := 54 if icon.length() <= 2 else 36
		draw_string_outline(ft, Vector2(0, c.y + fs * 0.35), icon, HORIZONTAL_ALIGNMENT_CENTER, w, fs, 8, Color.BLACK)
		draw_string(ft, Vector2(0, c.y + fs * 0.35), icon, HORIZONTAL_ALIGNMENT_CENTER, w, fs, Color.WHITE)
		draw_string(Game.font_body, Vector2(0, 204), Cards.RARITY_NAMES[r], HORIZONTAL_ALIGNMENT_CENTER, w, 14, col)
		draw_string_outline(ft, Vector2(0, 240), card["name"], HORIZONTAL_ALIGNMENT_CENTER, w, 30, 6, Color.BLACK)
		draw_string(ft, Vector2(0, 240), card["name"], HORIZONTAL_ALIGNMENT_CENTER, w, 30, Color.WHITE)
		draw_multiline_string(Game.font_body, Vector2(22, 278), card["desc"], HORIZONTAL_ALIGNMENT_CENTER, w - 44,
			18, -1, UI.TEXT)
		if selected:
			draw_string(ft, Vector2(0, h - 20), "▲ ELEGIR ▲", HORIZONTAL_ALIGNMENT_CENTER, w, 20, col)
