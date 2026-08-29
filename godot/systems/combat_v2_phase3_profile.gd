class_name WildDashCombatV2Phase3Profile
extends RefCounted

## Final Combat V2 specialization layer for characters that stayed generic in
## phases 1-2. Agile kits (Monkey/Rabbit/Deer/Cat/Fox) and Crocodile Bite/Tail
## remain owned by WildDashAnimalCombatProfile; this layer fills Heavy/Hunter /
## Thief identities and Crocodile's staged Water Ambush without duplicating the
## existing agile data.

const PHASE3_IDS: Array[StringName] = [
	&"dog", &"wolf", &"boar", &"elephant", &"bear", &"raccoon",
]

const DOG_SHOULDER: StringName = &"dog_shoulder_push"
const DOG_TACKLE: StringName = &"dog_running_tackle"
const WOLF_LUNGE: StringName = &"wolf_lunge_bite"
const WOLF_POUNCE: StringName = &"wolf_pounce"
const BOAR_HEADBUTT: StringName = &"boar_headbutt"
const BOAR_CHARGE: StringName = &"boar_charge"
const ELEPHANT_TRUNK_PUSH: StringName = &"elephant_trunk_push"
const ELEPHANT_TRUNK_SLAM: StringName = &"elephant_trunk_slam"
const ELEPHANT_GROUND_STOMP: StringName = &"elephant_ground_stomp"
const BEAR_PAW: StringName = &"bear_paw_swipe"
const BEAR_BODY_SLAM: StringName = &"bear_body_slam"
const BEAR_BELLY_DROP: StringName = &"bear_belly_drop"
const RACCOON_SHOVE: StringName = &"raccoon_quick_shove"
const RACCOON_SPIN: StringName = &"raccoon_spin_swipe"

static func has_profile(animal_id: StringName) -> bool:
	return PHASE3_IDS.has(animal_id)

static func get_basic_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	match animal_id:
		&"dog": return _spec(DOG_SHOULDER, "SHOULDER PUSH", WildDashCombatAbilitySpec.AttackType.BASIC, 3.55, -0.08, 5.8, 20.0, 0.70, 0.30, 0.55, 0, 0.0, [WildDashCombatAbilitySpec.ImpactType.PUSH, WildDashCombatAbilitySpec.ImpactType.STAGGER])
		&"wolf": return _spec(WOLF_LUNGE, "LUNGE BITE", WildDashCombatAbilitySpec.AttackType.BASIC, 3.65, 0.05, 6.2, 22.0, 0.68, 0.30, 1.25, 0, 0.15, [WildDashCombatAbilitySpec.ImpactType.PUSH, WildDashCombatAbilitySpec.ImpactType.STAGGER])
		&"boar": return _spec(BOAR_HEADBUTT, "HEADBUTT", WildDashCombatAbilitySpec.AttackType.BASIC, 3.50, 0.00, 7.0, 23.0, 0.76, 0.34, 0.65, 0, 0.10, [WildDashCombatAbilitySpec.ImpactType.PUSH, WildDashCombatAbilitySpec.ImpactType.STAGGER])
		&"elephant": return _spec(ELEPHANT_TRUNK_PUSH, "TRUNK PUSH", WildDashCombatAbilitySpec.AttackType.BASIC, 4.15, -0.18, 7.5, 24.0, 0.82, 0.40, 0.35, 1, 0.0, [WildDashCombatAbilitySpec.ImpactType.PUSH, WildDashCombatAbilitySpec.ImpactType.STAGGER, WildDashCombatAbilitySpec.ImpactType.SPILL])
		&"bear": return _spec(BEAR_PAW, "PAW SWIPE", WildDashCombatAbilitySpec.AttackType.BASIC, 3.65, -0.20, 7.1, 23.0, 0.78, 0.38, 0.30, 0, 0.0, [WildDashCombatAbilitySpec.ImpactType.PUSH, WildDashCombatAbilitySpec.ImpactType.STAGGER])
		&"raccoon": return _spec(RACCOON_SHOVE, "QUICK SHOVE", WildDashCombatAbilitySpec.AttackType.BASIC, 3.10, -0.10, 4.0, 16.0, 0.58, 0.26, 0.65, 0, 0.10, [WildDashCombatAbilitySpec.ImpactType.PUSH, WildDashCombatAbilitySpec.ImpactType.CONTROL])
		_: return null

static func get_heavy_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	match animal_id:
		&"dog": return _spec(DOG_TACKLE, "RUNNING TACKLE", WildDashCombatAbilitySpec.AttackType.HEAVY, 4.05, 0.02, 7.5, 29.0, 0.96, 0.42, 2.0, 1, 0.28, [WildDashCombatAbilitySpec.ImpactType.PUSH, WildDashCombatAbilitySpec.ImpactType.STAGGER, WildDashCombatAbilitySpec.ImpactType.SPILL])
		&"wolf": return _spec(WOLF_POUNCE, "POUNCE", WildDashCombatAbilitySpec.AttackType.HEAVY, 4.25, 0.10, 7.8, 31.0, 0.94, 0.40, 2.35, 1, 0.32, [WildDashCombatAbilitySpec.ImpactType.LAUNCH, WildDashCombatAbilitySpec.ImpactType.STAGGER, WildDashCombatAbilitySpec.ImpactType.SPILL])
		&"boar": return _spec(BOAR_CHARGE, "BOAR CHARGE", WildDashCombatAbilitySpec.AttackType.HEAVY, 4.75, 0.18, 9.2, 34.0, 1.18, 0.78, 4.0, 2, 0.52, [WildDashCombatAbilitySpec.ImpactType.LAUNCH, WildDashCombatAbilitySpec.ImpactType.STAGGER, WildDashCombatAbilitySpec.ImpactType.SPILL])
		&"elephant": return _spec(ELEPHANT_TRUNK_SLAM, "TRUNK SLAM", WildDashCombatAbilitySpec.AttackType.HEAVY, 4.35, -0.30, 8.4, 39.0, 1.08, 0.58, 0.30, 1, 0.0, [WildDashCombatAbilitySpec.ImpactType.PUSH, WildDashCombatAbilitySpec.ImpactType.STAGGER, WildDashCombatAbilitySpec.ImpactType.SPILL])
		&"bear": return _spec(BEAR_BODY_SLAM, "BODY SLAM", WildDashCombatAbilitySpec.AttackType.HEAVY, 4.10, -0.55, 8.3, 35.0, 1.04, 0.56, 1.0, 1, 0.12, [WildDashCombatAbilitySpec.ImpactType.PUSH, WildDashCombatAbilitySpec.ImpactType.STAGGER, WildDashCombatAbilitySpec.ImpactType.SPILL])
		&"raccoon": return _spec(RACCOON_SPIN, "SPIN SWIPE", WildDashCombatAbilitySpec.AttackType.HEAVY, 3.65, -0.65, 5.2, 21.0, 0.82, 0.36, 1.0, 0, 0.15, [WildDashCombatAbilitySpec.ImpactType.PUSH, WildDashCombatAbilitySpec.ImpactType.CONTROL])
		_: return null

static func get_aerial_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	if animal_id == &"bear":
		var spec: WildDashCombatAbilitySpec = _spec(BEAR_BELLY_DROP, "BELLY DROP", WildDashCombatAbilitySpec.AttackType.AERIAL, 2.75, -1.0, 7.2, 34.0, 1.02, 0.48, 0.0, 1, 0.35, [WildDashCombatAbilitySpec.ImpactType.PUSH, WildDashCombatAbilitySpec.ImpactType.STAGGER, WildDashCombatAbilitySpec.ImpactType.SPILL])
		spec.requires_airborne = true
		return spec
	return null

static func get_special_attack(animal_id: StringName) -> WildDashCombatAbilitySpec:
	if animal_id == &"elephant":
		return _spec(ELEPHANT_GROUND_STOMP, "GROUND STOMP", WildDashCombatAbilitySpec.AttackType.SPECIAL, 4.45, -1.0, 4.2, 28.0, 6.4, 0.62, 0.0, 1, 0.0, [WildDashCombatAbilitySpec.ImpactType.PUSH, WildDashCombatAbilitySpec.ImpactType.STAGGER, WildDashCombatAbilitySpec.ImpactType.SPILL])
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

static func get_identity(animal_id: StringName) -> String:
	match animal_id:
		&"dog": return "BALANCED FIGHTER"
		&"wolf": return "HUNTER"
		&"boar": return "CHARGE BRUISER"
		&"rabbit": return "AERIAL FIGHTER"
		&"deer": return "LEAP DUELIST"
		&"monkey": return "CANOPY TRICKSTER"
		&"elephant": return "PUSH KING"
		&"bear": return "CLOSE RANGE BRAWLER"
		&"crocodile": return "WATER BRUISER"
		&"cat": return "AMBUSH SPECIALIST"
		&"fox": return "HIT & RUN"
		&"raccoon": return "THIEF / CONTROL"
		_: return "BALANCED FIGHTER"

static func _spec(
	ability_id: StringName,
	display_name: String,
	attack_type: int,
	attack_range: float,
	arc_dot: float,
	knockback: float,
	stagger: float,
	cooldown: float,
	recovery: float,
	mobility_impulse: float,
	fruit_spill: int,
	momentum_scaling: float,
	impact_types: Array[int]
) -> WildDashCombatAbilitySpec:
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySpec.new()
	spec.ability_id = ability_id
	spec.display_name = display_name
	spec.attack_type = attack_type
	spec.impact_types = impact_types.duplicate()
	spec.range = attack_range
	spec.arc_dot = arc_dot
	spec.base_knockback = knockback
	spec.base_stagger = stagger
	spec.cooldown = cooldown
	spec.recovery = recovery
	spec.mobility_impulse = mobility_impulse
	spec.fruit_spill = fruit_spill
	spec.momentum_scaling = momentum_scaling
	return spec
