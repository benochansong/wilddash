extends Node

signal racer_recovered(racer: WildDashCharacterController, target_id: StringName)

const RECOVERY_DELAY_SECONDS: float = 0.90
const ABSOLUTE_FALL_Y: float = -18.0
const RECOVERY_SPAWN_HEIGHT: float = 1.24
const RECOVERY_RUNWAY_BACKOFF_MIN: float = 0.80
const RECOVERY_RUNWAY_BACKOFF_MAX: float = 1.60
const RECOVERY_RETRY_GRACE_SECONDS: float = 1.25
const RECOVERY_RETRY_GRACE_META: StringName = &"logspire_retry_grace_until"

var _world: Node
var _graph: Node
var _water_recovery: Node
var _pending: Dictionary = {}
var _recovery_token_counter: int = 0

func configure(world: Node, graph: Node) -> void:
	_world = world
	_graph = graph
	var areas_value: Variant = _world.call("get_recovery_areas")
	if areas_value is Array:
		for item: Variant in areas_value:
			var area := item as Area3D
			if area == null:
				continue
			if not area.body_entered.is_connected(_on_recovery_area_body_entered):
				area.body_entered.connect(_on_recovery_area_body_entered.bind(area))
	print("LOGSPIRE RECOVERY READY delay=%.2fs absolute_fall_y=%.1f latest_checkpoint_authority=true water_handoff=true stale_timer_guard=true safe_exit_guard=true pending_authority=true retry_grace=%.2fs" % [RECOVERY_DELAY_SECONDS, ABSOLUTE_FALL_Y, RECOVERY_RETRY_GRACE_SECONDS])

func set_water_recovery(value: Node) -> void:
	_water_recovery = value
	print("LOGSPIRE RECOVERY WATER HANDOFF enabled=%s" % str(_water_recovery != null))

func cancel_pending_for_water(racer: WildDashCharacterController) -> void:
	if racer == null or not is_instance_valid(racer):
		return
	var racer_id: int = racer.get_instance_id()
	if not _pending.has(racer_id):
		return
	_pending.erase(racer_id)
	_qa_set_state(racer, &"WATER", "checkpoint_cancelled_for_water")
	print("LOGSPIRE RECOVERY CANCELLED FOR WATER racer=%s stale_timer_invalidated=true authority=WATER" % RaceManager.get_racer_label(racer))

func force_checkpoint_recovery(racer: WildDashCharacterController, source: String = "forced") -> void:
	if racer == null or racer.finished or _graph == null:
		return
	if _water_should_handle(racer):
		print("LOGSPIRE RECOVERY BLOCKED BY WATER racer=%s source=%s ladder_priority=true" % [RaceManager.get_racer_label(racer), source])
		return
	var racer_id: int = racer.get_instance_id()
	if _pending.has(racer_id):
		return
	var target_id: StringName = _latest_checkpoint_target(racer)
	_queue_recovery(racer, target_id, source)

func begin_retry_grace(racer: WildDashCharacterController, source: String = "recovery") -> void:
	if racer == null or not is_instance_valid(racer) or racer.finished:
		return
	var until: float = Time.get_ticks_msec() * 0.001 + RECOVERY_RETRY_GRACE_SECONDS
	racer.set_meta(RECOVERY_RETRY_GRACE_META, until)
	racer.current_speed = 0.0
	racer.velocity.x = 0.0
	racer.velocity.z = 0.0
	print("LOGSPIRE RETRY GRACE racer=%s source=%s duration=%.2fs auto_forward_suppressed=true" % [
		RaceManager.get_racer_label(racer), source, RECOVERY_RETRY_GRACE_SECONDS,
	])

func _physics_process(_delta: float) -> void:
	if _graph == null or not RaceManager.active:
		return
	for racer_value: Variant in RaceManager.racers.duplicate():
		var racer := racer_value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.finished:
			continue
		_enforce_retry_grace(racer)
		if racer.global_position.y >= ABSOLUTE_FALL_Y:
			continue
		if _water_should_handle(racer):
			cancel_pending_for_water(racer)
			continue
		var racer_id: int = racer.get_instance_id()
		if _pending.has(racer_id):
			continue
		var target_id: StringName = _latest_checkpoint_target(racer)
		_queue_recovery(racer, target_id, "absolute_fall")

func _on_recovery_area_body_entered(body: Node3D, area: Area3D) -> void:
	var racer := body as WildDashCharacterController
	if racer == null or racer.finished or not RaceManager.active:
		return
	if _water_should_handle(racer):
		cancel_pending_for_water(racer)
		return
	var racer_id: int = racer.get_instance_id()
	if _pending.has(racer_id):
		return
	var target_id: StringName = _latest_checkpoint_target(racer)
	if target_id == &"":
		var meta_value: Variant = area.get_meta(&"logspire_recovery_target", &"")
		if meta_value is StringName:
			target_id = meta_value
		elif meta_value is String:
			target_id = StringName(meta_value)
	_queue_recovery(racer, target_id, String(area.name))

func _water_should_handle(racer: WildDashCharacterController) -> bool:
	if racer == null or not is_instance_valid(racer):
		return false
	if bool(racer.get_meta(&"logspire_water_recovery_active", false)):
		return true
	if _water_recovery == null or not is_instance_valid(_water_recovery):
		return false
	if _water_recovery.has_method("is_water_recovering") and bool(_water_recovery.call("is_water_recovering", racer)):
		return true
	if not _water_recovery.has_method("should_handle_racer"):
		return false
	return bool(_water_recovery.call("should_handle_racer", racer))

func _latest_checkpoint_target(racer: WildDashCharacterController) -> StringName:
	if racer == null or _graph == null:
		return &""
	var target_value: Variant = _graph.call("get_last_checkpoint_id", RaceManager.get_checkpoint_progress(racer))
	if target_value is StringName:
		return target_value
	if target_value is String:
		return StringName(target_value)
	return &""

func _queue_recovery(racer: WildDashCharacterController, target_id: StringName, source: String) -> void:
	if racer == null or target_id == &"":
		return
	if _water_should_handle(racer):
		cancel_pending_for_water(racer)
		return
	var racer_id: int = racer.get_instance_id()
	_recovery_token_counter += 1
	var token: int = _recovery_token_counter
	_pending[racer_id] = token
	# Claim recovery authority as soon as the bounded delay starts. This prevents
	# jump/landing helpers from becoming another transform writer on the reset frame.
	_qa_set_state(racer, &"RECOVERY", "checkpoint_recovery_pending")
	print("LOGSPIRE FALL racer=%s source=%s checkpoint=%d target=%s token=%d authority=RECOVERY" % [
		RaceManager.get_racer_label(racer),
		source,
		RaceManager.get_checkpoint_progress(racer),
		String(target_id),
		token,
	])
	_recover_after_delay(racer, target_id, racer_id, token)

func _recover_after_delay(racer: WildDashCharacterController, target_id: StringName, racer_id: int, token: int) -> void:
	await get_tree().create_timer(RECOVERY_DELAY_SECONDS).timeout
	if racer == null or not is_instance_valid(racer) or racer.finished:
		if int(_pending.get(racer_id, -1)) == token:
			_pending.erase(racer_id)
		return
	if not _pending.has(racer_id) or int(_pending.get(racer_id, -1)) != token:
		print("LOGSPIRE RECOVERY STALE TIMER DROPPED racer=%s token=%d" % [RaceManager.get_racer_label(racer), token])
		return
	if _water_should_handle(racer):
		_pending.erase(racer_id)
		_qa_set_state(racer, &"WATER", "checkpoint_timer_cancelled_for_water")
		print("LOGSPIRE RECOVERY TIMER CANCELLED BY WATER racer=%s token=%d ladder_priority=true authority=WATER" % [RaceManager.get_racer_label(racer), token])
		return
	var position_value: Variant = _graph.call("get_platform_position", target_id)
	var target_position: Vector3 = position_value if position_value is Vector3 else Vector3.ZERO
	var forward_value: Variant = _graph.call("get_platform_forward", target_id, &"safe")
	var forward: Vector3 = forward_value if forward_value is Vector3 else Vector3.FORWARD
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward.y = 0.0
		forward = forward.normalized()
	var landing_radius: float = 4.0
	if _graph.has_method("get_landing_radius"):
		landing_radius = maxf(3.0, float(_graph.call("get_landing_radius", target_id)))
	var runway_backoff: float = clampf(landing_radius * 0.24, RECOVERY_RUNWAY_BACKOFF_MIN, RECOVERY_RUNWAY_BACKOFF_MAX)
	var safe_spawn: Vector3 = target_position - forward * runway_backoff + Vector3.UP * RECOVERY_SPAWN_HEIGHT
	_qa_set_state(racer, &"RECOVERY", "checkpoint_recovery")
	racer.reset_motion(safe_spawn)
	racer.rotation.y = atan2(-forward.x, -forward.z)
	racer.current_speed = 0.0
	racer.velocity.x = 0.0
	racer.velocity.z = 0.0
	begin_retry_grace(racer, "checkpoint_recovery")
	_pending.erase(racer_id)
	_qa_set_state(racer, &"SAFE_EXIT", "checkpoint_recovery")
	_qa_release_safe_exit_after_frame(racer_id)
	print("LOGSPIRE RECOVERY racer=%s target=%s delay=%.2fs token=%d safe_exit_guard=true spawn=center_backoff backoff=%.2fm retry_grace=%.2fs" % [
		RaceManager.get_racer_label(racer),
		String(target_id),
		RECOVERY_DELAY_SECONDS,
		token,
		runway_backoff,
		RECOVERY_RETRY_GRACE_SECONDS,
	])
	racer_recovered.emit(racer, target_id)

func _enforce_retry_grace(racer: WildDashCharacterController) -> void:
	if racer == null or not is_instance_valid(racer) or not racer.has_meta(RECOVERY_RETRY_GRACE_META):
		return
	var until: float = float(racer.get_meta(RECOVERY_RETRY_GRACE_META, 0.0))
	var now: float = Time.get_ticks_msec() * 0.001
	if now >= until:
		racer.remove_meta(RECOVERY_RETRY_GRACE_META)
		print("LOGSPIRE RETRY GRACE COMPLETE racer=%s control_returned=true" % RaceManager.get_racer_label(racer))
		return
	# The race controller normally accelerates toward cruise speed even without
	# throttle. Resetting horizontal motion every frame during this short grace
	# gives the player time to read the platform and aim the next jump instead of
	# immediately walking off the recovery deck again.
	racer.current_speed = 0.0
	racer.velocity.x = 0.0
	racer.velocity.z = 0.0

func _qa_set_state(racer: WildDashCharacterController, state: StringName, source: String) -> void:
	var mode := get_parent()
	if mode != null and mode.has_method("reliability_set_motion_state"):
		mode.call("reliability_set_motion_state", racer, state, source)

func _qa_release_safe_exit_after_frame(racer_id: int) -> void:
	await get_tree().physics_frame
	for racer_value: Variant in RaceManager.racers:
		var racer := racer_value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.get_instance_id() != racer_id:
			continue
		if _water_should_handle(racer):
			return
		_qa_set_state(racer, &"NORMAL" if racer.is_on_floor() else &"AIRBORNE", "checkpoint_safe_exit_complete")
		return
