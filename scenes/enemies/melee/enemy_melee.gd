extends BaseEnemy
class_name MeleeEnemy

func _ready() -> void:
	# Set movement type before parent initialization
	movement_type = MovementType.FLANK
	super._ready()
