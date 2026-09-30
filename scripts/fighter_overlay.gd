extends Node2D
## Nodo auxiliar: dibuja cosas encima del personaje (escudo, nombre...). Ver Fighter.draw_overlay().

var fighter: Fighter


func _draw() -> void:
	if fighter:
		fighter.draw_overlay(self)
