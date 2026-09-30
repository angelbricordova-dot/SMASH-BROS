extends CanvasLayer
## Muestra el % de daño y las vidas de cada jugador.

var _panels := []  # uno por luchador: {fighter, percent_label, stocks_box, name_label}


func setup(fighters: Array) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var n := fighters.size()
	for i in n:
		var f: Fighter = fighters[i]
		var col: Color = f.data["color"]
		var panel := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0.45)
		sb.border_color = col
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(10)
		sb.set_content_margin_all(10)
		panel.add_theme_stylebox_override("panel", sb)
		panel.position = Vector2(1280.0 * (i + 1) / (n + 1) - 110.0, 552)
		panel.custom_minimum_size = Vector2(220, 100)
		root.add_child(panel)

		var vb := VBoxContainer.new()
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(vb)

		var name_label := Label.new()
		name_label.text = ("CPU  " if f.is_cpu else "P%d  " % f.player_id) + f.data["name"]
		name_label.add_theme_color_override("font_color", col)
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(name_label)

		var pl := Label.new()
		pl.add_theme_font_size_override("font_size", 52)
		pl.add_theme_constant_override("outline_size", 10)
		pl.add_theme_color_override("font_outline_color", Color.BLACK)
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(pl)

		var stocks := HBoxContainer.new()
		stocks.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.add_child(stocks)

		_panels.append({"fighter": f, "percent": pl, "stocks": stocks, "shown_stocks": -1})


func _process(_delta: float) -> void:
	for p in _panels:
		var f: Fighter = p["fighter"]
		var pct: float = f.percent
		var lbl: Label = p["percent"]
		lbl.text = "%d%%" % int(pct)
		# de blanco a rojo oscuro según el daño
		var k := clampf(pct / 150.0, 0.0, 1.0)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1).lerp(Color(0.85, 0.05, 0.05), k))
		if p["shown_stocks"] != f.stocks:
			p["shown_stocks"] = f.stocks
			var box: HBoxContainer = p["stocks"]
			for c in box.get_children():
				c.queue_free()
			var tex: Texture2D = load(f.data["sheet"])
			for i in f.stocks:
				var icon := TextureRect.new()
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(20, 12, 36, 32)
				icon.texture = at
				icon.custom_minimum_size = Vector2(36, 32)
				icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				box.add_child(icon)
