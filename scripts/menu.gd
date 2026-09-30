extends Control
## Menú principal + selección de personajes.
##  P1 (A / D)  y  P2 (← / →)  cambian de personaje.
##  G / .  (especial)  alterna HUMANO <-> CPU.
##  W / S / ↑ / ↓  cambian las vidas.   ENTER  empieza.

const SHEET_FRAME := 64

var _choice := [0, 1]         # índice en CharacterData.ORDER para cada jugador
var _cards := []
var _stocks_label: Label
var _t := 0.0


func _ready() -> void:
	# Fondo
	var bg := TextureRect.new()
	bg.texture = load("res://assets/sprites/background.png")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	# Título
	var title := _label("SUPER BRAWL", 84, Color(1, 0.9, 0.3), 16)
	title.position = Vector2(0, 20)
	title.size = Vector2(1280, 100)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var sub := _label("Elige tu luchador", 26, Color.WHITE, 6)
	sub.position = Vector2(0, 115)
	sub.size = Vector2(1280, 40)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub)

	# Tarjetas de jugador
	for i in 2:
		_cards.append(_build_card(i, Vector2(130 + i * 590, 165)))

	# Pie
	_stocks_label = _label("", 26, Color.WHITE, 6)
	_stocks_label.position = Vector2(0, 585)
	_stocks_label.size = Vector2(1280, 36)
	_stocks_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_stocks_label)
	var help := _label(
		"P1:  A / D personaje   G humano/CPU        P2:  ← / → personaje   . humano/CPU        W/S o ↑/↓ vidas",
		17, Color(1, 1, 1, 0.9), 4)
	help.position = Vector2(0, 630)
	help.size = Vector2(1280, 28)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(help)
	var start := _label("ENTER  =  ¡A PELEAR!", 36, Color(0.5, 1, 0.5), 8)
	start.position = Vector2(0, 665)
	start.size = Vector2(1280, 44)
	start.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(start)
	_refresh()


func _label(text: String, size: int, color: Color, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
	return l


func _build_card(i: int, pos: Vector2) -> Dictionary:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(4)
	sb.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = pos
	panel.size = Vector2(430, 410)
	add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	panel.add_child(vb)

	var head := _label("", 28, Color.WHITE, 6)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(head)

	var tr := TextureRect.new()
	var at := AtlasTexture.new()
	at.atlas = load("res://assets/sprites/char_rojo.png")
	at.region = Rect2(0, 0, SHEET_FRAME, SHEET_FRAME)
	tr.texture = at
	tr.custom_minimum_size = Vector2(200, 200)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vb.add_child(tr)

	var nm := _label("", 34, Color.WHITE, 6)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(nm)
	var desc := _label("", 16, Color(1, 1, 1, 0.9))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(desc)

	var bars := {}
	for stat in ["Velocidad", "Peso", "Potencia"]:
		var row := HBoxContainer.new()
		var l := _label(stat, 16, Color.WHITE)
		l.custom_minimum_size = Vector2(100, 0)
		row.add_child(l)
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(260, 16)
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(pb)
		vb.add_child(row)
		bars[stat] = pb

	return {"panel": panel, "style": sb, "head": head, "tex": tr, "atlas": at, "name": nm, "desc": desc,
		"bars": bars}


func _refresh() -> void:
	for i in 2:
		var card: Dictionary = _cards[i]
		var id: String = CharacterData.ORDER[_choice[i]]
		var d := CharacterData.get_data(id)
		var cfg: Dictionary = Game.players[i]
		cfg["char"] = id
		var who := "CPU" if cfg["cpu"] else "JUGADOR %d" % (i + 1)
		card["head"].text = who
		card["head"].add_theme_color_override("font_color", d["color"])
		card["style"].border_color = d["color"]
		card["name"].text = d["name"]
		card["name"].add_theme_color_override("font_color", d["color"])
		card["desc"].text = d["desc"]
		card["atlas"].atlas = load(d["sheet"])
		card["bars"]["Velocidad"].value = d["speed"] / 400.0 * 100.0
		card["bars"]["Peso"].value = d["weight"] / 140.0 * 100.0
		card["bars"]["Potencia"].value = d["moves"]["neutral"]["dmg"] / 12.0 * 100.0
	_stocks_label.text = "◄  Vidas: %d  ►" % Game.stocks


func _process(delta: float) -> void:
	_t += delta
	var frame := int(_t * 5.0) % 4
	for card in _cards:
		card["atlas"].region = Rect2(frame * SHEET_FRAME, 0, SHEET_FRAME, SHEET_FRAME)


func _unhandled_input(event: InputEvent) -> void:
	var n := CharacterData.ORDER.size()
	var changed := false
	if event.is_action_pressed("p1_left"):
		_choice[0] = (_choice[0] + n - 1) % n
		changed = true
	elif event.is_action_pressed("p1_right"):
		_choice[0] = (_choice[0] + 1) % n
		changed = true
	elif event.is_action_pressed("p2_left"):
		_choice[1] = (_choice[1] + n - 1) % n
		changed = true
	elif event.is_action_pressed("p2_right"):
		_choice[1] = (_choice[1] + 1) % n
		changed = true
	elif event.is_action_pressed("p1_special"):
		Game.players[0]["cpu"] = not Game.players[0]["cpu"]
		changed = true
	elif event.is_action_pressed("p2_special"):
		Game.players[1]["cpu"] = not Game.players[1]["cpu"]
		changed = true
	elif event.is_action_pressed("p1_up") or event.is_action_pressed("p2_up"):
		Game.stocks = mini(Game.stocks + 1, 9)
		changed = true
	elif event.is_action_pressed("p1_down") or event.is_action_pressed("p2_down"):
		Game.stocks = maxi(Game.stocks - 1, 1)
		changed = true
	elif event.is_action_pressed("ui_start"):
		Game.play_sfx("start")
		Game.goto_stage()
		return
	elif event.is_action_pressed("pause"):
		get_tree().quit()
		return
	if changed:
		Game.play_sfx("select")
		_refresh()
