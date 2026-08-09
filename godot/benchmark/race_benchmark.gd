extends Node3D

const TRACK_SCENE: PackedScene = preload("res://tracks/test_track.tscn")
const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")
const CHASE_CAMERA_SCRIPT: Script = preload("res://camera/chase_camera.gd")
const AI_ANIMALS: Array[StringName] = [&"rabbit", &"elephant", &"cat", &"dog"]
const AI_SPEEDS: Array[float] = [10.8, 9.9, 10.5, 10.1]
const LANES: Array[float] = [-7.7, -5.5, -3.3, -1.1, 1.1, 3.3, 5.5, 7.7]
const MIN_RACERS := 10
const MAX_RACERS := 50
const WARMUP_SECONDS := 2.0
const SAMPLE_SECONDS := 8.0

var racers: Array[WildDashCharacterController] = []
var drivers: Array[WildDashAIController] = []

func _ready() -> void:
	RaceManager.clear_racers()
	var requested := 10
	if OS.has_environment("WILDDASH_RACER_COUNT"):
		requested = int(OS.get_environment("WILDDASH_RACER_COUNT"))
	var total_racers := clampi(requested, MIN_RACERS, MAX_RACERS)
	var profile := "optimized" if PerformanceManager.optimization_enabled else "baseline"

	var track := TRACK_SCENE.instantiate()
	track.name = "BenchmarkTrack"
	add_child(track)
	_add_sun()

	for i in range(total_racers):
		var lane_index := i % LANES.size()
		var row := i / LANES.size()
		var lane := LANES[lane_index]
		var start_z := 40.0 + float(row) * 2.6
		var racer := RACER_SCENE.instantiate() as WildDashCharacterController
		racer.name = "BenchmarkRacer_%02d" % (i + 1)
		racer.animal_id = AI_ANIMALS[i % AI_ANIMALS.size()]
		racer.is_player = false
		racer.movement_mode = WildDashCharacterController.MovementMode.RACE
		racer.position = Vector3(lane, 0.1, start_z)
		add_child(racer)
		racers.append(racer)

	var focus_racer: WildDashCharacterController = racers[0]
	for i in range(racers.size()):
		var driver := WildDashAIController.new()
		driver.name = "BenchmarkAI_%02d" % (i + 1)
		driver.racer_path = NodePath("../%s" % racers[i].name)
		driver.ai_mode = WildDashAIController.AIMode.RACE
		driver.target_speed = AI_SPEEDS[i % AI_SPEEDS.size()] - float(i / AI_SPEEDS.size()) * 0.03
		driver.preferred_lane = LANES[i % LANES.size()]
		driver.lane_wander = 0.08
		add_child(driver)
		driver.set_lod_anchor(focus_racer)
		drivers.append(driver)

	var camera := CHASE_CAMERA_SCRIPT.new() as Camera3D
	camera.name = "BenchmarkCamera"
	camera.current = true
	camera.fov = 70.0
	add_child(camera)
	camera.call("set_target", focus_racer)

	await get_tree().physics_frame
	await get_tree().physics_frame
	RaceManager.start_race()
	print("BENCHMARK RACE START profile=%s racers=%d" % [profile, total_racers])
	await get_tree().create_timer(WARMUP_SECONDS).timeout
	PerformanceManager.start_benchmark(profile, total_racers)
	await get_tree().create_timer(SAMPLE_SECONDS).timeout
	PerformanceManager.finish_benchmark()
	print("BENCHMARK RACE COMPLETE profile=%s racers=%d" % [profile, total_racers])
	get_tree().quit(0)

func _add_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "BenchmarkSun"
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
