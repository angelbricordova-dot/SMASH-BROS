extends CanvasLayer
## Pantalla de pausa (Esc).


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var label := Label.new()
	label.text = "PAUSA\n\nEsc  ·  Continuar\nM  ·  Volver al menú"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 36)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	if get_parent().get("over"):
		return
	if event.is_action_pressed("pause"):
		visible = not visible
		get_tree().paused = visible
		get_viewport().set_input_as_handled()
	elif visible and event is InputEventKey and event.pressed and event.keycode == KEY_M:
		Game.goto_menu()
