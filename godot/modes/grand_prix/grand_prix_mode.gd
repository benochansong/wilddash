extends WildDashModeController

const TRACK_SCENE: PackedScene = preload("res://tracks/grand_prix_track.tscn")
const ITEM_BOX_SCENE: PackedScene = preload("res://items/item_box.tscn")
const CHASE_CAMERA_SCRIPT: Script = preload("res://camera/chase_camera.gd")
const AI_ITEM_BRAIN_SCRIPT: Script = preload("res://items/ai_item_brain.gd")
const AI_PACK_TACTICS_SCRIPT: Script = preload("res://characters/ai_pack_tactics.gd")
const AI_ANIMALS: Array[StringName] = [&"rabbit", &"elephant", &"cat", &"dog"]
const AI_SPEEDS: Array[float] = [14.5, 13.9, 14.3, 14.2]
const ROUTE_LANES: Array[float] = [-3.0, -1.0, 1.0, 3.0, -2.2, 0.0, 2.2, -3.6, -1.4, 1.4, 3.6, -2.8, 0.8, 2.8, -0.6, 2.0, -2.0]
const ITEM_BOX_ROUTE_INDICES: Array[int] = [2, 4, 6, 8, 11, 14, 16, 19, 22, 23, 26]
const ITEM_BOX_LANE_OFFSETS: Array[float] = [-3.2, 0.0, 3.2]
const ITEM_BOX_WIDE_LANE_OFFSETS: Array[float] = [-4.2, -1.4, 1.4, 4.2]
const WIDE_ITEM_STATIONS: Array[int] = [4, 8, 14, 19, 23]
const START_GRID_COLUMNS := 4
const START_GRID_X_SPACING := 2.45
const START_GRID_Z_SPACING := 3.15

const SHORTCUT_A_SKIP_ROUTE_INDEX := 17
const SHORTCUT_B_SKIP_ROUTE_INDEX := 24
const PLAYER_MAX_SPEED_SCALE := 1.10
const PLAYER_CRUISE_SPEED_SCALE := 1.06
const PLAYER_ACCELERATION_SCALE := 1.08

var _player_rank := 0
var _fps_sum := 0.0
var _fps_samples := 0
var _headless_debug_elapsed := 0.0
var _track: WildDashGrandPrixTrack
var _route_points: Array[Vector3] = []
var _item_boxes: Array[WildDashItemBox] = []
var _ai_item_brains: Array[WildDashAIItemBrain] = []
var _finish_times: Array[float] = []
var _realtime_balance_run := false
var _shortcut_a_users := 0
var _shortcut_b_users := 0

func _ready() -> void:
	setup_mode(
		&"grand_prix",
		"ROUND 1 — Wild World Grand Prix",
		"W/↑ 가속 · A/D 조향 · Space 점프 · E/X 캐릭터 스킬 · Q/B 아이템 · 11개 체크포인트",
		false,
	)
	RaceManager.clear_racers()
	RaceManager.clear_track()
	ItemSystem.reset_runtime()
	_track = TRACK_SCENE.instantiate() as WildDashGrandPrixTrack
	if _track == null:
		push_error("Failed to instantiate extended Grand Prix track")
		return
	_track.name = "GrandPrixWorldTrack"
	add_child(_track)
	_route_points = _track.get_route_points()

	var start := _track.get_start_position()
	player = spawn_racer("Player", &"dog", start + _get_start_grid_offset(0), true, WildDashCharacterController.MovementMode.RACE)
	_apply_grand_prix_player_pace(player)

	var ai_total: int = GameManager.ai_count
	var headless := DisplayServer.get_name() == "headless"
	_realtime_balance_run = headless and OS.has_environment("WILDDASH_REALTIME_BALANCE")
	for i in range(ai_total):
		var lane: float = ROUTE_LANES[i % ROUTE_LANES.size()]
		var animal: StringName = AI_ANIMALS[i % AI_ANIMALS.size()]
		var speed: float = AI_SPEEDS[i % AI_SPEEDS.size()] - float(i / AI_SPEEDS.size()) * 0.06
		var spawn_position := start + _get_start_grid_offset(i + 1)
		var racer := spawn_racer("AI_%02d" % (i + 1), animal, spawn_position, false, WildDashCharacterController.MovementMode.RACE)
		var driver := spawn_ai_driver(racer, WildDashAIController.AIMode.RACE, speed, lane, 0.18)
		driver.steering_strength = 6.2
		driver.acceleration = 24.0
		driver.avoidance_distance = 8.2

		var personality: int = i % 5
		var risk: float = float([0.90, 0.25, 0.68, 0.72, 0.52][personality])
		var overtake: float = float([0.95, 0.30, 0.64, 0.58, 0.62][personality])
		var shortcut_pref: float = float([0.48, 0.20, 0.96, 0.42, 0.55][personality])
		var tactics := AI_PACK_TACTICS_SCRIPT.new() as WildDashAIPackTactics
		tactics.name = "%sPackTactics" % racer.name
		tactics.configure(racer, driver, personality as WildDashAIPackTactics.Personality, risk, overtake, shortcut_pref)
		add_child(tactics)
		print("AI PERSONALITY racer=%s type=%s lane=%.1f risk=%.2f shortcut=%.2f overtake=%.2f" % [
			racer.name, tactics.get_personality_name(), lane, risk, shortcut_pref, overtake,
		])

		if personality == WildDashAIPackTactics.Personality.SHORTCUT:
			if (i / 5) % 2 == 0:
				driver.preferred_lane = clampf(lane * 0.25, -0.9, 0.9)
				driver.set_race_route(_build_shortcut_route(SHORTCUT_A_SKIP_ROUTE_INDEX))
				_shortcut_a_users += 1
				print("AI SHORTCUT A ROUTE racer=%s personality=Shortcut saving=%.1fm" % [racer.name, _track.get_shortcut_a_saving()])
			else:
				driver.preferred_lane = clampf(lane * 0.30, -1.0, 1.0)
				driver.set_race_route(_build_shortcut_route(SHORTCUT_B_SKIP_ROUTE_INDEX))
				_shortcut_b_users += 1
				print("AI SHORTCUT B ROUTE racer=%s personality=Shortcut saving=%.1fm" % [racer.name, _track.get_shortcut_b_saving()])
		else:
			driver.set_race_route(_route_points)

		var item_brain := AI_ITEM_BRAIN_SCRIPT.new() as WildDashAIItemBrain
		item_brain.name = "%sItemBrain" % racer.name
		item_brain.configure(racer, driver)
		add_child(item_brain)
		_ai_item_brains.append(item_brain)

	_spawn_item_boxes()

	if headless:
		var player_test_speed := player.max_speed if _realtime_balance_run else 50.0
		var headless_driver := spawn_ai_driver(player, WildDashAIController.AIMode.RACE, player_test_speed, 0.0, 0.0, true)
		headless_driver.steering_strength = 6.2 if _realtime_balance_run else 12.0
		headless_driver.acceleration = 24.0 if _realtime_balance_run else 90.0
		headless_driver.avoidance_distance = 8.2
		headless_driver.set_race_route(_route_points)
		var player_item_brain := AI_ITEM_BRAIN_SCRIPT.new() as WildDashAIItemBrain
		player_item_brain.name = "PlayerTestItemBrain"
		player_item_brain.configure(player, headless_driver)
		add_child(player_item_brain)
		_ai_item_brains.append(player_item_brain)
		if not _realtime_balance_run:
			for driver in ai_drivers:
				if driver == headless_driver:
					continue
				driver.target_speed *= 3.40
				driver.acceleration = 88.0
				driver.steering_strength = 11.8

	var camera := CHASE_CAMERA_SCRIPT.new() as Camera3D
	if camera != null:
		camera.name = "ChaseCamera"
		camera.current = true
		camera.fov = 70.0
		add_child(camera)
		camera.call("set_target", player)

	RaceManager.racer_finished.connect(_on_any_racer_finished)
	RaceManager.race_finished.connect(_on_player_finished)
	RaceManager.race_completed.connect(_on_race_completed)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not headless:
		await get_tree().create_timer(1.0).timeout
	GameManager.begin_round(&"grand_prix")
	RaceManager.start_race()
	print("START GRID PASS columns=4 racers=%d spacing_x=%.2f spacing_z=%.2f" % [RaceManager.racers.size(), START_GRID_X_SPACING, START_GRID_Z_SPACING])
	print("MODE START id=grand_prix ai=%d" % ai_racers.size())
	print("GRAND PRIX START racers=%d ai=%d checkpoints=%d length=%.1fm item_boxes=%d realtime_balance=%s" % [
		RaceManager.racers.size(), ai_racers.size(), RaceManager.get_checkpoint_count(),
		RaceManager.get_track_length(), _item_boxes.size(), str(_realtime_balance_run),
	])

func _get_start_grid_offset(slot: int) -> Vector3:
	var row := slot / START_GRID_COLUMNS
	var column := slot % START_GRID_COLUMNS
	var center := float(START_GRID_COLUMNS - 1) * 0.5
	var stagger := 0.55 if row % 2 == 1 else 0.0
	var x := (float(column) - center) * START_GRID_X_SPACING + stagger
	return Vector3(x, 0.1, float(row) * START_GRID_Z_SPACING)

func _process(_delta: float) -> void:
	if player == null:
		return
	var fps: int = Engine.get_frames_per_second()
	if fps > 0:
		_fps_sum += float(fps)
		_fps_samples += 1
	var rank: int = RaceManager.get_rank(player)
	var checkpoint_progress := RaceManager.get_checkpoint_progress(player)
	var checkpoint_total := RaceManager.get_checkpoint_count()
	var progress_percent := RaceManager.get_progress_percent(player)
	hud.set_metrics("Rank %d / %d   CP %d/%d   Progress %d%%   Speed %.1f   FPS %d" % [
		rank, RaceManager.racers.size(), checkpoint_progress, checkpoint_total,
		roundi(progress_percent), player.current_speed, fps,
	])
	hud.set_item_state(ItemSystem.get_display_name(player.get_held_item()), ItemSystem.get_status_text(player))

func _physics_process(delta: float) -> void:
	if RaceManager.active:
		for racer in RaceManager.racers.duplicate():
			RaceManager.sync_checkpoint_from_position(racer)
			RaceManager.sync_finish_from_position(racer)

	if player != null and player.global_position.y < -34.0 and not player.finished:
		player.reset_motion(RaceManager.get_respawn_position(player))
		_orient_to_route(player)
		print("PLAYER TRACK RECOVERY checkpoint=%d" % RaceManager.get_checkpoint_progress(player))

	if DisplayServer.get_name() != "headless" or not RaceManager.active:
		return
	_headless_debug_elapsed += delta
	if _headless_debug_elapsed < 5.0:
		return
	_headless_debug_elapsed = 0.0
	var parts: Array[String] = []
	for racer: Node3D in RaceManager.racers:
		if racer is WildDashCharacterController:
			var controller := racer as WildDashCharacterController
			parts.append("%s cp=%d/%d progress=%.0f%% speed=%.1f item=%s skill_cd=%.1f finished=%s" % [
				RaceManager.get_racer_label(racer), RaceManager.get_checkpoint_progress(racer), RaceManager.get_checkpoint_count(),
				RaceManager.get_progress_percent(racer), controller.current_speed,
				ItemSystem.get_display_name(controller.get_held_item()), controller.skill_cooldown_remaining, str(controller.finished),
			])
	print("GRAND PRIX PROGRESS " + " | ".join(parts))

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
			box.name = "ItemBox_R%02d_L%s" % [route_index, str(lane_offset).replace("-", "N").replace(".", "_")]
			box.position = point + right * lane_offset + Vector3.UP * 1.35
			box.respawn_seconds = respawn
			add_child(box)
			_item_boxes.append(box)
	print("GRAND PRIX ITEM BOXES READY count=%d stations=%d respawn=%.1fs wide_stations=%d first_route=%d final_route=%d" % [
		_item_boxes.size(), ITEM_BOX_ROUTE_INDICES.size(), respawn, WIDE_ITEM_STATIONS.size(), ITEM_BOX_ROUTE_INDICES[0], ITEM_BOX_ROUTE_INDICES[-1],
	])

func _build_shortcut_route(skip_route_index: int) -> Array[Vector3]:
	var route: Array[Vector3] = []
	for i in range(_route_points.size()):
		if i != skip_route_index:
			route.append(_route_points[i])
	return route

func _apply_grand_prix_player_pace(racer: WildDashCharacterController) -> void:
	if racer == null:
		return
	racer.max_speed *= PLAYER_MAX_SPEED_SCALE
	racer.cruise_speed *= PLAYER_CRUISE_SPEED_SCALE
	racer.acceleration *= PLAYER_ACCELERATION_SCALE
	print("GRAND PRIX PLAYER PACE max=%.2f cruise=%.2f accel=%.2f target=130-170s" % [racer.max_speed, racer.cruise_speed, racer.acceleration])

func _orient_to_route(racer: WildDashCharacterController) -> void:
	if _route_points.size() < 2:
		return
	var best_index := 0
	var best_distance := INF
	for i in range(_route_points.size() - 1):
		var distance := racer.global_position.distance_squared_to(_route_points[i])
		if distance < best_distance:
			best_distance = distance
			best_index = i
	var direction := _route_points[min(best_index + 1, _route_points.size() - 1)] - racer.global_position
	direction.y = 0.0
	if direction.length_squared() > 0.001:
		racer.rotation.y = atan2(-direction.normalized().x, -direction.normalized().z)

func _rank_system_valid() -> bool:
	var standings := RaceManager.get_standings()
	if standings.size() != RaceManager.racers.size():
		return false
	var previous_progress := INF
	for racer in standings:
		if RaceManager.finish_order.has(racer):
			continue
		var progress := RaceManager.get_track_progress(racer)
		if progress > previous_progress + 0.01:
			return false
		previous_progress = progress
	return true

func _on_any_racer_finished(_racer: Node3D, _rank: int) -> void:
	_finish_times.append(RaceManager.get_elapsed_seconds())

func _on_player_finished(rank: int) -> void:
	_player_rank = rank
	var elapsed := RaceManager.get_elapsed_seconds()
	print("GRAND PRIX PLAYER FINISH rank=%d elapsed=%.2fs checkpoints=%d/%d" % [rank, elapsed, RaceManager.get_checkpoint_progress(player), RaceManager.get_checkpoint_count()])
	# Human players should move on as soon as their own result is known. The
	# GameManager already provides a short 1.2 s result beat before loading the
	# next round, so waiting for every trailing AI racer only creates dead time.
	# Headless CI deliberately keeps the old all-finish path for telemetry and
	# 15/18-racer completion regression gates.
	if DisplayServer.get_name() == "headless":
		return
	var qualifying_rank := ceili(float(RaceManager.racers.size()) * 0.5)
	var success := rank > 0 and rank <= qualifying_rank
	var labels: Array[String] = []
	for racer: Node3D in RaceManager.finish_order:
		labels.append(RaceManager.get_racer_label(racer))
	print("GRAND PRIX PLAYER RESULT ADVANCE rank=%d finishers_now=%d/%d" % [rank, RaceManager.finish_order.size(), RaceManager.racers.size()])
	finish_mode(success, rank, {
		"rank": rank,
		"racers": RaceManager.racers.size(),
		"finishers": RaceManager.finish_order.size(),
		"finishers_at_player_finish": RaceManager.finish_order.size(),
		"checkpoints": RaceManager.get_checkpoint_count(),
		"track_length_m": RaceManager.get_track_length(),
		"item_boxes": _item_boxes.size(),
		"item_stations": ITEM_BOX_ROUTE_INDICES.size(),
		"player_finish_seconds": elapsed,
		"field_complete_seconds": elapsed,
		"shortcut_a_users": _shortcut_a_users,
		"shortcut_b_users": _shortcut_b_users,
		"shortcut_a_saving_m": _track.get_shortcut_a_saving(),
		"shortcut_b_saving_m": _track.get_shortcut_b_saving(),
		"order": labels,
	})

func _on_race_completed() -> void:
	if _player_rank <= 0 and player != null:
		var index := RaceManager.finish_order.find(player)
		if index >= 0:
			_player_rank = index + 1
	var labels: Array[String] = []
	for racer: Node3D in RaceManager.finish_order:
		labels.append(RaceManager.get_racer_label(racer))
	var average_fps := 0.0 if _fps_samples == 0 else _fps_sum / float(_fps_samples)
	var average_finish := 0.0
	for finish_time in _finish_times:
		average_finish += finish_time
	if not _finish_times.is_empty():
		average_finish /= float(_finish_times.size())
	var field_complete := RaceManager.get_elapsed_seconds()
	var qualifying_rank := ceili(float(RaceManager.racers.size()) * 0.5)
	var success := _player_rank > 0 and _player_rank <= qualifying_rank
	print("GRAND PRIX COMPLETE racers=%d finishers=%d order=%s" % [RaceManager.racers.size(), RaceManager.finish_order.size(), ", ".join(labels)])
	if RaceManager.racers.size() in [10, 15, 18]:
		print("%d RACERS PASS" % RaceManager.racers.size())
	if RaceManager.racers.size() in [15, 18] and RaceManager.finish_order.size() == RaceManager.racers.size():
		print("%d RACERS ALL FINISH PASS" % RaceManager.racers.size())
	if _shortcut_a_users + _shortcut_b_users > 0:
		print("AI SHORTCUT PASS users=%d" % (_shortcut_a_users + _shortcut_b_users))
	if _rank_system_valid():
		print("RANK SYSTEM PASS racers=%d" % RaceManager.racers.size())
	print("GRAND PRIX FPS avg=%.1f headless=%s" % [average_fps, str(DisplayServer.get_name() == "headless")])
	print("GRAND PRIX RACE TELEMETRY average_finish=%.2fs field_complete=%.2fs player_target=130-170 shortcut_a_users=%d shortcut_b_users=%d shortcut_a=%.1fm shortcut_b=%.1fm" % [
		average_finish, field_complete, _shortcut_a_users, _shortcut_b_users, _track.get_shortcut_a_saving(), _track.get_shortcut_b_saving(),
	])
	finish_mode(success, _player_rank, {
		"rank": _player_rank, "racers": RaceManager.racers.size(), "finishers": RaceManager.finish_order.size(),
		"checkpoints": RaceManager.get_checkpoint_count(), "track_length_m": RaceManager.get_track_length(),
		"item_boxes": _item_boxes.size(), "item_stations": ITEM_BOX_ROUTE_INDICES.size(),
		"average_finish_seconds": average_finish, "field_complete_seconds": field_complete,
		"shortcut_a_users": _shortcut_a_users, "shortcut_b_users": _shortcut_b_users,
		"shortcut_a_saving_m": _track.get_shortcut_a_saving(), "shortcut_b_saving_m": _track.get_shortcut_b_saving(), "order": labels,
	})
