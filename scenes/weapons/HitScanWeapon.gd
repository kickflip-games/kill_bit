extends Weapon

@export var damage = 1
@export var fire_rate = 0.3
@export var tracer_start_offset := 0.25
@export var tracer_min_distance := 3.0
@export var hook_range: float = 20.0

const DECAL_LIFETIME = 8.0
const BULLET_TRACER_SCENE = preload("res://scenes/weapons/bullet_tracer.tscn")

@onready var raycast = $RayCast3D
@onready var bullet_decals_mesh:DecalInstanceCompatibility = $BulletDecals
@onready var camera: Camera3D = get_parent().get_node_or_null("Camera3D")

var can_fire = true
var _next_decal_index := 0
var _crosshair_target_staggered: bool = false
var _peek_frame: int = 0

func _ready() -> void:
	# Initialize bullet decals
	if bullet_decals_mesh and bullet_decals_mesh.multimesh:
		# Keep decals in world space; do not inherit weapon/camera movement.
		bullet_decals_mesh.top_level = true
		bullet_decals_mesh.multimesh.visible_instance_count = 0

func _process(_delta: float) -> void:
	# Throttled crosshair peek for HUD stagger feedback
	_peek_frame += 1
	if _peek_frame % 4 != 0 or not is_inside_tree() or get_world_3d() == null:
		return
	var shot := _perform_hitscan()
	_crosshair_target_staggered = (
		shot["hit"] and shot["collider"] != null
		and shot["collider"].get("is_staggered") == true
	)

func fire():
	Log.dbg("In wpn, firing starts")
	if not is_inside_tree() or not can_fire or not can_shoot():
		Log.dbg("Cant fire yet..")
		return

	var shot := _perform_hitscan()

	# Context logic: hook-smash if crosshair is on a staggered enemy in range
	if shot["hit"] and shot["collider"] != null:
		var target = shot["collider"]
		var player_node = get_parent()
		if (target.get("is_staggered") == true
				and player_node and player_node.has_method("hook_smash")
				and not player_node.is_hooking
				and shot["hit_point"].distance_to(player_node.global_position) <= hook_range):
			player_node.hook_smash(target)
			return  # No ammo cost, no fire cooldown

	can_fire = false
	consume_ammo()

	_create_tracer_effect(shot["origin"], shot["direction"], shot["hit_point"])

	if shot["hit"]:
		Log.dbg("Player hit enemy")
		var target = shot["collider"]
		if target.has_method("take_damage"):
			Log.dbg("Player hit enemy", {"target": target.name, "damage": damage})
			target.take_damage(damage)

		# Spawn bullet decal on hit surface
		_spawn_bullet_decal(shot["hit_point"], shot["hit_normal"], target)

	SoundManager.play_sfx(SoundManager.SFX_PLAYER_SHOOTS)
	fired.emit()
	Log.dbg("Player hit nothing")

	await get_tree().create_timer(fire_rate).timeout
	can_fire = true

func _perform_hitscan() -> Dictionary:
	if not is_inside_tree() or get_world_3d() == null:
		return {
			"origin": global_position,
			"direction": -global_basis.z.normalized(),
			"hit": false,
			"hit_point": global_position,
			"hit_normal": Vector3.ZERO,
			"collider": null
		}

	var origin: Vector3
	var direction: Vector3
	if camera and camera.is_inside_tree():
		var screen_center := camera.get_viewport().get_visible_rect().size * 0.5
		origin = camera.global_position
		direction = camera.project_ray_normal(screen_center).normalized()
	elif raycast and raycast.is_inside_tree():
		origin = raycast.global_position
		direction = -raycast.global_basis.z.normalized()
	else:
		origin = global_position
		direction = -global_basis.z.normalized()
	
	var ray_length:float = raycast.target_position.length() if raycast else 100.0
	if ray_length <= 0.0:
		ray_length = 100.0
	var end := origin + direction * ray_length
	
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	if raycast:
		query.collision_mask = raycast.collision_mask
		query.collide_with_areas = raycast.collide_with_areas
		query.collide_with_bodies = raycast.collide_with_bodies
	query.exclude = [self, get_parent()]
	
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		return {
			"origin": origin,
			"direction": direction,
			"hit": true,
			"hit_point": result.position,
			"hit_normal": result.normal,
			"collider": result.collider
		}
	
	return {
		"origin": origin,
		"direction": direction,
		"hit": false,
		"hit_point": end,
		"hit_normal": Vector3.ZERO,
		"collider": null
	}

func _spawn_bullet_decal(hit_pos: Vector3, hit_normal: Vector3, hit_collider: Object) -> void:
	# Only spawn decals on walls/environment, not on enemies
	if hit_collider and hit_collider.has_method("take_damage"):
		return
	
	SoundManager.play_sfx(SoundManager.SFX_BULLET_ENV)
	_add_bullet_decal(hit_pos, hit_normal)

func _add_bullet_decal(pos: Vector3, normal: Vector3) -> void:
	if not bullet_decals_mesh or not bullet_decals_mesh.multimesh:
		return
	if bullet_decals_mesh.multimesh.instance_count <= 0:
		return
	
	var current_index = _next_decal_index
	var s:float = bullet_decals_mesh.size.x
	var world_decal_transform = _make_decal_transform(pos, normal, s)
	var local_decal_transform = bullet_decals_mesh.global_transform.affine_inverse() * world_decal_transform
	bullet_decals_mesh.multimesh.set_instance_transform(current_index, local_decal_transform)
	bullet_decals_mesh.reset_instance(current_index)
	bullet_decals_mesh.fade_out_instance(current_index, 2.0, DECAL_LIFETIME - 2.0)
	if bullet_decals_mesh.multimesh.visible_instance_count < bullet_decals_mesh.multimesh.instance_count:
		bullet_decals_mesh.multimesh.visible_instance_count += 1
	_next_decal_index = (current_index + 1) % bullet_decals_mesh.multimesh.instance_count
	Log.dbg("Decal placed at", world_decal_transform)

func _make_decal_transform(pos: Vector3, normal: Vector3, decal_scale: float) -> Transform3D:
	var y_axis = normal
	var ref = Vector3.RIGHT if abs(normal.dot(Vector3.UP)) > 0.99 else Vector3.UP
	var x_axis = ref.cross(y_axis).normalized()
	var z_axis = x_axis.cross(y_axis).normalized()
	var spin = randf() * TAU
	var rx = x_axis * cos(spin) + z_axis * sin(spin)
	var rz = -x_axis * sin(spin) + z_axis * cos(spin)
	var b = Basis(rx, y_axis, rz).scaled(Vector3.ONE * decal_scale)
	return Transform3D(b, pos + normal * 0.01)

func _create_tracer_effect(start_origin: Vector3, shot_direction: Vector3, hit_point: Vector3) -> void:
	if not is_inside_tree():
		return

	var to_target := hit_point - start_origin
	if to_target.is_zero_approx():
		return
	var bullet_dir := shot_direction if not shot_direction.is_zero_approx() else to_target.normalized()
	var start_pos := start_origin + bullet_dir * tracer_start_offset
	if start_pos.distance_to(hit_point) <= tracer_min_distance:
		return
	
	var tracer = BULLET_TRACER_SCENE.instantiate()
	var tracer_parent := get_tree().current_scene if get_tree().current_scene else self
	tracer_parent.add_child(tracer)
	tracer.target_pos = hit_point
	tracer.look_at_from_position(start_pos, hit_point)
