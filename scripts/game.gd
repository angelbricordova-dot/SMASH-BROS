extends Node
## Script GLOBAL (autoload "Game"): está disponible desde cualquier parte del juego.
## Aquí viven: los controles, la configuración de la partida y los sonidos.

const MENU_SCENE := "res://scenes/menu.tscn"
const STAGE_SCENE := "res://scenes/stage.tscn"

## Configuración de la partida actual (el menú la modifica).
var players: Array = [
	{"char": "rojo", "cpu": false},
	{"char": "azul", "cpu": false},
]
var stocks := 3  # vidas por jugador

var _sfx := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_controls()
	for sfx_name in ["hit", "hit_strong", "jump", "shoot", "shield", "ko", "select", "start"]:
		var path := "res://assets/sounds/%s.wav" % sfx_name
		if ResourceLoader.exists(path):
			_sfx[sfx_name] = load(path)
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx_players.append(p)


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


func goto_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func goto_stage() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(STAGE_SCENE)


# ------------------------------------------------------------------
#  CONTROLES  (aquí puedes cambiar las teclas)
# ------------------------------------------------------------------
func _register_controls() -> void:
	# Jugador 1: WASD + Espacio (saltar), F (ataque), G (especial), Q (escudo)
	_player_keys(1, {
		"left": KEY_A, "right": KEY_D, "up": KEY_W, "down": KEY_S,
		"jump": KEY_SPACE, "attack": KEY_F, "special": KEY_G, "shield": KEY_Q,
	})
	# Jugador 2: Flechas + Enter (saltar), coma (ataque), punto (especial), guion (escudo)
	_player_keys(2, {
		"left": KEY_LEFT, "right": KEY_RIGHT, "up": KEY_UP, "down": KEY_DOWN,
		"jump": KEY_ENTER, "attack": KEY_COMMA, "special": KEY_PERIOD, "shield": KEY_MINUS,
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
		_joy_button(pre + "jump", dev, JOY_BUTTON_Y)
		_joy_button(pre + "attack", dev, JOY_BUTTON_X)
		_joy_button(pre + "special", dev, JOY_BUTTON_B)
		_joy_button(pre + "shield", dev, JOY_BUTTON_LEFT_SHOULDER)
		_joy_button(pre + "shield", dev, JOY_BUTTON_RIGHT_SHOULDER)
		_joy_axis(pre + "shield", dev, JOY_AXIS_TRIGGER_LEFT, 1.0)
		_joy_axis(pre + "shield", dev, JOY_AXIS_TRIGGER_RIGHT, 1.0)

	# Acciones generales
	_ensure_action("pause")
	_add_key("pause", KEY_ESCAPE)
	_joy_button("pause", -1, JOY_BUTTON_START)
	_ensure_action("ui_start")
	_add_key("ui_start", KEY_ENTER)
	_add_key("ui_start", KEY_KP_ENTER)
	_joy_button("ui_start", -1, JOY_BUTTON_START)


func _player_keys(pl: int, keys: Dictionary) -> void:
	for action_name in keys:
		var full: String = "p%d_%s" % [pl, action_name]
		_ensure_action(full)
		_add_key(full, keys[action_name])


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
