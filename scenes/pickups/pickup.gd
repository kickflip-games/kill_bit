@tool
extends Area3D

enum PickupType { HEALTH, AMMO }

@export var type: PickupType = PickupType.HEALTH:
	set(v):
		type = v
		if sprite:
			setup_pickup()

@export var amount: int = 20

@export_group("Spritesheet Settings")
@export var health_frame: int = 0
@export var ammo_frame: int = 3

@onready var sprite = $Sprite3D

func _ready() -> void:
	setup_pickup()
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)

func setup_pickup() -> void:
	match type:
		PickupType.HEALTH:
			sprite.frame = health_frame
		PickupType.AMMO:
			sprite.frame = ammo_frame

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	sprite.position.y = sin(Time.get_ticks_msec() * 0.005) * 0.1

func _on_body_entered(body: Node3D) -> void:
	if body.has_method("add_pickup"):
		body.add_pickup(type, amount)
		queue_free()
