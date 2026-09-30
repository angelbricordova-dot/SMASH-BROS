extends Node
## Script GLOBAL (autoload "Game"): está disponible desde cualquier parte del juego.
## Aquí viven: los controles, los mapas, la música, los ajustes, las fuentes y los sonidos.

const MENU_SCENE := "res://scenes/menu.tscn"
const SETTINGS_FILE := "user://ajustes.cfg"

## Mapas disponibles. Para agregar uno: crea su escena en scenes/stages/ y añádelo aquí.
const STAGES := [
	{"id": "pradera", "name": "Pradera", "desc": "El clásico: suelo con 3 plataformas.", "music": "boulevard",
		"ambience": "pollen"},
	{"id": "cosmos", "name": "Destino Cósmico", "desc": "Plano y sin plataformas. Solo habilidad.", "music": "neon",
		"ambience": "stars"},
	{"id": "ciudad", "name": "Azotea", "desc": "Plataforma móvil y vigas a los lados.", "music": "asfalto",
		"ambience": "lights"},
	{"id": "volcan", "name": "Volcán", "desc": "Plataformas que suben y bajan sobre la lava.", "music": "fuego",
		"ambience": "embers"},
	{"id": "bosque", "name": "Bosque Nocturno", "desc": "Plataformas en escalera bajo la luna.", "music": "neon",
		"ambience": "fireflies"},
	{"id": "nieve", "name": "Cumbre Nevada", "desc": "Suelo angosto y plataformas de hielo.", "music": "asfalto",
		"ambience": "snow"},
]

## Canciones que se pueden elegir al escoger escenario (archivos en assets/music/<id>.ogg).
## "auto" = la que tiene asignada el escenario.
const TRACKS := [
	{"id": "auto", "name": "Automática (la del escenario)"},
	{"id": "boulevard", "name": "Rock del Boulevard"},
	{"id": "asfalto", "name": "Asfalto (hard rock)"},
	{"id": "fuego", "name": "Fuego Cruzado (metal)"},
	{"id": "neon", "name": "Noches de Neón (synth rock)"},
	{"id": "chaos", "name": "Caos Total (punk)"},
	{"id": "training", "name": "Calentando (funk)"},
	{"id": "menu", "name": "Boulevard de Noche (lo-fi)"},
	{"id": "random", "name": "Aleatoria"},
]

## Todos los efectos de sonido (archivos en assets/sounds/<nombre>.wav)
const SFX := [
	"hit", "hit_strong", "homerun", "swing", "swing_heavy", "slash", "charge", "jump", "double_jump", "land",
	"dash", "roll", "crouch", "helpless", "shield", "shield_up", "shield_crack", "shield_break", "parry", "ko",
	"ult_ready", "ult", "fire", "beam", "shoot", "freeze", "shatter", "quake", "teleport", "shadow", "uppercut",
	"zap", "thunder", "laser", "laser_big", "explosion", "magic", "counter", "hover", "bow_draw", "bow_shoot",
	"arrow_hit", "pickup", "item_spawn", "throw", "heal", "star", "fuse", "boomerang", "taunt", "menu_move",
	"select", "menu_confirm", "menu_back", "card_show", "card_pick", "countdown", "start", "go", "fanfare", "cheer",
	"gunshot", "reload", "slap", "fish", "mic", "flour", "paper", "bus_horn", "lie", "cash", "final_hit", "cloth",
	"powerup", "bread", "angry",
]

const LEVEL_NAMES := ["FÁCIL", "NORMAL", "DIFÍCIL"]
const MODES := {"classic": "CLÁSICO", "cards": "CAOS DE CARTAS", "training": "ENTRENAMIENTO"}

## Configuración de la partida actual (el menú la modifica).
var players: Array = [
	{"char": "rojo", "cpu": false, "level": 1},
	{"char": "azul", "cpu": true, "level": 1},
]
var stocks := 3
var items_on := true
var stage_id := "pradera"
var mode := "classic"         # "classic", "cards" o "training"
var music_choice := "auto"    # canción elegida en la pantalla de escenario (ver TRACKS)
var preview_mode := false
var match_setup := {}

## Ajustes (se guardan en el disco)
var music_volume := 0.7
var tap_jump := true          # saltar también con ARRIBA (W / flecha arriba)
var sfx_volume := 0.9
var fullscreen := false

var font_title: Font
var font_logo: Font          # Bungee: letras de cartel (logo, carteles grandes)
var font_tag: Font           # Permanent Marker: estilo grafiti
var font_body: Font

var _sfx := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next := 0
var _music: AudioStreamPlayer
var _music_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_register_controls()
	_setup_fonts()
	for sfx_name in SFX:
		var path := "res://assets/sounds/%s.wav" % sfx_name
		if ResourceLoader.exists(path):
			_sfx[sfx_name] = load(path)
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	load_settings()


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func _setup_fonts() -> void:
	font_title = load("res://assets/fonts/LilitaOne-Regular.ttf")
	font_logo = load("res://assets/fonts/Bungee-Regular.ttf")
	font_tag = load("res://assets/fonts/PermanentMarker-Regular.ttf")
	var body := FontVariation.new()
	body.base_font = load("res://assets/fonts/Nunito-Variable.ttf")
	body.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 800}
	font_body = body
	var theme := Theme.new()
	theme.default_font = font_body
	theme.default_font_size = 18
	get_tree().root.theme = theme


# ------------------------------------------------------------------
#  Ajustes: volumen y pantalla completa
# ------------------------------------------------------------------
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_FILE) == OK:
		music_volume = cfg.get_value("audio", "music", music_volume)
		sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
		fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
		tap_jump = cfg.get_value("controls", "tap_jump", tap_jump)
	apply_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("controls", "tap_jump", tap_jump)
	cfg.save(SETTINGS_FILE)


func apply_settings() -> void:
	_set_bus_volume("Music", music_volume)
	_set_bus_volume("SFX", sfx_volume)
	set_fullscreen(fullscreen, false)


func _set_bus_volume(bus_name: String, v: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(idx, v <= 0.001)


func set_fullscreen(on: bool, save := true) -> void:
	fullscreen = on
	if DisplayServer.get_name() == "headless":
		return
	var w := get_window()
	# Nota: si el juego corre DENTRO del editor de Godot 4.4+ (pestaña "Game"), la pantalla completa
	# no se puede activar ahí; funciona al ejecutar en ventana propia o con el juego exportado.
	w.mode = Window.MODE_FULLSCREEN if on else Window.MODE_WINDOWED
	if save:
		save_settings()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		set_fullscreen(get_window().mode != Window.MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------
#  Sonido y música
# ------------------------------------------------------------------
func play_sfx(sfx_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _sfx.has(sfx_name):
		return
	var p := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	p.stream = _sfx[sfx_name]
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func play_music(track: String, fade := 0.6) -> void:
	if track == _music_name and _music.playing:
		return
	_music_name = track
	var path := "res://assets/music/%s.ogg" % track
	if not ResourceLoader.exists(path):
		return
	var stream: AudioStream = load(path)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	var tw := create_tween()
	if _music.playing:
		tw.tween_property(_music, "volume_db", -40.0, fade * 0.5)
	tw.tween_callback(func():
		_music.stream = stream
		_music.volume_db = -30.0
		_music.play())
	tw.tween_property(_music, "volume_db", -4.0, fade)


# ------------------------------------------------------------------
#  Partidas
# ------------------------------------------------------------------
func get_stage(id: String) -> Dictionary:
	for s in STAGES:
		if s["id"] == id:
			return s
	return STAGES[0]


## La canción que suena en un escenario según lo elegido en el menú.
func battle_track(sid: String) -> String:
	var choice := music_choice
	if choice == "random":
		choice = TRACKS[1 + randi() % (TRACKS.size() - 2)]["id"]
	if choice != "auto":
		return choice
	if mode == "cards":
		return "chaos"
	if mode == "training":
		return "training"
	return get_stage(sid)["music"]


func stage_scene(id: String) -> String:
	return "res://scenes/stages/%s.tscn" % get_stage(id)["id"]


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


func goto_menu() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	match_setup = {}
	get_tree().change_scene_to_file(MENU_SCENE)


func goto_stage() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	match_setup = resolve_random()
	get_tree().change_scene_to_file(stage_scene(match_setup["stage"]))


func rematch() -> void:
	if match_setup.is_empty():
		goto_stage()
		return
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(stage_scene(match_setup["stage"]))


# ------------------------------------------------------------------
#  CONTROLES  (aquí puedes cambiar las teclas)
# ------------------------------------------------------------------
func _register_controls() -> void:
	# Jugador 1: WASD, Espacio saltar, F ataque, G especial, Q escudo, E ulti, R provocar, C lanzar objeto
	_player_keys(1, {
		"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S],
		"jump": [KEY_SPACE], "attack": [KEY_F], "special": [KEY_G], "shield": [KEY_Q],
		"ult": [KEY_E], "taunt": [KEY_R], "throw": [KEY_C],
	})
	# Jugador 2: Flechas, Enter saltar, coma ataque, punto especial, guion escudo, L ulti, K provocar, J lanzar
	# (también sirve el teclado numérico: 0 saltar, 1 ataque, 2 especial, 3 escudo, 4 ulti, 5 provocar, 6 lanzar)
	_player_keys(2, {
		"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
		"jump": [KEY_ENTER, KEY_KP_0], "attack": [KEY_COMMA, KEY_KP_1], "special": [KEY_PERIOD, KEY_KP_2],
		"shield": [KEY_MINUS, KEY_KP_3], "ult": [KEY_L, KEY_KP_4], "taunt": [KEY_K, KEY_KP_5],
		"throw": [KEY_J, KEY_KP_6],
	})
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
		_joy_axis(pre + "shield", dev, JOY_AXIS_TRIGGER_LEFT, 1.0)
		_joy_axis(pre + "shield", dev, JOY_AXIS_TRIGGER_RIGHT, 1.0)
		_joy_button(pre + "throw", dev, JOY_BUTTON_RIGHT_SHOULDER)
	_add_key("pause", KEY_ESCAPE)
	_joy_button("pause", -1, JOY_BUTTON_START)
	_add_key("ui_start", KEY_ENTER)
	_add_key("ui_start", KEY_KP_ENTER)
	_joy_button("ui_start", -1, JOY_BUTTON_START)
	_add_key("ui_back", KEY_ESCAPE)
	_add_key("ui_back", KEY_BACKSPACE)
	# modo Entrenamiento
	_add_key("train_reset", KEY_T)
	_add_key("train_mode", KEY_Y)
	_add_key("train_ult", KEY_U)


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
