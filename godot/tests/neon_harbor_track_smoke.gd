extends Node

const TRACK_SCENE: PackedScene = preload("res://tracks/neon_harbor_track.tscn")
const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")
const MIN_LENGTH: float = 1450.0
const MAX_LENGTH: float = 1650.0
const EXPECTED_ROUTE_POINTS: int = 30
const EXPECTED_CHECKPOINTS: int = 9
const EXPECTED_ZONES: int = 5

func _ready() -> void:
	RaceManager.clear_racers()
	RaceManager.clear_track()
	var track: WildDashWildTideDaylightTrack = TRACK_SCENE.instantiate() as WildDashWildTideDaylightTrack
	if track == null:
		_fail("Wild Tide daylight track did not instantiate")
		return
	add_child(track)
	await get_tree().physics_frame

	var route: Array[Vector3] = track.get_route_points()
	var length: float = track.get_track_length()
	if route.size() != EXPECTED_ROUTE_POINTS:
		_fail("Expected %d route points, got %d" % [EXPECTED_ROUTE_POINTS, route.size()])
		return
	if length < MIN_LENGTH or length > MAX_LENGTH:
		_fail("Track length outside %.0f-%.0fm: %.1f" % [MIN_LENGTH, MAX_LENGTH, length])
		return
	if RaceManager.get_checkpoint_count() != EXPECTED_CHECKPOINTS:
		_fail("Expected %d checkpoints, got %d" % [EXPECTED_CHECKPOINTS, RaceManager.get_checkpoint_count()])
		return
	print("NEON HARBOR TRACK LOAD PASS length=%.1fm route_points=%d checkpoints=%d" % [length, route.size(), RaceManager.get_checkpoint_count()])

	var zones: PackedStringArray = track.get_zone_names()
	var expected_zones: Array[String] = [
		"Harbor Start",
		"Flooded Harbor Split",
		"Mangrove Jungle",
		"Flooded Midfield",
		"Final Delta Sprint",
	]
	for zone: String in expected_zones:
		if not zones.has(zone):
			_fail("Missing Wild Tide zone: %s" % zone)
			return
	if zones.size() != EXPECTED_ZONES:
		_fail("Expected %d Wild Tide zones, got %d" % [EXPECTED_ZONES, zones.size()])
		return
	print("NEON HARBOR ZONES PASS count=%d wild_tide=true" % zones.size())

	var world: WorldEnvironment = track.get_node_or_null("WildTideDayWorldEnvironment") as WorldEnvironment
	var sun: DirectionalLight3D = track.get_node_or_null("WildTideSun") as DirectionalLight3D
	if world == null or world.environment == null or sun == null:
		_fail("Wild Tide daytime environment missing")
		return
	if world.environment.background_color.b < 0.70 or world.environment.ambient_light_energy < 1.0:
		_fail("Wild Tide daytime environment is still too dark")
		return
	if sun.light_energy < 1.0:
		_fail("Wild Tide daylight sun energy is too low")
		return
	print("NEON HARBOR ENVIRONMENT PASS daytime=true tropical=true night=false")

	var water_ratio: float = track.get_visible_water_ratio()
	var shallow_ratio: float = track.get_shallow_water_ratio()
	var deep_ratio: float = track.get_deep_water_ratio()
	if water_ratio < 0.45 or water_ratio > 0.55:
		_fail("Visible water ratio outside 45-55 percent: %.3f" % water_ratio)
		return
	if shallow_ratio < 0.18 or shallow_ratio > 0.30:
		_fail("Shallow water ratio outside expected range: %.3f" % shallow_ratio)
		return
	if deep_ratio < 0.18 or deep_ratio > 0.30:
		_fail("Deep water ratio outside expected range: %.3f" % deep_ratio)
		return
	var support_root: Node = track.get_node_or_null("WildTideDayCollision")
	var land_visual_root: Node = track.get_node_or_null("WildTideDayVisuals")
	if support_root == null or land_visual_root == null:
		_fail("Wild Tide visual/collision roots missing")
		return
	var water_support: CSGBox3D = support_root.get_node_or_null("WildTideSupport_05") as CSGBox3D
	if water_support == null or not water_support.use_collision or water_support.visible:
		_fail("Hidden support floor missing on first water segment")
		return
	if land_visual_root.get_node_or_null("WildTideLandRoadSurface") == null:
		_fail("Land road surface batch missing")
		return
	print("VISIBLE WATER CHECK segments=%d ratio=%.1f%% shallow=%.1f%% deep=%.1f%% road_surface_removed=true hidden_support=true" % [
		WildDashWildTideDaylightTrack.WILD_TIDE_WATER_SEGMENTS.size(),
		water_ratio * 100.0,
		shallow_ratio * 100.0,
		deep_ratio * 100.0,
	])
	print("NEON HARBOR SHORTCUT PASS wild_tide_branch_network=runtime")

	var finish: Vector3 = route[route.size() - 1]
	var finish_line: Area3D = track.get_node_or_null("FinishLine") as Area3D
	if finish_line == null:
		_fail("Wild Tide finish line missing")
		return
	if Vector2(finish_line.position.x, finish_line.position.z).distance_to(Vector2(finish.x, finish.z)) > 0.01:
		_fail("Wild Tide finish trigger is not aligned")
		return

	var racer: WildDashCharacterController = RACER_SCENE.instantiate() as WildDashCharacterController
	if racer == null:
		_fail("Checkpoint test racer failed to instantiate")
		return
	racer.name = "WildTideCheckpointTester"
	racer.is_player = true
	racer.movement_mode = WildDashCharacterController.MovementMode.RACE
	racer.position = track.get_start_position() + Vector3.UP
	add_child(racer)
	await get_tree().physics_frame
	RaceManager.start_race()
	for checkpoint_index: int in range(RaceManager.get_checkpoint_count()):
		if not RaceManager.record_checkpoint(racer, checkpoint_index):
			_fail("Wild Tide checkpoint %d failed" % (checkpoint_index + 1))
			return
	var previous: Vector3 = route[route.size() - 2]
	var direction: Vector3 = finish - previous
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		_fail("Wild Tide finish direction invalid")
		return
	direction = direction.normalized()
	racer.global_position = finish - direction * 1.5 + Vector3.UP
	if RaceManager.sync_finish_from_position(racer):
		_fail("Wild Tide finish recorded before line crossing")
		return
	racer.global_position = finish + direction * 1.0 + Vector3.UP
	if not RaceManager.sync_finish_from_position(racer):
		_fail("Wild Tide finish did not record after line crossing")
		return
	print("NEON HARBOR FINISH PASS checkpoints=%d finish_aligned=true" % RaceManager.get_checkpoint_progress(racer))
	print("NEON HARBOR TRACK SMOKE PASS wild_tide_daylight=true water_ratio=%.1f%%" % (water_ratio * 100.0))
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error("NEON HARBOR TRACK FAIL " + message)
	get_tree().quit(1)
