class_name BulletDecalPool

const MAX_BULLET_DECALS = 20
const DECAL_LIFETIME = 8.0
const DECAL_SCENE = "res://scenes/weapons/bullet_decal.tscn"

static var decal_pool := []
static var pool_initialized := false

static func initialize_pool(parent: Node3D) -> void:
	"""Pre-spawn all decals upfront to avoid lag on first fire"""
	if pool_initialized:
		return
	
	print("Initializing bullet decal pool with ", MAX_BULLET_DECALS, " decals")
	for i in range(MAX_BULLET_DECALS):
		var decal = preload(DECAL_SCENE).instantiate()
		parent.add_child.call_deferred(decal)
		decal.hide()
		decal_pool.append(decal)
	
	pool_initialized = true

static func spawn_bullet_decal(global_pos: Vector3, normal: Vector3, parent: Node3D) -> Node3D:
	"""
	Spawns a bullet decal at the given position and normal.
	Uses object pooling to avoid garbage collection spikes.
	"""
	# Initialize pool on first use
	if not pool_initialized:
		initialize_pool(parent)
	
	var decal_instance: Node3D
	
	# Get decal from pool (recycle oldest)
	if len(decal_pool) > 0:
		decal_instance = decal_pool.pop_front()
		decal_pool.push_back(decal_instance)
	else:
		print("ERROR: Decal pool empty!")
		return null
	
	# Reset and setup the decal
	decal_instance.show()
	if decal_instance.has_method("setup_decal"):
		decal_instance.setup_decal(global_pos, normal)
	
	# Schedule removal after lifetime
	_schedule_decal_removal(decal_instance)
	
	return decal_instance

static func _schedule_decal_removal(decal: Node3D) -> void:
	"""Schedule a decal to be hidden and reused after its lifetime"""
	# Create a new timer for this decal
	var timer = decal.get_tree().create_timer(DECAL_LIFETIME)
	timer.timeout.connect(func(): _on_decal_lifetime_expired(decal))

static func _on_decal_lifetime_expired(decal: Node3D) -> void:
	"""Called when a decal's lifetime expires"""
	if is_instance_valid(decal):
		decal.hide()
