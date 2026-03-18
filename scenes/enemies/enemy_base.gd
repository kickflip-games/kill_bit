extends CharacterBody3D
class_name BaseEnemy

const FLOOR_SNAP_LENGTH: float = 0.35
const ENEMIES_GROUP: StringName = &"enemies"
const ANIM_IDLE: StringName = &"idle"
const ANIM_TAKE_DAMAGE: StringName = &"take_damage"
const ANIM_DIE: StringName = &"die"
const WAYPOINT_STUCK_THRESHOLD: float = 0.5

enum MovementType {
	STATIONARY,  ## No movement
	DIRECT,      ## Move directly toward player
	FLANK,       ## Circle around player with random offset (melee/zombie)
	STRAFE       ## Orbit player while maintaining distance (shooter)
}

@export_group("Base Stats")
@export var move_speed = 2.5
@export var acceleration = 5.0
@export var blood_spray_cooldown = 0.2  # Cooldown between damage blood sprays
@export var hit_stun_duration: float = 0.2
@export var is_procedural: bool = false

@export_group("Stagger")
@export var stagger_hp_ratio: float = 0.5  ## HP fraction at which enemy staggers
@export var stagger_duration: float = 3.0  ## Seconds stagger window stays open

@export_group("Movement")
@export var movement_type: MovementType = MovementType.DIRECT

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
@onready var stagger_outline: Sprite3D = get_node_or_null("StaggerOutline")

var player : Node3D
var is_dead : bool = false
var is_stunned : bool = false
var is_staggered : bool = false
var damage_taken : float = 0.0  # Track total damage for blood intensity
var last_blood_spray_time : float = -1.0  # Cooldown tracker
var _stagger_tween: Tween = null
var _hit_flash_tween: Tween = null
var _stagger_blocked: bool = false  # Set during splash damage to suppress stagger
var _knockback_velocity: Vector3 = Vector3.ZERO
var _camera: Camera3D = null

# Movement state
var flank_offset: Vector3 = Vector3.ZERO
var flank_timer: float = 0.0
var strafe_angle: float = 0.0
var strafe_direction: float = 1.0
var strafe_speed: float = 2.0
var _gravity: float = 9.8

func _ready() -> void:
	add_to_group(ENEMIES_GROUP)
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	floor_snap_length = FLOOR_SNAP_LENGTH
	_camera = get_viewport().get_camera_3d()

	assert(nav_agent != null, "NavigationAgent3D not found on enemy!")

	if player == null:
		player = get_tree().get_first_node_in_group("player")

	if anim_player.has_animation(ANIM_IDLE):
		anim_player.play(ANIM_IDLE)

	health.died.connect(_on_health_died)
	health.damaged.connect(_on_health_damaged)

	_init_movement()
	call_deferred("_setup_navigation")

	if is_procedural:
		setup_as_sleeper()

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

func _set_hurtbox_enabled(enabled: bool) -> void:
	var hurtbox := get_node_or_null("Hurtbox") as Area3D
	if hurtbox:
		hurtbox.set_deferred("monitoring", enabled)

func setup_as_sleeper() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	hide()
	velocity.x = 0.0
	velocity.z = 0.0
	_set_hurtbox_enabled(false)

func wake_from_sleeper() -> void:
	if is_dead:
		return
	process_mode = Node.PROCESS_MODE_INHERIT
	show()
	_set_hurtbox_enabled(true)
	if anim_player and anim_player.has_animation(ANIM_IDLE):
		anim_player.play(ANIM_IDLE)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_apply_gravity(delta)

	if not is_stunned and player != null and movement_type != MovementType.STATIONARY:
		var target_pos = _calculate_target_position(delta)

		if nav_agent.target_position.distance_to(target_pos) > 1.0:
			nav_agent.target_position = target_pos

		_execute_movement(delta)
	else:
		_apply_horizontal_damping(delta)

	if _knockback_velocity.length() > 0.1:
		velocity += _knockback_velocity
		_knockback_velocity = _knockback_velocity.lerp(Vector3.ZERO, 10.0 * delta)
	else:
		_knockback_velocity = Vector3.ZERO

	_face_sprite_to_camera()
	move_and_slide()

func _face_sprite_to_camera() -> void:
	if _camera == null:
		return

	var sprite_pos := sprite_3d.global_position
	var camera_pos := _camera.global_position
	var target_pos := Vector3(camera_pos.x, sprite_pos.y, camera_pos.z)
	if sprite_pos.distance_squared_to(target_pos) < 0.0001:
		return

	sprite_3d.look_at(target_pos, Vector3.UP, true)
	if stagger_outline:
		stagger_outline.look_at(target_pos, Vector3.UP, true)

func _calculate_target_position(delta: float) -> Vector3:
	match movement_type:
		MovementType.DIRECT:
			return player.global_position

		MovementType.FLANK:
			flank_timer += delta
			if flank_timer >= flank_update_interval:
				flank_timer = 0.0
				_pick_new_flank_offset()
			return player.global_position + flank_offset

		MovementType.STRAFE:
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

	var my_pos_2d = Vector3(global_position.x, 0, global_position.z)
	var next_pos_2d = Vector3(next_path_pos.x, 0, next_path_pos.z)
	var dir = next_pos_2d - my_pos_2d

	# If waypoint is stuck, move directly toward target
	if dir.length() < WAYPOINT_STUCK_THRESHOLD:
		var target_2d = Vector3(nav_agent.target_position.x, 0, nav_agent.target_position.z)
		dir = target_2d - my_pos_2d

	if dir.length() > WAYPOINT_STUCK_THRESHOLD:
		dir = dir.normalized()

		var current_speed = move_speed
		if movement_type == MovementType.FLANK:
			if global_position.distance_squared_to(player.global_position) < lunge_distance * lunge_distance:
				current_speed = move_speed * lunge_speed_multiplier

		var target_velocity = dir * current_speed
		var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
		horizontal_velocity = horizontal_velocity.lerp(target_velocity, acceleration * delta)
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z
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


func take_damage(amount):
	if is_dead: return
	damage_taken += amount
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
	if _hit_flash_tween:
		_hit_flash_tween.kill()
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(mat, "shader_parameter/active", 0.0, 0.15).set_ease(Tween.EASE_OUT)

func _apply_hit_stun():
	is_stunned = true
	velocity.x = 0.0
	velocity.z = 0.0
	if anim_player.has_animation(ANIM_TAKE_DAMAGE):
		anim_player.play(ANIM_TAKE_DAMAGE)
	await get_tree().create_timer(hit_stun_duration).timeout
	if not is_dead:
		is_stunned = false
		if anim_player.has_animation(ANIM_IDLE):
			anim_player.play(ANIM_IDLE)

	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_blood_spray_time >= blood_spray_cooldown:
		last_blood_spray_time = current_time
		var damage_direction = (player.global_position - global_position).normalized() if player else Vector3.FORWARD
		FXManager.play_enemy_take_damage_fx(global_transform, damage_direction)

func _on_health_died():
	die()

func _on_health_damaged() -> void:
	if _stagger_blocked or is_staggered or is_dead:
		return
	if health.current_health <= health.max_health * stagger_hp_ratio:
		stagger()

func apply_splash_damage(amount: int) -> void:
	_stagger_blocked = true
	take_damage(amount)
	_stagger_blocked = false

func apply_knockback(impulse: Vector3) -> void:
	_knockback_velocity += impulse

func stagger() -> void:
	if is_staggered or is_dead:
		return
	is_staggered = true
	Log.dbg("Enemy staggered", {"enemy": name, "hp": health.current_health})

	if stagger_outline:
		stagger_outline.show()

	var mat := sprite_3d.material_override as ShaderMaterial
	if mat:
		mat.set_shader_parameter("flash_color", Color(1.0, 0.0, 0.0, 1.0))
		_stagger_tween = create_tween().set_loops()
		_stagger_tween.tween_property(mat, "shader_parameter/active", 0.8, 0.3)
		_stagger_tween.tween_property(mat, "shader_parameter/active", 0.15, 0.3)

	get_tree().create_timer(stagger_duration).timeout.connect(
		func(): if is_instance_valid(self) and is_staggered: unstagger()
	)

func unstagger() -> void:
	if not is_staggered:
		return
	is_staggered = false

	if stagger_outline:
		stagger_outline.hide()

	if _stagger_tween:
		_stagger_tween.kill()
		_stagger_tween = null

	var mat := sprite_3d.material_override as ShaderMaterial
	if mat:
		mat.set_shader_parameter("active", 0.0)
		mat.set_shader_parameter("flash_color", Color(1.0, 1.0, 1.0, 1.0))

func die():
	is_dead = true
	unstagger()
	Log.info("Enemy died", {"enemy": name, "total_damage_taken": damage_taken, "kill_count": GameManager.kill_count + 1})
	GameManager.register_kill()
	SoundManager.play_enemy_death()
	collision_layer = 0
	collision_mask = 0
	_set_hurtbox_enabled(false)

	var death_direction = (player.global_position - global_position).normalized() if player else Vector3.FORWARD
	FXManager.play_enemy_death_fx(global_transform, death_direction)

	anim_player.play(ANIM_DIE)
	await anim_player.animation_finished
	queue_free()
