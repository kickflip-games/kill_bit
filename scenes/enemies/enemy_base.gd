extends CharacterBody3D
class_name BaseEnemy

const FLOOR_SNAP_LENGTH: float = 0.35

enum MovementType {
	STATIONARY,  ## No movement
	DIRECT,      ## Move directly toward player
	FLANK,       ## Circle around player with random offset (melee/zombie)
	STRAFE       ## Orbit player while maintaining distance (shooter)
}

@export_group("Base Stats")
@export var move_speed = 1.5
@export var acceleration = 3.0
@export var blood_spray_cooldown = 0.2  # Cooldown between damage blood sprays
@export var hit_stun_duration: float = 0.2

@export_group("Movement")
@export var movement_type: MovementType = MovementType.DIRECT
@export var avoid_radius: float = 2.0  ## Distance to avoid other enemies
@export var avoid_strength: float = 0.5  ## How much to weight avoidance

@export_group("Flank Movement (Melee/Zombie)")
@export var flank_radius: float = 3.0  ## Distance offset from player
@export var flank_update_interval: float = 1.0  ## How often to pick new flank position
@export var lunge_distance: float = 3.0  ## Distance to trigger lunge
@export var lunge_speed_multiplier: float = 1.8  ## Speed increase when lunging

@export_group("Strafe Movement (Shooter)")
@export var strafe_radius: float = 5.0  ## How far to orbit from the player
@export var strafe_speed_min: float = 1.5  ## Min rotation speed (radians/sec)
@export var strafe_speed_max: float = 2.5  ## Max rotation speed (radians/sec)

@onready var anim_player = $AnimationPlayer
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health = $Health
@onready var hit_particles: GPUParticles3D = get_node_or_null("HitParticles")
@onready var sprite_3d: Sprite3D = $Sprite3D

var player : Node3D
var is_dead : bool = false
var is_stunned : bool = false
var damage_taken : float = 0.0  # Track total damage for blood intensity
var last_blood_spray_time : float = -1.0  # Cooldown tracker

# Movement state
var nearby_enemies: Array[BaseEnemy] = []
var flank_offset: Vector3 = Vector3.ZERO
var flank_timer: float = 0.0
var strafe_angle: float = 0.0
var strafe_direction: float = 1.0
var strafe_speed: float = 2.0
var _gravity: float = 9.8

func _ready() -> void:
	# Add to enemies group for GameManager communication
	add_to_group("enemies")
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	floor_snap_length = FLOOR_SNAP_LENGTH
	
	# Validate nav agent exists
	assert(nav_agent != null, "NavigationAgent3D not found on enemy!")
	
	# Fallback player lookup if not set yet
	if player == null:
		player = get_tree().get_first_node_in_group("player")
	
	if anim_player.has_animation("idle"):
		anim_player.play("idle")
	
	# Connect health signals
	health.died.connect(_on_health_died)
	
	# Initialize movement based on type
	_init_movement()
	
	# Setup navigation
	call_deferred("_setup_navigation")

func _setup_navigation():
	await get_tree().physics_frame
	nav_agent.path_desired_distance = 0.5
	nav_agent.target_desired_distance = 0.5

func _init_movement():
	match movement_type:
		MovementType.FLANK:
			_pick_new_flank_offset()
		MovementType.STRAFE:
			strafe_direction = 1.0 if randf() > 0.5 else -1.0
			strafe_speed = randf_range(strafe_speed_min, strafe_speed_max)

func set_player(p):
	player = p

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	
	_apply_gravity(delta)
	
	if not is_stunned and player != null and movement_type != MovementType.STATIONARY:
		# Calculate target position based on movement type
		var target_pos = _calculate_target_position(delta)
		
		# Find nearby enemies for avoidance
		_update_nearby_enemies()
		
		# Apply avoidance
		var avoidance = _calculate_avoidance_adjustment()
		target_pos += avoidance
		
		# Update navigation target (only if changed significantly)
		if nav_agent.target_position.distance_to(target_pos) > 1.0:
			nav_agent.target_position = target_pos
		
		# Execute movement
		_execute_movement(delta)
	else:
		_apply_horizontal_damping(delta)
	
	move_and_slide()

func _calculate_target_position(delta: float) -> Vector3:
	match movement_type:
		MovementType.DIRECT:
			return player.global_position
		
		MovementType.FLANK:
			# Update flank offset periodically
			flank_timer += delta
			if flank_timer >= flank_update_interval:
				flank_timer = 0.0
				_pick_new_flank_offset()
			return player.global_position + flank_offset
		
		MovementType.STRAFE:
			# Continuous orbit
			strafe_angle += strafe_speed * strafe_direction * delta
			var strafe_offset = Vector3(
				cos(strafe_angle) * strafe_radius,
				0,
				sin(strafe_angle) * strafe_radius
			)
			return player.global_position + strafe_offset
	
	return player.global_position

func _execute_movement(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		_apply_horizontal_damping(delta)
		return
	
	var next_path_pos = nav_agent.get_next_path_position()
	
	# Calculate horizontal direction (project to XZ plane)
	var my_pos_2d = Vector3(global_position.x, 0, global_position.z)
	var next_pos_2d = Vector3(next_path_pos.x, 0, next_path_pos.z)
	var dir = next_pos_2d - my_pos_2d
	
	# If waypoint is stuck, move directly toward target
	if dir.length() < 0.5:
		var target_2d = Vector3(nav_agent.target_position.x, 0, nav_agent.target_position.z)
		dir = target_2d - my_pos_2d
	
	if dir.length() > 0.5:
		dir = dir.normalized()
		
		# Apply lunge speed boost for FLANK movement
		var current_speed = move_speed
		if movement_type == MovementType.FLANK:
			var distance_to_player = global_position.distance_to(player.global_position)
			if distance_to_player < lunge_distance:
				current_speed = move_speed * lunge_speed_multiplier
		
		var target_velocity = dir * current_speed
		var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
		horizontal_velocity = horizontal_velocity.lerp(target_velocity, acceleration * delta)
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z
		
		# No rotation needed - billboard sprites automatically face the camera
	else:
		_apply_horizontal_damping(delta)

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta

func _apply_horizontal_damping(delta: float) -> void:
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, acceleration * delta)
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

func _pick_new_flank_offset() -> void:
	var angle = randf() * TAU
	flank_offset = Vector3(cos(angle), 0, sin(angle)) * flank_radius

func _update_nearby_enemies() -> void:
	nearby_enemies.clear()
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
	
	for enemy in nearby_enemies:
		var away_from = global_position.direction_to(enemy.global_position) * -1
		adjustment += away_from
	
	adjustment = (adjustment / nearby_enemies.size()) * avoid_strength
	adjustment.y = 0
	return adjustment

func take_damage(amount):
	if is_dead: return
	damage_taken += amount  # Track total damage taken
	if hit_particles:
		hit_particles.restart()
		hit_particles.emitting = true
	health.take_damage(amount)
	Log.dbg("Enemy took damage", {"enemy": name, "amount": amount, "hp_remaining": health.current_health})
	SoundManager.play_sfx(SoundManager.SFX_PLAYER_HIT_ENEMY)
	SoundManager.play_sfx(SoundManager.SFX_ENEMY_TAKES_DAMAGE)
	_apply_hit_stun()
	_play_hit_flash()

func _play_hit_flash() -> void:
	var mat := sprite_3d.material_override as ShaderMaterial
	if not mat:
		return
	mat.set_shader_parameter("active", 1.0)
	var tween := create_tween()
	tween.tween_property(mat, "shader_parameter/active", 0.0, 0.15).set_ease(Tween.EASE_OUT)

func _apply_hit_stun():
	is_stunned = true
	velocity.x = 0.0
	velocity.z = 0.0
	if anim_player.has_animation("take_damage"):
		anim_player.play("take_damage")
	await get_tree().create_timer(hit_stun_duration).timeout
	if not is_dead:
		is_stunned = false
		if anim_player.has_animation("idle"):
			anim_player.play("idle")
	
	# Spawn small blood splatter when damaged (with cooldown to avoid spam)
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_blood_spray_time >= blood_spray_cooldown:
		last_blood_spray_time = current_time
		var damage_direction = (player.global_position - global_position).normalized() if player else Vector3.FORWARD
		FXManager.play_enemy_take_damage_fx(global_transform, damage_direction)

func _on_health_died():
	die()

func die():
	is_dead = true
	Log.info("Enemy died", {"enemy": name, "total_damage_taken": damage_taken, "kill_count": GameManager.kill_count + 1})
	GameManager.register_kill()
	SoundManager.play_enemy_death()
	# Disable collision so the player can walk through the "corpse"
	collision_layer = 0
	collision_mask = 0
	# Disable hurtbox so it stops dealing damage during the die animation
	var hurtbox = get_node_or_null("Hurtbox")
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
	
	var death_direction = (player.global_position - global_position).normalized() if player else Vector3.FORWARD
	FXManager.play_enemy_death_fx(global_transform, death_direction)
	
	anim_player.play("die")
	await anim_player.animation_finished
	queue_free()
