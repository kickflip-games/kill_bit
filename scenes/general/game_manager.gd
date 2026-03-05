extends Node

const IMPACT_PAUSE_INTERVAL: int = 5
const IMPACT_PAUSE_DURATION: float = 0.02

var player: Node3D
var kill_count: int = 0

func _ready() -> void:
	Log.info("GameManager ready")
	Log.current_log_level = Log.LogLevel.DEBUG

func register_player(p):
	player = p
	Log.info("Player registered")
	get_tree().call_group("enemies", "set_player", player)

func register_kill() -> void:
	kill_count += 1
	Log.info("Kill registered", {"kill_count": kill_count})
	if kill_count % IMPACT_PAUSE_INTERVAL == 0:
		_trigger_impact_pause()

func _trigger_impact_pause() -> void:
	Log.dbg("Impact pause triggered", {"kill_count": kill_count})
	Engine.time_scale = 0.0
	# ignore_time_scale = true so the timer runs in real time, not game time
	await get_tree().create_timer(IMPACT_PAUSE_DURATION, true, false, true).timeout
	Engine.time_scale = 1.0
