extends Node3D
class_name BloodDecals
## Blood spray decals with sphere-cast raycasting.
## Contains 4 child DecalInstanceCompatibility nodes (one per texture) for variety.

const RAYCAST_DISTANCE = 3.0
const BLOOD_LIFETIME = 30.0

var _managers: Array  # Array of DecalInstanceCompatibility
var _indices: Array[int]

func _ready() -> void:
	_managers = []
	for child in get_children():
		if child is DecalInstanceCompatibility:
			_managers.append(child)
	_indices.resize(_managers.size())
	_indices.fill(0)
	for mgr in _managers:
		mgr.multimesh.visible_instance_count = 0
	Log.info("BloodDecals ready", {"texture_variants": _managers.size()})

func spawn_blood_at_position(origin: Vector3, spray_direction: Vector3, is_death: bool = false) -> void:
	if _managers.is_empty():
		return
	var base_scale = randf_range(2, 4)
	var scale_mult = base_scale * 2.0 if is_death else base_scale
	var num_rays = 12 if is_death else 5

	# Offset up from feet so rays cast from mid-body, hitting floor and nearby walls
	var cast_origin = origin + Vector3.UP * 0.5

	for i in range(num_rays):
		var random_offset = Vector3(
			randf_range(-1, 1),
			randf_range(-1, 0.3),
			randf_range(-1, 1)
		).normalized()
		var direction = (spray_direction * 0.6 + random_offset * 0.4).normalized()
		var query = PhysicsRayQueryParameters3D.create(
			cast_origin,
			cast_origin + direction * RAYCAST_DISTANCE
		)
		query.collision_mask = 1
		var result = get_world_3d().direct_space_state.intersect_ray(query)
		if result:
			_spawn_single_decal(result.position, result.normal, scale_mult * randf_range(0.9, 1.1))

func _spawn_single_decal(pos: Vector3, normal: Vector3, decal_scale: float) -> void:
	var mi = randi() % _managers.size()
	var mgr: DecalInstanceCompatibility = _managers[mi]
	var idx = _indices[mi]

	mgr.multimesh.set_instance_transform(idx, _make_transform(pos, normal, decal_scale))
	mgr.reset_instance(idx)
	mgr.fade_out_instance(idx, 3.0, BLOOD_LIFETIME - 3.0)

	_indices[mi] = (idx + 1) % mgr.instance_count
	if mgr.multimesh.visible_instance_count < mgr.instance_count:
		mgr.multimesh.visible_instance_count += 1

func _make_transform(pos: Vector3, normal: Vector3, decal_scale: float) -> Transform3D:
	# Align local Y to surface normal so the shader's XZ UV projection faces the surface
	var y_axis = normal
	var ref = Vector3.RIGHT if abs(normal.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var x_axis = ref.cross(y_axis).normalized()
	var z_axis = x_axis.cross(y_axis).normalized()
	var spin = randf() * TAU
	var rx = x_axis * cos(spin) + z_axis * sin(spin)
	var rz = -x_axis * sin(spin) + z_axis * cos(spin)
	var b = Basis(rx, y_axis, rz).scaled(Vector3.ONE * decal_scale)
	return Transform3D(b, pos + normal * 0.02)
