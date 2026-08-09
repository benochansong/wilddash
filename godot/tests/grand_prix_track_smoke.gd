extends Node

const TRACK_SCENE: PackedScene = preload("res://tracks/grand_prix_track.tscn")
const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")

func _ready() -> void:
	RaceManager.clear_racers()
	RaceManager.clear_track()
	var track := TRACK_SCENE.instantiate() as WildDashGrandPrixTrack
	if track == null:
		_fail("Grand Prix track scene failed to instantiate")
		return
	add_child(track)
	await get_tree().physics_frame

	var length := track.get_track_length()
	var route := track.get_route_points()
	if route.size() < 17 or length < 1400.0:
		_fail("Extended track is too short: points=%d length=%.1f" % [route.size(), length])
		return
	if RaceManager.get_checkpoint_count() != 7:
		_fail("Expected seven ordered checkpoints")
		return
	print("GRAND PRIX TRACK LOAD PASS points=%d length=%.1fm" % [route.size(), length])

	var racer := RACER_SCENE.instantiate() as WildDashCharacterController
	racer.name = "CheckpointTester"
	racer.is_player = true
	racer.movement_mode = WildDashCharacterController.MovementMode.RACE
	racer.position = track.get_start_position() + Vector3.UP
	add_child(racer)
	await get_tree().physics_frame
	RaceManager.start_race()

	if RaceManager.can_finish(racer):
		_fail("Finish should be blocked before checkpoints")
		return
	if RaceManager.record_checkpoint(racer, 1):
		_fail("Out-of-order checkpoint was accepted")
		return
	for checkpoint_index in range(RaceManager.get_checkpoint_count()):
		if not RaceManager.record_checkpoint(racer, checkpoint_index):
			_fail("Ordered checkpoint %d failed" % (checkpoint_index + 1))
			return
	print("CHECKPOINT PASS count=%d" % RaceManager.get_checkpoint_count())

	if not RaceManager.can_finish(racer):
		_fail("Finish remained blocked after all checkpoints")
		return
	var rank := RaceManager.record_finish(racer)
	if rank != 1:
		_fail("Validated finish did not record rank 1")
		return
	print("FINISH VALIDATION PASS checkpoints=%d rank=%d" % [RaceManager.get_checkpoint_progress(racer), rank])
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	print("GRAND PRIX TRACK FAIL " + message)
	get_tree().quit(1)
