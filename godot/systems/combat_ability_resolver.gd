class_name WildDashCombatAbilityResolver
extends RefCounted

## Shared Combat V2 resolver. It never mutates racer state directly; mode
## adapters remain responsible for actual knockback, fruit inventory, Stagger
## authority and hit credit. This keeps the migration regression-safe.

static func resolve_attack(
	source: WildDashCharacterController,
	target: WildDashCharacterController,
	ability_id: StringName,
	mode_id: StringName,
	context: Dictionary = {}
) -> WildDashCombatResolution:
	var empty: WildDashCombatResolution = WildDashCombatResolution.new()
	if source == null:
		return empty
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_ability(source.animal_id, ability_id)
	if spec == null:
		return empty
	return resolve_spec(source, target, spec, mode_id, context)

static func resolve_spec(
	source: WildDashCharacterController,
	target: WildDashCharacterController,
	spec: WildDashCombatAbilitySpec,
	mode_id: StringName,
	context: Dictionary = {}
) -> WildDashCombatResolution:
	var empty: WildDashCombatResolution = WildDashCombatResolution.new()
	if source == null or spec == null:
		return empty
	if spec.requires_airborne and not bool(context.get("airborne", false)):
		return empty
	if spec.requires_water and not bool(context.get("in_water", false)):
		return empty
	match mode_id:
		&"fruit_collection":
			return WildDashRound2CombatModifier.resolve(spec, source, target, context)
		&"push_out":
			return WildDashRound4CombatModifier.resolve(spec, source, target, context)
		_:
			return empty
