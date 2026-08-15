class_name WildDashRaceTerrainProfile
extends RefCounted

## Terrain adapter for the canonical six-stat animal ability profile.
## Public API is preserved so existing race/terrain systems do not need to know
## where player-facing ratings are stored.
##
## swim:    water speed and resistance to river current
## climb:   uphill / mountain pace retention
## agility: obstacle avoidance and technical shortcut aptitude
## power:   ability to push through light breakable obstacles
## rough:   resistance to mud, gravel, snow and uneven terrain slowdown

const DEFAULT_PROFILE: Dictionary = {
	"swim": 5.0,
	"climb": 5.0,
	"agility": 5.0,
	"power": 5.0,
	"rough": 5.0,
}

static func get_profile(animal_id: StringName) -> Dictionary:
	var ability: Dictionary = WildDashAnimalAbilityProfile.get_profile(animal_id)
	return {
		"swim": float(ability.get("swim", 5.0)),
		"climb": float(ability.get("climb", 5.0)),
		"agility": float(ability.get("agility", 5.0)),
		"power": float(ability.get("power", 5.0)),
		"rough": float(ability.get("rough", 5.0)),
	}

static func _profile(animal_id: StringName) -> Dictionary:
	return get_profile(animal_id)

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
	# 9-10 point water specialists retain a small real advantage while weak
	# swimmers still suffer a meaningful pace loss.
	return lerpf(0.68, 1.05, clampf(get_swim(animal_id) / 10.0, 0.0, 1.0))

static func get_swim_acceleration_scale(animal_id: StringName) -> float:
	return lerpf(0.72, 1.18, clampf(get_swim(animal_id) / 10.0, 0.0, 1.0))

static func get_river_current_susceptibility(animal_id: StringName) -> float:
	var resistance_rating: float = (get_swim(animal_id) + get_rough(animal_id)) * 0.5
	return lerpf(1.12, 0.34, clampf(resistance_rating / 10.0, 0.0, 1.0))

static func get_climb_speed_ratio(animal_id: StringName) -> float:
	return lerpf(0.72, 1.03, clampf(get_climb(animal_id) / 10.0, 0.0, 1.0))

static func get_rough_speed_ratio(animal_id: StringName) -> float:
	return lerpf(0.70, 1.0, clampf(get_rough(animal_id) / 10.0, 0.0, 1.0))

static func can_break_light_obstacle(animal_id: StringName) -> bool:
	return get_power(animal_id) >= 8.5

static func has_complete_profile(animal_id: StringName) -> bool:
	if not WildDashAnimalAbilityProfile.has_complete_profile(animal_id):
		return false
	var profile: Dictionary = get_profile(animal_id)
	for key: String in ["swim", "climb", "agility", "power", "rough"]:
		if not profile.has(key):
			return false
	return true
