class_name WildDashRound2CombatModifier
extends RefCounted

## Round 2 converts combat into fruit-economy pressure. Knockback stays below
## Round 4 while Spill / Steal values remain meaningful. This class resolves
## numbers only; Fruit Frenzy remains authoritative for inventory changes.

const ROUND2_KNOCKBACK_SCALE: float = 0.88
const ROUND2_HEAVY_KNOCKBACK_SCALE: float = 0.87

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
	var mode_scale: float = ROUND2_HEAVY_KNOCKBACK_SCALE if spec.attack_type == WildDashCombatAbilitySpec.AttackType.HEAVY else ROUND2_KNOCKBACK_SCALE
	var environment_scale: float = WildDashCombatAbilitySystem.get_environment_effect_multiplier(spec, in_water)
	result.directional_multiplier = maxf(0.1, direction_multiplier)
	result.water_bonus = in_water and spec.water_effect_multiplier > 1.001
	result.knockback = spec.base_knockback * mode_scale * environment_scale * result.directional_multiplier
	# Round 2 does not run Arena Stagger as its victory condition. Preserve this
	# value for feedback/future stun tuning, but adapters should not feed it into
	# the Round 4 Stagger authority.
	result.stagger = spec.base_stagger * 0.35 * environment_scale
	result.mobility_impulse = WildDashCombatAbilitySystem.get_effective_mobility_impulse(spec, in_water)
	result.fruit_spill = maxi(0, spec.fruit_spill)
	result.fruit_steal = maxi(0, spec.fruit_steal)
	return result
