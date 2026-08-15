class_name WildDashCombatAbilitySystem
extends RefCounted

## Thin typed facade over AnimalCombatProfile. Later character passes can add
## bespoke data here without changing Round 2 / Round 4 input code.

static func get_basic_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	return WildDashAnimalCombatProfile.get_basic_attack(animal_id)

static func get_heavy_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	return WildDashAnimalCombatProfile.get_heavy_attack(animal_id)

static func get_aerial_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	return WildDashAnimalCombatProfile.get_aerial_attack(animal_id)

static func get_special_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	return WildDashAnimalCombatProfile.get_special_attack(animal_id)

static func get_ability(animal_id: StringName, ability_id: StringName) -> WildDashCombatAbilitySpec:
	return WildDashAnimalCombatProfile.get_ability(animal_id, ability_id)

static func get_effective_range(spec: WildDashCombatAbilitySpec, in_water: bool) -> float:
	if spec == null:
		return 0.0
	return spec.range * (spec.water_range_multiplier if in_water else 1.0)

static func get_effective_mobility_impulse(spec: WildDashCombatAbilitySpec, in_water: bool) -> float:
	if spec == null:
		return 0.0
	return spec.mobility_impulse * (spec.water_mobility_multiplier if in_water else 1.0)

static func get_environment_effect_multiplier(spec: WildDashCombatAbilitySpec, in_water: bool) -> float:
	if spec == null:
		return 1.0
	return spec.water_effect_multiplier if in_water else spec.land_effect_multiplier

static func get_tail_direction_multiplier(source: WildDashCharacterController, target: WildDashCharacterController) -> float:
	if source == null or target == null:
		return 1.0
	var forward: Vector3 = -source.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var offset: Vector3 = target.global_position - source.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return 1.0
	var dot: float = forward.dot(offset.normalized())
	if dot <= -0.35:
		return 1.25
	if dot < 0.45:
		return 1.15
	return 1.0

static func get_legacy_special_bridge(animal_id: StringName) -> Dictionary:
	## Compatibility bridge only. Fart behavior stays in the proven special
	## runtime for Phase 1, but future resolvers can inspect equivalent impacts.
	if not WildDashAnimalSpecialAbilitySystem.can_use_special(animal_id, &"fruit_collection"):
		return {}
	var legacy: Dictionary = WildDashAnimalSpecialAbilitySystem.get_special(animal_id)
	var impacts: Array[int] = [
		WildDashCombatAbilitySpec.ImpactType.CONTROL,
	]
	if float(legacy.get("knockback", 0.0)) > 0.0:
		impacts.append(WildDashCombatAbilitySpec.ImpactType.PUSH)
	if float(legacy.get("stagger", 0.0)) > 0.0:
		impacts.append(WildDashCombatAbilitySpec.ImpactType.STAGGER)
	impacts.append(WildDashCombatAbilitySpec.ImpactType.SPILL)
	return {
		"ability_id": StringName(legacy.get("id", &"")),
		"impact_types": impacts,
		"cooldown": float(legacy.get("cooldown", 0.0)),
	}
