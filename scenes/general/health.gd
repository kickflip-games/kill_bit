extends Node

signal died
signal damaged

@export var max_health = 10
var current_health

func _ready():
	current_health = max_health

func take_damage(amount):
	if amount <= 0 or current_health <= 0:
		return

	current_health = max(current_health - amount, 0)
	emit_signal("damaged")
	
	if current_health == 0:
		emit_signal("died")
