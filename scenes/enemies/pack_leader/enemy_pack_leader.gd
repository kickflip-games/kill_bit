extends MeleeEnemy
class_name EnemyPackLeader

@export_group("Pack Rage")
@export var rage_radius: float = 12.0         ## Range to affect nearby melee enemies
@export var rage_speed_multiplier: float = 1.6 ## Speed boost applied to enraged allies
@export var rage_duration: float = 4.0        ## How long the buff lasts

func _ready() -> void:
	super._ready()

func die() -> void:
	_trigger_pack_rage()
	super.die()

func _trigger_pack_rage() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy is MeleeEnemy and enemy != self and not enemy.is_dead:
			if global_position.distance_to(enemy.global_position) <= rage_radius:
				_apply_rage(enemy as MeleeEnemy)

func _apply_rage(enemy: MeleeEnemy) -> void:
	Log.dbg("Pack rage applied", {"leader": name, "target": enemy.name})
	enemy.move_speed *= rage_speed_multiplier

	# Pulse red on the ally to signal the buff
	var mat := enemy.sprite_3d.material_override as ShaderMaterial
	if mat:
		mat.set_shader_parameter("flash_color", Color(1.0, 0.1, 0.1, 1.0))
		var tween := enemy.create_tween().set_loops(6)
		tween.tween_property(mat, "shader_parameter/active", 0.7, 0.2)
		tween.tween_property(mat, "shader_parameter/active", 0.0, 0.2)
		# Restore white flash color when rage expires so normal hit flash still works
		tween.finished.connect(
			func():
				if is_instance_valid(enemy) and not enemy.is_dead:
					mat.set_shader_parameter("flash_color", Color(1.0, 1.0, 1.0, 1.0))
		)

	# Revert speed after duration
	enemy.get_tree().create_timer(rage_duration).timeout.connect(
		func():
			if is_instance_valid(enemy) and not enemy.is_dead:
				enemy.move_speed /= rage_speed_multiplier
	)
