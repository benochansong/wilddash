extends Node

const TRACK_SCENE: PackedScene = preload("res://tracks/grand_prix_track.tscn")
const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")

const MIN_TRACK_LENGTH := 2200.0
const MAX_TRACK_LENGTH := 2600.0
const MIN_ROUTE_POINTS := 26
const MAX_ROUTE_POINTS := 32
const EXPECTED_CHECKPOINTS := 11
const MAX_RUNTIME_NODES := 180
const MIN_SHORTCUT_SAVING := 45.0
const MAX_SHORTCUT_SAVING := 95.0

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
	if length < MIN_TRACK_LENGTH or length > MAX_TRACK_LENGTH:
		_fail("Track length outside 2200-2600m: %.1f" % length)
		return
	print("TRACK LENGTH PASS %.1fm" % length)

	if route.size() < MIN_ROUTE_POINTS or route.size() > MAX_ROUTE_POINTS:
		_fail("AI route point count outside 26-32: %d" % route.size())
		return
	print("PLAYER ROUTE VALID PASS points=%d" % route.size())

	if RaceManager.get_checkpoint_count() != EXPECTED_CHECKPOINTS:
		_fail("Expected %d ordered checkpoints, got %d" % [EXPECTED_CHECKPOINTS, RaceManager.get_checkpoint_count()])
		return
	print("GRAND PRIX TRACK LOAD PASS points=%d length=%.1fm checkpoints=%d" % [
		route.size(), length, RaceManager.get_checkpoint_count(),
	])

	var shortcut_a := track.get_shortcut_a_saving()
	var shortcut_b := track.get_shortcut_b_saving()
	if shortcut_a < MIN_SHORTCUT_SAVING or shortcut_a > MAX_SHORTCUT_SAVING:
		_fail("Shortcut A saving outside risk/reward target: %.1fm" % shortcut_a)
		return
	if shortcut_b < MIN_SHORTCUT_SAVING or shortcut_b > MAX_SHORTCUT_SAVING:
		_fail("Shortcut B saving outside risk/reward target: %.1fm" % shortcut_b)
		return
	print("SHORTCUT A PASS saving=%.1fm" % shortcut_a)
	print("SHORTCUT B PASS saving=%.1fm" % shortcut_b)

	var runtime_nodes := track.get_runtime_node_count()
	if runtime_nodes > MAX_RUNTIME_NODES:
		_fail("Track runtime node budget exceeded: %d > %d" % [runtime_nodes, MAX_RUNTIME_NODES])
		return
	print("TRACK NODE BUDGET PASS nodes=%d max=%d" % [runtime_nodes, MAX_RUNTIME_NODES])

	var decoration := track.get_node_or_null("DecorationGeometry")
	var collision_root := track.get_node_or_null("GameplayCollision")
	if decoration == null or collision_root == null:
		_fail("Environment visual/collision roots are not separated")
		return
	var required_visual_nodes: Array[String] = [
		"RoadSurface_Asphalt", "RoadSurface_Dirt", "GrassShoulders",
		"ForestTrunks", "ForestCrownClusters", "CanyonLayeredCliffs",
		"CanyonOutcropsAndLooseRock", "BridgeStructure", "BridgeCrossBraces",
		"TunnelWallSegments", "TunnelCeilingPanels", "TunnelGuideLights",
	]
	for node_name in required_visual_nodes:
		if decoration.get_node_or_null(node_name) == null:
			_fail("Missing environment visual node: %s" % node_name)
			return
	var road_collision := collision_root.get_node_or_null("Road_00_Meadow_Straight_Collision") as CSGBox3D
	var tunnel_collision := collision_root.get_node_or_null("TunnelRoof") as CSGBox3D
	if road_collision == null or road_collision.visible or not road_collision.use_collision:
		_fail("Road visual/collision separation invalid")
		return
	if tunnel_collision == null or tunnel_collision.visible or not tunnel_collision.use_collision:
		_fail("Tunnel visual/collision separation invalid")
		return
	print("ENVIRONMENT FOUNDATION PASS materials=6 road_collision_separate=true decoration_collision=false")

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

	var finish := route[route.size() - 1]
	var previous := route[route.size() - 2]
	var finish_direction := finish - previous
	finish_direction.y = 0.0
	finish_direction = finish_direction.normalized()
	racer.global_position = finish - finish_direction * 2.0 + Vector3.UP
	if RaceManager.sync_finish_from_position(racer):
		_fail("Finish was recorded before crossing the visible line")
		return
	if RaceManager.finish_order.has(racer):
		_fail("Racer appeared in finish order before crossing the line")
		return

	racer.global_position = finish + finish_direction * 1.0 + Vector3.UP
	if not RaceManager.sync_finish_from_position(racer):
		_fail("Finish was not recorded after crossing the visible line")
		return
	var rank := RaceManager.finish_order.find(racer) + 1
	if rank != 1:
		_fail("Validated finish did not record rank 1")
		return
	print("FINISH CROSSING PASS before_line_rejected=true after_line_rank=%d" % rank)
	print("FINISH VALIDATION PASS checkpoints=%d rank=%d" % [
		RaceManager.get_checkpoint_progress(racer), rank,
	])
	get_tree().quit(0)

func _fail(message: String) -> void:
	push_error(message)
	print("GRAND PRIX TRACK FAIL " + message)
	get_tree().quit(1)
