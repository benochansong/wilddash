extends Node

const TRACK_SCENE: PackedScene = preload("res://tracks/neon_harbor_track.tscn")

func _ready() -> void:
	var track: WildDashNeonHarborTrack = TRACK_SCENE.instantiate() as WildDashNeonHarborTrack
	if track == null:
		_fail("track instantiate failed")
		return
	add_child(track)
	await get_tree().process_frame
	await get_tree().physics_frame

	var route: Array[Vector3] = track.get_route_points()
	var checkpoints: Array[Vector3] = track.get_checkpoint_positions()
	var length: float = track.get_track_length()

	if route.size() != 30:
		_fail("expected 30 route points, got %d" % route.size())
		return
	if checkpoints.size() != 9:
		_fail("expected 9 checkpoints, got %d" % checkpoints.size())
		return
	if length < 1350.0 or length > 1550.0:
		_fail("track length %.1f outside 1350..1550m" % length)
		return
	for point: Vector3 in route:
		if absf(point.y) > 0.5:
			_fail("route is not grounded: y=%.2f" % point.y)
			return
	var floor: Node = track.get_node_or_null("V2UrbanCollision/ContinuousHarborDistrictFloor")
	if floor == null:
		_fail("continuous city floor missing")
		return
	if not (floor is CSGBox3D) or not (floor as CSGBox3D).use_collision:
		_fail("continuous city floor collision disabled")
		return

	print("NEON HARBOR V2 GROUND SMOKE PASS route_points=30 checkpoints=9 length=%.1fm flat=true city_floor_collision=true" % length)
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("NEON HARBOR V2 GROUND SMOKE FAIL: %s" % message)
	get_tree().quit(1)
