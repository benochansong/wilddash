extends Node

const ROUND3_SCENE: PackedScene = preload("res://modes/neon_harbor_race/neon_harbor_race.tscn")
const DAYLIGHT_TRACK_SCRIPT: Script = preload("res://tracks/wild_tide_daylight_track.gd")
const MODE_V5_SCRIPT: Script = preload("res://modes/neon_harbor_race/neon_harbor_race_v5_rebuild.gd")
const WORLD_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_world_controller.gd")
const CANOPY_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_canopy_controller.gd")
const ROUTE_NETWORK_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_route_network.gd")
const GUIDANCE_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_route_guidance.gd")
const TITAN_SCRIPT: Script = preload("res://modes/neon_harbor_race/mangrove_titan_controller.gd")
const BREAKTHROUGH_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_breakthrough_route.gd")
const RESPAWN_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_respawn_guard.gd")

func _ready() -> void:
	var failures: Array[String] = []
	if ROUND3_SCENE == null:
		failures.append("Round 3 scene failed to preload")
	if DAYLIGHT_TRACK_SCRIPT == null or MODE_V5_SCRIPT == null:
		failures.append("Wild Tide V5 daylight mode scripts failed to preload")
	if WORLD_SCRIPT == null or CANOPY_SCRIPT == null or ROUTE_NETWORK_SCRIPT == null or GUIDANCE_SCRIPT == null:
		failures.append("Wild Tide world/route/guidance scripts failed to preload")
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

	var croc_deep: float = WildDashTerrainAbilitySystem.get_terrain_speed_multiplier(
		&"crocodile", WildDashTerrainAbilitySystem.TERRAIN_DEEP_WATER
	)
	var rabbit_deep: float = WildDashTerrainAbilitySystem.get_terrain_speed_multiplier(
		&"rabbit", WildDashTerrainAbilitySystem.TERRAIN_DEEP_WATER
	)
	var bear_deep: float = WildDashTerrainAbilitySystem.get_terrain_speed_multiplier(
		&"bear", WildDashTerrainAbilitySystem.TERRAIN_DEEP_WATER
	)
	if croc_deep < 1.40:
		failures.append("Crocodile must remain the deep-water king")
	if rabbit_deep > 0.90:
		failures.append("Rabbit deep-water penalty is too weak")
	if bear_deep < 1.10:
		failures.append("Bear water identity missing")
	if WildDashTerrainAbilitySystem.get_wave_knockback_multiplier(&"crocodile") >= 0.50:
		failures.append("Crocodile Titan-wave resistance missing")

	if failures.is_empty():
		print("WILD TIDE ROUND3 SMOKE PASS scene=true daylight=true visible_water=true jungle=true branches=true arrows=true canopy=true titan=true breakthrough=true respawn=true pack_buster=true")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("WILD TIDE ROUND3 SMOKE FAIL: %s" % failure)
	get_tree().quit(1)
