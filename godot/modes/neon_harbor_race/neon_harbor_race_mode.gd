extends WildDashModeController

const TRACK_SCENE: PackedScene = preload("res://tracks/neon_harbor_track.tscn")
const ITEM_BOX_SCENE: PackedScene = preload("res://items/item_box.tscn")
const CHASE_CAMERA_SCRIPT: Script = preload("res://camera/chase_camera.gd")
const AI_ITEM_BRAIN_SCRIPT: Script = preload("res://items/ai_item_brain.gd")
const AI_PACK_TACTICS_SCRIPT: Script = preload("res://characters/ai_pack_tactics.gd")

const ROUTE_LANES: Array[float] = [-3.0, -1.0, 1.0, 3.0, -2.2, 0.0, 2.2, -3.6, -1.4, 1.4, 3.6, -2.8, 0.8, 2.8, -0.6, 2.0, -2.0]
const AI_SPEEDS: Array[float] = [14.9, 14.4, 14.7, 14.6]
const ITEM_BOX_ROUTE_INDICES: Array[int] = [2, 5, 8, 11, 14, 17, 20, 23]
const WIDE_ITEM_STATIONS: Array[int] = [5, 14, 23]
const ITEM_BOX_LANE_OFFSETS: Array[float] = [-3.2, 0.0, 3.2]
const ITEM_BOX_WIDE_LANE_OFFSETS: Array[float] = [-4.2, -1.4, 1.4, 4.2]
const START_GRID_COLUMNS := 4
const START_GRID_X_SPACING := 2.45
const START_GRID_Z_SPACING := 3.15
const FINISH_RUNOUT_DISTANCE := 12.0
const SHORTCUT_SKIP_ROUTE_INDEX := 4
const HEAVY_SHORTCUT_BLOCK_IDS: Array[StringName] = [&"elephant", &"bear", &"panda"]
const PLAYER_MAX_SPEED_SCALE := 1.18
const PLAYER_CRUISE_SPEED_SCALE := 1.10
const PLAYER_ACCELERATION_SCALE := 1.10

var _track: WildDashNeonHarborTrack
var _route_points: Array[Vector3] = []
var _item_boxes: Array[WildDashItemBox] = []
var _ai_item_brains: Array[WildDashAIItemBrain] = []
var _player_rank := 0
var _finish_times: Array[float] = []
var _fps_sum := 0.0
var _fps_samples := 0
var _headless_debug_elapsed := 0.0
var _realtime_balance_run := false
var _shortcut_users := 0

func _ready() -> void:
	setup_mode(
		&"neon_harbor_race",
		"ROUND 3 — Neon Harbor Night Race",
		"W/↑ 가속 · A/D 조향 · Space 점프 · E/X 캐릭터 스킬 · Q/B 아이템 · 9개 체크포인트",
		false,
	)
	_configure_night_sun()
	RaceManager.clear_racers()
	RaceManager.clear_track()
	ItemSystem.reset_runtime()

	_track = TRACK_SCENE.instantiate() as WildDashNeonHarborTrack
	if _track == null:
		push_error("Failed to instantiate Neon Harbor track")
		return
	_track.name = "NeonHarborWorldTrack"
	add_child(_track)
	_route_points = _track.get_route_points()

	var start := _track.get_start_position()
	player = spawn_racer("Player", &"dog", start + _get_start_grid_offset(0), true, WildDashCharacterController.MovementMode.RACE)
	_apply_neon_player_pace(player)

	var ai_total: int = GameManager.ai_count
	var headless := DisplayServer.get_name() == "headless"
	_realtime_balance_run = headless and OS.has_environment("WILDDASH_REALTIME_BALANCE")
	for i in range(ai_total):
		var lane: float = ROUTE_LANES[i % ROUTE_LANES.size()]
		var speed: float = AI_SPEEDS[i % AI_SPEEDS.size()] - float(i / AI_SPEEDS.size()) * 0.05
		var spawn_position := start + _get_start_grid_offset(i + 1)
		var racer := spawn_racer("AI_%02d" % (i + 1), &"dog", spawn_position, false, WildDashCharacterController.MovementMode.RACE)
		var driver := spawn_ai_driver(racer, WildDashAIController.AIMode.RACE, speed, lane, 0.16)
		driver.steering_strength = 6.6
		driver.acceleration = 25.0
		driver.avoidance_distance = 8.5

		var personality: int = i % 5
		var risk: float = float([0.88, 0.28, 0.72, 0.68, 0.54][personality])
		var overtake: float = float([0.92, 0.34, 0.70, 0.60, 0.64][personality])
		var shortcut_pref: float = float([0.42, 0.18, 0.90, 0.36, 0.48][personality])
		var tactics := AI_PACK_TACTICS_SCRIPT.new() as WildDashAIPackTactics
		tactics.name = "%sPackTactics" % racer.name
		tactics.configure(racer, driver, personality as WildDashAIPackTactics.Personality, risk, overtake, shortcut_pref)
		add_child(tactics)

		var heavy_shortcut_blocked: bool = HEAVY_SHORTCUT_BLOCK_IDS.has(racer.animal_id)
		if personality == WildDashAIPackTactics.Personality.SHORTCUT and not heavy_shortcut_blocked:
			driver.preferred_lane = clampf(lane * 0.25, -0.9, 0.9)
			driver.set_race_route(_build_shortcut_route(SHORTCUT_SKIP_ROUTE_INDEX))
			_shortcut_users += 1
		else:
			driver.set_race_route(_build_race_route_with_runout())
			if personality == WildDashAIPackTactics.Personality.SHORTCUT and heavy_shortcut_blocked:
				print("NEON HARBOR HEAVY AI MAIN ROUTE racer=%s animal=%s shortcut_blocked=true" % [racer.name, racer.animal_id])

		var item_brain := AI_ITEM_BRAIN_SCRIPT.new() as WildDashAIItemBrain
		item_brain.name = "%sItemBrain" % racer.name
		item_brain.configure(racer, driver)
		add_child(item_brain)
		_ai_item_brains.append(item_brain)

	_spawn_item_boxes()

	if headless:
		var player_test_speed := player.max_speed if _realtime_balance_run else 52.0
		var headless_driver := spawn_ai_driver(player, WildDashAIController.AIMode.RACE, player_test_speed, 0.0, 0.0, true)
		headless_driver.steering_strength = 6.6 if _realtime_balance_run else 12.2
		headless_driver.acceleration = 25.0 if _realtime_balance_run else 92.0
		headless_driver.avoidance_distance = 8.5
		headless_driver.set_race_route(_build_race_route_with_runout())
		var player_item_brain := AI_ITEM_BRAIN_SCRIPT.new() as WildDashAIItemBrain
		player_item_brain.name = "PlayerTestItemBrain"
		player_item_brain.configure(player, headless_driver)
		add_child(player_item_brain)
		_ai_item_brains.append(player_item_brain)
		if not _realtime_balance_run:
			for driver in ai_drivers:
				if driver == headless_driver:
					continue
				driver.target_speed *= 3.45
				driver.acceleration = 90.0
				driver.steering_strength = 12.0

	var camera := CHASE_CAMERA_SCRIPT.new() as Camera3D
	if camera != null:
		camera.name = "ChaseCamera"
		camera.current = true
		camera.fov = 72.0
		add_child(camera)
		camera.call("set_target", player)

	RaceManager.racer_finished.connect(_on_any_racer_finished)
	RaceManager.race_finished.connect(_on_player_finished)
	RaceManager.race_completed.connect(_on_race_completed)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not headless:
		await get_tree().create_timer(1.0).timeout
	GameManager.begin_round(&"neon_harbor_race")
	RaceManager.start_race()
	print("NEON HARBOR START racers=%d ai=%d checkpoints=%d length=%.1fm item_boxes=%d npc_species=%d shortcut_users=%d" % [
		RaceManager.racers.size(), ai_racers.size(), RaceManager.get_checkpoint_count(), RaceManager.get_track_length(),
		_item_boxes.size(), WildDashAnimalCatalog.race_roster_ids().size(), _shortcut_users,
	])

func _process(_delta: float) -> void:
	if player == null:
		return
	var fps := Engine.get_frames_per_second()
	if fps > 0:
		_fps_sum += float(fps)
		_fps_samples += 1
	var rank := RaceManager.get_rank(player)
	var checkpoint_progress := RaceManager.get_checkpoint_progress(player)
	var progress_percent := RaceManager.get_progress_percent(player)
	hud.set_metrics("Rank %d / %d   CP %d/%d   Progress %d%%   Speed %.1f   FPS %d" % [
		rank, RaceManager.racers.size(), checkpoint_progress, RaceManager.get_checkpoint_count(),
		roundi(progress_percent), player.current_speed, fps,
	])
	hud.set_item_state(ItemSystem.get_display_name(player.get_held_item()), ItemSystem.get_status_text(player))

func _physics_process(delta: float) -> void:
	if RaceManager.active:
		for racer in RaceManager.racers.duplicate():
			RaceManager.sync_checkpoint_from_position(racer)
			RaceManager.sync_finish_from_position(racer)
	if player != null and player.global_position.y < -28.0 and not player.finished:
		player.reset_motion(RaceManager.get_respawn_position(player))
		_orient_to_route(player)
	if DisplayServer.get_name() != "headless" or not RaceManager.active:
		return
	_headless_debug_elapsed += delta
	if _headless_debug_elapsed < 5.0:
		return
	_headless_debug_elapsed = 0.0
	print("NEON HARBOR PROGRESS finishers=%d/%d player_cp=%d/%d progress=%.0f%%" % [
		RaceManager.finish_order.size(), RaceManager.racers.size(), RaceManager.get_checkpoint_progress(player),
		RaceManager.get_checkpoint_count(), RaceManager.get_progress_percent(player),
	])

func _spawn_item_boxes() -> void:
	var respawn := 5.0
	if RaceManager.racers.size() >= 18:
		respawn = 3.6
	elif RaceManager.racers.size() >= 15:
		respawn = 4.0
	for route_index in ITEM_BOX_ROUTE_INDICES:
		if route_index <= 0 or route_index >= _route_points.size() - 1:
			continue
		var point := _route_points[route_index]
		var tangent := _route_points[route_index + 1] - _route_points[route_index - 1]
		tangent.y = 0.0
		tangent = Vector3.FORWARD if tangent.length_squared() <= 0.001 else tangent.normalized()
		var right := Vector3(-tangent.z, 0.0, tangent.x)
		var lane_offsets := ITEM_BOX_WIDE_LANE_OFFSETS if WIDE_ITEM_STATIONS.has(route_index) and RaceManager.racers.size() >= 15 else ITEM_BOX_LANE_OFFSETS
		for lane_offset in lane_offsets:
			var box := ITEM_BOX_SCENE.instantiate() as WildDashItemBox
			if box == null:
				continue
			box.name = "NeonItemBox_R%02d_L%s" % [route_index, str(lane_offset).replace("-", "N").replace(".", "_")]
			box.position = point + right * lane_offset + Vector3.UP * 1.35
			box.respawn_seconds = respawn
			add_child(box)
			_item_boxes.append(box)
	print("NEON HARBOR ITEM BOXES PASS count=%d stations=%d respawn=%.1fs" % [_item_boxes.size(), ITEM_BOX_ROUTE_INDICES.size(), respawn])

func _build_race_route_with_runout() -> Array[Vector3]:
	var route := _route_points.duplicate()
	_append_finish_runout(route)
	return route

func _build_shortcut_route(skip_route_index: int) -> Array[Vector3]:
	var route: Array[Vector3] = []
	for index in range(_route_points.size()):
		if index != skip_route_index:
			route.append(_route_points[index])
	_append_finish_runout(route)
	return route

func _append_finish_runout(route: Array[Vector3]) -> void:
	if _route_points.size() < 2:
		return
	var finish := _route_points[-1]
	var previous := _route_points[-2]
	var direction := finish - previous
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	route.append(finish + direction.normalized() * FINISH_RUNOUT_DISTANCE)

func _apply_neon_player_pace(racer: WildDashCharacterController) -> void:
	if racer == null:
		return
	racer.max_speed *= PLAYER_MAX_SPEED_SCALE
	racer.cruise_speed *= PLAYER_CRUISE_SPEED_SCALE
	racer.acceleration *= PLAYER_ACCELERATION_SCALE
	print("NEON HARBOR PLAYER PACE max=%.2f cruise=%.2f accel=%.2f target=100-140s" % [racer.max_speed, racer.cruise_speed, racer.acceleration])

func _get_start_grid_offset(slot: int) -> Vector3:
	var row := slot / START_GRID_COLUMNS
	var column := slot % START_GRID_COLUMNS
	var center := float(START_GRID_COLUMNS - 1) * 0.5
	var stagger := 0.55 if row % 2 == 1 else 0.0
	return Vector3((float(column) - center) * START_GRID_X_SPACING + stagger, 0.1, float(row) * START_GRID_Z_SPACING)

func _orient_to_route(racer: WildDashCharacterController) -> void:
	if racer == null or _route_points.size() < 2:
		return
	var best_index := 0
	var best_distance := INF
	for index in range(_route_points.size() - 1):
		var distance := racer.global_position.distance_squared_to(_route_points[index])
		if distance < best_distance:
			best_distance = distance
			best_index = index
	var direction := _route_points[min(best_index + 1, _route_points.size() - 1)] - racer.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		racer.rotation.y = atan2(-direction.normalized().x, -direction.normalized().z)

func _configure_night_sun() -> void:
	var sun := get_node_or_null("Sun") as DirectionalLight3D
	if sun == null:
		return
	sun.light_color = Color(0.42, 0.55, 0.82)
	sun.light_energy = 0.32

func _on_any_racer_finished(_racer: Node3D, _rank: int) -> void:
	_finish_times.append(RaceManager.get_elapsed_seconds())

func _on_player_finished(rank: int) -> void:
	_player_rank = rank
	var elapsed := RaceManager.get_elapsed_seconds()
	print("NEON HARBOR PLAYER FINISH rank=%d elapsed=%.2fs checkpoints=%d/%d" % [rank, elapsed, RaceManager.get_checkpoint_progress(player), RaceManager.get_checkpoint_count()])
	if DisplayServer.get_name() == "headless":
		return
	var qualifying_rank := ceili(float(RaceManager.racers.size()) * 0.5)
	var success := rank > 0 and rank <= qualifying_rank
	finish_mode(success, rank, {
		"rank": rank,
		"racers": RaceManager.racers.size(),
		"finishers_at_player_finish": RaceManager.finish_order.size(),
		"checkpoints": RaceManager.get_checkpoint_count(),
		"track_length_m": RaceManager.get_track_length(),
		"item_boxes": _item_boxes.size(),
		"player_finish_seconds": elapsed,
		"shortcut_users": _shortcut_users,
		"shortcut_saving_m": _track.get_shortcut_a_saving(),
	})

func _on_race_completed() -> void:
	if _player_rank <= 0 and player != null:
		var index := RaceManager.finish_order.find(player)
		if index >= 0:
			_player_rank = index + 1
	var average_finish := 0.0
	for finish_time in _finish_times:
		average_finish += finish_time
	if not _finish_times.is_empty():
		average_finish /= float(_finish_times.size())
	var field_complete := RaceManager.get_elapsed_seconds()
	var qualifying_rank := ceili(float(RaceManager.racers.size()) * 0.5)
	var success := _player_rank > 0 and _player_rank <= qualifying_rank
	var average_fps := 0.0 if _fps_samples == 0 else _fps_sum / float(_fps_samples)
	print("NEON HARBOR COMPLETE racers=%d finishers=%d average_finish=%.2fs field_complete=%.2fs fps=%.1f" % [
		RaceManager.racers.size(), RaceManager.finish_order.size(), average_finish, field_complete, average_fps,
	])
	if RaceManager.racers.size() in [15, 18] and RaceManager.finish_order.size() == RaceManager.racers.size():
		print("NEON HARBOR %d RACERS ALL FINISH PASS" % RaceManager.racers.size())
	finish_mode(success, _player_rank, {
		"rank": _player_rank,
		"racers": RaceManager.racers.size(),
		"finishers": RaceManager.finish_order.size(),
		"checkpoints": RaceManager.get_checkpoint_count(),
		"track_length_m": RaceManager.get_track_length(),
		"item_boxes": _item_boxes.size(),
		"average_finish_seconds": average_finish,
		"field_complete_seconds": field_complete,
		"shortcut_users": _shortcut_users,
		"shortcut_saving_m": _track.get_shortcut_a_saving(),
	})
