class_name WildDashWildTideRouteGuidanceV3LongWater
extends "res://modes/neon_harbor_race/wild_tide_route_guidance_v2.gd"

## Adds readable guidance through the expanded 371m water finale while keeping
## all existing Round-3 arrows/signs intact.

const LONG_MAIN_ARROW_INDICES: Array[int] = [29, 31, 33, 35]
const LONG_WATER_ARROW_INDICES: Array[int] = [29, 30, 31, 32, 33, 34, 35]
const LONG_SPLIT_ARROW_INDICES: Array[int] = [29, 33]

func _ready() -> void:
	super._ready()
	call_deferred("_add_long_water_guidance")

func _add_long_water_guidance() -> void:
	for _attempt: int in range(120):
		if _route_points.size() >= 37 and _main_count > 0:
			break
		await get_tree().physics_frame
	if _route_points.size() < 37:
		push_warning("WILD TIDE GUIDANCE V3 long-water arrows skipped: expanded route unavailable")
		return

	var main_material: StandardMaterial3D = _arrow_material(Color(1.0, 0.66, 0.07), 0.48)
	var water_material: StandardMaterial3D = _arrow_material(Color(0.04, 0.90, 1.0), 0.66)
	var shallow_material: StandardMaterial3D = _arrow_material(Color(0.38, 0.98, 1.0), 0.58)
	var split_material: StandardMaterial3D = _arrow_material(Color(1.0, 0.34, 0.06), 0.60)

	for route_index: int in LONG_MAIN_ARROW_INDICES:
		if _create_route_arrow(route_index, 0.58, main_material, "LongMainArrow"):
			_main_count += 1
	for route_index: int in LONG_WATER_ARROW_INDICES:
		var lateral: float = -5.8 if route_index in [29, 30, 33, 34] else 5.6
		var material: StandardMaterial3D = water_material if lateral < 0.0 else shallow_material
		if _create_offset_arrow(route_index, lateral, 0.66, material, "LongWaterArrow"):
			_water_count += 1
	for route_index: int in LONG_SPLIT_ARROW_INDICES:
		if _create_offset_arrow(route_index, 7.0, 0.64, split_material, "LongSplitArrow"):
			_shortcut_count += 1

	_create_split_sign(29, "LONG WATER", 0.0, Color(0.05, 0.92, 1.0))
	_create_split_sign(29, "DEEP ROUTE", -7.5, Color(0.03, 0.72, 1.0))
	_create_split_sign(29, "SHALLOW EDGE", 7.5, Color(0.42, 0.98, 1.0))
	_create_split_sign(31, "DELTA RAPIDS", 0.0, Color(0.70, 0.96, 1.0))
	_create_split_sign(32, "MANGROVE CHANNEL", 0.0, Color(0.30, 1.0, 0.22))
	_create_split_sign(33, "OPEN WATER", 0.0, Color(1.0, 0.80, 0.12))

	print("ARROW GUIDE V3 LONG WATER READY main=%d water=%d canopy=%d shortcut=%d long_water_arrows=%d signs=6" % [
		_main_count, _water_count, _canopy_count, _shortcut_count, LONG_WATER_ARROW_INDICES.size(),
	])
