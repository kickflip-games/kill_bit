extends Node

@onready var blood_decals:BloodDecals = $BloodDecals
@export var enemy_damage_particles_scene: PackedScene
@export var enemy_death_particles_scene: PackedScene

func _ready() -> void:
	if not blood_decals:
		Log.warn("FXManager: BloodDecals child not found.")

func play_enemy_take_damage_fx(enemy_transform: Transform3D, spray_direction: Vector3 = Vector3.FORWARD) -> void:
	_spawn_enemy_particles(enemy_transform, false)
	if blood_decals:
		blood_decals.spawn_blood_at_position(enemy_transform.origin, _safe_direction(spray_direction), false)

func play_enemy_death_fx(enemy_transform: Transform3D, spray_direction: Vector3 = Vector3.FORWARD) -> void:
	_spawn_enemy_particles(enemy_transform, true)
	if blood_decals:
		blood_decals.spawn_blood_at_position(enemy_transform.origin, _safe_direction(spray_direction), true)

func _spawn_enemy_particles(enemy_transform: Transform3D, is_death: bool) -> void:
	var fx_scene: PackedScene = enemy_death_particles_scene if is_death else enemy_damage_particles_scene
	if not fx_scene:
		return
	var fx = fx_scene.instantiate()
	if fx is Node3D:
		(fx as Node3D).global_transform = enemy_transform
	elif fx is Node2D:
		(fx as Node2D).global_position = Vector2(enemy_transform.origin.x, enemy_transform.origin.z)
	var parent := get_tree().current_scene if get_tree().current_scene else self
	parent.add_child(fx)

func _safe_direction(dir: Vector3) -> Vector3:
	return dir.normalized() if not dir.is_zero_approx() else Vector3.FORWARD
