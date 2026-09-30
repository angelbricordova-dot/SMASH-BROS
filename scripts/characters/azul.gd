extends Fighter
## KORI — ninja del hielo.
##  Especial ........ Shurikens de hielo (3 a la vez, rápidos y débiles)
##  Arriba+Especial . Ráfaga (se lanza en la dirección que presiones, 8 direcciones)
##  Ulti ............ Ventisca Eterna (congela a todos, los daña y luego los hace estallar)


func do_special() -> void:
	begin_action("shards")


func do_up_special() -> void:
	begin_action("dash")


func do_ultimate() -> void:
	begin_action("ult_blizzard")


func char_action(action_name: String, t: float, delta: float) -> void:
	match action_name:
		"shards":
			anim_frame("special", mini(int(t / 0.07), 3))
			if not act.has("fired") and t >= 0.1:
				act["fired"] = true
				for deg in [-9.0, 0.0, 9.0]:
					spawn_projectile({"velocity": Vector2(facing * 900.0, 0).rotated(deg_to_rad(deg)),
						"global_position": global_position + Vector2(facing * 36, -44), "radius": 9.0,
						"lifetime": 0.45, "info": {"dmg": 3.0, "base_kb": 150.0, "kb_scale": 3.0, "angle": 20.0}})
				Game.play_sfx("shoot", -4.0, 1.4)
			_action_physics(delta)
			if t >= 0.32:
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
				invincible_time = maxf(invincible_time, 0.03)
				if Engine.get_physics_frames() % 2 == 0:
					Effects.afterimage(get_parent(), self, Color(0.5, 0.9, 1.0, 0.6))
				var hdir := facing if absf(dir.x) < 0.1 else int(signf(dir.x))
				hit_rect(box(Vector2(0, -36), Vector2(56, 76)),
					{"dmg": 7.0, "base_kb": 300.0, "kb_scale": 5.0, "angle": 70.0}, hdir)
			else:
				if not act.has("stop"):
					act["stop"] = true
					velocity *= 0.3
				apply_gravity(delta)
				air_drift(delta, 0.4)
			if t >= 0.34:
				end_action(true)
		"ult_blizzard":
			velocity = Vector2.ZERO
			anim_frame("taunt", 2 if t < 1.9 else 3)
			if t >= 0.4 and not act.has("frozen"):
				var victims := []
				for e in enemies():
					if e.global_position.distance_to(global_position) < 1300.0 and e.invincible_time <= 0.0:
						e.freeze(2.0)
						victims.append(e)
				act["frozen"] = victims
				act["ticks"] = 0
				Effects.snow(get_parent(), get_viewport().get_camera_2d().get_screen_center_position() if get_viewport().get_camera_2d() else global_position, 2.0)
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
							e.apply_hit(self, {"dmg": 10.0, "base_kb": 620.0, "kb_scale": 4.5, "angle": 75.0,
								"dir": d, "pos": e.global_position + Vector2(0, -40), "projectile": true, "sfx": "hit_strong"})
			if t >= 2.2:
				end_action()
		_:
			super.char_action(action_name, t, delta)
