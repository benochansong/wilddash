extends "res://modes/push_out/wild_rumble_round4_mode.gd"

## Round 4 control-safety + player-pressure + combat-input wrapper.
## Arena movement is world-space: left/right map to X and forward/back map to Z.
## The Titan Crown camera follows player position but keeps one fixed heading, so
## screen directions never rotate underneath the keyboard controls.
##
## F / Gamepad Y is intentionally immediate in Round 4: press = Quick Bash now,
## keep holding = Heavy Smash charge follow-up. Agile racers additionally gain
## real flank/back-attack routes and selected jump specialists can land a stomp.
##
## Balance goal: keep the strong, satisfying launch distance, but remove unfair
## early-round dogpiles. One hunter is always active, a second hunter joins only
## in short pressure windows unless the player is carrying a Relic/Crown, and the
## human gets modest incoming-KB/combo protection without any outgoing nerf.

const ROUND4_CAMERA_WORLD_BACK := Vector3(0.0, 0.0, 1.0)
const ROUND4_PLAYER_HUNTER_ROTATE_SECONDS := 6.0
const ROUND4_PLAYER_HUNTER_LOCK_SECONDS := 1.25
const ROUND4_PLAYER_HUNTER_SPEED_SCALE := 1.06
const ROUND4_SECOND_HUNTER_CYCLE_SECONDS := 9.0
const ROUND4_SECOND_HUNTER_ACTIVE_SECONDS := 1.8

const ROUND4_PLAYER_INCOMING_KB_SCALE := 0.88
const ROUND4_PLAYER_STAGGER_RECOVERY_SCALE := 1.22
const ROUND4_PLAYER_COMBO_GUARD_SECONDS := 0.42
const ROUND4_PLAYER_COMBO_KB_SCALE := 0.58
const ROUND4_PLAYER_COMBO_STAGGER_SCALE := 0.82

const ROUND4_EARLY_SHRINK_SPEED := 0.32
const ROUND4_MID_SHRINK_SPEED := 0.52
const ROUND4_LATE_SHRINK_SPEED := 1.15
const ROUND4_DUEL_SHRINK_SPEED := 1.35
const ROUND4_SUDDEN_SHRINK_SPEED := 1.65

const ROUND4_AGILE_FLOW_SPEED_SCALE := 1.15
const ROUND4_AGILE_FLOW_SECONDS := 0.55
const ROUND4_STOMP_RADIUS := 2.05
const ROUND4_STOMP_MIN_HEIGHT := 0.34
const ROUND4_STOMP_MAX_HEIGHT := 2.45
const ROUND4_STOMP_MIN_FALL_SPEED := -0.35

var _round4_attack_was_down := false
var _round4_player_balance_ready := false
var _round4_player_combo_guard_remaining := 0.0
var _round4_current_player_hit_is_combo := false
var _round4_agile_flow_remaining := 0.0

func _physics_process(delta: float) -> void:
	super(delta)
	_round4_player_combo_guard_remaining = maxf(0.0, _round4_player_combo_guard_remaining - delta)
	_round4_agile_flow_remaining = maxf(0.0, _round4_agile_flow_remaining - delta)
	_ensure_round4_player_balance()
	if mode_finished or not GameManager.round_active:
		_round4_attack_was_down = false
		return
	_update_round4_direct_attack_input()
	_update_round4_player_stomp()

func _ensure_round4_player_balance() -> void:
	if _round4_player_balance_ready or player == null or _combat_core == null:
		return
	if not is_instance_valid(player):
		return
	_combat_core.configure_survival_assist(
		player,
		ROUND4_PLAYER_INCOMING_KB_SCALE,
		ROUND4_PLAYER_STAGGER_RECOVERY_SCALE,
		ROUND4_PLAYER_COMBO_GUARD_SECONDS,
		ROUND4_PLAYER_COMBO_KB_SCALE,
		ROUND4_PLAYER_COMBO_STAGGER_SCALE
	)
	_round4_player_balance_ready = true
	print("WILD RUMBLE PLAYER BALANCE READY incoming_kb=%.2f combo_guard=%.2fs recovery=%.2f hunter_base=1 hunter_burst=2" % [
		ROUND4_PLAYER_INCOMING_KB_SCALE,
		ROUND4_PLAYER_COMBO_GUARD_SECONDS,
		ROUND4_PLAYER_STAGGER_RECOVERY_SCALE,
	])

func _update_round4_direct_attack_input() -> void:
	if player == null or not is_instance_valid(player) or not _is_combatant_active(player):
		_round4_attack_was_down = false
		return
	var attack_down := InputManager.is_race_combat_pressed()
	if attack_down and not _round4_attack_was_down:
		# The legacy gesture signal resolves a tap on release. For an arena brawler
		# that feels broken, so R4 fires the Quick Bash on the physical press edge.
		# The later release event is harmless because ArenaCombatCore cooldown blocks
		# the duplicate. Holding long enough is allowed to chain into Heavy Smash.
		var directional := InputManager.classify_race_combat_direction(InputManager.get_steer_axis())
		_on_phase1_combat_action({
			"kind": &"tap",
			"direction": directional,
			"held_seconds": 0.0,
			"source": &"round4_immediate_press",
		})
	_round4_attack_was_down = attack_down

func _update_round4_player_stomp() -> void:
	if player == null or _combat_core == null or not is_instance_valid(player):
		return
	if not _round4_can_stomp(player) or player.is_on_floor() or player.velocity.y > ROUND4_STOMP_MIN_FALL_SPEED:
		return
	if not _combat_core.can_attack(player):
		return

	var best: WildDashCharacterController
	var best_distance := INF
	for target in racers:
		if target == player or not _is_combatant_active(target):
			continue
		if float(_spawn_protection.get(target.get_instance_id(), 0.0)) > 0.0:
			continue
		var height_delta := player.global_position.y - target.global_position.y
		if height_delta < ROUND4_STOMP_MIN_HEIGHT or height_delta > ROUND4_STOMP_MAX_HEIGHT:
			continue
		var planar := Vector2(
			target.global_position.x - player.global_position.x,
			target.global_position.z - player.global_position.z
		)
		if planar.length() > ROUND4_STOMP_RADIUS:
			continue
		if planar.length_squared() < best_distance:
			best_distance = planar.length_squared()
			best = target
	if best == null or not _combat_core.try_begin_attack(player, &"stomp"):
		return

	var offset := best.global_position - player.global_position
	offset.y = 0.0
	if offset.length_squared() <= 0.001:
		offset = -player.global_transform.basis.z
	var result := _combat_core.apply_hit(player, best, offset, &"stomp", 0)
	if not bool(result.get("applied", false)):
		return
	_record_phase2_hit_credit(player, best)
	player.velocity.y = maxf(player.velocity.y, player.jump_velocity * 0.42)
	_round4_camera_shake_remaining = maxf(_round4_camera_shake_remaining, 0.10)
	if hud != null:
		hud.set_message("AERIAL STOMP! · STAGGER %.0f/100 · KB %.1f" % [
			_combat_core.get_stagger(best),
			float(result.get("knockback", 0.0)),
		])

func _round4_can_stomp(racer: WildDashCharacterController) -> bool:
	if racer == null:
		return false
	match racer.animal_id:
		&"rabbit", &"monkey", &"cat", &"deer", &"fox", &"raccoon":
			return true
		_:
			return false

func _create_round4_dynamic_camera() -> void:
	var old_camera := get_node_or_null("WildRumblePhase1Camera") as Camera3D
	if old_camera != null:
		old_camera.current = false

	_round4_dynamic_camera = Camera3D.new()
	_round4_dynamic_camera.name = "TitanCrownFollowCamera"
	_round4_dynamic_camera.fov = 62.0
	_round4_dynamic_camera.current = true
	add_child(_round4_dynamic_camera)

	if player != null:
		_round4_dynamic_camera.global_position = (
			player.global_position
			+ ROUND4_CAMERA_WORLD_BACK * CAMERA_DISTANCE
			+ Vector3.UP * CAMERA_HEIGHT
		)
		_round4_dynamic_camera.look_at(player.global_position + Vector3.UP * 1.1, Vector3.UP)

	print("WILD RUMBLE ROUND4 CONTROLS READY camera_heading_locked=true physical_keys_fail_safe=true F_immediate=true hold_heavy=true back_attack=true stomp=true player_hunters=1-plus-burst")

func _update_round4_dynamic_camera(delta: float) -> void:
	if _round4_dynamic_camera == null or player == null or not is_instance_valid(player):
		return

	var desired_position := (
		player.global_position
		+ ROUND4_CAMERA_WORLD_BACK * CAMERA_DISTANCE
		+ Vector3.UP * CAMERA_HEIGHT
	)
	var smoothing := clampf(CAMERA_SMOOTHING * delta, 0.0, 1.0)
	_round4_dynamic_camera.global_position = _round4_dynamic_camera.global_position.lerp(desired_position, smoothing)

	if _round4_camera_shake_remaining > 0.0:
		_round4_camera_shake_remaining = maxf(0.0, _round4_camera_shake_remaining - delta)
		_round4_camera_shake_phase += delta * 52.0
		var shake := Vector3(
			sin(_round4_camera_shake_phase),
			cos(_round4_camera_shake_phase * 1.31),
			0.0
		) * 0.16
		_round4_dynamic_camera.global_position += shake * clampf(
			_round4_camera_shake_remaining / 0.18,
			0.0,
			1.0
		)

	# Objective look-at is intentionally disabled. Relics/Crown remain visible in
	# HUD/world indicators without changing the player's screen-space directions.
	_round4_dynamic_camera.look_at(player.global_position + Vector3.UP * 1.1, Vector3.UP)

func _update_round4_phase(delta: float) -> void:
	var alive := _round4_alive_count()
	var target_radius := ROUND4_RING_OPEN
	var shrink_speed := ROUND4_EARLY_SHRINK_SPEED
	if alive <= 2:
		target_radius = ROUND4_RING_DUEL
		shrink_speed = ROUND4_DUEL_SHRINK_SPEED
	elif alive <= 5:
		target_radius = ROUND4_RING_LATE
		shrink_speed = ROUND4_LATE_SHRINK_SPEED
	elif alive <= 9:
		target_radius = ROUND4_RING_MID
		shrink_speed = ROUND4_MID_SHRINK_SPEED
	if time_remaining <= 0.0:
		target_radius = minf(target_radius, ROUND4_RING_SUDDEN_DEATH)
		shrink_speed = ROUND4_SUDDEN_SHRINK_SPEED
	_round4_current_ring_radius = move_toward(_round4_current_ring_radius, target_radius, shrink_speed * delta)
	if _round4_safe_ring != null:
		_round4_safe_ring.inner_radius = maxf(2.0, _round4_current_ring_radius - 0.28)
		_round4_safe_ring.outer_radius = _round4_current_ring_radius + 0.04

	if alive <= 10 and not _round4_arena_awake_announced:
		_round4_arena_awake_announced = true
		_round4_shockwave_remaining = 1.6
		if hud != null:
			hud.set_message("TITAN ARENA AWAKENS! · WALLS BREAK · SHOCKWAVES ACTIVE")
		print("WILD RUMBLE TITAN ARENA AWAKENS alive=%d" % alive)

	if _round4_arena_awake_announced and alive > 3:
		_round4_shockwave_remaining -= delta
		if _round4_shockwave_remaining <= 0.0:
			_round4_shockwave_remaining = TITAN_SHOCKWAVE_INTERVAL
			_emit_titan_shockwave()

	if alive <= 3 and not _round4_final_three_announced:
		_round4_final_three_announced = true
		_deactivate_titan_relics()
		_spawn_titan_crown()
		if hud != null:
			hud.set_message("FINAL THREE · TITAN CROWN AWAKENS!")
		print("WILD RUMBLE FINAL THREE crown=true")

	if alive <= 2 and not _round4_final_duel_announced:
		_round4_final_duel_announced = true
		if hud != null:
			hud.set_message("FINAL DUEL · LAST ANIMAL WINS!")
		print("WILD RUMBLE FINAL DUEL radius=%.1f" % ROUND4_RING_DUEL)

func _emit_titan_shockwave() -> void:
	_spawn_impact_ring(Vector3.ZERO, 2.4, Color(1.0, 0.48, 0.10))
	for racer in racers:
		if not _is_combatant_active(racer):
			continue
		var planar := racer.global_position
		planar.y = 0.0
		var distance := planar.length()
		if distance <= 0.2 or distance > TITAN_SHOCKWAVE_RADIUS:
			continue
		var strength := TITAN_SHOCKWAVE_STRENGTH * lerpf(1.0, 0.38, distance / TITAN_SHOCKWAVE_RADIUS)
		if racer == player:
			strength *= ROUND4_PLAYER_INCOMING_KB_SCALE
		racer.apply_knockback(planar.normalized(), strength)
	if hud != null:
		hud.set_message("TITAN SHOCKWAVE! · MOVE OR GET LAUNCHED")
	_round4_camera_shake_remaining = maxf(_round4_camera_shake_remaining, 0.16)

func _phase2_target_for(ai_index: int, racer: WildDashCharacterController) -> WildDashCharacterController:
	if racer == null:
		return null
	if _round4_is_designated_player_hunter(ai_index, racer):
		var racer_id := racer.get_instance_id()
		_phase2_ai_targets[racer_id] = player
		_phase2_ai_target_lock[racer_id] = maxf(
			float(_phase2_ai_target_lock.get(racer_id, 0.0)),
			ROUND4_PLAYER_HUNTER_LOCK_SECONDS
		)
		return player
	return super(ai_index, racer)

func _phase2_choose_state(
	ai_index: int,
	racer: WildDashCharacterController,
	target: WildDashCharacterController,
) -> int:
	if racer != null and target == player and _round4_is_designated_player_hunter(ai_index, racer):
		var offset := player.global_position - racer.global_position
		offset.y = 0.0
		var distance := offset.length()
		if _combat_core != null and distance <= _combat_core.get_attack_radius(&"tap") + PHASE2_AI_ATTACK_REACH_MARGIN:
			return Phase2AIState.ATTACK
		var role := _phase2_role(racer.animal_id)
		if role == &"light" and distance <= 6.3:
			return Phase2AIState.FLANK
		return Phase2AIState.CHASE
	return super(ai_index, racer, target)

func _phase2_attack_kind(
	ai_index: int,
	racer: WildDashCharacterController,
	target: WildDashCharacterController,
) -> StringName:
	var kind := super(ai_index, racer, target)
	if target != player or kind != &"hold" or _round4_player_is_hot_objective():
		return kind
	# Keep Heavy Smash dangerous, but do not spam high-launch attacks at a player
	# who is still at low/mid stagger. High stagger remains a real finishing threat.
	var player_stagger := _combat_core.get_stagger(player) if _combat_core != null else 0.0
	var heavy_gate := (int(Time.get_ticks_msec() / 900) + ai_index) % 3
	if player_stagger < 65.0 and heavy_gate != 0:
		return &"tap"
	return kind

func _phase2_state_target_point(
	racer: WildDashCharacterController,
	target: WildDashCharacterController,
	state: int,
) -> Vector3:
	if racer != null and target != null and state == Phase2AIState.FLANK:
		var role := _phase2_role(racer.animal_id)
		if role == &"light" or role == &"duelist":
			# A true flank means getting behind the opponent, not merely strafing
			# around the attacker's current line. This position intentionally aims
			# agile AI at the target's rear arc so BACK ATTACK can actually happen.
			var target_back := target.global_transform.basis.z.normalized()
			var target_side := target.global_transform.basis.x.normalized()
			var side_sign := float(_phase2_ai_strafe_sign.get(racer.get_instance_id(), 1.0))
			return _phase2_safe_move_point(
				target.global_position + target_back * 1.65 + target_side * side_sign * 0.95
			)
	return super(racer, target, state)

func _phase2_state_speed_scale(racer: WildDashCharacterController) -> float:
	var base_scale := super(racer)
	if racer == null:
		return base_scale
	var ai_index := ai_racers.find(racer)
	if ai_index >= 0 and _round4_is_designated_player_hunter(ai_index, racer):
		return base_scale * ROUND4_PLAYER_HUNTER_SPEED_SCALE
	return base_scale

func _round4_objective_speed_multiplier(racer: WildDashCharacterController) -> float:
	var multiplier := super(racer)
	if racer == player and _round4_agile_flow_remaining > 0.0:
		multiplier *= ROUND4_AGILE_FLOW_SPEED_SCALE
	return multiplier

func _round4_is_designated_player_hunter(ai_index: int, racer: WildDashCharacterController) -> bool:
	if player == null or racer == null or racer == player:
		return false
	if not is_instance_valid(player) or not _is_combatant_active(player) or not _is_combatant_active(racer):
		return false

	var active_indices: Array[int] = []
	for i in range(ai_racers.size()):
		var candidate := ai_racers[i]
		if candidate != null and is_instance_valid(candidate) and _is_combatant_active(candidate):
			active_indices.append(i)
	if active_indices.is_empty():
		return false

	var desired_hunters := 1
	if active_indices.size() >= 2:
		if _round4_player_is_hot_objective():
			desired_hunters = 2
		elif _round4_alive_count() > 3:
			var cycle_time := fmod(float(Time.get_ticks_msec()) * 0.001, ROUND4_SECOND_HUNTER_CYCLE_SECONDS)
			if cycle_time < ROUND4_SECOND_HUNTER_ACTIVE_SECONDS:
				desired_hunters = 2

	var rotate_bucket := int(Time.get_ticks_msec() / int(ROUND4_PLAYER_HUNTER_ROTATE_SECONDS * 1000.0))
	var start := rotate_bucket % active_indices.size()
	for hunter_slot in range(desired_hunters):
		var selected := active_indices[(start + hunter_slot) % active_indices.size()]
		if selected == ai_index:
			return true
	return false

func _round4_player_is_hot_objective() -> bool:
	if player == null or not is_instance_valid(player):
		return false
	return _racer_has_relic(player) or _racer_has_crown(player)

func _record_phase2_hit_credit(source: WildDashCharacterController, target: WildDashCharacterController) -> void:
	if source == null or target == null:
		return
	var combo_for_player := target == player and _round4_current_player_hit_is_combo
	if target == player:
		_round4_current_player_hit_is_combo = false
	var target_id := target.get_instance_id()
	_last_attacker[target_id] = source
	_last_hit_age[target_id] = 0.0
	var direction := target.global_position - source.global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	var source_power := WildDashRaceCombatProfile.get_attack_power(source.animal_id)
	var target_defense := WildDashRaceCombatProfile.get_defense(target.animal_id)
	var source_role := _phase2_role(source.animal_id)
	var target_role := _phase2_role(target.animal_id)
	var bonus := maxf(0.0, source_power - target_defense) * 0.70
	if source_role == &"heavy":
		bonus += 2.90
	elif source_role == &"mid":
		bonus += 0.95
	elif source_role == &"duelist":
		bonus += 0.62
	if target_role == &"light":
		bonus += 1.30
	if _relic_kind_for(source) == &"power":
		bonus += POWER_RELIC_BONUS_KNOCKBACK
	if _racer_has_crown(source):
		bonus += CROWN_KNOCKBACK_BONUS
	if _relic_kind_for(target) == &"guardian":
		bonus *= 0.56
	var target_radius := Vector2(target.global_position.x, target.global_position.z).length()
	var edge_start := minf(ROUND4_EDGE_PRESSURE_RADIUS, _round4_current_ring_radius - 2.8)
	if target_radius >= edge_start:
		bonus += lerpf(1.0, 3.8, clampf((target_radius - edge_start) / 4.5, 0.0, 1.0))
	if target == player:
		bonus *= ROUND4_PLAYER_INCOMING_KB_SCALE
		if combo_for_player:
			bonus *= ROUND4_PLAYER_COMBO_KB_SCALE
	if bonus > 0.10:
		target.apply_knockback(direction.normalized(), bonus)

func _on_round4_hit_resolved(
	source: WildDashCharacterController,
	target: WildDashCharacterController,
	result: Dictionary,
) -> void:
	if target == player and bool(result.get("applied", false)):
		_round4_current_player_hit_is_combo = _round4_player_combo_guard_remaining > 0.0
		_round4_player_combo_guard_remaining = ROUND4_PLAYER_COMBO_GUARD_SECONDS
	super(source, target, result)
	if source != player or not bool(result.get("applied", false)):
		return
	var agility := WildDashAnimalAbilityProfile.get_stat(player.animal_id, &"agility")
	if agility < 8.0:
		return
	if bool(result.get("back_attack", false)) or bool(result.get("stomp", false)):
		_round4_agile_flow_remaining = maxf(_round4_agile_flow_remaining, ROUND4_AGILE_FLOW_SECONDS)
