extends Node3D

const player_scene = preload("res://scenes/player/player.tscn")

@onready var dungeon_generator = %DungeonGenerator3D

# Dungeon configuration
@export var dungeon_size := Vector3i(10, 10, 10)
@export var generation_seed := 0  # 0 = random seed

var player: Node3D
var _last_debug_grid_pos: Vector3i = Vector3i(999999, 999999, 999999)

func _ready():
	# Configure dungeon generator
	dungeon_generator.dungeon_size = dungeon_size
	dungeon_generator.visualize_generation_wait_between_iterations = 0
	dungeon_generator.visualize_generation_progress = false
	dungeon_generator.show_debug_in_game = false
	_setup_preplaced_terminal_rooms()

	# Connect to generation complete and start generation
	if not dungeon_generator.done_generating.is_connected(_on_generation_complete):
		dungeon_generator.done_generating.connect(_on_generation_complete)

	# Generate with seed (0 = random)
	dungeon_generator.generate(generation_seed)

func _process(_delta: float) -> void:
	if not (player and is_instance_valid(player)):
		return
	var local_pos:Vector3 = dungeon_generator.to_local(player.global_position)
	var grid_pos := Vector3i((local_pos / dungeon_generator.voxel_scale + Vector3(dungeon_generator.dungeon_size) / 2.0).floor())
	if grid_pos == _last_debug_grid_pos:
		return
	_last_debug_grid_pos = grid_pos
	var room_data = get_player_room_data(player.global_position)
	if room_data.has("room"):
		DebugMenu.set_runtime_line("current_room", "Room: %s" % room_data.room.name)
	else:
		DebugMenu.set_runtime_line("current_room", "Room: Outside Dungeon")

func _setup_preplaced_terminal_rooms() -> void:
	for child in dungeon_generator.get_children():
		if child is DungeonRoom3D and child.has_meta("preplaced_terminal"):
			dungeon_generator.remove_child(child)
			child.queue_free()

func _on_generation_complete():
	Log.info("Dungeon generation complete, spawning player")
	spawn_player()

func spawn_player():
	if player and is_instance_valid(player):
		return

	var spawn_points = get_tree().get_nodes_in_group("player_spawn_point")
	if spawn_points.size() == 0:
		Log.warn("No player spawn points found")
		return

	var spawn_point: Node3D = spawn_points.pick_random() as Node3D
	if spawn_point == null:
		return

	player = player_scene.instantiate()
	add_child(player)
	player.global_transform = spawn_point.global_transform

	# Ensure player camera is active
	for cam in player.find_children("*", "Camera3D"):
		cam.current = true

func get_player_room_data(player_pos: Vector3) -> Dictionary:
	var local_pos: Vector3 = dungeon_generator.to_local(player_pos)
	var grid_pos: Vector3i = Vector3i((local_pos / dungeon_generator.voxel_scale + Vector3(dungeon_generator.dungeon_size) / 2.0).floor())
	var room = dungeon_generator.get_room_at_pos(grid_pos)
	if not room:
		return {}
	return {
		"room": room,
		"grid_pos": room.get_grid_pos(),
		"bounds": room.get_grid_aabbi(false)
	}
