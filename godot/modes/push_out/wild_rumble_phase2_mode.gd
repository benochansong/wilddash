extends "res://modes/push_out/wild_rumble_mode.gd"

## WILD RUMBLE Phase 2
## Replaces Phase 1 fixed shove values with the shared Power/Defense profile,
## Stagger/Break, finisher launch bonus and stat-derived Heavy character meta.

const ARENA_COMBAT_CORE_SCRIPT: Script = preload("res://modes/push_out/arena_combat_core.gd")
const BREAK_SCORE := 2
const PHASE2_AI_DECISION_INTERVAL := 0.20

# Arena engagement tuning. The old nearest-target-every-tick behavior made AI
# pairs repeatedly swap targets at contact distance, producing the visible
# "shivering in place" failure. Targets now stay locked briefly, approach an
# attack ring instead of the opponent's exact center, and strafe/drive through
# close engagements so bodies keep moving while attacks resolve.
const PHASE2_AI_TARGET_LOCK_SECONDS := 1.35
const PHASE2_AI_EDGE_RECOVERY_RADIUS := 16.25
const PHASE2_AI_STANDOFF_DISTANCE := 2.15
const PHASE2_AI_STRAFE_DISTANCE := 1.15
const PHASE2_AI_CLOSE_DISTANCE := 1.45
const PHASE2_AI_ATTACK_REACH_MARGIN := 0.38
const PHASE2_AI_QUICK_COMMIT_IMPULSE := 1.35
const PHASE2_AI_HEAVY_COMMIT_IMPULSE := 2.15
const PHASE2_AI_MAX_DIRECT_CHASERS := 3

var _combat_core: WildDashArenaCombatCore
var _phase2_initialized := false
var _base_arena_move_speeds: Dictionary = {}
var _base_ai_target_speeds: Dictionary = {}
var _phase2_active_state: Dictionary = {}
var _phase2_ai_targets: Dictionary = {}
var _phase2_ai_target_lock: Dictionary = {}
var _phase2_ai_strafe_sign: Dictionary = {}

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
	if hud != null:
		hud.configure(
			"ROUND 4 — WILD RUMBLE: TITAN CLASH",
			"PHASE 2 · F/Y QUICK BASH · HOLD F/Y HEAVY SMASH · STAGGER → BREAK"
		)
	_phase2_initialized = true
	var player_profile := _combat_core.get_profile(player)
	print("WILD RUMBLE PHASE2 READY power_defense=true stagger=true break=true finisher=true player=%s power=%.1f defense=%.1f stability=%.1f" % [
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
	_apply_break_control_locks()
	_tick_phase2_ai_target_locks(delta)

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

			# Edge recovery always wins. This keeps combatants on the octagon long
			# enough to re-engage instead of vibrating against the ring-out lip.
			var planar_radius := Vector2(racer.global_position.x, racer.global_position.z).length()
			if planar_radius >= PHASE2_AI_EDGE_RECOVERY_RADIUS:
				ai_drivers[i].set_arena_target(Vector3.ZERO)
				continue

			var target := _phase2_target_for(i, racer)
			if target != null:
				ai_drivers[i].set_arena_target(_phase2_engagement_point(racer, target))
			else:
				ai_drivers[i].set_arena_target(Vector3.ZERO)

	for i in range(ai_racers.size()):
		if i >= ai_drivers.size():
			break
		var racer: WildDashCharacterController = ai_racers[i]
		if not _is_combatant_active(racer) or _combat_core.get_stun_remaining(racer) > 0.0:
			continue
		if not _combat_core.can_attack(racer):
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
		var power := WildDashRaceCombatProfile.get_attack_power(racer.animal_id)
		var target_stagger := _combat_core.get_stagger(target)
		var phase_tick := int(Time.get_ticks_msec() / 900)
		var heavy_window := power >= 8.5 and (target_stagger >= 48.0 or ((phase_tick + i) % 3 == 0))
		var kind: StringName = &"hold" if heavy_window else &"tap"
		if offset.length() > _combat_core.get_attack_radius(kind) + PHASE2_AI_ATTACK_REACH_MARGIN:
			continue

		# Face the opponent before the strike so the animation/readability matches
		# the actual hit direction even though arena movement itself is world-space.
		var attack_direction := offset.normalized()
		var target_yaw := atan2(-attack_direction.x, -attack_direction.z)
		racer.rotation.y = lerp_angle(racer.rotation.y, target_yaw, 0.62)
		if not _combat_core.try_begin_attack(racer, kind):
			continue
		var result := _combat_core.apply_hit(racer, target, offset, kind, 0)
		if bool(result.get("applied", false)):
			_record_phase2_hit_credit(racer, target)
			# A short forward commit keeps combat visually aggressive and prevents
			# both bodies from immediately settling into a collision deadlock.
			var commit_impulse := PHASE2_AI_HEAVY_COMMIT_IMPULSE if kind == &"hold" else PHASE2_AI_QUICK_COMMIT_IMPULSE
			racer.apply_knockback(attack_direction, commit_impulse)
			_phase2_ai_target_lock[racer.get_instance_id()] = maxf(
				float(_phase2_ai_target_lock.get(racer.get_instance_id(), 0.0)),
				0.55
			)
			if target == player:
				hud.set_message("%s HIT · STAGGER %.0f/100" % [
					"HEAVY SMASH" if kind == &"hold" else "QUICK BASH",
					_combat_core.get_stagger(player),
				])

func _tick_phase2_ai_target_locks(delta: float) -> void:
	for raw_id in _phase2_ai_target_lock.keys():
		var id := int(raw_id)
		_phase2_ai_target_lock[id] = maxf(0.0, float(_phase2_ai_target_lock.get(id, 0.0)) - delta)

func _phase2_target_for(ai_index: int, racer: WildDashCharacterController) -> WildDashCharacterController:
	if racer == null:
		return null
	var racer_id := racer.get_instance_id()
	var locked_target: WildDashCharacterController = _phase2_ai_targets.get(racer_id, null) as WildDashCharacterController
	var lock_remaining := float(_phase2_ai_target_lock.get(racer_id, 0.0))
	if locked_target != null and is_instance_valid(locked_target) and locked_target != racer and _is_combatant_active(locked_target) and lock_remaining > 0.0:
		return locked_target

	var best: WildDashCharacterController
	var best_score := INF
	for candidate in racers:
		if candidate == racer or not _is_combatant_active(candidate):
			continue
		var distance_sq := racer.global_position.distance_squared_to(candidate.global_position)
		var direct_chasers := _phase2_direct_chaser_count(candidate, racer_id)
		# Keep the fight distributed. Three attackers can dogpile one carrier/player,
		# but additional AI strongly prefer another nearby opponent.
		var crowd_penalty := float(direct_chasers) * 14.0
		if direct_chasers >= PHASE2_AI_MAX_DIRECT_CHASERS:
			crowd_penalty += 180.0
		# Tiny deterministic bias prevents exact-score ties from flipping every tick.
		var tie_bias := float((candidate.get_instance_id() + ai_index * 17) % 11) * 0.025
		var score := distance_sq + crowd_penalty + tie_bias
		if score < best_score:
			best_score = score
			best = candidate

	if best != null:
		_phase2_ai_targets[racer_id] = best
		_phase2_ai_target_lock[racer_id] = PHASE2_AI_TARGET_LOCK_SECONDS + float(ai_index % 3) * 0.12
	return best

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

func _phase2_engagement_point(
	racer: WildDashCharacterController,
	target: WildDashCharacterController,
) -> Vector3:
	var offset := target.global_position - racer.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		return target.global_position
	var distance := offset.length()
	var direction := offset / distance
	var tangent := Vector3(-direction.z, 0.0, direction.x)
	var side := float(_phase2_ai_strafe_sign.get(racer.get_instance_id(), 1.0))

	if distance > 4.4:
		# Long approach: aim for the near side of the opponent, not its collider center.
		return target.global_position - direction * PHASE2_AI_STANDOFF_DISTANCE + tangent * side * 0.55
	if distance > PHASE2_AI_CLOSE_DISTANCE:
		# Fighting range: circle slightly while continuing to close. This produces
		# visible lateral motion and gives repeated hits room to create knockback.
		return target.global_position - direction * 0.95 + tangent * side * PHASE2_AI_STRAFE_DISTANCE

	# Too close / body-blocked: drive through and off-axis instead of reversing
	# target direction every decision tick. This is the key anti-shiver behavior.
	return target.global_position + direction * 0.85 + tangent * side * (PHASE2_AI_STRAFE_DISTANCE + 0.45)

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
			ai_drivers[i].target_speed = base_target_speed

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