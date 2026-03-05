extends Node3D

static var _textures: Array = []
static var _textures_loaded: bool = false

@onready var mesh_instance = $MeshInstance3D

func _ready():
	_ensure_textures_loaded()
	# Duplicate material so each pooled instance can show a unique texture
	mesh_instance.material_override = mesh_instance.get_active_material(0).duplicate()

static func _ensure_textures_loaded() -> void:
	if _textures_loaded:
		return
	for i in range(36):
		_textures.append(load("res://scenes/blood_decal/blood_decal_images/splat%02d.png" % i))
	_textures_loaded = true

func setup_decal(global_pos: Vector3, normal: Vector3, scale_factor: float = 1.0):
	# Pick a random splat texture
	var mat := mesh_instance.material_override as StandardMaterial3D
	if mat and _textures.size() > 0:
		mat.albedo_texture = _textures[randi() % _textures.size()]
		mat.albedo_color = Color(0.8, 0.0, 0.0, 0.9)

	global_position = global_pos + (normal * 0.01)  # Slight offset to prevent Z-fighting

	var randomized_scale = randf_range(0.5, 2.0) * scale_factor
	scale = Vector3.ONE * randomized_scale

	# Orient the quad to face along the surface normal
	var forward = -normal
	var up = Vector3.UP
	if abs(forward.dot(up)) > 0.99:
		up = Vector3.RIGHT
	var right = up.cross(forward).normalized()
	up = forward.cross(right).normalized()
	basis = Basis(right, up, -forward)

	rotate_object_local(Vector3(0, 0, 1), randf_range(0, TAU))
