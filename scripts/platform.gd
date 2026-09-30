@tool
class_name Platform
extends StaticBody2D
## Plataforma del escenario. Puedes moverla y cambiar su tamaño desde el Inspector.
##  - size: ancho y alto
##  - one_way: si es true, se puede atravesar desde abajo y bajar con ↓ (plataforma flotante)
##  - grass: si es true, dibuja pasto arriba (suelo principal)

@export var size := Vector2(200, 24):
	set(v):
		size = v
		_refresh()
@export var one_way := true:
	set(v):
		one_way = v
		_refresh()
@export var grass := false:
	set(v):
		grass = v
		queue_redraw()

var _shape := CollisionShape2D.new()
var _tex_grass: Texture2D
var _tex_dirt: Texture2D
var _tex_plat: Texture2D


func _ready() -> void:
	_tex_grass = load("res://assets/sprites/tile_grass.png")
	_tex_dirt = load("res://assets/sprites/tile_dirt.png")
	_tex_plat = load("res://assets/sprites/tile_platform.png")
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	_refresh()


func _refresh() -> void:
	if not is_node_ready():
		return
	(_shape.shape as RectangleShape2D).size = size
	_shape.position = size / 2.0
	_shape.one_way_collision = one_way
	collision_layer = 2 if one_way else 1
	collision_mask = 0
	if one_way:
		add_to_group("oneway")
	else:
		remove_from_group("oneway")
	queue_redraw()


## El origen (0,0) del nodo es la esquina superior izquierda de la plataforma.
func _draw() -> void:
	if not is_node_ready():
		return
	if grass:
		draw_texture_rect(_tex_grass, Rect2(0, 0, size.x, 32), true)
		draw_texture_rect(_tex_dirt, Rect2(0, 32, size.x, maxf(size.y - 32, 0)), true)
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0, 0, 0, 0.0))
	else:
		draw_texture_rect(_tex_plat, Rect2(0, 0, size.x, size.y), true)
