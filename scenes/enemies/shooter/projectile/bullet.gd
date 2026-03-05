extends Node3D

@export var speed = 5.0
@export var damage = 1
@export var lifetime = 5.0  # Destroy after 5 seconds if no collision

@onready var hurtbox = $Hurtbox
@onready var impact_sparks = $ImpactSparks

var direction = Vector3.ZERO

func _ready():
	# Connect collision signal
	hurtbox.body_entered.connect(_on_body_entered)
	
	# Auto-destroy after lifetime to prevent infinite bullets
	get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta):
	global_position += direction * speed * delta

func _on_body_entered(body):
	# Damage the target if possible
	if body.has_method("take_damage"):
		body.take_damage(damage)
		# Destroy immediately when hitting player
		queue_free()
	else:
		# Spawn sparks only when hitting walls/environment (not player)
		if impact_sparks:
			impact_sparks.emitting = true
			# Wait for particles to finish before destroying
			await get_tree().create_timer(0.5).timeout
		# Destroy after particles play
		queue_free()
