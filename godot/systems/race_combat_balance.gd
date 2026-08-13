class_name WildDashRaceCombatBalance
extends RefCounted

## Shared race-contact defense model for all 12 playable animals.
## A higher defense rating means less received knockback and less launch.

const DEFENSE_RATINGS: Dictionary = {
	&"elephant": 10.0,
	&"bear": 9.0,
	&"boar": 8.5,
	&"panda": 8.0,
	&"wolf": 6.5,
	&"dog": 6.0,
	&"deer": 5.5,
	&"monkey": 5.0,
	&"rabbit": 4.5,
	&"fox": 4.0,
	&"cat": 3.5,
	&"raccoon": 3.0,
}

const KNOCKBACK_MULTIPLIERS: Dictionary = {
	&"elephant": 0.56,
	&"bear": 0.64,
	&"boar": 0.70,
	&"panda": 0.75,
	&"wolf": 0.88,
	&"dog": 0.92,
	&"deer": 0.98,
	&"monkey": 1.02,
	&"rabbit": 1.08,
	&"fox": 1.13,
	&"cat": 1.18,
	&"raccoon": 1.22,
}

static func get_defense_rating(animal_id: StringName) -> float:
	return float(DEFENSE_RATINGS.get(animal_id, 5.0))

static func get_knockback_multiplier(animal_id: StringName) -> float:
	return float(KNOCKBACK_MULTIPLIERS.get(animal_id, 1.0))

static func get_effective_impulse(raw_power: float, target_id: StringName) -> float:
	return raw_power * get_knockback_multiplier(target_id)

static func get_launch_strength(raw_power: float, target_id: StringName) -> float:
	var effective: float = get_effective_impulse(raw_power, target_id)
	var defense: float = get_defense_rating(target_id)
	if effective < 10.5:
		return 0.0
	if defense <= 4.0:
		return clampf(1.6 + (effective - 10.5) * 0.16, 1.6, 3.4)
	if defense <= 5.5:
		return clampf(1.0 + (effective - 10.5) * 0.11, 1.0, 2.4)
	if defense <= 7.0:
		return clampf(0.55 + (effective - 10.5) * 0.07, 0.55, 1.5)
	return 0.0

static func get_defense_label(animal_id: StringName) -> String:
	var defense: float = get_defense_rating(animal_id)
	if defense >= 9.0:
		return "FORTRESS"
	if defense >= 7.5:
		return "HEAVY"
	if defense >= 5.5:
		return "STABLE"
	if defense >= 4.0:
		return "LIGHT"
	return "FEATHER"
