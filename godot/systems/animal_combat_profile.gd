class_name WildDashAnimalCombatProfile
extends RefCounted

## Combat V2 profile authority. Phase 1 deliberately defines full bespoke data
## only for Crocodile; all other animals receive conservative generic adapters so
## their proven Round 2 / Round 4 combat keeps working until later character
## passes replace those defaults.

const GENERIC_BASIC_ID: StringName = &"quick_bash"
const GENERIC_HEAVY_ID: StringName = &"heavy_smash"
const GENERIC_AERIAL_ID: StringName = &"stomp"

const CROCODILE_BITE_ID: StringName = &"crocodile_bite_lunge"
const CROCODILE_TAIL_ID: StringName = &"crocodile_tail_sweep"
const CROCODILE_WATER_AMBUSH_ID: StringName = &"crocodile_water_ambush"

static func get_basic_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	if animal_id == &"crocodile":
		return _crocodile_bite()
	return _generic_basic()

static func get_heavy_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	if animal_id == &"crocodile":
		return _crocodile_tail()
	return _generic_heavy()

static func get_aerial_attack(_animal_id: StringName) -> WildDashCombatAbilitySpec:
	return _generic_stomp()

static func get_special_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	if animal_id == &"crocodile":
		return _crocodile_water_ambush()
	return null

static func get_ability(animal_id: StringName, ability_id: StringName) -> WildDashCombatAbilitySpec:
	var basic: WildDashCombatAbilitySpec = get_basic_attack(animal_id)
	if basic != null and basic.ability_id == ability_id:
		return basic
	var heavy: WildDashCombatAbilitySpec = get_heavy_attack(animal_id)
	if heavy != null and heavy.ability_id == ability_id:
		return heavy
	var aerial: WildDashCombatAbilitySpec = get_aerial_attack(animal_id)
	if aerial != null and aerial.ability_id == ability_id:
		return aerial
	var special: WildDashCombatAbilitySpec = get_special_attack(animal_id)
	if special != null and special.ability_id == ability_id:
		return special
	return null

static func _generic_basic() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySpec.new()
	spec.ability_id = GENERIC_BASIC_ID
	spec.display_name = "QUICK BASH"
	spec.attack_type = WildDashCombatAbilitySpec.AttackType.BASIC
	spec.impact_types = [
		WildDashCombatAbilitySpec.ImpactType.PUSH,
		WildDashCombatAbilitySpec.ImpactType.STAGGER,
	]
	spec.range = 3.65
	spec.arc_dot = -0.04
	spec.base_knockback = 6.35
	spec.base_stagger = 22.0
	spec.cooldown = 0.78
	spec.recovery = 0.34
	return spec

static func _generic_heavy() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySpec.new()
	spec.ability_id = GENERIC_HEAVY_ID
	spec.display_name = "HEAVY SMASH"
	spec.attack_type = WildDashCombatAbilitySpec.AttackType.HEAVY
	spec.impact_types = [
		WildDashCombatAbilitySpec.ImpactType.LAUNCH,
		WildDashCombatAbilitySpec.ImpactType.STAGGER,
	]
	spec.range = 4.35
	spec.arc_dot = -0.24
	spec.base_knockback = 9.45
	spec.base_stagger = 36.0
	spec.cooldown = 1.06
	spec.startup = 0.18
	spec.recovery = 0.52
	return spec

static func _generic_stomp() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySpec.new()
	spec.ability_id = GENERIC_AERIAL_ID
	spec.display_name = "STOMP"
	spec.attack_type = WildDashCombatAbilitySpec.AttackType.AERIAL
	spec.impact_types = [
		WildDashCombatAbilitySpec.ImpactType.STAGGER,
		WildDashCombatAbilitySpec.ImpactType.PUSH,
	]
	spec.range = 2.20
	spec.arc_dot = -1.0
	spec.base_knockback = 7.35
	spec.base_stagger = 29.0
	spec.cooldown = 0.92
	spec.recovery = 0.34
	spec.requires_airborne = true
	spec.momentum_scaling = 0.25
	return spec

static func _crocodile_bite() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySpec.new()
	spec.ability_id = CROCODILE_BITE_ID
	spec.display_name = "BITE LUNGE"
	spec.attack_type = WildDashCombatAbilitySpec.AttackType.BASIC
	spec.impact_types = [
		WildDashCombatAbilitySpec.ImpactType.PUSH,
		WildDashCombatAbilitySpec.ImpactType.STAGGER,
		WildDashCombatAbilitySpec.ImpactType.SPILL,
	]
	spec.range = 3.45
	spec.arc_dot = 0.28
	spec.base_knockback = 7.05
	spec.base_stagger = 30.0
	spec.cooldown = 1.65
	spec.recovery = 0.52
	spec.mobility_impulse = 1.35
	spec.fruit_spill = 2
	spec.water_range_multiplier = 1.145
	spec.water_mobility_multiplier = 1.22
	spec.water_effect_multiplier = 1.10
	return spec

static func _crocodile_tail() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySpec.new()
	spec.ability_id = CROCODILE_TAIL_ID
	spec.display_name = "TAIL SWEEP"
	spec.attack_type = WildDashCombatAbilitySpec.AttackType.HEAVY
	spec.impact_types = [
		WildDashCombatAbilitySpec.ImpactType.PUSH,
		WildDashCombatAbilitySpec.ImpactType.STAGGER,
		WildDashCombatAbilitySpec.ImpactType.SPILL,
	]
	spec.range = 4.20
	spec.arc_dot = -1.0
	spec.base_knockback = 3.90
	spec.base_stagger = 19.0
	spec.cooldown = 1.25
	spec.startup = 0.16
	spec.recovery = 0.90
	spec.fruit_spill = 1
	return spec

static func _crocodile_water_ambush() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySpec.new()
	spec.ability_id = CROCODILE_WATER_AMBUSH_ID
	spec.display_name = "WATER AMBUSH"
	spec.attack_type = WildDashCombatAbilitySpec.AttackType.SPECIAL
	spec.impact_types = [
		WildDashCombatAbilitySpec.ImpactType.LAUNCH,
		WildDashCombatAbilitySpec.ImpactType.STAGGER,
		WildDashCombatAbilitySpec.ImpactType.SPILL,
	]
	spec.range = 4.20
	spec.arc_dot = 0.18
	spec.base_knockback = 7.20
	spec.base_stagger = 34.0
	spec.cooldown = 6.0
	spec.startup = 0.14
	spec.recovery = 0.72
	spec.mobility_impulse = 4.0
	spec.fruit_spill = 2
	spec.water_range_multiplier = 1.15
	spec.water_mobility_multiplier = 1.20
	spec.water_effect_multiplier = 1.18
	spec.land_effect_multiplier = 0.55
	return spec
