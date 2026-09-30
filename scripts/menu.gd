extends Control
## Menú: Título  →  Elegir luchadores  →  Elegir escenario  →  ¡A pelear!
##
## Selección de luchador (cada jugador con sus teclas):
##   izquierda/derecha = elegir   ·   ATAQUE = listo   ·   ESPECIAL = Humano/CPU
##   arriba/abajo = dificultad del CPU   ·   ENTER = continuar   ·   ESC = volver
## Selección de escenario:
##   izquierda/derecha = elegir   ·   arriba/abajo = vidas   ·   ESPECIAL = objetos sí/no

enum Screen { TITLE, CHARS, STAGE }

const TILE := Vector2(150, 150)

var _screen := Screen.TITLE
var _layer: Control
var _t := 0.0
var _anim_atlases: Array[AtlasTexture] = []   # cuadros animados (idle)

# selección de personajes
var _cursor := [0, 1]
var _ready_flags := [false, false]
var _tiles: Array[Panel] = []
var _badges := []
var _cards := []

# selección de escenario
var _stage_sel := 0
var _stage_cards: Array[PanelContainer] = []
var _rules_label: Label


func _ready() -> void:
	add_child(UI.MenuBackground.new())
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	# recuperar la selección anterior
	for i in 2:
		var c: String = Game.players[i]["char"]
		_cursor[i] = CharacterData.ORDER.size() if c == "random" else maxi(0, CharacterData.ORDER.find(c))
	var sid := Game.stage_id
	_stage_sel = Game.STAGES.size() if sid == "random" else 0
	for i in Game.STAGES.size():
		if Game.STAGES[i]["id"] == sid:
			_stage_sel = i
	_show(Screen.TITLE)


func _clear() -> void:
	for c in _layer.get_children():
		c.queue_free()
	_anim_atlases.clear()
	_tiles.clear()
	_badges.clear()
	_cards.clear()
	_stage_cards.clear()


func _show(s: Screen) -> void:
	_screen = s
	_clear()
	match s:
		Screen.TITLE: _build_title()
		Screen.CHARS: _build_chars()
		Screen.STAGE: _build_stage()
	_layer.modulate.a = 0.0
	create_tween().tween_property(_layer, "modulate:a", 1.0, 0.2)


func _add(node: Control, pos: Vector2, size := Vector2.ZERO) -> Control:
	node.position = pos
	if size != Vector2.ZERO:
		node.size = size
	_layer.add_child(node)
	return node


func _header(text: String, step: String) -> void:
	_add(UI.label(text, 54, UI.TEXT, true, 10), Vector2(60, 24))
	var chip := UI.panel(UI.ACCENT, 20)
	chip.add_child(UI.label(step, 18, Color(0.1, 0.08, 0.2), true))
	_add(chip, Vector2(1100, 36))


# ------------------------------------------------------------------
#  TÍTULO
# ------------------------------------------------------------------
func _build_title() -> void:
	var logo := UI.label("SUPER BRAWL", 136, UI.ACCENT, true, 26)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.name = "Logo"
	_add(logo, Vector2(0, 90), Vector2(1280, 170))
	var sub := UI.label("Peleas de plataformas  ·  4 luchadores  ·  3 escenarios", 24, UI.TEXT, false, 6)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(sub, Vector2(0, 270), Vector2(1280, 40))
	for i in CharacterData.ORDER.size():
		var at := UI.frame_tex(CharacterData.ORDER[i], 0, 0)
		_anim_atlases.append(at)
		var pic := UI.pixel_rect(at, Vector2(220, 220))
		pic.flip_h = i >= 2
		_add(pic, Vector2(170 + i * 240, 320), Vector2(220, 220))
	var press := UI.label("PRESIONA  ENTER", 36, Color.WHITE, true, 8)
	press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	press.name = "Press"
	_add(press, Vector2(0, 590), Vector2(1280, 50))
	var foot := UI.label("F11 pantalla completa  ·  ESC salir", 16, UI.MUTED)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(foot, Vector2(0, 680), Vector2(1280, 24))


# ------------------------------------------------------------------
#  LUCHADORES
# ------------------------------------------------------------------
func _build_chars() -> void:
	_header("ELIGE TU LUCHADOR", "PASO 1 / 2")
	var n := CharacterData.ORDER.size() + 1
	var x0 := 640.0 - (n * TILE.x + (n - 1) * 16.0) / 2.0
	for i in n:
		var tile := Panel.new()
		var is_random := i == CharacterData.ORDER.size()
		var col: Color = UI.MUTED if is_random else CharacterData.get_data(CharacterData.ORDER[i])["color"]
		tile.add_theme_stylebox_override("panel", UI.style(UI.CARD, 18, col, 3))
		_add(tile, Vector2(x0 + i * (TILE.x + 16.0), 108), TILE)
		if is_random:
			var q := UI.label("?", 90, UI.ACCENT, true, 10)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.position = Vector2(0, 0)
			q.size = Vector2(TILE.x, 110)
			tile.add_child(q)
		else:
			var head := UI.pixel_rect(UI.head_tex(CharacterData.ORDER[i]), Vector2(104, 104))
			head.position = Vector2(23, 4)
			head.size = Vector2(104, 104)
			tile.add_child(head)
		var nm := UI.label("ALEATORIO" if is_random else CharacterData.get_data(CharacterData.ORDER[i])["name"], 18, col, true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.position = Vector2(0, 112)
		nm.size = Vector2(TILE.x, 30)
		tile.add_child(nm)
		_tiles.append(tile)
	for p in 2:
		var badge := UI.panel(UI.P_COLORS[p], 12)
		badge.add_child(UI.label("P%d" % (p + 1), 16, Color.WHITE, true, 4))
		_layer.add_child(badge)
		_badges.append(badge)
	for p in 2:
		_cards.append(_build_player_card(p, Vector2(60 + p * 600, 290)))
	var hint := UI.label("P1:  A/D elegir · F listo · G Humano/CPU · W/S dificultad          P2:  ←/→ · , listo · . Humano/CPU · ↑/↓ dificultad",
		15, UI.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(hint, Vector2(0, 640), Vector2(1280, 22))
	var go := UI.label("ENTER  continuar          ESC  volver", 22, UI.ACCENT, true, 6)
	go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(go, Vector2(0, 670), Vector2(1280, 30))
	_refresh_chars()


func _build_player_card(p: int, pos: Vector2) -> Dictionary:
	var panel := Panel.new()
	var sb := UI.style(UI.CARD, 22, UI.P_COLORS[p], 3)
	panel.add_theme_stylebox_override("panel", sb)
	_add(panel, pos, Vector2(560, 336))
	var glow := ColorRect.new()
	glow.position = Vector2(14, 14)
	glow.size = Vector2(200, 308)
	panel.add_child(glow)
	var at := UI.frame_tex("rojo", 0, 0)
	_anim_atlases.append(at)
	var pic := UI.pixel_rect(at, Vector2(240, 240))
	pic.position = Vector2(-6, 50)
	pic.size = Vector2(240, 240)
	panel.add_child(pic)
	var q := UI.label("?", 150, UI.ACCENT, true, 16)
	q.position = Vector2(70, 60)
	panel.add_child(q)
	var who := UI.label("", 18, UI.P_COLORS[p], true)
	who.position = Vector2(236, 18)
	panel.add_child(who)
	var nm := UI.label("", 44, Color.WHITE, true, 8)
	nm.position = Vector2(234, 40)
	panel.add_child(nm)
	var desc := UI.label("", 15, UI.MUTED)
	desc.position = Vector2(236, 102)
	desc.size = Vector2(304, 44)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(desc)
	var abil := VBoxContainer.new()
	abil.position = Vector2(236, 150)
	abil.add_theme_constant_override("separation", 2)
	panel.add_child(abil)
	var mode := UI.panel(UI.CARD_HI, 14)
	mode.position = Vector2(236, 262)
	var mode_l := UI.label("", 18, Color.WHITE, true)
	mode.add_child(mode_l)
	panel.add_child(mode)
	var ready_stamp := UI.label("¡LISTO!", 52, UI.GOOD, true, 12)
	ready_stamp.position = Vector2(20, 250)
	ready_stamp.rotation = -0.12
	panel.add_child(ready_stamp)
	return {"panel": panel, "style": sb, "glow": glow, "atlas": at, "pic": pic, "q": q, "who": who, "name": nm,
		"desc": desc, "abil": abil, "mode": mode_l, "ready": ready_stamp}


func _refresh_chars() -> void:
	var n := CharacterData.ORDER.size()
	for p in 2:
		var c: int = _cursor[p]
		var id: String = "random" if c == n else CharacterData.ORDER[c]
		Game.players[p]["char"] = id
		var tile := _tiles[c]
		var badge: PanelContainer = _badges[p]
		badge.position = tile.position + Vector2(8 + p * 84, -14)
		var card: Dictionary = _cards[p]
		var cfg: Dictionary = Game.players[p]
		var col: Color = UI.ACCENT if id == "random" else CharacterData.get_data(id)["color"]
		card["glow"].color = Color(col.r, col.g, col.b, 0.12)
		card["who"].text = ("CPU  ·  " + Game.LEVEL_NAMES[cfg.get("level", 1)]) if cfg["cpu"] else "JUGADOR %d" % (p + 1)
		card["pic"].visible = id != "random"
		card["q"].visible = id == "random"
		for a in card["abil"].get_children():
			a.queue_free()
		if id == "random":
			card["name"].text = "ALEATORIO"
			card["name"].add_theme_color_override("font_color", UI.ACCENT)
			card["desc"].text = "¡Sorpresa! Se elige un luchador al azar."
		else:
			var d := CharacterData.get_data(id)
			card["atlas"].atlas = load(d["sheet"])
			card["name"].text = d["name"]
			card["name"].add_theme_color_override("font_color", col)
			card["desc"].text = d["desc"]
			var keys := ["Especial", "Arriba + Especial", "Ulti"]
			for i in 3:
				var row := HBoxContainer.new()
				row.add_child(UI.label("★ ", 16, col))
				row.add_child(UI.label(keys[i] + ": ", 15, UI.MUTED))
				row.add_child(UI.label(d["abilities"][i], 15, UI.TEXT))
				card["abil"].add_child(row)
		card["mode"].text = ("CPU  ◄ %s ►" % Game.LEVEL_NAMES[cfg.get("level", 1)] if cfg["cpu"] else "HUMANO")
		card["ready"].visible = _ready_flags[p]
		card["style"].border_color = UI.GOOD if _ready_flags[p] else UI.P_COLORS[p]


# ------------------------------------------------------------------
#  ESCENARIO
# ------------------------------------------------------------------
func _build_stage() -> void:
	_header("ELIGE EL ESCENARIO", "PASO 2 / 2")
	var n := Game.STAGES.size() + 1
	for i in n:
		var is_random := i == Game.STAGES.size()
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.style(UI.CARD, 20))
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 6)
		card.add_child(vb)
		var thumb: Control
		if is_random:
			var q := UI.label("?", 110, UI.ACCENT, true, 12)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			q.custom_minimum_size = Vector2(256, 144)
			thumb = q
		else:
			var path: String = Game.STAGES[i]["thumb"]
			var tex: Texture2D = load(path) if ResourceLoader.exists(path) else load("res://assets/sprites/bg_%s.png" % Game.STAGES[i]["id"])
			var tr := TextureRect.new()
			tr.texture = tex
			tr.custom_minimum_size = Vector2(256, 144)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			thumb = tr
		vb.add_child(thumb)
		var nm := UI.label("Aleatorio" if is_random else Game.STAGES[i]["name"], 26, UI.TEXT, true)
		vb.add_child(nm)
		var desc := UI.label("¡Que decida la suerte!" if is_random else Game.STAGES[i]["desc"], 14, UI.MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(256, 40)
		vb.add_child(desc)
		card.pivot_offset = Vector2(140, 130)
		_add(card, Vector2(36 + i * 306, 140))
		_stage_cards.append(card)
	var rules := UI.panel(UI.CARD, 18)
	_add(rules, Vector2(340, 480), Vector2(600, 0))
	_rules_label = UI.label("", 26, UI.TEXT, true)
	_rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules.add_child(_rules_label)
	var hint := UI.label("←/→ escenario   ·   ↑/↓ vidas   ·   G o . objetos sí/no", 16, UI.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(hint, Vector2(0, 620), Vector2(1280, 24))
	var go := UI.label("ENTER  ¡A PELEAR!          ESC  volver", 24, UI.ACCENT, true, 6)
	go.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(go, Vector2(0, 656), Vector2(1280, 34))
	_refresh_stage()


func _refresh_stage() -> void:
	for i in _stage_cards.size():
		var sel := i == _stage_sel
		_stage_cards[i].add_theme_stylebox_override("panel",
			UI.style(UI.CARD_HI if sel else UI.CARD, 20, UI.ACCENT if sel else Color(0, 0, 0, 0), 4 if sel else 0))
		_stage_cards[i].scale = Vector2(1.06, 1.06) if sel else Vector2.ONE
		_stage_cards[i].modulate = Color.WHITE if sel else Color(0.75, 0.75, 0.85)
	Game.stage_id = "random" if _stage_sel == Game.STAGES.size() else Game.STAGES[_stage_sel]["id"]
	_rules_label.text = "Vidas  ◄ %d ►        Objetos  %s" % [Game.stocks, "SÍ (bate y arco)" if Game.items_on else "NO"]


# ------------------------------------------------------------------
#  Animación y controles
# ------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	var frame := int(_t * 5.0) % 4
	for at in _anim_atlases:
		at.region.position = Vector2(frame * Fighter.FRAME, 0)
	if _screen == Screen.TITLE and _layer.has_node("Press"):
		_layer.get_node("Press").modulate.a = 0.55 + 0.45 * sin(_t * 4.0)
		_layer.get_node("Logo").position.y = 90 + sin(_t * 1.6) * 6.0


func _pressed(event: InputEvent, what: String) -> int:
	## Devuelve el jugador (0 o 1) que presionó la acción, o -1.
	for p in 2:
		if event.is_action_pressed("p%d_%s" % [p + 1, what]):
			return p
	return -1


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	match _screen:
		Screen.TITLE:
			if event.is_action_pressed("ui_start") or _pressed(event, "attack") >= 0 or _pressed(event, "jump") >= 0:
				Game.play_sfx("menu_confirm")
				_show(Screen.CHARS)
			elif event.is_action_pressed("ui_back"):
				get_tree().quit()
		Screen.CHARS:
			_input_chars(event)
		Screen.STAGE:
			_input_stage(event)


func _input_chars(event: InputEvent) -> void:
	var n := CharacterData.ORDER.size() + 1
	var p := _pressed(event, "left")
	if p >= 0 and not _ready_flags[p]:
		_cursor[p] = (_cursor[p] + n - 1) % n
		Game.play_sfx("menu_move")
		_refresh_chars()
		return
	p = _pressed(event, "right")
	if p >= 0 and not _ready_flags[p]:
		_cursor[p] = (_cursor[p] + 1) % n
		Game.play_sfx("menu_move")
		_refresh_chars()
		return
	p = _pressed(event, "attack")
	if p >= 0:
		_ready_flags[p] = not _ready_flags[p]
		Game.play_sfx("menu_confirm" if _ready_flags[p] else "menu_back")
		_refresh_chars()
		if _ready_flags[0] and _ready_flags[1]:
			_show(Screen.STAGE)
		return
	p = _pressed(event, "special")
	if p >= 0:
		Game.players[p]["cpu"] = not Game.players[p]["cpu"]
		Game.play_sfx("select")
		_refresh_chars()
		return
	for dir in ["up", "down"]:
		p = _pressed(event, dir)
		if p >= 0 and Game.players[p]["cpu"]:
			var lv: int = Game.players[p].get("level", 1)
			lv = clampi(lv + (1 if dir == "up" else -1), 0, 2)
			Game.players[p]["level"] = lv
			Game.play_sfx("menu_move")
			_refresh_chars()
			return
	if event.is_action_pressed("ui_start"):
		Game.play_sfx("menu_confirm")
		_show(Screen.STAGE)
	elif event.is_action_pressed("ui_back"):
		Game.play_sfx("menu_back")
		_ready_flags = [false, false]
		_show(Screen.TITLE)


func _input_stage(event: InputEvent) -> void:
	var n := Game.STAGES.size() + 1
	if _pressed(event, "left") >= 0:
		_stage_sel = (_stage_sel + n - 1) % n
		Game.play_sfx("menu_move")
		_refresh_stage()
	elif _pressed(event, "right") >= 0:
		_stage_sel = (_stage_sel + 1) % n
		Game.play_sfx("menu_move")
		_refresh_stage()
	elif _pressed(event, "up") >= 0:
		Game.stocks = mini(Game.stocks + 1, 9)
		Game.play_sfx("menu_move")
		_refresh_stage()
	elif _pressed(event, "down") >= 0:
		Game.stocks = maxi(Game.stocks - 1, 1)
		Game.play_sfx("menu_move")
		_refresh_stage()
	elif _pressed(event, "special") >= 0:
		Game.items_on = not Game.items_on
		Game.play_sfx("select")
		_refresh_stage()
	elif event.is_action_pressed("ui_start") or _pressed(event, "attack") >= 0:
		Game.play_sfx("start")
		Game.match_setup = {}
		Game.goto_stage()
	elif event.is_action_pressed("ui_back"):
		Game.play_sfx("menu_back")
		_ready_flags = [false, false]
		_show(Screen.CHARS)
