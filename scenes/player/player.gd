extends CharacterBody3D

const MAX_SPEED = 5.0
const ACCEL = 10.0
const FRICTION = 12.0
const MOUSE_SENS = 0.002
const FLOOR_SNAP_LENGTH: float = 0.35

const SHAKE_FIRE: float = 0.018
const SHAKE_DAMAGE: float = 0.05
const SHAKE_DECAY: float = 8.0

const TILT_MAX: float = 0.25     # max tilt in radians (~14 degrees)
const TILT_LERP: float = 8.0
const TILT_MIN_SPEED: float = 4.6  # match speedlines threshold

const FOV_INCREASE: float = 10.0  # degrees added to FOV at max speed
const FOV_LERP: float = 5.0       # how fast FOV transitions

@onready var camera = $Camera3D
@onready var weapon = $Weapon
@onready var hud = $Hud
@onready var health = $Health

var input_dir = Vector3.ZERO
var gameplay_active = false
var _shake_strength: float = 0.0
var _camera_base_pos: Vector3
var camera_tilt: float = 0.0  # Exposed for HUD to sync gun rotation
var _base_fov: float = 75.0
var _gravity: float = 9.8

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
	if not gameplay_active:
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

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
	
	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta):
	_apply_gravity(delta)
	
	if gameplay_active:
		handle_input()
		handle_movement(delta)
	else:
		var horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
		horizontal_velocity = horizontal_velocity.lerp(Vector3.ZERO, FRICTION * delta)
		velocity.x = horizontal_velocity.x
		velocity.z = horizontal_velocity.z
	
	move_and_slide()

func handle_input():
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
	
	if input_dir != Vector3.ZERO:
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
			Log.info("Pickup collected", {"type": "HEALTH", "amount": amount})
		1: # Ammo (Matches PickupType.AMMO)
			Log.info("Pickup collected", {"type": "AMMO", "amount": amount})
	
	# Play a sound effect or UI animation here!
	# still need to actually link these up as well...
