extends CanvasLayer

signal start_game_requested
signal game_over

@onready var anim_player = $AnimationPlayer
@onready var hp_label = $HpLabel
@onready var ammo_label = $AmmoLabel
@onready var vignette = $VignetteOverlay
@onready var start_screen = $StartScreen
@onready var end_screen = $EndScreen
@onready var end_title = $EndScreen/PanelContainer/VBoxContainer/EndTitle
@onready var gun_control = $Control
@onready var gun_sprite = $Control/GunSprite
@onready var reticle = $Reticle
@onready var speedlines = $SpeedlinesOverlay
@onready var pause_screen = $PauseScreen

const SPEEDLINES_MIN_SPEED: float = 4.6
const SPEEDLINES_MAX_DENSITY: float = 0.25
const SPEEDLINES_DENSITY_LERP: float = 6.0

const BOB_SPEED: float = 9.0
const BOB_AMOUNT_X: float = 4.0   # pixels, side-to-side
const BOB_AMOUNT_Y: float = 2.5   # pixels, up-down (half of X for figure-eight)
const SWAY_AMOUNT: float = 400.0  # scale factor for rotation delta → pixels
const SWAY_MAX: float = 18.0      # clamp sway so it doesn't fly off screen
const SWAY_LERP: float = 7.0

var player: CharacterBody3D
var _weapon: Node = null
var fade_timer = 0.0
var fade_duration = 2.0
var game_started = false
var is_paused = false

var _gun_base_pos: Vector2
var _bob_time: float = 0.0
var _sway_current: float = 0.0
var _prev_player_rotation_y: float = 0.0

func _ready():
	player = get_parent()
	if player and player.has_node("Health"):
		var health = player.get_node("Health")
		health.damaged.connect(_on_player_damaged)
		health.died.connect(_on_player_died)
		if hp_label:
			update_hp_display()
		if vignette:
			vignette.modulate.a = 0.0
	
	if player and player.has_node("Weapon"):
		_weapon = player.get_node("Weapon")
		_weapon.ammo_changed.connect(_on_ammo_changed)

	$StartScreen/PanelContainer/VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$StartScreen/PanelContainer/VBoxContainer/OptionsButton.pressed.connect(_on_options_pressed)
	$EndScreen/PanelContainer/VBoxContainer/RestartButton.pressed.connect(_on_restart_pressed)
	$PauseScreen/PanelContainer/VBoxContainer/ResumeButton.pressed.connect(_on_resume_pressed)
	$PauseScreen/PanelContainer/VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

	# Store base gun position
	if gun_sprite:
		_gun_base_pos = gun_sprite.position
	_prev_player_rotation_y = player.rotation.y

	_show_start_screen()

func _process(delta: float) -> void:
	_update_speedlines(delta)
	_update_weapon_bob_sway(delta)
	_update_crosshair_tint()
	# Handle vignette fade-out over time
	if fade_timer > 0.0:
		fade_timer -= delta
		if vignette:
			# Calculate the resting opacity based on health (max opacity when at max health is 0)
			var resting_opacity = calculate_resting_opacity()
			# Fade toward resting opacity
			var target_opacity = resting_opacity
			vignette.modulate.a = lerpf(vignette.modulate.a, target_opacity, delta / fade_duration)

func _update_crosshair_tint() -> void:
	if not game_started or not reticle or not _weapon:
		return
	var on_staggered: bool = _weapon.get("_crosshair_target_staggered") == true
	reticle.modulate = Color(1.0, 0.15, 0.15) if on_staggered else Color(1.0, 1.0, 1.0)

func _on_weapon_fired():
	if not game_started:
		return
	anim_player.play("shoot")

func _on_player_damaged():
	if not game_started:
		return
	update_hp_display()
	show_damage_vignette()

func _on_player_died():
	SoundManager.play_sfx(SoundManager.SFX_PLAYER_DEATH)
	if is_paused:
		toggle_pause()
	_show_end_screen("You Died")
	emit_signal("game_over")

func update_hp_display():
	if not hp_label or not player.has_node("Health"):
		return
	
	var health = player.get_node("Health")
	hp_label.text = str(health.current_health)

func _on_ammo_changed(current_ammo: int, max_ammo: int):
	if not ammo_label:
		return
	ammo_label.text = str(current_ammo) + "/" + str(max_ammo)

func calculate_resting_opacity() -> float:
	if not player.has_node("Health"):
		return 0.0
	
	var health = player.get_node("Health")
	var health_percent = float(health.current_health) / float(health.max_health)
	# Opacity increases as health decreases (inverse of health percent)
	return 1.0 - health_percent

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if game_started:
			toggle_pause()

func toggle_pause() -> void:
	is_paused = !is_paused
	get_tree().paused = is_paused
	pause_screen.visible = is_paused
	if is_paused:
		SoundManager.play_sfx(SoundManager.SFX_PAUSE)
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		SoundManager.play_sfx(SoundManager.SFX_UNPAUSE)
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _on_resume_pressed() -> void:
	toggle_pause()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _update_speedlines(delta: float) -> void:
	if not game_started or not speedlines:
		return
	var speed = player.velocity.length()
	var target_density = clampf(remap(speed, SPEEDLINES_MIN_SPEED, player.MAX_SPEED, 0.0, SPEEDLINES_MAX_DENSITY), 0.0, SPEEDLINES_MAX_DENSITY)
	var current_density = speedlines.material.get_shader_parameter("line_density")
	var new_density = lerpf(current_density, target_density, SPEEDLINES_DENSITY_LERP * delta)
	speedlines.material.set_shader_parameter("line_density", new_density)
	speedlines.visible = new_density > 0.01

func _update_weapon_bob_sway(delta: float) -> void:
	if not game_started or not gun_sprite:
		return
	
	# Figure-eight bob (Lissajous curve: sin(t) for X, sin(2t) for Y)
	var speed = player.velocity.length()
	var move_amount = clampf(speed / player.MAX_SPEED, 0.0, 1.0)
	
	if move_amount > 0.01:
		_bob_time += delta * BOB_SPEED
	else:
		# Decay bob time when not moving so gun settles
		_bob_time = lerpf(_bob_time, 0.0, 10.0 * delta)
	
	# Lissajous curve for figure-eight
	var bob_offset_x = sin(_bob_time) * BOB_AMOUNT_X * move_amount
	var bob_offset_y = sin(_bob_time * 2.0) * BOB_AMOUNT_Y * move_amount
	
	# Turn-based sway
	var rotation_delta = player.rotation.y - _prev_player_rotation_y
	var target_sway = clampf(rotation_delta * SWAY_AMOUNT, -SWAY_MAX, SWAY_MAX)
	_sway_current = lerpf(_sway_current, target_sway, SWAY_LERP * delta)
	_prev_player_rotation_y = player.rotation.y
	
	# Apply combined offset and camera tilt to gun
	gun_sprite.position = _gun_base_pos + Vector2(bob_offset_x + _sway_current, bob_offset_y)
	gun_sprite.rotation = player.camera_tilt  # Match camera tilt

func show_damage_vignette():
	if not vignette or not player.has_node("Health"):
		return
	
	var target_opacity = calculate_resting_opacity()
	vignette.modulate.a = min(target_opacity + 0.3, 1.0)
	fade_timer = fade_duration

func show_win_screen():
	SoundManager.play_sfx(SoundManager.SFX_WIN)
	_show_end_screen("You Won")
	emit_signal("game_over")

func _on_start_pressed():
	game_started = true
	start_screen.visible = false
	end_screen.visible = false
	gun_control.visible = true
	reticle.visible = true
	hp_label.visible = true
	ammo_label.visible = true
	vignette.visible = true
	emit_signal("start_game_requested")

func _on_options_pressed():
	pass

func _on_restart_pressed():
	get_tree().reload_current_scene()

func _show_start_screen():
	start_screen.visible = true
	end_screen.visible = false
	gun_control.visible = false
	reticle.visible = false
	hp_label.visible = false
	ammo_label.visible = false
	vignette.visible = false

func _show_end_screen(title: String):
	end_title.text = title
	end_screen.visible = true
	start_screen.visible = false
	gun_control.visible = false
	reticle.visible = false
	ammo_label.visible = false
