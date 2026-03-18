extends BaseEnemy
class_name EnemyShooter

const BULLET_SCENE = preload("res://scenes/enemies/shooter/projectile/bullet.tscn")

@export_group("Burst Fire")
@export var fire_rate: float = 2.5    ## Cooldown between bursts
@export var burst_count: int = 3      ## Bullets per burst
@export var burst_delay: float = 0.12 ## Seconds between shots in a burst

@export_group("Suppression")
@export var suppress_duration: float = 2.0  ## How long shooter retreats after being hit

var can_shoot: bool = true
var is_suppressed: bool = false

func _ready() -> void:
	movement_type = MovementType.STRAFE
	super._ready()

## Override nav target: retreat away from player when suppressed, otherwise normal strafe.
func _calculate_target_position(delta: float) -> Vector3:
	if is_suppressed:
		var away_dir = (global_position - player.global_position).normalized()
		away_dir.y = 0.0
		return global_position + away_dir * 6.0
	return super._calculate_target_position(delta)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	if is_dead or is_stunned or player == null:
		return

	# Shoot only when not suppressed and have LOS
	if can_shoot and not is_suppressed and _has_line_of_sight():
		_shoot()

func take_damage(amount) -> void:
	super.take_damage(amount)
	_trigger_suppression()

func _trigger_suppression() -> void:
	if is_suppressed or is_dead:
		return
	is_suppressed = true
	Log.dbg("Shooter suppressed", {"shooter": name, "duration": suppress_duration})
	await get_tree().create_timer(suppress_duration).timeout
	if is_instance_valid(self) and not is_dead:
		is_suppressed = false

func _has_line_of_sight() -> bool:
	var space_state = get_world_3d().direct_space_state
	var shoot_pos = global_position + Vector3(0, 0.5, 0)
	var player_pos = player.global_position + Vector3(0, 0.5, 0)

	var query = PhysicsRayQueryParameters3D.create(shoot_pos, player_pos)
	query.collision_mask = 1

	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return true
	return result.get("collider") == player

func _shoot() -> void:
	can_shoot = false
	Log.dbg("Shooter burst started", {"shooter": name, "burst_count": burst_count})
	SoundManager.play_sfx(SoundManager.SFX_ENEMY_SHOOTS)

	if anim_player.has_animation("shoot"):
		anim_player.play("shoot")

	for i in burst_count:
		if i > 0:
			await get_tree().create_timer(burst_delay).timeout
		if is_dead:
			break
		_fire_bullet()
		# Play shoot sound and animation on each subsequent shot in the burst
		if i > 0:
			SoundManager.play_sfx(SoundManager.SFX_ENEMY_SHOOTS)

	await get_tree().create_timer(fire_rate).timeout
	if is_instance_valid(self) and not is_dead:
		can_shoot = true

func _fire_bullet() -> void:
	if player == null:
		return
	var bullet = BULLET_SCENE.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position + Vector3(0, 0.5, 0)
	bullet.direction = (player.global_position - bullet.global_position).normalized()
