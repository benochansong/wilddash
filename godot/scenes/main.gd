extends Node3D

@onready var player: WildDashCharacterController = $Dog

var _fps_min := 9999
var _fps_max := 0
var _fps_sum := 0.0
var _fps_samples := 0

func _ready() -> void:
	GameManager.configure_run(&"dog", &"chaos", {"head": 0, "body": 0, "tail": 0})
	RaceManager.race_finished.connect(_on_player_finished)
	RaceManager.race_completed.connect(_on_race_completed)
	print("WILD DASH 3D Vertical Slice 01 ready: Dog player + Rabbit/Elephant/Cat AI")

	# Let all CharacterBody3D instances settle onto the real collision floor before GO.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().create_timer(1.2).timeout
	RaceManager.start_race()

func _process(_delta: float) -> void:
	var fps := Engine.get_frames_per_second()
	if fps <= 0:
		return
	_fps_min = mini(_fps_min, fps)
	_fps_max = maxi(_fps_max, fps)
	_fps_sum += fps
	_fps_samples += 1

func _on_player_finished(rank: int) -> void:
	print("PLAYER FINISH rank=%d elapsed=%.2fs" % [rank, RaceManager.get_elapsed_seconds()])

func _on_race_completed() -> void:
	var labels: Array[String] = []
	for racer in RaceManager.finish_order:
		labels.append(RaceManager.get_racer_label(racer))
	var average_fps := 0.0 if _fps_samples == 0 else _fps_sum / _fps_samples
	print("RACE COMPLETE order=%s" % ", ".join(labels))
	print("FPS SAMPLE min=%d avg=%.1f max=%d (headless/CI values are not GPU benchmark data)" % [_fps_min, average_fps, _fps_max])

func _exit_tree() -> void:
	if player != null:
		RaceManager.unregister_racer(player)
