extends CharacterBody3D

const MAX_SPEED = 8.0
const ACCEL = 14.0
const FRICTION = 14.0
const MOUSE_SENS = 0.002
const FLOOR_SNAP_LENGTH: float = 0.35

const SHAKE_FIRE: float = 0.018
const SHAKE_DAMAGE: float = 0.05
const SHAKE_HOOK: float = 0.12
const SHAKE_DECAY: float = 8.0

const HOOK_SPEED: float = 38.0
const HOOK_ARRIVE_DIST: float = 1.2
const HOOK_RANGE: float = 20.0
const HOOK_SPLASH_RADIUS: float = 4.0
const HOOK_SPLASH_DAMAGE: int = 1
const HOOK_SPLASH_KNOCKBACK: float = 10.0
const HOOK_SLIDE_DURATION: float = 0.5
const HOOK_SLIDE_FRICTION: float = 1.5

const TILT_MAX: float = 0.25     # max tilt in radians (~14 degrees)
const TILT_LERP: float = 8.0
const TILT_MIN_SPEED: float = 6.5  # match speedlines threshold

# Pitch tilt on slopes/stairs — commented out for now (not clean enough)
#const PITCH_TILT_MAX: float = 0.15  # max pitch tilt in radians (~8.6 degrees)
#const PITCH_TILT_LERP: float = 6.0

const FOV_INCREASE: float = 10.0  # degrees added to FOV at max speed
const FOV_LERP: float = 5.0       # how fast FOV transitions

@onready var camera = $Camera3D
@onready var weapon = $Weapon
@onready var hud = $Hud
@onready var health = $Health

var input_dir = Vector3.ZERO
var gameplay_active = false
var is_hooking: bool = false
var _hook_target: Node3D = null
var _hook_slide_timer: float = 0.0
var _shake_strength: float = 0.0
var _camera_base_pos: Vector3
var camera_tilt: float = 0.0  # Exposed for HUD to sync gun rotation
var _base_fov: float = 75.0
var _gravity: float = 9.8

func _is_debug_fly_active() -> bool:
	var debug_fly_camera := get_node_or_null("/root/DebugFlyCamera")
	return debug_fly_camera != null and debug_fly_camera.has_method("is_active") and debug_fly_camera.is_active()

func _ready():
	add_to_group("player")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_gravity = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	floor_snap_length = FLOOR_SNAP_LENGTH
	_camera_base_pos = camera.position
	_base_fov = camera.fov
	weapon.fired.connect(hud._on_weapon_fired)
	weapon.fired.connect(func(): _shake_camera(SHAKE_FIRE))
	hud.start_game_requested.connect(_on_start_game_requested)
	hud.game_over.connect(_on_game_over)

func _process(delta: float) -> void:
	# Camera shake
	if _shake_strength > 0.0:
		_shake_strength = lerpf(_shake_strength, 0.0, SHAKE_DECAY * delta)
		if _shake_strength < 0.001:
			_shake_strength = 0.0
		camera.position = _camera_base_pos + Vector3(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength),
			0.0
		)
	else:
		camera.position = _camera_base_pos
	
	# Camera tilt/roll while strafing (left/right movement).
	if gameplay_active:
		var speed = velocity.length()
		var tilt_speed_factor = clampf(remap(speed, TILT_MIN_SPEED, MAX_SPEED, 0.0, 1.0), 0.0, 1.0)
		var local_velocity = global_transform.basis.inverse() * velocity
		var strafe_factor = clampf(local_velocity.x / MAX_SPEED, -1.0, 1.0)
		var target_tilt = -strafe_factor * TILT_MAX * tilt_speed_factor
		camera_tilt = lerpf(camera_tilt, target_tilt, TILT_LERP * delta)
		camera.rotation.z = camera_tilt
		
		# Camera pitch down on slopes/stairs — commented out (not clean enough)
		#if is_on_floor():
		#	var floor_normal = get_floor_normal()
		#	# Calculate pitch angle from floor normal (positive = looking down)
		#	var pitch_angle = atan2(floor_normal.z, floor_normal.y) - PI/2
		#	var target_pitch = clampf(pitch_angle, -PITCH_TILT_MAX, PITCH_TILT_MAX)
		#	camera.rotation.x = lerpf(camera.rotation.x, target_pitch, PITCH_TILT_LERP * delta)
		#else:
		#	camera.rotation.x = lerpf(camera.rotation.x, 0.0, PITCH_TILT_LERP * delta)
		
		# Dynamic FOV based on speed
		var speed_factor = clampf(speed / MAX_SPEED, 0.0, 1.0)
		var target_fov = _base_fov + (FOV_INCREASE * speed_factor)
		camera.fov = lerpf(camera.fov, target_fov, FOV_LERP * delta)
	else:
		# Reset tilt and FOV when not in gameplay
		camera_tilt = 0.0
		camera.rotation.z = 0.0
		camera.fov = _base_fov

func _shake_camera(strength: float) -> void:
	_shake_strength = maxf(_shake_strength, strength)

func take_damage(amount):
	if not gameplay_active or is_hooking:
		return
	health.take_damage(amount)
	Log.dbg("Player took damage", {"amount": amount, "hp_remaining": health.current_health})
	SoundManager.play_sfx(SoundManager.SFX_PLAYER_TAKES_DAMAGE)
	_shake_camera(SHAKE_DAMAGE)

func trigger_win():
	if not gameplay_active:
		return

	hud.show_win_screen()

func _on_start_game_requested():
	if gameplay_active:
		return

	gameplay_active = true
	Log.info("Game started")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameManager.register_player(self)

func _on_game_over():
	gameplay_active = false
	Log.info("Game over")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	if not gameplay_active:
		return
	if _is_debug_fly_active():
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
	
	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta):
	if is_hooking:
		_handle_hook_movement(delta)
		move_and_slide()
		return

	if gameplay_active:
		handle_input()
		handle_movement(delta)
		_apply_gravity(delta)
	else:
		var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
		horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, FRICTION * delta)
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z
		_apply_gravity(delta)

	move_and_slide()

	if _hook_slide_timer > 0.0:
		for i in get_slide_collision_count():
			if get_slide_collision(i).get_normal().y < 0.7:  # wall, not floor
				_hook_slide_timer = 0.0
				velocity.x = 0.0
				velocity.z = 0.0
				break

func hook_smash(target: Node3D) -> void:
	is_hooking = true
	_hook_target = target
	set_collision_mask_value(2, false)  # Pass through enemies during smash
	Log.info("Hook-Smash launched", {"target": target.name})

func _handle_hook_movement(delta: float) -> void:
	if not is_instance_valid(_hook_target) or _hook_target.is_dead:
		_end_hook(false)
		return

	var to_target: Vector3 = _hook_target.global_position - global_position
	if to_target.length() < HOOK_ARRIVE_DIST:
		_on_hook_impact()
		return

	velocity = to_target.normalized() * HOOK_SPEED

func _on_hook_impact() -> void:
	var target := _hook_target
	var impact_pos := target.global_position
	_end_hook(false)
	velocity.y = 0.0  # Don't carry vertical hook velocity into slide
	_hook_slide_timer = HOOK_SLIDE_DURATION
	if is_instance_valid(target) and not target.is_dead:
		var spray_dir := global_position.direction_to(impact_pos)
		FXManager.play_enemy_death_fx(target.global_transform, spray_dir)
		target.die()
	_shake_camera(SHAKE_HOOK)
	_apply_hook_splash(impact_pos, target)
	Log.info("Hook-Smash impact executed")

func _apply_hook_splash(impact_pos: Vector3, killed_target: Node3D) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == killed_target or not is_instance_valid(enemy) or enemy.is_dead:
			continue
		var dist: float = enemy.global_position.distance_to(impact_pos)
		if dist > HOOK_SPLASH_RADIUS:
			continue
		var falloff: float = 1.0 - dist / HOOK_SPLASH_RADIUS
		var away_dir: Vector3 = (enemy.global_position - impact_pos).normalized()
		away_dir.y = maxf(away_dir.y + 0.3, 0.3)  # slight upward kick
		away_dir = away_dir.normalized()
		enemy.apply_splash_damage(HOOK_SPLASH_DAMAGE)
		enemy.apply_knockback(away_dir * HOOK_SPLASH_KNOCKBACK * falloff)
		Log.dbg("Hook splash hit", {"enemy": enemy.name, "dist": dist, "falloff": falloff})

func _end_hook(zero_velocity: bool = true) -> void:
	is_hooking = false
	_hook_target = null
	set_collision_mask_value(2, true)  # Restore enemy collision
	if zero_velocity:
		velocity = Vector3.ZERO

func handle_input():
	if _is_debug_fly_active():
		input_dir = Vector3.ZERO
		return

	input_dir = Vector3.ZERO
	
	if Input.is_action_pressed("move_forwards"):
		input_dir.z -= 1
	if Input.is_action_pressed("move_backwards"):
		input_dir.z += 1
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
		
	input_dir = input_dir.normalized()
	# Use global basis so movement follows view direction even if parent nodes are rotated.
	input_dir = global_transform.basis.orthonormalized() * input_dir
	input_dir.y = 0.0
	input_dir = input_dir.normalized()
	
	if Input.is_action_just_pressed("shoot"):
		Log.dbg("Player shot, going to weapon")
		weapon.fire()

func handle_movement(delta):
	var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)

	if _hook_slide_timer > 0.0:
		_hook_slide_timer -= delta
		horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, HOOK_SLIDE_FRICTION * delta)
	elif input_dir != Vector3.ZERO:
		var target_velocity:Vector3 = input_dir * MAX_SPEED
		horizontal_velocity = horizontal_velocity.lerp(target_velocity, ACCEL * delta)
	else:
		horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, FRICTION * delta)
	
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z

func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta


func add_pickup(type, amount):
	SoundManager.play_sfx(SoundManager.SFX_PICKUP)
	match type:
		0: # Health (Matches PickupType.HEALTH)
			if health:
				health.current_health = mini(health.current_health + amount, health.max_health)
				hud.sync_health_bar()
				Log.info("Pickup collected", {"type": "HEALTH", "amount": amount, "new_health": health.current_health})
		1: # Ammo (Matches PickupType.AMMO)
			if weapon:
				weapon.current_ammo = mini(weapon.current_ammo + amount, weapon.max_ammo)
				weapon.emit_signal("ammo_changed", weapon.current_ammo, weapon.max_ammo)
				Log.info("Pickup collected", {"type": "AMMO", "amount": amount, "new_ammo": weapon.current_ammo})
