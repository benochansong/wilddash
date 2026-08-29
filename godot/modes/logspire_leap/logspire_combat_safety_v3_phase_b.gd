extends "res://modes/logspire_leap/logspire_combat_safety_v2_recovery_protection.gd"

## Phase B crowd landing protection.
## Keeps Body Check and items alive, but the first fraction of a second after a
## successful platform landing cannot immediately throw a racer back into water.

const PHASE_B_LANDING_PROTECTION_SECONDS: float = 0.65
const PHASE_B_LANDING_KNOCKBACK_CAP: float = 0.85
const PHASE_B_FIRST_CONTACT_SECONDS: float = 0.18

var _phase_b_landing_protection: Dictionary = {}

func configure() -> void:
	super()
	print("LOGSPIRE PHASE B LANDING PROTECTION READY seconds=%.2f cap=%.2f player_control=true body_check_preserved=true" % [
		PHASE_B_LANDING_PROTECTION_SECONDS, PHASE_B_LANDING_KNOCKBACK_CAP,
	])

func _update_racer_safety(racer: WildDashCharacterController, delta: float) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var id: int = racer.get_instance_id()
	var on_floor: bool = racer.is_on_floor()
	var was_floor: bool = bool(_was_on_floor.get(id, on_floor))
	super(racer, delta)

	if on_floor and not was_floor:
		_phase_b_landing_protection[id] = PHASE_B_LANDING_PROTECTION_SECONDS
	var remaining: float = maxf(0.0, float(_phase_b_landing_protection.get(id, 0.0)) - delta)
	_phase_b_landing_protection[id] = remaining
	if remaining <= 0.0:
		return

	var knockback_value: Variant = racer.get("_knockback_velocity")
	var knockback: Vector3 = knockback_value if knockback_value is Vector3 else Vector3.ZERO
	var planar := Vector3(knockback.x, 0.0, knockback.z)
	var magnitude: float = planar.length()
	if magnitude <= 0.001:
		return
	var elapsed: float = PHASE_B_LANDING_PROTECTION_SECONDS - remaining
	var cap: float = 0.0 if elapsed <= PHASE_B_FIRST_CONTACT_SECONDS else PHASE_B_LANDING_KNOCKBACK_CAP
	if cap <= 0.001:
		racer.set("_knockback_velocity", Vector3(0.0, knockback.y, 0.0))
		return
	if magnitude <= cap:
		return
	var clamped := planar.normalized() * cap
	clamped.y = knockback.y
	racer.set("_knockback_velocity", clamped)
