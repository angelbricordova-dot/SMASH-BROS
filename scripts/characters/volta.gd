extends Fighter
## VOLTA — velocista eléctrico.
##  Especial (tocar G) ....... Chispa (rayo rápido)
##  Especial (mantener G) .... Sobrecarga (explosión eléctrica alrededor; más grande según la carga)
##  Arriba + Especial ........ Relámpago (dos zigzags veloces en la dirección que apuntes)
##  Abajo + Especial ......... Trueno (un rayo cae del cielo sobre ti y electrocuta a los cercanos)
##  Ulti ..................... Tormenta Eléctrica (rayos caen sobre los rivales una y otra vez)

const YELLOW := Color(1, 0.95, 0.4)


func do_special() -> void:
	begin_action("spark")


func do_charge_special() -> void:
	begin_action("charge_overload")


func do_up_special() -> void:
	begin_action("zip")


func do_down_special() -> void:
	begin_action("thunder")


func do_ultimate() -> void:
	begin_action("ult_storm")


func _strike(pos: Vector2, radius: float, m: Dictionary) -> void:
	Effects.lightning(get_parent(), pos + Vector2(randf_range(-40, 40), -900), pos, YELLOW, 0.25)
	Effects.lightning(get_parent(), pos + Vector2(randf_range(-40, 40), -900), pos, Color(1, 1, 1), 0.15)
	Effects.explosion(get_parent(), pos, radius * 0.8, YELLOW)
	Game.play_sfx("thunder", -2.0)
	hit_list.clear()
	hit_circle(pos + Vector2(0, -30), radius, m)


func char_action(action_name: String, t: float, delta: float) -> void:
	match action_name:
		"spark":
			anim_frame("special", mini(int(t / 0.05), 3))
			if not act.has("fired") and t >= 0.08:
				act["fired"] = true
				spawn_projectile({"velocity": Vector2(facing * 1150.0, 0), "radius": 12.0, "lifetime": 0.4,
					"global_position": global_position + Vector2(facing * 40, -48),
					"info": {"dmg": 5.0, "base_kb": 200.0, "kb_scale": 4.0, "angle": 25.0, "fx": "elec"}})
				Game.play_sfx("zap", -2.0)
			_action_physics(delta)
			if t >= 0.25:
				end_action()
		"charge_overload":
			_action_physics(delta)
			if Engine.get_physics_frames() % 4 == 0 and not act.has("released"):
				var a := randf() * TAU
				Effects.lightning(get_parent(), global_position + Vector2(0, -40),
					global_position + Vector2(0, -40) + Vector2(cos(a), sin(a)) * 60.0, YELLOW, 0.1)
			if hold_charge(t, 1.0):
				return
			var c: float = act["charge"]
			var rt: float = t - float(act["released"])
			anim_frame("charge", 2 if rt < 0.15 else 3)
			if not act.has("boom"):
				act["boom"] = true
				var r := 70.0 + 90.0 * c
				Effects.explosion(get_parent(), global_position + Vector2(0, -40), r, YELLOW)
				for i in 8:
					var a := i * TAU / 8.0
					Effects.lightning(get_parent(), global_position + Vector2(0, -40),
						global_position + Vector2(0, -40) + Vector2(cos(a), sin(a)) * r, YELLOW, 0.25)
				Game.play_sfx("thunder", -4.0, 1.4)
				hit_circle(global_position + Vector2(0, -40), r, {"dmg": 8.0 + 10.0 * c, "base_kb": 300.0,
					"kb_scale": 7.0 + 3.0 * c, "angle": 60.0, "fx": "elec", "special": true})
				hit_landed.emit(6.0 + 10.0 * c)
			if rt >= 0.35:
				end_action()
		"zip":
			var seg := 0 if t < 0.22 else 1
			if t < 0.05:
				anim_frame("upspecial", 0)
				velocity = Vector2.ZERO
				return
			if not act.has("d%d" % seg):
				var d := input_dir(Vector2.UP)
				act["d%d" % seg] = d
				hit_list.clear()
				if absf(d.x) > 0.1:
					facing = 1 if d.x > 0.0 else -1
				floor_snap_length = 0.0
				Game.play_sfx("zap", 0.0, 1.2)
			var dir: Vector2 = act["d%d" % seg]
			var st := 0.05 if seg == 0 else 0.22
			if t - st < 0.13:
				anim_frame("upspecial", 1)
				vanished = true
				velocity = dir * 1500.0
				intangible_time = maxf(intangible_time, 0.03)
				Effects.lightning(get_parent(), global_position + Vector2(0, -40) - dir * 40.0,
					global_position + Vector2(0, -40), YELLOW, 0.2)
				hit_rect(box(Vector2(0, -40), Vector2(60, 80)), {"dmg": 5.0, "base_kb": 260.0, "kb_scale": 5.0,
					"angle": 75.0, "fx": "elec", "special": true})
			else:
				vanished = false
				velocity *= 0.2
			if t >= 0.4:
				vanished = false
				end_action(true)
		"thunder":
			anim_frame("downspecial", 0 if t < 0.3 else 2)
			_action_physics(delta)
			if not act.has("bolt") and t >= 0.3:
				act["bolt"] = true
				_strike(global_position, 80.0, {"dmg": 12.0, "base_kb": 330.0, "kb_scale": 8.0, "angle": 80.0,
					"fx": "elec", "special": true})
				hit_landed.emit(10.0)
			if t >= 0.6:
				end_action()
		"ult_storm":
			velocity = Vector2.ZERO
			anim_frame("ult", 1 if t < 2.3 else 3)
			var stage := get_parent()
			if not act.has("start"):
				act["start"] = true
				if stage.has_method("dim"):
					stage.dim(2.6, 0.55)
			var n: int = act.get("n", 0)
			if n < 7 and t >= 0.4 + n * 0.3:
				act["n"] = n + 1
				var tg := find_target()
				if tg:
					var final := n == 6
					_strike(tg.global_position, 90.0 if final else 70.0, {"dmg": 15.0 if final else 6.0,
						"base_kb": 650.0 if final else 120.0, "kb_scale": 6.0 if final else 1.0,
						"angle": 80.0, "fx": "elec"})
					hit_landed.emit(30.0 if final else 8.0)
			if t >= 2.6:
				end_action()
		_:
			super.char_action(action_name, t, delta)
