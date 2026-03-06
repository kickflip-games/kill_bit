extends Weapon

@export var damage = 1
@export var fire_rate = 0.3
@export var tracer_duration: float = 0.08  # How long the tracer stays visible

const DECAL_LIFETIME = 8.0
const TRACER_COLOR = Color.RED  # Fits Sin City aesthetic

@onready var raycast = $RayCast3D
@onready var bullet_decals_mesh:DecalInstanceCompatibility = $BulletDecals

var can_fire = true

func _ready() -> void:
	# Initialize bullet decals
	if bullet_decals_mesh and bullet_decals_mesh.multimesh:
		bullet_decals_mesh.multimesh.visible_instance_count = 0

func fire():
	Log.dbg("In wpn, firing starts")
	if not can_fire or not can_shoot():
		Log.dbg("Cant fire yet..")
		return
		
	can_fire = false
	consume_ammo()
	
	raycast.force_raycast_update()
	if raycast.is_colliding():
		Log.dbg("Player hit enemy")
		var target = raycast.get_collider()
		if target.has_method("take_damage"):
			Log.dbg("Player hit enemy", {"target": target.name, "damage": damage})
			target.take_damage(damage)

		# Spawn bullet decal on hit surface
		_spawn_bullet_decal()
	
	SoundManager.play_sfx(SoundManager.SFX_PLAYER_SHOOTS)
	fired.emit()
	Log.dbg("Player hit nothing")

	await get_tree().create_timer(fire_rate).timeout
	can_fire = true

func _spawn_bullet_decal() -> void:
	var hit_collider = raycast.get_collider()
	# Only spawn decals on walls/environment, not on enemies
	if hit_collider.has_method("take_damage"):
		return
	
	SoundManager.play_sfx(SoundManager.SFX_BULLET_ENV)
	
	var hit_pos = raycast.get_collision_point()
	var hit_normal = raycast.get_collision_normal()
	_add_bullet_decal(hit_pos, hit_normal)

func _add_bullet_decal(pos: Vector3, normal: Vector3) -> void:
	if not bullet_decals_mesh or not bullet_decals_mesh.multimesh:
		return
	
	# Use a circular buffer - reset when full
	var current_index = bullet_decals_mesh.multimesh.visible_instance_count
	if current_index >= bullet_decals_mesh.multimesh.instance_count:
		# Reset and start over
		bullet_decals_mesh.reset_all_instances()
		bullet_decals_mesh.multimesh.visible_instance_count = 0
		current_index = 0

	var s:float = bullet_decals_mesh.size.x
	var decal_transform = _make_decal_transform(pos, normal, s)
	bullet_decals_mesh.multimesh.set_instance_transform(current_index, decal_transform)
	bullet_decals_mesh.fade_out_instance(current_index, 2.0, DECAL_LIFETIME - 2.0)
	bullet_decals_mesh.multimesh.visible_instance_count += 1
	Log.dbg("Decal placed at", decal_transform)

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
