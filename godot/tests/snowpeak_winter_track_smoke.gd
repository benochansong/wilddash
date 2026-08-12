extends Node

const TRACK_SCENE: PackedScene = preload("res://tracks/snowpeak_winter_track.tscn")
const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")
const MIN_LENGTH := 1800.0
const MAX_LENGTH := 2200.0
const EXPECTED_ROUTE_POINTS := 31
const EXPECTED_CHECKPOINTS := 10

func _ready() -> void:
	RaceManager.clear_racers()
	RaceManager.clear_track()
	var track := TRACK_SCENE.instantiate() as WildDashSnowpeakWinterTrack
	if track == null:
		_fail("Snowpeak track did not instantiate")
		return
	add_child(track)
	await get_tree().physics_frame

	var route := track.get_route_points()
	var length := track.get_track_length()
	if route.size() != EXPECTED_ROUTE_POINTS:
		_fail("Expected %d route points, got %d" % [EXPECTED_ROUTE_POINTS, route.size()])
		return
	if length < MIN_LENGTH or length > MAX_LENGTH:
		_fail("Track length outside 1800-2200m: %.1f" % length)
		return
	if RaceManager.get_checkpoint_count() != EXPECTED_CHECKPOINTS:
		_fail("Expected %d checkpoints, got %d" % [EXPECTED_CHECKPOINTS, RaceManager.get_checkpoint_count()])
		return
	print("SNOWPEAK TRACK LOAD PASS length=%.1fm route_points=%d checkpoints=%d" % [length, route.size(), RaceManager.get_checkpoint_count()])

	var zones := track.get_zone_names()
	for zone in ["Snow Resort Village", "Pine Forest Run", "Frozen River Crossing", "Mountain Hairpins", "Ice Cave Tunnel", "High Alpine Pass", "Frozen Lake Sprint", "Ski Lift District", "Snowfield Jump Section", "Blizzard Ridge", "Final Resort Straight"]:
		if not zones.has(zone):
			_fail("Missing Snowpeak zone: %s" % zone)
			return
	print("SNOWPEAK ZONES PASS count=%d" % zones.size())

	var decoration := track.get_node_or_null("DecorationGeometry")
	var collision := track.get_node_or_null("GameplayCollision")
	if decoration == null or collision == null:
		_fail("Snowpeak visual/collision roots are not separated")
		return
	for node_name in [
		"SnowpeakRoadSurface", "PackedSnowSurface", "IceSurfacePatches", "SnowShoulders", "SnowBanks",
		"WinterGuardrails", "SnowRouteMarkersRed", "ResortLodges", "SnowPineFoliage", "FrozenRiverScenery",
		"HairpinChevrons", "IceCaveWalls", "IceCaveEmbeddedLights", "DistantSnowMountains", "FrozenLakeScenery",
		"SkiLiftTowers", "SnowJumpGuidePoles", "BlizzardRouteMarkers", "SnowFinishGantry",
	]:
		if decoration.get_node_or_null(node_name) == null:
			_fail("Missing Snowpeak visual node: %s" % node_name)
			return
	var cave_roof := collision.get_node_or_null("IceCaveRoof") as CSGBox3D
	if cave_roof == null or cave_roof.visible or not cave_roof.use_collision:
		_fail("Ice Cave roof collision missing for obstruction-aware camera")
		return
	if _has_visual_collision(decoration):
		_fail("Snowpeak decoration contains gameplay collision")
		return
	print("SNOWPEAK ENVIRONMENT PASS winter=true bright_day=true ice_cave=true visual_collision=false")

	var normal := track.get_surface_profile_at(route[2])
	var packed := track.get_surface_profile_at(route[10])
	var ice := track.get_surface_profile_at(route[7])
	var shoulder_point := route[2] + Vector3.RIGHT * 12.0
	var deep := track.get_surface_profile_at(shoulder_point)
	if StringName(ice.get("surface", &"")) != &"ice":
		_fail("Ice surface profile missing")
		return
	if float(ice.get("slip_multiplier", 1.0)) <= float(packed.get("slip_multiplier", 1.0)):
		_fail("Ice should be slipperier than packed snow")
		return
	if float(deep.get("speed_multiplier", 1.0)) >= 1.0:
		_fail("Deep snow shoulder should slow player")
		return
	print("SNOWPEAK SURFACE PASS normal=%s packed=%s ice=%s deep=%s" % [normal.get("surface"), packed.get("surface"), ice.get("surface"), deep.get("surface")])

	var finish := route[-1]
	var finish_line := track.get_node_or_null("FinishLine") as Area3D
	var finish_stripe := decoration.get_node_or_null("FinishStripe") as CSGBox3D
	if finish_line == null or finish_stripe == null:
		_fail("Snowpeak finish line/stripe missing")
		return
	if Vector2(finish_line.position.x, finish_line.position.z).distance_to(Vector2(finish.x, finish.z)) > 0.01:
		_fail("Snowpeak finish trigger is not aligned")
		return

	var racer := RACER_SCENE.instantiate() as WildDashCharacterController
	racer.name = "SnowCheckpointTester"
	racer.is_player = true
	racer.movement_mode = WildDashCharacterController.MovementMode.RACE
	racer.position = track.get_start_position() + Vector3.UP
	add_child(racer)
	await get_tree().physics_frame
	RaceManager.start_race()
	for checkpoint_index in range(RaceManager.get_checkpoint_count()):
		if not RaceManager.record_checkpoint(racer, checkpoint_index):
			_fail("Snowpeak checkpoint %d failed" % (checkpoint_index + 1))
			return
	var previous := route[-2]
	var direction := finish - previous
	direction.y = 0.0
	direction = direction.normalized()
	racer.global_position = finish - direction * 1.5 + Vector3.UP
	if RaceManager.sync_finish_from_position(racer):
		_fail("Snowpeak finish recorded before line crossing")
		return
	racer.global_position = finish + direction * 1.0 + Vector3.UP
	if not RaceManager.sync_finish_from_position(racer):
		_fail("Snowpeak finish did not record after line crossing")
		return
	print("SNOWPEAK FINISH PASS checkpoints=%d finish_aligned=true" % RaceManager.get_checkpoint_progress(racer))
	print("SNOWPEAK TRACK SMOKE PASS")
	get_tree().quit(0)

func _has_visual_collision(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D:
		return true
	if node is CSGShape3D and (node as CSGShape3D).use_collision:
		return true
	for child in node.get_children():
		if _has_visual_collision(child):
			return true
	return false

func _fail(message: String) -> void:
	push_error("SNOWPEAK TRACK FAIL " + message)
	get_tree().quit(1)
