extends Node
## Genera las miniaturas de los escenarios para el menú (assets/ui/stage_<id>.png).
## Correr (necesita ventana):  godot --path . res://tools/make_thumbnails.tscn


func _ready() -> void:
	Game.preview_mode = true
	for s in Game.STAGES:
		var stage: Node = load(Game.stage_scene(s["id"])).instantiate()
		add_child(stage)
		for i in 20:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.resize(512, 288, Image.INTERPOLATE_BILINEAR)
		img.save_png(ProjectSettings.globalize_path("res://assets/ui/stage_%s.png" % s["id"]))
		print("miniatura: ", s["id"])
		stage.queue_free()
		await get_tree().process_frame
	Game.preview_mode = false
	get_tree().quit()
