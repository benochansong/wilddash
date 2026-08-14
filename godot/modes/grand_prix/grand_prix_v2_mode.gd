extends "res://modes/grand_prix/grand_prix_rc5_mode.gd"

## V2 adapter for systems that used legacy 29-point magic indices.
## Stage 1 deliberately sends every AI through the full shared Adventure route;
## terrain-aware branch choice is added in later Terrain Adventure stages.

const V2_ITEM_STATION_PROGRESS: Array[float] = [
	0.07, 0.15, 0.24, 0.33, 0.42, 0.51, 0.60, 0.69, 0.78, 0.87, 0.94,
]
const V2_WIDE_ITEM_STATIONS: Array[int] = [2, 5, 8]

func _build_shortcut_route(_skip_route_index: int) -> Array[Vector3]:
	# Legacy personality code still asks for A/B shortcut routes. Until the V2
	# terrain branch scorer exists, return the authoritative full route so every
	# racer reaches River -> Mountain -> Summit -> Descent -> Finish reliably.
	return _build_race_route_with_runout()

func _spawn_item_boxes() -> void:
	var respawn := 5.0
	if RaceManager.racers.size() >= 18:
		respawn = 3.6
	elif RaceManager.racers.size() >= 15:
		respawn = 4.0

	for station_index in range(V2_ITEM_STATION_PROGRESS.size()):
		if _route_points.size() < 3:
			break
		var progress := V2_ITEM_STATION_PROGRESS[station_index]
		var route_index := clampi(roundi(progress * float(_route_points.size() - 2)), 1, _route_points.size() - 2)
		var point := _route_points[route_index]
		var tangent := _route_points[route_index + 1] - _route_points[route_index - 1]
		tangent.y = 0.0
		tangent = Vector3.FORWARD if tangent.length_squared() <= 0.001 else tangent.normalized()
		var right := Vector3(-tangent.z, 0.0, tangent.x)

		var road_width := 16.0
		if _track != null and _track.has_method("get_v2_width_for_segment"):
			road_width = float(_track.call("get_v2_width_for_segment", route_index))
		var wide := V2_WIDE_ITEM_STATIONS.has(station_index) and road_width >= 16.0 and RaceManager.racers.size() >= 15
		var lane_offsets: Array[float] = [-3.0, 0.0, 3.0]
		if wide:
			lane_offsets = [-4.2, -1.4, 1.4, 4.2]
		else:
			var side_offset := minf(3.0, maxf(2.1, road_width * 0.27))
			lane_offsets = [-side_offset, 0.0, side_offset]

		for lane_offset: float in lane_offsets:
			var box := ITEM_BOX_SCENE.instantiate() as WildDashItemBox
			if box == null:
				continue
			box.name = "ItemBox_V2_S%02d_L%s" % [
				station_index + 1,
				str(lane_offset).replace("-", "N").replace(".", "_"),
			]
			box.position = point + right * lane_offset + Vector3.UP * 1.35
			box.respawn_seconds = respawn
			add_child(box)
			_item_boxes.append(box)

	print("GRAND PRIX V2 ITEM BOXES PASS count=%d stations=%d respawn=%.1fs progress_based=true" % [
		_item_boxes.size(), V2_ITEM_STATION_PROGRESS.size(), respawn,
	])
