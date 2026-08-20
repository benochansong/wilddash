extends "res://modes/fruit_collection/fruit_frenzy_v6_ai_vertical_assist.gd"

## Round 2 V7 Combat V2 adapter.
## Phase 1 migrates Crocodile Bite/Tail onto the typed shared ability contract
## while leaving the proven generic Body Check, fart specials and fruit economy
## authority in the existing Fruit Frenzy stack.

var _combat_v2_tail_recovery_remaining: float = 0.0

func _ready() -> void:
	await super()
	print("FRUIT FRENZY V7 COMBAT V2 READY crocodile_shared_profile=true round2_modifier=true legacy_farts_preserved=true")

func _physics_process(delta: float) -> void:
	super(delta)
	_combat_v2_tail_recovery_remaining = maxf(0.0, _combat_v2_tail_recovery_remaining - delta)

func _try_player_body_check() -> void:
	if player == null or player.animal_id != &"crocodile":
		super()
		return
	if _player_body_check_cooldown > 0.0 or _is_stunned(player):
		return

	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_basic_attack(player.animal_id)
	if spec == null:
		return
	var in_water: bool = _is_river_position(player.global_position)
	var effective_range: float = WildDashCombatAbilitySystem.get_effective_range(spec, in_water)
	var target: WildDashCharacterController = _combat_v2_front_target(player, effective_range, spec.arc_dot)
	var context: Dictionary = {"in_water": in_water}
	var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(
		player,
		target,
		spec,
		&"fruit_collection",
		context
	)
	if not result.applied:
		return

	if target == null:
		var miss_forward: Vector3 = -player.global_transform.basis.z
		miss_forward.y = 0.0
		if miss_forward.length_squared() <= 0.001:
			miss_forward = Vector3.FORWARD
		else:
			miss_forward = miss_forward.normalized()
		player.apply_knockback(miss_forward, result.mobility_impulse * 0.85)
		hud.set_message("BITE LUNGE · NO TARGET")
		_player_body_check_cooldown = maxf(0.62, result.cooldown * 0.38)
		return

	var offset: Vector3 = target.global_position - player.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return
	var direction: Vector3 = offset.normalized()
	target.apply_knockback(direction, result.knockback)
	var forward: Vector3 = -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = direction
	else:
		forward = forward.normalized()
	player.apply_knockback(forward, result.mobility_impulse)
	_player_body_check_cooldown = maxf(0.1, result.cooldown)
	var spill_count: int = mini(result.fruit_spill, _get_carry(target))
	if spill_count > 0:
		_spill_racer(target, spill_count, "CROCODILE BITE LUNGE V2")
		spill_hit_cooldown_by_id[target.get_instance_id()] = COMBAT_SPILL_COOLDOWN
	_apply_power_stun(player, target)
	AudioManager.play_sfx_id("hit", 1.0)
	hud.set_message("BITE LUNGE! · %s%s" % [
		target.get_display_name().to_upper(),
		" · WATER +15%" if result.water_bonus else "",
	])
	print("COMBAT V2 CROCODILE BITE mode=fruit_collection water=%s kb=%.2f spill=%d" % [
		str(in_water), result.knockback, spill_count,
	])

func _on_round2_combat_gesture(action: Dictionary) -> void:
	if player == null or player.animal_id != &"crocodile" or mode_finished or not GameManager.round_active:
		return
	var kind: StringName = StringName(action.get("kind", &""))
	if kind != &"hold":
		return
	_do_crocodile_tail_sweep()

func _do_crocodile_tail_sweep() -> void:
	if player == null or _combat_v2_tail_recovery_remaining > 0.0 or _is_stunned(player):
		return
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_heavy_attack(player.animal_id)
	if spec == null:
		return
	var hit_count: int = 0
	var spill_budget: int = spec.fruit_spill
	for target: WildDashCharacterController in racers:
		if target == null or target == player or target.finished:
			continue
		var offset: Vector3 = target.global_position - player.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= 0.01 or distance > spec.range:
			continue
		var directional_multiplier: float = WildDashCombatAbilitySystem.get_tail_direction_multiplier(player, target)
		var context: Dictionary = {
			"in_water": _is_river_position(player.global_position),
			"directional_multiplier": directional_multiplier,
		}
		var result: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(
			player,
			target,
			spec,
			&"fruit_collection",
			context
		)
		if not result.applied:
			continue
		target.apply_knockback(offset.normalized(), result.knockback)
		if spill_budget > 0 and _get_carry(target) > 0:
			var spill_count: int = mini(spill_budget, _get_carry(target))
			_spill_racer(target, spill_count, "CROCODILE TAIL SWEEP V2")
			spill_hit_cooldown_by_id[target.get_instance_id()] = COMBAT_SPILL_COOLDOWN
			spill_budget -= spill_count
		hit_count += 1

	_combat_v2_tail_recovery_remaining = spec.recovery
	_player_body_check_cooldown = maxf(_player_body_check_cooldown, spec.recovery)
	if hit_count > 0:
		AudioManager.play_sfx_id("hit", 0.86)
		hud.set_message("TAIL SWEEP! · TARGETS %d" % hit_count)
		print("COMBAT V2 CROCODILE TAIL mode=fruit_collection targets=%d recovery=%.2f" % [hit_count, spec.recovery])
	elif hud != null:
		hud.set_message("TAIL SWEEP · NO TARGET")

func _combat_v2_front_target(
	source: WildDashCharacterController,
	attack_range: float,
	arc_dot: float
) -> WildDashCharacterController:
	if source == null:
		return null
	var forward: Vector3 = -source.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var best: WildDashCharacterController = null
	var best_distance: float = INF
	for candidate: WildDashCharacterController in racers:
		if candidate == null or candidate == source or candidate.finished:
			continue
		var offset: Vector3 = candidate.global_position - source.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= 0.01 or distance > attack_range:
			continue
		if forward.dot(offset.normalized()) < arc_dot:
			continue
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best
