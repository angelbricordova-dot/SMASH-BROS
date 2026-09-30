extends Fighter
## RYU-KO — artista marcial de fuego.
##  Especial ........ Bola de fuego (proyectil recto)
##  Arriba+Especial . Puño del Dragón (gancho ascendente que golpea)
##  Ulti ............ Rayo Dragón (rayo gigante que cruza la pantalla)


func do_special() -> void:
	begin_action("fireball")   # la bola de fuego viene del Fighter base


func do_up_special() -> void:
	begin_action("uppercut")


func do_ultimate() -> void:
	begin_action("ult_beam")


func char_action(action_name: String, t: float, delta: float) -> void:
	match action_name:
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
			anim_frame("upspecial", 1 if t > 0.12 else 0)
			if t < 0.32:
				hit_rect(box(Vector2(12, -70), Vector2(52, 86)),
					{"dmg": 12.0, "base_kb": 340.0, "kb_scale": 8.0, "angle": 80.0, "sfx": "fire"})
				if Engine.get_physics_frames() % 3 == 0:
					Effects.spark(get_parent(), global_position + Vector2(facing * 14, -90), 0.3, Color(1, 0.6, 0.2))
			air_drift(delta, 0.3)
			apply_gravity(delta, 0.9)
			if t >= 0.5:
				end_action(true)
		"ult_beam":
			velocity = Vector2.ZERO
			if t < 0.55:
				anim_frame("special", 0 if t < 0.3 else 1)
				if Engine.get_physics_frames() % 6 == 0:
					Effects.ring(get_parent(), global_position + Vector2(facing * 34, -44), Color(1, 0.6, 0.2), 60.0 * (1.0 - t))
				return
			if not act.has("fired"):
				act["fired"] = true
				Effects.beam(get_parent(), global_position + Vector2(facing * 40, -44), facing, 1700.0, 110.0,
					Color(1, 0.5, 0.15), 1.0)
				Game.play_sfx("beam")
				hit_landed.emit(12.0)
			anim_frame("special", 2)
			if t < 1.45:
				var x0 := global_position.x + facing * 40.0
				var r := Rect2(x0 if facing > 0 else x0 - 1700.0, global_position.y - 99.0, 1700.0, 110.0)
				hit_rect(r, {"dmg": 28.0, "base_kb": 700.0, "kb_scale": 5.0, "angle": 25.0, "sfx": "hit_strong"})
			if t >= 1.6:
				end_action()
		_:
			super.char_action(action_name, t, delta)
