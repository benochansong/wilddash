extends WildDashModeController

const CHASE_CAMERA_SCRIPT: Script = preload("res://camera/chase_camera.gd")
const PLATFORM_AI_SCRIPT: Script = preload("res://modes/logspire_leap/logspire_platform_ai.gd")

const MODE_ID: StringName = &"logspire_leap"
const START_GRID_COLUMNS: int = 5
const START_GRID_X_SPACING: float = 2.75
const START_GRID_Z_SPACING: float = 3.35
const FINISH_RUNOUT_DISTANCE: float = 9.0

var _world: Node
var _graph: Node
var _recovery: Node
var _main_route: Array[Vector3] = []
var _safe_route_with_runout: Array[Vector3] = []
var _platform_ai_by_racer: Dictionary = {}
var _last_zone_by_racer: Dictionary = {}
var _player_rank: int = 0
var _fps_sum: float = 0.0
var _fps_samples: int = 0
var _direct_run: bool = false

func _ready() -> void:
	setup_mode(
		MODE_ID,
		"ROUND 3 — LOGSPIRE LEAP",
		"W/↑ 달리기 · A/D 조향 · Space 점프 · 숲 아래에서 THE CROWN NEST까지 올라가세요",
		false,
	)
	RaceManager.active = false
	RaceManager.clear_racers()
	RaceManager.clear_track()
	ItemSystem.reset_runtime()

	_world = get_node_or_null("LogspireWorld")
	_graph = get_node_or_null("PlatformGraph")
	_recovery = get_node_or_null("RecoverySystem")
	if _world == null or _graph == null or _recovery == null:
		push_error("LOGSPIRE ROUND INIT FAIL missing world/graph/recovery node")
		return

	_graph.call("configure", _world)
	if not bool(_graph.call("is_ready_for_race")):
		push_error("LOGSPIRE ROUND INIT FAIL platform graph unavailable")
		return

	_main_route = _copy_vector3_array(_world.call("get_main_route_points"))
	var checkpoints: Array[Vector3] = _copy_vector3_array(_world.call("get_checkpoint_positions"))
	if _main_route.size() < 3 or checkpoints.size() != 6:
		push_error("LOGSPIRE ROUND INIT FAIL route=%d checkpoints=%d" % [_main_route.size(), checkpoints.size()])
		return
	RaceManager.configure_track(_main_route, checkpoints)
	_safe_route_with_runout = _with_finish_runout(_copy_vector3_array(_graph.call("get_route_points", &"safe")))

	var start_value: Variant = _world.call("get_start_position")
	var start: Vector3 = start_value if start_value is Vector3 else Vector3.ZERO
	player = spawn_racer("Player", &"dog", start + _get_start_grid_offset(0), true, WildDashCharacterController.MovementMode.RACE)
	_orient_racer_to_first_target(player)

	var ai_total: int = GameManager.ai_count
	for i: int in range(ai_total):
		var spawn_position: Vector3 = start + _get_start_grid_offset(i + 1)
		var racer := spawn_racer("AI_%02d" % (i + 1), &"dog", spawn_position, false, WildDashCharacterController.MovementMode.RACE)
		_orient_racer_to_first_target(racer)
		var lane: float = float((i % 3) - 1) * 0.75
		var speed: float = clampf(racer.max_speed * 0.84, 9.5, 14.5)
		var driver := spawn_ai_driver(racer, WildDashAIController.AIMode.RACE, speed, lane, 0.08)
		driver.steering_strength = 7.2
		driver.acceleration = 23.0
		driver.avoidance_distance = 5.2

		var route_value: Variant = _graph.call("choose_route", i, GameManager.difficulty)
		var route_id := StringName(route_value) if route_value is StringName or route_value is String else &"safe"
		var route: Array[Vector3] = _with_finish_runout(_copy_vector3_array(_graph.call("get_route_points", route_id)))
		driver.set_race_route(route)
		_attach_platform_ai(racer, driver, route, route_id)

	if DisplayServer.get_name() == "headless":
		var player_driver := spawn_ai_driver(player, WildDashAIController.AIMode.RACE, clampf(player.max_speed * 0.90, 10.5, 15.5), 0.0, 0.0, true)
		player_driver.steering_strength = 7.6
		player_driver.acceleration = 25.0
		player_driver.avoidance_distance = 4.5
		player_driver.set_race_route(_safe_route_with_runout)
		_attach_platform_ai(player, player_driver, _safe_route_with_runout, &"safe")

	_recovery.call("configure", _world, _graph)
	if _recovery.has_signal("racer_recovered"):
		_recovery.connect("racer_recovered", Callable(self, "_on_racer_recovered"))

	var camera := CHASE_CAMERA_SCRIPT.new() as Camera3D
	if camera != null:
		camera.name = "ChaseCamera"
		camera.current = true
		add_child(camera)
		camera.call("set_target", player)
		camera.set("follow_distance", 10.5)
		camera.set("follow_height", 6.4)
		camera.set("look_ahead", 6.6)
		camera.fov = 74.0

	RaceManager.racer_finished.connect(_on_any_racer_finished)
	RaceManager.race_finished.connect(_on_player_finished)
	RaceManager.race_completed.connect(_on_race_completed)

	await get_tree().physics_frame
	await get_tree().physics_frame
	_direct_run = not _is_campaign_slot_active()
	if _direct_run:
		GameManager.set_state(GameManager.GameState.RACE)
	else:
		GameManager.begin_round(MODE_ID)
	RaceManager.start_race()

	print("LOGSPIRE ROUND READY run_mode=%s racers=%d ai=%d zones=%d checkpoints=%d platforms=%d course_length=%.1fm vertical_gain=%.1fm direct_scene=true" % [
		"F6_DIRECT" if _direct_run else "CAMPAIGN",
		RaceManager.racers.size(),
		ai_racers.size(),
		int(_world.call("get_zone_count")),
		RaceManager.get_checkpoint_count(),
		int(_world.call("get_platform_count")),
		float(_world.call("get_course_length")),
		_main_route[-1].y - _main_route[0].y,
	])

func _process(_delta: float) -> void:
	if player == null:
		return
	var fps: int = roundi(Engine.get_frames_per_second())
	if fps > 0:
		_fps_sum += float(fps)
		_fps_samples += 1
	var rank: int = RaceManager.get_rank(player)
	var checkpoint_progress: int = RaceManager.get_checkpoint_progress(player)
	var zone_name: String = String(_world.call("get_zone_name_for_checkpoint_progress", checkpoint_progress))
	hud.set_metrics("Rank %d/%d   CP %d/%d   %s   Progress %d%%   Speed %.1f   FPS %d" % [
		rank,
		RaceManager.racers.size(),
		checkpoint_progress,
		RaceManager.get_checkpoint_count(),
		zone_name,
		roundi(RaceManager.get_progress_percent(player)),
		player.current_speed,
		fps,
	])
	hud.set_item_state(ItemSystem.get_display_name(player.get_held_item()), ItemSystem.get_status_text(player))

func _physics_process(_delta: float) -> void:
	if not RaceManager.active:
		return
	for racer_value: Variant in RaceManager.racers.duplicate():
		var racer := racer_value as WildDashCharacterController
		if racer == null or racer.finished:
			continue
		RaceManager.sync_checkpoint_from_position(racer)
		RaceManager.sync_finish_from_position(racer)
		_log_zone_if_changed(racer)

func _attach_platform_ai(
	racer: WildDashCharacterController,
	driver: WildDashAIController,
	route: Array[Vector3],
	route_id: StringName
) -> void:
	var platform_ai := PLATFORM_AI_SCRIPT.new() as Node
	if platform_ai == null:
		return
	platform_ai.name = "%sLogspireJumpAI" % racer.name
	add_child(platform_ai)
	platform_ai.call("configure", racer, driver, route, _safe_route_with_runout, route_id)
	_platform_ai_by_racer[racer.get_instance_id()] = platform_ai

func _on_racer_recovered(racer: WildDashCharacterController, _target_id: StringName) -> void:
	if racer == null:
		return
	var node_value: Variant = _platform_ai_by_racer.get(racer.get_instance_id(), null)
	var platform_ai := node_value as Node
	if platform_ai != null and platform_ai.has_method("notify_recovered"):
		platform_ai.call("notify_recovered")

func _log_zone_if_changed(racer: WildDashCharacterController) -> void:
	var racer_id: int = racer.get_instance_id()
	var checkpoint_progress: int = RaceManager.get_checkpoint_progress(racer)
	var zone_name: String = String(_world.call("get_zone_name_for_checkpoint_progress", checkpoint_progress))
	var previous: String = String(_last_zone_by_racer.get(racer_id, ""))
	if previous == zone_name:
		return
	_last_zone_by_racer[racer_id] = zone_name
	print("LOGSPIRE ZONE ENTER racer=%s zone=%s checkpoint=%d/%d" % [
		RaceManager.get_racer_label(racer), zone_name, checkpoint_progress, RaceManager.get_checkpoint_count(),
	])
	if racer == player and hud != null:
		hud.set_message(zone_name)

func _on_any_racer_finished(racer: Node3D, rank: int) -> void:
	print("LOGSPIRE FINISH racer=%s rank=%d time=%.2fs" % [RaceManager.get_racer_label(racer), rank, RaceManager.get_elapsed_seconds()])

func _on_player_finished(rank: int) -> void:
	if mode_finished:
		return
	_player_rank = rank
	var elapsed: float = RaceManager.get_elapsed_seconds()
	var success: bool = rank > 0 and rank <= ceili(float(RaceManager.racers.size()) * 0.5)
	var average_fps: float = 0.0 if _fps_samples == 0 else _fps_sum / float(_fps_samples)
	print("LOGSPIRE PLAYER FINISH rank=%d elapsed=%.2fs checkpoints=%d/%d fps=%.1f" % [
		rank, elapsed, RaceManager.get_checkpoint_progress(player), RaceManager.get_checkpoint_count(), average_fps,
	])
	if _direct_run:
		mode_finished = true
		RaceManager.active = false
		hud.set_message("WILD FINISH — THE CROWN NEST")
		if DisplayServer.get_name() == "headless":
			get_tree().quit(0)
		return
	finish_mode(success, rank, {
		"rank": rank,
		"racers": RaceManager.racers.size(),
		"checkpoints": RaceManager.get_checkpoint_count(),
		"track_length_m": RaceManager.get_track_length(),
		"player_finish_seconds": elapsed,
		"average_fps": average_fps,
		"phase": 1,
	})

func _on_race_completed() -> void:
	if _direct_run or mode_finished:
		return
	if _player_rank <= 0 and player != null:
		var index: int = RaceManager.finish_order.find(player)
		if index >= 0:
			_player_rank = index + 1
	var success: bool = _player_rank > 0 and _player_rank <= ceili(float(RaceManager.racers.size()) * 0.5)
	finish_mode(success, _player_rank, {
		"rank": _player_rank,
		"racers": RaceManager.racers.size(),
		"finishers": RaceManager.finish_order.size(),
		"checkpoints": RaceManager.get_checkpoint_count(),
		"track_length_m": RaceManager.get_track_length(),
		"phase": 1,
	})

func _is_campaign_slot_active() -> bool:
	return GameManager.campaign_running and GameManager.get_current_round_id() == MODE_ID

func _get_start_grid_offset(slot: int) -> Vector3:
	var row: int = slot / START_GRID_COLUMNS
	var column: int = slot % START_GRID_COLUMNS
	var center: float = float(START_GRID_COLUMNS - 1) * 0.5
	var stagger: float = 0.50 if row % 2 == 1 else 0.0
	return Vector3((float(column) - center) * START_GRID_X_SPACING + stagger, 0.0, float(row) * START_GRID_Z_SPACING)

func _orient_racer_to_first_target(racer: WildDashCharacterController) -> void:
	if racer == null or _main_route.size() < 2:
		return
	var direction: Vector3 = _main_route[1] - racer.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		direction = direction.normalized()
		racer.rotation.y = atan2(-direction.x, -direction.z)

func _with_finish_runout(route: Array[Vector3]) -> Array[Vector3]:
	var result: Array[Vector3] = []
	for point: Vector3 in route:
		result.append(point)
	if result.size() < 2:
		return result
	var direction: Vector3 = result[-1] - result[-2]
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		result.append(result[-1] + direction.normalized() * FINISH_RUNOUT_DISTANCE)
	return result

func _copy_vector3_array(value: Variant) -> Array[Vector3]:
	var result: Array[Vector3] = []
	if not (value is Array):
		return result
	for item: Variant in value:
		if item is Vector3:
			result.append(item)
	return result
