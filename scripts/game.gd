extends Node
## Script GLOBAL (autoload "Game"): está disponible desde cualquier parte del juego.
## Aquí viven: los controles, la configuración de la partida, los mapas, las fuentes y los sonidos.

const MENU_SCENE := "res://scenes/menu.tscn"

## Mapas disponibles. Para agregar uno: crea su escena en scenes/stages/ y añádelo aquí.
const STAGES := [
	{"id": "pradera", "name": "Pradera", "desc": "El clásico: suelo con 3 plataformas.",
		"scene": "res://scenes/stages/pradera.tscn", "thumb": "res://assets/ui/stage_pradera.png"},
	{"id": "cosmos", "name": "Destino Cósmico", "desc": "Plano y sin plataformas. Solo habilidad.",
		"scene": "res://scenes/stages/cosmos.tscn", "thumb": "res://assets/ui/stage_cosmos.png"},
	{"id": "ciudad", "name": "Azotea", "desc": "Plataforma móvil y vigas a los lados.",
		"scene": "res://scenes/stages/ciudad.tscn", "thumb": "res://assets/ui/stage_ciudad.png"},
]

## Todos los efectos de sonido (archivos en assets/sounds/<nombre>.wav)
const SFX := [
	"hit", "hit_strong", "homerun", "swing", "jump", "double_jump", "land", "dash", "shoot", "shield",
	"shield_crack", "shield_break", "parry", "ko", "ult_ready", "ult", "beam", "freeze", "shatter",
	"quake", "teleport", "shadow", "fire", "uppercut", "bow_draw", "bow_shoot", "arrow_hit", "pickup",
	"item_spawn", "throw", "taunt", "crouch", "helpless", "select", "menu_move", "menu_confirm",
	"menu_back", "start", "go", "cheer", "fanfare",
]

const LEVEL_NAMES := ["FÁCIL", "NORMAL", "DIFÍCIL"]

## Configuración de la partida actual (el menú la modifica).
## "char" puede ser "random". "level": 0 fácil, 1 normal, 2 difícil (solo para CPU).
var players: Array = [
	{"char": "rojo", "cpu": false, "level": 1},
	{"char": "azul", "cpu": true, "level": 1},
]
var stocks := 3            # vidas por jugador
var items_on := true       # ¿aparecen objetos?
var stage_id := "pradera"  # puede ser "random"
var preview_mode := false  # usado solo para generar miniaturas de mapas

var font_title: Font
var font_body: Font

var _sfx := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_controls()
	_setup_fonts()
	for sfx_name in SFX:
		var path := "res://assets/sounds/%s.wav" % sfx_name
		if ResourceLoader.exists(path):
			_sfx[sfx_name] = load(path)
	for i in 14:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)


func _setup_fonts() -> void:
	font_title = load("res://assets/fonts/LilitaOne-Regular.ttf")
	var body := FontVariation.new()
	body.base_font = load("res://assets/fonts/Nunito-Variable.ttf")
	body.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	font_body = body
	var theme := Theme.new()
	theme.default_font = font_body
	theme.default_font_size = 18
	get_tree().root.theme = theme


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		var fs := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(
			DisplayServer.WINDOW_MODE_WINDOWED if fs else DisplayServer.WINDOW_MODE_FULLSCREEN)


func play_sfx(sfx_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _sfx.has(sfx_name):
		return
	var p := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = _sfx[sfx_name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func get_stage(id: String) -> Dictionary:
	for s in STAGES:
		if s["id"] == id:
			return s
	return STAGES[0]


## Resuelve las opciones "aleatorio" justo antes de pelear.
func resolve_random() -> Dictionary:
	var chosen_stage := stage_id
	if chosen_stage == "random":
		chosen_stage = STAGES[randi() % STAGES.size()]["id"]
	var chars: Array = []
	for p in players:
		var c: String = p["char"]
		if c == "random":
			c = CharacterData.ORDER[randi() % CharacterData.ORDER.size()]
		chars.append(c)
	return {"stage": chosen_stage, "chars": chars}


var match_setup := {}


func goto_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(MENU_SCENE)


func goto_stage() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	match_setup = resolve_random()
	get_tree().change_scene_to_file(get_stage(match_setup["stage"])["scene"])


## Revancha: mismo mapa y mismos personajes (aunque fueran aleatorios)
func rematch() -> void:
	if match_setup.is_empty():
		goto_stage()
		return
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(get_stage(match_setup["stage"])["scene"])


# ------------------------------------------------------------------
#  CONTROLES  (aquí puedes cambiar las teclas)
# ------------------------------------------------------------------
func _register_controls() -> void:
	# Jugador 1: WASD, Espacio saltar, F ataque, G especial, Q escudo, E ulti, R provocar
	_player_keys(1, {
		"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S],
		"jump": [KEY_SPACE], "attack": [KEY_F], "special": [KEY_G], "shield": [KEY_Q],
		"ult": [KEY_E], "taunt": [KEY_R],
	})
	# Jugador 2: Flechas, Enter saltar, coma ataque, punto especial, guion escudo, L ulti, K provocar
	# (también sirve el teclado numérico: 0 saltar, 1 ataque, 2 especial, 3 escudo, 4 ulti, 5 provocar)
	_player_keys(2, {
		"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
		"jump": [KEY_ENTER, KEY_KP_0], "attack": [KEY_COMMA, KEY_KP_1], "special": [KEY_PERIOD, KEY_KP_2],
		"shield": [KEY_MINUS, KEY_KP_3], "ult": [KEY_L, KEY_KP_4], "taunt": [KEY_K, KEY_KP_5],
	})

	# Control (gamepad): el primero es el jugador 1, el segundo el jugador 2.
	for pl in [1, 2]:
		var dev: int = pl - 1
		var pre := "p%d_" % pl
		_joy_axis(pre + "left", dev, JOY_AXIS_LEFT_X, -1.0)
		_joy_axis(pre + "right", dev, JOY_AXIS_LEFT_X, 1.0)
		_joy_axis(pre + "up", dev, JOY_AXIS_LEFT_Y, -1.0)
		_joy_axis(pre + "down", dev, JOY_AXIS_LEFT_Y, 1.0)
		_joy_button(pre + "left", dev, JOY_BUTTON_DPAD_LEFT)
		_joy_button(pre + "right", dev, JOY_BUTTON_DPAD_RIGHT)
		_joy_button(pre + "up", dev, JOY_BUTTON_DPAD_UP)
		_joy_button(pre + "down", dev, JOY_BUTTON_DPAD_DOWN)
		_joy_button(pre + "jump", dev, JOY_BUTTON_A)
		_joy_button(pre + "attack", dev, JOY_BUTTON_X)
		_joy_button(pre + "special", dev, JOY_BUTTON_B)
		_joy_button(pre + "ult", dev, JOY_BUTTON_Y)
		_joy_button(pre + "taunt", dev, JOY_BUTTON_BACK)
		_joy_button(pre + "shield", dev, JOY_BUTTON_LEFT_SHOULDER)
		_joy_button(pre + "shield", dev, JOY_BUTTON_RIGHT_SHOULDER)
		_joy_axis(pre + "shield", dev, JOY_AXIS_TRIGGER_LEFT, 1.0)
		_joy_axis(pre + "shield", dev, JOY_AXIS_TRIGGER_RIGHT, 1.0)

	# Acciones generales
	_add_key("pause", KEY_ESCAPE)
	_joy_button("pause", -1, JOY_BUTTON_START)
	_add_key("ui_start", KEY_ENTER)
	_add_key("ui_start", KEY_KP_ENTER)
	_joy_button("ui_start", -1, JOY_BUTTON_START)
	_add_key("ui_back", KEY_ESCAPE)
	_add_key("ui_back", KEY_BACKSPACE)


func _player_keys(pl: int, keys: Dictionary) -> void:
	for action_name in keys:
		var full: String = "p%d_%s" % [pl, action_name]
		for k in keys[action_name]:
			_add_key(full, k)


func _ensure_action(action_name: String) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name, 0.5)


func _add_key(action_name: String, keycode: Key) -> void:
	_ensure_action(action_name)
	var ev := InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(action_name, ev)


func _joy_button(action_name: String, device: int, button: JoyButton) -> void:
	_ensure_action(action_name)
	var ev := InputEventJoypadButton.new()
	ev.device = device
	ev.button_index = button
	InputMap.action_add_event(action_name, ev)


func _joy_axis(action_name: String, device: int, axis: JoyAxis, value: float) -> void:
	_ensure_action(action_name)
	var ev := InputEventJoypadMotion.new()
	ev.device = device
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action_name, ev)
