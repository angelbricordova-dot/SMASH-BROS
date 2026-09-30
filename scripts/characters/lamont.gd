extends Fighter
## LAMONT — el estándar del grupo, con pistola.
##  Especial (tocar G) ....... Disparo: una bala rápida
##  Especial (mantener G) .... Ráfaga triple: mientras mantienes G va cargando balas; al soltar dispara
##                             tres seguidas (¡ta-ta-ta!), más fuertes cuanto más cargues
##  Arriba + Especial ........ Uppercut de puerta: sube con un gancho brutal
##  Abajo + Especial ......... Freno de mano: en el suelo derrapa hacia delante levantando humo;
##                             en el aire baja en diagonal con una patada
##  Ulti ..................... Préstamo: le "pide prestada" vida al rival que elija (el más cercano, o
##                             hacia donde apuntes): el rival SUMA 40% de daño y Lamont se CURA 40%

const LOAN := 40.0


func do_special() -> void:
	begin_action("shot")


func do_charge_special() -> void:
	begin_action("burst")


func do_up_special() -> void:
	begin_action("door")


func do_down_special() -> void:
	begin_action("brake" if is_on_floor() else "brake_air")


func do_ultimate() -> void:
	begin_action("ult_loan")


## Dispara una bala desde la mano.
func _bullet(power: float) -> void:
	var h := body_point("hands")
	var p := global_position + Vector2(h.x, h.y) + Vector2(facing * 20.0, -3.0)
	spawn_projectile({"velocity": Vector2(facing * 1500.0, 0), "radius": 8.0, "lifetime": 0.45,
		"global_position": p, "sprite_scale": 1.0, "trail": Color(1.0, 0.85, 0.4, 0.55),
		"info": {"dmg": 3.0 + 4.0 * power, "base_kb": 120.0 + 170.0 * power, "kb_scale": 2.0 + 3.0 * power,
			"angle": 18.0, "sfx": "hit"}})
	Effects.spark(get_parent(), p, 0.35 + 0.2 * power, Color(1, 0.85, 0.4))
	Game.play_sfx("gunshot", -2.0, randf_range(0.95, 1.08))
	if is_on_floor():
		velocity.x -= facing * 60.0


func char_action(action_name: String, t: float, delta: float) -> void:
	match action_name:
		"shot":
			anim_frame("special", 0 if t < 0.05 else (2 if t < 0.16 else 3))
			if not act.has("fired") and t >= 0.06:
				act["fired"] = true
				_bullet(0.0)
			_action_physics(delta)
			if t >= 0.26:
				end_action()
		"burst":
			_action_physics(delta)
			if not act.has("released"):
				# cargando balas: un "clic" por cada una
				var loaded := mini(3, 1 + int(t / 0.35))
				if loaded != act.get("loaded", 0):
					act["loaded"] = loaded
					Game.play_sfx("reload", -4.0, 0.9 + 0.1 * loaded)
					Effects.popup(get_parent(), global_position + Vector2(0, -118), "•".repeat(loaded),
						Color(1, 0.85, 0.4), 0.7)
			if hold_charge(t, 1.05):
				return
			var c: float = act["charge"]
			var rt: float = t - float(act["released"])
			var shots: int = act.get("shots", 0)
			anim_frame("special", 2 if fmod(rt, 0.09) < 0.05 else 3)
			if shots < 3 and rt >= shots * 0.09:
				act["shots"] = shots + 1
				_bullet(c * (1.25 if shots == 2 else 1.0))
			if rt >= 0.42:
				end_action()
		"door":
			if t < 0.02:
				velocity = Vector2(facing * 160.0, -960.0 * mods["jump"])
				Game.play_sfx("uppercut", -2.0)
			anim_frame("upspecial", mini(int(t / 0.1), 2))
			air_drift(delta, 0.5)
			apply_gravity(delta, 0.6)
			if t >= 0.04 and t < 0.3:
				if hit_rect(box(Vector2(22, -64), Vector2(64, 84)), {"dmg": 10.0, "base_kb": 320.0, "kb_scale": 7.0,
						"angle": 84.0, "special": true}) > 0:
					Game.play_sfx("hit_strong", -4.0, 1.2)
			if t >= 0.46:
				end_action(true)
		"brake":
			anim_frame("downspecial", 0 if t < 0.06 else (1 if t < 0.3 else 3))
			if t < 0.02:
				velocity.x = facing * 680.0
				Game.play_sfx("dash", -2.0, 0.8)
			velocity.x = move_toward(velocity.x, 0.0, 1300.0 * delta)
			velocity.y = 0.0 if is_on_floor() else velocity.y
			if not is_on_floor():
				apply_gravity(delta)
			if Engine.get_physics_frames() % 2 == 0 and absf(velocity.x) > 100.0:
				Effects.burst(get_parent(), global_position + Vector2(-facing * 20, -4), {"count": 3,
					"color": Color(0.85, 0.85, 0.85, 0.7), "speed": 80.0, "life": 0.6, "size": 9.0, "grow": true,
					"angle": -90.0 - facing * 60.0, "spread": 40.0, "gravity": -40.0})
			if t >= 0.05 and t < 0.32:
				hit_rect(box(Vector2(40, -16), Vector2(72, 36)), {"dmg": 8.0, "base_kb": 260.0, "kb_scale": 6.0,
					"angle": 55.0, "special": true})
			if t >= 0.5:
				end_action()
		"brake_air":
			anim_frame("dair", 0 if t < 0.1 else 1)
			if t < 0.1:
				velocity *= 0.8
			else:
				velocity = Vector2(facing * 620.0, 760.0)
				hit_rect(box(Vector2(30, -18), Vector2(66, 56)), {"dmg": 10.0, "base_kb": 250.0, "kb_scale": 7.0,
					"angle": -40.0, "special": true})
				if Engine.get_physics_frames() % 2 == 0:
					Effects.afterimage(get_parent(), self, Color(1, 0.85, 0.4, 0.4))
			if is_on_floor() and t > 0.1:
				Effects.dust(get_parent(), global_position)
				Effects.burst(get_parent(), global_position, {"count": 12, "color": Color(0.85, 0.85, 0.85, 0.7),
					"speed": 160.0, "life": 0.6, "size": 9.0, "grow": true, "angle": -90.0, "spread": 80.0})
				end_action()
				landing_lag = 0.15
				return
			if t >= 0.9:
				end_action()
		"ult_loan":
			velocity.x = move_toward(velocity.x, 0.0, 2000.0 * delta)
			velocity.y = 0.0 if is_on_floor() else minf(velocity.y + 300.0 * delta, 120.0)
			anim_frame("ult", mini(int(t / 0.2), 3))
			if not act.has("target"):
				act["target"] = _choose_target()
				var tg0: Fighter = act["target"]
				if tg0:
					var fx := LoanFx.new()
					fx.from_f = tg0
					fx.to_f = self
					get_parent().add_child(fx)
					tg0.freeze(1.1)
				Game.play_sfx("cash", -2.0, 0.9)
			var tg: Fighter = act["target"]
			if t >= 0.95 and not act.has("done"):
				act["done"] = true
				if tg and is_instance_valid(tg) and tg.is_alive():
					tg.percent = minf(999.0, tg.percent + LOAN)
					tg.hit_flash = 0.3
					tg.last_hit_by = self
					damage_dealt += LOAN
					var healed := minf(percent, LOAN)
					percent -= healed
					Effects.popup(get_parent(), tg.global_position + Vector2(0, -130), "+%d%%" % int(LOAN),
						Color(1, 0.35, 0.3), 1.3)
					Effects.popup(get_parent(), global_position + Vector2(0, -130), "-%d%%" % int(healed),
						Color(0.4, 1, 0.5), 1.3)
					Effects.burst(get_parent(), global_position + Vector2(0, -46), {"count": 24,
						"color": Color(0.45, 1.0, 0.5), "speed": 260.0, "life": 0.6, "size": 4.0, "star": true})
					Game.play_sfx("cash")
					Game.play_sfx("heal", -2.0)
			if t >= 1.35:
				end_action()
		_:
			super.char_action(action_name, t, delta)


## El rival al que se le pide el préstamo: hacia donde apuntes, o el más cercano.
func _choose_target() -> Fighter:
	var best: Fighter = null
	var best_score := INF
	for f in enemies():
		var d: Vector2 = f.global_position - global_position
		var score := d.length()
		if absf(in_move) > 0.3 and signf(d.x) != signf(in_move):
			score += 5000.0
		if score < best_score:
			best_score = score
			best = f
	return best


## Billetes y energía verde viajando del rival a Lamont.
class LoanFx extends Node2D:
	var from_f: Fighter
	var to_f: Fighter
	var _t := 0.0
	const DUR := 1.2
	const MONEY := preload("res://assets/sprites/prop_money.png")

	func _ready() -> void:
		z_index = 12

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		if _t >= DUR + 0.2 or not is_instance_valid(from_f) or not is_instance_valid(to_f):
			queue_free()

	func _draw() -> void:
		var a := from_f.global_position + Vector2(0, -50)
		var b := to_f.global_position + Vector2(0, -50)
		var k := clampf(_t / DUR, 0.0, 1.0)
		# retícula sobre el rival elegido
		var r := 40.0 + 20.0 * sin(_t * 12.0)
		draw_arc(a, r, 0, TAU, 32, Color(1, 0.3, 0.3, 0.9), 3.0)
		draw_line(a - Vector2(r + 10, 0), a - Vector2(r - 12, 0), Color(1, 0.3, 0.3), 3.0)
		draw_line(a + Vector2(r - 12, 0), a + Vector2(r + 10, 0), Color(1, 0.3, 0.3), 3.0)
		draw_line(a - Vector2(0, r + 10), a - Vector2(0, r - 12), Color(1, 0.3, 0.3), 3.0)
		# rayo verde
		draw_line(a, b, Color(0.4, 1, 0.5, 0.35 * (1.0 - absf(k * 2.0 - 1.0))), 14.0)
		for i in 7:
			var q := fmod(k * 1.6 + i / 7.0, 1.0)
			var p := a.lerp(b, q) + Vector2(0, -sin(q * PI) * 60.0)
			draw_set_transform(p, sin(_t * 8.0 + i) * 0.6, Vector2.ONE)
			draw_texture(MONEY, -MONEY.get_size() / 2.0, Color(1, 1, 1, minf(1.0, (1.0 - k) * 4.0)))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
