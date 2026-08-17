extends "res://modes/logspire_leap/logspire_jump_rebalance.gd"

## Phase B player forgiveness.
## Landing magnet already covers near misses from above. This adds a short,
## collision-respecting ledge catch for Safe Route jumps that reach the edge but
## would otherwise slide into the river by a few centimetres.

const LEDGE_CATCH_WINDOW_SECONDS: float = 0.42
const LEDGE_CATCH_EXTRA_RANGE: float = 0.85
const LEDGE_CATCH_MAX_BELOW_TOP: float = 1.45
const LEDGE_CATCH_MAX_ABOVE_TOP: float = 0.35
const LEDGE_CATCH_INWARD_SPEED: float = 2.6
const LEDGE_CATCH_UP_SPEED: float = 3.4
const LEDGE_CATCH_MIN_DESCENT: float = 0.15

var _ledge_catch_remaining: float = 0.0
var _ledge_catch_target_id: StringName = &""
var _ledge_catch_logged: bool = false
var _water_recovery: Node

func _ready() -> void:
	super()
	_water_recovery = get_parent().get_node_or_null("WaterRecovery")
	print("LOGSPIRE PHASE B PLAYER ASSIST READY landing_assist=%.2fm ledge_catch=%.2fs extra_range=%.2fm teleport=false" % [
		LANDING_ASSIST_MAX_METERS, LEDGE_CATCH_WINDOW_SECONDS, LEDGE_CATCH_EXTRA_RANGE,
	])

func _physics_process(delta: float) -> void:
	super(delta)
	if not RaceManager.active:
		return
	var player := _resolve_player()
	if player == null or player.finished:
		_cancel_ledge_catch()
		return
	if _is_player_water_recovering(player):
		_cancel_ledge_catch()
		return
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

func _try_begin_ledge_catch(player: WildDashCharacterController) -> void:
	if player.velocity.y > -LEDGE_CATCH_MIN_DESCENT:
		return
	var target_id: StringName = _current_target_id()
	if target_id == &"":
		return
	var target_value: Variant = _world.call("get_platform_position", target_id)
	if not (target_value is Vector3):
		return
	var target: Vector3 = target_value
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

	_ledge_catch_remaining = LEDGE_CATCH_WINDOW_SECONDS
	_ledge_catch_target_id = target_id
	_ledge_catch_logged = false
	player.velocity.y = maxf(player.velocity.y, 0.25)
	print("LOGSPIRE LEDGE CATCH racer=%s target=%s window=%.2fs miss=%.2fm safe_route=true teleport=false" % [
		RaceManager.get_racer_label(player), String(target_id), LEDGE_CATCH_WINDOW_SECONDS, maxf(0.0, distance - radius),
	])

func _update_ledge_catch(player: WildDashCharacterController, delta: float) -> void:
	_ledge_catch_remaining = maxf(0.0, _ledge_catch_remaining - delta)
	if _ledge_catch_target_id == &"" or _ledge_catch_remaining <= 0.0:
		_cancel_ledge_catch()
		return
	var target_value: Variant = _world.call("get_platform_position", _ledge_catch_target_id)
	if not (target_value is Vector3):
		_cancel_ledge_catch()
		return
	var target: Vector3 = target_value
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
		player.move_and_collide(motion)
	player.velocity.y = maxf(player.velocity.y, 0.15)
	player.current_speed = maxf(player.current_speed, player.cruise_speed * 0.68)
	if not _ledge_catch_logged:
		_ledge_catch_logged = true
		print("LOGSPIRE LEDGE CATCH ASSIST target=%s duration=%.2fs collision_respected=true" % [
			String(_ledge_catch_target_id), LEDGE_CATCH_WINDOW_SECONDS,
		])
	if player.is_on_floor() or (player.global_position.y >= desired_y - 0.06 and distance <= radius * 0.82):
		_cancel_ledge_catch()

func _cancel_ledge_catch() -> void:
	_ledge_catch_remaining = 0.0
	_ledge_catch_target_id = &""
	_ledge_catch_logged = false

func _is_player_water_recovering(player: WildDashCharacterController) -> bool:
	if _water_recovery == null or not is_instance_valid(_water_recovery):
		_water_recovery = get_parent().get_node_or_null("WaterRecovery")
	if _water_recovery == null or not _water_recovery.has_method("is_water_recovering"):
		return false
	return bool(_water_recovery.call("is_water_recovering", player))
