class_name WildDashWildTideLongWaterTrack
extends "res://tracks/wild_tide_daylight_track.gd"

## Round 3 long-water expansion.
##
## The original Wild Tide route is preserved point-for-point through its old
## finish. Seven new route points then continue south into a 371m continuous
## water finale: deep channel -> delta rapids -> mangrove channel -> open-water
## sprint -> shallow final delta. The new finish/checkpoints are authoritative.

const ORIGINAL_TRACK_DISTANCE: float = 1523.9571
const LONG_WATER_START_SEGMENT: int = 29
const LONG_WATER_END_SEGMENT: int = 35

const EXPANDED_ROUTE_POINTS: Array[Vector3] = [
	Vector3(0.0, 0.0, 56.0),
	Vector3(0.0, 0.0, 14.0),
	Vector3(42.0, 0.0, -24.5),
	Vector3(91.0, 0.0, -42.0),
	Vector3(133.0, 0.0, -80.5),
	Vector3(129.5, 0.0, -129.5),
	Vector3(87.5, 0.0, -161.0),
	Vector3(38.5, 0.0, -171.5),
	Vector3(-14.0, 0.0, -161.0),
	Vector3(-59.5, 0.0, -189.0),
	Vector3(-98.0, 0.0, -227.5),
	Vector3(-108.5, 0.0, -280.0),
	Vector3(-77.0, 0.0, -318.5),
	Vector3(-28.0, 0.0, -332.5),
	Vector3(24.5, 0.0, -322.0),
	Vector3(73.5, 0.0, -350.0),
	Vector3(108.5, 0.0, -392.0),
	Vector3(101.5, 0.0, -441.0),
	Vector3(59.5, 0.0, -472.5),
	Vector3(7.0, 0.0, -483.0),
	Vector3(-45.5, 0.0, -469.0),
	Vector3(-87.5, 0.0, -497.0),
	Vector3(-101.5, 0.0, -546.0),
	Vector3(-73.5, 0.0, -591.5),
	Vector3(-24.5, 0.0, -612.5),
	Vector3(31.5, 0.0, -605.5),
	Vector3(73.5, 0.0, -633.5),
	Vector3(80.5, 0.0, -682.5),
	Vector3(42.0, 0.0, -724.5),
	Vector3(0.0, 0.0, -756.0),
	# NEW LONG WATER COURSE
	Vector3(-32.0, 0.0, -790.0),
	Vector3(-58.0, 0.0, -835.0),
	Vector3(-38.0, 0.0, -885.0),
	Vector3(8.0, 0.0, -925.0),
	Vector3(48.0, 0.0, -970.0),
	Vector3(22.0, 0.0, -1018.0),
	Vector3(0.0, 0.0, -1055.0),
]

const EXPANDED_SEGMENT_WIDTHS: Array[float] = [
	20.0, 20.0, 18.0, 18.0,
	16.0, 14.0, 15.0, 16.0,
	11.0, 10.0, 12.0, 13.0,
	15.0, 15.0, 14.0, 15.0,
	18.0, 18.0, 17.0, 18.0, 18.0,
	16.0, 18.0, 18.0, 16.0,
	18.0, 18.0, 20.0, 20.0,
	# long-water finale: deep, deep, rapids, mangrove, open, open, final delta
	22.0, 24.0, 18.0, 16.0, 28.0, 30.0, 22.0,
]

const EXPANDED_CHECKPOINT_ROUTE_INDICES: Array[int] = [3, 6, 9, 12, 15, 18, 21, 24, 28, 31, 34]
const EXPANDED_WATER_SEGMENTS: Array[int] = [
	5, 6, 7, 8, 9, 10, 11, 12,
	17, 18, 19, 20, 21, 22,
	29, 30, 31, 32, 33, 34, 35,
]
const EXPANDED_DEEP_SEGMENTS: Array[int] = [6, 7, 8, 17, 18, 19, 20, 29, 30, 33, 34]
const LONG_MANGROVE_CHANNEL_SEGMENTS: Array[int] = [31, 32]
const LONG_RAPIDS_SEGMENTS: Array[int] = [31]
const LONG_OPEN_WATER_SEGMENTS: Array[int] = [33, 34]
const LONG_FINAL_DELTA_SEGMENTS: Array[int] = [35]

const EXPANDED_FLOOR_SIZE: Vector3 = Vector3(430.0, 0.50, 1300.0)
const EXPANDED_FLOOR_CENTER: Vector3 = Vector3(8.0, -0.30, -480.0)

func _ready() -> void:
	_v2_build_materials()
	_v2_build_night_environment()
	_v2_build_world_floor()
	_v2_build_road()
	_v2_build_start_finish()
	_v2_build_checkpoints()
	RaceManager.configure_track(get_route_points(), get_checkpoint_positions())
	var total: float = maxf(0.01, _v2_track_length)
	print("WILD TIDE LONG WATER TRACK READY route_points=%d checkpoints=%d old_length=%.1fm new_length=%.1fm added=%.1fm long_water=%.1fm water=%.1f%% shallow=%.1f%% deep=%.1f%% hidden_support=true" % [
		EXPANDED_ROUTE_POINTS.size(),
		EXPANDED_CHECKPOINT_ROUTE_INDICES.size(),
		ORIGINAL_TRACK_DISTANCE,
		_v2_track_length,
		_v2_track_length - ORIGINAL_TRACK_DISTANCE,
		get_long_water_distance(),
		_wild_tide_water_distance / total * 100.0,
		_wild_tide_shallow_distance / total * 100.0,
		_wild_tide_deep_distance / total * 100.0,
	])

func get_route_points() -> Array[Vector3]:
	return EXPANDED_ROUTE_POINTS.duplicate()

func get_checkpoint_positions() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for route_index: int in EXPANDED_CHECKPOINT_ROUTE_INDICES:
		result.append(EXPANDED_ROUTE_POINTS[route_index])
	return result

func get_start_position() -> Vector3:
	return EXPANDED_ROUTE_POINTS[0]

func get_finish_position() -> Vector3:
	return EXPANDED_ROUTE_POINTS[-1]

func get_segment_width(segment_index: int) -> float:
	if segment_index < 0 or segment_index >= EXPANDED_SEGMENT_WIDTHS.size():
		return 18.0
	return EXPANDED_SEGMENT_WIDTHS[segment_index]

func is_wild_tide_water_segment(segment_index: int) -> bool:
	return EXPANDED_WATER_SEGMENTS.has(segment_index)

func is_wild_tide_deep_segment(segment_index: int) -> bool:
	return EXPANDED_DEEP_SEGMENTS.has(segment_index)

func get_long_water_distance() -> float:
	var distance: float = 0.0
	for segment_index: int in range(LONG_WATER_START_SEGMENT, LONG_WATER_END_SEGMENT + 1):
		distance += EXPANDED_ROUTE_POINTS[segment_index].distance_to(EXPANDED_ROUTE_POINTS[segment_index + 1])
	return distance

func get_zone_names() -> PackedStringArray:
	return PackedStringArray([
		"Harbor Start",
		"Flooded Harbor Split",
		"Mangrove Jungle",
		"Flooded Midfield",
		"High Tide Gate",
		"Long Deep Channel",
		"Delta Rapids",
		"Mangrove Water Channel",
		"Open Water Sprint",
		"Final Delta",
	])

func _v2_build_world_floor() -> void:
	_v2_visual_root = Node3D.new()
	_v2_visual_root.name = "WildTideLongWaterVisuals"
	add_child(_v2_visual_root)
	_v2_collision_root = Node3D.new()
	_v2_collision_root.name = "WildTideLongWaterCollision"
	add_child(_v2_collision_root)

	var floor_collision: CSGBox3D = CSGBox3D.new()
	floor_collision.name = "WildTideExpandedSupportFloor"
	floor_collision.size = EXPANDED_FLOOR_SIZE
	floor_collision.position = EXPANDED_FLOOR_CENTER
	floor_collision.use_collision = true
	floor_collision.collision_layer = 1
	floor_collision.collision_mask = 0
	floor_collision.visible = false
	_v2_collision_root.add_child(floor_collision)

	var ground_visual: CSGBox3D = CSGBox3D.new()
	ground_visual.name = "WildTideExpandedTropicalGround"
	ground_visual.size = EXPANDED_FLOOR_SIZE
	ground_visual.position = EXPANDED_FLOOR_CENTER + Vector3.DOWN * 0.04
	ground_visual.use_collision = false
	ground_visual.material = _v2_materials[&"city_ground"]
	_v2_visual_root.add_child(ground_visual)

func _v2_build_road() -> void:
	var road_transforms: Array[Transform3D] = []
	var cyan_edges: Array[Transform3D] = []
	var orange_edges: Array[Transform3D] = []
	_v2_track_length = 0.0
	_wild_tide_water_distance = 0.0
	_wild_tide_deep_distance = 0.0
	_wild_tide_shallow_distance = 0.0

	for segment_index: int in range(EXPANDED_ROUTE_POINTS.size() - 1):
		var a: Vector3 = EXPANDED_ROUTE_POINTS[segment_index]
		var b: Vector3 = EXPANDED_ROUTE_POINTS[segment_index + 1]
		var width: float = EXPANDED_SEGMENT_WIDTHS[segment_index]
		var length: float = a.distance_to(b)
		_v2_track_length += length
		_v2_add_road_collision("WildTideSupport_%02d" % segment_index, a, b, width, length)

		if EXPANDED_WATER_SEGMENTS.has(segment_index):
			_wild_tide_water_distance += length
			if EXPANDED_DEEP_SEGMENTS.has(segment_index):
				_wild_tide_deep_distance += length
			else:
				_wild_tide_shallow_distance += length
			continue

		road_transforms.append(_v2_track_xform(
			a, b, 0.5, 0.0, 0.02,
			Vector3(width, 0.16, length + 0.35)
		))
		for side: float in [-1.0, 1.0]:
			var edge_transform: Transform3D = _v2_track_xform(
				a, b, 0.5,
				side * (width * 0.5 - 0.28),
				0.115,
				Vector3(0.18, 0.05, maxf(0.5, length - 0.30))
			)
			if side < 0.0:
				cyan_edges.append(edge_transform)
			else:
				orange_edges.append(edge_transform)

	_v2_add_batch("WildTideLandRoadSurface", road_transforms, _v2_materials[&"road"])
	_v2_add_batch("WildTideLandEdgeCyan", cyan_edges, _v2_materials[&"edge_cyan"])
	_v2_add_batch("WildTideLandEdgeOrange", orange_edges, _v2_materials[&"edge_magenta"])

func _v2_build_start_finish() -> void:
	var start_a: Vector3 = EXPANDED_ROUTE_POINTS[0]
	var start_b: Vector3 = EXPANDED_ROUTE_POINTS[1]
	var finish_a: Vector3 = EXPANDED_ROUTE_POINTS[-2]
	var finish_b: Vector3 = EXPANDED_ROUTE_POINTS[-1]

	var start_parts: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		start_parts.append(_v2_track_xform(start_a, start_b, 0.12, side * 10.3, 2.5, Vector3(0.42, 5.0, 0.42)))
	start_parts.append(_v2_track_xform(start_a, start_b, 0.12, 0.0, 4.75, Vector3(21.0, 0.42, 0.42)))
	_v2_add_batch("WildTideStartGantry", start_parts, _v2_materials[&"metal"])

	var finish_parts: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		finish_parts.append(_v2_track_xform(finish_a, finish_b, 0.96, side * 11.0, 2.7, Vector3(0.46, 5.4, 0.46)))
	finish_parts.append(_v2_track_xform(finish_a, finish_b, 0.96, 0.0, 5.05, Vector3(22.5, 0.48, 0.48)))
	_v2_add_batch("WildTideLongWaterFinishGantry", finish_parts, _v2_materials[&"finish"])

	var finish_position: Vector3 = EXPANDED_ROUTE_POINTS[-1]
	var finish_direction: Vector3 = (finish_position - EXPANDED_ROUTE_POINTS[-2]).normalized()
	var finish_area: Area3D = Area3D.new()
	finish_area.name = "FinishLine"
	finish_area.set_script(FINISH_SCRIPT)
	finish_area.position = finish_position + Vector3.UP * 1.8
	finish_area.collision_mask = 2
	add_child(finish_area)
	finish_area.look_at(finish_position + finish_direction + Vector3.UP * 1.8, Vector3.UP)
	var finish_shape: CollisionShape3D = CollisionShape3D.new()
	var finish_box: BoxShape3D = BoxShape3D.new()
	finish_box.size = Vector3(24.0, 4.5, 7.0)
	finish_shape.shape = finish_box
	finish_area.add_child(finish_shape)

func _v2_build_checkpoints() -> void:
	for checkpoint_index: int in range(EXPANDED_CHECKPOINT_ROUTE_INDICES.size()):
		var route_index: int = EXPANDED_CHECKPOINT_ROUTE_INDICES[checkpoint_index]
		var point: Vector3 = EXPANDED_ROUTE_POINTS[route_index]
		var next: Vector3 = EXPANDED_ROUTE_POINTS[min(route_index + 1, EXPANDED_ROUTE_POINTS.size() - 1)]
		var width: float = EXPANDED_SEGMENT_WIDTHS[min(route_index, EXPANDED_SEGMENT_WIDTHS.size() - 1)]
		var area: Area3D = Area3D.new()
		area.name = "Checkpoint_%02d" % (checkpoint_index + 1)
		area.set_script(CHECKPOINT_SCRIPT)
		area.set("checkpoint_index", checkpoint_index)
		area.position = point + Vector3.UP * 1.8
		area.collision_mask = 2
		add_child(area)
		area.look_at(next + Vector3.UP * 1.8, Vector3.UP)
		var shape: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(width + 5.0, 4.5, 9.0)
		shape.shape = box
		area.add_child(shape)
