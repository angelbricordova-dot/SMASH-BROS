extends Fighter
## GRUNK — bruto de las montañas.
##  Especial (tocar G) ....... Lanzar roca (en arco)
##  Especial (mantener G) .... Carga de toro (embestida con súper armadura, más lejos según la carga)
##  Arriba + Especial ........ Supersalto con cabezazo
##  Abajo + Especial ......... Golpe sísmico (onda que lanza hacia arriba a los que estén cerca en el suelo)
##  Ulti ..................... Terremoto (lanza a TODOS los que estén en el suelo: ¡salta para esquivarlo!)


func do_special() -> void:
	begin_action("boulder")


func do_charge_special() -> void:
	begin_action("charge_bull")


func do_up_special() -> void:
	begin_action("superjump")


func do_down_special() -> void:
	begin_action("seismic")


func do_ultimate() -> void:
	begin_action("ult_quake")


func char_action(action_name: String, t: float, delta: float) -> void:
	match action_name:
		"boulder":
			anim_frame("special", mini(int(t / 0.12), 3))
			if not act.has("fired") and t >= 0.28:
				act["fired"] = true
				spawn_projectile({"velocity": Vector2(facing * 470.0, -260.0), "gravity": 1300.0,
					"global_position": global_position + Vector2(facing * 34, -60), "radius": 16.0,
					"sprite_scale": 1.3, "lifetime": 2.0, "solid": true,
					"info": {"dmg": 12.0, "base_kb": 360.0, "kb_scale": 9.0, "angle": 45.0}})
				Game.play_sfx("throw", 0.0, 0.7)
			_action_physics(delta)
			if t >= 0.6:
				end_action()
		"charge_bull":
			armor_time = 0.1
			_action_physics(delta)
			if hold_charge(t, 1.0):
				return
			var c: float = act["charge"]
			var rt: float = t - float(act["released"])
			anim_frame("dash", 1 if rt < 0.3 else 3)
			if rt < 0.35:
				velocity.x = facing * (450.0 + 550.0 * c)
				if Engine.get_physics_frames() % 3 == 0:
					Effects.dust(get_parent(), global_position)
				hit_rect(box(Vector2(30, -40), Vector2(60, 70)), {"dmg": 10.0 + 10.0 * c, "base_kb": 350.0,
					"kb_scale": 9.0, "angle": 38.0, "fx": "rock", "special": true})
			elif not act.has("sfx"):
				act["sfx"] = true
			if rt < delta * 1.5:
				Game.play_sfx("dash", 0.0, 0.7)
			if rt >= 0.55:
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
				Effects.ring(get_parent(), global_position, Color(0.8, 0.7, 0.5), 60.0)
			anim_frame("upspecial", 1)
			if t < 0.4:
				hit_rect(box(Vector2(4, -84), Vector2(64, 64)),
					{"dmg": 10.0, "base_kb": 330.0, "kb_scale": 8.0, "angle": 85.0, "special": true})
			air_drift(delta, 0.4)
			apply_gravity(delta, 0.85)
			if t >= 0.6:
				end_action(true)
		"seismic":
			if not act.has("landed"):
				if is_on_floor():
					act["landed"] = t
				else:
					anim_frame("dair", 1)
					velocity = Vector2(0, 1300.0)
					if t > 1.5:
						end_action()
					return
			var t0: float = act["landed"]
			anim_frame("downspecial", mini(int((t - t0) / 0.1), 3))
			_action_physics(delta)
			if not act.has("boom") and t - t0 >= 0.15:
				act["boom"] = true
				Effects.shockwave(get_parent(), global_position, Color(0.85, 0.7, 0.45), 380.0)
				Game.play_sfx("quake", -6.0, 1.3)
				hit_landed.emit(10.0)
				for e in enemies():
					if absf(e.global_position.x - global_position.x) < 190.0 and absf(e.global_position.y - global_position.y) < 50.0:
						var d := 1 if e.global_position.x >= global_position.x else -1
						e.apply_hit(self, {"dmg": 10.0, "base_kb": 330.0, "kb_scale": 6.0, "angle": 82.0, "dir": d,
							"pos": e.global_position + Vector2(0, -20), "projectile": true, "fx": "rock"})
			if t - t0 >= 0.5:
				end_action()
		"ult_quake":
			if not act.has("up"):
				act["up"] = true
				velocity = Vector2(0, -750.0)
				floor_snap_length = 0.0
			if t < 0.45:
				anim_frame("ult", 1)
				velocity.x = 0.0
				apply_gravity(delta)
				return
			if not act.has("slam"):
				act["slam"] = true
				velocity = Vector2(0, 1700.0)
			anim_frame("dair", 1)
			if is_on_floor() and not act.has("landed"):
				act["landed"] = t
				Game.play_sfx("quake")
				Effects.shockwave(get_parent(), global_position, Color(0.9, 0.75, 0.4), 2400.0)
				hit_landed.emit(50.0)
				for e in enemies():
					if e.is_on_floor() or absf(e.global_position.y - global_position.y) < 120.0:
						var d := 1 if e.global_position.x >= global_position.x else -1
						e.apply_hit(self, {"dmg": 25.0, "base_kb": 700.0, "kb_scale": 5.0, "angle": 82.0,
							"dir": d, "pos": e.global_position + Vector2(0, -20), "projectile": true, "fx": "rock"})
			if act.has("landed"):
				velocity = Vector2.ZERO
				anim_frame("downspecial", 2)
				if t - float(act["landed"]) > 0.5:
					end_action()
			elif t > 2.5:
				end_action()
		_:
			super.char_action(action_name, t, delta)
