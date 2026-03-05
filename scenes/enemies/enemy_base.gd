extends CharacterBody3D
class_name BaseEnemy

@export var move_speed = 1.5
@export var acceleration = 3.0
@export var blood_spray_cooldown = 0.2  # Cooldown between damage blood sprays
@export var hit_stun_duration: float = 0.2

@onready var anim_player = $AnimationPlayer
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var health = $Health
@onready var hit_particles: GPUParticles3D = get_node_or_null("HitParticles")

var player : Node3D
var is_dead : bool = false
var is_stunned : bool = false
var damage_taken : float = 0.0  # Track total damage for blood intensity
var last_blood_spray_time : float = -1.0  # Cooldown tracker

func _ready() -> void:
	if anim_player.has_animation("idle"):
		anim_player.play("idle")
	
	# Connect health signals
	health.died.connect(_on_health_died)

func set_player(p):
	player = p

func take_damage(amount):
	if is_dead: return
	damage_taken += amount  # Track total damage taken
	if hit_particles:
		hit_particles.restart()
		hit_particles.emitting = true
	health.take_damage(amount)
	_apply_hit_stun()

func _apply_hit_stun():
	is_stunned = true
	velocity = Vector3.ZERO
	if anim_player.has_animation("take_damage"):
		anim_player.play("take_damage")
	await get_tree().create_timer(hit_stun_duration).timeout
	if not is_dead:
		is_stunned = false
		if anim_player.has_animation("idle"):
			anim_player.play("idle")
	
	# Spawn small blood splatter when damaged (with cooldown to avoid spam)
	var current_time = Time.get_ticks_msec() / 1000.0
	if current_time - last_blood_spray_time >= blood_spray_cooldown:
		last_blood_spray_time = current_time
		var damage_direction = (player.global_position - global_position).normalized() if player else Vector3.FORWARD
		BloodDecalPool.spawn_blood_at_position(
			global_position,
			damage_direction,
			get_tree().current_scene,
			0.2  # Small intensity (0.2x scale)
		)

func _on_health_died():
	die()

func die():
	is_dead = true
	# Disable collision so the player can walk through the "corpse"
	collision_layer = 0
	collision_mask = 0
	
	# Spawn blood decals with damage intensity
	var death_direction = (player.global_position - global_position).normalized() if player else Vector3.FORWARD
	BloodDecalPool.spawn_blood_at_position(
		global_position,
		death_direction,
		get_tree().current_scene,
		damage_taken
	)
	
	anim_player.play("die")
	await anim_player.animation_finished
	queue_free()
