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
	if length < 2200.0 or length > 2600.0:
		_fail("Track length outside 2200-2600m target: %.1f" % length)
		return
	if route.size() < 26 or route.size() > 32:
		_fail("Route point target is 26-32, got %d" % route.size())
		return
	print("GRAND PRIX TRACK LOAD PASS points=%d length=%.1fm" % [route.size(), length])
	print("TRACK LENGTH PASS 2200-2600m actual=%.1fm" % length)

	if RaceManager.get_checkpoint_count() < 10:
		_fail("Expected at least ten ordered checkpoints")
		return
	print("CHECKPOINT PASS count=%d" % RaceManager.get_checkpoint_count())

	if not _route_is_valid(route):
		_fail("Main player route contains an invalid segment")
		return
	print("PLAYER ROUTE VALID PASS points=%d" % route.size())

	var saving_a := track.get_shortcut_a_saving()
	var saving_b := track.get_shortcut_b_saving()
	var time_a := saving_a / 14.0
	var time_b := saving_b / 14.0
	if time_a < 3.0 or time_a > 7.0 or track.get_node_or_null("RiskyShortcutA") == null:
		_fail("Shortcut A is outside 3-7 second target or missing geometry")
		return
	if time_b < 3.0 or time_b > 7.0 or track.get_node_or_null("ComebackShortcutB") == null:
		_fail("Shortcut B is outside 3-7 second target or missing geometry")
		return
	var route_a := track.get_shortcut_route(true, false)
	var route_b := track.get_shortcut_route(false, true)
	var route_ab := track.get_shortcut_route(true, true)
	if route_a.size() != route.size() - 1 or route_b.size() != route.size() - 1 or route_ab.size() != route.size() - 2:
		_fail("Shortcut route variants are malformed")
		return
	print("SHORTCUT A PASS saving=%.1fm estimated=%.2fs open_to_all=true" % [saving_a, time_a])
	print("SHORTCUT B PASS saving=%.1fm estimated=%.2fs open_to_all=true" % [saving_b, time_b])

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

	if not RaceManager.can_finish(racer):
		_fail("Finish remained blocked after all checkpoints")
		return
	var rank := RaceManager.record_finish(racer)
	if rank != 1:
		_fail("Validated finish did not record rank 1")
		return
	print("FINISH VALIDATION PASS checkpoints=%d rank=%d" % [RaceManager.get_checkpoint_progress(racer), rank])
	print("EXTENDED GRAND PRIX TRACK PASS length=%.1fm points=%d checkpoints=%d shortcuts=2" % [
		length, route.size(), RaceManager.get_checkpoint_count(),
	])
	get_tree().quit(0)

func _route_is_valid(route: Array[Vector3]) -> bool:
	if route.size() < 2:
		return false
	for i in range(route.size() - 1):
		var segment_length := route[i].distance_to(route[i + 1])
		if segment_length < 20.0 or segment_length > 180.0:
			return false
	return true

func _fail(message: String) -> void:
	push_error(message)
	print("GRAND PRIX TRACK FAIL " + message)
	get_tree().quit(1)
