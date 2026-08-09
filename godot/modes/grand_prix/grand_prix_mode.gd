extends WildDashModeController

const TRACK_SCENE: PackedScene = preload("res://tracks/test_track.tscn")
const CHASE_CAMERA_SCRIPT: Script = preload("res://camera/chase_camera.gd")
const AI_ANIMALS: Array[StringName] = [&"rabbit", &"elephant", &"cat", &"dog"]
const AI_SPEEDS: Array[float] = [10.8, 9.9, 10.5, 10.1]
const SAFE_LANES: Array[float] = [-7.2, 7.2, 5.5, -8.0, -5.8, 6.2, 7.8, -7.8, 4.9, -6.6]

var _player_rank := 0
var _fps_sum := 0.0
var _fps_samples := 0
var _headless_debug_elapsed := 0.0

func _ready() -> void:
	setup_mode(&"grand_prix", "ROUND 1 — Wild World Grand Prix", "W/↑ 또는 패드로 가속 · 좌우 조향 · Space/A 점프", false)
	RaceManager.clear_racers()
	var track := TRACK_SCENE.instantiate()
	track.name = "TestTrack"
	add_child(track)

	var selected := GameManager.selected_animal
	player = spawn_racer(String(selected).capitalize(), selected, Vector3(-5.8, 0.1, 40.0), true, WildDashCharacterController.MovementMode.RACE)
	var ai_total: int = GameManager.ai_count
	for i in range(ai_total):
		var lane: float = SAFE_LANES[i % SAFE_LANES.size()]
		var animal: StringName = AI_ANIMALS[i % AI_ANIMALS.size()]
		var speed: float = AI_SPEEDS[i % AI_SPEEDS.size()] - float(i / AI_SPEEDS.size()) * 0.12
		var start_row: int = 1 if i >= 3 else 0
		var start_z := 40.0 + float(start_row) * 3.2 + float(i / SAFE_LANES.size()) * 1.6
		var racer := spawn_racer("AI_%02d" % (i + 1), animal, Vector3(lane, 0.1, start_z), false, WildDashCharacterController.MovementMode.RACE)
		spawn_ai_driver(racer, WildDashAIController.AIMode.RACE, speed, lane, 0.12)

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
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(1.0).timeout
	GameManager.begin_round(&"grand_prix")
	RaceManager.start_race()
	print("RC_FLOW Race")
	print("MODE START id=grand_prix ai=%d" % ai_racers.size())
	print("GRAND PRIX START racers=%d ai=%d" % [RaceManager.racers.size(), ai_racers.size()])

func _process(_delta: float) -> void:
	if player == null:
		return
	var fps: int = Engine.get_frames_per_second()
	if fps > 0:
		_fps_sum += float(fps)
		_fps_samples += 1
	var rank: int = RaceManager.get_rank(player)
	hud.set_metrics("Rank %d/%d   Speed %.1f   FPS %d" % [rank, RaceManager.racers.size(), player.current_speed, fps])

func _physics_process(delta: float) -> void:
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
			parts.append("%s x=%.1f z=%.1f speed=%.1f finished=%s" % [
				RaceManager.get_racer_label(racer), controller.global_position.x,
				controller.global_position.z, controller.current_speed, str(controller.finished),
			])
	print("GRAND PRIX PROGRESS " + " | ".join(parts))

func _on_player_finished(rank: int) -> void:
	_player_rank = rank
	AudioManager.play_sfx_id("finish")
	print("GRAND PRIX PLAYER FINISH rank=%d elapsed=%.2fs" % [rank, RaceManager.get_elapsed_seconds()])

func _on_race_completed() -> void:
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
		"order": labels,
	})
