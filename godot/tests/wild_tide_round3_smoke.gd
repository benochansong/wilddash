extends Node

const ROUND3_SCENE: PackedScene = preload("res://modes/neon_harbor_race/neon_harbor_race.tscn")
const WORLD_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_world_controller.gd")
const CANOPY_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_canopy_controller.gd")
const TITAN_SCRIPT: Script = preload("res://modes/neon_harbor_race/mangrove_titan_controller.gd")
const BREAKTHROUGH_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_breakthrough_route.gd")
const RESPAWN_SCRIPT: Script = preload("res://modes/neon_harbor_race/wild_tide_respawn_guard.gd")

func _ready() -> void:
	var failures: Array[String] = []
	if ROUND3_SCENE == null:
		failures.append("Round 3 scene failed to preload")
	if WORLD_SCRIPT == null or CANOPY_SCRIPT == null or TITAN_SCRIPT == null or BREAKTHROUGH_SCRIPT == null or RESPAWN_SCRIPT == null:
		failures.append("Wild Tide runtime scripts failed to preload")

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
		print("WILD TIDE ROUND3 SMOKE PASS scene=true water=true canopy=true titan=true breakthrough=true respawn=true pack_buster=true")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("WILD TIDE ROUND3 SMOKE FAIL: %s" % failure)
	get_tree().quit(1)
