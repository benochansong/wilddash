extends WildDashModeController

const TRACK_SCENE: PackedScene = preload("res://tracks/grand_prix_track.tscn")
const ITEM_BOX_SCENE: PackedScene = preload("res://items/item_box.tscn")
const CHASE_CAMERA_SCRIPT: Script = preload("res://camera/chase_camera.gd")
const AI_ITEM_BRAIN_SCRIPT: Script = preload("res://items/ai_item_brain.gd")
const AI_ANIMALS: Array[StringName] = [&"rabbit", &"elephant", &"cat", &"dog"]
const AI_SPEEDS: Array[float] = [13.2, 12.5, 13.0, 12.8]
const ROUTE_LANES: Array[float] = [-2.4, 2.4, -0.8, 0.8, -1.7, 1.7, -0.2, 0.2, -2.8, 2.8]
# 11 stations x 3 lanes = 33 boxes. First station is ~144m from START and
# final station is just before Shortcut B, roughly 20-25 seconds from FINISH.
const ITEM_BOX_ROUTE_INDICES: Array[int] = [1, 3, 5, 7, 9, 11, 13, 15, 17, 21, 23]
const ITEM_BOX_LANE_OFFSETS: Array[float] = [-3.2, 0.0, 3.2]

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
var _player_recovery_locked := false
var _player_recoveries := 0

func _ready() -> void:
	var difficulty_name := WildDashDifficultySystem.get_display_name(GameManager.difficulty)
	setup_mode(
		&"grand_prix",
		"ROUND 1 — Wild World Grand Prix · %s" % difficulty_name,
		"W/↑ 가속 · A/D 조향 · Space 점프 · E/X 캐릭터 스킬 · Q/B 아이템 · 11개 체크포인트",
		false,
	)
	RaceManager.clear_racers()
	RaceManager.clear_track()
	ItemSystem.reset_runtime()
	_track = TRACK_SCENE.instantiate() as WildDashGrandPrixTrack
	if _track == null:
		push_error("Failed to instantiate 2.3km Grand Prix track")
		return
	_track.name = "GrandPrixWorldTrack"
	add_child(_track)
	_route_points = _track.get_route_points()

	var start := _track.get_start_position()
	player = spawn_racer("Player", &"dog", start + Vector3(-2.5, 0.1, 0.0), true, WildDashCharacterController.MovementMode.RACE)
	var ai_total: int = GameManager.ai_count
	var headless := DisplayServer.get_name() == "headless"
	_realtime_balance_run = headless and OS.has_environment("WILDDASH_REALTIME_BALANCE")
	for i in range(ai_total):
		var lane: float = ROUTE_LANES[i % ROUTE_LANES.size()]
		var animal: StringName = AI_ANIMALS[i % AI_ANIMALS.size()]
		var speed: float = AI_SPEEDS[i % AI_SPEEDS.size()] - float(i / AI_SPEEDS.size()) * 0.08
		var start_row := 1 + i / 5
		var spawn_position := start + Vector3(lane, 0.1, float(start_row) * 3.0)
		var racer := spawn_racer("AI_%02d" % (i + 1), animal, spawn_position, false, WildDashCharacterController.MovementMode.RACE)
		var driver := spawn_ai_driver(racer, WildDashAIController.AIMode.RACE, speed, lane, 0.10)
		driver.steering_strength = 5.8
		driver.acceleration = 22.0
		driver.avoidance_distance = 7.5

		var shortcut_choice := _choose_ai_shortcuts(animal, i)
		var use_a: bool = bool(shortcut_choice.a)
		var use_b: bool = bool(shortcut_choice.b)
		if use_a:
			_shortcut_a_users += 1
		if use_b:
			_shortcut_b_users += 1
		if use_a or use_b:
			driver.preferred_lane = clampf(lane * 0.32, -1.15, 1.15)
			driver.set_race_route(_track.get_shortcut_route(use_a, use_b))
			print("AI SHORTCUT ROUTE racer=%s animal=%s difficulty=%s A=%s B=%s savingA=%.1fm savingB=%.1fm" % [
				racer.name, String(animal), difficulty_name, str(use_a), str(use_b),
				_track.get_shortcut_a_saving(), _track.get_shortcut_b_saving(),
			])
		else:
			driver.set_race_route(_route_points)
		var item_brain := AI_ITEM_BRAIN_SCRIPT.new() as WildDashAIItemBrain
		item_brain.name = "%sItemBrain" % racer.name
		item_brain.configure(racer, driver)
		add_child(item_brain)
		_ai_item_brains.append(item_brain)

	_spawn_item_boxes()

	# Normal CI is intentionally accelerated. WILDDASH_REALTIME_BALANCE uses the
	# selected animal's real maximum speed so pacing reflects a human race rather
	# than the old 13.2m/s synthetic driver.
	if headless:
		var player_test_speed := player.max_speed if _realtime_balance_run else 40.0
		var headless_driver := spawn_ai_driver(player, WildDashAIController.AIMode.RACE, player_test_speed, 0.0, 0.0, true)
		headless_driver.steering_strength = 5.8 if _realtime_balance_run else 11.0
		headless_driver.acceleration = 24.0 if _realtime_balance_run else 72.0
		headless_driver.avoidance_distance = 7.5 if _realtime_balance_run else 8.5
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
				driver.target_speed *= 3.0
				driver.acceleration = 70.0
				driver.steering_strength = 10.5

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
	print("MODE START id=grand_prix ai=%d" % ai_racers.size())
	print("GRAND PRIX START racers=%d ai=%d checkpoints=%d length=%.1fm item_boxes=%d realtime_balance=%s difficulty=%s" % [
		RaceManager.racers.size(), ai_racers.size(), RaceManager.get_checkpoint_count(),
		RaceManager.get_track_length(), _item_boxes.size(), str(_realtime_balance_run), difficulty_name,
	])

func _choose_ai_shortcuts(animal: StringName, index: int) -> Dictionary:
	var difficulty := WildDashDifficultySystem.normalize(GameManager.difficulty)
	var use_a := false
	var use_b := false
	if animal == &"rabbit":
		# Rabbit is the natural specialist, but the physical roads are open to all.
		use_a = difficulty != WildDashDifficultySystem.CASUAL or WildDashDifficultySystem.should_take_shortcut(difficulty, index + 17)
		use_b = difficulty == WildDashDifficultySystem.HARD or WildDashDifficultySystem.should_take_shortcut(difficulty, index + 117)
	elif difficulty == WildDashDifficultySystem.HARD:
		# Hard rivals of every archetype occasionally take a risky line.
		use_a = (index % 5) == 2
		use_b = (index % 4) == 3
	elif difficulty == WildDashDifficultySystem.NORMAL:
		# Non-Rabbits prove shortcuts are not character locked, but use them much
		# less often than Rabbit so its mobility identity remains meaningful.
		use_a = animal == &"cat" and (index % 7) == 2
		use_b = animal == &"dog" and (index % 7) == 3
	return {"a": use_a, "b": use_b}

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
	hud.set_metrics("%s   Rank %d/%d   CP %d/%d   Progress %d%%   Speed %.1f   FPS %d" % [
		WildDashDifficultySystem.get_display_name(GameManager.difficulty), rank, RaceManager.racers.size(),
		checkpoint_progress, checkpoint_total, roundi(progress_percent), player.current_speed, fps,
	])
	hud.set_item_state(ItemSystem.get_display_name(player.get_held_item()), ItemSystem.get_status_text(player))

func _physics_process(delta: float) -> void:
	if RaceManager.active:
		for racer in RaceManager.racers.duplicate():
			RaceManager.sync_checkpoint_from_position(racer)
			RaceManager.sync_finish_from_position(racer)

	if player != null and player.global_position.y < -28.0 and not player.finished and not _player_recovery_locked:
		player.reset_motion(RaceManager.get_respawn_position(player))
		_orient_to_route(player)
		_player_recoveries += 1
		print("PLAYER TRACK RECOVERY checkpoint=%d difficulty=%s" % [
			RaceManager.get_checkpoint_progress(player), WildDashDifficultySystem.get_display_name(GameManager.difficulty),
		])
		if DisplayServer.get_name() != "headless":
			_start_player_recovery_penalty()

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
				RaceManager.get_racer_label(racer), RaceManager.get_checkpoint_progress(racer),
				RaceManager.get_checkpoint_count(), RaceManager.get_progress_percent(racer),
				controller.current_speed, ItemSystem.get_display_name(controller.get_held_item()),
				controller.skill_cooldown_remaining, str(controller.finished),
			])
	print("GRAND PRIX PROGRESS " + " | ".join(parts))

func _start_player_recovery_penalty() -> void:
	if _player_recovery_locked or player == null:
		return
	_player_recovery_locked = true
	var penalty := float(WildDashDifficultySystem.get_profile(GameManager.difficulty).recovery_penalty)
	player.current_speed = 0.0
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	print("PLAYER RECOVERY PENALTY seconds=%.2f difficulty=%s" % [penalty, WildDashDifficultySystem.get_display_name(GameManager.difficulty)])
	await get_tree().create_timer(penalty).timeout
	if is_instance_valid(player) and not player.finished:
		player.set_physics_process(true)
	_player_recovery_locked = false

func _spawn_item_boxes() -> void:
	for route_index in ITEM_BOX_ROUTE_INDICES:
		if route_index <= 0 or route_index >= _route_points.size() - 1:
			continue
		var point := _route_points[route_index]
		var tangent := _route_points[route_index + 1] - _route_points[route_index - 1]
		tangent.y = 0.0
		if tangent.length_squared() <= 0.001:
			tangent = Vector3.FORWARD
		else:
			tangent = tangent.normalized()
		var right := Vector3(-tangent.z, 0.0, tangent.x)
		for lane_offset in ITEM_BOX_LANE_OFFSETS:
			var box := ITEM_BOX_SCENE.instantiate() as WildDashItemBox
			if box == null:
				continue
			box.name = "ItemBox_R%02d_L%s" % [route_index, str(lane_offset).replace("-", "N").replace(".", "_")]
			box.position = point + right * lane_offset + Vector3.UP * 1.35
			add_child(box)
			_item_boxes.append(box)
	print("GRAND PRIX ITEM BOXES READY count=%d stations=%d respawn=5s first_route=%d final_route=%d" % [
		_item_boxes.size(), ITEM_BOX_ROUTE_INDICES.size(), ITEM_BOX_ROUTE_INDICES[0], ITEM_BOX_ROUTE_INDICES[-1],
	])

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

func _on_any_racer_finished(_racer: Node3D, _rank: int) -> void:
	_finish_times.append(RaceManager.get_elapsed_seconds())

func _on_player_finished(rank: int) -> void:
	_player_rank = rank
	print("GRAND PRIX PLAYER FINISH rank=%d elapsed=%.2fs checkpoints=%d/%d" % [
		rank, RaceManager.get_elapsed_seconds(), RaceManager.get_checkpoint_progress(player), RaceManager.get_checkpoint_count(),
	])

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
	var decisions := 0
	var overtakes := 0
	var rank_changes := 0
	var mistakes := 0
	var ai_recoveries := 0
	for brain in ai_competition_brains:
		var telemetry := brain.get_telemetry()
		decisions += int(telemetry.decisions)
		overtakes += int(telemetry.overtakes)
		rank_changes += int(telemetry.rank_changes)
		mistakes += int(telemetry.mistakes)
		ai_recoveries += int(telemetry.recoveries)
	var item_uses := 0
	for item_brain in _ai_item_brains:
		item_uses += item_brain.get_use_count()
	print("GRAND PRIX COMPLETE racers=%d finishers=%d order=%s" % [RaceManager.racers.size(), RaceManager.finish_order.size(), ", ".join(labels)])
	print("GRAND PRIX FPS avg=%.1f headless=%s" % [average_fps, str(DisplayServer.get_name() == "headless")])
	print("DIFFICULTY TELEMETRY mode=%s decisions=%d overtakes=%d rank_changes=%d mistakes=%d ai_recoveries=%d player_recoveries=%d item_uses=%d shortcutA_users=%d shortcutB_users=%d" % [
		WildDashDifficultySystem.get_display_name(GameManager.difficulty), decisions, overtakes, rank_changes,
		mistakes, ai_recoveries, _player_recoveries, item_uses, _shortcut_a_users, _shortcut_b_users,
	])
	print("EXTENDED RACE TELEMETRY average_finish=%.2fs field_complete=%.2fs target_player=130-170 length=%.1fm shortcutA=%.1fm shortcutB=%.1fm" % [
		average_finish, field_complete, RaceManager.get_track_length(), _track.get_shortcut_a_saving(), _track.get_shortcut_b_saving(),
	])
	finish_mode(success, _player_rank, {
		"rank": _player_rank,
		"racers": RaceManager.racers.size(),
		"finishers": RaceManager.finish_order.size(),
		"checkpoints": RaceManager.get_checkpoint_count(),
		"track_length_m": RaceManager.get_track_length(),
		"item_boxes": _item_boxes.size(),
		"average_finish_seconds": average_finish,
		"field_complete_seconds": field_complete,
		"shortcut_a_users": _shortcut_a_users,
		"shortcut_b_users": _shortcut_b_users,
		"shortcut_a_saving_m": _track.get_shortcut_a_saving(),
		"shortcut_b_saving_m": _track.get_shortcut_b_saving(),
		"difficulty": String(GameManager.difficulty),
		"rank_changes": rank_changes,
		"overtake_attempts": overtakes,
		"item_uses": item_uses,
		"order": labels,
	})
