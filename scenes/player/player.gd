extends CharacterBody3D

const MAX_SPEED = 5.0
const ACCEL = 10.0
const FRICTION = 12.0
const MOUSE_SENS = 0.002

@onready var camera = $Camera3D
@onready var weapon = $Weapon
@onready var hud = $Hud
@onready var health = $Health


var input_dir = Vector3.ZERO
var gameplay_active = false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	weapon.fired.connect(hud._on_weapon_fired)
	hud.start_game_requested.connect(_on_start_game_requested)
	hud.game_over.connect(_on_game_over)

func take_damage(amount):
	if not gameplay_active:
		return
	health.take_damage(amount)

func trigger_win():
	if not gameplay_active:
		return

	hud.show_win_screen()

func _on_start_game_requested():
	if gameplay_active:
		return

	gameplay_active = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	GameManager.register_player(self)

func _on_game_over():
	gameplay_active = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	if not gameplay_active:
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
	
	if event is InputEventMouseButton and event.pressed:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	if not gameplay_active:
		return

	handle_input()
	handle_movement(delta)

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
	input_dir = transform.basis * input_dir
	
	if Input.is_action_just_pressed("shoot"):
		weapon.fire()

func handle_movement(delta):
	if input_dir != Vector3.ZERO:
		velocity = velocity.lerp(input_dir * MAX_SPEED, ACCEL * delta)
	else:
		velocity = velocity.lerp(Vector3.ZERO, FRICTION * delta)
		
	move_and_slide()
