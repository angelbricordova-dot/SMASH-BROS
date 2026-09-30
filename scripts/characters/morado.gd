extends Fighter
## UMBRA — espectro de las sombras (inspirado en Omen de Valorant).
##  Especial (tocar G) ....... Paranoia (orbe lento que atraviesa y golpea a todos)
##  Especial (mantener G) .... Paranoia doble (hasta 3 orbes más grandes)
##  Arriba + Especial ........ Paso sombrío (se desvanece y reaparece donde apuntes)
##  Abajo + Especial ......... Trampa de sombra (el que la pise queda atrapado)
##  Ulti ..................... Desde las Sombras: oscurece el mundo, aparece a la ESPALDA del rival
##                             y lo destroza con 6 cortes (más de 50% de daño y un golpe final brutal)

const STEP_DISTANCE := 290.0
var _trap: Node2D = null


func do_special() -> void:
	begin_action("paranoia")


func do_charge_special() -> void:
	begin_action("charge_paranoia")


func do_up_special() -> void:
	begin_action("step")


func do_down_special() -> void:
	begin_action("trap")


func do_ultimate() -> void:
	begin_action("ult_shadow")


func _orb(offset_y: float, r: float, c: float) -> void:
	spawn_projectile({"velocity": Vector2(facing * 420.0, offset_y * 1.2), "radius": r,
		"global_position": global_position + Vector2(facing * 40, -48 + offset_y * 0.3), "sprite_scale": r / 14.0,
		"lifetime": 1.8, "pierce": true, "trail": Color(0.4, 0.15, 0.6, 0.6),
		"info": {"dmg": 8.0 + 6.0 * c, "base_kb": 280.0, "kb_scale": 6.5, "angle": 38.0, "fx": "shadow"}})


func char_action(action_name: String, t: float, delta: float) -> void:
	match action_name:
		"paranoia":
			anim_frame("special", mini(int(t / 0.1), 3))
			if not act.has("fired") and t >= 0.25:
				act["fired"] = true
				_orb(0.0, 20.0, 0.0)
				Game.play_sfx("shadow", -3.0)
			_action_physics(delta)
			if t >= 0.55:
				end_action()
		"charge_paranoia":
			_action_physics(delta)
			if hold_charge(t, 1.0):
				return
			var c: float = act["charge"]
			var rt: float = t - float(act["released"])
			anim_frame("charge", 2 if rt < 0.12 else 3)
			if not act.has("fired"):
				act["fired"] = true
				var n := 1 + int(2.0 * c)
				for i in n:
					_orb(0.0 if n == 1 else lerpf(-60.0, 60.0, float(i) / (n - 1)), 20.0 + 10.0 * c, c)
				Game.play_sfx("shadow", 0.0)
			if rt >= 0.35:
				end_action()
		"step":
			velocity = Vector2.ZERO
			if not act.has("vanish"):
				act["vanish"] = true
				vanished = true
				intangible_time = maxf(intangible_time, 0.45)
				Game.play_sfx("teleport")
				Effects.smoke(get_parent(), global_position)
			if t >= 0.28 and not act.has("moved"):
				act["moved"] = true
				var d := input_dir(Vector2.UP)
				if absf(d.x) > 0.1:
					facing = 1 if d.x > 0.0 else -1
				move_and_collide(d * STEP_DISTANCE)
				vanished = false
				floor_snap_length = 0.0
				Effects.smoke(get_parent(), global_position)
			if t >= 0.42:
				end_action(true)
		"trap":
			anim_frame("downspecial", mini(int(t / 0.08), 3))
			_action_physics(delta)
			if not act.has("placed") and t >= 0.2:
				act["placed"] = true
				if _trap and is_instance_valid(_trap):
					_trap.queue_free()
				_trap = ShadowTrap.new()
				_trap.owner_fighter = self
				var pos := global_position + Vector2(facing * 70, 0)
				var q := PhysicsRayQueryParameters2D.create(pos + Vector2(0, -60), pos + Vector2(0, 600), 3)
				var hit := get_world_2d().direct_space_state.intersect_ray(q)
				_trap.position = hit["position"] if hit else pos
				get_parent().add_child(_trap)
				Game.play_sfx("shadow", -6.0, 1.3)
			if t >= 0.4:
				end_action()
		"ult_shadow":
			velocity = Vector2.ZERO
			var stage := get_parent()
			if not act.has("vanish"):
				act["vanish"] = true
				vanished = true
				invincible_time = maxf(invincible_time, 2.2)
				Game.play_sfx("shadow")
				Effects.smoke(stage, global_position)
				if stage.has_method("dim"):
					stage.dim(2.0, 0.75)
				act["target"] = find_target()
				var tg0: Fighter = act["target"]
				if tg0:
					tg0.freeze(1.6)   # el rival queda paralizado por el miedo
			var tg: Fighter = act.get("target")
			if t >= 0.6 and not act.has("appear"):
				act["appear"] = true
				if tg and is_instance_valid(tg) and tg.is_alive():
					facing = tg.facing
					global_position = tg.global_position + Vector2(-tg.facing * 58.0, 0)
				else:
					global_position = Vector2(0, stage_info["ground_y"] - 1.0)
					tg = null
					act["target"] = null
				vanished = false
				Effects.smoke(stage, global_position)
				Game.play_sfx("teleport", 0.0, 0.7)
			if act.has("appear"):
				var cuts: int = act.get("cuts", 0)
				# 6 cortes rápidos
				if cuts < 6 and t >= 0.7 + cuts * 0.09:
					act["cuts"] = cuts + 1
					anim_frame(["jab1", "jab2", "ftilt", "fair", "utilt", "bair"][cuts], 1)
					if tg and is_instance_valid(tg) and tg.is_alive():
						tg.take_damage(6.0, self)
						var p := tg.global_position + Vector2(0, -40)
						var a := randf_range(0, 360)
						Effects.swoosh(tg, a, a + 160.0, 60.0, Color(0.8, 0.4, 1.0), 0.2, 12.0)
						Effects.burst(stage, p, {"count": 10, "color": Color(0.6, 0.2, 0.9), "speed": 260.0,
							"life": 0.3, "size": 4.0, "streak": true})
						Game.play_sfx("slash", -2.0, randf_range(0.8, 1.2))
						hit_landed.emit(6.0)
				# golpe final
				if t >= 1.35 and not act.has("final"):
					act["final"] = true
					anim_frame("smash", 2)
					if tg and is_instance_valid(tg) and tg.is_alive():
						tg.invincible_time = 0.0
						var p := tg.global_position + Vector2(0, -40)
						Effects.explosion(stage, p, 110.0, Color(0.55, 0.2, 0.9))
						Effects.hit(stage, p, 2.5, Color(0.8, 0.4, 1.0), facing)
						tg.apply_hit(self, {"dmg": 20.0, "base_kb": 820.0, "kb_scale": 6.0, "angle": 40.0, "dir": facing,
							"pos": p, "projectile": true, "fx": "shadow", "sfx": "hit_strong"})
						Game.play_sfx("explosion")
						hit_landed.emit(45.0)
						if stage.has_method("slowmo"):
							stage.slowmo(0.5, 0.3)
			if t >= 1.7:
				end_action()
		_:
			super.char_action(action_name, t, delta)


## Trampa de sombra: atrapa (congela) al primer rival que la pise.
class ShadowTrap extends Node2D:
	var owner_fighter: Fighter
	var _t := 0.0

	func _ready() -> void:
		z_index = -1

	func _physics_process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t > 10.0 or not is_instance_valid(owner_fighter):
			queue_free()
			return
		if _t < 0.4:
			return
		for f in get_tree().get_nodes_in_group("fighters"):
			if f == owner_fighter or not f.is_alive():
				continue
			if absf(f.global_position.x - global_position.x) < 40.0 and absf(f.global_position.y - global_position.y) < 30.0:
				f.take_damage(6.0, owner_fighter)
				f.freeze(1.1)
				Game.play_sfx("shadow", 0.0, 1.4)
				Effects.burst(get_parent(), global_position + Vector2(0, -30), {"count": 20,
					"color": Color(0.5, 0.2, 0.8), "speed": 200.0, "life": 0.6, "size": 5.0, "gravity": -100.0})
				queue_free()
				return

	func _draw() -> void:
		var a := minf(1.0, _t * 3.0)
		var pulse := 0.5 + 0.5 * sin(_t * 5.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1, 0.3))
		draw_circle(Vector2.ZERO, 38.0, Color(0.15, 0.05, 0.25, 0.7 * a))
		draw_arc(Vector2.ZERO, 38.0, 0, TAU, 32, Color(0.7, 0.4, 1.0, (0.5 + 0.4 * pulse) * a), 3.0)
		for i in 5:
			var ang := _t * 2.0 + i * TAU / 5.0
			draw_circle(Vector2(cos(ang), sin(ang)) * 26.0, 3.0, Color(0.8, 0.5, 1.0, a))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
