extends Area3D

@export var one_shot = true

var triggered = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if triggered:
		return

	if body.has_method("trigger_win"):
		body.trigger_win()
		if one_shot:
			triggered = true
