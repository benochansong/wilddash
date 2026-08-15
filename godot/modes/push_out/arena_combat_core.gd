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

# Round 4 attack readability/connection pass. F/Y should feel like an actual
# combat button rather than a tiny collision probe.
const QUICK_BASE_KNOCKBACK := 6.35
const QUICK_BASE_STAGGER := 22.0
const HEAVY_BASE_KNOCKBACK := 9.45
const HEAVY_BASE_STAGGER := 36.0
const STOMP_BASE_KNOCKBACK := 7.35
const STOMP_BASE_STAGGER := 29.0
const QUICK_RADIUS := 3.65
const HEAVY_RADIUS := 4.35
const STOMP_RADIUS := 2.20
const QUICK_ARC_DOT := -0.04
const HEAVY_ARC_DOT := -0.24
const STOMP_ARC_DOT := -1.0
const BREAK_FINISHER_KNOCKBACK := 1.40
const HEAVY_CHAIN_WINDOW := 0.58
const BACK_ATTACK_DOT := -0.38

var _racers: Dictionary = {}
var _stagger: Dictionary = {}
var _attack_cooldown: Dictionary = {}
var _heavy_chain_window: Dictionary = {}
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
	_heavy_chain_window[id] = 0.0
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
	_heavy_chain_window[id] = 0.0
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
		_heavy_chain_window[id] = maxf(0.0, float(_heavy_chain_window.get(id, 0.0)) - delta)
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
		_heavy_chain_window.erase(id)
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
	if racer == null:
		return false
	var id := racer.get_instance_id()
	if float(_stun_remaining.get(id, 0.0)) > 0.0:
		return false

	# R4 control feel: tapping F/Y launches Quick Bash immediately. If the same
	# press is held, the charge can still resolve into Heavy Smash even though the
	# quick attack's normal cooldown is active. This window is intentionally short
	# and only exists to make one F/Y press support tap vs hold naturally.
	if kind == &"hold" and float(_heavy_chain_window.get(id, 0.0)) > 0.0:
		_heavy_chain_window[id] = 0.0
		_attack_cooldown[id] = get_attack_cooldown(racer, kind)
		return true

	if not can_attack(racer):
		return false
	_attack_cooldown[id] = get_attack_cooldown(racer, kind)
	_heavy_chain_window[id] = HEAVY_CHAIN_WINDOW if kind == &"tap" else 0.0
	return true

func get_attack_cooldown(racer: WildDashCharacterController, kind: StringName) -> float:
	if racer == null:
		return 0.85
	var profile := WildDashRaceCombatProfile.get_profile(racer.animal_id)
	var trait_cooldown := float(profile.get("cooldown", 2.0))
	var normalized := clampf(inverse_lerp(1.45, 2.35, trait_cooldown), 0.0, 1.0)
	var quick := lerpf(0.62, 0.86, normalized)
	if WildDashRaceCombatProfile.get_attack_power(racer.animal_id) >= 9.0:
		quick += 0.04
	if kind == &"hold":
		return quick * 1.36
	if kind == &"stomp":
		return quick * 1.15
	return quick

func get_attack_radius(kind: StringName) -> float:
	if kind == &"hold":
		return HEAVY_RADIUS
	if kind == &"stomp":
		return STOMP_RADIUS
	return QUICK_RADIUS

func get_attack_arc_dot(kind: StringName) -> float:
	if kind == &"hold":
		return HEAVY_ARC_DOT
	if kind == &"stomp":
		return STOMP_ARC_DOT
	return QUICK_ARC_DOT

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
		"stagger_knockback_scale": 1.0,
		"back_attack": false,
		"stomp": kind == &"stomp",
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
	var source_agility := WildDashAnimalAbilityProfile.get_stat(source.animal_id, &"agility")

	var base_knockback := QUICK_BASE_KNOCKBACK
	var base_stagger := QUICK_BASE_STAGGER
	if kind == &"hold":
		base_knockback = HEAVY_BASE_KNOCKBACK
		base_stagger = HEAVY_BASE_STAGGER
	elif kind == &"stomp":
		base_knockback = STOMP_BASE_KNOCKBACK
		base_stagger = STOMP_BASE_STAGGER
	if directional != 0 and kind != &"stomp":
		base_knockback *= 0.98
		base_stagger *= 1.08

	var power_knockback_scale := lerpf(0.72, 1.45, clampf(power / 10.0, 0.0, 1.0))
	var defense_knockback_scale := lerpf(1.18, 0.58, clampf(target_defense / 10.0, 0.0, 1.0))
	var power_stagger_scale := lerpf(0.80, 1.32, clampf(power / 10.0, 0.0, 1.0))
	var defense_stagger_scale := lerpf(1.20, 0.62, clampf(target_defense / 10.0, 0.0, 1.0))
	var stability_stagger_scale := lerpf(1.08, 0.74, clampf(target_stability / 10.0, 0.0, 1.0))

	var knockback := base_knockback * power_knockback_scale * defense_knockback_scale
	var stagger_gain := base_stagger * power_stagger_scale * defense_stagger_scale * stability_stagger_scale

	# Heavy identity still comes from shared stats, not animal-name exceptions.
	if power >= 9.0 and source_defense >= 8.0:
		knockback *= 1.08
		stagger_gain *= 1.08
	if target_defense >= 8.5:
		knockback *= 0.92
		stagger_gain *= 0.92
	if power - target_defense >= 3.0:
		knockback *= 1.12
		stagger_gain *= 1.12

	# Counter-play for light/agile animals: attacking from behind partially
	# overcomes a heavy target's Defense advantage. High Agility makes the flank
	# bonus stronger, but Power/Defense still remain the underlying authority.
	var target_forward := -target.global_transform.basis.z.normalized()
	var target_to_source := source.global_position - target.global_position
	target_to_source.y = 0.0
	var back_attack := false
	if target_to_source.length_squared() > 0.001:
		back_attack = target_forward.dot(target_to_source.normalized()) <= BACK_ATTACK_DOT
	if back_attack:
		var agility_ratio := clampf(source_agility / 10.0, 0.0, 1.0)
		var flank_knockback := lerpf(1.16, 1.46, agility_ratio)
		var flank_stagger := lerpf(1.12, 1.36, agility_ratio)
		if target_defense - power >= 2.0:
			flank_knockback *= 1.08
			flank_stagger *= 1.08
		knockback *= flank_knockback
		stagger_gain *= flank_stagger

	# Aerial stomp rewards jump specialists without turning low-Power animals into
	# frontal tanks. Agility amplifies the landing and the target's Defense still
	# reduces the hit through the normal formulas above.
	if kind == &"stomp":
		var stomp_scale := lerpf(1.02, 1.34, clampf(source_agility / 10.0, 0.0, 1.0))
		knockback *= stomp_scale
		stagger_gain *= lerpf(1.04, 1.30, clampf(source_agility / 10.0, 0.0, 1.0))

	# Smash-style pressure curve: the more stagger a target is already carrying,
	# the farther the next successful hit launches them.
	var target_id := target.get_instance_id()
	var stagger_before := float(_stagger.get(target_id, 0.0))
	var stagger_ratio := clampf(stagger_before / MAX_STAGGER, 0.0, 1.0)
	var stagger_knockback_scale := lerpf(1.0, 1.72, pow(stagger_ratio, 1.35))
	if kind == &"hold" and stagger_before >= 90.0:
		stagger_knockback_scale *= 1.18
	if kind == &"stomp" and stagger_before >= 70.0:
		stagger_knockback_scale *= 1.10
	knockback *= stagger_knockback_scale

	if float(_break_vulnerability.get(target_id, 0.0)) > 0.0:
		knockback *= BREAK_FINISHER_KNOCKBACK
		_break_vulnerability[target_id] = 0.0
		result["finisher"] = true

	var launch_direction := planar.normalized()
	if directional != 0 and kind != &"stomp":
		var side := source.global_transform.basis.x.normalized() * float(directional)
		launch_direction = (launch_direction * 0.72 + side * 0.28).normalized()

	target.apply_knockback(launch_direction, knockback)
	var recoil_scale := lerpf(1.0, 0.42, clampf((power + source_defense) / 20.0, 0.0, 1.0))
	var recoil_strength := 0.26 if kind == &"stomp" else ((1.10 if kind == &"hold" else 0.62) * recoil_scale)
	source.apply_knockback(-launch_direction, recoil_strength)

	# Round 4 combat must read as an actual brawl, not invisible stat math.
	var source_visual := source.get_visual()
	if source_visual != null:
		source_visual.play_action(&"Skill", 0.46 if kind == &"hold" else (0.34 if kind == &"stomp" else 0.28))
	var target_visual := target.get_visual()
	if target_visual != null:
		target_visual.play_action(&"Hit", 0.52 if kind == &"hold" else (0.42 if kind == &"stomp" else 0.32))

	_since_hit[target_id] = 0.0
	var next_stagger := minf(MAX_STAGGER, stagger_before + stagger_gain)
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
	result["source_agility"] = source_agility
	result["target_defense"] = target_defense
	result["target_stability"] = target_stability
	result["kind"] = kind
	result["directional"] = directional
	result["stagger_knockback_scale"] = stagger_knockback_scale
	result["back_attack"] = back_attack
	hit_resolved.emit(source, target, result.duplicate(true))
	if broke:
		stagger_break.emit(source, target, result.duplicate(true))
		print("WILD RUMBLE BREAK source=%s target=%s power=%.1f defense=%.1f stagger_gain=%.1f kb_scale=%.2f back=%s stomp=%s stun=%.2f" % [
			source.get_display_name(), target.get_display_name(), power, target_defense, stagger_gain, stagger_knockback_scale, str(back_attack), str(kind == &"stomp"), stun_seconds,
		])
	return result

func add_environment_stagger(racer: WildDashCharacterController, amount: float) -> float:
	if racer == null or not is_instance_valid(racer):
		return 0.0
	var id := racer.get_instance_id()
	if not _racers.has(id):
		register_racer(racer)
	var current := float(_stagger.get(id, 0.0))
	# Environment contact builds pressure but never causes BREAK by itself;
	# another racer must still land the finishing combat hit.
	var next := minf(92.0, current + maxf(0.0, amount))
	_stagger[id] = next
	_since_hit[id] = 0.0
	return next

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
