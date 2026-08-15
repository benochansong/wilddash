class_name WildDashRaceCombatProfile
extends RefCounted

## Race Combat adapter. Power and Defense come from the canonical six-stat
## animal ability profile; the remaining combat traits stay independently tuned
## so range/cooldown/launch/stability can preserve species identity.

const DEFAULT_ANIMAL_ID: StringName = &"dog"

const COMBAT_TRAITS: Dictionary = {
	&"elephant": {"stability": 10.0, "cooldown": 1.90, "range": 8.50, "launch": 10.0},
	&"bear":     {"stability": 9.0,  "cooldown": 1.75, "range": 5.20, "launch": 8.2},
	&"boar":     {"stability": 7.5,  "cooldown": 2.15, "range": 4.80, "launch": 6.8},
	&"panda":    {"stability": 8.5,  "cooldown": 2.35, "range": 3.80, "launch": 5.2},
	&"wolf":     {"stability": 7.0,  "cooldown": 1.70, "range": 5.20, "launch": 4.8},
	&"dog":      {"stability": 7.5,  "cooldown": 1.85, "range": 4.00, "launch": 4.0},
	&"deer":     {"stability": 8.0,  "cooldown": 1.90, "range": 5.50, "launch": 4.2},
	&"monkey":   {"stability": 7.8,  "cooldown": 1.65, "range": 4.00, "launch": 3.0},
	&"rabbit":   {"stability": 8.5,  "cooldown": 1.60, "range": 3.80, "launch": 8.0},
	&"fox":      {"stability": 8.5,  "cooldown": 1.55, "range": 4.80, "launch": 4.0},
	&"cat":      {"stability": 9.5,  "cooldown": 1.45, "range": 4.20, "launch": 3.8},
	&"raccoon":  {"stability": 8.8,  "cooldown": 1.60, "range": 4.00, "launch": 2.8},
}

const DEFAULT_TRAITS: Dictionary = {
	"stability": 5.0,
	"cooldown": 2.0,
	"range": 4.0,
	"launch": 4.0,
}

static func get_default_profile() -> Dictionary:
	return get_profile(DEFAULT_ANIMAL_ID)

static func get_profile(animal_id: StringName) -> Dictionary:
	var resolved_animal_id: StringName = animal_id if animal_id != &"" else DEFAULT_ANIMAL_ID
	var traits: Dictionary = COMBAT_TRAITS.get(resolved_animal_id, DEFAULT_TRAITS)
	return {
		"attack_power": get_attack_power(resolved_animal_id),
		"defense": get_defense(resolved_animal_id),
		"stability": float(traits.get("stability", 5.0)),
		"cooldown": float(traits.get("cooldown", 2.0)),
		"range": float(traits.get("range", 4.0)),
		"launch": float(traits.get("launch", 4.0)),
	}

static func _traits(animal_id: StringName) -> Dictionary:
	var resolved_animal_id: StringName = animal_id if animal_id != &"" else DEFAULT_ANIMAL_ID
	return COMBAT_TRAITS.get(resolved_animal_id, DEFAULT_TRAITS)

static func get_attack_power(animal_id: StringName) -> float:
	var resolved_animal_id: StringName = animal_id if animal_id != &"" else DEFAULT_ANIMAL_ID
	return WildDashAnimalAbilityProfile.get_stat(resolved_animal_id, &"power")

static func get_defense(animal_id: StringName) -> float:
	var resolved_animal_id: StringName = animal_id if animal_id != &"" else DEFAULT_ANIMAL_ID
	return WildDashAnimalAbilityProfile.get_stat(resolved_animal_id, &"defense")

static func get_stability(animal_id: StringName) -> float:
	return float(_traits(animal_id).get("stability", 5.0))

static func get_cooldown(animal_id: StringName) -> float:
	return float(_traits(animal_id).get("cooldown", 2.0))

static func get_range(animal_id: StringName) -> float:
	return float(_traits(animal_id).get("range", 4.0))

static func get_launch(animal_id: StringName) -> float:
	return float(_traits(animal_id).get("launch", 4.0))

static func get_stability_recovery_multiplier(animal_id: StringName) -> float:
	return lerpf(0.82, 1.35, clampf(get_stability(animal_id) / 10.0, 0.0, 1.0))

static func get_attack_impulse_scale(animal_id: StringName) -> float:
	return lerpf(0.72, 1.35, clampf(get_attack_power(animal_id) / 10.0, 0.0, 1.0))

static func get_launch_scale(animal_id: StringName) -> float:
	return lerpf(0.55, 1.35, clampf(get_launch(animal_id) / 10.0, 0.0, 1.0))

static func has_complete_profile(animal_id: StringName) -> bool:
	if not WildDashAnimalAbilityProfile.has_complete_profile(animal_id):
		return false
	if not COMBAT_TRAITS.has(animal_id):
		return false
	var profile: Dictionary = get_profile(animal_id)
	for key: String in ["attack_power", "defense", "stability", "cooldown", "range", "launch"]:
		if not profile.has(key):
			return false
	return true
