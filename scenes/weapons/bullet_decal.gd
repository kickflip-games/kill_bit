extends Node3D

@onready var mesh_instance = $MeshInstance3D

func _ready():
	pass

func setup_decal(global_pos: Vector3, normal: Vector3):
	"""Position and orient the decal on the surface"""
	global_position = global_pos + (normal * 0.01)  # Slight offset to prevent Z-fighting
	
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
