extends Node

## EnemyDirector — maintains a dynamic enemy population around the player.
## Add EnemyMarker nodes (in group "enemy_markers") to rooms.
## Register this as an autoload named EnemyDirector.

enum Intensity { CALM, PRESSURE, CHAOS }

const MELEE_SCENE  := preload("res://scenes/enemies/melee/enemy_melee.tscn")
const SHOOTER_SCENE := preload("res://scenes/enemies/shooter/enemy_shooter.tscn")
const PICKUP_SCENE := preload("res://scenes/pickups/pickup.tscn")

## --- Tuning ---
@export var target_nearby: int = 8       ## Desired enemy count within nearby_radius
@export var max_total: int = 15          ## Hard cap on all active enemies
@export var nearby_radius: float = 20.0  ## Radius that counts as "nearby player"
@export var spawn_min_dist: float = 6.0  ## Don't spawn this close (in player's face)
@export var spawn_max_dist: float = 25.0 ## Don't spawn this far (off screen)

## Seconds between spawn attempts per intensity level
@export var interval_calm: float = 1.5
@export var interval_pressure: float = 0.7

## Kills required before shooters start appearing
@export var shooter_unlock_kills: int = 5

## How many enemies to spawn immediately when the player first enters the level
@export var initial_burst: int = 4

## Pickup spawning thresholds
@export var health_spawn_threshold: float = 0.4  ## Spawn health when player HP < 40%
@export var ammo_spawn_threshold: float = 0.3    ## Spawn ammo when player ammo < 30%
@export var pickup_check_interval: float = 5.0   ## Seconds between pickup spawn checks

## Enemies beyond this radius get culled (freed) to free up the budget
@export var despawn_radius: float = 40.0
## How far ahead of travel direction to bias spawning (0 = ignore direction)
@export var forward_spawn_bias: float = 0.4  ## dot-product threshold for "ahead"

var intensity: Intensity = Intensity.CALM

var _spawn_timer: float = 0.0
var _pickup_timer: float = 0.0
var _cull_timer: float = 0.0

var _player_prev_pos: Vector3 = Vector3.ZERO
var _player_travel_dir: Vector3 = Vector3.ZERO  ## Smoothed direction of player movement

# ------------------------------------------------------------------ lifecycle

func _ready() -> void:
	Log.info("EnemyDirector ready")
	# Wait one frame so GameManager is fully initialised, then watch for player
	call_deferred("_await_player")

func _await_player() -> void:
	if GameManager.player != null:
		_on_player_ready()
	else:
		# Poll — player spawns after dungeon generation completes
		set_process(false)  # pause normal process until player arrives
		get_tree().process_frame.connect(_poll_for_player)

func _poll_for_player() -> void:
	if GameManager.player == null:
		return
	get_tree().process_frame.disconnect(_poll_for_player)
	set_process(true)
	_on_player_ready()

func _on_player_ready() -> void:
	_player_prev_pos = GameManager.player.global_position
	Log.info("EnemyDirector: player ready, spawning initial burst", {"count": initial_burst})
	for i in initial_burst:
		_try_spawn()

func _process(delta: float) -> void:
	if GameManager.player == null:
		return

	_track_player_direction(delta)
	_update_intensity()

	if intensity == Intensity.CHAOS:
		return  # Already too many enemies — wait for player to clear some

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_try_spawn()
		_spawn_timer = interval_calm if intensity == Intensity.CALM else interval_pressure

	# Check if player needs pickups
	_pickup_timer -= delta
	if _pickup_timer <= 0.0:
		_try_spawn_pickup()
		_pickup_timer = pickup_check_interval

	# Cull enemies that have been left far behind
	_cull_timer -= delta
	if _cull_timer <= 0.0:
		_cull_distant_enemies()
		_cull_timer = 4.0

# ------------------------------------------------------------------ intensity

func _update_intensity() -> void:
	var nearby := _count_nearby_enemies()
	var total  := get_tree().get_nodes_in_group("enemies").size()

	if total >= max_total or nearby >= target_nearby:
		intensity = Intensity.CHAOS
	elif nearby >= target_nearby / 2:
		intensity = Intensity.PRESSURE
	else:
		intensity = Intensity.CALM

func _count_nearby_enemies() -> int:
	var player_pos := GameManager.player.global_position
	var count := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.distance_to(player_pos) <= nearby_radius:
			count += 1
	return count

func _track_player_direction(delta: float) -> void:
	var pos := GameManager.player.global_position
	var raw_dir := (pos - _player_prev_pos)
	raw_dir.y = 0.0
	if raw_dir.length() > 0.05:
		# Smooth toward the new direction so brief turns don't whip the bias
		_player_travel_dir = _player_travel_dir.lerp(raw_dir.normalized(), 8.0 * delta)
	_player_prev_pos = pos

func _cull_distant_enemies() -> void:
	var player_pos := GameManager.player.global_position
	var culled := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		if e is BaseEnemy and e.is_dead:
			continue
		if e.global_position.distance_to(player_pos) > despawn_radius:
			e.queue_free()
			culled += 1
	if culled > 0:
		Log.info("EnemyDirector culled distant enemies", {"count": culled})

# ------------------------------------------------------------------ spawning

func _try_spawn() -> void:
	var marker := _pick_marker()
	if marker == null:
		return

	var enemy: BaseEnemy = _pick_scene().instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = marker.global_position
	enemy.set_player(GameManager.player)
	Log.info("EnemyDirector spawned", {"scene": enemy.name, "pos": enemy.global_position, "intensity": Intensity.keys()[intensity]})

func _pick_marker() -> Node3D:
	var markers := get_tree().get_nodes_in_group("enemy_markers")
	if markers.is_empty():
		return null

	var player_pos := GameManager.player.global_position
	var ahead: Array = []
	var any_valid: Array = []

	for m: Node3D in markers:
		var offset := m.global_position - player_pos
		var d := offset.length()
		if d < spawn_min_dist or d > spawn_max_dist:
			continue
		any_valid.append(m)
		# Check if marker is in the direction of travel
		if _player_travel_dir.length() > 0.1:
			var flat_offset := Vector3(offset.x, 0, offset.z).normalized()
			if flat_offset.dot(_player_travel_dir) >= forward_spawn_bias:
				ahead.append(m)

	if any_valid.is_empty():
		return null

	# Prefer ahead markers; fall back to all valid if none are ahead
	var pool := ahead if not ahead.is_empty() else any_valid
	pool.shuffle()
	return pool[0]

func _pick_scene() -> PackedScene:
	if intensity == Intensity.PRESSURE and GameManager.kill_count >= shooter_unlock_kills:
		return SHOOTER_SCENE if randf() > 0.4 else MELEE_SCENE
	return MELEE_SCENE

# ------------------------------------------------------------------ pickups

func _try_spawn_pickup() -> void:
	var player := GameManager.player
	if player == null:
		return

	var needs_health := _check_health_need()
	var needs_ammo := _check_ammo_need()

	if not needs_health and not needs_ammo:
		return

	var marker := _pick_marker()
	if marker == null:
		return

	var pickup = PICKUP_SCENE.instantiate()
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = marker.global_position

	# Decide which type to spawn
	if needs_health and needs_ammo:
		# Both needed — prioritize health if critical
		var health_ratio := _get_health_ratio()
		if health_ratio < 0.25:
			pickup.type = 0  # Health
			pickup.amount = 25
		else:
			pickup.type = 1 if randf() > 0.5 else 0
			pickup.amount = 30 if pickup.type == 1 else 25
	elif needs_health:
		pickup.type = 0  # Health
		pickup.amount = 25
	else:
		pickup.type = 1  # Ammo
		pickup.amount = 30

	Log.info("EnemyDirector spawned pickup", {"type": "HEALTH" if pickup.type == 0 else "AMMO", "amount": pickup.amount, "pos": pickup.global_position})

func _check_health_need() -> bool:
	var health_ratio := _get_health_ratio()
	return health_ratio < health_spawn_threshold

func _check_ammo_need() -> bool:
	var ammo_ratio := _get_ammo_ratio()
	return ammo_ratio < ammo_spawn_threshold

func _get_health_ratio() -> float:
	var player := GameManager.player
	if player == null or not player.has_node("Health"):
		return 1.0
	var health_node = player.get_node("Health")
	return float(health_node.current_health) / float(health_node.max_health)

func _get_ammo_ratio() -> float:
	var player := GameManager.player
	if player == null or not player.has_node("Weapon"):
		return 1.0
	var weapon = player.get_node("Weapon")
	return float(weapon.current_ammo) / float(weapon.max_ammo)
