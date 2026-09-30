extends Fighter
## RYU-KO — artista marcial de fuego.
##  Especial (tocar G) ....... Bola de fuego
##  Especial (mantener G) .... Gran bola de fuego (más grande y fuerte según la carga)
##  Arriba + Especial ........ Puño del Dragón (gancho ascendente)
##  Abajo + Especial ......... Pisotón llameante (en el suelo: explosión de fuego; en el aire: patada en picada)
##  Ulti ..................... Rayo Dragón (rayo gigante que cruza la pantalla)


func do_special() -> void:
	begin_action("fireball")


func do_charge_special() -> void:
	begin_action("charge_fire")


func do_up_special() -> void:
	begin_action("uppercut")


func do_down_special() -> void:
	begin_action("stomp")


func do_ultimate() -> void:
	begin_action("ult_beam")


func char_action(action_name: String, t: float, delta: float) -> void:
	match action_name:
		"fireball":
			anim_frame("special", mini(int(t / 0.08), 3))
			if not act.has("fired") and t >= 0.16:
				act["fired"] = true
				spawn_projectile({"velocity": Vector2(facing * 640, 0), "radius": 14.0,
					"global_position": global_position + Vector2(facing * 40, -48),
					"info": {"dmg": 6.0, "base_kb": 250.0, "kb_scale": 5.0, "angle": 30.0, "fx": "fire"}})
				Game.play_sfx("fire", -4.0)
			_action_physics(delta)
			if t >= 0.4:
				end_action()
		"charge_fire":
			_action_physics(delta)
			if hold_charge(t, 1.0):
				return
			var c: float = act["charge"]
			var rt: float = t - float(act["released"])
			anim_frame("charge", 2 if rt < 0.12 else 3)
			if not act.has("fired"):
				act["fired"] = true
				spawn_projectile({"velocity": Vector2(facing * (600.0 + 300.0 * c), 0), "radius": 14.0 + 18.0 * c,
					"global_position": global_position + Vector2(facing * 44, -48), "pierce": c >= 1.0,
					"lifetime": 1.4, "info": {"dmg": 8.0 + 10.0 * c, "base_kb": 280.0 + 200.0 * c, "kb_scale": 6.0,
						"angle": 32.0, "fx": "fire"}})
				Game.play_sfx("fire", 0.0, 1.0 - 0.3 * c)
				hit_landed.emit(4.0 * c)
			if rt >= 0.3:
				end_action()
		"uppercut":
			if t < 0.05:
				anim_frame("upspecial", 0)
				velocity *= 0.3
				return
			if not act.has("go"):
				act["go"] = true
				velocity = Vector2(facing * 120.0 + in_move * 100.0, -1000.0)
				floor_snap_length = 0.0
				Game.play_sfx("uppercut")
			anim_frame("upspecial", 1 if t < 0.2 else 2)
			if t < 0.32:
				hit_rect(box(Vector2(12, -74), Vector2(56, 90)),
					{"dmg": 12.0, "base_kb": 340.0, "kb_scale": 8.0, "angle": 80.0, "fx": "fire", "special": true})
				if Engine.get_physics_frames() % 2 == 0:
					Effects.burst(get_parent(), global_position + Vector2(facing * 14, -90), {"count": 3,
						"color": Color(1, 0.55, 0.15), "speed": 80.0, "life": 0.35, "size": 5.0, "gravity": -100.0})
			air_drift(delta, 0.3)
			apply_gravity(delta, 0.9)
			if t >= 0.5:
				end_action(true)
		"stomp":
			if t < delta * 1.5:
				act["air"] = not is_on_floor()
				Game.play_sfx("fire", -2.0)
			if act["air"] and not act.has("landed"):
				anim_frame("dair", 1)
				velocity = Vector2(facing * 420.0, 1000.0)
				hit_rect(box(Vector2(10, 0), Vector2(56, 44)),
					{"dmg": 9.0, "base_kb": 260.0, "kb_scale": 6.0, "angle": -50.0, "fx": "fire", "special": true})
				if is_on_floor() or t > 1.2:
					act["landed"] = t
					hit_list.clear()
				return
			var t0: float = act.get("landed", 0.0)
			anim_frame("downspecial", mini(int((t - t0) / 0.08) + 1, 3))
			_action_physics(delta)
			if not act.has("boom") and t - t0 >= 0.08:
				act["boom"] = true
				Effects.explosion(get_parent(), global_position + Vector2(0, -24), 80.0, Color(1, 0.5, 0.15))
				Game.play_sfx("explosion", -6.0, 1.2)
				hit_circle(global_position + Vector2(0, -30), 85.0,
					{"dmg": 11.0, "base_kb": 320.0, "kb_scale": 8.0, "angle": 60.0, "fx": "fire", "special": true})
			if t - t0 >= 0.4:
				end_action()
		"ult_beam":
			velocity = Vector2.ZERO
			if t < 0.55:
				anim_frame("ult", 1 if t < 0.3 else 2)
				if Engine.get_physics_frames() % 5 == 0:
					Effects.ring(get_parent(), global_position + Vector2(facing * 34, -44), Color(1, 0.6, 0.2), 70.0 * (1.0 - t))
				return
			if not act.has("fired"):
				act["fired"] = true
				Effects.beam(get_parent(), global_position + Vector2(facing * 40, -48), facing, 1800.0, 130.0,
					Color(1, 0.5, 0.15), 1.0)
				Game.play_sfx("beam")
				hit_landed.emit(16.0)
			anim_frame("ult", 3)
			if t < 1.45:
				var x0 := global_position.x + facing * 40.0
				var r := Rect2(x0 if facing > 0 else x0 - 1800.0, global_position.y - 113.0, 1800.0, 130.0)
				hit_rect(r, {"dmg": 30.0, "base_kb": 720.0, "kb_scale": 5.0, "angle": 25.0, "fx": "fire"})
			if t >= 1.6:
				end_action()
		_:
			super.char_action(action_name, t, delta)
