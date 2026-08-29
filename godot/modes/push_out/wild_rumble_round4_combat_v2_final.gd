extends "res://modes/push_out/wild_rumble_round4_canopy_safety.gd"

## Round 4 Combat V2 final adapter. ArenaCombatCore remains authoritative for
## Stagger/Break/survival/Recovery Brake. This layer supplies final character
## identity, character-aware target scoring and limited AI canopy traversal.

const PHASE3_PLAYER_IDS: Array[StringName] = [&"dog", &"wolf", &"boar", &"elephant", &"bear", &"raccoon"]
const FINAL_AI_MAX_CHASERS: int = 2
const FINAL_AI_OBJECTIVE_MAX_CHASERS: int = 3
const RACCOON_CONTROL_SCALE: float = 0.82
const RACCOON_CONTROL_SECONDS: float = 0.72

var _final_ai_canopy_by_id: Dictionary = {}
var _final_bear_aerial_cooldown: float = 0.0

func _ready() -> void:
	await super()
	if _round4_canopy_routes.is_empty() and _has_round4_monkey_ai():
		_build_round4_canopy_network()
	for racer: WildDashCharacterController in ai_racers:
		if racer == null or racer.animal_id != &"monkey":
			continue
		var system: WildDashCanopyTraversalSystem = WildDashCanopyTraversalSystem.new()
		system.set_routes(_round4_canopy_routes)
		_final_ai_canopy_by_id[racer.get_instance_id()] = system
	print("WILD RUMBLE COMBAT V2 FINAL READY 12_roles=true ai_target_scoring=true anti_dogpile=2 objective_burst=3 monkey_ai_canopy=true")

func _exit_tree() -> void:
	for racer: WildDashCharacterController in ai_racers:
		if racer == null:
			continue
		var system: WildDashCanopyTraversalSystem = _final_ai_canopy_by_id.get(racer.get_instance_id(), null) as WildDashCanopyTraversalSystem
		if system != null and system.is_swinging():
			system.cancel_vine(racer)
	super()

func _physics_process(delta: float) -> void:
	super(delta)
	_final_bear_aerial_cooldown = maxf(0.0, _final_bear_aerial_cooldown - delta)
	if not _final_ai_canopy_by_id.is_empty():
		_update_round4_vine_availability()
		_update_round4_monkey_ai_canopy(delta)

func _on_phase1_combat_action(action: Dictionary) -> void:
	if player == null or not PHASE3_PLAYER_IDS.has(player.animal_id):
		super(action)
		return
	if _round4_brace_consumed_press or _round4_brace_signal_suppress_remaining > 0.0:
		return
	var kind: StringName = StringName(action.get("kind", &"tap"))
	_phase3_round4_profile_attack(kind == &"hold")

func _phase3_round4_profile_attack(heavy: bool) -> void:
	if player == null or _combat_core == null or not _is_combatant_active(player):
		return
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_heavy_attack(player.animal_id) if heavy else WildDashCombatAbilitySystem.get_basic_attack(player.animal_id)
	if spec == null:
		return
	var core_kind: StringName = &"hold" if heavy else &"tap"
	if not _combat_core.try_begin_attack(player, core_kind):
		return
	var momentum_ratio: float = clampf(Vector2(player.velocity.x, player.velocity.z).length() / maxf(1.0, player.arena_move_speed), 0.0, 1.0)
	var momentum_multiplier: float = WildDashCombatAbilitySystem.get_momentum_effect_multiplier(spec, momentum_ratio)
	var context: Dictionary = {"in_water": false, "momentum_multiplier": momentum_multiplier}
	var preview: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(player, null, spec, &"push_out", context)
	var forward: Vector3 = -player.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	if preview.mobility_impulse > 0.01:
		player.apply_knockback(forward, preview.mobility_impulse)

	if player.animal_id == &"bear" and heavy:
		_phase3_round4_bear_body_slam(spec)
		return

	var target: WildDashCharacterController = _combat_v2_round4_front_target(spec.range, spec.arc_dot)
	if target == null:
		if hud != null:
			hud.set_message("%s · NO TARGET" % spec.display_name)
		return
	var offset: Vector3 = target.global_position - player.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return
	var result: Dictionary = _combat_core.apply_hit(player, target, offset, core_kind, 0)
	if not bool(result.get("applied", false)):
		return
	_record_phase2_hit_credit(player, target)
	var back_attack: bool = bool(result.get("back_attack", false))

	if player.animal_id == &"wolf" and heavy and back_attack:
		_combat_core.add_environment_stagger(target, 7.0)
		target.apply_knockback(offset.normalized(), 1.15)
		if hud != null:
			hud.set_message("REAR POUNCE! · STAGGER %.0f/100" % _combat_core.get_stagger(target))
	elif player.animal_id == &"elephant":
		target.apply_knockback(offset.normalized(), 1.25 if not heavy else 0.75)
		if heavy:
			_combat_core.add_environment_stagger(target, 6.0)
		if hud != null:
			hud.set_message("%s! · PUSH · STAGGER %.0f/100" % [spec.display_name, _combat_core.get_stagger(target)])
	elif player.animal_id == &"boar" and heavy:
		target.apply_knockback(offset.normalized(), 1.35)
		if hud != null:
			hud.set_message("BOAR CHARGE! · KB %.1f" % float(result.get("knockback", 0.0)))
	elif player.animal_id == &"raccoon":
		_apply_round4_control(target, RACCOON_CONTROL_SCALE, RACCOON_CONTROL_SECONDS)
		if hud != null:
			hud.set_message("%s! · CONTROL" % spec.display_name)
	elif hud != null:
		hud.set_message("%s! · STAGGER %.0f/100" % [spec.display_name, _combat_core.get_stagger(target)])

	WildDashCombatV2FX.spawn_impact(self, target.global_position + Vector3.UP * 0.65, _final_fx_kind(player.animal_id, heavy), 1.15 if heavy else 0.95)
	_round4_camera_shake_remaining = maxf(_round4_camera_shake_remaining, 0.12 if heavy else 0.08)

func _phase3_round4_bear_body_slam(spec: WildDashCombatAbilitySpec) -> void:
	var hits: int = 0
	for target: WildDashCharacterController in racers:
		if target == player or not _is_combatant_active(target):
			continue
		var offset: Vector3 = target.global_position - player.global_position
		offset.y = 0.0
		if offset.length_squared() <= 0.001 or offset.length() > spec.range:
			continue
		var result: Dictionary = _combat_core.apply_hit(player, target, offset, &"tap", 0)
		if not bool(result.get("applied", false)):
			continue
		_combat_core.add_environment_stagger(target, 4.0)
		_record_phase2_hit_credit(player, target)
		hits += 1
		if hits >= 3:
			break
	WildDashCombatV2FX.spawn_impact(self, player.global_position + Vector3.UP * 0.30, &"stomp", 1.50)
	if hud != null:
		hud.set_message("BODY SLAM! · TARGETS %d" % hits)

func _update_round4_player_stomp() -> void:
	if player == null or player.animal_id != &"bear":
		super()
		return
	if _combat_core == null or _final_bear_aerial_cooldown > 0.0 or player.is_on_floor() or player.velocity.y > ROUND4_STOMP_MIN_FALL_SPEED:
		return
	var target: WildDashCharacterController = _final_bear_stomp_target()
	if target == null:
		return
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_aerial_attack(&"bear")
	if spec == null or not _combat_core.try_begin_attack(player, &"stomp"):
		return
	var offset: Vector3 = target.global_position - player.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		offset = Vector3.FORWARD
	var result: Dictionary = _combat_core.apply_hit(player, target, offset, &"stomp", 0)
	if not bool(result.get("applied", false)):
		return
	_record_phase2_hit_credit(player, target)
	_combat_core.add_environment_stagger(target, 5.0)
	player.velocity.y = maxf(player.velocity.y, player.jump_velocity * 0.24)
	_final_bear_aerial_cooldown = spec.cooldown
	WildDashCombatV2FX.spawn_impact(self, target.global_position + Vector3.UP * 0.30, &"stomp", 1.55)
	if hud != null:
		hud.set_message("BELLY DROP! · STAGGER %.0f/100" % _combat_core.get_stagger(target))

func _final_bear_stomp_target() -> WildDashCharacterController:
	var best: WildDashCharacterController
	var best_distance: float = INF
	for target: WildDashCharacterController in racers:
		if target == player or not _is_combatant_active(target):
			continue
		var height: float = player.global_position.y - target.global_position.y
		if height < 0.55 or height > 3.2:
			continue
		var distance: float = Vector2(target.global_position.x - player.global_position.x, target.global_position.z - player.global_position.z).length()
		if distance <= 2.8 and distance < best_distance:
			best_distance = distance
			best = target
	return best

func _try_use_round4_special(source: WildDashCharacterController) -> bool:
	if source == null:
		return false
	if source.animal_id == &"crocodile":
		return _final_crocodile_land_ambush(source)
	if source.animal_id == &"elephant":
		return _final_elephant_ground_stomp(source)
	return super(source)

func _final_crocodile_land_ambush(source: WildDashCharacterController) -> bool:
	var id: int = source.get_instance_id()
	if float(_round4_special_cooldown_by_id.get(id, 0.0)) > 0.0:
		return false
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_special_attack(&"crocodile")
	if spec == null:
		return false
	_round4_special_cooldown_by_id[id] = spec.cooldown
	var context: Dictionary = {"in_water": false}
	var preview: WildDashCombatResolution = WildDashCombatAbilityResolver.resolve_spec(source, null, spec, &"push_out", context)
	var forward: Vector3 = -source.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	source.apply_knockback(forward, preview.mobility_impulse * 0.55)
	var target: WildDashCharacterController = _nearest_round4_special_target(source, spec.range)
	WildDashCombatV2FX.spawn_trail(self, source.global_position + Vector3.UP * 0.55, forward, &"water", 1.0)
	if target == null or _combat_core == null:
		if source == player and hud != null:
			hud.set_message("WATER AMBUSH · LAND POWER 55%")
		return true
	var offset: Vector3 = target.global_position - source.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return true
	# In Titan Crown there is no water, so the ambush is deliberately a reduced
	# utility lunge rather than a replacement for Bite/Tail.
	target.apply_knockback(offset.normalized(), preview.knockback * 0.55)
	_combat_core.add_environment_stagger(target, preview.stagger * 0.55)
	if source == player and hud != null:
		hud.set_message("WATER AMBUSH! · LAND 55% · STAGGER %.0f/100" % _combat_core.get_stagger(target))
	return true

func _final_elephant_ground_stomp(source: WildDashCharacterController) -> bool:
	var id: int = source.get_instance_id()
	if float(_round4_special_cooldown_by_id.get(id, 0.0)) > 0.0:
		return false
	var spec: WildDashCombatAbilitySpec = WildDashCombatAbilitySystem.get_special_attack(&"elephant")
	if spec == null or _combat_core == null:
		return false
	_round4_special_cooldown_by_id[id] = spec.cooldown
	var hits: int = 0
	for target: WildDashCharacterController in racers:
		if target == source or not _is_combatant_active(target):
			continue
		var offset: Vector3 = target.global_position - source.global_position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= 0.01 or distance > spec.range:
			continue
		var falloff: float = lerpf(1.0, 0.55, distance / spec.range)
		target.apply_knockback(offset.normalized(), spec.base_knockback * falloff)
		_combat_core.add_environment_stagger(target, spec.base_stagger * falloff)
		hits += 1
	WildDashCombatV2FX.spawn_impact(self, source.global_position + Vector3.UP * 0.15, &"stomp", 1.70)
	if source == player and hud != null:
		hud.set_message("GROUND STOMP! · TARGETS %d" % hits)
	return true

func _apply_round4_control(target: WildDashCharacterController, scale: float, seconds: float) -> void:
	if target == null:
		return
	var id: int = target.get_instance_id()
	_round4_special_slow_remaining_by_id[id] = maxf(float(_round4_special_slow_remaining_by_id.get(id, 0.0)), seconds)
	_round4_special_slow_scale_by_id[id] = minf(float(_round4_special_slow_scale_by_id.get(id, 1.0)), scale)

func _phase2_target_for(ai_index: int, racer: WildDashCharacterController) -> WildDashCharacterController:
	if racer == null:
		return null
	var racer_id: int = racer.get_instance_id()
	var locked: WildDashCharacterController = _phase2_ai_targets.get(racer_id, null) as WildDashCharacterController
	var lock_remaining: float = float(_phase2_ai_target_lock.get(racer_id, 0.0))
	if locked != null and is_instance_valid(locked) and locked != racer and _is_combatant_active(locked) and lock_remaining > 0.0:
		return locked

	var best: WildDashCharacterController
	var best_score: float = INF
	for candidate: WildDashCharacterController in racers:
		if candidate == racer or not _is_combatant_active(candidate):
			continue
		var chasers: int = _phase2_direct_chaser_count(candidate, racer_id)
		var objective: bool = _final_is_objective_carrier(candidate)
		var allowed_chasers: int = FINAL_AI_OBJECTIVE_MAX_CHASERS if objective else FINAL_AI_MAX_CHASERS
		if chasers >= allowed_chasers:
			continue
		var radius: float = Vector2(candidate.global_position.x, candidate.global_position.z).length()
		var edge_ratio: float = clampf(radius / maxf(1.0, _round4_current_ring_radius), 0.0, 1.25)
		var stagger: float = _combat_core.get_stagger(candidate) if _combat_core != null else 0.0
		var score: float = WildDashCombatV2AIBrain.target_score(racer, candidate, &"push_out", 0, stagger, edge_ratio, objective, 0.0, chasers)
		if candidate == player and _phase2_is_player_pressure_slot(ai_index) and chasers < FINAL_AI_MAX_CHASERS:
			score -= 32.0
		score += float((candidate.get_instance_id() + ai_index * 19) % 13) * 0.03
		if score < best_score:
			best_score = score
			best = candidate

	if best != null:
		_phase2_ai_targets[racer_id] = best
		_phase2_ai_target_lock[racer_id] = PHASE2_AI_TARGET_LOCK_SECONDS + float(ai_index % 3) * 0.10
	return best

func _phase2_attack_kind(ai_index: int, racer: WildDashCharacterController, target: WildDashCharacterController) -> StringName:
	if racer == null or target == null or _combat_core == null:
		return super(ai_index, racer, target)
	var distance: float = racer.global_position.distance_to(target.global_position)
	var stagger: float = _combat_core.get_stagger(target)
	var behind: bool = WildDashCombatV2AIBrain.is_behind_target(racer, target)
	var tick: int = int(Time.get_ticks_msec() / 760) + ai_index
	return WildDashCombatV2AIBrain.preferred_attack_kind(racer.animal_id, stagger, distance, behind, tick)

func _phase2_after_successful_ai_hit(racer: WildDashCharacterController, target: WildDashCharacterController, attack_direction: Vector3, kind: StringName) -> void:
	super(racer, target, attack_direction, kind)
	if racer == null or target == null or _combat_core == null:
		return
	var behind: bool = WildDashCombatV2AIBrain.is_behind_target(racer, target)
	match racer.animal_id:
		&"elephant":
			target.apply_knockback(attack_direction, 1.05)
			if kind == &"hold":
				_combat_core.add_environment_stagger(target, 4.0)
		&"boar":
			if kind == &"hold":
				target.apply_knockback(attack_direction, 1.25)
				WildDashCombatV2FX.spawn_trail(self, racer.global_position + Vector3.UP * 0.5, attack_direction, &"charge", 1.0)
		&"wolf":
			if kind == &"hold" and behind:
				_combat_core.add_environment_stagger(target, 6.0)
		&"raccoon":
			_apply_round4_control(target, RACCOON_CONTROL_SCALE, RACCOON_CONTROL_SECONDS)
		&"crocodile":
			if kind == &"hold":
				_final_ai_crocodile_tail_pressure(racer, target)
		_:
			pass

func _final_ai_crocodile_tail_pressure(source: WildDashCharacterController, primary: WildDashCharacterController) -> void:
	for target: WildDashCharacterController in racers:
		if target == source or target == primary or not _is_combatant_active(target):
			continue
		var offset: Vector3 = target.global_position - source.global_position
		offset.y = 0.0
		if offset.length_squared() > 0.001 and offset.length() <= 3.8:
			target.apply_knockback(offset.normalized(), 0.85)

func _final_is_objective_carrier(candidate: WildDashCharacterController) -> bool:
	if candidate == null:
		return false
	for relic: Dictionary in _round4_relics:
		var carrier: WildDashCharacterController = relic.get("carrier", null) as WildDashCharacterController
		if carrier == candidate:
			return true
	var crown_carrier: WildDashCharacterController = _round4_crown.get("carrier", null) as WildDashCharacterController
	return crown_carrier == candidate

func _has_round4_monkey_ai() -> bool:
	for racer: WildDashCharacterController in ai_racers:
		if racer != null and racer.animal_id == &"monkey":
			return true
	return false

func _update_round4_monkey_ai_canopy(delta: float) -> void:
	if _round4_canopy_routes.is_empty() or _round4_alive_count() <= 2:
		return
	for racer: WildDashCharacterController in ai_racers:
		if racer == null or racer.animal_id != &"monkey" or not _is_combatant_active(racer):
			continue
		var system: WildDashCanopyTraversalSystem = _final_ai_canopy_by_id.get(racer.get_instance_id(), null) as WildDashCanopyTraversalSystem
		if system == null:
			continue
		var target: WildDashCharacterController = _phase2_ai_targets.get(racer.get_instance_id(), null) as WildDashCharacterController
		if system.is_swinging():
			var reached_end: bool = system.update_swing(racer, delta, 0.55)
			if target != null and _is_combatant_active(target) and racer.global_position.distance_to(target.global_position) <= 3.2:
				_final_monkey_ai_swing_kick(racer, target, system)
			if reached_end:
				racer.velocity = system.release_vine(racer, false) + Vector3.UP * 1.0
			continue
		if target == null or not _is_combatant_active(target) or racer.global_position.distance_to(target.global_position) > 8.5:
			continue
		var route: WildDashCanopyVineRoute = system.find_nearest_vine(racer.global_position, 3.7)
		if route != null:
			system.grab_vine(racer, route)

func _final_monkey_ai_swing_kick(source: WildDashCharacterController, target: WildDashCharacterController, system: WildDashCanopyTraversalSystem) -> void:
	if _combat_core == null or not _combat_core.can_attack(source):
		return
	if not _combat_core.try_begin_attack(source, &"tap"):
		return
	var offset: Vector3 = target.global_position - source.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return
	var result: Dictionary = _combat_core.apply_hit(source, target, offset, &"tap", 0)
	if not bool(result.get("applied", false)):
		return
	var impact: float = WildDashCombatAbilitySystem.get_monkey_swing_impact_scale(system.get_swing_speed_ratio())
	_combat_core.add_environment_stagger(target, 4.0 * impact)
	target.apply_knockback(offset.normalized(), 0.75 * impact)
	_record_phase2_hit_credit(source, target)

func _final_fx_kind(animal_id: StringName, heavy: bool) -> StringName:
	if animal_id == &"boar" and heavy:
		return &"charge"
	if animal_id == &"elephant":
		return &"push"
	if animal_id == &"raccoon":
		return &"control"
	return &"impact"
