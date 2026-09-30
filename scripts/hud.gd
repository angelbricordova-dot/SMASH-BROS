extends CanvasLayer
## HUD de la pelea: una tarjeta por luchador con retrato, % de daño, vidas y barra de ulti.

const ULT_KEYS := {1: "E", 2: "L"}
const CARD_H := 22
var _cards := []


func setup(fighters: Array) -> void:
	var n := fighters.size()
	for i in n:
		var card := HudCard.new()
		card.fighter = fighters[i]
		card.ult_key = "" if fighters[i].is_cpu else ULT_KEYS.get(fighters[i].player_id, "")
		card.position = Vector2(1280.0 * (i + 1) / (n + 1) - 150.0, 596)
		card.size = Vector2(300, 104)
		add_child(card)
		_cards.append(card)


class HudCard extends Control:
	var fighter: Fighter
	var ult_key := ""
	var _last_pct := 0.0
	var _pop := 0.0
	var _head: Texture2D
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_head = UI.head_tex(fighter.char_id)

	func _process(delta: float) -> void:
		_t += delta
		if fighter.percent != _last_pct:
			if fighter.percent > _last_pct:
				_pop = 0.25
			_last_pct = fighter.percent
		_pop = maxf(0.0, _pop - delta)
		queue_redraw()

	func _draw() -> void:
		var col: Color = fighter.data["color"]
		var w := size.x
		var h := size.y
		var alive := fighter.stocks > 0
		var sb := UI.style(Color(0.06, 0.07, 0.15, 0.82), 18, Color(col.r, col.g, col.b, 0.9), 0)
		draw_style_box(sb, Rect2(0, 0, w, h))
		draw_rect(Rect2(0, 12, 6, h - 24), col)
		# retrato
		var pc := Vector2(52, h / 2.0)
		draw_circle(pc, 38, Color(col.r, col.g, col.b, 0.35))
		draw_circle(pc, 34, Color(0.08, 0.09, 0.18))
		draw_arc(pc, 36, 0, TAU, 40, col, 3.0)
		draw_texture_rect(_head, Rect2(pc - Vector2(32, 34), Vector2(64, 64)), false,
			Color.WHITE if alive else Color(0.4, 0.4, 0.4))
		var font_t: Font = Game.font_title
		var font_b: Font = Game.font_body
		# nombre
		var who := "CPU" if fighter.is_cpu else "P%d" % fighter.player_id
		draw_string(font_b, Vector2(98, 24), "%s · %s" % [who, fighter.data["name"]],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(col.r, col.g, col.b))
		# porcentaje (rebota al recibir daño)
		var pct := fighter.percent
		var k := clampf(pct / 150.0, 0.0, 1.0)
		var pcol := Color(1, 1, 1).lerp(Color(1, 0.55, 0.2), clampf(k * 1.6, 0, 1)).lerp(Color(0.85, 0.05, 0.1), clampf(k * 1.6 - 0.6, 0, 1))
		var fs := int(46 * (1.0 + _pop * 1.4))
		var shake := Vector2(randf_range(-3, 3), randf_range(-3, 3)) * (_pop / 0.25)
		var txt := "%d%%" % int(pct) if alive else "—"
		draw_string_outline(font_t, Vector2(98, 72) + shake, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0, 0, 0, 0.9))
		draw_string(font_t, Vector2(98, 72) + shake, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, pcol)
		# vidas
		if Game.mode == "training":
			draw_string(font_t, Vector2(w - 44, 34), "∞", HORIZONTAL_ALIGNMENT_RIGHT, 30, 26, col)
		for i in (0 if Game.mode == "training" else fighter.stocks):
			var sp := Vector2(w - 22 - i * 20, 22)
			draw_circle(sp, 7, Color(0, 0, 0, 0.5))
			draw_circle(sp, 6, col)
			draw_circle(sp + Vector2(-2, -2), 2, Color(1, 1, 1, 0.6))
		# objeto
		if fighter.held_item != "":
			draw_string(font_b, Vector2(w - 92, 60), "BATE" if fighter.held_item == "bat" else "ARCO x%d" % fighter.item_ammo,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.ACCENT)
		# barra de ulti
		var bar := Rect2(98, 82, w - 116, 10)
		draw_style_box(UI.style(Color(0, 0, 0, 0.55), 5, Color(0, 0, 0, 0), 0, false), bar)
		var fill := clampf(fighter.ult_meter / Fighter.ULT_MAX, 0.0, 1.0)
		if fill > 0.0:
			var full := fill >= 1.0
			var fc := col.lerp(Color.WHITE, 0.35 + 0.35 * sin(_t * 8.0)) if full else col
			draw_style_box(UI.style(fc, 5, Color(0, 0, 0, 0), 0, false), Rect2(bar.position, Vector2(bar.size.x * fill, bar.size.y)))
			if full:
				var tag := "¡ULTI!  [%s]" % ult_key if ult_key != "" else "¡ULTI!"
				draw_string_outline(font_t, Vector2(bar.position.x + bar.size.x - 96, 80), tag, HORIZONTAL_ALIGNMENT_RIGHT, 96, 16, 6, Color.BLACK)
				draw_string(font_t, Vector2(bar.position.x + bar.size.x - 96, 80), tag, HORIZONTAL_ALIGNMENT_RIGHT, 96, 16, UI.ACCENT)
		# cartas del modo Caos (encima de la tarjeta)
		var cx := 6.0
		for id in fighter.cards:
			var c := Cards.get_card(id)
			var cc: Color = Cards.RARITY_COLORS[c["rarity"]]
			var r := Rect2(cx, -28, 40, 24)
			draw_style_box(UI.style(Color(0.06, 0.07, 0.15, 0.9), 6, cc, 2, false), r)
			draw_string(font_t, Vector2(r.position.x, r.position.y + 18), c["icon"], HORIZONTAL_ALIGNMENT_CENTER, 40, 14, Color.WHITE)
			cx += 44.0
