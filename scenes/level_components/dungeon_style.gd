@tool
extends RoommateStyle


const WALL_TEXTURE = preload("res://scenes/level_components/textures/wall.png")
const FLOOR_TEXTURE = preload("res://scenes/level_components/textures/floor.png")


func _build_rulesets() -> void:
	var ruleset := create_ruleset()
	ruleset.select_all_blocks()

	# =========================
	# WALL SETUP
	# =========================
	var walls_setter := ruleset.select_all_walls()

	var wall_material := StandardMaterial3D.new()
	wall_material.albedo_texture = WALL_TEXTURE
	wall_material.uv1_scale = Vector3(2, 2, 1) # controls tiling
	wall_material.roughness = 1.0

	walls_setter.override_fallback_surface().material.override(wall_material)

	# =========================
	# FLOOR SETUP
	# =========================
	var floor_setter := ruleset.select_floor()

	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_texture = FLOOR_TEXTURE
	floor_material.uv1_scale = Vector3(4, 4, 1) # floor tiling
	floor_material.roughness = 1.0

	floor_setter.override_fallback_surface().material.override(floor_material)

	
	
	var roof_setter := ruleset.select_ceil()
	roof_setter.override_fallback_surface().material.override(floor_material) 
