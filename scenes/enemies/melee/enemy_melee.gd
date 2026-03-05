extends BaseEnemy
class_name MeleeEnemy

# Flank & Avoidance
@export var flank_radius: float = 3.0  # Distance offset from player
@export var flank_update_interval: float = 1.0  # How often to pick new flank position
@export var avoid_radius: float = 2.0  # Distance to avoid other enemies
@export var avoid_strength: float = 0.5  # How much to weight avoidance

# Lunge
@export var lunge_distance: float = 3.0  # Distance to trigger lunge
@export var lunge_speed_multiplier: float = 1.8  # How much faster when lunging

var flank_offset: Vector3 = Vector3.ZERO
var flank_timer: float = 0.0
var nearby_enemies: Array[BaseEnemy] = []

func _ready() -> void:
	super._ready()
	_pick_new_flank_offset()

func _physics_process(delta: float) -> void:
	if is_dead or is_stunned or player == null:
		return

	# Update flank target periodically
	flank_timer += delta
	if flank_timer >= flank_update_interval:
		flank_timer = 0.0
		_pick_new_flank_offset()
	
	# Find nearby enemies for avoidance
	_update_nearby_enemies()
	
	# Determine target position (flank + avoidance)
	var flank_target = player.global_position + flank_offset
	var avoidance_adjustment = _calculate_avoidance_adjustment()
	var target_pos = flank_target + avoidance_adjustment
	
	# Only update nav target if it changed significantly
	if nav_agent.target_position.distance_to(target_pos) > 1.0:
		nav_agent.target_position = target_pos

	if nav_agent.is_navigation_finished():
		# Gradually slow down to a stop (Friction)
		velocity = velocity.lerp(Vector3.ZERO, acceleration * delta)
	else:
		var next_path_pos = nav_agent.get_next_path_position()
		
		# Clamp to horizontal movement only
		var dir = next_path_pos - global_position
		dir.y = 0

		if dir.length() > 0.01:
			dir = dir.normalized()
			
			# Calculate current speed based on distance to player (lunge when close)
			var distance_to_player = global_position.distance_to(player.global_position)
			var current_move_speed = move_speed
			if distance_to_player < lunge_distance:
				current_move_speed = move_speed * lunge_speed_multiplier

			# Target velocity is where we WANT to be
			var target_velocity = dir * current_move_speed
			
			# lerp() smooths the transition from current velocity to target
			velocity = velocity.lerp(target_velocity, acceleration * delta)

			# Rotation: Smoothly look toward the movement direction
			var look_target = Vector3(next_path_pos.x, global_position.y, next_path_pos.z)
			if global_position.distance_to(look_target) > 0.1:
				look_at(look_target, Vector3.UP)

	move_and_slide()

func _pick_new_flank_offset() -> void:
	# Random angle around the player (0 to 2π)
	var angle = randf() * TAU
	flank_offset = Vector3(cos(angle), 0, sin(angle)) * flank_radius

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
