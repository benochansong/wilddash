class_name WildDashGrandPrixV2Section
extends RefCounted

## Data-only definition for one Round 1 Adventure section.
## The same anchors feed the visual road, collision road, AI route and checkpoint placement.

var id: StringName
var display_name: String
var terrain_type: StringName
var target_width: float
var target_elevation: float
var obstacle_profile: StringName
var ai_profile: StringName
var sample_step: float
var anchors: Array[Vector3] = []

func _init(
	section_id: StringName,
	section_name: String,
	section_terrain: StringName,
	width: float,
	elevation: float,
	obstacles: StringName,
	ai: StringName,
	section_anchors: Array,
	step: float = 10.0
) -> void:
	id = section_id
	display_name = section_name
	terrain_type = section_terrain
	target_width = width
	target_elevation = elevation
	obstacle_profile = obstacles
	ai_profile = ai
	anchors.assign(section_anchors)
	sample_step = clampf(step, 8.0, 15.0)

func get_anchor_length() -> float:
	var total := 0.0
	for index in range(anchors.size() - 1):
		total += anchors[index].distance_to(anchors[index + 1])
	return total

func get_min_elevation() -> float:
	if anchors.is_empty():
		return 0.0
	var result := anchors[0].y
	for point: Vector3 in anchors:
		result = minf(result, point.y)
	return result

func get_max_elevation() -> float:
	if anchors.is_empty():
		return 0.0
	var result := anchors[0].y
	for point: Vector3 in anchors:
		result = maxf(result, point.y)
	return result
