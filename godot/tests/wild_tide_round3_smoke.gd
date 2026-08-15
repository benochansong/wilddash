extends Node

const ROUND3_SCENE: PackedScene = preload("res://modes/neon_harbor_race/neon_harbor_race.tscn")
const LONG_TRACK_SCENE: PackedScene = preload("res://tracks/neon_harbor_track.tscn")
const LONG_TRACK_SCRIPT: Script = preload("res://tracks/wild_tide_long_water_track.gd")
const MODE_V5_SCRIPT: Script = preload("res://modes/neon_harbor_race/neon_harbor_race_v5_rebuild.gd")
const MODE_V6_SCRIPT: Script = preload("res://modes/neon_harbor_race/neon_harbor_race_v6_long_water_runtime_verify.gd")
const WORLD_V4_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_world_controller_v4_long_water.gd")
const JUMP_GUARD_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_jump_guard.gd")
const WATER_VISIBILITY_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_water_visibility_boost.gd")
const CANOPY_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_canopy_controller.gd")
const ROUTE_NETWORK_V2_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_route_network_v2_long_water.gd")
const GUIDANCE_V3_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_route_guidance_v3_long_water.gd")
const TITAN_SCRIPT: Script = preload("res://modes/neon_harbor_race/mangrove_titan_controller.gd")
const BREAKTHROUGH_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_breakthrough_route.gd")
const RESPAWN_V2_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_respawn_guard_v2_long_water.gd")

const EXPECTED_ROUND3_MODE_SCRIPT: String = "res://modes/neon_harbor_race/neon_harbor_race_v6_long_water_runtime_verify.gd"
const EXPECTED_TRACK_SCRIPT: String = "res://tracks/wild_tide_long_water_track.gd"

func _ready() -> void:
	var failures: Array[String] = []
	if ROUND3_SCENE == null or LONG_TRACK_SCENE == null:
		failures.append("Round 3 production scene / track scene failed to preload")
	if LONG_TRACK_SCRIPT == null or MODE_V5_SCRIPT == null or MODE_V6_SCRIPT == null:
		failures.append("Wild Tide long-water track/mode scripts failed to preload")
	if WORLD_V4_SCRIPT == null or JUMP_GUARD_SCRIPT == null or WATER_VISIBILITY_SCRIPT == null:
		failures.append("Wild Tide long-water world/jump/visibility scripts failed to preload")
	if CANOPY_SCRIPT == null or ROUTE_NETWORK_V2_SCRIPT == null or GUIDANCE_V3_SCRIPT == null:
		failures.append("Wild Tide long-water route/canopy/guidance scripts failed to preload")
	if TITAN_SCRIPT == null or BREAKTHROUGH_SCRIPT == null or RESPAWN_V2_SCRIPT == null:
		failures.append("Wild Tide hazard/safety scripts failed to preload")

	if ROUND3_SCENE != null:
		var round3_root: Node = ROUND3_SCENE.instantiate()
		if round3_root == null:
			failures.append("Round 3 production scene failed to instantiate")
		else:
			var mode_path: String = _script_path(round3_root)
			if mode_path != EXPECTED_ROUND3_MODE_SCRIPT:
				failures.append("Round 3 production root is not V6 runtime verifier: %s" % mode_path)
			round3_root.free()

	if LONG_TRACK_SCENE != null:
		var track_root: Node = LONG_TRACK_SCENE.instantiate()
		if track_root == null:
			failures.append("Round 3 track scene failed to instantiate")
		else:
			var track_path: String = _script_path(track_root)
			if track_path != EXPECTED_TRACK_SCRIPT:
				failures.append("Round 3 production track scene is not long-water authoritative: %s" % track_path)
			track_root.free()

	var route_points: Array[Vector3] = WildDashWildTideLongWaterTrack.EXPANDED_ROUTE_POINTS
	if route_points.size() != 37:
		failures.append("Long-water route must contain 37 route points")
	if WildDashWildTideLongWaterTrack.EXPANDED_CHECKPOINT_ROUTE_INDICES.size() != 11:
		failures.append("Long-water route must contain 11 checkpoints")
	if WildDashWildTideLongWaterTrack.EXPANDED_WATER_SEGMENTS.size() != 21:
		failures.append("Expanded water segment budget changed")
	for long_segment: int in range(29, 36):
		if not WildDashWildTideLongWaterTrack.EXPANDED_WATER_SEGMENTS.has(long_segment):
			failures.append("Long-water segment %d is not authored as gameplay water" % long_segment)

	var total_distance: float = 0.0
	var water_distance: float = 0.0
	var deep_distance: float = 0.0
	var jungle_distance: float = 0.0
	var long_water_distance: float = 0.0
	for segment_index: int in range(route_points.size() - 1):
		var length: float = route_points[segment_index].distance_to(route_points[segment_index + 1])
		total_distance += length
		if WildDashWildTideLongWaterTrack.EXPANDED_WATER_SEGMENTS.has(segment_index):
			water_distance += length
		if WildDashWildTideLongWaterTrack.EXPANDED_DEEP_SEGMENTS.has(segment_index):
			deep_distance += length
		if WildDashWildTideDaylightTrack.WILD_TIDE_JUNGLE_SEGMENTS.has(segment_index) or WildDashWildTideLongWaterTrack.LONG_MANGROVE_CHANNEL_SEGMENTS.has(segment_index):
			jungle_distance += length
		if segment_index >= WildDashWildTideLongWaterTrack.LONG_WATER_START_SEGMENT and segment_index <= WildDashWildTideLongWaterTrack.LONG_WATER_END_SEGMENT:
			long_water_distance += length

	var added_distance: float = total_distance - WildDashWildTideLongWaterTrack.ORIGINAL_TRACK_DISTANCE
	var water_ratio: float = water_distance / maxf(0.01, total_distance)
	var deep_ratio: float = deep_distance / maxf(0.01, total_distance)
	var shallow_ratio: float = (water_distance - deep_distance) / maxf(0.01, total_distance)
	var jungle_ratio: float = jungle_distance / maxf(0.01, total_distance)

	if total_distance < 1850.0 or total_distance > 2000.0:
		failures.append("Expanded Round 3 track must stay within 1850-2000m")
	if added_distance < 300.0 or added_distance > 450.0:
		failures.append("Round 3 expansion must add 300-450m")
	if long_water_distance < 300.0:
		failures.append("Long-water finale must exceed 300m")
	if water_ratio < 0.50 or water_ratio > 0.60:
		failures.append("Expanded total water ratio must stay within 50-60 percent")
	if deep_ratio < 0.25 or shallow_ratio < 0.24:
		failures.append("Expanded shallow/deep water split became too small")
	if jungle_ratio < 0.25:
		failures.append("Mangrove identity became too sparse after track expansion")

	var croc_deep: float = WildDashTerrainAbilitySystem.get_terrain_speed_multiplier(
		&"crocodile", WildDashTerrainAbilitySystem.TERRAIN_DEEP_WATER
	)
	var rabbit_deep: float = WildDashTerrainAbilitySystem.get_terrain_speed_multiplier(
		&"rabbit", WildDashTerrainAbilitySystem.TERRAIN_DEEP_WATER
	)
	if croc_deep <= rabbit_deep:
		failures.append("Crocodile must remain stronger than Rabbit in deep water")
	if WildDashTerrainAbilitySystem.get_wave_knockback_multiplier(&"crocodile") >= 0.50:
		failures.append("Crocodile Titan-wave resistance missing")

	if failures.is_empty():
		print("WILD TIDE ROUND3 LONG WATER SMOKE PASS active_chain_v6=true production_track=long_water total=%.1fm added=%.1fm long_water=%.1fm water=%.1f%% shallow=%.1f%% deep=%.1f%% jungle=%.1f%% checkpoints=11 segments_29_35=true jump_guard=true routes=true arrows=true canopy=true titan=true respawn=true pack_buster=true" % [
			total_distance,
			added_distance,
			long_water_distance,
			water_ratio * 100.0,
			shallow_ratio * 100.0,
			deep_ratio * 100.0,
			jungle_ratio * 100.0,
		])
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("WILD TIDE ROUND3 LONG WATER SMOKE FAIL: %s" % failure)
	get_tree().quit(1)

func _script_path(node: Node) -> String:
	if node == null:
		return "<missing>"
	var script_value: Variant = node.get_script()
	if script_value is Script:
		var script: Script = script_value
		return script.resource_path
	return "<no-script>"
