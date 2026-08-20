class_name WildDashTerrainAbilitySystem
extends RefCounted

## Shared adapter that turns the canonical animal ability profile into terrain
## movement multipliers. Keep mode-specific terrain detection outside this file.

const TERRAIN_LAND: StringName = &"land"
const TERRAIN_WATER: StringName = &"water"
const TERRAIN_SHALLOW_WATER: StringName = &"shallow_water"
const TERRAIN_DEEP_WATER: StringName = &"deep_water"
const TERRAIN_ROUGH: StringName = &"rough"
const TERRAIN_CANOPY: StringName = &"canopy"

static func get_terrain_speed_multiplier(animal_id: StringName, terrain_type: StringName) -> float:
	match terrain_type:
		TERRAIN_SHALLOW_WATER:
			return _shallow_water_multiplier(animal_id)
		TERRAIN_DEEP_WATER:
			return _deep_water_multiplier(animal_id)
		TERRAIN_WATER:
			return _water_multiplier(animal_id)
		TERRAIN_ROUGH:
			var rough: float = WildDashAnimalAbilityProfile.get_stat(animal_id, &"rough")
			return lerpf(0.86, 1.08, clampf(rough / 10.0, 0.0, 1.0))
		TERRAIN_CANOPY:
			var agility: float = WildDashAnimalAbilityProfile.get_stat(animal_id, &"agility")
			var climb: float = WildDashAnimalAbilityProfile.get_stat(animal_id, &"climb")
			return lerpf(0.92, 1.10, clampf(maxf(agility, climb) / 10.0, 0.0, 1.0))
		_:
			return 1.0

static func _shallow_water_multiplier(animal_id: StringName) -> float:
	var base: float = _water_multiplier(animal_id)
	var multiplier: float = lerpf(1.0, base, 0.66)
	match animal_id:
		&"crocodile": multiplier = 1.28
		&"raccoon": multiplier = maxf(multiplier, 1.12)
		&"bear": multiplier = maxf(multiplier, 1.11)
		&"elephant": multiplier = maxf(multiplier, 1.10)
		&"cat": multiplier = minf(multiplier, 0.93)
		&"rabbit": multiplier = minf(multiplier, 0.94)
	return multiplier

static func _deep_water_multiplier(animal_id: StringName) -> float:
	var multiplier: float = _water_multiplier(animal_id)
	match animal_id:
		# Round 3's signature terrain: Crocodile should feel dramatically better in
		# deep channels while the generic WATER multiplier remains safe for Round 2.
		&"crocodile": multiplier = 1.45
		&"raccoon": multiplier = maxf(multiplier, 1.18)
		&"bear": multiplier = maxf(multiplier, 1.16)
		&"elephant": multiplier = maxf(multiplier, 1.09)
		&"cat": multiplier = minf(multiplier, 0.86)
		&"rabbit": multiplier = minf(multiplier, 0.84)
		&"monkey": multiplier = minf(multiplier, 0.88)
		&"fox": multiplier = minf(multiplier, 0.92)
	return multiplier

static func _water_multiplier(animal_id: StringName) -> float:
	if animal_id == &"crocodile":
		return 1.37
	var swim: float = WildDashAnimalAbilityProfile.get_stat(animal_id, &"swim")
	var multiplier: float = lerpf(0.82, 1.14, clampf(swim / 10.0, 0.0, 1.0))
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
		TERRAIN_SHALLOW_WATER, TERRAIN_DEEP_WATER, TERRAIN_WATER:
			return WildDashAnimalAbilityProfile.get_stat(animal_id, &"swim")
		TERRAIN_ROUGH:
			return WildDashAnimalAbilityProfile.get_stat(animal_id, &"rough")
		TERRAIN_CANOPY:
			return maxf(
				WildDashAnimalAbilityProfile.get_stat(animal_id, &"climb"),
				WildDashAnimalAbilityProfile.get_stat(animal_id, &"agility")
			)
		_:
			return 5.0

static func get_wave_knockback_multiplier(animal_id: StringName) -> float:
	match animal_id:
		&"crocodile": return 0.34
		&"elephant": return 0.58
		&"bear": return 0.68
		&"raccoon": return 0.72
		&"boar": return 0.82
		&"rabbit": return 1.12
		&"cat": return 1.10
		_:
			return 1.0
