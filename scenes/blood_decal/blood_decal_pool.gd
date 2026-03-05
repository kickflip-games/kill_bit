class_name BloodDecalPool

const MAX_BLOOD_DECALS = 30
const BLOOD_LIFETIME = 15.0
const BLOOD_SCENE = "res://scenes/blood_decal/blood_decal.tscn"
const RAYCAST_DISTANCE = 2.0

static var decal_pool := []
static var pool_initialized := false

static func initialize_pool(parent: Node3D) -> void:
	"""Pre-spawn all blood decals upfront"""
	if pool_initialized:
		# After a scene reload the nodes are freed but statics persist — detect and reset
		if decal_pool.size() > 0 and not is_instance_valid(decal_pool[0]):
			decal_pool.clear()
			pool_initialized = false
		else:
			return
	
	print("Initializing blood decal pool with ", MAX_BLOOD_DECALS, " decals")
	for i in range(MAX_BLOOD_DECALS):
		var decal = preload(BLOOD_SCENE).instantiate()
		parent.add_child.call_deferred(decal)
		decal.hide()
		decal_pool.append(decal)
	
	pool_initialized = true

static func spawn_blood_at_position(death_pos: Vector3, attacker_direction: Vector3, parent: Node3D, damage: float = 1.0) -> void:
	"""
	Spawn blood decals on floors and walls around a death position.
	
	Args:
		death_pos: Position where the enemy died
		attacker_direction: Direction the attacker was facing (for spray direction)
		parent: Scene root to add decals to
		damage: Damage amount (affects intensityscale)
	"""
	# Initialize pool on first use
	if not pool_initialized:
		initialize_pool(parent)
	
	# Clamp damage to intensity scale (0.5 to 2.0)
	var intensity = clamp(damage / 10.0, 0.5, 2.0)
	
	# Raycast downward for floor blood
	_try_spawn_floor_blood(death_pos, intensity, parent)
	
	# Raycast in multiple directions for wall/spray blood
	_try_spawn_spray_blood(death_pos, attacker_direction, intensity, parent)

static func _try_spawn_floor_blood(death_pos: Vector3, intensity: float, parent: Node3D) -> void:
	"""Cast downward to find floors and spawn pool blood"""
	var query = PhysicsRayQueryParameters3D.create(
		death_pos,
		death_pos + Vector3.DOWN * RAYCAST_DISTANCE
	)
	query.collision_mask = 1  # Only hit layer 0 (walls/environment)
	
	var result = PhysicsServer3D.space_get_direct_state(parent.get_world_3d().space).intersect_ray(query)
	
	if result:
		var hit_normal = result.normal
		_spawn_blood_decal(result.position, hit_normal, intensity, parent)

static func _try_spawn_spray_blood(death_pos: Vector3, attacker_direction: Vector3, intensity: float, parent: Node3D) -> void:
	"""Cast in multiple directions to find walls and spawn spray blood"""
	var spray_directions = [
		attacker_direction,
		attacker_direction.rotated(Vector3.UP, PI / 4),
		attacker_direction.rotated(Vector3.UP, -PI / 4),
		attacker_direction.rotated(Vector3.RIGHT, PI / 6),
		attacker_direction.rotated(Vector3.RIGHT, -PI / 6),
	]
	
	for direction in spray_directions:
		var query = PhysicsRayQueryParameters3D.create(
			death_pos,
			death_pos + direction.normalized() * RAYCAST_DISTANCE
		)
		query.collision_mask = 1  # Only hit layer 0 (walls/environment)
		
		var result = PhysicsServer3D.space_get_direct_state(parent.get_world_3d().space).intersect_ray(query)
		
		if result:
			var hit_normal = result.normal
			_spawn_blood_decal(result.position, hit_normal, intensity, parent)

static func _spawn_blood_decal(global_pos: Vector3, normal: Vector3, intensity: float, parent: Node3D) -> void:
	"""Get a blood decal from pool and spawn it"""
	if len(decal_pool) == 0:
		print("ERROR: Blood decal pool empty!")
		return
	
	# Get decal from pool (recycle oldest)
	var decal_instance = decal_pool.pop_front()
	decal_pool.push_back(decal_instance)

	if not is_instance_valid(decal_instance):
		return

	# Reset and setup the decal
	decal_instance.show()
	if decal_instance.has_method("setup_decal"):
		decal_instance.setup_decal(global_pos, normal, intensity)
	
	# Schedule removal after lifetime
	_schedule_blood_removal(decal_instance)

static func _schedule_blood_removal(decal: Node3D) -> void:
	"""Schedule a blood decal to be hidden and reused after its lifetime"""
	var timer = decal.get_tree().create_timer(BLOOD_LIFETIME)
	timer.timeout.connect(func(): _on_blood_lifetime_expired(decal))

static func _on_blood_lifetime_expired(decal: Node3D) -> void:
	"""Called when a blood decal's lifetime expires"""
	if is_instance_valid(decal):
		decal.hide()
