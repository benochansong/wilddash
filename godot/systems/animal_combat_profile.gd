class_name WildDashAnimalCombatProfile
extends RefCounted

## Combat V2 profile authority. Phase 2 adds the agile/aerial identities while
## Heavy characters remain on conservative generic adapters until the next pass.

const GENERIC_BASIC_ID: StringName = &"quick_bash"
const GENERIC_HEAVY_ID: StringName = &"heavy_smash"
const GENERIC_AERIAL_ID: StringName = &"stomp"

const CROCODILE_BITE_ID: StringName = &"crocodile_bite_lunge"
const CROCODILE_TAIL_ID: StringName = &"crocodile_tail_sweep"
const CROCODILE_WATER_AMBUSH_ID: StringName = &"crocodile_water_ambush"

const MONKEY_PALM_ID: StringName = &"monkey_palm_push"
const MONKEY_SPIN_ID: StringName = &"monkey_spin_kick"
const MONKEY_STOMP_ID: StringName = &"monkey_canopy_stomp"
const MONKEY_SWING_ID: StringName = &"monkey_swing_kick"

const RABBIT_KICK_ID: StringName = &"rabbit_fast_kick"
const RABBIT_DOUBLE_ID: StringName = &"rabbit_double_kick"
const RABBIT_STOMP_ID: StringName = &"rabbit_high_stomp"

const DEER_PUSH_ID: StringName = &"deer_antler_push"
const DEER_RUSH_ID: StringName = &"deer_antler_rush"
const DEER_DROP_ID: StringName = &"deer_hoof_drop"

const CAT_CLAW_ID: StringName = &"cat_quick_claw"
const CAT_POUNCE_ID: StringName = &"cat_pounce"
const CAT_STOMP_ID: StringName = &"cat_aerial_claw"

const FOX_DASH_ID: StringName = &"fox_dash_hit"
const FOX_FEINT_ID: StringName = &"fox_feint_strike"
const FOX_STOMP_ID: StringName = &"fox_drop_kick"

static func get_basic_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	match animal_id:
		&"crocodile": return _crocodile_bite()
		&"monkey": return _monkey_palm()
		&"rabbit": return _rabbit_fast_kick()
		&"deer": return _deer_antler_push()
		&"cat": return _cat_quick_claw()
		&"fox": return _fox_dash_hit()
		_: return _generic_basic()

static func get_heavy_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	match animal_id:
		&"crocodile": return _crocodile_tail()
		&"monkey": return _monkey_spin_kick()
		&"rabbit": return _rabbit_double_kick()
		&"deer": return _deer_antler_rush()
		&"cat": return _cat_pounce()
		&"fox": return _fox_feint_strike()
		_: return _generic_heavy()

static func get_aerial_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	match animal_id:
		&"monkey": return _monkey_stomp()
		&"rabbit": return _rabbit_stomp()
		&"deer": return _deer_hoof_drop()
		&"cat": return _cat_aerial_claw()
		&"fox": return _fox_drop_kick()
		_: return _generic_stomp()

static func get_mobility_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	if animal_id == &"monkey":
		return _monkey_swing_kick()
	return null

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
	var mobility: WildDashCombatAbilitySpec = get_mobility_attack(animal_id)
	if mobility != null and mobility.ability_id == ability_id:
		return mobility
	var special: WildDashCombatAbilitySpec = get_special_attack(animal_id)
	if special != null and special.ability_id == ability_id:
		return special
	return null

static func _generic_basic() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySpec.new()
	spec.ability_id = GENERIC_BASIC_ID
	spec.display_name = "QUICK BASH"
	spec.attack_type = WildDashCombatAbilitySpec.AttackType.BASIC
	spec.impact_types = [WildDashCombatAbilitySpec.ImpactType.PUSH, WildDashCombatAbilitySpec.ImpactType.STAGGER]
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
	spec.impact_types = [WildDashCombatAbilitySpec.ImpactType.LAUNCH, WildDashCombatAbilitySpec.ImpactType.STAGGER]
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
	spec.impact_types = [WildDashCombatAbilitySpec.ImpactType.STAGGER, WildDashCombatAbilitySpec.ImpactType.PUSH]
	spec.range = 2.20
	spec.arc_dot = -1.0
	spec.base_knockback = 7.35
	spec.base_stagger = 29.0
	spec.cooldown = 0.92
	spec.recovery = 0.34
	spec.requires_airborne = true
	spec.momentum_scaling = 0.25
	return spec

static func _monkey_palm() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = _generic_basic()
	spec.ability_id = MONKEY_PALM_ID
	spec.display_name = "PALM PUSH"
	spec.range = 3.25
	spec.base_knockback = 4.6
	spec.base_stagger = 18.0
	spec.cooldown = 0.64
	return spec

static func _monkey_spin_kick() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = _generic_heavy()
	spec.ability_id = MONKEY_SPIN_ID
	spec.display_name = "SPIN KICK"
	spec.range = 3.75
	spec.arc_dot = -0.70
	spec.base_knockback = 6.5
	spec.base_stagger = 27.0
	spec.cooldown = 0.92
	spec.recovery = 0.42
	spec.fruit_spill = 1
	spec.impact_types.append(WildDashCombatAbilitySpec.ImpactType.SPILL)
	return spec

static func _monkey_stomp() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = _generic_stomp()
	spec.ability_id = MONKEY_STOMP_ID
	spec.display_name = "CANOPY STOMP"
	spec.base_knockback = 5.8
	spec.base_stagger = 31.0
	spec.fruit_spill = 1
	spec.impact_types.append(WildDashCombatAbilitySpec.ImpactType.SPILL)
	return spec

static func _monkey_swing_kick() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySpec.new()
	spec.ability_id = MONKEY_SWING_ID
	spec.display_name = "SWING KICK"
	spec.attack_type = WildDashCombatAbilitySpec.AttackType.MOBILITY
	spec.impact_types = [WildDashCombatAbilitySpec.ImpactType.PUSH, WildDashCombatAbilitySpec.ImpactType.STAGGER, WildDashCombatAbilitySpec.ImpactType.SPILL]
	spec.range = 3.15
	spec.arc_dot = -0.20
	spec.base_knockback = 5.4
	spec.base_stagger = 26.0
	spec.cooldown = 0.68
	spec.recovery = 0.18
	spec.fruit_spill = 1
	spec.momentum_scaling = 1.0
	return spec

static func _rabbit_fast_kick() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = _generic_basic()
	spec.ability_id = RABBIT_KICK_ID
	spec.display_name = "FAST KICK"
	spec.range = 3.0
	spec.base_knockback = 4.5
	spec.base_stagger = 17.0
	spec.cooldown = 0.58
	return spec

static func _rabbit_double_kick() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = _generic_heavy()
	spec.ability_id = RABBIT_DOUBLE_ID
	spec.display_name = "DOUBLE KICK"
	spec.range = 3.45
	spec.base_knockback = 6.3
	spec.base_stagger = 26.0
	spec.cooldown = 0.82
	spec.recovery = 0.36
	spec.fruit_spill = 1
	spec.impact_types.append(WildDashCombatAbilitySpec.ImpactType.SPILL)
	return spec

static func _rabbit_stomp() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = _generic_stomp()
	spec.ability_id = RABBIT_STOMP_ID
	spec.display_name = "HIGH STOMP"
	spec.base_knockback = 5.4
	spec.base_stagger = 35.0
	spec.cooldown = 0.72
	spec.fruit_spill = 1
	spec.impact_types.append(WildDashCombatAbilitySpec.ImpactType.SPILL)
	return spec

static func _deer_antler_push() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = _generic_basic()
	spec.ability_id = DEER_PUSH_ID
	spec.display_name = "ANTLER PUSH"
	spec.range = 3.6
	spec.base_knockback = 5.3
	spec.base_stagger = 20.0
	spec.cooldown = 0.68
	return spec

static func _deer_antler_rush() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = _generic_heavy()
	spec.ability_id = DEER_RUSH_ID
	spec.display_name = "ANTLER RUSH"
	spec.range = 4.15
	spec.arc_dot = 0.02
	spec.base_knockback = 7.1
	spec.base_stagger = 28.0
	spec.cooldown = 0.98
	spec.recovery = 0.44
	spec.mobility_impulse = 2.4
	spec.fruit_spill = 1
	spec.momentum_scaling = 0.35
	spec.impact_types.append(WildDashCombatAbilitySpec.ImpactType.SPILL)
	return spec

static func _deer_hoof_drop() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = _generic_stomp()
	spec.ability_id = DEER_DROP_ID
	spec.display_name = "HOOF DROP"
	spec.base_knockback = 6.3
	spec.base_stagger = 30.0
	spec.fruit_spill = 1
	spec.momentum_scaling = 0.42
	spec.impact_types.append(WildDashCombatAbilitySpec.ImpactType.SPILL)
	return spec

static func _cat_quick_claw() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = _generic_basic()
	spec.ability_id = CAT_CLAW_ID
	spec.display_name = "QUICK CLAW"
	spec.range = 2.95
	spec.base_knockback = 3.9
	spec.base_stagger = 16.0
	spec.cooldown = 0.52
	return spec

static func _cat_pounce() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = _generic_heavy()
	spec.ability_id = CAT_POUNCE_ID
	spec.display_name = "POUNCE"
	spec.range = 3.75
	spec.arc_dot = 0.02
	spec.base_knockback = 5.4
	spec.base_stagger = 24.0
	spec.cooldown = 0.78
	spec.recovery = 0.30
	spec.mobility_impulse = 2.6
	spec.fruit_spill = 1
	spec.impact_types.append(WildDashCombatAbilitySpec.ImpactType.SPILL)
	return spec

static func _cat_aerial_claw() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = _generic_stomp()
	spec.ability_id = CAT_STOMP_ID
	spec.display_name = "AERIAL CLAW"
	spec.base_knockback = 4.8
	spec.base_stagger = 28.0
	spec.fruit_spill = 1
	spec.impact_types.append(WildDashCombatAbilitySpec.ImpactType.SPILL)
	return spec

static func _fox_dash_hit() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = _generic_basic()
	spec.ability_id = FOX_DASH_ID
	spec.display_name = "DASH HIT"
	spec.range = 3.45
	spec.base_knockback = 4.8
	spec.base_stagger = 18.0
	spec.cooldown = 0.56
	spec.mobility_impulse = 1.2
	return spec

static func _fox_feint_strike() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = _generic_heavy()
	spec.ability_id = FOX_FEINT_ID
	spec.display_name = "FEINT STRIKE"
	spec.range = 3.8
	spec.base_knockback = 5.8
	spec.base_stagger = 24.0
	spec.cooldown = 0.78
	spec.recovery = 0.28
	spec.mobility_impulse = 1.8
	spec.fruit_spill = 1
	spec.impact_types.append(WildDashCombatAbilitySpec.ImpactType.SPILL)
	return spec

static func _fox_drop_kick() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = _generic_stomp()
	spec.ability_id = FOX_STOMP_ID
	spec.display_name = "DROP KICK"
	spec.base_knockback = 5.2
	spec.base_stagger = 27.0
	return spec

static func _crocodile_bite() -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySpec.new()
	spec.ability_id = CROCODILE_BITE_ID
	spec.display_name = "BITE LUNGE"
	spec.attack_type = WildDashCombatAbilitySpec.AttackType.BASIC
	spec.impact_types = [WildDashCombatAbilitySpec.ImpactType.PUSH, WildDashCombatAbilitySpec.ImpactType.STAGGER, WildDashCombatAbilitySpec.ImpactType.SPILL]
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
	spec.impact_types = [WildDashCombatAbilitySpec.ImpactType.PUSH, WildDashCombatAbilitySpec.ImpactType.STAGGER, WildDashCombatAbilitySpec.ImpactType.SPILL]
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
	spec.impact_types = [WildDashCombatAbilitySpec.ImpactType.LAUNCH, WildDashCombatAbilitySpec.ImpactType.STAGGER, WildDashCombatAbilitySpec.ImpactType.SPILL]
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
