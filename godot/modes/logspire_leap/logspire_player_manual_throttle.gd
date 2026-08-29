extends Node

## Round 3 player movement policy.
## Logspire is a precision platforming race: W/Up is explicit forward movement.
## Unlike the faster circuit rounds, neutral input must not auto-cruise the
## player off narrow platforms, logs or cylinders.

const MODE_ID: StringName = &"logspire_leap"
const NEUTRAL_THROTTLE_DEADZONE: float = 0.05
const ORIGINAL_CRUISE_META: StringName = &"logspire_original_cruise_speed"
const MANUAL_THROTTLE_META: StringName = &"logspire_manual_throttle"

var _player_id: int = 0

func _ready() -> void:
	process_physics_priority = -100

func _physics_process(_delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var racer: WildDashCharacterController = _resolve_player()
	if racer == null:
		return

	# Persistently remove the base CharacterController's neutral cruise only for
	# the Round 3 player. W/Up still uses max_speed in the shared controller.
	if not racer.has_meta(ORIGINAL_CRUISE_META):
		racer.set_meta(ORIGINAL_CRUISE_META, racer.cruise_speed)
		racer.set_meta(MANUAL_THROTTLE_META, true)
		print("LOGSPIRE PLAYER MANUAL THROTTLE READY racer=%s original_cruise=%.2f neutral_cruise=0.00" % [
			RaceManager.get_racer_label(racer), racer.cruise_speed,
		])
	racer.cruise_speed = 0.0

	# If already settled on a surface with no forward/back input, remove only
	# self-propelled speed. External knockback and skill impulses remain intact.
	var throttle: float = InputManager.get_throttle_axis()
	if absf(throttle) > NEUTRAL_THROTTLE_DEADZONE or not racer.is_on_floor():
		return
	var knockback: Vector3 = racer.get_knockback_velocity()
	var skill_impulse_value: Variant = racer.get("_skill_impulse_velocity")
	var skill_impulse: Vector3 = skill_impulse_value if skill_impulse_value is Vector3 else Vector3.ZERO
	if knockback.length_squared() > 0.0025 or skill_impulse.length_squared() > 0.0025:
		return
	racer.current_speed = 0.0

func _resolve_player() -> WildDashCharacterController:
	if _player_id != 0:
		var existing := instance_from_id(_player_id) as WildDashCharacterController
		if existing != null and is_instance_valid(existing) and existing.is_player:
			return existing
		_player_id = 0

	var parent_mode: Node = get_parent()
	if parent_mode == null:
		return null
	var mode_value: Variant = parent_mode.get("mode_id")
	if not (mode_value is StringName or mode_value is String) or StringName(mode_value) != MODE_ID:
		return null

	for value: Variant in RaceManager.racers.duplicate():
		var racer := value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or not racer.is_player:
			continue
		_player_id = racer.get_instance_id()
		return racer
	return null
