extends Weapon

@export var damage = 1
@export var fire_rate = 0.3

@onready var raycast = $RayCast3D
var can_fire = true

func _ready():
	super._ready()
	# Initialize decal pool after tree is ready
	call_deferred("_init_decal_pool")

func _init_decal_pool():
	"""Initialize both bullet and blood decal pools after tree is ready"""
	var scene_root = get_tree().current_scene
	BulletDecalPool.initialize_pool(scene_root)
	BloodDecalPool.initialize_pool(scene_root)

func fire():
	if not can_fire or not can_shoot():
		return
		
	can_fire = false
	consume_ammo()
	
	raycast.force_raycast_update()
	if raycast.is_colliding():
		var target = raycast.get_collider()
		if target.has_method("take_damage"):
			Log.dbg("Player hit enemy", {"target": target.name, "damage": damage})
			target.take_damage(damage)

		# Spawn bullet decal on hit surface
		_spawn_bullet_decal()
	
	SoundManager.play_sfx(SoundManager.SFX_PLAYER_SHOOTS)
	fired.emit()

	await get_tree().create_timer(fire_rate).timeout
	can_fire = true

func _spawn_bullet_decal() -> void:
	"""Spawn a bullet decal at the raycast hit point"""
	var hit_collider = raycast.get_collider()
	
	# Only spawn decals on walls/environment, not on enemies
	if hit_collider.has_method("take_damage"):
		return
	SoundManager.play_sfx(SoundManager.SFX_BULLET_ENV)
	
	var hit_pos = raycast.get_collision_point()
	var hit_normal = raycast.get_collision_normal()
	
	# Spawn decal as a child of current scene root (level)
	BulletDecalPool.spawn_bullet_decal(hit_pos, hit_normal, get_tree().current_scene)
