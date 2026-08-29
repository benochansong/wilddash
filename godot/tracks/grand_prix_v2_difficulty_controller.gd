class_name WildDashGrandPrixV2DifficultyController
extends Node

## Stage 3 difficulty adapter. Dynamic hazards read the same profile directly;
## this node applies the remaining water-current scale after Stage 2 zones exist.

func _ready() -> void:
	call_deferred("_apply_when_ready")

func _apply_when_ready() -> void:
	for _frame: int in range(7):
		await get_tree().process_frame
	var profile: Dictionary = WildDashGrandPrixV2Stage3Controller.get_difficulty_profile(GameManager.difficulty)
	var current_scale: float = float(profile.get("current_scale", 1.0))
	var water_zones: int = 0
	for node: Node in get_tree().get_nodes_in_group("wilddash_terrain_zone"):
		if not node is WildDashTerrainZone:
			continue
		var zone: WildDashTerrainZone = node as WildDashTerrainZone
		if zone.get_terrain_type() != &"water":
			continue
		var direction: Vector3 = zone.get_current_direction()
		var strength: float = zone.get_current_strength()
		zone.configure_current(direction, strength * current_scale)
		water_zones += 1
	print("GRAND PRIX V2 DIFFICULTY READY difficulty=%s water_zones=%d current_scale=%.2f hazard_speed=%.2f extra_hazards=%s" % [
		String(GameManager.difficulty), water_zones, current_scale,
		float(profile.get("hazard_speed", 1.0)), str(bool(profile.get("extra_hazards", false))),
	])
