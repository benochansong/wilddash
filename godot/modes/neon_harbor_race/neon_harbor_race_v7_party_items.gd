extends "res://modes/neon_harbor_race/neon_harbor_race_v6_long_water_runtime_verify.gd"

## Round 3 V7 — distance-sampled party item distribution.
##
## The long-water track grew from ~1524m to ~1895m, but the inherited box list
## still stopped at old route index 23. V7 samples stations by cumulative route
## distance, so future track edits keep the item economy distributed and the
## 371m water finale receives four explicit combat/catch-up stations.

const ROUND3_ITEM_STATION_PROGRESS: Array[float] = [
	0.08, 0.17, 0.27, 0.37, 0.47, 0.57, 0.67, 0.76, 0.84, 0.90, 0.955, 0.985,
]
const ROUND3_WIDE_STATION_PROGRESS: Array[float] = [0.47, 0.76, 0.955]
const ROUND3_LONG_WATER_PROGRESS_START: float = 0.80
const ROUND3_LONG_WATER_SEGMENT_START: int = 29
const ROUND3_ITEM_RESPAWN_LEGACY_SECONDS: float = 4.0

func _spawn_item_boxes() -> void:
	if _route_points.size() < 3:
		push_warning("ROUND3 PARTY ITEM DISTRIBUTION skipped: route unavailable")
		return
	var cumulative: PackedFloat32Array = _build_round3_route_cumulative_distance()
	if cumulative.size() != _route_points.size():
		push_warning("ROUND3 PARTY ITEM DISTRIBUTION skipped: cumulative route mismatch")
		return
	var total_distance: float = float(cumulative[cumulative.size() - 1])
	if total_distance <= 0.01:
		return

	var long_water_stations: int = 0
	var wide_stations: int = 0
	for station_progress: float in ROUND3_ITEM_STATION_PROGRESS:
		var target_distance: float = clampf(station_progress, 0.0, 1.0) * total_distance
		var segment_index: int = _round3_segment_index_for_distance(target_distance, cumulative)
		if segment_index < 0 or segment_index + 1 >= _route_points.size():
			continue
		var start_distance: float = float(cumulative[segment_index])
		var end_distance: float = float(cumulative[segment_index + 1])
		var segment_distance: float = maxf(0.001, end_distance - start_distance)
		var local_t: float = clampf((target_distance - start_distance) / segment_distance, 0.0, 1.0)
		var a: Vector3 = _route_points[segment_index]
		var b: Vector3 = _route_points[segment_index + 1]
		var point: Vector3 = a.lerp(b, local_t)
		var tangent: Vector3 = b - a
		tangent.y = 0.0
		if tangent.length_squared() <= 0.001:
			tangent = Vector3.FORWARD
		else:
			tangent = tangent.normalized()
		var right: Vector3 = Vector3(-tangent.z, 0.0, tangent.x)
		var width: float = _round3_segment_width(segment_index)
		var lane_offsets: Array[float] = _round3_lane_offsets(segment_index, width, station_progress)
		if lane_offsets.size() >= 4:
			wide_stations += 1
		if station_progress >= ROUND3_LONG_WATER_PROGRESS_START:
			long_water_stations += 1

		var station_label: String = _round3_station_label(station_progress)
		for lane_offset: float in lane_offsets:
			var box: WildDashItemBox = ITEM_BOX_SCENE.instantiate() as WildDashItemBox
			if box == null:
				continue
			box.name = "%s_P%04d_L%s" % [
				station_label,
				roundi(station_progress * 1000.0),
				str(lane_offset).replace("-", "N").replace(".", "_"),
			]
			box.position = point + right * lane_offset + Vector3.UP * 1.35
			# Race pickups are per-racer in RC9. This value is retained only for the
			# ItemBox's non-race legacy fallback path.
			box.respawn_seconds = ROUND3_ITEM_RESPAWN_LEGACY_SECONDS
			add_child(box)
			_item_boxes.append(box)

	print("ROUND3 PARTY ITEM DISTRIBUTION READY stations=%d boxes=%d distance_sampled=true track_length=%.1fm long_water_stations=%d wide_stations=%d progresses=%s party_pickup=true" % [
		ROUND3_ITEM_STATION_PROGRESS.size(), _item_boxes.size(), total_distance,
		long_water_stations, wide_stations, str(ROUND3_ITEM_STATION_PROGRESS),
	])
	print("ROUND3 LONG WATER ITEM STATIONS entry=0.840 mangrove=0.900 open_water=0.955 final_delta=0.985 count=%d" % long_water_stations)

func get_round3_item_station_progresses() -> Array[float]:
	return ROUND3_ITEM_STATION_PROGRESS.duplicate()

func get_round3_long_water_station_count() -> int:
	var count: int = 0
	for progress: float in ROUND3_ITEM_STATION_PROGRESS:
		if progress >= ROUND3_LONG_WATER_PROGRESS_START:
			count += 1
	return count

func _build_round3_route_cumulative_distance() -> PackedFloat32Array:
	var cumulative: PackedFloat32Array = PackedFloat32Array()
	if _route_points.is_empty():
		return cumulative
	cumulative.append(0.0)
	var running: float = 0.0
	for index: int in range(1, _route_points.size()):
		running += _route_points[index - 1].distance_to(_route_points[index])
		cumulative.append(running)
	return cumulative

func _round3_segment_index_for_distance(target_distance: float, cumulative: PackedFloat32Array) -> int:
	if _route_points.size() < 2 or cumulative.size() != _route_points.size():
		return -1
	for index: int in range(1, cumulative.size()):
		if float(cumulative[index]) >= target_distance:
			return index - 1
	return _route_points.size() - 2

func _round3_segment_width(segment_index: int) -> float:
	if _track != null and _track.has_method("get_segment_width"):
		return maxf(10.0, float(_track.call("get_segment_width", segment_index)))
	return 18.0

func _round3_lane_offsets(segment_index: int, width: float, station_progress: float) -> Array[float]:
	var is_long_water: bool = segment_index >= ROUND3_LONG_WATER_SEGMENT_START
	var is_wide_authored: bool = _round3_is_wide_progress(station_progress)
	if is_long_water and width >= 22.0:
		return [-6.0, -2.0, 2.0, 6.0]
	if is_wide_authored and width >= 18.0:
		return [-4.5, -1.5, 1.5, 4.5]
	if width >= 24.0:
		return [-5.4, -1.8, 1.8, 5.4]
	return [-3.2, 0.0, 3.2]

func _round3_is_wide_progress(progress: float) -> bool:
	for wide_progress: float in ROUND3_WIDE_STATION_PROGRESS:
		if absf(progress - wide_progress) <= 0.001:
			return true
	return false

func _round3_station_label(progress: float) -> String:
	if absf(progress - 0.84) <= 0.002:
		return "LongWaterEntryItem"
	if absf(progress - 0.90) <= 0.002:
		return "MangroveChannelItem"
	if absf(progress - 0.955) <= 0.002:
		return "OpenWaterItem"
	if absf(progress - 0.985) <= 0.002:
		return "FinalDeltaItem"
	return "Round3Item"
