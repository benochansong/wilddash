extends Node

const TRACK_SCENE: PackedScene = preload("res://tracks/neon_harbor_track.tscn")
const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")
const MIN_LENGTH := 1500.0
const MAX_LENGTH := 1900.0
const EXPECTED_ROUTE_POINTS := 26
const EXPECTED_CHECKPOINTS := 9

func _ready() -> void:
	RaceManager.clear_racers()
	RaceManager.clear_track()
	var track := TRACK_SCENE.instantiate() as WildDashNeonHarborTrack
	if track == null:
		_fail("Neon Harbor track did not instantiate")
		return
	add_child(track)
	await get_tree().physics_frame

	var route := track.get_route_points()
	var length := track.get_track_length()
	if route.size() != EXPECTED_ROUTE_POINTS:
		_fail("Expected %d route points, got %d" % [EXPECTED_ROUTE_POINTS, route.size()])
		return
	if length < MIN_LENGTH or length > MAX_LENGTH:
		_fail("Track length outside 1500-1900m: %.1f" % length)
		return
	if RaceManager.get_checkpoint_count() != EXPECTED_CHECKPOINTS:
		_fail("Expected %d checkpoints, got %d" % [EXPECTED_CHECKPOINTS, RaceManager.get_checkpoint_count()])
		return
	print("NEON HARBOR TRACK LOAD PASS length=%.1fm route_points=%d checkpoints=%d" % [length, route.size(), RaceManager.get_checkpoint_count()])

	var zones := track.get_zone_names()
	for zone in ["Harbor Boulevard", "Container Yard", "Warehouse S-Curve", "Crane District", "Dockside Straight", "Industrial Tunnel", "Elevated Highway", "Neon Downtown", "Shipyard Chicane", "Final Harbor Straight"]:
		if not zones.has(zone):
			_fail("Missing Neon Harbor zone: %s" % zone)
			return
	print("NEON HARBOR ZONES PASS count=%d" % zones.size())

	var decoration := track.get_node_or_null("DecorationGeometry")
	var collision := track.get_node_or_null("GameplayCollision")
	if decoration == null or collision == null:
		_fail("Neon Harbor visual/collision roots are not separated")
		return
	for node_name in [
		"HarborRoadSurface", "HarborRoadEdges", "HarborGuardrails", "ContainersRed", "ContainersBlue",
		"WarehouseBodies", "HarborCranes", "HarborWater", "IndustrialTunnelPanels", "IndustrialTunnelLights",
		"ElevatedHighwaySupports", "NeonCityBuildings", "NeonCyanSigns", "NeonMagentaSigns",
		"ShipyardChicaneBarriers", "StreetLightPosts", "FinishGantry",
	]:
		if decoration.get_node_or_null(node_name) == null:
			_fail("Missing Neon Harbor visual node: %s" % node_name)
			return
	var tunnel_roof := collision.get_node_or_null("TunnelRoof") as CSGBox3D
	if tunnel_roof == null or tunnel_roof.visible or not tunnel_roof.use_collision:
		_fail("Industrial tunnel roof collision missing for obstruction-aware camera")
		return
	if _has_visual_collision(decoration):
		_fail("Neon Harbor decoration contains gameplay collision")
		return
	print("NEON HARBOR ENVIRONMENT PASS urban=true harbor=true night=true tunnel_camera_geometry=true visual_collision=false")

	if track.get_shortcut_a_saving() <= 8.0:
		_fail("Container-yard service shortcut saving is too small")
		return
	print("NEON HARBOR SHORTCUT PASS saving=%.1fm" % track.get_shortcut_a_saving())

	var finish := route[-1]
	var finish_line := track.get_node_or_null("FinishLine") as Area3D
	var finish_stripe := decoration.get_node_or_null("FinishStripe") as CSGBox3D
	if finish_line == null or finish_stripe == null:
		_fail("Neon Harbor finish line/stripe missing")
		return
	if Vector2(finish_line.position.x, finish_line.position.z).distance_to(Vector2(finish.x, finish.z)) > 0.01:
		_fail("Neon Harbor finish trigger is not aligned")
		return

	var racer := RACER_SCENE.instantiate() as WildDashCharacterController
	racer.name = "NeonCheckpointTester"
	racer.is_player = true
	racer.movement_mode = WildDashCharacterController.MovementMode.RACE
	racer.position = track.get_start_position() + Vector3.UP
	add_child(racer)
	await get_tree().physics_frame
	RaceManager.start_race()
	for checkpoint_index in range(RaceManager.get_checkpoint_count()):
		if not RaceManager.record_checkpoint(racer, checkpoint_index):
			_fail("Neon checkpoint %d failed" % (checkpoint_index + 1))
			return
	var previous := route[-2]
	var direction := finish - previous
	direction.y = 0.0
	direction = direction.normalized()
	racer.global_position = finish - direction * 1.5 + Vector3.UP
	if RaceManager.sync_finish_from_position(racer):
		_fail("Neon finish recorded before line crossing")
		return
	racer.global_position = finish + direction * 1.0 + Vector3.UP
	if not RaceManager.sync_finish_from_position(racer):
		_fail("Neon finish did not record after line crossing")
		return
	print("NEON HARBOR FINISH PASS checkpoints=%d finish_aligned=true" % RaceManager.get_checkpoint_progress(racer))
	print("NEON HARBOR TRACK SMOKE PASS")
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
	push_error("NEON HARBOR TRACK FAIL " + message)
	get_tree().quit(1)
