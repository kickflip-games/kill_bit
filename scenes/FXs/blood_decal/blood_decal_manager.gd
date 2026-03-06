extends Node3D
class_name BloodDecals
## Blood spray decals with sphere-cast raycasting.
## Contains 4 child DecalInstanceCompatibility nodes (one per texture) for variety.

const DAMAGE_RAYCAST_DISTANCE = 1.4
const DEATH_RAYCAST_DISTANCE = 2.0
const BLOOD_LIFETIME = 30.0
const DAMAGE_SCALE_MIN = 0.7
const DAMAGE_SCALE_MAX = 1.2
const DEATH_SCALE_MULT = 2.0
const SURFACE_PENETRATION = 0.02

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
		# Keep decals in world space so placement does not drift with parent transforms.
		mgr.top_level = true
		mgr.multimesh.visible_instance_count = 0
	Log.info("BloodDecals ready", {"texture_variants": _managers.size()})

func spawn_blood_at_position(origin: Vector3, spray_direction: Vector3, is_death: bool = false) -> void:
	if _managers.is_empty():
		return
	var num_rays = 12 if is_death else 5
	var scale_mult = DEATH_SCALE_MULT if is_death else 1.0
	var cast_distance = DEATH_RAYCAST_DISTANCE if is_death else DAMAGE_RAYCAST_DISTANCE

	# Cast from torso height to splash around the enemy onto nearby walls/floor.
	var cast_origin = origin + Vector3.UP * 0.8
	var base_dir := spray_direction.normalized() if not spray_direction.is_zero_approx() else Vector3.ZERO

	for i in range(num_rays):
		var random_dir = Vector3(
			randf_range(-0.8, 0.8),
			randf_range(-0.7, 0.15),
			randf_range(-0.8, 0.8)
		).normalized()
		var direction = random_dir if base_dir == Vector3.ZERO else (random_dir * 0.9 + base_dir * 0.1).normalized()
		var query = PhysicsRayQueryParameters3D.create(
			cast_origin,
			cast_origin + direction * cast_distance
		)
		query.collision_mask = 1
		var result = get_world_3d().direct_space_state.intersect_ray(query)
		if result:
			var decal_scale = randf_range(DAMAGE_SCALE_MIN, DAMAGE_SCALE_MAX) * scale_mult
			_spawn_single_decal(result.position, result.normal, decal_scale)

func _spawn_single_decal(pos: Vector3, normal: Vector3, decal_scale: float) -> void:
	var mi = randi() % _managers.size()
	var mgr: DecalInstanceCompatibility = _managers[mi]
	var idx = _indices[mi]
	var world_decal_transform = _make_transform(pos, normal, decal_scale)
	var local_decal_transform = mgr.global_transform.affine_inverse() * world_decal_transform

	mgr.multimesh.set_instance_transform(idx, local_decal_transform)
	mgr.reset_instance(idx)
	mgr.fade_out_instance(idx, 3.0, BLOOD_LIFETIME - 3.0)

	_indices[mi] = (idx + 1) % mgr.instance_count
	if mgr.multimesh.visible_instance_count < mgr.instance_count:
		mgr.multimesh.visible_instance_count += 1

func _make_transform(pos: Vector3, normal: Vector3, decal_scale: float) -> Transform3D:
	var y_axis = normal.normalized() if not normal.is_zero_approx() else Vector3.UP
	var ref = Vector3.RIGHT if abs(y_axis.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var x_axis = ref.cross(y_axis).normalized()
	var z_axis = x_axis.cross(y_axis).normalized()
	var spin = randf() * TAU
	var rx = x_axis * cos(spin) + z_axis * sin(spin)
	var rz = -x_axis * sin(spin) + z_axis * cos(spin)
	var b = Basis(rx, y_axis, rz).scaled(Vector3.ONE * decal_scale)
	# Push slightly into the surface so the decal box always intersects geometry.
	return Transform3D(b, pos - y_axis * SURFACE_PENETRATION)
