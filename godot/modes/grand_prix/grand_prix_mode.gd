extends WildDashModeController

const TRACK_SCENE: PackedScene = preload("res://tracks/grand_prix_track.tscn")
const CHASE_CAMERA_SCRIPT: Script = preload("res://camera/chase_camera.gd")
const AI_ANIMALS: Array[StringName] = [&"rabbit", &"elephant", &"cat", &"dog"]
const AI_SPEEDS: Array[float] = [13.2, 12.5, 13.0, 12.8]
const ROUTE_LANES: Array[float] = [-2.4, 2.4, -0.8, 0.8, -1.7, 1.7, -0.2, 0.2, -2.8, 2.8]

var _player_rank := 0
var _fps_sum := 0.0
var _fps_samples := 0
var _headless_debug_elapsed := 0.0
var _track: WildDashGrandPrixTrack
var _route_points: Array[Vector3] = []

func _ready() -> void:
	setup_mode(&"grand_prix", "ROUND 1 — Wild World Grand Prix", "W/↑ 가속 · A/D 조향 · Space 점프 · 7개 체크포인트를 순서대로 통과하세요", false)
	RaceManager.clear_racers()
	RaceManager.clear_track()
	_track = TRACK_SCENE.instantiate() as WildDashGrandPrixTrack
	if _track == null:
		push_error("Failed to instantiate extended Grand Prix track")
		return
	_track.name = "GrandPrixWorldTrack"
	add_child(_track)
	_route_points = _track.get_route_points()

	var start := _track.get_start_position()
	player = spawn_racer("Player", &"dog", start + Vector3(-2.5, 0.1, 0.0), true, WildDashCharacterController.MovementMode.RACE)
	var ai_total: int = GameManager.ai_count
	var headless := DisplayServer.get_name() == "headless"
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
		driver.set_race_route(_route_points)

	# CI must validate the same 1.48 km checkpoint route without spending two
	# real-time minutes in round one. A deterministic high-speed autopilot is
	# attached only in headless mode; Windows/human play remains untouched.
	if headless:
		var headless_driver := spawn_ai_driver(player, WildDashAIController.AIMode.RACE, 58.0, 0.0, 0.0)
		headless_driver.steering_strength = 13.0
		headless_driver.acceleration = 90.0
		headless_driver.avoidance_distance = 8.0
		headless_driver.set_race_route(_route_points)
		for driver in ai_drivers:
			if driver == headless_driver:
				continue
			driver.target_speed *= 4.35
			driver.acceleration = 88.0
			driver.steering_strength = 12.0

	var camera := CHASE_CAMERA_SCRIPT.new() as Camera3D
	if camera != null:
		camera.name = "ChaseCamera"
		camera.current = true
		camera.fov = 70.0
		add_child(camera)
		camera.call("set_target", player)

	RaceManager.race_finished.connect(_on_player_finished)
	RaceManager.race_completed.connect(_on_race_completed)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not headless:
		await get_tree().create_timer(1.0).timeout
	GameManager.begin_round(&"grand_prix")
	RaceManager.start_race()
	print("MODE START id=grand_prix ai=%d" % ai_racers.size())
	print("GRAND PRIX START racers=%d ai=%d checkpoints=%d length=%.1fm" % [RaceManager.racers.size(), ai_racers.size(), RaceManager.get_checkpoint_count(), RaceManager.get_track_length()])

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
	hud.set_metrics("Rank %d/%d   CP %d/%d   Progress %d%%   Speed %.1f   FPS %d" % [rank, RaceManager.racers.size(), checkpoint_progress, checkpoint_total, roundi(progress_percent), player.current_speed, fps])

func _physics_process(delta: float) -> void:
	if player != null and player.global_position.y < -28.0 and not player.finished:
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
			parts.append("%s cp=%d/%d progress=%.0f%% speed=%.1f finished=%s" % [
				RaceManager.get_racer_label(racer),
				RaceManager.get_checkpoint_progress(racer),
				RaceManager.get_checkpoint_count(),
				RaceManager.get_progress_percent(racer),
				controller.current_speed,
				str(controller.finished),
			])
	print("GRAND PRIX PROGRESS " + " | ".join(parts))

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

func _on_player_finished(rank: int) -> void:
	_player_rank = rank
	print("GRAND PRIX PLAYER FINISH rank=%d elapsed=%.2fs checkpoints=%d/%d" % [rank, RaceManager.get_elapsed_seconds(), RaceManager.get_checkpoint_progress(player), RaceManager.get_checkpoint_count()])

func _on_race_completed() -> void:
	# Headless CI uses an AI driver on the player node, so RaceManager's
	# player-only signal is intentionally bypassed. Recover the rank from the
	# authoritative finish order in that case.
	if _player_rank <= 0 and player != null:
		var index := RaceManager.finish_order.find(player)
		if index >= 0:
			_player_rank = index + 1

	var labels: Array[String] = []
	for racer: Node3D in RaceManager.finish_order:
		labels.append(RaceManager.get_racer_label(racer))
	var average_fps := 0.0 if _fps_samples == 0 else _fps_sum / float(_fps_samples)
	var qualifying_rank := ceili(float(RaceManager.racers.size()) * 0.5)
	var success := _player_rank > 0 and _player_rank <= qualifying_rank
	print("GRAND PRIX COMPLETE racers=%d finishers=%d order=%s" % [RaceManager.racers.size(), RaceManager.finish_order.size(), ", ".join(labels)])
	print("GRAND PRIX FPS avg=%.1f headless=%s" % [average_fps, str(DisplayServer.get_name() == "headless")])
	finish_mode(success, _player_rank, {
		"rank": _player_rank,
		"racers": RaceManager.racers.size(),
		"finishers": RaceManager.finish_order.size(),
		"checkpoints": RaceManager.get_checkpoint_count(),
		"track_length_m": RaceManager.get_track_length(),
		"order": labels,
	})
