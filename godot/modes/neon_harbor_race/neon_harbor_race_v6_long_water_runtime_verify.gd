extends "res://modes/neon_harbor_race/neon_harbor_race_v5_rebuild.gd"

## Round 3 V6 — production long-water runtime authority verifier.
##
## GitHub may contain the expanded track while a stale local import / wrong project
## instance still runs the old 30-point / ~1524 m route. V6 makes that mismatch
## impossible to miss: campaign and F6 both run this same root script, which checks
## the actual instantiated track, RaceManager route, world/route/guidance/respawn
## adapters, finish authority and AI routes after bootstrap.

const ROUND3_REVISION: String = "LONG_WATER_371M_V2_VERIFY"
const EXPECTED_FEATURE: String = "feature/rc9-racing-polish-multiplayer"
const EXPECTED_TRACK_SCRIPT: String = "res://tracks/wild_tide_long_water_track.gd"
const EXPECTED_WORLD_SCRIPT: String = "res://modes/neon_harbor_race/wild_tide_world_controller_v4_long_water.gd"
const EXPECTED_ROUTE_SCRIPT: String = "res://modes/neon_harbor_race/wild_tide_route_network_v2_long_water.gd"
const EXPECTED_GUIDANCE_SCRIPT: String = "res://modes/neon_harbor_race/wild_tide_route_guidance_v3_long_water.gd"
const EXPECTED_RESPAWN_SCRIPT: String = "res://modes/neon_harbor_race/wild_tide_respawn_guard_v2_long_water.gd"
const EXPECTED_ROUTE_POINTS: int = 37
const EXPECTED_CHECKPOINTS: int = 11
const EXPECTED_MIN_TRACK_LENGTH: float = 1850.0
const EXPECTED_MAX_TRACK_LENGTH: float = 2000.0
const EXPECTED_MIN_LONG_WATER: float = 300.0
const EXPECTED_MIN_WATER_RATIO: float = 0.50
const EXPECTED_MAX_WATER_RATIO: float = 0.60
const EXPECTED_ACTIVE_WATER_SEGMENTS: int = 21
const FINISH_MATCH_TOLERANCE: float = 0.75

var _runtime_verify_complete: bool = false
var _runtime_verify_passed: bool = false
var _zone_thresholds: Array[Dictionary] = []
var _zone_announced: Dictionary = {}

func _ready() -> void:
	print("WILD DASH RC9 ROUND3 REVISION revision=%s expected_feature=%s run_mode=%s" % [
		ROUND3_REVISION,
		EXPECTED_FEATURE,
		"CAMPAIGN" if GameManager.campaign_running else "F6_DIRECT",
	])
	super._ready()
	call_deferred("_verify_round3_runtime_authority")

func _process(delta: float) -> void:
	super(delta)
	if not _runtime_verify_passed or player == null or not RaceManager.active:
		return
	_update_long_water_zone_assertions()

func _verify_round3_runtime_authority() -> void:
	# World/route adapters bootstrap asynchronously after the track and racers.
	for _attempt: int in range(180):
		var world: Node = get_node_or_null("WildTideWorldController")
		var route_network: Node = get_node_or_null("WildTideRouteNetwork")
		var route_ready: bool = route_network != null and route_network.has_method("is_ready") and bool(route_network.call("is_ready"))
		var world_ready: bool = false
		if world != null and world.has_method("get_route_state"):
			var state_value: Variant = world.call("get_route_state")
			if state_value is Dictionary:
				var state: Dictionary = state_value
				world_ready = float(state.get("long_water_distance", 0.0)) >= EXPECTED_MIN_LONG_WATER
		if _track != null and RaceManager.get_route_point_count() >= EXPECTED_ROUTE_POINTS and route_ready and world_ready:
			break
		await get_tree().physics_frame

	var failures: Array[String] = []
	var track_path: String = _script_path(_track)
	var route_points: int = RaceManager.get_route_point_count()
	var checkpoints: int = RaceManager.get_checkpoint_count()
	var track_length: float = RaceManager.get_track_length()
	var world: Node = get_node_or_null("WildTideWorldController")
	var route_network: Node = get_node_or_null("WildTideRouteNetwork")
	var guidance: Node = get_node_or_null("WildTideRouteGuidance")
	var respawn: Node = get_node_or_null("WildTideRespawnGuard")
	var world_path: String = _script_path(world)
	var route_path: String = _script_path(route_network)
	var guidance_path: String = _script_path(guidance)
	var respawn_path: String = _script_path(respawn)
	var long_water_distance: float = 0.0
	var water_ratio: float = 0.0
	var active_water_segments: int = 0

	if _track != null and _track.has_method("get_long_water_distance"):
		long_water_distance = float(_track.call("get_long_water_distance"))
	if world != null and world.has_method("get_baseline_water_ratio"):
		water_ratio = float(world.call("get_baseline_water_ratio"))
	if world != null and world.has_method("get_route_state"):
		var world_state_value: Variant = world.call("get_route_state")
		if world_state_value is Dictionary:
			var world_state: Dictionary = world_state_value
			long_water_distance = maxf(long_water_distance, float(world_state.get("long_water_distance", 0.0)))
			active_water_segments = int(world_state.get("active_water_segments", 0))

	if track_path != EXPECTED_TRACK_SCRIPT:
		failures.append("active track script mismatch expected=%s actual=%s" % [EXPECTED_TRACK_SCRIPT, track_path])
	if route_points < EXPECTED_ROUTE_POINTS:
		failures.append("route points too small expected>=%d actual=%d" % [EXPECTED_ROUTE_POINTS, route_points])
	if checkpoints != EXPECTED_CHECKPOINTS:
		failures.append("checkpoint authority mismatch expected=%d actual=%d" % [EXPECTED_CHECKPOINTS, checkpoints])
	if track_length < EXPECTED_MIN_TRACK_LENGTH or track_length > EXPECTED_MAX_TRACK_LENGTH:
		failures.append("track length mismatch expected=%.0f..%.0f actual=%.1f" % [EXPECTED_MIN_TRACK_LENGTH, EXPECTED_MAX_TRACK_LENGTH, track_length])
	if long_water_distance < EXPECTED_MIN_LONG_WATER:
		failures.append("long water missing expected>=%.0f actual=%.1f" % [EXPECTED_MIN_LONG_WATER, long_water_distance])
	if water_ratio < EXPECTED_MIN_WATER_RATIO or water_ratio > EXPECTED_MAX_WATER_RATIO:
		failures.append("water ratio mismatch expected=50..60%% actual=%.1f%%" % (water_ratio * 100.0))
	if world_path != EXPECTED_WORLD_SCRIPT:
		failures.append("world controller mismatch expected=%s actual=%s" % [EXPECTED_WORLD_SCRIPT, world_path])
	if route_path != EXPECTED_ROUTE_SCRIPT:
		failures.append("route network mismatch expected=%s actual=%s" % [EXPECTED_ROUTE_SCRIPT, route_path])
	if guidance_path != EXPECTED_GUIDANCE_SCRIPT:
		failures.append("guidance mismatch expected=%s actual=%s" % [EXPECTED_GUIDANCE_SCRIPT, guidance_path])
	if respawn_path != EXPECTED_RESPAWN_SCRIPT:
		failures.append("respawn mismatch expected=%s actual=%s" % [EXPECTED_RESPAWN_SCRIPT, respawn_path])
	if active_water_segments < EXPECTED_ACTIVE_WATER_SEGMENTS:
		failures.append("long-water gameplay areas incomplete expected>=%d actual=%d" % [EXPECTED_ACTIVE_WATER_SEGMENTS, active_water_segments])

	var finish_count: int = _count_named_nodes(self, &"FinishLine")
	if finish_count != 1:
		failures.append("FinishLine authority mismatch expected=1 actual=%d" % finish_count)

	var finish_matches: bool = _race_manager_finish_matches_track()
	if not finish_matches:
		failures.append("RaceManager finish does not match expanded track final delta")

	var ai_routes_ok: bool = _verify_ai_routes_reach_expanded_finish()
	if not ai_routes_ok:
		failures.append("one or more AI routes do not reach the expanded finish")

	_runtime_verify_complete = true
	_runtime_verify_passed = failures.is_empty()
	if not _runtime_verify_passed:
		for failure: String in failures:
			push_error("ROUND3 ACTIVE TRACK VERIFY FAIL — %s" % failure)
		print("ROUND3 ACTIVE TRACK VERIFY FAIL revision=%s run_mode=%s track_script=%s route_points=%d checkpoints=%d track_length=%.1f long_water=%.1f water=%.1f%% world=%s route_network=%s guidance=%s respawn=%s finish_lines=%d finish_matches=%s" % [
			ROUND3_REVISION,
			"CAMPAIGN" if GameManager.campaign_running else "F6_DIRECT",
			track_path, route_points, checkpoints, track_length, long_water_distance, water_ratio * 100.0,
			world_path, route_path, guidance_path, respawn_path, finish_count, str(finish_matches),
		])
		_show_runtime_hud("ROUND 3 TRACK VERIFY FAIL — CHECK OUTPUT")
		return

	print("ROUND3 ACTIVE TRACK VERIFY PASS revision=%s run_mode=%s track_script=wild_tide_long_water_track.gd route_points=%d checkpoints=%d track_length=%.1f long_water_distance=%.1f water_ratio=%.1f%% world_controller=V4_LONG_WATER route_network=V2_LONG_WATER guidance=V3_LONG_WATER respawn=V2_LONG_WATER finish_lines=%d ai_finish=true segments_29_35=true" % [
		ROUND3_REVISION,
		"CAMPAIGN" if GameManager.campaign_running else "F6_DIRECT",
		route_points, checkpoints, track_length, long_water_distance, water_ratio * 100.0, finish_count,
	])
	_build_zone_thresholds()
	_show_runtime_hud("WILD TIDE LONG WATER VERIFIED — %.0fm TRACK" % track_length)

func _verify_ai_routes_reach_expanded_finish() -> bool:
	var route_points: Array[Vector3] = RaceManager.get_route_points()
	if route_points.is_empty():
		return false
	var finish: Vector3 = route_points[-1]
	var checked: int = 0
	var failures: int = 0
	for node: Node in get_tree().get_nodes_in_group("wilddash_ai_driver"):
		if node == null or node.get_parent() != self or not (node is WildDashAIController):
			continue
		var driver: WildDashAIController = node as WildDashAIController
		if driver.preserve_player_identity:
			continue
		var racer: WildDashCharacterController = driver.get_racer()
		if racer == null:
			continue
		checked += 1
		var route_value: Variant = driver.get("_race_route")
		var route_size: int = 0
		var contains_finish: bool = false
		if route_value is Array:
			var route: Array = route_value
			route_size = route.size()
			for point_value: Variant in route:
				if point_value is Vector3:
					var point: Vector3 = point_value
					if point.distance_to(finish) <= 2.5:
						contains_finish = true
						break
		if not contains_finish:
			failures += 1
		print("ROUND3 AI ROUTE VERIFY animal=%s points=%d finish_matches=%s" % [
			String(racer.animal_id), route_size, str(contains_finish),
		])
	return checked > 0 and failures == 0

func _race_manager_finish_matches_track() -> bool:
	if _track == null or not _track.has_method("get_finish_position"):
		return false
	var route_points: Array[Vector3] = RaceManager.get_route_points()
	if route_points.is_empty():
		return false
	var expected_value: Variant = _track.call("get_finish_position")
	if not (expected_value is Vector3):
		return false
	var expected_finish: Vector3 = expected_value
	return expected_finish.distance_to(route_points[-1]) <= FINISH_MATCH_TOLERANCE

func _build_zone_thresholds() -> void:
	_zone_thresholds.clear()
	_zone_announced.clear()
	var route_points: Array[Vector3] = RaceManager.get_route_points()
	if route_points.size() < EXPECTED_ROUTE_POINTS:
		return
	_zone_thresholds.append({"index": 29, "label": "LONG WATER ENTRY"})
	_zone_thresholds.append({"index": 31, "label": "DELTA RAPIDS"})
	_zone_thresholds.append({"index": 32, "label": "MANGROVE WATER CHANNEL"})
	_zone_thresholds.append({"index": 33, "label": "OPEN WATER SPRINT"})
	_zone_thresholds.append({"index": 35, "label": "FINAL DELTA"})
	for zone: Dictionary in _zone_thresholds:
		var route_index: int = int(zone.get("index", 0))
		zone["distance"] = _distance_to_route_index(route_points, route_index)

func _update_long_water_zone_assertions() -> void:
	var progress: float = RaceManager.get_track_progress(player)
	for zone: Dictionary in _zone_thresholds:
		var label: String = String(zone.get("label", ""))
		if label.is_empty() or _zone_announced.has(label):
			continue
		var distance: float = float(zone.get("distance", INF))
		if progress < distance:
			continue
		_zone_announced[label] = true
		print("ROUND3 LONG WATER ZONE label=%s progress=%.1fm total=%.1fm" % [label, progress, RaceManager.get_track_length()])
		_show_runtime_hud(label)
		break

func _distance_to_route_index(route_points: Array[Vector3], route_index: int) -> float:
	if route_points.is_empty():
		return 0.0
	var safe_index: int = clampi(route_index, 0, route_points.size() - 1)
	var distance: float = 0.0
	for index: int in range(safe_index):
		distance += route_points[index].distance_to(route_points[index + 1])
	return distance

func _script_path(node: Node) -> String:
	if node == null:
		return "<missing>"
	var script_value: Variant = node.get_script()
	if script_value is Script:
		var script: Script = script_value
		return script.resource_path
	return "<no-script>"

func _count_named_nodes(root: Node, target_name: StringName) -> int:
	if root == null:
		return 0
	var count: int = 1 if root.name == target_name else 0
	for child: Node in root.get_children():
		count += _count_named_nodes(child, target_name)
	return count

func _show_runtime_hud(text: String) -> void:
	var hud_value: Variant = get("hud")
	var mode_hud: WildDashModeHUD = hud_value as WildDashModeHUD
	if mode_hud != null:
		mode_hud.set_message(text)
