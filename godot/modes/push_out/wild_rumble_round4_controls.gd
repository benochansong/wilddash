extends "res://modes/push_out/wild_rumble_round4_mode.gd"

## Round 4 control-safety + player-pressure + combat-input wrapper.
## Arena movement is world-space: left/right map to X and forward/back map to Z.
## The Titan Crown camera follows player position but keeps one fixed heading, so
## screen directions never rotate underneath the keyboard controls.
##
## F / Gamepad Y is intentionally immediate in Round 4: press = Quick Bash now,
## keep holding = Heavy Smash charge follow-up. Agile racers additionally gain
## real flank/back-attack routes and selected jump specialists can land a stomp.

const ROUND4_CAMERA_WORLD_BACK := Vector3(0.0, 0.0, 1.0)
const ROUND4_PLAYER_HUNTER_ROTATE_SECONDS := 6.0
const ROUND4_PLAYER_HUNTER_LOCK_SECONDS := 1.35
const ROUND4_PLAYER_HUNTER_SPEED_SCALE := 1.10
const ROUND4_STOMP_RADIUS := 2.05
const ROUND4_STOMP_MIN_HEIGHT := 0.34
const ROUND4_STOMP_MAX_HEIGHT := 2.45
const ROUND4_STOMP_MIN_FALL_SPEED := -0.35

var _round4_attack_was_down := false

func _physics_process(delta: float) -> void:
	super(delta)
	if mode_finished or not GameManager.round_active:
		_round4_attack_was_down = false
		return
	_update_round4_direct_attack_input()
	_update_round4_player_stomp()

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

	print("WILD RUMBLE ROUND4 CONTROLS READY camera_heading_locked=true physical_keys_fail_safe=true F_immediate=true hold_heavy=true back_attack=true stomp=true player_hunters=1-2")

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

	# Main brawl: two hunters. Final Three / Duel: one dedicated hunter, leaving
	# the other survivor free to contest Crown/objectives and create crossfire.
	var desired_hunters := 2 if _round4_alive_count() > 3 and active_indices.size() >= 2 else 1
	var rotate_bucket := int(Time.get_ticks_msec() / int(ROUND4_PLAYER_HUNTER_ROTATE_SECONDS * 1000.0))
	var start := rotate_bucket % active_indices.size()
	for hunter_slot in range(desired_hunters):
		var selected := active_indices[(start + hunter_slot) % active_indices.size()]
		if selected == ai_index:
			return true
	return false
