class_name WildDashRaceCombatBalance
extends RefCounted

## Shared race-contact defense model for all 12 playable animals.
## A higher defense rating means less received knockback, launch and item disruption.

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
	&"elephant": 0.50,
	&"bear": 0.62,
	&"boar": 0.69,
	&"panda": 0.74,
	&"wolf": 0.88,
	&"dog": 0.92,
	&"deer": 0.98,
	&"monkey": 1.03,
	&"rabbit": 1.10,
	&"fox": 1.16,
	&"cat": 1.22,
	&"raccoon": 1.28,
}

const ITEM_DISRUPTION_MULTIPLIERS: Dictionary = {
	&"elephant": 0.52,
	&"bear": 0.68,
	&"boar": 0.74,
	&"panda": 0.78,
	&"wolf": 0.90,
	&"dog": 0.94,
	&"deer": 0.98,
	&"monkey": 1.00,
	&"rabbit": 1.04,
	&"fox": 1.07,
	&"cat": 1.10,
	&"raccoon": 1.12,
}

static func get_defense_rating(animal_id: StringName) -> float:
	return float(DEFENSE_RATINGS.get(animal_id, 5.0))

static func get_knockback_multiplier(animal_id: StringName) -> float:
	return float(KNOCKBACK_MULTIPLIERS.get(animal_id, 1.0))

static func get_item_disruption_multiplier(animal_id: StringName) -> float:
	return float(ITEM_DISRUPTION_MULTIPLIERS.get(animal_id, 1.0))

static func get_effective_impulse(raw_power: float, target_id: StringName) -> float:
	return raw_power * get_knockback_multiplier(target_id)

static func get_launch_strength(raw_power: float, target_id: StringName) -> float:
	var effective: float = get_effective_impulse(raw_power, target_id)
	var defense: float = get_defense_rating(target_id)
	if effective < 10.0:
		return 0.0
	if defense <= 3.5:
		return clampf(2.8 + (effective - 10.0) * 0.22, 2.8, 5.6)
	if defense <= 4.5:
		return clampf(2.1 + (effective - 10.0) * 0.18, 2.1, 4.8)
	if defense <= 5.5:
		return clampf(1.25 + (effective - 10.0) * 0.12, 1.25, 3.1)
	if defense <= 7.0:
		return clampf(0.55 + (effective - 10.0) * 0.07, 0.55, 1.6)
	return 0.0

static func get_item_speed_floor_ratio(animal_id: StringName) -> float:
	var defense: float = get_defense_rating(animal_id)
	if defense >= 10.0:
		return 0.80
	if defense >= 9.0:
		return 0.74
	if defense >= 8.0:
		return 0.69
	if defense >= 6.0:
		return 0.62
	return 0.55

static func get_item_recovery_seconds(animal_id: StringName) -> float:
	var defense: float = get_defense_rating(animal_id)
	if defense >= 10.0:
		return 0.72
	if defense >= 9.0:
		return 0.82
	if defense >= 8.0:
		return 0.92
	return 1.0

static func get_trap_launch_multiplier(animal_id: StringName) -> float:
	var defense: float = get_defense_rating(animal_id)
	if defense >= 10.0:
		return 0.48
	if defense >= 9.0:
		return 0.60
	if defense >= 8.0:
		return 0.70
	if defense >= 6.0:
		return 0.86
	return 1.0

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
