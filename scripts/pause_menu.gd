extends CanvasLayer
## Menú de pausa (Esc / Start).

const OPTIONS := ["Continuar", "Revancha", "Salir al menú"]
var _sel := 0
var _labels: Array[Label] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.02, 0.08, 0.7)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := UI.panel(UI.CARD, 22, UI.ACCENT, 3)
	panel.position = Vector2(440, 170)
	panel.custom_minimum_size = Vector2(400, 360)
	add_child(panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	panel.add_child(vb)
	var title := UI.label("PAUSA", 64, UI.ACCENT, true, 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	for o in OPTIONS:
		var l := UI.label(o, 30, UI.TEXT, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(l)
		_labels.append(l)
	var hint := UI.label("↑ ↓ elegir   ·   Enter aceptar", 16, UI.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)
	_refresh()


func _refresh() -> void:
	for i in _labels.size():
		_labels[i].text = ("▶  " + OPTIONS[i] + "  ◀") if i == _sel else OPTIONS[i]
		_labels[i].add_theme_color_override("font_color", UI.ACCENT if i == _sel else UI.TEXT)


func _set_paused(p: bool) -> void:
	visible = p
	get_tree().paused = p
	_sel = 0
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if get_parent().get("over"):
		return
	if event.is_action_pressed("pause"):
		_set_paused(not visible)
		Game.play_sfx("menu_confirm" if visible else "menu_back")
		get_viewport().set_input_as_handled()
		return
	if not visible:
		return
	if event.is_action_pressed("p1_up") or event.is_action_pressed("p2_up"):
		_sel = (_sel + OPTIONS.size() - 1) % OPTIONS.size()
		Game.play_sfx("menu_move")
		_refresh()
	elif event.is_action_pressed("p1_down") or event.is_action_pressed("p2_down"):
		_sel = (_sel + 1) % OPTIONS.size()
		Game.play_sfx("menu_move")
		_refresh()
	elif event.is_action_pressed("ui_start") or event.is_action_pressed("p1_jump") or event.is_action_pressed("p1_attack"):
		get_viewport().set_input_as_handled()
		Game.play_sfx("menu_confirm")
		match _sel:
			0: _set_paused(false)
			1: Game.rematch()
			2: Game.goto_menu()
