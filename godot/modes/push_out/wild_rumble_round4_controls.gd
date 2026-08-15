extends "res://modes/push_out/wild_rumble_round4_mode.gd"

## Round 4 control-safety + player-pressure wrapper.
## Arena movement is world-space: left/right map to X and forward/back map to Z.
## The Titan Crown camera follows player position but keeps one fixed heading, so
## screen directions never rotate underneath the keyboard controls.
##
## Player pressure is also guaranteed here: while the player is alive, two active
## AI fighters are designated as rotating hunters during the main brawl, and one
## remains committed in FINAL THREE / FINAL DUEL situations. This prevents the
## player from surviving simply by avoiding the AI-vs-AI fights.

const ROUND4_CAMERA_WORLD_BACK := Vector3(0.0, 0.0, 1.0)
const ROUND4_PLAYER_HUNTER_ROTATE_SECONDS := 6.0
const ROUND4_PLAYER_HUNTER_LOCK_SECONDS := 1.35
const ROUND4_PLAYER_HUNTER_SPEED_SCALE := 1.10

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

	print("WILD RUMBLE ROUND4 CONTROLS READY camera_heading_locked=true physical_keys_fail_safe=true player_hunters=1-2")

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
		if role == &"light" and distance <= 5.4:
			return Phase2AIState.FLANK
		return Phase2AIState.CHASE
	return super(ai_index, racer, target)

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
