extends Control
## Menú: Título → Menú principal → Luchadores → Escenario → ¡A pelear!
## (también: Controles y Ajustes)
##
## Luchadores (cada jugador con sus teclas):
##   izquierda/derecha = elegir   ·   ATAQUE = listo   ·   ESPECIAL = Humano/CPU
##   arriba/abajo = dificultad del CPU   ·   ENTER = continuar   ·   ESC = volver
## Escenario:  izquierda/derecha/arriba/abajo = elegir  ·  ESPECIAL = objetos sí/no  ·  ESCUDO/ULTI = vidas

enum Screen { TITLE, MAIN, CHARS, STAGE, SETTINGS, CONTROLS }

const MAIN_OPTIONS := [
	["JUGAR · CLÁSICO", "Pelea normal a vidas. El último en pie gana."],
	["JUGAR · CAOS DE CARTAS", "Al empezar y con cada KO eliges una carta de mejora: doble daño, triple salto, ulti instantánea... ¡Todo vale!"],
	["CONTROLES", "Todas las teclas y cómo hacer cada movimiento."],
	["AJUSTES", "Volumen de la música y los efectos, pantalla completa."],
	["SALIR", "Cerrar el juego."],
]
const TILE := Vector2(118, 128)

var _screen := Screen.TITLE
var _layer: Control
var _t := 0.0
var _anim_atlases: Array[AtlasTexture] = []

var _main_sel := 0
var _main_labels: Array[Label] = []
var _main_desc: Label

var _cursor := [0, 1]
var _ready_flags := [false, false]
var _tiles: Array[Panel] = []
var _badges := []
var _cards := []

var _stage_sel := 0
var _stage_cards: Array[PanelContainer] = []
var _rules_label: Label

var _set_sel := 0
var _set_rows: Array[Label] = []


func _ready() -> void:
	add_child(UI.MenuBackground.new())
	_layer = Control.new()
	_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_layer)
	for i in 2:
		var c: String = Game.players[i]["char"]
		_cursor[i] = CharacterData.ORDER.size() if c == "random" else maxi(0, CharacterData.ORDER.find(c))
	_stage_sel = Game.STAGES.size() if Game.stage_id == "random" else 0
	for i in Game.STAGES.size():
		if Game.STAGES[i]["id"] == Game.stage_id:
			_stage_sel = i
	Game.play_music("menu")
	_show(Screen.TITLE)


func _clear() -> void:
	for c in _layer.get_children():
		c.queue_free()
	_anim_atlases.clear()
	_tiles.clear()
	_badges.clear()
	_cards.clear()
	_stage_cards.clear()
	_main_labels.clear()
	_set_rows.clear()


func _show(s: Screen) -> void:
	_screen = s
	_clear()
	match s:
		Screen.TITLE: _build_title()
		Screen.MAIN: _build_main()
		Screen.CHARS: _build_chars()
		Screen.STAGE: _build_stage()
		Screen.SETTINGS: _build_settings()
		Screen.CONTROLS: _build_controls()
	_layer.modulate.a = 0.0
	create_tween().tween_property(_layer, "modulate:a", 1.0, 0.2)


func _add(node: Control, pos: Vector2, size := Vector2.ZERO) -> Control:
	node.position = pos
	if size != Vector2.ZERO:
		node.size = size
	_layer.add_child(node)
	return node


func _header(text: String, step: String) -> void:
	_add(UI.label(text, 50, UI.TEXT, true, 10), Vector2(56, 20))
	if step != "":
		var chip := UI.panel(UI.ACCENT, 20)
		chip.add_child(UI.label(step, 18, Color(0.1, 0.08, 0.2), true))
		_add(chip, Vector2(1060, 32))


func _centered(text: String, size: int, color: Color, y: float, title := true, outline := 6) -> Label:
	var l := UI.label(text, size, color, title, outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_add(l, Vector2(0, y), Vector2(1280, size + 12))
	return l


# ------------------------------------------------------------------
#  TÍTULO
# ------------------------------------------------------------------
func _build_title() -> void:
	var logo := _centered("SUPER BRAWL", 140, UI.ACCENT, 60, true, 26)
	logo.name = "Logo"
	_centered("8 luchadores  ·  6 escenarios  ·  modo Caos de Cartas", 24, UI.TEXT, 232, false)
	for i in CharacterData.ORDER.size():
		var at := UI.frame_tex(CharacterData.ORDER[i])
		_anim_atlases.append(at)
		var pic := UI.pixel_rect(at, Vector2(200, 180))
		pic.flip_h = i >= 4
		_add(pic, Vector2(-20 + i * 155, 300 + (i % 2) * 40), Vector2(200, 180))
	var press := _centered("PRESIONA  ENTER", 36, Color.WHITE, 590)
	press.name = "Press"
	_centered("F11 pantalla completa  ·  ESC salir", 16, UI.MUTED, 680, false, 0)


# ------------------------------------------------------------------
#  MENÚ PRINCIPAL
# ------------------------------------------------------------------
func _build_main() -> void:
	_add(UI.label("SUPER BRAWL", 64, UI.ACCENT, true, 12), Vector2(80, 40))
	for i in MAIN_OPTIONS.size():
		var l := UI.label(MAIN_OPTIONS[i][0], 36, UI.TEXT, true, 6)
		_add(l, Vector2(100, 170 + i * 72))
		_main_labels.append(l)
	var panel := UI.panel(UI.CARD, 22)
	_add(panel, Vector2(720, 180), Vector2(480, 260))
	_main_desc = UI.label("", 22, UI.TEXT)
	_main_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_main_desc.custom_minimum_size = Vector2(440, 0)
	panel.add_child(_main_desc)
	for i in 4:
		var at := UI.frame_tex(CharacterData.ORDER[(i * 2 + 1) % 8])
		_anim_atlases.append(at)
		var pic := UI.pixel_rect(at, Vector2(160, 144))
		_add(pic, Vector2(700 + i * 130, 470), Vector2(160, 144))
	_centered("↑ ↓  elegir     ENTER / ATAQUE  aceptar     ESC  volver", 18, UI.MUTED, 670, false, 0)
	_refresh_main()


func _refresh_main() -> void:
	for i in _main_labels.size():
		var sel := i == _main_sel
		_main_labels[i].text = ("▶  " if sel else "    ") + MAIN_OPTIONS[i][0]
		_main_labels[i].add_theme_color_override("font_color", UI.ACCENT if sel else UI.TEXT)
		_main_labels[i].scale = Vector2(1.05, 1.05) if sel else Vector2.ONE
	_main_desc.text = MAIN_OPTIONS[_main_sel][1]


# ------------------------------------------------------------------
#  LUCHADORES
# ------------------------------------------------------------------
func _build_chars() -> void:
	_header("ELIGE TU LUCHADOR", "%s · 1/2" % Game.MODES[Game.mode])
	var n := CharacterData.ORDER.size() + 1
	var x0 := 640.0 - (n * TILE.x + (n - 1) * 10.0) / 2.0
	for i in n:
		var tile := Panel.new()
		var is_random := i == CharacterData.ORDER.size()
		var col: Color = UI.MUTED if is_random else CharacterData.get_data(CharacterData.ORDER[i])["color"]
		tile.add_theme_stylebox_override("panel", UI.style(UI.CARD, 16, col, 3))
		_add(tile, Vector2(x0 + i * (TILE.x + 10.0), 100), TILE)
		if is_random:
			var q := UI.label("?", 80, UI.ACCENT, true, 10)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.size = Vector2(TILE.x, 100)
			tile.add_child(q)
		else:
			var head := UI.pixel_rect(UI.head_tex(CharacterData.ORDER[i]), Vector2(92, 92))
			head.position = Vector2(13, 6)
			head.size = Vector2(92, 92)
			tile.add_child(head)
		var nm := UI.label("AZAR" if is_random else CharacterData.get_data(CharacterData.ORDER[i])["name"], 16, col, true)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.position = Vector2(0, 100)
		nm.size = Vector2(TILE.x, 24)
		tile.add_child(nm)
		_tiles.append(tile)
	for p in 2:
		var badge := UI.panel(UI.P_COLORS[p], 12)
		badge.add_child(UI.label("P%d" % (p + 1), 15, Color.WHITE, true, 4))
		_layer.add_child(badge)
		_badges.append(badge)
	for p in 2:
		_cards.append(_build_player_card(p, Vector2(40 + p * 610, 250)))
	_centered("P1:  A/D elegir · F listo · G Humano/CPU · W/S dificultad          P2:  ←/→ · , listo · . Humano/CPU · ↑/↓ dificultad",
		15, UI.MUTED, 638, false, 0)
	_centered("ENTER  continuar          ESC  volver", 22, UI.ACCENT, 668)
	_refresh_chars()


func _build_player_card(p: int, pos: Vector2) -> Dictionary:
	var panel := Panel.new()
	var sb := UI.style(UI.CARD, 22, UI.P_COLORS[p], 3)
	panel.add_theme_stylebox_override("panel", sb)
	_add(panel, pos, Vector2(590, 370))
	var glow := ColorRect.new()
	glow.position = Vector2(14, 14)
	glow.size = Vector2(210, 342)
	panel.add_child(glow)
	var at := UI.frame_tex("rojo")
	_anim_atlases.append(at)
	var pic := UI.pixel_rect(at, Vector2(300, 270))
	pic.position = Vector2(-40, 50)
	pic.size = Vector2(300, 270)
	panel.add_child(pic)
	var q := UI.label("?", 150, UI.ACCENT, true, 16)
	q.position = Vector2(70, 70)
	panel.add_child(q)
	var who := UI.label("", 18, UI.P_COLORS[p], true)
	who.position = Vector2(240, 16)
	panel.add_child(who)
	var nm := UI.label("", 42, Color.WHITE, true, 8)
	nm.position = Vector2(238, 36)
	panel.add_child(nm)
	var desc := UI.label("", 14, UI.MUTED)
	desc.position = Vector2(240, 96)
	desc.size = Vector2(336, 40)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(desc)
	var abil := VBoxContainer.new()
	abil.position = Vector2(240, 142)
	abil.add_theme_constant_override("separation", 0)
	panel.add_child(abil)
	var mode := UI.panel(UI.CARD_HI, 14)
	mode.position = Vector2(240, 306)
	var mode_l := UI.label("", 18, Color.WHITE, true)
	mode.add_child(mode_l)
	panel.add_child(mode)
	var ready_stamp := UI.label("¡LISTO!", 52, UI.GOOD, true, 12)
	ready_stamp.position = Vector2(20, 290)
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
		var badge: PanelContainer = _badges[p]
		badge.position = _tiles[c].position + Vector2(6 + p * 66, -14)
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
			card["atlas"].atlas = load("res://assets/sprites/idle_%s.png" % id)
			card["name"].text = d["name"]
			card["name"].add_theme_color_override("font_color", col)
			card["desc"].text = d["desc"]
			var keys := ["G", "Arriba + G", "Abajo + G", "Mantener G", "Ulti"]
			for i in 5:
				var row := HBoxContainer.new()
				row.add_child(UI.label("★ ", 14, col))
				row.add_child(UI.label(keys[i] + ": ", 14, UI.MUTED))
				row.add_child(UI.label(d["abilities"][i], 14, UI.TEXT))
				card["abil"].add_child(row)
		card["mode"].text = "CPU  ◄ %s ►" % Game.LEVEL_NAMES[cfg.get("level", 1)] if cfg["cpu"] else "HUMANO"
		card["ready"].visible = _ready_flags[p]
		card["style"].border_color = UI.GOOD if _ready_flags[p] else UI.P_COLORS[p]


# ------------------------------------------------------------------
#  ESCENARIO
# ------------------------------------------------------------------
func _build_stage() -> void:
	_header("ELIGE EL ESCENARIO", "%s · 2/2" % Game.MODES[Game.mode])
	var n := Game.STAGES.size() + 1
	for i in n:
		var is_random := i == Game.STAGES.size()
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.style(UI.CARD, 18))
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 2)
		card.add_child(vb)
		var thumb: Control
		if is_random:
			var q := UI.label("?", 80, UI.ACCENT, true, 12)
			q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			q.custom_minimum_size = Vector2(256, 130)
			thumb = q
		else:
			var sid: String = Game.STAGES[i]["id"]
			var path := "res://assets/ui/stage_%s.png" % sid
			var tr := TextureRect.new()
			tr.texture = load(path) if ResourceLoader.exists(path) else load("res://assets/stages/%s/sky.png" % sid)
			tr.custom_minimum_size = Vector2(256, 130)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			thumb = tr
		vb.add_child(thumb)
		vb.add_child(UI.label("Aleatorio" if is_random else Game.STAGES[i]["name"], 22, UI.TEXT, true))
		var desc := UI.label("¡Que decida la suerte!" if is_random else Game.STAGES[i]["desc"], 13, UI.MUTED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(256, 34)
		vb.add_child(desc)
		card.pivot_offset = Vector2(140, 105)
		var row := i / 4
		var col := i % 4
		var x := 40.0 + col * 304.0 + (152.0 if row == 1 else 0.0)
		_add(card, Vector2(x, 100 + row * 240))
		_stage_cards.append(card)
	var rules := UI.panel(UI.CARD, 18)
	_add(rules, Vector2(290, 588), Vector2(700, 0))
	_rules_label = UI.label("", 22, UI.TEXT, true)
	_rules_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rules.add_child(_rules_label)
	_centered("flechas / WASD elegir  ·  Q o - vidas  ·  G o . objetos sí/no  ·  ENTER ¡a pelear!  ·  ESC volver",
		15, UI.MUTED, 668, false, 0)
	_refresh_stage()


func _refresh_stage() -> void:
	for i in _stage_cards.size():
		var sel := i == _stage_sel
		_stage_cards[i].add_theme_stylebox_override("panel",
			UI.style(UI.CARD_HI if sel else UI.CARD, 18, UI.ACCENT if sel else Color(0, 0, 0, 0), 4 if sel else 0))
		_stage_cards[i].scale = Vector2(1.05, 1.05) if sel else Vector2.ONE
		_stage_cards[i].modulate = Color.WHITE if sel else Color(0.72, 0.72, 0.82)
		_stage_cards[i].z_index = 1 if sel else 0
	Game.stage_id = "random" if _stage_sel == Game.STAGES.size() else Game.STAGES[_stage_sel]["id"]
	_rules_label.text = "Vidas  ◄ %d ►      Objetos  %s      Modo  %s" % [Game.stocks,
		"SÍ" if Game.items_on else "NO", Game.MODES[Game.mode]]


# ------------------------------------------------------------------
#  AJUSTES
# ------------------------------------------------------------------
func _build_settings() -> void:
	_header("AJUSTES", "")
	for i in 4:
		var l := UI.label("", 34, UI.TEXT, true, 6)
		_add(l, Vector2(160, 180 + i * 90))
		_set_rows.append(l)
	_centered("↑ ↓  elegir     ← →  cambiar     ESC  volver", 18, UI.MUTED, 640, false, 0)
	_centered("Nota: si juegas DENTRO del editor de Godot (pestaña Game), la pantalla completa solo funciona al ejecutar en ventana propia o con el juego exportado.",
		14, UI.MUTED, 590, false, 0)
	_refresh_settings()


func _bar(v: float) -> String:
	var n := int(round(v * 20.0))
	return "█".repeat(n) + "░".repeat(20 - n) + "  %d%%" % int(round(v * 100.0))


func _refresh_settings() -> void:
	var texts := ["Música      " + _bar(Game.music_volume), "Efectos     " + _bar(Game.sfx_volume),
		"Pantalla completa      %s" % ("SÍ" if Game.fullscreen else "NO"), "Volver"]
	for i in _set_rows.size():
		_set_rows[i].text = ("▶  " if i == _set_sel else "    ") + texts[i]
		_set_rows[i].add_theme_color_override("font_color", UI.ACCENT if i == _set_sel else UI.TEXT)


func _change_setting(dir: int) -> void:
	match _set_sel:
		0:
			Game.music_volume = clampf(Game.music_volume + dir * 0.05, 0.0, 1.0)
		1:
			Game.sfx_volume = clampf(Game.sfx_volume + dir * 0.05, 0.0, 1.0)
			Game.play_sfx("hit")
		2:
			Game.set_fullscreen(not Game.fullscreen)
	Game.apply_settings()
	Game.save_settings()
	_refresh_settings()


# ------------------------------------------------------------------
#  CONTROLES
# ------------------------------------------------------------------
func _build_controls() -> void:
	_header("CONTROLES", "")
	var rows := [
		["", "JUGADOR 1", "JUGADOR 2", "CONTROL"],
		["Moverse (doble toque = correr)", "A  D", "←  →", "Stick"],
		["Saltar / doble salto", "Espacio", "Enter", "A"],
		["Agacharse · caer rápido", "S", "↓", "Abajo"],
		["Ataque  (tocar varias veces = combo)", "F", ",", "X"],
		["Ataque + dirección (arriba/abajo/lado)", "W/S/A/D + F", "flechas + ,", "Stick + X"],
		["Smash cargado (mantener)", "Mantener F", "Mantener ,", "Mantener X"],
		["Especial · + arriba · + abajo · mantener", "G", ".", "B"],
		["Escudo · + lado = rodar · + abajo = esquivar", "Q", "-", "LB / gatillos"],
		["Esquiva en el aire", "Q en el aire", "- en el aire", "LB en el aire"],
		["Lanzar objeto", "C", "J", "RB"],
		["Ulti (barra llena)", "E", "L", "Y"],
		["Provocar", "R", "K", "Select"],
	]
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 8)
	var panel := UI.panel(UI.CARD, 20)
	panel.add_child(grid)
	_add(panel, Vector2(60, 96))
	for r in rows.size():
		for c in 4:
			var head: bool = r == 0 or c == 0
			grid.add_child(UI.label(rows[r][c], 17 if c == 0 else 18, UI.ACCENT if r == 0 else (UI.MUTED if c == 0 else UI.TEXT),
				r == 0 or c > 0))
	var tips := UI.label("PARRY: toca la dirección HACIA el atacante justo cuando te golpea.   BUFFER: presiona antes y la acción sale en cuanto puedas.",
		16, UI.TEXT)
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add(tips, Vector2(60, 610), Vector2(1160, 50))
	_centered("ESC  volver", 18, UI.ACCENT, 668)


# ------------------------------------------------------------------
#  Animación y controles del menú
# ------------------------------------------------------------------
func _process(delta: float) -> void:
	_t += delta
	var frame := int(_t * 8.0) % 6
	for at in _anim_atlases:
		at.region.position = Vector2(frame * Fighter.FRAME_W, 0)
	if _screen == Screen.TITLE and _layer.has_node("Press"):
		_layer.get_node("Press").modulate.a = 0.55 + 0.45 * sin(_t * 4.0)
		_layer.get_node("Logo").position.y = 60 + sin(_t * 1.6) * 6.0


func _pressed(event: InputEvent, what: String) -> int:
	for p in 2:
		if event.is_action_pressed("p%d_%s" % [p + 1, what]):
			return p
	return -1


func _any(event: InputEvent, what: String) -> bool:
	return _pressed(event, what) >= 0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	match _screen:
		Screen.TITLE:
			if event.is_action_pressed("ui_start") or _any(event, "attack") or _any(event, "jump"):
				Game.play_sfx("menu_confirm")
				_show(Screen.MAIN)
			elif event.is_action_pressed("ui_back"):
				get_tree().quit()
		Screen.MAIN:
			_input_main(event)
		Screen.CHARS:
			_input_chars(event)
		Screen.STAGE:
			_input_stage(event)
		Screen.SETTINGS:
			_input_settings(event)
		Screen.CONTROLS:
			if event.is_action_pressed("ui_back") or event.is_action_pressed("ui_start"):
				Game.play_sfx("menu_back")
				_show(Screen.MAIN)


func _input_main(event: InputEvent) -> void:
	if _any(event, "up"):
		_main_sel = (_main_sel + MAIN_OPTIONS.size() - 1) % MAIN_OPTIONS.size()
		Game.play_sfx("menu_move")
		_refresh_main()
	elif _any(event, "down"):
		_main_sel = (_main_sel + 1) % MAIN_OPTIONS.size()
		Game.play_sfx("menu_move")
		_refresh_main()
	elif event.is_action_pressed("ui_start") or _any(event, "attack") or _any(event, "jump"):
		Game.play_sfx("menu_confirm")
		match _main_sel:
			0:
				Game.mode = "classic"
				_ready_flags = [false, false]
				_show(Screen.CHARS)
			1:
				Game.mode = "cards"
				_ready_flags = [false, false]
				_show(Screen.CHARS)
			2: _show(Screen.CONTROLS)
			3: _show(Screen.SETTINGS)
			4: get_tree().quit()
	elif event.is_action_pressed("ui_back"):
		Game.play_sfx("menu_back")
		_show(Screen.TITLE)


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
			Game.players[p]["level"] = clampi(lv + (1 if dir == "up" else -1), 0, 2)
			Game.play_sfx("menu_move")
			_refresh_chars()
			return
	if event.is_action_pressed("ui_start"):
		Game.play_sfx("menu_confirm")
		_show(Screen.STAGE)
	elif event.is_action_pressed("ui_back"):
		Game.play_sfx("menu_back")
		_ready_flags = [false, false]
		_show(Screen.MAIN)


func _input_stage(event: InputEvent) -> void:
	var n := Game.STAGES.size() + 1
	if _any(event, "left"):
		_stage_sel = (_stage_sel + n - 1) % n
		Game.play_sfx("menu_move")
	elif _any(event, "right"):
		_stage_sel = (_stage_sel + 1) % n
		Game.play_sfx("menu_move")
	elif _any(event, "up") or _any(event, "down"):
		_stage_sel = clampi(_stage_sel + (4 if _stage_sel < 4 else -4), 0, n - 1)
		Game.play_sfx("menu_move")
	elif _any(event, "shield") or _any(event, "ult"):
		Game.stocks = Game.stocks % 9 + 1
		Game.play_sfx("menu_move")
	elif _any(event, "special"):
		Game.items_on = not Game.items_on
		Game.play_sfx("select")
	elif event.is_action_pressed("ui_start") or _any(event, "attack"):
		Game.play_sfx("start")
		Game.match_setup = {}
		Game.goto_stage()
		return
	elif event.is_action_pressed("ui_back"):
		Game.play_sfx("menu_back")
		_ready_flags = [false, false]
		_show(Screen.CHARS)
		return
	_refresh_stage()


func _input_settings(event: InputEvent) -> void:
	if _any(event, "up"):
		_set_sel = (_set_sel + 3) % 4
		Game.play_sfx("menu_move")
		_refresh_settings()
	elif _any(event, "down"):
		_set_sel = (_set_sel + 1) % 4
		Game.play_sfx("menu_move")
		_refresh_settings()
	elif _any(event, "left"):
		_change_setting(-1)
	elif _any(event, "right"):
		_change_setting(1)
	elif event.is_action_pressed("ui_start") or _any(event, "attack"):
		if _set_sel == 3:
			Game.play_sfx("menu_back")
			_show(Screen.MAIN)
		else:
			_change_setting(1)
	elif event.is_action_pressed("ui_back"):
		Game.play_sfx("menu_back")
		_show(Screen.MAIN)
