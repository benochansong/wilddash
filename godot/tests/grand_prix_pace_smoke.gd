extends Node

const TRACK_SCENE: PackedScene = preload("res://tracks/grand_prix_track.tscn")
const FIXED_STEP := 1.0 / 60.0
const CORNER_BRAKE_DISTANCE := 25.0

func _ready() -> void:
	RaceManager.clear_racers()
	RaceManager.clear_track()
	var track := TRACK_SCENE.instantiate() as WildDashGrandPrixTrack
	if track == null:
		_fail("track instantiate failed")
		return
	add_child(track)
	await get_tree().physics_frame

	var definition := WildDashAnimalCatalog.get_definition(&"dog")
	if definition == null:
		_fail("Dog definition missing")
		return
	var route := track.get_route_points()
	if route.size() < 2:
		_fail("route missing")
		return

	var elapsed := _estimate_clean_lap(route, definition.max_speed, definition.acceleration)
	print("PLAYER PACE ESTIMATE route=%.1fm animal=Dog max_speed=%.1f acceleration=%.1f seconds=%.2f no_teleport=true geometry_aware=true" % [
		track.get_track_length(), definition.max_speed, definition.acceleration, elapsed,
	])
	if elapsed < 130.0 or elapsed > 170.0:
		_fail("clean-lap estimate %.2fs outside 130-170s" % elapsed)
		return
	print("PLAYER RACE TIME PASS estimated_clean_lap=%.2fs target=130-170" % elapsed)
	get_tree().quit(0)

func _estimate_clean_lap(route: Array[Vector3], max_speed: float, acceleration: float) -> float:
	var speed := 0.0
	var elapsed := 0.0
	for i in range(route.size() - 1):
		var segment_length := route[i].distance_to(route[i + 1])
		var traveled := 0.0
		var corner_angle := 0.0
		if i + 1 < route.size() - 1:
			corner_angle = _turn_angle_degrees(route[i], route[i + 1], route[i + 2])
		while traveled < segment_length:
			var remaining := segment_length - traveled
			var speed_factor := 1.0
			if remaining <= CORNER_BRAKE_DISTANCE:
				speed_factor = _corner_speed_factor(corner_angle)
			var target_speed := max_speed * speed_factor
			speed = move_toward(speed, target_speed, acceleration * FIXED_STEP)
			var step_distance := minf(remaining, maxf(speed, 0.1) * FIXED_STEP)
			traveled += step_distance
			elapsed += FIXED_STEP
			if elapsed > 400.0:
				return elapsed
	return elapsed

func _turn_angle_degrees(a: Vector3, b: Vector3, c: Vector3) -> float:
	var incoming := b - a
	var outgoing := c - b
	incoming.y = 0.0
	outgoing.y = 0.0
	if incoming.length_squared() <= 0.001 or outgoing.length_squared() <= 0.001:
		return 0.0
	var dot_value := clampf(incoming.normalized().dot(outgoing.normalized()), -1.0, 1.0)
	return rad_to_deg(acos(dot_value))

func _corner_speed_factor(angle: float) -> float:
	if angle > 85.0:
		return 0.72
	if angle > 65.0:
		return 0.80
	if angle > 45.0:
		return 0.88
	if angle > 25.0:
		return 0.94
	return 1.0

func _fail(message: String) -> void:
	push_error("PLAYER RACE TIME FAIL " + message)
	print("PLAYER RACE TIME FAIL " + message)
	get_tree().quit(1)
