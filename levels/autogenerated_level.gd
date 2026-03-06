extends Node3D

const player_scene = preload("res://scenes/player/player.tscn")

@onready var dungeon_generator = %DungeonGenerator3D

# Dungeon configuration
@export var dungeon_size := Vector3i(10, 1, 10)
@export var generation_seed := 0  # 0 = random seed

var room_scenes = [
	preload("res://addons/SimpleDungeons/sample_dungeons/with_dev_textures_rooms/bridge_room.tscn"),
	preload("res://addons/SimpleDungeons/sample_dungeons/with_dev_textures_rooms/entrance_room.tscn"),
	preload("res://addons/SimpleDungeons/sample_dungeons/with_dev_textures_rooms/living_room.tscn"),
]
var corridor_scene = preload("res://addons/SimpleDungeons/sample_dungeons/with_dev_textures_rooms/corridor.tscn")

var player: Node3D

func _ready():
	# Configure dungeon generator
	dungeon_generator.dungeon_size = dungeon_size
	dungeon_generator.visualize_generation_wait_between_iterations = 0
	dungeon_generator.visualize_generation_progress = false
	dungeon_generator.show_debug_in_game = false
	
	# Set room scenes (filter out stair rooms if single floor)
	var filtered_rooms: Array[PackedScene] = []
	filtered_rooms.assign(room_scenes)
	dungeon_generator.room_scenes = filtered_rooms
	dungeon_generator.corridor_room_scene = corridor_scene
	
	# Connect to generation complete and start generation
	if not dungeon_generator.done_generating.is_connected(_on_generation_complete):
		dungeon_generator.done_generating.connect(_on_generation_complete)
	
	# Generate with seed (0 = random)
	dungeon_generator.generate(generation_seed)

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
		
	
