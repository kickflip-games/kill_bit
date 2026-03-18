@tool
extends Node3D

## EnemyMarker — marks valid enemy spawn positions for the EnemyDirector.
## Attach to an individual Marker3D OR to a container Node3D whose children
## are the actual spawn points (e.g. the "EnemyMarkers" node in room scenes).
## The EnemyDirector queries the "enemy_markers" group at runtime.

func _ready() -> void:
	if get_child_count() > 0:
		# Container mode: register each child spawn point
		for child in get_children():
			if child is Node3D:
				child.add_to_group("enemy_markers")
	else:
		# Leaf mode: register self
		add_to_group("enemy_markers")
