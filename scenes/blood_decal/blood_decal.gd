extends Node3D

@onready var mesh_instance = $MeshInstance3D

func _ready():
	pass

func setup_decal(global_pos: Vector3, normal: Vector3, scale_factor: float = 1.0):
	"""
	Position and orient the blood decal on the surface.
	
	Args:
		global_pos: Position of the blood splat
		normal: Surface normal where blood hit
		scale_factor: Intensity multiplier (damage amount)
	"""
	global_position = global_pos + (normal * 0.01)  # Slight offset to prevent Z-fighting
	
	# Randomize scale for varied blood splatters
	var randomized_scale = randf_range(0.5, 2.0) * scale_factor
	scale = Vector3.ONE * randomized_scale
	
	# Calculate basis to orient the quad to face along the normal
	var forward = -normal  # Face opposite direction (surface outward)
	var up = Vector3.UP
	
	# Handle edge case where normal is parallel to UP
	if abs(forward.dot(up)) > 0.99:
		up = Vector3.RIGHT
	
	var right = up.cross(forward).normalized()
	up = forward.cross(right).normalized()
	
	# Set the basis to face the normal direction
	basis = Basis(right, up, -forward)
	
	# Randomize rotation on the surface for variety
	rotate_object_local(Vector3(0, 0, 1), randf_range(0, TAU))
