extends "res://modes/logspire_leap/logspire_jump_rebalance.gd"

## Phase B player forgiveness.
## Landing magnet and ledge catch are bounded assists, never teleports. Both now
## query the CharacterBody motion before moving, and moving-platform targets use
## the PlatformGameplay predicted landing position instead of stale world data.
## WATER/RECOVERY/SAFE_EXIT own the player transform before base assists run.

const LEDGE_CATCH_WINDOW_SECONDS: float = 0.42
const LEDGE_CATCH_EXTRA_RANGE: float = 0.85
const LEDGE_CATCH_MAX_BELOW_TOP: float = 1.45
const LEDGE_CATCH_MAX_ABOVE_TOP: float = 0.35
const LEDGE_CATCH_INWARD_SPEED: float = 2.6
const LEDGE_CATCH_UP_SPEED: float = 3.4
const LEDGE_CATCH_MIN_DESCENT: float = 0.15
const MOVING_LANDING_PREDICT_MAX_SECONDS: float = 0.45

var _ledge_catch_remaining: float = 0.0
var _ledge_catch_target_id: StringName = &""
var _ledge_catch_logged: bool = false
var _water_recovery: Node

func _ready() -> void:
	super()
	_water_recovery = get_parent().get_node_or_null("WaterRecovery")
	print("LOGSPIRE PHASE B PLAYER ASSIST READY landing_assist=%.2fm ledge_catch=%.2fs extra_range=%.2fm teleport=false physics_query=true moving_prediction=true authority_guard=true" % [
		LANDING_ASSIST_MAX_METERS, LEDGE_CATCH_WINDOW_SECONDS, LEDGE_CATCH_EXTRA_RANGE,
	])

func _physics_process(delta: float) -> void:
	if not RaceManager.active:
		return
	var player := _resolve_player()
	if player == null or player.finished:
		_cancel_ledge_catch()
		return

	# SAFE_EXIT is deliberately one protected frame after a recovery transform.
	# This prevents landing magnet or ledge catch from becoming a second transform
	# writer before normal/airborne movement authority is restored.
	if not _authority_allows_jump_assist(player):
		_cancel_ledge_catch()
		_coyote_remaining = 0.0
		_jump_buffer_remaining = 0.0
		_landing_correction_used = 0.0
		_landing_assist_logged = false
		_player_was_on_floor = false
		return

	# Do this before super(delta): should_handle_racer catches a newly submerged
	# racer even before WaterRecovery's node gets its own physics callback.
	if _is_player_water_recovering(player):
		_qa_set_motion_state(player, &"WATER", "jump_pre_capture_guard")
		_cancel_ledge_catch()
		_coyote_remaining = 0.0
		_jump_buffer_remaining = 0.0
		_landing_correction_used = 0.0
		_landing_assist_logged = false
		_player_was_on_floor = false
		return

	_qa_set_motion_state(player, &"NORMAL" if player.is_on_floor() else &"AIRBORNE", "jump_assist")
	super(delta)
	if player.is_on_floor():
		_cancel_ledge_catch()
		return
	if _last_route_context != ROUTE_SAFE:
		_cancel_ledge_catch()
		return

	if _ledge_catch_remaining > 0.0:
		_update_ledge_catch(player, delta)
	else:
		_try_begin_ledge_catch(player)

## Overrides the base correction so a landing assist can never write the player
## directly into a platform, Titan collision, root, or moving log.
func _apply_landing_magnet(player: WildDashCharacterController, delta: float) -> void:
	if player.velocity.y > 1.0:
		return
	var target_id: StringName = _current_target_id()
	if target_id == &"":
		return
	var target: Vector3 = _resolve_landing_target(player, target_id)
	var vertical: float = player.global_position.y - target.y
	if vertical < 0.10 or vertical > 4.6:
		return
	var planar := Vector3(target.x - player.global_position.x, 0.0, target.z - player.global_position.z)
	var distance: float = planar.length()
	var landing_radius: float = float(_world.call("get_platform_landing_radius", target_id))
	var failure_count: int = int(_failures_by_target.get(target_id, 0))
	var max_total: float = minf(LANDING_ASSIST_MAX_METERS, LANDING_ASSIST_BASE_METERS + float(mini(3, failure_count)) * 0.08)
	if distance > landing_radius + max_total + 0.35 or distance <= landing_radius * 0.48:
		return
	var remaining: float = maxf(0.0, max_total - _landing_correction_used)
	if remaining <= 0.001 or planar.length_squared() <= 0.001:
		return
	var step: float = minf(remaining, minf(distance * 0.08, delta * 2.8))
	if step <= 0.001:
		return
	var motion: Vector3 = planar.normalized() * step
	if player.test_move(player.global_transform, motion):
		print("LOGSPIRE LANDING BLOCKED racer=%s target=%s assist=landing_magnet motion=%.3f correction_used=%.3f" % [
			RaceManager.get_racer_label(player), String(target_id), step, _landing_correction_used,
		])
		return
	player.move_and_collide(motion)
	_landing_correction_used += step
	if not _landing_assist_logged:
		_landing_assist_logged = true
		print("LOGSPIRE JUMP ASSIST type=landing_magnet target=%s max=%.2fm failures=%d physics_query=true moving_prediction=%s" % [
			String(target_id), max_total, failure_count, str(_is_moving_target(target_id)),
		])

func _try_begin_ledge_catch(player: WildDashCharacterController) -> void:
	if player.velocity.y > -LEDGE_CATCH_MIN_DESCENT:
		return
	var target_id: StringName = _current_target_id()
	if target_id == &"":
		return
	var target: Vector3 = _resolve_landing_target(player, target_id)
	var top_delta: float = target.y - player.global_position.y
	if top_delta < -LEDGE_CATCH_MAX_ABOVE_TOP or top_delta > LEDGE_CATCH_MAX_BELOW_TOP:
		return
	var planar := Vector3(target.x - player.global_position.x, 0.0, target.z - player.global_position.z)
	var distance: float = planar.length()
	var radius: float = float(_world.call("get_platform_landing_radius", target_id))
	if distance < maxf(0.4, radius * 0.58):
		return
	if distance > radius + LEDGE_CATCH_EXTRA_RANGE:
		return

	var preview_motion := Vector3.ZERO
	if planar.length_squared() > 0.001:
		preview_motion = planar.normalized() * minf(0.20, maxf(0.05, distance - radius * 0.72))
	preview_motion.y = minf(0.16, maxf(0.0, target.y + 0.10 - player.global_position.y))
	if preview_motion.length_squared() > 0.000001 and player.test_move(player.global_transform, preview_motion):
		print("LOGSPIRE LANDING BLOCKED racer=%s target=%s assist=ledge_catch phase=begin" % [
			RaceManager.get_racer_label(player), String(target_id),
		])
		return

	_ledge_catch_remaining = LEDGE_CATCH_WINDOW_SECONDS
	_ledge_catch_target_id = target_id
	_ledge_catch_logged = false
	player.velocity.y = maxf(player.velocity.y, 0.25)
	_qa_record_metric(&"ledge_catch", player, target_id)
	print("LOGSPIRE LEDGE CATCH racer=%s target=%s window=%.2fs miss=%.2fm safe_route=true teleport=false physics_query=true" % [
		RaceManager.get_racer_label(player), String(target_id), LEDGE_CATCH_WINDOW_SECONDS, maxf(0.0, distance - radius),
	])

func _update_ledge_catch(player: WildDashCharacterController, delta: float) -> void:
	_ledge_catch_remaining = maxf(0.0, _ledge_catch_remaining - delta)
	if _ledge_catch_target_id == &"" or _ledge_catch_remaining <= 0.0:
		_cancel_ledge_catch()
		return
	var target: Vector3 = _resolve_landing_target(player, _ledge_catch_target_id)
	var planar := Vector3(target.x - player.global_position.x, 0.0, target.z - player.global_position.z)
	var distance: float = planar.length()
	var radius: float = float(_world.call("get_platform_landing_radius", _ledge_catch_target_id))
	var inward_distance: float = maxf(0.0, distance - radius * 0.72)
	var inward_step: float = minf(inward_distance, LEDGE_CATCH_INWARD_SPEED * delta)
	var vertical_step: float = 0.0
	var desired_y: float = target.y + 0.10
	if player.global_position.y < desired_y:
		vertical_step = minf(desired_y - player.global_position.y, LEDGE_CATCH_UP_SPEED * delta)
	var motion := Vector3.ZERO
	if planar.length_squared() > 0.001 and inward_step > 0.0:
		motion += planar.normalized() * inward_step
	motion.y = vertical_step
	if motion.length_squared() > 0.000001:
		if player.test_move(player.global_transform, motion):
			print("LOGSPIRE LANDING BLOCKED racer=%s target=%s assist=ledge_catch phase=update motion=(%.2f,%.2f,%.2f)" % [
				RaceManager.get_racer_label(player), String(_ledge_catch_target_id), motion.x, motion.y, motion.z,
			])
			_cancel_ledge_catch()
			return
		player.move_and_collide(motion)
	player.velocity.y = maxf(player.velocity.y, 0.15)
	player.current_speed = maxf(player.current_speed, player.cruise_speed * 0.68)
	if not _ledge_catch_logged:
		_ledge_catch_logged = true
		print("LOGSPIRE LEDGE CATCH ASSIST target=%s duration=%.2fs collision_respected=true physics_query=true moving_prediction=%s" % [
			String(_ledge_catch_target_id), LEDGE_CATCH_WINDOW_SECONDS, str(_is_moving_target(_ledge_catch_target_id)),
		])
	if player.is_on_floor() or (player.global_position.y >= desired_y - 0.06 and distance <= radius * 0.82):
		_cancel_ledge_catch()

func _resolve_landing_target(player: WildDashCharacterController, target_id: StringName) -> Vector3:
	var value: Variant = _world.call("get_platform_position", target_id)
	var target: Vector3 = value if value is Vector3 else player.global_position
	if _gameplay == null or not _gameplay.has_method("predict_landing"):
		return target
	if not _is_moving_target(target_id):
		return target
	var vertical_distance: float = absf(player.global_position.y - target.y)
	var vertical_speed: float = maxf(2.0, absf(player.velocity.y))
	var travel_time: float = clampf(vertical_distance / vertical_speed, 0.0, MOVING_LANDING_PREDICT_MAX_SECONDS)
	var predicted_value: Variant = _gameplay.call("predict_landing", target_id, travel_time)
	return predicted_value if predicted_value is Vector3 else target

func _is_moving_target(target_id: StringName) -> bool:
	if _gameplay == null or not _gameplay.has_method("get_platform_kind"):
		return false
	return StringName(_gameplay.call("get_platform_kind", target_id)) != &"stable"

func _cancel_ledge_catch() -> void:
	_ledge_catch_remaining = 0.0
	_ledge_catch_target_id = &""
	_ledge_catch_logged = false

func _is_player_water_recovering(player: WildDashCharacterController) -> bool:
	if player == null:
		return false
	if _water_recovery == null or not is_instance_valid(_water_recovery):
		_water_recovery = get_parent().get_node_or_null("WaterRecovery")
	if _water_recovery == null:
		return false
	if _water_recovery.has_method("is_water_recovering") and bool(_water_recovery.call("is_water_recovering", player)):
		return true
	if _water_recovery.has_method("should_handle_racer"):
		return bool(_water_recovery.call("should_handle_racer", player))
	return false

func _authority_allows_jump_assist(player: WildDashCharacterController) -> bool:
	var mode := get_parent()
	if mode != null and mode.has_method("reliability_jump_assist_allowed"):
		return bool(mode.call("reliability_jump_assist_allowed", player))
	return true

func _qa_set_motion_state(player: WildDashCharacterController, state: StringName, source: String) -> void:
	var mode := get_parent()
	if mode != null and mode.has_method("reliability_set_motion_state"):
		mode.call("reliability_set_motion_state", player, state, source)

func _qa_record_metric(metric: StringName, player: WildDashCharacterController, platform_id: StringName) -> void:
	var mode := get_parent()
	if mode != null and mode.has_method("reliability_record_metric"):
		mode.call("reliability_record_metric", metric, player, platform_id)
