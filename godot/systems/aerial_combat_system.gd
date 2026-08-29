class_name WildDashAerialCombatSystem
extends RefCounted

## Shared, intentionally simple aerial scaling. Fall speed, height, agility and
## horizontal momentum matter, but all inputs are clamped so Stomp never turns
## into an unbounded physics multiplier.

const MIN_EFFECT_SCALE: float = 0.88
const MAX_EFFECT_SCALE: float = 1.32

static func get_effect_scale(
	racer: WildDashCharacterController,
	fall_speed: float,
	height_difference: float,
	horizontal_speed: float
) -> float:
	if racer == null:
		return 1.0
	var agility: float = WildDashAnimalAbilityProfile.get_stat(racer.animal_id, &"agility")
	var fall_ratio: float = clampf(absf(minf(0.0, fall_speed)) / 10.0, 0.0, 1.0)
	var height_ratio: float = clampf(height_difference / 2.8, 0.0, 1.0)
	var speed_reference: float = maxf(1.0, racer.arena_move_speed)
	var momentum_ratio: float = clampf(horizontal_speed / speed_reference, 0.0, 1.25)
	var agility_ratio: float = clampf(agility / 10.0, 0.0, 1.0)
	var combined: float = fall_ratio * 0.34 + height_ratio * 0.24 + minf(1.0, momentum_ratio) * 0.18 + agility_ratio * 0.24
	return lerpf(MIN_EFFECT_SCALE, MAX_EFFECT_SCALE, clampf(combined, 0.0, 1.0))

static func get_bounce_scale(animal_id: StringName) -> float:
	match animal_id:
		&"rabbit": return 0.58
		&"monkey": return 0.50
		&"deer": return 0.42
		&"cat": return 0.40
		_: return 0.36

static func get_chain_window(animal_id: StringName) -> float:
	return 1.0 if animal_id == &"rabbit" else 0.0

static func get_chain_stagger_bonus(chain_count: int) -> float:
	return clampf(float(maxi(0, chain_count - 1)) * 4.0, 0.0, 8.0)
