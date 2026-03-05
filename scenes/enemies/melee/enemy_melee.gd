extends BaseEnemy
class_name MeleeEnemy


func _physics_process(delta: float) -> void:
	if is_dead or is_stunned or player == null:
		return

	nav_agent.target_position = player.global_position

	if nav_agent.is_navigation_finished():
		# Gradually slow down to a stop (Friction)
		velocity = velocity.lerp(Vector3.ZERO, acceleration * delta)
	else:
		var next_path_pos = nav_agent.get_next_path_position()
		var dir = global_position.direction_to(next_path_pos)
		dir.y = 0
		dir = dir.normalized()

		# Target velocity is where we WANT to be
		var target_velocity = dir * move_speed
		
		# lerp() smooths the transition from current velocity to target
		velocity = velocity.lerp(target_velocity, acceleration * delta)

		# Rotation: Smoothly look toward the movement direction
		var look_target = Vector3(next_path_pos.x, global_position.y, next_path_pos.z)
		if global_position.distance_to(look_target) > 0.1:
			# Use lerp_angle or look_at; for zombies, look_at is usually fine
			look_at(look_target, Vector3.UP)

	move_and_slide()
