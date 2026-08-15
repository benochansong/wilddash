extends "res://modes/push_out/wild_rumble_mode.gd"

## WILD RUMBLE Phase 2
## Replaces Phase 1 fixed shove values with the shared Power/Defense profile,
## Stagger/Break, finisher launch bonus and stat-derived Heavy character meta.

const ARENA_COMBAT_CORE_SCRIPT: Script = preload("res://modes/push_out/arena_combat_core.gd")
const BREAK_SCORE := 2
const PHASE2_AI_DECISION_INTERVAL := 0.20

enum Phase2AIState {
	CHASE,
	ATTACK,
	EVADE,
	RETREAT,
	FLANK,
	EDGE_RECOVER,
}

# Round 4 must read as a moving brawl, not pairs of colliders glued together.
# Target locks stop twitching, state-specific movement creates chase/evasion arcs,
# and close-contact escape guarantees that every engagement breaks apart and
# reforms instead of shivering in place.
const PHASE2_AI_TARGET_LOCK_SECONDS := 1.45
const PHASE2_AI_EDGE_RECOVERY_RADIUS := 16.25
const PHASE2_AI_SAFE_MOVE_RADIUS := 14.9
const PHASE2_AI_STANDOFF_DISTANCE := 2.05
const PHASE2_AI_STRAFE_DISTANCE := 1.45
const PHASE2_AI_CLOSE_DISTANCE := 1.55
const PHASE2_AI_ATTACK_REACH_MARGIN := 0.48
const PHASE2_AI_MAX_DIRECT_CHASERS := 3
const PHASE2_AI_PLAYER_MAX_CHASERS := 3
const PHASE2_AI_PLAYER_PRESSURE_BONUS := 92.0
const PHASE2_AI_HEAVY_HUNT_BONUS := 58.0
const PHASE2_AI_THREAT_SCAN_RADIUS := 6.8
const PHASE2_AI_CLOSE_CONTACT_BREAK_SECONDS := 1.10
const PHASE2_AI_RETREAT_SECONDS := 0.82
const PHASE2_AI_EVADE_SECONDS := 0.72
const PHASE2_AI_FLANK_SECONDS := 0.78
const PHASE2_AI_QUICK_COMMIT_IMPULSE := 1.45
const PHASE2_AI_HEAVY_COMMIT_IMPULSE := 2.45

var _combat_core: WildDashArenaCombatCore
var _phase2_initialized := false
var _base_arena_move_speeds: Dictionary = {}
var _base_ai_target_speeds: Dictionary = {}
var _phase2_active_state: Dictionary = {}
var _phase2_ai_targets: Dictionary = {}
var _phase2_ai_target_lock: Dictionary = {}
var _phase2_ai_strafe_sign: Dictionary = {}
var _phase2_ai_state: Dictionary = {}
var _phase2_ai_state_timer: Dictionary = {}
var _phase2_ai_close_contact: Dictionary = {}

func _ensure_phase2_core() -> void:
	if _phase2_initialized:
		return
	_combat_core = ARENA_COMBAT_CORE_SCRIPT.new() as WildDashArenaCombatCore
	if _combat_core == null:
		push_error("WILD RUMBLE PHASE2 failed to create ArenaCombatCore")
		return
	_combat_core.name = "ArenaCombatCore"
	add_child(_combat_core)
	_combat_core.stagger_break.connect(_on_phase2_stagger_break)
	for racer in racers:
		if racer == null:
			continue
		_combat_core.register_racer(racer)
		var id := racer.get_instance_id()
		_base_arena_move_speeds[id] = racer.arena_move_speed
		_phase2_active_state[id] = _is_combatant_active(racer)
	for i in range(ai_racers.size()):
		if i >= ai_drivers.size():
			break
		var racer: WildDashCharacterController = ai_racers[i]
		var id := racer.get_instance_id()
		_base_ai_target_speeds[id] = ai_drivers[i].target_speed
		_phase2_ai_target_lock[id] = 0.0
		_phase2_ai_strafe_sign[id] = -1.0 if i % 2 == 0 else 1.0
		_phase2_ai_state[id] = Phase2AIState.CHASE
		_phase2_ai_state_timer[id] = 0.0
		_phase2_ai_close_contact[id] = 0.0
	if hud != null:
		hud.configure(
			"ROUND 4 — WILD RUMBLE: TITAN CLASH",
			"PHASE 2 · F/Y QUICK BASH · HOLD F/Y HEAVY SMASH · STAGGER → BREAK"
		)
	_phase2_initialized = true
	var player_profile := _combat_core.get_profile(player)
	print("WILD RUMBLE PHASE2 READY power_defense=true stagger=true break=true finisher=true role_ai=true player_pressure=true player=%s power=%.1f defense=%.1f stability=%.1f" % [
		player.get_display_name() if player != null else "none",
		float(player_profile.get("attack_power", 0.0)),
		float(player_profile.get("defense", 0.0)),
		float(player_profile.get("stability", 0.0)),
	])

func _update_phase1_ai(delta: float) -> void:
	_ensure_phase2_core()
	if not _phase2_initialized:
		return
	_sync_respawn_resets()
	_tick_phase2_ai_runtime(delta)
	_apply_break_control_locks()

	_ai_decision_elapsed += delta
	if _ai_decision_elapsed >= PHASE2_AI_DECISION_INTERVAL:
		_ai_decision_elapsed = fmod(_ai_decision_elapsed, PHASE2_AI_DECISION_INTERVAL)
		for i in range(ai_racers.size()):
			if i >= ai_drivers.size():
				break
			var racer: WildDashCharacterController = ai_racers[i]
			if not _is_combatant_active(racer):
				continue
			if _combat_core.get_stun_remaining(racer) > 0.0:
				ai_drivers[i].set_arena_target(racer.global_position)
				continue

			var planar_radius := Vector2(racer.global_position.x, racer.global_position.z).length()
			if planar_radius >= PHASE2_AI_EDGE_RECOVERY_RADIUS:
				_set_phase2_ai_state(racer, Phase2AIState.EDGE_RECOVER, 0.45)
				ai_drivers[i].set_arena_target(Vector3.ZERO)
				continue

			var target := _phase2_target_for(i, racer)
			if target == null:
				_set_phase2_ai_state(racer, Phase2AIState.CHASE, 0.0)
				ai_drivers[i].set_arena_target(Vector3.ZERO)
				continue

			var state := _phase2_choose_state(i, racer, target)
			_set_phase2_ai_state(racer, state, _phase2_default_state_hold(state))
			ai_drivers[i].set_arena_target(_phase2_state_target_point(racer, target, state))

	for i in range(ai_racers.size()):
		if i >= ai_drivers.size():
			break
		var racer: WildDashCharacterController = ai_racers[i]
		if not _is_combatant_active(racer) or _combat_core.get_stun_remaining(racer) > 0.0:
			continue
		if not _combat_core.can_attack(racer):
			continue
		var racer_id := racer.get_instance_id()
		var state := int(_phase2_ai_state.get(racer_id, Phase2AIState.CHASE))
		if state == Phase2AIState.EVADE or state == Phase2AIState.RETREAT or state == Phase2AIState.EDGE_RECOVER:
			continue
		var target := _phase2_target_for(i, racer)
		if target == null:
			continue
		if float(_spawn_protection.get(target.get_instance_id(), 0.0)) > 0.0:
			continue
		var offset := target.global_position - racer.global_position
		offset.y = 0.0
		if offset.length_squared() <= 0.001:
			continue

		var kind := _phase2_attack_kind(i, racer, target)
		if offset.length() > _combat_core.get_attack_radius(kind) + PHASE2_AI_ATTACK_REACH_MARGIN:
			continue

		_set_phase2_ai_state(racer, Phase2AIState.ATTACK, 0.24)
		var attack_direction := offset.normalized()
		var target_yaw := atan2(-attack_direction.x, -attack_direction.z)
		racer.rotation.y = lerp_angle(racer.rotation.y, target_yaw, 0.72)
		if not _combat_core.try_begin_attack(racer, kind):
			continue
		var result := _combat_core.apply_hit(racer, target, offset, kind, 0)
		if not bool(result.get("applied", false)):
			continue
		_record_phase2_hit_credit(racer, target)
		_phase2_after_successful_ai_hit(racer, target, attack_direction, kind)
		if target == player:
			hud.set_message("%s HIT · STAGGER %.0f/100" % [
				"HEAVY SMASH" if kind == &"hold" else "QUICK BASH",
				_combat_core.get_stagger(player),
			])

func _tick_phase2_ai_runtime(delta: float) -> void:
	for raw_id in _phase2_ai_target_lock.keys():
		var id := int(raw_id)
		_phase2_ai_target_lock[id] = maxf(0.0, float(_phase2_ai_target_lock.get(id, 0.0)) - delta)
		_phase2_ai_state_timer[id] = maxf(0.0, float(_phase2_ai_state_timer.get(id, 0.0)) - delta)

	for racer in ai_racers:
		if racer == null or not _is_combatant_active(racer):
			continue
		var racer_id := racer.get_instance_id()
		var target: WildDashCharacterController = _phase2_ai_targets.get(racer_id, null) as WildDashCharacterController
		if target == null or not is_instance_valid(target) or not _is_combatant_active(target):
			_phase2_ai_close_contact[racer_id] = 0.0
			continue
		var planar := target.global_position - racer.global_position
		planar.y = 0.0
		if planar.length() <= PHASE2_AI_CLOSE_DISTANCE:
			_phase2_ai_close_contact[racer_id] = float(_phase2_ai_close_contact.get(racer_id, 0.0)) + delta
		else:
			_phase2_ai_close_contact[racer_id] = maxf(0.0, float(_phase2_ai_close_contact.get(racer_id, 0.0)) - delta * 2.5)

		if float(_phase2_ai_close_contact.get(racer_id, 0.0)) < PHASE2_AI_CLOSE_CONTACT_BREAK_SECONDS:
			continue
		var role := _phase2_role(racer.animal_id)
		var escape_state := Phase2AIState.RETREAT if role == &"light" else Phase2AIState.FLANK
		_set_phase2_ai_state(racer, escape_state, PHASE2_AI_RETREAT_SECONDS if role == &"light" else PHASE2_AI_FLANK_SECONDS)
		_phase2_ai_strafe_sign[racer_id] = -float(_phase2_ai_strafe_sign.get(racer_id, 1.0))
		_phase2_ai_close_contact[racer_id] = 0.0

func _phase2_choose_state(
	ai_index: int,
	racer: WildDashCharacterController,
	target: WildDashCharacterController,
) -> int:
	var racer_id := racer.get_instance_id()
	var current_state := int(_phase2_ai_state.get(racer_id, Phase2AIState.CHASE))
	var state_time := float(_phase2_ai_state_timer.get(racer_id, 0.0))
	if state_time > 0.0 and (
		current_state == Phase2AIState.RETREAT
		or current_state == Phase2AIState.EVADE
		or current_state == Phase2AIState.FLANK
	):
		return current_state

	var offset := target.global_position - racer.global_position
	offset.y = 0.0
	var distance := offset.length()
	var role := _phase2_role(racer.animal_id)
	var own_power := WildDashRaceCombatProfile.get_attack_power(racer.animal_id)
	var target_power := WildDashRaceCombatProfile.get_attack_power(target.animal_id)

	if role == &"light":
		var threat := _phase2_nearest_heavy_threat(racer)
		if threat != null:
			var threat_distance := racer.global_position.distance_to(threat.global_position)
			if threat_distance <= PHASE2_AI_THREAT_SCAN_RADIUS:
				return Phase2AIState.RETREAT if threat_distance <= 3.25 else Phase2AIState.EVADE
		if distance <= _combat_core.get_attack_radius(&"tap") + PHASE2_AI_ATTACK_REACH_MARGIN:
			return Phase2AIState.ATTACK
		if distance <= 6.2:
			return Phase2AIState.FLANK
		return Phase2AIState.CHASE

	if role == &"heavy":
		if distance <= _combat_core.get_attack_radius(&"hold") + PHASE2_AI_ATTACK_REACH_MARGIN:
			return Phase2AIState.ATTACK
		return Phase2AIState.CHASE

	if target_power - own_power >= 2.4 and distance <= 2.7:
		return Phase2AIState.EVADE
	if distance <= _combat_core.get_attack_radius(&"tap") + PHASE2_AI_ATTACK_REACH_MARGIN:
		return Phase2AIState.ATTACK
	if role == &"duelist" and distance <= 6.0:
		return Phase2AIState.FLANK
	if role == &"mid" and ((ai_index + int(time_remaining)) % 4 == 0) and distance <= 5.5:
		return Phase2AIState.FLANK
	return Phase2AIState.CHASE

func _phase2_target_for(ai_index: int, racer: WildDashCharacterController) -> WildDashCharacterController:
	if racer == null:
		return null
	var racer_id := racer.get_instance_id()
	var locked_target: WildDashCharacterController = _phase2_ai_targets.get(racer_id, null) as WildDashCharacterController
	var lock_remaining := float(_phase2_ai_target_lock.get(racer_id, 0.0))
	if locked_target != null and is_instance_valid(locked_target) and locked_target != racer and _is_combatant_active(locked_target) and lock_remaining > 0.0:
		return locked_target

	# Keep 1–3 opponents consciously pressuring the human player. The designated
	# pressure slots rotate every few seconds so the player gets attacked without
	# the whole field dogpiling them for the entire round.
	if player != null and player != racer and _is_combatant_active(player):
		var player_chasers := _phase2_direct_chaser_count(player, racer_id)
		if player_chasers < PHASE2_AI_PLAYER_MAX_CHASERS and _phase2_is_player_pressure_slot(ai_index):
			_phase2_ai_targets[racer_id] = player
			_phase2_ai_target_lock[racer_id] = PHASE2_AI_TARGET_LOCK_SECONDS + float(ai_index % 3) * 0.12
			return player

	var role := _phase2_role(racer.animal_id)
	var best: WildDashCharacterController
	var best_score := INF
	for candidate in racers:
		if candidate == racer or not _is_combatant_active(candidate):
			continue
		var distance_sq := racer.global_position.distance_squared_to(candidate.global_position)
		var direct_chasers := _phase2_direct_chaser_count(candidate, racer_id)
		var crowd_penalty := float(direct_chasers) * 16.0
		if direct_chasers >= PHASE2_AI_MAX_DIRECT_CHASERS:
			crowd_penalty += 220.0

		var score := distance_sq + crowd_penalty
		var candidate_role := _phase2_role(candidate.animal_id)
		if candidate == player and direct_chasers < PHASE2_AI_PLAYER_MAX_CHASERS:
			score -= PHASE2_AI_PLAYER_PRESSURE_BONUS
		if role == &"heavy":
			if candidate_role == &"light":
				score -= PHASE2_AI_HEAVY_HUNT_BONUS
			elif candidate_role == &"heavy":
				score += 24.0
		elif role == &"light":
			if candidate_role == &"heavy":
				score += 120.0
			elif candidate_role == &"light":
				score -= 18.0
		elif role == &"duelist" and candidate_role == &"heavy":
			score += 12.0

		# Tiny deterministic bias prevents exact-score ties from flipping each tick.
		score += float((candidate.get_instance_id() + ai_index * 17) % 11) * 0.025
		if score < best_score:
			best_score = score
			best = candidate

	if best != null:
		_phase2_ai_targets[racer_id] = best
		var role_lock_scale := 0.82 if role == &"light" else (1.16 if role == &"heavy" else 1.0)
		_phase2_ai_target_lock[racer_id] = (PHASE2_AI_TARGET_LOCK_SECONDS + float(ai_index % 3) * 0.12) * role_lock_scale
	return best

func _phase2_is_player_pressure_slot(ai_index: int) -> bool:
	var pressure_phase := int(maxf(0.0, time_remaining) / 6.0) % 5
	return ai_index % 5 == pressure_phase

func _phase2_direct_chaser_count(target: WildDashCharacterController, excluding_racer_id: int) -> int:
	if target == null:
		return 0
	var count := 0
	for raw_source_id in _phase2_ai_targets.keys():
		var source_id := int(raw_source_id)
		if source_id == excluding_racer_id:
			continue
		var assigned: WildDashCharacterController = _phase2_ai_targets.get(source_id, null) as WildDashCharacterController
		if assigned == target and float(_phase2_ai_target_lock.get(source_id, 0.0)) > 0.0:
			count += 1
	return count

func _phase2_nearest_heavy_threat(racer: WildDashCharacterController) -> WildDashCharacterController:
	var best: WildDashCharacterController
	var best_distance := INF
	for candidate in racers:
		if candidate == racer or not _is_combatant_active(candidate):
			continue
		if _phase2_role(candidate.animal_id) != &"heavy":
			continue
		var distance := racer.global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

func _phase2_state_target_point(
	racer: WildDashCharacterController,
	target: WildDashCharacterController,
	state: int,
) -> Vector3:
	if state == Phase2AIState.EDGE_RECOVER:
		return Vector3.ZERO

	var focus := target
	if state == Phase2AIState.EVADE or state == Phase2AIState.RETREAT:
		var threat := _phase2_nearest_heavy_threat(racer)
		if threat != null:
			focus = threat

	var offset := focus.global_position - racer.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return _phase2_safe_move_point(racer.global_position + Vector3(2.0, 0.0, 0.0))
	var distance := offset.length()
	var direction := offset / distance
	var tangent := Vector3(-direction.z, 0.0, direction.x)
	var side := float(_phase2_ai_strafe_sign.get(racer.get_instance_id(), 1.0))
	var point := target.global_position

	match state:
		Phase2AIState.RETREAT:
			point = racer.global_position - direction * 6.4 + tangent * side * 1.6
		Phase2AIState.EVADE:
			point = racer.global_position - direction * 4.2 + tangent * side * 4.0
		Phase2AIState.FLANK:
			point = target.global_position - direction * 1.35 + tangent * side * 2.75
		Phase2AIState.ATTACK:
			point = target.global_position + direction * 0.55 + tangent * side * 0.35
		_:
			var role := _phase2_role(racer.animal_id)
			var stand_off := 1.35 if role == &"heavy" else PHASE2_AI_STANDOFF_DISTANCE
			var strafe := 0.35 if role == &"heavy" else PHASE2_AI_STRAFE_DISTANCE * 0.55
			point = target.global_position - direction * stand_off + tangent * side * strafe

	return _phase2_safe_move_point(point)

func _phase2_safe_move_point(point: Vector3) -> Vector3:
	var planar := Vector2(point.x, point.z)
	if planar.length() > PHASE2_AI_SAFE_MOVE_RADIUS:
		planar = planar.normalized() * PHASE2_AI_SAFE_MOVE_RADIUS
	return Vector3(planar.x, 0.20, planar.y)

func _phase2_attack_kind(
	ai_index: int,
	racer: WildDashCharacterController,
	target: WildDashCharacterController,
) -> StringName:
	var role := _phase2_role(racer.animal_id)
	var power := WildDashRaceCombatProfile.get_attack_power(racer.animal_id)
	var target_stagger := _combat_core.get_stagger(target)
	var phase_tick := int(Time.get_ticks_msec() / 760)
	if role == &"heavy" and power >= 8.5:
		return &"hold" if target_stagger >= 38.0 or ((phase_tick + ai_index) % 2 == 0) else &"tap"
	if role == &"mid" and power >= 7.0:
		return &"hold" if target_stagger >= 66.0 or ((phase_tick + ai_index) % 5 == 0) else &"tap"
	if role == &"duelist" and power >= 7.0:
		return &"hold" if target_stagger >= 72.0 or ((phase_tick + ai_index) % 6 == 0) else &"tap"
	if role == &"light" and power >= 6.5 and target_stagger >= 88.0:
		return &"hold"
	return &"tap"

func _phase2_after_successful_ai_hit(
	racer: WildDashCharacterController,
	target: WildDashCharacterController,
	attack_direction: Vector3,
	kind: StringName,
) -> void:
	var racer_id := racer.get_instance_id()
	var role := _phase2_role(racer.animal_id)
	if role == &"heavy":
		var commit_impulse := PHASE2_AI_HEAVY_COMMIT_IMPULSE if kind == &"hold" else PHASE2_AI_QUICK_COMMIT_IMPULSE
		racer.apply_knockback(attack_direction, commit_impulse)
		_set_phase2_ai_state(racer, Phase2AIState.CHASE, 0.24)
	elif role == &"light":
		# Hit-and-run identity: land a quick shot, recoil out, then re-enter from a side.
		racer.apply_knockback(-attack_direction, 1.05)
		_set_phase2_ai_state(racer, Phase2AIState.RETREAT, PHASE2_AI_RETREAT_SECONDS)
		_phase2_ai_strafe_sign[racer_id] = -float(_phase2_ai_strafe_sign.get(racer_id, 1.0))
	else:
		racer.apply_knockback(attack_direction, PHASE2_AI_QUICK_COMMIT_IMPULSE)
		_set_phase2_ai_state(racer, Phase2AIState.FLANK, PHASE2_AI_FLANK_SECONDS)
	_phase2_ai_target_lock[racer_id] = maxf(float(_phase2_ai_target_lock.get(racer_id, 0.0)), 0.58)
	_phase2_ai_close_contact[racer_id] = 0.0

func _phase2_role(animal_id: StringName) -> StringName:
	match animal_id:
		&"elephant", &"bear", &"boar":
			return &"heavy"
		&"rabbit", &"cat", &"fox", &"monkey", &"raccoon":
			return &"light"
		&"wolf", &"deer":
			return &"duelist"
		&"panda", &"dog":
			return &"mid"
		_:
			return &"mid"

func _phase2_default_state_hold(state: int) -> float:
	match state:
		Phase2AIState.RETREAT:
			return PHASE2_AI_RETREAT_SECONDS
		Phase2AIState.EVADE:
			return PHASE2_AI_EVADE_SECONDS
		Phase2AIState.FLANK:
			return PHASE2_AI_FLANK_SECONDS
		Phase2AIState.ATTACK:
			return 0.22
		Phase2AIState.EDGE_RECOVER:
			return 0.45
		_:
			return 0.0

func _set_phase2_ai_state(racer: WildDashCharacterController, state: int, hold_seconds: float) -> void:
	if racer == null:
		return
	var id := racer.get_instance_id()
	var current := int(_phase2_ai_state.get(id, Phase2AIState.CHASE))
	var current_timer := float(_phase2_ai_state_timer.get(id, 0.0))
	if current == state and current_timer > hold_seconds:
		return
	_phase2_ai_state[id] = state
	_phase2_ai_state_timer[id] = maxf(current_timer if current == state else 0.0, hold_seconds)

func _phase2_state_speed_scale(racer: WildDashCharacterController) -> float:
	if racer == null:
		return 1.0
	var role := _phase2_role(racer.animal_id)
	var state := int(_phase2_ai_state.get(racer.get_instance_id(), Phase2AIState.CHASE))
	if state == Phase2AIState.EDGE_RECOVER:
		return 1.18
	if role == &"heavy":
		return 1.00 if state == Phase2AIState.CHASE else 0.92
	if role == &"light":
		if state == Phase2AIState.EVADE or state == Phase2AIState.RETREAT:
			return 1.34
		if state == Phase2AIState.FLANK:
			return 1.20
		return 1.10
	if role == &"duelist":
		return 1.13 if state == Phase2AIState.FLANK or state == Phase2AIState.EVADE else 1.04
	return 1.05 if state == Phase2AIState.FLANK else 1.0

func _on_phase1_combat_action(action: Dictionary) -> void:
	_ensure_phase2_core()
	if not _phase2_initialized or mode_finished or not GameManager.round_active:
		return
	if not _is_combatant_active(player) or _combat_core.get_stun_remaining(player) > 0.0:
		return
	var kind: StringName = StringName(action.get("kind", &"tap"))
	if kind != &"hold":
		kind = &"tap"
	if not _combat_core.try_begin_attack(player, kind):
		return

	var directional := clampi(int(action.get("direction", 0)), -1, 1)
	var forward := -player.global_transform.basis.z.normalized()
	var right := player.global_transform.basis.x.normalized()
	var attack_forward := forward
	if directional != 0:
		attack_forward = (forward + right * float(directional) * 0.58).normalized()
	var radius := _combat_core.get_attack_radius(kind)
	var arc_dot := _combat_core.get_attack_arc_dot(kind)
	var hits := 0
	var breaks := 0
	var strongest_knockback := 0.0

	for target in racers:
		if target == player or not _is_combatant_active(target):
			continue
		if float(_spawn_protection.get(target.get_instance_id(), 0.0)) > 0.0:
			continue
		var offset := target.global_position - player.global_position
		offset.y = 0.0
		if offset.length_squared() <= 0.001 or offset.length() > radius:
			continue
		if attack_forward.dot(offset.normalized()) < arc_dot:
			continue
		var result := _combat_core.apply_hit(player, target, offset, kind, directional)
		if not bool(result.get("applied", false)):
			continue
		_record_phase2_hit_credit(player, target)
		hits += 1
		strongest_knockback = maxf(strongest_knockback, float(result.get("knockback", 0.0)))
		if bool(result.get("break", false)):
			breaks += 1

	var label := "HEAVY SMASH" if kind == &"hold" else "QUICK BASH"
	if directional < 0:
		label += " LEFT"
	elif directional > 0:
		label += " RIGHT"
	if hits > 0:
		hud.set_message("%s · %d HIT · KB %.1f%s" % [
			label,
			hits,
			strongest_knockback,
			" · BREAK!" if breaks > 0 else "",
		])
	else:
		hud.set_message("%s · MISS" % label)

func _record_phase2_hit_credit(source: WildDashCharacterController, target: WildDashCharacterController) -> void:
	if source == null or target == null:
		return
	var target_id := target.get_instance_id()
	_last_attacker[target_id] = source
	_last_hit_age[target_id] = 0.0

func _on_phase2_stagger_break(
	source: WildDashCharacterController,
	target: WildDashCharacterController,
	result: Dictionary,
) -> void:
	if source == null or target == null or source == target:
		return
	if not _is_combatant_active(source) or not _is_combatant_active(target):
		return
	var source_id := source.get_instance_id()
	_scores[source_id] = int(_scores.get(source_id, 0)) + BREAK_SCORE
	if source == player:
		hud.set_message("BREAK! +%d DOMINANCE · FINISHER WINDOW" % BREAK_SCORE)
	elif target == player:
		hud.set_message("BREAK! %.2fs STAGGER · 다음 타격에 강한 LAUNCH" % float(result.get("stun", 0.0)))
	print("WILD RUMBLE PHASE2 BREAK SCORE source=%s target=%s score=%d" % [
		source.get_display_name(), target.get_display_name(), _score_for(source),
	])

func _apply_break_control_locks() -> void:
	if not _phase2_initialized:
		return
	for racer in racers:
		if racer == null:
			continue
		var id := racer.get_instance_id()
		var base_speed := float(_base_arena_move_speeds.get(id, racer.arena_move_speed))
		if _is_combatant_active(racer):
			racer.arena_move_speed = 0.0 if _combat_core.get_stun_remaining(racer) > 0.0 else base_speed
		else:
			racer.arena_move_speed = base_speed
	for i in range(ai_racers.size()):
		if i >= ai_drivers.size():
			break
		var racer: WildDashCharacterController = ai_racers[i]
		var id := racer.get_instance_id()
		var base_target_speed := float(_base_ai_target_speeds.get(id, ai_drivers[i].target_speed))
		if _is_combatant_active(racer) and _combat_core.get_stun_remaining(racer) > 0.0:
			ai_drivers[i].target_speed = 0.0
		else:
			ai_drivers[i].target_speed = base_target_speed * _phase2_state_speed_scale(racer)

func _sync_respawn_resets() -> void:
	if not _phase2_initialized:
		return
	for racer in racers:
		if racer == null:
			continue
		var id := racer.get_instance_id()
		var active_now := _is_combatant_active(racer)
		var active_before := bool(_phase2_active_state.get(id, active_now))
		if active_now and not active_before:
			_combat_core.reset_racer(racer)
			_phase2_ai_targets.erase(id)
			_phase2_ai_target_lock[id] = 0.0
			_phase2_ai_state[id] = Phase2AIState.CHASE
			_phase2_ai_state_timer[id] = 0.0
			_phase2_ai_close_contact[id] = 0.0
		_phase2_active_state[id] = active_now

func _update_hud() -> void:
	_ensure_phase2_core()
	if player == null or hud == null or not _phase2_initialized:
		return
	var profile := _combat_core.get_profile(player)
	var stagger := _combat_core.get_stagger(player)
	var attack_cd := _combat_core.get_attack_cooldown_remaining(player)
	var stun := _combat_core.get_stun_remaining(player)
	hud.set_metrics("TIME %.0f   DOM %d   KOs %d   RANK %d/%d   STAGGER %.0f/100   PWR %.1f DEF %.1f%s" % [
		time_remaining,
		_score_for(player),
		_kos_for(player),
		_rank_for(player),
		racers.size(),
		stagger,
		float(profile.get("attack_power", 0.0)),
		float(profile.get("defense", 0.0)),
		"   BREAK %.1fs" % stun if stun > 0.0 else ("   ATK CD %.1f" % attack_cd if attack_cd > 0.05 else "   READY"),
	])

func _finish_score_battle() -> void:
	if mode_finished or player == null:
		return
	var player_score := _score_for(player)
	var best_score := player_score
	for racer in racers:
		best_score = maxi(best_score, _score_for(racer))
	var success := player_score >= best_score
	print("WILD RUMBLE PHASE2 COMPLETE player=%s score=%d kos=%d breaks=%d best=%d rank=%d" % [
		player.get_display_name(),
		player_score,
		_kos_for(player),
		_combat_core.get_break_count(player) if _combat_core != null else 0,
		best_score,
		_rank_for(player),
	])
	finish_mode(success, player_score, {
		"dominance": player_score,
		"kos": _kos_for(player),
		"rank": _rank_for(player),
		"stagger_breaks_received": _combat_core.get_break_count(player) if _combat_core != null else 0,
		"phase": 2,
		"score_mode": true,
		"power_defense_combat": true,
		"stagger_break": true,
	})
