extends "res://systems/item_system_rc9_party_turbo.gd"

## Round 1-only offensive item impact pass.
## The existing ItemSystem remains authoritative for inventory, comeback rolls,
## recent-item history, shields, pickup flow and the 12-item architecture.
## Outside Grand Prix this adapter delegates directly to the proven RC9 system.

const ROUND1_CHAIN_WINDOW_SECONDS: float = 0.82
const ROUND1_CHAIN_SECOND_SCALE: float = 0.55
const ROUND1_CHAIN_THIRD_SCALE: float = 0.32
const ROUND1_SHOCKWAVE_CENTER_MULTIPLIER: float = 1.38
const ROUND1_SHOCKWAVE_CENTER_RADIUS: float = 2.80
const ROUND1_SHOCKWAVE_MIDDLE_RADIUS: float = 5.80
const ROUND1_SHOCKWAVE_MIDDLE_SCALE: float = 0.70
const ROUND1_SHOCKWAVE_OUTER_SCALE: float = 0.40
const ROUND1_DIRECT_KNOCKBACK_MULTIPLIERS: Dictionary = {
	&"snowball": 1.30,
	&"wind_boost": 1.20,
}

var _round1_chain_state: Dictionary = {}

func _process(delta: float) -> void:
	super._process(delta)
	_update_round1_chain_recovery()

func reset_runtime() -> void:
	_round1_chain_state.clear()
	super.reset_runtime()

func get_round1_chain_scale(target: Node) -> float:
	if not _round1_impact_active() or target == null or not is_instance_valid(target):
		return 1.0
	var data: Dictionary = _round1_chain_state.get(target.get_instance_id(), {})
	if data.is_empty():
		return 1.0
	var now: float = _now_seconds()
	if now - float(data.get("last_hit", -100.0)) > ROUND1_CHAIN_WINDOW_SECONDS:
		return 1.0
	var hit_count: int = int(data.get("hit_count", 0))
	if hit_count <= 0:
		return 1.0
	if hit_count == 1:
		return ROUND1_CHAIN_SECOND_SCALE
	return ROUND1_CHAIN_THIRD_SCALE

func apply_attack(
	target: Node,
	source: Node,
	effect_id: StringName,
	duration := 1.0,
	slow_multiplier := 0.65,
	knockback_strength := 0.0,
) -> bool:
	if not _round1_impact_active():
		return super.apply_attack(target, source, effect_id, duration, slow_multiplier, knockback_strength)
	if target == null or target == source or not is_instance_valid(target):
		return false
	if target is WildDashCharacterController and (target as WildDashCharacterController).finished:
		return false

	# Bubble Shield keeps the original full block window. A shielded hit never
	# starts the Round 1 chain counter, so the next hit cannot pierce the block.
	if has_shield(target):
		var blocked: bool = super.apply_attack(target, source, effect_id, duration, slow_multiplier, knockback_strength)
		if blocked:
			print("ROUND1 ITEM IMPACT item_hit=1 effect=%s blocked=1 chain_protection=shield" % String(effect_id))
		return blocked

	var chain_scale: float = get_round1_chain_scale(target)
	var tuned_duration: float = _round1_tuned_duration(effect_id, duration)
	var tuned_slow: float = _round1_tuned_slow(effect_id, slow_multiplier)
	var tuned_knockback: float = _round1_tuned_knockback(effect_id, knockback_strength)
	if chain_scale < 0.999:
		if tuned_duration > 0.0:
			tuned_duration = maxf(0.20, tuned_duration * maxf(0.45, chain_scale))
		tuned_slow = 1.0 - (1.0 - tuned_slow) * chain_scale
		tuned_knockback *= chain_scale

	var target_id: int = target.get_instance_id()
	var now: float = _now_seconds()
	var previous_immunity: float = float(_hit_immunity.get(target_id, 0.0))
	var bypass_immunity: bool = chain_scale < 0.999 and previous_immunity > now
	if bypass_immunity:
		_hit_immunity.erase(target_id)

	# Base ItemSystem caps its direct impulse at 6.0. Preserve that stable path,
	# then add only the bounded remainder for strengthened Round 1 hits.
	var base_knockback: float = minf(tuned_knockback, 6.0)
	var applied: bool = super.apply_attack(
		target,
		source,
		effect_id,
		tuned_duration,
		clampf(tuned_slow, 0.52, 1.0),
		base_knockback
	)
	if not applied:
		if bypass_immunity and previous_immunity > now:
			_hit_immunity[target_id] = previous_immunity
		return false

	if tuned_knockback > 6.0 and target is WildDashCharacterController:
		var controller: WildDashCharacterController = target as WildDashCharacterController
		var direction: Vector3 = -controller.global_transform.basis.z
		if source is Node3D:
			direction = controller.global_position - (source as Node3D).global_position
		direction.y = 0.0
		if direction.length_squared() > 0.001:
			controller.apply_knockback(direction.normalized(), tuned_knockback - 6.0)

	_record_round1_chain_hit(target, effect_id)
	var direct_hit: int = 1 if effect_id in [&"snowball", &"wind_boost"] else 0
	var area_hit: int = 1 if effect_id == &"shockwave" else 0
	print("ROUND1 ITEM IMPACT item_hit=1 effect=%s direct_hit=%d area_hit=%d knockback_applied=%.2f stagger_applied=%.2f chain_protection=%.2f multi_hit=%d" % [
		String(effect_id), direct_hit, area_hit, tuned_knockback, tuned_duration,
		chain_scale, 1 if chain_scale < 0.999 else 0,
	])
	return true

func _use_power_shockwave(character: Node) -> bool:
	if not _round1_impact_active():
		return super._use_power_shockwave(character)
	if not character is WildDashCharacterController:
		return false
	var source: WildDashCharacterController = character as WildDashCharacterController
	var hits: int = 0
	var center_hits: int = 0
	var middle_hits: int = 0
	var outer_hits: int = 0
	var center_knockback: float = POWER_SHOCKWAVE_KNOCKBACK * ROUND1_SHOCKWAVE_CENTER_MULTIPLIER
	for value: Variant in RaceManager.racers:
		var target: WildDashCharacterController = value as WildDashCharacterController
		if target == null or target == source or target.finished:
			continue
		var distance: float = source.global_position.distance_to(target.global_position)
		if distance > POWER_SHOCKWAVE_RADIUS:
			continue
		var falloff: float = _round1_shockwave_falloff(distance)
		var knockback: float = center_knockback * falloff
		var duration: float = maxf(0.24, POWER_SHOCKWAVE_DURATION * maxf(0.45, falloff))
		var speed_loss: float = (1.0 - POWER_SHOCKWAVE_SLOW) * falloff
		var slow: float = 1.0 - speed_loss
		if apply_attack(target, source, &"shockwave", duration, slow, knockback):
			hits += 1
			if distance <= ROUND1_SHOCKWAVE_CENTER_RADIUS:
				center_hits += 1
			elif distance <= ROUND1_SHOCKWAVE_MIDDLE_RADIUS:
				middle_hits += 1
			else:
				outer_hits += 1
	print("ROUND1 SHOCKWAVE POWER area_hit=%d center=%d middle=%d outer=%d radius=%.1f center_knockback=%.2f falloff=100/70/40" % [
		hits, center_hits, middle_hits, outer_hits, POWER_SHOCKWAVE_RADIUS, center_knockback,
	])
	return true

func _round1_shockwave_falloff(distance: float) -> float:
	if distance <= ROUND1_SHOCKWAVE_CENTER_RADIUS:
		return 1.0
	if distance <= ROUND1_SHOCKWAVE_MIDDLE_RADIUS:
		var middle_t: float = clampf(
			(distance - ROUND1_SHOCKWAVE_CENTER_RADIUS) /
			(ROUND1_SHOCKWAVE_MIDDLE_RADIUS - ROUND1_SHOCKWAVE_CENTER_RADIUS),
			0.0, 1.0
		)
		return lerpf(1.0, ROUND1_SHOCKWAVE_MIDDLE_SCALE, middle_t)
	var outer_t: float = clampf(
		(distance - ROUND1_SHOCKWAVE_MIDDLE_RADIUS) /
		maxf(0.01, POWER_SHOCKWAVE_RADIUS - ROUND1_SHOCKWAVE_MIDDLE_RADIUS),
		0.0, 1.0
	)
	return lerpf(ROUND1_SHOCKWAVE_MIDDLE_SCALE, ROUND1_SHOCKWAVE_OUTER_SCALE, outer_t)

func _round1_tuned_knockback(effect_id: StringName, value: float) -> float:
	var multiplier: float = float(ROUND1_DIRECT_KNOCKBACK_MULTIPLIERS.get(effect_id, 1.0))
	return maxf(0.0, value * multiplier)

func _round1_tuned_duration(effect_id: StringName, value: float) -> float:
	match effect_id:
		&"bee_swarm":
			return minf(value, 0.95)
		&"mud_splash":
			return minf(value, 1.10)
		&"sticky_fruit":
			return minf(value, 1.10)
		&"banana_peel":
			return minf(value, 0.72)
		&"rocket_nut":
			return minf(value, 0.65)
		&"acorn_bomb":
			return minf(value, 0.82)
		_:
			return value

func _round1_tuned_slow(effect_id: StringName, value: float) -> float:
	match effect_id:
		&"snowball":
			return minf(value, 0.69)
		&"bee_swarm":
			return minf(value, 0.82)
		&"mud_splash":
			return maxf(value, 0.68)
		&"wind_boost":
			return minf(value, 0.92)
		_:
			return value

func _record_round1_chain_hit(target: Node, effect_id: StringName) -> void:
	var id: int = target.get_instance_id()
	var now: float = _now_seconds()
	var data: Dictionary = _round1_chain_state.get(id, {})
	var hit_count: int = 0
	if not data.is_empty() and now - float(data.get("last_hit", -100.0)) <= ROUND1_CHAIN_WINDOW_SECONDS:
		hit_count = int(data.get("hit_count", 0))
	_round1_chain_state[id] = {
		"target": target,
		"last_hit": now,
		"hit_count": mini(3, hit_count + 1),
		"effect": effect_id,
	}

func _update_round1_chain_recovery() -> void:
	if not _round1_impact_active():
		if not _round1_chain_state.is_empty():
			_round1_chain_state.clear()
		return
	var now: float = _now_seconds()
	for id_value: Variant in _round1_chain_state.keys():
		var id: int = int(id_value)
		var data: Dictionary = _round1_chain_state.get(id, {})
		if now - float(data.get("last_hit", now)) <= ROUND1_CHAIN_WINDOW_SECONDS:
			continue
		var target: Node = data.get("target") as Node
		print("ROUND1 ITEM IMPACT recovery_complete=1 target=%s chain_hits=%d last_effect=%s" % [
			_label(target), int(data.get("hit_count", 0)), StringName(data.get("effect", &"")),
		])
		_round1_chain_state.erase(id)

func _round1_impact_active() -> bool:
	return RaceManager.active and GameManager.get_current_round_id() == &"grand_prix"
