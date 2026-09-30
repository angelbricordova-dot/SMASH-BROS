@tool
class_name Platform
extends StaticBody2D
## Plataforma del escenario. Puedes moverla y cambiar su tamaño desde el Inspector.
##  - size: ancho y alto
##  - one_way: si es true, se puede atravesar desde abajo y bajar con ↓ (plataforma flotante)
##  - ground: si es true, es suelo principal (se dibuja con su textura de suelo y tiene bordes para colgarse)
##  - style: 0 pradera, 1 cósmico, 2 ciudad, 3 volcán, 4 bosque, 5 nieve

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
@export_enum("Pradera", "Cosmico", "Ciudad", "Volcan", "Bosque", "Nieve") var style := 0:
	set(v):
		style = v
		queue_redraw()

var _shape := CollisionShape2D.new()


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
const STYLE_IDS := ["pradera", "cosmos", "ciudad", "volcan", "bosque", "nieve"]


## Carga una textura una sola vez y la guarda (si no, Godot la liberaría enseguida).
static func tex(tex_name: String) -> Texture2D:
	if not _tex_cache.has(tex_name):
		_tex_cache[tex_name] = load("res://assets/stages/tiles/%s.png" % tex_name)
	return _tex_cache[tex_name]


## Dibuja una plataforma (lo usa también la plataforma móvil).
static func draw_platform(ci: CanvasItem, sz: Vector2, st: int, is_ground: bool) -> void:
	var sid: String = STYLE_IDS[clampi(st, 0, STYLE_IDS.size() - 1)]
	if is_ground:
		var top_h := minf(64.0, sz.y)
		# sombra suave debajo del suelo
		ci.draw_rect(Rect2(8, sz.y, sz.x - 16, 18), Color(0, 0, 0, 0.18))
		ci.draw_texture_rect(tex(sid + "_body"), Rect2(0, top_h - 2, sz.x, maxf(sz.y - top_h + 2, 0)), true)
		ci.draw_texture_rect(tex(sid + "_top"), Rect2(0, 0, sz.x, top_h), true)
		# degradado oscuro hacia abajo para dar volumen
		for i in 6:
			var k := float(i) / 6.0
			ci.draw_rect(Rect2(0, sz.y * (0.5 + k * 0.5), sz.x, sz.y / 12.0 + 1), Color(0, 0, 0, 0.06 + 0.05 * k))
		ci.draw_rect(Rect2(0, 0, 4, sz.y), Color(0, 0, 0, 0.15))
		ci.draw_rect(Rect2(sz.x - 4, 0, 4, sz.y), Color(0, 0, 0, 0.15))
	else:
		ci.draw_rect(Rect2(6, sz.y, sz.x - 12, 8), Color(0, 0, 0, 0.18))
		ci.draw_texture_rect(tex(sid + "_plat"), Rect2(0, 0, sz.x, maxf(sz.y, 24.0)), true)
