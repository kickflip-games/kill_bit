extends Node3D

@onready var sprite: Sprite3D = $Sprite3D

@export var debug_mouse_follow: bool = false

func _process(_delta: float):
	if debug_mouse_follow:
		var mouse_pos = get_viewport().get_mouse_position()
		var camera = get_viewport().get_camera_3d()
		
		# Project mouse to a 3D plane at y=0 (or your arrow_height)
		var from = camera.project_ray_origin(mouse_pos)
		var dir = camera.project_ray_normal(mouse_pos)
		var distance = (global_position.y - from.y) / dir.y
		var target = from + dir * distance
		
		# Check if we are at least 0.1 units away
		if global_position.distance_to(target) > 0.1:
			look_at(target, Vector3.UP)
		else:
			# Optional: handle 'too close' by doing nothing 
			# or looking at a default 'forward'
			pass

func setup(weight: int, is_start: bool):
	if is_start:
		sprite.modulate = Color.GREEN
	elif weight <= 2:
		sprite.modulate = Color.YELLOW
	else:
		sprite.modulate = Color.WHITE
