extends Node3D

@export var speed = 5.0
@export var lifetime = 5.0  # Destroy after 5 seconds if no collision

@onready var hurtbox = $Hurtbox
@onready var impact_sparks = $ImpactSparks

var direction = Vector3.ZERO

func _ready():
	# Start with monitoring off to avoid spawn-overlap false positives.
	# set_deferred re-enables it after the current physics step has passed.
	hurtbox.monitoring = false
	hurtbox.body_entered.connect(_on_body_entered)
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	hurtbox.set_deferred("monitoring", true)

func _physics_process(delta):
	global_position += direction * speed * delta

func _on_body_entered(body):
	# hurtbox.gd handles damage; bullet manages FX and self-destruct
	if body.has_method("take_damage"):
		Log.dbg("Bullet hit player")
		queue_free()
	else:
		Log.dbg("Bullet hit environment", {"body": body.name})
		# Wall/environment hit: show sparks then destroy
		if impact_sparks:
			impact_sparks.emitting = true
			await get_tree().create_timer(0.5).timeout
		queue_free()
