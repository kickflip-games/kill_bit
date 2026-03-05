extends BaseEnemy
class_name EnemyShooter

const BULLET_SCENE = preload("res://scenes/enemies/shooter/projectile/bullet.tscn")

@export var fire_rate = 2.0  # Seconds between shots
@export var optimal_distance = 15.0  # Distance shooter prefers to maintain from player
@export var stop_distance = 0.5  # Distance threshold to stop moving

var can_shoot = true

func _ready() -> void:
	super._ready()
	# Add idle animation if it exists
	if anim_player.has_animation("idle"):
		anim_player.play("idle")

func _physics_process(delta: float) -> void:
	if is_dead or is_stunned or player == null:
		return

	nav_agent.target_position = player.global_position
	
	var distance_to_player = global_position.distance_to(player.global_position)

	if nav_agent.is_navigation_finished() or distance_to_player < stop_distance:
		# Stop moving - at optimal distance or close enough
		velocity = velocity.lerp(Vector3.ZERO, acceleration * delta)
	else:
		# Move towards player
		var next_path_pos = nav_agent.get_next_path_position()
		var dir = global_position.direction_to(next_path_pos)
		dir.y = 0  # Keep movement horizontal
		dir = dir.normalized()

		var target_velocity = dir * move_speed
		velocity = velocity.lerp(target_velocity, acceleration * delta)

		# Look toward the movement direction
		var look_target = Vector3(next_path_pos.x, global_position.y, next_path_pos.z)
		if global_position.distance_to(look_target) > 0.1:
			look_at(look_target, Vector3.UP)

	# Look at the player
	var player_look_pos = player.global_position
	player_look_pos.y = global_position.y  # Keep looking level
	if global_position.distance_to(player_look_pos) > 0.1:
		look_at(player_look_pos, Vector3.UP)

	# Try to shoot
	if can_shoot:
		_shoot()

	move_and_slide()

func _shoot() -> void:
	"""Spawn a bullet aimed at the player"""
	can_shoot = false
	
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
