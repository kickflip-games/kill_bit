extends BaseEnemy
class_name EnemyShooter

const BULLET_SCENE = preload("res://scenes/enemies/shooter/projectile/bullet.tscn")

@export var fire_rate = 2.0  # Seconds between shots

var can_shoot = true

func _ready() -> void:
	# Set movement type before parent initialization
	movement_type = MovementType.STRAFE
	super._ready()

func _physics_process(delta: float) -> void:
	# Call parent movement logic
	super._physics_process(delta)
	
	# Skip if dead/stunned/no player
	if is_dead or is_stunned or player == null:
		return
	
	# Always look at the player (for aiming) - strafe moves sideways but aims at player
	var player_look_pos = Vector3(player.global_position.x, global_position.y, player.global_position.z)
	if global_position.distance_to(player_look_pos) > 0.1:
		look_at(player_look_pos, Vector3.UP)
	
	# Try to shoot (only if player is in line-of-sight)
	if can_shoot and _has_line_of_sight():
		_shoot()

func _has_line_of_sight() -> bool:
	"""Check if the player is visible (not blocked by environment)"""
	var space_state = get_world_3d().direct_space_state
	var shoot_pos = global_position + Vector3(0, 0.5, 0)  # Shoot from mid-height
	var player_pos = player.global_position + Vector3(0, 0.5, 0)  # Aim at mid-height
	
	var query = PhysicsRayQueryParameters3D.create(shoot_pos, player_pos)
	query.collision_mask = 1  # Check against environment layer
	
	var result = space_state.intersect_ray(query)
	# If no collision, we have LOS. If collision exists but it's the player, we still have LOS.
	if result.is_empty():
		return true
	return result.get("collider") == player

func _shoot() -> void:
	"""Spawn a bullet aimed at the player"""
	can_shoot = false
	Log.dbg("Shooter fired", {"shooter": name, "dist": snappedf(global_position.distance_to(player.global_position), 0.1)})
	SoundManager.play_sfx(SoundManager.SFX_ENEMY_SHOOTS)

	# Play shoot animation if available
	if anim_player.has_animation("shoot"):
		anim_player.play("shoot")
	
	# Spawn bullet at shooter position
	var bullet = BULLET_SCENE.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position + Vector3(0, 0.5, 0)  # Spawn slightly above ground
	
	# Calculate direction to player
	var direction_to_player = (player.global_position - bullet.global_position).normalized()
	bullet.direction = direction_to_player
	
	# Wait before next shot
	await get_tree().create_timer(fire_rate).timeout
	can_shoot = true
