extends Fighter
## BRUMA — bruja de la niebla.
##  Especial (tocar G) ....... Estrella mágica (persigue al rival)
##  Especial (mantener G) .... Meteorito (cae del cielo delante de ti; más grande según la carga)
##  Arriba + Especial ........ Escoba voladora (vuela un momento hacia donde apuntes)
##  Abajo + Especial ......... Círculo de runas (zona mágica que golpea y levanta a los rivales)
##  Ulti ..................... Lluvia de Meteoros

const MINT := Color(0.55, 1.0, 0.85)


func do_special() -> void:
	begin_action("star")


func do_charge_special() -> void:
	begin_action("charge_meteor")


func do_up_special() -> void:
	begin_action("broom")


func do_down_special() -> void:
	begin_action("runes")


func do_ultimate() -> void:
	begin_action("ult_meteors")


func _meteor(target_x: float, top_y: float, r: float, dmg: float) -> void:
	var tex: Texture2D = load("res://assets/sprites/proj_rojo.png")
	spawn_projectile({"velocity": Vector2(facing * 180.0, 760.0), "radius": r, "lifetime": 2.5,
		"texture": tex, "sprite_scale": r / 12.0, "solid": true, "explode_radius": r * 4.0,
		"global_position": Vector2(target_x - facing * 120.0, top_y), "trail": Color(1, 0.6, 0.3, 0.6),
		"info": {"dmg": dmg, "base_kb": 300.0, "kb_scale": 7.0, "angle": 60.0, "fx": "fire"}})


func char_action(action_name: String, t: float, delta: float) -> void:
	match action_name:
		"star":
			anim_frame("special", mini(int(t / 0.08), 3))
			if not act.has("fired") and t >= 0.18:
				act["fired"] = true
				spawn_projectile({"velocity": Vector2(facing * 460.0, -40.0), "radius": 14.0, "lifetime": 1.8,
					"homing": 2.2, "spin": 6.0, "global_position": global_position + Vector2(facing * 50, -60),
					"info": {"dmg": 7.0, "base_kb": 240.0, "kb_scale": 5.5, "angle": 40.0, "fx": "magic"}})
				Game.play_sfx("magic")
			_action_physics(delta)
			if t >= 0.4:
				end_action()
		"charge_meteor":
			_action_physics(delta)
			if hold_charge(t, 1.0):
				return
			var c: float = act["charge"]
			var rt: float = t - float(act["released"])
			anim_frame("charge", 2 if rt < 0.15 else 3)
			if not act.has("fired"):
				act["fired"] = true
				_meteor(global_position.x + facing * (160.0 + 260.0 * c), global_position.y - 620.0, 14.0 + 14.0 * c,
					10.0 + 12.0 * c)
				Game.play_sfx("magic", 0.0, 0.8)
			if rt >= 0.35:
				end_action()
		"broom":
			anim_frame("upspecial", 1)
			if t < delta * 1.5:
				floor_snap_length = 0.0
				Game.play_sfx("magic", -4.0, 1.2)
			if t < 0.8:
				var d := input_dir(Vector2(0.4 * facing, -1.0).normalized())
				if d.y > 0.2:
					d.y = -0.2
				velocity = velocity.lerp(d.normalized() * 520.0, 8.0 * delta)
				if absf(d.x) > 0.2:
					facing = 1 if d.x > 0.0 else -1
				if Engine.get_physics_frames() % 2 == 0:
					Effects.burst(get_parent(), global_position + Vector2(0, -20), {"count": 2, "color": MINT,
						"speed": 40.0, "life": 0.5, "size": 3.0, "star": true})
			else:
				apply_gravity(delta)
				air_drift(delta, 0.5)
			if t >= 0.9:
				end_action(true)
		"runes":
			anim_frame("downspecial", mini(int(t / 0.1), 3))
			_action_physics(delta)
			if not act.has("placed") and t >= 0.2:
				act["placed"] = true
				var field := RuneField.new()
				field.owner_fighter = self
				field.position = global_position
				get_parent().add_child(field)
				Game.play_sfx("magic", -2.0, 0.7)
			if t >= 0.45:
				end_action()
		"ult_meteors":
			anim_frame("ult", 1 if t < 2.6 else 3)
			_action_physics(delta)
			var stage := get_parent()
			if not act.has("start"):
				act["start"] = true
				if stage.has_method("dim"):
					stage.dim(2.8, 0.6)
			var n: int = act.get("n", 0)
			if n < 14 and t >= 0.3 + n * 0.16:
				act["n"] = n + 1
				var tg := find_target()
				var cx := tg.global_position.x if tg else global_position.x
				_meteor(cx + randf_range(-170.0, 170.0), global_position.y - 800.0, 18.0, 7.0)
			if t >= 2.9:
				end_action()
		_:
			super.char_action(action_name, t, delta)


## Círculo de runas: golpea poco a poco y levanta a los rivales que estén encima.
class RuneField extends Node2D:
	var owner_fighter: Fighter
	var _t := 0.0
	var _next := 0.3

	func _ready() -> void:
		z_index = -1
		Effects.rune_circle(self, Vector2.ZERO, 95.0, Color(0.55, 1.0, 0.85), 2.6)

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t > 2.6 or not is_instance_valid(owner_fighter):
			queue_free()
			return
		if _t >= _next:
			_next += 0.3
			for f in get_tree().get_nodes_in_group("fighters"):
				if f == owner_fighter or not f.is_alive():
					continue
				if absf(f.global_position.x - global_position.x) < 95.0 and absf(f.global_position.y - global_position.y) < 60.0:
					f.apply_hit(owner_fighter, {"dmg": 2.5, "base_kb": 260.0, "kb_scale": 0.8, "angle": 88.0,
						"dir": 1, "pos": f.hurtbox().get_center(), "projectile": true, "fx": "magic"})
