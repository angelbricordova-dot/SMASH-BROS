extends Fighter
## GRUNK — bruto de las montañas.
##  Especial ........ Lanzar roca (cae en arco, pega fuerte)
##  Arriba+Especial . Supersalto (salto enorme con cabezazo)
##  Ulti ............ Terremoto (salta y golpea el suelo: lanza a todos los que estén en el piso)


func do_special() -> void:
	begin_action("boulder")


func do_up_special() -> void:
	begin_action("superjump")


func do_ultimate() -> void:
	begin_action("ult_quake")


func char_action(action_name: String, t: float, delta: float) -> void:
	match action_name:
		"boulder":
			anim_frame("special", mini(int(t / 0.12), 3))
			if not act.has("fired") and t >= 0.28:
				act["fired"] = true
				spawn_projectile({"velocity": Vector2(facing * 470.0, -260.0), "gravity": 1300.0,
					"global_position": global_position + Vector2(facing * 34, -56), "radius": 16.0,
					"sprite_scale": 2.4, "lifetime": 2.0, "solid": true,
					"info": {"dmg": 12.0, "base_kb": 360.0, "kb_scale": 9.0, "angle": 45.0}})
				Game.play_sfx("throw", 0.0, 0.7)
			_action_physics(delta)
			if t >= 0.6:
				end_action()
		"superjump":
			if t < 0.1:
				anim_frame("crouch", 0)
				velocity.x *= 0.5
				apply_gravity(delta)
				return
			if not act.has("go"):
				act["go"] = true
				velocity = Vector2(in_move * 180.0, -1150.0)
				floor_snap_length = 0.0
				Game.play_sfx("jump", 0.0, 0.6)
				Effects.dust(get_parent(), global_position)
				Effects.ring(get_parent(), global_position, Color(0.8, 0.7, 0.5), 50.0)
			anim_frame("upspecial", 1)
			if t < 0.4:
				hit_rect(box(Vector2(4, -80), Vector2(60, 60)),
					{"dmg": 10.0, "base_kb": 330.0, "kb_scale": 8.0, "angle": 85.0})
			air_drift(delta, 0.4)
			apply_gravity(delta, 0.85)
			if t >= 0.6:
				end_action(true)
		"ult_quake":
			if not act.has("up"):
				act["up"] = true
				velocity = Vector2(0, -750.0)
				floor_snap_length = 0.0
			if t < 0.45:
				anim_frame("jump", 0)
				velocity.x = 0.0
				apply_gravity(delta)
				return
			if not act.has("slam"):
				act["slam"] = true
				velocity = Vector2(0, 1700.0)
			anim_frame("upspecial", 0)
			if is_on_floor() and not act.has("landed"):
				act["landed"] = t
				Game.play_sfx("quake")
				Effects.shockwave(get_parent(), global_position, Color(0.9, 0.75, 0.4), 2200.0)
				hit_landed.emit(45.0)
				for e in enemies():
					if e.is_on_floor() or absf(e.global_position.y - global_position.y) < 120.0:
						var d := 1 if e.global_position.x >= global_position.x else -1
						e.apply_hit(self, {"dmg": 24.0, "base_kb": 700.0, "kb_scale": 5.0, "angle": 82.0,
							"dir": d, "pos": e.global_position + Vector2(0, -20), "projectile": true, "sfx": "hit_strong"})
			if act.has("landed"):
				velocity = Vector2.ZERO
				anim_frame("crouch", 0)
				if t - float(act["landed"]) > 0.5:
					end_action()
			elif t > 2.5:
				end_action()
		_:
			super.char_action(action_name, t, delta)
