class_name WildDashRaceCombatProfile
extends RefCounted

## Shared Race Combat Core V2 tuning for all playable animals.
## Values are intentionally separated from movement stats so race speed can be
## balanced independently from combat identity.
##
## attack_power: 1-10 contact/offense rating
## defense:      1-10 received-force resistance rating
## stability:    1-10 recovery/poise rating after an impact
## cooldown:     baseline F combat cooldown in seconds
## range:        baseline F combat reach in metres
## launch:       1-10 vertical/ring-out threat rating

const PROFILES: Dictionary = {
	&"elephant": {"attack_power": 10.0, "defense": 10.0, "stability": 10.0, "cooldown": 1.90, "range": 8.50, "launch": 10.0},
	&"bear":     {"attack_power": 9.0,  "defense": 9.0,  "stability": 8.5,  "cooldown": 2.20, "range": 4.20, "launch": 7.5},
	&"boar":     {"attack_power": 9.0,  "defense": 8.5,  "stability": 7.5,  "cooldown": 2.15, "range": 4.80, "launch": 6.8},
	&"panda":    {"attack_power": 7.5,  "defense": 8.0,  "stability": 8.5,  "cooldown": 2.35, "range": 3.80, "launch": 5.2},
	&"wolf":     {"attack_power": 7.5,  "defense": 6.5,  "stability": 7.0,  "cooldown": 1.70, "range": 5.20, "launch": 4.8},
	&"dog":      {"attack_power": 6.5,  "defense": 6.0,  "stability": 7.5,  "cooldown": 1.85, "range": 4.00, "launch": 4.0},
	&"deer":     {"attack_power": 6.2,  "defense": 5.5,  "stability": 8.0,  "cooldown": 1.90, "range": 5.50, "launch": 4.2},
	&"monkey":   {"attack_power": 5.8,  "defense": 5.0,  "stability": 7.8,  "cooldown": 1.65, "range": 4.00, "launch": 3.0},
	&"rabbit":   {"attack_power": 5.5,  "defense": 4.5,  "stability": 8.5,  "cooldown": 1.60, "range": 3.80, "launch": 8.0},
	&"fox":      {"attack_power": 6.0,  "defense": 4.0,  "stability": 8.5,  "cooldown": 1.55, "range": 4.80, "launch": 4.0},
	&"cat":      {"attack_power": 5.5,  "defense": 3.5,  "stability": 9.5,  "cooldown": 1.45, "range": 4.20, "launch": 3.8},
	&"raccoon":  {"attack_power": 5.0,  "defense": 3.0,  "stability": 8.8,  "cooldown": 1.60, "range": 4.00, "launch": 2.8},
}

const DEFAULT_PROFILE: Dictionary = {
	"attack_power": 5.0,
	"defense": 5.0,
	"stability": 5.0,
	"cooldown": 2.0,
	"range": 4.0,
	"launch": 4.0,
}

static func get_profile(animal_id: StringName) -> Dictionary:
	var profile: Dictionary = PROFILES.get(animal_id, DEFAULT_PROFILE)
	return profile.duplicate(true)

static func _profile(animal_id: StringName) -> Dictionary:
	return PROFILES.get(animal_id, DEFAULT_PROFILE)

static func get_attack_power(animal_id: StringName) -> float:
	var profile: Dictionary = _profile(animal_id)
	return float(profile.get("attack_power", 5.0))

static func get_defense(animal_id: StringName) -> float:
	var profile: Dictionary = _profile(animal_id)
	return float(profile.get("defense", 5.0))

static func get_stability(animal_id: StringName) -> float:
	var profile: Dictionary = _profile(animal_id)
	return float(profile.get("stability", 5.0))

static func get_cooldown(animal_id: StringName) -> float:
	var profile: Dictionary = _profile(animal_id)
	return float(profile.get("cooldown", 2.0))

static func get_range(animal_id: StringName) -> float:
	var profile: Dictionary = _profile(animal_id)
	return float(profile.get("range", 4.0))

static func get_launch(animal_id: StringName) -> float:
	var profile: Dictionary = _profile(animal_id)
	return float(profile.get("launch", 4.0))

static func get_stability_recovery_multiplier(animal_id: StringName) -> float:
	# High stability means a quicker recovery from a hit without reducing the
	# initial spectacle of the impact itself.
	return lerpf(0.82, 1.35, clampf(get_stability(animal_id) / 10.0, 0.0, 1.0))

static func get_attack_impulse_scale(animal_id: StringName) -> float:
	return lerpf(0.72, 1.35, clampf(get_attack_power(animal_id) / 10.0, 0.0, 1.0))

static func get_launch_scale(animal_id: StringName) -> float:
	return lerpf(0.55, 1.35, clampf(get_launch(animal_id) / 10.0, 0.0, 1.0))

static func has_complete_profile(animal_id: StringName) -> bool:
	if not PROFILES.has(animal_id):
		return false
	var profile: Dictionary = PROFILES[animal_id]
	for key: String in ["attack_power", "defense", "stability", "cooldown", "range", "launch"]:
		if not profile.has(key):
			return false
	return true
