extends "res://modes/grand_prix/grand_prix_v2_mode.gd"

## Round 1 Item Chaos V2 station pass.
## 15 stations vs the previous 11 (~1.36x) and a modestly faster respawn.

const CHAOS_ITEM_BOX_ROUTE_INDICES: Array[int] = [2, 4, 6, 8, 10, 11, 14, 16, 18, 19, 21, 22, 23, 25, 26]
const CHAOS_WIDE_ITEM_STATIONS: Array[int] = [4, 8, 14, 19, 23, 25]
const CHAOS_ITEM_BOX_LANE_OFFSETS: Array[float] = [-3.2, 0.0, 3.2]
const CHAOS_ITEM_BOX_WIDE_LANE_OFFSETS: Array[float] = [-4.2, -1.4, 1.4, 4.2]

func _spawn_item_boxes() -> void:
	var respawn := 4.1
	if RaceManager.racers.size() >= 18:
		respawn = 3.4
	elif RaceManager.racers.size() >= 15:
		respawn = 3.8
	for route_index in CHAOS_ITEM_BOX_ROUTE_INDICES:
		if route_index <= 0 or route_index >= _route_points.size() - 1:
			continue
		var point := _route_points[route_index]
		var tangent := _route_points[route_index + 1] - _route_points[route_index - 1]
		tangent.y = 0.0
		tangent = Vector3.FORWARD if tangent.length_squared() <= 0.001 else tangent.normalized()
		var right := Vector3(-tangent.z, 0.0, tangent.x)
		var lane_offsets := CHAOS_ITEM_BOX_WIDE_LANE_OFFSETS if CHAOS_WIDE_ITEM_STATIONS.has(route_index) and RaceManager.racers.size() >= 15 else CHAOS_ITEM_BOX_LANE_OFFSETS
		for lane_offset in lane_offsets:
			var box := ITEM_BOX_SCENE.instantiate() as WildDashItemBox
			if box == null:
				continue
			box.name = "ChaosItemBox_R%02d_L%s" % [route_index, str(lane_offset).replace("-", "N").replace(".", "_")]
			box.position = point + right * lane_offset + Vector3.UP * 1.35
			box.respawn_seconds = respawn
			add_child(box)
			_item_boxes.append(box)
	print("ITEM CHAOS boxes=%d stations=%d density_scale=1.36 respawn=%.1fs expanded_target=0.52" % [
		_item_boxes.size(), CHAOS_ITEM_BOX_ROUTE_INDICES.size(), respawn,
	])
