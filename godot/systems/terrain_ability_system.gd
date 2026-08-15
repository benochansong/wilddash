class_name WildDashTerrainAbilitySystem
extends RefCounted

## Shared adapter that turns the canonical animal ability profile into terrain
## movement multipliers. Keep mode-specific terrain detection outside this file.

const TERRAIN_LAND: StringName = &"land"
const TERRAIN_WATER: StringName = &"water"
const TERRAIN_ROUGH: StringName = &"rough"

static func get_terrain_speed_multiplier(animal_id: StringName, terrain_type: StringName) -> float:
	match terrain_type:
		TERRAIN_WATER:
			return _water_multiplier(animal_id)
		TERRAIN_ROUGH:
			var rough := WildDashAnimalAbilityProfile.get_stat(animal_id, &"rough")
			return lerpf(0.86, 1.08, clampf(rough / 10.0, 0.0, 1.0))
		_:
			return 1.0

static func _water_multiplier(animal_id: StringName) -> float:
	if animal_id == &"crocodile":
		return 1.37
	var swim := WildDashAnimalAbilityProfile.get_stat(animal_id, &"swim")
	var multiplier := lerpf(0.82, 1.14, clampf(swim / 10.0, 0.0, 1.0))
	# Preserve distinct water identities instead of making Swim feel like a tiny
	# spreadsheet bonus. Crocodile remains uniquely dominant.
	match animal_id:
		&"raccoon": multiplier = maxf(multiplier, 1.16)
		&"bear": multiplier = maxf(multiplier, 1.15)
		&"elephant": multiplier = maxf(multiplier, 1.10)
		&"cat": multiplier = minf(multiplier, 0.90)
		&"rabbit": multiplier = minf(multiplier, 0.92)
	return multiplier

static func get_terrain_rating(animal_id: StringName, terrain_type: StringName) -> float:
	match terrain_type:
		TERRAIN_WATER:
			return WildDashAnimalAbilityProfile.get_stat(animal_id, &"swim")
		TERRAIN_ROUGH:
			return WildDashAnimalAbilityProfile.get_stat(animal_id, &"rough")
		_:
			return 5.0
