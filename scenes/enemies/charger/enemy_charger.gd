extends BaseEnemy
class_name EnemyCharger

@export_group("Charge")
@export var charge_trigger_distance: float = 8.0  ## Player range that starts the windup
@export var charge_windup: float = 0.5            ## Pause before launching (telegraphs the charge)
@export var charge_speed: float = 12.0            ## Sprint speed during charge
@export var stumble_duration: float = 0.9         ## Stumble time after overshooting / hitting wall

enum ChargeState { WAITING, WINDING_UP, CHARGING, STUMBLING }

var charge_state: ChargeState = ChargeState.WAITING
var charge_direction: Vector3 = Vector3.ZERO
var _stumble_timer: float = 0.0

func _ready() -> void:
	# Charger just waits — movement is handled entirely by our own _physics_process
	movement_type = MovementType.STATIONARY
	super._ready()

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_apply_gravity(delta)

	match charge_state:
		ChargeState.WAITING:
			_apply_horizontal_damping(delta)
			if not is_stunned and player != null:
				if global_position.distance_to(player.global_position) <= charge_trigger_distance:
					_begin_windup()

		ChargeState.WINDING_UP:
			# Frozen in place — windup timer drives the transition
			_apply_horizontal_damping(delta)

		ChargeState.CHARGING:
			if is_stunned:
				_begin_stumble()
			else:
				velocity.x = charge_direction.x * charge_speed
				velocity.z = charge_direction.z * charge_speed
				if is_on_wall() or _has_overshot():
					_begin_stumble()

		ChargeState.STUMBLING:
			_stumble_timer -= delta
			_apply_horizontal_damping(delta)
			if _stumble_timer <= 0.0:
				charge_state = ChargeState.WAITING

	# Knockback
	if _knockback_velocity.length() > 0.1:
		velocity += _knockback_velocity
		_knockback_velocity = _knockback_velocity.lerp(Vector3.ZERO, 10.0 * delta)
	else:
		_knockback_velocity = Vector3.ZERO

	move_and_slide()

func _begin_windup() -> void:
	if charge_state != ChargeState.WAITING:
		return
	charge_state = ChargeState.WINDING_UP
	# Lock direction toward player at the moment of windup (not at launch)
	charge_direction = (player.global_position - global_position)
	charge_direction.y = 0.0
	charge_direction = charge_direction.normalized()

	# Flash to signal the incoming charge
	_play_hit_flash()

	get_tree().create_timer(charge_windup).timeout.connect(
		func():
			if is_instance_valid(self) and charge_state == ChargeState.WINDING_UP and not is_dead:
				_begin_charge()
	)

func _begin_charge() -> void:
	charge_state = ChargeState.CHARGING
	# Snap direction fresh at launch so player has a tiny window to dodge during windup
	charge_direction = (player.global_position - global_position)
	charge_direction.y = 0.0
	charge_direction = charge_direction.normalized()
	Log.dbg("Charger launched", {"charger": name})

func _begin_stumble() -> void:
	if charge_state == ChargeState.STUMBLING:
		return
	charge_state = ChargeState.STUMBLING
	_stumble_timer = stumble_duration
	Log.dbg("Charger stumbling", {"charger": name})

func _has_overshot() -> bool:
	if player == null:
		return false
	var to_player = player.global_position - global_position
	to_player.y = 0.0
	# If the dot product flips negative we've passed the player
	return to_player.dot(charge_direction) < 0.0
