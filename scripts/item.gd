class_name Item
extends CharacterBody2D
## Objeto que cae del cielo. Acércate y presiona ATAQUE para recogerlo.
##  - "bat": bate. Tu ataque se vuelve un batazo que manda a volar lejísimos.
##  - "bow": arco (estilo Minecraft) con 3 flechas. Mantén ATAQUE para tensar, suelta para disparar.
## Escudo + Ataque lanza el objeto que tengas.

const LIFETIME := 20.0

var kind := "bat"
var _age := 0.0
var _tex: Texture2D


func _ready() -> void:
	add_to_group("items")
	collision_layer = 0
	collision_mask = 3
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(30, 16)
	shape.shape = r
	shape.position = Vector2(0, -8)
	add_child(shape)
	_tex = load("res://assets/sprites/item_bat.png" if kind == "bat" else "res://assets/sprites/item_bow.png")
	z_index = 1


func can_pickup() -> bool:
	return _age > 0.3


func _physics_process(delta: float) -> void:
	_age += delta
	velocity.y = minf(velocity.y + 1400.0 * delta, 900.0)
	velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
	move_and_slide()
	if is_on_floor():
		velocity.y = 0.0
	if _age > LIFETIME or global_position.y > 1300.0:
		queue_free()
	queue_redraw()


func _draw() -> void:
	if _age > LIFETIME - 3.0 and fmod(_age, 0.2) < 0.1:
		return
	var pulse := 0.5 + 0.5 * sin(_age * 6.0)
	draw_circle(Vector2(0, -16), 26.0 + pulse * 4.0, Color(1, 0.95, 0.5, 0.18 + pulse * 0.12))
	draw_arc(Vector2(0, -16), 26.0 + pulse * 4.0, 0, TAU, 28, Color(1, 1, 0.7, 0.6), 2.0)
	var bob := sin(_age * 3.0) * 3.0
	if kind == "bat":
		draw_set_transform(Vector2(-38, -20 + bob), -0.35, Vector2(2, 2))
		draw_texture(_tex, Vector2.ZERO)
	else:
		draw_set_transform(Vector2(-14, -40 + bob), 0.0, Vector2(1.6, 1.6))
		draw_texture_rect_region(_tex, Rect2(0, 0, 20, 28), Rect2(0, 0, 20, 28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
