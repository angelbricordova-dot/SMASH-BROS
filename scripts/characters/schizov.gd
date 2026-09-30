extends Fighter
## SCHIZOV — tanque que pelea con un pez en la mano.
##  Especial (tocar G) ....... Revistas: lanza una revista que gira
##  Especial (mantener G) .... Montón de revistas: carga y lanza un abanico de 3 a 5 revistas
##  Arriba + Especial ........ Birrete volador: lanza el birrete hacia arriba y sube detrás golpeando
##  Abajo + Especial ......... En el suelo: Plano deslizante (se tira encima de un plano y se desliza)
##                             En el aire: Pez en picada (cae con el pez por delante: manda hacia abajo)
##  Ulti ..................... ¡Ya me cansé!: se enfada, va hacia el rival y le da una lluvia de
##                             cachetadas y un último pescadazo


func do_special() -> void:
	begin_action("magazine")


func do_charge_special() -> void:
	begin_action("magazines")


func do_up_special() -> void:
	begin_action("cap")


func do_down_special() -> void:
	begin_action("slide" if is_on_floor() else "fishdive")


func do_ultimate() -> void:
	begin_action("ult_slaps")


func _magazine(angle_deg: float, dmg: float, speed := 720.0) -> void:
	var a := deg_to_rad(angle_deg)
	var h := body_point("hands")
	spawn_projectile({"velocity": Vector2(cos(a) * facing, sin(a)) * speed + Vector2(0, -120), "gravity": 420.0,
		"radius": 15.0, "lifetime": 1.0, "sprite_scale": 1.3, "global_position": global_position + Vector2(h.x, h.y - 8.0),
		"trail": Color(1, 0.6, 0.75, 0.35),
		"info": {"dmg": dmg, "base_kb": 210.0, "kb_scale": 5.0, "angle": 40.0}})


func char_action(action_name: String, t: float, delta: float) -> void:
	match action_name:
		"magazine":
			anim_frame("special", 0 if t < 0.1 else (1 if t < 0.2 else (2 if t < 0.3 else 3)))
			if not act.has("fired") and t >= 0.14:
				act["fired"] = true
				_magazine(0.0, 6.0)
				Game.play_sfx("paper")
				Game.play_sfx("throw", -8.0)
			_action_physics(delta)
			if t >= 0.42:
				end_action()
		"magazines":
			_action_physics(delta)
			if hold_charge(t, 1.2):
				return
			var c: float = act["charge"]
			var rt: float = t - float(act["released"])
			anim_frame("charge", 2 if rt < 0.14 else 3)
			if not act.has("fired"):
				act["fired"] = true
				var n := 3 + int(round(2.0 * c))
				for i in n:
					_magazine(lerpf(-24.0, 18.0, float(i) / (n - 1)), 5.0 + 4.0 * c, 700.0 + 150.0 * c)
				Game.play_sfx("paper", 0.0, 0.8)
				Game.play_sfx("throw", -4.0)
			if rt >= 0.45:
				end_action()
		"cap":
			if t < 0.02:
				velocity = Vector2(facing * 110.0, -920.0 * mods["jump"])
				spawn_projectile({"velocity": Vector2(0, -1100.0), "gravity": 1200.0, "radius": 20.0, "lifetime": 0.7,
					"spin": 4.0, "sprite_scale": 1.3, "texture": preload("res://assets/sprites/prop_cap.png"), "hframes": 1, "global_position": global_position + Vector2(0, -100),
					"info": {"dmg": 5.0, "base_kb": 250.0, "kb_scale": 5.0, "angle": 85.0}})
				Game.play_sfx("throw", -2.0, 1.2)
			anim_frame("upspecial", mini(int(t / 0.12), 2))
			air_drift(delta, 0.5)
			apply_gravity(delta, 0.65)
			if t >= 0.05 and t < 0.32:
				hit_rect(box(Vector2(6, -80), Vector2(70, 70)), {"dmg": 8.0, "base_kb": 300.0, "kb_scale": 6.5,
					"angle": 85.0, "special": true, "sfx_hit": "slap"})
			if t >= 0.52:
				end_action(true)
		"slide":
			anim_frame("downspecial", 0 if t < 0.08 else (1 if t < 0.36 else 3))
			if t < 0.02:
				velocity.x = facing * 720.0
				Game.play_sfx("paper", -2.0, 0.7)
			velocity.x = move_toward(velocity.x, 0.0, 1150.0 * delta)
			velocity.y = 0.0 if is_on_floor() else velocity.y
			if not is_on_floor():
				apply_gravity(delta)
			if t >= 0.06 and t < 0.38:
				hit_rect(box(Vector2(40, -14), Vector2(90, 30)), {"dmg": 9.0, "base_kb": 270.0, "kb_scale": 6.5,
					"angle": 60.0, "special": true})
			if t >= 0.56:
				end_action()
		"fishdive":
			anim_frame("dair", 0 if t < 0.12 else 1)
			if t < 0.12:
				velocity *= 0.8
			else:
				velocity = Vector2(facing * 80.0, 1300.0)
				hit_rect(box(Vector2(10, 0), Vector2(56, 60)), {"dmg": 12.0, "base_kb": 250.0, "kb_scale": 7.0,
					"angle": -80.0, "special": true, "sfx_hit": "fish"})
				if Engine.get_physics_frames() % 2 == 0:
					Effects.burst(get_parent(), global_position + Vector2(0, 10), {"count": 2,
						"color": Color(0.6, 0.85, 1.0, 0.8), "speed": 80.0, "life": 0.4, "size": 4.0})
			if is_on_floor() and t > 0.12:
				hit_list.clear()
				hit_circle(global_position + Vector2(0, -16), 80.0, {"dmg": 6.0, "base_kb": 240.0, "kb_scale": 5.0,
					"angle": 70.0, "special": true})
				Effects.burst(get_parent(), global_position, {"count": 26, "color": Color(0.55, 0.8, 1.0, 0.9),
					"speed": 360.0, "life": 0.7, "size": 5.0, "gravity": 900.0, "angle": -90.0, "spread": 70.0})
				Effects.ring(get_parent(), global_position, Color(0.6, 0.85, 1.0), 90.0)
				Game.play_sfx("fish")
				end_action()
				landing_lag = 0.2
				return
			if t >= 1.1:
				end_action()
		"ult_slaps":
			var stage := get_parent()
			if not act.has("target"):
				act["target"] = find_target()
				Game.play_sfx("angry")
				Effects.popup(stage, global_position + Vector2(0, -190), "¡YA ME CANSÉ!", Color(1, 0.3, 0.3), 1.4)
				if stage.has_method("dim"):
					stage.dim(1.9, 0.5)
				var tg0: Fighter = act["target"]
				if tg0:
					tg0.freeze(1.9)
			var tg: Fighter = act["target"]
			var ok := tg != null and is_instance_valid(tg) and tg.is_alive()
			if t < 0.3:
				# se pone roja de rabia y va directa al rival
				anim_frame("ult", 0 if t < 0.15 else 1)
				tint = Color(1.6, 0.7, 0.7)
				if ok:
					facing = 1 if tg.global_position.x >= global_position.x else -1
					var goal := tg.global_position + Vector2(-facing * 52.0, 0)
					global_position = global_position.lerp(goal, minf(1.0, delta * 14.0))
					velocity = Vector2.ZERO
				if Engine.get_physics_frames() % 2 == 0:
					Effects.afterimage(stage, self, Color(1, 0.4, 0.4, 0.5))
				return
			velocity = Vector2.ZERO
			var n: int = act.get("n", 0)
			if n < 8 and t >= 0.3 + n * 0.1:
				act["n"] = n + 1
				tint = Color(1.4, 0.8, 0.8)
				anim_frame(["jab1", "jab2", "ult"][n % 3], 1 if n % 3 < 2 else 2)
				if ok:
					tg.take_damage(3.5, self)
					tg.hit_flash = 0.08
					var p := tg.global_position + Vector2(randf_range(-10, 10), -60 + randf_range(-10, 10))
					Effects.popup(stage, p + Vector2(0, -30), ["¡PLAF!", "¡ZAS!", "¡PAF!"].pick_random(),
						Color(1, 0.5, 0.5), 0.7)
					Effects.spark(stage, p, 0.6, Color(1, 0.6, 0.6))
					Game.play_sfx("slap", 0.0, randf_range(0.85, 1.2))
					hit_landed.emit(4.0)
			if t >= 1.2 and not act.has("final"):
				act["final"] = true
				anim_frame("smash", 2)
				if ok:
					tg.invincible_time = 0.0
					tg.state = State.NORMAL
					var p := tg.global_position + Vector2(0, -44)
					Effects.hit(stage, p, 2.2, Color(0.6, 0.85, 1.0), facing)
					tg.apply_hit(self, {"dmg": 12.0, "base_kb": 640.0, "kb_scale": 5.5, "angle": 38.0, "dir": facing,
						"pos": p, "projectile": true, "sfx": "fish"})
					hit_landed.emit(30.0)
			if t >= 1.55:
				tint = Color.WHITE
				end_action()
		_:
			super.char_action(action_name, t, delta)
