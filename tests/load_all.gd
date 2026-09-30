extends Node
## Carga todos los scripts y escenas para detectar errores (desarrollo).
func _ready() -> void:
	var bad := 0
	for dir in ["res://scripts/", "res://scripts/characters/", "res://scenes/", "res://scenes/stages/"]:
		var d := DirAccess.open(dir)
		for f in d.get_files():
			if f.ends_with(".gd") or f.ends_with(".tscn"):
				var r = load(dir + f)
				if r == null:
					print("FALLA: ", dir + f)
					bad += 1
	print("cargados, fallas=", bad)
	get_tree().quit()
