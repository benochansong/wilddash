class_name WildDashCombatV2FinalOverrides
extends RefCounted

## Tiny final-balance overrides kept separate from the phase-2 agile profile so
## the staged migration history stays readable. These are data-only adjustments.

static func get_basic_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	if animal_id != &"fox":
		return null
	var spec: WildDashCombatAbilitySpec = WildDashAnimalCombatProfile.get_basic_attack(animal_id)
	if spec == null:
		return null
	spec.fruit_spill = 1
	if not spec.has_impact(WildDashCombatAbilitySpec.ImpactType.SPILL):
		spec.impact_types.append(WildDashCombatAbilitySpec.ImpactType.SPILL)
	return spec
