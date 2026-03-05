extends Area3D

@export var damage = 1
@export var delete_after = true  # If false, hurtbox persists for melee attacks
@export var repeat_cooldown = 0.0  # If > 0, deals damage again after this cooldown (melee mode)

var damage_cooldown_timer = 0.0  # Single cooldown timer for all bodies

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.has_method("take_damage"):
		Log.dbg("Hurtbox dealt damage", {"target": body.name, "damage": damage, "source": get_parent().name})
		body.take_damage(damage)
		
		# If this is a persistent attack (melee), start cooldown
		if repeat_cooldown > 0.0:
			damage_cooldown_timer = repeat_cooldown
	
	# Self-destruct if configured (for projectile-based attacks)
	if delete_after:
		queue_free()

func _process(delta):
	# Update cooldown for persistent melee attacks
	if repeat_cooldown > 0.0 and damage_cooldown_timer > 0.0:
		damage_cooldown_timer -= delta
		
		# Ready to deal damage again to any overlapping body
		if damage_cooldown_timer <= 0.0:
			for body in get_overlapping_bodies():
				if body.has_method("take_damage"):
					body.take_damage(damage)
					damage_cooldown_timer = repeat_cooldown
					break  # Only damage one body per cycle
