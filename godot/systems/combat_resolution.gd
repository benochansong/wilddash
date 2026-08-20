class_name WildDashCombatResolution
extends RefCounted

## Typed output from Combat V2. Mode adapters decide how to apply the resolved
## values so legacy Round 2 fruit authority and Round 4 ArenaCombatCore remain
## intact during the staged migration.

var applied: bool = false
var ability_id: StringName = &""
var display_name: String = ""
var knockback: float = 0.0
var stagger: float = 0.0
var fruit_spill: int = 0
var fruit_steal: int = 0
var control_scale: float = 1.0
var control_duration: float = 0.0
var mobility_impulse: float = 0.0
var cooldown: float = 0.0
var recovery: float = 0.0
var directional_multiplier: float = 1.0
var water_bonus: bool = false

func reset_from_spec(spec: WildDashCombatAbilitySpec) -> void:
	if spec == null:
		return
	ability_id = spec.ability_id
	display_name = spec.display_name
	knockback = spec.base_knockback
	stagger = spec.base_stagger
	fruit_spill = spec.fruit_spill
	fruit_steal = spec.fruit_steal
	mobility_impulse = spec.mobility_impulse
	cooldown = spec.cooldown
	recovery = spec.recovery
	directional_multiplier = 1.0
