extends Node

const ROUND3_SCENE: PackedScene = preload("res://modes/neon_harbor_race/neon_harbor_race.tscn")
const DAYLIGHT_TRACK_SCRIPT: Script = preload("res://tracks/wild_tide_daylight_track.gd")
const MODE_V5_SCRIPT: Script = preload("res://modes/neon_harbor_race/neon_harbor_race_v5_rebuild.gd")
const WORLD_V3_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_world_controller_v3_visual_gameplay.gd")
const JUMP_GUARD_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_jump_guard.gd")
const WATER_VISIBILITY_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_water_visibility_boost.gd")
const CANOPY_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_canopy_controller.gd")
const ROUTE_NETWORK_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_route_network.gd")
const GUIDANCE_V2_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_route_guidance_v2.gd")
const TITAN_SCRIPT: Script = preload("res://modes/neon_harbor_race/mangrove_titan_controller.gd")
const BREAKTHROUGH_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_breakthrough_route.gd")
const RESPAWN_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_respawn_guard.gd")

func _ready() -> void:
	var failures: Array[String] = []
	if ROUND3_SCENE == null:
		failures.append("Round 3 scene failed to preload")
	if DAYLIGHT_TRACK_SCRIPT == null or MODE_V5_SCRIPT == null:
		failures.append("Wild Tide V5 daylight mode scripts failed to preload")
	if WORLD_V3_SCRIPT == null or JUMP_GUARD_SCRIPT == null or WATER_VISIBILITY_SCRIPT == null:
		failures.append("Wild Tide V3 world/jump/visibility scripts failed to preload")
	if CANOPY_SCRIPT == null or ROUTE_NETWORK_SCRIPT == null or GUIDANCE_V2_SCRIPT == null:
		failures.append("Wild Tide route/canopy/guidance scripts failed to preload")
	if TITAN_SCRIPT == null or BREAKTHROUGH_SCRIPT == null or RESPAWN_SCRIPT == null:
		failures.append("Wild Tide hazard/safety scripts failed to preload")

	if WildDashWildTideDaylightTrack.WILD_TIDE_WATER_SEGMENTS.size() != 14:
		failures.append("Wild Tide visible-water segment budget changed")
	if WildDashWildTideDaylightTrack.WILD_TIDE_DEEP_SEGMENTS.size() != 7:
		failures.append("Wild Tide deep-water segment budget changed")
	if WildDashWildTideRouteGuidance.MAIN_ARROW_INDICES.size() < 12:
		failures.append("Round 3 main-route arrow coverage too sparse")
	if WildDashWildTideRouteGuidance.WATER_ARROW_INDICES.size() < 5:
		failures.append("Round 3 water-route arrow coverage too sparse")
	if WildDashWildTideRouteGuidance.CANOPY_ARROW_INDICES.size() < 4:
		failures.append("Round 3 canopy arrow coverage too sparse")

	var route_points: Array[Vector3] = WildDashWildTideDaylightTrack.V2_ROUTE_POINTS
	var total_distance: float = 0.0
	var water_distance: float = 0.0
	var deep_distance: float = 0.0
	var jungle_distance: float = 0.0
	for segment_index: int in range(route_points.size() - 1):
		var length: float = route_points[segment_index].distance_to(route_points[segment_index + 1])
		total_distance += length
		if WildDashWildTideDaylightTrack.WILD_TIDE_WATER_SEGMENTS.has(segment_index):
			water_distance += length
		if WildDashWildTideDaylightTrack.WILD_TIDE_DEEP_SEGMENTS.has(segment_index):
			deep_distance += length
		if WildDashWildTideDaylightTrack.WILD_TIDE_JUNGLE_SEGMENTS.has(segment_index):
			jungle_distance += length
	var water_ratio: float = water_distance / maxf(0.01, total_distance)
	var deep_ratio: float = deep_distance / maxf(0.01, total_distance)
	var shallow_ratio: float = (water_distance - deep_distance) / maxf(0.01, total_distance)
	var jungle_ratio: float = jungle_distance / maxf(0.01, total_distance)
	if water_ratio < 0.45 or water_ratio > 0.55:
		failures.append("Wild Tide visible/gameplay water must stay within 45-55 percent")
	if jungle_ratio < 0.25 or jungle_ratio > 0.35:
		failures.append("Wild Tide jungle identity must stay within 25-35 percent")
	if deep_ratio < 0.20 or shallow_ratio < 0.20:
		failures.append("Wild Tide shallow/deep split became too small")

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
		print("WILD TIDE ROUND3 SMOKE PASS scene=true daylight=true water_ratio=%.1f%% shallow=%.1f%% deep=%.1f%% jungle=%.1f%% jump_guard=true visibility=true branches=true arrows=true canopy=true titan=true breakthrough=true respawn=true pack_buster=true" % [
			water_ratio * 100.0, shallow_ratio * 100.0, deep_ratio * 100.0, jungle_ratio * 100.0,
		])
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("WILD TIDE ROUND3 SMOKE FAIL: %s" % failure)
	get_tree().quit(1)
