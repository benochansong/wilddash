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
		"RoadDustyShoulders", "RoadPaintedEdgeLines",
		"ForestTrunks", "ForestCrownClusters", "CanyonLayeredCliffs",
		"CanyonOutcropsAndLooseRock", "BridgeStructure", "BridgeCrossBraces",
		"TunnelWallSegments", "TunnelCeilingPanels", "TunnelGuideLights",
	]
	for node_name in required_visual_nodes:
		if decoration.get_node_or_null(node_name) == null:
			_fail("Missing environment visual node: %s" % node_name)
			return
	var road_edges := decoration.get_node_or_null("RoadPaintedEdgeLines") as MultiMeshInstance3D
	var dusty_shoulders := decoration.get_node_or_null("RoadDustyShoulders") as MultiMeshInstance3D
	if road_edges == null or road_edges.multimesh == null or road_edges.multimesh.instance_count < 50:
		_fail("Main-route painted edge continuity is incomplete")
		return
	if dusty_shoulders == null or dusty_shoulders.multimesh == null or dusty_shoulders.multimesh.instance_count < 20:
		_fail("Forest/Canyon dusty shoulder hierarchy is incomplete")
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
	print("ROAD READABILITY PASS main_route_edges=%d dusty_shoulders=%d collision=false" % [
		road_edges.multimesh.instance_count, dusty_shoulders.multimesh.instance_count,
	])
	var road_arrows := decoration.get_node_or_null("RoadDirectionArrows") as MultiMeshInstance3D
	var trackside_guides := decoration.get_node_or_null("TracksideDirectionGuides") as MultiMeshInstance3D
	if road_arrows == null or road_arrows.multimesh == null or road_arrows.multimesh.instance_count < 34:
		_fail("Road-surface direction arrow coverage is incomplete")
		return
	if trackside_guides == null or trackside_guides.multimesh == null or trackside_guides.multimesh.instance_count < 34:
		_fail("Trackside direction marker/chevron coverage is incomplete")
		return
	var arrow_coverage: PackedStringArray = road_arrows.get_meta(&"coverage", PackedStringArray())
	var marker_coverage: PackedStringArray = trackside_guides.get_meta(&"coverage", PackedStringArray())
	for zone in ["sharp_curve", "hairpin", "s_curve", "branch", "bridge", "tunnel", "jump", "final"]:
		if not arrow_coverage.has(zone) or not marker_coverage.has(zone):
			_fail("Direction guidance coverage missing for zone: %s" % zone)
			return
	print("DIRECTION GUIDE PASS road_arrows=%d trackside_guides=%d static_multimesh=true" % [
		road_arrows.multimesh.instance_count, trackside_guides.multimesh.instance_count,
	])
	var shortcut_wear := decoration.get_node_or_null("ShortcutWearMarks") as MultiMeshInstance3D
	if shortcut_wear == null or shortcut_wear.multimesh == null or shortcut_wear.multimesh.instance_count < 10:
		_fail("Shortcut worn-path hierarchy is incomplete")
		return
	var special_coverage: PackedStringArray = decoration.get_meta(&"special_readability_coverage", PackedStringArray())
	for zone in ["shortcut", "jump", "bridge", "tunnel", "obstacle", "final", "finish"]:
		if not special_coverage.has(zone):
			_fail("Special-section readability coverage missing: %s" % zone)
			return
	var finish_position := route[route.size() - 1]
	var finish_line := track.get_node_or_null("FinishLine") as Area3D
	var finish_stripe := decoration.get_node_or_null("FinishStripe") as CSGBox3D
	if finish_line == null or finish_stripe == null:
		_fail("Finish detection or visual stripe missing")
		return
	var finish_xz := Vector2(finish_position.x, finish_position.z)
	if Vector2(finish_line.position.x, finish_line.position.z).distance_to(finish_xz) > 0.01 or Vector2(finish_stripe.position.x, finish_stripe.position.z).distance_to(finish_xz) > 0.01:
		_fail("Visual finish stripe and finish detection are misaligned")
		return
	var structural_batch := decoration.get_node_or_null("EnvironmentStructuralProps") as MultiMeshInstance3D
	var finish_gate_position: Vector3 = structural_batch.get_meta(&"finish_gate_position", Vector3(INF, INF, INF)) if structural_batch != null else Vector3(INF, INF, INF)
	if Vector2(finish_gate_position.x, finish_gate_position.z).distance_to(finish_xz) > 0.01:
		_fail("Visual finish gantry anchor is not aligned to the finish plane")
		return
	print("SPECIAL READABILITY PASS shortcut_wear=%d coverage=7 finish_aligned=true" % shortcut_wear.multimesh.instance_count)

	var pass_2_visual_nodes: Array[String] = [
		"RoadSurface_Shortcuts", "EnvironmentStructuralProps",
		"EnvironmentWarningDetails", "EnvironmentEventDetails", "RiverWetRockAccents",
	]
	for node_name in pass_2_visual_nodes:
		if decoration.get_node_or_null(node_name) == null:
			_fail("Missing environment pass-2 visual node: %s" % node_name)
			return
	var bridge_river := decoration.get_node_or_null("BridgeRiver") as CSGBox3D
	if bridge_river == null or not (bridge_river.material is ShaderMaterial):
		_fail("River is not using the lightweight animated water material")
		return
	var static_collision := collision_root.get_node_or_null("ForestBlockA") as CSGBox3D
	if static_collision == null or static_collision.visible or not static_collision.use_collision:
		_fail("Static obstacle visual/collision separation invalid")
		return
	var moving_gate := collision_root.get_node_or_null("MovingGateA") as WildDashDynamicObstacle
	if moving_gate == null:
		_fail("Moving gate gameplay body missing")
		return
	var gate_visual := moving_gate.get_node_or_null("MechanicalVisual") as MeshInstance3D
	var gate_collision := moving_gate.get_node_or_null("GameplayCollision") as CollisionShape3D
	if gate_visual == null or not (gate_visual.mesh is ArrayMesh) or gate_visual.mesh.get_surface_count() < 3:
		_fail("Moving gate mechanical visual is not a compound mesh")
		return
	if gate_collision == null or not (gate_collision.shape is BoxShape3D):
		_fail("Moving gate gameplay collision is not the preserved primitive shape")
		return
	if not is_equal_approx(moving_gate.motion_speed, 1.15) or not is_equal_approx(moving_gate.amplitude, 5.2):
		_fail("Moving gate timing changed")
		return
	var jump_collision := track.get_node_or_null("JumpRampCollision") as CSGBox3D
	var multi_jump_collision := collision_root.get_node_or_null("MultiJumpHurdle_01") as CSGBox3D
	if jump_collision == null or jump_collision.visible or not jump_collision.use_collision:
		_fail("Main jump ramp collision changed")
		return
	if multi_jump_collision == null or multi_jump_collision.visible or not multi_jump_collision.use_collision:
		_fail("Multi-jump collision/visual separation invalid")
		return
	print("ENVIRONMENT PASS 2 PASS water=animated obstacles=compound gates=timing_preserved ramps=collision_preserved shortcuts=readable finish=aligned")

	if not WildDashEnvironmentMaterialLibrary.has_required_materials():
		_fail("Environment material library is incomplete")
		return
	var palette := WildDashEnvironmentMaterialLibrary.get_palette()
	if palette[&"metal"] != palette[&"bridge"] or palette[&"finish"] != palette[&"event_blue"]:
		_fail("Environment material aliases are not reusing shared resources")
		return
	if palette[&"dirt_road"] == palette[&"dirt"] or palette[&"bridge_road"] == palette[&"bridge"] or palette[&"tunnel_road"] == palette[&"tunnel"]:
		_fail("Road surfaces are not visually separated from terrain/structures")
		return
	var canyon_road := decoration.get_node_or_null("RoadSurface_Dirt") as MultiMeshInstance3D
	var bridge_road := decoration.get_node_or_null("RoadSurface_Bridge") as MultiMeshInstance3D
	var tunnel_road := decoration.get_node_or_null("RoadSurface_Tunnel") as MultiMeshInstance3D
	if canyon_road.material_override != palette[&"dirt_road"] or bridge_road.material_override != palette[&"bridge_road"] or tunnel_road.material_override != palette[&"tunnel_road"]:
		_fail("Zone road surfaces are not using readability materials")
		return
	var world_environment := track.get_node_or_null("GrandPrixWorldEnvironment") as WorldEnvironment
	if world_environment == null or world_environment.environment == null:
		_fail("Grand Prix WorldEnvironment missing")
		return
	if world_environment.environment.background_mode != Environment.BG_SKY:
		_fail("Grand Prix sky environment missing")
		return
	if world_environment.environment.ssao_enabled:
		_fail("SSAO must remain disabled for the gl_compatibility renderer")
		return
	var far_forest := decoration.get_node_or_null("ForestFarCanopies") as GeometryInstance3D
	var near_bushes := decoration.get_node_or_null("ForestBushes") as GeometryInstance3D
	var round_props := decoration.get_node_or_null("TracksideRoundProps") as GeometryInstance3D
	if far_forest == null or far_forest.visibility_range_begin <= 0.0:
		_fail("Forest far-silhouette LOD missing")
		return
	if near_bushes == null or near_bushes.visibility_range_end <= 0.0:
		_fail("Near vegetation culling range missing")
		return
	if round_props == null or round_props.visibility_range_end <= 0.0:
		_fail("Trackside prop visibility range missing")
		return
	if decoration.process_mode != Node.PROCESS_MODE_DISABLED:
		_fail("Static decoration root must not process")
		return
	if _has_unexpected_visual_collision(decoration):
		_fail("Decoration tree contains gameplay collision")
		return
	print("ENVIRONMENT PASS 3 PASS materials=shared lighting=compatibility_safe lod=near_mid_far culling=true decoration_process=false")

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

func _has_unexpected_visual_collision(node: Node) -> bool:
	if node is CollisionObject3D or node is CollisionShape3D:
		return true
	if node is CSGShape3D and (node as CSGShape3D).use_collision:
		return true
	for child in node.get_children():
		if _has_unexpected_visual_collision(child):
			return true
	return false
