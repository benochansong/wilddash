class_name WildDashRound4CombatModifier
extends RefCounted

## Round 4 preserves ArenaCombatCore as the combat authority. This modifier
## exposes shared ability intent (range/recovery/directional pressure/momentum)
## so bespoke animal kits can migrate without bypassing Stagger, Break or
## survival assists.

static func resolve(
	spec: WildDashCombatAbilitySpec,
	_source: WildDashCharacterController,
	_target: WildDashCharacterController,
	context: Dictionary
) -> WildDashCombatResolution:
	var result: WildDashCombatResolution = WildDashCombatResolution.new()
	if spec == null:
		return result
	result.reset_from_spec(spec)
	result.applied = true
	var in_water: bool = bool(context.get("in_water", false))
	var direction_multiplier: float = float(context.get("directional_multiplier", 1.0))
	var momentum_multiplier: float = clampf(float(context.get("momentum_multiplier", 1.0)), 0.70, 1.40)
	var environment_scale: float = WildDashCombatAbilitySystem.get_environment_effect_multiplier(spec, in_water)
	result.directional_multiplier = maxf(0.1, direction_multiplier)
	result.water_bonus = in_water and spec.water_effect_multiplier > 1.001
	result.knockback = spec.base_knockback * environment_scale * result.directional_multiplier * momentum_multiplier
	result.stagger = spec.base_stagger * environment_scale * result.directional_multiplier * momentum_multiplier
	result.mobility_impulse = WildDashCombatAbilitySystem.get_effective_mobility_impulse(spec, in_water)
	# Fruit values are intentionally zeroed in the ring-out mode.
	result.fruit_spill = 0
	result.fruit_steal = 0
	return result
