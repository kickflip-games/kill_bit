extends Node3D

class_name Weapon

signal fired
signal ammo_changed(current_ammo: int, max_ammo: int)

@export var max_ammo: int = 30

var current_ammo: int

func _ready():
	current_ammo = max_ammo
	emit_signal("ammo_changed", current_ammo, max_ammo)

func fire():
	pass

func can_shoot() -> bool:
	return current_ammo > 0

func consume_ammo():
	if current_ammo > 0:
		current_ammo -= 1
		emit_signal("ammo_changed", current_ammo, max_ammo)
