extends Fighter
## ILUNNA — rápido y ligero, pelea a patadas.
##  Especial (tocar G) ....... Patada de viento: una media luna de aire sale volando recto
##  Especial (mantener G) .... Puño de impacto: carga y se lanza hacia delante con un puñetazo explosivo
##  Arriba + Especial ........ Patada tornado: sube girando y golpea varias veces
##  Abajo + Especial ......... Hachazo: en el suelo, patada hacia abajo que levanta al rival;
##                             en el aire, cae en picada y lo manda hacia abajo (meteoro)
##  Ulti ..................... Sin Chaqueta: lanza la chaqueta y durante 10 s es más rápido, pega más
##                             fuerte, salta más (un salto extra) y deja estelas

const BUFF_TIME := 10.0
const BUFF := {"speed": 1.35, "dmg": 1.3, "jump": 1.1, "kb": 1.15}
var buff_t := 0.0


func do_special() -> void:
	begin_action("wind")


func do_charge_special() -> void:
	begin_action("impact")


func do_up_special() -> void:
	begin_action("tornado")


func do_down_special() -> void:
	begin_action("axe" if is_on_floor() else "axe_air")


func do_ultimate() -> void:
	begin_action("ult_jacket")


func char_tick(delta: float) -> void:
	if buff_t <= 0.0:
		return
	buff_t -= delta
	if Engine.get_physics_frames() % 4 == 0 and (absf(velocity.x) > 150.0 or state == State.ATTACK):
		Effects.afterimage(get_parent(), self, Color(0.5, 0.9, 1.0, 0.5))
	if Engine.get_physics_frames() % 9 == 0:
		Effects.burst(get_parent(), global_position + Vector2(0, -46), {"count": 2, "color": Color(0.6, 0.95, 1.0),
			"speed": 60.0, "life": 0.5, "size": 3.0, "radius": 30.0, "gravity": -120.0, "star": true})
	if buff_t <= 0.0:
		_end_buff()


func _end_buff() -> void:
	if form == "":
		return
	buff_t = 0.0
	for k in BUFF:
		mods[k] /= BUFF[k]
	mods["extra_jumps"] -= 1
	set_form("")
	if is_alive():
		Effects.popup(get_parent(), global_position + Vector2(0, -120), "Se acabó", Color(0.7, 0.9, 1.0), 0.8)


func kill() -> void:
	_end_buff()
	super.kill()


func char_action(action_name: String, t: float, delta: float) -> void:
	match action_name:
		"wind":
			anim_frame("special", 0 if t < 0.07 else (1 if t < 0.16 else (2 if t < 0.24 else 3)))
			if not act.has("fired") and t >= 0.1:
				act["fired"] = true
				spawn_projectile({"velocity": Vector2(facing * 820.0, 0), "radius": 18.0, "lifetime": 0.7,
					"global_position": global_position + Vector2(facing * 50, -52), "sprite_scale": 1.6,
					"trail": Color(0.5, 0.9, 1.0, 0.5),
					"info": {"dmg": 7.0, "base_kb": 220.0, "kb_scale": 5.5, "angle": 30.0}})
				Game.play_sfx("swing_heavy", -2.0, 1.3)
				Effects.swoosh(self, -40.0, 30.0, 58.0, Color(0.6, 0.95, 1.0), 0.2, 10.0)
			_action_physics(delta)
			if t >= 0.34:
				end_action()
		"impact":
			if not act.has("released"):
				velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
				if not is_on_floor():
					apply_gravity(delta, 0.4)
			if hold_charge(t, 1.0):
				return
			var c: float = act["charge"]
			var rt: float = t - float(act["released"])
			anim_frame("charge", 2 if rt < 0.25 else 3)
			if rt < 0.02:
				velocity.x = facing * (520.0 + 520.0 * c)
				Game.play_sfx("dash", -2.0)
			if rt < 0.26:
				velocity.y = 0.0 if is_on_floor() else minf(velocity.y, 60.0)
				if Engine.get_physics_frames() % 2 == 0:
					Effects.afterimage(get_parent(), self, Color(0.6, 0.9, 1.0, 0.5))
				var n := hit_rect(box(Vector2(44, -48), Vector2(76, 56)), {"dmg": 8.0 + 13.0 * c,
					"base_kb": 300.0 + 260.0 * c, "kb_scale": 7.0 + 5.0 * c, "angle": 35.0, "special": true})
				if n > 0 and not act.has("boom"):
					act["boom"] = true
					var p := global_position + Vector2(facing * 60, -48)
					Effects.explosion(get_parent(), p, 60.0 + 60.0 * c, Color(1, 0.95, 0.7))
					Game.play_sfx("explosion", -4.0, 1.3)
					velocity.x *= 0.2
			else:
				ground_friction(delta, 2.0)
				if not is_on_floor():
					apply_gravity(delta)
			if rt >= 0.5:
				end_action()
		"tornado":
			if t < 0.02:
				velocity = Vector2(facing * 140.0 + in_move * 120.0, -880.0 * mods["jump"])
				Game.play_sfx("uppercut", -2.0, 1.2)
			anim_frame("upspecial", int(t * 14.0) % 3)
			air_drift(delta, 0.6)
			apply_gravity(delta, 0.55)
			if Engine.get_physics_frames() % 3 == 0:
				Effects.swoosh(self, randf() * 360.0, randf() * 360.0 + 200.0, 50.0, Color(0.6, 0.95, 1.0), 0.15, 8.0)
			var idx := int(t / 0.08)
			if idx != act.get("idx", -1) and idx <= 5:
				act["idx"] = idx
				hit_list.clear()
			if t < 0.4:
				var last := t >= 0.32
				hit_rect(box(Vector2(0, -46), Vector2(96, 96)), {"dmg": 4.5 if last else 2.2,
					"base_kb": 330.0 if last else 60.0, "kb_scale": 7.0 if last else 0.4, "angle": 82.0, "special": true})
			if t >= 0.52:
				end_action(true)
		"axe":
			anim_frame("downspecial", 0 if t < 0.14 else (1 if t < 0.26 else 3))
			_action_physics(delta)
			if t >= 0.14 and t < 0.24:
				if hit_rect(box(Vector2(42, -24), Vector2(76, 56)), {"dmg": 11.0, "base_kb": 300.0, "kb_scale": 7.5,
						"angle": 78.0, "special": true}) > 0:
					Effects.shockwave(get_parent(), global_position + Vector2(facing * 50, 0), Color(0.6, 0.9, 1.0), 200.0)
			if t >= 0.14 and not act.has("fx"):
				act["fx"] = true
				Game.play_sfx("swing_heavy", -2.0, 0.9)
				Effects.dust(get_parent(), global_position + Vector2(facing * 50, 0))
			if t >= 0.46:
				end_action()
		"axe_air":
			anim_frame("dair", 0 if t < 0.12 else 1)
			if t < 0.12:
				velocity *= 0.8
			else:
				velocity = Vector2(facing * 100.0, 1350.0)
				if Engine.get_physics_frames() % 2 == 0:
					Effects.afterimage(get_parent(), self, Color(0.6, 0.9, 1.0, 0.45))
				hit_rect(box(Vector2(16, -14), Vector2(62, 62)), {"dmg": 12.0, "base_kb": 260.0, "kb_scale": 7.0,
					"angle": -78.0, "special": true})
			if is_on_floor() and t > 0.12:
				hit_list.clear()
				hit_circle(global_position + Vector2(0, -20), 80.0, {"dmg": 6.0, "base_kb": 240.0, "kb_scale": 5.0,
					"angle": 70.0, "special": true})
				Effects.shockwave(get_parent(), global_position, Color(0.6, 0.9, 1.0), 260.0)
				Game.play_sfx("quake", -4.0, 1.3)
				end_action()
				landing_lag = 0.18
				return
			if t >= 1.1:
				end_action()
		"ult_jacket":
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			velocity.y = 0.0 if is_on_floor() else minf(velocity.y + 400.0 * delta, 200.0)
			anim_frame("ult", mini(int(t / 0.16), 3))
			if t >= 0.3 and not act.has("off"):
				act["off"] = true
				_throw_jacket()
				Game.play_sfx("cloth")
				Game.play_sfx("powerup", -2.0)
				set_form("ult")
				if buff_t <= 0.0:
					for k in BUFF:
						mods[k] *= BUFF[k]
					mods["extra_jumps"] += 1
				buff_t = BUFF_TIME
				air_jumps_left = max_air_jumps()
				var p := global_position + Vector2(0, -46)
				Effects.ring(get_parent(), p, Color(0.6, 0.95, 1.0), 120.0)
				Effects.burst(get_parent(), p, {"count": 30, "color": Color(0.7, 0.95, 1.0), "speed": 380.0, "life": 0.6,
					"size": 4.0, "star": true})
				Effects.popup(get_parent(), global_position + Vector2(0, -190), "¡SIN CHAQUETA!", data["color"], 1.3)
			if t >= 0.8:
				end_action()
		_:
			super.char_action(action_name, t, delta)


## La chaqueta sale volando hacia atrás, gira y cae.
func _throw_jacket() -> void:
	var s := Sprite2D.new()
	s.texture = preload("res://assets/sprites/prop_jacket.png")
	s.global_position = global_position + Vector2(0, -60)
	s.z_index = 3
	get_parent().add_child(s)
	var dir := -facing
	var tw := s.create_tween().set_parallel(true)
	tw.tween_property(s, "position:x", s.position.x + dir * 220.0, 1.1)
	tw.tween_property(s, "position:y", s.position.y - 120.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(s, "position:y", s.position.y + 260.0, 0.7).set_delay(0.4).set_ease(Tween.EASE_IN) \
		.set_trans(Tween.TRANS_QUAD)
	tw.tween_property(s, "rotation", dir * TAU * 1.5, 1.1)
	tw.tween_property(s, "modulate:a", 0.0, 0.3).set_delay(0.8)
	tw.chain().tween_callback(s.queue_free)
