class_name WildDashRaceTerrainProfile
extends RefCounted

## Shared terrain affinity model for all 12 playable animals.
## Ratings are gameplay-oriented rather than strict zoological simulation.
## Each axis is 1-10 and is intentionally separate from race/combat stats.
##
## swim:    water speed and resistance to river current
## climb:   uphill / mountain pace retention
## agility: obstacle avoidance and technical shortcut aptitude
## power:   ability to push through light breakable obstacles
## rough:   resistance to mud, gravel, snow and uneven terrain slowdown

const PROFILES: Dictionary = {
	&"elephant": {"swim": 8.5, "climb": 4.5, "agility": 3.0, "power": 10.0, "rough": 10.0},
	&"bear":     {"swim": 10.0, "climb": 9.0, "agility": 5.0, "power": 9.5, "rough": 9.5},
	&"boar":     {"swim": 6.5, "climb": 8.0, "agility": 5.5, "power": 9.0, "rough": 10.0},
	&"panda":    {"swim": 6.0, "climb": 7.0, "agility": 6.0, "power": 7.5, "rough": 8.5},
	&"wolf":     {"swim": 5.5, "climb": 9.0, "agility": 8.0, "power": 6.5, "rough": 7.5},
	&"dog":      {"swim": 7.5, "climb": 7.0, "agility": 7.0, "power": 6.5, "rough": 7.0},
	&"deer":     {"swim": 5.5, "climb": 8.5, "agility": 9.0, "power": 5.5, "rough": 8.0},
	&"monkey":   {"swim": 4.5, "climb": 10.0, "agility": 10.0, "power": 5.5, "rough": 7.0},
	&"rabbit":   {"swim": 3.5, "climb": 7.5, "agility": 10.0, "power": 4.5, "rough": 6.0},
	&"fox":      {"swim": 4.5, "climb": 8.0, "agility": 9.5, "power": 5.5, "rough": 7.0},
	&"cat":      {"swim": 2.5, "climb": 9.5, "agility": 10.0, "power": 4.5, "rough": 6.5},
	&"raccoon":  {"swim": 8.5, "climb": 7.5, "agility": 9.0, "power": 5.0, "rough": 8.5},
}

const DEFAULT_PROFILE: Dictionary = {
	"swim": 5.0,
	"climb": 5.0,
	"agility": 5.0,
	"power": 5.0,
	"rough": 5.0,
}

static func get_profile(animal_id: StringName) -> Dictionary:
	var profile: Dictionary = PROFILES.get(animal_id, DEFAULT_PROFILE)
	return profile.duplicate(true)

static func _profile(animal_id: StringName) -> Dictionary:
	return PROFILES.get(animal_id, DEFAULT_PROFILE)

static func get_swim(animal_id: StringName) -> float:
	return float(_profile(animal_id).get("swim", 5.0))

static func get_climb(animal_id: StringName) -> float:
	return float(_profile(animal_id).get("climb", 5.0))

static func get_agility(animal_id: StringName) -> float:
	return float(_profile(animal_id).get("agility", 5.0))

static func get_power(animal_id: StringName) -> float:
	return float(_profile(animal_id).get("power", 5.0))

static func get_rough(animal_id: StringName) -> float:
	return float(_profile(animal_id).get("rough", 5.0))

static func get_swim_speed_ratio(animal_id: StringName) -> float:
	# Water specialists can slightly exceed ordinary race pace, while weak
	# swimmers lose meaningful speed. Bear tops out around 1.03x max speed.
	return lerpf(0.68, 1.03, clampf(get_swim(animal_id) / 10.0, 0.0, 1.0))

static func get_swim_acceleration_scale(animal_id: StringName) -> float:
	return lerpf(0.72, 1.18, clampf(get_swim(animal_id) / 10.0, 0.0, 1.0))

static func get_river_current_susceptibility(animal_id: StringName) -> float:
	# Strong swimmers and rough-terrain heavyweights resist sideways current.
	var resistance_rating: float = (get_swim(animal_id) + get_rough(animal_id)) * 0.5
	return lerpf(1.12, 0.34, clampf(resistance_rating / 10.0, 0.0, 1.0))

static func get_climb_speed_ratio(animal_id: StringName) -> float:
	return lerpf(0.72, 1.03, clampf(get_climb(animal_id) / 10.0, 0.0, 1.0))

static func get_rough_speed_ratio(animal_id: StringName) -> float:
	return lerpf(0.70, 1.0, clampf(get_rough(animal_id) / 10.0, 0.0, 1.0))

static func can_break_light_obstacle(animal_id: StringName) -> bool:
	return get_power(animal_id) >= 8.5

static func has_complete_profile(animal_id: StringName) -> bool:
	if not PROFILES.has(animal_id):
		return false
	var profile: Dictionary = PROFILES[animal_id]
	for key: String in ["swim", "climb", "agility", "power", "rough"]:
		if not profile.has(key):
			return false
	return true
