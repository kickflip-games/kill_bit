extends CanvasLayer

signal start_game_requested
signal game_over

@onready var anim_player = $AnimationPlayer
@onready var hp_label = $HpLabel
@onready var vignette = $VignetteOverlay
@onready var start_screen = $StartScreen
@onready var end_screen = $EndScreen
@onready var end_title = $EndScreen/PanelContainer/VBoxContainer/EndTitle
@onready var gun_control = $Control
@onready var reticle = $Reticle

var player: CharacterBody3D
var fade_timer = 0.0
var fade_duration = 2.0
var game_started = false

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

	$StartScreen/PanelContainer/VBoxContainer/StartButton.pressed.connect(_on_start_pressed)
	$StartScreen/PanelContainer/VBoxContainer/OptionsButton.pressed.connect(_on_options_pressed)
	$EndScreen/PanelContainer/VBoxContainer/RestartButton.pressed.connect(_on_restart_pressed)

	_show_start_screen()

func _process(delta: float) -> void:
	# Handle vignette fade-out over time
	if fade_timer > 0.0:
		fade_timer -= delta
		if vignette:
			# Calculate the resting opacity based on health (max opacity when at max health is 0)
			var resting_opacity = calculate_resting_opacity()
			# Fade toward resting opacity
			var target_opacity = resting_opacity
			vignette.modulate.a = lerpf(vignette.modulate.a, target_opacity, delta / fade_duration)

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
	_show_end_screen("You Died")
	emit_signal("game_over")

func update_hp_display():
	if not hp_label or not player.has_node("Health"):
		return
	
	var health = player.get_node("Health")
	hp_label.text = str(health.current_health)

func calculate_resting_opacity() -> float:
	if not player.has_node("Health"):
		return 0.0
	
	var health = player.get_node("Health")
	var health_percent = float(health.current_health) / float(health.max_health)
	# Opacity increases as health decreases (inverse of health percent)
	return 1.0 - health_percent

func show_damage_vignette():
	if not vignette or not player.has_node("Health"):
		return
	
	var target_opacity = calculate_resting_opacity()
	vignette.modulate.a = min(target_opacity + 0.3, 1.0)
	fade_timer = fade_duration

func show_win_screen():
	_show_end_screen("You Won")
	emit_signal("game_over")

func _on_start_pressed():
	game_started = true
	start_screen.visible = false
	end_screen.visible = false
	gun_control.visible = true
	reticle.visible = true
	hp_label.visible = true
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
	vignette.visible = false

func _show_end_screen(title: String):
	end_title.text = title
	end_screen.visible = true
	start_screen.visible = false
	gun_control.visible = false
	reticle.visible = false
