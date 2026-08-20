extends Node

const BASIN_DEPTH_METERS: float = 7.0
const ZONE1_WATER_Y: float = -0.15
const RECOVERY_WATER_Y: Dictionary = {
	"Recovery_Z2": -0.75,
	"Recovery_Z3": 8.75,
	"Recovery_Z4": 15.75,
	"Recovery_Z5": 23.25,
	"Recovery_Z6": 48.25,
}

func _ready() -> void:
	call_deferred("_apply_final_water_depth")

func _apply_final_water_depth() -> void:
	var root := get_parent()
	if root == null:
		return
	var world := root.get_node_or_null("LogspireWorld") as Node3D
	if world == null:
		return
	var hidden_legacy_decks: int = 0
	var forest_floor := world.get_node_or_null("FOREST_FLOOR") as Node3D
	if forest_floor != null:
		forest_floor.position.y = ZONE1_WATER_Y - BASIN_DEPTH_METERS - 0.30
	for recovery_name_value: Variant in RECOVERY_WATER_Y.keys():
		var recovery_name: String = String(recovery_name_value)
		var water_y: float = float(RECOVERY_WATER_Y[recovery_name_value])
		hidden_legacy_decks += _set_recovery_pair_depth(world, recovery_name, water_y - BASIN_DEPTH_METERS)
	var zone1_area := world.get_node_or_null("Recovery_Z1_Accessible") as Area3D
	if zone1_area != null:
		zone1_area.position.y = ZONE1_WATER_Y - BASIN_DEPTH_METERS + 1.20
	print("LOGSPIRE WATER DEPTH FINAL depth=%.1fm walking_floor=false legacy_deck_visuals_hidden=%d water_surface_clear=true" % [
		BASIN_DEPTH_METERS,
		hidden_legacy_decks,
	])

func _set_recovery_pair_depth(world: Node3D, recovery_name: String, floor_top_y: float) -> int:
	var hidden_count: int = 0
	var deck := world.get_node_or_null(NodePath(recovery_name + "_Deck")) as Node3D
	if deck != null:
		deck.position.y = floor_top_y - 0.30
		# These broad legacy decks are only deep fail-safe collision floors now.
		# Their mesh must never appear as a giant mint platform above the river.
		deck.visible = false
		hidden_count = 1
	var area := world.get_node_or_null(NodePath(recovery_name)) as Area3D
	if area != null:
		area.position.y = floor_top_y + 1.20
	return hidden_count
