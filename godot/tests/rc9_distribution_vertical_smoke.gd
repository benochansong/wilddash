extends Node

const GRAND_PRIX_SCENE: PackedScene = preload("res://modes/grand_prix/grand_prix.tscn")
const FRUIT_SCENE: PackedScene = preload("res://modes/fruit_collection/fruit_collection.tscn")
const ITEM_MODE: Script = preload("res://modes/grand_prix/grand_prix_v5_item_chaos.gd")
const ROUND2: Script = preload("res://modes/fruit_collection/fruit_frenzy_v12_vertical_dispersion.gd")
const ROAD_CLEARANCE: Script = preload("res://tracks/grand_prix_v5_road_corridor_clearance.gd")

func _ready() -> void:
	assert(GRAND_PRIX_SCENE != null)
	assert(FRUIT_SCENE != null)
	assert(ROAD_CLEARANCE != null)
	var station_progress: Array = ITEM_MODE.ITEM_STATION_PROGRESS
	assert(station_progress.size() == 11)
	assert(float(station_progress[0]) >= 0.09)
	assert(float(station_progress[station_progress.size() - 1]) >= 0.97)
	var max_gap: float = 0.0
	for i: int in range(1, station_progress.size()):
		max_gap = maxf(max_gap, float(station_progress[i]) - float(station_progress[i - 1]))
	assert(max_gap <= 0.14)
	assert(int(ROUND2.V12_FRUIT_COUNT) == 30)
	assert((ROUND2.V12_HIGH_INDICES as Array).size() == 6)
	assert((ROUND2.V12_TREE_INDICES as Array).size() == 7)
	assert((ROUND2.V12_TREE_TOP_HEIGHTS as Array).size() == 6)
	print("RC9 DISTRIBUTION VERTICAL SMOKE PASS stations=%d max_gap=%.3f fruit=%d high=%d tree=%d trees=%d" % [
		station_progress.size(), max_gap, int(ROUND2.V12_FRUIT_COUNT),
		(ROUND2.V12_HIGH_INDICES as Array).size(), (ROUND2.V12_TREE_INDICES as Array).size(),
		(ROUND2.V12_TREE_TOP_HEIGHTS as Array).size(),
	])
	get_tree().quit()
