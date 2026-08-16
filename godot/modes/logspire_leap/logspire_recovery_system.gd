extends Node

signal racer_recovered(racer: WildDashCharacterController, target_id: StringName)

const RECOVERY_DELAY_SECONDS: float = 0.90
const ABSOLUTE_FALL_Y: float = -18.0

var _world: Node
var _graph: Node
var _pending: Dictionary = {}

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
	print("LOGSPIRE RECOVERY READY delay=%.2fs absolute_fall_y=%.1f" % [RECOVERY_DELAY_SECONDS, ABSOLUTE_FALL_Y])

func _physics_process(_delta: float) -> void:
	if _graph == null or not RaceManager.active:
		return
	for racer_value: Variant in RaceManager.racers.duplicate():
		var racer := racer_value as WildDashCharacterController
		if racer == null or racer.finished or racer.global_position.y >= ABSOLUTE_FALL_Y:
			continue
		var racer_id: int = racer.get_instance_id()
		if _pending.has(racer_id):
			continue
		var target_value: Variant = _graph.call("get_last_checkpoint_id", RaceManager.get_checkpoint_progress(racer))
		var target_id := StringName(target_value) if target_value is StringName or target_value is String else &""
		_queue_recovery(racer, target_id, "absolute_fall")

func _on_recovery_area_body_entered(body: Node3D, area: Area3D) -> void:
	var racer := body as WildDashCharacterController
	if racer == null or racer.finished or not RaceManager.active:
		return
	var racer_id: int = racer.get_instance_id()
	if _pending.has(racer_id):
		return
	var meta_value: Variant = area.get_meta(&"logspire_recovery_target", &"")
	var target_id := StringName(meta_value) if meta_value is StringName or meta_value is String else &""
	_queue_recovery(racer, target_id, String(area.name))

func _queue_recovery(racer: WildDashCharacterController, target_id: StringName, source: String) -> void:
	if racer == null or target_id == &"":
		return
	var racer_id: int = racer.get_instance_id()
	_pending[racer_id] = true
	print("LOGSPIRE FALL racer=%s source=%s checkpoint=%d target=%s" % [
		RaceManager.get_racer_label(racer),
		source,
		RaceManager.get_checkpoint_progress(racer),
		String(target_id),
	])
	_recover_after_delay(racer, target_id, racer_id)

func _recover_after_delay(racer: WildDashCharacterController, target_id: StringName, racer_id: int) -> void:
	await get_tree().create_timer(RECOVERY_DELAY_SECONDS).timeout
	if racer == null or not is_instance_valid(racer) or racer.finished:
		_pending.erase(racer_id)
		return
	var position_value: Variant = _graph.call("get_platform_position", target_id)
	var target_position: Vector3 = position_value if position_value is Vector3 else Vector3.ZERO
	var forward_value: Variant = _graph.call("get_platform_forward", target_id, &"safe")
	var forward: Vector3 = forward_value if forward_value is Vector3 else Vector3.FORWARD
	racer.reset_motion(target_position + Vector3.UP * 1.20)
	if forward.length_squared() > 0.001:
		forward.y = 0.0
		forward = forward.normalized()
		racer.rotation.y = atan2(-forward.x, -forward.z)
	racer.current_speed = maxf(racer.current_speed, racer.cruise_speed * 0.72)
	_pending.erase(racer_id)
	print("LOGSPIRE RECOVERY racer=%s target=%s delay=%.2fs" % [
		RaceManager.get_racer_label(racer),
		String(target_id),
		RECOVERY_DELAY_SECONDS,
	])
	racer_recovered.emit(racer, target_id)
