@tool
class_name Platform
extends StaticBody2D
## Plataforma del escenario. Puedes moverla y cambiar su tamaño desde el Inspector.
##  - size: ancho y alto
##  - one_way: si es true, se puede atravesar desde abajo y bajar con ↓ (plataforma flotante)
##  - ground: si es true, es suelo principal (se dibuja con su textura de suelo y tiene bordes para colgarse)
##  - style: 0 = pradera, 1 = cósmico, 2 = ciudad

@export var size := Vector2(200, 24):
	set(v):
		size = v
		_refresh()
@export var one_way := true:
	set(v):
		one_way = v
		_refresh()
@export var ground := false:
	set(v):
		ground = v
		queue_redraw()
@export_enum("Pradera", "Cosmico", "Ciudad") var style := 0:
	set(v):
		style = v
		queue_redraw()

var _shape := CollisionShape2D.new()


func _ready() -> void:
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
	elif is_in_group("oneway"):
		remove_from_group("oneway")
	queue_redraw()


func _draw() -> void:
	draw_platform(self, size, style, ground)


static var _tex_cache := {}


## Carga una textura una sola vez y la guarda (si no, Godot la liberaría enseguida).
static func tex(tex_name: String) -> Texture2D:
	if not _tex_cache.has(tex_name):
		_tex_cache[tex_name] = load("res://assets/sprites/%s.png" % tex_name)
	return _tex_cache[tex_name]


## Dibuja una plataforma (lo usa también la plataforma móvil).
static func draw_platform(ci: CanvasItem, sz: Vector2, st: int, is_ground: bool) -> void:
	var tops := ["tile_grass", "tile_metal_top", "tile_roof"]
	var bodies := ["tile_dirt", "tile_metal", "tile_brick"]
	var plats := ["tile_platform", "tile_platform_metal", "tile_platform_city"]
	if is_ground:
		var top: Texture2D = tex(tops[st])
		var body: Texture2D = tex(bodies[st])
		ci.draw_texture_rect(top, Rect2(0, 0, sz.x, 32), true)
		if sz.y > 32:
			ci.draw_texture_rect(body, Rect2(0, 32, sz.x, sz.y - 32), true)
		# sombra inferior para dar volumen
		ci.draw_rect(Rect2(0, sz.y - 10, sz.x, 10), Color(0, 0, 0, 0.25))
	else:
		ci.draw_texture_rect(tex(plats[st]), Rect2(0, 0, sz.x, sz.y), true)
