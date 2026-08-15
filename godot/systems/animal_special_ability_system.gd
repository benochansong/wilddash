class_name WildDashAnimalSpecialAbilitySystem
extends RefCounted

## Shared data/rules for character-specific party abilities. Runtime hit/spill
## application stays in each mode so Round 1 item input is never affected.

const SUPPORTED_MODES: Array[StringName] = [&"fruit_collection", &"push_out"]

const SPECIALS: Dictionary = {
	&"boar": {
		"id": &"mud_gas", "name": "MUD GAS", "cooldown": 6.0,
		"radius": 4.6, "knockback": 3.2, "stagger": 8.0, "slow": 0.78, "duration": 1.05,
	},
	&"bear": {
		"id": &"heavy_gas", "name": "HEAVY GAS", "cooldown": 7.0,
		"radius": 4.9, "knockback": 4.1, "stagger": 7.0, "slow": 0.88, "duration": 0.70,
	},
	&"raccoon": {
		"id": &"stink_cloud", "name": "STINK CLOUD", "cooldown": 7.0,
		"radius": 4.2, "knockback": 1.2, "stagger": 4.0, "slow": 0.72, "duration": 2.0,
	},
	&"monkey": {
		"id": &"jet_fart", "name": "JET FART", "cooldown": 5.5,
		"radius": 3.8, "knockback": 2.8, "stagger": 6.0, "slow": 0.90, "duration": 0.55,
		"forward_impulse": 3.0,
	},
}

static func can_use_special(animal_id: StringName, mode_id: StringName) -> bool:
	return SUPPORTED_MODES.has(mode_id) and SPECIALS.has(animal_id)

static func get_special(animal_id: StringName) -> Dictionary:
	return (SPECIALS.get(animal_id, {}) as Dictionary).duplicate(true)

static func get_special_id(animal_id: StringName) -> StringName:
	return StringName(get_special(animal_id).get("id", &""))

static func get_special_name(animal_id: StringName) -> String:
	return str(get_special(animal_id).get("name", "SPECIAL"))

static func get_special_cooldown(animal_id: StringName) -> float:
	return float(get_special(animal_id).get("cooldown", 0.0))
