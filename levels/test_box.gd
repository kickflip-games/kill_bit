extends Node3D

@onready var player: CharacterBody3D = $PlayerSpawn/Player
@onready var stopwatch: Label = $TrialOverlay/Stopwatch

var elapsed := 0.0

func _ready() -> void:
	GameManager.kill_count = 0
	Engine.time_scale = 1.0
	call_deferred("_start_trial")

func _start_trial() -> void:
	player.get_node("Hud")._on_start_pressed()

func _process(delta: float) -> void:
	if player.gameplay_active:
		elapsed += delta
		stopwatch.text = "%05.2f  |  F5 restart" % elapsed

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F5:
		get_tree().paused = false
		get_tree().reload_current_scene()
