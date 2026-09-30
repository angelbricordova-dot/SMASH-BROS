@tool
extends AnimatableBody2D
## Plataforma que se mueve de un lado a otro (se puede atravesar desde abajo).
##  - travel: cuánto se mueve desde su posición inicial
##  - period: segundos en ir y volver

@export var size := Vector2(180, 20)
@export var travel := Vector2(260, 0)
@export var period := 6.0
@export_enum("Pradera", "Cosmico", "Ciudad", "Volcan", "Bosque", "Nieve") var style := 2

var _origin := Vector2.ZERO
var _t := 0.0


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_origin = position
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	shape.shape = r
	shape.position = size / 2.0
	shape.one_way_collision = true
	add_child(shape)
	collision_layer = 2
	collision_mask = 0
	add_to_group("oneway")
	sync_to_physics = true


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	position = _origin + travel * sin(_t / period * TAU)


func _draw() -> void:
	Platform.draw_platform(self, size, style, false)
