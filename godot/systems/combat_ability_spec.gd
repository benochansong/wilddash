class_name WildDashCombatAbilitySpec
extends RefCounted

## Typed Combat V2 ability schema. Keeping combat data out of loose Dictionaries
## avoids Godot 4.7 Variant inference failures and gives Round 2 / Round 4 a
## shared contract without forcing either mode to abandon its existing authority.

enum AttackType {
	BASIC,
	HEAVY,
	AERIAL,
	MOBILITY,
	SPECIAL,
}

enum ImpactType {
	PUSH,
	LAUNCH,
	STAGGER,
	CONTROL,
	SPILL,
	STEAL,
}

var ability_id: StringName = &""
var display_name: String = ""
var attack_type: int = AttackType.BASIC
var impact_types: Array[int] = []
var range: float = 0.0
var arc_dot: float = 0.0
var base_knockback: float = 0.0
var base_stagger: float = 0.0
var cooldown: float = 0.0
var startup: float = 0.0
var recovery: float = 0.0
var mobility_impulse: float = 0.0
var fruit_spill: int = 0
var fruit_steal: int = 0
var requires_airborne: bool = false
var requires_water: bool = false
var momentum_scaling: float = 0.0
var water_range_multiplier: float = 1.0
var water_mobility_multiplier: float = 1.0
var water_effect_multiplier: float = 1.0
var land_effect_multiplier: float = 1.0

func has_impact(impact_type: int) -> bool:
	return impact_types.has(impact_type)

func clone() -> WildDashCombatAbilitySpec:
	var copy: WildDashCombatAbilitySpec = WildDashCombatAbilitySpec.new()
	copy.ability_id = ability_id
	copy.display_name = display_name
	copy.attack_type = attack_type
	copy.impact_types = impact_types.duplicate()
	copy.range = range
	copy.arc_dot = arc_dot
	copy.base_knockback = base_knockback
	copy.base_stagger = base_stagger
	copy.cooldown = cooldown
	copy.startup = startup
	copy.recovery = recovery
	copy.mobility_impulse = mobility_impulse
	copy.fruit_spill = fruit_spill
	copy.fruit_steal = fruit_steal
	copy.requires_airborne = requires_airborne
	copy.requires_water = requires_water
	copy.momentum_scaling = momentum_scaling
	copy.water_range_multiplier = water_range_multiplier
	copy.water_mobility_multiplier = water_mobility_multiplier
	copy.water_effect_multiplier = water_effect_multiplier
	copy.land_effect_multiplier = land_effect_multiplier
	return copy
