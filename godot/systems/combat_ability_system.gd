class_name WildDashCombatAbilitySystem
extends RefCounted

## Typed facade over the staged Combat V2 profiles. Phase 3 specializes the
## Heavy/Hunter/Thief kits while Phase 2 keeps the agile/aerial and Crocodile
## Bite/Tail data. Mode code asks this facade rather than caring which phase owns
## a particular animal.

static func get_basic_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	if WildDashCombatV2Phase3Profile.has_profile(animal_id):
		var phase3: WildDashCombatAbilitySpec = WildDashCombatV2Phase3Profile.get_basic_attack(animal_id)
		if phase3 != null:
			return phase3
	return WildDashAnimalCombatProfile.get_basic_attack(animal_id)

static func get_heavy_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	if WildDashCombatV2Phase3Profile.has_profile(animal_id):
		var phase3: WildDashCombatAbilitySpec = WildDashCombatV2Phase3Profile.get_heavy_attack(animal_id)
		if phase3 != null:
			return phase3
	return WildDashAnimalCombatProfile.get_heavy_attack(animal_id)

static func get_aerial_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	if WildDashCombatV2Phase3Profile.has_profile(animal_id):
		var phase3: WildDashCombatAbilitySpec = WildDashCombatV2Phase3Profile.get_aerial_attack(animal_id)
		if phase3 != null:
			return phase3
	return WildDashAnimalCombatProfile.get_aerial_attack(animal_id)

static func get_mobility_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	return WildDashAnimalCombatProfile.get_mobility_attack(animal_id)

static func get_special_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	var phase3: WildDashCombatAbilitySpec = WildDashCombatV2Phase3Profile.get_special_attack(animal_id)
	if phase3 != null:
		return phase3
	return WildDashAnimalCombatProfile.get_special_attack(animal_id)

static func get_ability(animal_id: StringName, ability_id: StringName) -> WildDashCombatAbilitySpec:
	var phase3: WildDashCombatAbilitySpec = WildDashCombatV2Phase3Profile.get_ability(animal_id, ability_id)
	if phase3 != null:
		return phase3
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

static func get_momentum_effect_multiplier(spec: WildDashCombatAbilitySpec, normalized_momentum: float) -> float:
	if spec == null or spec.momentum_scaling <= 0.001:
		return 1.0
	var ratio: float = clampf(normalized_momentum, 0.0, 1.0)
	var low: float = maxf(0.72, 1.0 - spec.momentum_scaling * 0.25)
	var high: float = 1.0 + spec.momentum_scaling * 0.35
	return lerpf(low, high, ratio)

static func get_monkey_swing_impact_scale(normalized_swing_speed: float) -> float:
	return lerpf(0.75, 1.35, clampf(normalized_swing_speed, 0.0, 1.0))

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
	## runtime, while the shared resolver can inspect equivalent impacts.
	if not WildDashAnimalSpecialAbilitySystem.can_use_special(animal_id, &"fruit_collection"):
		return {}
	var legacy: Dictionary = WildDashAnimalSpecialAbilitySystem.get_special(animal_id)
	var impacts: Array[int] = [WildDashCombatAbilitySpec.ImpactType.CONTROL]
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
