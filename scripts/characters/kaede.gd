extends Fighter
## KAEDE — samurái de la flor de cerezo.
##  Especial (tocar G) ....... Corte al viento (onda cortante que atraviesa)
##  Especial (mantener G) .... Estocada (se lanza hacia delante; más lejos y fuerte según la carga)
##  Arriba + Especial ........ Iai ascendente (corte que sube en la dirección que apuntes)
##  Abajo + Especial ......... Contraataque (si te golpean durante la postura, devuelves el golpe más fuerte)
##  Ulti ..................... Mil Cortes (lluvia de cortes sobre todos los rivales)


func do_special() -> void:
	begin_action("wind")


func do_charge_special() -> void:
	begin_action("charge_lunge")


func do_up_special() -> void:
	begin_action("iai")


func do_down_special() -> void:
	begin_action("counter")


func do_ultimate() -> void:
	begin_action("ult_cuts")


func try_counter(attacker: Fighter, info: Dictionary) -> bool:
	if state != State.ACTION or action != "counter" or action_t < 0.05 or action_t > 0.6 or act.has("countered"):
		return false
	act["countered"] = true
	action_t = 0.61
	invincible_time = 0.5
	parry_flash = 0.3
	Game.play_sfx("counter")
	Effects.popup(get_parent(), global_position + Vector2(0, -120), "¡CONTRA!", Color(1, 0.6, 0.8), 1.2)
	if attacker and is_instance_valid(attacker):
		if not info.get("projectile", false):
			facing = 1 if attacker.global_position.x > global_position.x else -1
			global_position.x = attacker.global_position.x - facing * 50.0
		act["victim"] = attacker
		act["dmg"] = maxf(8.0, float(info["dmg"]) * 1.3)
	return true


func char_action(action_name: String, t: float, delta: float) -> void:
	match action_name:
		"wind":
			anim_frame("special", mini(int(t / 0.07), 3))
			if not act.has("fired") and t >= 0.14:
				act["fired"] = true
				Effects.swoosh(self, -60.0, 60.0, 70.0, Color(1, 0.8, 0.9), 0.2, 10.0)
				spawn_projectile({"velocity": Vector2(facing * 820.0, 0), "radius": 18.0, "lifetime": 0.55,
					"pierce": true, "sprite_scale": 1.4, "global_position": global_position + Vector2(facing * 50, -48),
					"info": {"dmg": 7.0, "base_kb": 240.0, "kb_scale": 6.0, "angle": 35.0}})
				Game.play_sfx("slash")
			_action_physics(delta)
			if t >= 0.4:
				end_action()
		"charge_lunge":
			_action_physics(delta)
			if hold_charge(t, 1.0):
				return
			var c: float = act["charge"]
			var rt: float = t - float(act["released"])
			anim_frame("dash", 1 if rt < 0.25 else 3)
			if rt < 0.25:
				velocity = Vector2(facing * (700.0 + 700.0 * c), 0)
				if rt < 0.03:
					Game.play_sfx("slash", 0.0, 0.8)
					Effects.swoosh(self, -5.0, 5.0, 90.0, Color(1, 0.8, 0.9), 0.3, 14.0)
				if Engine.get_physics_frames() % 2 == 0:
					Effects.afterimage(get_parent(), self, Color(1, 0.6, 0.8, 0.5))
				hit_rect(box(Vector2(50, -44), Vector2(100, 40)), {"dmg": 9.0 + 11.0 * c, "base_kb": 320.0,
					"kb_scale": 8.0 + 3.0 * c, "angle": 30.0, "special": true})
			else:
				velocity.x = move_toward(velocity.x, 0.0, 4000.0 * delta)
			if rt >= 0.45:
				end_action()
		"iai":
			if t < 0.08:
				anim_frame("upspecial", 0)
				velocity = Vector2.ZERO
				return
			if not act.has("dir"):
				var d := input_dir(Vector2(0.35 * facing, -1.0).normalized())
				if d.y > 0.3:
					d = Vector2(d.x, -0.2).normalized()
				act["dir"] = d
				if absf(d.x) > 0.2:
					facing = 1 if d.x > 0.0 else -1
				floor_snap_length = 0.0
				Game.play_sfx("slash")
			var dir: Vector2 = act["dir"]
			if t < 0.3:
				anim_frame("upspecial", 1)
				velocity = dir * 1000.0
				if Engine.get_physics_frames() % 2 == 0:
					Effects.afterimage(get_parent(), self, Color(1, 0.7, 0.85, 0.6))
				if int(t / 0.07) != act.get("seg", -1):
					act["seg"] = int(t / 0.07)
					hit_list.clear()
				hit_rect(box(Vector2(10, -50), Vector2(80, 90)),
					{"dmg": 3.5, "base_kb": 120.0, "kb_scale": 1.0, "angle": 85.0, "special": true})
			else:
				if not act.has("fin"):
					act["fin"] = true
					velocity *= 0.25
					hit_list.clear()
					hit_rect(box(Vector2(20, -60), Vector2(100, 90)),
						{"dmg": 6.0, "base_kb": 330.0, "kb_scale": 7.0, "angle": 70.0, "special": true})
				anim_frame("upspecial", 2)
				apply_gravity(delta)
				air_drift(delta, 0.4)
			if t >= 0.42:
				end_action(true)
		"counter":
			anim_frame("downspecial", 0 if t < 0.6 else 3)
			_action_physics(delta)
			if t < 0.6 and Engine.get_physics_frames() % 6 == 0:
				Effects.ring(get_parent(), global_position + Vector2(0, -40), Color(1, 0.7, 0.85, 0.6), 40.0)
			if act.has("victim") and not act.has("struck"):
				act["struck"] = true
				anim_frame("smash", 2)
				var v: Fighter = act["victim"]
				Effects.swoosh(self, -80.0, 40.0, 90.0, Color(1, 0.8, 0.9), 0.3, 16.0)
				hit_list.clear()
				if is_instance_valid(v) and v.is_alive():
					v.hitlag = 0.0
					v.apply_hit(self, {"dmg": act["dmg"], "base_kb": 380.0, "kb_scale": 9.0, "angle": 40.0,
						"dir": facing, "pos": v.hurtbox().get_center(), "sfx": "hit_strong"})
			if t >= 0.9:
				end_action()
		"ult_cuts":
			velocity = Vector2.ZERO
			var stage := get_parent()
			if not act.has("start"):
				act["start"] = true
				vanished = true
				invincible_time = 2.0
				Game.play_sfx("slash", 0.0, 0.6)
				Effects.afterimage(stage, self, Color(1, 0.6, 0.8, 0.8))
				if stage.has_method("dim"):
					stage.dim(1.6, 0.5)
				var victims := []
				for e in enemies():
					if e.global_position.distance_to(global_position) < 1500.0:
						e.freeze(1.5)
						victims.append(e)
				act["victims"] = victims
			var cuts: int = act.get("cuts", 0)
			if cuts < 8 and t >= 0.25 + cuts * 0.1:
				act["cuts"] = cuts + 1
				for e in act["victims"]:
					if is_instance_valid(e) and e.is_alive():
						e.take_damage(3.0, self)
						var a := randf_range(0, 360)
						Effects.swoosh(e, a, a + 180.0, 80.0, Color(1, 0.75, 0.9), 0.2, 12.0)
						Effects.burst(stage, e.global_position + Vector2(0, -40), {"count": 8,
							"color": Color(1, 0.7, 0.85), "speed": 220.0, "life": 0.4, "size": 4.0, "star": true})
				Game.play_sfx("slash", -3.0, randf_range(0.9, 1.3))
			if t >= 1.2 and not act.has("final"):
				act["final"] = true
				vanished = false
				var tg := find_target()
				if tg:
					facing = 1 if tg.global_position.x > global_position.x else -1
					global_position = tg.global_position + Vector2(facing * 70.0, 0)
					facing = -facing
				anim_frame("smash", 3)
				for e in act["victims"]:
					if is_instance_valid(e) and e.is_alive():
						var d := 1 if e.global_position.x >= global_position.x else -1
						Effects.hit(stage, e.global_position + Vector2(0, -40), 2.2, Color(1, 0.7, 0.85), d)
						e.apply_hit(self, {"dmg": 18.0, "base_kb": 700.0, "kb_scale": 5.5, "angle": 45.0, "dir": d,
							"pos": e.global_position + Vector2(0, -40), "projectile": true, "sfx": "hit_strong"})
				hit_landed.emit(35.0)
			if t >= 1.6:
				end_action()
		_:
			super.char_action(action_name, t, delta)
