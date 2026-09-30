extends Fighter
## NOVA — robot explorador.
##  Especial (tocar G) ....... Blaster (láser rápido)
##  Especial (mantener G) .... Cañón de plasma (bola enorme según la carga; explota a carga máxima)
##  Arriba + Especial ........ Jetpack (vuela hacia arriba, puedes moverte a los lados)
##  Abajo + Especial ......... Mina (explota cuando un rival se acerca)
##  Ulti ..................... Láser Orbital (un láser desde el espacio persigue al rival)

var _mine: Node2D = null


func do_special() -> void:
	begin_action("blaster")


func do_charge_special() -> void:
	begin_action("charge_plasma")


func do_up_special() -> void:
	begin_action("jetpack")


func do_down_special() -> void:
	begin_action("mine")


func do_ultimate() -> void:
	begin_action("ult_orbital")


func char_action(action_name: String, t: float, delta: float) -> void:
	match action_name:
		"blaster":
			anim_frame("special", 2 if t < 0.12 else 3)
			if not act.has("fired") and t >= 0.06:
				act["fired"] = true
				spawn_projectile({"velocity": Vector2(facing * 1300.0, 0), "radius": 9.0, "lifetime": 0.5,
					"global_position": global_position + Vector2(facing * 44, -50), "sprite_scale": 0.9,
					"info": {"dmg": 4.0, "base_kb": 150.0, "kb_scale": 3.0, "angle": 20.0}})
				Game.play_sfx("laser", -2.0)
			_action_physics(delta)
			if t >= 0.22:
				end_action()
		"charge_plasma":
			_action_physics(delta)
			if hold_charge(t, 1.2):
				return
			var c: float = act["charge"]
			var rt: float = t - float(act["released"])
			anim_frame("charge", 2 if rt < 0.12 else 3)
			if not act.has("fired"):
				act["fired"] = true
				spawn_projectile({"velocity": Vector2(facing * (650.0 + 250.0 * c), 0), "radius": 12.0 + 22.0 * c,
					"lifetime": 1.5, "global_position": global_position + Vector2(facing * 48, -50),
					"explode_radius": 100.0 if c >= 1.0 else 0.0, "trail": Color(0.4, 0.95, 1.0, 0.5),
					"info": {"dmg": 6.0 + 18.0 * c, "base_kb": 250.0 + 300.0 * c, "kb_scale": 5.0 + 4.0 * c,
						"angle": 35.0, "fx": "elec"}})
				Game.play_sfx("laser_big", -2.0, 1.4 - 0.4 * c)
				velocity.x -= facing * 200.0 * c
			if rt >= 0.3:
				end_action()
		"jetpack":
			anim_frame("upspecial", 1)
			if t < delta * 1.5:
				floor_snap_length = 0.0
				Game.play_sfx("hover")
			if t < 0.85:
				velocity.y = move_toward(velocity.y, -560.0, 3000.0 * delta)
				velocity.x = move_toward(velocity.x, in_move * 320.0, 1500.0 * delta)
				if Engine.get_physics_frames() % 2 == 0:
					Effects.burst(get_parent(), global_position + Vector2(-facing * 14, -30), {"count": 3,
						"color": Color(1, 0.6, 0.2), "speed": 200.0, "life": 0.3, "size": 5.0, "angle": 90.0,
						"spread": 20.0})
				hit_rect(box(Vector2(-8, 10), Vector2(40, 40)), {"dmg": 2.0, "base_kb": 100.0, "kb_scale": 1.0,
					"angle": -80.0, "fx": "fire", "special": true})
				if Engine.get_physics_frames() % 8 == 0:
					hit_list.clear()
				if Engine.get_physics_frames() % 12 == 0:
					Game.play_sfx("hover", -10.0)
			else:
				apply_gravity(delta)
				air_drift(delta, 0.4)
			if t >= 0.95:
				end_action(true)
		"mine":
			anim_frame("downspecial", mini(int(t / 0.08), 3))
			_action_physics(delta)
			if not act.has("placed") and t >= 0.2:
				act["placed"] = true
				if _mine and is_instance_valid(_mine):
					_mine.queue_free()
				_mine = Mine.new()
				_mine.owner_fighter = self
				var pos := global_position + Vector2(facing * 30, 0)
				var q := PhysicsRayQueryParameters2D.create(pos + Vector2(0, -60), pos + Vector2(0, 700), 3)
				var hit := get_world_2d().direct_space_state.intersect_ray(q)
				_mine.position = hit["position"] if hit else pos
				get_parent().add_child(_mine)
				Game.play_sfx("pickup", -6.0, 0.7)
			if t >= 0.4:
				end_action()
		"ult_orbital":
			anim_frame("ult", 1 if t < 2.6 else 3)
			_action_physics(delta)
			var stage := get_parent()
			var tg := find_target()
			if not act.has("aim"):
				act["aim"] = tg.global_position if tg else global_position
				if stage.has_method("dim"):
					stage.dim(2.8, 0.5)
			var aim: Vector2 = act["aim"]
			if tg:
				aim = aim.move_toward(tg.global_position, (380.0 if t > 0.8 else 900.0) * delta)
			act["aim"] = aim
			if t < 0.8:
				if Engine.get_physics_frames() % 4 == 0:
					Effects.ring(stage, aim + Vector2(0, -30), Color(1, 0.3, 0.2), 60.0)
				return
			if not act.has("beam"):
				act["beam"] = true
				Game.play_sfx("laser_big")
				act["beam_fx"] = null
			if Engine.get_physics_frames() % 3 == 0 and t < 2.4:
				Effects.vbeam(stage, aim, 40.0, Color(0.4, 0.95, 1.0), 0.12)
			var ticks: int = act.get("ticks", 0)
			if t < 2.4 and t >= 0.8 + ticks * 0.15:
				act["ticks"] = ticks + 1
				hit_list.clear()
				hit_rect(Rect2(aim.x - 45.0, aim.y - 900.0, 90.0, 920.0), {"dmg": 2.5, "base_kb": 40.0,
					"kb_scale": 0.3, "angle": 90.0, "fx": "elec"})
				if ticks % 3 == 0:
					Game.play_sfx("zap", -8.0)
					hit_landed.emit(4.0)
			if t >= 2.4 and not act.has("final"):
				act["final"] = true
				Effects.vbeam(stage, aim, 110.0, Color(0.5, 1.0, 1.0), 0.5)
				Effects.explosion(stage, aim + Vector2(0, -30), 150.0, Color(0.4, 0.95, 1.0))
				Game.play_sfx("explosion")
				hit_list.clear()
				hit_rect(Rect2(aim.x - 110.0, aim.y - 900.0, 220.0, 940.0), {"dmg": 14.0, "base_kb": 720.0,
					"kb_scale": 5.0, "angle": 85.0, "fx": "elec"})
				hit_landed.emit(40.0)
			if t >= 2.8:
				end_action()
		_:
			super.char_action(action_name, t, delta)


## Mina de proximidad.
class Mine extends Node2D:
	var owner_fighter: Fighter
	var _t := 0.0

	func _physics_process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t > 15.0 or not is_instance_valid(owner_fighter):
			queue_free()
			return
		if _t < 0.6:
			return
		for f in get_tree().get_nodes_in_group("fighters"):
			if f == owner_fighter or not f.is_alive():
				continue
			if f.global_position.distance_to(global_position) < 60.0:
				Effects.explosion(get_parent(), global_position + Vector2(0, -16), 90.0, Color(1, 0.6, 0.2))
				Game.play_sfx("explosion")
				for g in get_tree().get_nodes_in_group("fighters"):
					if g.is_alive() and Projectile.circle_hits_rect(global_position + Vector2(0, -16), 90.0, g.hurtbox()):
						g.apply_hit(owner_fighter if g != owner_fighter else null, {"dmg": 14.0, "base_kb": 380.0,
							"kb_scale": 8.0, "angle": 70.0, "dir": 1 if g.global_position.x >= global_position.x else -1,
							"pos": g.hurtbox().get_center(), "projectile": true, "sfx": "hit_strong"})
				queue_free()
				return

	func _draw() -> void:
		draw_rect(Rect2(-14, -8, 28, 8), Color(0.3, 0.32, 0.4))
		draw_rect(Rect2(-10, -12, 20, 4), Color(0.45, 0.48, 0.56))
		var on := _t > 0.6 and fmod(_t, 0.6) < 0.3
		draw_circle(Vector2(0, -12), 3.5, Color(1, 0.2, 0.2) if on else Color(0.4, 0.1, 0.1))
		if on:
			draw_circle(Vector2(0, -12), 9.0, Color(1, 0.2, 0.2, 0.25))
