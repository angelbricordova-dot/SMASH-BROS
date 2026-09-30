extends Fighter
## ABNIELITO — de Tenerife, pelea con su micrófono.
##  Especial (tocar G) ....... Onda de micro: grita al micro y lanza una onda de sonido
##  Especial (mantener G) .... Freestyle: carga y suelta una onda enorme que atraviesa y aturde
##  Arriba + Especial ........ ¡Guagua!: aparece una guagua que atropella y lo lanza hacia arriba
##  Abajo + Especial ......... Mic drop: en el suelo deja caer el micro y sale una onda expansiva;
##                             en el aire cae en picada y la onda sale al aterrizar
##  Ulti ..................... Mentiras: suelta mentiras por el micro y los rivales se confunden 7 s:
##                             ¡izquierda y derecha (y arriba y abajo) quedan al revés!

const CONFUSE_TIME := 7.0
const LIES := ["¡Yo nací en Madrid!", "¡Te llama tu madre!", "¡Mira, un ovni!", "¡La guagua llega puntual!",
	"¡Tu mando está al revés!", "¡Estás ganando tú!", "¡En Tenerife nieva en agosto!", "¡Yo no fui!",
	"¡Tu cordón está suelto!", "¡Esto es un tutorial!"]
const BUS_TEX := preload("res://assets/sprites/prop_bus.png")


func do_special() -> void:
	begin_action("wave")


func do_charge_special() -> void:
	begin_action("freestyle")


func do_up_special() -> void:
	begin_action("guagua")


func do_down_special() -> void:
	begin_action("micdrop" if is_on_floor() else "micdrop_air")


func do_ultimate() -> void:
	begin_action("ult_lies")


func _wave(scale: float, info: Dictionary, pierce := false, stun := 0.0) -> void:
	var h := body_point("hands")
	var p := global_position + Vector2(h.x + facing * 14.0, h.y - 6.0)
	var proj := spawn_projectile({"velocity": Vector2(facing * (700.0 + 150.0 * scale), 0), "radius": 16.0 * scale,
		"lifetime": 0.55 + 0.2 * scale, "global_position": p, "sprite_scale": 1.3 * scale, "pierce": pierce,
		"trail": Color(1.0, 0.85, 0.3, 0.35), "info": info})
	if stun > 0.0:
		proj.on_hit = func(f: Fighter) -> void: f.freeze(stun)
	Effects.ring(get_parent(), p, Color(1.0, 0.9, 0.4), 30.0 * scale)


func char_action(action_name: String, t: float, delta: float) -> void:
	match action_name:
		"wave":
			anim_frame("special", 0 if t < 0.06 else (1 if t < 0.14 else (2 if t < 0.24 else 3)))
			if not act.has("fired") and t >= 0.1:
				act["fired"] = true
				_wave(1.0, {"dmg": 6.0, "base_kb": 230.0, "kb_scale": 5.0, "angle": 35.0})
				Game.play_sfx("mic", -4.0, randf_range(1.0, 1.15))
			_action_physics(delta)
			if t >= 0.34:
				end_action()
		"freestyle":
			_action_physics(delta)
			if not act.has("released") and Engine.get_physics_frames() % 12 == 0:
				Effects.popup(get_parent(), global_position + Vector2(randf_range(-30, 30), -120),
					["♪", "♫", "¡ey!", "¡yo!"].pick_random(), Color(1, 0.86, 0.3), 0.6)
			if hold_charge(t, 1.2):
				return
			var c: float = act["charge"]
			var rt: float = t - float(act["released"])
			anim_frame("charge", 2 if rt < 0.14 else 3)
			if not act.has("fired"):
				act["fired"] = true
				_wave(1.3 + 1.3 * c, {"dmg": 8.0 + 12.0 * c, "base_kb": 250.0 + 250.0 * c, "kb_scale": 5.0 + 4.0 * c,
					"angle": 38.0}, true, 0.5 * c)
				Game.play_sfx("mic", 0.0, 0.85)
				get_parent().add_shake(4.0 + 10.0 * c)
			if rt >= 0.4:
				end_action()
		"guagua":
			if t < 0.02:
				velocity = Vector2(facing * 180.0, -1000.0 * mods["jump"])
				Game.play_sfx("bus_horn")
				# la guagua pasa por debajo, atropellando a quien esté ahí
				var bus := spawn_projectile({"texture": BUS_TEX, "hframes": 1, "radius": 44.0, "lifetime": 0.9,
					"velocity": Vector2(facing * 950.0, 0), "sprite_scale": 1.0, "pierce": true,
					"trail": Color(1, 1, 1, 0.25),
					"global_position": global_position + Vector2(-facing * 140.0, -34.0),
					"info": {"dmg": 11.0, "base_kb": 330.0, "kb_scale": 7.0, "angle": 42.0, "sfx": "hit_strong"}})
				bus.z_index = 0
				Effects.dust(get_parent(), global_position)
			anim_frame("upspecial", mini(int(t / 0.12), 2))
			air_drift(delta, 0.6)
			apply_gravity(delta, 0.6)
			if t >= 0.5:
				end_action(true)
		"micdrop":
			anim_frame("downspecial", 0 if t < 0.16 else (1 if t < 0.34 else 3))
			_action_physics(delta)
			if t >= 0.18 and not act.has("boom"):
				act["boom"] = true
				_boom(1.0)
			if t >= 0.5:
				end_action()
		"micdrop_air":
			anim_frame("dair", 0 if t < 0.1 else 1)
			if t < 0.1:
				velocity *= 0.8
			else:
				velocity = Vector2(facing * 60.0, 1250.0)
				hit_rect(box(Vector2(8, -10), Vector2(56, 56)), {"dmg": 9.0, "base_kb": 240.0, "kb_scale": 6.0,
					"angle": -80.0, "special": true})
			if is_on_floor() and t > 0.1:
				hit_list.clear()
				_boom(1.3)
				end_action()
				landing_lag = 0.16
				return
			if t >= 1.1:
				end_action()
		"ult_lies":
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			velocity.y = 0.0 if is_on_floor() else minf(velocity.y + 300.0 * delta, 120.0)
			anim_frame("ult", mini(int(t / 0.22), 3))
			var n: int = act.get("n", 0)
			if n < 4 and t >= n * 0.18:
				act["n"] = n + 1
				var b := LieBubble.new()
				b.text = LIES.pick_random()
				b.position = global_position + Vector2(facing * 70.0 + randf_range(-40, 40), -150.0 - n * 34.0)
				get_parent().add_child(b)
				Game.play_sfx("lie", -4.0, randf_range(0.9, 1.2))
			if t >= 0.75 and not act.has("done"):
				act["done"] = true
				for f in enemies():
					f.confused_time = CONFUSE_TIME
					f.take_damage(5.0, self)
					Effects.popup(get_parent(), f.global_position + Vector2(0, -140), "¡CONFUNDIDO!",
						Color(1.0, 0.86, 0.3), 1.1)
					Effects.burst(get_parent(), f.global_position + Vector2(0, -60), {"count": 20,
						"color": Color(0.8, 0.5, 1.0), "speed": 200.0, "life": 0.7, "size": 4.0, "star": true})
				Game.play_sfx("magic", -2.0, 0.8)
			if t >= 1.1:
				end_action()
		_:
			super.char_action(action_name, t, delta)


## Onda expansiva del micro al caer.
func _boom(power: float) -> void:
	var p := global_position + Vector2(0, -20)
	hit_circle(p, 90.0 * power, {"dmg": 8.0 * power, "base_kb": 280.0, "kb_scale": 6.0 * power, "angle": 70.0,
		"special": true})
	Effects.shockwave(get_parent(), global_position, Color(1.0, 0.86, 0.3), 320.0 * power)
	Effects.ring(get_parent(), p, Color(1.0, 0.9, 0.4), 110.0 * power)
	Effects.ring(get_parent(), p, Color(1, 1, 1), 70.0 * power)
	Game.play_sfx("mic", -2.0, 0.7)
	Game.play_sfx("quake", -8.0, 1.4)
	get_parent().add_shake(10.0 * power)


## Bocadillo con una mentira.
class LieBubble extends Node2D:
	var text := ""
	var _t := 0.0

	func _ready() -> void:
		z_index = 25

	func _process(delta: float) -> void:
		_t += delta
		position.y -= 14.0 * delta
		queue_redraw()
		if _t > 1.6:
			queue_free()

	func _draw() -> void:
		var font: Font = Game.font_title if Game.font_title else ThemeDB.fallback_font
		var fs := 18
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 24.0
		var s := minf(1.0, _t * 8.0)
		var a := minf(1.0, (1.6 - _t) * 3.0)
		draw_set_transform(Vector2.ZERO, sin(_t * 3.0) * 0.05, Vector2(s, s))
		var r := Rect2(-w / 2.0, -20, w, 34)
		draw_rect(r.grow(3), Color(0.1, 0.05, 0.15, a))
		draw_rect(r, Color(1, 1, 1, a))
		draw_colored_polygon(PackedVector2Array([Vector2(-8, 14), Vector2(8, 14), Vector2(-4, 28)]), Color(1, 1, 1, a))
		draw_string(font, Vector2(-w / 2.0 + 12, 4), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.35, 0.1, 0.5, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
