class_name WildDashArenaCombatCore
extends Node

## Round 4-only combat authority for WILD RUMBLE Phase 2.
## Power/Defense stay sourced from WildDashAnimalAbilityProfile through
## WildDashRaceCombatProfile. This file does not alter the shared racing skills.

signal hit_resolved(source: WildDashCharacterController, target: WildDashCharacterController, result: Dictionary)
signal stagger_break(source: WildDashCharacterController, target: WildDashCharacterController, result: Dictionary)

const MAX_STAGGER := 100.0
const STUN_IMMUNITY_SECONDS := 1.0
const BREAK_VULNERABILITY_SECONDS := 1.20
const STAGGER_RECOVERY_DELAY := 0.90
const QUICK_BASE_KNOCKBACK := 5.80
const QUICK_BASE_STAGGER := 20.0
const HEAVY_BASE_KNOCKBACK := 8.60
const HEAVY_BASE_STAGGER := 33.0
const QUICK_RADIUS := 3.15
const HEAVY_RADIUS := 3.75
const QUICK_ARC_DOT := 0.04
const HEAVY_ARC_DOT := -0.16
const BREAK_FINISHER_KNOCKBACK := 1.40

var _racers: Dictionary = {}
var _stagger: Dictionary = {}
var _attack_cooldown: Dictionary = {}
var _stun_remaining: Dictionary = {}
var _stun_immunity: Dictionary = {}
var _break_vulnerability: Dictionary = {}
var _since_hit: Dictionary = {}
var _break_count: Dictionary = {}

func register_racer(racer: WildDashCharacterController) -> void:
	if racer == null:
		return
	var id := racer.get_instance_id()
	_racers[id] = racer
	_stagger[id] = 0.0
	_attack_cooldown[id] = 0.0
	_stun_remaining[id] = 0.0
	_stun_immunity[id] = 0.0
	_break_vulnerability[id] = 0.0
	_since_hit[id] = 999.0
	_break_count[id] = 0

func reset_racer(racer: WildDashCharacterController) -> void:
	if racer == null:
		return
	var id := racer.get_instance_id()
	if not _racers.has(id):
		register_racer(racer)
		return
	_stagger[id] = 0.0
	_attack_cooldown[id] = 0.0
	_stun_remaining[id] = 0.0
	_stun_immunity[id] = 0.0
	_break_vulnerability[id] = 0.0
	_since_hit[id] = 999.0

func _physics_process(delta: float) -> void:
	var stale: Array[int] = []
	for raw_id in _racers.keys():
		var id := int(raw_id)
		var racer: WildDashCharacterController = _racers.get(id, null) as WildDashCharacterController
		if racer == null or not is_instance_valid(racer):
			stale.append(id)
			continue
		_attack_cooldown[id] = maxf(0.0, float(_attack_cooldown.get(id, 0.0)) - delta)
		_stun_remaining[id] = maxf(0.0, float(_stun_remaining.get(id, 0.0)) - delta)
		_stun_immunity[id] = maxf(0.0, float(_stun_immunity.get(id, 0.0)) - delta)
		_break_vulnerability[id] = maxf(0.0, float(_break_vulnerability.get(id, 0.0)) - delta)
		_since_hit[id] = float(_since_hit.get(id, 999.0)) + delta
		if float(_since_hit[id]) >= STAGGER_RECOVERY_DELAY and float(_stagger.get(id, 0.0)) > 0.0:
			var stability := WildDashRaceCombatProfile.get_stability(racer.animal_id)
			var recovery_per_second := lerpf(9.0, 17.0, clampf(stability / 10.0, 0.0, 1.0))
			_stagger[id] = maxf(0.0, float(_stagger[id]) - recovery_per_second * delta)
	for id in stale:
		_racers.erase(id)
		_stagger.erase(id)
		_attack_cooldown.erase(id)
		_stun_remaining.erase(id)
		_stun_immunity.erase(id)
		_break_vulnerability.erase(id)
		_since_hit.erase(id)
		_break_count.erase(id)

func can_attack(racer: WildDashCharacterController) -> bool:
	if racer == null:
		return false
	var id := racer.get_instance_id()
	return float(_attack_cooldown.get(id, 0.0)) <= 0.0 and float(_stun_remaining.get(id, 0.0)) <= 0.0

func try_begin_attack(racer: WildDashCharacterController, kind: StringName) -> bool:
	if not can_attack(racer):
		return false
	var id := racer.get_instance_id()
	_attack_cooldown[id] = get_attack_cooldown(racer, kind)
	return true

func get_attack_cooldown(racer: WildDashCharacterController, kind: StringName) -> float:
	if racer == null:
		return 0.85
	var profile := WildDashRaceCombatProfile.get_profile(racer.animal_id)
	var trait_cooldown := float(profile.get("cooldown", 2.0))
	var normalized := clampf(inverse_lerp(1.45, 2.35, trait_cooldown), 0.0, 1.0)
	var quick := lerpf(0.66, 0.90, normalized)
	if WildDashRaceCombatProfile.get_attack_power(racer.animal_id) >= 9.0:
		quick += 0.04
	return quick * 1.45 if kind == &"hold" else quick

func get_attack_radius(kind: StringName) -> float:
	return HEAVY_RADIUS if kind == &"hold" else QUICK_RADIUS

func get_attack_arc_dot(kind: StringName) -> float:
	return HEAVY_ARC_DOT if kind == &"hold" else QUICK_ARC_DOT

func apply_hit(
	source: WildDashCharacterController,
	target: WildDashCharacterController,
	direction: Vector3,
	kind: StringName,
	directional: int = 0,
) -> Dictionary:
	var result: Dictionary = {
		"applied": false,
		"break": false,
		"knockback": 0.0,
		"stagger_gain": 0.0,
		"stagger": 0.0,
		"stun": 0.0,
		"finisher": false,
	}
	if source == null or target == null or source == target:
		return result
	if not is_instance_valid(source) or not is_instance_valid(target):
		return result
	var planar := Vector3(direction.x, 0.0, direction.z)
	if planar.length_squared() <= 0.001:
		return result

	var source_profile := WildDashRaceCombatProfile.get_profile(source.animal_id)
	var target_profile := WildDashRaceCombatProfile.get_profile(target.animal_id)
	var power := float(source_profile.get("attack_power", 5.0))
	var source_defense := float(source_profile.get("defense", 5.0))
	var target_defense := float(target_profile.get("defense", 5.0))
	var target_stability := float(target_profile.get("stability", 5.0))

	var base_knockback := HEAVY_BASE_KNOCKBACK if kind == &"hold" else QUICK_BASE_KNOCKBACK
	var base_stagger := HEAVY_BASE_STAGGER if kind == &"hold" else QUICK_BASE_STAGGER
	if directional != 0:
		base_knockback *= 0.96
		base_stagger *= 1.08

	var power_knockback_scale := lerpf(0.72, 1.45, clampf(power / 10.0, 0.0, 1.0))
	var defense_knockback_scale := lerpf(1.18, 0.58, clampf(target_defense / 10.0, 0.0, 1.0))
	var power_stagger_scale := lerpf(0.80, 1.32, clampf(power / 10.0, 0.0, 1.0))
	var defense_stagger_scale := lerpf(1.20, 0.62, clampf(target_defense / 10.0, 0.0, 1.0))
	var stability_stagger_scale := lerpf(1.08, 0.74, clampf(target_stability / 10.0, 0.0, 1.0))

	var knockback := base_knockback * power_knockback_scale * defense_knockback_scale
	var stagger_gain := base_stagger * power_stagger_scale * defense_stagger_scale * stability_stagger_scale

	# Heavy identity comes from the shared stats, not animal-name exceptions.
	if power >= 9.0 and source_defense >= 8.0:
		knockback *= 1.08
		stagger_gain *= 1.08
	if target_defense >= 8.5:
		knockback *= 0.92
		stagger_gain *= 0.92
	if power - target_defense >= 3.0:
		knockback *= 1.12
		stagger_gain *= 1.12

	var target_id := target.get_instance_id()
	if float(_break_vulnerability.get(target_id, 0.0)) > 0.0:
		knockback *= BREAK_FINISHER_KNOCKBACK
		_break_vulnerability[target_id] = 0.0
		result["finisher"] = true

	var launch_direction := planar.normalized()
	if directional != 0:
		var side := source.global_transform.basis.x.normalized() * float(directional)
		launch_direction = (launch_direction * 0.72 + side * 0.28).normalized()

	target.apply_knockback(launch_direction, knockback)
	var recoil_scale := lerpf(1.0, 0.42, clampf((power + source_defense) / 20.0, 0.0, 1.0))
	source.apply_knockback(-launch_direction, (1.10 if kind == &"hold" else 0.62) * recoil_scale)

	# Round 4 combat must read as an actual brawl, not invisible stat math.
	# These states are supported by both production animation rigs and the
	# procedural placeholders, so every resolved hit visibly shows attack/recoil.
	var source_visual := source.get_visual()
	if source_visual != null:
		source_visual.play_action(&"Skill", 0.42 if kind == &"hold" else 0.28)
	var target_visual := target.get_visual()
	if target_visual != null:
		target_visual.play_action(&"Hit", 0.48 if kind == &"hold" else 0.32)

	_since_hit[target_id] = 0.0
	var next_stagger := minf(MAX_STAGGER, float(_stagger.get(target_id, 0.0)) + stagger_gain)
	var broke := false
	var stun_seconds := 0.0
	if next_stagger >= MAX_STAGGER:
		if float(_stun_immunity.get(target_id, 0.0)) <= 0.0:
			broke = true
			_stagger[target_id] = 0.0
			_break_vulnerability[target_id] = BREAK_VULNERABILITY_SECONDS
			_stun_immunity[target_id] = STUN_IMMUNITY_SECONDS
			stun_seconds = lerpf(0.64, 0.40, clampf((target_defense + target_stability) / 20.0, 0.0, 1.0))
			_stun_remaining[target_id] = stun_seconds
			_break_count[target_id] = int(_break_count.get(target_id, 0)) + 1
		else:
			_stagger[target_id] = 95.0
	else:
		_stagger[target_id] = next_stagger

	result["applied"] = true
	result["break"] = broke
	result["knockback"] = knockback
	result["stagger_gain"] = stagger_gain
	result["stagger"] = float(_stagger.get(target_id, 0.0))
	result["stun"] = stun_seconds
	result["power"] = power
	result["target_defense"] = target_defense
	result["target_stability"] = target_stability
	result["kind"] = kind
	result["directional"] = directional
	hit_resolved.emit(source, target, result.duplicate(true))
	if broke:
		stagger_break.emit(source, target, result.duplicate(true))
		print("WILD RUMBLE BREAK source=%s target=%s power=%.1f defense=%.1f stagger_gain=%.1f stun=%.2f" % [
			source.get_display_name(), target.get_display_name(), power, target_defense, stagger_gain, stun_seconds,
		])
	return result

func get_stagger(racer: WildDashCharacterController) -> float:
	return 0.0 if racer == null else float(_stagger.get(racer.get_instance_id(), 0.0))

func get_stun_remaining(racer: WildDashCharacterController) -> float:
	return 0.0 if racer == null else float(_stun_remaining.get(racer.get_instance_id(), 0.0))

func get_attack_cooldown_remaining(racer: WildDashCharacterController) -> float:
	return 0.0 if racer == null else float(_attack_cooldown.get(racer.get_instance_id(), 0.0))

func get_break_vulnerability_remaining(racer: WildDashCharacterController) -> float:
	return 0.0 if racer == null else float(_break_vulnerability.get(racer.get_instance_id(), 0.0))

func get_break_count(racer: WildDashCharacterController) -> int:
	return 0 if racer == null else int(_break_count.get(racer.get_instance_id(), 0))

func get_profile(racer: WildDashCharacterController) -> Dictionary:
	if racer == null:
		return WildDashRaceCombatProfile.get_default_profile()
	return WildDashRaceCombatProfile.get_profile(racer.animal_id)
