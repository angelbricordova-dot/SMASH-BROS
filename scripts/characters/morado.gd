extends Fighter
## UMBRA — espectro de las sombras (inspirado en Omen de Valorant).
##  Especial ........ Paranoia (orbe lento que atraviesa y golpea a todos)
##  Arriba+Especial . Paso sombrío (se desvanece y reaparece en la dirección que presiones)
##  Ulti ............ Desde las Sombras (desaparece y aparece a la ESPALDA del rival para golpearlo)

const STEP_DISTANCE := 290.0


func do_special() -> void:
	begin_action("paranoia")


func do_up_special() -> void:
	begin_action("step")


func do_ultimate() -> void:
	begin_action("ult_shadow")


func char_action(action_name: String, t: float, delta: float) -> void:
	match action_name:
		"paranoia":
			anim_frame("special", mini(int(t / 0.1), 3))
			if not act.has("fired") and t >= 0.25:
				act["fired"] = true
				spawn_projectile({"velocity": Vector2(facing * 400.0, 0),
					"global_position": global_position + Vector2(facing * 40, -44), "radius": 20.0,
					"sprite_scale": 3.0, "lifetime": 1.8, "pierce": true,
					"info": {"dmg": 8.0, "base_kb": 280.0, "kb_scale": 6.5, "angle": 38.0}})
				Game.play_sfx("shadow", -3.0)
			_action_physics(delta)
			if t >= 0.55:
				end_action()
		"step":
			velocity = Vector2.ZERO
			if not act.has("vanish"):
				act["vanish"] = true
				vanished = true
				invincible_time = maxf(invincible_time, 0.45)
				Game.play_sfx("teleport")
				Effects.smoke(get_parent(), global_position)
			if t >= 0.28 and not act.has("moved"):
				act["moved"] = true
				var d := input_dir(Vector2.UP)
				if absf(d.x) > 0.1:
					facing = 1 if d.x > 0.0 else -1
				move_and_collide(d * STEP_DISTANCE)   # no atraviesa el suelo
				vanished = false
				floor_snap_length = 0.0
				Effects.smoke(get_parent(), global_position)
			if t >= 0.42:
				end_action(true)
		"ult_shadow":
			velocity = Vector2.ZERO
			if not act.has("vanish"):
				act["vanish"] = true
				vanished = true
				invincible_time = maxf(invincible_time, 1.2)
				Game.play_sfx("shadow")
				Effects.smoke(get_parent(), global_position)
			if t >= 0.7 and not act.has("appear"):
				act["appear"] = true
				var target := find_target()
				if target:
					# aparecer a la espalda del rival, mirándolo
					facing = target.facing
					global_position = target.global_position + Vector2(-target.facing * 56.0, 0)
				else:
					global_position = Vector2(0, stage_info["ground_y"] - 1.0)
				vanished = false
				Effects.smoke(get_parent(), global_position)
				Game.play_sfx("teleport", 0.0, 0.7)
			if act.has("appear"):
				anim_frame("attack", 0 if t < 0.8 else 2)
				if t >= 0.8 and t < 0.95:
					hit_rect(box(Vector2(30, -40), Vector2(96, 96)),
						{"dmg": 30.0, "base_kb": 720.0, "kb_scale": 5.0, "angle": 40.0, "sfx": "hit_strong"})
			if t >= 1.2:
				end_action()
		_:
			super.char_action(action_name, t, delta)
