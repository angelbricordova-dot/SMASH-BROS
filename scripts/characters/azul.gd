extends Fighter
## KORI — ninja del hielo.
##  Especial (tocar G) ....... Shurikens de hielo (3 a la vez)
##  Especial (mantener G) .... Tormenta de shurikens (hasta 9 en abanico)
##  Arriba + Especial ........ Ráfaga (se lanza en cualquiera de 8 direcciones)
##  Abajo + Especial ......... Patada en picada (aire) / barrida (suelo)
##  Ulti ..................... Ventisca Eterna (congela a todos, los daña y los hace estallar)


func do_special() -> void:
	begin_action("shards")


func do_charge_special() -> void:
	begin_action("charge_shards")


func do_up_special() -> void:
	begin_action("dash")


func do_down_special() -> void:
	begin_action("dive")


func do_ultimate() -> void:
	begin_action("ult_blizzard")


func _throw_shards(n: int, spread: float) -> void:
	for i in n:
		var deg := 0.0 if n == 1 else lerpf(-spread, spread, float(i) / (n - 1))
		spawn_projectile({"velocity": Vector2(facing * 950.0, 0).rotated(deg_to_rad(deg) * facing),
			"global_position": global_position + Vector2(facing * 36, -48), "radius": 9.0, "lifetime": 0.5,
			"info": {"dmg": 3.0, "base_kb": 150.0, "kb_scale": 3.0, "angle": 20.0, "fx": "ice"}})
	Game.play_sfx("shoot", -4.0, 1.4)


func char_action(action_name: String, t: float, delta: float) -> void:
	match action_name:
		"shards":
			anim_frame("special", mini(int(t / 0.06), 3))
			if not act.has("fired") and t >= 0.1:
				act["fired"] = true
				_throw_shards(3, 9.0)
			_action_physics(delta)
			if t >= 0.3:
				end_action()
		"charge_shards":
			_action_physics(delta)
			if hold_charge(t, 0.9):
				return
			var rt: float = t - float(act["released"])
			anim_frame("charge", 2 if rt < 0.1 else 3)
			if not act.has("fired"):
				act["fired"] = true
				_throw_shards(3 + int(6.0 * act["charge"]), 9.0 + 16.0 * act["charge"])
			if rt >= 0.25:
				end_action()
		"dash":
			if t < 0.06:
				anim_frame("upspecial", 0)
				velocity = Vector2.ZERO
				return
			if not act.has("dir"):
				var d := input_dir(Vector2.UP)
				act["dir"] = d
				if absf(d.x) > 0.1:
					facing = 1 if d.x > 0.0 else -1
				floor_snap_length = 0.0
				Game.play_sfx("dash")
			var dir: Vector2 = act["dir"]
			if t < 0.26:
				anim_frame("upspecial", 1)
				velocity = dir * 1150.0
				intangible_time = maxf(intangible_time, 0.03)
				if Engine.get_physics_frames() % 2 == 0:
					Effects.afterimage(get_parent(), self, Color(0.5, 0.9, 1.0, 0.6))
				var hdir := facing if absf(dir.x) < 0.1 else int(signf(dir.x))
				hit_rect(box(Vector2(0, -38), Vector2(58, 80)),
					{"dmg": 7.0, "base_kb": 300.0, "kb_scale": 5.0, "angle": 70.0, "fx": "ice", "special": true}, hdir)
			else:
				if not act.has("stop"):
					act["stop"] = true
					velocity *= 0.3
				apply_gravity(delta)
				air_drift(delta, 0.4)
			if t >= 0.34:
				end_action(true)
		"dive":
			if t < delta * 1.5:
				act["air"] = not is_on_floor()
				Game.play_sfx("dash", -2.0)
			if act["air"]:
				anim_frame("dair", 1)
				if not act.has("bounce"):
					velocity = Vector2(facing * 650.0, 950.0)
					if hit_rect(box(Vector2(14, -6), Vector2(50, 46)),
							{"dmg": 9.0, "base_kb": 250.0, "kb_scale": 6.0, "angle": -45.0, "fx": "ice", "special": true}) > 0:
						act["bounce"] = true
						velocity = Vector2(-facing * 220.0, -620.0)
					if Engine.get_physics_frames() % 2 == 0:
						Effects.afterimage(get_parent(), self, Color(0.5, 0.9, 1.0, 0.5))
				else:
					apply_gravity(delta)
				if is_on_floor() or t > 0.9:
					end_action()
					landing_lag = 0.1
			else:
				anim_frame("dtilt", 1)
				velocity.x = facing * 560.0 * (1.0 - t / 0.4)
				velocity.y = 0.0
				if t < 0.3:
					hit_rect(box(Vector2(30, -12), Vector2(60, 30)),
						{"dmg": 8.0, "base_kb": 260.0, "kb_scale": 5.0, "angle": 75.0, "fx": "ice", "special": true})
				if t >= 0.42:
					end_action()
		"ult_blizzard":
			velocity = Vector2.ZERO
			anim_frame("ult", 1 if t < 1.9 else 3)
			if t >= 0.4 and not act.has("frozen"):
				var victims := []
				for e in enemies():
					if e.global_position.distance_to(global_position) < 1400.0 and e.invincible_time <= 0.0:
						e.freeze(2.0)
						victims.append(e)
				act["frozen"] = victims
				act["ticks"] = 0
				var cam := get_viewport().get_camera_2d()
				Effects.snow(get_parent(), cam.get_screen_center_position() if cam else global_position, 2.0)
				Game.play_sfx("freeze")
			if act.has("frozen"):
				var ticks: int = act["ticks"]
				if ticks < 4 and t >= 0.8 + ticks * 0.3:
					act["ticks"] = ticks + 1
					for e in act["frozen"]:
						if is_instance_valid(e) and e.state == State.FROZEN:
							e.take_damage(4.0, self)
					Game.play_sfx("hit", -8.0, 1.6)
				if t >= 2.0 and not act.has("shattered"):
					act["shattered"] = true
					Game.play_sfx("shatter")
					for e in act["frozen"]:
						if is_instance_valid(e) and e.state == State.FROZEN:
							var d := 1 if e.global_position.x >= global_position.x else -1
							Effects.shatter(get_parent(), e.global_position + Vector2(0, -40), Color(0.7, 0.9, 1.0))
							e.apply_hit(self, {"dmg": 12.0, "base_kb": 640.0, "kb_scale": 4.5, "angle": 75.0,
								"dir": d, "pos": e.global_position + Vector2(0, -40), "projectile": true, "fx": "ice"})
			if t >= 2.2:
				end_action()
		_:
			super.char_action(action_name, t, delta)
