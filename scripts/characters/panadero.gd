extends Fighter
## PANADERO — tanque: lento, pesado y con golpes que duelen.
##  Especial (tocar G) ....... Harina: lanza un puñado de harina (una nube que golpea varias veces)
##  Especial (mantener G) .... Baguette gigante: carga y lanza una baguette que gira
##  Arriba + Especial ........ Explosión de harina: una nube de harina lo impulsa hacia arriba
##  Abajo + Especial ......... En el suelo: Masa pegajosa (una masa de levadura que atrapa al que la pisa)
##                             En el aire: Panzazo (cae en picada con la barriga y hace temblar el suelo)
##  Ulti ..................... Panadero Real: se convierte en un panadero de verdad (gorro y filipina) y
##                             durante 7 s lanza panes a diestra y siniestra, con súper armadura

const BAKER_TIME := 7.0
const BREADS := [preload("res://assets/sprites/prop_baguette.png"), preload("res://assets/sprites/prop_croissant.png"),
	preload("res://assets/sprites/prop_loaf.png")]
var baker_t := 0.0
var _bread_cd := 0.0
var _trap: Node2D = null


func do_special() -> void:
	begin_action("flour")


func do_charge_special() -> void:
	begin_action("baguette")


func do_up_special() -> void:
	begin_action("flour_jump")


func do_down_special() -> void:
	begin_action("dough" if is_on_floor() else "bellyflop")


func do_ultimate() -> void:
	begin_action("ult_baker")


func char_tick(delta: float) -> void:
	if baker_t <= 0.0:
		return
	baker_t -= delta
	armor_time = maxf(armor_time, 0.1)
	_bread_cd -= delta
	if _bread_cd <= 0.0 and is_alive() and state != State.FROZEN:
		_bread_cd = 0.13
		_throw_bread()
	if baker_t <= 0.0:
		set_form("")
		Effects.smoke(get_parent(), global_position, Color(1, 1, 1))


func kill() -> void:
	baker_t = 0.0
	set_form("")
	super.kill()


## Un pan volando en arco hacia cualquier lado.
func _throw_bread() -> void:
	var side := 1.0 if randf() < 0.5 else -1.0
	var i := randi() % BREADS.size()
	spawn_projectile({"texture": BREADS[i], "hframes": 1, "radius": 16.0, "lifetime": 1.8, "solid": true,
		"sprite_scale": [0.55, 0.9, 0.8][i], "spin": 2.5, "gravity": 1300.0,
		"velocity": Vector2(side * randf_range(260.0, 820.0), -randf_range(420.0, 950.0)),
		"global_position": global_position + Vector2(side * 16.0, -80.0), "trail": Color(1, 0.85, 0.5, 0.3),
		"info": {"dmg": 5.0, "base_kb": 210.0, "kb_scale": 4.0, "angle": 50.0}})
	if randf() < 0.35:
		Game.play_sfx("throw", -10.0, randf_range(0.9, 1.2))


func char_action(action_name: String, t: float, delta: float) -> void:
	match action_name:
		"flour":
			anim_frame("special", 0 if t < 0.1 else (1 if t < 0.2 else (2 if t < 0.3 else 3)))
			if not act.has("fired") and t >= 0.14:
				act["fired"] = true
				var h := body_point("hands")
				var p := global_position + Vector2(h.x, h.y)
				for i in 3:
					var a := deg_to_rad(-14.0 + i * 14.0)
					spawn_projectile({"velocity": Vector2(cos(a) * facing, sin(a)) * randf_range(380.0, 470.0),
						"radius": 26.0, "lifetime": 0.45, "global_position": p, "sprite_scale": 1.8,
						"pierce": true, "trail": Color(1, 1, 1, 0.25),
						"info": {"dmg": 3.5, "base_kb": 150.0 if i == 1 else 70.0, "kb_scale": 3.0 if i == 1 else 0.5,
							"angle": 40.0}})
				Effects.burst(get_parent(), p, {"count": 22, "color": Color(1, 1, 0.97, 0.8), "speed": 330.0,
					"life": 0.6, "size": 7.0, "grow": true, "angle": 0.0 if facing > 0 else 180.0, "spread": 30.0})
				Game.play_sfx("flour")
			_action_physics(delta)
			if t >= 0.5:
				end_action()
		"baguette":
			_action_physics(delta)
			if hold_charge(t, 1.2):
				return
			var c: float = act["charge"]
			var rt: float = t - float(act["released"])
			anim_frame("charge", 2 if rt < 0.14 else 3)
			if not act.has("fired"):
				act["fired"] = true
				spawn_projectile({"texture": BREADS[0], "hframes": 1, "radius": 18.0 + 12.0 * c, "lifetime": 1.3,
					"sprite_scale": 0.6 + 0.5 * c, "spin": 3.0, "gravity": 350.0,
					"velocity": Vector2(facing * (640.0 + 320.0 * c), -160.0),
					"global_position": global_position + Vector2(facing * 40, -60), "trail": Color(1, 0.8, 0.45, 0.4),
					"info": {"dmg": 8.0 + 14.0 * c, "base_kb": 260.0 + 300.0 * c, "kb_scale": 6.0 + 4.0 * c,
						"angle": 35.0, "sfx": "hit_strong" if c > 0.6 else ""}})
				Game.play_sfx("swing_heavy", 0.0, 0.8)
				Game.play_sfx("bread", -4.0)
			if rt >= 0.4:
				end_action()
		"flour_jump":
			if t < 0.02:
				velocity = Vector2(facing * 90.0, -980.0 * mods["jump"])
				var p := global_position + Vector2(0, -6)
				Effects.burst(get_parent(), p, {"count": 30, "color": Color(1, 1, 0.97, 0.85), "speed": 300.0,
					"life": 0.8, "size": 10.0, "grow": true, "angle": 90.0, "spread": 70.0})
				Effects.ring(get_parent(), p, Color(1, 1, 1), 80.0)
				hit_circle(p + Vector2(0, 20), 70.0, {"dmg": 7.0, "base_kb": 260.0, "kb_scale": 5.5, "angle": 60.0,
					"special": true})
				Game.play_sfx("flour", 0.0, 0.8)
				Game.play_sfx("explosion", -10.0, 1.4)
			anim_frame("upspecial", mini(int(t / 0.12), 2))
			air_drift(delta, 0.5)
			apply_gravity(delta, 0.65)
			if Engine.get_physics_frames() % 3 == 0:
				Effects.burst(get_parent(), global_position, {"count": 2, "color": Color(1, 1, 1, 0.7), "speed": 40.0,
					"life": 0.5, "size": 8.0, "grow": true})
			if t >= 0.5:
				end_action(true)
		"dough":
			anim_frame("downspecial", mini(int(t / 0.09), 3))
			_action_physics(delta)
			if not act.has("placed") and t >= 0.22:
				act["placed"] = true
				if _trap and is_instance_valid(_trap):
					_trap.queue_free()
				_trap = DoughTrap.new()
				_trap.owner_fighter = self
				var pos := global_position + Vector2(facing * 70, 0)
				var q := PhysicsRayQueryParameters2D.create(pos + Vector2(0, -60), pos + Vector2(0, 600), 3)
				var hit := get_world_2d().direct_space_state.intersect_ray(q)
				_trap.position = hit["position"] if hit else pos
				get_parent().add_child(_trap)
				Game.play_sfx("fish", -6.0, 0.6)
			if t >= 0.45:
				end_action()
		"bellyflop":
			anim_frame("dair", 0 if t < 0.15 else 1)
			armor_time = maxf(armor_time, 0.05)
			if t < 0.15:
				velocity = Vector2(velocity.x * 0.8, -120.0)
			else:
				velocity = Vector2(move_toward(velocity.x, 0.0, 800.0 * delta), 1400.0)
				hit_rect(box(Vector2(0, -20), Vector2(80, 60)), {"dmg": 10.0, "base_kb": 240.0, "kb_scale": 6.0,
					"angle": -75.0, "special": true})
			if is_on_floor() and t > 0.15:
				hit_list.clear()
				hit_circle(global_position + Vector2(0, -20), 120.0, {"dmg": 12.0, "base_kb": 300.0, "kb_scale": 7.0,
					"angle": 65.0, "special": true})
				Effects.shockwave(get_parent(), global_position, Color(0.9, 0.8, 0.6), 420.0)
				Effects.burst(get_parent(), global_position, {"count": 26, "color": Color(1, 1, 0.97, 0.85),
					"speed": 360.0, "life": 0.7, "size": 9.0, "grow": true, "angle": -90.0, "spread": 80.0})
				Game.play_sfx("quake")
				Game.play_sfx("flour", -4.0, 0.7)
				get_parent().add_shake(20.0)
				squash = Vector2(1.35, 0.7)
				end_action()
				landing_lag = 0.25
				return
			if t >= 1.2:
				end_action()
		"ult_baker":
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			velocity.y = 0.0 if is_on_floor() else minf(velocity.y + 300.0 * delta, 120.0)
			anim_frame("ult", mini(int(t / 0.16), 3))
			if t >= 0.35 and not act.has("on"):
				act["on"] = true
				set_form("ult")
				baker_t = BAKER_TIME
				_bread_cd = 0.2
				Effects.smoke(get_parent(), global_position, Color(1, 1, 1))
				Effects.burst(get_parent(), global_position + Vector2(0, -50), {"count": 40,
					"color": Color(1, 1, 0.97), "speed": 360.0, "life": 0.8, "size": 8.0, "grow": true})
				Effects.popup(get_parent(), global_position + Vector2(0, -190), "¡PANADERO REAL!", data["color"], 1.3)
				Game.play_sfx("powerup")
				Game.play_sfx("flour", 0.0, 0.8)
			if t >= 0.75:
				end_action()
		_:
			super.char_action(action_name, t, delta)


## Masa de levadura: el primer rival que la pise se queda pegado.
class DoughTrap extends Node2D:
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
		if _t < 0.3:
			return
		for f in get_tree().get_nodes_in_group("fighters"):
			if f == owner_fighter or not f.is_alive():
				continue
			if absf(f.global_position.x - global_position.x) < 40.0 and absf(f.global_position.y - global_position.y) < 30.0:
				f.take_damage(7.0, owner_fighter)
				f.freeze(1.2)
				Game.play_sfx("fish", 0.0, 0.5)
				Effects.burst(get_parent(), global_position + Vector2(0, -20), {"count": 18,
					"color": Color(0.95, 0.85, 0.6), "speed": 200.0, "life": 0.6, "size": 6.0, "gravity": 500.0})
				queue_free()
				return

	func _draw() -> void:
		var s := minf(1.0, _t * 4.0)
		var wob := sin(_t * 4.0) * 2.0
		var pts := PackedVector2Array()
		for i in 16:
			var a := PI + i * PI / 15.0
			var r := (34.0 + sin(i * 1.7 + _t * 3.0) * 3.0) * s
			pts.append(Vector2(cos(a) * r, sin(a) * (18.0 + wob) * s))
		draw_colored_polygon(pts, Color(0.93, 0.82, 0.58))
		draw_polyline(pts, Color(0.45, 0.32, 0.18), 2.0)
		draw_circle(Vector2(-10, -8) * s, 4.0 * s, Color(1, 0.95, 0.8))
		draw_circle(Vector2(12, -5) * s, 3.0 * s, Color(1, 0.95, 0.8))
