extends BaseEnemy
class_name EnemyShooter

const BULLET_SCENE = preload("res://scenes/enemies/shooter/projectile/bullet.tscn")

@export var fire_rate = 2.0  # Seconds between shots
@export var optimal_distance = 15.0  # Distance shooter prefers to maintain from player
@export var stop_distance = 0.5  # Distance threshold to stop moving
@export var strafe_radius: float = 5.0  # How far to strafe from the player
@export var avoid_radius: float = 2.0  # Distance to avoid other enemies
@export var avoid_strength: float = 0.5  # How much to weight avoidance

var can_shoot = true
var strafe_angle: float = 0.0
var strafe_direction: float = 1.0  # 1.0 or -1.0 for clockwise/counterclockwise
var strafe_speed: float = 1.0  # Radians per second
var nearby_enemies: Array[BaseEnemy] = []

func _ready() -> void:
	super._ready()
	# Randomize starting strafe direction
	strafe_direction = 1.0 if randf() > 0.5 else -1.0
	strafe_speed = randf_range(1.5, 2.5)  # Vary strafe speed per enemy
	# Add idle animation if it exists
	if anim_player.has_animation("idle"):
		anim_player.play("idle")

func _physics_process(delta: float) -> void:
	if is_dead or is_stunned or player == null:
		return

	# Update strafe angle (continuous orbit)
	strafe_angle += strafe_speed * strafe_direction * delta
	
	# Calculate strafe position around the player
	var strafe_offset = Vector3(
		cos(strafe_angle) * strafe_radius,
		0,
		sin(strafe_angle) * strafe_radius
	)
	var target_pos = player.global_position + strafe_offset
	
	# Find nearby enemies for avoidance
	_update_nearby_enemies()
	
	# Calculate avoidance adjustment
	var avoidance_adjustment = _calculate_avoidance_adjustment()
	
	# Final target with avoidance
	target_pos += avoidance_adjustment
	
	# Only update nav target if it changed significantly (don't spam path recalculation)
	if nav_agent.target_position.distance_to(target_pos) > 1.0:
		nav_agent.target_position = target_pos
	
	# Movement logic
	if nav_agent.is_navigation_finished():
		velocity = velocity.lerp(Vector3.ZERO, acceleration * delta)
	else:
		var next_path_pos = nav_agent.get_next_path_position()
		
		# Clamp to horizontal movement only
		var dir = next_path_pos - global_position
		dir.y = 0
		
		if dir.length() > 0.01:
			dir = dir.normalized()
			var target_velocity = dir * move_speed
			velocity = velocity.lerp(target_velocity, acceleration * delta)

	# Always look at the player (for aiming)
	var player_look_pos = Vector3(player.global_position.x, global_position.y, player.global_position.z)
	if global_position.distance_to(player_look_pos) > 0.1:
		look_at(player_look_pos, Vector3.UP)

	# Try to shoot (only if player is in line-of-sight)
	if can_shoot and _has_line_of_sight():
		_shoot()

	move_and_slide()

func _has_line_of_sight() -> bool:
	"""Check if the player is visible (not blocked by environment)"""
	var space_state = get_world_3d().direct_space_state
	var shoot_pos = global_position + Vector3(0, 0.5, 0)  # Shoot from mid-height
	var player_pos = player.global_position + Vector3(0, 0.5, 0)  # Aim at mid-height
	
	var query = PhysicsRayQueryParameters3D.create(shoot_pos, player_pos)
	query.collision_mask = 1  # Check against environment layer (adjust if needed)
	
	var result = space_state.intersect_ray(query)
	# If no collision, we have LOS. If collision exists but it's the player, we still have LOS.
	if result.is_empty():
		return true
	# Check if we hit the player
	return result.get("collider") == player

func _update_nearby_enemies() -> void:
	nearby_enemies.clear()
	# Find all other enemies in the scene
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy != self and enemy is BaseEnemy:
			var distance = global_position.distance_to(enemy.global_position)
			if distance < avoid_radius:
				nearby_enemies.append(enemy)

func _calculate_avoidance_adjustment() -> Vector3:
	var adjustment = Vector3.ZERO
	if nearby_enemies.is_empty():
		return adjustment
	
	# Push away from nearby enemies
	for enemy in nearby_enemies:
		var away_from = global_position.direction_to(enemy.global_position) * -1
		adjustment += away_from
	
	# Average and scale by avoidance strength
	adjustment = (adjustment / nearby_enemies.size()) * avoid_strength
	adjustment.y = 0  # Keep it horizontal
	return adjustment

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
